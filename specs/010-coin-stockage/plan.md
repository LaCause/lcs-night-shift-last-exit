# Implementation Plan: Coin de stockage du restaurant

**Branch**: `010-coin-stockage` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/010-coin-stockage/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Le coin de stockage de l'arrière-salle (aujourd'hui un décor) devient un stock commun à l'équipe :
un nombre fixe d'emplacements au sol, où l'on range un objet soit en le lâchant près de lui avec le
sac (touche de lâcher, bref ou maintenu), soit en glissant-déposant un objet du monde dessus. Un
objet rangé reste visible, **figé** sur son emplacement, et ne sort du stock que par une reprise à
proximité : soit vers le sac (touche de ramassage), soit tiré à la souris hors du coin
(clarifications 2026-09-25).

**Un objet rangé est un nœud de forêt « lâché », simplement figé** (research R1). Le jeu sait déjà
faire apparaître un objet du sac au sol (`ForestService.spawnDrop`), l'afficher, le viser, le
ramasser (`HarvestResource`, touche F) et le saisir à la souris (`GrabItem`/`ReleaseItem`). Ranger,
c'est faire apparaître ce nœud sur un emplacement libre, l'ancrer et lui retirer sa collision ;
reprendre, c'est le ramasser ou le saisir comme n'importe quel objet — à une condition de portée en
plus. **Aucune nouvelle intention réseau, aucune modification de la visée côté client** au-delà d'un
libellé d'indice.

**Un seul point d'extension neuf, côté serveur** (research R2) : `ForestService` gagne des
*crochets* par nœud (`canTake` / `onTaken`), posés par le stockage sur ses nœuds figés.
`HarvestResource` et `GrabItem` les consultent : hors de portée du coin, la reprise est refusée
(`TooFar`) ; à la reprise, l'emplacement se libère et l'objet redevient un objet du monde ordinaire.
`ForestService` ne peut pas requérir le stockage (il en est une dépendance), d'où des crochets
fournis par le stockage plutôt qu'une connaissance du stockage dans la forêt.

**Un nouveau service, quatre extensions additives** : `StorageService` (nouveau : emplacements,
rangement, état répliqué, indicateur de remplissage) ; `ForestService` (+ crochets) ;
`CarryService` (le glisser-déposer appelle le rangement, la saisie consulte les crochets) ;
`StationDepositService` (le lâcher au sac essaie le stockage après l'établi, avant les postes
fixes). Le maintien de la touche de lâcher, le lâcher bref et la file d'ordre du sac (`BagService`)
restent **strictement inchangés**.

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les fichiers nouveaux ou modifiés —
inchangé.

**Primary Dependencies**: aucune nouvelle — même outillage Rokit (Rojo, selene, StyLua) ; aucun
`DataStoreService` (le stock ne persiste pas d'une partie à l'autre, FR-013).

**Storage**: N/A — l'état des emplacements vit en mémoire serveur ; ses seules traces répliquées
sont les nœuds eux-mêmes (dans `Workspace.Forest`) et un petit dossier `ReplicatedStorage.StorageState`
(`Count`, `Capacity`), sur le patron de `GeneratorState`/`BusState`/`OrderState`.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md), dont **au moins deux
  clients** (Definition of Done de la constitution : test « Clients and Servers ») pour les
  scénarios de concurrence et de vue partagée ;
- `Dev.GiveResources` (existant) suffit à obtenir des objets ; les objets fabriqués (`HealKit`,
  `FuelCanister`) s'obtiennent via l'établi (009) ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers nouveaux ou modifiés.

**Target Platform**: Roblox — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- rangement et reprise synchrones : une seule passe serveur, aucun délai artificiel ; l'objet est
  visible figé dans la seconde (SC-001, SC-005) ;
- coût borné : au plus `Storage.Capacity` (12) nœuds figés supplémentaires, ancrés et sans
  collision ; aucune boucle par frame, aucun `Heartbeat` (SC-007).

**Constraints**:

- autorité serveur : le stock n'existe que côté serveur ; le client n'envoie que des gestes déjà
  existants (`DropBag`/`DropOneItem`, `ReleaseItem`, `HarvestResource`, `GrabItem`) que le serveur
  revalide (principe III, FR-014) ;
- **aucun `math.random`** : l'emplacement attribué est toujours le plus bas index libre — même
  suite d'actions, même résultat (principe V) ;
- toute valeur d'équilibrage (capacité, disposition, portée) dans `Settings.luau`, domaine
  `Storage` (research R3, FR-001/FR-016) ;
- le comportement des fonctions existantes (`BagService.drop`/`dropOne`,
  `StationDepositService.tryDeposit` pour les postes fixes, `HarvestResource`, `GrabItem`) ne
  change **que** pour un nœud figé par le stockage : tout autre objet suit exactement le chemin
  actuel ;
