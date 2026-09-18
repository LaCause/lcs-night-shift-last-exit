# Data Model — Vidage progressif du sac et dépôt automatique aux postes

Étend le modèle de `specs/004-sac-collecte/data-model.md`. **Aucun attribut répliqué existant ne
change de forme** : les compteurs `Inv_Essence`/`Inv_SuspectSteak`/`Inv_RoadBread`/`Inv_Scrap`,
`BagType`, `BagCapacity`, `BagEquipped`, `GrabbedBy` restent exactement ce qu'ils sont. Cette
fonctionnalité ajoute un état serveur pur (l'ordre d'arrivée) et une connaissance transversale (la
correspondance objet-poste), tous deux non répliqués — le client n'a besoin de connaître ni l'un
ni l'autre pour afficher quoi que ce soit (research R1).

## Ordre d'arrivée du sac (InventoryService, état serveur non répliqué)

```text
order: { [Player]: { ResourceType } }
```

Un tableau par joueur, le **dernier élément étant le plus récemment ajouté**. C'est la seule
nouvelle donnée introduite par cette fonctionnalité.

**Invariant** (vérifiable à tout moment) :

```text
#order[player] == somme(Inv_Essence, Inv_SuspectSteak, Inv_RoadBread, Inv_Scrap) pour ce joueur
```

Autrement dit, l'ordre ne stocke rien de plus que les compteurs existants ne portent déjà — c'est
une seconde représentation de la même quantité, jamais une source d'information indépendante
(aucune divergence possible tant que les deux sont maintenus au même endroit, research R1).

**Écrivain unique** : `InventoryService`, aux mêmes points d'entrée qui touchent déjà `Inv_*` :

| Point d'entrée | Effet sur `order[player]` |
| --- | --- |
| `addPersonal(player, type, amount)` | ajoute `amount` entrées de `type` à la fin |
| `depositResource(player, type, maxAmount?)` | retire jusqu'à `maxAmount` entrées de `type` (n'importe lesquelles : deux entrées du même type sont interchangeables) |
| `depositResourceToStock(player, type, maxAmount)` *(nouveau, R3)* | même retrait, ciblé sur un seul type stock-eligible |
| `depositToStock(player)` | retire toutes les entrées `SuspectSteak`/`RoadBread` |
| `clearCarried(player)` *(nouveau, R6)* | vide entièrement l'ordre (et les compteurs) — remplace l'écriture directe d'attributs de `BagService.empty` |
| `initPlayer` (`PlayerJoined`, élimination) | vide l'ordre |
| `resetAll` (`MatchStarting`) | vide l'ordre pour tous les joueurs présents |
| *(nouveau)* `SessionService.PlayerLeft` | supprime l'entrée `order[player]` (sans quoi la table fuit : contrairement aux attributs, elle n'est pas nettoyée automatiquement au départ du joueur) |

**Transitions** :

```text
récolte (F) / Dev.GiveResources / Dev.FillBag  → addPersonal → +1 (ou +N) entrée(s) en fin d'ordre
DropOneItem accepté                             → retire la dernière entrée de l'ordre
DropBag accepté                                 → parcourt l'ordre (le plus récent d'abord),
                                                   chaque entrée retirée au fur et à mesure qu'elle
                                                   est traitée (dépôt automatique ou pose au sol)
dépôt manuel (comptoir/générateur/bus)           → retire les entrées du type concerné
Dev.EmptyBag, élimination, nouvelle partie      → ordre vidé entièrement
départ du joueur                                 → entrée supprimée de la table (pas de fuite)
```

## Correspondance objet-poste (StationDepositService, table statique)

```text
AUTO_DEPOSIT: { [ResourceType]: {
  RefPointId: RefPointId,
  RangeSetting: string,   -- "Domaine.Réglage", résolu comme dans NetService.rangeFor
  attempt: (player: Player) -> boolean,  -- prélève 1 unité ET l'applique ; ne touche rien si false
} }
```

| Type | Poste | `RangeSetting` réutilisé | Capacité vérifiée avant prélèvement |
| --- | --- | --- | --- |
| `Essence` | Générateur (`Generator`) | `Generator.InteractRange` | oui — `Capacity - fuel` (research R3) |
| `SuspectSteak` | Comptoir (`Counter`) | `Forest.HarvestRange` *(même réglage que le dépôt manuel existant, aucun nouveau)* | non — le stock partagé n'a pas de plafond |
| `RoadBread` | Comptoir (`Counter`) | `Forest.HarvestRange` | non |
| `Scrap` | Bus (`BusSpot`) | `Bus.InteractRange` | oui — `Required - Deposited` |

Table conçue comme celle de `BAG_TYPES` (004, research R7) ou `VISUAL_FOR`/`NODE_COUNT_SETTING`
(002) : un futur type de ressource avec une action de poste n'ajoute qu'une entrée, aucune
logique nouvelle (FR-006).

## Dépôt automatique (événement, pas une entité stockée)

Un dépôt automatique n'a pas d'état propre : c'est le résultat immédiat d'un appel à
`StationDepositService.tryDeposit(player, resourceType, position)`, qui soit prélève et applique
une unité (renvoie `true`), soit ne touche rien (renvoie `false`). Rien n'est mis en attente,
aucune trace n'est conservée au-delà de la notification déjà envoyée par le poste concerné
(`GeneratorFueled`, `ScrapDeposited`, `ResourceDeposited`).

## Notification `BagDropped` (révisée)

**Forme inchangée** (`{ amount: number }`), **sens révisé** : `amount` est désormais le nombre
d'objets qui ont atterri **au sol** pendant l'action (jamais ceux absorbés par un poste). La
notification n'est **pas envoyée** si `amount` vaut 0 — tout le contenu concerné a été déposé
automatiquement, et chaque dépôt a déjà sa propre confirmation (research R8).

## Objet lâché au sol (ForestService, inchangé)

Aucun changement : un objet qui ne trouve pas de poste compatible (ou dont le poste est plein)
redevient un nœud `dropped = true` via `ForestService.spawnDrop`, exactement comme en
004-sac-collecte — ramassable, déplaçable, sans réapparition après récolte.

## Relations avec les entités existantes

- **Aucune nouvelle entité de scène** : ni dossier, ni modèle, ni attribut sur une pièce du monde.
- Le **cycle de vie des nœuds** (002) et les **compteurs `Inv_*`** (002/004) restent la référence ;
  cette fonctionnalité ajoute une vue ordonnée par-dessus, jamais une donnée parallèle qui
  pourrait diverger (invariant ci-dessus).
- Les **postes existants** (`GeneratorService`, `BusService`, `InventoryService.depositToStock`)
  ne gagnent aucune nouvelle donnée d'état : `BusService.deposit` (R7) et
  `depositResourceToStock` (R3) sont des découpages de logique déjà existante, pas de nouveaux
  compteurs.
