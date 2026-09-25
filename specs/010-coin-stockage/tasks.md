---

description: "Task list template for feature implementation"
---

# Tasks: Coin de stockage du restaurant

**Input**: Design documents from `/specs/010-coin-stockage/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé par la spec — validation manuelle dans Studio selon `quickstart.md`, comme pour les incréments précédents (006 à 009). Les scénarios S8 et S9 exigent **deux clients** (test Studio « Clients and Servers », Definition of Done de la constitution).

**Organization**: Les tâches sont groupées par user story pour permettre une implémentation et une validation indépendantes de chacune.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut s'exécuter en parallèle (fichiers différents, aucune dépendance)
- **[Story]**: US1 (ranger au lâcher et voir figé, P1), US2 (reprendre à proximité, P1), US3 (glisser-déposer, P2), US4 (stock commun, P2)

## Path Conventions

Projet Roblox/Rojo unique : `src/` à la racine du dépôt, structure exacte définie dans [plan.md](./plan.md) § Project Structure. Les comportements décrits (crochets, rangement, reprise) sont détaillés dans [research.md](./research.md) R1 à R9, [data-model.md](./data-model.md) et [contracts/server-api.md](./contracts/server-api.md).

---

## Phase 1: Setup (données partagées)

**Purpose**: Étendre les modules de données partagés (`Settings`, `Types`, `Strings`, `RefPoints`, `Remotes`) avec les identifiants et réglages du stockage, avant toute logique serveur ou client.

- [X] T001 Ajouter le domaine `Storage` dans `src/ReplicatedStorage/Shared/Config/Settings.luau`, après `Craft`, avec commentaires en français : `Capacity` (12, 1–16, `kind = "integer"`), `Columns` (4, 1–8, `kind = "integer"`), `SlotSpacing` (2, 1.5–4), `InteractRange` (6, 3–7), `FullNoticeCooldown` (2, 0–10), `IndicatorDistance` (40, 10–100) — valeurs, bornes et justifications exactes dans [contracts/config.md](./contracts/config.md)
- [X] T002 Ajouter `"Storage"` à l'union `Types.RefPointId` dans `src/ReplicatedStorage/Shared/Types.luau` (aucun nouveau `RejectCode` : `TooFar` existe déjà)
- [X] T003 [P] Ajouter `"Storage"` à la liste `IDS` dans `src/ReplicatedStorage/Shared/World/RefPoints.luau` (dépend de T002)
- [X] T004 [P] Ajouter dans `src/ReplicatedStorage/Shared/Strings.luau` : `["Storage.Fill"] = "Stockage {count}/{capacity}"`, `["Notify.StorageFull"] = "Stockage plein ({capacity}) : reprenez un objet avant d'en ranger un autre."`, `["Pointer.Retrieve"] = "[F] Reprendre {resource}"`
- [X] T005 [P] Ajouter `"StorageFull"` à `Remotes.NotificationKinds` dans `src/ReplicatedStorage/Shared/Net/Remotes.luau`, avec un commentaire (« stockage plein : le pipeline ne renvoie jamais ses refus au client », patron de `BagFull`) — **aucune** intention n'est ajoutée à `Remotes.Intents`

**Checkpoint** : les identifiants et réglages nécessaires existent ; aucune logique de jeu encore branchée.

---

## Phase 2: Foundational (lieu, crochets et cœur du stockage — bloquant)

**Purpose**: Construire le lieu, le mécanisme de crochets par nœud et le cœur de `StorageService` dont **toutes** les user stories dépendent : emplacements, apparition d'un objet figé, protection à la reprise, état répliqué, remise à zéro. Aucun geste joueur n'est encore branché sur le rangement.

**⚠️ CRITICAL**: Aucune user story ne peut être validée avant la fin de cette phase.

- [X] T006 Ajouter `Storage = { cframe = CFrame.new(-13.5, 1.1, 14) }` dans `Layout.RefPoints` de `src/ServerScriptService/Server/World/Layout.luau`, avec un commentaire (coordonnées hand-matchées au décor : centre de `StorageZoneFloor` dans `Assets/Catalog.luau` ; 1,1 = dessus du sol de la zone, soit `FLOOR_TOP + 0,06 + 0,04`, la hauteur de pose des objets rangés) (dépend de T002, T003)
- [X] T007 [P] Dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau`, libérer la zone pour la grille (4 × 3 cellules de 2 studs, x ∈ [-17,5 ; -9,5], z ∈ [11 ; 17]) : **retirer** les trois `StorageCrate` et la `StoragePallet`, **conserver** `StorageZoneEdge`, `StorageZoneFloor`, les deux `StorageShelfPost` et les trois `StorageShelfBoard` (contre le mur ouest, hors grille) ; mettre à jour le commentaire du bloc (« visuel du coin ; les emplacements des objets rangés sont calculés par StorageService ») et retirer la couleur `Crate` devenue inutile (recherche R3)
- [X] T008 Dans `src/ServerScriptService/Server/Services/ForestService.luau`, ajouter les crochets par nœud (recherche R2) : `export type NodeHooks = { canTake: (player: Player) -> Types.RejectCode?, onTaken: () -> () }` ; un champ optionnel `hooks: NodeHooks?` dans `NodeState` ; `ForestService.attachHooks(part: BasePart, hooks: NodeHooks)` (retrouve le nœud par l'attribut `NodeId`, sans effet s'il est inconnu) ; `ForestService.checkTake(player: Player, part: BasePart): Types.RejectCode?` (renvoie `nil` si le nœud est inconnu ou sans crochet, sinon le résultat de `hooks.canTake(player)`) ; `ForestService.releaseHooks(part: BasePart)` (appelle `onTaken` une seule fois puis met `hooks` à `nil`, sans effet sans crochet). Un nœud sans crochet doit se comporter **exactement** comme aujourd'hui
- [X] T009 Dans `src/ServerScriptService/Server/Services/ForestService.luau`, brancher les crochets dans le gestionnaire `HarvestResource` (dépend de T008), dans cet ordre : refus existants (nœud connu, `NodeUnavailable`, `AlreadyCarried`) → **`ForestService.checkTake(player, node.part)`** et renvoi de son rejet s'il y en a un (avant `BagNotEquipped` : un joueur hors de portée reçoit `TooFar`, pas une explication sur son sac) → `BagNotEquipped` → `addPersonal` / `BagFull` / `InventoryFull` → **`ForestService.releaseHooks(node.part)`** juste après l'ajout au sac réussi et avant `retire(...)`
- [X] T010 [P] Dans `src/ServerScriptService/Server/Services/CarryService.luau`, brancher les crochets dans le gestionnaire `GrabItem` (dépend de T008) : après le refus `AlreadyCarried` et avant `release(player, nil)`, appeler `ForestService.checkTake(player, part)` et renvoyer son rejet ; une fois la saisie acquise (`attach`, propriété réseau), appeler `ForestService.releaseHooks(part)`. Aucun besoin de sac : la reprise tirée à la souris ne passe pas par lui (FR-018)
- [X] T011 Créer `src/ServerScriptService/Server/Services/StorageService.luau` (`--!strict`, `{ Name = "StorageService", Priority = 54 }`) — cœur du service (dépend de T001, T003, T006, T008) : requires (`Config`, `Log`, `Strings`, `Types`, `ForestService`, `InventoryService`, `MatchService`, `NotifyService`, `WorldService`) ; état `slots: { [number]: { part: BasePart, resourceType: Types.ResourceType }? }` ; `slotPosition(index)` selon la formule de [data-model.md](./data-model.md) (grille `Storage.Columns` × rangées `ceil(Capacity / Columns)`, pas `Storage.SlotSpacing`, centrée sur le point de référence, hauteur = celle du point de référence) ; `lowestFreeIndex()` ; `publish()` qui écrit `Count`/`Capacity` sur `ReplicatedStorage.StorageState` ; `Init` : retrouver `WorldService.refPoint("Storage")` (absent → `error(...)` « stockage désactivé », comme `buildCraftPrompt`), créer le dossier `StorageState`, se connecter à `MatchService.MatchStarting` pour vider `slots` et republier, journaliser `Stockage prêt (%d emplacements)`
- [X] T012 Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter la fonction interne `placeStored(resourceType): number?` (dépend de T011) : prend `lowestFreeIndex()` (renvoie `nil` si plein), appelle `ForestService.spawnDrop(resourceType, slotPosition(index))` (`nil` → renvoie `nil`, rien n'a changé), retrouve la pièce avec `ForestService.findNode`, **fige** le nœud (toutes les `BasePart` du modèle `Anchored = true`, `CanCollide = false`), pose les attributs `Stored = true` et `StoredSlot = index`, attache les crochets via `ForestService.attachHooks` — `canTake(player)` : personnage absent → `"NoCharacter"`, distance **horizontale** joueur ↔ point de référence supérieure à `Storage.InteractRange` → `"TooFar"`, sinon `nil` ; `onTaken()` : libérer `slots[index]`, retirer `Stored`/`StoredSlot`, rendre `CanCollide = true` aux pièces (si le modèle existe encore) et `publish()` — puis enregistre `slots[index]`, `publish()` et renvoie `index`
- [X] T013 Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter au `Init` les vérifications de démarrage de [contracts/server-api.md](./contracts/server-api.md) § « Vérifications au démarrage » (dépend de T011), chacune journalisée sans interrompre les autres systèmes : zone du stockage chevauchant celle de l'établi (`distance < Storage.InteractRange + Craft.InteractRange`, via `WorldService.refPoint("Workbench")`) → `log:error` ; `Storage.InteractRange` + rayon de la grille au-delà de `Forest.HarvestRange + Net.DistanceTolerance` moins une marge verticale de 1 stud → `log:warn` ; grille (`rangées × SlotSpacing`) plus profonde que les 8 studs de la zone → `log:warn`

**Checkpoint** : le point de référence existe, la zone est libre, `StorageService` démarre sans erreur (`Stockage prêt (12 emplacements)`, journal de démarrage sans avertissement), `ReplicatedStorage.StorageState` existe avec `Count = 0`. La récolte d'un nœud ordinaire et la saisie d'un objet lâché au sol se comportent exactement comme avant.

---

## Phase 3: User Story 1 - Ranger un objet du sac près du coin de stockage et le voir figé (Priority: P1) 🎯 MVP

**Goal**: Un joueur, son sac en main, lâche un objet près du coin de stockage : il apparaît figé sur un emplacement libre au lieu de tomber au sol ; l'appui long range tout le sac ; le stock plein refuse proprement.

**Independent Test**: avec plusieurs objets dans le sac, aller au coin, appuyer brièvement sur G — le dernier objet ramassé quitte le sac et apparaît immobile sur l'emplacement 1 ; un appui long range le reste ; un objet rangé ne réagit ni aux joueurs qui passent ni à une reprise depuis trop loin (`TooFar`) ; un coin plein refuse sans perdre d'objet (quickstart S1, S2, S3, S7).

- [X] T014 [US1] Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter `notifyFull(player)` (dépend de T012) : envoie `NotifyService.send(player, "StorageFull", { capacity = Config.get("Storage", "Capacity") })` au plus une fois toutes les `Storage.FullNoticeCooldown` secondes par joueur (table `lastFullNotice: { [Player]: number }` sur `os.clock()`) ; nettoyer l'entrée sur `Players.PlayerRemoving` — un appui long avec un sac plein ne doit pas répéter le message à chaque objet (recherche R8)
- [X] T015 [US1] Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter et exporter `StorageService.tryStoreFromBag(player, resourceType): boolean` (dépend de T012, T014) : personnage absent ou distance **horizontale** joueur ↔ point de référence > `Storage.InteractRange` → `false` sans effet ; aucun emplacement libre → `notifyFull(player)` puis `false` ; `placeStored(resourceType)` (le nœud apparaît **avant** tout prélèvement) → `nil` → `false` sans avoir touché le sac ; sinon `InventoryService.depositResource(player, resourceType, 1)` (si le prélèvement renvoie 0, détruire le nœud fraîchement créé et libérer l'emplacement plutôt que dupliquer), `NotifyService.send(player, "ResourceDeposited", { amount = 1 })`, `true` (recherche R5)
- [X] T016 [US1] Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter l'indicateur de remplissage (dépend de T011) : dans `Init`, créer un `BillboardGui` `StorageIndicator` parenté au point de référence (`AlwaysOnTop = true`, `MaxDistance = Config.get("Storage", "IndicatorDistance")`, `StudsOffsetWorldSpace = Vector3.new(0, 6, 0)`, taille fixe en pixels, fond sombre semi-transparent) contenant un `TextLabel` en `Enum.Font.GothamBold` ; `publish()` en met le texte à jour avec `Strings.format("Storage.Fill", { count = ..., capacity = ... })` (recherche R8, FR-012)
- [X] T017 [US1] Dans `src/ServerScriptService/Server/Services/StationDepositService.luau`, requérir `StorageService` et, dans `tryDeposit`, essayer `StorageService.tryStoreFromBag(player, resourceType)` **juste après** `CraftService.tryPlaceFromBag` et **avant** la table `AUTO_DEPOSIT` (`return true` s'il a rangé) ; mettre à jour le commentaire d'en-tête (ordre établi → stockage → postes fixes, recherche R4) (dépend de T015)
- [X] T018 [P] [US1] Ajouter `"StorageFull"` à la liste `FEED_KINDS` de `src/StarterGui/HUD/Hud.client.luau`, avec un commentaire (« retour du refus de rangement, comme BagFull ») — le texte vient de `Notify.StorageFull` (T004) (dépend de T004, T005)
- [X] T019 [P] [US1] Ajouter une entrée `StorageFull` dans la table `SFX` de `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SfxController.luau`, avec le même identifiant sonore et les mêmes réglages que `BagFull` (un refus existant, aucun nouvel asset) (dépend de T005)
- [X] T020 [US1] Valider manuellement dans Studio les scénarios S1 (rangement bref, plus bas index libre, aucun objet ne passe par le sol), S2 (appui long, plus récent d'abord), S3 (objet figé : on marche au travers ; F et clic maintenu depuis hors de portée n'ont aucun effet, `TooFar` dans `Dev.GetRejections`) et S7 (12 emplacements pleins : rien ne disparaît, un seul message par cadence, l'indicateur reste à 12/12) de [quickstart.md](./quickstart.md)

**Checkpoint** : US1 fonctionnelle et testable indépendamment — le stock se remplit et se lit à l'œil. Les objets ne peuvent pas encore être repris **vers le sac avec un indice dédié** (US2), mais le mécanisme de reprise de la phase 2 fonctionne déjà.

---

## Phase 4: User Story 2 - Récupérer un objet rangé, uniquement à proximité (Priority: P1)

**Goal**: Un joueur proche du coin reprend un objet rangé soit vers son sac (touche de ramassage), soit tiré à la souris hors du coin ; depuis trop loin, rien ne se passe.

**Independent Test**: après avoir rangé un objet (US1), tenter de le reprendre avec F puis par glisser depuis trois distances : tout près, juste au-delà de la portée, très loin — seul « tout près » réussit avec chacun des deux gestes ; le sac plein ou rangé refuse F sans perdre l'objet, mais n'empêche pas de le tirer (quickstart S4, S5).

**Note** : la reprise elle-même (garde de portée, libération de l'emplacement, collision rendue) est portée par le mécanisme de crochets des phases 2 et 3 (T008 à T012) : la récolte (F) et la saisie (clic maintenu) existent déjà. Cette story ajoute l'indice de visée et **valide** ces deux chemins de bout en bout.

- [X] T021 [P] [US2] Dans `showHint` de `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PointerController.luau`, dans la branche qui affiche `Pointer.Collect` (sac en main et de la place), afficher `Strings.format("Pointer.Retrieve", { resource = Strings.format(`Resource.{resourceType}`) })` à la place quand `part:GetAttribute("Stored") == true` ; les indices `Pointer.NeedBag` et `Pointer.BagFull` restent inchangés (dépend de T004)
- [X] T022 [US2] Valider manuellement dans Studio les scénarios S4 (F depuis trois distances ; sac plein puis sac rangé refusés comme un ramassage au sol, l'objet reste rangé, l'indicateur baisse d'un à chaque reprise) et S5 partie (a) (tirer un objet hors du coin : l'emplacement se libère dès la saisie, même sac rangé ou plein ; relâché au sol hors du coin il devient un objet ordinaire ramassable) de [quickstart.md](./quickstart.md) ; les parties (b) et (c) de S5 (re-ranger, déposer sur l'établi) se valident avec T025

**Checkpoint** : US1 + US2 forment le MVP — on range, on voit, on reprend. Le coin est déjà utile en solo.

---

## Phase 5: User Story 3 - Ranger un objet du monde par glisser-déposer (Priority: P2)

**Goal**: Un objet posé au sol, saisi à la souris et relâché au-dessus du coin de stockage, s'y range figé ; relâché ailleurs il reste simplement posé ; un coin plein le laisse où il est.

**Independent Test**: déposer un objet au sol à quelques pas du coin (G), le saisir à la souris et le relâcher au-dessus du coin — il disparaît du sol et apparaît figé sur un emplacement ; le relâcher ailleurs le laisse posé (quickstart S6).

- [X] T023 [US3] Dans `src/ServerScriptService/Server/Services/StorageService.luau`, ajouter et exporter `StorageService.tryStoreCarried(player, part): boolean` (dépend de T012, T014) : lire `part:GetAttribute("ResourceType")` (chaîne valide, sinon `false`) ; distance **horizontale** entre `part.Position` et le point de référence > `Storage.InteractRange` → `false` sans effet ; aucun emplacement libre → `notifyFull(player)` puis `false` ; **ordre sûr (principe VI)** : d'abord `placeStored(resourceType)` (`nil` → `false`, l'objet du monde n'est pas touché), **ensuite** `ForestService.consumeNode(part)` (`nil` → l'objet n'est plus disponible : détruire le nœud figé qu'on vient de créer, libérer l'emplacement, `false`) ; puis `ResourceDeposited` et `true`. Un nœud naturel de forêt est traité comme récolté et réapparaît selon les règles habituelles (spec, cas limites)
- [X] T024 [US3] Dans `src/ServerScriptService/Server/Services/CarryService.luau`, requérir `StorageService` et, dans `ReleaseItem`, après `CraftService.tryPlaceCarried(player, carry.part)`, appeler `StorageService.tryStoreCarried(player, carry.part)` **seulement si** l'établi n'a rien pris (`if not CraftService.tryPlaceCarried(...) then StorageService.tryStoreCarried(...) end`) ; mettre à jour le commentaire du site d'appel (dépend de T023)
- [X] T025 [US3] Valider manuellement dans Studio les scénarios S6 (objet relâché au-dessus du coin : rangé sans passer par le sac ; relâché en dehors : posé là ; coin plein : reste où il est + message ; ressource naturelle glissée : rangée, le nœud d'origine réapparaît) et S5 parties (b) et (c) (un objet tiré hors du coin puis relâché au-dessus du coin est rangé de nouveau ; relâché sur l'établi il compte comme ingrédient) de [quickstart.md](./quickstart.md)

**Checkpoint** : les deux façons de ranger et les deux façons de reprendre fonctionnent ; un objet circule librement entre sac, sol, établi et stock.

---

## Phase 6: User Story 4 - Un stock commun à toute l'équipe (Priority: P2)

**Goal**: Plusieurs joueurs voient le même stock, y rangent et y reprennent ; les actions simultanées ne perdent ni ne dupliquent aucun objet ; les objets d'un joueur parti restent.

**Independent Test**: à deux clients, l'un range un objet et l'autre le voit au même emplacement puis le reprend ; les deux rangent au même instant quand un seul emplacement est libre : exactement un objet est rangé (quickstart S8, S9).

- [X] T026 [US4] Passer en revue `src/ServerScriptService/Server/Services/StorageService.luau` pour la concurrence (recherche R9, FR-011) : aucune attente (`task.wait`, `WaitForChild`, `Instance.new(...)` en boucle bloquante) entre le choix de l'emplacement (`lowestFreeIndex`) et son enregistrement dans `slots` — `placeStored` est une section sans point d'attente ; vérifier que `onTaken` est idempotent (appelé au plus une fois par `releaseHooks`) et qu'un nœud détruit entre-temps (partie relancée) ne lève pas d'erreur (`part.Parent == nil`) ; confirmer qu'aucun état n'est rattaché à un joueur en dehors de `lastFullNotice` (nettoyé sur `PlayerRemoving`, T014) : le stock est commun, les objets d'un joueur parti restent
- [ ] T027 [US4] Valider manuellement dans Studio avec **deux clients** (« Clients and Servers ») les scénarios S8 (le second joueur voit l'objet rangé en moins d'une seconde et le reprend ; les objets d'un joueur parti restent disponibles) et S9 (dernier emplacement visé au même instant par deux joueurs : exactement un objet rangé, l'autre reste au joueur ; même objet repris au même instant : un seul l'obtient ; comptabilité sac A + sac B + sol + stock constante sur 50 cycles) de [quickstart.md](./quickstart.md). **Non faite** : les outils de test disponibles ne pilotent qu'un seul client. Simulation mono-client réussie (deux rangements dans la même frame pour un seul emplacement libre : un seul aboutit, l'autre retombe au sol, aucune perte ni copie) ; la vue partagée et la vraie concurrence à deux joueurs restent à valider manuellement dans Studio « Clients and Servers »

**Checkpoint** : les quatre user stories fonctionnent indépendamment et ensemble.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cycle de vie, autorité, performances et contrôles statiques transverses.

- [X] T028 Valider manuellement dans Studio le scénario S10 de [quickstart.md](./quickstart.md) : ranger quelques objets, terminer la partie (`Dev.EndMatch`) puis en relancer une — le coin est vide (`StorageState.Count = 0`, aucun objet figé, indicateur « Stockage 0/12 ») et aucune erreur de crochet dans la sortie
- [X] T029 Valider les scénarios S11 (autorité : relire `StorageService.luau`, aucune intention enregistrée ; un attribut `Stored` modifié côté client ne débloque rien ; journal de démarrage propre ; `Dev.TestVisualFallback` : le rangement fonctionne avec le remplaçant en primitives, rien n'est prélevé si l'apparition échoue) et S12 (`grep -rn "math.random" src` → seule occurrence préexistante `SfxController.luau` ; `selene src` et `stylua --check` sans écart sur les fichiers nouveaux ou modifiés ; comportement de `BagService` et `InventoryService` inchangé) de [quickstart.md](./quickstart.md)
- [X] T030 [P] Contrôler les performances avec les 12 emplacements pleins (SC-007) : Script Performance / MicroProfiler de Studio sur `src/ServerScriptService/Server/Services/StorageService.luau` et les scripts client touchés (`Hud.client.luau`, `PointerController.luau`) — aucune boucle par frame ni `Heartbeat` ajoutés, aucune baisse visible de fluidité ; idéalement avec plusieurs clients (6 recommandé avant chaque jalon, Definition of Done de la constitution). **Mesuré** (Studio, 1 client) : 16,66 ms/frame serveur avec 1 objet figé, 16,67 ms avec 12 (60 fps dans les deux cas), aucune boucle par frame ajoutée ; le MicroProfiler et un test à 6 clients ne sont pas faits — à reprendre avant le jalon
- [X] T031 [P] Cocher la checklist de fin de [quickstart.md](./quickstart.md) au fil des validations et ajouter en tête de `src/ServerScriptService/Server/Services/StorageService.luau` un commentaire d'en-tête en français (rôle du service, renvoi à `specs/010-coin-stockage/`, principe III : aucune intention réseau, tout est décidé côté serveur) au style des autres services

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — peut démarrer immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — BLOQUE toutes les user stories.
- **User Stories (Phase 3-6)** : dépendent toutes de Foundational. US1 → US2 → US3 → US4 en ordre de priorité, mais voir ci-dessous : elles partagent `StorageService.luau` et se mènent donc en séquence sur ce fichier.
- **Polish (Phase 7)** : dépend des user stories qu'on souhaite couvrir (au moins US1 + US2 pour S10 à S12).

### User Story Dependencies

- **US1 (P1)** : démarre après Foundational — aucune dépendance sur les autres stories.
- **US2 (P1)** : démarre après Foundational, mais **se teste** avec les objets rangés par US1 (rien à reprendre sans rangement) — US1 doit être validée d'abord.
- **US3 (P2)** : démarre après Foundational ; le rangement par glisser-déposer est indépendant de US1 et de US2 dans son code, mais sa validation (T025) réutilise la reprise de US2 pour la partie « tiré puis re-rangé ».
- **US4 (P2)** : ne demande **aucun code neuf** hors la revue T026 — la vue partagée et la concurrence découlent du fait que les objets rangés sont des nœuds répliqués et que les gestionnaires serveur s'exécutent l'un après l'autre ; sa validation (T027) requiert US1 et US2.

### Fichiers touchés par plusieurs tâches (éditions séquentielles, jamais [P])

- `StorageService.luau` : T011 → T012 → T013 → T014 → T015 → T016 → T023 → T026 → T031.
- `ForestService.luau` : T008 → T009.
- `CarryService.luau` : T010 → T024.
- `StationDepositService.luau` : T017 seul. `PointerController.luau` : T021 seul.

### Parallel Opportunities

- Setup : T003, T004 et T005 en parallèle (fichiers différents) après T002 pour T003.
- Foundational : T006 et T007 en parallèle (`Layout.luau` / `Catalog.luau`) ; T009 (`ForestService`) et T010 (`CarryService`) en parallèle une fois T008 fait ; T011 peut démarrer dès que T001, T003, T006 et T008 sont faits.
- US1 : T018 (`Hud.client.luau`) et T019 (`SfxController.luau`) en parallèle de T014 à T017 (fichiers différents, aucune dépendance sur `StorageService.luau`).
- US2 : T021 (`PointerController.luau`) peut être fait avant même T020.
- Polish : T030 et T031 en parallèle.

---

## Parallel Example: Foundational

```bash
# Après T005 (données partagées prêtes) :
Task: "Layout.RefPoints.Storage dans Layout.luau"
Task: "Retirer caisses et palette du décor dans Catalog.luau"

# Après T008 (API des crochets dans ForestService) :
Task: "Brancher les crochets dans HarvestResource (ForestService.luau)"
Task: "Brancher les crochets dans GrabItem (CarryService.luau)"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Compléter Phase 1 : Setup
2. Compléter Phase 2 : Foundational (CRITIQUE — bloque toutes les stories)
3. Compléter Phase 3 : User Story 1 (ranger et voir figé)
4. **ARRÊTER ET VALIDER** : S1, S2, S3, S7
5. Compléter Phase 4 : User Story 2 (reprendre à proximité) → **ARRÊTER ET VALIDER** S4, S5(a)
6. US1 seule ne livre pas de valeur complète (on range sans indice de reprise) : le MVP réel est **US1 + US2**, deux stories P1

### Incremental Delivery

1. Setup + Foundational → coin prêt, mécanisme de crochets en place, aucun geste branché
2. + US1 → on range depuis le sac et on voit le stock figé
3. + US2 → on reprend à proximité (vers le sac ou tiré) — **MVP**
4. + US3 → on range par glisser-déposer ; l'objet circule librement entre les postes
5. + US4 → le stock commun est validé à deux clients (vue partagée, concurrence)
6. + Polish → cycle de vie, autorité, performances, contrôles statiques

## Notes

- [P] = fichiers différents, aucune dépendance non résolue.
- Le label [Story] ne s'applique qu'aux phases 3 à 6 ; Setup, Foundational et Polish n'en portent pas.
- Aucune tâche de test automatisé : validation manuelle dans Studio uniquement, comme 006 à 009.
- Aucune nouvelle intention réseau : le stock réutilise `DropBag`/`DropOneItem`, `ReleaseItem`, `HarvestResource` et `GrabItem` (plan.md, Constitution Check principe III).
- Après chaque tâche de code : `stylua` sur les fichiers touchés puis `selene src` ; rappel de l'environnement de test — après une modification côté client (`PointerController`, `Hud`, `Sfx`), relancer la partie de test Studio pour recharger les scripts, et attendre la synchronisation Rojo avant de tester.
