--!strict
-- Saisie et déplacement d'objets à la souris (004-sac-collecte, FR-008 à FR-014). Un déplacement
-- complet ne coûte que deux intentions (GrabItem, ReleaseItem) : entre les deux, le client produit
-- le suivi du pointeur et le serveur borne la distance à Bag.CarryRange, force le relâchement
-- au-delà et décide seul de la position finale (research R4). Le limiteur de cadence n'accorde
-- que 5 intentions par seconde : tout flux de position par frame est exclu par conception.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local CraftService = require(script.Parent.CraftService)
local ForestService = require(script.Parent.ForestService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local SessionService = require(script.Parent.SessionService)
local StorageService = require(script.Parent.StorageService)

type PlayerStatus = Types.PlayerStatus
type Carry = { part: BasePart, lastValidPosition: Vector3 }

local WELD_NAME = "CarryWeld"
-- Portée de la sonde qui cherche le sol sous un objet relâché (même valeur que BagService).
local GROUND_PROBE = 60

local log = Log.new("Carry")

local CarryService = { Name = "CarryService", Priority = 48 }

local carries: { [Player]: Carry } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function modelOf(part: BasePart): Model?
	local parent = part.Parent
	return if parent ~= nil and parent:IsA("Model") then parent :: Model else nil
end

local function maxRange(): number
	return Config.get("Bag", "CarryRange") + Config.get("Net", "DistanceTolerance")
end

-- Libère la pièce pour qu'elle puisse être simulée par le client : les autres pièces du modèle la
-- suivent, soudées, pour qu'un nœud en plusieurs primitives ne se disloque pas pendant un
-- déplacement.
local function attach(part: BasePart)
	local model = modelOf(part)
	if model ~= nil then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= part then
				local weld = Instance.new("WeldConstraint")
				weld.Name = WELD_NAME
				weld.Part0 = part
				weld.Part1 = descendant
				weld.Parent = part
				descendant.Anchored = false
			end
		end
	end
	part.Anchored = false
end

-- Fait retomber un objet relâché en l'air : l'objet est réancré, donc sans cette étape il resterait
-- suspendu où la souris l'a lâché. Cherche le premier support sous l'objet (sol, établi, étagère)
-- et renvoie la position de `part` qui pose le point le plus bas du modèle dessus. Sans support,
-- la position reçue est conservée. Déterministe et décidé côté serveur : aucune simulation physique.
local function landedPosition(part: BasePart, position: Vector3): Vector3
	local model = modelOf(part)
	local parts: { BasePart } = {}
	if model ~= nil then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	if #parts == 0 then
		parts = { part }
	end

	-- Extrémités verticales du modèle, mesurées par rapport à `part` (rotation prise en compte).
	local lowest = math.huge
	local highest = -math.huge
	for _, piece in parts do
		local cf = piece.CFrame
		local size = piece.Size
		local half = 0.5
			* (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			)
		lowest = math.min(lowest, cf.Position.Y - half - part.Position.Y)
		highest = math.max(highest, cf.Position.Y + half - part.Position.Y)
	end

	local exclusions: { Instance } = { model or part }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(exclusions, other.Character)
		end
	end
	-- Comme pour un objet lâché du sac (BagService) : ni les autres objets, ni les arbres ne servent
	-- de support, sans quoi les objets s'empileraient ou se poseraient sur une branche.
	local forest = workspace:FindFirstChild("Forest")
	if forest ~= nil then
		table.insert(exclusions, forest)
	end
	local world = workspace:FindFirstChild("World")
	local trees = if world ~= nil then world:FindFirstChild("Trees") else nil
	if trees ~= nil then
		table.insert(exclusions, trees)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.RespectCanCollide = true

	local origin = Vector3.new(position.X, position.Y + highest, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -GROUND_PROBE, 0), params)
	if result == nil then
		return position
	end
	return Vector3.new(position.X, result.Position.Y - lowest, position.Z)
end

-- Déplace le modèle entier (pièces ancrées) pour que `part` se trouve à `position`.
local function moveTo(part: BasePart, position: Vector3)
	local model = modelOf(part)
	if model ~= nil then
		model:PivotTo(CFrame.new(position - part.Position) * model:GetPivot())
	else
		part.CFrame = CFrame.new(position) * part.CFrame.Rotation
	end
end

-- Chute d'un objet relâché en l'air : mouvement uniformément accéléré (Bag.FallGravity) de sa
-- position de relâchement jusqu'au support trouvé. Pilotée par le serveur, qui garde seul la
-- position finale ; s'arrête si l'objet est repris, ramassé, rangé ou détruit pendant la chute.
local function fall(part: BasePart, target: Vector3)
	local start = part.Position
	local distance = start.Y - target.Y
	if distance <= 0.05 then
		moveTo(part, target)
		return
	end
	local gravity: number = Config.get("Bag", "FallGravity")
	local duration = math.sqrt(2 * distance / gravity)
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local grabbedBy = part:GetAttribute("GrabbedBy")
		if part.Parent == nil or part:GetAttribute("Available") ~= true or (grabbedBy ~= nil and grabbedBy ~= 0) then
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		if elapsed >= duration then
			moveTo(part, target)
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		moveTo(part, Vector3.new(start.X, start.Y - 0.5 * gravity * elapsed * elapsed, start.Z))
	end)
end

