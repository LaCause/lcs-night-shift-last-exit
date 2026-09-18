---

description: "Task list template for feature implementation"
---

# Tasks: Sac de collecte et manipulation des objets à la souris

**Input**: Documents de conception de `specs/004-sac-collecte/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001`, `002` et `003`).

**Organisation** : les tâches sont groupées par user story (P1/P2/P3 de `spec.md`) pour permettre
une implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1, US2, US3)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle (001 + 002 + 003) reste intact avant d'y greffer cette
fonctionnalité. Aucune nouvelle dépendance, aucun nouvel outil.

- [X] T001 Vérifier que le projet compile toujours :
      `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans erreur
      (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée par les trois user stories — types, réglages, textes,
remotes, et surtout **la contenance du sac**, dont US1 dépend pour sa limite de 5. Le `Tool` dans
le sac à dos est volontairement exclu d'ici : c'est US2.

**⚠️ CRITICAL** : aucune user story ne démarre avant la fin de cette phase.

- [X] T002 [P] Étendre `Types.luau` : nouveau type exporté `BagType = "LittleBag"` ;
      `RejectCode` + `AlreadyCarried` et `NotCarrying` (data-model.md, contracts/network.md) —
      dans `src/ReplicatedStorage/Shared/Types.luau`
- [X] T003 [P] Modifier `Settings.luau` : **retirer** `Forest.InventoryCapacity` et créer le
      domaine `Bag` (`DefaultType` = `"LittleBag"` avec `choices`, `SmallCapacity` défaut 5 1–50
      entier, `CarryRange` défaut 18 5–40, `CarryCheckInterval` défaut 0.2 0.05–2, `MaxCoordinate`
      défaut 2000 100–10000, `PointerRefreshRate` défaut 15 5–60 entier) — valeurs exactes de
      contracts/config.md — dans `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T004 [P] Étendre `Strings.luau` : libellé du sac et de sa contenance pour le HUD, indice de
      ramassage affiché au pointage (action + nom de la ressource), message « sac plein », noms
      des commandes de dev `Dev.FillBag`/`Dev.EmptyBag` — dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T005 [P] Déclarer dans `Remotes.Intents` les intentions `GrabItem`
      (`{ target: string(≤64) }`, phases jouables, cible → `Forest.HarvestRange`) et
      `ReleaseItem` (`{ target: string(≤64), x, y, z }` avec
      `Validate.number(-Bag.MaxCoordinate, Bag.MaxCoordinate)` — `Validate` n'est pas modifié,
      il expose déjà ce vérificateur —, phases jouables, cible → `Bag.CarryRange`), les commandes
      `Dev.FillBag` et `Dev.EmptyBag` (`devOnly`, sans payload), et ajouter `BagFull` à
      `Remotes.NotificationKinds` — dans `src/ReplicatedStorage/Shared/Net/Remotes.luau`
- [X] T006 Créer `BagService` (Priority 47), **sans le `Tool`** (US2) : table `BAG_TYPES`
      associant à chaque `BagType` sa contenance (réglage `Bag.SmallCapacity`) et son entrée de
      catalogue (research R7) ; à `SessionService.PlayerJoined`, écrire sur le joueur les
      attributs `BagType` (= `Bag.DefaultType`) et `BagCapacity` (= contenance du type) ; exposer
      `capacityOf(player)`, `usedBy(player)` (somme des `Inv_*`), `fill(player)` et
      `empty(player)` — dans `src/ServerScriptService/Server/Services/BagService.luau`
      (dépend de T002, T003)
- [X] T007 Modifier `InventoryService.addPersonal` : lire le plafond dans l'attribut
      `BagCapacity` du joueur, avec repli sur `Config.get("Bag", "SmallCapacity")` si l'attribut
      n'est pas encore écrit — **ne pas requérir `BagService`** (dépendance circulaire, research
      R6) ; signature, valeur de retour et sémantique inchangées — dans
      `src/ServerScriptService/Server/Services/InventoryService.luau` (dépend de T003)

**Checkpoint** : la contenance de 5 s'applique déjà (vérifiable via `Dev.GiveResources`) ; les
user stories peuvent commencer.

---

## Phase 3 : User Story 1 - Ramasser un objet pointé dans un sac à contenance limitée (Priority: P1) 🎯 MVP

