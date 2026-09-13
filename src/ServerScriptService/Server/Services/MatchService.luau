--!strict
-- Horloge de partie autoritaire (data-model.md, « Phase — machine à états ») :
-- Attente → Compte à rebours → Jour/Nuit × N → Évasion → Fin → nouvelle partie.
-- L'état est répliqué par attributs sur ReplicatedStorage.MatchState, dont ce service est le
-- seul écrivain (contracts/replicated-state.md ; FR-017 à FR-020, FR-026 à FR-029, FR-039).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Rng = require(Shared.Util.Rng)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local NotifyService = require(script.Parent.NotifyService)
local SessionService = require(script.Parent.SessionService)

type Phase = Types.Phase
type MatchResult = Types.MatchResult
type PlayerStatus = Types.PlayerStatus

local MAX_SEED = 2147483647
local DURATION_KEYS: { [string]: string } = {
	Countdown = "CountdownDuration",
	Day = "DayDuration",
	Night = "NightDuration",
	Escape = "EscapeDuration",
	Ended = "EndScreenDuration",
}

local log = Log.new("Match")

local MatchService = {
	Name = "MatchService",
	Priority = 50,
	PhaseStarted = Signal.new("MatchService.PhaseStarted") :: Signal.Signal<Phase, number>,
	PhaseEnded = Signal.new("MatchService.PhaseEnded") :: Signal.Signal<Phase, number>,
	MatchStarted = Signal.new("MatchService.MatchStarted") :: Signal.Signal<number, number>,
	MatchEnded = Signal.new("MatchService.MatchEnded") :: Signal.Signal<MatchResult, number>,
}

local state = {
	phase = "Waiting" :: Phase,
	night = 0,
	totalNights = 0,
	phaseEndsAt = 0,
	result = "",
	matchId = 0,
	seed = 0,
	testProfile = Config.TestProfileDefault :: boolean,
	token = 0,
}

local stateFolder: Folder? = nil

local function publish()
	local folder = stateFolder
	if folder == nil then
		return
	end
	-- La phase en dernier : un client qui réagit à son changement lit déjà le reste à jour.
	folder:SetAttribute("PhaseEndsAt", state.phaseEndsAt)
	folder:SetAttribute("Night", state.night)
	folder:SetAttribute("TotalNights", state.totalNights)
	folder:SetAttribute("Result", state.result)
	folder:SetAttribute("MatchId", state.matchId)
	folder:SetAttribute("TestProfile", state.testProfile)
	folder:SetAttribute("Phase", state.phase)
end

local function durationFor(phase: Phase): number
	local key = DURATION_KEYS[phase]
	if key == nil then
		return 0
	end
	return Config.get("Match", key, state.testProfile)
end

local advance: () -> ()

local function enterPhase(phase: Phase, night: number)
	local previousPhase, previousNight = state.phase, state.night
	state.token += 1
	local token = state.token
	state.phase = phase
	state.night = night
	local duration = durationFor(phase)
	state.phaseEndsAt = if duration > 0 then workspace:GetServerTimeNow() + duration else 0
	publish()

	local durationText = if duration > 0 then `{duration} s` else "sans limite"
	log:info("Phase %s (nuit %d/%d, %s)", phase, night, state.totalNights, durationText)
	MatchService.PhaseEnded:Fire(previousPhase, previousNight)
	MatchService.PhaseStarted:Fire(phase, night)
	if phase ~= "Waiting" and phase ~= "Ended" then
		NotifyService.broadcast("PhaseStarted", {
			phase = phase,
			night = night,
			totalNights = state.totalNights,
			duration = duration,
		})
	end

	if duration > 0 then
		task.delay(duration, function()
			-- Un saut de phase ou un abandon a invalidé ce délai entre-temps.
			if state.token == token then
				advance()
			end
		end)
	end
end

local function pickSeed(): number
	local forced: number = Config.get("Match", "ForcedSeed")
	if forced > 0 then
		return forced
	end
	return Random.new():NextInteger(1, MAX_SEED)
end

local function startNewMatch(respawn: boolean)
	state.matchId += 1
	state.seed = pickSeed()
	state.totalNights = Config.get("Match", "NightCount")
	state.result = ""
	SessionService.resetAll()
	if respawn then
		SessionService.respawnAll()
	end
	log:info("Partie #%d — seed %d", state.matchId, state.seed)
	enterPhase("Countdown", 0)
