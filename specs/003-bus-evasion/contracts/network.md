# Contrat réseau — Bus et victoire par évasion

Étend `specs/002-premier-increment-jouable/contracts/network.md` (pipeline en 10 étapes inchangé,
résolveur de cible optionnel inchangé). Ce document ne redéfinit rien : il ajoute deux
intentions, deux codes de refus et deux notifications. Aucune extension du pipeline lui-même
n'est nécessaire (R5) : `RepairBus` et `DepartBus` utilisent toutes deux la résolution par
`RefPoints.find` déjà existante (`BusSpot`), sans résolveur dynamique.

## Nouvelles intentions

| Intention | Payload | Phases | Cible (champ → portée) | devOnly |
| --- | --- | --- | --- | --- |
| `RepairBus` | `{ target: string(≤64) }` | Countdown, Day, Night, Escape | `target` → `Bus.InteractRange` | non |
| `DepartBus` | `{ target: string(≤64) }` | Escape | `target` → `Bus.DepartureRange` | non |

Toutes deux reprennent les étapes 1 à 6 et 10 du pipeline sans modification (cadence, enveloppe,
intention déclarée, réservation dev, schéma, phase, gestionnaire sous `xpcall`). `DepartBus` est
restreinte à la phase Évasion par l'étape 6 générique (`WrongPhase` sinon) — cohérent avec
FR-008 : le départ n'est possible qu'une fois les nuits requises survécues.

### Comportement des handlers

- **RepairBus** : refuse `TargetMissing` si `target ≠ "BusSpot"` (cas générique, cible
  inexistante). Si le bus est déjà réparé (`Deposited >= Required`), accepté sans effet — aucune
  ferraille consommée, comme `RefuelGenerator` sur un générateur déjà plein (aucun code de refus
  dédié : c'est un succès sans conséquence, pas une erreur). Sinon, dépose jusqu'au manque
  (`Required - Deposited`) via `InventoryService.depositResource(player, "Scrap", room)` (R4) ;
  si au moins une unité est effectivement déposée, notifie `ScrapDeposited` au joueur et publie
  `BusState`. Si `Deposited` atteint `Required` à ce dépôt, bascule `Repaired = true`, diffuse
  `BusRepaired`, et met à jour le visuel du bus (R7).
- **DepartBus** : refuse `TargetMissing` si `target ≠ "BusSpot"` (cas générique). Refuse
  `BusNotRepaired` si `BusState.Repaired` est faux. Sinon, vérifie que chaque session dont
  `Status == "Alive"` a un personnage chargé à une distance de `BusSpot` ≤ `Bus.DepartureRange +
  Net.DistanceTolerance` (un joueur en vie sans personnage chargé compte comme hors de portée,
  R5) ; au premier manquant, refuse `TeamNotReady`. Si tous sont présents, appelle
  `MatchService.endMatch("Victory", "le bus est parti")` — qui diffuse déjà `MatchEnded` et fait
  transiter la partie vers `Ended` (socle technique, inchangé).

## Nouveaux codes de refus (`Types.RejectCode`, additifs)

| Code | Utilisé par | Sens |
| --- | --- | --- |
| `BusNotRepaired` | DepartBus | le bus n'a pas encore atteint son total de réparation requis |
| `TeamNotReady` | DepartBus | au moins un joueur encore en vie n'est pas à portée du bus (ou n'a pas de personnage chargé) |

Les seize codes déjà en place (socle + `002-premier-increment-jouable`) gardent leur sens exact.
`TargetMissing`/`TooFar`/`WrongPhase` restent les refus génériques du pipeline (cible
inexistante, appelant trop loin, mauvaise phase) ; `BusNotRepaired`/`TeamNotReady` couvrent
uniquement les règles métier vérifiées dans le gestionnaire, au-delà de ce que le pipeline sait
valider seul (comme `MissingIngredients` pour `PrepareOrder` en 002).

## Nouvelles notifications (`Remotes.NotificationKinds`, additives)

| Notification | Portée | Déclenchée par | Données |
| --- | --- | --- | --- |
| `ScrapDeposited` | send (joueur qui dépose uniquement) | `BusService` (dépôt effectif) | `{ amount }` |
| `BusRepaired` | broadcast | `BusService` (transition `Repaired` false → true, une seule fois) | *(aucune)* |

Suit exactement le même patron que `GeneratorFueled` (send, retour personnel) et
`GeneratorRefueled` (broadcast, uniquement à la transition). La victoire elle-même ne crée
aucune nouvelle notification : `DepartBus` réussi diffuse `MatchEnded` (déjà défini dans le
socle), réutilisé tel quel (FR-009).

## Extension de `Dev.GiveResources`

Son schéma (`resource = Validate.enum({...})`) accepte désormais `"Scrap"` en plus des trois
valeurs existantes, pour tester la Story 1 sans exploration réelle — même principe que
l'extension déjà faite pour les ressources de `002-premier-increment-jouable`.

## Nouvelle commande de développement

| Intention | Payload | Effet |
| --- | --- | --- |
| `Dev.RepairBus` | *(aucun)* | force `Deposited = Required` (calcule/fige `Required` s'il ne l'était pas encore) et bascule `Repaired` si atteint — pour tester `DepartBus` sans dépendre d'une récolte réelle (FR-012) |

Suit exactement le même schéma que les commandes de dev existantes (`Dev.*`, `devOnly: true`,
validées par le même pipeline).
