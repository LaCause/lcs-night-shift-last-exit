--!strict
-- Santé serveur du joueur (002-premier-increment-jouable, FR-022, FR-023 ; research R4).
-- Valeur distincte de Humanoid.Health : seuls les dégâts d'ennemi et la remise à zéro de
-- partie la modifient. La chute accidentelle du monde (comportement du socle) n'y touche pas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local MatchService = require(script.Parent.MatchService)
local SessionService = require(script.Parent.SessionService)

local log = Log.new("Health")

local HealthService = { Name = "HealthService", Priority = 46 }

local function initPlayer(player: Player)
	local maxHealth: number = Config.get("Players", "MaxHealth")
	player:SetAttribute("MaxHealth", maxHealth)
	player:SetAttribute("Health", maxHealth)
end

local function resetAll()
	for _, player in Players:GetPlayers() do
		initPlayer(player)
	end
end

function HealthService.get(player: Player): number?
	local value = player:GetAttribute("Health")
	return if typeof(value) == "number" then value else nil
end

-- Sans effet si le joueur n'est pas en vie (déjà éliminé, ou personnage absent).
function HealthService.damage(player: Player, amount: number)
	local session = SessionService.get(player)
	if session == nil or session.Status ~= "Alive" then
		return
	end
	local current = HealthService.get(player)
	if current == nil then
		return
	end
	local updated = math.max(0, current - amount)
	player:SetAttribute("Health", updated)
	if updated <= 0 then
		log:info("%s : santé à 0", player.Name)
		SessionService.setStatus(player, "Eliminated")
	end
end

-- Miroir symétrique de damage ci-dessus (009-craft-etabli, research R4) : clamp à MaxHealth au
-- lieu de 0, aucun changement de statut associé. Sans effet si le joueur n'est pas en vie.
function HealthService.heal(player: Player, amount: number)
	local session = SessionService.get(player)
	if session == nil or session.Status ~= "Alive" then
		return
	end
	local current = HealthService.get(player)
	if current == nil then
		return
	end
	local maxHealth = player:GetAttribute("MaxHealth")
	local cap = if typeof(maxHealth) == "number" then maxHealth else Config.get("Players", "MaxHealth")
	player:SetAttribute("Health", math.min(cap, current + amount))
end

function HealthService.Init()
	MatchService.MatchStarting:Connect(resetAll)
	SessionService.PlayerJoined:Connect(initPlayer)
	log:info("Santé des joueurs prête (max %d)", Config.get("Players", "MaxHealth"))
end

return HealthService
