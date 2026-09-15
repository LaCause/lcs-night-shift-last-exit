# État répliqué — Bus et victoire par évasion

Étend `specs/002-premier-increment-jouable/contracts/replicated-state.md`. Règle inchangée : un
élément répliqué a un seul écrivain.

## `ReplicatedStorage.BusState` (écrivain : BusService)

| Attribut | Type | Description |
| --- | --- | --- |
| `Deposited` | number (entier) | ferraille cumulée déposée |
| `Required` | number (entier) | total requis — prévisualisé en direct avant l'Évasion, figé à son entrée (research R1) |
| `Repaired` | bool | `Deposited >= Required` |

Créé à `BusService.Init`, publié à chaque changement (dépôt, recalcul du total avant l'Évasion,
`MatchStarting`).

## Attribut sur `Player` (écrivain : InventoryService, extension additive)

| Attribut | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `Inv_Scrap` | InventoryService | number (entier) | ferraille portée |

Même convention que `Inv_Essence`/`Inv_SuspectSteak`/`Inv_RoadBread` (002) : remis à zéro à
`MatchStarting` et à l'élimination du joueur.

## `Workspace.World.Bus` (écrivain du contenu : WorldService à la construction, puis BusService pour l'état « réparé »)

Modèle déjà construit une seule fois au démarrage du serveur par `WorldService` (inchangé,
socle technique) — pas reconstruit par partie, contrairement à la forêt. `BusService` retrouve
cette instance via une nouvelle API additive (`WorldService.visual("Bus")`, voir
contracts/server-api.md) et modifie deux de ses pièces déjà nommées, en place :

| Pièce | Propriété modifiée | État non réparé | État réparé |
| --- | --- | --- | --- |
| `RustPatch` (déjà existante) | `Transparency` | `0` (visible) | `1` (masquée) |
| `RepairLight` (nouvelle, `Catalog.buildBus`) | `Color` | rouge (`COLORS.Warning`) | vert |

Aucune autre donnée n'est répliquée pour cet état visuel : la réplication native des propriétés
d'instance suffit, comme pour la disponibilité d'un nœud de ressource (002).

## Aucun changement à `ReplicatedStorage.MatchState`

`BusService` appelle `MatchService.endMatch("Victory", ...)` mais n'écrit jamais lui-même dans
`MatchState` : la victoire reste entièrement écrite par `MatchService`, seul écrivain, comme
toute fin de partie (socle technique, inchangé).
