--!strict
-- Plan déclaratif du monde de départ (data-model.md, « Point de référence »).
-- Coordonnées en studs : sol à y = 0, restaurant sur x ∈ [-20, 20] et z ∈ [-14, 14],
-- façade et parking au sud (z négatifs), voie du drive-thru à l'est.

export type Placement = { visual: string, cframe: CFrame }
export type RefPointSpec = { cframe: CFrame, size: Vector3? }

-- Rotation d'un demi-tour : le point d'apparition regarde le restaurant.
local FACE_NORTH = CFrame.Angles(0, math.pi, 0)

local visuals: { Placement } = {
	{ visual = "Ground", cframe = CFrame.identity },
	{ visual = "Restaurant", cframe = CFrame.identity },
	{ visual = "NeonSign", cframe = CFrame.new(-28, 0, -38) },
	{ visual = "Bus", cframe = CFrame.new(36, 0, 22) * CFrame.Angles(0, math.rad(15), 0) },
}

-- Spawn est loin du Générateur, bien plus que Generator.InteractRange + Net.DistanceTolerance :
-- le cas « trop loin » de la liste de contrôle se teste depuis le point d'apparition.
local refPoints: { [string]: RefPointSpec } = {
	Spawn = { cframe = CFrame.new(0, 0.5, -30) * FACE_NORTH },
	DriveThruWindow = { cframe = CFrame.new(20, 6, 4) },
	Intercom = { cframe = CFrame.new(28.2, 4.6, -8) },
	Counter = { cframe = CFrame.new(0, 4.8, -6) },
	Worktop = { cframe = CFrame.new(6, 4.5, 6) },
	Fryer = { cframe = CFrame.new(-6, 5, 6) },
	-- Devant le générateur (GeneratorBody dans Catalog.luau, centré en (-14, 2.4, 18) sur la
	-- dalle GeneratorPad) : au bord sud de la dalle, pas dans le volume solide du décor.
	Generator = { cframe = CFrame.new(-14, 1, 21.5) },
	NeonSign = { cframe = CFrame.new(-28, 20, -38) },
	SafeZoneCenter = { cframe = CFrame.new(0, 2, 0) },
	BusSpot = { cframe = CFrame.new(36, 1, 22) },
	-- En lisière de forêt, au nord, au-delà de Forest.AreaMaxRadius (002-premier-increment-jouable).
	EnemySpawn = { cframe = CFrame.new(0, 1, 180) },
}

return table.freeze({
	Visuals = table.freeze(visuals),
	RefPoints = table.freeze(refPoints),
})
