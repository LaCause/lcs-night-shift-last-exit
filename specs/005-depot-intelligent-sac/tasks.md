---

description: "Task list template for feature implementation"
---

# Tasks: Vidage progressif du sac et dépôt automatique aux postes

**Input**: Documents de conception de `specs/005-depot-intelligent-sac/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé (spec et constitution du projet : validation
manuelle en Studio via `quickstart.md`, comme pour `001` à `004`).

**Organisation** : les tâches sont groupées par user story (P1/P2 de `spec.md`) pour permettre une
implémentation et une validation indépendantes de chacune.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : peut s'exécuter en parallèle (fichier différent, aucune dépendance sur une tâche
  non terminée)
- **[Story]** : user story concernée (US1, US2)
- Chemin de fichier exact dans chaque description

## Phase 1 : Setup

**Purpose** : vérifier que le socle (001 à 004) reste intact avant d'y greffer cette
fonctionnalité. Aucune nouvelle dépendance, aucun nouvel outil.

- [ ] T001 Vérifier que le projet compile toujours :
      `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` réussit sans erreur
      (racine du dépôt)

**Checkpoint** : le socle est un point de départ sain.

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée bloquant les deux user stories.

**Aucune tâche cette fois** : contrairement à `004-sac-collecte`, US1 et US2 sont **entièrement
indépendantes l'une de l'autre** (confirmé par `spec.md` : US1 fonctionne avec le vidage « tout ou
rien » actuel, sans l'ordre d'arrivée ; US2 se valide sans qu'aucun poste ne soit à proximité).
Aucun type, réglage, texte ou remote nouveau n'est requis par les deux à la fois — chacune apporte
ses propres ajouts dans sa propre phase. Passer directement à la Phase 3.

**Checkpoint** : aucune attente — les deux user stories peuvent commencer dès la Phase 1 terminée.

---

## Phase 3 : User Story 1 - Déposer automatiquement un objet lâché près d'un poste compatible (Priority: P1) 🎯 MVP

**Goal** : lâcher un objet transporté (par le vidage complet déjà existant, `DropBag`) à portée
d'un poste qui sait s'en servir le dépose directement — carburant, stock ou réparation du bus —
au lieu de le poser au sol.

**Independent Test** : porter de l'essence, s'approcher du générateur, vider le sac (`DropBag`,
geste déjà livré par 004), et constater que le carburant augmente exactement du montant transporté
sans qu'aucun objet n'apparaisse au sol — quickstart.md W3 et W4. Ne nécessite ni la pression
brève ni l'ordre d'arrivée (US2) : `DropBag` continue de tout vider d'un coup, seul le sort de
chaque unité change.

### Implementation for User Story 1

- [X] T002 [P] [US1] Ajouter `GeneratorService.fuelRoom(): number` (= `Capacity - fuel` courant),
      simple lecture de l'état privé déjà maintenu par le module — dans
      `src/ServerScriptService/Server/Services/GeneratorService.luau`
- [X] T003 [P] [US1] Extraire de `RepairBus` une fonction publique
      `BusService.deposit(player, maxAmount): number` : prélève jusqu'à `maxAmount` ferraille via
      `InventoryService.depositResource`, incrémente `deposited`, publie l'état, envoie
      `ScrapDeposited`, déclenche `BusRepaired` au seuil (comportement observable strictement
      inchangé, research R7) ; le gestionnaire `RepairBus` appelle désormais cette fonction avec
      `room = required - deposited` au lieu de dupliquer cette logique — dans
      `src/ServerScriptService/Server/Services/BusService.luau`
- [X] T004 [P] [US1] Ajouter `InventoryService.depositResourceToStock(player, resourceType,
      maxAmount): number` : jumelle unitaire de `depositToStock`, pour un seul type
      (`SuspectSteak` ou `RoadBread`) — prélève jusqu'à `maxAmount` unités, les ajoute au `Stock`
      partagé, renvoie la quantité réellement déposée (0 si le type n'a rien à donner) ; la
      fonction bulk `depositToStock` existante n'est pas modifiée — dans
      `src/ServerScriptService/Server/Services/InventoryService.luau`
- [X] T005 [US1] Créer `StationDepositService` (Priority 49), découvert automatiquement par le
      `Loader` : table `AUTO_DEPOSIT` associant à chaque `ResourceType` son poste
      (`RefPointId`, `RangeSetting`, `attempt`) — `Essence`→Générateur (`Generator.
      InteractRange`, capacité vérifiée via `fuelRoom()`), `SuspectSteak`/`RoadBread`→Comptoir
      (`Forest.HarvestRange`, sans limite de capacité), `Scrap`→Bus (`Bus.InteractRange`,
      capacité vérifiée via `required - deposited`) ; exposer `tryDeposit(player, resourceType,
      position): boolean` qui vérifie la portée depuis `position` (**pas** depuis le joueur,
      research R5, **sans** `Net.DistanceTolerance`), vérifie la capacité avant tout prélèvement,
      et délègue le prélèvement + l'application au poste concerné (`GeneratorService.deposit`,
      `BusService.deposit`, `InventoryService.depositResourceToStock`) ; renvoie `false` sans
      avoir touché le sac si aucune condition n'est réunie (research R3) — dans
      `src/ServerScriptService/Server/Services/StationDepositService.luau` (dépend de T002, T003,
      T004)
- [X] T006 [US1] Étendre `BagService.drop` : pour chaque unité à poser (parcours actuel à ordre
      fixe, `CARRIED_TYPES`, inchangé pour l'instant — US2 le remplacera), calculer sa position
      d'atterrissage puis tenter `StationDepositService.tryDeposit(player, resourceType,
      position)` **avant** `ForestService.spawnDrop` ; ne poser au sol que si `tryDeposit` renvoie
      `false` ; compter uniquement les unités posées au sol pour la valeur de retour. Modifier le
      gestionnaire de l'intention `DropBag` pour n'envoyer `BagDropped` que si ce compte est `> 0`
      (research R8) — dans `src/ServerScriptService/Server/Services/BagService.luau` (dépend de
      T005)

**Checkpoint** : le dépôt automatique fonctionne aux trois postes (générateur, comptoir, bus) via
le vidage complet existant ; US1 testable indépendamment de tout geste de pression brève.

---

## Phase 4 : User Story 2 - Choisir de lâcher un seul objet ou tout le sac (Priority: P2)

**Goal** : une pression brève sur la touche de vidage ne fait tomber que le dernier objet
ramassé ; un maintien continue de tout vider (comme aujourd'hui), mais désormais dans l'ordre
inverse exact du ramassage.

**Independent Test** : ramasser plusieurs objets de types différents dans un ordre connu, presser
brièvement la touche de vidage et vérifier que seul le dernier objet ramassé sort, puis maintenir
et vérifier que le reste sort en une seule action, dans l'ordre inverse — quickstart.md W1 et W2.
Se valide entièrement sans qu'aucun poste ne soit à proximité (US1 non requis).

### Implementation for User Story 2

- [X] T007 [P] [US2] Ajouter le réglage `Bag.DropHoldThreshold` (défaut 0.4, bornes 0.15–1.5,
      description : seuil de maintien de la touche de vidage) — dans
      `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T008 [P] [US2] Déclarer l'intention `DropOneItem` dans `Remotes.Intents` : payload vide,
      mêmes phases que `DropBag`, aucune cible (même forme que `DropBag`, contracts/network.md)
      — dans `src/ReplicatedStorage/Shared/Net/Remotes.luau`