end

local function abandon()
	log:info("Plus aucun joueur : partie #%d abandonnée", state.matchId)
	state.result = ""
	enterPhase("Waiting", 0)
end

function MatchService.isActive(): boolean
	return state.phase == "Day" or state.phase == "Night" or state.phase == "Escape"
end

-- Termine la partie ; seul le premier résultat compte (renvoie false si ignoré).
function MatchService.endMatch(result: MatchResult, reason: string): boolean
	if not MatchService.isActive() then
		log:info("Fin de partie ignorée (%s, %s) : phase %s", result, reason, state.phase)
		return false
	end
	state.result = result
	local night = state.night
	log:info("Partie #%d terminée : %s (%s), nuit %d/%d", state.matchId, result, reason, night, state.totalNights)
	enterPhase("Ended", night)
	MatchService.MatchEnded:Fire(result, night)
	NotifyService.broadcast("MatchEnded", { result = result, night = night, totalNights = state.totalNights })
	return true
end

local function checkDefeat()
	if MatchService.isActive() and SessionService.countPresent() > 0 and SessionService.countAlive() == 0 then
		MatchService.endMatch("Defeat", "toute l'équipe est hors service")
	end
end

advance = function()
	local phase = state.phase
	if phase == "Countdown" then
		enterPhase("Day", 1)
		MatchService.MatchStarted:Fire(state.matchId, state.seed)
	elseif phase == "Day" then
		enterPhase("Night", state.night)
	elseif phase == "Night" then
		if state.night < state.totalNights then
			enterPhase("Day", state.night + 1)
		else
			enterPhase("Escape", state.totalNights)
		end
	elseif phase == "Escape" then
		-- Provisoire : la fonctionnalité du bus redéfinira la fin de l'évasion.
		MatchService.endMatch("Defeat", "le bus n'est pas parti à temps")
	elseif phase == "Ended" then
		if SessionService.countPresent() > 0 then
			startNewMatch(true)
		else
			enterPhase("Waiting", 0)
		end
	end
end

function MatchService.getPhase(): Phase
	return state.phase
end

function MatchService.getNight(): number
	return state.night
end

function MatchService.getTotalNights(): number
	return state.totalNights
end

function MatchService.getSeed(): number
	return state.seed
end

function MatchService.getMatchId(): number
	return state.matchId
end

function MatchService.isTestProfile(): boolean
	return state.testProfile
end

-- Flux aléatoire dérivé de la seed de la partie et d'un contexte (jamais math.random).
function MatchService.rng(...: string | number): Random
	return Rng.forContext(state.seed, ...)
end

-- Commande de dev : force la fin de la phase courante (en Évasion : défaite provisoire).
function MatchService.skipPhase(): boolean
	if state.phase == "Waiting" then
		return false
	end
	log:info("Phase %s sautée (commande de dev)", state.phase)
	advance()
	return true
end

-- Active ou coupe le profil de test ; les durées changent dès la phase suivante.
function MatchService.setTestProfile(enabled: boolean)
	state.testProfile = enabled
	publish()
	log:info("Profil de test %s (dès la phase suivante)", if enabled then "activé" else "désactivé")
end

function MatchService.Init()
	local previous = ReplicatedStorage:FindFirstChild("MatchState")
	if previous then
		previous:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MatchState"
	stateFolder = folder
	publish()
	folder.Parent = ReplicatedStorage

	-- Branché dès l'Init : SessionService annonce les joueurs déjà présents pendant son Start.
	SessionService.PlayerJoined:Connect(function(player: Player)
		NotifyService.broadcast("PlayerJoined", { name = player.DisplayName })
		if state.phase == "Waiting" then
			startNewMatch(false)
		end
	end)
	SessionService.PlayerLeft:Connect(function(player: Player)
		NotifyService.broadcast("PlayerLeft", { name = player.DisplayName })
		if SessionService.countPresent() == 0 then
			if state.phase ~= "Waiting" then
				abandon()
			end
		else
			checkDefeat()
		end
	end)
	SessionService.StatusChanged:Connect(function(player: Player, status: PlayerStatus)
		NotifyService.broadcast("StatusChanged", { name = player.DisplayName, status = status })
		checkDefeat()
	end)
end

return MatchService
