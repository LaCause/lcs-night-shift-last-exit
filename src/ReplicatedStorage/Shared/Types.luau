--!strict
-- Types partagés entre serveur et client (contracts/server-api.md, « Types partagés »).

export type Phase = "Waiting" | "Countdown" | "Day" | "Night" | "Escape" | "Ended"

export type MatchResult = "Victory" | "Defeat"

export type PlayerStatus = "Alive" | "Eliminated"

-- Ressources récoltables en forêt (002-premier-increment-jouable, data-model.md).
export type ResourceType = "Essence" | "SuspectSteak" | "RoadBread"

-- État de la commande de la nuit (data-model.md, « Commande »).
export type OrderStatus = "" | "Pending" | "Prepared" | "Delivered" | "Failed"

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
