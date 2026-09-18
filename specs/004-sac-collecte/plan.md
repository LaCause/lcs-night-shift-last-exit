# Implementation Plan: Sac de collecte et manipulation des objets à la souris

**Branch**: `004-sac-collecte` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-sac-collecte/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cette fonctionnalité change **la manière de manipuler les objets**, pas leur nature ni leur
économie. Les recettes, les sources, les usages et les dépôts existants restent inchangés.

**Le résultat le plus important de la recherche** : côté serveur, le ramassage ne change
**presque pas**. L'intention `HarvestResource`, son résolveur (`ForestService.findNode`), son
gestionnaire et ses codes de refus sont conservés **tels quels** ; seul le *déclencheur côté
client* passe de l'invite de proximité au pointeur + touche F (R3). Les nœuds de forêt portent
déjà les attributs dont le client a besoin pour viser (`ResourceType`, `Available`).

**Deux nouveaux systèmes serveur**, chacun écrivain unique de son état :

- `BagService` (priorité 47) : le sac comme **contenant unique** du joueur. Il publie la
  contenance sur le joueur (`BagType`, `BagCapacity`) et dépose un `Tool` « LittleBag » dans le
  sac à dos natif à chaque apparition du personnage (R2). C'est le **premier `Tool` du projet** :
  aucun code `Tool`/`Backpack`/`StarterPack` n'existait jusqu'ici.
- `CarryService` (priorité 48) : la saisie exclusive d'un objet et son déplacement, borné et
  surveillé par le serveur (R4, R5).

**Un nouveau contrôleur client**, `PointerController` (priorité 12), qui possède **le seul
raycast du pointeur** et en dérive les deux gestes : F pour ramasser, clic maintenu pour
déplacer. Un seul propriétaire du pointeur évite de dupliquer le lancer de rayon par geste.

**Trois modifications assumées à du code existant** (comme `003-bus-evasion`, ce n'est pas une
extension purement additive) :

1. `ForestService.buildNode` ne crée plus de `ProximityPrompt` sur les nœuds, et `setAvailable`
   n'a plus de prompt à basculer : c'est précisément le remplacement demandé par la spec. Les
   invites de proximité des **postes** (comptoir, générateur, plan de travail, fenêtre, bus,
   sonnette) et le `InteractionController` qui les relaie restent intacts.
2. `Forest.InventoryCapacity` (10) **disparaît** au profit du domaine `Bag` : la contenance
   n'est plus une constante globale mais une propriété du sac porté (R6). `InventoryService`
   lit la contenance dans l'attribut `BagCapacity` du joueur — pas dans `BagService` — pour
   éviter une dépendance circulaire, exactement comme `NetService` lit la phase dans
   `MatchState` plutôt que dans `MatchService`.
3. Une notification `BagFull` est ajoutée : le pipeline réseau **ne renvoie aucun refus au
   client** (il les journalise seulement), donc sans elle l'exigence « un retour indique que le
   sac est plein » (FR-003) serait intenable. C'est un manque réel de l'architecture actuelle,
   révélé par cette fonctionnalité.

**Le point de conception le plus délicat** est le déplacement à la souris, traité en R4 : il est
conçu pour tenir dans le budget du limiteur de cadence (10 jetons, 5/s) — **deux intentions par
déplacement**, jamais un flux par frame — et pour que le serveur garde le dernier mot sur la
position finale.

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les nouveaux modules — inchangé.

**Primary Dependencies**:

- Moteur Roblox uniquement : `UserInputService` (touche F, clic maintenu),
  `Workspace:Raycast` + `Camera:ViewportPointToRay` (visée), `Highlight` (surbrillance de
  l'objet visé), `Tool`/`Backpack` (le sac dans l'inventaire natif), `AlignPosition` (suivi du
  pointeur pendant un déplacement). Aucune bibliothèque externe.
- Même outillage figé par Rokit (Rojo 7.7.0, selene 0.31.0, StyLua 2.5.2), aucune version à
  changer.

**Storage**: N/A. Aucune persistance ; tout l'état vit en mémoire serveur et se réplique par
attributs, comme les incréments précédents.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md), qui complète sans les
  répéter les guides de `002` et `003` ;
- deux commandes de dev ajoutées (`Dev.FillBag`, `Dev.EmptyBag`) pour tester la contenance et le
  refus « sac plein » sans récolte réelle, dans le même esprit que `Dev.RepairBus` ;
- `selene`, `stylua --check`, `grep math.random` étendus aux nouveaux fichiers.

**Target Platform**: Roblox, ordinateur en priorité. **La visée au pointeur et le clic maintenu
sont des gestes clavier/souris** : le support manette et tactile est explicitement hors périmètre
(Assumptions de la spec). Les invites de proximité des postes, elles, restent utilisables partout.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- le raycast du pointeur est **throttlé** (≈ 15 Hz) et limité par `RaycastParams` à un
  `Workspace.Forest` filtré : aucun coût par frame significatif ;
