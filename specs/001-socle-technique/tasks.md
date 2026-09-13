---

description: "Liste des tâches — Socle technique du projet"
---

# Tasks: Socle technique du projet

**Input**: Design documents from `specs/001-socle-technique/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: la spec ne demande aucun test automatisé. La validation suit
[quickstart.md](./quickstart.md) (manuelle dans Studio) et les contrôles intégrés au panneau de
développement. Chaque phase de scénario utilisateur se termine par une tâche de validation.

**Organization**: les tâches sont regroupées par scénario utilisateur, pour que chaque
scénario puisse être implémenté et validé comme un incrément.

**Avant de commencer** :

1. Créer la branche `001-socle-technique` depuis `main`.
2. Installer Rokit (voir « Prérequis » dans [quickstart.md](./quickstart.md)).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallélisable (fichiers différents, pas de dépendance sur une tâche inachevée)
- **[Story]**: scénario utilisateur concerné (US1 à US5)
- Chaque description donne le chemin exact du fichier concerné.

## Path Conventions

- Place Rojo unique : sources dans `src/<Service>/…`, fichiers d'outillage à la racine du dépôt
  (plan.md, « Source Code »).
- Tout fichier `.luau` commence par `--!strict`.
- Les modules de `Services/` (serveur) et `Controllers/` (client) respectent le contrat de
  système de [contracts/server-api.md](./contracts/server-api.md) (`Name`, `Priority`, `Init`,
  `Start`).
- Aucune valeur d'équilibrage hors de `src/ReplicatedStorage/Shared/Config/Settings.luau`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: initialiser le dépôt comme projet Rojo, avec des outils aux versions figées.

- [X] T001 [P] Créer `rokit.toml` à la racine avec la section `[tools]` : `rojo = "rojo-rbx/rojo@7.7.0"`, `selene = "Kampfkarren/selene@0.31.0"`, `stylua = "JohnnyMorganz/StyLua@2.5.2"` (research R1)
- [X] T002 [P] Créer `default.project.json` à la racine :
  - nom `LastExitDriveThru` ;
  - `ReplicatedStorage` → `Shared` (`$path: src/ReplicatedStorage/Shared`) et `Assets` (`$className: Folder`) ;
  - `ServerScriptService` → `Server` (`$path: src/ServerScriptService/Server`) ;
  - `StarterPlayer` → `StarterPlayerScripts` → `Client` (`$path: src/StarterPlayer/StarterPlayerScripts/Client`) ;
  - `StarterGui` (`$path: src/StarterGui`) ;
  - `$ignoreUnknownInstances: true` sur chaque nœud de service ;
  - `Players.$properties.CharacterAutoLoads = false` ;
  - `Workspace.$properties.FallenPartsDestroyHeight = -100`.

  Forme validée par prototype (research R2).
- [X] T003 [P] Créer `.gitignore` à la racine : `build/`, `*.rbxl`, `*.rbxlx`, `*.rbxl.lock`, `*.rbxlx.lock`, `sourcemap.json`, `roblox.yml`, `.DS_Store`
- [X] T004 [P] Créer `selene.toml` à la racine avec `std = "roblox"`
- [X] T005 [P] Créer `stylua.toml` à la racine : `syntax = "Luau"`, `column_width = 120`, `indent_type = "Tabs"`, `quote_style = "AutoPreferDouble"`
- [X] T006 [P] Créer les conteneurs d'écrans `src/StarterGui/HUD/init.meta.json`, `src/StarterGui/EndScreen/init.meta.json` et `src/StarterGui/DevPanel/init.meta.json`, chacun avec le contenu `{ "className": "ScreenGui", "properties": { "ResetOnSpawn": false } }`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: utilitaires partagés, configuration validée, cycle de vie des systèmes, canal
réseau validé et outils de développement de base.

**⚠️ CRITICAL**: aucun scénario utilisateur ne peut commencer avant la fin de cette phase.

- [X] T007 [P] Créer `src/ReplicatedStorage/Shared/Types.luau` : types exportés `Phase`, `MatchResult`, `PlayerStatus`, `RejectCode`, `RefPointId` (contracts/server-api.md, « Types partagés »)
- [X] T008 [P] Implémenter `src/ReplicatedStorage/Shared/Util/Log.luau` (research R12) :
  - `Log.new(system)` → `debug`, `info`, `warn`, `error` ;
  - préfixe `[LastExit/<système>]` ;
  - `Log.setLevel(level)`, `Info` par défaut ;
  - `error` écrit via `warn` avec la mention `ERREUR` et une trace facultative, sans lever d'exception.
- [X] T009 [P] Créer `src/ReplicatedStorage/Shared/Config/Settings.luau` : les 23 réglages de contracts/config.md, rangés par domaine (`Match`, `Players`, `Net`, `Bell`, `Ui`, `Visuals`, `Debug`). Chaque entrée a la forme `{ value, default, min?, max?, choices?, test? }`, avec un commentaire en français (unité, rôle).
- [X] T010 [P] Créer `src/ReplicatedStorage/Shared/Strings.luau` (FR-037) :
  - tous les textes joueurs en français : libellés de phase, HUD, invite de la sonnette, écran de fin, panneau de dev ;
  - modèles des notifications `PhaseStarted`, `PlayerJoined`, `PlayerLeft`, `StatusChanged`, `BellRang`, `MatchEnded` ;
  - ton « meme horror », sans contenu graphique ;
  - `Strings.format(key, params)`, avec interpolation `{name}`.
- [X] T011 [P] Créer `src/ReplicatedStorage/Shared/World/RefPoints.luau` :
  - liste gelée des 11 identifiants (data-model.md) ;
  - `RefPoints.isValid(id)` ;
  - `RefPoints.find(id): BasePart?`, via le tag CollectionService `RefPoint` et l'attribut `RefPoint`, utilisable côté serveur comme côté client.
- [X] T012 [P] Implémenter `src/ReplicatedStorage/Shared/Net/Validate.luau`, module pur sans dépendance (research R7) :
  - `string(maxLength)`, `number(min, max)` (refuse NaN et ±inf), `integer`, `boolean`, `enum`, `optional` ;
  - `object(fields)`, qui refuse les clés inconnues et les valeurs qui ne sont pas des tables ;
  - `check(schema, value) -> (boolean, string?)`.
- [X] T013 Implémenter `src/ReplicatedStorage/Shared/Util/Signal.luau` (dépend de T008 ; FR-010) :
  - `Signal.new(owner)`, `Connect`, `Once`, `Disconnect` ;
  - `Fire` exécute chaque écouteur dans son propre thread (`task.spawn`), sous `xpcall` ;
  - un écouteur en erreur est journalisé avec `owner` et la trace ; les autres continuent.
- [X] T014 Implémenter `src/ReplicatedStorage/Shared/Config/init.luau` (dépend de T008, T009 ; FR-013 à FR-016) :
  - charge `Settings` et applique les règles 1 à 6 de contracts/config.md ;
  - valeur rejetée → défaut, avec l'avertissement `Réglage X.Y invalide (v) : défaut d utilisé` ;
  - gèle le résultat (`table.freeze`) ;
  - expose `Config.get(domain, key, useTest)` et `Config.TestProfileDefault` ;
  - appelle `Log.setLevel` avec `Debug.LogLevel`.
- [X] T015 Implémenter `src/ReplicatedStorage/Shared/Util/Loader.luau` : `Loader.run(folder, label)` (dépend de T008, T014 ; FR-006, FR-009) :
  - charge les ModuleScripts enfants directs du dossier et les trie par `Priority` (100 par défaut), puis par `Name` ;
  - exécute tous les `require`, puis tous les `Init`, puis chaque `Start` dans son propre thread, le tout sous `xpcall` ;
  - ne démarre pas un système dont l'`Init` a échoué ;
  - honore `Debug.FailSystemAtInit` uniquement si `RunService:IsStudio()` ;
  - dossier absent → simple information, pas d'erreur ;
  - journalise le résumé `N systèmes démarrés, M en échec`.
- [X] T016 Créer `src/ReplicatedStorage/Shared/Net/Remotes.luau` (dépend de T007, T012 ; FR-030) :
  - nom du dossier (`Remotes`) et noms des remotes (`Intent`, `Notify`) ;
  - déclaration de chaque intention de contracts/network.md (`RingBell` et toutes les `Dev.*`) : `schema` (via `Validate`), `phases`, `target` (`{ field, rangeSetting }`), `devOnly` ;
  - liste des types de notification.
- [X] T017 Implémenter `src/ServerScriptService/Server/Services/NetService.luau`, `Priority = 30` (dépend de T011, T014, T015, T016 ; FR-030 à FR-033, FR-043) :
  - `Init` crée `ReplicatedStorage.Remotes` avec les RemoteEvents `Intent` et `Notify` ;
  - pipeline en 10 étapes de contracts/network.md :
    - seau à jetons par joueur en premier, libéré au départ du joueur ;
    - phase lue dans l'attribut `ReplicatedStorage.MatchState.Phase` (`Waiting` si l'attribut est absent) ;
    - cible trouvée par `RefPoints.find` ;
    - distance mesurée depuis le `HumanoidRootPart`, avec `Net.DistanceTolerance` ;
    - gestionnaire exécuté sous `xpcall` ;
  - refus historisés (`Net.RejectionHistory`) et journal limité par joueur et par code (`Net.RejectLogCooldown`) ;
  - API `registerIntent(name, { handler })` : les métadonnées sont lues dans `Remotes`, et enregistrer une intention non déclarée est une erreur ;
  - API `remote(name)` et `recentRejections(player, count)` ;
  - aucune RemoteFunction.
- [X] T018 Implémenter `src/ServerScriptService/Server/Services/NotifyService.luau`, `Priority = 35` : `broadcast(kind, params)` et `send(player, kind, params)` via le remote `Notify`, avec vérification du type dans la liste de `Remotes` (dépend de T017 ; FR-036)
- [X] T019 [P] Implémenter `src/ServerScriptService/Server/Main.server.luau` : charge `Config` en premier, pour que ses avertissements s'affichent d'emblée, puis appelle `Loader.run(script.Parent.Services, "Serveur")` (dépend de T015)
- [X] T020 [P] Implémenter `src/ReplicatedStorage/Shared/Client/NetClient.luau` (dépend de T016) :
  - attend `Remotes.Intent` et `Remotes.Notify` (10 s au plus, puis ERREUR) ;
  - `send(action, payload)` et `onNotify(kind, fn)` ;
  - types de notification inconnus ignorés (journal debug) ;
  - `rawIntent()`, réservé au panneau de dev.
- [X] T021 [P] Implémenter `src/ReplicatedStorage/Shared/Client/UiKit.luau` (FR-038) :
  - `screen(name)` renvoie le ScreenGui dans `PlayerGui` ;
  - briques : panneau, libellé (`TextScaled` + `UITextSizeConstraint` de 14 à 32), bouton, liste verticale ;
  - palette sombre et néon originale ;
  - tailles en Scale, pour rester lisible sur téléphone.
- [X] T022 [P] Implémenter `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau` : `Loader.run(script.Parent:FindFirstChild("Controllers"), "Client")`. Le dossier `Controllers` n'arrive qu'en US3 ; son absence est une simple information (dépend de T015).
- [X] T023 Implémenter `src/ServerScriptService/Server/Services/DevService.luau`, `Priority = 90` (dépend de T017, T018 ; FR-042, FR-043) :
  - helper `command(name, handler)` qui enregistre `Dev.<name>` auprès de `NetService` (le `devOnly` vient de `Remotes`) ;
  - helper `report(player, title, lines)`, via `NotifyService.send(player, "DevReport", …)` ;
  - commande `Dev.Ping`, sans effet.
- [X] T024 Implémenter `src/StarterGui/DevPanel/DevPanel.client.luau` (dépend de T020, T021) :
  - détruit son ScreenGui si `not RunService:IsStudio()` ;
  - panneau repliable en haut à gauche ;
  - registre local `addButton(label, fn)` ;
  - zone de rapport qui affiche le dernier `DevReport` (titre et lignes) ;
  - bouton « Ping ».
- [ ] T025 Point de contrôle : construire `build/LastExitDriveThru.rbxlx` et vérifier le démarrage du socle :
  - `rokit install`, puis `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` ;
  - ouvrir `build/LastExitDriveThru.rbxlx` dans Studio et lancer Play : résumé du Loader sans ligne `ERREUR`, dossier `ReplicatedStorage.Remotes` présent ;
  - `selene src` et `stylua --check src` sans erreur.

**Checkpoint**: le socle démarre, les systèmes sont découverts et isolés, le canal réseau
existe. Les scénarios utilisateurs peuvent commencer.

---

## Phase 3: User Story 1 - Dépôt Rojo et première session jouable (Priority: P1) 🎯 MVP

**Goal**: depuis une copie fraîche du dépôt, obtenir par synchronisation une session où chaque
joueur apparaît devant le restaurant provisoire, sans aucune manipulation dans Studio.

**Independent Test**: [quickstart.md](./quickstart.md) V1 et V2.

- Copie fraîche → `rojo serve` → Play : le joueur apparaît au restaurant.
- Les 11 points de référence sont présents, et la sortie ne contient aucune erreur.
- Test à 2 clients.
- Mise à jour en direct d'un fichier.
- `rojo build`.
- Échec simulé d'un système.

### Implementation for User Story 1

- [X] T026 [P] [US1] Créer `src/ReplicatedStorage/Shared/Assets/Catalog.luau` (principe VIII ; FR-041) :
  - visuel `Ground` ;
  - visuel `Restaurant` : murs, toit, comptoir, ouverture du drive-thru, plan de travail, friteuse, générateur ;
  - visuel `NeonSign` : panneau en matériau Neon, sans texte copié ;
  - visuel `Bus` : caisse, vitres, roues ;
  - aucun `ModelName` ; chaque entrée a un `BuildFallback` qui construit un Model low-poly ancré, en primitives, au style original.
- [X] T027 [P] [US1] Créer `src/ServerScriptService/Server/World/Layout.luau` (data-model.md, « Point de référence ») :
  - placements (`CFrame`) des visuels et positions des 11 points de référence ;
  - `Spawn` à au moins 20 studs de `CounterBell` (plus que `Bell.Range` + `Net.DistanceTolerance`) ;
  - `CounterBell` posé sur le comptoir ;
  - `SafeZoneCenter` au centre du restaurant.
- [X] T028 [US1] Implémenter `src/ServerScriptService/Server/Services/VisualService.luau`, `Priority = 10` : `build(id) -> (Model, usedFallback)` (dépend de T026 ; FR-041) :
  - clone `ReplicatedStorage.Assets[ModelName]` si le modèle est déclaré, présent, et que `Visuals.PrimitivesOnly` est faux ;
  - sinon utilise `BuildFallback`, avec un avertissement si le `ModelName` déclaré est introuvable ;
  - id inconnu → ERREUR, et renvoie `nil`.
- [X] T029 [US1] Implémenter `src/ServerScriptService/Server/Services/WorldService.luau`, `Priority = 20` (dépend de T011, T027, T028 ; FR-004, FR-007) :
  - `Init` construit `Workspace.World` selon contracts/replicated-state.md :
    - `Ground`, `Restaurant`, `NeonSign` et `Bus`, via `VisualService` et `Layout` ;
    - dossier `RefPoints` : Parts ancrées, invisibles, `CanCollide`, `CanTouch` et `CanQuery` à `false`, avec le tag et l'attribut `RefPoint` ;
    - `CounterBell` visible ;
    - `RestaurantSpawn` (SpawnLocation `Neutral`) placé sur `Spawn` ;
  - désactive tout SpawnLocation étranger, avec un avertissement ;
  - vérifie la présence des 11 identifiants (une ERREUR par manquant) ;
  - API `refPoint(id)` (délègue à `RefPoints.find`), `spawnLocation()`, `isReady()`.
- [X] T030 [US1] Implémenter `src/ServerScriptService/Server/Services/SessionService.luau`, `Priority = 40` (dépend de T013, T029 ; FR-021 à FR-025) :
  - sessions `{ UserId, Player, Status, JoinedAt }` ;
  - attribut `Player.Status` ;
  - signaux `PlayerJoined`, `PlayerLeft` et `StatusChanged`, via `Signal` ;
  - au `Start`, traite les joueurs déjà présents puis `PlayerAdded`, avec `LoadCharacter` une fois `WorldService.isReady()` vrai ;
  - à la mort d'un joueur « en vie », réapparition après `Players.RespawnDelay` (valeur de test si l'attribut `MatchState.TestProfile` est vrai, sinon selon `Config.TestProfileDefault`) ;
  - au départ d'un joueur, nettoyage de ses connexions ;
  - API `get`, `all`, `countPresent`, `countAlive`, `setStatus`, `resetAll`, `respawnAll` ;
  - avertissement si le nombre de joueurs dépasse `Players.MaxPlayers`.
- [X] T031 [P] [US1] Rédiger `README.md` à la racine (FR-008) :
  - prérequis, installation de Rokit, `rokit install`, `rojo plugin install` ;
  - `rojo build -o build/LastExitDriveThru.rbxlx`, puis `rojo serve` et connexion depuis Studio ;
  - règle d'or : on modifie le dépôt, jamais Studio ;
  - alignement des versions du plugin et de l'outil ;
  - réglage de publication à 6 joueurs ;
  - test solo et test « Clients and Servers » ;
  - arborescence résumée ;
  - section « Ajouter un système » (contracts/server-api.md) ;
  - lien vers la checklist de quickstart.md.
- [ ] T032 [US1] Valider US1 selon `specs/001-socle-technique/quickstart.md` V1 et V2 : apparition au restaurant, 11 points de référence, synchronisation en moins de 2 s, place construite, 2 clients, `Debug.FailSystemAtInit`, système de démonstration ajouté puis retiré

**Checkpoint**: US1 est entièrement fonctionnelle : dépôt Rojo reproductible et session
multijoueur lançable.

---

## Phase 4: User Story 2 - Une partie qui se déroule pour toute l'équipe (Priority: P2)

**Goal**: une horloge de partie autoritaire (Attente → Compte à rebours → 7 jours et 7 nuits →
Évasion), affichée à l'identique chez tous les joueurs, avec l'état de l'équipe et un fil de
notifications.

**Independent Test**: [quickstart.md](./quickstart.md) V3.

- Profil de test, 2 clients : enchaînement complet jusqu'à l'Évasion en moins de 5 min.
- Écart d'affichage d'au plus 1 s entre clients.
- Arrivée tardive.
- Départ d'un joueur.

### Implementation for User Story 2

- [X] T033 [US2] Implémenter `src/ServerScriptService/Server/Services/MatchService.luau`, `Priority = 50` (dépend de T018, T030 ; FR-017 à FR-020) :
  - `Init` crée `ReplicatedStorage.MatchState` et ses attributs (contracts/replicated-state.md) ;
  - machine à états de data-model.md pour `Waiting`, `Countdown`, `Day`, `Night` et `Escape` (la fin de partie arrive en US4) ;
  - jeton de phase + `task.delay` ;
  - durées lues via `Config.get(…, testProfile)` ;
  - `PhaseEndsAt` basé sur `workspace:GetServerTimeNow()`, `0` = sans limite ;
  - `PlayerJoined` en `Waiting` → nouvelle partie, puis `Countdown` :
    - `MatchId` + 1 ;
    - seed `Random.new():NextInteger(1, 2147483647)` ;
    - `TotalNights` figé ;
    - `SessionService.resetAll()` et `respawnAll()` ;
  - plus aucun joueur → abandon et retour en `Waiting` ;
  - signaux `PhaseStarted`, `PhaseEnded` et `MatchStarted` ;
  - notification `PhaseStarted` à chaque phase ;
  - relais des notifications `PlayerJoined`, `PlayerLeft` et `StatusChanged` à partir des signaux de `SessionService` ;
  - journal `Partie #N — seed S` ;
  - API `getPhase`, `getNight`, `getSeed`, `getMatchId`, `isActive`, `skipPhase` ;
  - API `setTestProfile` : effet à la phase suivante, attribut `TestProfile` mis à jour.
