# Modèle de données — Coin de stockage du restaurant

## Emplacement (calculé, non stocké)

Aucune table de coordonnées : la position monde de l'emplacement `i` se déduit du point de
référence `Storage` et des réglages (research R3).

| Champ | Type | Source |
| --- | --- | --- |
| `index` | `number` (1 à `Storage.Capacity`) | ordre d'attribution : toujours le plus bas index libre |
| `position` | `Vector3` | `refpoint + ((col - (colonnes-1)/2) × espacement, 0, (rangée - (rangées-1)/2) × espacement)`, avec `col = (i-1) % colonnes`, `rangée = (i-1) // colonnes` |
| `occupant` | `{ part: BasePart, resourceType: ResourceType }?` | état serveur en mémoire ; `nil` = libre |

`colonnes` = `Storage.Columns`, `espacement` = `Storage.SlotSpacing`, `rangées` =
`ceil(Capacity / Columns)`. La hauteur de pose est celle du point de référence (le sol de la zone).

## Objet rangé (un nœud de forêt existant, figé)

Aucun nouveau type : c'est un nœud de `ForestService` créé par `spawnDrop` (`dropped = true`), donc
il porte déjà les attributs habituels. Le stockage ajoute deux attributs et fige le nœud.

| Élément | Valeur pendant le rangement | Rôle |
| --- | --- | --- |
| `ResourceType`, `NodeId`, `Available`, `GrabbedBy` | inchangés (`Available = true`, `GrabbedBy = 0`) | la visée, `HarvestResource` et `GrabItem` continuent de le reconnaître |
| `Stored` | `true` | permet au client d'adapter l'indice de visée (research R8) |
| `StoredSlot` | index de l'emplacement | déboguage et vérification (ne pilote aucune logique) |
| pièces du modèle | `Anchored = true`, `CanCollide = false` | figé et sans effet sur les joueurs (FR-006) |
| crochets (mémoire serveur) | `{ canTake, onTaken }` | garde de portée et libération à la reprise (research R2) |

À la reprise, `onTaken` retire `Stored`/`StoredSlot`, rend `CanCollide = true` aux pièces et libère
l'emplacement ; le nœud est alors un objet du monde ordinaire.

## État répliqué : `ReplicatedStorage.StorageState`

Dossier créé par `StorageService.Init`, même patron que `GeneratorState`/`BusState`/`OrderState`.

| Attribut | Type | Description |
| --- | --- | --- |
| `Count` | `number` | emplacements occupés |
| `Capacity` | `number` | emplacements au total (`Storage.Capacity`) |

L'indicateur « Stockage n/N » (`BillboardGui` serveur sur le point de référence) reflète ces deux
valeurs ; aucun client ne les recalcule.

## Transitions

```text
Ranger (depuis le sac — StationDepositService.tryDeposit → StorageService.tryStoreFromBag) :
  joueur hors de portée du point de référence            → false  (lâcher habituel)
  aucun emplacement libre                                → false + notification StorageFull
                                                            (lâcher habituel : poste, sinon sol)
  ForestService.spawnDrop(type, position) == nil         → false  (rien prélevé, principe VI)
  sinon : figer le nœud (ancré, sans collision, attributs, crochets),
          InventoryService.depositResource(player, type, 1),
          occupant[i] = { part, type }, Count += 1, notification ResourceDeposited → true

Ranger (glisser-déposer — CarryService après ReleaseItem → StorageService.tryStoreCarried) :
  objet relâché hors de portée du point de référence     → false  (l'objet reste où il est)
  aucun emplacement libre                                → false + notification StorageFull
  ForestService.spawnDrop(type, position) == nil         → false  (l'objet du monde n'est pas touché)
  sinon : créer d'abord le nœud figé (comme ci-dessus), puis ForestService.consumeNode(part) ;
          si consumeNode == nil (objet déjà pris) : détruire le nœud figé, libérer l'emplacement → false ;
          sinon → true (aucun prélèvement dans le sac)

Reprendre (vers le sac — HarvestResource, touche F) :
  ForestService.checkTake → canTake : joueur hors de portée → rejet TooFar
  refus habituels : NodeUnavailable, AlreadyCarried, BagNotEquipped, InventoryFull (+ BagFull)
  sinon : releaseHooks → onTaken (libère l'emplacement) ; l'objet rejoint le sac ; le nœud disparaît

Reprendre (tiré à la souris — GrabItem) :
  ForestService.checkTake → canTake : hors de portée → rejet TooFar
  refus habituels : NodeUnavailable, AlreadyCarried ; aucun besoin de sac (FR-018)
  sinon : releaseHooks → onTaken (libère l'emplacement) ; saisie habituelle du nœud devenu ordinaire

Nouvelle partie (MatchService.MatchStarting) :
  la forêt est régénérée (les nœuds figés disparaissent) ; occupant[*] = nil ; Count = 0
```

L'ordre des refus place `checkTake` avant les refus propres au joueur (sac rangé, sac plein) : un
joueur hors de portée reçoit `TooFar`, pas une explication sur son sac.

## Invariants

- **Un objet à un seul endroit** (FR-011) : `#{occupant non nil} == Count`, et chaque occupant est
  un nœud vivant de `Workspace.Forest` portant `Stored = true`. Un objet quitte le sac **après** que
  son nœud existe (jamais l'inverse), donc un échec d'apparition ne perd rien.
- **Plus bas index libre** : l'attribution est déterministe (principe V).
- **Aucune persistance** : le stock ne survit pas à une partie (FR-013) ; rien n'est écrit dans un
  `DataStore`.
