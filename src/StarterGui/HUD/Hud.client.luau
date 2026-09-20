--!strict
-- HUD (FR-035, FR-036) : phase, nuit, temps restant, équipe, vie, commandes en cours et fil de
-- notifications. N'affiche que l'état répliqué par le serveur (principe III).
--
-- Disposition : bandeau en haut au centre, cartes de commande sous le bandeau, colonne vie +
-- équipe à droite, fil de notifications en bas à gauche. Le carburant, la zone sûre et la
-- réparation du bus vivent désormais dans le monde, près de ce qu'ils décrivent (voir
-- FuelGaugeController, BusRepairController) ; le détail du sac, au-dessus du joueur quand il est
-- équipé (BagStatusController). Le coin haut gauche reste libre pour le chat Roblox et le panneau
-- de dev de Studio (DevPanel.client.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local MatchStateClient = require(ClientFolder:WaitForChild("MatchStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

type GameplayState = GameplayStateClient.State

local screen = script.Parent :: ScreenGui
local Colors = UiKit.Colors

local REFRESH_INTERVAL = 0.1 -- 10 Hz au plus
local ROW_TEXT_SIZE = 16
local FEED_KINDS = {
	"PhaseStarted",
	"PlayerJoined",
	"PlayerLeft",
	"StatusChanged",
	"MatchEnded",
	"OrderPrepared",
	"BusRepaired",
	-- 004-sac-collecte : seul retour visible d'un ramassage refusé, le pipeline ne renvoyant
	-- jamais ses refus au client (research R10).
	"BagFull",
	"BagDropped",
}
local PHASE_COLORS: { [string]: Color3 } = {
	Waiting = Colors.Muted,
	Countdown = Colors.Text,
	Day = Colors.Warn,
	Night = Colors.Neon,
	Escape = Colors.Cyan,
	Ended = Colors.Muted,
}

-- Bandeau du haut : phase, nuit, temps restant ----------------------------------------------

local topBar = UiKit.frame(screen, "TopBar", UDim2.fromScale(0.42, 0.12), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
UiKit.sizeLimits(topBar, Vector2.new(280, 64), Vector2.new(520, 96))
UiKit.corner(topBar, 12)
UiKit.stroke(topBar, Colors.Neon, 2)
UiKit.padding(topBar, 6)

local phaseLabel = UiKit.label(topBar, "Phase", "", UDim2.fromScale(1, 0.55), {
	font = UiKit.Fonts.Title,
	color = Colors.Neon,
	maxSize = 34,
})
local nightLabel = UiKit.label(topBar, "Night", "", UDim2.fromScale(0.5, 0.42), {
	position = UDim2.fromScale(0, 0.58),
	color = Colors.Muted,
	align = Enum.TextXAlignment.Left,
	maxSize = 20,
})
local timerLabel = UiKit.label(topBar, "Timer", "", UDim2.fromScale(0.5, 0.42), {
	position = UDim2.fromScale(0.5, 0.58),
	color = Colors.Cyan,
	font = UiKit.Fonts.Mono,
	align = Enum.TextXAlignment.Right,
	maxSize = 22,
})

local function formatClock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local function refreshTop()
	local state = MatchStateClient.get()
	local phase = state.phase
	phaseLabel.Text = Strings.format(`Phase.{phase}`, { night = state.night })
	phaseLabel.TextColor3 = PHASE_COLORS[phase] or Colors.Text

	if phase == "Day" or phase == "Night" or phase == "Escape" then
		nightLabel.Text = Strings.format("Hud.NightCounter", {
			night = math.max(state.night, 1),
			totalNights = state.totalNights,
		})
	elseif phase == "Countdown" or phase == "Ended" then
		nightLabel.Text = Strings.format("Hud.NightsToSurvive", { totalNights = state.totalNights })
	else
		nightLabel.Text = ""
	end

	local remaining = MatchStateClient.remaining()
	if remaining == nil then
		timerLabel.Text = if phase == "Waiting" then "" else Strings.format("Hud.NoLimit")
	elseif phase == "Countdown" then
		timerLabel.Text = Strings.format("Hud.CountdownPrefix", { time = formatClock(remaining) })
	else
		timerLabel.Text = formatClock(remaining)
	end
end

-- Colonne de droite : panneaux empilés, à hauteur ajustée à leur contenu ---------------------

local sideColumn = UiKit.frame(screen, "Side", UDim2.fromScale(0.22, 0), UDim2.new(1, -12, 0, 8), Vector2.new(1, 0))
sideColumn.BackgroundTransparency = 1
sideColumn.AutomaticSize = Enum.AutomaticSize.Y
UiKit.sizeLimits(sideColumn, Vector2.new(190, 0), Vector2.new(260, math.huge))
UiKit.list(sideColumn, 8)

local function sidePanel(name: string, order: number): Frame
	local panel = UiKit.frame(sideColumn, name, UDim2.fromScale(1, 0))
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.LayoutOrder = order
	UiKit.corner(panel, 10)
	UiKit.padding(panel, 8)
	UiKit.list(panel, 4)
	return panel
end

local function panelTitle(panel: Frame, text: string): TextLabel
	local title = UiKit.label(panel, "Title", text, UDim2.new(1, 0, 0, 24), {
		font = UiKit.Fonts.Title,
		color = Colors.Cyan,
		align = Enum.TextXAlignment.Left,
		maxSize = 20,
	})
	title.LayoutOrder = 0
	return title
end

-- Ligne à hauteur automatique : un texte trop long passe à la ligne au lieu de déborder.
local function panelRow(panel: Frame, name: string, text: string, color: Color3?): TextLabel
	return UiKit.label(panel, name, text, UDim2.fromScale(1, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = ROW_TEXT_SIZE,
		color = color,
	})
end

-- Vie (toujours visible, en tête de la colonne de droite) -------------------------------------

local healthPanel = sidePanel("Health", 1)
panelTitle(healthPanel, Strings.format("Hud.Health"))

local healthTrack, healthFill = UiKit.bar(healthPanel, "Bar", UDim2.new(1, 0, 0, 14))
healthTrack.LayoutOrder = 1
UiKit.corner(healthTrack, 6)
UiKit.corner(healthFill, 6)

local healthText = panelRow(healthPanel, "Text", "")
healthText.LayoutOrder = 2

-- 006-monnaie-jetons-fidelite : même colonne que la Vie, toujours visible (principe VII,
-- « ressources du joueur »). Une simple ligne suffit — pas de barre, le solde n'a pas de plafond.
local currencyText = panelRow(healthPanel, "Currency", "")
currencyText.LayoutOrder = 3

local previousHealth: number? = nil

local function refreshHealth()
	local state = GameplayStateClient.get()
	local ratio = if state.maxHealth > 0 then math.clamp(state.health / state.maxHealth, 0, 1) else 0
	local steady = if state.health <= state.maxHealth * 0.3 then Colors.Bad else Colors.Good
	healthFill.Size = UDim2.fromScale(ratio, 1)
	healthFill.BackgroundColor3 = steady
	healthText.Text = `{math.floor(state.health)} / {math.floor(state.maxHealth)}`
	currencyText.Text = `{Strings.format("Hud.Currency")} : {state.currency}`

	if previousHealth ~= nil and state.health ~= previousHealth then
		local accent = if state.health > previousHealth then Colors.Good else Colors.Bad
		healthFill.BackgroundColor3 = accent
		TweenService:Create(healthFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundColor3 = steady }):Play()
	end
	previousHealth = state.health
end

-- Équipe ------------------------------------------------------------------------------------

local teamPanel = sidePanel("Team", 2)
local teamTitle = panelTitle(teamPanel, Strings.format("Hud.Team"))

local function rebuildTeam(leaving: Player?)
	for _, child in teamPanel:GetChildren() do
		if child:GetAttribute("TeamRow") then
			child:Destroy()
		end
	end
	local members: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player ~= leaving then
			table.insert(members, player)
		end
	end
	table.sort(members, function(a: Player, b: Player): boolean
		return a.DisplayName < b.DisplayName
	end)
	for index, player in members do
		local alive = player:GetAttribute("Status") ~= "Eliminated"
		local status = Strings.format(if alive then "Hud.Status.Alive" else "Hud.Status.Eliminated")
		local row = panelRow(
			teamPanel,
			"Row",
			`● {player.DisplayName} — {status}`,
			if alive then Colors.Good else Colors.Bad
		)
		row.LayoutOrder = index
		row:SetAttribute("TeamRow", true)
	end
	teamTitle.Text = `{Strings.format("Hud.Team")} ({#members})`
end

local statusConnections: { [Player]: RBXScriptConnection } = {}

local function watch(player: Player)
	if statusConnections[player] ~= nil then
		return
	end
	statusConnections[player] = player:GetAttributeChangedSignal("Status"):Connect(function()
		rebuildTeam(nil)
	end)
end

-- Commandes en attente (une carte animée par commande active) ---------------------------------
-- Amélioration visuelle : remplace la ligne texte unique qui vivait dans l'ancienne box
-- « Ressources ». Écrit dès aujourd'hui comme une liste de cartes (indexées par clé, pas un seul
-- slot fixe) même si le serveur ne produit qu'une commande à la fois (OrderService) : le jour où
-- plusieurs commandes tourneront en parallèle, seule la source (une commande → un tableau de
-- commandes) changera, pas ce rendu.

local ordersColumn =
	UiKit.frame(screen, "Orders", UDim2.fromScale(0.3, 0), UDim2.fromScale(0.5, 0.14), Vector2.new(0.5, 0))
ordersColumn.BackgroundTransparency = 1
ordersColumn.AutomaticSize = Enum.AutomaticSize.Y
UiKit.sizeLimits(ordersColumn, Vector2.new(220, 0), Vector2.new(340, math.huge))
UiKit.list(ordersColumn, 8)

type OrderCard = {
	frame: CanvasGroup,
	title: TextLabel,
	statusLabel: TextLabel,
	progressTrack: Frame,
	progressFill: Frame,
	ingredientsLabel: TextLabel,
	stage: string,
	cookingStartedAt: number?,
	removing: boolean,
}

local orderCards: { [string]: OrderCard } = {}
-- Identifie l'instance de commande en cours (pas juste sa recette, qui peut se répéter d'une nuit
-- à l'autre) : assigné à la première apparition d'un statut non-vide, oublié seulement quand le
-- serveur revient à "" (OrderService.clearOrder, au changement de phase suivant — pas aussitôt
-- après Livrée/Ratée : une commande livrée en milieu de nuit reste "Delivered" jusqu'à la fin de
-- la nuit). `finalizedKeys` retient qu'une instance a déjà joué sa disparition, pour ignorer les
-- rafraîchissements suivants tant que le statut reste au même palier terminal.
local activeOrderKey: string? = nil
local finalizedKeys: { [string]: boolean } = {}
local orderSeq = 0

local function buildOrderCard(order: number): OrderCard
	local frame = Instance.new("CanvasGroup")
	frame.Name = `Card{order}`
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Colors.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.GroupTransparency = 1
	frame.Parent = ordersColumn
	UiKit.corner(frame, 10)
	UiKit.stroke(frame, Colors.Cyan, 1.5)
	UiKit.padding(frame, 8)
	UiKit.list(frame, 4)

	local title = UiKit.label(frame, "Title", "", UDim2.new(1, 0, 0, 22), {
		font = UiKit.Fonts.Title,
		color = Colors.Cyan,
		align = Enum.TextXAlignment.Left,
		maxSize = 18,
	})
	title.LayoutOrder = 1

	local statusLabel = panelRow(frame, "Status", "")
	statusLabel.LayoutOrder = 2

	local progressTrack, progressFill = UiKit.bar(frame, "Progress", UDim2.new(1, 0, 0, 8))
	progressTrack.LayoutOrder = 3
	progressFill.BackgroundColor3 = Colors.Warn
	UiKit.corner(progressTrack, 4)
	UiKit.corner(progressFill, 4)

	local ingredientsLabel = panelRow(frame, "Ingredients", "", Colors.Muted)
	ingredientsLabel.LayoutOrder = 4

	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()

	return {
		frame = frame,
		title = title,
		statusLabel = statusLabel,
		progressTrack = progressTrack,
		progressFill = progressFill,
		ingredientsLabel = ingredientsLabel,
		stage = "",
		cookingStartedAt = nil,
		removing = false,
	}
end

local function removeOrderCard(key: string)
	local card = orderCards[key]
	if card == nil or card.removing then
		return
	end
	card.removing = true
	local tween = TweenService:Create(card.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		card.frame:Destroy()
		if orderCards[key] == card then
			orderCards[key] = nil
		end
	end)
	tween:Play()
end

local function updateOrderCard(card: OrderCard, state: GameplayState)
	if card.stage ~= state.orderStatus then
		if state.orderStatus == "Preparing" then
			card.cookingStartedAt = os.clock()
		end
		card.stage = state.orderStatus
	end

	local recipe = GameplayStateClient.getOrderRecipe()
	card.title.Text = if recipe then Strings.format(recipe.NameKey) else state.orderRecipeId

	local stageColor = if state.orderStatus == "Failed"
		then Colors.Bad
		elseif state.orderStatus == "Delivered" or state.orderStatus == "Prepared" then Colors.Good
		else Colors.Text
	card.statusLabel.Text = Strings.format(`Hud.Order.Status.{state.orderStatus}`)
	card.statusLabel.TextColor3 = stageColor

	local cooking = state.orderStatus == "Preparing"
	card.progressTrack.Visible = cooking
	if cooking and card.cookingStartedAt then
		local duration: number = Config.get("Kitchen", "PrepareDuration")
		local ratio = if duration > 0 then math.clamp((os.clock() - card.cookingStartedAt) / duration, 0, 1) else 1
		card.progressFill.Size = UDim2.fromScale(ratio, 1)
	end

	if recipe then
		local parts = {}
		for resource, amount in recipe.Ingredients do
			table.insert(parts, `{amount}× {Strings.format(`Resource.{resource}`)}`)
		end
		card.ingredientsLabel.Text = table.concat(parts, ", ")
	else
		card.ingredientsLabel.Text = ""
	end
end

local function refreshOrders()
	local state = GameplayStateClient.get()
	if state.orderStatus == "" then
		if activeOrderKey then
			finalizedKeys[activeOrderKey] = nil
			removeOrderCard(activeOrderKey)
			activeOrderKey = nil
		end
		return
	end

	if activeOrderKey == nil then
		orderSeq += 1
		activeOrderKey = `Order{orderSeq}`
	end
	local key = activeOrderKey :: string
	if finalizedKeys[key] then
		return -- déjà livrée/ratée et déjà retirée : rien à refaire tant que le serveur ne revient
		-- pas à "" (voir le commentaire sur activeOrderKey plus haut).
	end

	local card = orderCards[key]
	if card == nil then
		card = buildOrderCard(orderSeq)
		orderCards[key] = card
	end
	updateOrderCard(card, state)

	if state.orderStatus == "Delivered" or state.orderStatus == "Failed" then
		finalizedKeys[key] = true
		task.delay(Config.get("Ui", "OrderCardLinger"), function()
			removeOrderCard(key)
		end)
	end
end

-- Fil de notifications (en bas à gauche) ---------------------------------------------------

local feed = UiKit.frame(screen, "Feed", UDim2.fromScale(0.36, 0.3), UDim2.new(0, 12, 1, -12), Vector2.new(0, 1))
feed.BackgroundTransparency = 1
UiKit.sizeLimits(feed, Vector2.new(240, 100), Vector2.new(520, 260))
local feedLayout = UiKit.list(feed, 4)
feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

local feedOrder = 0

local function push(text: string)
	feedOrder += 1
	local entry = UiKit.label(feed, "Entry", text, UDim2.new(1, 0, 0, 0), {
		align = Enum.TextXAlignment.Left,
		autoHeight = true,
		textSize = 16,
		background = true,
	})
	entry.LayoutOrder = feedOrder
	UiKit.corner(entry, 6)
	UiKit.padding(entry, 4)

	local entries: { TextLabel } = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a: TextLabel, b: TextLabel): boolean
		return a.LayoutOrder < b.LayoutOrder
	end)
	local limit: number = Config.get("Ui", "NotificationMax")
	while #entries > limit do
		local oldest = table.remove(entries, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(Config.get("Ui", "NotificationLifetime"), function()
		if entry.Parent == nil then
			return
		end
		local fade =
			TweenService:Create(entry, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			entry:Destroy()
		end)
		fade:Play()
	end)
end

local function textFor(kind: string, params: { [string]: any }): string?
	local key = `Notify.{kind}`
	if kind == "PhaseStarted" then
		key = `Notify.PhaseStarted.{tostring(params.phase)}`
	elseif kind == "StatusChanged" then
		key = `Notify.StatusChanged.{tostring(params.status)}`
	elseif kind == "MatchEnded" then
		key = `Notify.MatchEnded.{tostring(params.result)}`
	end
	if not Strings.has(key) then
		return nil
	end
	return Strings.format(key, params)
end

-- Branchements ------------------------------------------------------------------------------

for _, kind in FEED_KINDS do
	NetClient.onNotify(kind, function(params: { [string]: any })
		local text = textFor(kind, params)
		if text then
			push(text)
		end
	end)
end

Players.PlayerAdded:Connect(function(player: Player)
	watch(player)
	rebuildTeam(nil)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	local connection = statusConnections[player]
	if connection then
		connection:Disconnect()
		statusConnections[player] = nil
	end
	rebuildTeam(player)
end)
for _, player in Players:GetPlayers() do
	watch(player)
end
rebuildTeam(nil)

GameplayStateClient.Changed:Connect(refreshHealth)
GameplayStateClient.Changed:Connect(refreshOrders)
refreshHealth()
refreshOrders()

MatchStateClient.Changed:Connect(refreshTop)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= REFRESH_INTERVAL then
		elapsed = 0
		refreshTop()
		-- Anime la barre de progression pendant la cuisson : pas d'événement Changed dédié, donc
		-- un rafraîchissement périodique est nécessaire pour que la barre avance visuellement.
		refreshOrders()
	end
end)
refreshTop()
