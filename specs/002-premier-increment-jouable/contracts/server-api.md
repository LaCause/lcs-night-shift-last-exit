# Contrat des systèmes serveur — Premier incrément jouable

Étend `specs/001-socle-technique/contracts/server-api.md` (contrat `{Name, Priority, Init,
Start}`, découverte automatique par `Loader`). Sept nouveaux systèmes rejoignent
`ServerScriptService/Server/Services/`, avec les priorités suivantes (celles du socle sont
rappelées entre parenthèses pour situer l'ordre) :

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 10 | VisualService | (socle) |
| 20 | WorldService | (socle) |
| 30 | NetService | (socle) |
| 35 | NotifyService | (socle) |
| 40 | SessionService | (socle) |
| **42** | **ForestService** | oui |
| **44** | **GeneratorService** | oui |
| **45** | **InventoryService** | oui |
| **46** | **HealthService** | oui |
| 50 | MatchService | (socle) |
| **52** | **AmbianceService** | oui |
| 60 | BellService | (socle) |
| **65** | **OrderService** | oui |
| **70** | **EnemyService** | oui |
| 90 | DevService | (socle, étendu) |

## Graphe de dépendances (acyclique)

```text
ForestService      → WorldService (RefPoints), MatchService (rng, signal MatchStarting), NetService
GeneratorService    → WorldService (RefPoints), MatchService (signal MatchStarting), NetService
InventoryService    → SessionService (PlayerJoined/StatusChanged), MatchService (signal MatchStarting), NetService
HealthService       → SessionService (PlayerJoined, setStatus), MatchService (signal MatchStarting)
AmbianceService     → MatchService (PhaseStarted/PhaseEnded)
OrderService        → MatchService (PhaseStarted/PhaseEnded, rng), InventoryService (stock), NetService
EnemyService        → OrderService (signal OrderFailed), MatchService (PhaseEnded), WorldService (RefPoints),
                      GeneratorService (zone de sécurité), HealthService (dégâts)
DevService (étendu) → tous les systèmes ci-dessus (commandes de test, comme dans le socle)
```

Aucun système de gameplay n'est requis par `MatchService`, `SessionService`, `WorldService` ou
`NetService` : le sens de dépendance suit toujours socle → gameplay, jamais l'inverse (research
R1, R9 ; identique au principe déjà appliqué par `BellService` dans le socle).

## Nouvelles API par système

### ForestService

- `ForestService.findNode(id: string): BasePart?` — résolveur pour `NetService.registerIntent`
  (research R3), aussi utilisable par les outils de dev.
- `ForestService.isReady(): boolean`

### GeneratorService

- `GeneratorService.deposit(player: Player, amount: number): number` — retourne la quantité
  réellement ajoutée (peut être < `amount` si la capacité est atteinte).
- `GeneratorService.hasFuel(): boolean`
- `GeneratorService.isSafeZoneActive(): boolean` (alias explicite de `hasFuel`, utilisé par
  `EnemyService`)
- `GeneratorService.isPositionSafe(position: Vector3): boolean` — distance à `SafeZoneCenter`
  ≤ `Generator.SafeZoneRadius`, et `hasFuel()`.

### InventoryService

- `InventoryService.addPersonal(player: Player, resource: ResourceType, amount: number): boolean`
  — `false` si `Forest.InventoryCapacity` serait dépassée (aucun ajout partiel).
- `InventoryService.depositToStock(player: Player)` — vide `SuspectSteak`/`RoadBread` de
  l'inventaire du joueur vers `Stock`.
- `InventoryService.depositEssence(player: Player): number` — vide `Inv_Essence` du joueur,
  retourne la quantité prélevée (consommée ensuite par `GeneratorService.deposit`).
- `InventoryService.hasStock(requirements: { [ResourceType]: number }): boolean`
- `InventoryService.consumeStock(requirements: { [ResourceType]: number })` — appelé seulement
  après `hasStock` a confirmé la disponibilité (pas de vérification redondante).

### HealthService

- `HealthService.damage(player: Player, amount: number)` — no-op si le joueur n'est pas en vie.
- `HealthService.get(player: Player): number?`

### OrderService

- `OrderService.OrderFailed: Signal<string>` (recipeId)
- `OrderService.getStatus(): (string, string)` — `(recipeId, status)`

### EnemyService

- Aucune API publique nécessaire pour cet incrément (un seul consommateur : `DevService`, pour
  forcer un test manuel via `EnemyService.spawnAt(refPointId: string)`).

## Commandes de développement ajoutées (`DevService`, Studio uniquement)

Cohérent avec FR-042/FR-043 du socle (réservées à Studio, refusées ailleurs) :

| Intention | Effet |
| --- | --- |
| `Dev.GiveResources` | ajoute des ressources à l'inventaire de l'appelant (test sans exploration) |
| `Dev.ForceOrderResult` | force `OrderState.Status` à `Delivered` ou `Failed` (test de l'écran, sans attendre la nuit) |
| `Dev.SpawnEnemy` | déclenche l'apparition de l'ennemi immédiatement (équivalent à un échec de commande) |
| `Dev.ShowGameplayState` | rapporte carburant, stock, commande active et santé de l'appelant |

Ces commandes suivent exactement le même schéma que celles du socle (`Dev.*`, `devOnly: true`,
validées par le même pipeline).
