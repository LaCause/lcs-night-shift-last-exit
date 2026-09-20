---

description: "Task list template for feature implementation"
---

# Tasks: Nuits optionnelles après réparation du bus

**Input**: Documents de conception de `specs/007-nuits-optionnelles-evasion/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001` à `006`).

**Organisation** : les tâches sont groupées par user story (P1/P2/P3 de `spec.md`) pour permettre
une implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1, US2, US3)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle (001 à 006) reste intact avant d'y greffer cette
fonctionnalité. Aucune nouvelle dépendance, aucun nouvel outil.

- [X] T001 Vérifier que le projet compile toujours :
      `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans erreur
      (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : le correctif de progression des nuits (research R2), sans lequel aucune nuit
supplémentaire ne peut fonctionner correctement au-delà de la première.

**⚠️ CRITICAL** : aucune des trois user stories ne peut être validée avec confiance avant que
cette phase soit terminée — en particulier US2, qui en dépend directement.

- [X] T002 Dans `advance()`, remplacer `enterPhase("Escape", state.totalNights)` par
      `enterPhase("Escape", state.night)` dans la branche `elseif phase == "Night"` (transition
      normale vers l'Évasion). Sans effet sur le flux normal (`state.night == state.totalNights`
      à cet instant, toujours) ; nécessaire pour que la phase Évasion conserve le bon numéro de
      nuit après une ou plusieurs nuits supplémentaires (research R2) — dans
      `src/ServerScriptService/Server/Services/MatchService.luau`

**Checkpoint** : la progression des nuits reste correcte quel que soit le nombre de nuits
supplémentaires déjà jouées. Les trois user stories peuvent commencer.

---

## Phase 3 : User Story 1 - Partir dès que possible (Priority: P1) 🎯 MVP

**Goal** : une fois le seuil minimum de nuits survécu et le bus réparé, l'équipe voit
explicitement l'option de partir et peut la déclencher elle-même — pour la première fois, sans
outil de développement (`DepartBus` n'a aujourd'hui aucun déclencheur joueur : ni prompt, ni
bouton).

**Independent Test** : survivre au seuil minimum, réparer le bus, voir l'option de départ
s'afficher au bus avec sa récompense, la déclencher, obtenir la victoire — quickstart.md C1, C5.

### Implementation for User Story 1

- [X] T003 [P] [US1] Ajouter les textes du choix d'évasion : `["Hud.Escape.Title"] = "Bus prêt"`
      et `["Hud.Escape.Depart"] = "Partir maintenant (+{amount} jetons)"` — dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T004 [US1] Dans `BusService.luau`, ajouter une fonction `buildEscapePrompts()` (appelée
      depuis `Init()`, aux côtés de `buildRepairPrompt()`) qui crée un `ProximityPrompt`
      `DeparturePrompt` sur le point de référence `BusSpot` (`Intent = "DepartBus"`,
      `Target = BUS_ID`, même portée que `Config.get("Bus", "DepartureRange")`), initialement
      `Enabled = false`. Basculer `Enabled = repaired` partout où `repaired` change déjà
      aujourd'hui (`deposit`, `forceRepair`, `resetForNewMatch`) — **sans aucune condition de
      phase** : ce prompt doit rester utilisable dès la réparation, même avant le seuil minimum
      de nuits (FR-008, ne pas régresser le départ anticipé déjà permis aujourd'hui) — dans
      `src/ServerScriptService/Server/Services/BusService.luau` (aucun changement client
      nécessaire : `InteractionController.luau` relaie déjà tout `ProximityPrompt` portant
      l'attribut `Intent`, research R5)
- [X] T005 [US1] Étendre `BusRepairController.luau` : quand `state.busRepaired`, afficher le
      titre (`Hud.Escape.Title`) et l'option de départ (`Hud.Escape.Depart`) avec sa récompense
      prévisionnelle `Config.get("Currency", "EscapeBonusPerNight") * matchState.night`
      (`data-model.md`), en plus (pas à la place) du statut « Réparé » déjà affiché — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BusRepairController.luau`
      (dépend de T003, T004)

**Checkpoint** : un départ réel, déclenchable par un joueur, avec sa récompense visible avant de
décider — US1 testable indépendamment de US2 (rester) et US3 (défaite pendant une nuit
supplémentaire).

---

## Phase 4 : User Story 2 - Rester pour une nuit de plus (Priority: P2)

**Goal** : au lieu de partir, l'équipe peut choisir de rester une nuit supplémentaire pour une
récompense strictement supérieure, avec un danger strictement croissant ; le même choix se
représente après chaque nuit supplémentaire survécue, sans plafond.

**Independent Test** : depuis l'écran de choix (US1), déclencher « rester », survivre à une
nuit avec des ennemis mesurablement plus dangereux, revoir le même choix, recommencer plusieurs
fois de suite — quickstart.md C2, C3 (le scénario qui valide le correctif de Phase 2), C6, C7.

