--!strict
-- Résolution des visuels du catalogue (FR-041) : modèle externe s'il est déclaré et présent dans
-- ReplicatedStorage.Assets, sinon remplaçant en primitives (toujours si Visuals.PrimitivesOnly).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Assets.Catalog)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local log = Log.new("Visual")

local VisualService = { Name = "VisualService", Priority = 10 }

-- Renvoie le modèle construit (nil en cas d'échec) et vrai si le remplaçant a été utilisé.
function VisualService.build(id: string): (Model?, boolean)
	local entry = Catalog[id]
	if entry == nil then
		log:error("Visuel inconnu : %s", id)
		return nil, false
	end

	local modelName = entry.ModelName
	if modelName ~= nil and not Config.get("Visuals", "PrimitivesOnly") then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local source = if assets then assets:FindFirstChild(modelName) else nil
		if source ~= nil and source:IsA("Model") then
			return source:Clone(), false
		end
		log:warn("Modèle %s introuvable pour le visuel %s : remplaçant en primitives utilisé", modelName, id)
	end

	local ok, result = pcall(entry.BuildFallback)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("Model") then
		log:error("Remplaçant du visuel %s en échec : %s", id, tostring(result))
		return nil, true
	end
	return result, true
end

return VisualService
