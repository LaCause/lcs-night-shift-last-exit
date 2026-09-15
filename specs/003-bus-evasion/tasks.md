---

description: "Task list template for feature implementation"
---

# Tasks: Bus et victoire par évasion

**Input**: Documents de conception de `specs/003-bus-evasion/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001-socle-technique` et
`002-premier-increment-jouable`).

**Organisation** : les tâches sont groupées par user story (P1/P2 de `spec.md`) pour permettre
une implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1, US2)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle (001 + 002) reste intact avant d'y greffer cette
fonctionnalité. Aucune nouvelle dépendance, aucun nouvel outil.

- [X] T001 Depuis la branche `003-bus-evasion`, vérifier que le projet compile toujours :
      `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans erreur
      (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée que les deux user stories utilisent (types, réglages,
textes, remotes, généralisation du dépôt d'inventaire). Correspond à research.md (R4, R6 exclu
— voir US2) et contracts/.

**⚠️ CRITICAL** : aucune user story ne démarre avant la fin de cette phase.

- [X] T002 [P] Étendre `Types.luau` : `ResourceType` + `"Scrap"`, `RejectCode` + `BusNotRepaired`
      et `TeamNotReady` (data-model.md, contracts/network.md) — dans
      `src/ReplicatedStorage/Shared/Types.luau`
- [X] T003 [P] Étendre `Settings.luau` : `Forest.NodeCountScrap` (défaut 8, 1–40) ; nouveau
      domaine `Bus` (`ScrapPerPlayer` défaut 6 1–50, `InteractRange` défaut 8 4–20,
      `DepartureRange` défaut 15 5–40) ; corriger le commentaire de `Match.EscapeDuration` (ne
      mentionne plus une définition future par le bus) — valeurs exactes de
      contracts/config.md — dans `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T004 [P] Étendre `Strings.luau` : nom de la ferraille (ressource), textes du bus (déposer,
      réparé, départ, refus manque de coéquipiers) — dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T005 [P] Déclarer dans `Remotes.Intents` les intentions `RepairBus` et `DepartBus`
      (payload `{ target: string(≤64) }`, phases et cibles de contracts/network.md), la
      commande `Dev.RepairBus` (`devOnly`, sans payload), étendre l'énumération de
      `Dev.GiveResources` avec `"Scrap"`, et ajouter à `Remotes.NotificationKinds`
      `ScrapDeposited` (send) et `BusRepaired` (broadcast) — dans
      `src/ReplicatedStorage/Shared/Net/Remotes.luau`
- [X] T006 [P] Généraliser `InventoryService.depositEssence(player, maxAmount?)` en
      `InventoryService.depositResource(player: Player, resourceType: ResourceType, maxAmount:
      number?): number`, comportement identique pour `resourceType = "Essence"` (research R4)
      — dans `src/ServerScriptService/Server/Services/InventoryService.luau` (dépend de T002)
- [X] T007 Adapter l'unique appel de `GeneratorService` à
      `InventoryService.depositResource(player, "Essence", maxAmount)` (renommage, aucun
      changement de comportement) — dans
      `src/ServerScriptService/Server/Services/GeneratorService.luau` (dépend de T006)

**Checkpoint** : infrastructure partagée prête ; les user stories peuvent commencer.

---

## Phase 3 : User Story 1 - Réparer le bus avec de la ferraille (Priority: P1) 🎯 MVP

**Goal** : des tas de ferraille apparaissent en forêt ; un joueur peut en récolter et la
déposer au bus pour faire progresser une réparation partagée par toute l'équipe, visible et
terminée par un changement d'état visuel.

**Independent Test** : en solo, récolter plusieurs tas de ferraille, les déposer au bus, et
vérifier que sa progression de réparation augmente jusqu'à devenir complète (voyant vert,
rouille masquée), sans avoir besoin de la fonctionnalité de départ (Story 2) — quickstart.md V1.

### Implementation for User Story 1

