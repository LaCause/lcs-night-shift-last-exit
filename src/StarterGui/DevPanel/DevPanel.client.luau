--!strict
-- Panneau de développement, Studio uniquement (FR-042, FR-043) : commandes Dev.*, ligne d'état,
-- rapports du serveur et liste de contrôle des requêtes invalides (contracts/network.md, SC-006).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local screen = script.Parent :: ScreenGui

if not RunService:IsStudio() then
	screen:Destroy()
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local RefPoints = require(Shared:WaitForChild("World"):WaitForChild("RefPoints") :: ModuleScript)
local MatchStateClient = require(ClientFolder:WaitForChild("MatchStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

type Case = {
	number: number,
	label: string,
	expected: string,
	burst: boolean?,
	send: (remote: RemoteEvent) -> (),
}

type Pending = { cases: { Case }, notes: { string } }

local Colors = UiKit.Colors
local EXPANDED_SIZE = UDim2.fromOffset(280, 540)
local COLLAPSED_SIZE = UDim2.fromOffset(280, 44)
-- Doit correspondre au titre du rapport Dev.GetRejections (DevService.luau).
local REJECTIONS_TITLE = "Refus récents"
local BURST_SIZE = 30
local BURST_MIN_LIMITED = 20

-- Construction du panneau --------------------------------------------------------------------

local root = UiKit.frame(screen, "Root", EXPANDED_SIZE, UDim2.new(0, 12, 0, 60))
UiKit.corner(root, 10)
UiKit.stroke(root, Colors.Neon, 1.5)
UiKit.padding(root, 8)

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, 36)
body.Size = UDim2.new(1, 0, 1, -36)
body.Parent = root

local expanded = true
local header = UiKit.button(root, "Header", `{Strings.format("Dev.Title")} ▾`, function()
	expanded = not expanded
	body.Visible = expanded
	root.Size = if expanded then EXPANDED_SIZE else COLLAPSED_SIZE
end)
header.Size = UDim2.new(1, 0, 0, 28)

local stateLabel = UiKit.label(body, "State", "", UDim2.new(1, 0, 0, 36), {
	color = Colors.Muted,
	align = Enum.TextXAlignment.Left,
	minSize = 14,
	maxSize = 15,
})

local grid = Instance.new("Frame")
grid.Name = "Buttons"
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(0, 42)
grid.Size = UDim2.new(1, 0, 0, 216)
grid.Parent = body
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -4, 0, 30)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local contextBox = Instance.new("TextBox")
contextBox.Name = "RngContext"
contextBox.Position = UDim2.fromOffset(0, 264)
contextBox.Size = UDim2.new(1, 0, 0, 28)
contextBox.BackgroundColor3 = Colors.Ink
contextBox.BorderSizePixel = 0
contextBox.ClearTextOnFocus = false
contextBox.Font = UiKit.Fonts.Mono
contextBox.PlaceholderText = Strings.format("Dev.ContextPlaceholder")
contextBox.Text = "test"
contextBox.TextColor3 = Colors.Text
contextBox.TextSize = 14
contextBox.Parent = body
UiKit.corner(contextBox, 6)

local report = Instance.new("ScrollingFrame")
report.Name = "Report"
report.Position = UDim2.fromOffset(0, 300)
report.Size = UDim2.new(1, 0, 1, -300)
report.BackgroundColor3 = Colors.Ink
report.BackgroundTransparency = 0.2
report.BorderSizePixel = 0
report.ScrollBarThickness = 4
report.AutomaticCanvasSize = Enum.AutomaticSize.Y
report.CanvasSize = UDim2.new()
report.Parent = body
UiKit.corner(report, 6)
UiKit.padding(report, 6)
UiKit.list(report, 2)

local function showReport(title: string, lines: { string })
	for _, child in report:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local order = 0
	local function addLine(text: string, color: Color3, font: Enum.Font)
		order += 1
		local line = UiKit.label(report, "Line", text, UDim2.new(1, -4, 0, 0), {
			align = Enum.TextXAlignment.Left,
			autoHeight = true,
			textSize = 14,
			color = color,
			font = font,
		})
		line.LayoutOrder = order
	end
	addLine(title, Colors.Cyan, UiKit.Fonts.Title)
	for _, text in lines do
		addLine(text, Colors.Text, UiKit.Fonts.Body)
	end
