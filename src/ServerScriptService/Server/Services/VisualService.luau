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
		elseif source ~= nil and source:IsA("BasePart") then
			-- Le marketplace insère parfois une pièce unique (MeshPart/UnionOperation) plutôt
			-- qu'un Model : on l'enveloppe pour rester compatible avec le reste du pipeline
			-- (PivotTo, etc.) sans exiger un regroupement manuel dans Studio.
			local part = source:Clone()
			local wrapper = Instance.new("Model")
			wrapper.Name = modelName
			part.Parent = wrapper
			wrapper.PrimaryPart = part
			wrapper:PivotTo(part.CFrame)
			return wrapper, false
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

-- Place un modèle tout juste construit à `cframe`, sans passer par PivotTo (bug Roblox vérifié :
-- dès qu'un PrimaryPart est défini, PivotTo/GetPivot se calent dessus, quel que soit le WorldPivot
-- déclaré avant — un modèle du catalogue avec PrimaryPart (nœuds de ressource, ennemi) se
-- retrouverait alors enfoncé dans le sol de la hauteur de son PrimaryPart au lieu d'y reposer par
-- sa base). Chaque pièce du catalogue est autorée relative à l'origine (X=0, Z=0 au centre, base
-- à Y=0, en-tête de Catalog.luau) : les replacer comme si ce point d'origine devenait `cframe`
-- revient à composer `cframe * pièce.CFrame` pour chacune, sans jamais consulter le pivot déclaré.
--
-- À réserver au placement INITIAL d'un modèle fraîchement construit (ses pièces sont encore à
-- leur position autorée) : un modèle déjà déplacé une première fois (PivotTo ou celle-ci) n'est
-- plus origine-relative, le réutiliser composerait incorrectement les transformations.
function VisualService.placeFresh(model: Model, cframe: CFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = cframe * descendant.CFrame
		end
	end
end

-- Pose un modèle DONT LE PIVOT N'EST PAS FIABLE (asset externe inséré à la main : son
-- `WorldPivot` reflète l'endroit où Studio l'a laissé, pas forcément sa base) au sol à `position`,
-- tourné de `angleY` autour de l'axe vertical. Calcule sa boîte englobante réelle plutôt que de
-- faire une hypothèse sur son origine — contrairement à `placeFresh`, qui suppose un modèle du
-- catalogue autoré base-à-l'origine. Ancre chaque pièce au passage : un asset cloné depuis
-- ReplicatedStorage est parfois `Anchored = false`, ce qui le ferait tomber dès la prochaine
-- simulation physique sinon.
function VisualService.placeOnGround(model: Model, position: Vector3, angleY: number)
	local box, size = model:GetBoundingBox()
	local lowestY = box.Position.Y - size.Y / 2
	local pivot = CFrame.new(box.Position.X, lowestY, box.Position.Z)
	local target = CFrame.new(position) * CFrame.Angles(0, angleY, 0)
	local toPivotSpace = pivot:Inverse()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = target * (toPivotSpace * descendant.CFrame)
			descendant.Anchored = true
		end
	end
end

return VisualService
