--!strict
-- Repères visuels du marketplace (002-premier-increment-jouable) : sac au comptoir quand le stock
-- vient d'augmenter, poêle au plan de travail tant qu'une commande attend d'être préparée, sac à
-- emporter à la fenêtre tant qu'elle attend d'être livrée. Purement décoratif : aucune autorité de
-- jeu, seulement un reflet de l'état déjà répliqué (ReplicatedStorage.Stock, .OrderState),
-- construit et affiché/masqué depuis le serveur (principe III) donc identique pour tous les
-- joueurs. Voir Catalog.luau (DepositCue/PrepareCue/DeliverCue) et AssetImportService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local VisualService = require(script.Parent.VisualService)
local WorldService = require(script.Parent.WorldService)

type ResourceType = Types.ResourceType

local COUNTER_ID = "Counter"
local WORKTOP_ID = "Worktop"
local WINDOW_ID = "DriveThruWindow"
-- Le dépôt est un geste ponctuel (contrairement au statut de commande, un état) : le sac
-- apparaît puis s'efface, comme le flash/son de SfxController/FeedbackFxController côté client.
local DEPOSIT_POP_DURATION = 1.6
local STOCK_TYPES: { ResourceType } = { "SuspectSteak", "RoadBread" }

local log = Log.new("FeedbackVisual")

local FeedbackVisualService = { Name = "FeedbackVisualService", Priority = 70 }

-- Construit un visuel du catalogue au-dessus d'un point de référence, masqué par défaut.
-- nil en cas d'échec (point de référence ou construction manquants), avec un journal explicite :
-- comportement de secours cohérent avec le reste du catalogue (FR-041), jamais un plantage.
local function buildCue(catalogId: string, refPointId: string, height: number): Model?
	local anchor = WorldService.refPoint(refPointId)
	if anchor == nil then
		log:error("Point de référence %s introuvable : repère %s désactivé", refPointId, catalogId)
		return nil
	end
	local model = VisualService.build(catalogId)
	if model == nil then
		log:error("Construction de %s impossible : repère désactivé", catalogId)
		return nil
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model:PivotTo(anchor.CFrame + Vector3.new(0, height, 0))
	model.Name = catalogId
	model.Parent = workspace
	return model
end

local function setVisible(model: Model?, visible: boolean)
	if model == nil then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
		end
	end
end

function FeedbackVisualService.Init()
	-- Hauteurs choisies à partir de la géométrie de Catalog.luau (comptoir, plan de travail,
	-- ouverture de la fenêtre) pour flotter juste au-dessus de chaque poste sans le traverser.
	local depositCue = buildCue("DepositCue", COUNTER_ID, 0.4)
	local prepareCue = buildCue("PrepareCue", WORKTOP_ID, 0.3)
	local deliverCue = buildCue("DeliverCue", WINDOW_ID, -1)
	setVisible(depositCue, false)
	setVisible(prepareCue, false)
	setVisible(deliverCue, false)

	-- Sac au comptoir : un pic à chaque dépôt (hausse du stock partagé), pas à sa consommation
	-- par une préparation ni à sa remise à zéro en début de partie.
	local stock = ReplicatedStorage:WaitForChild("Stock")
	local previousStock: { [string]: number } = {}
	for _, resourceType in STOCK_TYPES do
		local value = stock:GetAttribute(resourceType)
		previousStock[resourceType] = if typeof(value) == "number" then value else 0
	end
	local popToken = 0
	local function onStockChanged(resourceType: string)
		local value = stock:GetAttribute(resourceType)
		if typeof(value) ~= "number" then
			return
		end
		local previous = previousStock[resourceType] or 0
		previousStock[resourceType] = value
		if value <= previous then
			return
		end
		popToken += 1
		local token = popToken
		setVisible(depositCue, true)
		task.delay(DEPOSIT_POP_DURATION, function()
			if popToken == token then
				setVisible(depositCue, false)
			end
		end)
	end
	for _, resourceType in STOCK_TYPES do
		stock:GetAttributeChangedSignal(resourceType):Connect(function()
			onStockChanged(resourceType)
		end)
	end

	-- Poêle au plan de travail tant que la commande attend d'être préparée, sac à la fenêtre
	-- tant qu'elle attend d'être livrée.
	local orderState = ReplicatedStorage:WaitForChild("OrderState")
	local function onOrderStatusChanged()
		local status = orderState:GetAttribute("Status")
		setVisible(prepareCue, status == "Pending")
		setVisible(deliverCue, status == "Prepared")
	end
	orderState:GetAttributeChangedSignal("Status"):Connect(onOrderStatusChanged)
	onOrderStatusChanged()

	log:info("Repères visuels prêts (comptoir, plan de travail, fenêtre)")
end

return FeedbackVisualService
