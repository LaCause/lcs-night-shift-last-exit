---

description: "Task list template for feature implementation"
---

# Tasks: Premier incrément jouable

**Input**: Documents de conception de `specs/002-premier-increment-jouable/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001-socle-technique`).

**Organisation** : les tâches sont groupées par user story (P1 à P5 de `spec.md`) pour permettre
une implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1 à US5)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle reste intact avant d'y greffer le gameplay. Aucune nouvelle
dépendance, aucun nouvel outil (même Rokit/Rojo que `001-socle-technique`).

- [X] T001 Depuis la branche `002-premier-increment-jouable`, vérifier que le socle compile
      toujours : `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans
      erreur (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée que toutes les user stories utilisent. Correspond aux
extensions additives décrites dans `research.md` (R1, R3, R10, R11) et `contracts/`.

**⚠️ CRITICAL** : aucune user story ne démarre avant la fin de cette phase.

- [X] T002 [P] Étendre `Types.luau` : type `ResourceType` (`"Essence" | "SuspectSteak" |
      "RoadBread"`), type `OrderStatus`, 5 nouveaux `RejectCode` (`NodeUnavailable`,
      `InventoryFull`, `MissingIngredients`, `NotPrepared`, `OrderClosed`), `RefPointId` +
      `"EnemySpawn"` (data-model.md, contracts/network.md) — dans
      `src/ReplicatedStorage/Shared/Types.luau`
- [X] T003 [P] Ajouter `"EnemySpawn"` à la liste `IDS` — dans
      `src/ReplicatedStorage/Shared/World/RefPoints.luau`
- [X] T004 [P] Ajouter le point de référence `EnemySpawn` (position en lisière de forêt,
      au-delà de `Forest.AreaMaxRadius`) à la table `refPoints` (research R10) — dans
      `src/ServerScriptService/Server/World/Layout.luau`
- [X] T005 [P] Étendre `Settings.luau` avec les domaines `Forest`, `Generator`, `Kitchen`,
      `Enemy`, `Ambiance` et l'entrée `Players.MaxHealth`, valeurs exactes de
      contracts/config.md — dans `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T006 [P] Étendre `Strings.luau` : noms des ressources (Essence, Steak suspect, Pain de
      route), textes du générateur (néon éteint/rallumé), de la commande (recette, échec,
      livraison), de l'ennemi (contact) et de la santé — dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T007 Ajouter à `NetService.registerIntent(name, definition)` un champ `resolve` optionnel
      (`(targetId: any) -> BasePart?`) ; l'utiliser aux étapes 7-9 du pipeline à la place de
      `RefPoints.find` quand il est fourni, sans changer le comportement des intentions
      existantes (research R3, contracts/network.md) — dans
      `src/ServerScriptService/Server/Services/NetService.luau`
- [X] T008 [P] Ajouter le signal `MatchService.MatchStarting: Signal<number, number>`
      (matchId, seed), déclenché en tout premier dans `startNewMatch`, avant
      `SessionService.resetAll()` (research R1) — dans
      `src/ServerScriptService/Server/Services/MatchService.luau`
- [X] T009 Déclarer dans `Remotes.Intents` les 5 nouvelles intentions (`HarvestResource`,
      `DepositResources`, `RefuelGenerator`, `PrepareOrder`, `DeliverOrder`, avec leurs schémas,
      phases et cibles) et ajouter à `Remotes.NotificationKinds` les 6 nouvelles notifications
      (`GeneratorEmpty`, `GeneratorRefueled`, `OrderStarted`, `OrderDelivered`, `OrderFailed`,
      `EnemyHit`), conformément à contracts/network.md — dans
      `src/ReplicatedStorage/Shared/Net/Remotes.luau`

**Checkpoint** : infrastructure partagée prête ; les user stories peuvent commencer.

---

## Phase 3 : User Story 1 - Récolter des ressources dans la forêt (Priority: P1) 🎯 MVP

**Goal** : une forêt basique générée depuis la seed de la partie, avec des points de ressource
récoltables et un stock partagé au restaurant.

**Independent Test** : en solo, sortir du restaurant le jour, récolter un point de chaque
ressource, vérifier l'inventaire du joueur, les déposer au restaurant et vérifier le stock
partagé (quickstart.md V1).

### Implementation for User Story 1

