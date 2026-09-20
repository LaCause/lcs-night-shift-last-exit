---

description: "Task list template for feature implementation"
---

# Tasks: Monnaie de base, gain par nuit et bonus d'évasion

**Input**: Documents de conception de `specs/006-monnaie-jetons-fidelite/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001` à `005`).

**Organisation** : les tâches sont groupées par user story (P1/P2/P3 de `spec.md`) pour permettre
une implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1, US2, US3)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle (001 à 005) reste intact avant d'y greffer cette
fonctionnalité. Aucune nouvelle dépendance, aucun nouvel outil.

- [X] T001 Vérifier que le projet compile toujours :
      `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans erreur
      (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée bloquant les trois user stories — le service qui portera
tout le crédit, et le canal qui rend son résultat observable. Aucune formule de gain ni de bonus
n'est encore branchée ici (research R3, R7).

**⚠️ CRITICAL** : aucune des trois user stories ne peut commencer avant que cette phase soit
terminée.

- [X] T002 [P] Ajouter le champ `currency: number` au type `State` et à
      `GameplayStateClient.get()` : `readAttr(player, "Currency", 0)`, exactement au même patron
      que `health`/`maxHealth` — dans
      `src/ReplicatedStorage/Shared/Client/GameplayStateClient.luau`
- [X] T003 Créer `CurrencyService.luau` (Priority 70), découvert automatiquement par le
      `Loader` : un `DataStore` dédié (`DataStoreService:GetDataStore("PlayerCurrency")`), une
      table privée `loaded: { [Player]: boolean }` (jamais répliquée, nettoyée sur
      `SessionService.PlayerLeft` — même patron que `InventoryService.order` en 005), et
      `balanceOf(player): number` (= `player:GetAttribute("Currency") or 0`). Dans `Init()`,
      s'abonner à `SessionService.PlayerJoined` : lancer un chargement asynchrone
      (`store:GetAsync(tostring(player.UserId))`, protégé par un seul `pcall` pour l'instant —
      la version à tentatives multiples est ajoutée en Phase 5, US3) ; poser l'attribut
      `Currency` **seulement après résolution** du chargement (valeur trouvée, ou `0` si absente
      ou en échec, avec un message de journal en cas d'échec) puis marquer
      `loaded[player] = true` — ne jamais poser un `0` par défaut avant cette résolution (research
      R7 : évite qu'un gain crédité pendant le chargement soit écrasé par le résultat tardif) —
      dans `src/ServerScriptService/Server/Services/CurrencyService.luau`

**Checkpoint** : un joueur qui rejoint voit son solde persistant (ou 0 pour un nouveau joueur)
posé sur son attribut `Currency`, visible via `GameplayStateClient` — sans qu'aucun gain ne soit
encore crédité nulle part. Les trois user stories peuvent commencer.

---

## Phase 3 : User Story 1 - Gagner de la monnaie en survivant (Priority: P1) 🎯 MVP

**Goal** : à la fin de chaque nuit survécue, le solde de monnaie du joueur augmente d'un montant
supérieur à celui de la nuit précédente.

**Independent Test** : lancer une partie, enchaîner plusieurs nuits avec `Dev.NextPhase`, et
constater dans le HUD que le solde augmente à chaque fin de nuit, d'un montant croissant —
quickstart.md C1 (et C4 pour le cas d'un rejoin tardif, couvert par la même boucle de crédit).

### Implementation for User Story 1

- [X] T004 [P] [US1] Ajouter le domaine `Currency` dans `Settings.luau` avec `NightlyBase`
      (défaut 10, bornes 1–500) et `NightlyGrowth` (défaut 5, bornes 0–200) — voir
      contracts/config.md pour la justification des valeurs — dans
      `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T005 [P] [US1] Ajouter le texte `["Hud.Currency"] = "Jetons fidélité"` — dans
      `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T006 [US1] Étendre `CurrencyService.luau` : ajouter une fonction pure locale
      `gain(night: number): number` = `Currency.NightlyBase + Currency.NightlyGrowth * (night -
      1)` ; ajouter une fonction privée `save(player)` qui lance une écriture asynchrone
      (`store:SetAsync(tostring(player.UserId), balanceOf(player))`, protégée par un seul
      `pcall` pour l'instant, journalisée en cas d'échec — la version à tentatives multiples est
      ajoutée en Phase 5, US3) ; s'abonner à `MatchService.PhaseEnded` dans `Init()` : quand
      `previousPhase == "Night"`, pour chaque joueur de `SessionService.all()` avec
      `loaded[joueur] == true`, incrémenter son attribut `Currency` de `gain(previousNight)` puis
      appeler `save(joueur)` — dans
      `src/ServerScriptService/Server/Services/CurrencyService.luau` (dépend de T003, T004 ;
      même fichier que T003, donc après lui)
- [X] T007 [P] [US1] Ajouter un indicateur de solde dans la colonne de droite du HUD (même
      colonne que le panneau Vie, `Strings.format("Hud.Currency")` + valeur de
      `GameplayStateClient.get().currency`, mis à jour comme tout le reste via
      `GameplayStateClient.Changed`) — dans `src/StarterGui/HUD/Hud.client.luau` (dépend de T002,
      T005)

**Checkpoint** : le gain nocturne croissant fonctionne et s'affiche ; US1 testable
indépendamment de l'évasion (US2) et de la persistance au redémarrage (US3).

---

## Phase 4 : User Story 2 - Bonus au moment de l'évasion (Priority: P2)

**Goal** : quand l'équipe réussit son évasion, chaque joueur présent reçoit un bonus
supplémentaire, proportionnel au nombre de nuits survécues cette partie-là.

**Independent Test** : mener une partie jusqu'à l'évasion réussie et constater qu'un montant
distinct des gains nocturnes déjà accumulés est crédité au moment précis du départ du bus, plus
élevé pour une partie plus longue — quickstart.md C2 (et C5 pour un joueur en attente de
réapparition à cet instant).

### Implementation for User Story 2

- [X] T008 [P] [US2] Ajouter `EscapeBonusPerNight` au domaine `Currency` de `Settings.luau`
      (défaut 25, bornes 1–1000) — dans `src/ReplicatedStorage/Shared/Config/Settings.luau`
      (même fichier que T004, donc après lui)
- [X] T009 [US2] Étendre `CurrencyService.luau` : ajouter une fonction pure locale
      `escapeBonus(nightsSurvived: number): number` = `Currency.EscapeBonusPerNight *
      nightsSurvived` ; s'abonner à `MatchService.MatchEnded` dans `Init()` : quand `result ==
      "Victory"`, pour chaque joueur de `SessionService.all()` avec `loaded[joueur] == true`
      (**pas seulement** les joueurs `Alive` — un joueur en attente de réapparition fait toujours
      partie de l'équipe victorieuse à cet instant, Edge Cases du spec), incrémenter son attribut
      `Currency` de `escapeBonus(night)` puis appeler `save(joueur)` (réutilise la fonction posée
      en T006) — dans `src/ServerScriptService/Server/Services/CurrencyService.luau` (dépend de
      T006, T008 ; même fichier que T006, donc après lui)

**Checkpoint** : le bonus d'évasion fonctionne, y compris pour un joueur en réapparition ; US1 et
US2 coexistent sans interférence (deux abonnements distincts, une seule fonction `save` partagée).

---

## Phase 5 : User Story 3 - Conserver ses gains malgré un échec (Priority: P3)

**Goal** : un joueur ne perd jamais les gains déjà crédités nuit après nuit, y compris en cas de
défaite de l'équipe, de déconnexion, ou d'un échec temporaire d'écriture — et retrouve son solde
exact même après un redémarrage complet du serveur.

**Independent Test** : provoquer la défaite de l'équipe après 2-3 nuits et constater que le
solde conserve exactement les gains des nuits terminées, sans bonus d'évasion — puis arrêter et
relancer complètement le serveur de test et constater que le solde survit — quickstart.md C3, C6,
C7.

**Note** : FR-006 (pas de bonus sans évasion), FR-007 (gains nocturnes acquis) et FR-010 (pas de
crédit rétroactif) sont déjà satisfaits par construction dès la Phase 4 — `escapeBonus` n'est
jamais appelée hors de la branche `"Victory"` (rien à coder pour une défaite), et chaque gain est
déjà écrit au fil de l'eau dès qu'il est crédité (research R3, R5). Cette phase ajoute la seule
chose qui manque encore réellement : que ces écritures survivent à un échec transitoire de
`DataStoreService`, pas seulement au cas nominal.

### Implementation for User Story 3

- [X] T010 [P] [US3] Ajouter `SaveRetryAttempts` (défaut 3, bornes 1–10, `kind = "integer"`) et
      `SaveRetryDelay` (défaut 2, bornes 0.5–30) au domaine `Currency` de `Settings.luau` — dans
      `src/ReplicatedStorage/Shared/Config/Settings.luau` (même fichier que T008, donc après lui)
- [X] T011 [US3] Remplacer dans `CurrencyService.luau` le chargement à tentative unique (T003)
      par une boucle bornée : jusqu'à `Currency.SaveRetryAttempts` tentatives (`GetAsync`,
      chacune protégée par son propre `pcall`), séparées de `Currency.SaveRetryDelay` secondes
      (`task.wait`) ; même remplacement pour `save` (T006) avec `SetAsync`. Dans les deux cas, si
      toutes les tentatives échouent : journaliser clairement l'échec définitif et continuer sans
      bloquer ni dégrader la partie pour personne (chargement → solde par défaut à 0 ; écriture →
      abandon de cette écriture précise, la suivante partira au prochain événement de crédit) —
      dans `src/ServerScriptService/Server/Services/CurrencyService.luau` (dépend de T003, T006,
      T010 ; même fichier, donc après T009)

**Checkpoint** : la garantie « rien n'est jamais perdu » couvre maintenant aussi bien un échec de
gameplay (défaite) qu'un échec d'infrastructure (écriture ratée) — toutes les user stories sont
indépendamment fonctionnelles.

---

## Phase 6 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles statiques et validation manuelle finale, communes aux trois stories.

- [X] T012 [P] `selene src` et `stylua --check src` sur tous les fichiers nouveaux ou modifiés
      par cette fonctionnalité : aucun écart
- [X] T013 [P] Contrôle de non-régression : `grep -rn "math.random" src` → toujours la seule
      occurrence préexistante (`SfxController.luau`) ; aucune dans `gain`, `escapeBonus` ou la
      logique de nouvelle tentative
- [X] T014 Exécuter les scénarios C1 à C8 de `quickstart.md` en Studio (solo, puis 2 clients
      locaux pour C4), en incluant un arrêt/relance complet du serveur de test pour C6, et cocher
      la « Checklist de fin »

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — **bloque les trois user stories**.
- **User Story 1 (Phase 3)** : dépend de Foundational uniquement — aucune dépendance sur US2/US3.
- **User Story 2 (Phase 4)** : dépend de Foundational ; réutilise la fonction `save` posée par
  US1 (T006) mais reste testable indépendamment (son propre déclencheur, `MatchEnded`, n'a besoin
  d'aucun gain nocturne pour fonctionner en pratique — seul le calcul du bonus dépend du numéro
  de nuit fourni par `MatchService`, pas des gains eux-mêmes).
- **User Story 3 (Phase 5)** : dépend de Foundational (chargement à remplacer) et de US1
  (fonction `save` à remplacer) — modifie du code déjà écrit plutôt que d'en ajouter de
  nouveau ; reste indépendamment validable (C3, C6, C7 ne nécessitent pas l'évasion d'US2).
- **Polish (Phase 6)** : dépend des trois user stories livrées.

### Conflits de fichiers à respecter

- `src/ServerScriptService/Server/Services/CurrencyService.luau` est touché par **T003
  (Foundational) → T006 (US1) → T009 (US2) → T011 (US3)** : strictement séquentiel, jamais en
  parallèle — chaque tâche étend ou remplace une partie du fichier posée par la précédente.
- `src/ReplicatedStorage/Shared/Config/Settings.luau` est touché par **T004 (US1) → T008 (US2) →
  T010 (US3)** : séquentiel entre phases (chacune ajoute ses propres clés au même domaine
  `Currency`, aucun chevauchement de contenu).

### Parallel Opportunities

- T002 (GameplayStateClient) et T003 (CurrencyService) : fichiers différents, aucune dépendance
  mutuelle — en parallèle dès la Phase 2 ouverte.
- T004 (Settings) et T005 (Strings) : fichiers différents — en parallèle, dès la Phase 3 ouverte.
- T007 (HUD) peut démarrer dès que T002 et T005 sont faits, **sans attendre T006** (fichier
  différent, aucune dépendance de contenu sur la logique de crédit elle-même) — en parallèle de
  T006.
- T012 et T013 (contrôles statiques) : indépendants — en parallèle.
- **US1 peut être développée en parallèle de la préparation d'US2/US3** dans la mesure où seules
  les tâches touchant `CurrencyService.luau`/`Settings.luau` doivent respecter l'ordre
  séquentiel ci-dessus ; T007, T005, T008, T010 (fichiers hors de ces deux-là, ou tâches de
  configuration pure) peuvent être préparées à l'avance.

---

## Parallel Example: Phase 2 (Foundational)

```bash
Task: "Ajouter le champ currency à GameplayStateClient"
Task: "Créer le squelette de CurrencyService (chargement à tentative unique)"
```

---

## Implementation Strategy

### MVP First (User Story 1 seule)

1. Compléter Phase 1 : Setup
2. Compléter Phase 2 : Foundational (bloquant, mais minimal — deux tâches)
3. Compléter Phase 3 : User Story 1
4. **STOP et VALIDER** : quickstart.md C1, en solo
5. Livrable : le solde de monnaie augmente à chaque nuit survécue, de plus en plus — démontrable
   sans évasion ni redémarrage de serveur

### Incremental Delivery

1. Setup + Foundational → base prête, aucun gain encore crédité
2. + User Story 1 → validation indépendante (C1) → le gain nocturne croissant est visible
3. + User Story 2 → validation indépendante (C2, C5) → l'évasion rapporte un bonus distinct
4. + User Story 3 → validation indépendante (C3, C6, C7) → rien n'est jamais perdu, y compris au
   redémarrage du serveur
5. Chaque story ajoute de la valeur sans casser la précédente

## Notes

- [P] tasks = fichiers différents, aucune dépendance
- [Story] label = traçabilité vers la user story de `spec.md`
- **Aucune intention réseau nouvelle** : tout le crédit part d'événements serveur
  (`PhaseEnded`, `MatchEnded`), jamais d'une action du joueur — `Remotes.luau` n'est pas modifié.
- **La défaite ne demande aucun code dédié** (research R3, R5) : ne pas chercher de tâche
  « gérer la défaite » manquante — l'absence de déclenchement de `escapeBonus` est déjà le
  comportement correct.
- **`gain` et `escapeBonus` restent des fonctions pures locales à `CurrencyService.luau`**,
  jamais exposées publiquement — rien d'autre dans le projet n'a besoin de les appeler.
- Éviter : tâches vagues, conflits sur un même fichier en parallèle (voir « Conflits de fichiers
  à respecter »), dépendances qui casseraient l'indépendance de test de chaque story.