- le déplacement coûte **2 intentions au total** (prise, relâche), jamais une par frame — le
  limiteur de cadence (`Net.IntentBurst = 10`, recharge 5/s) reste entièrement disponible pour
  les autres actions du joueur ;
- la surveillance serveur d'un objet saisi tourne à 5 Hz par objet saisi (au plus 6 simultanés),
  sur un accumulateur `Heartbeat`, jamais une intention.

**Constraints**:

- autorité serveur : le serveur valide la prise (portée, disponibilité, exclusivité), borne la
  position en continu et **décide seul de la position finale** au relâchement ; il peut forcer un
  relâchement à tout moment ;
- **une exception assumée et bornée** : pendant un déplacement, la propriété réseau (`SetNetwork
  Owner`) de la pièce est confiée au client qui la tient, pour un rendu fluide. Analysée en R4 et
  déclarée au Constitution Check ci-dessous ;
- aucun `math.random` : cette fonctionnalité n'introduit aucun tirage aléatoire ;
- toute valeur d'équilibrage dans `Settings.luau` (contracts/config.md) ;
- commandes de dev toujours limitées à Studio (`devOnly`) ;
- le sac fonctionne **sans l'asset** « LittleBag » : remplaçant en primitives dans `Catalog.luau`,
  comme toute entrée du catalogue (principe VIII).

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 2 nouveaux systèmes serveur, 1 nouveau
contrôleur client, 2 nouvelles intentions, 2 nouveaux codes de refus, 1 nouvelle notification,
1 nouveau domaine de configuration (et 1 réglage retiré), ~12 fichiers touchés dont 3 créés.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer le jour → récupérer des ressources → … | la collecte reste la même étape de la boucle ; seul son geste change. Aucune phase, aucun objectif, aucune condition de victoire n'est touchée | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | US1 (ramassage) est livrable seule et remplace intégralement la collecte actuelle ; US2 et US3 s'ajoutent sans la casser | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; pipeline de validation ; l'UI reflète l'état répliqué | ramassage : **pipeline inchangé**, même intention, même résolveur, même gestionnaire (R3). Saisie : prise et relâche validées (portée, disponibilité, exclusivité), position bornée à 5 Hz côté serveur, position finale décidée par le serveur (R4). La contenance est écrite par `BagService` et lue par le client, jamais calculée par lui | ✅ *(avec la réserve explicitée sous le tableau)* |
| IV. Rojo et services | répartition par service, remotes en un seul endroit, configuration centralisée, aucune manipulation manuelle dans Studio | 2 services dans `Server/Services`, 1 contrôleur dans `Client/Controllers` ; intentions ajoutées au `Remotes.luau` existant ; domaine `Bag` dans `Settings.luau` ; **aucune entrée `StarterPack` ajoutée à `default.project.json`** : le `Tool` est construit par le serveur à partir de l'asset, donc rien à déplacer à la main dans Studio (R2) | ✅ |
| V. Procédural déterministe | `Random` par contexte, pas de `math.random`, pas de gel | aucun tirage aléatoire introduit ; la génération de la forêt est inchangée ; le raycast est throttlé et filtré | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | asset `LittleBag` absent → remplaçant en primitives ; joueur qui se déconnecte ou meurt en tenant un objet → relâchement propre à la dernière position valide (FR-014) ; objet saisi qui sort de la portée → ramené et relâché de force ; sac plein → refus + notification, objet conservé dans le monde | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | surbrillance + libellé de touche sur l'objet visé (FR-001) ; ligne « Sac : n/5 » au HUD ; son et flash déjà génériques réutilisés ; un objet tenu par un coéquipier est visiblement indisponible (`GrabbedBy`) | ✅ |
| VIII. Originalité, ton et assets | primitives par défaut, remplaçant automatique, aucune copie d'un jeu existant | la référence de l'auteur porte sur un **schéma d'interaction générique** (contenant limité, ramassage à la touche, glisser-déposer), pas sur du contenu : objets, noms, visuels et ton restent ceux du projet. `LittleBag` est un asset Creator Store déjà inséré, doublé d'un remplaçant en primitives | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md) | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | exploration procédurale et coopération — en-tête de la spec | ✅ |

**Réserve explicite sur le principe III (propriété réseau pendant un déplacement)**

Le principe III n'admet aucune dérogation, donc cette conception ne se cache pas derrière un
non-dit : pendant un déplacement, `CarryService` confie la propriété réseau de la pièce au client
qui la tient. Ce n'est **pas** une dérogation au principe III, pour trois raisons vérifiables :

1. le principe III énumère ce dont le serveur doit être l'unique source de vérité — ressources,
   inventaires, commandes, carburant, ennemis, dégâts, santé, progression, génération du monde.
   **La position transitoire d'un décor saisi n'y figure pas**, et un objet déplacé ne modifie
   aucune de ces données : déplacer un objet ne le fait pas entrer dans le sac, ne crée ni ne
   consomme aucune ressource ;
