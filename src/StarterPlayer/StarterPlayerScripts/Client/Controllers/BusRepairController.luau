--!strict
-- Progression de la réparation du bus, affichée au-dessus du bus (amélioration visuelle, même
-- principe que FuelGaugeController). Masquée tant que la réparation n'a pas commencé et que
-- l'Évasion n'est pas en cours, pour ne pas encombrer la vue en dehors des nuits où ça compte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local RefPoints = require(Shared:WaitForChild("World"):WaitForChild("RefPoints") :: ModuleScript)
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local MatchStateClient = require(ClientFolder:WaitForChild("MatchStateClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local WAIT_TIMEOUT = 30
local OFFSET = Vector3.new(0, 8, 0)
local MAX_DISTANCE = 55

local BusRepairController = { Name = "BusRepairController", Priority = 59 }

function BusRepairController.Start()
	local busSpot = RefPoints.waitFor("BusSpot", WAIT_TIMEOUT)
	if busSpot == nil then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "BusRepairGauge"
	gui.Size = UDim2.fromOffset(170, 46)
	gui.StudsOffsetWorldSpace = OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.Enabled = false
	gui.Parent = busSpot

	local status = UiKit.label(gui, "Status", "", UDim2.new(1, 0, 0, 20), { textSize = 15 })

	local track, fill = UiKit.bar(gui, "Track", UDim2.new(1, 0, 0, 14), UDim2.fromScale(0, 0.6))
	UiKit.corner(track, 6)
	UiKit.corner(fill, 6)

	local function refresh()
		local state = GameplayStateClient.get()
		local matchPhase = MatchStateClient.get().phase
		local showBus = state.busDeposited > 0 or (state.busRequired > 0 and matchPhase == "Escape")
		gui.Enabled = showBus or state.busRepaired

		if state.busRepaired then
			status.Text = Strings.format("Hud.Bus.Repaired")
			status.TextColor3 = UiKit.Colors.Good
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = UiKit.Colors.Good
			return
		end

		status.Text =
			Strings.format("Hud.Bus.Progress", { deposited = state.busDeposited, required = state.busRequired })
		status.TextColor3 = UiKit.Colors.Text
		local ratio = if state.busRequired > 0 then math.clamp(state.busDeposited / state.busRequired, 0, 1) else 0
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = UiKit.Colors.Cyan
	end

	GameplayStateClient.Changed:Connect(refresh)
	MatchStateClient.Changed:Connect(refresh)
	refresh()
end

return BusRepairController
