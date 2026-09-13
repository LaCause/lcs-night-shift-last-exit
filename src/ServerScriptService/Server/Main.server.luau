--!strict
-- Amorçage serveur : charge la configuration en premier (ses avertissements apparaissent
-- d'emblée), puis démarre les systèmes de Services/ via le Loader partagé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Config)
local Loader = require(ReplicatedStorage.Shared.Util.Loader)

Loader.run(script.Parent:FindFirstChild("Services"), "Serveur")
