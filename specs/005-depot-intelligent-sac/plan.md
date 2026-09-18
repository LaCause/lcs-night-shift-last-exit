# Implementation Plan: Vidage progressif du sac et dépôt automatique aux postes

**Branch**: `005-depot-intelligent-sac` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-depot-intelligent-sac/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Cette fonctionnalité révise le vidage du sac livré par `004-sac-collecte` (jusqu'ici « tout ou
rien ») en deux gestes distincts — une pression brève retire le dernier objet ramassé, un maintien
vide tout le sac — et donne un sens contextuel au fait de lâcher un objet près d'un poste qui sait
déjà en faire quelque chose (le générateur pour l'essence, le comptoir pour la nourriture, le bus
pour la ferraille).

**Le changement de donnée le plus structurant** : le sac ne peut plus être décrit uniquement par
des compteurs par type (`Inv_Essence`, etc.) — « le dernier objet mis dans le sac » exige de savoir
dans quel ordre ils sont arrivés. Cet ordre est ajouté comme un **état serveur pur**
(`InventoryService`, jamais répliqué : un `Attribute` Roblox ne peut pas porter un tableau), à côté
des compteurs existants qui restent inchangés et continuent seuls à être lus par tout le reste du
jeu (research R1).

**Un nouveau service, `StationDepositService`** (priorité 49), porte la seule connaissance neuve
de cette fonctionnalité : quel type d'objet correspond à quel poste. Il ne crée rien, ne
s'abonne à rien, n'enregistre aucune intention — une table statique et une fonction,
`tryDeposit(player, resourceType, position)`, appelée uniquement par `BagService`. Le dépôt
automatique réutilise **exactement** le même contrat « prélever puis appliquer » que chaque
interaction manuelle utilise déjà (`GeneratorService.deposit`, `BusService.deposit` — extrait
pour l'occasion —, `InventoryService.depositResourceToStock` — nouvelle jumelle unitaire de
`depositToStock`), plutôt que d'inventer un second chemin : FR-009 (même retour qu'un dépôt
manuel) est ainsi garanti par construction, pas par discipline entre deux copies.

**Une seule intention nouvelle**, `DropOneItem` (payload vide, comme `DropBag`), pour la pression
brève. `DropBag` elle-même n'est **pas** remplacée : sa déclaration réseau ne change pas, seul son
gestionnaire est révisé pour parcourir l'ordre d'arrivée et tenter un dépôt automatique par unité
avant de poser au sol. Conformément à la clarification du 2026-09-18 (Q1), un maintien reste **une
seule action groupée côté réseau** — jamais un flux d'intentions par objet — dans le droit fil du
budget de cadence déjà éprouvé par 004 (research R4).

**Un écart assumé et documenté** (clarification Q2) : la portée du dépôt automatique se mesure
depuis la position d'arrivée de **l'objet**, pas depuis le joueur — à l'inverse de toutes les
autres interactions du jeu, qui mesurent systématiquement depuis le joueur
(`NetService.rangeFor`). L'auteur a maintenu ce choix après en avoir vu la conséquence : deux
objets identiques d'un même vidage peuvent avoir des issues différentes selon leur position exacte
d'atterrissage (research R5, documenté comme effet accepté dans `spec.md`).

**Un bug trouvé, pas introduit, corrigé au passage** : `BagService.empty` (livré par 004, pas
encore mergé) écrit aujourd'hui les compteurs `Inv_*` directement, en contournant
`InventoryService` — un contournement inoffensif tant qu'aucune seconde donnée n'en dépendait.
L'ordre d'arrivée introduit ici en dépend ; `BagService.empty` est donc corrigé pour passer par une
nouvelle fonction `InventoryService.clearCarried` (research R6).

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les nouveaux modules — inchangé.

**Primary Dependencies**:

- Moteur Roblox uniquement : `UserInputService` (mesure de durée d'appui côté client, sur la
  touche déjà utilisée en 004), aucune bibliothèque externe.
- Même outillage figé par Rokit (Rojo, selene, StyLua) qu'en 004 — aucune version à changer.

**Storage**: N/A. L'ordre d'arrivée est un état serveur en mémoire (`InventoryService`), comme
`CarryService.carries` ou `ForestService.nodes` ; aucune persistance entre parties.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md) (scénarios W1 à W8), qui
  complète sans les répéter les guides de `002`, `003` et `004` ;
