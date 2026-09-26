--!strict
-- Panneau de l'établi (009-craft-etabli, research R5) en deux vues, qui suivent l'état répliqué
-- par CraftService (CraftStateClient) sans jamais le décider :
--   1. la liste des recettes, où l'on choisit ce que l'on veut fabriquer ;
--   2. le plan de travail de la recette choisie : ses ingrédients, avec ce qui est déjà posé. On les
--      y dépose avec la touche G près de l'établi, ou en glissant un objet du monde dessus (le
--      serveur s'en charge, voir CraftService) ; le bouton Fabriquer s'active quand tout y est.
--
-- L'invite de proximité "CraftPrompt", construite par CraftService sans attribut Intent, n'est
-- jamais relayée par InteractionController (celui-ci ignore déjà silencieusement toute invite sans
-- Intent de type chaîne) — ce contrôleur l'écoute donc directement pour n'ouvrir/fermer qu'un
-- panneau local, aucun aller-retour serveur pour un simple affichage d'interface (SC-001). Choisir
-- une recette, la quitter et fabriquer restent des intentions réseau ordinaires, revalidées
-- entièrement côté serveur.

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
local PANEL_SIZE = UDim2.fromScale(0.34, 0.62)
local WORKBENCH_TARGET = "Workbench"
local CRAFT_PROMPT_NAME = "CraftPrompt"
local HEADER_HEIGHT = 38