- [X] T034 [P] [US2] Implémenter `src/ReplicatedStorage/Shared/Client/MatchStateClient.luau` : attend `ReplicatedStorage.MatchState` ; `get()` ; `remaining()` (`nil` = sans limite) ; signal `Changed` à chaque changement d'attribut (FR-019)
- [X] T035 [US2] Implémenter `src/StarterGui/HUD/Hud.client.luau` (dépend de T010, T020, T021, T034 ; FR-035, FR-036) :
  - en haut au centre : phase, « Nuit n / N » et temps restant au format `mm:ss` ;
    - « En attente de joueurs » en `Waiting` ;
    - « Début dans » en `Countdown` ;
    - pas de minuteur quand la phase est sans limite ;
  - à droite : l'équipe (`Players` + attribut `Status`), mise à jour à chaque arrivée, départ ou changement de statut ;
  - en bas à gauche : le fil de notifications :
    - `NetClient.onNotify` pour les six types de jeu ;
    - textes via `Strings.format` ;
    - au plus `Ui.NotificationMax` visibles, chacune effacée après `Ui.NotificationLifetime` ;
  - rafraîchissement à 10 Hz au plus ;
  - éléments construits avec `UiKit`.
- [X] T036 [US2] Ajouter dans `src/ServerScriptService/Server/Services/DevService.luau` les commandes `Dev.NextPhase` (`MatchService.skipPhase`) et `Dev.SetTestProfile` (`MatchService.setTestProfile`), chacune avec un rapport (dépend de T023, T033)
- [X] T037 [US2] Ajouter dans `src/StarterGui/DevPanel/DevPanel.client.luau` les boutons « Phase suivante » et « Profil test on/off », ainsi qu'une ligne d'état (phase, nuit, temps restant, profil de test) alimentée par `MatchStateClient` (dépend de T024, T034, T036)
- [ ] T038 [US2] Valider US2 selon `specs/001-socle-technique/quickstart.md` V3 : cycle complet en moins de 5 min en profil de test, écart d'au plus 1 s entre 2 clients, arrivée tardive, départ d'un joueur

