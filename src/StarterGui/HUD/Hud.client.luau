--!strict
-- HUD (FR-035, FR-036) : phase, nuit, temps restant, équipe et fil de notifications.
-- N'affiche que l'état répliqué par le serveur (principe III).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local MatchStateClient = require(ClientFolder:WaitForChild("MatchStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local screen = script.Parent :: ScreenGui
local Colors = UiKit.Colors

local REFRESH_INTERVAL = 0.1 -- 10 Hz au plus
local FEED_KINDS = { "PhaseStarted", "PlayerJoined", "PlayerLeft", "StatusChanged", "BellRang", "MatchEnded" }
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

-- Équipe (à droite) -------------------------------------------------------------------------

local teamPanel = UiKit.frame(screen, "Team", UDim2.fromScale(0.2, 0.34), UDim2.new(1, -12, 0, 8), Vector2.new(1, 0))
UiKit.sizeLimits(teamPanel, Vector2.new(170, 110), Vector2.new(260, 300))
UiKit.corner(teamPanel, 10)
UiKit.padding(teamPanel, 8)
UiKit.list(teamPanel, 4)

local teamTitle = UiKit.label(teamPanel, "Title", Strings.format("Hud.Team"), UDim2.new(1, 0, 0, 24), {
	font = UiKit.Fonts.Title,
	color = Colors.Cyan,
	align = Enum.TextXAlignment.Left,
	maxSize = 20,
})
teamTitle.LayoutOrder = 0

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
		local row = UiKit.label(teamPanel, "Row", `● {player.DisplayName} — {status}`, UDim2.new(1, 0, 0, 22), {
			color = if alive then Colors.Good else Colors.Bad,
			align = Enum.TextXAlignment.Left,
			maxSize = 18,
		})
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
		local fade = TweenService:Create(entry, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 })
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
