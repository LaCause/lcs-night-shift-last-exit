# Implementation Plan: Monnaie de base, gain par nuit et bonus d'évasion

**Branch**: `006-monnaie-jetons-fidelite` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-monnaie-jetons-fidelite/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Chaque joueur possède un solde individuel de « Jetons fidélité » qui survit à la partie en cours :
crédité à la fin de chaque nuit survécue (montant croissant avec le numéro de la nuit), avec un
bonus supplémentaire au moment où l'équipe réussit son évasion, proportionnel au nombre de nuits
survécues cette partie-là. Un échec ne retire rien de déjà acquis — seul le bonus d'évasion, qui
récompense une réussite effective, n'est jamais versé sans elle (clarification 2026-09-20 :
persistance durable, façon compte joueur, au-delà d'un redémarrage de serveur).

**La simplification la plus structurante** : cette fonctionnalité n'a besoin d'aucun état
intermédiaire. Deux signaux déjà existants dans `MatchService` couvrent l'intégralité du besoin —
`PhaseEnded` (quand `previousPhase == "Night"`) pour le gain nocturne, `MatchEnded` (quand
`result == "Victory"`) pour le bonus d'évasion. Comme le bonus n'est déclenché que sur Victoire, une
Défaite n'exige **aucune logique dédiée** : l'absence de déclenchement est déjà le comportement
correct (research R3). Le nouveau service, `CurrencyService`, ne maintient donc aucune table privée
par joueur (contrairement à `InventoryService.order` en 005) — juste deux abonnements à des signaux
existants et une paire de fonctions de chargement/sauvegarde.

**Un premier dans ce projet** : aucun système existant n'utilise `DataStoreService` (research R1) —
tout l'état actuel (ressources, sac, générateur, commandes) est réinitialisé à chaque partie. Cette
fonctionnalité introduit donc la première dépendance de persistance inter-serveurs du jeu,
documentée en détail dans `research.md` plutôt que devinée : chargement au moment où
`SessionService.PlayerJoined` se déclenche, écriture au fil de l'eau à chaque crédit (pas de
sauvegarde différée ni groupée), retries bornés en cas d'échec (principe VI), et une jauge en
mémoire (l'attribut `Currency` du joueur) qui reste la source affichée pendant toute la partie —
jamais bloquante sur la réussite d'une écriture.

**Représentation du solde** : un attribut `Currency` sur l'instance `Player`, au même endroit que
`Health`/`MaxHealth` (`HealthService`) plutôt qu'une entrée `Inv_*` — ce n'est pas une ressource
récoltable parmi d'autres, c'est un solde scalaire unique, donc le patron le plus proche est celui
de la santé, pas celui de l'inventaire (research R2). `GameplayStateClient` l'expose par une simple
lecture d'attribut supplémentaire, sans rien changer à son mécanisme de rafraîchissement existant
(`player.AttributeChanged`, déjà générique).

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les nouveaux modules — inchangé.

**Primary Dependencies**:

- `DataStoreService` (moteur Roblox) — **nouveau dans ce projet** (research R1), aucune
  bibliothèque externe.
- Même outillage figé par Rokit (Rojo, selene, StyLua) que les incréments précédents.

**Storage**: `DataStoreService`, un DataStore dédié (`PlayerCurrency` ou équivalent), une clé par
`UserId`. Premier usage de persistance inter-serveurs du projet (research R1) ; tout le reste de
l'état du jeu reste en mémoire, réinitialisé à chaque partie.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md) ;
- `Dev.NextPhase` (existant) suffit à accélérer les nuits pour tester le gain croissant sans
  attendre une partie complète ; aucune nouvelle commande de développement n'est nécessaire ;
- la persistance inter-redémarrage ne peut pas se vérifier par un simple test en session : elle
  s'observe en arrêtant puis relançant le serveur de test Studio entre deux parties (quickstart.md,
  scénario dédié) ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers nouveaux ou modifiés.

**Target Platform**: Roblox — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- le crédit d'une nuit ou d'un bonus d'évasion met à jour l'attribut `Currency` en mémoire de façon
  synchrone (retour HUD immédiat, SC-001) ; l'appel `DataStoreService` correspondant part en
  arrière-plan et ne bloque jamais la boucle de jeu (research R6) ;
- au plus un appel d'écriture par joueur et par événement de crédit (fin de nuit, évasion) — pas de
  sauvegarde périodique ni de polling.

**Constraints**:

- autorité serveur : le solde n'est jamais calculé ni modifié côté client ; `CurrencyService` est
  l'unique écrivain de l'attribut `Currency` ;
- aucun `math.random` : aucun tirage n'entre dans le calcul des gains ou du bonus (formules
  purement déterministes à partir du numéro de nuit) ;
- toute valeur d'équilibrage dans `Settings.luau` (`contracts/config.md`) — formule du gain
  nocturne, formule du bonus d'évasion, paramètres de nouvelle tentative d'écriture ;
- un échec (ou une lenteur) de `DataStoreService` NE DOIT PAS bloquer ni dégrader la partie pour
  qui que ce soit (principe VI, research R7/R8) ;