**Checkpoint**: US1 et US2 fonctionnent. La partie avance et chacun voit le même état.

---

## Phase 5: User Story 3 - Des actions de joueurs validées par le serveur (Priority: P3)

**Goal**: la sonnette du comptoir comme interaction de référence, du client au serveur et
retour. Toute requête invalide ou abusive est refusée, sans effet, et journalisée.

**Independent Test**: [quickstart.md](./quickstart.md) V4.1 à V4.3.

- 2 clients : sonnette vue par les deux joueurs.
- Sonnerie simultanée → `Cooldown`.
- Checklist des requêtes invalides : cas 1 à 9 conformes.

### Implementation for User Story 3

- [X] T039 [US3] Implémenter `src/ServerScriptService/Server/Services/BellService.luau`, `Priority = 60` (dépend de T017, T018, T029 ; FR-034) :
  - à l'`Init`, ajoute sur `CounterBell` un `ProximityPrompt` :
    - textes tirés de `Strings` ;
    - `HoldDuration = 0`, `MaxActivationDistance = Bell.Range`, `RequiresLineOfSight = false` ;
    - attributs `Intent = "RingBell"` et `Target = "CounterBell"` ;
  - enregistre le gestionnaire `RingBell` :
    - délai commun `Bell.Cooldown`, sinon refus `Cooldown` ;
    - met à jour les attributs `LastRungAt` et `LastRungBy` ;
    - `NotifyService.broadcast("BellRang", { name })` ;
  - ne se branche jamais sur `Triggered`.
