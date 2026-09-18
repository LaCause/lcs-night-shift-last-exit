# Quickstart — valider le vidage progressif et le dépôt automatique

Suite de `specs/004-sac-collecte/quickstart.md` (V1 à V7) : mêmes prérequis et même mise en place
(`rojo serve` ou `rojo build`). Ce guide ajoute les scénarios propres à cette fonctionnalité.

## Scénarios de validation

### W1 — Pression brève : un seul objet, le plus récent (US2 ; FR-001, FR-004, SC-004)

1. Play en solo, sac équipé. Ramasser dans l'ordre : Essence, Ferraille, Essence (`Dev.
   GiveResources` répété avec des types différents, ou récolte réelle).
2. Presser brièvement `G` (relâcher avant `Bag.DropHoldThreshold`).
   - **Attendu** : un seul objet quitte le sac — la **deuxième Essence** (la dernière ramassée) —
     et non la Ferraille ni la première Essence. La ligne « Sac » passe de `3/5` à `2/5`.
3. Répéter la pression brève deux fois de plus.
   - **Attendu** : Ferraille puis la première Essence sortent, dans cet ordre — l'inverse exact du
     ramassage (FR-004).
4. Presser `G` avec le sac vide.
   - **Attendu** : rien ne se produit, aucune erreur.

### W2 — Maintien : vidage complet en une seule action (US2 ; FR-002, SC-005, Clarifications Q1)

1. Ramasser 4 objets de types différents. Maintenir `G` au-delà du seuil.
   - **Attendu** : les 4 objets quittent le sac en une seule fois (pas de défilé visible objet par
     objet) ; la ligne « Sac » passe directement à `0/5`.
2. Continuer à maintenir `G` après que le sac est vide.
   - **Attendu** : rien d'autre ne se produit ; aucune erreur, aucun deuxième déclenchement.
3. Relâcher `G`, ramasser 1 objet, maintenir de nouveau `G`.
   - **Attendu** : un nouveau vidage se déclenche normalement (le geste précédent ne bloque rien).
4. Vérifier le journal serveur après plusieurs cycles ramassage/maintien rapprochés.
   - **Attendu** : aucun refus `RateLimited` — chaque maintien ne coûte qu'une seule intention
     (research R4), comme une seule pression.

### W3 — Dépôt automatique à chaque poste compatible (US1 ; FR-005, FR-006, FR-009, SC-001, SC-002)

1. Ramasser de l'Essence, s'approcher du générateur à sa portée d'interaction habituelle
   (`Generator.InteractRange`), vider le sac (pression ou maintien).
   - **Attendu** : le carburant du générateur augmente exactement du montant transporté ; la
     notification et le son sont ceux de `GeneratorFueled`, identiques à un ravitaillement manuel ;
     aucun objet n'apparaît au sol ; aucune notification `BagDropped`.
2. Répéter avec du Steak suspect ou du Pain de route près du comptoir (`Forest.HarvestRange`).
   - **Attendu** : le stock partagé augmente ; notification `ResourceDeposited`, comme un dépôt
     manuel.
3. Répéter avec de la Ferraille près du bus (`Bus.InteractRange`).
   - **Attendu** : la progression de réparation du bus augmente ; notification `ScrapDeposited`
     (et `BusRepaired` si le seuil est atteint), comme un dépôt manuel.
4. Vérifier `Dev.ShowGameplayState` avant/après chaque dépôt automatique.
   - **Attendu** : les compteurs affichés (générateur, stock, bus) correspondent exactement à ce
     qu'un dépôt manuel aurait produit pour le même montant.

### W4 — Postes incompatibles, hors de portée ou déjà pleins (US1 ; FR-007, FR-008, SC-003)

1. Vider un sac de Ferraille près du générateur (type incompatible).
   - **Attendu** : la ferraille tombe au sol normalement, ramassable et déplaçable ; notification
     `BagDropped` avec le bon compte.
2. Vider un sac d'Essence hors de portée de tout poste.
   - **Attendu** : idem — au sol, rien perdu.
3. Remplir le générateur à sa capacité maximale (`Dev.` répété ou attente), puis vider de
   l'Essence à sa portée.
   - **Attendu** : l'essence tombe au sol au lieu de disparaître sans effet ; le carburant du
     générateur n'augmente pas au-delà de sa capacité.
4. Vider un sac mixte (Essence + Ferraille + Steak suspect) près du seul générateur.
   - **Attendu** : seule l'Essence est absorbée ; Ferraille et Steak suspect tombent au sol ;
     `BagDropped` ne compte que ces deux derniers.

### W5 — Cohérence de la mesure de portée, effet assumé (Clarifications Q2, Edge Cases)

1. Se placer à une distance du générateur légèrement supérieure à sa portée d'interaction (le
   joueur lui-même est donc hors de portée), avec plusieurs Essence dans le sac.
2. Maintenir `G` pour tout vider.
   - **Attendu** : selon l'angle d'atterrissage de chaque unité dans le cercle de dépose
     (`Bag.DropRadius`), certaines Essence peuvent atterrir dans la portée du générateur et être
     déposées, d'autres juste en dehors et tomber au sol — **dans la même action**. C'est le
     comportement attendu (research R5) : la distance qui compte est celle de chaque objet à sa
     position d'arrivée, jamais celle du joueur. Aucune incohérence à corriger ici.

### W6 — Conservation et absence de duplication (FR-012, SC-006, SC-008 de 004)

1. Noter le total transporté (`Dev.ShowGameplayState`). Vider le sac près d'un poste compatible
   plein pour un des types (mélange dépôt + sol).
2. Ramasser tout ce qui est resté au sol.
   - **Attendu** : le total transporté après ce cycle est identique au total initial moins ce qui
     a été réellement absorbé par le poste — jamais plus, jamais moins.
3. Enchaîner plusieurs cycles vider/ramasser/déposer.
   - **Attendu** : aucune divergence cumulée entre les compteurs affichés et le contenu réel du
     monde.

### W7 — Interruption avant le seuil de maintien (Edge Cases)

1. Maintenir `G` puis relâcher juste avant `Bag.DropHoldThreshold`.
   - **Attendu** : traité comme une pression brève — un seul objet sort, jamais un vidage partiel.
2. Maintenir `G` au-delà du seuil, puis se déconnecter (fermer le client) immédiatement après.
   - **Attendu** : le vidage complet, déjà résolu côté serveur en une seule fois au moment où le
     seuil a été franchi, n'est jamais laissé à moitié fait par la déconnexion qui suit.

### W8 — Contrôles statiques (complète V6 de 004-sac-collecte)

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante
  (`SfxController.luau`, variation de hauteur des sons) ; aucune dans le calcul de position en
  cercle ni dans la correspondance objet-poste.
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Relire `BagService.empty` : confirme l'appel à `InventoryService.clearCarried`, plus aucune
  écriture directe d'attribut `Inv_*` (research R6).
- Relire `RepairBus` : confirme l'appel à `BusService.deposit`, comportement observable inchangé
  (research R7).

## Checklist de fin (complète celles du socle, de 002, 003 et 004)

- [ ] Solo : W1 à W4 et W6 conformes.
- [ ] Multijoueur local (2 clients) : un joueur vide son sac près d'un poste pendant qu'un
      coéquipier dépose manuellement au même poste — les deux contributions s'additionnent
      correctement, sans perte ni double comptage.
- [ ] Aucune autorité critique côté client : la distinction pression/maintien n'est qu'un choix
      client, revalidé par le serveur (W2.4, W7) ; la portée et la capacité du dépôt automatique
      sont décidées côté serveur (W4.3, W5).
- [ ] Réglages centralisés : `Bag.DropHoldThreshold` dans `Settings.luau`, aucune valeur codée en
      dur.
- [ ] Comportements de secours : poste plein → objet au sol (W4.3) ; poste incompatible ou hors
      de portée → objet au sol (W4.1, W4.2) ; déconnexion après le seuil de maintien → jamais à
      moitié fait (W7.2).
- [ ] Conservation : aucune ressource créée ni perdue sur l'ensemble de W6.
- [ ] La boucle reste jouable de bout en bout, le dépôt automatique en plus : explorer → ramasser
      au pointeur → vider près d'un poste (ou déposer manuellement) → préparer et livrer →
      réparer le bus → partir en vainqueur.
