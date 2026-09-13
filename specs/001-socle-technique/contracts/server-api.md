# Contrat des systèmes (API interne)

C'est l'interface sur laquelle les fonctionnalités suivantes (MVP, forêt, commandes, ennemis…)
se brancheront. Seules les signatures sont données ici ; les corps relèvent de
l'implémentation. Exigences couvertes : FR-006, FR-009, FR-010, FR-017 à FR-029, FR-039 à
FR-041.

## Contrat de système (Loader)

```luau
export type System = {
	Name: string,
	Priority: number?, -- défaut 100 ; ordre croissant, puis par Name
	Init: ((self: System) -> ())?, -- préparation locale, enregistrements
	Start: ((self: System) -> ())?, -- comportement d'exécution (événements, horloge)
}
```

- `Shared/Util/Loader.luau` charge chaque ModuleScript placé **directement** dans le dossier
  cible (pas de récursion).
- Dossiers cibles : `ServerScriptService.Server.Services` côté serveur,
  `StarterPlayerScripts.Client.Controllers` côté client.
- Déroulé : `require` de chaque module, puis tous les `Init`, puis tous les `Start` ; chaque
  `Start` tourne dans son propre thread. Chaque étape passe par `xpcall`.
- Un système dont le `require` ou l'`Init` a échoué n'est pas démarré. Le journal nomme le
  système et donne la trace.
- `Debug.FailSystemAtInit = "<Name>"` force l'échec de l'`Init` de ce système (Studio
  uniquement) : c'est ainsi qu'on teste SC-011.
- Ajouter un système = ajouter un fichier : aucun autre fichier n'est modifié (FR-006).

## Ordre de démarrage côté serveur

| Priority | Système | Rôle |
| --- | --- | --- |
| 10 | `VisualService` | catalogue de visuels et remplaçants |
| 20 | `WorldService` | monde de départ, points de référence, point d'apparition |
| 30 | `NetService` | remotes et pipeline des intentions |
| 35 | `NotifyService` | notifications |
| 40 | `SessionService` | sessions, statuts, apparitions |
| 50 | `MatchService` | horloge de partie, seed, fin et redémarrage |
| 60 | `BellService` | interaction de référence |
| 90 | `DevService` | commandes de développement (Studio) |

## Dépendances autorisées (graphe acyclique)

```text
Shared (Config, Log, Signal, Rng, Validate, Strings, Types, Remotes, RefPoints, Catalog)
VisualService  → Catalog
WorldService   → VisualService, Layout, RefPoints
NetService     → Remotes, Validate, RefPoints (cibles, recherche par tag) ; lit MatchState (phase)
NotifyService  → NetService
SessionService → WorldService (point d'apparition)
MatchService   → SessionService, NotifyService, Rng
BellService    → NetService, NotifyService, WorldService
DevService     → NetService, NotifyService, MatchService, SessionService, VisualService, Rng
```

Règles :

- Aucun cycle.
- `NetService` lit la phase dans l'attribut `ReplicatedStorage.MatchState.Phase` au lieu
  d'appeler `MatchService`.
- `SessionService` n'appelle jamais `MatchService` : il publie des signaux que `MatchService`
  écoute.

## Types partagés (`Shared/Types.luau`)

```luau
export type Phase = "Waiting" | "Countdown" | "Day" | "Night" | "Escape" | "Ended"
export type MatchResult = "Victory" | "Defeat"
export type PlayerStatus = "Alive" | "Eliminated"
export type RejectCode = "BadEnvelope" | "UnknownAction" | "NotAllowed" | "RateLimited"
	| "BadPayload" | "WrongPhase" | "NoCharacter" | "TargetMissing" | "TooFar"
	| "Cooldown" | "HandlerError"
export type RefPointId = "Spawn" | "DriveThruWindow" | "Intercom" | "Counter" | "CounterBell"
	| "Worktop" | "Fryer" | "Generator" | "NeonSign" | "SafeZoneCenter" | "BusSpot"
```

## Utilitaires partagés