-- Réglage config lu pour afficher le montant que produira l'objet fabriqué dans sa description
-- (Craft.HealAmount pour la trousse, Craft.FuelAmount pour le bidon) — même donnée que celle que
-- CraftService et GeneratorService appliquent réellement à l'usage, jamais dupliquée en dur ici.
local AMOUNT_SETTING: { [string]: string } = {
	HealKit = "HealAmount",
	FuelCanister = "FuelAmount",
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
UiKit.sizeLimits(root, Vector2.new(280, 220), Vector2.new(480, 620))

local closeButton = UiKit.button(root, "Close", `{Strings.format("Craft.Title")} ✕`, function()
	screen.Enabled = false
end)
closeButton.Size = UDim2.new(1, 0, 0, 30)

-- Zone défilante sous l'en-tête : les deux vues en ont une, pour qu'un petit écran n'écrase rien.
local function scrollArea(name: string): ScrollingFrame
	local area = Instance.new("ScrollingFrame")
	area.Name = name
	area.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	area.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	area.BackgroundTransparency = 1
	area.BorderSizePixel = 0
	area.ScrollBarThickness = 5
	area.AutomaticCanvasSize = Enum.AutomaticSize.Y
	area.CanvasSize = UDim2.new()
	area.Parent = root
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = area
	UiKit.list(area, 8)
	return area
end

local list = scrollArea("Recipes")
local bench = scrollArea("Bench")

type Slot = {
	count: TextLabel,
	fill: Frame,
	required: number,
	resourceType: string,
}

local benchName: TextLabel
local benchDescription: TextLabel
local slotsFrame: Frame
local makeButton: TextButton
local slots: { Slot } = {}
local builtRecipeId: string? = nil

-- Ingrédients dans un ordre stable (un dictionnaire n'en a pas) : la liste des cartes et les lignes
-- du plan de travail s'affichent toujours de la même façon.
local function sortedIngredients(recipe: Recipes.Recipe): { { resourceType: string, amount: number } }
	local result = {}
	for resourceType, amount in recipe.Ingredients do
		table.insert(result, { resourceType = resourceType :: string, amount = amount })
	end
	table.sort(result, function(a, b)
		return a.resourceType < b.resourceType
	end)
	return result
end

local function ingredientsText(recipe: Recipes.Recipe): string
	local parts = {}
	for _, ingredient in sortedIngredients(recipe) do
		table.insert(parts, `{ingredient.amount}× {Strings.format(`Resource.{ingredient.resourceType}`)}`)
	end
	return table.concat(parts, ", ")
end

local function descriptionOf(recipe: Recipes.Recipe): string
	local amount = Config.get("Craft", AMOUNT_SETTING[recipe.Result])
	return Strings.format(recipe.DescriptionKey, { amount = amount })
end

-- Vue 1 : une carte par recette, un seul bouton pour la choisir. On peut la choisir sans avoir les
-- ingrédients : c'est justement à l'établi qu'on voit ce qu'il manque et qu'on le dépose.
local function buildCard(recipe: Recipes.Recipe, order: number)
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

	local description = UiKit.label(frame, "Description", descriptionOf(recipe), UDim2.fromScale(1, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
		color = Colors.Muted,
	})
	description.LayoutOrder = 2

	local ingredients = UiKit.label(frame, "Ingredients", ingredientsText(recipe), UDim2.new(1, 0, 0, 16), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
	})
	ingredients.LayoutOrder = 3

	local choose = UiKit.button(frame, "Select", Strings.format("Craft.Select"), function()
		NetClient.send("SelectCraftRecipe", { recipeId = recipe.Id, target = WORKBENCH_TARGET })
	end)
	choose.Size = UDim2.new(1, 0, 0, 26)
	choose.LayoutOrder = 4
end

local chooseHint = UiKit.label(list, "Hint", Strings.format("Craft.ChooseHint"), UDim2.fromScale(1, 0), {
	align = Enum.TextXAlignment.Left,
	autoHeight = true,
	textSize = 13,
	color = Colors.Muted,
})
chooseHint.LayoutOrder = 0

for order, recipe in Recipes.All do
	buildCard(recipe, order)
end

-- Vue 2 : le plan de travail. Les éléments fixes sont construits une fois ; seules les lignes
-- d'ingrédients dépendent de la recette et sont refaites quand elle change (rebuildBench).
local function buildBench()
	benchName = UiKit.label(bench, "Name", "", UDim2.new(1, 0, 0, 24), {
		font = UiKit.Fonts.Title,
		color = Colors.Cyan,
		align = Enum.TextXAlignment.Left,
		maxSize = 20,
	})
	benchName.LayoutOrder = 1

	benchDescription = UiKit.label(bench, "Description", "", UDim2.fromScale(1, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
		color = Colors.Muted,
	})
	benchDescription.LayoutOrder = 2

	slotsFrame = UiKit.frame(bench, "Slots", UDim2.new(1, -4, 0, 0))
	slotsFrame.AutomaticSize = Enum.AutomaticSize.Y
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.LayoutOrder = 3
	UiKit.list(slotsFrame, 6)

	local hint = UiKit.label(bench, "Hint", Strings.format("Craft.BenchHint"), UDim2.fromScale(1, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
		color = Colors.Muted,
	})
	hint.LayoutOrder = 4

	makeButton = UiKit.button(bench, "Make", "", function()
		local state = CraftStateClient.get()
		if state.recipe ~= nil and state.complete then
			NetClient.send("CraftItem", { recipeId = state.recipe.Id, target = WORKBENCH_TARGET })
		end
	end)
	makeButton.Size = UDim2.new(1, -4, 0, 30)
	makeButton.LayoutOrder = 5

	local back = UiKit.button(bench, "Back", Strings.format("Craft.Back"), function()
		NetClient.send("CancelCraft", { target = WORKBENCH_TARGET })
	end)
	back.Size = UDim2.new(1, -4, 0, 26)
	back.LayoutOrder = 6
end

buildBench()

local function buildSlot(ingredient: { resourceType: string, amount: number }, order: number): Slot
	local row = UiKit.frame(slotsFrame, ingredient.resourceType, UDim2.new(1, 0, 0, 40))
	row.LayoutOrder = order
	UiKit.corner(row, 8)

	UiKit.label(row, "Name", Strings.format(`Resource.{ingredient.resourceType}`), UDim2.new(0.6, -8, 0, 20), {
		position = UDim2.fromOffset(8, 4),
		align = Enum.TextXAlignment.Left,
		maxSize = 16,
	})
	local count = UiKit.label(row, "Count", "", UDim2.new(0.4, -8, 0, 20), {
		position = UDim2.new(0.6, 0, 0, 4),
		align = Enum.TextXAlignment.Right,
		maxSize = 16,
	})
	local track, fill = UiKit.bar(row, "Track", UDim2.new(1, -16, 0, 6), UDim2.new(0, 8, 1, -12))
	UiKit.corner(track, 3)
	UiKit.corner(fill, 3)

	return { count = count, fill = fill, required = ingredient.amount, resourceType = ingredient.resourceType }
end

local function rebuildBench(recipe: Recipes.Recipe)
	for _, child in slotsFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	slots = {}
	for order, ingredient in sortedIngredients(recipe) do
		table.insert(slots, buildSlot(ingredient, order))
	end
	benchName.Text = Strings.format(recipe.NameKey)
	benchDescription.Text = descriptionOf(recipe)
	builtRecipeId = recipe.Id
end

local function refreshBench(state: CraftStateClient.State)
	for _, slot in slots do
		local placed = state.placed[slot.resourceType] or 0
		local full = placed >= slot.required
		slot.count.Text = Strings.format("Craft.SlotCount", { placed = placed, required = slot.required })
		slot.count.TextColor3 = if full then Colors.Good else Colors.Text
		slot.fill.Size = UDim2.fromScale(math.clamp(placed / slot.required, 0, 1), 1)
		slot.fill.BackgroundColor3 = if full then Colors.Good else Colors.Cyan
	end
	-- Le bouton dit toujours pourquoi il n'agit pas : le serveur refuse en silence une recette
	-- incomplète, un clic dans le vide ne dirait rien au joueur.
	makeButton.Text = if state.complete
		then Strings.format("Craft.Make")
		else Strings.format("Craft.MissingIngredients")
	makeButton.TextColor3 = if state.complete then Colors.Text else Colors.Bad
	makeButton.AutoButtonColor = state.complete
end

-- Une seule fonction décide de la vue affichée : celle que l'état répliqué impose. Choisir une
-- recette (ou l'abandonner) ne change donc rien ici tant que le serveur ne l'a pas confirmé.
local function refreshAll()
	local state = CraftStateClient.get()
	local recipe = state.recipe
	list.Visible = recipe == nil
	bench.Visible = recipe ~= nil
	if recipe == nil then
		builtRecipeId = nil
		return
	end
	if builtRecipeId ~= recipe.Id then
		rebuildBench(recipe)
	end
	refreshBench(state)
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
