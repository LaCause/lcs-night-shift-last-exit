--!strict
-- Utiliser une trousse de soins du sac (009-craft-etabli) : la touche H envoie l'intention
-- UseHealKit. Le client n'exprime qu'une intention — le serveur revalide tout (joueur vivant,
-- trousse réellement possédée, santé pas déjà pleine) et décide seul du soin ; ce contrôleur ne
-- fait que ne pas envoyer dans le vide pour ne pas gâcher un jeton de cadence du limiteur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)

local USE_KEY = Enum.KeyCode.H

local HealKitController = { Name = "HealKitController", Priority = 14 }

function HealKitController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= USE_KEY then
			return
		end
		if GameplayStateClient.get().healKit > 0 then
			NetClient.send("UseHealKit", {})
		end
	end)
end

return HealKitController
