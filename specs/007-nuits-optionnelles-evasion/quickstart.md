# Quickstart — valider les nuits optionnelles après réparation du bus

Prérequis inchangés : `rojo serve` (ou `rojo build`), Studio connecté. Activer `Match.TestProfile`
(`Dev.TestProfile`) pour raccourcir les nuits pendant les tests. `Dev.RepairBus` force la
réparation complète sans dépendre d'une vraie récolte de ferraille (existant, `003-bus-evasion`).

## Scénarios de validation

### C1 — Départ immédiat au seuil minimum, comportement inchangé (US1 ; FR-001, FR-002, SC-001)

1. Survivre aux `Match.NightCount` nuits normalement (ou `Dev.NextPhase` en profil de test),
   réparer le bus (`Dev.RepairBus` ou dépôt réel), atteindre la phase « Escape ».
   - **Attendu** : le choix partir/rester est visible au bus (billboard étendu, deux prompts).
2. Choisir de partir (prompt existant, intention `DepartBus`).
   - **Attendu** : victoire immédiate, exactement comme avant cette fonctionnalité — même
     récompense que `006-monnaie-jetons-fidelite` verse aujourd'hui pour ce nombre de nuits.

### C2 — Rester une nuit supplémentaire (US2 ; FR-003, FR-004, FR-005, SC-002, SC-003)

1. Au même point que C1, choisir de rester (nouveau prompt, intention `PushNight`).
   - **Attendu** : une nouvelle phase Jour démarre (nuit `totalNights + 1`), pas de victoire ni de
     défaite immédiate ; le solde de jetons n'a pas encore changé (le crédit de la nuit
     précédente a déjà eu lieu en entrant en Escape, via `CurrencyService`, inchangé).
2. Survivre à cette nuit supplémentaire, revenir en Escape.
   - **Attendu** : le choix partir/rester est de nouveau proposé.
3. Partir à ce stade.
   - **Attendu** : la récompense totale est strictement supérieure à celle obtenue en partant à
     l'étape C1 (SC-002) — vérifier concrètement le solde avant/après contre
     `EscapeBonusPerNight * night`.

### C3 — Deux nuits supplémentaires consécutives (vérifie le correctif R2 ; FR-004, FR-005, SC-003)

**Le scénario le plus important de cette fonctionnalité** : sans le correctif de
`MatchService.advance()` documenté dans `research.md` (R2), cette séquence échouerait
silencieusement (la deuxième nuit supplémentaire recalculerait le même numéro de nuit que la
première au lieu de progresser).

1. Depuis Escape, choisir de rester deux fois de suite (survivre à chaque nuit intermédiaire).
   - **Attendu** : après la deuxième nuit supplémentaire, `MatchStateClient.get().night` vaut
     `totalNights + 2` (pas `totalNights + 1` répété). Vérifiable via `Dev.ShowGameplayState` ou
     lecture directe de `ReplicatedStorage.MatchState:GetAttribute("Night")`.
2. Partir à ce stade.
   - **Attendu** : la récompense correspond à `EscapeBonusPerNight * (totalNights + 2)`, distincte
     et supérieure à celle de C2 — pas une répétition de la récompense de la première nuit
     supplémentaire.

### C4 — Défaite pendant une nuit supplémentaire (US3 ; FR-006, SC-004)

1. Depuis Escape, choisir de rester, noter le solde de jetons actuel.
2. Provoquer l'élimination de toute l'équipe pendant cette nuit supplémentaire (santé à 0 sans
   soin, ou `Dev.SetStatus` sur `Eliminated` pour tous les joueurs présents).
   - **Attendu** : la partie se termine en défaite (`MatchEnded`, `result = "Defeat"`), aucun
     bonus d'évasion versé.
3. Consulter le solde de jetons.
   - **Attendu** : il reste exactement celui noté à l'étape 1 — aucune perte, cohérent avec
     `006-monnaie-jetons-fidelite` (persistance malgré une défaite).

### C5 — Bus réparé avant le seuil minimum : toujours aucun départ possible (Edge Cases ; FR-008, SC-005)

**Correction post-implémentation** : `DepartBus` s'est révélé déjà restreint à la phase Évasion
(`phases = { "Escape" }` dans `Remotes.luau`, présent depuis `003-bus-evasion`) — repéré en
testant ce scénario en direct, pas en relisant le code. Il n'existe donc pas de « départ
anticipé » à préserver ; ce scénario vérifie plutôt l'absence de régression sur cette restriction
déjà existante.

1. Réparer le bus avant d'avoir atteint `Match.NightCount` nuits (ex. `Dev.RepairBus` en nuit 2).
   - **Attendu** : aucun choix partir/rester n'apparaît (les deux prompts, `DeparturePrompt` et
     `StayPrompt`, restent `Enabled = false` tant que la phase n'est pas « Escape », même une fois
     le bus réparé).
2. Déclencher `DepartBus` malgré tout (par exemple en appelant l'intention directement, en
   contournant l'interface).
   - **Attendu** : refusé par le serveur avec `WrongPhase` (`Remotes.luau`, avant même d'atteindre
     `BusService` — comportement déjà en place avant cette fonctionnalité, non ajouté par elle).

### C6 — Danger réellement croissant (FR-010, FR-011, SC-006)

1. Noter les dégâts subis lors d'un contact ennemi pendant une nuit normale (avant le seuil
   minimum) — doit correspondre à `Enemy.ContactDamage` (20 par défaut).
