--!strict
-- Correspondance objet-poste (005-depot-intelligent-sac, FR-005 à FR-009). Seule connaissance
-- neuve de cette fonctionnalité : quel type d'objet transporté correspond à quel poste, et
-- comment l'y déposer. Requiert InventoryService, GeneratorService, BusService et WorldService ;
-- aucun d'eux ne le requiert en retour (research R2) — aucune dépendance circulaire.
--
-- tryDeposit ne touche jamais le sac tant que le dépôt n'est pas garanti : chaque poste vérifie
-- sa capacité avant tout prélèvement, en réutilisant exactement le contrat « prélever puis
-- appliquer » de son interaction manuelle (research R3). La portée se mesure depuis la position
-- d'arrivée de l'objet lui-même, jamais depuis le joueur (research R5, clarification 2026-09-18,
-- Q2) — volontairement sans la marge Net.DistanceTolerance, qui compense une latence réseau
-- absente ici : le calcul est entièrement serveur, dans le même tick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local BusService = require(script.Parent.BusService)
local GeneratorService = require(script.Parent.GeneratorService)
local InventoryService = require(script.Parent.InventoryService)
local WorldService = require(script.Parent.WorldService)

type ResourceType = Types.ResourceType
type RefPointId = Types.RefPointId

-- Prélève et applique 1 unité ; ne renvoie true que si le dépôt a réellement eu lieu.
type AttemptFn = (player: Player) -> boolean

type AutoDepositDef = {
	RefPointId: RefPointId,
	RangeSetting: string, -- "Domaine.Réglage", résolu comme dans NetService.rangeFor
	attempt: AttemptFn,
}

local log = Log.new("StationDeposit")

local StationDepositService = { Name = "StationDepositService", Priority = 49 }

local function rangeFor(setting: string): number
	local domain, key = string.match(setting, "^(%w+)%.(%w+)$")
	if domain == nil or key == nil then
		error(`Réglage de portée mal formé : {setting}`, 2)
	end
	return Config.get(domain, key)
end

-- L'essence est convertie en carburant brut au même taux que le ravitaillement manuel
-- (Generator.FuelPerEssence) ; la capacité est vérifiée avant tout prélèvement dans le sac.
local function attemptGenerator(player: Player): boolean
	local fuelPerEssence: number = Config.get("Generator", "FuelPerEssence")
	if GeneratorService.fuelRoom() < fuelPerEssence then
		return false
	end
	local used = InventoryService.depositResource(player, "Essence", 1)
	if used <= 0 then
		return false
	end
	GeneratorService.deposit(used * fuelPerEssence)
	return true
end

-- BusService.deposit vérifie lui-même sa propre capacité (required - deposited) avant de
-- prélever quoi que ce soit ; renvoie 0 sans effet si le bus est déjà réparé.
local function attemptBus(player: Player): boolean
	return BusService.deposit(player, 1) > 0
end

-- Le stock partagé n'a pas de plafond (contrairement au générateur et au bus) : aucune
-- vérification de capacité n'est nécessaire ici, seulement le prélèvement.
local function attemptCounter(resourceType: ResourceType): AttemptFn
	return function(player: Player): boolean
		return InventoryService.depositResourceToStock(player, resourceType, 1) > 0
	end
end

-- Table conçue comme BAG_TYPES (004, research R7) : un futur type avec une action de poste
-- n'ajoute qu'une entrée, aucune logique nouvelle (FR-006).
local AUTO_DEPOSIT: { [ResourceType]: AutoDepositDef } = {
	Essence = { RefPointId = "Generator", RangeSetting = "Generator.InteractRange", attempt = attemptGenerator },
	SuspectSteak = {
		RefPointId = "Counter",
		RangeSetting = "Forest.HarvestRange", -- même réglage que le dépôt manuel existant (DepositResources)
		attempt = attemptCounter("SuspectSteak"),
	},
	RoadBread = {
		RefPointId = "Counter",
		RangeSetting = "Forest.HarvestRange",
		attempt = attemptCounter("RoadBread"),
	},
	Scrap = { RefPointId = "BusSpot", RangeSetting = "Bus.InteractRange", attempt = attemptBus },
}

-- Tente de déposer 1 unité de `resourceType`, apparue à `position`, dans le poste compatible.
-- Renvoie `false` sans avoir touché le sac si aucun poste ne correspond, si `position` est hors
-- de sa portée, ou s'il n'a pas de place (research R3) — l'appelant garde alors le geste existant
-- (poser au sol).
function StationDepositService.tryDeposit(player: Player, resourceType: ResourceType, position: Vector3): boolean
	local def = AUTO_DEPOSIT[resourceType]
	if def == nil then
		return false
	end
	local target = WorldService.refPoint(def.RefPointId)
	if target == nil then
		return false
	end
	if (position - target.Position).Magnitude > rangeFor(def.RangeSetting) then
		return false
	end
	return def.attempt(player)
end

function StationDepositService.Init()
	local count = 0
	for _ in AUTO_DEPOSIT do
		count += 1
	end
	log:info("Correspondances objet-poste prêtes : %d types", count)
end

return StationDepositService
