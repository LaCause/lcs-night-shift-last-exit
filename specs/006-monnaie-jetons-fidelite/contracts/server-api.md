# API serveur — Monnaie de base, gain par nuit et bonus d'évasion

Contrairement aux fonctionnalités précédentes, cette fonctionnalité n'ajoute aucune intention
réseau (`Remotes.luau` inchangé) et ne modifie aucun service existant — un seul service nouveau,
entièrement autonome côté écriture.

## `CurrencyService` (nouveau, priorité 70)

Service à une seule responsabilité : maintenir le solde persistant de chaque joueur. Ne crée
aucune instance dans `Workspace`, n'enregistre aucune intention `NetService` (rien ne vient jamais
du client pour cette fonctionnalité) — s'abonne uniquement à des signaux déjà existants d'autres
services.

| Fonction | Contrat |
| --- | --- |
| `Init()` | s'abonne à `SessionService.PlayerJoined` (chargement), `SessionService.PlayerLeft` (nettoyage de l'état transitoire `loaded`), `MatchService.PhaseEnded` (gain nocturne) et `MatchService.MatchEnded` (bonus d'évasion) |
| `balanceOf(player): number` | lecture directe de `player:GetAttribute("Currency") or 0` — utilisée par `GameplayStateClient` et tout futur outil de dev, sans dupliquer l'accès à l'attribut ailleurs dans le code |

**Aucune autre fonction publique** : contrairement à `StationDepositService` (005), rien d'autre
n'a besoin d'appeler ce service — il réagit seul à des événements, personne ne lui délègue de
décision.

**Dépend de** : `SessionService` (liste des joueurs présents, cycle de vie), `MatchService`
(numéro de nuit, résultat de partie), `Config` (formules et paramètres de nouvelle tentative),
`DataStoreService` (moteur Roblox). **Aucun service existant ne dépend de `CurrencyService` en
retour** — aucune circularité, comme pour `StationDepositService` en 005.

### Comportement interne (non exposé, pour référence des tâches d'implémentation)

| Événement source | Effet |
| --- | --- |
| `SessionService.PlayerJoined(player)` | lance un chargement asynchrone (`GetAsync`, protégé par `pcall`, jusqu'à `Currency.SaveRetryAttempts` tentatives) ; pose l'attribut `Currency` une fois résolu (valeur chargée, ou 0 si échec définitif) ; marque `loaded[player] = true` |
| `SessionService.PlayerLeft(player)` | supprime `loaded[player]` (nettoyage, même patron que `InventoryService.order` en 005) |
| `MatchService.PhaseEnded(previousPhase, previousNight)` où `previousPhase == "Night"` | pour chaque joueur de `SessionService.all()` avec `loaded[joueur] == true` : incrémente son attribut `Currency` de `gain(previousNight)` (contracts/config.md), lance une écriture asynchrone (`SetAsync`, jusqu'à `Currency.SaveRetryAttempts` tentatives) |
| `MatchService.MatchEnded(result, night)` où `result == "Victory"` | pour chaque joueur de `SessionService.all()` avec `loaded[joueur] == true` : incrémente son attribut `Currency` de `escapeBonus(night)` (contracts/config.md), lance une écriture asynchrone |
| `MatchService.MatchEnded(result, night)` où `result == "Defeat"` | aucun effet — pas de branche, pas d'appel (research R3/R5) |

## `GameplayStateClient` (module partagé, inchangé dans sa forme)

| Champ | Statut | Contrat |
| --- | --- | --- |
| `currency: number` | **nouveau** dans le type `State` | lecture de `player:GetAttribute("Currency")`, défaut `0` — même patron exact que `health`/`maxHealth` (`readAttr(player, "Currency", 0)`) |

Aucun nouveau branchement nécessaire : `GameplayStateClient.Changed` se déclenche déjà sur tout
changement d'attribut du joueur local (`player.AttributeChanged`), `Currency` en bénéficie sans
code supplémentaire.

## Services existants — aucune modification

`SessionService`, `MatchService`, `BusService`, `HealthService`, `InventoryService` : lus par
`CurrencyService` (signaux, `getNight()`, `all()`), jamais modifiés. Aucun de ces services n'a
connaissance de l'existence de `CurrencyService` — la dépendance ne va que dans un seul sens,
comme l'exige la réévaluation du principe IV dans `plan.md`.
