# Feature Specification: Bus et victoire par évasion

**Feature Branch**: `003-bus-evasion`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description : réparer le bus après avoir tenu le nombre de nuits prévu, pour
déclencher la victoire — la dernière pièce manquante de la boucle constitutionnelle (jour → nuit
→ survie → fuite).

**Axes d'évolutivité renforcés** : coopération (la réparation se partage entre tous les joueurs
présents, sans rôle réservé) et rejouabilité (le jeu dispose enfin d'une fin victorieuse réelle,
condition de la boucle « recommencer une partie » déjà en place).

## Clarifications

### Session 2026-09-14

- Q: Le départ du bus doit-il pouvoir être déclenché par un seul joueur, même si d'autres
  membres de l'équipe encore en vie sont loin du bus à ce moment-là ? → A: Non — le départ
  exige que tous les joueurs encore en vie soient à portée du bus au moment de l'interaction
  (Option B).
- Q: Le total de ferraille requis pour réparer le bus doit-il augmenter avec le nombre de
  joueurs, ou rester le même quel que soit l'effectif ? → A: Il est proportionnel au nombre de
  joueurs présents au moment où la phase d'Évasion commence, fixé à cet instant (Option B).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Réparer le bus avec de la ferraille (Priority: P1)

Comme dans la forêt du premier incrément, des tas de ferraille (carcasses, décharges) sont
dispersés autour du restaurant. Un joueur qui en récolte peut la rapporter directement au bus,
garé sur le parking, et la déposer pour faire progresser sa réparation. La progression est
visible par toute l'équipe, à distance.

**Why this priority** : sans réparation possible, aucune victoire n'est atteignable ; c'est le
point d'entrée de toute la fonctionnalité, comme la récolte l'était pour le premier incrément.

**Independent Test** : en solo, récolter plusieurs tas de ferraille, les déposer au bus, et
vérifier que sa progression de réparation augmente jusqu'à devenir complète, sans avoir besoin
de la fonctionnalité de départ (Story 2).

**Acceptance Scenarios**:

1. **Given** un tas de ferraille visible dans la forêt, **When** un joueur s'en approche et
   interagit, **Then** la ferraille est ajoutée à son inventaire, le tas devient indisponible,
   et tous les joueurs le voient épuisé (même comportement que les ressources existantes).
2. **Given** de la ferraille dans l'inventaire d'un joueur, **When** il s'approche du bus et
   interagit pour la déposer, **Then** la progression de réparation du bus augmente d'autant, sa
   ferraille personnelle disparaît de son inventaire, et l'équipe entière voit la nouvelle
   progression (interface et état visuel du bus).
3. **Given** une progression de réparation qui atteint le total requis, **When** le dernier dépôt
   est effectué, **Then** le bus passe à l'état « réparé », visible par toute l'équipe (état
   visuel distinct, notification).
4. **Given** un tas de ferraille épuisé, **When** son délai de réapparition configuré est écoulé,
   **Then** le tas redevient disponible, comme les autres ressources.

---

### User Story 2 - Partir avec le bus réparé (Priority: P2)

Une fois le nombre de nuits requis survécu et le bus entièrement réparé, l'équipe se regroupe
près du bus : dès que tous les joueurs encore en vie sont à portée, n'importe lequel d'entre eux
peut interagir pour lancer le départ. Toute l'équipe encore en vie remporte alors la partie, et
une nouvelle partie peut recommencer après l'écran de fin, comme pour les autres conditions de
fin déjà en place.

**Why this priority** : c'est l'aboutissement de la boucle du jeu — sans cette étape, réparer le
bus n'aurait aucune conséquence ; mais elle ne peut être testée qu'une fois la Story 1 en place.

**Independent Test** : forcer un bus déjà réparé (commande de développement) pendant la phase
d'Évasion, interagir pour partir avec toute l'équipe rassemblée et vérifier la victoire, puis
retenter avec un coéquipier volontairement éloigné et vérifier le refus propre.

**Acceptance Scenarios**:

1. **Given** le bus entièrement réparé, la phase d'Évasion en cours, et tous les joueurs encore
   en vie à portée du bus, **When** l'un d'eux interagit pour partir, **Then** la partie se
   termine en victoire pour toute l'équipe, une notification est diffusée, et l'écran de fin
   l'affiche.
2. **Given** le bus pas encore entièrement réparé, **When** un joueur tente d'interagir pour
   partir, **Then** la tentative est refusée proprement, sans effet, avec un retour clair
   indiquant qu'il manque de la réparation.
