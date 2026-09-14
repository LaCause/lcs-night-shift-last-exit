# Implementation Plan: Premier incrément jouable

**Branch**: `002-premier-increment-jouable` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-premier-increment-jouable/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Ce plan rend la boucle de jeu jouable de bout en bout pour la première fois (principe II),
au-dessus du socle technique (`001-socle-technique`) qu'il ne modifie pas, hormis deux
extensions additives déjà prévues par ce dernier : un nouveau point de référence
(`EnemySpawn`) et un résolveur de cible optionnel dans `NetService.registerIntent` (research
R3).

Sept nouveaux systèmes serveur s'ajoutent aux huit du socle :

- **ForestService** génère, à chaque nouvelle partie, un ensemble fixe de nœuds de ressource
  (essence, steak suspect, pain de route) dérivé de la seed ;
- **InventoryService** tient l'inventaire personnel de chaque joueur et le stock partagé du
  restaurant ;
- **GeneratorService** fait baisser le carburant en continu, l'augmente sur dépôt d'essence, et
  pilote le néon et la zone de sécurité (une lumière attachée au point de référence existant) ;
- **OrderService** génère une commande au début de chaque nuit, valide sa préparation puis sa
  livraison, et signale son échec ;
- **EnemyService** fait apparaître un ennemi simple (poursuite, contact, repli) quand une
  commande échoue, protégé par la zone de sécurité ;
- **HealthService** porte une santé serveur par joueur, distincte de `Humanoid`, qui déclenche
  l'élimination déjà gérée par le socle ;
- **AmbianceService** tweenne l'éclairage et le brouillard entre Jour et Nuit.

Toutes les nouvelles actions de joueur (récolter, déposer, alimenter, préparer, livrer) passent
par le canal `Intent` unique du socle, avec les mêmes dix étapes de validation. Le bus et la
vraie condition de victoire restent hors périmètre (assumption de la spec).

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les nouveaux modules — identique au
socle.

**Primary Dependencies**:

- Moteur Roblox uniquement (`PathfindingService`, `TweenService`, `CollectionService`) ;
  aucune bibliothèque externe, pas de Wally — inchangé.
- Même outillage figé par Rokit (Rojo 7.7.0, selene 0.31.0, StyLua 2.5.2), aucune version à
  changer.

**Storage**: N/A. Toujours aucune persistance ; tout l'état de gameplay vit en mémoire serveur
et se réplique par attributs, comme le socle.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md), qui complète (sans le
  répéter) `specs/001-socle-technique/quickstart.md` ;
- commandes de dev ajoutées à `DevService` pour déclencher chaque scénario sans attendre les
  minuteries réelles (`Dev.GiveResources`, `Dev.ForceOrderResult`, `Dev.SpawnEnemy`,
  `Dev.ShowGameplayState`) ;
- `selene` et `stylua --check`, `grep math.random` — étendus aux nouveaux fichiers.

**Target Platform**: Roblox, ordinateur en priorité, interface lisible sur téléphone —
inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que le socle.

**Performance Goals**:

- aucun gel perceptible à la génération de la forêt (par lot, au changement de partie, pas par
  frame), à l'apparition/déplacement de l'ennemi, ni au drain périodique du générateur ;
- le déplacement de l'ennemi et le drain du générateur utilisent des boucles à faible fréquence
  (`RepathInterval`, tick d'une seconde), jamais un calcul par `Heartbeat` coûteux ;
- écart d'affichage entre joueurs toujours < 1 s (hérité du socle, aucune nouvelle donnée
  temporelle propre à cette fonctionnalité qui échapperait à `GetServerTimeNow`).

**Constraints**:

- autorité serveur totale, inchangée : aucune nouvelle RemoteFunction, aucun `InvokeClient` ;
- aucun `math.random` : `ForestService` et `EnemyService` utilisent `MatchService.rng(...)` ;
- toute valeur d'équilibrage listée dans `Settings.luau` (contracts/config.md) ;
- commandes de dev toujours limitées à Studio (`devOnly`) ;
- aucun asset externe requis : tous les nouveaux visuels (nœuds de ressource, ennemi) sont des
  primitives, comme `Catalog.luau` existant.

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 7 nouveaux systèmes serveur, environ
24 nœuds de ressource actifs par partie, 1 recette, 1 archétype d'ennemi, 5 nouvelles
intentions, ~15 nouveaux fichiers Luau.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | jour = exploration/collecte ; nuit = commande, menace, énergie ; néon/zone de sécurité liés au générateur ; victoire/défaite déjà en place | ForestService (collecte de jour) ; OrderService + EnemyService (nuit) ; GeneratorService (néon/zone) ; défaite déjà gérée par le socle via `HealthService` → `SessionService.setStatus` | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | pour la première fois depuis le socle : explorer → alimenter → préparer/livrer → survivre forment une boucle complète et testable en solo (quickstart V1–V5) | ✅ (plus d'écart à justifier ici) |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide, pipeline de validation, pas d'`InvokeClient`, l'UI reflète l'état répliqué | 5 nouvelles intentions via le canal `Intent` unique, mêmes 10 étapes ; résolveur de cible additif (research R3), toujours côté serveur ; santé, stock, carburant et commande tous à écrivain unique serveur | ✅ |
| IV. Rojo et services | répartition par service, `Workspace` reproductible par script, remotes déclarés en un seul endroit, configuration centralisée | nouveaux services dans `ServerScriptService/Server/Services` ; `Workspace.Forest`/`Workspace.Enemies` construits par script (research R2) ; intentions ajoutées dans le `Remotes.luau` existant ; réglages dans `Settings.luau` (contracts/config.md) | ✅ |
| V. Procédural déterministe | `Random` par contexte dérivé de la seed, pas de `math.random`, pas de gel perceptible, rayons de génération configurables | `ForestService` utilise `MatchService.rng("forest")` ; forêt fixe générée en un lot par partie (autorisé pour le MVP par la constitution) ; `Forest.AreaMinRadius`/`AreaMaxRadius` configurables | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible, `pcall` sur les appels risqués, IA simple et prévisible, `PathfindingService` avec repli | recherche de chemin en échec → déplacement direct (research R8) ; délai de repli/disparition (`Enemy.GiveUpDelay`/`MaxLifetime`) ; tous les nouveaux systèmes passent par `Loader` (`Init`/`Start` sous `xpcall`, inchangé) | ✅ |
| VII. Coopération lisible | chaque joueur peut contribuer, interactions rapides et visibles, interface avec nuit/commande/temps/énergie/équipe/ressources | récolte, dépôt, préparation, livraison ouvertes à tout joueur, retour immédiat (prompt, notification, attribut visible) ; HUD étendu (carburant, commande active, ressources, santé) | ✅ |
| VIII. Originalité et assets | primitives par défaut, remplaçant automatique, ton non graphique | nœuds de ressource et ennemi en primitives low-poly, noms originaux (steak suspect, pain de route) ; dégâts sans effet graphique choquant (juste une notification et une baisse de santé) | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md), qui étend celle du socle | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | exploration procédurale, commandes absurdes, tension nocturne, coopération (en-tête de la spec) | ✅ |

