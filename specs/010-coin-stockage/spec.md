# Feature Specification: Coin de stockage du restaurant

**Feature Branch**: `010-coin-stockage`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description : « Sur la partie stockage il faut que le / les joueurs puissent
stocker les items. Soit en s'approchant avec le sac et en lâchant un item à proximité, soit en
faisant un drag and drop de l'item en question. Il faut que l'on puisse voir l'item « figé » une
fois qu'il est posé. Le / les joueurs pourront récupérer l'objet stocké que lorsqu'ils sont à
proximité. »

Cette fonctionnalité prolonge `004-sac-collecte` (sac, objets au sol, déplacement à la souris),
`005-depot-intelligent-sac` (lâcher un objet près d'un poste) et `009-craft-etabli` (objets
fabriqués). Le restaurant possède déjà, dans l'arrière-salle, un coin de stockage qui n'est pour
l'instant qu'un décor (zone marquée au sol, étagère, caisses) : cette spec lui donne son usage.

**Axe renforcé** (filtre d'évolutivité de la constitution) : **coopération** — un stock commun
que toute l'équipe voit, alimente et vide ensemble, là où le sac de chacun est petit et strictement
personnel.

## Clarifications

### Session 2026-09-25

- Q: Le coin de stockage est-il un stock commun à toute l'équipe, personnel à chaque joueur, ou
  commun avec un propriétaire par objet ? → A: Stock commun à toute l'équipe : chacun voit les
  mêmes objets, chacun peut ranger et reprendre n'importe quel objet, sans notion de propriétaire.
- Q: Comment un joueur proche du coin reprend-il un objet rangé (touche de ramassage vers le sac,
  glisser à la souris hors du coin, ou les deux) ? → A: Les deux gestes sont acceptés : la touche de
  ramassage (l'objet rejoint le sac) ou le glisser à la souris hors du coin (l'objet devient un
  objet du monde tenu par le joueur).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ranger un objet du sac près du coin de stockage et le voir figé (Priority: P1)

Un joueur revient au restaurant avec un sac bien rempli. Il s'approche du coin de stockage de
l'arrière-salle et appuie sur la touche de lâcher. Plutôt que de tomber par terre, l'objet le plus
récemment ramassé se pose sur un emplacement du coin de stockage, où il reste bien visible et
immobile — « figé » — comme posé sur l'étagère. Un appui long range de la même façon tout le sac,
le plus récent d'abord, tant qu'il reste de la place.

**Why this priority**: c'est le cœur de la demande. Le sac a une contenance très limitée : sans
endroit où mettre de côté ce qu'on ne peut pas porter, tout surplus est perdu ou abandonné en
forêt. Le rangement au lâcher prolonge exactement le geste que le joueur connaît déjà.

**Independent Test**: avec plusieurs objets dans le sac, se rendre au coin de stockage et appuyer
brièvement sur la touche de lâcher — le dernier objet ramassé quitte le sac et apparaît immobile
sur un emplacement du coin, sans être passé par le sol. Un appui long range le reste du sac.

**Acceptance Scenarios**:

1. **Given** un joueur avec son sac en main, contenant plusieurs objets, à proximité du coin de
   stockage, **When** il appuie brièvement sur la touche de lâcher, **Then** le dernier objet
   ramassé quitte le sac et apparaît figé sur un emplacement libre du coin, sans jamais tomber au
   sol.
2. **Given** le même joueur, **When** il maintient la touche de lâcher, **Then** les objets de son
   sac sont rangés du plus récent au plus ancien, autant qu'il y a d'emplacements libres ; ceux
   qui ne trouvent pas de place suivent le comportement habituel du lâcher (voir Edge Cases).
3. **Given** un objet rangé, **When** des joueurs passent devant, le heurtent ou tentent de le
   déplacer, **Then** il reste exactement au même emplacement, sans bouger, jusqu'à ce qu'un joueur
   le reprenne (User Story 2).
4. **Given** un joueur hors de portée du coin de stockage, **When** il lâche un objet, **Then**
   rien ne change par rapport à aujourd'hui : l'objet tombe au sol ou est déposé au poste
   compatible s'il y en a un.
5. **Given** un coin de stockage dont tous les emplacements sont occupés, **When** un joueur proche
   lâche un objet, **Then** rien n'est rangé, l'objet suit le comportement habituel du lâcher, et le
   joueur est prévenu que le stockage est plein.

---

### User Story 2 - Récupérer un objet rangé, uniquement à proximité (Priority: P1)

Plus tard dans la partie, un joueur revient au coin de stockage et reprend un objet rangé de deux
façons possibles. Soit il le vise et utilise le geste qu'il connaît pour ramasser un objet au sol :
l'objet rejoint son sac. Soit il le saisit à la souris et le tire hors du coin : l'objet devient un
objet du monde qu'il tient, qu'il peut poser où il veut, ranger de nouveau ou amener à un autre
poste. Dans les deux cas l'emplacement se libère. Depuis trop loin, il n'y a simplement rien à
faire : on ne peut pas récupérer à distance.

**Why this priority**: ranger sans pouvoir reprendre transformerait le coin en trou noir. La règle
de proximité donne au stock un sens dans le monde : il faut se déplacer pour l'utiliser, ce qui
crée un vrai choix (ce que l'on porte, ce que l'on met de côté, ce que l'on va chercher).

**Independent Test**: après avoir rangé un objet, tenter de le reprendre — avec la touche de
ramassage puis par glisser — depuis trois distances : tout près, juste en dehors de la portée, très
loin. Seul le cas « tout près » réussit, avec chacun des deux gestes.

**Acceptance Scenarios**:

1. **Given** un objet rangé et un joueur proche du coin, avec son sac en main et de la place dedans,
   **When** il reprend l'objet avec le geste de ramassage, **Then** l'objet rejoint son sac,
   disparaît du coin, et son emplacement redevient libre.
2. **Given** un objet rangé et un joueur hors de portée, **When** il tente de le reprendre (par l'un
   ou l'autre geste), **Then** rien ne se passe : l'objet reste rangé, sans effet de bord.
3. **Given** un joueur proche mais dont le sac est plein, **When** il tente de reprendre un objet,
   **Then** la reprise est refusée avec la même explication que pour un ramassage au sol (sac plein)
   et l'objet reste rangé.
4. **Given** un joueur proche mais dont le sac n'est pas en main, **When** il tente de reprendre un
   objet, **Then** la reprise est refusée comme pour un ramassage au sol, et l'objet reste rangé.
5. **Given** un objet repris puis rangé de nouveau, **When** le joueur regarde le coin, **Then**
   l'objet occupe un seul emplacement, sans doublon ni fantôme laissé à l'ancien.
6. **Given** un objet rangé et un joueur proche du coin, **When** il le saisit à la souris et le
   tire hors du coin, **Then** l'emplacement se libère aussitôt et l'objet devient un objet du monde
   tenu par ce joueur — sans que son sac ait besoin d'être en main ni d'avoir de la place.
7. **Given** un objet ainsi tiré hors du coin, **When** le joueur le relâche, **Then** il se comporte
   comme n'importe quel objet du monde : posé là où il est relâché, rangé de nouveau s'il est
   relâché au-dessus du coin (et qu'un emplacement est libre), ou déposé sur l'établi.
8. **Given** un objet rangé déjà tenu par un autre joueur qui le tire hors du coin, **When** un
   deuxième joueur tente de le saisir, **Then** il ne le peut pas : un objet n'a qu'un seul porteur.

---

### User Story 3 - Ranger un objet du monde par glisser-déposer (Priority: P2)

Un joueur voit un objet posé par terre dans le restaurant (un objet lâché plus tôt, ou une
ressource ramassable). Il le saisit à la souris comme n'importe quel objet déplaçable, l'amène
au-dessus du coin de stockage et le relâche : l'objet se range et se fige sur un emplacement libre,
sans passer par son sac.

**Why this priority**: c'est la seconde façon de ranger demandée. Elle est utile quand le sac est
plein ou rangé, ou pour vider un tas d'objets au sol sans les ramasser un à un — mais le rangement
depuis le sac (User Story 1) suffit déjà à rendre le stockage utilisable.

**Independent Test**: déposer un objet au sol à quelques pas du coin, le saisir à la souris et le
relâcher sur le coin — il disparaît du sol et apparaît figé sur un emplacement ; le relâcher
ailleurs le laisse simplement posé là.

**Acceptance Scenarios**:

1. **Given** un objet au sol que le joueur peut saisir, **When** il le déplace et le relâche
   au-dessus du coin de stockage, **Then** l'objet est rangé sur un emplacement libre et disparaît
   de sa position d'origine.
2. **Given** le même geste, **When** l'objet est relâché en dehors du coin, **Then** il est simplement
   posé à cet endroit, comme aujourd'hui.
3. **Given** un coin de stockage plein, **When** un joueur y relâche un objet, **Then** l'objet reste
   là où il a été relâché et le joueur est prévenu que le stockage est plein.
4. **Given** un objet actuellement tenu à la souris par un autre joueur, **When** un second joueur
   essaie de le ranger, **Then** il ne le peut pas : seul celui qui le tient peut le relâcher.

---

### User Story 4 - Un stock commun à toute l'équipe (Priority: P2)

Une joueuse range du carburant avant de repartir en forêt. Son coéquipier, resté au restaurant, voit
l'objet figé sur l'étagère, s'approche et le reprend pour l'utiliser. Le coin de stockage appartient
à l'équipe : chacun voit la même chose, chacun peut y ranger, chacun peut y reprendre.

**Why this priority**: la spec vise explicitement « le / les joueurs » ; le jeu se joue de 1 à 6
joueurs et la coopération est un de ses piliers. Le stock est utile en solo dès la User Story 1, mais
c'est le partage qui en fait un outil d'équipe.

**Independent Test**: à deux joueurs, l'un range un objet ; l'autre le voit au même emplacement
depuis sa propre vue, puis le reprend depuis proximité. Les deux tentent ensuite de ranger un objet
au même instant alors qu'il ne reste qu'un emplacement libre.

**Acceptance Scenarios**:

1. **Given** un objet rangé par un premier joueur, **When** un second joueur s'approche, **Then** il
   voit l'objet au même emplacement et peut le reprendre à proximité.
2. **Given** un seul emplacement libre et deux joueurs qui rangent chacun un objet au même instant,
   **When** les deux actions sont traitées, **Then** exactement un objet est rangé ; l'autre reste
   avec son propriétaire (dans son sac ou dans sa main), sans perte ni duplication.
3. **Given** deux joueurs qui tentent de reprendre le même objet rangé au même instant, **When** les
   deux actions sont traitées, **Then** un seul l'obtient.
4. **Given** un joueur qui a rangé des objets puis se déconnecte, **When** la partie continue,
   **Then** ses objets restent rangés et disponibles pour l'équipe.

---

### Edge Cases

- Le stockage se remplit en plein milieu d'un rangement complet (appui long avec plus d'objets que
  d'emplacements libres) : les objets qui ont trouvé une place sont rangés, les suivants suivent le
  comportement habituel du lâcher (poste compatible, sinon sol), sans interrompre le reste du
  rangement.
- Un joueur lâche un objet près du coin de stockage alors que le coin est plein : l'objet ne
  disparaît jamais sans trace — il tombe au sol comme avant, et le message « stockage plein »
  explique pourquoi il n'a pas été rangé.
- Un joueur lâche un objet loin du coin : aucun rangement, comportement habituel du lâcher ; le coin
  de stockage n'attire pas les objets de loin.
- Un objet en cours de rangement ne doit jamais apparaître brièvement au sol avant de se figer : pas
  d'objet fantôme, pas de duplication (même exigence que le dépôt automatique aux postes).
- Un joueur essaie de reprendre un objet alors que quelqu'un d'autre vient de le reprendre : la
  seconde tentative n'a aucun effet et ne donne rien au joueur.
- Un joueur est éliminé ou se déconnecte en tenant un objet au-dessus du coin sans l'avoir relâché :
  l'objet suit le comportement habituel d'un objet lâché en cours de déplacement, il n'est pas
  rangé.
- Un objet rangé est un objet ordinaire du jeu : un objet fabriqué (trousse, bidon) se range et se
  reprend exactement comme une ressource récoltée, et garde son apparence.
- Un objet rangé ne doit pouvoir être ni ramassé, ni saisi, ni déplacé de loin ni par n'importe quel
  autre moyen : ses seules sorties du stock sont les deux formes de reprise à proximité (vers le
  sac, ou tiré hors du coin à la souris).
- Un joueur tire un objet hors du coin puis se déconnecte, est éliminé ou s'éloigne au-delà de la
  portée de déplacement avant de le relâcher : l'objet suit le comportement habituel d'un objet
  du monde qui échappe à son porteur (posé à la dernière position valide). Il n'est jamais perdu ni
  rangé de force, et l'emplacement qu'il occupait reste libre.
- Un joueur tire un objet hors du coin pendant qu'un autre range un objet dans l'emplacement
  fraîchement libéré : les deux actions restent valides, l'objet tiré ne retrouve pas d'emplacement
  garanti s'il est relâché sur un coin devenu plein (il reste alors posé où il a été relâché).
- Une ressource naturelle de la forêt glissée sur le coin de stockage est traitée comme si le
  joueur l'avait ramassée : elle réapparaît ensuite selon les règles habituelles de la forêt.
- Le coin de stockage est plein d'objets identiques : chacun occupe son propre emplacement visible ;
  aucun empilement invisible qui ferait mentir le remplissage affiché.
- Un nouvel appui sur la touche de lâcher quand le sac est vide : rien ne se produit, comme
  aujourd'hui.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le restaurant DOIT offrir un coin de stockage comportant un nombre fini et fixe
  d'emplacements, chacun pouvant accueillir un seul objet. Le nombre d'emplacements DOIT être un
  réglage facile à ajuster.
- **FR-002**: Lorsqu'un joueur, son sac en main, lâche un objet avec la touche de lâcher tout en étant
  à portée du coin de stockage, l'objet DOIT être rangé sur un emplacement libre plutôt que tomber
  au sol, quel que soit son type (ressource récoltée ou objet fabriqué).
- **FR-003**: Le maintien de la touche de lâcher près du coin DOIT ranger les objets du sac un par
  un, du plus récent au plus ancien, tant qu'il reste des emplacements libres ; les objets restants
  DOIVENT suivre le comportement habituel du lâcher.
- **FR-004**: Un joueur DOIT pouvoir ranger un objet du monde par glisser-déposer : saisi à la
  souris puis relâché au-dessus du coin, l'objet DOIT se ranger sur un emplacement libre, sans
  transiter par le sac du joueur.
- **FR-005**: Chaque objet rangé DOIT être visible sur son emplacement, avec l'apparence qu'il a
  quand il est posé au sol, afin qu'un joueur voie d'un coup d'œil ce que contient le stock.
- **FR-006**: Un objet rangé DOIT être figé : il ne bouge plus, ne réagit pas aux collisions ni aux
  joueurs qui passent, et NE DOIT PAS pouvoir être saisi, déplacé ni ramassé par les gestes
  habituels sur les objets du monde. Ses seules sorties sont les deux formes de reprise décrites en
  FR-007 et FR-018.
- **FR-007**: Un joueur DOIT pouvoir reprendre un objet rangé avec le geste qu'il utilise pour
  ramasser un objet au sol, à condition d'être à portée du coin de stockage. L'objet DOIT alors
  quitter le coin, son emplacement DOIT redevenir libre et l'objet DOIT rejoindre le sac du joueur.
- **FR-008**: Chaque forme de reprise DOIT être impossible hors de portée, sans aucun effet de bord.
  La reprise vers le sac DOIT en plus obéir aux mêmes conditions d'accès que le ramassage au sol :
  sac en main et place restante. Faute de quoi elle DOIT être refusée avec la même explication
  qu'un ramassage refusé, et l'objet DOIT rester rangé.
- **FR-009**: Lorsque tous les emplacements sont occupés, tout rangement DOIT être refusé sans
  qu'aucun objet ne soit perdu ni consommé : l'objet reste dans les mains ou le sac du joueur, ou suit
  le comportement habituel du lâcher, et le joueur DOIT être informé que le stockage est plein.
- **FR-010**: Le stockage DOIT être commun à tous les joueurs de la partie : chacun voit les mêmes
  objets aux mêmes emplacements, et chacun peut ranger et reprendre.
- **FR-011**: Un objet DOIT exister à un seul endroit à tout instant (sac, main, sol ou coin de
  stockage). Deux actions simultanées sur le même emplacement ou le même objet DOIVENT se résoudre
  sans perte ni duplication : exactement une aboutit.
- **FR-012**: Le remplissage du stock (nombre d'emplacements occupés sur le total) DOIT être lisible
  pour un joueur à proximité du coin.
- **FR-013**: Le stock DOIT être vidé au début de chaque partie ; aucun objet rangé ne persiste
  d'une partie à l'autre, comme le sac et le stock partagé du comptoir.
- **FR-014**: Le jeu (côté serveur) DOIT être seul juge de ce qui est rangé ou repris, de la
  distance et de l'état des emplacements ; un client NE DOIT jamais pouvoir ranger, reprendre ni
  déplacer un objet sans cette validation.
- **FR-015**: Chaque rangement et chaque reprise DOIVENT produire un retour immédiat et lisible (son
  et/ou visuel léger, message en cas de refus), comme les autres interactions du monde.
- **FR-016**: La portée de rangement/reprise DOIT être un réglage facile à ajuster, identique pour
  ranger et reprendre.
- **FR-017**: L'apparition de l'objet figé DOIT avoir un comportement de secours si son apparence
  n'est pas disponible : un remplaçant en formes simples reste visible, le stockage ne devient jamais
  invisible ni inutilisable.
- **FR-018** *(clarification 2026-09-25)*: Un joueur à portée du coin DOIT aussi pouvoir saisir un
  objet rangé à la souris et le tirer hors du coin. L'emplacement DOIT alors redevenir libre dès la
  saisie, et l'objet DOIT devenir un objet du monde tenu par ce joueur, qui peut le relâcher comme
  n'importe quel objet saisi (posé au sol, rangé de nouveau, déposé sur l'établi). Ce geste NE DOIT
  PAS exiger que le sac soit en main ni qu'il ait de la place, l'objet ne passant pas par lui.

### Key Entities

- **Coin de stockage** : lieu unique du restaurant, doté d'un nombre fixe d'emplacements et d'une
  zone de proximité ; il appartient à toute l'équipe et se vide à chaque nouvelle partie.
- **Emplacement** : une place fixe du coin de stockage, occupée par au plus un objet à la fois, à
  une position visible qui ne change jamais.
- **Objet rangé** : un objet du jeu (ressource ou objet fabriqué) posé sur un emplacement, figé et
  visible, que seule une reprise à proximité peut faire sortir.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ranger un objet depuis le sac tient en une seule action (une pression de touche) et
  l'objet apparaît figé sur son emplacement en moins de 1 seconde.
- **SC-002**: 100 % des objets rangés restent visibles et immobiles à leur emplacement jusqu'à leur
  reprise, y compris après 5 minutes de jeu avec 6 joueurs autour.
- **SC-003**: 0 reprise réussie hors de portée, avec chacun des deux gestes (vers le sac, tiré à la
  souris), sur au moins 20 tentatives à des distances variées.
- **SC-004**: 0 objet perdu ou dupliqué sur 50 cycles ranger/reprendre, dont des cycles à deux joueurs
  agissant au même instant (le total d'objets sac + mains + sol + stock reste constant).
- **SC-005**: Un second joueur présent voit l'objet rangé par le premier en moins de 1 seconde.
- **SC-006**: Une fois le stockage plein, 100 % des tentatives de rangement supplémentaires sont
  refusées avec une explication visible, sans qu'aucun objet ne disparaisse.
- **SC-007**: Un coin de stockage plein ne dégrade pas visiblement la fluidité d'une partie à 6
  joueurs.
- **SC-008**: Au moins 4 testeurs sur 5 qui découvrent le coin sans explication parviennent à y
  ranger un objet en moins de 30 secondes.

## Assumptions

- **Stock commun à l'équipe** (confirmé, voir Clarifications) : cohérent avec le pilier de
  coopération du jeu ; ni stock personnel par joueur, ni propriétaire par objet.
- **Le coin de stockage existant sert de lieu** : le décor déjà présent dans l'arrière-salle (zone
  marquée au sol, étagère, caisses) reste l'endroit où l'on range ; cette spec n'en change ni
  l'emplacement ni l'aspect général, elle lui ajoute des emplacements visibles pour les objets.
- **Capacité modeste et configurable** : une douzaine d'emplacements en valeur initiale indicative,
  ajustable ; assez pour soulager le sac (5 places), pas assez pour transformer le stock en réserve
  illimitée. La valeur exacte relève de la configuration, pas de cette spec.
- **Tous les objets transportables se rangent** : les quatre ressources récoltées comme les objets
  fabriqués à l'établi (`009-craft-etabli`) ; aucune restriction par type dans cette version.
- **Le glisser-déposer est celui des objets du monde** : le déplacement à la souris des objets posés
  au sol (`004-sac-collecte`), et non un glisser depuis une interface du sac, qui n'existe pas.
- **« À proximité » se mesure depuis le joueur** pour le lâcher avec la touche (« en s'approchant
  avec le sac »), et depuis l'objet pour le glisser-déposer (là où il est relâché) ; les deux
  utilisent la même portée.
- **Deux gestes de reprise** (clarification 2026-09-25) : le geste de ramassage existant (viser
  l'objet et appuyer sur la touche de ramassage, avec ses mêmes conditions d'accès — sac en main,
  place restante), et le déplacement à la souris existant appliqué à un objet rangé, qui le sort du
  coin sans passer par le sac.
- **Le stock se vide à chaque nouvelle partie**, comme le sac et les autres états de partie ; la
  persistance entre parties (comme la monnaie et la boutique, `008-boutique-persistance`) est hors
  périmètre.
- **Le stockage ne nourrit aucun autre système** : les objets rangés ne sont consommés ni par les
  commandes, ni par le générateur, ni par le bus — ils attendent seulement d'être repris. Le stock
  partagé du comptoir (steak, pain) reste une mécanique distincte, inchangée.
- **Aucune propriété des objets rangés** : n'importe quel joueur à proximité peut reprendre n'importe
  quel objet, quel que soit celui qui l'a rangé.
- **Les autres postes gardent leurs règles** : le coin de stockage est éloigné de l'établi, du
  comptoir et du générateur ; leurs zones de dépôt ne se chevauchent pas avec la sienne, et si elles
  venaient à le faire, l'objet irait au poste le plus proche.