- [X] T008 [P] [US1] Ajouter au catalogue le visuel du tas de ferraille en primitive
      (`BuildFallback`, sans modèle externe requis, principe VIII) et étendre `buildBus` pour
      ajouter la pièce `RepairLight` (rouge par défaut, `COLORS.Warning`) sur le modèle déjà
      construit — dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau` (dépend de T002)
- [X] T009 [US1] Ajouter `WorldService.visual(name: string): Model?`, qui retrouve un modèle
      déjà construit depuis `Layout.Visuals` sous `Workspace.World` par son nom (même esprit
      que `refPoint(id)`, additif, aucun appelant existant cassé) — dans
      `src/ServerScriptService/Server/Services/WorldService.luau`
- [X] T010 [US1] Ajouter `"Scrap"` aux tables `RESOURCE_TYPES`/`VISUAL_FOR`/
      `NODE_COUNT_SETTING` (aucun changement de logique, research R3) — dans
      `src/ServerScriptService/Server/Services/ForestService.luau` (dépend de T002, T003, T008)
- [X] T011 [US1] Créer `BusService` (Priority 66) : à `MatchService.MatchStarting`, crée/réinitialise
      `ReplicatedStorage.BusState` (`Deposited = 0`, `Required = Bus.ScrapPerPlayer ×
      SessionService.countPresent()`, `Repaired = false`, non figé) ; recalcule `Required` sur
      les évènements de présence de `SessionService` tant que non figé ; fige `Required` à
      `MatchService.PhaseStarted("Escape", ...)` (research R1) ; enregistre l'intention
      `RepairBus` via `NetService.registerIntent` avec `resolve = RefPoints.find` sur
      `"BusSpot"` — refuse `TargetMissing` si la cible ne correspond pas ; si déjà réparé,
      accepté sans effet ; sinon dépose jusqu'au manque via
      `InventoryService.depositResource(player, "Scrap", Required - Deposited)`, notifie
      `ScrapDeposited` si au moins une unité déposée, et si `Deposited` atteint `Required`,
      bascule `Repaired = true`, diffuse `BusRepaired`, et via `WorldService.visual("Bus")`
      masque `RustPatch` (`Transparency = 1`) et passe `RepairLight.Color` au vert ; expose
      `isRepaired(): boolean` et `getProgress(): (number, number)` — dans
      `src/ServerScriptService/Server/Services/BusService.luau` (dépend de T002, T003, T005,
      T006, T008, T009)
- [X] T012 [US1] Étendre `GameplayStateClient` : lire l'attribut `Inv_Scrap` du joueur local et
      le dossier `ReplicatedStorage.BusState` (`Deposited`/`Required`/`Repaired`), inclus dans
      le même signal `Changed` — dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de T011)
- [X] T013 [US1] Étendre le HUD : ajouter la ligne ferraille portée (comme les 3 ressources
      existantes) et une ligne de progression de réparation du bus (`Deposited`/`Required`,
      visible dès le premier dépôt ou dès la phase d'Évasion, effet « punch » sur changement
      comme les autres valeurs) — dans `src/StarterGui/HUD/Hud.client.luau` (dépend de T012)
- [X] T014 [P] [US1] Étendre `SfxController` : ajouter les entrées `ScrapDeposited` et
      `BusRepaired` à la table `SFX` (même patron que les entrées existantes) — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SfxController.luau` (dépend
      de T005, T011)
- [X] T015 [P] [US1] Étendre `FeedbackFxController` : ajouter l'entrée `BusRepaired` à la table
      `FLASHES` — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/FeedbackFxController.luau`
      (dépend de T005, T011)

**Checkpoint** : la récolte, le dépôt et la réparation complète du bus fonctionnent de bout en
bout, en solo comme à plusieurs (US1 testable indépendamment).

---

## Phase 4 : User Story 2 - Partir avec le bus réparé (Priority: P2)

**Goal** : une fois le bus entièrement réparé et la phase d'Évasion en cours, l'équipe
rassemblée près du bus peut déclencher le départ et remporter la partie.

**Independent Test** : forcer un bus déjà réparé (`Dev.RepairBus`) pendant la phase d'Évasion
(`Dev.NextPhase` répété), interagir pour partir avec toute l'équipe rassemblée et vérifier la
victoire, puis retenter avec un coéquipier volontairement éloigné et vérifier le refus
`TeamNotReady` — quickstart.md V2/V3.

### Implementation for User Story 2

- [X] T016 [US2] Retirer de `MatchService.advance()` la branche provisoire
      `elseif phase == "Escape" then MatchService.endMatch("Defeat", ...) end` (résout le TODO
      explicite du socle) ; adapter `skipPhase()` pour traiter l'Évasion comme l'Attente
      (`return false`, aucun effet — seul un départ réel ou `Dev.EndMatch` termine la phase,
      research R6) — dans `src/ServerScriptService/Server/Services/MatchService.luau`
- [X] T017 [US2] Étendre `BusService` : enregistrer l'intention `DepartBus` via
      `NetService.registerIntent` avec `resolve = RefPoints.find` sur `"BusSpot"` (portée
      `Bus.DepartureRange`) — refuse `TargetMissing` si la cible ne correspond pas, refuse
      `BusNotRepaired` si `Repaired` est faux, sinon vérifie que chaque `Session` avec
      `Status == "Alive"` a un personnage chargé à une distance de `BusSpot` ≤
      `Bus.DepartureRange + Net.DistanceTolerance` (un joueur en vie sans personnage chargé
      compte comme hors de portée, research R5) ; au premier manquant, refuse `TeamNotReady` ;
      sinon appelle `MatchService.endMatch("Victory", "le bus est parti")` — dans
      `src/ServerScriptService/Server/Services/BusService.luau` (dépend de T011, T016)
- [X] T018 [US2] Étendre `DevService` : ajouter la commande `Dev.RepairBus` (fige `Required`
      s'il ne l'était pas encore, force `Deposited = Required`, bascule `Repaired` via
      `BusService`, met à jour le visuel du bus) et ajouter la ligne progression du bus
      (`Deposited`/`Required`/`Repaired`) à `Dev.ShowGameplayState` — dans
      `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T017)

