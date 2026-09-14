# Feature Specification: Premier incrément jouable

**Feature Branch**: `002-premier-increment-jouable`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description : premier incrément jouable de la constitution — ambiance jour/nuit
visible (éclairage, brouillard), forêt de base générée depuis une seed, collecte de ressources,
générateur à alimenter, enseigne néon et zone de sécurité, une commande la nuit, un ennemi. La
boucle devient jouable de bout en bout, sans le bus (qui arrivera plus tard).

**Axes d'évolutivité renforcés** : exploration procédurale (forêt et collecte), commandes
absurdes (première commande servie), tension nocturne (générateur, néon, ennemi) et coopération
(ressources et défense partagées par l'équipe).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Récolter des ressources dans la forêt (Priority: P1)

Le jour, un joueur quitte le restaurant et explore une forêt basique construite autour de lui.
Il y trouve des points de ressources (essence, steak suspect, pain de route) qu'il peut
récolter en s'en approchant. Ses ressources ramassées sont visibles dans son inventaire et
peuvent être déposées au restaurant.

**Why this priority** : sans collecte, aucune autre mécanique (générateur, commande) n'a de
matière première ; c'est le point d'entrée de toute la boucle de jour (principe I).

**Independent Test** : en solo, sortir du restaurant le jour, récolter un point de chaque
ressource, vérifier l'inventaire du joueur, puis les déposer au restaurant et vérifier le stock
partagé.

**Acceptance Scenarios**:

1. **Given** un point de ressource visible dans la forêt, **When** un joueur s'en approche et
   interagit, **Then** la ressource est ajoutée à son inventaire, le point de ressource devient
   indisponible, et tous les joueurs le voient épuisé.
2. **Given** un point de ressource épuisé, **When** le délai de réapparition configuré est
   écoulé, **Then** le point redevient disponible avec un signal visuel.
3. **Given** un joueur avec des ressources en inventaire, **When** il les dépose au restaurant
   (comptoir ou plan de travail), **Then** elles rejoignent le stock partagé de l'équipe et
   disparaissent de son inventaire personnel.
4. **Given** deux joueurs présents, **When** l'un récolte un point de ressource, **Then**
   l'autre le voit disparaître immédiatement et ne peut pas le récolter une seconde fois.
5. **Given** une même seed de partie, **When** deux sessions démarrent avec cette seed, **Then**
   la forêt et l'emplacement des points de ressources sont identiques.

---

### User Story 2 - Alimenter le générateur pour garder le néon et la zone de sécurité (Priority: P2)

Le générateur du restaurant consomme de l'essence en continu. Tant qu'il en a, l'enseigne néon
reste allumée et une zone de sécurité protège les joueurs proches du restaurant. Un joueur peut
déposer de l'essence récoltée dans le générateur pour prolonger son fonctionnement. Si
l'essence s'épuise, le néon s'éteint et la zone de sécurité cesse de protéger.

**Why this priority** : donne un objectif concret à la collecte d'essence et crée l'enjeu
central de la nuit (générateur, néon, sécurité — principe I) ; dépend de la Story 1 pour la
matière première.

**Independent Test** : en solo, observer le niveau de carburant baisser au fil du temps,
déposer de l'essence récoltée dans le générateur et vérifier que le niveau remonte ; laisser le
générateur s'épuiser et constater l'extinction du néon et la désactivation de la zone de
sécurité.

**Acceptance Scenarios**:

1. **Given** une partie en cours, **When** le temps passe, **Then** le niveau de carburant du
   générateur diminue à un taux configurable, visible sur l'interface.
2. **Given** un joueur avec de l'essence en inventaire, **When** il la dépose au générateur,
   **Then** le niveau de carburant augmente en conséquence, sans dépasser sa capacité maximale.
3. **Given** un générateur alimenté, **When** le niveau de carburant est supérieur à zéro,
   **Then** l'enseigne néon reste allumée et la zone de sécurité protège les joueurs qui s'y
   trouvent.
4. **Given** un générateur à sec, **When** le carburant atteint zéro, **Then** le néon s'éteint
   et la zone de sécurité cesse de protéger, avec une notification à tous les joueurs.
5. **Given** un générateur à sec, **When** un joueur y dépose de l'essence, **Then** le néon se
   rallume et la zone de sécurité redevient active.

---

### User Story 3 - Préparer et livrer la commande de la nuit (Priority: P3)

Chaque nuit, une commande apparaît à l'interphone et à l'écran : elle demande une combinaison
d'ingrédients récoltés dans la forêt. Un joueur rassemble les ingrédients au plan de travail,
valide la préparation, puis dépose le résultat à la fenêtre du drive-thru avant la fin de la
nuit. Une commande non livrée à temps échoue.

**Why this priority** : c'est la mécanique originale du jeu (le drive-thru absurde) et le
premier objectif nocturne concret ; elle s'appuie sur les ressources collectées le jour
(Story 1) et sur les points de référence déjà posés par le socle technique.

**Independent Test** : en profil de test, attendre l'apparition de la commande en début de
nuit, récolter ou utiliser les ingrédients requis, les préparer au plan de travail, livrer à la
fenêtre du drive-thru, et vérifier la confirmation avant la fin de la nuit. Recommencer sans
livrer pour observer l'échec.

**Acceptance Scenarios**:

1. **Given** le début d'une phase de nuit, **When** la phase démarre, **Then** une commande
   apparaît à l'interphone et sur l'interface de tous les joueurs, avec ses ingrédients requis
   et le temps restant de la nuit comme échéance.
2. **Given** les ingrédients requis présents dans le stock partagé, **When** un joueur les
   assemble au plan de travail, **Then** la commande préparée est disponible pour être livrée.
3. **Given** une commande préparée, **When** un joueur la dépose à la fenêtre du drive-thru,
   **Then** la commande est validée, une notification de succès s'affiche à tous, et le stock
   d'ingrédients utilisés est déduit.
4. **Given** une tentative de préparation avec des ingrédients manquants ou incorrects,
   **When** le joueur valide, **Then** la préparation est refusée et l'interface indique les
   ingrédients manquants.
5. **Given** une commande non livrée, **When** la nuit se termine, **Then** la commande est
   marquée en échec, une notification l'annonce à tous les joueurs, et l'ennemi de la nuit
   apparaît (Story 4).
6. **Given** une commande déjà livrée avec succès, **When** un joueur tente de livrer à nouveau
   la même nuit, **Then** la tentative est refusée sans effet.

---

### User Story 4 - Survivre à l'ennemi nocturne (Priority: P4)

Quand une commande échoue, ou pendant certaines nuits, un ennemi apparaît en lisière de forêt
et se dirige vers le joueur le plus proche situé hors de la zone de sécurité. À portée, il
inflige des dégâts, puis se retire ou disparaît après un délai. Un joueur qui perd toute sa
santé est éliminé. La zone de sécurité du néon repousse ou empêche l'ennemi d'agir tant qu'elle
est active.

**Why this priority** : introduit la tension et l'enjeu de survie de la boucle canonique
(principe I), mais seulement après que la commande (Story 3) et le générateur (Story 2) donnent
un sens à son apparition et à la protection du néon.

**Independent Test** : en profil de test, provoquer l'échec d'une commande, observer
l'apparition de l'ennemi, se laisser approcher hors de la zone de sécurité et vérifier la perte
de santé puis l'élimination après plusieurs contacts ; recommencer en restant dans la zone de
sécurité et vérifier qu'il ne peut pas agir.

**Acceptance Scenarios**:

1. **Given** une commande qui vient d'échouer, **When** l'échec est traité, **Then** un ennemi
   apparaît à un point d'apparition en lisière de forêt, hors de la zone de sécurité.
2. **Given** un ennemi actif, **When** aucun joueur n'est visible ou atteignable, **Then** il se
   déplace vers le dernier point connu puis se retire ou disparaît après un délai configurable.
3. **Given** un joueur hors de la zone de sécurité, **When** l'ennemi l'atteint, **Then** le
   joueur perd un montant configurable de santé et reçoit un retour visible (effet, notification).
4. **Given** un joueur dans la zone de sécurité active, **When** un ennemi tente de l'atteindre,
   **Then** l'ennemi ne peut lui infliger aucun dégât.
5. **Given** un joueur dont la santé atteint zéro, **When** le dernier coup est reçu, **Then**
   son statut passe à « Éliminé », sans réapparition automatique pour le reste de la partie.
6. **Given** un chemin bloqué ou un calcul de déplacement impossible, **When** l'ennemi ne peut
   pas atteindre sa cible, **Then** il se replie ou disparaît après un court délai, sans rester
   bloqué indéfiniment.
7. **Given** plusieurs joueurs présents, **When** l'ennemi choisit une cible, **Then** il vise
   le joueur valide le plus proche parmi ceux hors de la zone de sécurité.

---

### User Story 5 - Ambiance jour/nuit visible (Priority: P5)

L'éclairage et le brouillard du ciel changent nettement entre le jour et la nuit, en plus de
l'indication déjà donnée par l'interface : le jour est clair, la nuit est sombre et brumeuse,
avec des transitions progressives aux changements de phase.

**Why this priority** : renforce la lisibilité de la boucle (principe VII) et l'ambiance
« meme horror » (principe VIII), mais la boucle reste jouable sans elle grâce à l'interface
textuelle déjà livrée par le socle ; c'est un raffinement, pas un prérequis.

**Independent Test** : en profil de test, observer une transition Jour → Nuit puis Nuit → Jour
et confirmer visuellement le changement d'éclairage et de brouillard sans lire l'interface.

**Acceptance Scenarios**:

1. **Given** le passage du Jour à la Nuit, **When** la phase change, **Then** l'éclairage
   s'assombrit et le brouillard s'épaissit progressivement sur une durée configurable.
2. **Given** le passage de la Nuit au Jour, **When** la phase change, **Then** l'éclairage et le
   brouillard reviennent progressivement à leur état de jour.
3. **Given** la zone de sécurité active la nuit, **When** un joueur s'y trouve, **Then**
   l'éclairage y reste sensiblement plus clair que le reste de la forêt.

---

### Edge Cases

- Un joueur dépose de l'essence alors que le générateur est déjà plein : le surplus reste dans
  son inventaire, rien n'est perdu.
- Un joueur récolte le dernier point de ressource disponible d'un type juste avant la fin du
  jour : le point reste épuisé pendant la nuit et réapparaît selon son délai, y compris pendant
  la nuit.
- Deux joueurs valident une préparation avec les mêmes ingrédients au même instant : un seul
  prélèvement dans le stock partagé est accepté, l'autre est refusé faute d'ingrédients restants.
- Un joueur est éliminé pendant qu'il transporte des ressources en inventaire personnel : ces
  ressources sont perdues (non versées au stock partagé) ; seul le stock déjà déposé reste
  disponible pour l'équipe.
- Le dernier joueur en vie est éliminé par l'ennemi alors qu'une commande est en attente de
  livraison : la partie se termine en défaite (règle déjà en place dans le socle) et la commande
  en cours est abandonnée.
- L'ennemi apparaît alors qu'aucun joueur n'est hors de la zone de sécurité : il patrouille sans
  cible jusqu'à ce qu'un joueur sorte de la zone ou jusqu'à son délai de disparition.
- La phase de nuit se termine pendant que l'ennemi est encore actif : il disparaît
  immédiatement au passage au Jour suivant.
- Un joueur rejoint en pleine nuit alors qu'une commande est déjà affichée : il voit la commande
  et son échéance actuelles, comme pour l'état de partie existant.
- Le carburant du générateur est déjà à zéro au tout début d'une partie (redémarrage) : il est
  remis à son niveau initial configuré à chaque nouvelle partie, comme le reste de l'état de
  jeu.
- Un point de ressource se trouve à l'intérieur de la zone de sécurité : il reste récoltable
  normalement, de jour comme de nuit.

## Requirements *(mandatory)*

### Functional Requirements

**Forêt et collecte**

- **FR-001**: Au démarrage d'une partie, le serveur DOIT générer un ensemble fixe de points de
  ressources dans une forêt basique autour du restaurant, dérivé de la seed de la partie ; une
  même seed DOIT produire les mêmes emplacements.
- **FR-002**: Chaque point de ressource DOIT avoir un type (au minimum essence, steak suspect,
  pain de route) et être récoltable par interaction à portée, selon le même modèle de
  validation serveur que les interactions existantes du socle.
- **FR-003**: Un point de ressource récolté DOIT devenir indisponible pour tous les joueurs
  jusqu'à l'écoulement d'un délai de réapparition configurable, puis redevenir disponible avec
  un signal visuel.
- **FR-004**: Chaque joueur DOIT disposer d'un inventaire personnel limité recevant les
  ressources récoltées ; il DOIT pouvoir les déposer au restaurant pour les verser à un stock
  partagé visible par toute l'équipe.
- **FR-005**: Les ressources d'un inventaire personnel non déposées DOIVENT être perdues si leur
  porteur est éliminé.

**Générateur, néon et zone de sécurité**

- **FR-006**: Le générateur DOIT avoir un niveau de carburant qui diminue à un taux configurable
  pendant toute la partie, avec une capacité maximale configurable.
- **FR-007**: Un joueur DOIT pouvoir déposer de l'essence de son inventaire dans le générateur
  pour augmenter son niveau de carburant, sans dépasser la capacité maximale ; le surplus reste
  dans l'inventaire du joueur.
- **FR-008**: Tant que le niveau de carburant est supérieur à zéro, l'enseigne néon DOIT rester
  allumée et une zone de sécurité centrée sur le restaurant DOIT empêcher tout ennemi d'infliger
  des dégâts aux joueurs qui s'y trouvent.
- **FR-009**: Quand le niveau de carburant atteint zéro, le néon DOIT s'éteindre, la zone de
  sécurité DOIT cesser de protéger, et une notification DOIT en informer tous les joueurs ; le
  néon et la protection DOIVENT reprendre dès qu'un apport d'essence ramène le niveau au-dessus
  de zéro.
- **FR-010**: Le niveau de carburant DOIT être visible en permanence sur l'interface de tous les
  joueurs.

**Commande de la nuit**

- **FR-011**: Au début de chaque phase de nuit, le serveur DOIT générer une commande demandant
  une combinaison d'ingrédients réalisable avec les ressources disponibles dans la partie en
  cours, et la diffuser à tous les joueurs (interphone et interface) avec son échéance.
- **FR-012**: Un joueur DOIT pouvoir préparer une commande au plan de travail en utilisant les
  ingrédients requis prélevés dans le stock partagé ; une préparation aux ingrédients
  incomplets ou incorrects DOIT être refusée sans effet, avec le détail des ingrédients
  manquants affiché au joueur.
- **FR-013**: Un joueur DOIT pouvoir livrer une commande préparée à la fenêtre du drive-thru ;
  la livraison DOIT être validée par le serveur, déduire les ingrédients utilisés du stock
  partagé, et déclencher une notification de succès pour tous les joueurs.
- **FR-014**: Une commande non livrée avant la fin de la phase de nuit DOIT être marquée en
  échec, notifiée à tous les joueurs, et déclencher l'apparition d'un ennemi (FR-015).
- **FR-015**: Une commande déjà livrée avec succès ou déjà en échec NE DOIT accepter aucune
  livraison supplémentaire pendant la même nuit.

**Ennemi nocturne**

- **FR-016**: L'échec d'une commande DOIT déclencher l'apparition d'un ennemi à un point
  d'apparition situé en lisière de forêt, hors de la zone de sécurité.
- **FR-017**: L'ennemi DOIT se diriger vers le joueur valide le plus proche parmi ceux situés
  hors de la zone de sécurité, en utilisant la recherche de chemin du moteur, avec un
  déplacement direct de secours si elle échoue.
- **FR-018**: Quand l'ennemi atteint un joueur hors de la zone de sécurité, il DOIT lui infliger
  un montant configurable de dégâts à sa santé, avec un retour visible immédiat pour ce joueur.
- **FR-019**: Un ennemi NE DOIT infliger aucun dégât à un joueur situé dans la zone de sécurité
  active.
- **FR-020**: Si l'ennemi ne trouve aucune cible atteignable, ou après un délai configurable
  sans contact, il DOIT se replier ou disparaître proprement ; il NE DOIT jamais rester bloqué
  indéfiniment.
- **FR-021**: Un ennemi encore actif à la fin de la phase de nuit DOIT disparaître au passage à
  la phase suivante.

**Santé et élimination**

- **FR-022**: Chaque joueur DOIT avoir une santé server-autoritaire, distincte de tout mécanisme
  natif du moteur, initialisée à une valeur configurable à chaque apparition en début de
  partie.
- **FR-023**: Quand la santé d'un joueur atteint zéro, son statut DOIT passer à « Éliminé », sans
  réapparition automatique pour le reste de la partie en cours (la défaite se déclenche selon
  la règle déjà en place dans le socle technique quand tous les joueurs présents sont éliminés).

**Ambiance**

- **FR-024**: L'éclairage et le brouillard DOIVENT changer visiblement entre le Jour et la Nuit,
  avec une transition progressive sur une durée configurable au moment du changement de phase.
- **FR-025**: La zone de sécurité active la nuit DOIT rester visiblement plus éclairée que le
  reste de la forêt environnante.

**Configuration**

- **FR-026**: Toutes les nouvelles valeurs d'équilibrage (types et quantités de points de
  ressources, délai de réapparition, capacité et taux de consommation du générateur, quantité
  d'essence apportée par dépôt, ingrédients et délai de la commande, dégâts et délai de repli de
  l'ennemi, santé initiale du joueur, durée des transitions d'ambiance) DOIVENT rejoindre la
  configuration centrale existante, avec valeur par défaut et bornes.

