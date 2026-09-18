# Feature Specification: Sac de collecte et manipulation des objets à la souris

**Feature Branch**: `004-sac-collecte`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description : les objets collectables vont dans un sac (« LittleBag », présent dans
`ReplicatedStorage.Assets`) accessible depuis l'inventaire, limité à 5 objets au total, avec des
sacs de plus grande contenance prévus plus tard. On ramasse un objet en le pointant avec la souris
et en appuyant sur F ; on peut aussi simplement le déplacer en le sélectionnant et en maintenant
le clic pour le poser ailleurs.

**Axes d'évolutivité renforcés** : exploration procédurale (la collecte devient une manipulation
directe du monde plutôt qu'une invite automatique) et coopération (une contenance volontairement
réduite impose des arbitrages, des allers-retours et une répartition des rôles de portage entre
coéquipiers).

## Clarifications

### Session 2026-09-16

- Q: Le sac remplace-t-il l'inventaire personnel actuel, ou s'ajoute-t-il à côté ? → A: Il le
  remplace — le sac devient l'unique contenant de portage, et sa contenance de 5 objets se
  substitue à la capacité d'inventaire actuelle de 10.
- Q: Que signifie « accessible depuis l'inventaire » ? → A: Le sac est un objet équipable depuis
  l'inventaire natif du joueur (barre du sac à dos) ; une fois équipé, son modèle est visible sur
  le personnage.
- Q: Quels objets sont déplaçables à la souris ? → A: Uniquement les objets collectables — tout ce
  qui est ramassable est saisissable, et rien d'autre.

### Session 2026-09-17

- Q: Quand un joueur peut-il ramasser un objet ? → A: Uniquement quand son sac est équipé, en
  main. Sac rangé dans l'inventaire, la touche de ramassage reste sans effet et l'indice au
  pointeur explique quoi faire.
- Q: Que peut faire le joueur du contenu de son sac hors d'un poste de dépôt ? → A: Une touche
  dédiée vide le sac au sol ; chaque objet redevient un objet du monde, ramassable et déplaçable
  comme les autres.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ramasser un objet pointé dans un sac à contenance limitée (Priority: P1)

Un joueur explore la forêt, vise un objet collectable avec sa souris et appuie sur la touche de
ramassage. L'objet disparaît du monde et rejoint son sac, dans la limite de la contenance de
celui-ci. Quand le sac est plein, le ramassage est refusé avec un retour clair, et l'objet reste
disponible au sol pour un coéquipier ou pour plus tard.

**Why this priority** : c'est le cœur de la fonctionnalité — sans ramassage au pointeur ni sac
limité, rien d'autre n'a de sens. Cette story remplace à elle seule la collecte actuelle et reste
jouable de bout en bout.

**Independent Test** : en solo, pointer successivement plusieurs objets collectables, les ramasser
avec la touche prévue, constater le remplissage progressif du sac, puis vérifier qu'au-delà de la
contenance le ramassage est refusé sans que l'objet disparaisse du monde.

**Acceptance Scenarios**:

1. **Given** un objet collectable à portée et pointé par la souris, **When** le joueur appuie sur
   la touche de ramassage, **Then** l'objet rejoint son sac, disparaît du monde pour tous les
   joueurs, et le contenu du sac affiché est mis à jour.
2. **Given** un objet collectable pointé mais hors de la portée de ramassage, **When** le joueur
   appuie sur la touche de ramassage, **Then** rien n'est ramassé, l'objet reste dans le monde, et
   le joueur comprend qu'il doit s'approcher.
3. **Given** un sac déjà rempli à sa contenance maximale, **When** le joueur pointe un objet
   collectable et appuie sur la touche de ramassage, **Then** le ramassage est refusé proprement,
   l'objet reste dans le monde, et un retour indique que le sac est plein.
