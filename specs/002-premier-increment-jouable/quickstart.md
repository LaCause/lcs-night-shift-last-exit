# Quickstart — valider le premier incrément jouable

Suite de `specs/001-socle-technique/quickstart.md` : reprend les mêmes prérequis et la même
mise en place (`rojo serve` ou `rojo build`). Ce guide ajoute les scénarios propres au
gameplay ; il ne répète pas V1/V2/V9/V10 du socle, toujours valables.

## Scénarios de validation

### V1 — Récolte en forêt (US1 ; SC-002, SC-009)

1. Play en solo, sortir du restaurant.
   - **Attendu** : des nœuds de ressource (essence, steak suspect, pain de route) sont visibles
     dans `Workspace.Forest`, entre `Forest.AreaMinRadius` et `Forest.AreaMaxRadius` studs du
     restaurant.
2. S'approcher d'un nœud et interagir (prompt de proximité).
   - **Attendu** : le nœud devient invisible/inactif immédiatement ; la ressource apparaît dans
     l'inventaire du joueur (`Dev.ShowGameplayState`).
3. Attendre `Forest.RespawnDelay` (réglé court en profil de test).
   - **Attendu** : le nœud redevient visible et récoltable.
4. Déposer au comptoir (`Counter`).
   - **Attendu** : le stock partagé augmente (`Dev.ShowGameplayState`), l'inventaire personnel
     du joueur pour ce type revient à zéro.
5. Forcer `Match.ForcedSeed` à une valeur fixe, relancer deux fois.
   - **Attendu** : mêmes emplacements de nœuds aux deux lancements (SC-009).

### V2 — Générateur, néon et zone de sécurité (US2)

1. Play en solo, observer `Dev.ShowGameplayState` répété pendant quelques dizaines de secondes.
   - **Attendu** : le carburant diminue régulièrement (`Generator.DrainPerSecond`).
2. Récolter de l'essence, la déposer au générateur (`RefuelGenerator`).
   - **Attendu** : le carburant augmente (plafonné à `Generator.Capacity`) ; si l'inventaire
     dépasse la capacité restante, le surplus reste dans l'inventaire du joueur.
3. Laisser le carburant s'épuiser complètement (ou le forcer via un profil de test avec un
   `DrainPerSecond` élevé).
   - **Attendu** : la lumière de la zone de sécurité s'éteint, une notification
     `GeneratorEmpty` s'affiche.
4. Déposer à nouveau de l'essence.
   - **Attendu** : la lumière se rallume, notification `GeneratorRefueled`.

### V3 — Commande de la nuit (US3)

1. Profil de test actif, attendre le début d'une nuit.
   - **Attendu** : `OrderState.Status` passe à `Pending`, notification `OrderStarted`, HUD
     affiche la recette et son délai (fin de la nuit).
2. Sans les ingrédients requis dans le stock, tenter `PrepareOrder` au plan de travail.
   - **Attendu** : refusé `MissingIngredients`, aucun effet sur le stock.
3. Récolter/déposer les ingrédients requis, refaire `PrepareOrder`.
   - **Attendu** : `Status` passe à `Prepared`, le stock diminue des quantités utilisées.
4. Livrer à la fenêtre du drive-thru (`DeliverOrder`).
   - **Attendu** : `Status` passe à `Delivered`, notification `OrderDelivered` chez tous les
     joueurs.
5. Retenter `DeliverOrder` la même nuit.
   - **Attendu** : refusé `OrderClosed`, sans effet.

### V4 — Échec de commande et ennemi (US4)

1. Profil de test actif, laisser une nuit se terminer sans livrer la commande.
   - **Attendu** : `Status` passe à `Failed`, notification `OrderFailed`, un ennemi apparaît au
     point de référence `EnemySpawn` en moins de 5 s (SC-006).
2. Rester dans la zone de sécurité pendant que l'ennemi est actif.
   - **Attendu** : aucun dégât reçu, quelle que soit la durée (SC-007).
3. Sortir de la zone de sécurité à portée de l'ennemi.
   - **Attendu** : perte de santé au contact (`Player.Health` diminue), notification ciblée
     `EnemyHit`, un délai minimal (`Enemy.ContactCooldown`) s'écoule avant un nouveau contact.
