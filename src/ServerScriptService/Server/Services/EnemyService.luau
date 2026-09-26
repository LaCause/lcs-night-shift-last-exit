--!strict
-- Ennemi nocturne (002-premier-increment-jouable, FR-016 à FR-021). Apparaît quand une
-- commande échoue (research R9), poursuit le joueur valide le plus proche hors de la zone de
-- sécurité, sans Humanoid (research R8) : déplacement par CFrame, PathfindingService avec
-- repli en ligne droite. Au plus une instance active à la fois (data-model.md).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local GeneratorService = require(script.Parent.GeneratorService)
local HealthService = require(script.Parent.HealthService)
local MatchService = require(script.Parent.MatchService)
local NotifyService = require(script.Parent.NotifyService)
local OrderService = require(script.Parent.OrderService)
local SessionService = require(script.Parent.SessionService)
local VisualService = require(script.Parent.VisualService)
local WorldService = require(script.Parent.WorldService)

local ENEMIES_FOLDER = "Enemies"
local WAYPOINT_TOLERANCE = 2

local log = Log.new("Enemy")

local EnemyService = { Name = "EnemyService", Priority = 70 }

local model: Model? = nil
local primaryPart: BasePart? = nil
local enemyHeight = 0
local lifetime = 0
local idleSince = 0
local repathTimer = math.huge
local waypoints: { PathWaypoint }? = nil
local waypointIndex = 1
local lastContactAt: { [Player]: number } = {}

local function enemiesFolder(): Folder
	local found = workspace:FindFirstChild(ENEMIES_FOLDER)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = ENEMIES_FOLDER
	folder.Parent = workspace
	return folder
end

local function despawn()
	if model then
		model:Destroy()
	end
	model = nil
	primaryPart = nil
	waypoints = nil
	lastContactAt = {}
end

local function spawnAtPart(spawnPart: BasePart)
	if model ~= nil then
		log:info("Un ennemi est déjà actif : nouvelle apparition ignorée")
		return
	end
	local built = VisualService.build("Enemy")
	if built == nil then
		log:error("Visuel de l'ennemi introuvable : apparition annulée")
		return
	end
	local part = built.PrimaryPart
	if part == nil then
		log:error("Modèle de l'ennemi sans PrimaryPart : apparition annulée")
		built:Destroy()
		return
	end
	built.Name = "Enemy"
	-- placeFresh, pas PivotTo : ce modèle a un PrimaryPart (Torso), ce qui ferait reposer PivotTo
	-- dessus plutôt que sur la base du modèle (VisualService.placeFresh). Les déplacements
	-- ultérieurs (ci-dessous) restent en PivotTo : une fois ce premier placement fait, la
	-- géométrie relative du modèle ne bouge plus, donc PivotTo y reste cohérent avec lui-même.
	VisualService.placeFresh(built, spawnPart.CFrame)
	built.Parent = enemiesFolder()

	model = built
	primaryPart = part
	enemyHeight = spawnPart.Position.Y
	lifetime = 0
	idleSince = 0
	repathTimer = math.huge
	waypoints = nil
	waypointIndex = 1
	lastContactAt = {}
	log:info("Ennemi apparu à %s", spawnPart.Name)
end

-- Commande de dev (Dev.SpawnEnemy) : déclenche une apparition à un point de référence donné.
function EnemyService.spawnAt(refPointId: string)
	local point = WorldService.refPoint(refPointId)
	if point == nil then
		log:warn("Point de référence %s introuvable : apparition annulée", refPointId)
		return
	end
	spawnAtPart(point)
end

-- Joueur en vie, avec un personnage, hors de la zone de sécurité, le plus proche de `from`.
local function pickTarget(from: Vector3): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local session = SessionService.get(player)
		if session == nil or session.Status ~= "Alive" then
			continue
		end
		local character = player.Character
		if character == nil then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		if GeneratorService.isPositionSafe(root.Position) then
			continue
		end
		local distance = (root.Position - from).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = player
			bestRoot = root
		end
	end
	return best, bestRoot
end

