--!strict
-- Sonnette du comptoir, interaction de référence (FR-034) : le client envoie l'intention
-- RingBell ; le serveur la valide (pipeline NetService, puis délai de réutilisation) et diffuse le
-- résultat. Le serveur ne se branche jamais sur ProximityPrompt.Triggered (research R8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local BELL_ID = "CounterBell"

local log = Log.new("Bell")

local BellService = { Name = "BellService", Priority = 60 }

local lastRungAt = -math.huge

function BellService.Init()
	local found = WorldService.refPoint(BELL_ID)
	if found == nil then
		error(`Point de référence {BELL_ID} introuvable : sonnette désactivée`)
	end
	local bell: BasePart = found

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BellPrompt"
	prompt.ActionText = Strings.format("Bell.Action")
	prompt.ObjectText = Strings.format("Bell.Object")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Bell", "Range")
	prompt.RequiresLineOfSight = false
	-- Lus par InteractionController côté client : aucune logique propre à la sonnette côté client.
	prompt:SetAttribute("Intent", "RingBell")
	prompt:SetAttribute("Target", BELL_ID)
	prompt.Parent = bell

	NetService.registerIntent("RingBell", {
		handler = function(player: Player, payload: { [string]: any })
			-- Le pipeline a mesuré la distance jusqu'à la cible demandée : elle doit être la sonnette.
			if payload.target ~= BELL_ID then
				return "TargetMissing"
			end
			local now = workspace:GetServerTimeNow()
			if now - lastRungAt < Config.get("Bell", "Cooldown") then
				return "Cooldown"
			end
			lastRungAt = now
			bell:SetAttribute("LastRungAt", now)
			bell:SetAttribute("LastRungBy", player.DisplayName)
			NotifyService.broadcast("BellRang", { name = player.DisplayName })
			log:info("%s a sonné", player.Name)
			return nil
		end,
	})
end

return BellService