**Goal** : viser un objet avec la souris, voir qu'il est ramassable, appuyer sur F pour le mettre
dans son sac, et être refusé proprement — avec un retour explicite — quand le sac est plein.

**Independent Test** : en solo, viser plusieurs nœuds et les ramasser avec F jusqu'à remplir le
sac, puis constater que le ramassage suivant est refusé avec un retour « sac plein » et que
l'objet reste dans le monde — quickstart.md V1 et V2. Ne nécessite ni le `Tool` (US2) ni le
déplacement (US3).

### Implementation for User Story 1

- [X] T008 [US1] Retirer l'invite de proximité des nœuds : `buildNode` ne crée plus de
      `ProximityPrompt` (`HarvestPrompt`), et `setAvailable` ne bascule plus `prompt.Enabled` —
      conserver les attributs `ResourceType` et `Available` sur la pièce, qui suffisent à la
      visée côté client (research R9) ; **ne pas toucher aux invites des postes** — dans
      `src/ServerScriptService/Server/Services/ForestService.luau`
- [X] T009 [US1] Dans le gestionnaire de l'intention `HarvestResource` (inchangé par ailleurs :
      même schéma, même résolveur, même effet), envoyer
      `NotifyService.send(player, "BagFull", { capacity })` juste avant de retourner
      `InventoryFull` (research R10) — dans
      `src/ServerScriptService/Server/Services/ForestService.luau` (même fichier que T008, donc
      séquentiel ; dépend de T005)
- [X] T010 [US1] Créer `PointerController` (Priority 12), découvert automatiquement par le
      `Loader` : lancer de rayon depuis la caméra vers le pointeur, throttlé à
      `Bag.PointerRefreshRate` Hz et filtré sur `Workspace.Forest` ; une cible est valide si sa
      pièce porte `ResourceType`, que `Available` est vrai et que `GrabbedBy` vaut 0 ; afficher
      un `Highlight` et un libellé (touche + nom de la ressource, via `Strings`) ; sur appui de
      **F**, envoyer `NetClient.send("HarvestResource", { target = <id du nœud> })` — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PointerController.luau`
      (dépend de T003, T004, T008)
- [X] T011 [P] [US1] Étendre `SfxController` : ajouter l'entrée `BagFull` à la table `SFX` (même
      patron que les entrées existantes, son d'échec) — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SfxController.luau` (dépend de
      T005)
- [X] T012 [P] [US1] Étendre `DevService` : commandes `Dev.FillBag` (remplit jusqu'à
      `BagCapacity` via `BagService.fill`) et `Dev.EmptyBag` (via `BagService.empty`), chacune
      avec son `DevService.report` ; ajouter à `Dev.ShowGameplayState` une ligne
      `BagType`/`BagCapacity`/total porté — dans
      `src/ServerScriptService/Server/Services/DevService.luau` (dépend de T005, T006)
- [X] T013 [P] [US1] Étendre le panneau de dev : boutons `Dev.FillBag` et `Dev.EmptyBag` via
      `addButton` ; **corriger le commentaire obsolète** du bouton `Dev.GiveResources`, qui
      mentionne encore « dans la limite de `Forest.InventoryCapacity` » (réglage retiré en T003)
      — dans `src/StarterGui/DevPanel/DevPanel.client.luau` (dépend de T004, T005)

**Checkpoint** : le ramassage au pointeur fonctionne de bout en bout avec la limite de 5 et son
refus explicite (US1 testable indépendamment).

---

## Phase 4 : User Story 2 - Accéder au sac depuis l'inventaire (Priority: P2)

**Goal** : le sac « LittleBag » figure dans l'inventaire natif du joueur, s'équipe, s'affiche sur
le personnage, ne peut pas être lâché, et le HUD indique en permanence ce qu'il contient et la
place restante.

**Independent Test** : avec un sac partiellement rempli (`Dev.FillBag` puis dépôt), ouvrir
l'inventaire, équiper le sac, vérifier le modèle sur le personnage, tenter de le lâcher sans
succès, puis mourir et réapparaître en vérifiant que le sac est toujours là — quickstart.md V3.

### Implementation for User Story 2

- [X] T014 [P] [US2] Ajouter l'entrée `LittleBag` au catalogue : `ModelName = "LittleBag"` plus
      un `BuildFallback` en primitives (sac low-poly original, principe VIII), pour que le sac
      reste jouable si l'asset est absent — dans
      `src/ReplicatedStorage/Shared/Assets/Catalog.luau`