- [X] T040 [P] [US3] Implémenter `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/InteractionController.luau`, selon le contrat de système : écoute `ProximityPromptService.PromptTriggered` côté client ; si l'invite porte l'attribut `Intent`, appelle `NetClient.send(Intent, { target = Target })`. C'est le modèle générique des interactions futures (research R8).
- [X] T041 [P] [US3] Implémenter `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BellEffectController.luau`, selon le contrat de système : trouve `CounterBell` via `RefPoints.find` et joue un effet local (flash néon + petit rebond par `TweenService`) à chaque changement de `LastRungAt`
- [X] T042 [US3] Ajouter dans `src/ServerScriptService/Server/Services/DevService.luau` la commande `Dev.GetRejections` : rapport des `count` derniers refus du demandeur (`code`, `action`, `detail`), obtenus via `NetService.recentRejections` (dépend de T017, T023)
- [X] T043 [US3] Ajouter dans `src/StarterGui/DevPanel/DevPanel.client.luau` le bouton « Checklist requêtes » (dépend de T042) :
  - envoie les 10 cas de contracts/network.md :
    - cas 1 et 3 via `NetClient.rawIntent()` ;
    - cas 10 seulement si la phase est `Ended` ;
  - attend 3 s, puis demande `Dev.GetRejections` ;
  - affiche attendu et obtenu avec ✅ ou ❌, et un total `n/10`.