- [X] T010 [P] [US1] Ajouter au catalogue trois visuels de nœuds de ressource en primitives
      (bidon d'essence, glacière suspecte, distributeur routier), sans modèle externe requis
      (principe VIII) — dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau`
- [X] T011 [US1] Créer `ForestService` (Priority 42) : génère `Workspace.Forest` à chaque
      `MatchService.MatchStarting` avec `MatchService.rng("forest")` (nombre de nœuds par type
      et rayon depuis `Settings.Forest`, research R1/R2) ; chaque nœud a un `ProximityPrompt`
      (`Intent="HarvestResource"`, `Target=NodeId`) ; expose `findNode(id): BasePart?` et
      `isReady()` ; enregistre l'intention `HarvestResource` via
      `NetService.registerIntent("HarvestResource", { handler = ..., resolve = ForestService.findNode })`
      — refuse `NodeUnavailable`/`InventoryFull` selon contracts/network.md, sinon appelle
      `InventoryService.addPersonal` et rend le nœud indisponible jusqu'à
      `Forest.RespawnDelay` — dans
      `src/ServerScriptService/Server/Services/ForestService.luau` (dépend de T002 à T010)
- [X] T012 [US1] Créer `InventoryService` (Priority 45) : inventaire personnel par attributs
      `Player` (`Inv_Essence`, `Inv_SuspectSteak`, `Inv_RoadBread`, plafond
      `Forest.InventoryCapacity`), dossier `ReplicatedStorage.Stock` (stock partagé,
      `SuspectSteak`/`RoadBread`) ; expose `addPersonal`, `depositToStock`, `depositEssence`,
      `hasStock`, `consumeStock` ; enregistre l'intention `DepositResources` (verse
      `SuspectSteak`/`RoadBread` vers `Stock`) ; remet tout à zéro sur `MatchStarting` et vide
      l'inventaire d'un joueur éliminé (`SessionService.StatusChanged` → `"Eliminated"`,
      FR-005) — dans `src/ServerScriptService/Server/Services/InventoryService.luau` (dépend de
      T002 à T009)
- [X] T013 [US1] Étendre `DevService` : commande `Dev.GiveResources` (ajoute des ressources à
      l'inventaire de l'appelant) et commande `Dev.ShowGameplayState` (rapporte pour l'instant
      l'inventaire et le stock partagé) — dans
      `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T011, T012)
- [X] T014 [US1] Créer `GameplayStateClient` : lit `ReplicatedStorage.Stock` et les attributs
      `Inv_*` du joueur local, expose un `Signal` de changement et un accesseur `get()` — dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de T012)
- [X] T015 [US1] Étendre le HUD : afficher les ressources portées par le joueur (essence,
      steak suspect, pain de route) — dans `src/StarterGui/HUD/Hud.client.luau` (dépend de
      T014)

**Checkpoint** : la récolte et le dépôt fonctionnent de bout en bout, en solo comme à plusieurs
(US1 testable indépendamment).

---

## Phase 4 : User Story 2 - Alimenter le générateur (Priority: P2)

**Goal** : le générateur consomme du carburant en continu ; en déposer prolonge le néon et la
zone de sécurité.

**Independent Test** : en solo, observer le carburant baisser, déposer de l'essence récoltée et
vérifier qu'il remonte ; le laisser s'épuiser et constater l'extinction du néon et de la zone de
sécurité (quickstart.md V2).

### Implementation for User Story 2

- [X] T016 [US2] Créer `GeneratorService` (Priority 44) : dossier
      `ReplicatedStorage.GeneratorState` (`Fuel`, `Capacity`, `SafeZoneActive`) ; boucle de
      drain (`Generator.DrainPerSecond` par seconde tant que `MatchService.isActive()`) ; ajoute
      un `PointLight` en enfant du point de référence `SafeZoneCenter` (research R5), activé
      tant que `Fuel > 0` ; expose `deposit`, `hasFuel`, `isSafeZoneActive`, `isPositionSafe` ;
      enregistre l'intention `RefuelGenerator` (vide `Inv_Essence` du joueur via
      `InventoryService.depositEssence`, applique `Generator.FuelPerEssence`, plafonne à
      `Capacity`) ; diffuse `GeneratorEmpty`/`GeneratorRefueled` aux transitions ; remet `Fuel`
      à `Generator.InitialFuel` sur `MatchStarting` — dans
      `src/ServerScriptService/Server/Services/GeneratorService.luau` (dépend de T002 à T009,
      T012)
