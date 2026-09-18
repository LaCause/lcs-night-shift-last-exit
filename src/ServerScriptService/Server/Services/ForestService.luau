--!strict
-- Forêt basique et points de ressource (002-premier-increment-jouable, FR-001 à FR-003).
-- Régénérée à chaque MatchService.MatchStarting, à partir de MatchService.rng("forest")
-- (research R1). Vit dans Workspace.Forest, séparé de Workspace.World (research R2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
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
	-- 004-sac-collecte : vrai pour un objet sorti d'un sac (ForestService.spawnDrop). Seule
	-- différence avec un nœud généré : il ne réapparaît pas une fois ramassé (FR-021).
	dropped: boolean,
}

-- Ordre fixe : garantit des tirages reproductibles pour une même seed (SC-009).
-- "Scrap" ajouté par 003-bus-evasion (research R3) : aucun changement de logique, une entrée de
-- plus dans ces tables de données.
local RESOURCE_TYPES: { ResourceType } = { "Essence", "SuspectSteak", "RoadBread", "Scrap" }

local VISUAL_FOR: { [ResourceType]: string } = {
	Essence = "FuelCanister",
	SuspectSteak = "SuspectCooler",
	RoadBread = "RoadVendingMachine",
	Scrap = "ScrapPile",
}

local NODE_COUNT_SETTING: { [ResourceType]: string } = {
	Essence = "NodeCountEssence",
	SuspectSteak = "NodeCountSuspectSteak",
	RoadBread = "NodeCountRoadBread",
	Scrap = "NodeCountScrap",
}

local log = Log.new("Forest")

local ForestService = { Name = "ForestService", Priority = 42 }

local nodes: { [string]: NodeState } = {}
local ready = false

local function setAvailable(node: NodeState, value: boolean)
	node.available = value
	node.part:SetAttribute("Available", value)
	for _, descendant in node.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if value then 0 else 1
			descendant.CanCollide = value
		end
	end
end

local function buildNode(folder: Folder, resourceType: ResourceType, id: string, position: Vector3): NodeState?
	local model = VisualService.build(VISUAL_FOR[resourceType])
	if model == nil then
		log:error("Visuel introuvable pour le nœud %s : ignoré", id)
		return nil
	end
	model.Name = id
	-- placeFresh, pas PivotTo : ce modèle a un PrimaryPart (utilisé plus bas), ce qui ferait
	-- reposer PivotTo dessus plutôt que sur la base du modèle (VisualService.placeFresh).
	VisualService.placeFresh(model, CFrame.new(position))
	local part = model.PrimaryPart
	if part == nil then
		log:error("Nœud %s sans PrimaryPart : ignoré", id)
		model:Destroy()
		return nil
	end

	-- 004-sac-collecte : plus d'invite de proximité sur les nœuds — la visée au pointeur
	-- (PointerController) remplace ce déclencheur (research R9). Ces quatre attributs suffisent au
	-- client pour viser : le type visé, sa disponibilité, s'il est déjà tenu par un coéquipier, et
	-- l'identifiant à renvoyer au serveur (que portait auparavant l'attribut Target de l'invite).
	part:SetAttribute("ResourceType", resourceType)
	part:SetAttribute("Available", true)
	part:SetAttribute("GrabbedBy", 0)
	part:SetAttribute("NodeId", id)
	model.Parent = folder

	local node: NodeState = {
		model = model,
		part = part,
		resourceType = resourceType,
		available = true,
		dropped = false,
	}
	nodes[id] = node
	return node
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

-- Compteur des objets lâchés : donne des identifiants uniques et stables, sans aucun tirage
-- (principe V). Jamais remis à zéro — une nouvelle partie vide `nodes`, donc aucune collision.
local dropCount = 0

-- Fait apparaître au sol un objet sorti d'un sac (004-sac-collecte, FR-021). C'est un nœud de
-- forêt ordinaire à une exception près, portée par `dropped` : une fois ramassé il disparaît pour
-- de bon au lieu de réapparaître — sans quoi lâcher puis ramasser en boucle fabriquerait des
-- ressources à partir de rien. Renvoie l'identifiant du nœud créé, ou nil si rien n'a pu être posé :
-- l'appelant ne retire alors rien du sac (principe VI).
function ForestService.spawnDrop(resourceType: ResourceType, position: Vector3): string?
	local folder = workspace:FindFirstChild("Forest")
	if folder == nil or not folder:IsA("Folder") then
		return nil
	end
	if VISUAL_FOR[resourceType] == nil then
		return nil
	end
	dropCount += 1
	local id = `Drop_{dropCount}`
	local node = buildNode(folder, resourceType, id, position)
	if node == nil then
		return nil
	end
	node.dropped = true
	return id
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
			-- Un objet tenu par un coéquipier ne peut pas lui être ramassé sous la main (FR-010,
			-- quickstart V5.2). L'attribut est écrit par CarryService et simplement lu ici :
			-- requérir CarryService rendrait la dépendance circulaire, puisqu'il requiert déjà ce
			-- module pour résoudre ses cibles.
			local grabbedBy = node.part:GetAttribute("GrabbedBy")
			if typeof(grabbedBy) == "number" and grabbedBy ~= 0 and grabbedBy ~= player.UserId then
				return "AlreadyCarried"
			end
			-- On ne ramasse que le sac en main (FR-019) : sans contenant sorti, rien à remplir.
			-- Attribut écrit par BagService, lu ici — même procédé que BagCapacity plus bas, pour
			-- ne pas faire dépendre ce service de lui.
			if player:GetAttribute("BagEquipped") ~= true then
				return "BagNotEquipped"
			end
			if not InventoryService.addPersonal(player, node.resourceType, 1) then
				-- Le pipeline ne renvoie jamais un refus au client (il les journalise seulement) :
				-- sans cette notification, la touche resterait sans effet ni explication
				-- (research R10, FR-003). La contenance est lue dans l'attribut écrit par
				-- BagService, pour ne pas faire dépendre ce service de lui.
				local capacity = player:GetAttribute("BagCapacity")
				NotifyService.send(player, "BagFull", {
					capacity = if typeof(capacity) == "number" then capacity else 0,
				})
				return "InventoryFull"
			end
			setAvailable(node, false)
			-- Retour son/visuel léger côté client (SfxController) : pas d'effet de jeu.
			NotifyService.send(player, "ResourceHarvested", { resourceType = node.resourceType })
			if node.dropped then
				-- Un objet lâché d'un sac existait déjà : le faire réapparaître le dupliquerait.
				-- Il quitte le monde définitivement (FR-021).
				nodes[payload.target] = nil
				node.model:Destroy()
				return nil
			end
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
