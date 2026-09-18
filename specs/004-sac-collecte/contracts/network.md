# Contrat réseau — Sac de collecte et manipulation des objets

Étend `specs/002-premier-increment-jouable/contracts/network.md` (pipeline en 10 étapes inchangé,
résolveur de cible optionnel inchangé) et `specs/003-bus-evasion/contracts/network.md`. Le
pipeline lui-même **n'est pas modifié**.

## Intention conservée telle quelle, déclencheur client modifié

| Intention | Déclaration | Ce qui change |
| --- | --- | --- |
| `HarvestResource` | **aucun changement** : `{ target: string(≤64) }`, phases jouables, `target` → `Forest.HarvestRange`, résolveur `ForestService.findNode` | seul le **déclencheur côté client** passe de l'invite de proximité au pointeur + touche F (research R3) |

Le **contrat réseau** du ramassage ne change pas : même schéma, même résolveur, même intention,
mêmes portées. La visée est une manière de désigner une cible, pas une règle de jeu : le serveur
revalide exactement comme avant, donc la sécurité ne dépend à aucun moment du geste du joueur.

Le **gestionnaire**, lui, gagne trois comportements — les deux derniers ajoutés par l'amendement
du 2026-09-17 :

1. avant de retourner `InventoryFull`, il envoie la notification `BagFull` au joueur concerné
   (research R10) ;
2. il refuse `AlreadyCarried` quand l'objet visé est tenu par un autre joueur — sans quoi un
   coéquipier pourrait le ramasser sous la main de celui qui le déplace (FR-010, quickstart V5.2) ;
3. il refuse `BagNotEquipped` quand le joueur n'a pas son sac en main (FR-019).

Ces deux nouvelles vérifications lisent des **attributs répliqués** (`GrabbedBy`, écrit par
`CarryService` ; `BagEquipped`, écrit par `BagService`) plutôt que de requérir ces modules :
`CarryService` requiert déjà `ForestService` pour résoudre ses cibles, donc la dépendance inverse
serait circulaire (même procédé que `BagCapacity`, research R6).

## Nouvelles intentions

| Intention | Payload | Phases | Cible (champ → portée) | devOnly |
| --- | --- | --- | --- | --- |
| `GrabItem` | `{ target: string(≤64) }` | Countdown, Day, Night, Escape | `target` → `Forest.HarvestRange` | non |
| `ReleaseItem` | `{ target: string(≤64), x: number, y: number, z: number }` | Countdown, Day, Night, Escape | `target` → `Bag.CarryRange` | non |
| `DropBag` | *(aucun)* | Countdown, Day, Night, Escape | *(aucune cible)* | non |