2. les trois décisions qui comptent restent serveur : **peut-on saisir** (portée, disponibilité,
   exclusivité), **jusqu'où** (bornage à 5 Hz, relâchement forcé au-delà), **où l'objet finit**
   (position validée au relâchement) ;
3. `SetNetworkOwner` est le mécanisme prévu par le moteur pour une physique pilotée par le
   joueur ; le refuser imposerait soit un flux d'intentions par frame (impossible : le limiteur
   accorde 5 intentions par seconde, ce qui affamerait toutes les autres actions du joueur), soit
   un objet qui se téléporte à l'écran des coéquipiers (R4, alternatives étudiées).

Le pire cas exploitable est donc **un client modifié qui fait bouger un décor de façon incohérente
dans sa propre portée, sans aucun gain de jeu** — borné, sans effet sur l'économie, et corrigé au
relâchement par le serveur.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- le ramassage ne touche pas au pipeline générique — la seule modification serveur est le retrait
  d'une invite de proximité devenue inutile (R3), voir [network.md](./contracts/network.md) ;
- chaque donnée répliquée garde un écrivain unique (`BagService` pour la contenance,
  `CarryService` pour `GrabbedBy`), voir [replicated-state.md](./contracts/replicated-state.md) ;
- le sens des dépendances reste socle/gameplay établi → nouveauté : `InventoryService` ne dépend
  **pas** de `BagService`, il lit un attribut (R6), voir
  [server-api.md](./contracts/server-api.md).

## Project Structure

### Documentation (this feature)

```text
specs/004-sac-collecte/
├── plan.md                  # Ce fichier
├── research.md              # Phase 0 : décisions R1 à R10
├── data-model.md            # Phase 1 : entités de gameplay
├── quickstart.md            # Phase 1 : scénarios V1 à V5 + checklist DoD
├── contracts/
│   ├── network.md           # Nouvelles intentions, codes, notification, déclencheur modifié
│   ├── replicated-state.md  # Attributs du sac, attribut GrabbedBy
│   ├── server-api.md        # Nouveaux systèmes, API, modifications ciblées documentées
│   └── config.md            # Nouveau domaine Bag, retrait de Forest.InventoryCapacity
├── checklists/
│   └── requirements.md      # Qualité de la spec
└── tasks.md                 # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Types.luau                          # + BagType ; + codes AlreadyCarried, NotCarrying
│   ├── Strings.luau                        # + libellés du sac, indice de ramassage, sac plein
│   ├── Config/Settings.luau                # + domaine Bag ; − Forest.InventoryCapacity (R6)
│   ├── Net/Remotes.luau                    # + intentions GrabItem/ReleaseItem, + Dev.FillBag/Dev.EmptyBag, + notification BagFull
│   ├── Assets/Catalog.luau                 # + entrée LittleBag (ModelName + remplaçant en primitives)
│   └── Client/
│       └── GameplayStateClient.luau        # + bagType, bagCapacity, bagUsed
├── ServerScriptService/Server/Services/
│   ├── BagService.luau                     # nouveau (47) — contenance + Tool dans le sac à dos
│   ├── CarryService.luau                   # nouveau (48) — saisie exclusive, bornage, relâchement
│   ├── ForestService.luau                  # − ProximityPrompt des nœuds ; + notification BagFull (R3, R9)
│   ├── InventoryService.luau               # contenance lue dans l'attribut BagCapacity (R6)
│   └── DevService.luau                     # + Dev.FillBag, Dev.EmptyBag
├── StarterPlayer/StarterPlayerScripts/Client/Controllers/
│   ├── PointerController.luau              # nouveau (12) — raycast unique, surbrillance, F, clic maintenu
│   └── SfxController.luau                  # + BagFull (table de données, aucune logique)
└── StarterGui/
    ├── HUD/Hud.client.luau                 # + ligne « Sac : n/5 »
    └── DevPanel/DevPanel.client.luau       # + boutons Remplir/Vider le sac
```

`InteractionController.luau` (relais des invites de proximité) n'est **pas** modifié : les postes
gardent leurs invites. Seuls les nœuds de forêt n'en ont plus.

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. En particulier, aucune entrée `StarterPack` n'est ajoutée : le `Tool`
du sac est construit par `BagService` à partir de `ReplicatedStorage.Assets.LittleBag` (dossier
déjà protégé par `$ignoreUnknownInstances`) et déposé dans le sac à dos à chaque apparition, ce
qui garde le dépôt comme seule source de vérité et n'exige aucune manipulation manuelle dans
Studio (principe IV).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* Les trois modifications à du code existant
(§ Summary) et la réserve sur la propriété réseau (§ Constitution Check) sont documentées pour
rester vérifiables à la lecture, comme l'exige le principe IV — elles ne contournent,
n'affaiblissent ni ne dérogent à aucun principe.
