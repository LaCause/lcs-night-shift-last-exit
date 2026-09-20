# Quickstart — valider la boutique et sa persistance entre parties

Prérequis inchangés : `rojo serve` (ou `rojo build`), Studio connecté. `Dev.GiveResources`
n'aide pas ici (jetons, pas ressources récoltables) — utiliser `Dev.NextPhase` pour accumuler des
jetons via `006-monnaie-jetons-fidelite` avant de tester les achats, ou lire/forcer l'attribut
`Currency` directement en Studio pour les tests ciblés.

## Scénarios de validation

### C1 — Acheter un objet cosmétique (US1 ; FR-001 à FR-004, SC-001 à SC-003)

1. Avec un solde suffisant, ouvrir la boutique, choisir un objet cosmétique non possédé.
   - **Attendu** : prix affiché correspond au catalogue.
2. Confirmer l'achat.
   - **Attendu** : solde diminue exactement du prix, l'objet est marqué possédé, et se signale
     désormais comme tel dans la boutique (non ré-achetable).
3. Retenter l'achat du même objet.
   - **Attendu** : refusé (`AlreadyOwned`), aucun débit.
4. Tenter d'acheter un objet dont le prix dépasse le solde restant.
   - **Attendu** : refusé (`InsufficientFunds`), aucun débit, solde inchangé.

### C2 — Un cosmétique acheté devient actif automatiquement (US1/US2 ; FR-005, FR-006)

1. Acheter un premier objet cosmétique d'un emplacement (ex. teinte de sac).
   - **Attendu** : cet objet est désormais celui affiché pour cet emplacement, sans action
     supplémentaire.
2. Acheter un second objet du même emplacement.
   - **Attendu** : le nouvel objet remplace le précédent comme actif ; jamais les deux à la fois.

### C3 — Choisir un objet actif parmi ceux déjà possédés (US2 ; FR-007, SC-007)

1. Avec deux objets déjà possédés pour le même emplacement (C2), sélectionner depuis la boutique
   celui qui n'est pas actuellement actif.
   - **Attendu** : il devient l'actif, sans aucun débit (aucun nouvel achat).
2. Sélectionner de nouveau l'objet déjà actif.
   - **Attendu** : aucun effet, reste actif (Edge Case).

### C4 — Démarrer avec l'avantage acheté (US3 ; FR-008, FR-010, SC-004)

1. Acheter l'avantage de départ (`BiggerBag`), noter la capacité de sac actuelle (partie en
   cours, si applicable — ne doit pas changer immédiatement).
2. Terminer la partie en cours (ou utiliser `Dev.EndMatch`) puis en rejoindre une nouvelle.
   - **Attendu** : la capacité du sac au tout début de cette nouvelle partie est celle de
     `Bag.MediumCapacity`, pas `Bag.SmallCapacity` — vérifiable via `GameplayStateClient.get().bagCapacity`
     ou `Dev.ShowGameplayState`.

### C5 — Défaite pendant une partie n'affecte ni les achats ni les avantages (Edge Cases ; FR-009, FR-010)

1. Avec un avantage et un cosmétique déjà possédés, provoquer une défaite d'équipe.
   - **Attendu** : la partie suivante conserve exactement les mêmes objets possédés, le même
     objet actif, et le même avantage de départ — rien n'est jamais retiré par une défaite (la
     boutique n'a aucune notion de risque, contrairement à `007`).

### C6 — Persistance au-delà d'un redémarrage complet du serveur (US4 ; FR-011, SC-005)

1. Acheter au moins un objet, choisir un objet actif différent du dernier acheté (C3), noter le
   solde restant.
2. Arrêter complètement le test Play (`start_stop_play(false)`), puis le relancer
   (`start_stop_play(true)`) — un tout nouveau serveur de test.
3. Rejoindre en tant que le même joueur.
   - **Attendu** : les mêmes objets sont possédés, le même objet actif par emplacement est
     conservé (pas le dernier acheté si un autre avait été choisi depuis), et le solde est
     identique à celui noté avant l'arrêt.

### C7 — Comportement de secours si la sauvegarde échoue (FR-013, principe VI)

