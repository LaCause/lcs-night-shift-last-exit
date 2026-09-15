--!strict
-- Catalogue des visuels (FR-041, principe VIII). Chaque entrée peut désigner un modèle externe
-- (ReplicatedStorage.Assets) mais DOIT fournir un remplaçant en primitives low-poly, construit
-- autour de l'origine (pivot au sol, au centre). Style original « néon de bord de route ».

local Strings = require(script.Parent.Parent.Strings)

export type Entry = {
	ModelName: string?,
	BuildFallback: () -> Model,
	TestOnly: boolean?,
}

type PartOptions = {
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?,
}

local COLORS = {
	Tile = Color3.fromRGB(226, 218, 204),
	Wall = Color3.fromRGB(196, 92, 64),
	WallTrim = Color3.fromRGB(245, 238, 222),
	Roof = Color3.fromRGB(46, 42, 52),
	Counter = Color3.fromRGB(214, 176, 92),
	Steel = Color3.fromRGB(150, 156, 166),
	DarkSteel = Color3.fromRGB(70, 74, 82),
	Oil = Color3.fromRGB(150, 110, 30),
	Generator = Color3.fromRGB(62, 96, 64),
	Concrete = Color3.fromRGB(140, 138, 134),
	Asphalt = Color3.fromRGB(52, 52, 58),
	Paint = Color3.fromRGB(236, 220, 120),
	Grass = Color3.fromRGB(74, 104, 58),
	Glass = Color3.fromRGB(150, 200, 220),
	BusBody = Color3.fromRGB(222, 196, 120),
	BusStripe = Color3.fromRGB(150, 70, 40),
	Tire = Color3.fromRGB(28, 28, 30),
	NeonPink = Color3.fromRGB(255, 70, 170),
	NeonCyan = Color3.fromRGB(70, 235, 255),
	Warning = Color3.fromRGB(255, 80, 60),
	Pole = Color3.fromRGB(90, 90, 96),
	-- 002-premier-increment-jouable : nœuds de ressource et ennemi.
	FuelCanister = Color3.fromRGB(200, 70, 50),
	CoolerBody = Color3.fromRGB(90, 150, 140),
	CoolerLid = Color3.fromRGB(220, 220, 210),
	VendingBody = Color3.fromRGB(210, 60, 90),
	VendingGlass = Color3.fromRGB(170, 210, 220),
	EnemyBody = Color3.fromRGB(70, 60, 80),
	EnemyEye = Color3.fromRGB(255, 230, 90),
	-- Repères visuels flottants (dépôt, à préparer, à livrer) : remplaçants en primitives.
	CueBag = Color3.fromRGB(196, 154, 96),
	CueReady = Color3.fromRGB(222, 140, 60),
}

-- Oriente l'axe X d'un cylindre vers le haut.
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))
local FLOOR_TOP = 1
local WALL_HEIGHT = 12

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local function block(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PartOptions?
): Part
	local opts: PartOptions = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	if opts.shape then
		part.Shape = opts.shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.Transparency = opts.transparency or 0
	part.CanCollide = opts.collide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function finish(model: Model): Model
	model.WorldPivot = CFrame.identity
	return model
end

local function buildGround(): Model
	local model = newModel("Ground")
	block(model, "Grass", Vector3.new(400, 2, 400), CFrame.new(0, -1, 0), COLORS.Grass, {
		material = Enum.Material.Grass,
	})
	return finish(model)
end

