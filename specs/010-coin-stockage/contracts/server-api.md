# Contrat des systèmes serveur — Coin de stockage du restaurant

Étend `specs/009-craft-etabli/contracts/server-api.md` (même contrat `{Name, Priority, Init}`). Un
seul nouveau système ; trois systèmes existants gagnent une extension additive.

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 42 | ForestService | (existant, API additive : crochets par nœud) |
| 48 | CarryService | (existant, comportement étendu : saisie soumise aux crochets, relâcher → stockage) |
| 49 | StationDepositService | (existant, ordre d'essai étendu : stockage après l'établi) |
| **54** | **StorageService** | **oui** |

Aucun changement pour `BagService`, `InventoryService`, `CraftService`, `GeneratorService` (leur
comportement et leur API restent identiques).

## Nouvelle API : StorageService

```text
StorageService.tryStoreFromBag(player: Player, resourceType: ResourceType): boolean
StorageService.tryStoreCarried(player: Player, part: BasePart): boolean
```

- `tryStoreFromBag` — appelé par `StationDepositService.tryDeposit` pour chaque objet lâché du sac.
  Renvoie `true` si l'objet a été rangé (il a quitté le sac). Renvoie `false` **sans avoir touché le
  sac** si le joueur est hors de portée, s'il n'y a plus d'emplacement libre (et envoie alors
  `StorageFull`), ou si l'objet n'a pu apparaître. L'appelant garde le comportement habituel.
- `tryStoreCarried` — appelé par `CarryService` juste après un `ReleaseItem` accepté. Renvoie
  `true` si l'objet du monde a été retiré et recréé figé sur un emplacement. Renvoie `false` sans
  effet si l'objet est hors de portée, si le stock est plein (notification `StorageFull`) ou si
  l'objet n'est plus disponible.

`StorageService` n'enregistre **aucune intention** : son seul contrat avec le réseau passe par les
gestes existants. `Init` crée `ReplicatedStorage.StorageState` (`Count`, `Capacity`), le
`BillboardGui` d'indicateur sur le point de référence `Storage`, et écoute `MatchStarting` pour tout
remettre à zéro.

## Extension additive : ForestService — crochets par nœud (research R2)

```text
type NodeHooks = {
    canTake: (player: Player) -> Types.RejectCode?,   -- nil = reprise permise
    onTaken: () -> (),                                 -- appelé une seule fois, à la reprise
}

ForestService.attachHooks(part: BasePart, hooks: NodeHooks)
ForestService.checkTake(player: Player, part: BasePart): Types.RejectCode?
ForestService.releaseHooks(part: BasePart)
```

- `checkTake` renvoie `nil` pour tout nœud sans crochet : **aucun changement** pour un nœud de forêt
  ordinaire ou un objet lâché au sol.
- `releaseHooks` appelle `onTaken` puis retire les crochets ; sans effet si le nœud n'en a pas.
- Les crochets vivent dans l'état interne du nœud (jamais répliqués) ; ils disparaissent avec lui.

`HarvestResource` change comme suit, dans cet ordre :

```text
nœud connu ? disponible ? porté par un coéquipier ?          → refus existants
ForestService.checkTake(player, part)                        → rejet du crochet (TooFar) — NOUVEAU
sac en main ?  place dans le sac ?                            → refus existants (BagNotEquipped, InventoryFull + BagFull)
ForestService.releaseHooks(part)                              → NOUVEAU (libère l'emplacement)
ajout au sac, retrait du nœud                                 → inchangés
```

## Modification : CarryService

`GrabItem` :

```text
nœud connu ? disponible ? déjà porté par un autre ?          → refus existants
ForestService.checkTake(player, part)                        → rejet du crochet (TooFar) — NOUVEAU
saisie habituelle (libère la précédente, propriété réseau)   → inchangée
ForestService.releaseHooks(part)                              → NOUVEAU (libère l'emplacement)
```

