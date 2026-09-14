--!strict
-- Inventaire personnel et stock partagé (002-premier-increment-jouable, FR-004, FR-005).
-- Inventaire personnel : attributs Inv_* sur chaque Player. Stock partagé : attributs sur
-- ReplicatedStorage.Stock (jamais l'essence, qui va uniquement au générateur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local SessionService = require(script.Parent.SessionService)
local WorldService = require(script.Parent.WorldService)

local COUNTER_ID = "Counter"

type ResourceType = Types.ResourceType
type PlayerStatus = Types.PlayerStatus

-- Ressources qui transitent par le stock partagé (l'essence n'y entre jamais, FR-006 à FR-009).
local STOCK_TYPES: { ResourceType } = { "SuspectSteak", "RoadBread" }

local log = Log.new("Inventory")

local InventoryService = { Name = "InventoryService", Priority = 45 }

local stock: Folder? = nil

local function attributeKey(resourceType: ResourceType): string
	return `Inv_{resourceType}`
end

local function getNumber(instance: Instance, key: string): number
	local value = instance:GetAttribute(key)
	return if typeof(value) == "number" then value else 0
end

local function initPlayer(player: Player)
	player:SetAttribute(attributeKey("Essence"), 0)
	player:SetAttribute(attributeKey("SuspectSteak"), 0)
	player:SetAttribute(attributeKey("RoadBread"), 0)
end

local function personalTotal(player: Player): number
	return getNumber(player, attributeKey("Essence"))
		+ getNumber(player, attributeKey("SuspectSteak"))
		+ getNumber(player, attributeKey("RoadBread"))
end

local function stockFolder(): Folder
	local folder = stock
	if folder == nil then
		error("InventoryService.Init n'a pas encore créé Stock", 2)
	end
	return folder
end

-- Ajoute une ressource à l'inventaire personnel ; false si Forest.InventoryCapacity serait
-- dépassée (aucun ajout partiel).
function InventoryService.addPersonal(player: Player, resourceType: ResourceType, amount: number): boolean
	local capacity: number = Config.get("Forest", "InventoryCapacity")
	if personalTotal(player) + amount > capacity then
		return false
	end
	local key = attributeKey(resourceType)
	player:SetAttribute(key, getNumber(player, key) + amount)
	return true
end

-- Verse SuspectSteak/RoadBread de l'inventaire du joueur vers le stock partagé (jamais
-- l'essence). Toujours accepté, sans effet si l'inventaire de ces types est déjà vide.
-- Retourne le total versé (toutes ressources confondues), pour le retour son/visuel de l'appelant.
function InventoryService.depositToStock(player: Player): number
	local folder = stockFolder()
	local total = 0
	for _, resourceType in STOCK_TYPES do
		local key = attributeKey(resourceType)
		local amount = getNumber(player, key)
		if amount > 0 then
			player:SetAttribute(key, 0)
			folder:SetAttribute(resourceType, getNumber(folder, resourceType) + amount)
			total += amount
		end
	end
	return total
end

-- Prélève l'essence portée par le joueur (au plus `maxAmount`, ou tout si omis) et renvoie la
-- quantité réellement prélevée ; le reste demeure dans l'inventaire (FR-007). Consommée par
-- GeneratorService avant d'appeler GeneratorService.deposit.
function InventoryService.depositEssence(player: Player, maxAmount: number?): number
	local key = attributeKey("Essence")
	local carried = getNumber(player, key)
	local amount = if maxAmount ~= nil then math.min(carried, maxAmount) else carried
	if amount > 0 then
		player:SetAttribute(key, carried - amount)
	end
	return amount
end

function InventoryService.hasStock(requirements: { [string]: number }): boolean
	local folder = stockFolder()
	for resourceType, amount in requirements do
		if getNumber(folder, resourceType) < amount then
			return false
		end
	end
	return true
end

-- À appeler seulement après que hasStock a confirmé la disponibilité (pas de vérification
-- redondante).
function InventoryService.consumeStock(requirements: { [string]: number })
	local folder = stockFolder()
	for resourceType, amount in requirements do
		folder:SetAttribute(resourceType, getNumber(folder, resourceType) - amount)
	end
end

local function resetAll()
	for _, player in Players:GetPlayers() do
		initPlayer(player)
	end
	local folder = stockFolder()
	for _, resourceType in STOCK_TYPES do
		folder:SetAttribute(resourceType, 0)
	end
end

local function buildCounterPrompt()
	local found = WorldService.refPoint(COUNTER_ID)
	if found == nil then
		error(`Point de référence {COUNTER_ID} introuvable : dépôt au stock désactivé`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = Strings.format("Counter.DepositAction")
	prompt.ObjectText = Strings.format("Counter.DepositObject")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Forest", "HarvestRange")
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Intent", "DepositResources")
	prompt:SetAttribute("Target", COUNTER_ID)
	prompt.Parent = found
end

function InventoryService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Stock"
	for _, resourceType in STOCK_TYPES do
		folder:SetAttribute(resourceType, 0)
	end
	folder.Parent = ReplicatedStorage
	stock = folder

	buildCounterPrompt()

	MatchService.MatchStarting:Connect(resetAll)
	SessionService.PlayerJoined:Connect(initPlayer)
	SessionService.StatusChanged:Connect(function(player: Player, status: PlayerStatus)
		if status == "Eliminated" then
			-- Ressources non déposées perdues à l'élimination (FR-005, edge case de la spec).
			initPlayer(player)
		end
	end)

	NetService.registerIntent("DepositResources", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= COUNTER_ID then
				return "TargetMissing"
			end
			local deposited = InventoryService.depositToStock(player)
			if deposited > 0 then
				-- Retour son/visuel léger côté client (SfxController) : pas d'effet de jeu.
				NotifyService.send(player, "ResourceDeposited", { amount = deposited })
			end
			return nil
		end,
	})

	log:info("Inventaire et stock partagé prêts")
end

return InventoryService
