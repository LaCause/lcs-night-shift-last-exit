# Implementation Plan: Système de craft à l'établi

**Branch**: `009-craft-etabli` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/009-craft-etabli/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Un établi, nouveau lieu du restaurant (interaction de proximité, comme le bus ou le générateur),
où un joueur ouvre un petit panneau listant les recettes connues et fabrique celle qu'il choisit
parmi elles, en consommant exactement les ressources requises depuis son propre sac — jamais le
stock partagé. Deux recettes à cet incrément : une trousse de soins de fortune (restaure de la
santé) et un bidon de carburant de secours (alimente la réserve partagée du générateur), chacune
donnant une utilité nouvelle à des ressources déjà récoltées (dont la ferraille, jusqu'ici réservée
à la seule réparation du bus).

**Un seul nouveau service, une extension additive chacun à `InventoryService`/`HealthService`** :
`CraftService` (nouveau) porte le mécanisme de fabrication et son panneau ; `InventoryService`
gagne `hasPersonal`/`consumePersonal`, miroir exact de `hasStock`/`consumeStock` déjà existants
mais sur l'inventaire personnel plutôt que le stock partagé ; `HealthService` gagne `heal`, miroir
symétrique de `damage` déjà existant. `GeneratorService.deposit`/`fuelRoom` (déjà publics) sont
réutilisés tels quels pour l'effet du bidon de carburant — aucune modification nécessaire.

**Un lieu neuf, pas un lieu réutilisé** : deux points de référence existants (`Fryer`, `Intercom`)
se sont révélés totalement inutilisés par aucun système (research R1), un candidat tentant pour
économiser une nouvelle géométrie. Écarté : recycler une friteuse ou un interphone sous l'étiquette
« établi » induirait en erreur quiconque relit `RefPoints.luau`/`Assets/Catalog.luau` plus tard, et
la demande initiale nomme explicitement un lieu nouveau. Le nouveau point de référence
`"Workbench"` est construit comme les autres postes de cuisine — quelques pièces de plus dans le
modèle `Restaurant` déjà existant (`Layout.luau` : coordonnées voisines de `Worktop`/`Fryer`), pas
un nouveau modèle `Layout.Visuals` (aucun état visuel à basculer, contrairement au bus).

**Interaction en deux temps, un seul nouveau patron client** : une invite de proximité à l'établi,
sans attribut `Intent` (`InteractionController.luau` les ignore déjà silencieusement, confirmé par
lecture directe — aucune modification nécessaire de ce contrôleur générique), ouvre localement le
panneau de recettes — aucun aller-retour serveur pour un simple affichage d'interface. La
fabrication elle-même (`CraftItem`) reste une intention réseau ordinaire, revalidée entièrement
côté serveur, avec `target` borné par portée comme `RepairBus`/`RefuelGenerator`.

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les fichiers nouveaux ou modifiés —
inchangé.

**Primary Dependencies**: aucune nouvelle — même outillage Rokit (Rojo, selene, StyLua) que les
incréments précédents ; aucun `DataStoreService` (rien à persister, l'effet est immédiat et ne
laisse aucun état après coup — spec, Assumptions).

**Storage**: N/A — la fabrication ne persiste rien ; ses seuls effets (santé, réserve de carburant)
utilisent des mécanismes de stockage déjà existants (attributs `Player`, `ReplicatedStorage.GeneratorState`).

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md) ;
- `Dev.GiveResources` (existant) suffit à obtenir Essence/Scrap pour tester les deux recettes,
  aucune nouvelle commande de développement n'est strictement nécessaire ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers nouveaux ou modifiés.

**Target Platform**: Roblox — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- fabrication synchrone : vérification, déduction et effet appliqués en une seule passe serveur,
  aucun délai artificiel (contrairement à `OrderService.PrepareDuration`, qui cuit une commande —
  ici rien ne "cuit", l'objet fabriqué n'existant que le temps de son effet) ;
- l'ouverture du panneau est purement locale (aucun aller-retour réseau, SC-001).

**Constraints**:

- autorité serveur : la possession de ressources, leur déduction et l'octroi de l'effet (santé,
  carburant) ne sont jamais décidés côté client ; `CraftService` est l'unique déclencheur de
  `HealthService.heal`/`GeneratorService.deposit` pour cette fonctionnalité (principe III, FR-010) ;
- aucun `math.random` : aucune part de tirage dans la fabrication ;
- toute valeur d'équilibrage (portée, montants de soin/carburant) dans `Settings.luau` ; les
  recettes elles-mêmes (ingrédients, identifiants) sont une donnée structurée dans
  `Craft/Recipes.luau` (research R2/R3), pas un réglage ;
