# Implementation Plan: Socle technique du projet

**Branch**: `001-socle-technique` (le travail est actuellement sur `main` ; créer la branche avant
l'implémentation) | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-socle-technique/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Le socle transforme le dépôt vide en projet Rojo aux outils figés (Rokit : Rojo 7.7.0, selene,
StyLua), synchronisable en direct (`rojo serve`) ou constructible en place complète
(`rojo build`). Au démarrage, le serveur :

- construit un monde de départ en primitives (restaurant, bus, point d'apparition, 11 points de
  référence nommés) ;
- fait tourner une horloge de partie autoritaire (Attente → Compte à rebours → 7 jours et
  7 nuits → Évasion → Fin → nouvelle partie), répliquée par attributs et horloge serveur
  partagée ;
- gère les sessions, la règle de défaite et le redémarrage automatique avec une nouvelle seed.

Toutes les actions des joueurs passent par un canal unique, `Intent`, validé par un pipeline
(schéma, cadence, phase, cible, distance), avec la sonnette du comptoir comme interaction de
référence. Le socle fournit aussi :

- une configuration centralisée et validée ;
- des tirages aléatoires dérivés de la seed et d'un contexte ;
- des visuels de secours en primitives ;
- un HUD lisible sur téléphone ;
- des commandes de développement réservées à Studio.

Les systèmes sont découverts automatiquement et isolés les uns des autres (voir
[research.md](./research.md)).

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les modules

**Primary Dependencies**:

- Moteur Roblox uniquement : aucune bibliothèque Luau externe, pas de Wally.
- Outillage de développement figé par Rokit 1.2.0 : Rojo 7.7.0, selene 0.31.0, StyLua 2.5.2.
- Recommandé : luau-lsp (VS Code), avec le sourcemap produit par Rojo.

**Storage**: N/A. Aucune persistance ; l'état vit en mémoire serveur et une partie est
répliquée par attributs.

**Testing**:

- validation manuelle dans Studio (Play solo ; Clients and Servers à 2 puis 6 clients) selon
  [quickstart.md](./quickstart.md) ;
- contrôles intégrés au panneau de dev : liste de requêtes invalides, tirages de contrôle,
  visuel de secours ;
- panne simulée au démarrage via `Debug.FailSystemAtInit` ;
- `selene` et `stylua --check`.

**Target Platform**: Roblox, avec l'ordinateur en priorité et une interface lisible sur
téléphone. Développement dans Roblox Studio sur macOS.

**Project Type**: jeu Roblox multijoueur (une place) synchronisé depuis le dépôt par Rojo

**Performance Goals**:

- aucun gel perceptible au démarrage, aux changements de phase ni à l'arrivée d'un joueur ;
- monde de départ (environ 80 pièces) construit avant le premier personnage ;
- aucun trafic réseau périodique pour l'horloge ;
- écart d'affichage entre joueurs inférieur à 1 s ;
- HUD rafraîchi au plus 10 fois par seconde.

**Constraints**:

- autorité serveur totale ; aucune RemoteFunction ni `InvokeClient` ;
- commandes de dev limitées à Studio ;
- aucun asset externe requis ;
- toute valeur d'équilibrage dans `Settings.luau` ;
- aucun `math.random` ;
- 1 à 6 joueurs.