`GrabItem` et `ReleaseItem` utilisent le résolveur dynamique déjà existant
`ForestService.findNode` (même cible qu'un ramassage : un nœud de forêt), donc aucune extension du
résolveur n'est nécessaire.

`DropBag` (amendement du 2026-09-17) est la seule intention de cette fonctionnalité **sans cible** :
vider son sac ne vise rien, c'est le serveur qui décide où les objets tombent. Sans `target`, le
pipeline saute ses étapes 7 à 9 — y compris la vérification du personnage vivant — donc le
gestionnaire la refait lui-même et retourne `NoCharacter` le cas échéant. Un vidage coûte **une
seule intention**, quel que soit le nombre d'objets posés.

**Portées choisies** : `GrabItem` réutilise `Forest.HarvestRange` — « à quelle distance peut-on
interagir avec un nœud » reste **un seul réglage**, que l'on ramasse ou que l'on saisisse.
`ReleaseItem` utilise `Bag.CarryRange`, la portée maximale à laquelle l'objet tenu peut se
trouver : le joueur doit encore être à portée de l'objet pour le poser.

**Validation de `x`/`y`/`z`** : `Validate.number(-Bag.MaxCoordinate, Bag.MaxCoordinate)`, qui
existe déjà et **rejette aussi les valeurs non finies** (`NaN`, `±inf`) avant toute comparaison de
bornes. Aucun nouveau vérificateur n'est nécessaire : `Validate` n'est pas modifié.

### Comportement des handlers

- **GrabItem** (`CarryService`) : refuse `TargetMissing` si le nœud n'existe pas. Refuse
  `NodeUnavailable` si le nœud a déjà été récolté (`Available == false`). Refuse
  `AlreadyCarried` si `GrabbedBy ≠ 0` **et** que le porteur est un autre joueur encore présent ;
  si le porteur enregistré a quitté la partie, la saisie est reprise proprement (nettoyage
  défensif, principe VI). Si le joueur tient déjà un autre objet, l'objet précédent est relâché
  avant la nouvelle prise — un joueur ne tient jamais deux objets. Sinon : écrit
  `GrabbedBy = UserId`, confie la propriété réseau de la pièce au joueur, enregistre la saisie et
  sa `lastValidPosition`.
- **ReleaseItem** (`CarryService`) : refuse `NotCarrying` si ce joueur ne tient pas cet objet
  (rien à relâcher — protège contre un client qui relâcherait l'objet d'un autre). Sinon :
  valide la position reçue (distance du joueur ≤ `Bag.CarryRange` + `Net.DistanceTolerance`) ;
  si elle est hors portée, la `lastValidPosition` est appliquée à la place. Puis rend la
  propriété réseau au serveur, réancre la pièce et remet `GrabbedBy = 0`.
- **DropBag** (`BagService`) : refuse `NoCharacter` sans personnage vivant, `BagNotEquipped` si le
  sac n'est pas en main (FR-019), `BagEmpty` s'il est déjà vide. Sinon, chaque unité transportée
  devient un nœud de forêt ordinaire posé au sol autour du joueur (`ForestService.spawnDrop`), puis
  une notification `BagDropped` confirme le total posé. **Rien n'est retiré du sac tant que l'objet
  n'existe pas réellement dans le monde** : si une apparition échoue, l'unité reste dans le sac et
  le joueur ne perd rien (principe VI). Les objets ainsi posés portent le marqueur `dropped` et
  **ne réapparaissent pas** une fois ramassés — sinon lâcher puis ramasser en boucle fabriquerait
  des ressources à partir de rien (FR-021).

**Relâchements sans intention** — le serveur peut relâcher seul, sans qu'aucune intention soit
reçue (research R4, FR-014) : dépassement de portée constaté à 5 Hz, mort du porteur,
déconnexion, régénération de la forêt à `MatchStarting`. Dans tous ces cas, la pièce revient à sa
dernière position valide et `GrabbedBy` repasse à `0`.

## Nouveaux codes de refus (`Types.RejectCode`, additifs)

| Code | Utilisé par | Sens |
| --- | --- | --- |
| `AlreadyCarried` | GrabItem, HarvestResource | l'objet est déjà tenu par un autre joueur encore présent |
| `NotCarrying` | ReleaseItem | ce joueur ne tient pas cet objet (relâchement sans prise) |
| `BagNotEquipped` | HarvestResource, DropBag | le sac du joueur n'est pas en main (FR-019) |
| `BagEmpty` | DropBag | le sac est déjà vide : rien à poser au sol |

Les dix-huit codes déjà en place gardent leur sens exact. `InventoryFull` (002) couvre déjà le
sac plein : **aucun code de refus nouveau n'est nécessaire pour la contenance**, seul le retour
au joueur manquait (`BagFull`, ci-dessous).

## Nouvelle notification (`Remotes.NotificationKinds`, additive)

| Notification | Portée | Déclenchée par | Données |
| --- | --- | --- | --- |
| `BagFull` | send (joueur concerné uniquement) | `ForestService` (juste avant de retourner `InventoryFull`) | `{ capacity }` |
| `BagDropped` | send (joueur concerné uniquement) | `BagService` (après un vidage réussi) | `{ amount }` |

**Pourquoi elle existe** : le pipeline journalise les refus côté serveur et les conserve pour
l'outil de dev, mais **ne les renvoie jamais au client**. Sans cette notification, un joueur au
sac plein verrait sa touche F rester sans effet, sans explication — un échec muet, contraire au
principe VI et à FR-003. Elle comble ce manque au strict nécessaire (un seul cas) plutôt que
d'ouvrir un canal générique de refus, qui reste une amélioration possible pour plus tard
(research R10).

Suit le patron de `ResourceHarvested`/`ScrapDeposited` (send, retour personnel). Consommée par
`SfxController` (son d'échec) et par le fil de notifications du HUD.

## Nouvelles commandes de développement

| Intention | Payload | Effet |
| --- | --- | --- |
| `Dev.FillBag` | *(aucun)* | remplit le sac jusqu'à `BagCapacity` pour tester le refus « sac plein » sans récolte réelle (FR-018) |
| `Dev.EmptyBag` | *(aucun)* | vide entièrement le sac du joueur |

Mêmes règles que toutes les commandes `Dev.*` : `devOnly: true`, refusées hors Studio par
l'étape 4 du pipeline, validées par le même pipeline que le reste.