### Implementation for User Story 2

- [X] T006 [P] [US2] Ajouter au domaine `Enemy` de `Settings.luau` : `ExtraNightDamageGrowth`
      (défaut 5, bornes 0–50) et `ExtraNightSpeedGrowth` (défaut 1, bornes 0–10) — voir
      contracts/config.md pour la justification des valeurs — dans
      `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T007 [US2] Ajouter `MatchService.pushExtraNight(): boolean` : si `state.phase ~= "Escape"`,
      ne rien faire et renvoyer `false` (même convention que `endMatch`) ; sinon appeler
      `enterPhase("Day", state.night + 1)` et renvoyer `true` — dans
      `src/ServerScriptService/Server/Services/MatchService.luau` (dépend de T002 ; même fichier,
      donc après lui)
- [X] T008 [US2] Dans `BusService.luau` : extraire la vérification de présence d'équipe (joueurs
      `Alive`, `HumanoidRootPart` à portée) actuellement en ligne dans le handler `DepartBus` en
      fonction locale `teamReadyAtBus(range: number): boolean`, réutilisée par `DepartBus`
      (comportement inchangé, FR-002/FR-008) ; ajouter l'intention `PushNight` (payload
      `{ target: string }`) : `payload.target ~= BUS_ID` → `TargetMissing`,
      `MatchService.getPhase() ~= "Escape"` → `WrongPhase`, `not repaired` → `BusNotRepaired`,
      `not teamReadyAtBus(...)` → `TeamNotReady`, sinon `MatchService.pushExtraNight()`. Ajouter
      un second `ProximityPrompt` `StayPrompt` sur `BusSpot` (`Intent = "PushNight"`,
      `Target = BUS_ID`), dont `Enabled` est basculé à `phase == "Escape" and repaired`
      (contrairement à `DeparturePrompt`, celui-ci DOIT rester désactivé avant le seuil minimum —
      FR-011) via les mêmes points de bascule que T004, plus un abonnement à
      `MatchService.PhaseStarted`/`PhaseEnded` — dans
      `src/ServerScriptService/Server/Services/BusService.luau` (dépend de T004, même fichier,
      donc après lui ; dépend de T007)
      — **écart constaté en direct** : `PushNight` devait aussi être déclarée dans
      `src/ReplicatedStorage/Shared/Net/Remotes.luau` (`phases = { "Escape" }`, comme
      `DepartBus`) — oubliée dans le découpage initial de cette tâche, `NetService` refuse
      d'enregistrer toute intention non déclarée là (`BusService.Init()` échouait entièrement au
      premier lancement). Corrigé, et `DeparturePrompt.Enabled` aligné sur la même condition que
      `StayPrompt` (`repaired and phase == "Escape"`) une fois découvert que `DepartBus` était
      déjà restreint à l'Évasion (voir `quickstart.md`, Notes de vérification).
- [X] T009 [US2] Dans `EnemyService.luau` : calculer
      `extraNights = math.max(0, MatchService.getNight() - MatchService.getTotalNights())` dans
      `step()` ; dans `tryDamage`, remplacer la lecture directe de `Enemy.ContactDamage` par
      `Config.get("Enemy", "ContactDamage") + Config.get("Enemy", "ExtraNightDamageGrowth") *
      extraNights` ; dans `moveToward`, même substitution pour `Enemy.MoveSpeed` avec
      `ExtraNightSpeedGrowth` (`contracts/server-api.md`, `data-model.md`) — dans
      `src/ServerScriptService/Server/Services/EnemyService.luau` (dépend de T006)
- [X] T010 [US2] Ajouter le texte de l'option « rester » :
      `["Hud.Escape.Stay"] = "Rester une nuit (+{amount} jetons)"` — dans
      `src/ReplicatedStorage/Shared/Strings.luau` (dépend de T003 ; même fichier, donc après lui)
      — déjà fait dans le même geste que T003
- [X] T011 [US2] Étendre `BusRepairController.luau` : quand `matchState.phase == "Escape" and
      state.busRepaired`, afficher aussi l'option « rester » (`Hud.Escape.Stay`) avec sa
      récompense prévisionnelle `Config.get("Currency", "EscapeBonusPerNight") *
      (matchState.night + 1)`, à côté de l'option de départ déjà affichée par US1 — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BusRepairController.luau`
      (dépend de T005, même fichier, donc après lui ; dépend de T010) — déjà fait dans le même
      geste que T005

**Checkpoint** : le choix complet (partir/rester) fonctionne, se répète sans plafond, et le
danger comme la récompense progressent correctement à travers plusieurs nuits supplémentaires
consécutives (validé spécifiquement par C3, qui aurait échoué sans le correctif de la Phase 2).

---

## Phase 5 : User Story 3 - Conserver ses gains malgré l'échec (Priority: P3)