**Scale/Scope**: 1 à 6 joueurs par serveur ; environ 30 fichiers Luau ; 3 écrans ; 1
interaction de référence ; 11 points de référence ; 23 réglages.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | ordre des phases, défaite si tous éliminés, victoire côté serveur, 1 à 6 joueurs | machine à états (data-model) ; défaite automatique ; victoire uniquement par `endMatch` serveur (branchée plus tard sur le bus) ; durées et nombre de nuits en configuration | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | incrément 0 sans boucle de gameplay, mais lançable et testable en solo et en multijoueur ; aucune fonctionnalité décorative | ⚠️ justifié (Complexity Tracking) |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide, pipeline de validation, pas d'`InvokeClient`, l'UI reflète l'état répliqué | `Intent` unique + pipeline en 10 étapes ; aucune RemoteFunction ; état en attributs à écrivain unique ; `Dev.*` refusés hors de Studio | ✅ |
| IV. Rojo et services | `default.project.json`, `rojo serve` sans manipulation, répartition par service, Workspace reproductible, remotes déclarés en un endroit, configuration centralisée | prototype `rojo build` validé ; dossiers = services ; monde construit par script ; `Remotes.luau` ; `Settings.luau` ; aucun autre service de rangement (ex. `ServerStorage` non utilisé) | ✅ |
| V. Procédural déterministe | `Random` par contexte, pas de `math.random` | `Rng.forContext(seed, …)` (FNV-1a) ; recherche `math.random` en V9 ; chunks hors périmètre | ✅ |
| VI. Robustesse | secours prévisibles, `pcall`, pas de propagation des échecs | `Loader` et `Signal` sous `xpcall` ; visuels de secours ; déconnexions gérées ; SpawnLocation étrangers neutralisés | ✅ |
| VII. Coopération lisible | HUD minimal, interactions rapides, lisible | phase, nuit, temps et équipe ; fil de notifications ; `ProximityPrompt` ; test téléphone (V7) | ✅ (commande, carburant et ressources arriveront avec leurs fonctionnalités) |
| VIII. Originalité et assets | primitives par défaut, remplaçants automatiques, ton non graphique | tout en primitives ; `Catalog` + `Visuals.PrimitivesOnly` ; textes FR originaux | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist finale de [quickstart.md](./quickstart.md) | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | coopération et rejouabilité (en-tête de la spec) | ✅ |

**Résultat avant recherche** : PASS, avec un écart justifié (principe II).

**Réévaluation après conception (Phase 1)** : PASS, sans nouvel écart. La conception ajoute
quatre garanties :

- l'état répliqué a un seul écrivain par élément ([replicated-state.md](./contracts/replicated-state.md)) ;
- le graphe de dépendances est acyclique ([server-api.md](./contracts/server-api.md)) ;
- les refus ont des codes et un journal limité ([network.md](./contracts/network.md)) ;
- aucun réglage n'est codé ailleurs que dans `Settings.luau` ([config.md](./contracts/config.md)).

## Project Structure

### Documentation (this feature)