1. Si l'environnement de test ne permet pas d'exercer `DataStoreService` avec succès (limite déjà
   connue depuis `006`), rejouer C1 à C5 tel quel.
   - **Attendu** : rien ne bloque — achats et changements d'objet actif continuent de fonctionner
     en mémoire, la partie reste jouable de bout en bout. Seule la persistance réelle au
     redémarrage (C6) ne peut alors pas être confirmée par ce moyen ; à revalider séparément dans
     un environnement où `DataStoreService` fonctionne pleinement.

### C8 — Aucune autorité côté client (FR-012, principe III)

- Relire `BoutiqueService.luau` : `BuyItem` et `SetActiveCosmetic` revalident tout côté serveur
  (existence de l'objet dans le catalogue, possession, solde) — le client ne fait que proposer
  l'action et prévisualiser un état déjà répliqué (`BoutiqueStateClient`), jamais l'imposer.
- Confirmer qu'aucun code client ne modifie directement `Currency` ou les attributs `Owned_*`/
  `Active_*` (recherche `SetAttribute("Currency"` / `SetAttribute("Owned_` / `SetAttribute("Active_`
  hors des fichiers serveur).

### C9 — Contrôles statiques

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante (`SfxController.luau`).
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Le comportement par défaut de `BagService` (aucun avantage possédé) reste strictement inchangé
  — `assignBag`/`defaultType` ne sont pas modifiées, seule une nouvelle entrée `BAG_TYPES` et une
  nouvelle fonction additive `setType` sont ajoutées.

## Checklist de fin

- [x] C1 conforme : achat, refus à solde insuffisant, refus si déjà possédé — vérifié en direct
      dans Studio (achat BagTintRed, débit exact 50, `AlreadyOwned` sur rachat, `InsufficientFunds`
      sans débit à solde 10 sur un objet à 50).
- [x] C2 conforme : un achat cosmétique devient automatiquement actif pour son emplacement —
      vérifié (`Active_Bag` passe à `BagTintBlue` dès son achat, remplaçant `BagTintRed`).
- [x] C3 conforme : changer d'objet actif parmi ceux possédés, sans nouvel achat — vérifié
      (`SetActiveCosmetic` vers `BagTintRed` déjà possédé, solde inchangé).
- [x] C4 conforme : un avantage acheté s'applique dès la partie suivante — vérifié (`BagCapacity`
      reste à 5 pendant la partie en cours après achat de `BiggerBag`, puis passe à 8 au début de
      la partie suivante, `Dev.EndMatch` → nouvelle partie).
- [x] C5 conforme : une défaite/victoire ne retire ni objets, ni avantages, ni objet actif — vérifié
      (tous les `Owned_*`/`Active_*` identiques après la transition de partie déclenchée pour C4).
- [ ] C6 conforme : tout survit à un redémarrage complet du serveur — **non confirmable dans cet
      environnement** : `DataStoreService` est bloqué en Studio (`StudioAccessToApisNotAllowed`,
      même limitation déjà rencontrée en 006/007), donc aucune écriture réelle n'a lieu ; à
      revalider séparément dans un environnement où `DataStoreService` fonctionne pleinement.
- [x] C7 conforme : aucun blocage si la sauvegarde échoue — vérifié (les échecs `SetAsync`/`GetAsync`
      apparaissent bien dans la console à chaque achat/changement, mais achats et changements
      d'objet actif continuent de fonctionner en mémoire sans interruption).
- [x] C8 conforme : aucune autorité critique côté client — revue de code (`BuyItem`/
      `SetActiveCosmetic` revalident tout côté serveur) + `grep` confirmant qu'aucun fichier client
      n'écrit `Currency`/`Owned_*`/`Active_*`.
- [x] Réglages centralisés : `Bag.MediumCapacity` et le domaine `Boutique` dans `Settings.luau`,
      le catalogue dans `Catalog.luau` — aucune valeur codée en dur ailleurs.
- [x] La boucle reste jouable de bout en bout sans jamais utiliser la boutique — elle ajoute une
      option, ne remplace ni ne conditionne aucune étape existante (comportement par défaut de
      `BagService` inchangé, confirmé par lecture de code : `assignBag`/`defaultType` non modifiées).