- [ ] T044 [US3] Valider US3 selon `specs/001-socle-technique/quickstart.md` V4.1 à V4.3 : sonnette vue par 2 clients, sonnerie simultanée → `Cooldown`, cas 1 à 9 conformes. Le cas 10 est rejoué en T049.

**Checkpoint**: le modèle d'interaction validée par le serveur est en place et vérifié.

---

## Phase 6: User Story 4 - Fin de partie et nouvelle partie (Priority: P4)

**Goal**: victoire ou défaite (défaite automatique quand tous les joueurs présents sont
éliminés), écran de fin, puis nouvelle partie automatique avec une nouvelle seed.

**Independent Test**: [quickstart.md](./quickstart.md) V5.

- Victoire forcée → écran de fin → redémarrage à ± 1 s, avec une nouvelle seed.
- Deux éliminations → défaite.
- Victoire puis défaite en rafale → un seul écran de fin.

### Implementation for User Story 4

- [X] T045 [US4] Étendre `src/ServerScriptService/Server/Services/MatchService.luau` avec la fin de partie (dépend de T033 ; FR-026 à FR-029) :
  - `endMatch(result, reason)` n'est accepté qu'en phase active ; le premier résultat est retenu, les suivants renvoient `false` et journalisent une information ;
  - phase `Ended`, de durée `Match.EndScreenDuration` ;
  - attribut `Result` ;
  - signal et notification `MatchEnded` ;
  - règle de défaite, évaluée sur `StatusChanged` et `PlayerLeft` : phase active, `countPresent > 0` et `countAlive == 0` ;
  - expiration de `Escape` quand `Match.EscapeDuration > 0` → défaite (provisoire) ;
  - fin de `Ended` :
    - joueurs présents → nouvelle partie : nouvelle seed, `resetAll`, `respawnAll`, puis `Countdown` ;
    - aucun joueur → `Waiting` ;
  - un joueur qui arrive pendant `Ended` rejoint la partie suivante « en vie ».
