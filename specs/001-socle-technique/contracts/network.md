# Contrat réseau

Source unique : `src/ReplicatedStorage/Shared/Net/Remotes.luau` (déclaration des remotes et des
schémas d'intentions). Exigences couvertes : FR-030 à FR-034, FR-042, FR-043.

## Remotes

| Nom | Type | Sens | Rôle |
| --- | --- | --- | --- |
| `Intent` | RemoteEvent | client → serveur | toutes les intentions des joueurs |
| `Notify` | RemoteEvent | serveur → client(s) | notifications de partie, rapports de dev |

- `NetService` les crée pendant son `Init`, dans le dossier `ReplicatedStorage.Remotes`.
- Côté client, `NetClient` les attend (`WaitForChild`, 10 s au plus) ; au-delà, une ERREUR est
  journalisée.
- Aucune RemoteFunction. Le serveur n'attend jamais la réponse d'un client (FR-033).

## Enveloppe

```text
Intent:FireServer(action: string, payload: { [string]: any }?)
Notify:FireClient(player, kind: string, params: { [string]: any })
Notify:FireAllClients(kind: string, params: { [string]: any })
```

Un `payload` absent vaut `{}`.

## Pipeline de validation serveur (ordre strict)

| # | Contrôle | Code de refus |
| --- | --- | --- |
| 1 | seau à jetons du joueur (`Net.IntentBurst`, `Net.IntentRefillPerSecond`), consommé par tout message reçu, même malformé | `RateLimited` |
| 2 | `action` est une chaîne de 64 caractères au plus ; `payload` est `nil` ou une table | `BadEnvelope` |
| 3 | l'intention est enregistrée | `UnknownAction` |
| 4 | si `devOnly`, la session tourne dans Studio | `NotAllowed` |
| 5 | schéma strict : clés connues, champs requis, types, bornes, nombres finis, chaînes de `Net.MaxStringLength` au plus | `BadPayload` |
| 6 | phase courante (lue dans `ReplicatedStorage.MatchState`) dans les phases autorisées | `WrongPhase` |
| 7 | si l'intention a une cible : personnage vivant avec `HumanoidRootPart` | `NoCharacter` |
| 8 | la cible désignée existe (point de référence) | `TargetMissing` |
| 9 | distance au plus égale à la portée + `Net.DistanceTolerance` | `TooFar` |
| 10 | gestionnaire exécuté sous `xpcall` ; il peut renvoyer un code (ex. `Cooldown`) | code renvoyé ou `HandlerError` |

Un refus ne produit **aucun effet**. Il est enregistré dans l'historique
(`Net.RejectionHistory` entrées) et journalisé au plus une fois par joueur et par code toutes
les `Net.RejectLogCooldown` secondes, avec le nombre de refus regroupés. Format :

```text
[LastExit/Net] Refus RingBell de Alex (12345) : TooFar (distance 23.4 > 13.0)
```

`HandlerError` est journalisé comme ERREUR, avec la trace.

## Catalogue des intentions

| Action | Payload | Phases | Cible / portée | Notes |
| --- | --- | --- | --- | --- |
| `RingBell` | `{ target: "CounterBell" }` | Countdown, Day, Night, Escape | point de référence `target`, portée `Bell.Range` | refus `Cooldown` si la sonnette a sonné il y a moins de `Bell.Cooldown` s (délai commun à tous) |
| `Dev.NextPhase` | `{}` | toutes sauf Waiting | — | dev |
| `Dev.SetTestProfile` | `{ enabled: boolean }` | toutes | — | dev ; effet à la phase suivante |
| `Dev.EndMatch` | `{ result: "Victory" \| "Defeat" }` | Day, Night, Escape | — | dev |
| `Dev.SetStatus` | `{ status: "Alive" \| "Eliminated", userId: integer? }` | toutes | — | dev ; sans `userId` : soi-même |
| `Dev.ShowState` | `{}` | toutes | — | dev ; `DevReport` (phase, nuit, seed, partie, sessions) |
| `Dev.SampleRng` | `{ context: string, count: integer 1..20 }` | toutes | — | dev ; `DevReport` des tirages |
| `Dev.GetRejections` | `{ count: integer 1..50 }` | toutes | — | dev ; `DevReport` des derniers refus du demandeur |
| `Dev.TestVisualFallback` | `{}` | toutes | — | dev ; construit un visuel dont le modèle manque et rapporte le résultat |
| `Dev.Ping` | `{}` | toutes | — | dev ; sans effet, sert au test de cadence |

Toutes les intentions `Dev.*` sont `devOnly` (FR-043).

## Notifications (`Notify`)

| Type | Destinataires | Paramètres |
| --- | --- | --- |
| `PhaseStarted` | tous | `{ phase, night, totalNights, duration }` |
| `PlayerJoined` | tous | `{ name }` |
| `PlayerLeft` | tous | `{ name }` |
| `StatusChanged` | tous | `{ name, status }` |
| `BellRang` | tous | `{ name }` |
| `MatchEnded` | tous | `{ result, night, totalNights }` |
| `DevReport` | demandeur uniquement | `{ title: string, lines: { string } }` |

Les textes affichés viennent de `Strings.luau` (clé = type, paramètres interpolés). Un type
inconnu est ignoré côté client.

## Liste de contrôle des requêtes invalides (SC-006)

Jouée par le bouton « Checklist requêtes » du panneau de dev, **depuis le point d'apparition**
(situé hors de portée de la sonnette). Le panneau envoie chaque cas, attend 3 s (le seau se
remplit), appelle `Dev.GetRejections`, puis compare les codes obtenus aux codes attendus.

| # | Envoi | Code attendu |
| --- | --- | --- |
| 1 | `Intent:FireServer(42, {})` | `BadEnvelope` |
| 2 | `("Nope", {})` | `UnknownAction` |
| 3 | `("RingBell", "x")` | `BadEnvelope` |
| 4 | `("RingBell", { target = "CounterBell", extra = 1 })` | `BadPayload` |
| 5 | `("RingBell", { target = string.rep("a", 500) })` | `BadPayload` |
| 6 | `("Dev.SampleRng", { context = "x", count = 0/0 })` | `BadPayload` |
| 7 | `("RingBell", { target = "Nowhere" })` | `TargetMissing` |
| 8 | `("RingBell", { target = "CounterBell" })` depuis le point d'apparition | `TooFar` |
| 9 | 30 × `("Dev.Ping", {})` en rafale | au moins 20 × `RateLimited` |
| 10 | `("RingBell", { target = "CounterBell" })` pendant l'écran de fin | `WrongPhase` (cas joué seulement en phase `Ended`, sinon affiché « à relancer pendant l'écran de fin ») |

Critère de réussite : 100 % des cas donnent le code attendu, l'état de jeu est inchangé (pas de
sonnerie, pas de changement de phase) et chaque code apparaît dans le journal serveur.
