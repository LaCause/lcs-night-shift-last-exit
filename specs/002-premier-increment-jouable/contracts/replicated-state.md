# État répliqué — Premier incrément jouable

Étend `specs/001-socle-technique/contracts/replicated-state.md`. Règle inchangée : un élément
répliqué a un seul écrivain. `MatchState` (MatchService) n'est pas touché.

## `Workspace.Forest` (écrivain : ForestService)

Dossier reconstruit à chaque `MatchService.MatchStarting`. Contient une `BasePart` par nœud de
ressource, avec :

- `Name` = `NodeId` (ex. `"Essence_3"`)
- attribut `ResourceType` (string, un des `ResourceType`)
- attribut `Available` (bool)
- un `ProximityPrompt` enfant, `Intent="HarvestResource"`, `Target=NodeId`, activé/désactivé
  avec `Available` (même convention que `CounterBell`, socle R8)

Aucune autre donnée répliquée : la visibilité (transparence, collision, prompt actif) suffit à
montrer la disponibilité, par simple réplication de propriétés d'instance.

## `Workspace.Enemies` (écrivain : EnemyService)

Dossier contenant au plus un `Model` d'ennemi actif à la fois pour cet incrément. Aucun
attribut de jeu à lire côté client : le modèle et sa position se répliquent nativement. Le seul
signal client-visible est la notification ciblée `EnemyHit` (contracts/network.md).

## `ReplicatedStorage.Stock` (écrivain : InventoryService)

| Attribut | Type |
| --- | --- |
| `SuspectSteak` | number (entier) |
| `RoadBread` | number (entier) |

Créé à `InventoryService.Init`, remis à zéro à `MatchStarting`.

## Attributs sur `Player` (écrivains multiples, un par attribut)

| Attribut | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `Inv_Essence` | InventoryService | number (entier) | essence portée |
| `Inv_SuspectSteak` | InventoryService | number (entier) | steak suspect porté |
| `Inv_RoadBread` | InventoryService | number (entier) | pain de route porté |
| `Health` | HealthService | number | santé courante |
| `MaxHealth` | HealthService | number | santé maximale (copie de `Players.MaxHealth`) |

`Status` (déjà écrit par `SessionService` dans le socle) n'est pas modifié par ces nouveaux
systèmes ; `HealthService` appelle `SessionService.setStatus`, il n'écrit jamais l'attribut
`Status` lui-même.

## `ReplicatedStorage.GeneratorState` (écrivain : GeneratorService)

| Attribut | Type | Description |
| --- | --- | --- |
| `Fuel` | number | niveau courant |
| `Capacity` | number | copie de `Generator.Capacity` |
| `SafeZoneActive` | bool | `Fuel > 0` |

Créé à `GeneratorService.Init`, publié à chaque changement (dépôt d'essence, tick de drain,
`MatchStarting`).

## `ReplicatedStorage.OrderState` (écrivain : OrderService)

| Attribut | Type | Description |
| --- | --- | --- |
| `RecipeId` | string | `""` hors des nuits |
| `Status` | string | `""`, `"Pending"`, `"Prepared"`, `"Delivered"`, `"Failed"` |

Le nom et les ingrédients affichés se déduisent côté client de `RecipeId` via
`Shared/Kitchen/Recipes.luau` (table statique partagée), jamais répliqués individuellement.

## `Workspace.World.RefPoints` (écrivain : WorldService, extension additive)

Un nouveau point de référence, `EnemySpawn`, rejoint la liste construite par `WorldService`
(inchangée sinon). Voir `Shared/World/RefPoints.luau` et `Server/World/Layout.luau`.

## Zone de sécurité : valeur dérivée, non répliquée séparément

Un client ou un système calcule la protection d'une position avec
`GeneratorState.SafeZoneActive` et la distance à `RefPoints.find("SafeZoneCenter")` (rayon
`Generator.SafeZoneRadius`, lu depuis la configuration côté client comme le reste des réglages
d'affichage du socle). Aucun attribut booléen « je suis protégé » n'est répliqué par joueur.