3. **Given** le bus entièrement réparé mais une phase autre que l'Évasion (nuits pas encore
   toutes survécues), **When** un joueur tente d'interagir pour partir, **Then** la tentative est
   refusée proprement, sans effet.
4. **Given** le bus entièrement réparé et la phase d'Évasion en cours, mais au moins un joueur
   encore en vie hors de portée du bus, **When** un joueur présent tente d'interagir pour partir,
   **Then** la tentative est refusée proprement, sans effet, avec un retour indiquant qu'il
   manque des coéquipiers.
5. **Given** la victoire déclenchée, **When** l'écran de fin se termine, **Then** une nouvelle
   partie démarre automatiquement avec une nouvelle seed, un bus non réparé et aucune ferraille
   déposée, comme le reste de l'état de partie.

---

### Edge Cases

- Un joueur est éliminé pendant qu'il transporte de la ferraille récoltée non déposée : cette
  ferraille est perdue (même règle que les autres ressources personnelles, FR-005 du premier
  incrément).
- Tous les joueurs sont éliminés pendant la phase d'Évasion, bus partiellement ou totalement
  réparé : la partie se termine en défaite (règle déjà en place), la réparation n'a alors aucun
  effet.
- Aucun joueur ne récolte de ferraille avant la fin des nuits requises : la phase d'Évasion
  n'a pas de limite de temps (`Match.EscapeDuration` déjà à « sans limite »), l'équipe peut donc
  continuer à récolter et réparer aussi longtemps que nécessaire, sans échec automatique.
- Un joueur tente de déposer de la ferraille alors que le bus est déjà entièrement réparé : le
  dépôt est refusé proprement (surplus non perdu, reste dans l'inventaire personnel), comme le
  générateur déjà plein dans le premier incrément.
- Un joueur rejoint la partie après que le bus est déjà réparé (ou après la victoire, pendant
  l'écran de fin) : il voit l'état actuel répliqué, sans incohérence.
- Un joueur encore en vie se déconnecte pendant que l'équipe tente de partir : il n'est plus
  compté parmi les joueurs à rassembler (même définition de présence que la règle de défaite
  déjà en place, socle technique).
- Un joueur rejoint ou quitte la partie après le début de la phase d'Évasion : le total de
  ferraille requis, déjà fixé au nombre de joueurs présents à cet instant, ne change pas
  rétroactivement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT faire apparaître des tas de ferraille dans la forêt, selon les
  mêmes règles de génération que les ressources existantes (nombre configurable, seed de
  partie, reproductible).
- **FR-002**: Un joueur DOIT pouvoir récolter un tas de ferraille en s'en approchant et en
  interagissant ; la ferraille récoltée DOIT rejoindre son inventaire personnel, dans la limite
  de sa capacité d'inventaire existante.
- **FR-003**: Un tas de ferraille récolté DOIT devenir indisponible immédiatement pour tous les
  joueurs, puis redevenir disponible après un délai de réapparition configurable, comme les
  ressources existantes.
- **FR-004**: Un joueur DOIT pouvoir déposer sa ferraille personnelle au bus pour faire progresser
  sa réparation, sans dépasser le total requis pour une réparation complète ; le surplus éventuel
  DOIT rester dans son inventaire personnel.
- **FR-005**: La progression de réparation du bus DOIT être un état partagé par toute l'équipe
  (pas un total par joueur), répliqué à tous les clients.
- **FR-005a**: Le total de ferraille requis pour une réparation complète DOIT être proportionnel
  au nombre de joueurs présents au moment où la phase d'Évasion commence, et DOIT rester fixe
  ensuite pour le reste de la partie (les arrivées ou départs de joueurs pendant l'Évasion ne le
  recalculent pas).
- **FR-006**: L'interface DOIT afficher la progression de réparation du bus (quantité déposée sur
  le total requis) dès qu'au moins un dépôt a été effectué ou que la phase d'Évasion est en
  cours.
- **FR-007**: Le bus DOIT afficher un état visuel distinct une fois entièrement réparé, visible à
  distance par toute l'équipe.
- **FR-008**: Un joueur DOIT pouvoir déclencher le départ du bus par une interaction, disponible
  uniquement quand le bus est entièrement réparé, que la phase d'Évasion est en cours, ET que
  tous les joueurs encore en vie se trouvent à portée du bus au moment de l'interaction (un
  joueur solo satisfait cette condition seul) ; toute tentative hors de ces conditions DOIT être
  refusée sans effet, avec un retour indiquant qu'il manque des coéquipiers le cas échéant.
