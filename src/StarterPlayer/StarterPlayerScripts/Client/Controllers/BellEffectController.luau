--!strict
-- Effet local de la sonnette : flash néon et petit rebond à chaque sonnerie acceptée par le
-- serveur (changement de l'attribut LastRungAt). Purement visuel, rien n'est renvoyé au serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local RefPoints = require(Shared:WaitForChild("World"):WaitForChild("RefPoints") :: ModuleScript)

local FLASH_COLOR = Color3.fromRGB(70, 235, 255)
local WAIT_TIMEOUT = 30

local log = Log.new("BellEffect")

local BellEffectController = { Name = "BellEffectController", Priority = 50 }

function BellEffectController.Start()
	local bell = RefPoints.waitFor("CounterBell", WAIT_TIMEOUT)
	if bell == nil then
		log:warn("Sonnette introuvable : effet désactivé")
		return
	end
	local baseColor = bell.Color
	local baseCFrame = bell.CFrame
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

	bell:GetAttributeChangedSignal("LastRungAt"):Connect(function()
		bell.Color = baseColor
		bell.CFrame = baseCFrame
		TweenService:Create(bell, info, { Color = FLASH_COLOR, CFrame = baseCFrame * CFrame.new(0, 0.35, 0) }):Play()
	end)
end

return BellEffectController