```luau
-- Shared/Util/Signal.luau : chaque écouteur tourne dans son propre thread, sous xpcall
Signal.new(owner: string): Signal<T...>
signal:Connect(fn: (T...) -> ()): Connection
signal:Fire(...: T...): ()

-- Shared/Util/Log.luau
Log.new(system: string): Logger  -- logger:debug/info/warn/error(message: string, ...any)

-- Shared/Util/Rng.luau
Rng.hash32(text: string): number
Rng.forContext(seed: number, ...: string | number): Random

-- Shared/World/RefPoints.luau (serveur et client)
RefPoints.isValid(id: string): boolean
RefPoints.find(id: RefPointId): BasePart? -- tag CollectionService « RefPoint » + attribut RefPoint

-- Shared/Net/Validate.luau (schémas déclaratifs)
Validate.string(maxLength: number?): Check
Validate.number(min: number, max: number): Check        -- refuse NaN et ±inf
Validate.integer(min: number, max: number): Check
Validate.boolean(): Check
Validate.enum(choices: { string }): Check
Validate.optional(check: Check): Check
Validate.object(fields: { [string]: Check }): Schema    -- refuse les clés inconnues
Validate.check(schema: Schema, value: any): (boolean, string?)

-- Shared/Config (config résolue et gelée)
Config.get(domain: string, key: string, useTest: boolean?): any
Config.TestProfileDefault: boolean
```

## Services serveur

```luau
-- MatchService
MatchService.PhaseStarted: Signal<(phase: Phase, night: number)>
MatchService.PhaseEnded: Signal<(phase: Phase, night: number)>
MatchService.MatchStarted: Signal<(matchId: number, seed: number)>
MatchService.MatchEnded: Signal<(result: MatchResult, night: number)>
MatchService.getPhase(): Phase
MatchService.getNight(): number
MatchService.getSeed(): number
MatchService.getMatchId(): number
MatchService.isActive(): boolean                   -- Day, Night ou Escape
MatchService.rng(...: string | number): Random     -- flux dérivé de la seed de la partie
MatchService.endMatch(result: MatchResult, reason: string): boolean -- false si ignoré
MatchService.skipPhase(): ()
MatchService.setTestProfile(enabled: boolean): ()

-- SessionService
SessionService.PlayerJoined: Signal<(player: Player)>
SessionService.PlayerLeft: Signal<(player: Player)>
SessionService.StatusChanged: Signal<(player: Player, status: PlayerStatus)>
SessionService.get(player: Player): Session?
SessionService.all(): { Session }
SessionService.countPresent(): number
SessionService.countAlive(): number
SessionService.setStatus(player: Player, status: PlayerStatus): ()
SessionService.resetAll(): ()     -- tous « en vie »
SessionService.respawnAll(): ()   -- LoadCharacter au restaurant

-- NetService
export type IntentDef = {
	schema: Validate.Schema,
	phases: { Phase }?,                                  -- nil = toutes
	target: { field: string, rangeSetting: string }?,    -- ex. { field = "target", rangeSetting = "Bell.Range" }
	devOnly: boolean?,
	handler: (player: Player, payload: any) -> RejectCode?,
}
NetService.registerIntent(name: string, def: IntentDef): ()
NetService.remote(name: "Intent" | "Notify"): RemoteEvent
NetService.recentRejections(player: Player, count: number): { Rejection }

-- NotifyService
NotifyService.broadcast(kind: string, params: { [string]: any }): ()
NotifyService.send(player: Player, kind: string, params: { [string]: any }): ()

-- WorldService
WorldService.refPoint(id: RefPointId): BasePart?
WorldService.spawnLocation(): SpawnLocation
WorldService.isReady(): boolean

-- VisualService
VisualService.build(id: string): (Model, boolean) -- boolean = remplaçant utilisé
```

## Modules clients (`Shared/Client`)

```luau
-- MatchStateClient : lecture de ReplicatedStorage.MatchState
MatchStateClient.get(): { phase: Phase, night: number, totalNights: number, result: string, matchId: number }
MatchStateClient.remaining(): number?   -- nil = sans limite
MatchStateClient.Changed: Signal<()>

-- NetClient
NetClient.send(action: string, payload: { [string]: any }?): ()
NetClient.onNotify(kind: string, fn: (params: { [string]: any }) -> ()): Connection

-- UiKit : briques d'interface lisibles sur téléphone (Scale, UITextSizeConstraint)
```

## Comment une fonctionnalité future se branche

1. Ajouter `Services/<Nom>Service.luau`, qui respecte le contrat de système.
2. Dans son `Init` : enregistrer ses intentions (`NetService.registerIntent`) et déclarer ses
   réglages dans `Settings.luau`.
3. Dans son `Start` : écouter `MatchService.PhaseStarted`, `MatchEnded`, etc.
4. Tirages aléatoires : `MatchService.rng("<contexte>", …)`, jamais `math.random`.
5. Visuels : les déclarer dans `Catalog.luau` avec un remplaçant en primitives.
