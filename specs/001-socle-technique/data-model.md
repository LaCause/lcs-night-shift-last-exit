# Data Model — Socle technique du projet

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

Aucune persistance : tout l'état vit en mémoire côté serveur. Ce que les clients doivent voir
est répliqué (voir [contracts/replicated-state.md](./contracts/replicated-state.md)).

## Partie

| Champ | Type | Règles |
| --- | --- | --- |
| `MatchId` | entier ≥ 0 | +1 à chaque nouvelle partie |
| `Seed` | entier 1..2147483647 | `Match.ForcedSeed` si > 0, sinon tirée ; serveur uniquement |
| `Phase` | Phase | voir la machine à états ci-dessous |
| `Night` | entier 0..N | 0 en Attente et Compte à rebours ; n pendant Jour n et Nuit n ; N en Évasion ; conservé en Fin |
| `TotalNights` | entier | copie de `Match.NightCount` au début de la partie, figée ensuite |
| `PhaseEndsAt` | nombre | horodatage serveur de fin de phase ; `0` = sans limite |
| `Result` | `""`, `"Victory"`, `"Defeat"` | écrit une seule fois, à l'entrée en Fin |
| `TestProfile` | booléen | initialisé depuis `Match.TestProfile`, basculable par commande de dev ; s'applique à la phase suivante |

Pendant le Jour n, l'interface affiche « Jour n » et « Nuit n / N » (la nuit à venir).

## Phase — machine à états

Valeurs : `Waiting`, `Countdown`, `Day`, `Night`, `Escape`, `Ended`. Les **phases actives**
sont `Day`, `Night` et `Escape` : la règle de défaite et `endMatch` n'agissent que dans ces
phases.

| Phase | Durée |
| --- | --- |
| `Waiting` | sans limite |
| `Countdown` | `Match.CountdownDuration` |
| `Day` | `Match.DayDuration` |
| `Night` | `Match.NightDuration` |
| `Escape` | `Match.EscapeDuration` (`0` = sans limite) |
| `Ended` | `Match.EndScreenDuration` |

Avec le profil de test, chaque durée est remplacée par sa valeur `test` quand elle en a une
(voir [contracts/config.md](./contracts/config.md)).

| De | Déclencheur | Vers | Effets |
| --- | --- | --- | --- |
| `Waiting` | au moins 1 joueur présent | `Countdown` | nouvelle partie : `MatchId`+1, nouvelle seed, sessions « en vie » |
| `Countdown` | fin du délai | `Day` (n = 1) | `MatchStarted`, notification de phase |
| `Day` (n) | fin du délai | `Night` (n) | notification de phase |
| `Night` (n < N) | fin du délai | `Day` (n + 1) | notification de phase |
| `Night` (N) | fin du délai | `Escape` | notification de phase |
| `Escape` | fin du délai (si durée > 0) | `Ended` (Defeat) | provisoire : la fonctionnalité du bus redéfinira la fin de l'évasion |
| phase active | tous les joueurs présents éliminés | `Ended` (Defeat) | `MatchEnded` |
| phase active | `endMatch(Victory \| Defeat)` | `Ended` | premier résultat retenu, les suivants sont ignorés |
| toute phase sauf `Waiting` | plus aucun joueur présent | `Waiting` | partie abandonnée, journalisée |
| `Ended` | fin du délai, au moins 1 joueur | `Countdown` | nouvelle partie, joueurs replacés au restaurant |
| `Ended` | fin du délai, 0 joueur | `Waiting` | — |

Invariants :

- Une seule phase est active à la fois. Tout délai programmé porte un jeton de phase et
  n'avance la partie que si ce jeton est encore courant (un saut de phase ou un abandon
  invalide les délais en attente).
- `Result` n'est défini qu'en `Ended`. `endMatch` hors des phases actives renvoie `false` et
  journalise une information.

## Session joueur

| Champ | Type | Règles |
| --- | --- | --- |
| `UserId` | entier | clé de la session |
| `Player` | Player | référence au joueur |
| `Status` | `"Alive"` ou `"Eliminated"` | répliqué dans l'attribut `Player.Status` |
| `JoinedAt` | nombre | horodatage serveur d'arrivée |

- Créée à l'arrivée du joueur, supprimée à son départ (connexions libérées).
- Arrivée en phase active ou en Compte à rebours : « en vie », le personnage est chargé au
  restaurant. Arrivée en Fin : « en vie », et le joueur participe à la partie suivante.
