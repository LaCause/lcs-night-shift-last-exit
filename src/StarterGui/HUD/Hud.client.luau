--!strict
-- HUD (FR-035, FR-036) : phase, nuit, temps restant, équipe et fil de notifications.
-- N'affiche que l'état répliqué par le serveur (principe III).
--
-- Disposition : bandeau en haut au centre, colonne équipe + ressources à droite, fil de
-- notifications en bas à gauche. Le coin haut gauche reste libre pour le chat Roblox et le
-- panneau de dev de Studio (DevPanel.client.luau).

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

local screen = script.Parent :: ScreenGui
local Colors = UiKit.Colors

local REFRESH_INTERVAL = 0.1 -- 10 Hz au plus
local ROW_TEXT_SIZE = 16
local FEED_KINDS = {
	"PhaseStarted",
	"PlayerJoined",
	"PlayerLeft",
	"StatusChanged",
	"BellRang",
	"MatchEnded",
	"OrderPrepared",
	"BusRepaired",
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

-- Équipe ------------------------------------------------------------------------------------

local teamPanel = sidePanel("Team", 1)
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

-- Ressources et jauges du joueur (002-premier-increment-jouable) ------------------------------

local gameplayPanel = sidePanel("Gameplay", 2)
panelTitle(gameplayPanel, Strings.format("Hud.Resources"))

local gameplayRows: { [string]: TextLabel } = {}

-- Une ligne par clé, créée au premier appel puis seulement mise à jour.
local function gameplayRow(key: string, order: number): TextLabel
	local row = gameplayRows[key]
	if row == nil then
		row = panelRow(gameplayPanel, key, "")
		row.LayoutOrder = order
		gameplayRows[key] = row
	end
	return row
end

-- Petit « coup de pouce » visuel (FR-035/FR-036, retour immédiat) : la ligne bascule dans une
-- couleur d'accent puis retourne à sa couleur normale, sans dépendre d'une notification réseau —
-- ça marche même si Notify arrive dans un ordre différent de Changed.
local previousGameplay: { [string]: number } = {}
local activeTweens: { [TextLabel]: Tween } = {}

local function punch(row: TextLabel, accent: Color3, steady: Color3)
	local existing = activeTweens[row]
	if existing then
		existing:Cancel()
	end
	row.TextColor3 = accent
	local tween = TweenService:Create(row, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { TextColor3 = steady })
	activeTweens[row] = tween
	tween.Completed:Connect(function()
		if activeTweens[row] == tween then
			activeTweens[row] = nil
		end
	end)
	tween:Play()
end

-- Punch sur tout changement (récolte = gain, dépôt/ravitaillement = perte utile : les deux sont
-- une action réussie, donc le même accent positif dans les deux sens).
local function punchOnChange(key: string, row: TextLabel, value: number, steady: Color3)
	local previous = previousGameplay[key]
	if previous ~= nil and value ~= previous then
		punch(row, Colors.Good, steady)
	end
	previousGameplay[key] = value
end

-- Punch seulement à la hausse (santé) ou (carburant) : une baisse de carburant par la
-- consommation normale ne doit pas clignoter à chaque seconde.
local function punchOnRise(key: string, row: TextLabel, value: number, steady: Color3)
	local previous = previousGameplay[key]
	if previous ~= nil and value > previous then
		punch(row, Colors.Good, steady)
	end
	previousGameplay[key] = value
end

local function refreshGameplay()
	local state = GameplayStateClient.get()
	local healthRow = gameplayRow("Health", 1)
	healthRow.Text = `{Strings.format("Hud.Health")} : {math.floor(state.health)}/{math.floor(state.maxHealth)}`
	local healthColor = if state.health <= state.maxHealth * 0.3 then Colors.Bad else Colors.Text
	healthRow.TextColor3 = healthColor
	local previousHealth = previousGameplay.Health
	if previousHealth ~= nil and state.health ~= previousHealth then
		punch(healthRow, if state.health > previousHealth then Colors.Good else Colors.Bad, healthColor)
	end
	previousGameplay.Health = state.health

	local essenceRow = gameplayRow("Essence", 2)
	essenceRow.Text = `{Strings.format("Resource.Essence")} : {state.essence}`
	punchOnChange("Essence", essenceRow, state.essence, Colors.Text)

	local steakRow = gameplayRow("SuspectSteak", 3)
	steakRow.Text = `{Strings.format("Resource.SuspectSteak")} : {state.suspectSteak}`
	punchOnChange("SuspectSteak", steakRow, state.suspectSteak, Colors.Text)

	local breadRow = gameplayRow("RoadBread", 4)
	breadRow.Text = `{Strings.format("Resource.RoadBread")} : {state.roadBread}`
	punchOnChange("RoadBread", breadRow, state.roadBread, Colors.Text)

	local scrapRow = gameplayRow("Scrap", 5)
	scrapRow.Text = `{Strings.format("Resource.Scrap")} : {state.scrap}`
	punchOnChange("Scrap", scrapRow, state.scrap, Colors.Text)

	local fuelRow = gameplayRow("Fuel", 6)
	fuelRow.Text = `{Strings.format("Hud.Fuel")} : {math.floor(state.fuel)}/{math.floor(state.fuelCapacity)}`
	local fuelColor = if state.safeZoneActive then Colors.Good else Colors.Bad
	fuelRow.TextColor3 = fuelColor
	punchOnRise("Fuel", fuelRow, state.fuel, fuelColor)

	gameplayRow("SafeZone", 7).Text =
		Strings.format(if state.safeZoneActive then "Hud.SafeZone.Active" else "Hud.SafeZone.Inactive")

	local orderRow = gameplayRow("Order", 8)
	if state.orderStatus == "" then
		orderRow.Text = Strings.format("Hud.Order.None")
	else
		local recipe = GameplayStateClient.getOrderRecipe()
		local recipeName = if recipe then Strings.format(recipe.NameKey) else state.orderRecipeId
		orderRow.Text = Strings.format("Hud.Order.Active", {
			recipe = recipeName,
			status = Strings.format(`Hud.Order.Status.{state.orderStatus}`),
		})
	end

	local ingredientsRow = gameplayRow("OrderIngredients", 9)
	local recipe = if state.orderStatus == "" then nil else GameplayStateClient.getOrderRecipe()
	if recipe == nil then
		ingredientsRow.Text = ""
	else
		local parts = {}
		for resource, amount in recipe.Ingredients do
			table.insert(parts, `{amount}× {Strings.format(`Resource.{resource}`)}`)
		end
		ingredientsRow.Text = table.concat(parts, ", ")
	end
	-- Une ligne vide garderait sa hauteur dans la liste : on la masque.
	ingredientsRow.Visible = ingredientsRow.Text ~= ""

	-- Bus (003-bus-evasion, FR-006) : visible dès le premier dépôt ou dès l'Évasion en cours.
	local busRow = gameplayRow("Bus", 10)
	local matchPhase = MatchStateClient.get().phase
	local showBus = state.busDeposited > 0 or state.busRequired > 0 and matchPhase == "Escape"
	if state.busRepaired then
		busRow.Text = Strings.format("Hud.Bus.Repaired")
		busRow.TextColor3 = Colors.Good
	else
		busRow.Text =
			Strings.format("Hud.Bus.Progress", { deposited = state.busDeposited, required = state.busRequired })
		busRow.TextColor3 = Colors.Text
	end
	punchOnChange("BusDeposited", busRow, state.busDeposited, if state.busRepaired then Colors.Good else Colors.Text)
	busRow.Visible = showBus or state.busRepaired
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

GameplayStateClient.Changed:Connect(refreshGameplay)
refreshGameplay()

MatchStateClient.Changed:Connect(refreshTop)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= REFRESH_INTERVAL then
		elapsed = 0
		refreshTop()
	end
end)
refreshTop()