- [X] T015 [US2] Étendre `BagService` : construire le `Tool` du sac à partir de
      `VisualService.build("LittleBag")` en prenant le `PrimaryPart` du modèle comme `Handle`
      (l'asset est une pièce unique, enveloppée en `Model` par `VisualService`) ;
      `RequiresHandle = true`, `CanBeDropped = false` ; le déposer dans `player.Backpack` à
      **chaque** `CharacterAdded` (le `Backpack` est recréé à chaque apparition, research R2) —
      dans `src/ServerScriptService/Server/Services/BagService.luau` (dépend de T006, T014)
- [X] T016 [P] [US2] Étendre `GameplayStateClient` : exposer `bagType`, `bagCapacity` (attributs
      du joueur) et `bagUsed` (somme des compteurs `Inv_*` déjà lus), inclus dans le même signal
      `Changed` — dans `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau` (dépend de
      T006)
- [X] T017 [US2] Étendre le HUD : ajouter une ligne « Sac : n/capacité » juste après la ligne
      Santé (`gameplayRow("Bag", 2)`) et **renuméroter** les `LayoutOrder` des lignes suivantes
      (Essence → 3, SuspectSteak → 4, RoadBread → 5, Scrap → 6, Fuel → 7, SafeZone → 8, Order →
      9, OrderIngredients → 10, Bus → 11) ; effet « punch » sur changement, comme les autres
      valeurs — dans `src/StarterGui/HUD/Hud.client.luau` (dépend de T016)

**Checkpoint** : le sac est visible, équipable et lisible ; US1 et US2 fonctionnent
indépendamment.

---

## Phase 5 : User Story 3 - Déplacer un objet sans le ramasser (Priority: P3)

**Goal** : saisir un objet au clic maintenu, le déplacer avec la souris et le poser ailleurs,
sans consommer de place dans le sac — avec une saisie exclusive et une position finale décidée
par le serveur.

**Independent Test** : saisir un objet, le traîner, le relâcher et vérifier qu'il reste à sa
nouvelle position pour tous les joueurs sans que le sac ait changé ; puis vérifier le relâchement
forcé au-delà de `Bag.CarryRange` et le refus `AlreadyCarried` à deux joueurs — quickstart.md V4
et V5.

### Implementation for User Story 3

- [X] T018 [US3] Créer `CarryService` (Priority 48) : enregistrer `GrabItem` et `ReleaseItem` via
      `NetService.registerIntent` avec `resolve = ForestService.findNode` ; `GrabItem` refuse
      `TargetMissing`, `NodeUnavailable` (nœud récolté) et `AlreadyCarried` (porteur encore
      présent — si le porteur enregistré a quitté, reprendre proprement), relâche l'objet
      précédent du joueur le cas échéant, puis écrit `GrabbedBy = UserId` et confie la propriété
      réseau de la pièce au joueur ; `ReleaseItem` refuse `NotCarrying`, valide la position reçue
      (≤ `Bag.CarryRange` + `Net.DistanceTolerance`, sinon applique la `lastValidPosition`), rend
      la propriété réseau, réancre la pièce et remet `GrabbedBy = 0` ; boucle `Heartbeat` à
      `Bag.CarryCheckInterval` qui borne la distance porteur–objet et force le relâchement
      au-delà ; `releaseAll(player)` appelé à la mort, au départ du joueur
      (`SessionService.StatusChanged`/`PlayerLeft`) et à `MatchService.MatchStarting` ; exposer
      `isCarried(part)` et `carrierOf(part)` — dans
      `src/ServerScriptService/Server/Services/CarryService.luau` (dépend de T002, T003, T005)
- [X] T019 [US3] Initialiser `GrabbedBy = 0` sur la pièce de chaque nœud dans `buildNode`, pour
      que l'attribut existe dès la génération (le client s'en sert pour ne pas proposer un objet
      déjà tenu) — dans `src/ServerScriptService/Server/Services/ForestService.luau` (même
      fichier que T008/T009, donc séquentiel)