### Key Entities

- **Point de ressource** : emplacement dans la forêt ; type de ressource, disponibilité, délai
  de réapparition.
- **Ressource** : objet récoltable (essence, steak suspect, pain de route) ; existe dans un
  inventaire personnel ou dans le stock partagé du restaurant.
- **Inventaire personnel** : ressources portées par un joueur, perdues à son élimination si non
  déposées.
- **Stock partagé** : ressources déposées au restaurant, visibles et utilisables par toute
  l'équipe.
- **Générateur** : niveau de carburant courant, capacité maximale, taux de consommation ;
  détermine l'état du néon et de la zone de sécurité.
- **Zone de sécurité** : région centrée sur le restaurant, active tant que le générateur a du
  carburant ; empêche les dégâts d'ennemis en son sein.
- **Commande** : ingrédients requis, échéance (fin de la nuit courante), état (en attente,
  livrée, en échec).
- **Ennemi** : instance apparue après un échec de commande ; état (poursuite, repli, disparu),
  cible courante.
- **Santé du joueur** : valeur server-autoritaire par joueur, distincte du statut « en vie » /
  « éliminé » déjà existant, qui déclenche le passage à « Éliminé » à zéro.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En solo, un joueur peut récolter les trois types de ressources, alimenter le
  générateur, préparer et livrer une commande, puis survivre à l'ennemi qui apparaît si une
  commande échoue — le tout sans intervention d'un développeur, en une seule nuit de profil de
  test.
