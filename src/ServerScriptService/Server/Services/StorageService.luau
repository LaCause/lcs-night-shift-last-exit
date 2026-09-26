--!strict
-- Coin de stockage commun du restaurant (010-coin-stockage, contracts/server-api.md). Un nombre
-- fixe d'emplacements au sol, où l'on range un objet — soit en le lâchant près du coin avec le sac
-- (StationDepositService → tryStoreFromBag), soit en glissant-déposant un objet du monde dessus
-- (CarryService → tryStoreCarried). Un objet rangé est un nœud de forêt « lâché », simplement figé
-- (research R1) : on peut donc le viser, le ramasser (F) ou le saisir à la souris comme n'importe
-- quel objet, à une condition de portée en plus, portée par des crochets que ce service pose sur
-- le nœud (ForestService.attachHooks, research R2).
--
-- Aucune intention réseau : ce service ne répond qu'à des appels serveur (principe III). Tout est
-- décidé ici — portée, emplacement libre, libération — et le client ne fait que viser et envoyer
-- des gestes déjà existants. Aucun tirage (principe V) : l'emplacement attribué est toujours le
-- plus bas index libre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ForestService = require(script.Parent.ForestService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

type ResourceType = Types.ResourceType
type Slot = { part: BasePart, resourceType: ResourceType }

local STORAGE_ID = "Storage"
local WORKBENCH_ID = "Workbench"

-- Côté de la zone marquée au sol dans Assets/Catalog.luau (StorageZoneFloor) : constante
-- géométrique du décor, pas un réglage d'équilibrage — la grille doit y tenir.
local ZONE_SIZE = 8
-- Marge verticale entre le joueur et un nœud posé au sol, retranchée de la portée que tolère le
-- pipeline réseau pour une reprise (research R7).
local VERTICAL_MARGIN = 1

local log = Log.new("Storage")

local StorageService = { Name = "StorageService", Priority = 54 }

local slots: { [number]: Slot? } = {}
local refPart: BasePart? = nil
local state: Folder? = nil
local indicatorLabel: TextLabel? = nil

-- Dernier message « stockage plein » envoyé, par joueur (cadence : Storage.FullNoticeCooldown).
local lastFullNotice: { [Player]: number } = {}

local function capacity(): number
	return Config.get("Storage", "Capacity")
end

-- Colonnes réellement utilisées : jamais plus que d'emplacements, sinon la grille ne serait pas
-- centrée sur le point de référence.
local function columnCount(): number
	local columns: number = Config.get("Storage", "Columns")
	return math.max(1, math.min(columns, capacity()))
end

local function rowCount(): number
	return math.ceil(capacity() / columnCount())
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Personnage vivant du joueur : le stock ne se sert ni d'un mort ni d'un absent.
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

-- Distance mesurée à l'horizontale depuis le point de référence : ranger et reprendre partagent la
-- même règle et le même réglage (FR-016), sans que la hauteur du point de référence (au sol) ne
-- pèse sur la distance d'un joueur debout.
local function withinRange(position: Vector3): boolean
	local center = refPart
	if center == nil then
		return false
	end
	local range: number = Config.get("Storage", "InteractRange")
	return flatDistance(position, center.Position) <= range
end

-- Position monde de l'emplacement `index` : grille centrée sur le point de référence, cellules de
-- Storage.SlotSpacing studs, hauteur de pose = celle du point de référence (data-model.md).
local function slotPosition(center: Vector3, index: number): Vector3
	local columns = columnCount()
	local rows = rowCount()
	local spacing: number = Config.get("Storage", "SlotSpacing")
	local column = (index - 1) % columns
	local row = (index - 1) // columns
	return Vector3.new(
		center.X + (column - (columns - 1) / 2) * spacing,
		center.Y,
		center.Z + (row - (rows - 1) / 2) * spacing
	)
end

-- Plus bas index libre (principe V : même suite d'actions, mêmes emplacements) ; nil si plein.
local function lowestFreeIndex(): number?
	for index = 1, capacity() do
		if slots[index] == nil then
			return index
		end
	end
	return nil
end

local function occupiedCount(): number
	local total = 0
	for _ in slots do
		total += 1
	end
	return total
end

-- Publie le remplissage sur ReplicatedStorage.StorageState, même patron que GeneratorState.
local function publish()
	local folder = state
	if folder == nil then
		return
	end
	local occupied = occupiedCount()
	folder:SetAttribute("Count", occupied)
	folder:SetAttribute("Capacity", capacity())

	-- L'indicateur affiche exactement ce que publie l'état : aucun client ne le recalcule.
	local label = indicatorLabel
	if label ~= nil then
		label.Text = Strings.format("Storage.Fill", { count = occupied, capacity = capacity() })
	end
end

-- Rend à un nœud repris son état d'objet ordinaire : plus marqué comme rangé, de nouveau solide.
local function thaw(part: BasePart)
	part:SetAttribute("Stored", nil)
	part:SetAttribute("StoredSlot", nil)
	local model = part.Parent
	if model ~= nil and model:IsA("Model") then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = true
			end
		end
	end
end

-- Fait apparaître un objet figé sur le plus bas emplacement libre et renvoie son index (nil si
-- plein, ou si l'objet n'a pas pu apparaître — rien n'a alors changé). Section sans point
-- d'attente : le choix de l'emplacement et son enregistrement ne peuvent pas être interrompus par
-- une autre action (FR-011, research R9).
local function placeStored(resourceType: ResourceType): number?
	local center = refPart
	if center == nil then
		return nil
	end
	local index = lowestFreeIndex()
	if index == nil then
		return nil
	end
	local id = ForestService.spawnDrop(resourceType, slotPosition(center.Position, index))
	if id == nil then
		return nil
	end
	local part = ForestService.findNode(id)
	if part == nil then
		return nil
	end

	-- Figé : ancré, sans collision — il ne bouge pas, ne bloque personne et ne réagit pas aux
	-- joueurs qui passent (FR-006).
	local model = part.Parent
	if model ~= nil and model:IsA("Model") then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
	end
	part:SetAttribute("Stored", true)
	part:SetAttribute("StoredSlot", index)

	local hooks: ForestService.NodeHooks = {
		canTake = function(player: Player): Types.RejectCode?
			local root = rootOf(player)
			if root == nil then
				return "NoCharacter"
			end
			if not withinRange(root.Position) then
				return "TooFar"
			end
			return nil
		end,
		onTaken = function()
			local slot = slots[index]
			if slot ~= nil and slot.part == part then
				slots[index] = nil
			end
			thaw(part)
			publish()
		end,
	}
	ForestService.attachHooks(part, hooks)

	slots[index] = { part = part, resourceType = resourceType }
	publish()
	return index
end

-- Défait un rangement qui vient d'être fait mais ne peut pas être mené à terme : libère
-- l'emplacement (crochets) puis retire le nœud du monde. Garantit qu'un échec ne laisse ni objet
-- fantôme ni emplacement bloqué (principe VI).
local function discardStored(index: number)
	local slot = slots[index]
	if slot == nil then
		return
	end
	ForestService.releaseHooks(slot.part)
	ForestService.consumeNode(slot.part)
end

-- Prévient un joueur que le stock est plein, au plus une fois toutes les
-- Storage.FullNoticeCooldown secondes : un appui long avec un sac plein tente de ranger chaque
-- objet et répéterait sinon le message à chacun (research R8).
local function notifyFull(player: Player)
	local now = os.clock()
	local cooldown: number = Config.get("Storage", "FullNoticeCooldown")
	local last = lastFullNotice[player]
	if last ~= nil and now - last < cooldown then
		return
	end
	lastFullNotice[player] = now
	NotifyService.send(player, "StorageFull", { capacity = capacity() })
end

-- Indicateur « Stockage n/N » (FR-012) : un BillboardGui créé par le serveur sur le point de
-- référence, donc répliqué à tous sans aucun code client (research R8). Couleurs reprises de la
-- palette de l'interface (UiKit, module client que le serveur ne requiert pas).
local function buildIndicator(center: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StorageIndicator"
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = Config.get("Storage", "IndicatorDistance")
	gui.Parent = center

	local label = Instance.new("TextLabel")
	label.Name = "Fill"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(70, 235, 255)
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	indicatorLabel = label
end

-- Contrôles de démarrage (principe VI) : journalisés, jamais bloquants pour les autres systèmes.
local function validateSettings(center: BasePart)
	local range: number = Config.get("Storage", "InteractRange")

	-- Les zones de l'établi et du stockage ne doivent pas se chevaucher : sans cela, un même objet
	-- lâché pourrait avoir deux destinations (research R4).
	local bench = WorldService.refPoint(WORKBENCH_ID)
	if bench ~= nil then
		local craftRange: number = Config.get("Craft", "InteractRange")
		local distance = flatDistance(bench.Position, center.Position)
		if distance < range + craftRange then
			log:error(
				"Zones du stockage et de l'établi qui se chevauchent : %.1f studs d'écart pour des portées de %.1f et %.1f",
				distance,
				range,
				craftRange
			)
		end
	end

	-- Le pipeline réseau borne déjà la reprise à Forest.HarvestRange + Net.DistanceTolerance depuis
	-- le nœud : un joueur à portée du coin doit l'être aussi du nœud le plus éloigné (research R7).
	local columns = columnCount()
	local rows = rowCount()
	local spacing: number = Config.get("Storage", "SlotSpacing")
	local halfWidth = (columns - 1) / 2 * spacing
	local halfDepth = (rows - 1) / 2 * spacing
	local gridRadius = math.sqrt(halfWidth * halfWidth + halfDepth * halfDepth)
	local harvestRange: number = Config.get("Forest", "HarvestRange")
	local tolerance: number = Config.get("Net", "DistanceTolerance")
	if range + gridRadius > harvestRange + tolerance - VERTICAL_MARGIN then
		log:warn(
			"Storage.InteractRange (%.1f) + rayon de la grille (%.1f) dépasse ce que le pipeline tolère pour une reprise (%.1f) : certaines reprises seraient refusées à tort",
			range,
			gridRadius,
			harvestRange + tolerance - VERTICAL_MARGIN
		)
	end

	-- La grille doit tenir dans la zone marquée au sol du décor.
	if columns * spacing > ZONE_SIZE or rows * spacing > ZONE_SIZE then
		log:warn(
			"La grille du stockage (%d colonnes × %d rangées, pas de %.1f) sort de la zone marquée (%d studs de côté)",
			columns,
			rows,
			spacing,
			ZONE_SIZE
		)
	end
end

-- Range 1 unité du sac du joueur (lâcher avec la touche G près du coin, research R5). Renvoie true
-- si l'objet a quitté le sac pour un emplacement. Renvoie false SANS avoir touché le sac si le
-- joueur est hors de portée, si le stock est plein (le joueur en est prévenu) ou si l'objet n'a pas
-- pu apparaître : l'appelant garde alors le comportement habituel du lâcher (poste compatible,
-- sinon sol). Le nœud apparaît AVANT tout prélèvement (comme BagService.drop) : un échec ne perd
-- rien (principe VI).
function StorageService.tryStoreFromBag(player: Player, resourceType: ResourceType): boolean
	local root = rootOf(player)
	if root == nil or not withinRange(root.Position) then
		return false
	end
	if lowestFreeIndex() == nil then
		notifyFull(player)
		return false
	end
	local index = placeStored(resourceType)
	if index == nil then
		return false
	end
	if InventoryService.depositResource(player, resourceType, 1) <= 0 then
		-- Le sac ne contenait pas l'unité (état incohérent) : on défait plutôt que de dupliquer.
		discardStored(index)
		return false
	end
	-- Un dépôt automatique a sa propre confirmation sonore (voir BagService.handleDrop).
	NotifyService.send(player, "ResourceDeposited", { amount = 1 })
	return true
end

-- Range un objet du monde relâché au-dessus du coin (glisser-déposer, research R6). La portée se
-- mesure depuis l'objet lui-même (« là où il est relâché ») : `at` est la position où il se posera,
-- l'objet pouvant encore tomber. Renvoie true si l'objet a été retiré du
-- monde et recréé figé sur un emplacement ; false sans effet sinon (hors de portée, objet déjà pris,
-- ou stock plein : le joueur en est prévenu et l'objet reste où il a été relâché).
--
-- Ordre sûr (principe VI) : on crée d'ABORD l'objet figé, puis on consomme l'objet du monde ; si ce
-- retrait échoue (déjà pris par quelqu'un d'autre), on défait le nœud fraîchement créé. Dans l'ordre
-- inverse, un échec d'apparition perdrait l'objet. Un nœud naturel de forêt est traité comme s'il
-- avait été récolté : il réapparaît selon les règles habituelles (spec, cas limites).
function StorageService.tryStoreCarried(player: Player, part: BasePart, at: Vector3?): boolean
	local resourceType = part:GetAttribute("ResourceType")
	if typeof(resourceType) ~= "string" or part.Parent == nil then
		return false
	end
	if not withinRange(at or part.Position) then
		return false
	end
	if lowestFreeIndex() == nil then
		notifyFull(player)
		return false
	end
	local index = placeStored(resourceType :: ResourceType)
	if index == nil then
		return false
	end
	if ForestService.consumeNode(part) == nil then
		discardStored(index)
		return false
	end
	NotifyService.send(player, "ResourceDeposited", { amount = 1 })
	return true
end

function StorageService.Init()
	local center = WorldService.refPoint(STORAGE_ID)
	if center == nil then
		error(`Point de référence {STORAGE_ID} introuvable : stockage désactivé`)
	end
	refPart = center

	local folder = Instance.new("Folder")
	folder.Name = "StorageState"
	folder.Parent = ReplicatedStorage
	state = folder
	buildIndicator(center)
	publish()

	Players.PlayerRemoving:Connect(function(player: Player)
		lastFullNotice[player] = nil
	end)

	-- La forêt est détruite puis régénérée à chaque nouvelle partie (ForestService) : les objets
	-- figés disparaissent avec elle, il ne reste qu'à remettre les emplacements à zéro (FR-013).
	MatchService.MatchStarting:Connect(function()
		slots = {}
		publish()
	end)

	validateSettings(center)
	log:info("Stockage prêt (%d emplacements)", capacity())
end

return StorageService
