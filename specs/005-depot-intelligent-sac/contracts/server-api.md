# API serveur — Vidage progressif du sac et dépôt automatique aux postes

Étend `specs/004-sac-collecte/contracts/server-api.md`. Liste chaque fonction publique nouvelle ou
modifiée, par service, avec son écrivain et ses appelants attendus.

## `InventoryService` (priorité 45, inchangée)

Devient le seul écrivain de l'ordre d'arrivée en plus des compteurs `Inv_*` (research R1,
data-model.md).

| Fonction | Statut | Contrat |
| --- | --- | --- |
| `addPersonal(player, type, amount): boolean` | modifiée (interne) | signature et effet sur `Inv_*` inchangés ; ajoute désormais `amount` entrées à `order[player]` si l'ajout est accepté |
| `depositResource(player, type, maxAmount?): number` | modifiée (interne) | signature et effet sur `Inv_*` inchangés ; retire désormais autant d'entrées de `type` que d'unités effectivement prélevées |
| `depositToStock(player): number` | modifiée (interne) | signature et effet inchangés ; retire désormais toutes les entrées `SuspectSteak`/`RoadBread` |
| `depositResourceToStock(player, type, maxAmount): number` | **nouvelle** | jumelle unitaire de `depositToStock`, pour un seul type ; prélève jusqu'à `maxAmount` unités de `type` (doit être `SuspectSteak` ou `RoadBread`), les ajoute au `Stock` partagé, retire les entrées d'ordre correspondantes, renvoie la quantité réellement déposée |
| `clearCarried(player)` | **nouvelle** | remplace l'écriture directe d'attributs de `BagService.empty` (research R6) : remet tous les `Inv_*` à 0 **et** vide `order[player]` en un seul appel |
| `orderOf(player): { ResourceType }` | **nouvelle** | copie en lecture seule de `order[player]` (le plus récent en dernier), `{}` si vide ou joueur inconnu — utilisée par `BagService` pour le parcours de `DropBag`/`DropOneItem` et par `Dev.ShowGameplayState` (affichage de contrôle) |
| `mostRecent(player): ResourceType?` | **nouvelle** | `nil` si le sac est vide, sinon le type du dernier élément de `order[player]` — utilisée par `DropOneItem` |

**Nettoyage ajouté** : un abonnement à `SessionService.PlayerLeft` supprime `order[player]` (la
table ne se nettoie pas seule à la différence des attributs, research R1).

## `StationDepositService` (nouveau, priorité 49)

Service à une seule responsabilité : savoir quel poste sait faire quelque chose d'un type d'objet,
et le lui appliquer si les conditions sont réunies. Ne crée aucune instance, ne s'abonne à aucun
événement, n'enregistre aucune intention `NetService` — appelé uniquement depuis `BagService`.

| Fonction | Contrat |
| --- | --- |
| `tryDeposit(player, resourceType, position): boolean` | `true` si un poste compatible a réellement absorbé 1 unité (le sac a été mis à jour et la notification du poste a été envoyée) ; `false` sinon, **sans avoir touché le sac** — soit aucun poste ne correspond à `resourceType`, soit `position` est hors de sa portée, soit il n'a pas de place (research R3) |

Dépend de : `Config` (portées), `WorldService.refPoint` (position des postes),
`InventoryService` (prélèvement), `GeneratorService`, `BusService` (application). Aucun de ces
services ne dépend de `StationDepositService` (aucune circularité, research R2).

## `GeneratorService` (priorité 44)

| Fonction | Statut | Contrat |
| --- | --- | --- |
| `deposit(amount): number` | inchangée | réutilisée telle quelle par `StationDepositService` |
| `fuelRoom(): number` | **nouvelle** | `Capacity - fuel` courant ; permet à `StationDepositService` de vérifier la place disponible avant de prélever, sans dupliquer l'état privé du module |

## `BusService` (priorité 66)

| Fonction | Statut | Contrat |
| --- | --- | --- |
| `deposit(player, maxAmount): number` | **nouvelle**, extraite du corps de `RepairBus` | prélève jusqu'à `maxAmount` ferraille (`InventoryService.depositResource`), incrémente `deposited`, publie l'état, envoie `ScrapDeposited`, déclenche `BusRepaired` au seuil ; renvoie la quantité réellement déposée (0 si déjà réparé) |
| Gestionnaire `RepairBus` | modifié (interne) | appelle désormais `BusService.deposit(player, room)` au lieu de dupliquer cette logique ; comportement observable strictement inchangé (research R7) |

## `BagService` (priorité 47)

| Fonction | Statut | Contrat |
| --- | --- | --- |
| `drop(player): number` | **révisée** | ne parcourt plus `CARRIED_TYPES` dans un ordre fixe : parcourt `InventoryService.orderOf(player)` (le plus récent d'abord), tente `StationDepositService.tryDeposit` par unité, sinon la pose au sol (comportement de pose inchangé, y compris le calcul de position en cercle). Renvoie le nombre d'objets **posés au sol** (pour `BagDropped`, research R8) |
| `dropOne(player): (boolean, ResourceType?)` | **nouvelle** | traite une seule unité — celle que renvoie `InventoryService.mostRecent(player)` — avec le même embranchement poste-ou-sol que `drop`. Renvoie si l'unité a été posée au sol (pour `BagDropped`) et son type |
| `empty(player)` | **révisée** | appelle désormais `InventoryService.clearCarried(player)` au lieu d'écrire les attributs `Inv_*` directement (research R6) ; comportement observable inchangé (`Dev.EmptyBag`) |
| Gestionnaire `DropBag` | modifié (interne) | appelle `BagService.drop`, envoie `BagDropped` seulement si le compte renvoyé est `> 0` |
| Gestionnaire `DropOneItem` | **nouveau** | mêmes préconditions que `DropBag` (`BagNotEquipped`, `BagEmpty`) ; appelle `BagService.dropOne`, envoie `BagDropped { amount = 1 }` seulement si l'objet a été posé au sol |

## `ForestService` (priorité 42) — inchangé

`spawnDrop` est réutilisée telle quelle par `BagService.drop`/`dropOne`, exactement comme en
004-sac-collecte. Aucune modification.