local function buildRestaurant(): Model
	local model = newModel("Restaurant")
	local wallY = FLOOR_TOP + WALL_HEIGHT / 2

	-- Sol, parking et voie du drive-thru.
	block(
		model,
		"Floor",
		Vector3.new(40, 1, 28),
		CFrame.new(0, 0.5, 0),
		COLORS.Tile,
		{ material = Enum.Material.Marble }
	)
	block(model, "Parking", Vector3.new(44, 0.4, 26), CFrame.new(-2, 0.2, -27), COLORS.Asphalt, {
		material = Enum.Material.Asphalt,
	})
	block(model, "DriveThruLane", Vector3.new(10, 0.4, 54), CFrame.new(25, 0.2, -13), COLORS.Asphalt, {
		material = Enum.Material.Asphalt,
	})
	for index = 0, 4 do
		block(model, "LaneMark", Vector3.new(0.4, 0.05, 5), CFrame.new(25, 0.43, -36 + index * 11), COLORS.Paint, {
			collide = false,
		})
	end
	for index = 0, 5 do
		block(model, "ParkingLine", Vector3.new(0.4, 0.05, 8), CFrame.new(-20 + index * 7, 0.43, -35), COLORS.Paint, {
			collide = false,
		})
	end

	-- Murs : façade au sud (z = -14) avec une porte x ∈ [-3, 3].
	local function wall(name: string, size: Vector3, position: Vector3)
		block(model, name, size, CFrame.new(position), COLORS.Wall, { material = Enum.Material.Brick })
	end
	wall("FrontWallLeft", Vector3.new(17, WALL_HEIGHT, 1), Vector3.new(-11.5, wallY, -13.5))
	wall("FrontWallRight", Vector3.new(17, WALL_HEIGHT, 1), Vector3.new(11.5, wallY, -13.5))
	wall("FrontLintel", Vector3.new(6, 4, 1), Vector3.new(0, 11, -13.5))
	wall("BackWall", Vector3.new(40, WALL_HEIGHT, 1), Vector3.new(0, wallY, 13.5))
	wall("WestWall", Vector3.new(1, WALL_HEIGHT, 26), Vector3.new(-19.5, wallY, 0))
	-- Mur est, percé de la fenêtre du drive-thru (z ∈ [2, 6], y ∈ [4, 8]).
	wall("EastWallSouth", Vector3.new(1, WALL_HEIGHT, 15), Vector3.new(19.5, wallY, -5.5))
	wall("EastWallNorth", Vector3.new(1, WALL_HEIGHT, 7), Vector3.new(19.5, wallY, 9.5))
	wall("EastWallBelowWindow", Vector3.new(1, 3, 4), Vector3.new(19.5, 2.5, 4))
	wall("EastWallAboveWindow", Vector3.new(1, 5, 4), Vector3.new(19.5, 10.5, 4))
	block(model, "WindowSill", Vector3.new(1.8, 0.3, 4.4), CFrame.new(20.2, 4.15, 4), COLORS.Counter, {
		material = Enum.Material.Wood,
	})
	for _, x in { -11, 11 } do
		block(model, "FrontWindow", Vector3.new(9, 5, 0.3), CFrame.new(x, 6.5, -14.1), COLORS.Glass, {
			material = Enum.Material.Glass,
			transparency = 0.35,
		})
	end

	-- Toit, liseré néon et auvent.
	block(model, "Roof", Vector3.new(42, 1, 30), CFrame.new(0, FLOOR_TOP + WALL_HEIGHT + 0.5, 0), COLORS.Roof, {
		material = Enum.Material.Metal,
	})
	block(model, "RoofTrim", Vector3.new(42.4, 0.5, 0.5), CFrame.new(0, 13.2, -15.2), COLORS.NeonPink, {
		material = Enum.Material.Neon,
		collide = false,
	})
	block(model, "Awning", Vector3.new(10, 0.4, 4), CFrame.new(0, 9.4, -16), COLORS.WallTrim)

	-- Comptoir, cuisine, tableau des menus et tables.
	block(model, "CounterBody", Vector3.new(16, 3.5, 2), CFrame.new(0, FLOOR_TOP + 1.75, -6), COLORS.WallTrim)
	block(model, "CounterTop", Vector3.new(16.4, 0.3, 2.4), CFrame.new(0, FLOOR_TOP + 3.65, -6), COLORS.Counter, {
		material = Enum.Material.Wood,
	})
	block(model, "WorktopBody", Vector3.new(8, 3, 3), CFrame.new(6, FLOOR_TOP + 1.5, 6), COLORS.Steel, {
		material = Enum.Material.Metal,
	})
	block(model, "WorktopTop", Vector3.new(8.2, 0.2, 3.2), CFrame.new(6, FLOOR_TOP + 3.1, 6), COLORS.Steel, {
		material = Enum.Material.DiamondPlate,
	})
	block(model, "FryerBody", Vector3.new(4, 3.5, 3), CFrame.new(-6, FLOOR_TOP + 1.75, 6), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
	})
	block(model, "FryerOil", Vector3.new(3, 0.2, 2), CFrame.new(-6, FLOOR_TOP + 3.6, 6), COLORS.Oil)
	block(model, "MenuBoard", Vector3.new(14, 3, 0.4), CFrame.new(0, 10, 13), COLORS.Roof)
	for _, y in { 8.4, 11.6 } do
		block(model, "MenuNeon", Vector3.new(14.4, 0.3, 0.2), CFrame.new(0, y, 12.8), COLORS.NeonCyan, {
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	for _, x in { -12, 12 } do
		block(model, "TableLeg", Vector3.new(0.6, 2.6, 0.6), CFrame.new(x, FLOOR_TOP + 1.3, -9), COLORS.DarkSteel)
		block(
			model,
			"TableTop",
			Vector3.new(0.4, 4, 4),
			CFrame.new(x, FLOOR_TOP + 2.8, -9) * VERTICAL,
			COLORS.WallTrim,
			{
				shape = Enum.PartType.Cylinder,
			}
		)
	end

	-- Interphone, sur la voie du drive-thru.
	block(model, "IntercomPost", Vector3.new(0.6, 4, 0.6), CFrame.new(28.2, 2, -8), COLORS.Pole, {
		material = Enum.Material.Metal,
	})
	block(model, "IntercomBox", Vector3.new(1, 1.8, 1.6), CFrame.new(28.2, 4.6, -8), COLORS.DarkSteel)
	block(model, "IntercomSpeaker", Vector3.new(0.2, 0.8, 1), CFrame.new(27.6, 4.8, -8), COLORS.NeonCyan, {
		material = Enum.Material.Neon,
		collide = false,
	})

	-- Générateur, derrière le restaurant (à l'arrêt : voyant rouge).
	block(model, "GeneratorPad", Vector3.new(7, 0.4, 5), CFrame.new(-14, 0.2, 18), COLORS.Concrete, {
		material = Enum.Material.Concrete,
	})
	block(model, "GeneratorBody", Vector3.new(5, 4, 3), CFrame.new(-14, 2.4, 18), COLORS.Generator, {
		material = Enum.Material.Metal,
	})
	block(
		model,
		"GeneratorExhaust",
		Vector3.new(2, 0.6, 0.6),
		CFrame.new(-12.2, 5.4, 18.8) * VERTICAL,
		COLORS.DarkSteel,
		{
			shape = Enum.PartType.Cylinder,
		}
	)
	block(model, "GeneratorLight", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-11.4, 3.2, 18), COLORS.Warning, {
		material = Enum.Material.Neon,
		collide = false,
	})

	return finish(model)
end

local function addSignText(board: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = Strings.format("World.SignTitle")
	title.TextColor3 = COLORS.NeonPink
	title.TextScaled = true
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0, 0.62)
	subtitle.Size = UDim2.fromScale(1, 0.38)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = Strings.format("World.SignSubtitle")
	subtitle.TextColor3 = COLORS.NeonCyan
	subtitle.TextScaled = true
	subtitle.Parent = gui

	gui.Parent = board
end

local function buildNeonSign(): Model
	local model = newModel("NeonSign")
	block(model, "Pole", Vector3.new(18, 1, 1), CFrame.new(0, 9, 0) * VERTICAL, COLORS.Pole, {
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
	})
	local board = block(model, "Board", Vector3.new(14, 6, 1), CFrame.new(0, 20, 0), COLORS.Roof, {
		material = Enum.Material.Metal,
	})
	block(model, "FrameTop", Vector3.new(14.6, 0.4, 1.2), CFrame.new(0, 23.2, 0), COLORS.NeonPink, {
		material = Enum.Material.Neon,
	})
	block(model, "FrameBottom", Vector3.new(14.6, 0.4, 1.2), CFrame.new(0, 16.8, 0), COLORS.NeonPink, {
		material = Enum.Material.Neon,
	})
	block(model, "FrameLeft", Vector3.new(0.4, 6.8, 1.2), CFrame.new(-7.2, 20, 0), COLORS.NeonCyan, {
		material = Enum.Material.Neon,
	})
	block(model, "FrameRight", Vector3.new(0.4, 6.8, 1.2), CFrame.new(7.2, 20, 0), COLORS.NeonCyan, {
		material = Enum.Material.Neon,
	})
	addSignText(board, Enum.NormalId.Front)
	addSignText(board, Enum.NormalId.Back)
	return finish(model)
end

local function buildBus(): Model
	local model = newModel("Bus")
	block(model, "Body", Vector3.new(8, 6, 22), CFrame.new(0, 4.4, 0), COLORS.BusBody)
	block(model, "Roof", Vector3.new(8.2, 0.6, 22.2), CFrame.new(0, 7.7, 0), COLORS.WallTrim)
	block(model, "Stripe", Vector3.new(8.2, 0.8, 22.2), CFrame.new(0, 3.2, 0), COLORS.BusStripe)
	block(model, "Windows", Vector3.new(8.3, 2, 17), CFrame.new(0, 5.8, 1.5), COLORS.Glass, {
		material = Enum.Material.Glass,
		transparency = 0.3,
	})
	block(model, "Windshield", Vector3.new(7, 2.6, 0.3), CFrame.new(0, 5.6, -11.1), COLORS.Glass, {
		material = Enum.Material.Glass,
		transparency = 0.3,
	})
	block(model, "Bumper", Vector3.new(8.4, 0.8, 0.6), CFrame.new(0, 1.8, -11.2), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
	})
	for _, x in { -2.8, 2.8 } do
		block(model, "Headlight", Vector3.new(1.2, 0.8, 0.2), CFrame.new(x, 2.9, -11.1), COLORS.WallTrim)
	end
	for _, x in { -4.1, 4.1 } do
		for _, z in { -7, 7 } do
			block(model, "Wheel", Vector3.new(1.2, 3.4, 3.4), CFrame.new(x, 1.7, z), COLORS.Tire, {
				shape = Enum.PartType.Cylinder,
			})
		end
	end
	block(model, "RustPatch", Vector3.new(8.25, 1.2, 2.5), CFrame.new(0, 2.2, 6), COLORS.BusStripe, {
		material = Enum.Material.CorrodedMetal,
	})
	-- 003-bus-evasion : voyant de réparation, rouge tant que le bus n'est pas réparé, vert une
	-- fois réparé (BusService bascule sa couleur, comme GeneratorLight pour le générateur).
	block(model, "RepairLight", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 5.6, -11.05), COLORS.Warning, {
		material = Enum.Material.Neon,
		collide = false,
	})
	return finish(model)