- aucune nouvelle commande de développement : `Dev.GiveResources` (existant depuis 002) suffit
  déjà à construire un ordre d'arrivée connu, puisqu'il passe par le même point d'entrée instrumenté
  (`InventoryService.addPersonal`, research R9) ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers nouveaux ou modifiés.

**Target Platform**: Roblox, ordinateur en priorité — inchangé depuis 004 (clavier/souris ;
manette et tactile hors périmètre).

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- un maintien de la touche de vidage reste **une seule intention réseau**, quel que soit le
  nombre d'objets traités (research R4) — le budget de cadence (`Net.IntentBurst = 10`, recharge
  5/s) n'est pas davantage sollicité qu'aujourd'hui ;
- le calcul de portée du dépôt automatique est une comparaison de distances en mémoire (pas de
  `Raycast`, pas d'E/S) : coût négligeable, au plus 5 comparaisons par vidage complet (contenance
  maximale du sac).

**Constraints**:

- autorité serveur : la distinction pression/maintien n'est qu'un choix client sur QUELLE
  intention envoyer ; le serveur revalide entièrement les deux (sac équipé, sac non vide,
  personnage vivant) et décide seul quel poste absorbe quoi ;
- aucun `math.random` : la position de chaque objet lâché reste le calcul déterministe déjà
  utilisé en 004 (angle dérivé du rang de l'objet) ;
- toute valeur d'équilibrage dans `Settings.luau` (`contracts/config.md`) — une seule valeur
  nouvelle, `Bag.DropHoldThreshold` ;
- commandes de dev toujours limitées à Studio (`devOnly`) — aucune nouvelle commande cette fois
  (research R9) ;
- le dépôt automatique fonctionne identiquement que les assets des postes soient présents ou
  remplacés par leurs primitives : il n'ajoute aucune dépendance à un visuel, seulement à la
  position d'un point de référence (`WorldService.refPoint`), déjà robuste depuis 002/003.

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur
(`StationDepositService`), 1 nouvelle intention (`DropOneItem`), 1 intention révisée (`DropBag`),
0 nouveau code de refus, 1 notification au sens révisé (`BagDropped`), 1 nouveau réglage ; environ
10 fichiers touchés dont 1 créé — nettement plus modeste que 004 (~15 fichiers dont 3 créés).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer le jour → récupérer des ressources → … | le dépôt automatique raccourcit une étape déjà existante (déposer aux postes) sans en ajouter ni en retirer aucune ; aucune phase, aucun objectif, aucune condition de victoire n'est touchée | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | US1 (dépôt automatique) est livrable seule, le vidage restant « tout ou rien » (comportement 004) ; US2 (pression/maintien) s'ajoute sans casser US1 | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; pipeline de validation ; l'UI reflète l'état répliqué | pipeline `NetService` inchangé ; le choix client (pression/maintien) ne fait que sélectionner QUELLE intention envoyer, entièrement revalidée par le serveur ; le poste, la capacité et la position d'atterrissage sont calculés et décidés exclusivement côté serveur (`StationDepositService`, `BagService`). Aucune réserve à documenter cette fois — contrairement à 004, aucune propriété réseau n'est déléguée au client | ✅ |
| IV. Rojo et services | répartition par service, remotes en un seul endroit, configuration centralisée, aucune manipulation manuelle dans Studio | 1 service neuf dans `Server/Services` (`StationDepositService`), aucune dépendance circulaire (research R2) ; intention ajoutée à `Remotes.luau` existant ; réglage `DropHoldThreshold` dans `Settings.luau` | ✅ |
| V. Procédural déterministe | `Random` par contexte, pas de `math.random`, pas de gel | aucun tirage introduit ; position des objets lâchés toujours calculée par la même formule déterministe qu'en 004 (angle dérivé du rang, pas de hasard) | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | poste plein, incompatible ou hors de portée → objet posé au sol, jamais perdu (FR-007, FR-008) ; rien n'est retiré du sac tant que le dépôt n'a pas réellement réussi (research R3) ; déconnexion après le seuil de maintien → le vidage, déjà résolu en un seul appel serveur, ne peut jamais rester à moitié fait (FR-002, Edge Cases) | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | un dépôt automatique produit **exactement** la même confirmation qu'un dépôt manuel (research R7, R8) ; la ligne « Sac » du HUD se met à jour immédiatement, inchangée depuis 004 | ✅ |
| VIII. Originalité, ton et assets | primitives par défaut, remplaçant automatique, aucune copie d'un jeu existant | aucun nouvel asset ; le dépôt automatique s'appuie sur des points de référence déjà robustes aux remplaçants en primitives (002/003) | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md) | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | coopération (une contenance partagée et des dépôts automatiques encouragent la répartition des rôles de portage) — cohérent avec l'axe déjà revendiqué par `004-sac-collecte` | ✅ |

