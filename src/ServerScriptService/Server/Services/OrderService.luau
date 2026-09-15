--!strict
-- Commande de la nuit (002-premier-increment-jouable, FR-011 à FR-015). Une commande par nuit,
-- générée depuis Shared/Kitchen/Recipes.luau avec MatchService.rng("order") (research R7),
-- préparée au plan de travail puis livrée à la fenêtre du drive-thru. Son échec (research R9)
-- est signalé par OrderFailed, sans que ce service connaisse EnemyService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Recipes = require(Shared.Kitchen.Recipes)
local Signal = require(Shared.Util.Signal)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

type Phase = Types.Phase
type OrderStatus = Types.OrderStatus

local WORKTOP_ID = "Worktop"
local WINDOW_ID = "DriveThruWindow"

local log = Log.new("Order")

local recipeById: { [string]: Recipes.Recipe } = {}
for _, recipe in Recipes do
	recipeById[recipe.Id] = recipe
end

local OrderService = {
	Name = "OrderService",
	Priority = 65,
	-- Déclenché quand une nuit se termine sans livraison réussie (research R9).
	OrderFailed = Signal.new("OrderService.OrderFailed") :: Signal.Signal<string>,
}

local state: Folder? = nil
local currentRecipeId = ""
local currentStatus: OrderStatus = ""
-- Incrémenté à chaque nouvelle commande/remise à zéro : garde le minuteur de cuisson (task.delay)
-- d'une commande périmée de ne jamais affecter la commande suivante (même esprit que le jeton de
-- MatchService pour ses délais de phase).
local orderToken = 0

local function stateFolder(): Folder
	local folder = state
	if folder == nil then
		error("OrderService.Init n'a pas encore créé OrderState", 2)
	end
	return folder
end

local function publish()
	local folder = stateFolder()
	folder:SetAttribute("RecipeId", currentRecipeId)
	folder:SetAttribute("Status", currentStatus)
end

local function startNewOrder()
	orderToken += 1
	local recipe = Recipes[MatchService.rng("order"):NextInteger(1, #Recipes)]
	currentRecipeId = recipe.Id
	currentStatus = "Pending"
	publish()
	NotifyService.broadcast("OrderStarted", { recipe = Strings.format(recipe.NameKey) })
	log:info("Nouvelle commande : %s", recipe.Id)
end

local function clearOrder()
	orderToken += 1
	currentRecipeId = ""
	currentStatus = ""
	publish()
end

function OrderService.getStatus(): (string, OrderStatus)
	return currentRecipeId, currentStatus
end

-- Commande de dev (Dev.ForceOrderResult) : force le résultat sans attendre la nuit réelle.
-- Sans effet si aucune commande n'est active.
function OrderService.forceResult(result: "Delivered" | "Failed"): boolean
	if currentStatus == "" or currentStatus == "Delivered" or currentStatus == "Failed" then
		return false
	end
	currentStatus = result
	publish()
	local recipe = recipeById[currentRecipeId]
	local recipeName = if recipe then Strings.format(recipe.NameKey) else currentRecipeId
	if result == "Delivered" then
		NotifyService.broadcast("OrderDelivered", { recipe = recipeName })
	else
		NotifyService.broadcast("OrderFailed", { recipe = recipeName })
		OrderService.OrderFailed:Fire(currentRecipeId)
	end
	return true
end

local function buildPrompt(refPointId: string, intent: string, actionKey: string, objectKey: string, range: number)
	local found = WorldService.refPoint(refPointId)
	if found == nil then
		error(`Point de référence {refPointId} introuvable : {intent} désactivée`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = `{intent}Prompt`
	prompt.ActionText = Strings.format(actionKey)
	prompt.ObjectText = Strings.format(objectKey)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = range
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Intent", intent)
	prompt:SetAttribute("Target", refPointId)
	prompt.Parent = found
end

function OrderService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "OrderState"
	folder:SetAttribute("RecipeId", "")
	folder:SetAttribute("Status", "")
	folder.Parent = ReplicatedStorage
	state = folder

	buildPrompt(
		WORKTOP_ID,
		"PrepareOrder",
		"Kitchen.PrepareAction",
		"Kitchen.PrepareObject",
		Config.get("Kitchen", "PrepareRange")
	)
	buildPrompt(
		WINDOW_ID,
		"DeliverOrder",
		"Kitchen.DeliverAction",
		"Kitchen.DeliverObject",
		Config.get("Kitchen", "DeliverRange")
	)

	MatchService.PhaseStarted:Connect(function(phase: Phase, _night: number)
		if phase == "Night" then
			startNewOrder()
		else
			clearOrder()
		end
	end)

	MatchService.PhaseEnded:Connect(function(phase: Phase, _night: number)
		if phase == "Night" and currentStatus ~= "" and currentStatus ~= "Delivered" then
			currentStatus = "Failed"
			publish()
			local recipe = recipeById[currentRecipeId]
			NotifyService.broadcast("OrderFailed", {
				recipe = if recipe then Strings.format(recipe.NameKey) else currentRecipeId,
			})
			log:info("Commande en échec : %s", currentRecipeId)
			OrderService.OrderFailed:Fire(currentRecipeId)
		end
	end)

	NetService.registerIntent("PrepareOrder", {
		handler = function(_player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WORKTOP_ID then
				return "TargetMissing"
			end
			if currentStatus == "Preparing" or currentStatus == "Prepared" then
				return nil -- déjà en cuisson ou déjà prête : rien à faire (comme un générateur plein)
			end
			if currentStatus ~= "Pending" then
				return "OrderClosed"
			end
			local recipe = recipeById[currentRecipeId]
			if recipe == nil then
				return "OrderClosed"
			end
			if not InventoryService.hasStock(recipe.Ingredients) then
				return "MissingIngredients"
			end
			InventoryService.consumeStock(recipe.Ingredients)
			currentStatus = "Preparing"
			publish()
			local recipeName = Strings.format(recipe.NameKey)
			NotifyService.broadcast("OrderPreparing", { recipe = recipeName })
			local token = orderToken
			local duration: number = Config.get("Kitchen", "PrepareDuration", MatchService.isTestProfile())
			task.delay(duration, function()
				if orderToken == token and currentStatus == "Preparing" then
					currentStatus = "Prepared"
					publish()
					NotifyService.broadcast("OrderPrepared", { recipe = recipeName })
				end
			end)
			return nil
		end,
	})

	NetService.registerIntent("DeliverOrder", {
		handler = function(_player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WINDOW_ID then
				return "TargetMissing"
			end
			if currentStatus == "" or currentStatus == "Delivered" or currentStatus == "Failed" then
				return "OrderClosed"
			end
			if currentStatus == "Pending" or currentStatus == "Preparing" then
				return "NotPrepared"
			end
			currentStatus = "Delivered"
			publish()
			local recipe = recipeById[currentRecipeId]
			NotifyService.broadcast("OrderDelivered", {
				recipe = if recipe then Strings.format(recipe.NameKey) else currentRecipeId,
			})
			return nil
		end,
	})

	log:info("Cuisine prête (%d recette(s) déclarée(s))", #Recipes)
end

return OrderService