**Goal** : si l'équipe est éliminée pendant une nuit supplémentaire, elle ne perd que la
récompense potentielle de cette tentative — jamais les gains déjà acquis lors des nuits
précédentes.

**Independent Test** : choisir de rester, provoquer une défaite pendant cette nuit
supplémentaire, constater que le solde de jetons reste exactement celui d'avant la tentative —
quickstart.md C4.

**Note** : cette garantie est déjà entièrement satisfaite par construction dès la Phase 4
(research R7) — `CurrencyService` n'est touché par aucune tâche de cette fonctionnalité ; son
abonnement existant à `MatchService.MatchEnded` (qui ne crédite le bonus d'évasion que sur
`"Victory"`) et le chemin de défaite existant (`checkDefeat` → `endMatch("Defeat", ...)`,
inchangés) couvrent déjà entièrement ce cas. Cette phase ne contient donc qu'une vérification.

### Implementation for User Story 3

- [X] T012 [US3] Exécuter le scénario C4 de `quickstart.md` en Studio (choisir de rester, puis
      éliminer toute l'équipe pendant cette nuit supplémentaire) et confirmer que le solde de
      jetons affiché reste inchangé et qu'aucun bonus d'évasion n'est versé — aucun changement de
      code associé à cette tâche (dépend de la Phase 4 pour disposer d'une nuit supplémentaire à
      interrompre)

**Checkpoint** : les trois user stories sont indépendamment fonctionnelles et validées.

---

## Phase 6 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles statiques et validation manuelle finale, communes aux trois stories.

- [X] T013 [P] `selene src` et `stylua --check src` sur tous les fichiers nouveaux ou modifiés
      par cette fonctionnalité : aucun écart
- [X] T014 [P] Contrôle de non-régression : `grep -rn "math.random" src` → toujours la seule
      occurrence préexistante (`SfxController.luau`) ; aucune dans `pushExtraNight`, le calcul de
      `extraNights` ou les statistiques effectives de l'ennemi
- [X] T015 Exécuter les scénarios C1 à C8 de `quickstart.md` en Studio et cocher la « Checklist
      de fin » — C1 à C5 et C8 pleinement vérifiés ; C6 et C7 partiellement (voir Notes de
      vérification de `quickstart.md`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — **bloque une validation fiable des trois user
  stories**, en particulier US2.
- **User Story 1 (Phase 3)** : dépend de Foundational. Aucune dépendance sur US2/US3.
- **User Story 2 (Phase 4)** : dépend de Foundational (T002/T007) et réutilise le fichier étendu
  par US1 (`BusService.luau` via T004, `BusRepairController.luau` via T005, `Strings.luau` via
  T003) — séquentiel avec US1 sur ces trois fichiers, mais reste une story fonctionnellement
  distincte (US1 seule reste jouable sans elle).
- **User Story 3 (Phase 5)** : ne modifie aucun fichier (research R7) ; dépend de US2 pour avoir
  une nuit supplémentaire à interrompre pendant le test.
- **Polish (Phase 6)** : dépend des trois user stories livrées.

### Conflits de fichiers à respecter

- `src/ServerScriptService/Server/Services/MatchService.luau` : **T002 (Foundational) → T007
  (US2)** — séquentiel, jamais en parallèle.
- `src/ServerScriptService/Server/Services/BusService.luau` : **T004 (US1) → T008 (US2)** —
  séquentiel.
- `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/BusRepairController.luau` : **T005
  (US1) → T011 (US2)** — séquentiel.
- `src/ReplicatedStorage/Shared/Strings.luau` : **T003 (US1) → T010 (US2)** — séquentiel.
- `src/ServerScriptService/Server/Services/EnemyService.luau` (T009) et
  `src/ReplicatedStorage/Shared/Config/Settings.luau` (T006) ne sont touchés que par US2 : aucun
  conflit avec US1.

### Parallel Opportunities

- T003 (Strings, US1) peut démarrer en parallèle de T004 (BusService, US1) — fichiers distincts.
- T006 (Settings, US2) peut démarrer dès la fin de la Phase 2, en parallèle de tout le reste de
  US1 — fichier distinct, aucune dépendance sur US1.
- T013 et T014 (Polish) peuvent s'exécuter en parallèle l'une de l'autre.

## Implementation Strategy

**MVP = User Story 1 seule** : donne au jeu, pour la première fois, un moyen réel pour les
joueurs de déclencher leur propre victoire (le seul chemin existant aujourd'hui passe par un
outil de développement). Livrable et testable indépendamment de tout le reste de cette
fonctionnalité.

**Incrément suivant = User Story 2** : ajoute la mécanique de « push your luck » proprement dite
— sans elle, US1 seule n'apporte qu'une amélioration d'interface, pas de nouveau gameplay.

**Dernier incrément = User Story 3** : une vérification, pas du code — confirme que la garantie
déjà offerte par `006-monnaie-jetons-fidelite` s'étend correctement à ce nouveau cas sans rien
ajouter.