- **FR-009**: Le départ du bus DOIT déclencher la victoire de la partie pour tous les joueurs
  présents, DOIT diffuser une notification à toute l'équipe, et DOIT réutiliser l'écran de fin et
  le redémarrage automatique déjà en place.
- **FR-010**: Chaque nouvelle partie DOIT réinitialiser la réparation du bus à zéro et régénérer
  les tas de ferraille, comme le reste de l'état de partie (forêt, générateur, commande).
- **FR-011**: Toute action de récolte, de dépôt et de départ DOIT être validée par le serveur
  (type et bornes des arguments, existence de la cible, distance joueur–cible, phase de jeu),
  comme toutes les intentions déjà en place.
- **FR-012**: Le panneau de développement DOIT permettre de forcer la réparation complète du bus,
  pour tester le départ sans dépendre d'une récolte réelle (même principe que les commandes de
  développement déjà en place pour la commande de la nuit et l'ennemi).

### Key Entities

- **Ferraille (Scrap)** : nouveau type de ressource récoltable en forêt, au même titre que
  l'essence, le steak suspect et le pain de route ; sert uniquement à réparer le bus, jamais au
  stock partagé du restaurant ni au générateur.
- **Bus** : élément déjà présent visuellement (premier incrément, purement décoratif) ; gagne un
  état de réparation partagé par l'équipe (progression actuelle, total requis — proportionnel à
  l'effectif présent au début de l'Évasion, fixé à cet instant —, réparé ou non) et une action de
  départ qui déclenche la victoire.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Une équipe qui a survécu au nombre de nuits requis peut réparer entièrement le bus
  et déclencher la victoire en moins de 10 minutes de récolte active, en solo comme à plusieurs.
- **SC-002**: 100 % des tentatives de départ avec un bus pas encore entièrement réparé sont
  refusées sans aucun effet sur l'état de partie.
- **SC-003**: 100 % des dépôts de ferraille valides mettent à jour la progression de réparation
  visible par tous les joueurs présents, sans décalage perceptible entre les clients.
- **SC-004**: Une partie peut être rejouée entièrement plusieurs fois de suite (survie, réparation,
  départ, redémarrage) sans erreur ni état résiduel de la partie précédente (ferraille ou
  réparation qui persisterait).
- **SC-005**: Aucun gel perceptible du serveur n'est observé à l'apparition des tas de ferraille,
  au dépôt ou au déclenchement de la victoire, y compris à 6 joueurs.

## Assumptions

- **Base technique** : cette fonctionnalité s'appuie entièrement sur les socles existants
  (`001-socle-technique`, `002-premier-increment-jouable`) : horloge de partie et phase
  d'Évasion déjà présente, sessions joueurs, canal d'intentions validées, configuration
  centrale, points de référence du monde (dont `BusSpot`), catalogue de visuels avec
  remplaçants en primitives, écran de fin et redémarrage automatique. Aucune de ces briques
  n'est reconstruite ici.
- **Récolte possible avant l'Évasion** : la récolte et le dépôt de ferraille sont ouverts dès le
  début de la partie (comme les autres ressources), pour permettre à l'équipe de s'organiser à
  l'avance plutôt que de tout faire dans l'urgence une fois les nuits survécues. Seul le départ
  effectif (déclenchement de la victoire) est réservé à la phase d'Évasion, conformément à la
  constitution (« survivre… puis réparer »).
- **Pas de nouvelle menace pendant l'Évasion** : cette fonctionnalité n'introduit aucun danger
  spécifique à la phase d'Évasion (pas de nouvel ennemi, pas de limite de temps) ; la phase reste
  sans limite (`Match.EscapeDuration` à 0), comme déjà configuré. Une tension propre à l'Évasion
  pourra être ajoutée dans un incrément ultérieur.
- **Une seule vague de réparation** : le bus se répare en un seul total cumulé (comme le
  carburant du générateur), pas par étapes distinctes ni par pièces différentes à réparer
  séparément ; une réparation en plusieurs étapes distinctes pourra être introduite plus tard si
  besoin.
- **Essence non requise pour le bus** : contrairement à la mention du catalogue MVP (« Essence :
  alimenter le générateur et le bus final »), cette fonctionnalité ne fait pas dépendre la
  réparation de l'essence, pour ne pas entrer en concurrence avec son usage déjà établi au
  générateur (premier incrément) ; ce choix pourra être révisé dans un incrément ultérieur si le
  jeu a besoin de renforcer cette tension.
