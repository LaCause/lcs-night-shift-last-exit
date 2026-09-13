--!strict
-- Écran de fin (FR-028) : résultat, nuit atteinte et compte à rebours avant la nouvelle partie.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local MatchStateClient = require(ClientFolder:WaitForChild("MatchStateClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local screen = script.Parent :: ScreenGui
screen.IgnoreGuiInset = true
local Colors = UiKit.Colors

local overlay = UiKit.frame(screen, "Overlay", UDim2.fromScale(1, 1))
overlay.BackgroundColor3 = Colors.Ink
overlay.BackgroundTransparency = 0.3
overlay.Visible = false

local card = UiKit.frame(overlay, "Card", UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
UiKit.sizeLimits(card, Vector2.new(300, 180), Vector2.new(640, 320))
UiKit.corner(card, 16)
local cardStroke = UiKit.stroke(card, Colors.Neon, 3)
UiKit.padding(card, 12)

local title = UiKit.label(card, "Result", "", UDim2.fromScale(1, 0.5), {
	font = UiKit.Fonts.Title,
	minSize = 24,
	maxSize = 64,
})
local nightLine = UiKit.label(card, "Night", "", UDim2.fromScale(1, 0.22), {
	position = UDim2.fromScale(0, 0.52),
	color = Colors.Muted,
	maxSize = 26,
})
local countdown = UiKit.label(card, "Countdown", "", UDim2.fromScale(1, 0.22), {
	position = UDim2.fromScale(0, 0.76),
	color = Colors.Cyan,
	font = UiKit.Fonts.Mono,
	maxSize = 24,
})

local function refresh()
	local state = MatchStateClient.get()
	local visible = state.phase == "Ended"
	overlay.Visible = visible
	if not visible then
		return
	end
	local victory = state.result == "Victory"
	local accent = if victory then Colors.Good else Colors.Bad
	title.Text = Strings.format(if victory then "End.Victory" else "End.Defeat")
	title.TextColor3 = accent
	cardStroke.Color = accent
	nightLine.Text = Strings.format("End.NightReached", { night = state.night, totalNights = state.totalNights })
	local remaining = MatchStateClient.remaining()
	countdown.Text = Strings.format("End.NextMatch", { seconds = if remaining then math.ceil(remaining) else 0 })
end

MatchStateClient.Changed:Connect(refresh)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= 0.2 then
		elapsed = 0
		if overlay.Visible then
			refresh()
		end
	end
end)
refresh()
