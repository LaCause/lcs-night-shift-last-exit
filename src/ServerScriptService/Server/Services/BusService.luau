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
local departurePrompt: ProximityPrompt? = nil
local stayPrompt: ProximityPrompt? = nil

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

-- 007-nuits-optionnelles-evasion : correction de recherche — DepartBus est en réalité déjà
-- restreint à la phase Évasion depuis 003-bus-evasion (`phases = { "Escape" }` dans
-- Remotes.luau, repéré seulement en testant cette fonctionnalité en direct : research.md et
-- spec.md avaient supposé un départ anticipé possible avant le seuil minimum, qui n'a jamais
-- existé). Les deux prompts partagent donc exactement la même condition.
local function refreshEscapePrompts()
	local available = repaired and MatchService.getPhase() == "Escape"
	if departurePrompt then
		departurePrompt.Enabled = available
	end
	if stayPrompt then
		stayPrompt.Enabled = available
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
	refreshEscapePrompts()
end

function BusService.isRepaired(): boolean
	return repaired
end

function BusService.getProgress(): (number, number)
	return deposited, required
end

-- Prélève jusqu'à `maxAmount` ferraille et l'applique à la réparation (005-depot-intelligent-sac,
-- research R7) : extraite de l'ancien corps de `RepairBus` pour que le dépôt manuel et le dépôt
-- automatique partagent exactement le même code — même seuil, même notification, même
-- déclenchement de `BusRepaired` — plutôt que deux copies qui pourraient diverger. Renvoie la
-- quantité réellement déposée (0 si déjà réparé).
function BusService.deposit(player: Player, maxAmount: number): number
	local room = required - deposited
	if room <= 0 then
		return 0
	end
	local used = InventoryService.depositResource(player, "Scrap", math.min(maxAmount, room))
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
			refreshEscapePrompts()
			NotifyService.broadcast("BusRepaired", {})
			log:info("Bus réparé (%d/%d)", deposited, required)
		end
	end
	return used
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
		refreshEscapePrompts()
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

-- 007-nuits-optionnelles-evasion : le prompt de départ, désactivé tant que le bus n'est pas
-- réparé (research R5 — InteractionController.luau relaie déjà tout ProximityPrompt portant
-- l'attribut Intent, aucun changement client nécessaire).
local function buildEscapePrompts()
	local found = WorldService.refPoint(BUS_ID)
	if found == nil then
		error(`Point de référence {BUS_ID} introuvable : départ désactivé`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeparturePrompt"
	prompt.ActionText = Strings.format("Bus.DepartAction")
	prompt.ObjectText = Strings.format("Bus.DepartObject")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Bus", "DepartureRange")
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("Intent", "DepartBus")
	prompt:SetAttribute("Target", BUS_ID)
	prompt.Parent = found
	departurePrompt = prompt

	local stay = Instance.new("ProximityPrompt")
	stay.Name = "StayPrompt"
	stay.ActionText = Strings.format("Bus.StayAction")
	stay.ObjectText = Strings.format("Bus.StayObject")
	stay.HoldDuration = 0
	stay.MaxActivationDistance = Config.get("Bus", "DepartureRange")
	stay.RequiresLineOfSight = false
	stay.Enabled = false
	stay:SetAttribute("Intent", "PushNight")
	stay:SetAttribute("Target", BUS_ID)
	stay.Parent = found
	stayPrompt = stay
end

-- Vérifie que tous les joueurs vivants sont à portée de `busPart` (007-nuits-optionnelles-evasion,
-- research R3 : extrait de l'ancien corps de `DepartBus` pour que ce dernier et `PushNight`
-- partagent exactement la même règle plutôt que deux copies qui pourraient diverger).
local function teamReadyAtBus(busPart: BasePart): boolean
	local range: number = Config.get("Bus", "DepartureRange") + Config.get("Net", "DistanceTolerance")
	for _, session in SessionService.all() do
		if session.Status == "Alive" then
			local character = session.Player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root == nil or not root:IsA("BasePart") then
				return false
			end
			local distance = (root.Position - busPart.Position).Magnitude
			if distance > range then
				return false
			end
		end
	end
	return true
end

function BusService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "BusState"
	folder.Parent = ReplicatedStorage
	state = folder
	resetForNewMatch()

	buildRepairPrompt()
	buildEscapePrompts()

	MatchService.MatchStarting:Connect(resetForNewMatch)
	MatchService.PhaseStarted:Connect(function(phase: Types.Phase, _night: number)
		if phase == "Escape" then
			frozen = true
		end
		-- 007-nuits-optionnelles-evasion : le prompt "rester" dépend de la phase, pas seulement
		-- de `repaired` — le rafraîchir à chaque changement de phase (entrée ET sortie d'Évasion).
		refreshEscapePrompts()
	end)
	SessionService.PlayerJoined:Connect(recomputeRequiredIfUnfrozen)
	SessionService.PlayerLeft:Connect(recomputeRequiredIfUnfrozen)

	NetService.registerIntent("RepairBus", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= BUS_ID then
				return "TargetMissing"
			end
			BusService.deposit(player, math.huge)
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
			if not teamReadyAtBus(busPart) then
				return "TeamNotReady"
			end
			MatchService.endMatch("Victory", "le bus est parti")
			return nil
		end,
	})

	-- 007-nuits-optionnelles-evasion : au lieu de partir, l'équipe choisit de rester une nuit de
	-- plus. Réservée à la phase Évasion, comme DepartBus — déjà garanti par la déclaration
	-- `phases = { "Escape" }` de Remotes.luau (NetService rejette WrongPhase avant même d'appeler
	-- ce gestionnaire, research R3), donc aucune revérification ici, par cohérence avec DepartBus
	-- ci-dessus et le reste des intentions du projet (aucune ne revérifie sa propre phase).
	NetService.registerIntent("PushNight", {
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
			if not teamReadyAtBus(busPart) then
				return "TeamNotReady"
			end
			MatchService.pushExtraNight()
			return nil
		end,
	})

	log:info("Bus prêt (ferraille requise : %d pour %d joueur(s))", required, SessionService.countPresent())
end

return BusService
