--!strict
-- Générateur, néon et zone de sécurité (002-premier-increment-jouable, FR-006 à FR-010).
-- État répliqué sur ReplicatedStorage.GeneratorState (research R5 : la zone de sécurité est une
-- lumière attachée au point de référence SafeZoneCenter du socle, pas un nouveau modèle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local WorldService = require(script.Parent.WorldService)

local GENERATOR_ID = "Generator"
local SAFE_ZONE_ID = "SafeZoneCenter"

local log = Log.new("Generator")

local GeneratorService = { Name = "GeneratorService", Priority = 44 }

local state: Folder? = nil
local safeZoneLight: PointLight? = nil
local safeZoneCenter: BasePart? = nil
local fuel = 0
local safeZoneActive = false

local function stateFolder(): Folder
	local folder = state
	if folder == nil then
		error("GeneratorService.Init n'a pas encore créé GeneratorState", 2)
	end
	return folder
end

local function setSafeZone(active: boolean)
	if safeZoneActive == active then
		return
	end
	safeZoneActive = active
	stateFolder():SetAttribute("SafeZoneActive", active)
	if safeZoneLight then
		safeZoneLight.Enabled = active
	end
end

-- Centralise le clamp, la publication et la transition de la zone de sécurité. `notify` est
-- faux pour la remise à zéro d'une nouvelle partie (pas un événement à annoncer, FR-009).
local function applyFuel(newFuel: number, notify: boolean)
	local capacity: number = Config.get("Generator", "Capacity")
	fuel = math.clamp(newFuel, 0, capacity)
	stateFolder():SetAttribute("Fuel", fuel)
	local active = fuel > 0
	if active ~= safeZoneActive then
		setSafeZone(active)
		if notify then
			NotifyService.broadcast(if active then "GeneratorRefueled" else "GeneratorEmpty", {})
		end
	end
end

local function resetFuel()
	local capacity: number = Config.get("Generator", "Capacity")
	stateFolder():SetAttribute("Capacity", capacity)
	applyFuel(Config.get("Generator", "InitialFuel"), false)
end

-- Ajoute du carburant brut (déjà converti depuis l'essence par l'appelant). Retourne la
-- quantité réellement ajoutée (peut être moindre si la capacité est atteinte).
function GeneratorService.deposit(amount: number): number
	if amount <= 0 then
		return 0
	end
	local before = fuel
	applyFuel(fuel + amount, true)
	return fuel - before
end

function GeneratorService.hasFuel(): boolean
	return fuel > 0
end

function GeneratorService.isSafeZoneActive(): boolean
	return GeneratorService.hasFuel()
end

function GeneratorService.isPositionSafe(position: Vector3): boolean
	if not GeneratorService.hasFuel() then
		return false
	end
	local center = safeZoneCenter
	if center == nil then
		return false
	end
	local radius: number = Config.get("Generator", "SafeZoneRadius")
	return (position - center.Position).Magnitude <= radius
end

local function buildSafeZoneLight()
	local center = WorldService.refPoint(SAFE_ZONE_ID)
	if center == nil then
		error(`Point de référence {SAFE_ZONE_ID} introuvable : zone de sécurité désactivée`)
	end
	safeZoneCenter = center
	local light = Instance.new("PointLight")
	light.Name = "SafeZoneLight"
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Range = Config.get("Generator", "SafeZoneRadius") * 1.2
	light.Brightness = 2
	light.Enabled = false
	light.Parent = center
	safeZoneLight = light
end

local function buildGeneratorPrompt()
	local found = WorldService.refPoint(GENERATOR_ID)
	if found == nil then
		error(`Point de référence {GENERATOR_ID} introuvable : ravitaillement désactivé`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RefuelPrompt"
	prompt.ActionText = Strings.format("Generator.RefuelAction")
	prompt.ObjectText = Strings.format("Generator.RefuelObject")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Generator", "InteractRange")
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Intent", "RefuelGenerator")
	prompt:SetAttribute("Target", GENERATOR_ID)
	prompt.Parent = found
end

local function drainLoop()
	local lastTick = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now
		if MatchService.isActive() and fuel > 0 then
			local drain: number = Config.get("Generator", "DrainPerSecond", MatchService.isTestProfile())
			applyFuel(fuel - drain * dt, true)
		end
	end
end

function GeneratorService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "GeneratorState"
	folder.Parent = ReplicatedStorage
	state = folder

	buildSafeZoneLight()
	buildGeneratorPrompt()

	MatchService.MatchStarting:Connect(resetFuel)

	NetService.registerIntent("RefuelGenerator", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= GENERATOR_ID then
				return "TargetMissing"
			end
			local fuelPerEssence: number = Config.get("Generator", "FuelPerEssence")
			local capacity: number = Config.get("Generator", "Capacity")
			local room = capacity - fuel
			local maxEssence = math.floor(room / fuelPerEssence)
			if maxEssence <= 0 then
				return nil -- déjà plein : aucune essence consommée, rien à faire
			end
			local used = InventoryService.depositResource(player, "Essence", maxEssence)
			if used > 0 then
				GeneratorService.deposit(used * fuelPerEssence)
				-- Retour son/visuel léger côté client (SfxController) : distinct de
				-- GeneratorRefueled/GeneratorEmpty, qui ne se déclenchent qu'au changement d'état
				-- de la zone de sécurité, pas à chaque ravitaillement.
				NotifyService.send(player, "GeneratorFueled", { amount = used })
				log:info("%s ravitaille le générateur : %d essence", player.Name, used)
			end
			return nil
		end,
	})

	log:info("Générateur prêt (carburant initial : %d)", Config.get("Generator", "InitialFuel"))
end

function GeneratorService.Start()
	task.spawn(drainLoop)
end

return GeneratorService