- [X] T046 [P] [US4] Implémenter `src/StarterGui/EndScreen/EndScreen.client.luau` : superposition plein écran affichée en phase `Ended`, avec le titre « Victoire » ou « Défaite » (tiré de `Strings`), « Nuit n / N » et « Nouvelle partie dans s » (via `MatchStateClient`) ; masquée dès que la phase change ; lisible sur téléphone (dépend de T021, T034 ; FR-028)
- [X] T047 [US4] Ajouter dans `src/ServerScriptService/Server/Services/DevService.luau` les commandes `Dev.EndMatch` (`MatchService.endMatch(result, "dev")`) et `Dev.SetStatus` (`SessionService.setStatus` sur `userId`, ou sur le demandeur) (dépend de T045)
- [X] T048 [US4] Ajouter dans `src/StarterGui/DevPanel/DevPanel.client.luau` les boutons « Victoire », « Défaite », « M'éliminer » et « Me ranimer » (dépend de T047)
- [ ] T049 [US4] Valider US4 selon `specs/001-socle-technique/quickstart.md` V5, puis rejouer le cas 10 de la checklist pendant l'écran de fin (V4.4)

**Checkpoint**: les parties s'enchaînent sans intervention ; la règle de défaite est active.

---

## Phase 7: User Story 5 - Réglages centralisés, parties reproductibles et visuels de secours (Priority: P5)

