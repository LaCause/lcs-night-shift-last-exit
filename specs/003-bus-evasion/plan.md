# Implementation Plan: Bus et victoire par évasion

**Branch**: `003-bus-evasion` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-bus-evasion/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Ce plan referme la boucle constitutionnelle : jusqu'ici, la phase d'Évasion se terminait par une
défaite provisoire codée en dur dans `MatchService`, explicitement marquée comme telle
(`-- Provisoire : la fonctionnalité du bus redéfinira la fin de l'évasion.`). Cette fonctionnalité
la remplace par une vraie victoire.

**Un seul nouveau système serveur**, `BusService`, qui réutilise presque tout ce qui existe déjà :

- la ferraille est un **quatrième type de ressource**, récoltée par `ForestService` sans aucune
  modification de ce service (juste une entrée de plus dans ses tables de données) ;
- le dépôt au bus suit exactement le patron déjà établi par `RefuelGenerator` (vider un
  inventaire personnel dans un compteur partagé plafonné, surplus conservé) ;
- le départ réutilise `MatchService.endMatch("Victory", ...)`, donc l'écran de fin et le
  redémarrage automatique du socle technique, sans aucune modification ;
- le bus visible (décoratif depuis le premier incrément) gagne un état « réparé » affiché sur
  son modèle déjà construit, sans nouveau visuel de scène.

**Deux petites modifications, justifiées, à du code existant** (pas une extension purement
additive comme l'était `002-premier-increment-jouable`) :

1. `MatchService.advance()` perd sa branche provisoire « Évasion → défaite » (exactement le TODO
   qu'elle annonçait) ; `skipPhase()` traite désormais l'Évasion comme l'Attente (aucun effet, le
   départ n'est plus piloté par l'horloge de phase).
2. `InventoryService.depositEssence` est généralisée en `InventoryService.depositResource(player,
   resourceType, maxAmount?)` pour que `RefuelGenerator` et le nouveau `RepairBus` partagent la
   même logique plutôt que de la dupliquer ; `GeneratorService` adapte son unique appel.

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les nouveaux modules — identique aux
incréments précédents.

**Primary Dependencies**:

- Moteur Roblox uniquement (`CollectionService`, `TweenService` pour un éventuel fondu du voyant
  du bus) ; aucune bibliothèque externe.
- Même outillage figé par Rokit (Rojo 7.7.0, selene 0.31.0, StyLua 2.5.2), aucune version à
  changer.

**Storage**: N/A. Toujours aucune persistance ; tout l'état vit en mémoire serveur et se réplique
par attributs.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md), qui complète (sans le
  répéter) `specs/002-premier-increment-jouable/quickstart.md` ;
- commande de dev ajoutée (`Dev.RepairBus`) pour tester le départ sans dépendre d'une récolte
  réelle, dans le même esprit que `Dev.ForceOrderResult` ;
- `Dev.GiveResources` étendue à la ferraille pour tester la Story 1 sans exploration ;
- `selene` et `stylua --check`, `grep math.random` — étendus aux nouveaux fichiers.

**Target Platform**: Roblox, ordinateur en priorité, interface lisible sur téléphone — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- aucun gel perceptible à l'apparition des tas de ferraille (même génération par lot que les
  autres ressources) ni au calcul de présence au départ (une boucle sur au plus 6 sessions,
  déclenchée seulement par l'intention `DepartBus`, jamais par frame) ;
- écart d'affichage entre joueurs toujours < 1 s (attributs répliqués, comme le reste de l'état
  de partie).

**Constraints**:

