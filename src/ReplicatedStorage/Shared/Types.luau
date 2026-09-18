--!strict
-- Types partagés entre serveur et client (contracts/server-api.md, « Types partagés »).

export type Phase = "Waiting" | "Countdown" | "Day" | "Night" | "Escape" | "Ended"

export type MatchResult = "Victory" | "Defeat"

export type PlayerStatus = "Alive" | "Eliminated"

-- Ressources récoltables en forêt (002-premier-increment-jouable, data-model.md).
-- "Scrap" ajouté par 003-bus-evasion (data-model.md) : sert uniquement à réparer le bus.
export type ResourceType = "Essence" | "SuspectSteak" | "RoadBread" | "Scrap"

-- Sacs de portage (004-sac-collecte, data-model.md). Un seul type pour l'instant : la table
-- BAG_TYPES de BagService est conçue pour en accueillir d'autres (contenances supérieures) sans
-- logique nouvelle, seulement une entrée de plus.
export type BagType = "LittleBag"

-- État de la commande de la nuit (data-model.md, « Commande »).
-- "Preparing" ajouté : la préparation dure désormais Kitchen.PrepareDuration secondes au lieu
-- d'être instantanée (retour visuel/sonore pendant la cuisson).
export type OrderStatus = "" | "Pending" | "Preparing" | "Prepared" | "Delivered" | "Failed"

export type RejectCode = "BadEnvelope"
	| "UnknownAction"
	| "NotAllowed"
	| "RateLimited"
	| "BadPayload"
	| "WrongPhase"
	| "NoCharacter"
	| "TargetMissing"
	| "TooFar"
	| "Cooldown"
	| "HandlerError"
	-- Ajoutés par 002-premier-increment-jouable (contracts/network.md).
	| "NodeUnavailable"
	| "InventoryFull"
	| "MissingIngredients"
	| "NotPrepared"
	| "OrderClosed"
	-- Ajoutés par 003-bus-evasion (contracts/network.md).
	| "BusNotRepaired"
	| "TeamNotReady"
	-- Ajoutés par 004-sac-collecte (contracts/network.md).
	| "AlreadyCarried"
	| "NotCarrying"
	| "BagNotEquipped"
	| "BagEmpty"

export type RefPointId = "Spawn"
	| "DriveThruWindow"
	| "Intercom"
	| "Counter"
	| "CounterBell"
	| "Worktop"
	| "Fryer"
	| "Generator"
	| "NeonSign"
	| "SafeZoneCenter"
	| "BusSpot"
	-- Ajouté par 002-premier-increment-jouable (research R10).
	| "EnemySpawn"

-- Contrat de système chargé par Shared/Util/Loader (serveur : Services/, client : Controllers/).
export type System = {
	Name: string,
	Priority: number?,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return {}