**Goal**: une seed forçable qui rend les tirages reproductibles, des outils pour l'inspecter,
et une vérification des visuels de secours et de la validation de la configuration.

**Independent Test**: [quickstart.md](./quickstart.md) V6.

- Réglage modifié → pris en compte.
- Valeur invalide → avertissement et défaut.
- Seed forcée → tirages identiques.
- Visuel de secours.
- `Visuals.PrimitivesOnly`.

### Implementation for User Story 5

- [X] T050 [P] [US5] Implémenter `src/ReplicatedStorage/Shared/Util/Rng.luau` (research R11 ; FR-040) :
  - `hash32(text)` : FNV-1a 32 bits, avec la multiplication décomposée `(h * 403 + bit32.lshift(h, 24)) % 2^32` pour rester exacte ;
  - `forContext(seed, ...) -> Random`, calculé sur la chaîne `seed|partie1|…`.
- [X] T051 [US5] Ajouter la gestion de la seed dans `src/ServerScriptService/Server/Services/MatchService.luau` : `Match.ForcedSeed` est utilisée à chaque nouvelle partie si elle est positive, sinon la seed est tirée ; `MatchService.rng(...)` = `Rng.forContext(seed, ...)` (dépend de T045, T050 ; FR-039, FR-040)
- [X] T052 [US5] Ajouter les commandes de reproductibilité dans `src/ServerScriptService/Server/Services/DevService.luau` et le visuel de test dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau` (dépend de T028, T051) :
  - dans `src/ServerScriptService/Server/Services/DevService.luau` :
    - `Dev.ShowState` : phase, nuit, seed, partie, profil de test, sessions ;
    - `Dev.SampleRng` : `count` tirages `NextInteger(1, 1000000)` de `MatchService.rng(context)` ;
    - `Dev.TestVisualFallback` : construit l'entrée `FallbackProbe` et rapporte `usedFallback` ;
  - dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau` : l'entrée de test `FallbackProbe`, avec un `ModelName` volontairement absent et un petit cube comme remplaçant.
- [X] T053 [US5] Ajouter dans `src/StarterGui/DevPanel/DevPanel.client.luau` les boutons « État », « Tirages » (champ de contexte, `test` par défaut) et « Test visuel de secours » (dépend de T052)
- [ ] T054 [US5] Valider US5 selon `specs/001-socle-technique/quickstart.md` V6 : changement de réglage, valeur invalide, seed forcée reproductible, visuel de secours, `Visuals.PrimitivesOnly`

**Checkpoint**: les cinq scénarios fonctionnent et chacun a été validé séparément.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: contrôles transverses et Definition of Done de la constitution.

- [ ] T055 [P] Lancer `selene src` et `stylua --check src`, puis corriger tous les écarts dans `src/` (quickstart V9)
- [X] T056 [P] Vérifier dans `src/` et corriger les écarts (quickstart V9 ; principes III, IV et V) :
  - aucun `math.random`, `InvokeClient` ni `RemoteFunction` ;
  - `--!strict` en tête de chaque fichier `.luau` ;
  - aucune valeur d'équilibrage codée hors de `src/ReplicatedStorage/Shared/Config/Settings.luau`.
- [ ] T057 Passe de lisibilité sur téléphone, avec l'émulateur d'appareils de Studio, et ajustements dans `src/ReplicatedStorage/Shared/Client/UiKit.luau`, `src/StarterGui/HUD/Hud.client.luau` et `src/StarterGui/EndScreen/EndScreen.client.luau` (quickstart V7 ; FR-038)
- [X] T058 Compléter `README.md` avec la checklist de test solo et multijoueur (Definition of Done) et une section de dépannage : SpawnLocation étranger désactivé, versions du plugin et de l'outil différentes, remotes introuvables
- [ ] T059 Test d'endurance à 6 clients pendant 30 min selon `specs/001-socle-technique/quickstart.md` V8 (recommandé par la constitution avant le jalon MVP)
- [ ] T060 Vérification sur serveur publié en privé selon `specs/001-socle-technique/quickstart.md` V10 : pas de panneau de dev, intentions `Dev.*` refusées avec `NotAllowed`
- [ ] T061 Cocher la « Checklist de fin (Definition of Done) » de `specs/001-socle-technique/quickstart.md` une fois tous les scénarios conformes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance.
- **Foundational (Phase 2)** : dépend du Setup et bloque tous les scénarios.
- **US1 (Phase 3)** : dépend de la phase 2.
- **US2 (Phase 4)** : dépend d'US1 (sessions et apparition des joueurs).
- **US3 (Phase 5)** : dépend d'US1 (`CounterBell`) et d'US2 (phases, pour les phases autorisées).
- **US4 (Phase 6)** : dépend d'US2 (`MatchService`).
- **US5 (Phase 7)** : dépend d'US1 (`VisualService`, `Catalog`) et d'US4 (`MatchService` complet).
- **Polish (Phase 8)** : dépend de tous les scénarios.

