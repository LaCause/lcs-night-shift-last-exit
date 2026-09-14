--!strict
-- Retour visible immédiat au contact de l'ennemi (FR-018) : flash rouge plein écran à la
-- réception de la notification ciblée EnemyHit. Purement local, rien n'est renvoyé au serveur.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NetClient = require(Shared:WaitForChild("Client"):WaitForChild("NetClient") :: ModuleScript)

local FLASH_COLOR = Color3.fromRGB(180, 30, 30)

local EnemyEffectController = { Name = "EnemyEffectController", Priority = 55 }

function EnemyEffectController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "EnemyEffect"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 20
	screen.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = FLASH_COLOR
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = screen

	NetClient.onNotify("EnemyHit", function()
		flash.BackgroundTransparency = 0.55
		TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end)
end

return EnemyEffectController