end

-- 002-premier-increment-jouable : nœuds de ressource de la forêt. Chaque modèle a un
-- PrimaryPart, sur lequel ForestService accroche le ProximityPrompt et bascule la
-- disponibilité (transparence, collision, prompt actif) — même principe que CounterBell.
local function buildFuelCanister(): Model
	local model = newModel("FuelCanister")
	local body = block(model, "Body", Vector3.new(1.4, 2, 1.4), CFrame.new(0, 1, 0), COLORS.FuelCanister, {
		material = Enum.Material.Metal,
	})
	block(model, "Cap", Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 2.2, 0), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
	})
	block(model, "Handle", Vector3.new(0.9, 0.2, 0.3), CFrame.new(0, 1.9, 0.6), COLORS.DarkSteel)
	model.PrimaryPart = body
	return finish(model)
end

local function buildSuspectCooler(): Model
	local model = newModel("SuspectCooler")
	local body = block(model, "Body", Vector3.new(2, 1.4, 1.4), CFrame.new(0, 0.7, 0), COLORS.CoolerBody, {
		material = Enum.Material.Plastic,
	})
	block(model, "Lid", Vector3.new(2.1, 0.3, 1.5), CFrame.new(0, 1.5, 0), COLORS.CoolerLid)
	model.PrimaryPart = body
	return finish(model)