- Transitions : `Alive → Eliminated` (commande de dev, plus tard système de santé) ;
  `Eliminated → Alive` (commande de dev, nouvelle partie).
- Un joueur éliminé ne réapparaît pas. Le comportement de son personnage (spectateur, etc.)
  viendra avec le système de santé.

## Équipe (dérivée)

- `countPresent` : nombre de sessions. `countAlive` : sessions au statut « en vie ».
- Règle de défaite : en phase active, si `countPresent > 0` et `countAlive == 0`, la partie se
  termine en défaite. Si `countPresent == 0`, la partie est abandonnée (ce n'est pas une
  défaite).

## Réglage

| Champ | Type | Règles |
| --- | --- | --- |
| `domain`, `key` | chaîne | ex. `Match.DayDuration` |
| `kind` | `number`, `integer`, `boolean`, `string`, `enum` | déduit ou déclaré |
| `value` | selon `kind` | la valeur modifiée par le designer |
| `default` | selon `kind` | valeur sûre, utilisée si `value` est invalide |
| `min`, `max` | nombre | bornes incluses (`number`, `integer`) |
| `choices` | liste | valeurs permises (`enum`) |
| `test` | selon `kind` | valeur du profil de test (facultative) |

Validation au chargement : une valeur absente, de mauvais type, hors bornes, non finie, non
entière pour un `integer` ou hors `choices` est remplacée par `default`, avec un avertissement
qui nomme `domain.key` et la valeur rejetée. Un `default` lui-même invalide est une erreur de
développement : il est journalisé comme ERREUR, et le système qui lit ce réglage refuse de
démarrer. Liste complète : [contracts/config.md](./contracts/config.md).

## Requête de joueur (intention)

- **Enveloppe** : `action` (chaîne de 64 caractères au plus) + `payload` (table, facultative).
- **Définition d'une intention** : nom, schéma, phases autorisées, cible (champ du payload qui
  désigne un point de référence, et réglage de portée), `devOnly`, gestionnaire.
- **Refus** : `{ at, userId, action, code, detail }`. Codes : `BadEnvelope`, `UnknownAction`,
  `NotAllowed`, `RateLimited`, `BadPayload`, `WrongPhase`, `NoCharacter`, `TargetMissing`,
  `TooFar`, `Cooldown`, `HandlerError`. Les refus sont gardés dans un historique circulaire de
  `Net.RejectionHistory` entrées.
- Détail du pipeline : [contracts/network.md](./contracts/network.md).

## Point de référence

| Champ | Règles |
| --- | --- |
| `Id` | `Spawn`, `DriveThruWindow`, `Intercom`, `Counter`, `CounterBell`, `Worktop`, `Fryer`, `Generator`, `NeonSign`, `SafeZoneCenter`, `BusSpot` |
| Instance | Part ancrée, invisible et non collisionnable, sauf `CounterBell` qui est visible |
| Marquage | attribut `RefPoint = <Id>` et tag CollectionService `RefPoint` |
| Position | fixée dans `World/Layout.luau` |

Tous les identifiants sont uniques. `WorldService` vérifie au démarrage qu'ils existent tous et
journalise une ERREUR pour chaque manquant. `Spawn` est à plus de `Bell.Range` +
`Net.DistanceTolerance` de `CounterBell`, pour que le cas « trop loin » se teste depuis le
point d'apparition.

## Visuel catalogué

| Champ | Règles |
| --- | --- |
| `Id` | ex. `Restaurant`, `Bus`, `NeonSign`, `Ground` |
| `ModelName` | facultatif : nom d'un modèle sous `ReplicatedStorage.Assets` |
| `BuildFallback` | obligatoire : construit le modèle en primitives low-poly |

Le remplaçant est utilisé si `ModelName` est absent ou introuvable, ou si
`Visuals.PrimitivesOnly` vaut `true`. Un avertissement est journalisé quand un modèle déclaré
manque. Dans le socle, aucun visuel ne déclare de `ModelName` : seul le test de secours en
utilise un, volontairement absent.

## Notification

| Champ | Règles |
| --- | --- |
| `kind` | `PhaseStarted`, `PlayerJoined`, `PlayerLeft`, `StatusChanged`, `BellRang`, `MatchEnded`, `DevReport` |
| `params` | table propre à chaque type (voir [contracts/network.md](./contracts/network.md)) |

Côté client, le texte vient de `Strings.luau`. Le fil affiche au plus `Ui.NotificationMax`
messages, chacun effacé après `Ui.NotificationLifetime` secondes. Les types inconnus sont
ignorés (journal de niveau debug).