**Aucune réserve à documenter** : à la différence de `004-sac-collecte` (propriété réseau
temporaire pendant un déplacement), cette fonctionnalité ne délègue au client aucune décision
faisant autorité — la distinction pression/maintien ne choisit qu'une intention à envoyer parmi
deux, toutes deux entièrement revalidées.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- l'ordre d'arrivée reste une donnée serveur pure, jamais répliquée ni lue par le client (R1,
  [data-model.md](./data-model.md)) ;
- chaque poste garde un écrivain unique de son propre état (`GeneratorService` pour le carburant,
  `BusService` pour la progression, `InventoryService` pour le stock) ; `StationDepositService` ne
  fait qu'orchestrer des appels vers eux, il ne duplique aucune donnée (R2, R3,
  [server-api.md](./contracts/server-api.md)) ;
- le sens des dépendances reste établi → nouveauté : `StationDepositService` requiert
  `InventoryService`/`GeneratorService`/`BusService`/`WorldService`, aucun d'eux ne le requiert en
  retour ([contracts/server-api.md](./contracts/server-api.md)).

## Project Structure

### Documentation (this feature)

```text
specs/005-depot-intelligent-sac/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R10
├── data-model.md             # Phase 1 : ordre d'arrivée, correspondance objet-poste
├── quickstart.md             # Phase 1 : scénarios W1 à W8 + checklist DoD
├── contracts/
│   ├── network.md            # Intention DropOneItem, DropBag révisée, BagDropped révisée
│   ├── server-api.md         # Nouvelles/modifiées : InventoryService, StationDepositService, BagService, BusService, GeneratorService
│   └── config.md             # Nouveau réglage Bag.DropHoldThreshold
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Net/Remotes.luau                    # + intention DropOneItem (payload vide, comme DropBag)
│   └── Config/Settings.luau                # + Bag.DropHoldThreshold
├── ServerScriptService/Server/Services/
│   ├── StationDepositService.luau          # nouveau (49) — table objet↔poste, tryDeposit
│   ├── InventoryService.luau                # + ordre d'arrivée (order), depositResourceToStock, clearCarried, orderOf, mostRecent ; nettoyage PlayerLeft
│   ├── BagService.luau                      # drop() révisé (ordre + dépôt auto) ; + dropOne() ; empty() corrigé (R6) ; + gestionnaire DropOneItem
│   ├── GeneratorService.luau                # + fuelRoom() (lecture seule)
│   ├── BusService.luau                      # + deposit() extrait de RepairBus (R7)
│   └── DevService.luau                      # Dev.ShowGameplayState affiche l'ordre courant (contrôle, aucune commande nouvelle)
└── StarterPlayer/StarterPlayerScripts/Client/Controllers/
    └── PointerController.luau               # touche G : minuteur pression/maintien, envoie DropOneItem ou DropBag
```

Aucun fichier `StarterGui` ni `Strings.luau` ne change de contrat de données — seules leurs valeurs
d'affichage évoluent (libellé de l'indice « [G] », texte de `BagDropped`), portées par les tâches
d'implémentation plutôt que par ce plan.

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Le nouveau service suit exactement le même patron que les services
existants (`Name`, `Priority`, `Init`) et rejoint `ServerScriptService/Server/Services/` sans
aucune manipulation manuelle dans Studio (principe IV).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* Le bug trouvé dans `BagService.empty`
(research R6) et l'extraction de `BusService.deposit` (research R7) sont des corrections et des
refactorisations documentées pour rester vérifiables à la lecture, comme l'exige le principe IV —
elles ne contournent, n'affaiblissent ni ne dérogent à aucun principe.
