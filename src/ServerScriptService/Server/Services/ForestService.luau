--!strict
-- Forêt basique et points de ressource (002-premier-increment-jouable, FR-001 à FR-003).
-- Régénérée à chaque MatchService.MatchStarting, à partir de MatchService.rng("forest")
-- (research R1). Vit dans Workspace.Forest, séparé de Workspace.World (research R2).

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
local VisualService = require(script.Parent.VisualService)

type ResourceType = Types.ResourceType

type NodeState = {
	model: Model,
	part: BasePart,
	resourceType: ResourceType,
	available: boolean,
}

-- Ordre fixe : garantit des tirages reproductibles pour une même seed (SC-009).
local RESOURCE_TYPES: { ResourceType } = { "Essence", "SuspectSteak", "RoadBread" }

local VISUAL_FOR: { [ResourceType]: string } = {
	Essence = "FuelCanister",
	SuspectSteak = "SuspectCooler",
	RoadBread = "RoadVendingMachine",
}

local NODE_COUNT_SETTING: { [ResourceType]: string } = {
	Essence = "NodeCountEssence",
	SuspectSteak = "NodeCountSuspectSteak",
	RoadBread = "NodeCountRoadBread",
}

local log = Log.new("Forest")

local ForestService = { Name = "ForestService", Priority = 42 }

local nodes: { [string]: NodeState } = {}
local ready = false

local function setAvailable(node: NodeState, value: boolean)
	node.available = value
	node.part:SetAttribute("Available", value)
	local prompt = node.part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = value
	end
	for _, descendant in node.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if value then 0 else 1
			descendant.CanCollide = value
		end
	end
end

local function buildNode(folder: Folder, resourceType: ResourceType, id: string, position: Vector3)
	local model = VisualService.build(VISUAL_FOR[resourceType])
	if model == nil then
		log:error("Visuel introuvable pour le nœud %s : ignoré", id)
		return
	end
	model.Name = id
	model:PivotTo(CFrame.new(position))
	local part = model.PrimaryPart
	if part == nil then
		log:error("Nœud %s sans PrimaryPart : ignoré", id)
		model:Destroy()
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = Strings.format("Forest.HarvestAction")
	prompt.ObjectText = Strings.format(`Resource.{resourceType}`)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Forest", "HarvestRange")
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Intent", "HarvestResource")
	prompt:SetAttribute("Target", id)
	prompt.Parent = part

	part:SetAttribute("ResourceType", resourceType)
	part:SetAttribute("Available", true)
	model.Parent = folder

	nodes[id] = { model = model, part = part, resourceType = resourceType, available = true }
end

local function regenerate(seed: number)
	local previous = workspace:FindFirstChild("Forest")
	if previous then
		previous:Destroy()
	end
	nodes = {}

	local folder = Instance.new("Folder")
	folder.Name = "Forest"

	local rng = MatchService.rng("forest")
	local minRadius: number = Config.get("Forest", "AreaMinRadius")
	local maxRadius: number = Config.get("Forest", "AreaMaxRadius")

	local built = 0
	for _, resourceType in RESOURCE_TYPES do
		local count: number = Config.get("Forest", NODE_COUNT_SETTING[resourceType])
		for index = 1, count do
			local angle = rng:NextNumber(0, 2 * math.pi)
			local radius = rng:NextNumber(minRadius, maxRadius)
			local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			buildNode(folder, resourceType, `{resourceType}_{index}`, position)
			built += 1
		end
	end

	folder.Parent = workspace
	ready = true
	log:info("Forêt régénérée : %d nœuds (seed %d)", built, seed)
end

function ForestService.findNode(id: any): BasePart?
	if typeof(id) ~= "string" then
		return nil
	end
	local node = nodes[id]
	if node == nil then
		return nil
	end
	return node.part
end

function ForestService.isReady(): boolean
	return ready
end

function ForestService.Init()
	MatchService.MatchStarting:Connect(function(_matchId: number, seed: number)
		regenerate(seed)
	end)

	NetService.registerIntent("HarvestResource", {
		resolve = ForestService.findNode,
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			local node = nodes[payload.target]
			if node == nil then
				return "TargetMissing"
			end
			if not node.available then
				return "NodeUnavailable"
			end
			if not InventoryService.addPersonal(player, node.resourceType, 1) then
				return "InventoryFull"
			end
			setAvailable(node, false)
			-- Retour son/visuel léger côté client (SfxController) : pas d'effet de jeu.
			NotifyService.send(player, "ResourceHarvested", { resourceType = node.resourceType })
			local respawnDelay: number = Config.get("Forest", "RespawnDelay", MatchService.isTestProfile())
			task.delay(respawnDelay, function()
				if nodes[payload.target] == node then
					setAvailable(node, true)
				end
			end)
			return nil
		end,
	})
end

return ForestService