- `InventoryService.hasPersonal`/`consumePersonal` DOIVENT maintenir l'invariant déjà documenté du
  module (`#order[player] == somme(Inv_*)`) — toute consommation appelle `removeFromOrder`, comme
  `depositResource` le fait déjà (research R4).

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur (`CraftService`),
1 nouveau point de référence (`Workbench`), 1 nouvelle intention réseau (`CraftItem`), 2 nouveaux
codes de rejet, 1 nouveau domaine de réglages (`Craft`), 1 nouveau module de recettes statique, 1
nouveau contrôleur client (panneau + invite locale) ; environ 8 fichiers touchés dont 3 créés.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer → récolter → maintenir → survivre → réparer → fuir | la fabrication est un nouveau débouché pour la récolte (jour) et un nouveau levier de maintien nocturne (soin, carburant) — renforce la boucle existante sans en changer les règles | ✅ |
| II. Jouable d'abord | chaque incrément jouable de bout en bout ; rien de décoratif ne bloque | entièrement optionnelle — un joueur qui ne fabrique jamais rien joue exactement comme avant (aucun système existant n'est modifié en profondeur, seulement étendu de façon additive) ; US1 (soin) livrable et utile seule | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; aucune autorité client | `CraftItem` revalide tout côté serveur (recette connue, ressources possédées, bénéfice non nul) ; l'invite d'ouverture du panneau ne déclenche aucun effet de jeu, seulement un affichage local | ✅ |
| IV. Rojo et services | 1 dossier = 1 service, remotes centralisés, configuration centralisée | 1 service neuf (`CraftService`) suivant `{Name, Priority, Init}` ; 1 intention déclarée dans `Remotes.luau` ; réglages dans `Settings.luau`, recettes dans leur propre module de données (comme `Recipes.luau`/`Catalog.luau`) | ✅ |
| V. Procédural déterministe | pas de `math.random`, pas de gel perceptible | aucun tirage ; fabrication synchrone et instantanée, aucun `task.wait` bloquant | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | ressources insuffisantes → refus propre (`InsufficientResources`) ; bénéfice nul → refus propre (`NoBenefit`) ; aucun DataStore impliqué, donc aucun mode d'échec réseau à couvrir pour cette fonctionnalité | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | le panneau affiche en permanence si le joueur a de quoi fabriquer chaque recette (FR-009) ; l'effet (santé/carburant) se reflète immédiatement dans le HUD déjà existant | ✅ |
| VIII. Originalité, ton et assets | aucune copie d'un jeu existant, primitives par défaut | établi = primitives assemblées dans le modèle `Restaurant` déjà construit, même patron que `Worktop`/`Fryer` (aucun nouvel asset) ; noms et thème (« trousse de fortune », « bidon de secours ») cohérents avec le ton déjà établi | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md) | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | tension nocturne (nouveau moyen de survivre à une nuit difficile) et coopération (fabriquer pour l'équipe, gestion partagée du carburant) — deux axes explicitement portés par la spec | ✅ |

**Aucune réserve à documenter** : aucune autorité n'est déléguée au client (même l'invite locale ne
fait qu'afficher, jamais agir) ; les trois extensions additives (`InventoryService.hasPersonal`/
`consumePersonal`, `HealthService.heal`) ne changent le comportement d'aucun appelant existant.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- aucune nouvelle donnée répliquée au-delà de ce que `WorldService`/`HealthService`/
  `GeneratorService` répliquent déjà ([data-model.md](./data-model.md)) ;
- le sens des dépendances reste à direction unique → `CraftService` requiert `InventoryService`,
  `HealthService`, `GeneratorService`, `NetService`, `WorldService` ; aucun d'eux ne le requiert en
  retour ([contracts/server-api.md](./contracts/server-api.md)) ;
- la question de fond (réutiliser un point de référence orphelin ou en construire un nouveau) a été
  tranchée par transparence (research R1) plutôt que par défaut — aucune dérogation nécessaire.

## Project Structure

### Documentation (this feature)

```text
specs/009-craft-etabli/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R6
├── data-model.md             # Phase 1 : recettes, effets, transitions
├── quickstart.md             # Phase 1 : scénarios de validation C1 à C7
├── contracts/
│   ├── server-api.md         # CraftService, InventoryService/HealthService additifs
│   └── config.md             # Domaine Craft
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Config/Settings.luau                    # + domaine Craft
│   ├── Strings.luau                             # + libellés établi (recettes, actions, refus)
│   ├── Types.luau                                # + RefPointId "Workbench" ; + 2 RejectCode
│   ├── Net/Remotes.luau                          # + intention CraftItem
│   ├── World/RefPoints.luau                      # + "Workbench" dans la liste des identifiants
│   └── Craft/Recipes.luau                        # nouveau — recettes statiques (research R2)
├── ServerScriptService/Server/
│   ├── World/Layout.luau                         # + coordonnées du point de référence Workbench
│   └── Services/
│       ├── CraftService.luau                     # nouveau — fabrication, invite, panneau serveur
│       ├── InventoryService.luau                 # + hasPersonal()/consumePersonal() additives
│       └── HealthService.luau                    # + heal() additive
└── StarterPlayer/StarterPlayerScripts/Client/Controllers/
    └── CraftPanelController.luau                 # nouveau — invite locale + panneau de recettes
```

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Un seul nouveau service serveur, suivant exactement le patron existant
(`Name`, `Priority`, `Init`). Aucun nouveau dossier `Layout.Visuals` (research R1) : le nouveau
point de référence s'ajoute au modèle `Restaurant` déjà construit, comme `Worktop`/`Fryer`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* La seule décision non triviale (une invite de
proximité sans attribut `Intent`, purement client) est documentée par transparence (research R5)
plutôt que comme un écart : elle ne délègue aucune autorité au client, `InteractionController.luau`
l'ignore déjà nativement sans aucune modification requise.
