--!strict
-- Panneau de boutique (008-boutique-persistance, US1/US2, research R11) : catalogue, achat et
-- choix de l'objet actif par emplacement. Déclenché par un bouton du HUD (Hud.client.luau), pas
-- une invite de proximité — accessible à tout moment, en partie ou non (FR-001). Reprend les
-- idiomes visuels de DevPanel.client.luau (UiKit, ScrollingFrame + liste).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Catalog = require(Shared:WaitForChild("Boutique"):WaitForChild("Catalog") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local BoutiqueStateClient = require(ClientFolder:WaitForChild("BoutiqueStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local Colors = UiKit.Colors
local PANEL_SIZE = UDim2.fromScale(0.36, 0.66)

local BoutiquePanelController = { Name = "BoutiquePanelController", Priority = 62 }

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BoutiqueScreen"
screen.ResetOnSpawn = false
screen.DisplayOrder = 5
screen.Enabled = false
screen.Parent = playerGui

local root = UiKit.frame(screen, "Root", PANEL_SIZE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
UiKit.corner(root, 12)
UiKit.stroke(root, Colors.Neon, 1.5)
UiKit.padding(root, 10)
UiKit.sizeLimits(root, Vector2.new(300, 260), Vector2.new(520, 640))

local header = UiKit.button(root, "Close", `{Strings.format("Boutique.Title")} ✕`, function()
	screen.Enabled = false
end)
header.Size = UDim2.new(1, 0, 0, 30)

local balanceLabel = UiKit.label(root, "Balance", "", UDim2.new(1, 0, 0, 22), {
	position = UDim2.fromOffset(0, 36),
	color = Colors.Cyan,
	align = Enum.TextXAlignment.Left,
	minSize = 14,
	maxSize = 16,
})

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.Position = UDim2.fromOffset(0, 62)
list.Size = UDim2.new(1, 0, 1, -62)
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

local function buildCard(item: Catalog.Item, order: number): Card
	local frame = UiKit.frame(list, item.Id, UDim2.new(1, -4, 0, 0))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	UiKit.corner(frame, 8)
	UiKit.padding(frame, 8)
	UiKit.list(frame, 4)

	local title = UiKit.label(frame, "Title", Strings.format(item.NameKey), UDim2.new(1, 0, 0, 20), {
		font = UiKit.Fonts.Title,
		color = Colors.Cyan,
		align = Enum.TextXAlignment.Left,
		maxSize = 18,
	})
	title.LayoutOrder = 1

	local description = UiKit.label(frame, "Description", Strings.format(item.DescriptionKey), UDim2.fromScale(1, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 13,
		color = Colors.Muted,
	})
	description.LayoutOrder = 2

	local status = UiKit.label(frame, "Status", "", UDim2.new(1, 0, 0, 16), {
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

local function refreshCard(item: Catalog.Item, card: Card, state: BoutiqueStateClient.State)
	local owned = state.owned[item.Id] == true
	-- Un bouton précédent reste connecté (UiKit.button ne fournit pas de Disconnect) : on ne
	-- reconnecte jamais Activated deux fois, on remplace le bouton entier si son action change.
	local action = card.action :: TextButton

	if item.Category == "Advantage" then
		if owned then
			card.status.Text = Strings.format("Boutique.Owned")
			card.status.TextColor3 = Colors.Good
			action.Visible = false
		else
			card.status.Text = ""
			action.Visible = true
			local affordable = state.balance >= item.Price
			action.Text = if affordable
				then Strings.format("Boutique.Buy", { price = item.Price })
				else Strings.format("Boutique.InsufficientFunds")
			action.AutoButtonColor = affordable
			action.TextColor3 = if affordable then Colors.Text else Colors.Bad
		end
		return
	end

	-- Cosmétique.
	local slot = item.Slot :: string
	local activeId = state.active[slot]
	if not owned then
		card.status.Text = ""
		action.Visible = true
		local affordable = state.balance >= item.Price
		action.Text = if affordable
			then Strings.format("Boutique.Buy", { price = item.Price })
			else Strings.format("Boutique.InsufficientFunds")
		action.AutoButtonColor = affordable
		action.TextColor3 = if affordable then Colors.Text else Colors.Bad
	elseif activeId == item.Id then
		card.status.Text = Strings.format("Boutique.Active")
		card.status.TextColor3 = Colors.Good
		action.Visible = false
	else
		card.status.Text = Strings.format("Boutique.Owned")
		card.status.TextColor3 = Colors.Muted
		action.Visible = true
		action.Text = Strings.format("Boutique.SetActive")
		action.AutoButtonColor = true
		action.TextColor3 = Colors.Text
	end
end

-- Un seul écouteur Activated par bouton, posé une fois à la construction : lit l'état courant au
-- moment du clic plutôt que de reconnecter une fermeture à chaque rafraîchissement.
local function wireAction(item: Catalog.Item, card: Card)
	(card.action :: TextButton).Activated:Connect(function()
		local state = BoutiqueStateClient.get()
		local owned = state.owned[item.Id] == true
		if not owned then
			if state.balance >= item.Price then
				NetClient.send("BuyItem", { itemId = item.Id })
			end
			return
		end
		if item.Category == "Cosmetic" then
			NetClient.send("SetActiveCosmetic", { itemId = item.Id })
		end
	end)
end

local function refreshAll()
	local state = BoutiqueStateClient.get()
	balanceLabel.Text = `{Strings.format("Hud.Currency")} : {state.balance}`
	for _, item in Catalog.Items do
		refreshCard(item, cards[item.Id], state)
	end
end

for order, item in Catalog.Items do
	local card = buildCard(item, order)
	cards[item.Id] = card
	wireAction(item, card)
end

BoutiqueStateClient.Changed:Connect(refreshAll)
refreshAll()

function BoutiquePanelController.SetVisible(visible: boolean)
	screen.Enabled = visible
end

function BoutiquePanelController.Toggle()
	screen.Enabled = not screen.Enabled
end

return BoutiquePanelController
