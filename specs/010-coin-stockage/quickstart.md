# Quickstart — valider le coin de stockage

Prérequis inchangés : `rojo serve` (ou `rojo build`), Studio connecté. `Dev.GiveResources` donne une
unité de chaque ressource par appel (Essence, SuspectSteak, RoadBread, Scrap) ; l'établi (009)
fournit les objets fabriqués (`HealKit`, `FuelCanister`). Le sac (5 places) doit être **en main**
pour lâcher et pour reprendre vers le sac. Le coin de stockage est l'angle nord-ouest de
l'arrière-salle : la zone marquée au sol, cerclée de néon cyan, avec le message « Stockage n/N » au
dessus. Les scénarios S8 et S9 exigent **deux clients** (test Studio « Clients and Servers »).

## Scénarios de validation

### S1 — Ranger avec le lâcher bref (US1 ; FR-002, FR-005, SC-001)

1. Sac en main avec au moins deux objets, se placer dans le coin de stockage, appuyer brièvement sur
   la touche de lâcher (G).
   - **Attendu** : le dernier objet ramassé quitte le sac (`Inv_*` −1) et apparaît **immédiatement**
     posé sur l'emplacement 1, à sa taille réelle, sans être passé par le sol ; l'indicateur passe à
     « Stockage 1/12 » ; le son de dépôt retentit.
2. Recommencer avec l'objet suivant.
   - **Attendu** : il occupe l'emplacement 2 (plus bas index libre), à côté du premier.

### S2 — Ranger tout le sac avec l'appui long (FR-003)

1. Sac chargé de plusieurs objets, dans le coin, maintenir G.
   - **Attendu** : les objets se rangent du plus récent au plus ancien, un par emplacement ; le sac
     est vide ; l'indicateur reflète le total. Avec plus d'objets que d'emplacements libres, les
     derniers tombent au sol comme avant (voir S7).

### S3 — Un objet rangé est figé (US1 ; FR-006, SC-002)

1. Marcher au travers des objets rangés et autour.
   - **Attendu** : rien ne bouge ni ne bloque le joueur ; les objets restent exactement où ils sont.
2. Depuis **hors de portée** (plus de 6 studs), viser un objet rangé, puis F, puis clic maintenu.
   - **Attendu** : aucun effet, l'objet reste rangé ; le journal du pipeline montre `TooFar`
     (`Dev.GetRejections`).

### S4 — Reprendre vers le sac, à proximité seulement (US2 ; FR-007, FR-008, SC-003)

1. Viser un objet rangé depuis trois distances : dans le coin, juste au-delà de 6 studs, très loin.
   Appuyer sur la touche de ramassage (F) à chaque fois.
   - **Attendu** : seul le cas « dans le coin » réussit : l'objet rejoint le sac, son emplacement
     redevient libre, l'indicateur baisse d'un.
2. Reprendre avec le sac **plein**, puis avec le sac **rangé**.
   - **Attendu** : refusé comme un ramassage au sol (« Sac plein » / indice d'équiper le sac), l'objet
     reste rangé.

### S5 — Tirer un objet hors du coin (US2 ; FR-018)

1. Dans le coin, viser un objet rangé, maintenir le clic gauche et tirer.
   - **Attendu** : l'emplacement se libère **dès la saisie** (l'indicateur baisse), l'objet suit la
     souris, **même sac rangé ou plein**.
2. Relâcher : (a) sur le sol hors du coin ; (b) au-dessus du coin ; (c) sur l'établi.
   - **Attendu** : (a) posé là comme un objet ordinaire, ramassable ; (b) rangé de nouveau sur un
     emplacement libre ; (c) compté comme ingrédient si la recette l'attend.

### S6 — Ranger un objet du monde par glisser-déposer (US3 ; FR-004)

1. Lâcher un objet au sol à quelques pas du coin (G), le saisir à la souris et le relâcher au-dessus
   du coin.
   - **Attendu** : il disparaît du sol et apparaît figé sur un emplacement libre, sans passer par le
     sac.
2. Le relâcher **en dehors** du coin, puis **dans** un coin plein.
   - **Attendu** : posé simplement là où il est relâché ; dans un coin plein, message « stockage plein ».
3. Glisser une ressource naturelle de la forêt (si à portée) sur le coin.
   - **Attendu** : rangée ; le nœud d'origine réapparaît après `Forest.RespawnDelay`.

