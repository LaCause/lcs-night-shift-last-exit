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

-- Ordre d'arrivée du sac (005-depot-intelligent-sac, research R1) : le dernier élément est le
-- plus récemment ajouté. État serveur pur, jamais répliqué — un Attribute Roblox ne peut pas
-- porter un tableau, et aucun client n'a besoin de le connaître (le HUD n'affiche qu'un total).
-- Seconde représentation de la même quantité que les compteurs Inv_*, jamais une source
-- indépendante : #order[player] == somme(Inv_*) de ce joueur, à tout moment (data-model.md).
local order: { [Player]: { ResourceType } } = {}

local function attributeKey(resourceType: ResourceType): string
	return `Inv_{resourceType}`
end

local function getNumber(instance: Instance, key: string): number
	local value = instance:GetAttribute(key)
	return if typeof(value) == "number" then value else 0
end

-- Toutes les ressources personnelles (indépendant de STOCK_TYPES, qui exclut Essence/Scrap), y
-- compris les objets fabriqués à l'établi (009-craft-etabli) qui occupent le sac comme le reste.
local ALL_RESOURCE_TYPES: { ResourceType } =
	{ "Essence", "SuspectSteak", "RoadBread", "Scrap", "HealKit", "FuelCanister" }

-- Ajoute `count` entrées de `resourceType` en fin d'ordre (les plus récentes).
local function pushOrder(player: Player, resourceType: ResourceType, count: number)
	if count <= 0 then
		return
	end
	local list = order[player]
	if list == nil then
		list = {}
		order[player] = list
	end
	for _ = 1, count do
		table.insert(list, resourceType)
	end
end

-- Retire jusqu'à `count` entrées de `resourceType`, les plus récentes de ce type en priorité.
-- Deux entrées du même type sont interchangeables (aucune identité au-delà du type), donc leur
-- ordre relatif entre elles n'a aucune importance.
local function removeFromOrder(player: Player, resourceType: ResourceType, count: number)
	if count <= 0 then
		return
	end
	local list = order[player]
	if list == nil then
		return
	end
	local remaining = count
	local index = #list
	while index >= 1 and remaining > 0 do
		if list[index] == resourceType then
			table.remove(list, index)
			remaining -= 1
		end
		index -= 1
	end
end

local function initPlayer(player: Player)
	for _, resourceType in ALL_RESOURCE_TYPES do
		player:SetAttribute(attributeKey(resourceType), 0)
	end
	order[player] = {}
end

local function personalTotal(player: Player): number
	local total = 0
	for _, resourceType in ALL_RESOURCE_TYPES do
		total += getNumber(player, attributeKey(resourceType))
	end
	return total
end

local function stockFolder(): Folder
	local folder = stock
	if folder == nil then
		error("InventoryService.Init n'a pas encore créé Stock", 2)
	end
	return folder
end