**Checkpoint** : la boucle complète (récolte → réparation → rassemblement → départ → victoire)
est jouable de bout en bout, pour la première fois depuis le début du projet.

---

## Phase 5 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles statiques et validation manuelle finale, communs aux deux stories.

- [X] T019 [P] `selene src` et `stylua --check src` sur tous les fichiers nouveaux ou modifiés
      par cette fonctionnalité : aucun écart
- [X] T020 [P] `grep -rn "math.random" src` : toujours aucun résultat, y compris dans
      `ForestService`, `MatchService`, `InventoryService`, `BusService`
- [X] T021 Exécuter les scénarios V1 à V4 de `quickstart.md` en Studio (solo puis 2 clients
      locaux) et cocher la « Checklist de fin »

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — BLOQUE les deux user stories.
- **User Story 1 (Phase 3)** : dépend de Foundational — aucune dépendance sur US2.
- **User Story 2 (Phase 4)** : dépend de Foundational **et** de `BusService` créé en US1 (T011,
  T017 l'étend) et de `MatchService` (T016) — ne peut pas être développée avant US1, mais reste
  une story séparée, testable indépendamment une fois US1 en place (via `Dev.RepairBus`).
- **Polish (Phase 5)** : dépend des deux user stories.

### Parallel Opportunities

- T002 à T005 (Types, Settings, Strings, Remotes) : fichiers différents, aucune dépendance
  mutuelle — en parallèle.
- T006 (InventoryService) peut suivre T002 en parallèle des autres tâches Foundational ; T007
  (GeneratorService) doit attendre T006.
- T008 (Catalog) et T009 (WorldService) : fichiers différents, en parallèle une fois T002 fait.
- T014 et T015 (SfxController, FeedbackFxController) : fichiers différents, en parallèle une
  fois T005 et T011 faits.
- T019 et T020 (contrôles statiques) : indépendants, en parallèle.

---

## Parallel Example: Phase 2 (Foundational)

```bash
Task: "Étendre Types.luau (ResourceType + Scrap, 2 RejectCode)"
Task: "Étendre Settings.luau (Forest.NodeCountScrap, domaine Bus)"
Task: "Étendre Strings.luau (textes ferraille/bus)"
Task: "Étendre Remotes.luau (RepairBus/DepartBus, Dev.RepairBus, notifications)"
```

---

## Implementation Strategy

### MVP First (User Story 1 seule)

1. Compléter Phase 1 : Setup
2. Compléter Phase 2 : Foundational (CRITIQUE — bloque les deux stories)
3. Compléter Phase 3 : User Story 1
4. **STOP et VALIDER** : quickstart.md V1, en solo
5. Livrable : réparation du bus jouable et visible, même sans départ possible

### Incremental Delivery

1. Setup + Foundational → base prête
2. + User Story 1 → validation indépendante (V1) → réparation démontrable
3. + User Story 2 → validation indépendante (V2/V3) → boucle complète, victoire incluse
4. Chaque story ajoute de la valeur sans casser la précédente

## Notes

- [P] tasks = fichiers différents, aucune dépendance
- [Story] label = traçabilité vers la user story de `spec.md`
- Contrairement à `002-premier-increment-jouable`, US2 dépend structurellement de `BusService`
  créé en US1 (le départ est une seconde intention sur le même système que la réparation) —
  c'est la même relation que `GeneratorService`/`OrderService` entre eux en 002 : deux stories
  séparées et testables indépendamment, mais pas deux systèmes indépendants.
- Éviter : tâches vagues, conflits sur un même fichier en parallèle, dépendances qui casseraient
  l'indépendance de test de chaque story.