4. **Given** deux joueurs qui pointent le même objet, **When** tous deux appuient sur la touche de
   ramassage quasi simultanément, **Then** un seul joueur obtient l'objet et l'autre reçoit un
   refus propre, sans duplication ni disparition sans bénéficiaire.
5. **Given** un joueur portant des objets dans son sac, **When** il est éliminé, **Then** le
   contenu de son sac est perdu, comme les ressources personnelles non déposées le sont déjà.
6. **Given** un joueur dont le sac est rangé dans l'inventaire, **When** il pointe un objet
   collectable et appuie sur la touche de ramassage, **Then** rien n'est ramassé, l'objet reste
   dans le monde, et l'interface indique qu'il faut d'abord équiper le sac.
7. **Given** un joueur dont le sac est en main et contient des objets, **When** il appuie sur la
   touche de vidage, **Then** tout le contenu du sac est posé au sol autour de lui, le sac
   retombe à zéro, et chaque objet posé redevient ramassable et déplaçable par toute l'équipe.

---

### User Story 2 - Accéder au sac depuis l'inventaire (Priority: P2)

Le joueur dispose du sac « LittleBag » dans son inventaire. Il peut le sortir/consulter pour voir
ce qu'il transporte et combien de place il lui reste, sans quitter l'action ni ouvrir un menu
complexe.

**Why this priority** : indispensable pour que la contenance limitée soit lisible et pour que le
joueur arbitre ce qu'il porte, mais la collecte (Story 1) fonctionne déjà sans cette consultation
détaillée.

**Independent Test** : avec un sac partiellement rempli (via une commande de développement),
accéder au sac depuis l'inventaire et vérifier que le contenu et la place restante correspondent
exactement à l'état réel, y compris après un ramassage et après un dépôt.

**Acceptance Scenarios**:

1. **Given** un joueur en partie, **When** il ouvre son inventaire, **Then** le sac « LittleBag »
   y figure comme objet équipable, et l'équiper affiche son modèle sur son personnage, visible
   également par les autres joueurs.
2. **Given** un sac contenant des objets, **When** le joueur y accède, **Then** il voit le détail
   de ce qu'il transporte ainsi que la contenance totale et la place restante.
3. **Given** un sac ouvert/consulté, **When** son contenu change (ramassage, dépôt, élimination),
   **Then** l'affichage reflète immédiatement le nouvel état, sans rechargement manuel.
4. **Given** le modèle d'asset du sac indisponible, **When** le joueur accède à son sac, **Then**
   un visuel de remplacement est utilisé et la fonctionnalité reste entièrement jouable.

---

### User Story 3 - Déplacer un objet sans le ramasser (Priority: P3)

Plutôt que de le mettre dans son sac, un joueur peut saisir un objet en maintenant le clic de la
souris dessus, le déplacer là où il le souhaite, puis le relâcher pour le poser. Cela permet de
réorganiser le décor et de rapprocher des objets d'un poste de travail sans consommer de place
dans le sac.

**Why this priority** : c'est un confort de manipulation et un levier de personnalisation, mais la
boucle de collecte reste complète sans lui.

**Independent Test** : saisir un objet déplaçable, le traîner à un autre endroit, le relâcher, et
vérifier qu'il reste à sa nouvelle position pour tous les joueurs — sans que le contenu du sac ait
changé.

**Acceptance Scenarios**:

1. **Given** un objet déplaçable à portée, **When** le joueur maintient le clic dessus et bouge la
   souris, **Then** l'objet suit le pointeur tant que le clic est maintenu et que l'objet reste
   dans la portée autorisée.
2. **Given** un objet en cours de déplacement, **When** le joueur relâche le clic, **Then** l'objet
   est posé à sa position courante et y reste, visible par tous les joueurs.
3. **Given** un objet déjà saisi par un joueur, **When** un autre joueur tente de le saisir,
   **Then** la tentative est refusée proprement et l'objet ne change pas de porteur.