- [X] T017 [US2] Étendre `Dev.ShowGameplayState` : ajouter la ligne carburant/zone de sécurité
      — dans `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T013, T016)
- [X] T018 [US2] Étendre `GameplayStateClient` : lire `ReplicatedStorage.GeneratorState` — dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de T014, T016)
- [X] T019 [US2] Étendre le HUD : afficher le niveau de carburant et l'état du néon/zone de
      sécurité — dans `src/StarterGui/HUD/Hud.client.luau` (dépend de T015, T018)

**Checkpoint** : générateur, néon et zone de sécurité fonctionnels, en plus de US1.

---

## Phase 5 : User Story 3 - Préparer et livrer la commande de la nuit (Priority: P3)

**Goal** : une commande apparaît chaque nuit, se prépare au plan de travail depuis le stock
partagé, et se livre à la fenêtre du drive-thru avant l'échéance.

**Independent Test** : en profil de test, attendre la commande, récolter/déposer ses
ingrédients, la préparer, la livrer avant la fin de la nuit ; recommencer sans livrer pour
observer l'échec (quickstart.md V3).

### Implementation for User Story 3

- [X] T020 [P] [US3] Créer `Shared/Kitchen/Recipes.luau` : table statique figée, une entrée
      `SuspectBurger` (`Ingredients = { SuspectSteak = ..., RoadBread = ... }` selon
      `Kitchen.*` de contracts/config.md, `NameKey`) — dans
      `src/ReplicatedStorage/Shared/Kitchen/Recipes.luau`
- [X] T021 [US3] Créer `OrderService` (Priority 65) : dossier `ReplicatedStorage.OrderState`
      (`RecipeId`, `Status`) ; sur `MatchService.PhaseStarted("Night", ...)`, tire une recette
      avec `MatchService.rng("order")` et passe `Status` à `"Pending"`, diffuse
      `OrderStarted` ; enregistre `PrepareOrder` (refuse `OrderClosed`/`MissingIngredients`,
      sinon `InventoryService.consumeStock` puis `Status = "Prepared"`) et `DeliverOrder`
      (refuse `OrderClosed`/`NotPrepared`, sinon `Status = "Delivered"`, diffuse
      `OrderDelivered`) ; sur `MatchService.PhaseEnded` avec `previousPhase == "Night"`, si
      `Status` n'est pas `"Delivered"`, passe à `"Failed"`, diffuse `OrderFailed` et déclenche
      le signal `OrderService.OrderFailed(recipeId)` (research R9) — dans
      `src/ServerScriptService/Server/Services/OrderService.luau` (dépend de T002 à T009, T012,
      T020)
- [X] T022 [US3] Étendre `DevService` : commande `Dev.ForceOrderResult` (force `Status` à
      `Delivered` ou `Failed`) et ligne commande dans `Dev.ShowGameplayState` — dans
      `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T017, T021)
- [X] T023 [US3] Étendre `GameplayStateClient` : lire `ReplicatedStorage.OrderState` et
      résoudre le nom/les ingrédients affichés via `Shared/Kitchen/Recipes.luau` — dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de T018, T020,
      T021)
- [X] T024 [US3] Étendre le HUD : afficher la commande active, ses ingrédients requis et son
      échéance (temps restant de la nuit) — dans `src/StarterGui/HUD/Hud.client.luau` (dépend
      de T019, T023)

**Checkpoint** : la boucle commande complète (apparition → préparation → livraison ou échec)
fonctionne, en plus de US1 et US2.

---

## Phase 6 : User Story 4 - Survivre à l'ennemi nocturne (Priority: P4)

**Goal** : l'échec d'une commande fait apparaître un ennemi simple qui menace les joueurs hors
de la zone de sécurité, avec une santé serveur qui déclenche l'élimination à zéro.

**Independent Test** : en profil de test, provoquer l'échec d'une commande, observer
l'apparition de l'ennemi, se laisser approcher hors zone de sécurité et vérifier la perte de
santé puis l'élimination ; recommencer en restant protégé (quickstart.md V4).

### Implementation for User Story 4

