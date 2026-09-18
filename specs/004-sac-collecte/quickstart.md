# Quickstart — valider le sac et la manipulation des objets

Suite de `specs/001-socle-technique/quickstart.md`,
`specs/002-premier-increment-jouable/quickstart.md` et
`specs/003-bus-evasion/quickstart.md` : mêmes prérequis et même mise en place (`rojo serve` ou
`rojo build`). Ce guide ajoute les scénarios propres à cette fonctionnalité.

**Prérequis spécifique** : l'asset `LittleBag` doit être présent dans
`ReplicatedStorage.Assets`. Le scénario V5 valide justement le cas où il est absent.

## Scénarios de validation

### V1 — Ramasser au pointeur, sac en main (US1 ; SC-001, SC-004, FR-019)

1. Play en solo, profil de test actif.
   - **Attendu** : les nœuds de ressource **n'affichent plus d'invite de proximité** ; les
     invites des postes (comptoir, générateur, plan de travail, fenêtre, bus, sonnette) sont
     toujours là. La ligne « Sac » du HUD indique `0/5 · non équipé`.
2. **Sac encore rangé**, viser un nœud de ressource à portée puis appuyer sur F.
   - **Attendu** : l'indice au pointeur affiche « Équipez votre sac pour ramasser » ; **rien
     n'est ramassé**, le nœud reste dans le monde (FR-019).
3. Équiper le sac depuis la barre d'inventaire (touche `1`).
   - **Attendu** : le modèle du sac apparaît sur le personnage et la ligne « Sac » perd la
     mention « non équipé ».
4. Viser de nouveau le même nœud.
   - **Attendu** : le nœud se met en surbrillance ; la première ligne de l'indice donne la touche
     de ramassage et le nom de la ressource, la seconde rappelle le clic maintenu.
5. Appuyer sur F.
   - **Attendu** : la ressource rejoint le sac (`Inv_*` augmente), le nœud devient indisponible
     puis réapparaît après `Forest.RespawnDelay`, la ligne « Sac » passe à
     `1/5 · [G] vider au sol`.
6. Viser le même type de nœud **hors de portée** (`Forest.HarvestRange`) et appuyer sur F.
   - **Attendu** : aucune surbrillance active à cette distance, aucun ramassage ; le nœud reste
     dans le monde.
7. Viser le décor, le ciel ou un coéquipier, appuyer sur F.
   - **Attendu** : rien ne se produit, aucun message d'erreur intrusif.

### V2 — Contenance du sac et refus « sac plein » (US1 ; SC-002, SC-006)

1. Remplir le sac avec `Dev.FillBag` (ou par récolte réelle) jusqu'à `5/5`.
   - **Attendu** : la ligne « Sac » affiche `5/5`.
2. Viser un nœud disponible et appuyer sur F.
   - **Attendu** : **aucun ramassage**, le nœud reste disponible dans le monde, et un retour
     clair indique que le sac est plein (notification `BagFull`).
3. Déposer au comptoir, puis retenter le ramassage.
   - **Attendu** : le dépôt vide les types concernés, la ligne « Sac » redescend, le ramassage
     refonctionne immédiatement.
4. Changer `Bag.SmallCapacity` de 5 à 8 dans `Settings.luau`, relancer.
   - **Attendu** : le nouveau plafond s'applique sans aucune autre modification (SC-006), et la
     ligne « Sac » affiche `n/8`.
5. Vérifier qu'aucun `Forest.InventoryCapacity` ne subsiste :
   `grep -rn "InventoryCapacity" src` → aucun résultat.

### V3 — Le sac dans l'inventaire natif (US2 ; SC-004)

1. Ouvrir l'inventaire (barre du sac à dos) en jeu.
   - **Attendu** : le sac « LittleBag » y figure ; l'équiper affiche son modèle sur le
     personnage.
2. Tenter de lâcher le sac (`Backspace` avec le sac équipé).
   - **Attendu** : le sac **ne peut pas être lâché** (`CanBeDropped = false`) — le joueur ne peut
     pas se retrouver sans contenance.
3. Se faire éliminer, puis réapparaître.
   - **Attendu** : le sac est de nouveau présent dans le sac à dos après la réapparition (le
     `Backpack` est recréé à chaque apparition, research R2), et son contenu est bien vide
     (règle d'élimination existante).

### V4 — Déplacer un objet sans le ramasser (US3 ; SC-003, SC-005)

1. Viser un nœud disponible, maintenir le clic et bouger la souris.
   - **Attendu** : l'objet suit le pointeur ; la ligne « Sac » **ne change pas** (déplacer n'est
     pas ramasser).
2. Relâcher le clic.
   - **Attendu** : l'objet reste à sa nouvelle position, et y reste après quelques secondes.
3. Tenter d'éloigner l'objet au-delà de `Bag.CarryRange` en reculant.
   - **Attendu** : le serveur ramène l'objet et force le relâchement ; l'objet ne peut pas être
     emmené à l'autre bout de la carte.
4. Pendant un déplacement, se faire éliminer (`Dev.SetStatus` → `Eliminated`) ou quitter la
   partie.
   - **Attendu** : l'objet est relâché proprement à sa dernière position valide et redevient
     saisissable (FR-014) ; il n'est ni bloqué, ni perdu.