4. **Given** un joueur en train de déplacer un objet, **When** il se déconnecte ou est éliminé,
   **Then** l'objet est relâché proprement à sa dernière position valide et redevient saisissable.

---

### Edge Cases

- Le joueur pointe un objet non collectable (décor, bâtiment, coéquipier) et appuie sur la touche
  de ramassage : rien ne se produit, sans message d'erreur intrusif.
- Le joueur pointe le vide ou le ciel : aucun ramassage, aucun effet.
- Le sac est plein et le joueur veut un objet précis : il doit d'abord déposer ou poser un objet,
  aucun remplacement automatique n'a lieu.
- Un objet est déplacé contre un mur, dans le décor ou hors de la zone jouable : la portée
  autorisée et les collisions empêchent de le perdre définitivement.
- Un objet est déplacé puis relâché à un endroit inatteignable : il reste saisissable, aucun objet
  ne devient définitivement inaccessible.
- Deux joueurs ramassent et déplacent des objets en même temps, à 6 joueurs : aucun ralentissement
  perceptible, aucun objet dupliqué.
- Un joueur rejoint la partie en cours : il voit l'état réel des objets du monde (présents,
  déplacés, déjà ramassés), sans incohérence.
- Une nouvelle partie démarre : les objets du monde et le contenu des sacs sont remis à l'état
  initial, comme le reste de l'état de partie.
- Le joueur appuie sur la touche de ramassage sans son sac en main : rien n'est ramassé, l'objet
  reste dans le monde, et l'indice au pointeur dit quoi faire.
- Le joueur vide un sac déjà vide, ou avec son sac rangé : rien ne se produit, aucun message
  d'erreur.
- Le joueur vide son sac dos à un mur, en hauteur ou au bord du décor : les objets se posent sur
  le sol trouvé autour de lui, jamais dans le vide ni à l'intérieur du décor.
- Un joueur vide son sac puis ramasse aussitôt ce qu'il vient de poser : le total transporté est
  identique — aucune ressource n'est créée par ce cycle.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT indiquer visuellement, quand un joueur pointe un objet collectable à
  portée, que cet objet peut être ramassé et par quelle touche.
- **FR-002**: Un joueur DOIT pouvoir ramasser l'objet qu'il pointe en appuyant sur une touche
  dédiée ; l'objet DOIT alors rejoindre son sac et disparaître du monde pour tous les joueurs.
- **FR-003**: Le sac DOIT avoir une contenance totale maximale, fixée initialement à 5 objets ;
  tout ramassage au-delà DOIT être refusé proprement, sans perte de l'objet visé.
- **FR-004**: La contenance DOIT être une valeur de configuration attachée au type de sac, de façon
  qu'un sac de plus grande contenance puisse être ajouté plus tard sans refonte de la mécanique.
- **FR-005**: Le sac « LittleBag » DOIT figurer dans l'inventaire natif du joueur (barre du sac à
  dos) sous la forme d'un objet équipable ; une fois équipé, son modèle DOIT être visible sur le
  personnage, pour son porteur comme pour les autres joueurs.
- **FR-006**: Le joueur DOIT pouvoir consulter à tout moment le contenu de son sac et la place
  restante, et cet affichage DOIT refléter l'état réel répliqué par le serveur.
- **FR-007**: Le sac DOIT remplacer l'inventaire personnel existant : il devient l'unique contenant
  de portage du joueur, et sa contenance totale (5 objets, toutes ressources confondues) se
  substitue à la capacité d'inventaire actuelle. Aucun second contenant NE DOIT subsister.
- **FR-008**: Un joueur DOIT pouvoir saisir un objet déplaçable en maintenant le clic de la souris
  dessus, le déplacer dans une portée maximale configurable, puis le poser en relâchant le clic.
- **FR-009**: Seuls les objets collectables DOIVENT être déplaçables à la souris : tout objet
  ramassable DOIT aussi être saisissable, et aucun autre élément du décor NE DOIT l'être.