- [X] T020 [US3] Étendre `PointerController` : sur clic maintenu sur une cible valide, envoyer
      `GrabItem`, puis suivre le pointeur localement (contrainte `AlignPosition` vers le point
      visé, bornée à `Bag.CarryRange`) ; au relâchement du clic, envoyer `ReleaseItem` avec la
      position finale — **exactement deux intentions par déplacement, jamais un flux par frame**
      (research R4) ; ne pas proposer la saisie d'un objet dont `GrabbedBy` est non nul — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PointerController.luau` (dépend
      de T010, T018)

**Checkpoint** : les trois gestes (viser, ramasser, déplacer) coexistent ; la boucle complète du
jeu reste jouable.

---

## Phase 6 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles statiques et validation manuelle finale, communs aux trois stories.

- [X] T021 [P] `selene src` et `stylua --check src` sur tous les fichiers nouveaux ou modifiés
      par cette fonctionnalité : aucun écart
- [X] T022 [P] Contrôles de non-régression : `grep -rn "math.random" src` → aucun résultat ;
      `grep -rn "InventoryCapacity" src` → **aucun résultat** (réglage retiré en T003, dernier
      commentaire nettoyé en T013)
- [ ] T023 Exécuter les scénarios V1 à V6 de `quickstart.md` en Studio (solo puis 2 clients
      locaux) et cocher la « Checklist de fin », en incluant le test de l'asset absent (V5.5) et
      le contrôle d'absence de refus `RateLimited` pendant les déplacements (V4.5)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — BLOQUE les trois user stories.
- **User Story 1 (Phase 3)** : dépend de Foundational — aucune dépendance sur US2 ni US3.
- **User Story 2 (Phase 4)** : dépend de Foundational **et** de `BagService` créé en T006 (T015
  l'étend) — reste testable indépendamment d'US1 et d'US3.
- **User Story 3 (Phase 5)** : dépend de Foundational **et** de `PointerController` créé en US1
  (T010, que T020 étend) — même relation qu'`US1`/`US2` en 003 : deux stories séparées et
  testables indépendamment, mais pas deux contrôleurs indépendants.
- **Polish (Phase 6)** : dépend des user stories livrées.

### Conflits de fichiers à respecter

- `ForestService.luau` est touché par **T008, T009 et T019** : ces trois tâches ne sont jamais
  parallèles entre elles, malgré leurs stories différentes.
- `BagService.luau` est créé en T006 puis étendu en T015 : séquentiel.
- `PointerController.luau` est créé en T010 puis étendu en T020 : séquentiel.

### Parallel Opportunities

- T002 à T005 (Types, Settings, Strings, Remotes) : fichiers différents, aucune dépendance
  mutuelle — en parallèle.
- T006 et T007 : fichiers différents ; T007 ne dépend que de T003 (il lit un attribut, pas
  `BagService`), donc les deux peuvent avancer en parallèle une fois T002/T003 faits.
- T011, T012 et T013 (SfxController, DevService, DevPanel) : trois fichiers différents — en
  parallèle une fois T005/T006 faits.
- T014 et T016 (Catalog, GameplayStateClient) : fichiers différents — en parallèle.
- T021 et T022 (contrôles statiques) : indépendants — en parallèle.

---

## Parallel Example: Phase 2 (Foundational)

```bash
Task: "Étendre Types.luau (BagType, 2 RejectCode)"
Task: "Modifier Settings.luau (domaine Bag, retrait de Forest.InventoryCapacity)"
Task: "Étendre Strings.luau (libellés du sac, indice de ramassage, sac plein)"
Task: "Étendre Remotes.luau (GrabItem/ReleaseItem, Dev.FillBag/EmptyBag, BagFull)"
```

---

## Implementation Strategy

### MVP First (User Story 1 seule)

1. Compléter Phase 1 : Setup
2. Compléter Phase 2 : Foundational (CRITIQUE — bloque les trois stories)
3. Compléter Phase 3 : User Story 1
4. **STOP et VALIDER** : quickstart.md V1 et V2, en solo
5. Livrable : le ramassage au pointeur avec un sac limité à 5 remplace intégralement la collecte
   actuelle — jouable et démontrable même sans le `Tool` ni le déplacement

### Incremental Delivery

1. Setup + Foundational → base prête, contenance déjà appliquée
2. + User Story 1 → validation indépendante (V1, V2) → nouveau geste de collecte démontrable
3. + User Story 2 → validation indépendante (V3) → le sac devient visible et lisible
4. + User Story 3 → validation indépendante (V4, V5) → manipulation complète des objets
5. Chaque story ajoute de la valeur sans casser la précédente

## Notes

- [P] tasks = fichiers différents, aucune dépendance
- [Story] label = traçabilité vers la user story de `spec.md`
- **Le ramassage ne crée aucune intention nouvelle** : `HarvestResource` est réutilisée telle
  quelle (research R3). Aucune tâche ne modifie le pipeline de `NetService` — si une tâche
  semble l'exiger, c'est le signe d'une erreur de conception à remonter avant de coder.
- **Le déplacement coûte exactement deux intentions** (T020). Le limiteur accorde 10 jetons
  rechargés à 5/s : tout flux par frame est à proscrire (research R4).
- `InventoryService` ne doit **jamais** requérir `BagService` (T007) : la contenance passe par
  un attribut, sans quoi la dépendance devient circulaire (research R6).
- Éviter : tâches vagues, conflits sur un même fichier en parallèle (voir « Conflits de fichiers
  à respecter »), dépendances qui casseraient l'indépendance de test de chaque story.

---

## Amendement du 2026-09-17 — sac en main et vidage au sol

Demande de l'auteur après l'implémentation initiale : « les collectibles ne peuvent être ramassés
que lorsque le sac est dans la main du joueur » et « en appuyant sur une touche, le joueur peut
lâcher les collectibles qui sont dans le sac ». Traduit en FR-019 à FR-022 et SC-008 dans
`spec.md`, rattaché à **US1** (la boucle de collecte) sans nouvelle user story : ces deux règles
précisent le geste de ramassage plutôt que d'ouvrir un parcours nouveau.

- [X] T024 [US1] Déclarer l'état et le contrat : `BagNotEquipped`/`BagEmpty` dans
      `src/ReplicatedStorage/Shared/Types.luau`, intention `DropBag` et notification `BagDropped`
      dans `src/ReplicatedStorage/Shared/Net/Remotes.luau`, `Bag.DropRadius` dans
      `src/ReplicatedStorage/Shared/Config/Settings.luau`, libellés dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T025 [US1] Écrire l'attribut `BagEquipped` (Tool.Equipped/Unequipped, remise à faux à chaque
      apparition) et implémenter `BagService.drop` + le gestionnaire `DropBag` dans
      `src/ServerScriptService/Server/Services/BagService.luau`
