--!strict
-- Flash d'écran bref sur les événements d'équipe (commande, générateur) : même principe
-- qu'EnemyEffectController (FR-018), généralisé aux autres notifications diffusées de
-- 002-premier-increment-jouable. Purement local, rien n'est renvoyé au serveur.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local Colors = UiKit.Colors

type FlashDef = { color: Color3, peak: number, duration: number }

-- `peak` : transparence juste après le flash (plus bas = plus visible) ; `duration` : temps du
-- retour au transparent. Des valeurs discrètes : ce sont des accents, pas des écrans de dégâts.
local FLASHES: { [string]: FlashDef } = {
	OrderStarted = { color = Colors.Warn, peak = 0.8, duration = 0.6 },
	OrderPrepared = { color = Colors.Cyan, peak = 0.82, duration = 0.5 },
	OrderDelivered = { color = Colors.Good, peak = 0.72, duration = 0.6 },
	OrderFailed = { color = Color3.fromRGB(200, 40, 40), peak = 0.58, duration = 0.7 },
	GeneratorEmpty = { color = Color3.fromRGB(210, 100, 20), peak = 0.68, duration = 0.6 },
	GeneratorRefueled = { color = Colors.Cyan, peak = 0.82, duration = 0.5 },
}

local FeedbackFxController = { Name = "FeedbackFxController", Priority = 57 }

function FeedbackFxController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "FeedbackFx"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 19
	screen.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = screen

	for kind, def in FLASHES do
		NetClient.onNotify(kind, function()
			flash.BackgroundColor3 = def.color
			flash.BackgroundTransparency = def.peak
			TweenService:Create(flash, TweenInfo.new(def.duration), { BackgroundTransparency = 1 }):Play()
		end)
	end
end

return FeedbackFxController
