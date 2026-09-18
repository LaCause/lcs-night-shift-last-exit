# Contrat des systèmes — Sac de collecte et manipulation des objets

Étend `specs/002-premier-increment-jouable/contracts/server-api.md` et
`specs/003-bus-evasion/contracts/server-api.md` (contrat `{Name, Priority, Init, Start}`,
découverte automatique par `Loader`, inchangé). Deux systèmes serveur et un contrôleur client
rejoignent le projet.

## Systèmes serveur (`ServerScriptService/Server/Services/`)

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 10 | VisualService | (existant) |
| 20 | WorldService | (existant) |
| 30 | NetService | (existant) |
| 35 | NotifyService | (existant) |
| 40 | SessionService | (existant) |
| 42 | ForestService | (existant, **modifié** : invites retirées, notification ajoutée) |
| 44 | GeneratorService | (existant) |
| 45 | InventoryService | (existant, **modifié** : source de la contenance) |
| 46 | HealthService | (existant) |
| **47** | **BagService** | **oui** |
| **48** | **CarryService** | **oui** |
| 50 | MatchService | (existant) |
| 52 | AmbianceService | (existant) |
| 60 | BellService | (existant) |
| 65 | OrderService | (existant) |
| 66 | BusService | (existant) |
| 70 | EnemyService, FeedbackVisualService | (existants) |
| 90 | DevService | (existant, étendu) |

## Contrôleurs client (`StarterPlayerScripts/Client/Controllers/`)

| Priority | Contrôleur | Nouveau ? |
| --- | --- | --- |
| 10 | InteractionController | (existant, **non modifié** — les postes gardent leurs invites) |
| **12** | **PointerController** | **oui** |
| 50 | BellEffectController | (existant) |
| 55 | EnemyEffectController | (existant) |
| 56 | SfxController | (existant, une entrée de données ajoutée) |
| 57 | FeedbackFxController | (existant) |

## Graphe de dépendances (acyclique)

```text
BagService    → SessionService (PlayerJoined, CharacterAdded pour redonner le Tool)
              → VisualService (build "LittleBag", avec remplaçant en primitives)
              → InventoryService (total porté, pour les commandes de dev)

CarryService  → ForestService (findNode : même résolveur de cible que le ramassage)
              → SessionService (mort / départ d'un porteur → relâchement)
              → MatchService (MatchStarting → la forêt est régénérée, toutes les saisies tombent)
              → NetService

InventoryService (modifié) → ⚠ **ne dépend PAS de BagService** : lit l'attribut BagCapacity
PointerController → NetClient, GameplayStateClient (contenance, pour griser l'indice)
DevService (étendu) → BagService
```

**Le point à ne pas casser** : `InventoryService` (45) est chargé *avant* `BagService` (47) et
`BagService` a besoin du total porté d'`InventoryService`. Si `InventoryService` requérait
`BagService` pour connaître la contenance, la dépendance deviendrait circulaire. Il lit donc
l'**attribut** `BagCapacity` du joueur (research R6), avec repli sur `Bag.SmallCapacity` si
l'attribut n'est pas encore écrit — exactement le procédé déjà employé par `NetService`, qui lit
la phase dans `MatchState` plutôt que dans `MatchService`.

Le sens des dépendances reste socle/gameplay établi → nouvelle fonctionnalité, jamais l'inverse.

## Nouvelle API : BagService

- `BagService.capacityOf(player: Player): number` — contenance du sac porté.
- `BagService.usedBy(player: Player): number` — total porté (somme des compteurs `Inv_*`).
- `BagService.fill(player: Player)` / `BagService.empty(player: Player)` — réservées aux
  commandes de dev.

Table interne `BAG_TYPES` (research R7) associant à chaque `BagType` sa contenance (réglage) et
son entrée de catalogue. Ajouter un sac plus grand = une entrée de plus, **aucune logique
nouvelle**.

## Nouvelle API : CarryService

- `CarryService.isCarried(part: BasePart): boolean`
- `CarryService.carrierOf(part: BasePart): Player?`
- `CarryService.releaseAll(player: Player)` — relâchement propre, appelé à la mort, au départ du
  joueur et à la régénération de la forêt.

Surveillance interne à 5 Hz (accumulateur `Heartbeat`, au plus 6 objets suivis) : borne la
distance porteur–objet à `Bag.CarryRange` et force le relâchement au-delà. **Aucune intention
n'est consommée par cette surveillance** (research R4).

## Modification : ForestService (research R3, R9, R10)

- `buildNode` ne crée plus de `ProximityPrompt` sur les nœuds. Les attributs `ResourceType` et
  `Available`, déjà posés sur la pièce, suffisent à la visée côté client.
- `setAvailable` n'a plus d'invite à basculer (transparence, collision et attribut `Available`
  inchangés).
- Le gestionnaire de `HarvestResource` envoie `NotifyService.send(player, "BagFull",
  { capacity })` juste avant de retourner `InventoryFull`. **Aucune autre ligne de ce
  gestionnaire ne change**, et l'intention, son schéma et son résolveur restent identiques.
- `ForestService.findNode` est désormais utilisé par trois intentions (`HarvestResource`,
  `GrabItem`, `ReleaseItem`) au lieu d'une — sans modification.

## Modification : InventoryService (research R1, R6)

- `addPersonal` lit le plafond dans l'attribut `BagCapacity` du joueur (repli
  `Bag.SmallCapacity`) au lieu de `Config.get("Forest", "InventoryCapacity")`. **Signature,
  valeur de retour et sémantique inchangées** — tous les appelants existants (`ForestService`)
  fonctionnent sans adaptation.
- `depositToStock`, `depositResource`, `hasStock`, `consumeStock`, `initPlayer` et la remise à
  zéro à l'élimination : **aucun changement**.

## Commandes de développement ajoutées (`DevService`, Studio uniquement)

| Intention | Effet |
| --- | --- |
| `Dev.FillBag` | remplit le sac jusqu'à `BagCapacity` (FR-018), pour tester le refus « sac plein » |
| `Dev.EmptyBag` | vide entièrement le sac |

`Dev.ShowGameplayState` (existante) est étendue pour rapporter `BagType`, `BagCapacity` et le
total porté — même commande, rapport enrichi, comme elle l'avait été pour le bus en 003.