end

local function send(action: string, payload: { [string]: any })
	task.spawn(NetClient.send, action, payload)
end

-- Liste de contrôle des requêtes invalides ------------------------------------------------------

local pending: Pending? = nil

local function distanceToBell(): number?
	local character = Players.LocalPlayer.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local bell = RefPoints.find("CounterBell")
	if rootPart == nil or bell == nil or not rootPart:IsA("BasePart") then
		return nil
	end
	return (rootPart.Position - bell.Position).Magnitude
end

local function ringBell(remote: RemoteEvent)
	remote:FireServer("RingBell", { target = "CounterBell" })
end

local function buildCases(): ({ Case }, { string })
	local phase = MatchStateClient.get().phase
	local playable = phase == "Countdown" or phase == "Day" or phase == "Night" or phase == "Escape"
	local notes: { string } = {}
	local cases: { Case } = {
		{
			number = 1,
			label = "action non-chaîne",
			expected = "BadEnvelope",
			send = function(remote)
				remote:FireServer(42, {})
			end,
		},
		{
			number = 2,
			label = "action inconnue",
			expected = "UnknownAction",
			send = function(remote)
				remote:FireServer("Nope", {})
			end,
		},
		{
			number = 3,
			label = "payload non-table",
			expected = "BadEnvelope",
			send = function(remote)
				remote:FireServer("RingBell", "x")
			end,
		},
		{
			number = 4,
			label = "clé inconnue",
			expected = "BadPayload",
			send = function(remote)
				remote:FireServer("RingBell", { target = "CounterBell", extra = 1 })
			end,
		},
		{
			number = 5,
			label = "chaîne trop longue",
			expected = "BadPayload",
			send = function(remote)
				remote:FireServer("RingBell", { target = string.rep("a", 500) })
			end,
		},
		{
			number = 6,
			label = "nombre non fini",
			expected = "BadPayload",
			send = function(remote)
				remote:FireServer("Dev.SampleRng", { context = "x", count = 0 / 0 })
			end,
		},
	}

	if playable then
		table.insert(cases, {
			number = 7,
			label = "cible inexistante",
			expected = "TargetMissing",
			send = function(remote)
				remote:FireServer("RingBell", { target = "Nowhere" })
			end,
		})
		local range = Config.get("Bell", "Range") + Config.get("Net", "DistanceTolerance")
		local distance = distanceToBell()
		if distance ~= nil and distance > range then
			table.insert(cases, { number = 8, label = "trop loin", expected = "TooFar", send = ringBell })
		else
			table.insert(notes, "Cas 8 ignoré : se placer au point d'apparition, hors de portée de la sonnette")
		end
	else
		table.insert(notes, "Cas 7 et 8 : à lancer pendant une phase de jeu")
	end

	if phase == "Ended" then
		table.insert(cases, { number = 10, label = "phase interdite", expected = "WrongPhase", send = ringBell })
	else
		table.insert(notes, "Cas 10 : à relancer pendant l'écran de fin")
	end

	-- La rafale part en dernier : elle vide le seau à jetons.
	table.insert(cases, {
		number = 9,
		label = `rafale de {BURST_SIZE} pings`,
		expected = "RateLimited",
		burst = true,
		send = function(remote)
			for _ = 1, BURST_SIZE do
				remote:FireServer("Dev.Ping", {})
			end
		end,
	})
	return cases, notes
end