- **SC-002**: 100 % des points de ressources récoltés deviennent indisponibles pour tous les
  joueurs immédiatement, et redeviennent disponibles après leur délai de réapparition, à 1
  seconde près.
- **SC-003**: Le niveau de carburant affiché est identique, à un arrondi près, pour tous les
  joueurs à un instant donné.
- **SC-004**: 100 % des tentatives de préparation avec des ingrédients incomplets sont refusées
  sans prélever aucune ressource du stock partagé.
- **SC-005**: 100 % des livraisons valides à la fenêtre du drive-thru avant l'échéance sont
  acceptées et notifiées à tous les joueurs en moins de 2 secondes.
- **SC-006**: 100 % des commandes non livrées à l'échéance déclenchent l'apparition d'un ennemi
  en moins de 5 secondes après la fin de la nuit.
- **SC-007**: Un joueur resté dans la zone de sécurité pendant toute une nuit ne subit aucun
  dégât d'ennemi, quelle que soit la durée de présence de l'ennemi.
- **SC-008**: Aucun ennemi n'observé bloqué plus de son délai de repli configuré (secours
  systématique en cas d'échec de recherche de chemin).
- **SC-009**: Deux parties lancées avec la même seed forcée produisent des forêts et des
  emplacements de ressources identiques à 100 %.