-- Contenance du sac porté (004-sac-collecte, research R1) : lue dans l'attribut BagCapacity écrit
-- par BagService, jamais en requérant BagService — celui-ci dépend déjà de ce module, ce qui
-- rendrait la dépendance circulaire (research R6, même procédé que NetService qui lit la phase
-- dans MatchState). Repli sur le réglage tant que l'attribut n'est pas écrit (fenêtre d'arrivée).
local function bagCapacity(player: Player): number
	local value = player:GetAttribute("BagCapacity")
	if typeof(value) == "number" then
		return value
	end
	return Config.get("Bag", "SmallCapacity")
end

-- Ajoute une ressource à l'inventaire personnel ; false si la contenance du sac serait dépassée
-- (aucun ajout partiel).
function InventoryService.addPersonal(player: Player, resourceType: ResourceType, amount: number): boolean
	local capacity = bagCapacity(player)
	if personalTotal(player) + amount > capacity then
		return false
	end
	local key = attributeKey(resourceType)
	player:SetAttribute(key, getNumber(player, key) + amount)
	pushOrder(player, resourceType, amount)
	return true
end

-- Vrai si `amount` unités de plus tiennent dans le sac (009-craft-etabli) : permet de rendre d'un
-- seul bloc les ingrédients posés sur l'établi sans jamais en perdre une partie faute de place.
function InventoryService.canAddPersonal(player: Player, amount: number): boolean
	return personalTotal(player) + amount <= bagCapacity(player)
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
			removeFromOrder(player, resourceType, amount)
			total += amount
		end
	end
	return total
end

-- Jumelle unitaire de depositToStock, pour un seul type (005-depot-intelligent-sac, research R3) :
-- utilisée par le dépôt automatique, qui ne prélève jamais plus d'une unité à la fois. La fonction
-- bulk ci-dessus n'est pas modifiée ; elle reste le chemin du dépôt manuel complet au comptoir.
function InventoryService.depositResourceToStock(player: Player, resourceType: ResourceType, maxAmount: number): number
	if table.find(STOCK_TYPES, resourceType) == nil then
		return 0
	end
	local folder = stockFolder()
	local key = attributeKey(resourceType)
	local carried = getNumber(player, key)
	local amount = math.min(carried, maxAmount)
	if amount > 0 then
		player:SetAttribute(key, carried - amount)
		folder:SetAttribute(resourceType, getNumber(folder, resourceType) + amount)
		removeFromOrder(player, resourceType, amount)
	end
	return amount
end

-- Prélève une ressource portée par le joueur (au plus `maxAmount`, ou tout si omis) et renvoie
-- la quantité réellement prélevée ; le reste demeure dans l'inventaire (FR-007). Généralisée par
-- 003-bus-evasion (research R4) pour servir à la fois GeneratorService (Essence) et BusService
-- (Scrap), sans dupliquer la logique de prélèvement.
function InventoryService.depositResource(player: Player, resourceType: ResourceType, maxAmount: number?): number
	local key = attributeKey(resourceType)
	local carried = getNumber(player, key)
	local amount = if maxAmount ~= nil then math.min(carried, maxAmount) else carried
	if amount > 0 then
		player:SetAttribute(key, carried - amount)
		removeFromOrder(player, resourceType, amount)
	end
	return amount
end

-- Vide entièrement ce que porte le joueur — compteurs et ordre d'arrivée en un seul appel
-- (005-depot-intelligent-sac, research R6). Remplace toute écriture directe d'attribut Inv_* :
-- BagService.empty (Dev.EmptyBag) l'utilise pour ne jamais laisser l'ordre diverger des
-- compteurs répliqués ; même effet que le reset d'élimination ou d'arrivée (initPlayer), exposé
-- ici pour cet appelant externe.
function InventoryService.clearCarried(player: Player)
	initPlayer(player)
end

-- Copie en lecture seule de l'ordre d'arrivée courant, le plus récent en dernier
-- (005-depot-intelligent-sac, research R1). {} si le sac est vide ou le joueur inconnu.
function InventoryService.orderOf(player: Player): { ResourceType }
	local list = order[player]
	if list == nil then
		return {}
	end
	return table.clone(list)
end

-- Type du dernier objet ajouté au sac, nil si le sac est vide.
function InventoryService.mostRecent(player: Player): ResourceType?
	local list = order[player]
	if list == nil or #list == 0 then
		return nil
	end
	return list[#list]
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

-- Miroir exact de hasStock/consumeStock ci-dessus, mais sur l'inventaire personnel plutôt que le
-- stock partagé (009-craft-etabli, research R3) : aucune vérification/déduction multi-ressources
-- atomique n'existait pour l'inventaire personnel avant cet incrément.
function InventoryService.hasPersonal(player: Player, requirements: { [string]: number }): boolean
	for resourceType, amount in requirements do
		if getNumber(player, attributeKey(resourceType :: ResourceType)) < amount then
			return false
		end
	end
	return true
end

-- À appeler seulement après que hasPersonal a confirmé la disponibilité (pas de vérification
-- redondante). Appelle removeFromOrder pour chaque ressource déduite, comme depositResource
-- déjà : maintient l'invariant #order[player] == somme(Inv_*) documenté en tête de ce module.
function InventoryService.consumePersonal(player: Player, requirements: { [string]: number })
	for resourceType, amount in requirements do
		local key = attributeKey(resourceType :: ResourceType)
		player:SetAttribute(key, getNumber(player, key) - amount)
		removeFromOrder(player, resourceType :: ResourceType, amount)
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
	-- L'ordre d'arrivée n'est pas un attribut : contrairement à Inv_*, il ne se nettoie pas seul
	-- au départ du joueur (005-depot-intelligent-sac, research R1) — sans ce nettoyage, la table
	-- fuirait une entrée par joueur ayant quitté la partie.
	SessionService.PlayerLeft:Connect(function(player: Player)
		order[player] = nil
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