- **FR-010**: Un objet NE DOIT pouvoir être ramassé ou déplacé que par un seul joueur à la fois ;
  toute tentative concurrente DOIT être refusée proprement, sans duplication ni disparition.
- **FR-011**: Le serveur DOIT valider chaque ramassage et chaque déplacement (existence de l'objet,
  distance joueur–objet, phase de jeu, cadence d'appel), comme toutes les intentions déjà en place.
- **FR-012**: La position finale d'un objet déplacé DOIT être décidée par le serveur et répliquée à
  tous les joueurs ; aucun client NE DOIT pouvoir téléporter un objet hors de la portée autorisée.
- **FR-013**: Le contenu du sac d'un joueur éliminé DOIT être perdu, conformément à la règle déjà
  en place pour les ressources personnelles non déposées.
- **FR-014**: Un objet saisi par un joueur qui se déconnecte ou est éliminé DOIT être relâché
  proprement à sa dernière position valide et redevenir saisissable.
- **FR-015**: Les dépôts existants (stock du restaurant, générateur, bus) DOIVENT continuer de
  fonctionner en puisant dans le contenu transporté par le joueur.
- **FR-016**: Le sac DOIT utiliser l'asset « LittleBag » s'il est disponible, et un remplaçant
  construit en primitives sinon, conformément à la règle de secours du catalogue de visuels.
- **FR-017**: Chaque nouvelle partie DOIT réinitialiser le contenu des sacs et l'état des objets du
  monde, comme le reste de l'état de partie.
- **FR-018**: Le panneau de développement DOIT permettre de remplir et de vider un sac, afin de
  tester la contenance et les refus sans dépendre d'une collecte réelle.
- **FR-019**: Un joueur NE DOIT pouvoir ramasser un objet que lorsque son sac est équipé, en main.
  Sac rangé, la touche de ramassage DOIT rester sans effet et l'interface DOIT indiquer clairement
  qu'il faut équiper le sac.
- **FR-020**: Un joueur DOIT pouvoir vider le contenu de son sac au sol en appuyant sur une touche
  dédiée, à condition d'avoir son sac en main et qu'il ne soit pas vide ; les objets DOIVENT être
  posés autour de lui, sur le sol, à portée de reprise immédiate.
- **FR-021**: Un objet lâché d'un sac DOIT redevenir un objet du monde à part entière — visible par
  tous, ramassable et déplaçable — mais NE DOIT PAS réapparaître après avoir été ramassé, afin
  qu'aucune ressource ne puisse être créée en lâchant puis ramassant en boucle.
- **FR-022**: Le déplacement d'un objet à la souris NE DOIT PAS exiger que le sac soit en main :
  déplacer un objet n'est pas le transporter.

### Key Entities

- **Sac (LittleBag)** : contenant personnel d'un joueur, caractérisé par un type, une contenance
  maximale (5 pour le petit sac) et un contenu courant. Conçu pour qu'un autre type de sac, de
  contenance supérieure, puisse être introduit ultérieurement sans changer la mécanique.
- **Objet collectable** : élément du monde qu'un joueur peut viser et ramasser pour le faire entrer
  dans son sac ; il disparaît alors du monde pour tous les joueurs.
- **Objet déplaçable** : exactement le même ensemble que les objets collectables — tout objet
  ramassable peut aussi être saisi et repositionné sans entrer dans le sac ; il reste alors dans le
  monde, à sa nouvelle position, visible par toute l'équipe.
- **Saisie en cours** : lien temporaire entre un joueur et un objet pendant un déplacement,
  exclusif (un seul joueur par objet) et libéré à la fin du déplacement, à l'élimination ou à la
  déconnexion.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un joueur ramasse un objet qu'il pointe en une seule action, sans ouvrir de menu, et
  voit le résultat immédiatement (objet disparu, sac mis à jour).
- **SC-002**: 100 % des tentatives de ramassage au-delà de la contenance du sac sont refusées sans
  faire disparaître l'objet visé.
- **SC-003**: 100 % des ramassages et des déplacements aboutis produisent le même état chez tous
  les joueurs présents (objet disparu ou déplacé pour tout le monde), sans décalage perceptible.
- **SC-004**: 100 % des objets collectables pointés à portée affichent une indication de ramassage,
  de sorte qu'un nouveau joueur découvre la mécanique sans tutoriel.
- **SC-005**: Aucun objet n'est dupliqué ni perdu lors de tentatives simultanées de deux joueurs ou
  plus sur le même objet, sur 100 % des essais.
- **SC-006**: La contenance peut passer de 5 à une autre valeur par simple ajustement de
  configuration, sans modification de la logique de jeu, et le nouveau plafond s'applique
  immédiatement.
- **SC-007**: Aucun gel perceptible du serveur n'est observé lorsque 6 joueurs ramassent et
  déplacent des objets simultanément.
- **SC-008**: Aucune ressource n'est créée ni perdue par un cycle « vider le sac puis tout
  ramasser » : le total transporté est identique avant et après, sur 100 % des essais.

## Assumptions

- **Originalité (principe VIII)** : la référence faite par l'auteur à un jeu existant porte
  uniquement sur un schéma d'interaction générique (contenant à capacité limitée, ramassage au
  pointeur via une touche, déplacement d'objet à la souris maintenue). Les objets, les noms, les
  visuels, l'interface et le ton restent entièrement originaux ; aucun contenu, identité, nom ni
  visuel d'un jeu existant n'est reproduit.
- **Base technique** : la fonctionnalité s'appuie sur les socles existants (canal d'intentions
  validées côté serveur, configuration centralisée, sessions joueurs, catalogue de visuels avec
  remplaçants en primitives, panneau de développement). Aucune de ces briques n'est reconstruite.
