# Contrat réseau — Vidage progressif du sac et dépôt automatique aux postes

Étend `specs/004-sac-collecte/contracts/network.md`. Le pipeline en 10 étapes de `NetService`
**n'est pas modifié**. Aucun nouveau code de refus (research R10) : `BagNotEquipped` et
`BagEmpty`, déjà déclarés, couvrent les deux intentions de vidage.

## Intention conservée, gestionnaire révisé

| Intention | Déclaration | Ce qui change |
| --- | --- | --- |
| `DropBag` | **aucun changement** : payload vide, mêmes phases, aucune cible | le **gestionnaire** parcourt désormais l'ordre d'arrivée (le plus récent d'abord) et tente un dépôt automatique par unité avant de la poser au sol, au lieu de l'ancien parcours à ordre fixe qui posait tout au sol |

Comme en 004 pour `HarvestResource` (research R3) : la déclaration réseau ne bouge pas, seul le
comportement interne change. Aucune migration de contrat côté client au-delà du déclenchement
(voir « Comportement client » ci-dessous).

## Nouvelle intention

| Intention | Payload | Phases | Cible | devOnly |
| --- | --- | --- | --- | --- |
| `DropOneItem` | *(aucun)* | Countdown, Day, Night, Escape | *(aucune)* | non |

Même forme que `DropBag` : sans `target`, le pipeline saute ses étapes 7 à 9 (y compris la
vérification du personnage vivant), donc le gestionnaire la refait lui-même et retourne
`NoCharacter` le cas échéant — exactement comme `DropBag` aujourd'hui.

### Comportement des handlers

- **`DropOneItem`** (`BagService.dropOne`) : refuse `NoCharacter`, `BagNotEquipped`, `BagEmpty`
  (mêmes préconditions que `DropBag`). Sinon : lit l'entrée la plus récente de l'ordre d'arrivée
  (`InventoryService`), calcule sa position d'atterrissage, tente
  `StationDepositService.tryDeposit` ; à défaut, la pose au sol via `ForestService.spawnDrop` et
  retire l'unité correspondante (`InventoryService.depositResource(player, type, 1)`).
- **`DropBag`** (`BagService.drop`, révisé) : mêmes préconditions. Sinon : parcourt une copie de
  l'ordre d'arrivée courant (le plus récent d'abord), et pour chaque entrée répète exactement le
  traitement de `DropOneItem` (tenter un dépôt automatique, sinon poser au sol). Le nombre
  d'objets réellement posés au sol est compté pour la notification `BagDropped` (voir ci-dessous).

Dans les deux cas, **rien n'est retiré du sac tant que le sort de l'unité n'est pas déterminé** :
`StationDepositService.tryDeposit` ne touche le sac que s'il peut réellement appliquer le dépôt
(research R3) ; sinon c'est le chemin « pose au sol », inchangé depuis 004, qui prélève.

## Comportement client (hors pipeline réseau, pour mémoire)

La distinction pression brève / maintien est **entièrement une décision client**, revalidée par le
serveur comme n'importe quelle autre intention (même principe que la visée au pointeur, 004-R3) :

- relâchement avant `Bag.DropHoldThreshold` → un seul `DropOneItem` est envoyé à `InputEnded` ;
- maintien au-delà de `Bag.DropHoldThreshold` → un seul `DropBag` est envoyé dès que le seuil est
  franchi, jamais répété tant que la touche reste enfoncée (clarification 2026-09-18, Q1) ;
  relâcher ensuite la touche n'envoie plus rien (le geste a déjà eu son effet).

Un client modifié qui enverrait `DropBag` en boucle ne gagnerait rien : chaque appel traite
seulement ce qui reste réellement dans le sac au moment de l'appel (idempotent au sens où un sac
déjà vide renvoie `BagEmpty` sans effet).

## Notification révisée : `BagDropped`

| Notification | Portée | Déclenchée par | Données | Ce qui change |
| --- | --- | --- | --- | --- |
| `BagDropped` | send (joueur concerné) | `BagService`, après `DropOneItem` ou `DropBag` | `{ amount }` | `amount` ne compte plus que les objets **posés au sol** (jamais ceux absorbés par un poste) ; **non envoyée si `amount == 0`** (research R8) |

## Notifications de poste réutilisées telles quelles

Un dépôt automatique déclenche exactement la notification qu'un dépôt manuel au même poste
enverrait — aucune notification nouvelle :

| Type déposé | Notification réutilisée | Émise par |
| --- | --- | --- |
| `Essence` | `GeneratorFueled` | `GeneratorService.deposit` (appelé depuis `StationDepositService`) |
| `Scrap` | `ScrapDeposited` (et `BusRepaired` si le seuil est atteint) | `BusService.deposit` (research R7) |
| `SuspectSteak` / `RoadBread` | `ResourceDeposited` | `InventoryService.depositResourceToStock` |

## Codes de refus (`Types.RejectCode`) — aucun ajout

| Code | Utilisé par | Sens (inchangé depuis l'amendement du 2026-09-17) |
| --- | --- | --- |
| `BagNotEquipped` | `DropOneItem`, `DropBag` | le sac n'est pas en main |
| `BagEmpty` | `DropOneItem`, `DropBag` | rien à retirer |
| `NoCharacter` | `DropOneItem`, `DropBag` | aucun personnage vivant (vérifié manuellement, sans `target`) |

## Nouveau réglage de protocole côté client

`Bag.DropHoldThreshold` (voir `contracts/config.md`) détermine, côté `PointerController`, quand
basculer de « pression brève » à « maintien ». Ce n'est **pas** une validation serveur : le
serveur accepte `DropOneItem` et `DropBag` indépendamment de toute notion de durée d'appui, comme
toute intention de ce pipeline.
