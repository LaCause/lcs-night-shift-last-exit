--!strict
-- Sessions des joueurs, statuts et apparitions (FR-021 à FR-025). Les personnages ne se chargent
-- pas automatiquement (CharacterAutoLoads = false) : le serveur les fait apparaître au restaurant
-- une fois le monde prêt et fait réapparaître les joueurs en vie (research R4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local WorldService = require(script.Parent.WorldService)

type PlayerStatus = Types.PlayerStatus

export type Session = {
	UserId: number,
	Player: Player,
	Status: PlayerStatus,
	JoinedAt: number,
	connections: { RBXScriptConnection },
}

local log = Log.new("Session")

local SessionService = {
	Name = "SessionService",
	Priority = 40,
	PlayerJoined = Signal.new("SessionService.PlayerJoined") :: Signal.Signal<Player>,
	PlayerLeft = Signal.new("SessionService.PlayerLeft") :: Signal.Signal<Player>,
	StatusChanged = Signal.new("SessionService.StatusChanged") :: Signal.Signal<Player, PlayerStatus>,
}

local sessions: { [Player]: Session } = {}

-- Profil de test courant : attribut répliqué par MatchService, sinon valeur de configuration.
local function testProfileActive(): boolean
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	local value = if matchState then matchState:GetAttribute("TestProfile") else nil
	if typeof(value) == "boolean" then
		return value
	end
	return Config.TestProfileDefault
end

local function isDead(player: Player): boolean
	local character = player.Character
	if character == nil then
		return true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health <= 0
end

local function loadCharacter(player: Player)
	if player.Parent == nil then
		return
	end
	if not WorldService.isReady() then
		log:warn("Monde non prêt : %s apparaîtra au point par défaut", player.Name)
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		log:error("Apparition de %s impossible : %s", player.Name, tostring(err))
	end
end

local function watchCharacter(session: Session, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		if sessions[session.Player] ~= session or session.Status ~= "Alive" then
			return
		end
		local respawnDelay: number = Config.get("Players", "RespawnDelay", testProfileActive())
		task.delay(respawnDelay, function()
			local stillHere = sessions[session.Player] == session
			if stillHere and session.Status == "Alive" and session.Player.Character == character then
				loadCharacter(session.Player)
			end
		end)
	end)
end

function SessionService.get(player: Player): Session?
	return sessions[player]
end

function SessionService.all(): { Session }
	local list: { Session } = {}
	for _, session in sessions do
		table.insert(list, session)
	end
	return list
end

function SessionService.countPresent(): number
	local count = 0
	for _ in sessions do
		count += 1
	end
	return count
end

function SessionService.countAlive(): number
	local count = 0
	for _, session in sessions do
		if session.Status == "Alive" then
			count += 1
		end
	end
	return count
end

function SessionService.setStatus(player: Player, status: PlayerStatus)
	local session = sessions[player]
	if session == nil or session.Status == status then
		return
	end
	session.Status = status
	player:SetAttribute("Status", status)
	log:info("%s : %s", player.Name, status)
	SessionService.StatusChanged:Fire(player, status)
	if status == "Alive" and isDead(player) then
		task.spawn(loadCharacter, player)
	end
end

-- Remet tout le monde « en vie » pour une nouvelle partie, sans émettre StatusChanged.
function SessionService.resetAll()
	for player, session in sessions do
		if session.Status ~= "Alive" then
			session.Status = "Alive"
			player:SetAttribute("Status", "Alive")
		end
	end
end

-- Recharge tous les personnages au point d'apparition du restaurant.
function SessionService.respawnAll()
	for player in sessions do
		task.spawn(loadCharacter, player)
	end
end

local function addPlayer(player: Player)
	if sessions[player] ~= nil then
		return
	end
	local session: Session = {
		UserId = player.UserId,
		Player = player,
		Status = "Alive",
		JoinedAt = workspace:GetServerTimeNow(),
		connections = {},
	}
	sessions[player] = session
	player:SetAttribute("Status", session.Status)
	table.insert(
		session.connections,
		player.CharacterAdded:Connect(function(character: Model)
			watchCharacter(session, character)
		end)
	)

	local present = SessionService.countPresent()
	local limit: number = Config.get("Players", "MaxPlayers")
	if present > limit then
		log:warn("%d joueurs présents, au-delà de Players.MaxPlayers (%d) : vérifier la capacité de la place", present, limit)
	end
	log:info("%s a rejoint (%d présents)", player.Name, present)
	SessionService.PlayerJoined:Fire(player)
	task.spawn(loadCharacter, player)
end

local function removePlayer(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	for _, connection in session.connections do
		connection:Disconnect()
	end
	log:info("%s est parti (%d présents)", player.Name, SessionService.countPresent())
	SessionService.PlayerLeft:Fire(player)
end

function SessionService.Start()
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

return SessionService