### S7 — Stockage plein (FR-009, SC-006)

1. Remplir les 12 emplacements. Tenter d'en ranger un de plus (lâcher bref, appui long, glisser).
   - **Attendu** : rien n'est rangé, **aucun objet ne disparaît** : le lâcher suit son chemin habituel
     (sol), le glisser laisse l'objet où il est ; un seul message « Stockage plein » par cadence,
     même sur un appui long ; l'indicateur reste à 12/12.

### S8 — Un stock commun (US4 ; FR-010, SC-005) — deux clients

1. Client A range un objet. Client B, dans le coin, regarde.
   - **Attendu** : B voit l'objet au même emplacement en moins d'une seconde et peut le reprendre
     (F ou tiré) ; A voit l'emplacement se libérer.
2. Client A range des objets puis quitte la partie.
   - **Attendu** : ses objets restent rangés et disponibles pour B.

### S9 — Concurrence (FR-011, SC-004) — deux clients

1. Ne laisser qu'un emplacement libre. A et B rangent chacun un objet au même instant.
   - **Attendu** : exactement un objet est rangé ; l'autre reste dans le sac (ou tombe au sol selon le
     geste) sans perte ni copie.
2. A et B visent le même objet rangé et appuient sur F au même instant.
   - **Attendu** : un seul l'obtient ; aucun objet fantôme, l'indicateur est cohérent.
3. Comptabilité : sac A + sac B + objets au sol + stock = constant sur 50 cycles ranger/reprendre.

### S10 — Nouvelle partie (FR-013)

1. Ranger quelques objets, finir la partie (`Dev.EndMatch`) et en relancer une.
   - **Attendu** : le coin est vide (`Count = 0`, plus aucun objet figé), indicateur « Stockage 0/12 ».

### S11 — Autorité et secours (FR-014, FR-017, principes III et VI)

- Relire `StorageService.luau` : aucun `OnServerEvent`, aucune intention ; toute décision (portée,
  emplacement libre, libération) est prise côté serveur ; le client ne fait que viser et envoyer les
  gestes existants.
- Un attribut modifié côté client (par exemple `Stored`) ne débloque rien : la reprise dépend du
  crochet serveur.
- Journal de démarrage : `Stockage prêt (12 emplacements)` sans avertissement ni erreur
  (chevauchement établi/stockage, portée, taille de grille).
- `Dev.TestVisualFallback` (existant) : un visuel absent laisse le rangement fonctionner avec le
  remplaçant en primitives ; si l'apparition échoue, rien n'est prélevé du sac.

### S12 — Contrôles statiques

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante (`SfxController.luau`).
- `selene src` et `stylua --check` → aucun écart sur les fichiers nouveaux ou modifiés.
- Le comportement de `BagService` et d'`InventoryService` reste strictement inchangé ; la récolte
  d'un nœud ordinaire et la saisie d'un objet lâché au sol se comportent exactement comme avant.

## Checklist de fin

- [x] S1 conforme (rangement bref, plus bas index libre)
- [x] S2 conforme (appui long, ordre du plus récent)
- [x] S3 conforme (objet figé, hors de portée : `TooFar`)
- [x] S4 conforme (trois distances, sac plein, sac rangé)
- [x] S5 conforme (tiré hors du coin, trois façons de le relâcher)
- [x] S6 conforme (glisser-déposer, hors coin, coin plein, ressource naturelle)
- [x] S7 conforme (stock plein, aucun objet perdu, un message par cadence)
- [ ] S8 conforme (vue partagée, déconnexion) — deux clients *(non validé : un seul client disponible pour les tests ; à faire manuellement)*
- [ ] S9 conforme (concurrence, comptabilité constante) — deux clients *(simulation mono-client réussie : deux rangements simultanés, un seul emplacement libre → un seul aboutit, aucune perte ; vraie concurrence à deux joueurs à valider manuellement)*
- [x] S10 conforme (vidé à chaque partie)
- [x] S11 conforme (autorité, secours, journal de démarrage propre)
- [x] S12 conforme (contrôles statiques)
- [x] Réglages centralisés : le domaine `Storage` dans `Settings.luau`, aucune valeur codée en dur
- [x] La boucle reste jouable de bout en bout sans jamais utiliser le stock