end

local function buildRoadVendingMachine(): Model
	local model = newModel("RoadVendingMachine")
	local body = block(model, "Body", Vector3.new(1.6, 3, 1.2), CFrame.new(0, 1.5, 0), COLORS.VendingBody, {
		material = Enum.Material.Metal,
	})
	block(model, "Glass", Vector3.new(1.2, 1.8, 0.1), CFrame.new(0, 1.9, 0.65), COLORS.VendingGlass, {
		material = Enum.Material.Glass,
		transparency = 0.2,
	})
	model.PrimaryPart = body
	return finish(model)
end

-- 002-premier-increment-jouable : ennemi apparu après une commande en échec. Silhouette
-- originale, non graphique (principe VIII) : un contour sombre et deux yeux pâles.
local function buildEnemy(): Model
	local model = newModel("Enemy")
	local torso = block(model, "Torso", Vector3.new(2, 4, 1.2), CFrame.new(0, 2.5, 0), COLORS.EnemyBody, {
		material = Enum.Material.SmoothPlastic,
	})
	block(model, "Head", Vector3.new(1.4, 1.2, 1.2), CFrame.new(0, 5, 0), COLORS.EnemyBody)
	for _, x in { -0.3, 0.3 } do
		block(model, "Eye", Vector3.new(0.2, 0.2, 0.1), CFrame.new(x, 5.1, 0.6), COLORS.EnemyEye, {
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	model.PrimaryPart = torso
	return finish(model)
end

-- 002-premier-increment-jouable : repères visuels flottants au comptoir, au plan de travail et
-- à la fenêtre du drive-thru (FeedbackVisualService). ModelName pointe vers un modèle du
-- marketplace inséré manuellement dans ReplicatedStorage.Assets (Roblox refuse
-- InsertService:LoadAsset pour un asset Creator Store non possédé depuis un script serveur, même
-- gratuit — voir default.project.json, Assets a $ignoreUnknownInstances pour que Rojo ne l'efface
-- pas). Ces primitives restent le remplaçant si le modèle est absent (place fraîchement
-- reconstruite, pas encore réinséré) ou si Visuals.PrimitivesOnly est actif, comme tout le
-- catalogue (FR-041).
local function buildDepositCue(): Model
	local model = newModel("DepositCue")
	block(model, "Bag", Vector3.new(1.6, 2, 1), CFrame.new(0, 1, 0), COLORS.CueBag, {
		material = Enum.Material.Fabric,
		collide = false,
	})
	block(model, "Fold", Vector3.new(1.6, 0.4, 1), CFrame.new(0, 2.1, 0), COLORS.CueBag, {
		material = Enum.Material.Fabric,
		collide = false,
	})
	return finish(model)
end

local function buildPrepareCue(): Model
	local model = newModel("PrepareCue")
	block(model, "Pan", Vector3.new(1.6, 0.15, 1.6), CFrame.new(0, 0.08, 0), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
		collide = false,
	})
	block(model, "Handle", Vector3.new(1.2, 0.12, 0.3), CFrame.new(1.1, 0.08, 0), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
		collide = false,
	})
	return finish(model)
