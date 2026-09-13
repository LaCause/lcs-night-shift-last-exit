--!strict
-- Interactions génériques (research R8) : toute invite de proximité portant l'attribut Intent
-- envoie cette intention au serveur, avec l'attribut Target comme cible. Les interactions
-- futures (ramasser, cuisiner, livrer…) n'ont besoin d'aucun nouveau code client.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetClient = require(Shared:WaitForChild("Client"):WaitForChild("NetClient") :: ModuleScript)

local InteractionController = { Name = "InteractionController", Priority = 10 }

function InteractionController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local intent = prompt:GetAttribute("Intent")
		if typeof(intent) ~= "string" then
			return
		end
		local target = prompt:GetAttribute("Target")
		NetClient.send(intent, if typeof(target) == "string" then { target = target } else {})
	end)
end

return InteractionController