- **Asset disponible** : l'asset « LittleBag » est déjà présent dans les assets partagés du projet.
  Il s'agit d'une pièce unique (et non d'un modèle assemblé), cas déjà pris en charge par le
  catalogue de visuels, avec remplaçant en primitives si l'asset venait à manquer.
- **Périmètre des interactions modifiées** : seule la collecte d'objets passe au ramassage au
  pointeur. Les interactions de poste existantes (déposer au comptoir, ravitailler le générateur,
  préparer, livrer, réparer le bus, sonner) conservent leurs invites de proximité actuelles.
- **Un seul type de sac** : cet incrément ne livre que le petit sac (contenance 5). Les sacs de
  plus grande contenance sont anticipés dans la conception mais restent hors périmètre, tout comme
  la manière de les obtenir (fabrication, récompense, achat).
- **Remplacement de la capacité actuelle** : la contenance de 5 du petit sac se substitue à la
  capacité d'inventaire actuelle de 10. Les valeurs d'équilibrage qui en dépendent (quantités à
  rapporter, nombre d'allers-retours pour une commande ou pour la réparation du bus) sont revues en
  conséquence lors de la planification, sans changer les recettes ni les coûts existants.
- **Commande clavier/souris** : la touche de ramassage par défaut est « F », celle du vidage du sac
  « G », et la saisie utilise le clic maintenu de la souris. Le support manette et tactile est hors
  périmètre de cet incrément.
- **Le sac en main est un état de jeu, pas une contrainte d'interface** : une seule règle couvre
  les deux sens (on ne remplit ni ne vide un sac qu'on ne tient pas), ce qui rend l'équipement du
  sac lisible sans tutoriel. Le déplacement d'objets, lui, reste libre : il ne passe pas par le
  sac (FR-022).
- **Pas de nouvelle économie** : cette fonctionnalité change la manière de transporter les objets,
  pas leur nature, leurs sources ni leur utilité ; les recettes, les coûts et les usages existants
  restent inchangés.
