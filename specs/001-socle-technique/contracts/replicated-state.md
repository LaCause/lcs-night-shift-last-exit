# Contrat d'état répliqué

Tout ce que les clients lisent de l'état de jeu. Les clients **lisent** seulement : chaque
élément n'a qu'un seul écrivain, côté serveur (principe III). Exigences couvertes : FR-007,
FR-019, FR-024, FR-034, FR-035.

## `ReplicatedStorage.MatchState` (Folder)

Créé par `MatchService` pendant son `Init`. Seul écrivain : `MatchService`.

| Attribut | Type | Valeurs |
| --- | --- | --- |
| `Phase` | string | `Waiting`, `Countdown`, `Day`, `Night`, `Escape`, `Ended` |
| `Night` | number | 0..`TotalNights` (voir [data-model.md](../data-model.md)) |
| `TotalNights` | number | nombre de nuits de la partie en cours |
| `PhaseEndsAt` | number | horodatage `workspace:GetServerTimeNow()` de fin de phase ; `0` = sans limite |
| `Result` | string | `""`, `"Victory"`, `"Defeat"` |
| `MatchId` | number | identifiant de la partie |
| `TestProfile` | boolean | profil de test actif (affiché dans le panneau de dev) |

Temps restant côté client :
`PhaseEndsAt > 0 and math.max(0, PhaseEndsAt - workspace:GetServerTimeNow()) or nil`, où
`nil` signifie « sans limite ».

La seed n'est **pas** répliquée : elle ne figure que dans le journal serveur et dans
`Dev.ShowState`.

## Attributs de `Player`

Seul écrivain : `SessionService`.

| Attribut | Type | Valeurs |
| --- | --- | --- |
| `Status` | string | `"Alive"`, `"Eliminated"` |

L'état de l'équipe se lit sur `Players:GetPlayers()` et sur l'attribut `Status` de chaque
joueur.

## Monde de départ (`Workspace.World`)

Construit par `WorldService` pendant son `Init`, avant le chargement de tout personnage.

```text
Workspace.World (Folder)
├── Ground            (Part)          sol provisoire
├── Restaurant        (Model)         visuel catalogué « Restaurant »
├── NeonSign          (Model)         visuel catalogué « NeonSign »
├── Bus               (Model)         visuel catalogué « Bus »
├── RestaurantSpawn   (SpawnLocation) Neutral, placé sur le point de référence Spawn
└── RefPoints         (Folder)
    ├── Spawn, DriveThruWindow, Intercom, Counter, Worktop, Fryer,
    │   Generator, NeonSign, SafeZoneCenter, BusSpot      (Part invisible)
    └── CounterBell   (Part visible + ProximityPrompt)
```

Chaque point de référence :

- porte l'attribut `RefPoint = <Id>` et le tag CollectionService `RefPoint` ;
- est ancré, avec `CanCollide`, `CanTouch` et `CanQuery` à `false` ;
- est invisible (`Transparency = 1`), sauf `CounterBell`.

Un `SpawnLocation` étranger présent dans le Workspace (ex. gabarit Studio) est désactivé au
démarrage, avec un avertissement.

## Sonnette : `Workspace.World.RefPoints.CounterBell`

| Élément | Valeur |
| --- | --- |
| Attribut `LastRungAt` | number, horodatage serveur de la dernière sonnerie acceptée |
| Attribut `LastRungBy` | string, `DisplayName` du joueur qui a sonné |
| `ProximityPrompt` | `ActionText` « Sonner », `ObjectText` « Sonnette », `HoldDuration = 0`, `MaxActivationDistance = Bell.Range`, `RequiresLineOfSight = false` ; attributs `Intent = "RingBell"` et `Target = "CounterBell"` |

- Côté client, `InteractionController` écoute `ProximityPromptService.PromptTriggered` et envoie
  l'intention désignée par les attributs `Intent` et `Target` de l'invite (ici `RingBell` sur
  `CounterBell`) : les interactions futures n'auront pas besoin de nouveau code client.
- `BellEffectController` joue l'effet local (flash et petit rebond) à chaque changement de
  `LastRungAt`.
- Le serveur n'écoute jamais `Triggered`.

## `ReplicatedStorage.Remotes` (Folder)

`Intent` et `Notify` (RemoteEvent), créés par `NetService` : voir [network.md](./network.md).

## `ReplicatedStorage.Assets` (Folder)

Déclaré dans `default.project.json`, vide dans le socle. Il accueillera les futurs modèles
externes, référencés par `ModelName` dans le catalogue de visuels.