local function evaluate(lines: { string })
	local current = pending
	pending = nil
	if current == nil then
		return
	end

	local codes: { string } = {}
	for _, line in lines do
		local code = string.match(line, "^(%a+) · ")
		if code then
			table.insert(codes, code)
		end
	end

	-- Les refus sont chronologiques : la rafale occupe la fin, les cas unitaires la précèdent.
	local limited = 0
	local cursor = #codes
	while cursor >= 1 and codes[cursor] == "RateLimited" do
		limited += 1
		cursor -= 1
	end
	local singles: { Case } = {}
	for _, case in current.cases do
		if not case.burst then
			table.insert(singles, case)
		end
	end
	local first = cursor - #singles + 1

	local results: { [number]: string } = {}
	local passed = 0
	for position, case in singles do
		local got = codes[first + position - 1] or "aucun refus"
		local ok = got == case.expected
		if ok then
			passed += 1
		end
		local detail = if ok then case.expected else `attendu {case.expected}, obtenu {got}`
		results[case.number] = `{if ok then "✅" else "❌"} {case.number}. {case.label} : {detail}`
	end
	for _, case in current.cases do
		if case.burst then
			local ok = limited >= BURST_MIN_LIMITED
			if ok then
				passed += 1
			end
			results[case.number] =
				`{if ok then "✅" else "❌"} {case.number}. {case.label} : {limited} × RateLimited (≥ {BURST_MIN_LIMITED})`
		end
	end

	local summary = { `{passed}/{#current.cases} cas conformes` }
	for number = 1, 10 do
		local line = results[number]
		if line then
			table.insert(summary, line)
		end
	end
	for _, note in current.notes do
		table.insert(summary, `ℹ️ {note}`)
	end
	showReport(Strings.format("Dev.Checklist"), summary)
end

local function runChecklist()
	local remote = NetClient.rawIntent()
	if remote == nil then
		showReport(Strings.format("Dev.Checklist"), { "Remote Intent introuvable" })
		return
	end
	showReport(Strings.format("Dev.Checklist"), { "Préparation : le seau à jetons se remplit…" })
	task.wait(2.5)
	local cases, notes = buildCases()
	for _, case in cases do
		case.send(remote)
	end
	pending = { cases = cases, notes = notes }
	showReport(Strings.format("Dev.Checklist"), { "Requêtes envoyées, lecture des refus…" })
	task.wait(3)
	NetClient.send("Dev.GetRejections", { count = 50 })
end

-- Boutons ------------------------------------------------------------------------------------

local buttonOrder = 0
local function addButton(key: string, onClick: () -> ())
	buttonOrder += 1
	local button = UiKit.button(grid, key, Strings.format(key), onClick)
	button.LayoutOrder = buttonOrder
end

addButton("Dev.Ping", function()
	send("Dev.Ping", {})
	showReport(Strings.format("Dev.Ping"), { "Envoyé (sans effet côté serveur)" })
end)
addButton("Dev.NextPhase", function()
	send("Dev.NextPhase", {})
end)
addButton("Dev.TestProfile", function()
	send("Dev.SetTestProfile", { enabled = not MatchStateClient.get().testProfile })
end)
addButton("Dev.Victory", function()
	send("Dev.EndMatch", { result = "Victory" })
end)
addButton("Dev.Defeat", function()
	send("Dev.EndMatch", { result = "Defeat" })
end)
addButton("Dev.Eliminate", function()
	send("Dev.SetStatus", { status = "Eliminated" })
end)
addButton("Dev.Revive", function()
	send("Dev.SetStatus", { status = "Alive" })
end)
addButton("Dev.ShowState", function()
	send("Dev.ShowState", {})
end)
addButton("Dev.SampleRng", function()
	local context = if contextBox.Text ~= "" then contextBox.Text else "test"
	send("Dev.SampleRng", { context = context, count = 5 })
end)
addButton("Dev.VisualFallback", function()
	send("Dev.TestVisualFallback", {})
end)
addButton("Dev.Checklist", function()
	task.spawn(runChecklist)
end)

-- Rapports et ligne d'état ------------------------------------------------------------------

NetClient.onNotify("DevReport", function(params: { [string]: any })
	local title = if typeof(params.title) == "string" then params.title else "Rapport"
	local lines: { string } = {}
	if typeof(params.lines) == "table" then
		for _, line in params.lines do
			table.insert(lines, tostring(line))
		end
	end
	if pending ~= nil and title == REJECTIONS_TITLE then
		evaluate(lines)
	else
		showReport(title, lines)
	end
end)

local function formatClock(seconds: number?): string
	if seconds == nil then
		return "∞"
	end
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local state = MatchStateClient.get()
	stateLabel.Text = Strings.format("Dev.State", {
		phase = state.phase,
		night = state.night,
		totalNights = state.totalNights,
		time = formatClock(MatchStateClient.remaining()),
		testProfile = if state.testProfile then "oui" else "non",
	})
end)

showReport(Strings.format("Dev.Title"), { "Panneau visible uniquement dans Studio." })
