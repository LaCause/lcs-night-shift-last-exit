--!strict
-- Progression de la réparation du bus, affichée au-dessus du bus (amélioration visuelle, même
-- principe que FuelGaugeController). Masquée tant que la réparation n'a pas commencé et que
-- l'Évasion n'est pas en cours, pour ne pas encombrer la vue en dehors des nuits où ça compte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
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
	gui.Size = UDim2.fromOffset(170, 78)
	gui.StudsOffsetWorldSpace = OFFSET
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.Enabled = false
	gui.Parent = busSpot

	local status = UiKit.label(gui, "Status", "", UDim2.new(1, 0, 0, 20), { textSize = 15 })

	local track, fill = UiKit.bar(gui, "Track", UDim2.new(1, 0, 0, 14), UDim2.fromScale(0, 0.6))
	UiKit.corner(track, 6)
	UiKit.corner(fill, 6)

	-- 007-nuits-optionnelles-evasion : options partir/rester, affichées sous la barre une fois
	-- le bus réparé (data-model.md, « Choix d'évasion » — dérivé, rien de nouveau à répliquer).
	local departOption = UiKit.label(gui, "DepartOption", "", UDim2.new(1, 0, 0, 18), {
		textSize = 13,
		position = UDim2.fromScale(0, 0.78),
	})
	local stayOption = UiKit.label(gui, "StayOption", "", UDim2.new(1, 0, 0, 18), {
		textSize = 13,
		position = UDim2.fromScale(0, 1),
	})

	local function refresh()
		local state = GameplayStateClient.get()
		local matchPhase = MatchStateClient.get().phase
		local night = MatchStateClient.get().night
		local showBus = state.busDeposited > 0 or (state.busRequired > 0 and matchPhase == "Escape")
		gui.Enabled = showBus or state.busRepaired

		if state.busRepaired then
			status.Text = Strings.format("Hud.Bus.Repaired")
			status.TextColor3 = UiKit.Colors.Good
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = UiKit.Colors.Good

			local perNight: number = Config.get("Currency", "EscapeBonusPerNight")
			departOption.Text = Strings.format("Hud.Escape.Depart", { amount = perNight * night })
			departOption.TextColor3 = UiKit.Colors.Text
			if matchPhase == "Escape" then
				stayOption.Text = Strings.format("Hud.Escape.Stay", { amount = perNight * (night + 1) })
				stayOption.TextColor3 = UiKit.Colors.Cyan
			else
				stayOption.Text = ""
			end
			return
		end

		departOption.Text = ""
		stayOption.Text = ""
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
