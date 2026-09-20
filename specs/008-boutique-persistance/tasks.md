---

description: "Task list for 008-boutique-persistance"
---

# Tasks: Boutique et persistance entre parties

**Input**: Design documents from `/specs/008-boutique-persistance/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/server-api.md, contracts/config.md, quickstart.md

**Tests**: Non demandés explicitement dans la spec — validation manuelle via `quickstart.md` (C1–C9), pas de tâches de test automatisé générées.

**Organization**: Tâches groupées par user story (US1–US4, priorité P1→P4 de `spec.md`) pour permettre une implémentation et une validation indépendantes de chacune.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: peut s'exécuter en parallèle (fichiers différents, aucune dépendance non résolue)
- **[Story]**: user story concernée (US1, US2, US3, US4)

## Phase 1: Setup (données partagées)

**Objectif** : déclarer les données statiques et types partagés par toutes les stories, sans encore aucune logique serveur.

- [X] T001 [P] Ajouter `Owned_<Id>`/`Active_<Slot>` au vocabulaire de types : nouveau `BagType` `"MediumBag"` et 4 nouveaux `RejectCode` (`ItemUnknown`, `AlreadyOwned`, `InsufficientFunds`, `NotOwned`) dans `src/ReplicatedStorage/Shared/Types.luau`
- [X] T002 [P] Ajouter le réglage `Bag.MediumCapacity` (défaut 8, bornes 1–50, integer) et le nouveau domaine `Boutique` (`SaveRetryAttempts` défaut 3, `SaveRetryDelay` défaut 2) dans `src/ReplicatedStorage/Shared/Config/Settings.luau` (voir `contracts/config.md`)
- [X] T003 [P] Ajouter les clés `Strings.luau` pour le catalogue (noms/descriptions des 5 objets), les libellés du panneau boutique (acheter, déjà possédé, solde insuffisant, actif, choisir) et les refus (`ItemUnknown`, `AlreadyOwned`, `InsufficientFunds`, `NotOwned`) dans `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T004 [P] Créer le module de catalogue statique `src/ReplicatedStorage/Shared/Boutique/Catalog.luau` (`table.freeze`, patron `Recipes.luau`) avec les 5 objets de `data-model.md` (`BagTintRed`, `BagTintBlue`, `BusPaintTeal`, `CounterGlowPink`, `BiggerBag`) et une fonction `Catalog.find(itemId): Item?`

**Checkpoint** : types, réglages, libellés et catalogue disponibles — rien n'exécute encore de logique.

---

## Phase 2: Foundational (prérequis bloquants)

**Objectif** : le service `BoutiqueService` existe, se charge/sauvegarde comme `CurrencyService`, et les intentions réseau sont déclarées — aucune story ne peut être testée avant cette phase.

**⚠️ CRITIQUE** : aucune story ne peut démarrer avant la fin de cette phase.

- [X] T005 Déclarer les intentions `BuyItem` (`{ itemId: string }`) et `SetActiveCosmetic` (`{ itemId: string }`) dans la table `intents` de `src/ReplicatedStorage/Shared/Net/Remotes.luau` (`phases = nil`, aucune `target`, voir `contracts/server-api.md`)
- [X] T006 Créer `src/ServerScriptService/Server/Services/BoutiqueService.luau` : contrat `{Name = "BoutiqueService", Priority = 71, Init}` ; table `loaded: {[Player]: boolean}` ; `loadPlayer(player)` lisant le DataStore `PlayerBoutique` (clé = `tostring(player.UserId)`), posant les attributs `Owned_<Id>` et `Active_<Slot>` d'après `data-model.md`, avec repli sur un état vide en cas d'échec définitif (comme `CurrencyService`) ; `save(player)` asynchrone (`task.spawn`) avec `withRetry` borné par `Boutique.SaveRetryAttempts`/`SaveRetryDelay` ; abonnements `SessionService.PlayerJoined` (déclenche `loadPlayer`, puis marque `loaded[player] = true`) et `SessionService.PlayerLeft` (sauvegarde finale, nettoyage de `loaded`)
- [X] T007 [P] Ajouter `CurrencyService.spend(player: Player, amount: number): boolean` (additif) dans `src/ServerScriptService/Server/Services/CurrencyService.luau` — débite si `balanceOf(player) >= amount`, réutilise la fonction `save` privée déjà existante, ne change aucune signature existante
- [X] T008 [P] Ajouter `BagService.setType(player: Player, bagType: BagType): ()` (additif) et l'entrée `BAG_TYPES.MediumBag = { CapacitySetting = "MediumCapacity", VisualId = "LittleBag" }` (aucun nouvel asset, principe VIII) dans `src/ServerScriptService/Server/Services/BagService.luau` — `assignBag`/`defaultType` ne changent pas
- [X] T009 [P] Créer `src/ReplicatedStorage/Shared/Client/BoutiqueStateClient.luau` (même contrat que `GameplayStateClient` : `.get(): State`, `.Changed: Signal.Signal<()>`), `State` calculé en parcourant `Catalog.luau` et en lisant les attributs `Owned_*`/`Active_*`/`Currency` du joueur local à chaque appel (`data-model.md`, research R10)

