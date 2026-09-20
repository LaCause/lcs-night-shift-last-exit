# Quickstart — valider la monnaie, le gain par nuit et le bonus d'évasion

Prérequis inchangés depuis les incréments précédents : `rojo serve` (ou `rojo build`), Studio
connecté. Activer `Match.TestProfile` (`Dev.TestProfile`) pour raccourcir les nuits pendant les
tests — les formules et seuils restent les mêmes, seule la durée change.

## Scénarios de validation

### C1 — Gain nocturne croissant (US1 ; FR-001 à FR-003, SC-001, SC-002)

1. Play en solo. Noter le solde initial (`GameplayStateClient.get().currency`, ou l'affichage HUD).
2. Enchaîner plusieurs nuits avec `Dev.NextPhase` jusqu'à la fin de chacune.
   - **Attendu** : après chaque nuit, le solde augmente avant le début de la suivante, d'un montant
     strictement supérieur à celui de la nuit précédente (`gain(night)` de `contracts/config.md`).
3. Comparer le montant crédité à chaque nuit avec `NightlyBase + NightlyGrowth * (night - 1)`.
   - **Attendu** : correspondance exacte.

### C2 — Bonus d'évasion (US2 ; FR-004, FR-005, SC-003)

1. Mener une partie jusqu'à la réparation complète du bus, puis déclencher `DepartBus`.
   - **Attendu** : au moment précis où le bus part (victoire), le solde augmente d'un montant
     supplémentaire, distinct des gains nocturnes déjà accumulés — `escapeBonus(nightsSurvived)`.
2. Comparer deux parties où l'évasion survient après un nombre de nuits différent.
   - **Attendu** : la partie la plus longue verse le bonus le plus élevé, proportionnellement au
     nombre de nuits survécues.

### C3 — Conservation malgré une défaite (US3 ; FR-006, FR-007, SC-004)

1. Survivre à 2-3 nuits complètes (noter le solde après chacune), puis provoquer la défaite de
   l'équipe (`Dev.SetStatus` sur `Eliminated` pour tous les joueurs présents, ou laisser la santé
   tomber à 0 sans soin).
   - **Attendu** : la partie se termine en défaite (`MatchEnded`, `result = "Defeat"`) ; le solde
     reste exactement celui accumulé par les nuits terminées — aucun retrait, aucun bonus
     d'évasion ajouté.
2. Rejoindre une nouvelle partie sur le même serveur.
   - **Attendu** : le solde affiché au démarrage correspond à celui laissé par la défaite
     précédente.

### C4 — Rejoindre une partie déjà commencée (Edge Cases ; FR-010)

1. Avec deux clients (« Clients and Servers », 2 clients) : le premier joueur survit à une nuit
   complète avant que le second ne rejoigne.
   - **Attendu** : le solde du second joueur au moment où il rejoint ne contient aucun crédit pour
     la nuit déjà terminée avant son arrivée.
2. Les deux joueurs terminent ensuite une nuit ensemble.
   - **Attendu** : les deux reçoivent le même gain pour cette nuit-là (celle qu'ils ont vécue tous
     les deux), chacun sur son propre solde.

### C5 — Joueur en attente de réapparition au moment de l'évasion (Edge Cases)

1. Juste avant de déclencher `DepartBus`, éliminer un joueur (`Dev.SetStatus` sur `Eliminated`)
   sans attendre sa réapparition, puis déclencher l'évasion avec le reste de l'équipe.
   - **Attendu** : le joueur en attente de réapparition reçoit quand même le bonus d'évasion — il
     fait toujours partie de la partie à cet instant, la réapparition n'étant pas un échec.

### C6 — Persistance au-delà d'un redémarrage complet du serveur (US3 ; FR-008, SC-005)

1. Survivre à au moins une nuit, noter le solde exact.
2. Arrêter complètement le test Play (`start_stop_play(false)`), puis le relancer
   (`start_stop_play(true)`) — un tout nouveau serveur de test, pas une reconnexion au même
   processus.
3. Rejoindre en tant que le même joueur.
   - **Attendu** : le solde affiché est identique à celui noté avant l'arrêt. C'est le seul
     scénario de cette fonctionnalité qui ne peut pas se vérifier par une simple session continue —
     il exige un arrêt/relance réel.