- un objet n'est jamais à deux endroits : on fait apparaître le nœud **avant** de prélever l'objet
  (comme `BagService.drop`), et on ne prélève rien si l'apparition échoue (principe VI, FR-011).

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur
(`StorageService`), 1 nouveau point de référence (`Storage`), 0 nouvelle intention réseau, 1
nouveau type de notification (`StorageFull`), 1 nouveau domaine de réglages (`Storage`) ; environ
14 fichiers touchés dont 1 créé.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer → récolter → maintenir → survivre → réparer → fuir | le stock s'insère entre la récolte et l'usage (bidon versé au générateur, trousse utilisée) : il soulage un sac de 5 places sans changer aucune règle de la boucle ; aucun système n'en dépend | ✅ |
| II. Jouable d'abord | chaque incrément jouable de bout en bout ; rien de décoratif ne bloque | entièrement optionnelle — un joueur qui ne range jamais rien joue exactement comme avant ; US1 + US2 livrables et utiles seules, US3/US4 s'y ajoutent | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; aucune autorité client | rangement, distance, emplacement, reprise : tout est décidé et validé côté serveur ; le client ne fait que viser et exprimer des gestes existants, jamais poser ni déplacer un objet figé (ancré côté serveur) | ✅ |
| IV. Rojo et services | 1 dossier = 1 service, remotes centralisés, configuration centralisée | 1 service neuf (`StorageService`) suivant `{Name, Priority, Init}` ; aucune nouvelle intention (rien à déclarer) ; 1 type de notification déclaré dans `Remotes.luau` ; réglages dans `Settings.luau` ; point de référence déclaré à un seul endroit (`RefPoints.luau` + `Layout.luau`) | ✅ |
| V. Procédural déterministe | pas de `math.random`, pas de gel perceptible | aucun tirage ; emplacement = plus bas index libre ; aucun travail par frame | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | stock plein → refus propre, l'objet suit le lâcher habituel + message (FR-009) ; apparition impossible (visuel/forêt absents) → rien prélevé ; joueur déconnecté → ses objets rangés restent ; point de référence absent → stockage désactivé sans gêner les autres systèmes ; visuel absent → remplaçant en primitives (déjà garanti par `VisualService`, FR-017) | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | indicateur « Stockage n/N » lisible à proximité (FR-012) ; son de dépôt réutilisé ; message « stockage plein » dans le fil du HUD (FR-015) ; l'étagère montre le contenu d'un coup d'œil | ✅ |
| VIII. Originalité, ton et assets | aucune copie d'un jeu existant, primitives par défaut | objets rangés = les visuels existants (primitives) ; aucun nouvel asset ; le coin de stockage est le décor déjà construit | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md), dont un test à deux clients | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | **coopération** — un stock commun que l'équipe voit, alimente et vide ensemble (spec, en-tête) | ✅ |

**Aucune réserve à documenter** : aucune autorité n'est déléguée au client ; le seul ajout
transversal (les crochets de `ForestService`) est justifié en [research.md](./research.md) R2 et
n'altère le comportement d'aucun nœud qui n'en porte pas.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- **aucune nouvelle intention** : le stock réutilise les quatre gestes existants, donc la surface
  d'attaque réseau ne grandit pas ([contracts/server-api.md](./contracts/server-api.md)) ;
- le sens des dépendances reste à direction unique et **acyclique** :
  `StorageService → ForestService, InventoryService, WorldService, NotifyService, MatchService`,
  puis `CarryService → StorageService` et `StationDepositService → StorageService` ; ni
  `ForestService` ni `StorageService` ne requièrent `CarryService`, `BagService` ou
  `StationDepositService` (graphe complet en [contracts/server-api.md](./contracts/server-api.md)) ;
- aucune nouvelle donnée répliquée au-delà de `ReplicatedStorage.StorageState` et de deux attributs
  sur les nœuds figés ([data-model.md](./data-model.md)) ;
- la question de fond (où vit un objet rangé, comment le protéger) a été tranchée par réutilisation
  (research R1/R2), pas par un nouveau type d'objet ni de nouvelles intentions.

## Project Structure

### Documentation (this feature)

```text
specs/010-coin-stockage/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R10
├── data-model.md             # Phase 1 : emplacements, objets rangés, transitions
├── quickstart.md             # Phase 1 : scénarios de validation S1 à S12
├── contracts/
│   ├── server-api.md         # StorageService, extensions ForestService/CarryService/StationDepositService
│   └── config.md             # Domaine Storage
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Config/Settings.luau                    # + domaine Storage
│   ├── Strings.luau                             # + « Stockage n/N », message « stockage plein », indice de reprise
│   ├── Types.luau                                # + RefPointId "Storage"
│   ├── Net/Remotes.luau                          # + notification StorageFull (aucune intention)
│   ├── World/RefPoints.luau                      # + "Storage" dans la liste des identifiants
│   └── Assets/Catalog.luau                       # décor : caisses et palette retirées (la grille occupe la zone)
├── ServerScriptService/Server/
│   ├── World/Layout.luau                         # + coordonnées du point de référence Storage
│   └── Services/
│       ├── StorageService.luau                   # nouveau — emplacements, rangement, état, indicateur
│       ├── ForestService.luau                    # + crochets par nœud (attachHooks/checkTake/releaseHooks)
│       ├── CarryService.luau                     # + saisie soumise aux crochets ; relâcher → rangement
│       └── StationDepositService.luau            # + essai du stockage (après l'établi, avant les postes)
├── StarterPlayer/StarterPlayerScripts/Client/Controllers/
│   ├── PointerController.luau                    # + libellé d'indice « Reprendre » pour un objet rangé
│   └── SfxController.luau                        # + son de StorageFull
└── StarterGui/HUD/Hud.client.luau                # + StorageFull dans le fil de notifications
```

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Un seul nouveau service serveur, suivant exactement le patron existant
(`Name`, `Priority`, `Init`). Aucun nouveau contrôleur client : le stock réutilise la visée, le
ramassage et le déplacement à la souris déjà en place ; seules deux lignes de libellé et un son
sont ajoutés côté client. `BagService`, `InventoryService`, `CraftService` ne sont pas modifiés.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* Les deux décisions non triviales — réutiliser
un nœud de forêt figé comme objet rangé (research R1) et lui greffer des crochets fournis par le
stockage (research R2) — sont documentées par transparence plutôt que comme des écarts : elles
n'ajoutent aucune autorité au client et évitent deux intentions, une notification de démarrage de
saisie et une refonte de la visée, que l'alternative « modèles dédiés » aurait exigées.