**Résultat avant recherche** : PASS, sans écart à justifier.

**Réévaluation après conception (Phase 1)** : PASS, sans nouvel écart. La conception confirme
trois garanties supplémentaires :

- le graphe de dépendances reste acyclique en ajoutant sept systèmes
  ([server-api.md](./contracts/server-api.md)) ;
- chaque nouvel élément répliqué garde un écrivain unique
  ([replicated-state.md](./contracts/replicated-state.md)) ;
- l'extension du pipeline réseau (résolveur de cible) est strictement additive et ne change le
  comportement d'aucune intention du socle ([network.md](./contracts/network.md)).

## Project Structure

### Documentation (this feature)

```text
specs/002-premier-increment-jouable/
├── plan.md                  # Ce fichier
├── research.md              # Phase 0 : décisions R1 à R11
├── data-model.md            # Phase 1 : entités de gameplay
├── quickstart.md            # Phase 1 : scénarios V1 à V7 + checklist DoD (complète le socle)
├── contracts/
│   ├── network.md           # Nouvelles intentions, résolveur de cible, codes, notifications
│   ├── replicated-state.md  # Nouveaux dossiers/attributs répliqués
│   ├── server-api.md        # Nouveaux systèmes, priorités, graphe de dépendances, API
│   └── config.md            # Nouveaux réglages (Forest, Generator, Kitchen, Enemy, Ambiance…)
├── checklists/
│   └── requirements.md      # Qualité de la spec
└── tasks.md                 # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Types.luau                          # + ResourceType, OrderStatus, RejectCode (5 codes), RefPointId (+EnemySpawn)
│   ├── Strings.luau                        # + textes des ressources, du générateur, de la commande, de l'ennemi
│   ├── Config/Settings.luau                # + domaines Forest, Generator, Kitchen, Enemy, Ambiance ; Players.MaxHealth
│   ├── Net/Remotes.luau                    # + 5 intentions, + notifications (contracts/network.md)
│   ├── World/RefPoints.luau                # + "EnemySpawn"
│   ├── Assets/Catalog.luau                 # + visuels des nœuds de ressource et de l'ennemi (primitives)
│   ├── Kitchen/
│   │   └── Recipes.luau                    # nouveau : table statique des recettes (une entrée)
│   └── Client/
│       └── GameplayStateClient.luau        # nouveau : lecture Stock/GeneratorState/OrderState/Health/Inventaire
├── ServerScriptService/Server/
│   ├── World/Layout.luau                   # + point de référence EnemySpawn
│   └── Services/
│       ├── ForestService.luau              # nouveau
│       ├── InventoryService.luau           # nouveau
│       ├── GeneratorService.luau           # nouveau
│       ├── HealthService.luau              # nouveau
│       ├── AmbianceService.luau            # nouveau
│       ├── OrderService.luau               # nouveau
│       ├── EnemyService.luau               # nouveau
│       ├── NetService.luau                 # + champ `resolve` optionnel dans registerIntent (additif)
│       └── DevService.luau                 # + 4 commandes de test (contracts/server-api.md)
└── StarterGui/HUD/
    └── Hud.client.luau                     # + carburant, commande active, ressources et santé du joueur
```

**Structure Decision** : toujours une place Rojo unique, aucune nouvelle correspondance dans
`default.project.json` (tous les nouveaux fichiers vivent sous des dossiers déjà mappés par le
socle). `Kitchen/` est un nouveau sous-dossier de `Shared`, au même niveau que `World/` ou
`Assets/`, réservé aux données de cuisine (recettes) — pas de logique, uniquement des données,
comme `Catalog.luau`.

## Complexity Tracking

*Aucune violation du Constitution Check à justifier pour cette fonctionnalité.*