-- Repose le modèle entier à une position que le serveur a validée, le réancre, puis le laisse
-- retomber sur son support. Renvoie la position finale (là où l'objet se posera).
local function detach(part: BasePart, requested: Vector3): Vector3
	local landed = landedPosition(part, requested)
	for _, child in part:GetChildren() do
		if child.Name == WELD_NAME then
			child:Destroy()
		end
	end
	local model = modelOf(part)
	if model ~= nil then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	else
		part.Anchored = true
	end
	moveTo(part, requested)
	part:SetAttribute("GrabbedBy", 0)
	fall(part, landed)
	return landed
end

local function release(player: Player, position: Vector3?): Vector3?
	local carry = carries[player]
	if carry == nil then
		return nil
	end
	carries[player] = nil
	local part = carry.part
	if part.Parent == nil then
		return nil
	end
	-- La pièce peut avoir été détruite avec la forêt : SetNetworkOwner échouerait alors.
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	return detach(part, position or carry.lastValidPosition)
end

function CarryService.isCarried(part: BasePart): boolean
	local value = part:GetAttribute("GrabbedBy")
	return typeof(value) == "number" and value ~= 0
end

function CarryService.carrierOf(part: BasePart): Player?
	local value = part:GetAttribute("GrabbedBy")
	if typeof(value) ~= "number" or value == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(value)
end

function CarryService.releaseAll(player: Player)
	release(player, nil)
end

function CarryService.Init()
	NetService.registerIntent("GrabItem", {
		resolve = ForestService.findNode,
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			local part = ForestService.findNode(payload.target)
			if part == nil then
				return "TargetMissing"
			end
			if part:GetAttribute("Available") ~= true then
				return "NodeUnavailable"
			end
			local holder = CarryService.carrierOf(part)
			if holder ~= nil and holder ~= player then
				return "AlreadyCarried"
			end
			-- Objet rangé au stockage (010-coin-stockage, research R2) : hors de portée du coin, la
			-- saisie est refusée ; à portée elle est permise et n'exige aucun sac (FR-018). Sans
			-- crochet sur le nœud : nil, aucun changement pour un objet ordinaire.
			local blocked = ForestService.checkTake(player, part)
			if blocked ~= nil then
				return blocked
			end
			-- Un joueur ne tient qu'un objet à la fois : le précédent est reposé proprement.
			release(player, nil)
			carries[player] = { part = part, lastValidPosition = part.Position }
			part:SetAttribute("GrabbedBy", player.UserId)
			attach(part)
			pcall(function()
				part:SetNetworkOwner(player)
			end)
			-- La saisie est acquise : un objet rangé libère son emplacement et redevient un objet du
			-- monde ordinaire (no-op pour tout autre nœud).
			ForestService.releaseHooks(part)
			return nil
		end,
	})

	NetService.registerIntent("ReleaseItem", {
		resolve = ForestService.findNode,
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			local carry = carries[player]
			if carry == nil or carry.part ~= ForestService.findNode(payload.target) then
				return "NotCarrying"
			end
			-- La position reçue ne fait pas foi : hors de portée, c'est la dernière position vue
			-- dans la portée qui est appliquée (FR-012).
			local requested = Vector3.new(payload.x, payload.y, payload.z)
			local root = rootOf(player)
			local accepted = root ~= nil and (requested - root.Position).Magnitude <= maxRange()
			local landed = release(player, if accepted then requested else carry.lastValidPosition)
			-- Glissé sur l'établi (009-craft-etabli) : si la recette choisie attend cet objet, il
			-- quitte le monde pour rejoindre la recette. Sinon, glissé sur le coin de stockage
			-- (010-coin-stockage) : il est rangé, figé, sur un emplacement libre. Si aucun des deux
			-- ne le prend (hors de portée, stock plein), il reste simplement posé là. Les zones de
			-- l'établi et du stockage sont disjointes : au plus un des deux peut le prendre. La
			-- décision porte sur la position où l'objet se posera, pas sur son point de chute en
			-- cours : il peut encore être en l'air.
			local at = landed or carry.part.Position
			if not CraftService.tryPlaceCarried(player, carry.part, at) then
				StorageService.tryStoreCarried(player, carry.part, at)
			end
			return nil
		end,
	})

	-- Surveillance du bornage : tourne dans la boucle serveur, ne consomme aucune intention et
	-- suit au plus un objet par joueur (research R4).
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Config.get("Bag", "CarryCheckInterval") then
			return
		end
		elapsed = 0
		local limit = maxRange()
		for player, carry in carries do
			local root = rootOf(player)
			local part = carry.part
			if root == nil or part.Parent == nil then
				release(player, nil)
			elseif (part.Position - root.Position).Magnitude > limit then
				release(player, carry.lastValidPosition)
			else
				carry.lastValidPosition = part.Position
			end
		end
	end)

	SessionService.PlayerLeft:Connect(function(player: Player)
		release(player, nil)
	end)
	SessionService.StatusChanged:Connect(function(player: Player, status: PlayerStatus)
		if status == "Eliminated" then
			release(player, nil)
		end
	end)
	-- La forêt est régénérée à chaque partie : toutes les saisies tombent avec les anciens nœuds.
	MatchService.MatchStarting:Connect(function()
		for player in carries do
			release(player, nil)
		end
	end)

	log:info("Manipulation d'objets prête (portée %d studs)", Config.get("Bag", "CarryRange"))
end

return CarryService
