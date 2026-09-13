--!strict
-- Amorçage client : démarre les contrôleurs de Controllers/ via le Loader partagé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader") :: ModuleScript)

Loader.run(script.Parent:FindFirstChild("Controllers"), "Client")