-- 007-nuits-optionnelles-evasion : nombre de nuits jouées au-delà du seuil minimum (0 tant qu'il
-- n'est pas dépassé, FR-011 — les nuits normales ne sont donc jamais affectées).
local function extraNights(): number
	return math.max(0, MatchService.getNight() - MatchService.getTotalNights())
end

local function tryDamage(target: Player)
	local now = os.clock()
	local cooldown: number = Config.get("Enemy", "ContactCooldown")
	if now - (lastContactAt[target] or -math.huge) < cooldown then
		return
	end
	lastContactAt[target] = now
	local damage: number = Config.get("Enemy", "ContactDamage")
		+ Config.get("Enemy", "ExtraNightDamageGrowth") * extraNights()
	HealthService.damage(target, damage)
	NotifyService.send(target, "EnemyHit", { damage = damage })
end

-- Chemin vers la cible ; nil si le calcul échoue (repli en ligne droite, principe VI).
local function computePath(from: Vector3, to: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath()
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	return path:GetWaypoints()
end

local function moveToward(current: Vector3, target: Vector3, dt: number): Vector3
	local delta = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
	local distance = delta.Magnitude
	if distance < 0.05 then
		return current
	end
	local speed: number = Config.get("Enemy", "MoveSpeed")
		+ Config.get("Enemy", "ExtraNightSpeedGrowth") * extraNights()
	local step = math.min(distance, speed * dt)
	return current + delta.Unit * step
end

local function step(dt: number)
	local part = primaryPart
	if part == nil then
		return
	end

	lifetime += dt
	if lifetime > Config.get("Enemy", "MaxLifetime") then
		log:info("Ennemi disparu : durée de vie maximale atteinte")
		despawn()
		return
	end

	local currentPosition = part.Position
	local target, targetRoot = pickTarget(currentPosition)
	if target == nil or targetRoot == nil then
		idleSince += dt
		if idleSince > Config.get("Enemy", "GiveUpDelay") then
			log:info("Ennemi disparu : aucune cible atteignable")
			despawn()
		end
		return
	end
	idleSince = 0

	local targetPosition = targetRoot.Position
	if (currentPosition - targetPosition).Magnitude <= Config.get("Enemy", "ContactRange") then
		tryDamage(target)
	end

	repathTimer += dt
	if repathTimer >= Config.get("Enemy", "RepathInterval") or waypoints == nil then
		repathTimer = 0
		waypoints = computePath(currentPosition, targetPosition)
		waypointIndex = 1
	end

	local nextPosition: Vector3
	local activeWaypoints = waypoints
	if activeWaypoints ~= nil and activeWaypoints[waypointIndex] ~= nil then
		local waypoint = activeWaypoints[waypointIndex]
		nextPosition = moveToward(currentPosition, waypoint.Position, dt)
		-- Distance à plat, comme moveToward : les points du chemin sont à la hauteur de la surface
		-- navigable, pas à celle de l'ennemi, et un écart vertical bloquerait le point 1 à jamais.
		local flatGap = Vector3.new(nextPosition.X - waypoint.Position.X, 0, nextPosition.Z - waypoint.Position.Z)
		if flatGap.Magnitude <= WAYPOINT_TOLERANCE then
			waypointIndex += 1
		end
	else
		-- Repli : ligne droite directe vers la cible.
		nextPosition = moveToward(currentPosition, targetPosition, dt)
	end

	local flatTarget = Vector3.new(targetPosition.X, enemyHeight, targetPosition.Z)
	local flatNext = Vector3.new(nextPosition.X, enemyHeight, nextPosition.Z)
	if (flatTarget - flatNext).Magnitude > 0.05 then
		if model then
			model:PivotTo(CFrame.new(flatNext, flatTarget))
		end
	elseif model then
		model:PivotTo(CFrame.new(flatNext))
	end
end

function EnemyService.Init()
	MatchService.PhaseEnded:Connect(function()
		despawn()
	end)
	OrderService.OrderFailed:Connect(function(_recipeId: string)
		local spawnPoint = WorldService.refPoint("EnemySpawn")
		if spawnPoint == nil then
			log:error("Point de référence EnemySpawn introuvable : apparition annulée")
			return
		end
		spawnAtPart(spawnPoint)
	end)
	log:info("Système d'ennemi prêt")
end

function EnemyService.Start()
	RunService.Heartbeat:Connect(step)
end

return EnemyService