- aucune commande de développement nouvelle : la persistance et la progression restent testables
  avec les outils déjà existants (`Dev.NextPhase`, `Dev.SetTestProfile`).

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur
(`CurrencyService`), 0 nouvelle intention réseau (le crédit est entièrement déclenché par des
événements serveur, jamais par une action du joueur), 2 réglages nouveaux dans `Settings.luau`
(formules de gain et de bonus) ; environ 5 fichiers touchés dont 1 créé — plus modeste que
005 (~10 fichiers dont 1 créé), la simplification venant de l'absence d'état intermédiaire à
maintenir.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer → récolter → maintenir → survivre → réparer → fuir | la monnaie récompense la boucle existante sans en changer une étape ; aucune phase, aucun objectif, aucune condition de victoire/défaite n'est modifié — seul un effet secondaire s'ajoute à des transitions déjà existantes (`PhaseEnded`, `MatchEnded`) | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | US1 (gain nocturne) est livrable seule et déjà utile ; US2 (bonus d'évasion) et US3 (persistance sur échec) s'ajoutent sans rien casser de US1 | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; aucune autorité client | `CurrencyService` est l'unique écrivain de l'attribut `Currency` ; aucune intention réseau n'est ajoutée pour cette fonctionnalité — rien que le client puisse demander ou influencer ; l'interface ne fait que lire l'attribut répliqué (`GameplayStateClient`, déjà en lecture seule) | ✅ |
| IV. Rojo et services | 1 dossier = 1 service, remotes centralisés, configuration centralisée | 1 service neuf (`CurrencyService`) dans `Server/Services`, suivant le patron existant (`Name`, `Priority`, `Init`) ; aucune intention à déclarer dans `Remotes.luau` (rien ne vient du client) ; formules dans `Settings.luau` | ✅ |
| V. Procédural déterministe | pas de `math.random`, pas de gel perceptible | gain nocturne et bonus d'évasion sont des fonctions pures du numéro de nuit, aucun tirage ; l'appel `DataStoreService` est asynchrone et ne peut pas geler le serveur (research R6) | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | échec de chargement au moment où un joueur rejoint → solde par défaut à 0, rien ne bloque sa partie (research R7) ; échec d'écriture → nouvelle(s) tentative(s) bornée(s), aucune perte silencieuse au-delà de la limite documentée (research R8) ; le solde affiché (mémoire) ne dépend jamais du succès de la sauvegarde | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | le solde de monnaie rejoint l'affichage minimal déjà exigé par ce principe (« ressources du joueur ») ; mise à jour immédiate, comme toute autre valeur pilotée par `GameplayStateClient` | ✅ |
| VIII. Originalité, ton et assets | aucune copie d'un jeu existant | nom « Jetons fidélité » et thème (programme de fidélité maudit du drive-thru) originaux, distincts de toute référence externe citée en amont de cette spécification ; aucun nouvel asset | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md), incluant un scénario dédié au redémarrage serveur | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | rejouabilité (une progression qui survit à l'échec donne une raison de relancer une partie) — axe explicitement listé par le filtre de la constitution | ✅ |

**Aucune réserve à documenter** : aucune autorité n'est déléguée au client, et l'usage
de `DataStoreService` — bien qu'inédit dans ce projet — reste un appel serveur ordinaire depuis
`ServerScriptService/Server/Services/`, au même titre que tout autre service Roblox déjà utilisé ;
il ne contourne aucune des responsabilités de dossier fixées par le principe IV.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- `CurrencyService` ne duplique l'état d'aucun autre système : il ne fait que lire
  `MatchService.getNight()`/`SessionService.all()` et écrire son propre attribut
  ([data-model.md](./data-model.md)) ;
- le sens des dépendances reste à direction unique → `CurrencyService` requiert `MatchService`,
  `SessionService`, `DataStoreService` ; aucun d'eux ne le requiert en retour
  ([contracts/server-api.md](./contracts/server-api.md)) ;
- aucune donnée par-joueur n'emprunte la convention de dossier `ReplicatedStorage/<Système>State` :
  `Currency` suit exactement le patron attribut-sur-`Player` déjà établi par `HealthService`
  (research R2).

## Project Structure

### Documentation (this feature)

```text
specs/006-monnaie-jetons-fidelite/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R8
├── data-model.md             # Phase 1 : solde de monnaie, événements de crédit
├── quickstart.md             # Phase 1 : scénarios de validation + redémarrage serveur
├── contracts/
│   ├── server-api.md         # CurrencyService : surface publique, dépendances
│   └── config.md             # Nouveaux réglages Settings.luau (formules, retries)
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Config/Settings.luau                # + domaine Currency (formules, retries)
│   ├── Client/GameplayStateClient.luau      # + champ `currency` (lecture de l'attribut Player)
│   └── Strings.luau                         # + libellé HUD du solde
├── ServerScriptService/Server/Services/
│   └── CurrencyService.luau                 # nouveau — charge/sauvegarde, crédite nuit + évasion
└── StarterGui/HUD/
    └── Hud.client.luau                      # + indicateur de solde, même colonne que Vie
```

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Le nouveau service suit exactement le même patron que les services
existants (`Name`, `Priority`, `Init`) et rejoint `ServerScriptService/Server/Services/` sans
aucune manipulation manuelle dans Studio (principe IV).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* L'usage de `DataStoreService`, bien
qu'inédit dans ce projet, n'enfreint aucun principe (voir la note sous le tableau ci-dessus) — il
est documenté par transparence, pas parce qu'il constitue un écart à justifier.
