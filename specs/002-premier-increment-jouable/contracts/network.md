# Contrat réseau — Premier incrément jouable

Étend `specs/001-socle-technique/contracts/network.md` (pipeline en 10 étapes, canal `Intent` /
`Notify` uniques). Ce document ne redéfinit rien : il ajoute des intentions, un point
d'extension du pipeline (étapes 7-9) et de nouveaux codes/notifications.

## Extension du pipeline : résolveur de cible optionnel (research R3)

`NetService.registerIntent(name, definition)` accepte désormais :

```text
definition = {
  handler: (player, payload) -> RejectCode?,
  resolve: ((targetId: any) -> BasePart?)?,   -- nouveau, optionnel
}
```

- Sans `resolve` (toutes les intentions du socle : `RingBell`, `Dev.*`) : comportement inchangé,
  la cible est cherchée par `RefPoints.find`.
- Avec `resolve` (`HarvestResource` uniquement dans cet incrément) : les étapes 7-9 appellent
  `resolve(targetId)` à la place de `RefPoints.find`. Le résolveur DOIT lui-même valider le
  type de `targetId` et renvoyer `nil` si la cible n'existe pas ou n'est plus valide.
- `Remotes.luau` ne porte toujours que `target = { field, rangeSetting }` : `resolve` est fourni
  par le service propriétaire au moment de `registerIntent`, jamais dans la déclaration
  partagée.

## Nouvelles intentions

| Intention | Payload | Phases | Cible (champ → portée) | devOnly |
| --- | --- | --- | --- | --- |
| `HarvestResource` | `{ node: string(≤64) }` | Countdown, Day, Night, Escape | `node` → `Forest.HarvestRange`, résolu par `ForestService.findNode` | non |
| `DepositResources` | *(aucun)* | Countdown, Day, Night, Escape | `Counter` → `Forest.HarvestRange`¹ | non |
| `RefuelGenerator` | *(aucun)* | Countdown, Day, Night, Escape | `Generator` → `Generator.InteractRange` | non |
| `PrepareOrder` | *(aucun)* | Night | `Worktop` → `Kitchen.PrepareRange` | non |
| `DeliverOrder` | *(aucun)* | Night | `DriveThruWindow` → `Kitchen.DeliverRange` | non |

¹ `DepositResources` réutilise le point de référence `Counter` du socle ; sa portée reprend
`Forest.HarvestRange` (même échelle qu'une interaction de comptoir courte) plutôt que de créer
un réglage dédié pour une portée identique.

Toutes reprennent les étapes 1 à 6 et 10 du pipeline du socle sans modification (cadence,
enveloppe, intention déclarée, réservation dev, schéma, phase, gestionnaire sous `xpcall`).

### Comportement des handlers

- **HarvestResource** : refuse `NodeUnavailable` si le nœud est en délai de réapparition,
  `InventoryFull` si l'inventaire personnel est déjà à `Forest.InventoryCapacity` ; sinon
  ajoute 1 unité à l'inventaire du joueur et rend le nœud indisponible.
- **DepositResources** : verse la totalité de `Inv_SuspectSteak` et `Inv_RoadBread` du joueur
  dans `Stock` (`Essence` n'est jamais concernée) ; toujours accepté (aucun effet si
  l'inventaire est déjà vide de ces types).
- **RefuelGenerator** : verse la totalité de `Inv_Essence` du joueur dans le générateur, en
  respectant sa capacité ; le surplus reste dans l'inventaire. Toujours accepté.
- **PrepareOrder** : refuse `OrderClosed` si `OrderState.Status` n'est pas `Pending`, refuse
  `MissingIngredients` si le stock partagé n'a pas les quantités de la recette active ; sinon
  déduit le stock et passe `Status` à `Prepared`.
- **DeliverOrder** : refuse `OrderClosed` si `Status` est `Delivered`/`Failed`/vide, refuse
  `NotPrepared` si `Status` est encore `Pending` ; sinon passe `Status` à `Delivered` et
  diffuse `OrderDelivered`.

## Nouveaux codes de refus (`Types.RejectCode`, additifs — research R11)

| Code | Utilisé par | Sens |
| --- | --- | --- |
| `NodeUnavailable` | HarvestResource | le nœud existe mais est en délai de réapparition |
| `InventoryFull` | HarvestResource | inventaire personnel déjà à sa capacité |
| `MissingIngredients` | PrepareOrder | stock partagé insuffisant pour la recette active |
| `NotPrepared` | DeliverOrder | la commande n'a pas encore été préparée |
| `OrderClosed` | PrepareOrder, DeliverOrder | aucune commande active, ou déjà livrée/en échec |

Les onze codes du socle (`RateLimited`, `BadEnvelope`, `UnknownAction`, `NotAllowed`,
`BadPayload`, `WrongPhase`, `NoCharacter`, `TargetMissing`, `TooFar`, `Cooldown`,
`HandlerError`) gardent leur sens exact, y compris pour ces nouvelles intentions (ex. :
`HarvestResource` sur un nœud inexistant renvoie `TargetMissing`, pas `NodeUnavailable`, qui ne
couvre que le cas « existe mais indisponible »).

## Nouvelles notifications (`Remotes.NotificationKinds`, additives)

| Notification | Portée | Déclenchée par | Données |
| --- | --- | --- | --- |
| `GeneratorEmpty` | broadcast | `GeneratorService` | *(aucune)* |
| `GeneratorRefueled` | broadcast | `GeneratorService` (transition 0 → >0 uniquement) | *(aucune)* |
| `OrderStarted` | broadcast | `OrderService` (début de nuit) | `{ recipeId }` |
| `OrderDelivered` | broadcast | `OrderService` | `{ recipeId }` |
| `OrderFailed` | broadcast | `OrderService` | `{ recipeId }` |
| `EnemyHit` | send (joueur touché uniquement) | `EnemyService` | `{ damage }` |

`GeneratorEmpty`/`GeneratorRefueled` ne se déclenchent qu'aux transitions (pas à chaque tick de
drain), pour ne pas noyer le fil de notifications (cohérent avec `Ui.NotificationMax` du
socle).

## Aucune intention pour l'ennemi

L'ennemi est une IA entièrement serveur (research R8, R9) : aucun client n'envoie d'intention
le concernant, et le serveur ne lui envoie aucune donnée hors la notification ciblée
`EnemyHit`. Sa position/visuel se réplique comme toute instance de `Workspace`.