end

local function buildDeliverCue(): Model
	local model = newModel("DeliverCue")
	block(model, "Bag", Vector3.new(1.4, 1.8, 1), CFrame.new(0, 0.9, 0), COLORS.CueReady, {
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	block(model, "Fold", Vector3.new(1.4, 0.3, 1), CFrame.new(0, 1.85, 0), COLORS.CueReady, {
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	return finish(model)
end

-- 003-bus-evasion : tas de ferraille récoltable en forêt, même principe que les trois nœuds de
-- ressource existants (PrimaryPart pour le ProximityPrompt et la bascule de disponibilité).
local function buildScrapPile(): Model
	local model = newModel("ScrapPile")
	local body = block(model, "Body", Vector3.new(1.8, 1, 1.6), CFrame.new(0, 0.5, 0), COLORS.DarkSteel, {
		material = Enum.Material.Metal,
	})
	block(
		model,
		"Plate",
		Vector3.new(1.2, 0.15, 0.9),
		CFrame.new(0.1, 1.05, 0.1) * CFrame.Angles(0, math.rad(20), 0),
		COLORS.Steel,
		{
			material = Enum.Material.Metal,
		}
	)
	block(
		model,
		"Rod",
		Vector3.new(0.15, 0.15, 1.4),
		CFrame.new(-0.3, 1.15, -0.2) * CFrame.Angles(math.rad(70), 0, 0),
		COLORS.Steel,
		{
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Metal,
		}
	)
	model.PrimaryPart = body
	return finish(model)
end

local function buildFallbackProbe(): Model
	local model = newModel("FallbackProbe")
	block(model, "Probe", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), COLORS.NeonPink, { material = Enum.Material.Neon })
	return finish(model)
end

local Catalog: { [string]: Entry } = {
	Ground = { BuildFallback = buildGround },
	Restaurant = { BuildFallback = buildRestaurant },
	NeonSign = { BuildFallback = buildNeonSign },
	Bus = { BuildFallback = buildBus },
	-- 002-premier-increment-jouable : nœuds de ressource, toujours en primitives (originaux).
	FuelCanister = { BuildFallback = buildFuelCanister },
	SuspectCooler = { BuildFallback = buildSuspectCooler },
	RoadVendingMachine = { BuildFallback = buildRoadVendingMachine },
	Enemy = { BuildFallback = buildEnemy },
	-- 003-bus-evasion : nœud de ferraille, en primitive (original).
	ScrapPile = { BuildFallback = buildScrapPile },
	-- 002-premier-increment-jouable : repères visuels, marketplace + repli en primitives.
	DepositCue = { ModelName = "DepositCue", BuildFallback = buildDepositCue },
	PrepareCue = { ModelName = "PrepareCueModel", BuildFallback = buildPrepareCue },
	DeliverCue = { ModelName = "DeliverCue", BuildFallback = buildDeliverCue },
	-- Entrée de test (Dev.TestVisualFallback) : son modèle est volontairement absent.
	FallbackProbe = { ModelName = "__FallbackProbeMissing", BuildFallback = buildFallbackProbe, TestOnly = true },
}

return table.freeze(Catalog)
