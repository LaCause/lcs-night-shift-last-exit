--!strict
-- Points de référence du monde de départ (data-model.md) : identifiants et recherche par tag
-- CollectionService, utilisable côté serveur comme côté client.

local CollectionService = game:GetService("CollectionService")

local Types = require(script.Parent.Parent.Types)

local TAG = "RefPoint"

local IDS: { Types.RefPointId } = {
	"Spawn",
	"DriveThruWindow",
	"Intercom",
	"Counter",
	"Worktop",
	"Fryer",
	"Generator",
	"NeonSign",
	"SafeZoneCenter",
	"BusSpot",
	"EnemySpawn",
}

local RefPoints = {}

-- Nom du tag CollectionService et de l'attribut portant l'identifiant.
RefPoints.Tag = TAG
RefPoints.Ids = table.freeze(IDS)

function RefPoints.isValid(id: any): boolean
	return typeof(id) == "string" and table.find(IDS, id :: any) ~= nil
end

function RefPoints.find(id: string): BasePart?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("BasePart") and instance:GetAttribute(TAG) == id then
			return instance
		end
	end
	return nil
end

-- Attend qu'un point de référence soit répliqué (côté client), jusqu'à `timeout` secondes.
function RefPoints.waitFor(id: string, timeout: number?): BasePart?
	local deadline = os.clock() + (timeout or 10)
	repeat
		local found = RefPoints.find(id)
		if found then
			return found
		end
		task.wait(0.25)
	until os.clock() >= deadline
	return RefPoints.find(id)
end

return table.freeze(RefPoints)