**Checkpoint** : le socle existe (service, réseau, état client) — les user stories peuvent commencer.

---

## Phase 3: User Story 1 - Acheter un objet cosmétique (Priority: P1) 🎯 MVP

**Goal** : un joueur peut consulter le catalogue et acheter un objet, avec débit exact et blocage des cas invalides (FR-001 à FR-004, FR-006, FR-009, FR-012, FR-013).

**Independent Test** : avec un solde suffisant, ouvrir la boutique, acheter un objet cosmétique non possédé — le solde diminue exactement du prix, l'objet devient possédé et reste visible après avoir rejoint une nouvelle partie (`quickstart.md` C1, C2 partiel).

### Implementation for User Story 1

- [X] T010 [US1] Implémenter le handler `BuyItem` dans `src/ServerScriptService/Server/Services/BoutiqueService.luau` : `Catalog.find(itemId) == nil` → `ItemUnknown` ; `not loaded[player]` → `NotAllowed` ; déjà possédé → `AlreadyOwned` ; `CurrencyService.balanceOf(player) < item.Price` → `InsufficientFunds` ; sinon `CurrencyService.spend(...)`, `Owned_<itemId> = true`, si `Category == "Cosmetic"` alors `Active_<Slot> = itemId` (FR-006, la visibilité immédiate de US1 en dépend), sauvegarde en arrière-plan (`contracts/server-api.md`)
- [X] T011 [US1] Exposer les lectures publiques `BoutiqueService.isOwned(player, itemId): boolean` et `BoutiqueService.activeItem(player, slot): string?` dans `src/ServerScriptService/Server/Services/BoutiqueService.luau`
- [X] T012 [US1] Créer un contrôleur d'application visuelle des cosmétiques (recoloration des pièces `Bag`/`Bus`/`Counter` déjà existantes selon `BoutiqueStateClient.get().active`, primitives uniquement — principe VIII) dans `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BoutiqueCosmeticsController.luau`, connecté à `BoutiqueStateClient.Changed`
- [X] T013 [US1] Créer `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BoutiquePanelController.luau` : panneau listant le catalogue (`Catalog.luau`) avec nom, prix, description, état possédé/non-possédé, bouton Acheter appelant `NetClient.send("BuyItem", { itemId = ... })`, idiomes visuels de `DevPanel.client.luau` (research R11)
- [X] T014 [US1] Ajouter un bouton « Boutique » dans `src/StarterGui/HUD/Hud.client.luau` qui bascule la visibilité du panneau créé par `BoutiquePanelController.luau`

**Checkpoint** : US1 fonctionnelle et testable indépendamment (`quickstart.md` C1).

---

## Phase 4: User Story 2 - Choisir son cosmétique actif parmi ceux possédés (Priority: P2)

**Goal** : un joueur possédant plusieurs objets du même emplacement choisit lequel est actif, sans nouvel achat (FR-005, FR-007, SC-007).

**Independent Test** : posséder deux cosmétiques du même emplacement, changer l'actif depuis l'interface — seul le nouvel objet choisi s'affiche (`quickstart.md` C3).

### Implementation for User Story 2

- [X] T015 [US2] Implémenter le handler `SetActiveCosmetic` dans `src/ServerScriptService/Server/Services/BoutiqueService.luau` : `Catalog.find(itemId) == nil` ou `item.Category ~= "Cosmetic"` → `ItemUnknown` ; `not BoutiqueService.isOwned(player, itemId)` → `NotOwned` ; sinon `Active_<item.Slot> = itemId`, sauvegarde en arrière-plan (`contracts/server-api.md`)
- [X] T016 [US2] Étendre `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BoutiquePanelController.luau` : pour chaque emplacement possédant plusieurs objets possédés, afficher lequel est actif et permettre de sélectionner un autre objet déjà possédé via `NetClient.send("SetActiveCosmetic", { itemId = ... })`

**Checkpoint** : US1 + US2 fonctionnelles ensemble (`quickstart.md` C2, C3).

---

## Phase 5: User Story 3 - Démarrer avec un avantage acheté (Priority: P3)

**Goal** : un avantage de départ acheté (`BiggerBag`) s'applique automatiquement dès la partie suivante, sans action du joueur (FR-008, FR-010, SC-004).

**Independent Test** : acheter `BiggerBag`, rejoindre une nouvelle partie — la capacité de sac de départ est `Bag.MediumCapacity`, pas `Bag.SmallCapacity` (`quickstart.md` C4).

### Implementation for User Story 3