- [X] T026 [US1] Ajouter `ForestService.spawnDrop` et le champ `dropped` (aucune réapparition d'un
      objet lâché), plus les refus `BagNotEquipped` et `AlreadyCarried` au gestionnaire
      `HarvestResource`, dans `src/ServerScriptService/Server/Services/ForestService.luau`
- [X] T027 [US1] Conditionner F au sac en main, brancher la touche G sur `DropBag` et afficher
      l'indice « Équipez votre sac » dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PointerController.luau`
- [X] T028 [P] [US1] Exposer `bagEquipped` dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau`, afficher l'état du sac et le
      rappel de la touche dans `src/StarterGui/HUD/Hud.client.luau`, ajouter le son `BagDropped`
      dans `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SfxController.luau`
- [X] T029 Contrôles statiques : `selene src` (0 erreur, 0 avertissement) et `rojo build`
- [ ] T030 Validation manuelle du scénario V7 de `quickstart.md` (vidage au sol, absence de
      duplication) et du V1 amendé (sac rangé → aucun ramassage) — **à mener en même temps que
      T023**

### Notes d'amendement

- **Aucune dépendance de module dans le sens interdit** : `ForestService` lit `BagEquipped` et
  `GrabbedBy` comme des attributs répliqués, jamais en requérant `BagService` ni `CarryService`.
  Seul `BagService` gagne un require (`ForestService`), dans le sens libre.
- **`DropBag` est la seule intention sans cible** de la fonctionnalité : le pipeline saute alors
  ses étapes 7 à 9, donc le gestionnaire vérifie lui-même le personnage vivant.
- **Un vidage coûte une seule intention**, quel que soit le nombre d'objets posés : le budget de
  cadence (research R4) n'est pas plus sollicité qu'avant.
- **Correction embarquée** : `HarvestResource` refusait jusqu'ici de ramasser un objet tenu par un
  coéquipier — le scénario V5.2 du quickstart l'exigeait, le code ne le faisait pas. Réparé par
  T026.
