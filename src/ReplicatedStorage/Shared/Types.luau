--!strict
-- Types partagés entre serveur et client (contracts/server-api.md, « Types partagés »).

export type Phase = "Waiting" | "Countdown" | "Day" | "Night" | "Escape" | "Ended"

export type MatchResult = "Victory" | "Defeat"

export type PlayerStatus = "Alive" | "Eliminated"

-- Ressources récoltables en forêt (002-premier-increment-jouable, data-model.md).
-- "Scrap" ajouté par 003-bus-evasion (data-model.md) : sert uniquement à réparer le bus.
export type ResourceType = "Essence" | "SuspectSteak" | "RoadBread" | "Scrap"

-- Sacs de portage (004-sac-collecte, data-model.md). "MediumBag" ajouté par
-- 008-boutique-persistance (avantage de départ "sac de départ agrandi") : la table BAG_TYPES de
-- BagService était conçue pour en accueillir d'autres sans logique nouvelle, seulement une entrée
-- de plus (research R6).
export type BagType = "LittleBag" | "MediumBag"

-- État de la commande de la nuit (data-model.md, « Commande »).
-- "Preparing" ajouté : la préparation dure désormais Kitchen.PrepareDuration secondes au lieu
-- d'être instantanée (retour visuel/sonore pendant la cuisson).
export type OrderStatus = "" | "Pending" | "Preparing" | "Prepared" | "Delivered" | "Failed"

export type RejectCode =
	"BadEnvelope"
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
	-- Ajoutés par 008-boutique-persistance (contracts/server-api.md).
	| "ItemUnknown"
	| "AlreadyOwned"
	| "InsufficientFunds"
	| "NotOwned"
	-- Ajoutés par 009-craft-etabli (contracts/server-api.md).
	| "RecipeUnknown"
	| "InsufficientResources"
	| "NoBenefit"

export type RefPointId =
	"Spawn"
	| "DriveThruWindow"
	| "Intercom"
	| "Counter"
	| "Worktop"
	| "Fryer"
	| "Generator"
	| "NeonSign"
	| "SafeZoneCenter"
	| "BusSpot"
	-- Ajouté par 002-premier-increment-jouable (research R10).
	| "EnemySpawn"
	-- Ajouté par 009-craft-etabli (research R1) : nouveau lieu, pas un point orphelin recyclé.
	| "Workbench"

-- Contrat de système chargé par Shared/Util/Loader (serveur : Services/, client : Controllers/).
export type System = {
	Name: string,
	Priority: number?,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return {}