5. Vérifier le budget de cadence : enchaîner plusieurs déplacements puis ramasser aussitôt.
   - **Attendu** : aucun refus `RateLimited` dans le journal — un déplacement ne coûte que deux
     intentions (research R4).

### V5 — Multijoueur et comportements de secours (SC-003, SC-005 ; principe VI)

**Clients and Servers**, au moins 2 joueurs.

1. Le joueur A déplace un objet ; observer l'écran du joueur B.
   - **Attendu** : B voit l'objet bouger, et le voit finir exactement au même endroit que A.
2. Pendant que A tient l'objet, B vise ce même objet et tente de le saisir puis de le ramasser.
   - **Attendu** : les deux tentatives sont refusées proprement (`AlreadyCarried`), sans que
     l'objet change de porteur ni soit dupliqué.
3. A relâche ; B saisit immédiatement le même objet.
   - **Attendu** : la saisie réussit (l'exclusivité est bien libérée).
4. A et B visent le même nœud et appuient sur F quasi simultanément.
   - **Attendu** : un seul l'obtient ; l'autre ne reçoit rien et le nœud n'est pas dupliqué.
5. Retirer temporairement `LittleBag` de `ReplicatedStorage.Assets` et relancer.
   - **Attendu** : le sac fonctionne avec son remplaçant en primitives — contenance, ramassage,
     dépôt et déplacement inchangés ; un avertissement explicite apparaît au journal, jamais une
     erreur bloquante (principe VIII).

### V6 — Contrôles statiques (complète V4 de 003)

- `grep -rn "math.random" src` → **une seule** occurrence, dans `SfxController.luau` (variation de
  hauteur des sons, antérieure à cette fonctionnalité). Aucune dans la génération du monde ni dans
  une règle de jeu : le déterminisme du principe V est intact. Toute occurrence ailleurs est un
  écart à corriger — en particulier la pose des objets lâchés, dont l'angle dérive du rang de
  l'objet, sans aucun tirage.
- `grep -rn "InventoryCapacity" src` → aucun résultat (réglage retiré, research R6).
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Relire `ForestService.luau` : confirmer qu'aucune invite de proximité n'est créée pour les
  nœuds, et que les invites des postes ne sont pas touchées (research R9).

### V7 — Vider le sac au sol (US1 ; FR-020, FR-021, SC-008)

1. Sac en main, ramasser 3 objets de types différents, puis appuyer sur `G`.
   - **Attendu** : les 3 objets se posent au sol en cercle autour du joueur, la ligne « Sac »
     retombe à `0/5`, et le fil du HUD confirme « Sac vidé au sol : 3 objet(s) ».
2. Ramasser de nouveau les objets posés.
   - **Attendu** : ils rejoignent le sac normalement **et ne réapparaissent pas** au sol après
     `Forest.RespawnDelay` — un objet lâché ne repousse jamais (FR-021).
3. Enchaîner plusieurs cycles vider/ramasser et comparer le total transporté.
   - **Attendu** : le total est strictement identique à chaque tour ; aucune ressource n'est
     créée ni perdue (SC-008).
4. Appuyer sur `G` avec un sac vide, puis avec le sac rangé dans l'inventaire.
   - **Attendu** : rien ne se produit dans les deux cas, aucun message d'erreur.
5. Saisir au clic un objet qui vient d'être lâché et le déplacer.
   - **Attendu** : il se déplace comme n'importe quel autre objet, **sans que le sac soit
     nécessaire** (FR-022) : un objet lâché est un objet du monde à part entière.
6. Vider son sac dos à un mur ou en hauteur.
   - **Attendu** : les objets se posent sur le sol trouvé autour du joueur, jamais dans le vide
     ni à l'intérieur du décor.

## Checklist de fin (complète celles du socle, de 002 et de 003)

- [ ] Solo : V1 à V4 conformes.
- [ ] Multijoueur local (2 clients) : V5 conforme, y compris le refus `AlreadyCarried` et la
      cohérence de la position finale entre les deux clients.
- [ ] Aucune autorité critique côté client : ramassage validé par le pipeline inchangé ; prise,
      bornage et position finale décidés par le serveur — vérifié en tentant d'emmener un objet
      au-delà de `Bag.CarryRange` (V4.3).
- [ ] Réglages centralisés : domaine `Bag` entièrement dans `Settings.luau`, aucune valeur codée
      en dur, et `Forest.InventoryCapacity` bien retiré.
- [ ] Comportements de secours : asset absent → primitives (V5.5) ; mort ou déconnexion en cours
      de déplacement → relâchement propre (V4.4) ; sac plein → refus explicite et objet conservé
      (V2.2).
- [ ] Sac en main exigé dans les deux sens : ni ramassage (V1.2) ni vidage (V7.4) sans le sac
      équipé, et l'interface le dit avant l'appui sur la touche.
- [ ] Aucune duplication possible : vider puis tout ramasser conserve exactement le même total, et
      un objet lâché ne réapparaît jamais (V7.2, V7.3).
- [ ] Performances : aucun gel perceptible à 6 joueurs manipulant des objets simultanément, et
      aucun refus `RateLimited` provoqué par les déplacements (V4.5).
- [ ] La boucle reste jouable de bout en bout : explorer → ramasser au pointeur → déposer →
      préparer et livrer → réparer le bus → partir en vainqueur.
