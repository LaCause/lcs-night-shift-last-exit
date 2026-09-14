# Data Model — Premier incrément jouable

Étend le modèle du socle (`specs/001-socle-technique/data-model.md`) sans le modifier. Toutes
les entités ci-dessous sont détenues par un seul système, qui en est l'unique écrivain.

## ResourceType (type partagé)

```text
"Essence" | "SuspectSteak" | "RoadBread"
```

Ajouté à `Types.luau`. Les noms affichés (« Essence », « Steak suspect », « Pain de route »)
vivent dans `Strings.luau`, jamais en dur ailleurs.

## Point de ressource (ForestService, `Workspace.Forest`)

| Champ | Type | Description |
| --- | --- | --- |
| `NodeId` | string | identifiant unique généré à la construction (`"<Type>_<n>"`) |
| `ResourceType` | ResourceType | type récolté |
| `Available` | bool | attribut sur la pièce ; `false` pendant le délai de réapparition |
| `AvailableAt` | number | horodatage serveur (`GetServerTimeNow`) auquel le nœud redevient disponible |

Le nœud est une `BasePart` avec un `ProximityPrompt` (`Intent="HarvestResource"`,
`Target=NodeId`), suivant le même modèle que `CounterBell`. Devenir indisponible = mettre
`Transparency`, `CanCollide` et `ProximityPrompt.Enabled` en conséquence ; aucune donnée
supplémentaire n'est répliquée pour l'affichage, la réplication des propriétés d'instance
suffit (comme la sonnette).

**Cycle de vie** : créé par lot au signal `MatchService.MatchStarting` (régénère
`Workspace.Forest`, R1) ; un nœud récolté devient indisponible immédiatement, puis redevient
disponible seul (tâche différée par nœud) après `Forest.RespawnDelay`.

## Inventaire personnel (InventoryService, attributs sur `Player`)

| Attribut | Type | Description |
| --- | --- | --- |
| `Inv_Essence` | number (entier) | quantité d'essence portée |
| `Inv_SuspectSteak` | number (entier) | quantité de steak suspect portée |
| `Inv_RoadBread` | number (entier) | quantité de pain de route portée |

Somme des trois DOIT rester ≤ `Forest.InventoryCapacity`. Remis à zéro à `MatchStarting` et à
l'élimination du joueur (`SessionService.StatusChanged` vers `"Eliminated"` — FR-005).

## Stock partagé (InventoryService, `ReplicatedStorage.Stock`)

| Attribut | Type | Description |
| --- | --- | --- |
| `SuspectSteak` | number (entier) | quantité disponible pour la cuisine |
| `RoadBread` | number (entier) | quantité disponible pour la cuisine |

Pas d'entrée `Essence` : l'essence ne transite jamais par le stock partagé, seulement vers le
générateur (FR-006 à FR-009). Pas de plafond (une équipe qui sur-récolte ne perd rien).

## Générateur (GeneratorService, `ReplicatedStorage.GeneratorState`)

| Attribut | Type | Description |
| --- | --- | --- |
| `Fuel` | number | niveau courant, `0 ≤ Fuel ≤ Capacity` |
| `Capacity` | number | copie de `Generator.Capacity`, pour l'affichage sans lire la config côté client |
| `SafeZoneActive` | bool | `Fuel > 0` |

**Transitions** : `Fuel` diminue de `Generator.DrainPerSecond` par seconde tant que
`MatchService.isActive()` ; augmente de `essenceDéposée * Generator.FuelPerEssence`, plafonné à
`Capacity`, le surplus restant dans l'inventaire du joueur (FR-007). Remis à
`Generator.InitialFuel` à `MatchStarting`.

## Zone de sécurité (dérivée, pas d'entité propre)

Calculée à la demande : un point est protégé si `GeneratorState.SafeZoneActive` est vrai et que
sa distance à `RefPoints.find("SafeZoneCenter")` est ≤ `Generator.SafeZoneRadius`. Aucune
donnée supplémentaire à répliquer : le halo lumineux (R5) suffit à la rendre visible.

## Recette (statique, `Shared/Kitchen/Recipes.luau`)

| Champ | Type | Description |
| --- | --- | --- |
| `Id` | string | identifiant (ex. `"SuspectBurger"`) |
| `Ingredients` | `{ [ResourceType]: number }` | quantités requises dans le stock partagé |
| `NameKey` | string | clé `Strings` du nom affiché |

Table figée, un seul module partagé, une seule entrée pour cet incrément (R7).

## Commande (OrderService, `ReplicatedStorage.OrderState`)

| Attribut | Type | Description |
| --- | --- | --- |
| `RecipeId` | string | `""` si aucune commande active (Jour, Attente, Fin) |
| `Status` | `"" \| "Pending" \| "Prepared" \| "Delivered" \| "Failed"` | état courant |

**Transitions** (une commande par nuit) :

```text
(début de Nuit) → Pending
Pending --PrepareOrder (ingrédients suffisants)--> Prepared
Pending --PrepareOrder (ingrédients insuffisants)--> Pending (refusé, MissingIngredients)
Prepared --DeliverOrder--> Delivered
(fin de Nuit, Status == Pending ou Prepared) → Failed
```

`Delivered` et `Failed` sont terminaux pour la nuit courante ; la nuit suivante recommence à
`Pending` avec une recette éventuellement différente.

## Ennemi (EnemyService, `Workspace.Enemies`, au plus une instance pour cet incrément)

| Champ (interne, non répliqué) | Type | Description |
| --- | --- | --- |
| `Model` | Model | instance visuelle, `PrimaryPart` déplacé par CFrame |
| `Target` | Player? | joueur actuellement poursuivi (hors zone de sécurité) |
| `LastContactAt` | `{ [Player]: number }` | horodatage du dernier coup porté à chaque joueur (cadence des dégâts) |
| `LastSeenTargetAt` | number | horodatage du dernier contact avec une cible valide (déclenche le repli) |

**Cycle de vie** : apparu par `OrderService.OrderFailed` (R9) à `RefPoints.find("EnemySpawn")` ;
détruit au changement de phase (`MatchService.PhaseEnded`) ou après
`Enemy.GiveUpDelay`/`Enemy.MaxLifetime` sans cible atteignable (R8).

## Santé du joueur (HealthService, attributs sur `Player`)

| Attribut | Type | Description |
| --- | --- | --- |
| `Health` | number | `0 ≤ Health ≤ MaxHealth` |
| `MaxHealth` | number | copie de `Players.MaxHealth` |

**Transitions** : initialisée à `Players.MaxHealth` à l'arrivée du joueur et remise à ce niveau
à chaque `MatchStarting` (R4). Décrémentée par `EnemyService` au contact
(`Enemy.ContactDamage`). À 0, `SessionService.setStatus(player, "Eliminated")` est appelé une
seule fois (aucune réapparition automatique pour le reste de la partie, comportement déjà en
place dans le socle).

## Relations avec les entités du socle

- Le stock partagé et les commandes réutilisent les points de référence existants (`Counter`,
  `Worktop`, `DriveThruWindow`, `Generator`) sans les modifier.
- La forêt et l'ennemi ajoutent un seul point de référence (`EnemySpawn`) à la liste fermée du
  socle.
- La santé se déclenche vers le statut de session existant (`PlayerStatus`) sans le redéfinir.
- Toutes les nouvelles horloges (drain du générateur, réapparition des nœuds, déplacement de
  l'ennemi) sont indépendantes de l'horloge de partie ; seules leurs bornes (début/fin) suivent
  les signaux `MatchService` (R1, R9).
