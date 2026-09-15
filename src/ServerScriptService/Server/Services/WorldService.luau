--!strict
-- Monde de départ construit par script (research R3 ; FR-004, FR-007, FR-023) : sol, restaurant,
-- enseigne néon, bus, points de référence et point d'apparition, dans Workspace.World.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local RefPoints = require(Shared.World.RefPoints)
local Layout = require(script.Parent.Parent.World.Layout)
local VisualService = require(script.Parent.VisualService)

local BELL_ID = "CounterBell"
local BELL_COLOR = Color3.fromRGB(230, 190, 70)
local SPAWN_COLOR = Color3.fromRGB(236, 220, 120)

local log = Log.new("World")

local WorldService = { Name = "WorldService", Priority = 20 }

local ready = false
local restaurantSpawn: SpawnLocation? = nil
local worldFolder: Folder? = nil

-- Un SpawnLocation hérité d'un gabarit Studio ferait apparaître les joueurs ailleurs.
local function disableForeignSpawns()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			descendant.Enabled = false
			log:warn("SpawnLocation étranger désactivé : %s", descendant:GetFullName())
		end
	end
end

local function buildRefPoint(id: string, spec: Layout.RefPointSpec, parent: Instance)
	local part = Instance.new("Part")
	part.Name = id
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	if id == BELL_ID then
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Metal
		part.Color = BELL_COLOR
	else
		part.Transparency = 1
		part.CastShadow = false
	end
	part.Size = spec.size or Vector3.one
	part.CFrame = spec.cframe
	part:SetAttribute(RefPoints.Tag, id)
	CollectionService:AddTag(part, RefPoints.Tag)
	part.Parent = parent
end

function WorldService.Init()
	local previous = workspace:FindFirstChild("World")
	if previous then
		previous:Destroy()
	end
	disableForeignSpawns()

	local world = Instance.new("Folder")
	world.Name = "World"

	for _, placement in Layout.Visuals do
		local model = VisualService.build(placement.visual)
		if model then
			model.Name = placement.visual
			model:PivotTo(placement.cframe)
			model.Parent = world
		end
	end

	local refFolder = Instance.new("Folder")
	refFolder.Name = "RefPoints"
	refFolder.Parent = world
	for id, spec in Layout.RefPoints do
		if RefPoints.isValid(id) then
			buildRefPoint(id, spec, refFolder)
		else
			log:error("Point de référence inconnu dans Layout.luau : %s", id)
		end
	end

	local spawnSpec = Layout.RefPoints.Spawn
	if spawnSpec ~= nil then
		local spawnPart = Instance.new("SpawnLocation")
		spawnPart.Name = "RestaurantSpawn"
		spawnPart.Anchored = true
		spawnPart.Neutral = true
		spawnPart.Duration = 0
		spawnPart.Size = Vector3.new(8, 1, 8)
		spawnPart.CFrame = spawnSpec.cframe
		spawnPart.Color = SPAWN_COLOR
		spawnPart.Material = Enum.Material.SmoothPlastic
		spawnPart.Parent = world
		restaurantSpawn = spawnPart
	end

	world.Parent = workspace
	worldFolder = world

	for _, id in RefPoints.Ids do
		if refFolder:FindFirstChild(id) == nil then
			log:error("Point de référence manquant : %s", id)
		end
	end
	ready = restaurantSpawn ~= nil
	if not ready then
		log:error("Point d'apparition du restaurant absent (point de référence Spawn)")
	end
	log:info("Monde de départ construit : %d points de référence", #refFolder:GetChildren())
end

function WorldService.refPoint(id: string): BasePart?
	return RefPoints.find(id)
end

-- Retrouve un modèle déjà construit depuis Layout.Visuals par son nom (ex. "Bus"), sous
-- Workspace.World (003-bus-evasion, même esprit que refPoint, pour un visuel plutôt qu'un point
-- de référence). Le modèle est construit une seule fois au démarrage du serveur (Init), jamais
-- reconstruit par partie, contrairement à la forêt.
function WorldService.visual(name: string): Model?
	local folder = worldFolder
	if folder == nil then
		return nil
	end
	local found = folder:FindFirstChild(name)
	if found ~= nil and found:IsA("Model") then
		return found
	end
	return nil
end

function WorldService.spawnLocation(): SpawnLocation?
	return restaurantSpawn
end

function WorldService.isReady(): boolean
	return ready
end

return WorldService
