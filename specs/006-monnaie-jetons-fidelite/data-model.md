# Data Model — Monnaie de base, gain par nuit et bonus d'évasion

Aucun attribut ni dossier existant ne change de forme. Cette fonctionnalité ajoute un attribut
répliqué par joueur (le solde), un enregistrement persistant hors du serveur (`DataStoreService`),
et un petit état interne transitoire (savoir si le chargement initial d'un joueur est résolu) —
rien de tout cela n'a d'équivalent dans les fonctionnalités précédentes (research R1, R2).

## Solde de monnaie (attribut `Player`, répliqué)

```text
Currency: number   -- attribut sur l'instance Player, comme Health/MaxHealth
```

**Écrivain unique** : `CurrencyService`. Aucun autre système ne lit ni n'écrit cet attribut.

**Posé** uniquement après résolution du chargement initial (research R7) — jamais un `0` par
défaut immédiat suivi d'un écrasement, pour éliminer la course entre un chargement tardif et un
crédit survenu entre-temps.

**Lu par** :

- `GameplayStateClient.get()` (nouveau champ `currency`, lecture de `player:GetAttribute("Currency")`,
  défaut `0`) ;
- `Hud.client.luau`, via `GameplayStateClient`, pour l'affichage.

**Transitions** :

```text
SessionService.PlayerJoined  → chargement asynchrone depuis DataStore → attribut posé (valeur
                                chargée, ou 0 si l'échec persiste après les tentatives de R8)
MatchService.PhaseEnded
  (previousPhase == "Night") → += gain nocturne (fonction du numéro de nuit terminée, R3/R4)
MatchService.MatchEnded
  (result == "Victory")      → += bonus d'évasion (fonction du nombre de nuits survécues, R3/R4)
MatchService.MatchEnded
  (result == "Defeat")       → aucune transition : l'attribut garde sa valeur courante (R5)
```

**Jamais réinitialisé** par `MatchStarting` ni par aucune remise à zéro de partie : contrairement à
tout le reste de l'état géré par ce projet jusqu'ici, ce solde est explicitement conçu pour
survivre à la partie (clarification 2026-09-20).

## Enregistrement persistant (DataStoreService)

```text
DataStore: "PlayerCurrency" (nom indicatif, choix exact laissé à l'implémentation)
Clé       : tostring(player.UserId)
Valeur    : number  -- même quantité que l'attribut Currency, au moment de la dernière écriture réussie
```

**Écrit** à chaque transition de l'attribut `Currency` ci-dessus (fin de nuit, bonus d'évasion),
jamais à intervalle régulier ni en fin de partie uniquement (R5, R6). Chaque écriture est
indépendante des autres : un échec sur l'une ne retient pas les suivantes.

**Lu** une seule fois par session de jeu, au moment de `SessionService.PlayerJoined`.

## État interne transitoire (CurrencyService, non répliqué)

```text
loaded: { [Player]: boolean }
```

Vrai une fois le chargement initial d'un joueur résolu (succès ou échec définitif après les
tentatives de R8). Tant qu'il est faux ou absent pour un joueur, ce joueur est ignoré par les deux
événements de crédit (R7) — jamais bloquant pour la partie, juste un garde-fou pour éviter la
course décrite en R7.

**Nettoyage** : entrée supprimée sur `SessionService.PlayerLeft`, même patron que
`InventoryService.order` (005, `InventoryService.luau:287-289`) — sans quoi la table fuirait un
joueur par départ.

## Gain nocturne (règle, pas une entité stockée)

```text
gain(night: number) -> number   -- fonction pure, valeurs de configuration (contracts/config.md)
```

Aucun état à conserver : recalculé à chaque `PhaseEnded("Night", n)` à partir du seul argument
`n` (`previousNight`, fourni par `MatchService`). Strictement croissant avec `n` par construction
de la formule retenue (contracts/config.md), ce qui satisfait SC-002 sans validation
supplémentaire à l'exécution.

## Bonus d'évasion (règle, pas une entité stockée)

```text
escapeBonus(nightsSurvived: number) -> number   -- fonction pure, valeurs de configuration
```

`nightsSurvived` est lu directement depuis `MatchService.getNight()` au moment où `MatchEnded`
livre `result == "Victory"` — aucun compteur dédié à maintenir en parallèle.

## Relations avec les entités existantes

- **Aucune nouvelle donnée par partie** : `MatchState`, `GeneratorState`, `OrderState`, `BusState`
  restent inchangés ; `CurrencyService` les lit (`MatchService.getNight()`,
  `SessionService.all()`) sans jamais les modifier.
- **Aucun nouveau dossier `ReplicatedStorage`** : la monnaie suit le patron attribut-sur-`Player`
  (`Health`), pas le patron dossier-par-système (`GeneratorState` et consorts) — voir research R2
  pour la justification de ce choix.
- **Aucune ressource récoltable n'est affectée** : `Inv_Essence`/`Inv_SuspectSteak`/
  `Inv_RoadBread`/`Inv_Scrap` et le reste du modèle 002/004/005 restent exactement ce qu'ils sont ;
  la monnaie est un système entièrement additif, sans point de couplage avec l'inventaire.