```text
specs/001-socle-technique/
├── plan.md                  # Ce fichier
├── research.md              # Phase 0 : décisions techniques R1 à R17
├── data-model.md            # Phase 1 : entités, machine à états des phases
├── quickstart.md            # Phase 1 : scénarios de validation V1 à V10 + checklist DoD
├── contracts/
│   ├── network.md           # Remotes, pipeline, intentions, notifications, liste de contrôle
│   ├── replicated-state.md  # Attributs répliqués, monde de départ, sonnette
│   ├── server-api.md        # Contrat de système, API des services, dépendances
│   └── config.md            # Réglages, bornes, valeurs de test
├── checklists/
│   └── requirements.md      # Qualité de la spec
└── tasks.md                 # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
.
├── default.project.json          # Projet Rojo : mapping dépôt → services, CharacterAutoLoads=false
├── rokit.toml                    # rojo 7.7.0, selene 0.31.0, stylua 2.5.2
├── selene.toml                   # std = "roblox"
├── stylua.toml                   # syntax = "Luau"
├── .gitignore                    # build/, *.rbxl(x), *.lock, sourcemap.json, roblox.yml
├── README.md                     # installation, synchronisation, tests, checklist (FR-008)
└── src/
    ├── ReplicatedStorage/
    │   └── Shared/                              # → ReplicatedStorage.Shared
    │       ├── Types.luau                       # Phase, MatchResult, PlayerStatus, RejectCode, RefPointId
    │       ├── Strings.luau                     # textes FR centralisés (FR-037)
    │       ├── Config/
    │       │   ├── init.luau                    # validation + gel de la configuration
    │       │   └── Settings.luau                # LE fichier de réglages (contracts/config.md)
    │       ├── Net/
    │       │   ├── Remotes.luau                 # déclaration unique des remotes + schémas d'intentions
    │       │   └── Validate.luau                # validateurs de schéma
    │       ├── Util/
    │       │   ├── Loader.luau                  # découverte + Init/Start isolés (serveur et client)
    │       │   ├── Log.luau                     # journal préfixé, niveaux
    │       │   ├── Signal.luau                  # signal à écouteurs isolés
    │       │   └── Rng.luau                     # tirages dérivés (seed, contexte)
    │       ├── World/
    │       │   └── RefPoints.luau               # identifiants + recherche par tag (serveur et client)
    │       ├── Assets/
    │       │   └── Catalog.luau                 # visuels + remplaçants en primitives
    │       └── Client/
    │           ├── MatchStateClient.luau        # lecture de l'état répliqué, temps restant
    │           ├── NetClient.luau               # envoi d'intentions, écoute de Notify
    │           └── UiKit.luau                   # briques d'interface lisibles sur mobile
    ├── ServerScriptService/
    │   └── Server/                              # → ServerScriptService.Server
    │       ├── Main.server.luau                 # amorçage serveur (Loader sur Services/)
    │       ├── Services/
    │       │   ├── VisualService.luau           # FR-041
    │       │   ├── WorldService.luau            # FR-004, FR-007, FR-023
    │       │   ├── NetService.luau              # FR-030 à FR-033
    │       │   ├── NotifyService.luau           # FR-036
    │       │   ├── SessionService.luau          # FR-021 à FR-025
    │       │   ├── MatchService.luau            # FR-017 à FR-020, FR-026 à FR-029, FR-039
    │       │   ├── BellService.luau             # FR-034
    │       │   └── DevService.luau              # FR-042, FR-043
    │       └── World/
    │           └── Layout.luau                  # plan déclaratif du monde de départ
    ├── StarterPlayer/
    │   └── StarterPlayerScripts/
    │       └── Client/                          # → StarterPlayerScripts.Client
    │           ├── Main.client.luau             # amorçage client (Loader sur Controllers/)
    │           └── Controllers/
    │               ├── InteractionController.luau  # ProximityPrompt → intentions
    │               └── BellEffectController.luau   # effet local de la sonnette
    └── StarterGui/
        ├── HUD/                                 # ScreenGui (init.meta.json) + Hud.client.luau
        ├── EndScreen/                           # ScreenGui + EndScreen.client.luau
        └── DevPanel/                            # ScreenGui + DevPanel.client.luau (Studio uniquement)
```

**Structure Decision**: une place Rojo unique.

- Dossiers sources nommés comme les services Roblox, chacun contenant un sous-dossier mappé
  (`Shared`, `Server`, `Client`) pour ne jamais écraser ce que Studio ajoute (validé par un
  prototype `rojo build`, voir research R2).
- Logique d'autorité dans `ServerScriptService/Server/Services` ; modules partagés,
  configuration et déclaration réseau dans `ReplicatedStorage/Shared` ; logique locale dans
  `StarterPlayerScripts/Client` ; écrans dans `StarterGui`.
- Le contenu du `Workspace` est construit par `WorldService` (research R3), donc rien n'est
  mappé dans le Workspace hormis ses propriétés.
- Pas de dossier `tests/` : la validation suit la quickstart et les contrôles intégrés
  (research R15).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Principe II : incrément livré sans boucle de gameplay jouable de bout en bout | le socle (Rojo, horloge, autorité, configuration, outils) est le prérequis commun à tout le MVP ; le valider seul, en solo et en multijoueur, isole les bugs d'infrastructure avant d'ajouter le gameplay | fusionner socle et MVP donnerait un incrément trop gros pour être validé proprement et mélangerait les causes de bug. Le socle reste lançable, testable et sans erreur, et le MVP suivant rétablit la boucle jouable. |