- autorité serveur totale, inchangée : `BusService` est l'unique écrivain de `ReplicatedStorage.
  BusState` ; le client ne fait qu'exprimer des intentions (`RepairBus`, `DepartBus`) ;
- aucun `math.random` : la génération des tas de ferraille suit `MatchService.rng("forest")`,
  déjà utilisé par `ForestService` (aucun nouveau contexte de tirage nécessaire) ;
- toute valeur d'équilibrage dans `Settings.luau` (contracts/config.md) ;
- commande de dev toujours limitée à Studio (`devOnly`) ;
- aucun asset externe requis pour la géométrie de base : le nouveau visuel de ressource
  (« tas de ferraille ») est une primitive, comme les trois existants ; l'état « réparé » du bus
  réutilise le modèle déjà construit (masque une pièce existante, ajoute un voyant, comme
  `GeneratorLight`) — cohérent avec le principe VIII (remplaçant en primitives par défaut).

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur, 2 nouvelles
intentions, 2 nouveaux codes de refus, ~8 nouveaux fichiers/sections Luau modifiés, 2
modifications ciblées de fichiers existants (justifiées ci-dessus).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | la victoire DOIT exiger de survivre au nombre de nuits prévu, puis de réparer le bus de fuite | c'est littéralement l'objet de cette fonctionnalité : `BusService` + retrait du placeholder de `MatchService` | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout | le jeu dispose enfin d'une fin victorieuse réelle ; aucune régression sur la boucle jour/nuit existante | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | serveur décide, pipeline de validation, pas d'`InvokeClient`, l'UI reflète l'état répliqué | `RepairBus`/`DepartBus` passent par le canal `Intent` unique, mêmes 10 étapes ; `DepartBus` ajoute une vérification serveur supplémentaire (présence de l'équipe) dans son gestionnaire, comme `PrepareOrder` vérifie le stock | ✅ |
| IV. Rojo et services | répartition par service, `Workspace` reproductible par script, remotes déclarés en un seul endroit, configuration centralisée | `BusService` dans `ServerScriptService/Server/Services` ; aucun nouveau dossier `Workspace` (réutilise `BusSpot`, déjà construit par `WorldService`) ; intentions ajoutées au `Remotes.luau` existant ; réglages dans `Settings.luau` | ✅ |
| V. Procédural déterministe | `Random` par contexte dérivé de la seed, pas de `math.random`, pas de gel perceptible | les tas de ferraille suivent `MatchService.rng("forest")`, déjà utilisé (aucun nouveau contexte) | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | dépôt sur bus déjà réparé : accepté sans effet (comme le générateur plein) ; départ tenté trop tôt ou équipe dispersée : refus propre (`BusNotRepaired`, `TeamNotReady`) ; joueur sans personnage chargé compté comme absent, jamais une erreur | ✅ |
| VII. Coopération lisible | chaque joueur peut contribuer, retour immédiat et visible, interface à jour | récolte et dépôt ouverts à tout joueur ; progression du bus visible par toute l'équipe (état visuel + HUD) ; le départ exige explicitement que l'équipe se retrouve, ce qui rend la coopération finale visible plutôt qu'un simple clic solo | ✅ |
| VIII. Originalité et assets | primitives par défaut, remplaçant automatique, ton non graphique | tas de ferraille en primitive originale ; bus réparé = pièce de rouille masquée + voyant néon, même esprit que le générateur, aucun asset externe | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md) | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | coopération (rassemblement au départ) et rejouabilité (fin victorieuse réelle) — en-tête de la spec | ✅ |

**Résultat avant recherche** : PASS. Les deux modifications au code existant (§ Summary) ne
violent aucun principe — l'une résout un TODO explicitement laissé par le socle précédent,
l'autre est une généralisation de signature sans changement de comportement pour l'appelant
existant (`GeneratorService`) ; toutes deux sont documentées en recherche (research.md) et
listées ici pour rester vérifiables à la lecture, conformément au principe IV.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- `BusService` ne dépend que de systèmes qui existaient déjà avant lui, dans le même sens que le
  reste du projet (socle/gameplay établi → nouvelle fonctionnalité, jamais l'inverse) — voir
  [server-api.md](./contracts/server-api.md) ;
- `ReplicatedStorage.BusState` a un écrivain unique, comme tout le reste de l'état répliqué —
  voir [replicated-state.md](./contracts/replicated-state.md) ;
- la vérification supplémentaire de `DepartBus` (présence de l'équipe) reste entièrement dans le
  gestionnaire du système propriétaire, sans dupliquer ni contourner le pipeline générique —
  voir [network.md](./contracts/network.md).

## Project Structure

### Documentation (this feature)

```text
specs/003-bus-evasion/
├── plan.md                  # Ce fichier
├── research.md              # Phase 0 : décisions R1 à R8
├── data-model.md            # Phase 1 : entités de gameplay
├── quickstart.md            # Phase 1 : scénarios V1 à V3 + checklist DoD (complète 001 et 002)
├── contracts/
│   ├── network.md           # Nouvelles intentions, codes, notifications
│   ├── replicated-state.md  # Nouveau dossier répliqué, attribut joueur
│   ├── server-api.md        # Nouveau système, API, modifications ciblées documentées
│   └── config.md            # Nouveaux réglages (Forest.NodeCountScrap, domaine Bus)
├── checklists/
│   └── requirements.md      # Qualité de la spec
└── tasks.md                 # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Types.luau                          # + "Scrap" à ResourceType, + 2 codes de refus (BusNotRepaired, TeamNotReady)
│   ├── Strings.luau                        # + textes de la ferraille, du bus (récolter/déposer/partir), notifications
│   ├── Config/Settings.luau                # + Forest.NodeCountScrap ; nouveau domaine Bus (ScrapPerPlayer, InteractRange, DepartureRange) ; commentaire EscapeDuration mis à jour
│   ├── Net/Remotes.luau                    # + intentions RepairBus/DepartBus, + Dev.RepairBus, + notifications ScrapDeposited/BusRepaired, énumération Dev.GiveResources étendue
│   ├── Assets/Catalog.luau                 # + visuel du tas de ferraille (primitive) ; buildBus + voyant de réparation (nouvelle pièce)
│   └── Client/
│       └── GameplayStateClient.luau        # + lecture Inv_Scrap et ReplicatedStorage.BusState
├── ServerScriptService/Server/
│   └── Services/
│       ├── BusService.luau                 # nouveau
│       ├── ForestService.luau              # + "Scrap" dans ses tables de données (aucun changement de logique)
│       ├── GeneratorService.luau           # adapte son appel à InventoryService.depositResource (renommage)
│       ├── InventoryService.luau           # depositEssence → depositResource(player, resourceType, maxAmount?)
│       ├── MatchService.luau                # retire la branche provisoire Évasion→défaite de advance() ; skipPhase() traite l'Évasion comme l'Attente
│       ├── WorldService.luau                # + WorldService.visual(name): Model? (additif, même esprit que refPoint)
│       └── DevService.luau                  # + commande Dev.RepairBus ; Dev.GiveResources accepte "Scrap"
└── StarterGui/HUD/
    └── Hud.client.luau                     # + ligne ferraille (comme les 3 ressources existantes) ; + ligne progression du bus (conditionnelle, comme la commande)
```

Fichiers déjà créés hors plan (session précédente, retour son/visuel générique) et simplement
**étendus** par cette fonctionnalité, sans nouveau mécanisme :
`StarterPlayer/StarterPlayerScripts/Client/Controllers/SfxController.luau` (+ `ScrapDeposited`,
`BusRepaired`) et `FeedbackFxController.luau` (+ `BusRepaired`) — mêmes tables de données,
aucune nouvelle logique.

**Structure Decision** : toujours une place Rojo unique, aucune nouvelle correspondance dans
`default.project.json`. Aucun nouveau dossier `ReplicatedStorage.Assets` requis : la ferraille et
le voyant du bus restent des primitives intégrées à `Catalog.luau`, comme toutes les entrées sans
`ModelName` du catalogue actuel.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier pour cette fonctionnalité.* Les deux
modifications à du code existant (§ Summary) ne sont pas des écarts au Constitution Check : elles
sont documentées ici et en recherche précisément pour rester vérifiables, comme l'exige le
principe IV, mais ne contournent, n'affaiblissent ni ne dérogent à aucun principe.