### C7 — Comportement de secours si l'écriture ou la lecture échoue (US3 ; FR-009, principe VI)

1. Si l'environnement de test ne permet pas d'exercer `DataStoreService` avec succès (voir la note
   de fin de `research.md`), rejouer C1 à C5 tel quel.
   - **Attendu** : rien ne bloque — le solde continue de se mettre à jour en mémoire, la partie
     reste jouable de bout en bout, une erreur de sauvegarde ne casse jamais le reste du jeu. Seule
     la persistance réelle au redémarrage (C6) ne peut alors pas être confirmée par ce moyen ; à
     revalider séparément dans un environnement où `DataStoreService` fonctionne pleinement (place
     publiée, ou Studio avec l'accès aux services d'API activé).

### C8 — Contrôles statiques

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante (`SfxController.luau`) ;
  aucune dans les formules de gain ou de bonus.
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Relire `CurrencyService.luau` : confirme qu'aucune intention `NetService` n'est enregistrée
  (rien ne vient du client pour cette fonctionnalité) et que `Currency` n'est jamais modifié
  ailleurs que dans ce fichier.

## Checklist de fin (complète celles des incréments précédents)

- [X] Solo : C1, C2, C3 conformes — vérifié en Studio (deux parties complètes, formules exactes,
      y compris après correctif du crédit d'une nuit interrompue par une défaite, voir Notes).
- [ ] Multijoueur local (2 clients) : C4 conforme — pas de crédit rétroactif pour un rejoin tardif.
      **Non exécuté** (un seul client dans cet environnement de test) ; garanti par construction
      (`creditAll` ne parcourt que `SessionService.all()` au moment de l'événement, research R4) —
      à confirmer par un vrai test à 2 clients avant publication.
- [ ] C5 conforme : un joueur en réapparition compte toujours pour le bonus d'évasion.
      **Non exécuté en conditions réelles** (éliminer l'unique joueur d'une session solo déclenche
      la défaite de toute l'équipe avant même l'évasion — testé, comportement correct : aucun bonus
      dans ce cas) ; confirmé par relecture du code (`creditAll` ne filtre jamais par statut
      `Alive`) — à confirmer par un vrai test à 2 clients avant publication.
- [ ] C6 (persistance réelle au redémarrage) : **non vérifiable dans cet environnement** —
      `DataStoreService` y est bloqué (`StudioAccessToApisNotAllowed`), confirmé en direct. Le
      repli C7 a lui pu être vérifié : le solde par défaut à 0 s'est posé sans bloquer la partie,
      erreur journalisée une seule fois par tentative épuisée. C6 à revalider séparément (place
      publiée, ou Studio avec l'accès aux services d'API activé).
- [X] Aucune autorité critique côté client : aucune intention réseau n'existe pour cette
      fonctionnalité, tout le crédit part d'événements serveur.
- [X] Réglages centralisés : domaine `Currency` dans `Settings.luau`, aucune valeur codée en dur.
- [X] Comportements de secours : échec de chargement ou d'écriture → solde par défaut à 0, partie
      jamais bloquée (C7, vérifié en direct).
- [X] La boucle reste jouable de bout en bout, la monnaie n'en changeant aucune étape : explorer →
      récolter → maintenir → survivre → réparer → fuir, avec un solde qui progresse en toile de
      fond.

**Notes de vérification (2026-09-20)** : un bug réel a été trouvé et corrigé pendant ces tests, pas
seulement à la relecture. `MatchService.enterPhase` déclenche `PhaseEnded("Night", n)` même quand la
partie se termine de force en pleine nuit (défaite : `endMatch` appelle `enterPhase("Ended", ...)`,
qui déclenche ce même signal) — la première version créditait donc à tort la nuit interrompue.
Corrigé en vérifiant `MatchService.getPhase() ~= "Ended"` dans le gestionnaire (la nouvelle phase
est déjà posée avant que le signal ne parte). Revérifié après correctif : nuit interrompue par une
défaite → aucun crédit (delta 0), nuit terminée naturellement (y compris la dernière, qui bascule
vers Escape) → créditée normalement.
