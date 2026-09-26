# Implementation Plan: Nuits optionnelles après réparation du bus

**Branch**: `007-nuits-optionnelles-evasion` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/007-nuits-optionnelles-evasion/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Une fois le seuil minimum de nuits (`Match.NightCount`) survécu et le bus réparé, l'équipe voit
un choix explicite au bus : partir immédiatement (comportement déjà existant, inchangé) ou rester
une nuit de plus pour une récompense strictement supérieure, au prix d'un danger strictement
croissant. Le choix se répète après chaque nuit supplémentaire survécue, sans plafond. Une
défaite pendant une nuit supplémentaire ne retire jamais les gains déjà acquis (persistance déjà
garantie par `006-monnaie-jetons-fidelite`).

**La phase « Escape » existante devient le point de décision** (research R1) : c'est déjà,
aujourd'hui, exactement le moment où le seuil minimum est atteint et où plus rien ne se passe
automatiquement — cette fonctionnalité transforme ce point mort en choix répétable, sans ajouter
de nouvelle valeur à l'union fermée `Types.Phase`.

**Un vrai bug trouvé en marge, avant même d'écrire du code** : `MatchService.advance()`
transitionne aujourd'hui de « Night » vers « Escape » via `enterPhase("Escape",
state.totalNights)` — codé en dur avec le seuil plutôt qu'avec le numéro de nuit réel. Sans
conséquence dans le flux normal (les deux valeurs coïncident toujours à cet instant), mais une
nuit supplémentaire déjà jouée verrait sa progression silencieusement effacée à chaque retour en
Escape, cassant la récompense strictement croissante exigée par FR-005 dès la deuxième nuit
supplémentaire. Corrigé par un remplacement d'une ligne (`state.night` au lieu de
`state.totalNights`), documenté en détail dans `research.md` (R2) et testé explicitement par le
scénario C3 de `quickstart.md`.

**Aucun changement à `CurrencyService`** : ses deux abonnements existants (`PhaseEnded` quand
`previousPhase == "Night"`, `MatchEnded` quand `result == "Victory"`) couvrent déjà entièrement la
récompense d'une nuit supplémentaire, une fois le correctif ci-dessus appliqué (research R7).
Cette fonctionnalité n'introduit donc aucune nouvelle mécanique de monnaie.

**Le danger croît sans toucher à l'invariant « un seul ennemi actif à la fois »** (research R4) :
`EnemyService` impose déjà cet invariant depuis `002-premier-increment-jouable` ; plutôt que d'y
toucher, le danger croissant vient d'une augmentation linéaire des dégâts et de la vitesse du même
ennemi, scopée aux seules nuits au-delà du seuil (`extraNights`), laissant les nuits normales
totalement inchangées (FR-011).

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les fichiers modifiés — inchangé.

**Primary Dependencies**: aucune nouvelle. Même outillage Rokit (Rojo, selene, StyLua) que les
incréments précédents ; aucune bibliothèque externe, aucun nouveau service Roblox (contrairement
à `006` qui introduisait `DataStoreService`).

**Storage**: aucune nouvelle donnée persistée. La monnaie déjà persistée par `006` suffit ; cette
fonctionnalité ne fait qu'augmenter le nombre de nuits qui peuvent y contribuer avant un départ.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md), en particulier le
  scénario C3 qui vérifie explicitement le correctif R2 (deux nuits supplémentaires consécutives
  doivent progresser, pas se répéter) ;
- `Dev.NextPhase`, `Dev.RepairBus`, `Dev.TestProfile` (tous existants) suffisent à tester sans
  attendre une partie complète ; aucune nouvelle commande de développement n'est nécessaire ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers modifiés.

**Target Platform**: Roblox — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**: aucun changement — `PushNight` est une intention réseau ordinaire, validée
et traitée de façon synchrone comme `DepartBus` et `RepairBus` existants ; aucun appel
asynchrone nouveau (contrairement à `006` et `DataStoreService`).

**Constraints**:

- autorité serveur : `PushNight` revalide entièrement côté serveur (phase, réparation, présence
  d'équipe) — le client ne fait que proposer l'action, jamais la décider (principe III) ;
- aucun `math.random` : ni le choix, ni la croissance du danger, ni la récompense ne dépendent
  d'un tirage — toutes des fonctions déterministes du numéro de nuit ;
- toute valeur d'équilibrage dans `Settings.luau` (`contracts/config.md`) — croissance du danger
  par nuit supplémentaire ; aucune valeur codée en dur ;
- le comportement de départ avant le seuil minimum (bus réparé en avance) ne doit subir aucune
  régression (FR-008, vérifié par C5) ;
- aucun plafond du nombre de nuits supplémentaires (research R8, cohérent avec l'Assumption de la
  spec) — pas de nouveau réglage spéculatif.

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 0 nouveau système serveur (extension de
`MatchService`, `BusService`, `EnemyService` existants) ; 1 nouvelle intention réseau
(`PushNight`) ; 2 réglages nouveaux dans `Settings.luau` (domaine `Enemy` étendu) ; environ 6
fichiers touchés, aucun créé côté serveur — plus modeste que `006` en surface, mais avec un
correctif ciblé sur du code déjà existant.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer → récolter → maintenir → survivre → réparer → fuir | aucune étape n'est modifiée ; cette fonctionnalité ajoute une option *après* la victoire déjà atteignable, jamais une nouvelle étape obligatoire | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | US1 (départ inchangé) reste le comportement par défaut si l'équipe ne fait rien de nouveau ; US2 (rester) et US3 (gains conservés en cas d'échec) s'ajoutent sans rien casser de US1 | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; aucune autorité client | `PushNight` revalide phase, réparation et présence d'équipe côté serveur, exactement comme `DepartBus` ; le client ne fait qu'afficher une prévisualisation calculée à partir de données déjà répliquées | ✅ |
| IV. Rojo et services | 1 dossier = 1 service, remotes centralisés, configuration centralisée | aucun nouveau service ; extension additive de `MatchService`/`BusService`/`EnemyService` existants, suivant leur patron déjà en place ; nouveau réglage dans `Settings.luau`, domaine `Enemy` déjà existant | ✅ |
| V. Procédural déterministe | pas de `math.random`, pas de gel perceptible | croissance du danger et de la récompense purement fonction du numéro de nuit ; `PushNight` traité de façon synchrone, aucun appel bloquant | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | `PushNight` échoue proprement (`WrongPhase`/`BusNotRepaired`/`TeamNotReady`) sans jamais bloquer la partie si les conditions ne sont pas réunies ; une défaite pendant une nuit supplémentaire suit exactement le chemin de défaite déjà existant (`checkDefeat`, inchangé) | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | le choix et sa récompense prévisionnelle sont affichés explicitement au bus (FR-009), pas seulement disponibles en silence comme l'était `DepartBus` jusqu'ici | ✅ |
| VIII. Originalité, ton et assets | aucune copie d'un jeu existant | aucun nouvel asset ; réutilise le décor et le vocabulaire déjà établis (bus, évasion, jetons fidélité) | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md), avec un scénario dédié (C3) au correctif de progression des nuits | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | tension nocturne (chaque nuit supplémentaire est un vrai risque accru) et rejouabilité (une raison mécanique de tenter d'aller plus loin à chaque partie) — deux axes explicitement listés par le filtre de la constitution | ✅ |

**Aucune réserve à documenter** : aucune autorité n'est déléguée au client ; le correctif de
`MatchService.advance()` (research R2) ne change le comportement observable d'aucun flux existant
(vérifié no-op sur le cas normal, C1/C5).

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- aucune nouvelle donnée répliquée ([data-model.md](./data-model.md)) : `MatchState` et
  `BusState` déjà existants suffisent entièrement ;
- le sens des dépendances reste à direction unique → `EnemyService` dépend déjà de `MatchService`
  (aucun nouvel import), `BusService` dépend déjà de `MatchService` ; aucun des deux n'est
  dépendu en retour par une fonctionnalité plus ancienne
  ([contracts/server-api.md](./contracts/server-api.md)) ;
- `CurrencyService` (006) n'est touché par aucune modification — son contrat public reste
  identique, confirmant que cette fonctionnalité se branche entièrement sur des signaux déjà
  existants plutôt que d'en créer de nouveaux.

## Project Structure

### Documentation (this feature)

```text
specs/007-nuits-optionnelles-evasion/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R8, dont le correctif MatchService
├── data-model.md             # Phase 1 : état dérivé (choix, prévisualisations), aucune nouvelle donnée persistée
├── quickstart.md             # Phase 1 : scénarios de validation, dont C3 (correctif de progression)
├── contracts/
│   ├── server-api.md         # MatchService/BusService/EnemyService : API additive, correctif documenté
│   └── config.md             # Nouveaux réglages Settings.luau (domaine Enemy étendu)
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Config/Settings.luau                    # domaine Enemy + ExtraNightDamageGrowth/ExtraNightSpeedGrowth
│   └── Strings.luau                             # + libellés du choix (partir/rester, récompense)
├── ServerScriptService/Server/Services/
│   ├── MatchService.luau                        # + pushExtraNight() ; correctif de la transition Night→Escape
│   ├── BusService.luau                          # + intention PushNight ; extraction de teamReadyAtBus()
│   └── EnemyService.luau                        # dégâts/vitesse effectifs lisent les 2 nouveaux réglages
└── StarterPlayer/StarterPlayerScripts/Client/Controllers/
    └── BusRepairController.luau                 # + affichage du choix et des deux ProximityPrompt
```

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Aucun nouveau service : toutes les modifications étendent des systèmes
déjà découverts par `Loader` selon le patron existant (`Name`, `Priority`, `Init`, `Start`),
principe IV respecté sans exception.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* Le correctif apporté à
`MatchService.advance()` modifie du code existant plutôt que de se limiter à de l'addition pure,
mais reste strictement dans le périmètre du principe IV (même service, même fonction, comportement
normal inchangé) — documenté par transparence dans `research.md` (R2), pas parce qu'il constitue
un écart à justifier.