- **SC-010**: Lors d'un test à 6 joueurs sur une nuit complète, aucune erreur ni gel perceptible
  n'est observé lors de l'apparition de l'ennemi, de la préparation ou de la livraison d'une
  commande.
- **SC-011**: Modifier une valeur d'équilibrage de cette fonctionnalité (ex. dégâts de l'ennemi,
  capacité du générateur) ne demande d'intervenir qu'à un seul endroit de la configuration.

## Assumptions

- **Base technique** : cette fonctionnalité s'appuie entièrement sur le socle technique
  (`001-socle-technique`) : horloge de partie, sessions joueurs, canal d'intentions validées,
  configuration centrale, points de référence du monde, catalogue de visuels avec remplaçants
  en primitives. Aucune de ces briques n'est reconstruite ici.
- **Forêt fixe pour cet incrément** : conformément à la constitution, la forêt de ce premier
  incrément est un ensemble fixe de points de ressources généré une fois au démarrage à partir
  de la seed, sans chargement ni déchargement dynamique par chunks ; la génération dynamique par
  chunks est hors périmètre et arrivera dans un incrément ultérieur.
- **Ressources introduites** : seules l'essence, le steak suspect et le pain de route sont
  introduits dans cet incrément, car ce sont les seuls nécessaires au générateur et à la
  commande unique. Les autres objets du catalogue MVP (bois, batterie, ferraille, planches,
  cône de chantier, radio cassée, kit de soins, lampe torche) sont hors périmètre et seront
  introduits avec les fonctionnalités qui en ont besoin (barricades, bus, autres commandes).
