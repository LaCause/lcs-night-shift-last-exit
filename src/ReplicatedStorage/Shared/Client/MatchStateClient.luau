--!strict
-- Lecture côté client de l'état de partie répliqué (contracts/replicated-state.md, FR-019).
-- Le client ne recalcule rien : il lit les attributs écrits par MatchService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(script.Parent.Parent.Util.Log)
local Signal = require(script.Parent.Parent.Util.Signal)

export type State = {
	phase: string,
	night: number,
	totalNights: number,
	phaseEndsAt: number,
	result: string,
	matchId: number,
	testProfile: boolean,
}

local WAIT_TIMEOUT = 30

local log = Log.new("MatchStateClient")

local folder: Instance? = nil

local MatchStateClient = {
	Changed = Signal.new("MatchStateClient.Changed") :: Signal.Signal<()>,
}

local function read(name: string, default: any): any
	local current = folder
	if current == nil then
		return default
	end
	local value = current:GetAttribute(name)
	if value == nil or typeof(value) ~= typeof(default) then
		return default
	end
	return value
end

function MatchStateClient.get(): State
	return {
		phase = read("Phase", "Waiting"),
		night = read("Night", 0),
		totalNights = read("TotalNights", 0),
		phaseEndsAt = read("PhaseEndsAt", 0),
		result = read("Result", ""),
		matchId = read("MatchId", 0),
		testProfile = read("TestProfile", false),
	}
end

-- Temps restant de la phase, calculé sur l'horloge serveur partagée ; nil = sans limite.
function MatchStateClient.remaining(): number?
	local endsAt: number = read("PhaseEndsAt", 0)
	if endsAt <= 0 then
		return nil
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

-- Une seule connexion pour tout le client, établie au premier chargement du module.
task.spawn(function()
	local found = ReplicatedStorage:WaitForChild("MatchState", WAIT_TIMEOUT)
	if found == nil then
		log:error("ReplicatedStorage.MatchState introuvable après %d s", WAIT_TIMEOUT)
		return
	end
	folder = found
	found.AttributeChanged:Connect(function()
		MatchStateClient.Changed:Fire()
	end)
	MatchStateClient.Changed:Fire()
end)

return MatchStateClient