`ReleaseItem` : après le relâchement habituel, `CraftService.tryPlaceCarried` (inchangé) puis, s'il
n'a rien pris, **`StorageService.tryStoreCarried(player, part)`** — NOUVEAU. Un objet tiré hors du
coin est un objet ordinaire du monde (ses crochets ont été libérés à la saisie) : il se pose, se
range de nouveau ou va sur l'établi selon où il est relâché.

## Modification : StationDepositService

`tryDeposit` essaie, dans cet ordre : **`CraftService.tryPlaceFromBag`** (inchangé) →
**`StorageService.tryStoreFromBag`** (NOUVEAU) → postes fixes (générateur, comptoir, bus, inchangés).
`BagService.drop`/`dropOne` n'appellent que `tryDeposit` : le lâcher bref, l'appui long et l'ordre
inverse du ramassage sont hérités sans modification.

## Point de référence et types

- `Types.RefPointId` gagne `"Storage"` ; `RefPoints.luau` l'ajoute à la liste des identifiants ;
  `Layout.luau` lui donne des coordonnées (centre de la zone marquée au sol de l'arrière-salle,
  ordonnée = hauteur du sol de la zone), hand-matchées à `Assets/Catalog.luau` comme les autres
  postes.
- **Aucun nouveau code de rejet** : `TooFar` (existant) couvre la reprise hors de portée.

## Réseau : aucune nouvelle intention

Le stock **n'ajoute aucune ligne** à `Remotes.Intents` : ranger utilise `DropBag`/`DropOneItem` et
`ReleaseItem`, reprendre utilise `HarvestResource` et `GrabItem`. Seul ajout à `Remotes.luau` :

| Type de notification | Portée | Usage |
| --- | --- | --- |
| `StorageFull` | personnelle (`NotifyService.send`) | rangement refusé, stock plein ; params `{ capacity }` ; limitée par `Storage.FullNoticeCooldown` |

Retours de succès réutilisés : `ResourceDeposited` (rangement), `ResourceHarvested` (reprise).

## Vérifications au démarrage (principe VI)

`StorageService.Init` journalise sans interrompre les autres systèmes :

- point de référence `Storage` introuvable → erreur, stockage désactivé (aucun rangement possible) ;
- zone du stockage qui chevauche celle de l'établi
  (`distance < Storage.InteractRange + Craft.InteractRange`) → erreur (research R4) ;
- `Storage.InteractRange + rayon de la grille` au-delà de ce que le pipeline réseau tolère pour une
  reprise (`Forest.HarvestRange + Net.DistanceTolerance`, moins une marge verticale) → avertissement
  (research R7) ;
- grille plus profonde que la zone marquée au sol → avertissement.

## Graphe de dépendances (acyclique)

```text
StorageService → ForestService (spawnDrop, findNode, consumeNode, crochets)
               → InventoryService (depositResource)
               → WorldService (point de référence Storage, Workbench pour la vérification)
               → NotifyService
               → MatchService (MatchStarting)
               → Config, Strings, Types

CarryService            → StorageService   (nouveau : tryStoreCarried)
StationDepositService   → StorageService   (nouveau : tryStoreFromBag)
```

Aucun de `ForestService`, `StorageService`, `InventoryService` ne requiert `CarryService`,
`BagService` ni `StationDepositService` : le sens reste socle → gameplay → interaction, inchangé.

## Client

Aucun nouveau contrôleur ni module d'état.

- `PointerController` : quand le nœud visé porte `Stored = true`, l'indice affiche « [F] Reprendre
  … » au lieu de « [F] Ramasser … » ; les indices de sac plein et de sac rangé sont inchangés.
- `Hud.client.luau` : `StorageFull` rejoint la liste des notifications du fil.
- `SfxController` : un son pour `StorageFull` (celui d'un refus existant).
- L'indicateur « Stockage n/N » est un `BillboardGui` créé par le serveur : aucun code client.