4. Rester hors de portée de tout joueur (ou utiliser `Dev.SpawnEnemy` puis s'éloigner).
   - **Attendu** : l'ennemi se replie ou disparaît après `Enemy.GiveUpDelay`, jamais bloqué
     indéfiniment (SC-008).
5. Laisser la santé du joueur atteindre 0 (contacts répétés, ou `Dev.GiveResources`/combat
   réel).
   - **Attendu** : le statut du joueur passe à « Éliminé », sans réapparition automatique ; la
     règle de défaite déjà en place dans le socle s'applique si c'est le dernier joueur en vie.
6. Changer de phase (nuit → jour) pendant que l'ennemi est actif.
   - **Attendu** : l'ennemi disparaît immédiatement.

### V5 — Ambiance jour/nuit (US5)

1. Profil de test actif, observer un passage Jour → Nuit puis Nuit → Jour.
   - **Attendu** : l'éclairage s'assombrit et le brouillard s'épaissit progressivement sur
     `Ambiance.TransitionDuration`, puis l'inverse au retour au Jour.
2. Comparer la zone de sécurité active (carburant > 0) au reste de la forêt, de nuit.
   - **Attendu** : la zone de sécurité reste visiblement plus éclairée.

### V6 — Multijoueur (avant chaque jalon ; SC-003, SC-010)

1. **Clients and Servers** à 2 joueurs : l'un récolte, l'autre voit le nœud disparaître
   immédiatement et ne peut pas le récolter une seconde fois (edge case du spec).
2. Un joueur prépare, l'autre livre : la commande est acceptée normalement (le stock et l'état
   de commande sont partagés par l'équipe, pas par joueur).
3. À 6 joueurs, une nuit complète avec échec volontaire de la commande : aucune erreur, aucun
   gel perceptible à l'apparition de l'ennemi, à la préparation ni à la livraison (SC-010).

### V7 — Contrôles statiques (complète V9 du socle)

- `grep -rn "math.random" src` → toujours aucun résultat, y compris dans `ForestService` et
  `EnemyService` (utiliser `MatchService.rng` partout).
- `selene src` et `stylua --check src` → aucun écart sur les nouveaux fichiers.

## Checklist de fin (complète celle du socle)

- [x] Solo : V1 à V5 conformes (validé en Studio le 2026-09-13 : récolte, dépôt, ravitaillement
      du générateur avec extinction/rallumage du néon, préparation et livraison réussies,
      échec de commande avec apparition de l'ennemi, protection de la zone de sécurité,
      dégâts de contact avec délai de réutilisation respecté, élimination et défaite, plusieurs
      parties enchaînées avec seeds différentes, aucune erreur sur ~3 parties complètes).
- [ ] Multijoueur local (2 clients) : V6.1 et V6.2 conformes. *(pas encore testé : une seule
      session Studio disponible pour cette validation)*
- [x] Aucune autorité critique côté client : toute action (récolte, dépôt, préparation,
      livraison) passe par une intention validée par `NetService`, y compris la résolution de
      cible dynamique (`ForestService.findNode`) — vérifié via un refus `NodeUnavailable` sur
      un nœud déjà récolté.
- [ ] Performances : V6.3 (6 joueurs, une nuit complète) sans gel perceptible, avant le jalon
      MVP. *(pas encore testé)*
- [x] Réglages centralisés : tous les nouveaux réglages sont dans `Settings.luau`
      (contracts/config.md), aucun codé en dur (valeurs vérifiées en jeu via
      `Dev.ShowGameplayState` et lecture directe de l'état répliqué).
- [x] Comportements de secours : nœud indisponible refusé proprement (`NodeUnavailable`) ;
      ennemi sans cible atteignable (joueur protégé) se replie après `Enemy.GiveUpDelay` sans
      jamais rester bloqué (V4.4) ; le repli en ligne droite en cas d'échec du calcul de chemin
      n'a pas été déclenché isolément (terrain ouvert), mais son code est identique au chemin
      normal, revu et sans erreur à l'exécution.
- [x] La boucle est jouable de bout en bout en solo : explorer → alimenter le générateur →
      préparer et livrer une commande → survivre à un échec (principe II, satisfait pour la
      première fois depuis le socle) — validé de bout en bout, y compris la défaite et le
      redémarrage automatique.
