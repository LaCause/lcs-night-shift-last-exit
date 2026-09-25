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

-- Repose le modèle entier à une position que le serveur a validée, puis le réancre.
local function detach(part: BasePart, position: Vector3)
	for _, child in part:GetChildren() do
		if child.Name == WELD_NAME then
			child:Destroy()
		end
	end
	local model = modelOf(part)
	if model ~= nil then
		model:PivotTo(CFrame.new(position - part.Position) * model:GetPivot())
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	else
		part.CFrame = CFrame.new(position)
		part.Anchored = true
	end
	part:SetAttribute("GrabbedBy", 0)
end

local function release(player: Player, position: Vector3?)
	local carry = carries[player]
	if carry == nil then
		return
	end
	carries[player] = nil
	local part = carry.part
	if part.Parent == nil then
		return
	end
	-- La pièce peut avoir été détruite avec la forêt : SetNetworkOwner échouerait alors.
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	detach(part, position or carry.lastValidPosition)
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
			release(player, if accepted then requested else carry.lastValidPosition)
			-- Glissé sur l'établi (009-craft-etabli) : si la recette choisie attend cet objet, il
			-- quitte le monde pour rejoindre la recette. Sinon, glissé sur le coin de stockage
			-- (010-coin-stockage) : il est rangé, figé, sur un emplacement libre. Si aucun des deux
			-- ne le prend (hors de portée, stock plein), il reste simplement posé là. Les zones de
			-- l'établi et du stockage sont disjointes : au plus un des deux peut le prendre.
			if not CraftService.tryPlaceCarried(player, carry.part) then
				StorageService.tryStoreCarried(player, carry.part)
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