- [X] T009 [US2] Ajouter l'ordre d'arrivée à `InventoryService` : table serveur privée `order: {
      [Player]: { ResourceType } }` (le dernier élément étant le plus récent) ; instrumenter
      `addPersonal` (ajoute `amount` entrées de `type` en fin de liste), `depositResource`
      (retire jusqu'à `maxAmount` entrées de `type`), `depositToStock` et
      `depositResourceToStock` (T004, retirent les entrées `SuspectSteak`/`RoadBread`
      concernées) ; ajouter `clearCarried(player)` (vide compteurs **et** ordre en un seul appel,
      research R6), `orderOf(player): { ResourceType }` (copie en lecture seule) et
      `mostRecent(player): ResourceType?` ; vider `order[player]` dans `initPlayer` et
      `resetAll` ; ajouter un abonnement `SessionService.PlayerLeft` qui supprime
      `order[player]` (pas de nettoyage automatique comme pour un attribut, research R1) — dans
      `src/ServerScriptService/Server/Services/InventoryService.luau` (dépend de T004 ; même
      fichier que T004, donc séquentiel après lui)
- [X] T010 [US2] Corriger `BagService.empty` : appeler `InventoryService.clearCarried(player)` au
      lieu d'écrire les attributs `Inv_*` directement — sans ce correctif, `Dev.EmptyBag`
      laisserait des entrées fantômes dans l'ordre d'arrivée (bug trouvé en 004, non encore
      mergé, research R6) ; comportement observable de `Dev.EmptyBag` inchangé — dans
      `src/ServerScriptService/Server/Services/BagService.luau` (dépend de T009 ; même fichier
      que T006, donc séquentiel après lui)
- [X] T011 [US2] Étendre `BagService` : remplacer dans `drop` le parcours à ordre fixe
      (`CARRIED_TYPES`, posé en T006) par un parcours de `InventoryService.orderOf(player)` (le
      plus récent d'abord, FR-004) ; ajouter `dropOne(player): (boolean, ResourceType?)` — traite
      la seule unité renvoyée par `InventoryService.mostRecent`, même embranchement
      poste-ou-sol que `drop` (position calculée comme un cercle à un seul élément) ; enregistrer
      le gestionnaire de l'intention `DropOneItem` (mêmes refus que `DropBag` :
      `NoCharacter`/`BagNotEquipped`/`BagEmpty`, vérifiés manuellement puisqu'aucune cible n'est
      déclarée) qui appelle `dropOne` et n'envoie `BagDropped { amount = 1 }` que si l'objet a
      été posé au sol — dans `src/ServerScriptService/Server/Services/BagService.luau` (dépend de
      T008, T009, T010 ; même fichier, donc séquentiel après T010)
- [X] T012 [US2] Étendre `PointerController` : remplacer l'envoi immédiat de `DropBag` sur `G` par
      un minuteur de maintien — à `InputBegan(G)`, démarrer le chronométrage ; si `Bag.
      DropHoldThreshold` est franchi pendant que la touche reste enfoncée, envoyer `DropBag` une
      seule fois (ne jamais se redéclencher tant que la touche reste enfoncée après ce premier
      envoi, clarification 2026-09-18 Q1) ; à `InputEnded(G)`, si le seuil n'a pas été atteint,
      envoyer `DropOneItem` à la place ; dans les deux cas, ne rien envoyer si le sac n'est pas
      équipé ou est vide (même garde qu'aujourd'hui) — dans
      `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PointerController.luau` (dépend
      de T007, T008)
- [X] T013 [P] [US2] Mettre à jour `Strings.luau` : `Hud.Bag.Drop` distingue désormais pression
      brève et maintien (ex. « [G] lâcher · maintenir : tout vider ») ; le texte de `Notify.
      BagDropped` devient agnostique du nombre d'objets (éviter « vidé » pour un seul objet posé)
      — dans `src/ReplicatedStorage/Shared/Strings.luau`
- [X] T014 [P] [US2] Étendre `Dev.ShowGameplayState` : ajouter une ligne listant l'ordre
      d'arrivée courant du joueur (`InventoryService.orderOf`), utile pour valider FR-004 sans
      deviner l'état interne — dans `src/ServerScriptService/Server/Services/DevService.luau`
      (dépend de T009)

**Checkpoint** : les deux gestes (pression, maintien) coexistent avec le dépôt automatique ; la
boucle complète du jeu reste jouable.

---

## Phase 5 : Polish & Cross-Cutting Concerns

**Purpose** : contrôles statiques et validation manuelle finale, communes aux deux stories.

- [X] T015 [P] `selene src` et `stylua --check src` sur tous les fichiers nouveaux ou modifiés par
      cette fonctionnalité : aucun écart
- [X] T016 [P] Contrôles de non-régression : `grep -rn "math.random" src` → toujours la seule
      occurrence préexistante (`SfxController.luau`) ; vérifier que `#InventoryService.orderOf
      (player) == somme(Inv_*)` reste vrai après un cycle ramasser/vider/re-ramasser (invariant de
      data-model.md)
- [ ] T017 Exécuter les scénarios W1 à W8 de `quickstart.md` en Studio (solo puis 2 clients
      locaux) et cocher la « Checklist de fin », en incluant le cas de portée assumé (W5) et la
      déconnexion après le seuil de maintien (W7.2)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : vide cette fois (voir ci-dessus) — ne bloque rien.
- **User Story 1 (Phase 3)** : dépend de Setup uniquement — aucune dépendance sur US2.
- **User Story 2 (Phase 4)** : dépend de Setup uniquement pour son propre fonctionnement, mais
  **modifie du code que US1 a déjà touché** (`BagService.drop`) — voir « Conflits de fichiers »
  ci-dessous. Reste testable indépendamment (son parcours ne dépend d'aucun poste).
- **Polish (Phase 5)** : dépend des deux user stories livrées.

### Conflits de fichiers à respecter

- `InventoryService.luau` est touché par **T004 (US1) puis T009 (US2)** : séquentiel, jamais en
  parallèle.
- `BagService.luau` est touché par **T006 (US1) puis T010 et T011 (US2)** : séquentiel — T011
  réécrit littéralement le parcours posé par T006 (ordre fixe → `orderOf`), donc T006 doit être
  terminé avant T011.
- `GeneratorService.luau` (T002) et `BusService.luau` (T003) ne sont touchés qu'une fois chacun :
  aucun conflit.

### Parallel Opportunities

- T002, T003 et T004 (GeneratorService, BusService, InventoryService) : trois fichiers différents,
  aucune dépendance mutuelle — en parallèle.
- T007 et T008 (Settings, Remotes) : fichiers différents — en parallèle, dès la Phase 4 ouverte
  (n'attendent aucune tâche d'US1).
- T013 et T014 (Strings, DevService) : fichiers différents des autres tâches d'US2 — en parallèle
  une fois T009 fait (pour T014).
- T015 et T016 (contrôles statiques) : indépendants — en parallèle.
- **US1 et US2 peuvent être développées par deux personnes en parallèle** jusqu'à T011 : T006
  (US1) et T007/T008 (US2) n'ont aucune dépendance croisée ; seul T011 doit attendre que T006 soit
  terminé, puisqu'il réécrit le même parcours.

---

## Parallel Example: Phase 3 (User Story 1)

```bash
Task: "Ajouter GeneratorService.fuelRoom()"
Task: "Extraire BusService.deposit() de RepairBus"
Task: "Ajouter InventoryService.depositResourceToStock()"
```

---

## Implementation Strategy

### MVP First (User Story 1 seule)

1. Compléter Phase 1 : Setup
2. Compléter Phase 3 : User Story 1 (Phase 2 est vide, rien à attendre)
3. **STOP et VALIDER** : quickstart.md W3 et W4, en solo
4. Livrable : vider son sac près d'un poste compatible le dépose directement — démontrable sans
   toucher à la pression brève ni à l'ordre d'arrivée

### Incremental Delivery

1. Setup → base prête
2. + User Story 1 → validation indépendante (W3, W4) → le vidage devient contextuel aux postes
3. + User Story 2 → validation indépendante (W1, W2) → contrôle fin du vidage, dans l'ordre exact
   du ramassage
4. Chaque story ajoute de la valeur sans casser la précédente — vérifié explicitement par W6
   (conservation) une fois les deux livrées

## Notes

- [P] tasks = fichiers différents, aucune dépendance
- [Story] label = traçabilité vers la user story de `spec.md`
- **Aucun nouveau code de refus** (research R10) : `BagNotEquipped` et `BagEmpty`, déjà déclarés
  par l'amendement du 2026-09-17 de `004-sac-collecte`, couvrent `DropOneItem` comme `DropBag`.
  Aucune tâche ne touche `Types.luau`.
- **Le pipeline `NetService` n'est pas modifié** : `DropOneItem` suit exactement le même patron
  que `DropBag` (payload vide, aucune cible, vérifications manuelles dans le gestionnaire).
- **La portée du dépôt automatique se mesure depuis l'objet, pas depuis le joueur** (T005,
  research R5) — c'est un choix assumé de l'auteur, à l'encontre de la convention du reste du
  pipeline réseau ; ne pas « corriger » vers une mesure depuis le joueur sans revalider avec
  l'auteur.
- **`InventoryService.depositResourceToStock` (T004) est créée avant l'ordre d'arrivée (T009)** :
  elle fonctionne dès US1 sans lui, T009 l'instrumente ensuite pour qu'elle retire aussi les
  entrées d'ordre correspondantes — pas une réécriture, un ajout dans la même fonction.
- Éviter : tâches vagues, conflits sur un même fichier en parallèle (voir « Conflits de fichiers
  à respecter »), dépendances qui casseraient l'indépendance de test de chaque story.