- [X] T017 [US3] Dans `src/ServerScriptService/Server/Services/BoutiqueService.luau`, à la résolution de `loadPlayer(player)` (après la pose des attributs `Owned_*`/`Active_*`), si `Owned_BiggerBag == true` alors appeler `BagService.setType(player, "MediumBag")` — après l'attribution par défaut de `BagService` sur `PlayerJoined`, jamais en s'appuyant sur l'ordre de connexion des écouteurs `Priority` (research R7, `Signal.luau` isole chaque écouteur dans son propre thread)

**Checkpoint** : US1 + US2 + US3 fonctionnelles ensemble (`quickstart.md` C4, C5).

---

## Phase 6: User Story 4 - Conserver ses achats malgré un redémarrage du serveur (Priority: P4)

**Goal** : objets possédés, objet actif par emplacement et solde survivent à un redémarrage complet du serveur (FR-011, FR-013, SC-005).

**Independent Test** : acheter un objet, choisir un objet actif différent du dernier acheté, arrêter puis relancer complètement le serveur de test, rejoindre en tant que le même joueur — tout est identique à avant l'arrêt (`quickstart.md` C6).

### Implementation for User Story 4

- [X] T018 [US4] Vérifier/compléter dans `src/ServerScriptService/Server/Services/BoutiqueService.luau` que `save(player)` écrit exactement la forme persistée `{ owned: {string}, active: {[string]: string} }` de `data-model.md` dans le DataStore `PlayerBoutique`, et que `PlayerLeft` déclenche une sauvegarde finale avant nettoyage de `loaded[player]`
- [X] T019 [US4] Valider manuellement le scénario C6 de `quickstart.md` (arrêt/relance complète du serveur de test, même joueur) et le scénario C7 (repli si `DataStoreService` échoue) ; consigner le résultat

**Checkpoint** : toutes les user stories fonctionnelles ensemble (`quickstart.md` C1–C7 conformes).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose** : contrôles transverses, alignement avec `quickstart.md` C8/C9.

- [X] T020 [P] Relire `BoutiqueService.luau` pour confirmer qu'aucune autorité n'est déléguée au client (`BuyItem`/`SetActiveCosmetic` revalident tout côté serveur) et qu'aucun code client ne modifie directement `Currency`/`Owned_*`/`Active_*` (`quickstart.md` C8)
- [X] T021 [P] Exécuter `selene src`, `stylua --check src` et `grep -rn "math.random" src` sur les fichiers nouveaux/modifiés ; corriger tout écart introduit par cette fonctionnalité (`quickstart.md` C9)
- [X] T022 Confirmer que le comportement par défaut de `BagService` (aucun avantage possédé) reste strictement inchangé et que la boucle reste jouable de bout en bout sans jamais utiliser la boutique (`quickstart.md`, Checklist de fin)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — peut démarrer immédiatement, toutes les tâches sont `[P]` (fichiers distincts)
- **Foundational (Phase 2)** : dépend de la Phase 1 (T004 pour T006, T001/T002 pour T005/T006) — **bloque** toutes les user stories
- **US1 (Phase 3)** : dépend de la Phase 2 complète
- **US2 (Phase 4)** : dépend de la Phase 2 complète ; T015/T016 dépendent aussi de T010/T013 (même fichiers `BoutiqueService.luau`/`BoutiquePanelController.luau`)
- **US3 (Phase 5)** : dépend de la Phase 2 complète (T006, T008) ; indépendante de US1/US2 dans son mécanisme, mais nécessite `Owned_BiggerBag` déjà posable par T006/T010
- **US4 (Phase 6)** : dépend de T006 (le mécanisme de sauvegarde existe déjà depuis la Phase 2) ; T019 nécessite US1 (T010) pour avoir quelque chose à persister
- **Polish (Phase 7)** : dépend de toutes les stories désirées étant complètes

### Parallel Opportunities

- T001–T004 (Setup) : tous `[P]`, fichiers distincts
- T007, T008, T009 (Foundational) : `[P]` entre eux, mais T006 (même service que T005 les précède logiquement bien que fichiers distincts)
- T020, T021 (Polish) : `[P]`, revues indépendantes

---

## Implementation Strategy

### MVP First (User Story 1 uniquement)

1. Compléter Phase 1 (Setup) et Phase 2 (Foundational)
2. Compléter Phase 3 (US1)
3. **Valider** : `quickstart.md` C1 — achat, refus solde insuffisant, refus si déjà possédé
4. Démontrable en l'état : un joueur peut acheter un cosmétique et le voir appliqué

### Incremental Delivery

1. Setup + Foundational → socle prêt
2. US1 → valider C1 → MVP démontrable
3. US2 → valider C2/C3 → sélection d'objet actif
4. US3 → valider C4/C5 → avantage de départ appliqué, défaite sans impact
5. US4 → valider C6/C7 → persistance confirmée au redémarrage
6. Polish → valider C8/C9 → autorité serveur et contrôles statiques confirmés