- [X] T025 [P] [US4] Ajouter au catalogue un visuel d'ennemi en primitives, original et non
      graphique (principe VIII) — dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau`
      (dépend de T010, même fichier : à appliquer après T010)
- [X] T026 [US4] Créer `HealthService` (Priority 46) : attributs `Player.Health`/`MaxHealth`
      (research R4), initialisés à `Players.MaxHealth` à l'arrivée du joueur et remis à ce
      niveau sur `MatchStarting` ; expose `damage(player, amount)` (no-op si non vivant) et
      `get(player)` ; appelle `SessionService.setStatus(player, "Eliminated")` une seule fois
      quand `Health` atteint 0 — dans `src/ServerScriptService/Server/Services/HealthService.luau`
      (dépend de T002 à T009)
- [X] T027 [US4] Créer `EnemyService` (Priority 70) : dossier `Workspace.Enemies` ; s'abonne à
      `OrderService.OrderFailed` pour faire apparaître un ennemi (visuel T025) au point de
      référence `EnemySpawn` ; poursuit le joueur valide le plus proche hors de
      `GeneratorService.isPositionSafe` via `PathfindingService`, avec repli en ligne droite si
      le calcul échoue (research R8) ; inflige `Enemy.ContactDamage` via
      `HealthService.damage` au contact (`Enemy.ContactRange`, cadence
      `Enemy.ContactCooldown` par joueur) et envoie la notification ciblée `EnemyHit` ; se
      replie ou disparaît après `Enemy.GiveUpDelay` sans cible atteignable ou
      `Enemy.MaxLifetime` ; disparaît immédiatement sur `MatchService.PhaseEnded` ; expose
      `spawnAt(refPointId)` pour les tests — dans
      `src/ServerScriptService/Server/Services/EnemyService.luau` (dépend de T016, T021, T025,
      T026)
- [X] T028 [US4] Étendre `DevService` : commande `Dev.SpawnEnemy` (`EnemyService.spawnAt`) et
      ligne santé dans `Dev.ShowGameplayState` — dans
      `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T022, T026, T027)
- [X] T029 [US4] Étendre `GameplayStateClient` : lire `Health`/`MaxHealth` du joueur local —
      dans `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de T023,
      T026)
- [X] T030 [US4] Étendre le HUD : afficher la santé du joueur — dans
      `src/StarterGui/HUD/Hud.client.luau` (dépend de T024, T029)
- [X] T031 [P] [US4] Créer un contrôleur local qui réagit à la notification ciblée `EnemyHit`
      par un retour visible immédiat (flash d'écran) — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/EnemyEffectController.luau`
      (dépend de T027)

**Checkpoint** : la menace nocturne fonctionne, avec élimination réelle ; toutes les stories
P1 à P4 forment la boucle complète du premier incrément jouable.

---

## Phase 7 : User Story 5 - Ambiance jour/nuit visible (Priority: P5)

**Goal** : l'éclairage et le brouillard changent visiblement entre le Jour et la Nuit.

**Independent Test** : en profil de test, observer une transition Jour → Nuit puis Nuit → Jour
et confirmer le changement visuel sans lire l'interface (quickstart.md V5).

### Implementation for User Story 5

- [X] T032 [US5] Créer `AmbianceService` (Priority 52) : sur
      `MatchService.PhaseStarted`/`PhaseEnded`, tweene avec `TweenService` les propriétés
      `Lighting.Brightness`, `ClockTime`, `FogEnd` (et `FogColor`, constante) entre les valeurs
      Jour (`Ambiance.DayBrightness`, `Ambiance.DayFogEnd`) et Nuit
      (`Ambiance.NightBrightness`, `Ambiance.NightFogEnd`) sur `Ambiance.TransitionDuration`
      (research R6) — dans `src/ServerScriptService/Server/Services/AmbianceService.luau`
      (dépend de T002 à T009 uniquement)

**Checkpoint** : les cinq user stories du premier incrément jouable sont fonctionnelles,
indépendamment testables.

---

## Phase 8 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles finaux, une fois toutes les stories désirées terminées.

- [X] T033 [P] Contrôles statiques sur les nouveaux fichiers : `selene src` (0 erreur),
      `stylua --check src`, `grep -rn "math.random" src` et
      `grep -rn "InvokeClient\|RemoteFunction" src` sans résultat (quickstart.md V7) — racine
      du dépôt
- [ ] T034 Exécuter les scénarios V1 à V6 de `quickstart.md` : solo, puis 2 clients, puis 6
      clients sur une nuit complète — Studio (`Clients and Servers`)
- [X] T035 [P] Mettre à jour `README.md` : nouvelles commandes du panneau de dev
      (`Dev.GiveResources`, `Dev.ForceOrderResult`, `Dev.SpawnEnemy`,
      `Dev.ShowGameplayState`), nouveau dossier `Shared/Kitchen/` — dans `README.md`
