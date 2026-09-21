--!strict
-- Panneau de l'établi (009-craft-etabli, research R5) : l'invite de proximité "CraftPrompt",
-- construite par CraftService sans attribut Intent, n'est jamais relayée par
-- InteractionController (celui-ci ignore déjà silencieusement toute invite sans Intent de type
-- chaîne) — ce contrôleur l'écoute donc directement pour n'ouvrir/fermer qu'un panneau local,
-- aucun aller-retour serveur pour un simple affichage d'interface (SC-001). La fabrication
-- elle-même reste une intention réseau ordinaire (CraftItem), revalidée entièrement côté serveur.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Recipes = require(Shared:WaitForChild("Craft"):WaitForChild("Recipes") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local CraftStateClient = require(ClientFolder:WaitForChild("CraftStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local Colors = UiKit.Colors
local PANEL_SIZE = UDim2.fromScale(0.34, 0.5)
local WORKBENCH_TARGET = "Workbench"
local CRAFT_PROMPT_NAME = "CraftPrompt"

-- Réglage config lu pour afficher le montant de chaque effet dans sa description (Craft.HealAmount
-- pour Heal, Craft.FuelAmount pour RefuelGenerator) — même donnée que celle que CraftService
-- applique réellement, jamais dupliquée en dur ici.
local AMOUNT_SETTING: { [string]: string } = {
	Heal = "HealAmount",
	RefuelGenerator = "FuelAmount",
}

local CraftPanelController = { Name = "CraftPanelController", Priority = 63 }

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "CraftScreen"
screen.ResetOnSpawn = false
screen.DisplayOrder = 5
screen.Enabled = false
screen.Parent = playerGui

local root = UiKit.frame(screen, "Root", PANEL_SIZE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
UiKit.corner(root, 12)
UiKit.stroke(root, Colors.Neon, 1.5)
UiKit.padding(root, 10)
UiKit.sizeLimits(root, Vector2.new(280, 220), Vector2.new(480, 560))

local closeButton = UiKit.button(root, "Close", `{Strings.format("Craft.Title")} ✕`, function()
	screen.Enabled = false
end)
closeButton.Size = UDim2.new(1, 0, 0, 30)

local list = Instance.new("ScrollingFrame")
list.Name = "Recipes"
list.Position = UDim2.fromOffset(0, 38)
list.Size = UDim2.new(1, 0, 1, -38)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = root
local listPadding = Instance.new("UIPadding")
listPadding.PaddingRight = UDim.new(0, 8)
listPadding.Parent = list
UiKit.list(list, 8)

type Card = {
	frame: Frame,
	status: TextLabel,
	action: GuiObject,
}

local cards: { [string]: Card } = {}

local function ingredientsText(recipe: Recipes.Recipe): string
	local parts = {}
	for resourceType, amount in recipe.Ingredients do
		table.insert(parts, `{amount}× {Strings.format(`Resource.{resourceType}`)}`)
	end
	return table.concat(parts, ", ")
end

local function buildCard(recipe: Recipes.Recipe, order: number): Card
	local frame = UiKit.frame(list, recipe.Id, UDim2.new(1, -4, 0, 0))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	UiKit.corner(frame, 8)
	UiKit.padding(frame, 8)
	UiKit.list(frame, 4)

	local title = UiKit.label(frame, "Title", Strings.format(recipe.NameKey), UDim2.new(1, 0, 0, 20), {
		font = UiKit.Fonts.Title,
		color = Colors.Cyan,
		align = Enum.TextXAlignment.Left,
		maxSize = 18,
	})
	title.LayoutOrder = 1

	local amount = Config.get("Craft", AMOUNT_SETTING[recipe.Effect])
	local description = UiKit.label(
		frame,
		"Description",
		Strings.format(recipe.DescriptionKey, { amount = amount }),
		UDim2.fromScale(1, 0),
		{
			align = Enum.TextXAlignment.Left,
			autoHeight = true,
			textSize = 13,
			color = Colors.Muted,
		}
	)
	description.LayoutOrder = 2

	local status = UiKit.label(frame, "Status", ingredientsText(recipe), UDim2.new(1, 0, 0, 16), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
	})
	status.LayoutOrder = 3

	local action = UiKit.button(frame, "Action", "", function() end)
	action.Size = UDim2.new(1, 0, 0, 26)
	action.LayoutOrder = 4

	return { frame = frame, status = status, action = action }
end

local function refreshCard(recipe: Recipes.Recipe, card: Card, state: CraftStateClient.State)
	local available = state.recipes[recipe.Id] ~= nil and state.recipes[recipe.Id].available
	local action = card.action :: TextButton
	action.Text = if available then Strings.format("Craft.Make") else Strings.format("Craft.InsufficientResources")
	action.AutoButtonColor = available
	action.TextColor3 = if available then Colors.Text else Colors.Bad
end

local function wireAction(recipe: Recipes.Recipe, card: Card)
	(card.action :: TextButton).Activated:Connect(function()
		local state = CraftStateClient.get()
		local entry = state.recipes[recipe.Id]
		if entry ~= nil and entry.available then
			NetClient.send("CraftItem", { recipeId = recipe.Id, target = WORKBENCH_TARGET })
		end
	end)
end

local function refreshAll()
	local state = CraftStateClient.get()
	for _, recipe in Recipes.All do
		refreshCard(recipe, cards[recipe.Id], state)
	end
end

for order, recipe in Recipes.All do
	local card = buildCard(recipe, order)
	cards[recipe.Id] = card
	wireAction(recipe, card)
end

CraftStateClient.Changed:Connect(refreshAll)
refreshAll()

function CraftPanelController.SetVisible(visible: boolean)
	screen.Enabled = visible
end

function CraftPanelController.Toggle()
	screen.Enabled = not screen.Enabled
end

function CraftPanelController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == CRAFT_PROMPT_NAME then
			CraftPanelController.Toggle()
		end
	end)
end

return CraftPanelController
