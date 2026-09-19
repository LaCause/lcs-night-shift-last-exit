--!strict
-- Sac de portage (004-sac-collecte, FR-003 à FR-007). Le sac est LE contenant du joueur : sa
-- contenance remplace l'ancien réglage Forest.InventoryCapacity (research R1). Ce service est
-- l'unique écrivain des attributs BagType/BagCapacity ; InventoryService les lit plutôt que de
-- requérir ce module, ce qui rendrait la dépendance circulaire (research R6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ForestService = require(script.Parent.ForestService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local SessionService = require(script.Parent.SessionService)
local StationDepositService = require(script.Parent.StationDepositService)
local VisualService = require(script.Parent.VisualService)

type BagType = Types.BagType
type ResourceType = Types.ResourceType

-- Un type de sac = une contenance (réglage) et une entrée de catalogue. Ajouter un sac plus grand
-- est une entrée de plus ici, sans aucune logique nouvelle (research R7).
type BagDef = { CapacitySetting: string, VisualId: string }

local BAG_TYPES: { [string]: BagDef } = {
	LittleBag = { CapacitySetting = "SmallCapacity", VisualId = "LittleBag" },
}

-- Ressources qui occupent de la place dans le sac : les mêmes compteurs que l'inventaire
-- personnel, dont le sac n'est que le plafond.
local CARRIED_TYPES: { ResourceType } = { "Essence", "SuspectSteak", "RoadBread", "Scrap" }

-- Longueur de la sonde verticale qui cherche le sol sous un objet lâché : constante de robustesse,
-- pas un réglage d'équilibrage. Son repli est le plan y = 0, celui où la forêt pose ses nœuds.
local GROUND_PROBE = 60

local log = Log.new("Bag")

local BagService = { Name = "BagService", Priority = 47 }

local function defaultType(): BagType
	return Config.get("Bag", "DefaultType") :: BagType
end

local function defFor(bagType: string): BagDef
	return BAG_TYPES[bagType] or BAG_TYPES[defaultType()]
end

-- Personnage vivant du joueur. DropBag ne vise aucune cible : le pipeline saute alors ses étapes
-- 7 à 9, donc cette vérification revient au gestionnaire (contracts/network.md).
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- Positions réparties en cercle autour du joueur, dans un ordre fixe : deux sacs identiques vidés
-- au même endroit donnent exactement la même disposition (principe V, aucun tirage). Chaque objet
-- est posé sur le sol trouvé sous lui, à défaut sur le plan y = 0, celui des nœuds de la forêt.
local function dropPosition(player: Player, root: BasePart, index: number, total: number): Vector3
	local angle = (index - 1) * (2 * math.pi / math.max(total, 1))
	local radius: number = Config.get("Bag", "DropRadius")
	local around = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions: { Instance } = {}
	local character = player.Character
	if character ~= nil then
		table.insert(exclusions, character)
	end
	-- Sans exclure la forêt, un objet lâché se poserait sur un autre objet au lieu du sol.
	local forest = workspace:FindFirstChild("Forest")
	if forest ~= nil then
		table.insert(exclusions, forest)
	end
	-- Sans exclure les arbres, un objet lâché près de l'un d'eux atterrirait sur une branche.
	local world = workspace:FindFirstChild("World")
	local trees = if world ~= nil then world:FindFirstChild("Trees") else nil
	if trees ~= nil then
		table.insert(exclusions, trees)
	end
	params.FilterDescendantsInstances = exclusions

	local result = workspace:Raycast(around + Vector3.new(0, 2, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	return if result ~= nil then result.Position else Vector3.new(around.X, 0, around.Z)
end

function BagService.capacityOf(player: Player): number
	local value = player:GetAttribute("BagCapacity")
	if typeof(value) == "number" then
		return value
	end
	return Config.get("Bag", "SmallCapacity")
end

function BagService.usedBy(player: Player): number
	local total = 0
	for _, resourceType in CARRIED_TYPES do
		local value = player:GetAttribute(`Inv_{resourceType}`)
		total += if typeof(value) == "number" then value else 0
	end
	return total
end

function BagService.typeOf(player: Player): BagType
	local value = player:GetAttribute("BagType")
	return if typeof(value) == "string" then value :: BagType else defaultType()
end

local function assignBag(player: Player, bagType: BagType)
	local def = defFor(bagType)
	player:SetAttribute("BagType", bagType)
	player:SetAttribute("BagCapacity", Config.get("Bag", def.CapacitySetting))
	-- Sac rangé tant qu'il n'a pas été sorti : ForestService et le client lisent cet attribut
	-- pour savoir si le joueur peut ramasser (FR-019).
	player:SetAttribute("BagEquipped", false)
end

-- Commandes de dev : remplir jusqu'à la contenance, vider entièrement. Le remplissage passe par
-- InventoryService pour respecter le même plafond que le jeu, jamais en écrivant les compteurs
-- directement.
function BagService.fill(player: Player): number
	local room = BagService.capacityOf(player) - BagService.usedBy(player)
	if room <= 0 then
		return 0
	end
	if not InventoryService.addPersonal(player, "Scrap", room) then
		return 0
	end
	return room
end

-- Délègue à InventoryService.clearCarried plutôt que d'écrire les attributs directement
-- (005-depot-intelligent-sac, research R6) : une écriture directe laisserait des entrées
-- fantômes dans l'ordre d'arrivée, désormais tenu par InventoryService. Comportement observable
-- inchangé (Dev.EmptyBag).
function BagService.empty(player: Player)
	InventoryService.clearCarried(player)
end

-- Vide le sac (FR-020, FR-021 ; dépôt automatique : 005-depot-intelligent-sac FR-005 à FR-009).
-- Chaque unité tente d'abord un dépôt automatique au poste compatible (StationDepositService) ;
-- à défaut, elle redevient un objet du monde, ramassable et déplaçable comme n'importe quel
-- autre. Rien n'est retiré du sac tant que le sort de l'unité n'est pas déterminé — ni pour un
-- dépôt (research R3), ni pour une pose au sol (principe VI, si l'apparition échoue l'unité reste
-- dans le sac).
--
-- Renvoie (posés au sol, déposés automatiquement, forêt indisponible). Parcourt l'ordre d'arrivée
-- réel (InventoryService.orderOf), le plus récent d'abord (FR-004) — plus l'ancien ordre fixe
-- CARRIED_TYPES d'avant l'US2, qui ignorait quand chaque objet avait été ramassé.
function BagService.drop(player: Player): (number, number, boolean)
	local root = rootOf(player)
	if root == nil then
		return 0, 0, false
	end
	local items = InventoryService.orderOf(player) -- le plus récent en dernier
	local total = #items
	local grounded = 0
	local autoDeposited = 0
	local index = 0
	for i = total, 1, -1 do -- le plus récent d'abord
		local resourceType = items[i]
		index += 1
		local position = dropPosition(player, root, index, total)
		if StationDepositService.tryDeposit(player, resourceType, position) then
			autoDeposited += 1
			continue
		end
		if ForestService.spawnDrop(resourceType, position) == nil then
			return grounded, autoDeposited, true
		end
		InventoryService.depositResource(player, resourceType, 1)
		grounded += 1
	end
	return grounded, autoDeposited, false
end

-- Retire uniquement le dernier objet ramassé (US2, FR-001). Même embranchement poste-ou-sol et
-- même forme de retour que `drop`, sur une seule unité — le cercle de dépose est donc à un seul
-- élément (angle fixe, déterministe comme le reste de la formule).
function BagService.dropOne(player: Player): (number, number, boolean)
	local root = rootOf(player)
	if root == nil then
		return 0, 0, false
	end
	local resourceType = InventoryService.mostRecent(player)
	if resourceType == nil then
		return 0, 0, false
	end
	local position = dropPosition(player, root, 1, 1)
	if StationDepositService.tryDeposit(player, resourceType, position) then
		return 0, 1, false
	end
	if ForestService.spawnDrop(resourceType, position) == nil then
		return 0, 0, true
	end
	InventoryService.depositResource(player, resourceType, 1)
	return 1, 0, false
end

-- Construit le Tool du sac : l'asset (ou son remplaçant en primitives) fournit la pièce reprise
-- comme Handle. CanBeDropped = false : un joueur ne peut pas se retrouver sans contenance en
-- lâchant son sac, état qu'il ne pourrait plus réparer en jeu (research R2).
local function buildTool(bagType: BagType): Tool?
	local def = defFor(bagType)
	local model = VisualService.build(def.VisualId)
	if model == nil then
		log:error("Visuel %s introuvable : sac non équipable", def.VisualId)
		return nil
	end
	local handle = model.PrimaryPart
	if handle == nil then
		log:error("Visuel %s sans PrimaryPart : sac non équipable", def.VisualId)
		model:Destroy()
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = Strings.format(`Bag.{bagType}`)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Un asset en plusieurs pièces suit le Handle, soudé (le Handle a déjà quitté le modèle).
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.CanCollide = false
			child.Massless = true
			child.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = child
			weld.Parent = handle
		end
	end
	model:Destroy()
	return tool
end

-- Le Backpack est vidé et recréé à chaque apparition : le sac doit être redonné à chaque fois,
-- pas une seule fois à l'arrivée du joueur (research R2).
local function giveBag(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	-- Un personnage neuf n'a rien en main : l'état repart à faux à chaque apparition, et seuls
	-- les événements du Tool le feront repasser à vrai.
	player:SetAttribute("BagEquipped", false)
	local bagType = BagService.typeOf(player)
	local name = Strings.format(`Bag.{bagType}`)
	if backpack:FindFirstChild(name) ~= nil then
		return
	end
	local tool = buildTool(bagType)
	if tool then
		tool.Equipped:Connect(function()
			player:SetAttribute("BagEquipped", true)
		end)
		tool.Unequipped:Connect(function()
			player:SetAttribute("BagEquipped", false)
		end)
		tool.Parent = backpack
	end
end

-- Corps commun aux deux intentions de vidage (DropBag, DropOneItem, US2) : mêmes préconditions,
-- même traitement du résultat. Aucune des deux ne vise de cible : le pipeline saute ses étapes 7
-- à 9, donc le personnage vivant est vérifié ici. `dropFn` fait la seule différence entre « un
-- objet » et « tout le sac ».
local function handleDrop(player: Player, dropFn: (Player) -> (number, number, boolean)): Types.RejectCode?
	if rootOf(player) == nil then
		return "NoCharacter"
	end
	if player:GetAttribute("BagEquipped") ~= true then
		return "BagNotEquipped"
	end
	if BagService.usedBy(player) == 0 then
		return "BagEmpty"
	end
	local grounded, autoDeposited, forestUnavailable = dropFn(player)
	if forestUnavailable and grounded == 0 and autoDeposited == 0 then
		-- Rien n'a pu être posé ni déposé : la forêt qui accueille les objets lâchés est absente.
		-- Rien n'a quitté le sac, le joueur ne perd rien.
		log:error("Sac non vidé pour %s : aucun endroit où poser les objets", player.Name)
		return "TargetMissing"
	end
	-- Un dépôt automatique a déjà sa propre confirmation (GeneratorFueled, ScrapDeposited,
	-- ResourceDeposited) ; BagDropped ne compte que ce qui a réellement atterri au sol, et se tait
	-- s'il n'y a rien à confirmer (research R8).
	if grounded > 0 then
		NotifyService.send(player, "BagDropped", { amount = grounded })
	end
	return nil
end

function BagService.Init()
	SessionService.PlayerJoined:Connect(function(player: Player)
		assignBag(player, defaultType())
		player.CharacterAdded:Connect(function()
			giveBag(player)
		end)
		if player.Character ~= nil then
			giveBag(player)
		end
	end)

	-- Vider le sac au sol (FR-020) ou le déposer aux postes compatibles (FR-005 à FR-009).
	NetService.registerIntent("DropBag", {
		handler = function(player: Player): Types.RejectCode?
			return handleDrop(player, BagService.drop)
		end,
	})

	-- Pression brève (US2, FR-001) : ne retire que le dernier objet ramassé.
	NetService.registerIntent("DropOneItem", {
		handler = function(player: Player): Types.RejectCode?
			return handleDrop(player, BagService.dropOne)
		end,
	})

	log:info("Sacs prêts (contenance par défaut : %d)", Config.get("Bag", "SmallCapacity"))
end

return BagService