- [ ] T036 Cocher la checklist de fin (Definition of Done) dans `quickstart.md` une fois tous
      les scénarios validés — dans `specs/002-premier-increment-jouable/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance, démarre immédiatement.
- **Foundational (Phase 2)** : dépend de Setup ; BLOQUE toutes les user stories.
- **User Stories (Phase 3-7)** : dépendent toutes de Foundational.
  - US1 (T010-T015), US2 (T016-T019), US3 (T020-T024), US4 (T025-T031) et US5 (T032) sont
    chacune indépendamment testables (quickstart.md), mais US2 réutilise `InventoryService`
    (US1), US3 réutilise `InventoryService` (US1), US4 réutilise `OrderService.OrderFailed`
    (US3) et `GeneratorService.isPositionSafe` (US2). L'ordre P1 → P2 → P3 → P4 → P5 est donc
    le chemin le plus direct ; US5 (Ambiance) est la seule totalement indépendante des autres
    et peut être menée en parallèle à tout moment après la Phase 2.
- **Polish (Phase 8)** : dépend de toutes les stories retenues pour ce jalon.

### Within Each User Story

- Service(s) serveur avant les extensions de `DevService` (outils de test).
- Services serveur avant `GameplayStateClient` (lecture de l'état répliqué qu'ils publient).
- `GameplayStateClient` avant l'extension du HUD qui l'utilise.

### Parallel Opportunities

- Toutes les tâches Foundational marquées [P] (T002, T003, T004, T005, T006, T008) peuvent
  s'exécuter en parallèle ; T007 et T009 touchent des fichiers partagés sensibles (pipeline
  réseau, déclaration des intentions) et s'enchaînent après les précédentes.
- T010 (US1) et T020 (US3) sont indépendantes de tout autre fichier de leur phase.
- T025 (US4) et T031 (US4) peuvent s'exécuter en parallèle du reste de leur phase (fichiers
  différents de `EnemyService.luau`).
- US5 (T032) peut être développée en parallèle de US2 à US4 par une autre personne, dès la
  Phase 2 terminée.

---

## Parallel Example: Foundational

```bash
# Une fois T001 terminée, lancer ensemble :
Task: "Étendre Types.luau (ResourceType, OrderStatus, RejectCode, RefPointId)"
Task: "Ajouter EnemySpawn à RefPoints.Ids"
Task: "Ajouter le point de référence EnemySpawn à Layout.luau"
Task: "Étendre Settings.luau (Forest, Generator, Kitchen, Enemy, Ambiance, Players.MaxHealth)"
Task: "Étendre Strings.luau"
Task: "Ajouter le signal MatchService.MatchStarting"
# Puis, une fois Types et Settings prêts :
Task: "Étendre NetService.registerIntent (résolveur de cible optionnel)"
Task: "Déclarer les 5 intentions et 6 notifications dans Remotes.luau"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Terminer la Phase 1 : Setup.
2. Terminer la Phase 2 : Foundational (CRITIQUE — bloque toutes les stories).
3. Terminer la Phase 3 : User Story 1 (récolte et dépôt).
4. **STOP et VALIDER** : quickstart.md V1, en solo puis à 2 joueurs.
5. Démontrer si prêt : la forêt est explorable et le stock partagé se remplit.

### Incremental Delivery

1. Setup + Foundational → base commune prête.
2. + US1 (récolte) → tester seul → premier incrément partiel démontrable.
3. + US2 (générateur) → tester seul → le carburant a un enjeu.
4. + US3 (commande) → tester seul → la nuit a un objectif concret.
5. + US4 (ennemi/santé) → tester seul → la boucle canonique du principe I est complète.
6. + US5 (ambiance) → tester seul → raffinement visuel, sans rien risquer sur le reste.
7. Chaque story ajoute de la valeur sans casser les précédentes (Independent Test de chacune).

### Parallel Team Strategy

Avec plusieurs personnes :

1. L'équipe termine Setup + Foundational ensemble (bloquant).
2. Une fois Foundational fait :
   - Personne A : US1 puis US3 (dépend d'InventoryService qu'elle vient de livrer).
   - Personne B : US2 (dépend d'InventoryService de la Personne A pour `depositEssence`, donc
     démarre après T012).
   - Personne C : US5 (Ambiance), totalement indépendante, démarrable immédiatement après la
     Phase 2.
   - US4 démarre dès que US2 et US3 sont livrées (dépend de `isPositionSafe` et
     `OrderFailed`).
3. Polish (Phase 8) une fois les stories retenues pour ce jalon terminées.

---

## Notes

- [P] = fichiers différents, sans dépendance non résolue.
- Chaque story est indépendamment complète et testable via `quickstart.md`.
- Pas de tests automatisés dans ce projet (validation manuelle en Studio, comme
  `001-socle-technique`) ; ne pas en ajouter sans qu'ils soient demandés.
- Committer après chaque tâche ou groupe logique.
- S'arrêter à chaque checkpoint pour valider la story indépendamment avant de passer à la
  suivante.
- Éviter : coder en dur une valeur qui appartient à `Settings.luau`, un `math.random`, une
  dépendance d'un système du socle vers un système de gameplay (le sens va toujours du socle
  vers le gameplay, jamais l'inverse — research R1/R9).
