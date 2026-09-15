--!strict
-- Réparation du bus et départ en victoire (003-bus-evasion, FR-001 à FR-012).
-- État répliqué sur ReplicatedStorage.BusState, dont ce service est le seul écrivain
-- (contracts/replicated-state.md). Le modèle du bus lui-même est construit une seule fois par
-- WorldService au démarrage du serveur (pas reconstruit par partie, contrairement à la forêt) ;
-- BusService bascule seulement deux de ses pièces déjà nommées (RustPatch, RepairLight).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local SessionService = require(script.Parent.SessionService)
local WorldService = require(script.Parent.WorldService)

local BUS_ID = "BusSpot"
local UNREPAIRED_LIGHT_COLOR = Color3.fromRGB(255, 80, 60)
local REPAIRED_LIGHT_COLOR = Color3.fromRGB(90, 220, 130)

local log = Log.new("Bus")

local BusService = { Name = "BusService", Priority = 66 }

local state: Folder? = nil
local deposited = 0
local required = 0
local repaired = false
local frozen = false

local function stateFolder(): Folder
	local folder = state
	if folder == nil then
		error("BusService.Init n'a pas encore créé BusState", 2)
	end
	return folder
end

local function computeRequired(): number
	local perPlayer: number = Config.get("Bus", "ScrapPerPlayer")
	return perPlayer * SessionService.countPresent()
end

local function publish()
	local folder = stateFolder()
	folder:SetAttribute("Deposited", deposited)
	folder:SetAttribute("Required", required)
	folder:SetAttribute("Repaired", repaired)
end

local function setVisualRepaired(value: boolean)
	local model = WorldService.visual("Bus")
	if model == nil then
		log:warn("Modèle du bus introuvable : état visuel de réparation ignoré")
		return
	end
	local rustPatch = model:FindFirstChild("RustPatch")
	if rustPatch and rustPatch:IsA("BasePart") then
		rustPatch.Transparency = if value then 1 else 0
	end
	local repairLight = model:FindFirstChild("RepairLight")
	if repairLight and repairLight:IsA("BasePart") then
		repairLight.Color = if value then REPAIRED_LIGHT_COLOR else UNREPAIRED_LIGHT_COLOR
	end
end

local function recomputeRequiredIfUnfrozen()
	if frozen then
		return
	end
	required = computeRequired()
	publish()
end

local function resetForNewMatch()
	deposited = 0
	required = computeRequired()
	repaired = false
	frozen = false
	publish()
	setVisualRepaired(false)
end

function BusService.isRepaired(): boolean
	return repaired
end

function BusService.getProgress(): (number, number)
	return deposited, required
end

-- Force la réparation complète (Dev.RepairBus, FR-012) : fige `required` s'il ne l'était pas
-- encore (comme l'entrée en Évasion le ferait), porte `deposited` à `required`, et bascule
-- `repaired` si ce n'était pas déjà le cas.
function BusService.forceRepair()
	if not frozen then
		frozen = true
		required = computeRequired()
	end
	if required <= 0 then
		required = 1
	end
	deposited = required
	if not repaired then
		repaired = true
		setVisualRepaired(true)
		NotifyService.broadcast("BusRepaired", {})
	end
	publish()
end

local function buildRepairPrompt()
	local found = WorldService.refPoint(BUS_ID)
	if found == nil then
		error(`Point de référence {BUS_ID} introuvable : réparation du bus désactivée`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ActionText = Strings.format("Bus.RepairAction")
	prompt.ObjectText = Strings.format("Bus.RepairObject")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Bus", "InteractRange")
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Intent", "RepairBus")
	prompt:SetAttribute("Target", BUS_ID)
	prompt.Parent = found
end

function BusService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "BusState"
	folder.Parent = ReplicatedStorage
	state = folder
	resetForNewMatch()

	buildRepairPrompt()

	MatchService.MatchStarting:Connect(resetForNewMatch)
	MatchService.PhaseStarted:Connect(function(phase: Types.Phase, _night: number)
		if phase == "Escape" then
			frozen = true
		end
	end)
	SessionService.PlayerJoined:Connect(recomputeRequiredIfUnfrozen)
	SessionService.PlayerLeft:Connect(recomputeRequiredIfUnfrozen)

	NetService.registerIntent("RepairBus", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= BUS_ID then
				return "TargetMissing"
			end
			local room = required - deposited
			if room <= 0 then
				return nil -- déjà réparé : aucune ferraille consommée, rien à faire
			end
			local used = InventoryService.depositResource(player, "Scrap", room)
			if used > 0 then
				deposited += used
				publish()
				-- Retour son/visuel léger côté client (SfxController) : pas d'effet de jeu.
				NotifyService.send(player, "ScrapDeposited", { amount = used })
				log:info("%s dépose %d ferraille au bus (%d/%d)", player.Name, used, deposited, required)
				if deposited >= required and not repaired then
					repaired = true
					publish()
					setVisualRepaired(true)
					NotifyService.broadcast("BusRepaired", {})
					log:info("Bus réparé (%d/%d)", deposited, required)
				end
			end
			return nil
		end,
	})

	NetService.registerIntent("DepartBus", {
		handler = function(_player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= BUS_ID then
				return "TargetMissing"
			end
			if not repaired then
				return "BusNotRepaired"
			end
			local busPart = WorldService.refPoint(BUS_ID)
			if busPart == nil then
				return "TargetMissing"
			end
			local range: number = Config.get("Bus", "DepartureRange") + Config.get("Net", "DistanceTolerance")
			for _, session in SessionService.all() do
				if session.Status == "Alive" then
					local character = session.Player.Character
					local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if root == nil or not root:IsA("BasePart") then
						return "TeamNotReady"
					end
					local distance = (root.Position - busPart.Position).Magnitude
					if distance > range then
						return "TeamNotReady"
					end
				end
			end
			MatchService.endMatch("Victory", "le bus est parti")
			return nil
		end,
	})

	log:info("Bus prêt (ferraille requise : %d pour %d joueur(s))", required, SessionService.countPresent())
end

return BusService