- **Une seule recette de commande** : cet incrément définit un unique type de commande
  (ingrédients fixes). Les commandes aléatoires multiples et leur tirage arriveront dans un
  incrément ultérieur, une fois plusieurs recettes disponibles.
- **Un seul type d'ennemi** : un seul comportement d'ennemi est implémenté ici (poursuite simple
  hors zone de sécurité) ; d'autres archétypes viendront plus tard.
- **Déclenchement de l'ennemi** : l'apparition est liée à l'échec d'une commande, conformément à
  `TECH.md`. Une apparition aléatoire indépendante des commandes est hors périmètre de cet
  incrément.
- **Santé et élimination** : introduit une valeur de santé minimale suffisante pour donner un
  enjeu à l'ennemi ; les kits de soins, la régénération et les réapparitions limitées en cours
  de partie restent hors périmètre et arriveront avec une fonctionnalité de santé plus complète.
- **Chute accidentelle** : le comportement existant du socle (réapparition au point d'apparition
  en cas de chute) n'est pas modifié par cette fonctionnalité ; il reste indépendant de la santé
  introduite ici, qui ne concerne que les dégâts d'ennemi.
- **Bus** : explicitement hors périmètre de cet incrément, comme précisé dans la description de
  la fonctionnalité ; la phase d'Évasion existante reste sans condition de victoire réelle tant
  que le bus n'est pas implémenté.
- **Interaction** : la récolte, le dépôt, la préparation et la livraison utilisent le même
  modèle d'interaction validée par le serveur déjà posé par le socle (prompt de proximité →
  intention → validation serveur).