### Fichiers partagés entre phases (à modifier dans l'ordre, jamais en parallèle)

- `src/ServerScriptService/Server/Services/MatchService.luau` : T033 (US2), T045 (US4), T051 (US5).
- `src/ServerScriptService/Server/Services/DevService.luau` : T023, T036, T042, T047, T052.
- `src/StarterGui/DevPanel/DevPanel.client.luau` : T024, T037, T043, T048, T053.
- `src/ReplicatedStorage/Shared/Assets/Catalog.luau` : T026 (US1), T052 (US5).
- `README.md` : T031 (US1), T058 (Polish).

### Within Each User Story

- Données déclaratives (catalogue, plan, réglages) → services serveur → contrôleurs et écrans
  clients → commandes de dev → validation.
- Un scénario est validé (dernière tâche de sa phase) avant de passer au suivant.

### Parallel Opportunities

- Phase 1 : T001 à T006, tous en parallèle.
- Phase 2 : T007 à T012 en parallèle ; puis T019, T020, T021 et T022 en parallèle, une fois
  leurs dépendances terminées.
- US1 : T026, T027 et T031 en parallèle.
- US2 : T034 en parallèle de T033.
- US3 : T040 et T041 en parallèle, dès que T039 a fixé les attributs de l'invite.
- US4 : T046 en parallèle de T045.
- US5 : T050 en parallèle de toute tâche US4.
- Polish : T055 et T056 en parallèle.

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Modules sans dépendance, lancés ensemble :
Task: "T007 Créer src/ReplicatedStorage/Shared/Types.luau"
Task: "T008 Implémenter src/ReplicatedStorage/Shared/Util/Log.luau"
Task: "T009 Créer src/ReplicatedStorage/Shared/Config/Settings.luau"
Task: "T010 Créer src/ReplicatedStorage/Shared/Strings.luau"
Task: "T011 Créer src/ReplicatedStorage/Shared/World/RefPoints.luau"
Task: "T012 Implémenter src/ReplicatedStorage/Shared/Net/Validate.luau"
```

## Parallel Example: User Story 1

```bash
Task: "T026 [US1] Créer src/ReplicatedStorage/Shared/Assets/Catalog.luau"
Task: "T027 [US1] Créer src/ServerScriptService/Server/World/Layout.luau"
Task: "T031 [US1] Rédiger README.md"
```

## Parallel Example: User Story 3

```bash
# Après T039 (attributs Intent/Target de l'invite fixés) :
Task: "T040 [US3] InteractionController.luau"
Task: "T041 [US3] BellEffectController.luau"
```

---

## Implementation Strategy

### Premier incrément (US1 seul)

1. Phase 1 (Setup) puis phase 2 (Foundational).
2. Phase 3 (US1).
3. **Arrêt et validation** : V1 et V2 de la quickstart. Le dépôt Rojo est reproductible et une
   session multijoueur se lance sans erreur.

« MVP » désigne ici le premier incrément de cette fonctionnalité, à ne pas confondre avec le
MVP de gameplay de la constitution, qui viendra dans la fonctionnalité suivante.

### Livraison incrémentale

1. Setup + Foundational → socle démarrable.
2. US1 → session reproductible (démo possible).
3. US2 → horloge de partie visible par tous : premier aperçu « jeu » du socle.
4. US3 → modèle d'interaction validée par le serveur.
5. US4 → parties qui s'enchaînent.
6. US5 → reproductibilité et outils d'inspection.
7. Polish → Definition of Done, puis `/speckit-specify` pour le MVP de gameplay.

### Travail en solo (cas actuel)

Suivre les phases dans l'ordre. Faire un commit après chaque tâche ou groupe logique, et après
chaque tâche de validation réussie.

---

## Notes

- [P] = fichiers différents, sans dépendance sur une tâche inachevée.
- L'étiquette [USn] relie chaque tâche à son scénario, pour la traçabilité.
- Toujours modifier les fichiers du dépôt ; ne jamais éditer les scripts synchronisés dans
  Studio.
- Les intentions, remotes et réglages ne sont déclarés qu'à un seul endroit
  (`Remotes.luau`, `Settings.luau`).
- À éviter : tâches vagues, modifications simultanées d'un même fichier, dépendance d'un
  service vers un service de priorité supérieure qui l'appelle déjà (cycle).
