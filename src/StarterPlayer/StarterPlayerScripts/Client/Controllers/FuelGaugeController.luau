--!strict
-- Jauge de carburant et statut de la zone sûre, affichés au-dessus du générateur (amélioration
-- visuelle : l'info vit à l'endroit concerné plutôt que dans un coin d'écran fixe). La zone sûre
-- est directement dérivée du carburant (GeneratorService.isSafeZoneActive : active dès que
-- fuel > 0), donc les deux tiennent dans le même écriteau plutôt que deux panneaux superposés.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local RefPoints = require(Shared:WaitForChild("World"):WaitForChild("RefPoints") :: ModuleScript)
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local WAIT_TIMEOUT = 30
local OFFSET = Vector3.new(0, 6, 0)
local MAX_DISTANCE = 55

local FuelGaugeController = { Name = "FuelGaugeController", Priority = 58 }

function FuelGaugeController.Start()
	local generator = RefPoints.waitFor("Generator", WAIT_TIMEOUT)
	if generator == nil then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FuelGauge"
	gui.Size = UDim2.fromOffset(150, 58)
	gui.StudsOffsetWorldSpace = OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.Parent = generator

	UiKit.label(gui, "Title", Strings.format("Hud.Fuel"), UDim2.new(1, 0, 0, 20), {
		font = UiKit.Fonts.Title,
		color = UiKit.Colors.Cyan,
		maxSize = 18,
	})

	local track, fill = UiKit.bar(gui, "Track", UDim2.new(1, 0, 0, 14), UDim2.fromScale(0, 0.42))
	UiKit.corner(track, 6)
	UiKit.corner(fill, 6)

	local status = UiKit.label(gui, "Status", "", UDim2.new(1, 0, 0, 16), {
		position = UDim2.fromScale(0, 0.72),
		textSize = 13,
	})

	local function refresh()
		local state = GameplayStateClient.get()
		local ratio = if state.fuelCapacity > 0 then math.clamp(state.fuel / state.fuelCapacity, 0, 1) else 0
		local color = if state.safeZoneActive then UiKit.Colors.Good else UiKit.Colors.Bad
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = color
		status.Text = Strings.format(if state.safeZoneActive then "Hud.SafeZone.Active" else "Hud.SafeZone.Inactive")
		status.TextColor3 = color
	end

	GameplayStateClient.Changed:Connect(refresh)
	refresh()
end

return FuelGaugeController
