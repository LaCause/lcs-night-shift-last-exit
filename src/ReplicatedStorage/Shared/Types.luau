--!strict
-- Types partagés entre serveur et client (contracts/server-api.md, « Types partagés »).

export type Phase = "Waiting" | "Countdown" | "Day" | "Night" | "Escape" | "Ended"

export type MatchResult = "Victory" | "Defeat"

export type PlayerStatus = "Alive" | "Eliminated"

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

-- Contrat de système chargé par Shared/Util/Loader (serveur : Services/, client : Controllers/).
export type System = {
	Name: string,
	Priority: number?,
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return {}
