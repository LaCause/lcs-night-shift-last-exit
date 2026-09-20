--!strict
-- Lecture côté client de l'état de gameplay répliqué (002-premier-increment-jouable).
-- Le client ne recalcule rien : il lit les attributs écrits par InventoryService (et, au fil
-- des user stories suivantes, GeneratorService, OrderService, HealthService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(script.Parent.Parent.Util.Log)
local Recipes = require(script.Parent.Parent.Kitchen.Recipes)
local Signal = require(script.Parent.Parent.Util.Signal)

export type State = {
	-- Inventaire personnel (InventoryService).
	essence: number,
	suspectSteak: number,
	roadBread: number,
	scrap: number,
	-- Stock partagé du restaurant (InventoryService, ReplicatedStorage.Stock).
	stockSuspectSteak: number,
	stockRoadBread: number,
	-- Générateur (GeneratorService, ReplicatedStorage.GeneratorState).
	fuel: number,
	fuelCapacity: number,
	safeZoneActive: boolean,
	-- Commande de la nuit (OrderService, ReplicatedStorage.OrderState).
	orderRecipeId: string,
	orderStatus: string,
	-- Santé (HealthService, attributs sur Player).
	health: number,
	maxHealth: number,
	-- Bus (BusService, ReplicatedStorage.BusState, 003-bus-evasion).
	busDeposited: number,
	busRequired: number,
	busRepaired: boolean,
	-- Sac de portage (BagService, attributs sur Player, 004-sac-collecte). `bagUsed` est la somme
	-- des compteurs ci-dessus : jamais une valeur stockée à part, pour qu'aucune divergence entre
	-- le total et le détail ne soit possible.
	bagType: string,
	bagCapacity: number,
	bagUsed: number,
	-- Sac en main ou rangé : conditionne le ramassage et le vidage au sol (FR-019, FR-020).
	bagEquipped: boolean,
	-- Monnaie persistante (CurrencyService, attribut sur Player, 006-monnaie-jetons-fidelite).
	currency: number,
}

local WAIT_TIMEOUT = 30

local log = Log.new("GameplayStateClient")

local player = Players.LocalPlayer
local stockFolder: Instance? = nil
local generatorFolder: Instance? = nil
local orderFolder: Instance? = nil
local busFolder: Instance? = nil

local recipeById: { [string]: Recipes.Recipe } = {}
for _, recipe in Recipes do
	recipeById[recipe.Id] = recipe
end

local GameplayStateClient = {
	Changed = Signal.new("GameplayStateClient.Changed") :: Signal.Signal<()>,
}

local function readAttr(instance: Instance?, name: string, default: any): any
	if instance == nil then
		return default
	end
	local value = instance:GetAttribute(name)
	if value == nil or typeof(value) ~= typeof(default) then
		return default
	end
	return value
end

function GameplayStateClient.get(): State
	local essence: number = readAttr(player, "Inv_Essence", 0)
	local suspectSteak: number = readAttr(player, "Inv_SuspectSteak", 0)
	local roadBread: number = readAttr(player, "Inv_RoadBread", 0)
	local scrap: number = readAttr(player, "Inv_Scrap", 0)
	return {
		essence = essence,
		suspectSteak = suspectSteak,
		roadBread = roadBread,
		scrap = scrap,
		bagType = readAttr(player, "BagType", ""),
		bagCapacity = readAttr(player, "BagCapacity", 0),
		bagUsed = essence + suspectSteak + roadBread + scrap,
		bagEquipped = readAttr(player, "BagEquipped", false),
		stockSuspectSteak = readAttr(stockFolder, "SuspectSteak", 0),
		stockRoadBread = readAttr(stockFolder, "RoadBread", 0),
		fuel = readAttr(generatorFolder, "Fuel", 0),
		fuelCapacity = readAttr(generatorFolder, "Capacity", 0),
		safeZoneActive = readAttr(generatorFolder, "SafeZoneActive", false),
		orderRecipeId = readAttr(orderFolder, "RecipeId", ""),
		orderStatus = readAttr(orderFolder, "Status", ""),
		health = readAttr(player, "Health", 0),
		maxHealth = readAttr(player, "MaxHealth", 0),
		busDeposited = readAttr(busFolder, "Deposited", 0),
		busRequired = readAttr(busFolder, "Required", 0),
		busRepaired = readAttr(busFolder, "Repaired", false),
		currency = readAttr(player, "Currency", 0),
	}
end

-- Résout la recette active via la table statique partagée (nil hors des nuits).
function GameplayStateClient.getOrderRecipe(): Recipes.Recipe?
	local id = readAttr(orderFolder, "RecipeId", "")
	if id == "" then
		return nil
	end
	return recipeById[id]
end

-- Une seule connexion pour tout le client, établie au premier chargement du module.
task.spawn(function()
	if player then
		player.AttributeChanged:Connect(function()
			GameplayStateClient.Changed:Fire()
		end)
	end
	local found = ReplicatedStorage:WaitForChild("Stock", WAIT_TIMEOUT)
	if found == nil then
		log:error("ReplicatedStorage.Stock introuvable après %d s", WAIT_TIMEOUT)
		return
	end
	stockFolder = found
	found.AttributeChanged:Connect(function()
		GameplayStateClient.Changed:Fire()
	end)

	local generatorState = ReplicatedStorage:WaitForChild("GeneratorState", WAIT_TIMEOUT)
	if generatorState == nil then
		log:error("ReplicatedStorage.GeneratorState introuvable après %d s", WAIT_TIMEOUT)
	else
		generatorFolder = generatorState
		generatorState.AttributeChanged:Connect(function()
			GameplayStateClient.Changed:Fire()
		end)
	end

	local orderState = ReplicatedStorage:WaitForChild("OrderState", WAIT_TIMEOUT)
	if orderState == nil then
		log:error("ReplicatedStorage.OrderState introuvable après %d s", WAIT_TIMEOUT)
	else
		orderFolder = orderState
		orderState.AttributeChanged:Connect(function()
			GameplayStateClient.Changed:Fire()
		end)
	end

	local busState = ReplicatedStorage:WaitForChild("BusState", WAIT_TIMEOUT)
	if busState == nil then
		log:error("ReplicatedStorage.BusState introuvable après %d s", WAIT_TIMEOUT)
	else
		busFolder = busState
		busState.AttributeChanged:Connect(function()
			GameplayStateClient.Changed:Fire()
		end)
	end

	GameplayStateClient.Changed:Fire()
end)

return GameplayStateClient
