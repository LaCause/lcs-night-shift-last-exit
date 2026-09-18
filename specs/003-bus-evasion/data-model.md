# Data Model — Bus et victoire par évasion

Étend le modèle de `specs/002-premier-increment-jouable/data-model.md` sans le modifier, à
l'exception d'un renommage de fonction sans effet sur les données qu'elle manipule (R4). Toutes
les entités ci-dessous sont détenues par un seul système, qui en est l'unique écrivain.

## ResourceType (type partagé, extension additive)

```text
"Essence" | "SuspectSteak" | "RoadBread" | "Scrap"
```

`"Scrap"` (« Ferraille » dans `Strings.luau`) rejoint le type déjà partagé ; aucune des trois
valeurs existantes ne change de sens. Comme l'essence, la ferraille ne transite jamais par le
stock partagé du restaurant (`ReplicatedStorage.Stock`) : elle va uniquement au bus.

## Tas de ferraille (ForestService, `Workspace.Forest` — même entité « Point de ressource » que 002)

Aucun nouveau champ : un tas de ferraille est un point de ressource ordinaire
(`specs/002-premier-increment-jouable/data-model.md`, « Point de ressource »), avec
`ResourceType = "Scrap"`. Généré, récolté et réapparu exactement comme les trois ressources
existantes (R3) ; visuel propre (« tas de ferraille ») ajouté à `Catalog.luau`.

## Inventaire personnel (InventoryService, attributs sur `Player`, extension additive)

| Attribut | Type | Description |
| --- | --- | --- |
| `Inv_Scrap` | number (entier) | quantité de ferraille portée |

Rejoint `Inv_Essence`/`Inv_SuspectSteak`/`Inv_RoadBread` ; compte dans le même plafond
`Forest.InventoryCapacity`. Remis à zéro à `MatchStarting` et à l'élimination du joueur, comme
les trois autres (règle déjà en place, aucun changement).

## Bus (BusService, `ReplicatedStorage.BusState`)

| Attribut | Type | Description |
| --- | --- | --- |
| `Deposited` | number (entier) | ferraille cumulée déposée au bus depuis le début de la partie, `0 ≤ Deposited ≤ Required` |
| `Required` | number (entier) | total requis pour une réparation complète — prévisualisé en direct avant l'Évasion, figé à son entrée (R1) |
| `Repaired` | number → bool | `Deposited >= Required` |

**Transitions** :

```text
(MatchStarting)         → Deposited = 0, Required = Bus.ScrapPerPlayer × joueurs présents, Repaired = false, non figé
(PlayerJoined/Left,      → Required recalculé (Bus.ScrapPerPlayer × joueurs présents), tant que non figé
 tant que non figé)
(PhaseStarted "Escape") → Required figé à sa valeur courante, ne change plus pour le reste de la partie
RepairBus (room > 0)    → Deposited += ferraille déposée (plafonnée à Required - Deposited)
RepairBus (room == 0)   → aucun effet (bus déjà réparé), comme le générateur déjà plein
Deposited atteint       → Repaired = true, notification diffusée BusRepaired, voyant du bus passe au vert,
Required                  rouille masquée (R7)
```

`Deposited` et `Required` ne redescendent jamais après avoir été atteints/figés pendant une
même partie ; seule une nouvelle partie (`MatchStarting`) les réinitialise.

## Départ (dérivé, pas d'entité propre)

Pas de nouvel état répliqué : le départ est une action instantanée (`DepartBus`), pas un état à
observer. Sa condition (`Repaired == true` ET tous les joueurs en vie à portée de `BusSpot`) est
vérifiée au moment de l'intention par `BusService`, jamais répliquée à l'avance — le client n'a
besoin de connaître que `Repaired` (déjà répliqué) pour savoir si le départ est en principe
possible ; la présence de l'équipe se découvre au moment de l'action, comme n'importe quelle
autre intention (aucune préannonce nécessaire, cohérent avec le reste du jeu qui ne prévalide
jamais côté client une règle serveur).

## Relations avec les entités existantes

- Le bus réutilise le point de référence existant `BusSpot` (socle technique) et le modèle déjà
  construit par `WorldService` au démarrage — aucune nouvelle entité de scène, seulement deux
  pièces modifiées en place (`RustPatch` masquée, `RepairLight` ajoutée) sur un modèle qui
  existait déjà, purement décoratif jusqu'ici.
- La ferraille réutilise entièrement l'entité « Point de ressource » et le cycle de vie de
  `ForestService` (002) : génération par lot à `MatchStarting`, délai de réapparition par nœud,
  capacité d'inventaire partagée avec les trois autres ressources.
- Le départ réutilise `MatchService.MatchResult` et le cycle déjà en place
  (`MatchService.endMatch` → `MatchEnded` → écran de fin → nouvelle partie automatique, socle
  technique) sans aucune modification de ce cycle.
