# État répliqué — Sac de collecte et manipulation des objets

Étend `specs/002-premier-increment-jouable/contracts/replicated-state.md` et
`specs/003-bus-evasion/contracts/replicated-state.md`. Règle inchangée : **un élément répliqué a
un seul écrivain**.

**Aucun nouveau dossier dans `ReplicatedStorage`** : tout l'état ajouté tient dans des attributs
posés sur des instances qui existent déjà (le joueur, la pièce d'un nœud de forêt).

## Attributs sur `Player` (écrivain : BagService)

| Attribut | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `BagType` | BagService | string | type de sac porté (`"LittleBag"`) |
| `BagCapacity` | BagService | number (entier) | contenance totale du sac porté, toutes ressources confondues |

Écrits à l'arrivée du joueur (`SessionService.PlayerJoined`) et jamais remis à zéro par une
nouvelle partie : le sac est une propriété du joueur, pas de la partie.

`BagCapacity` a un **second rôle, volontaire** : c'est la valeur que lit
`InventoryService.addPersonal` pour appliquer le plafond, au lieu de requérir `BagService` — ce
qui évite une dépendance circulaire (research R6). Le même procédé que `NetService`, qui lit la
phase dans `MatchState` plutôt que dans `MatchService`.

## Attributs existants sur `Player` (écrivain : InventoryService, inchangés)

`Inv_Essence`, `Inv_SuspectSteak`, `Inv_RoadBread`, `Inv_Scrap` : **forme et écrivain
inchangés**. Seule la règle qui les plafonne change de source (`BagCapacity` au lieu de
`Forest.InventoryCapacity`). Le remplissage du sac est donc toujours la **somme** de ces
compteurs — jamais une valeur stockée à part, pour qu'aucune divergence ne soit possible.

## Attribut sur la pièce d'un nœud de forêt (écrivain : CarryService)

| Attribut | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `GrabbedBy` | CarryService | number | `UserId` du joueur qui tient l'objet, `0` si libre |

Posé à `0` à la construction du nœud, il suit la même convention que `Available` (002) : un
attribut d'instance répliqué nativement, à écrivain unique. Le client s'en sert pour ne pas
proposer la saisie d'un objet déjà tenu — un confort d'affichage, jamais une validation : le
serveur revérifie systématiquement à la prise.

## Attributs existants sur la pièce d'un nœud (écrivain : ForestService, inchangés)

| Attribut | Rôle dans cette fonctionnalité |
| --- | --- |
| `ResourceType` | identifie la pièce comme visable et donne son libellé à la surbrillance |
| `Available` | un nœud récolté n'est ni visable, ni ramassable, ni saisissable |

Ces deux attributs existaient déjà et **suffisent** à la visée au pointeur : c'est la raison pour
laquelle le retrait des invites de proximité (research R9) ne fait perdre aucune information au
client.

## Propriété réseau pendant un déplacement (non répliqué au sens des attributs)

Pendant une saisie, la propriété réseau de la pièce est confiée au joueur qui la tient, puis
rendue au serveur au relâchement (research R4). Ce n'est pas un état répliqué mais un mode de
simulation ; il est mentionné ici parce qu'il détermine **qui produit la position visible** :

| Moment | Position produite par | Position faisant foi |
| --- | --- | --- |
| hors saisie | serveur (pièce ancrée) | serveur |
| pendant la saisie | client porteur (suivi du pointeur) | serveur, qui borne à 5 Hz et peut relâcher de force |
| au relâchement | serveur | serveur (position reçue validée, ou dernière position valide) |

## `Backpack` du joueur (écrivain : BagService)

Le `Tool` du sac est déposé dans `player.Backpack` à chaque `CharacterAdded`, car le `Backpack`
est **vidé et recréé à chaque apparition**. Ce n'est pas de l'état de jeu répliqué : c'est une
instance native, réplicée par le moteur, dont le contenu ne porte aucune information de gameplay
(la contenance et le contenu vivent dans les attributs ci-dessus). Perdre le `Tool` n'aurait donc
aucun effet sur les ressources portées — et il ne peut pas être lâché (`CanBeDropped = false`).

## Aucun changement aux états existants

`ReplicatedStorage.Stock`, `GeneratorState`, `OrderState`, `BusState` et `MatchState` ne sont ni
lus en écriture ni modifiés par cette fonctionnalité. Leurs écrivains respectifs restent seuls
maîtres de leur contenu.