2. Provoquer un contact ennemi pendant une première nuit supplémentaire, puis une deuxième.
   - **Attendu** : les dégâts subis augmentent à chaque nuit supplémentaire
     (`ContactDamage + ExtraNightDamageGrowth * extraNights` — 25 puis 30 avec les valeurs par
     défaut, `contracts/config.md`), et la vitesse de poursuite de l'ennemi est visiblement plus
     rapide.
3. Revérifier une nuit normale antérieure au seuil (si testée à nouveau dans une nouvelle
   partie).
   - **Attendu** : dégâts et vitesse identiques à aujourd'hui, aucune régression sur les nuits
     normales (FR-011).

### C7 — Répétabilité sans plafond (US2 ; FR-004, SC-003)

1. Enchaîner au moins 3 nuits supplémentaires de suite sans jamais partir.
   - **Attendu** : le choix partir/rester est proposé après chacune, sans blocage ni plafond
     imposé par le code (aucun réglage `MaxExtraNights` n'existe, research R8).

### C8 — Contrôles statiques

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante (`SfxController.luau`).
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Relire `BusService.luau` : `PushNight` suit exactement la même forme de validation que
  `DepartBus` (aucune autorité déléguée au client — la phase est déjà garantie par la déclaration
  `phases = { "Escape" }` de `Remotes.luau` avant même d'atteindre le gestionnaire ; l'état
  `repaired` et la présence d'équipe sont revérifiés dans le gestionnaire, principe III).

## Checklist de fin

- [X] C1 conforme : départ immédiat au seuil minimum inchangé — vérifié en Studio (nuit 7/7,
      178 → 175 refusé, exactement 175 versés, comme `006` avant cette fonctionnalité).
- [X] C2 conforme : une nuit supplémentaire augmente correctement la récompense — vérifié
      (partie #1, bonus d'évasion 225 pour 9 nuits contre 175 pour 7 dans la même partie).
- [X] C3 conforme : deux nuits supplémentaires consécutives progressent correctement — vérifié en
      direct (nuit 7 → 8 → 9, jamais de répétition), validant le correctif R2.
- [X] C4 conforme : une défaite pendant une nuit supplémentaire ne retire aucun gain acquis —
      vérifié (partie #2, solde resté à 670 avant/après la défaite en nuit 8, aucun bonus versé).
- [X] C5 conforme : aucun départ possible avant le seuil minimum — vérifié (`WrongPhase` avant
      cette fonctionnalité, comportement retrouvé identique après), et la correction de
      `FR-008`/spec ci-dessus documente pourquoi l'énoncé initial était inexact.
- [~] C6 partiellement vérifié : les réglages et la formule sont confirmés corrects en lisant
      `Config.get("Enemy", ...)` en direct (25/15 puis 30/16, exactement `contracts/config.md`),
      et `EnemyService` lit bien `MatchService.getNight()`/`getTotalNights()` (déjà confirmés
      corrects par C3) — mais aucun contact ennemi réel n'a été mesuré en jeu pendant une nuit
      supplémentaire (aurait demandé de garder un ennemi actif et de se faire toucher
      délibérément, non fait faute de temps). À revalider par un contact réel avant publication.
- [~] C7 partiellement vérifié : deux nuits supplémentaires consécutives réussies (partie #1),
      pas trois — mais `pushExtraNight()` ne contient aucun compteur ni plafond (relecture du
      code), donc rien ne distingue structurellement une deuxième d'une troisième tentative.
- [X] Aucune autorité critique côté client : `PushNight` revalide tout côté serveur (phase via
      `Remotes.luau`, réparation et présence d'équipe dans le gestionnaire).
- [X] Réglages centralisés : domaine `Enemy` étendu dans `Settings.luau`, aucune valeur codée en
      dur.
- [X] La boucle reste jouable de bout en bout : deux parties complètes jouées en Studio (une
      victoire après 9 nuits, une défaite après 8), rien de cassé ailleurs.

**Notes de vérification (2026-09-20)** : deux bugs réels ont été trouvés pendant ces tests, pas
seulement à la relecture.

1. **Oubli bloquant** : `PushNight` n'avait pas été déclaré dans `Remotes.luau` (la liste unique
   d'intentions que `NetService` exige, principe IV) — `BusService.Init()` échouait entièrement
   au démarrage (« 1 système en échec »), désactivant du même coup `DepartBus`, `RepairBus` et
   toute la réparation du bus, pas seulement `PushNight`. Repéré immédiatement au premier lancement
   (log d'erreur explicite). Corrigé en ajoutant la déclaration, symétrique à `DepartBus`.
2. **Prémisse de conception fausse** : `research.md`, `spec.md` (FR-008, Assumptions, Edge Cases)
   et le premier jet de `BusService.luau` supposaient tous qu'un départ anticipé avant le seuil
   minimum de nuits était possible aujourd'hui (lu uniquement dans le corps du gestionnaire
   `DepartBus`, qui n'a effectivement aucune vérification de phase en ligne). En testant le
   scénario C5, `[LastExit/Net] Refus DepartBus ... WrongPhase (phase Day)` a révélé que
   `Remotes.luau` déclare déjà `phases = { "Escape" }` pour `DepartBus` depuis `003-bus-evasion` —
   une restriction centralisée, séparée du gestionnaire, qui n'apparaît jamais en lisant
   `BusService.luau` seul. Corrigé : `DeparturePrompt.Enabled` exige désormais aussi
   `phase == "Escape"` (plus seulement `repaired`), la revérification de phase en ligne dans
   `PushNight` a été retirée (redondante avec la déclaration, incohérente avec le reste du
   projet qui ne double jamais cette vérification), et `spec.md`/FR-008/Edge Cases/Assumptions ont
   été corrigés pour refléter le comportement réel plutôt que la lecture initiale, incomplète.
