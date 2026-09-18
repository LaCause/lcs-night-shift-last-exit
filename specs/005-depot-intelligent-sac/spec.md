# Feature Specification: Vidage progressif du sac et dépôt automatique aux postes

**Feature Branch**: `005-depot-intelligent-sac`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description : « Quand on clique sur G, le sac lâche les items 1 par 1 par ordre
des derniers items mis dans le sac. Quand on garde G appuyé, ça vide tout le sac. Il faut que
quand un item est lâché par exemple proche du générateur, si c'est l'essence il faut que ça ajoute
l'essence au générateur et que cette mécanique soit pareil sur tout les items qui ont une
action. »

Cette fonctionnalité prolonge `004-sac-collecte` : elle remplace le vidage « tout ou rien » du sac
par un contrôle progressif, et donne un sens contextuel au fait de lâcher un objet près d'un poste
qui sait déjà en faire quelque chose.

## Clarifications

### Session 2026-09-18

- Q: Quand le joueur maintient la touche de vidage pour tout vider, les objets doivent-ils sortir
  un par un avec un léger délai visible entre chacun, ou tous d'un coup en une seule action ? → A:
  Une seule action groupée, comme le vidage complet actuel de 004-sac-collecte : chaque objet est
  traité individuellement et dans l'ordre inverse du ramassage en coulisses, mais rien n'exige un
  défilé visible à l'écran ni une suite d'actions séparées.
- Q: Pour décider si un objet lâché doit être automatiquement déposé, la distance à mesurer est-elle
  celle entre le joueur et le poste, ou celle entre l'objet lâché lui-même et le poste ? → A: Entre
  l'objet lâché et le poste — chaque objet est évalué à sa propre position d'arrivée, pas à celle du
  joueur. Deux objets d'un même vidage peuvent donc avoir des issues différentes si l'un atterrit
  dans la portée du poste et l'autre juste en dehors ; c'est un effet accepté de ce choix, pas un
  défaut à corriger.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Déposer automatiquement un objet lâché près d'un poste compatible (Priority: P1)

Un joueur porte de l'essence dans son sac. Il s'approche du générateur et appuie sur la touche de
vidage. Plutôt que de tomber au sol, l'essence rejoint directement le carburant du générateur —
exactement comme s'il l'avait ravitaillé à la main. La même logique s'applique à tout autre objet
transporté près du poste qui sait s'en servir (le comptoir pour la nourriture, le bus pour la
ferraille) : lâcher un objet à portée du bon poste équivaut à l'y déposer.

**Why this priority** : c'est la demande la plus explicite et la plus structurante de cette
fonctionnalité — elle transforme le geste de vider son sac en un raccourci pour toutes les
interactions de dépôt déjà existantes, sans qu'aucun poste supplémentaire ne soit à visiter à la
main. Elle a de la valeur même si le vidage reste « tout ou rien » (comportement actuel de
004-sac-collecte).

**Independent Test** : porter de l'essence, s'approcher du générateur à la distance d'interaction
habituelle, vider le sac, et constater que le carburant du générateur augmente exactement du
montant transporté, sans qu'aucun objet ne reste au sol.

**Acceptance Scenarios**:

1. **Given** un joueur transportant de l'essence, **When** il la lâche (par vidage partiel ou
   complet du sac) et qu'elle atterrit à portée d'interaction du générateur, **Then** le carburant
   du générateur augmente d'autant, le joueur reçoit le même retour que s'il avait ravitaillé à la
   main, et aucun objet n'apparaît au sol.
2. **Given** un joueur transportant du steak suspect ou du pain de route, **When** il lâche cet
   objet et qu'il atterrit à portée du comptoir, **Then** il rejoint le stock partagé du
   restaurant, comme un dépôt manuel.
3. **Given** un joueur transportant de la ferraille, **When** il lâche cet objet et qu'il atterrit
   à portée du bus, **Then** elle est comptée dans la réparation du bus, comme un dépôt manuel.
4. **Given** un joueur lâche un objet dont la position d'arrivée est hors de portée de tout poste
   compatible, **When** l'objet atterrit, **Then** il tombe au sol normalement, ramassable et
   déplaçable par toute l'équipe — comme aujourd'hui.
5. **Given** un objet atterrit à portée d'un poste déjà à sa limite (générateur plein, bus déjà
   réparé), **When** il touche le sol, **Then** il y reste normalement au lieu de disparaître sans
   effet — rien n'est perdu.
6. **Given** un sac contenant plusieurs types d'objets, **When** le joueur le vide entièrement à
   portée d'un seul poste, **Then** seuls les objets que ce poste sait utiliser lui sont déposés ;
   les autres tombent au sol, exactement comme s'il n'y avait pas de poste à proximité.

---

### User Story 2 - Choisir de lâcher un seul objet ou tout le sac (Priority: P2)

Le joueur peut désormais lâcher ses objets progressivement plutôt que tout d'un coup. Une pression
brève sur la touche de vidage ne fait tomber que le dernier objet mis dans le sac. Maintenir la
touche enfoncée vide le sac en entier, objet par objet, dans le même ordre.

**Why this priority** : c'est un contrôle plus fin sur un geste qui existe déjà (vider le sac,
004-sac-collecte) — utile pour ne relâcher qu'un objet précis (par exemple juste l'essence, au
générateur, sans jeter le reste du sac au sol), mais la fonctionnalité reste jouable sans lui : le
vidage complet (Story 1) fonctionne déjà seul.

**Independent Test** : remplir le sac avec plusieurs objets de types différents (par récolte
réelle ou commande de développement), noter l'ordre de ramassage, presser brièvement la touche de
vidage et vérifier que seul le dernier objet ramassé disparaît du sac ; puis maintenir la touche et
vérifier qu'une seule action fait sortir le reste du sac d'un coup, chaque objet ayant été traité
dans l'ordre inverse de son ramassage.

**Acceptance Scenarios**:

1. **Given** un sac contenant plusieurs objets ramassés dans un ordre connu, **When** le joueur
   presse brièvement la touche de vidage, **Then** seul le dernier objet ramassé quitte le sac ;
   le reste du contenu est inchangé.
2. **Given** un sac contenant plusieurs objets, **When** le joueur maintient la touche de vidage
   au-delà du seuil, **Then** le sac se vide en une seule action, chaque objet étant traité dans
   l'ordre inverse de son ramassage (déposé automatiquement ou tombé au sol selon sa cible), et se
   retrouve vide immédiatement.
3. **Given** le joueur maintient la touche au-delà du seuil, **When** le vidage complet s'est déjà
   déclenché une fois pendant ce maintien, **Then** il ne se redéclenche pas tant que la touche
   reste enfoncée ; il faut la relâcher puis la presser de nouveau pour agir une seconde fois.
4. **Given** un sac déjà vide ou un sac non équipé, **When** le joueur presse ou maintient la
   touche de vidage, **Then** rien ne se produit, sans message d'erreur intrusif.
5. **Given** un joueur qui relâche la touche juste avant le seuil de maintien, **When** l'appui est
   trop court pour compter comme un maintien, **Then** exactement un seul objet est lâché (le geste
   compte comme une pression brève, jamais comme un vidage partiel du maintien).

---

### Edge Cases

- Un objet en cours de dépôt automatique ne doit jamais apparaître brièvement au sol avant d'être
  absorbé par le poste : pas d'objet fantôme, pas de duplication.
- Un poste atteint sa limite en plein milieu d'un vidage complet (par exemple le générateur se
  remplit après avoir absorbé 2 des 3 essences du sac) : les unités suivantes de ce type tombent au
  sol normalement, sans interrompre le reste du vidage.
- Deux joueurs vident leur sac au même poste au même moment : les deux dépôts s'additionnent
  correctement, comme pour un dépôt manuel à plusieurs.
- Le joueur relâche la touche, se déconnecte ou est éliminé avant que le seuil de maintien soit
  atteint : rien n'est envoyé, le sac reste inchangé, comme n'importe quel appui non validé. Une
  fois le seuil atteint, le vidage complet se résout en une seule fois côté serveur : aucune
  déconnexion ne peut donc le laisser à moitié fait.
- Le joueur maintient la touche alors qu'il n'a qu'un seul objet dans le sac : cet objet est lâché
  (et éventuellement déposé automatiquement), le sac atteint zéro, rien d'autre ne se produit même
  si la touche reste enfoncée.
- Le joueur relâche un objet à la fois près d'un poste incompatible avec son type (par exemple de
  la ferraille près du générateur) : l'objet tombe au sol normalement, comme s'il n'y avait pas de
  poste à proximité.
- Un vidage complet disperse plusieurs objets autour du joueur : deux objets identiques peuvent
  atterrir à des distances légèrement différentes du même poste. Si l'un tombe dans la portée et
  l'autre juste en dehors, seul le premier est déposé automatiquement — c'est la distance de
  chaque objet à sa propre position d'arrivée qui compte, jamais celle du joueur.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Une pression brève sur la touche de vidage DOIT faire quitter le sac exactement un
  objet : celui ramassé le plus récemment.
- **FR-002**: Maintenir la touche de vidage au-delà du seuil DOIT vider le sac dans son intégralité
  en une seule action groupée : chaque objet est traité individuellement et dans l'ordre inverse du
  ramassage (déposé automatiquement ou tombé au sol selon FR-005 à FR-008), sans exiger de suite
  d'actions séparées ni de défilé visible objet par objet. L'action ne se redéclenche pas tant que
  la touche reste enfoncée après son premier déclenchement.
- **FR-003**: Un appui relâché avant le seuil de maintien DOIT toujours compter comme une pression
  brève (un seul objet), jamais comme un vidage partiel.
- **FR-004**: L'ordre de sortie des objets DOIT toujours être l'inverse strict de leur ordre
  d'entrée dans le sac (dernier entré, premier sorti), que la sortie se fasse un par un ou par
  vidage complet.
- **FR-005**: Quand un objet quitte le sac et que sa position d'arrivée — celle de l'objet
  lui-même, pas celle du joueur qui l'a lâché — est à portée d'interaction d'un poste dont l'action
  correspond à son type, le système DOIT exécuter cette action automatiquement (comme un dépôt
  manuel à ce poste) au lieu de laisser l'objet au sol.
- **FR-006**: Cette correspondance objet-poste DOIT s'appliquer de façon générique à tout type
  d'objet ayant une action de poste existante, sans traitement particulier pour l'essence : la même
  règle couvre aujourd'hui l'essence (générateur), le steak suspect et le pain de route (comptoir),
  et la ferraille (bus), et DOIT pouvoir couvrir un futur type sans changement de logique.
- **FR-007**: Si le poste compatible ne peut pas utiliser l'objet au moment du dépôt (capacité
  atteinte, progression déjà complète), l'objet DOIT tomber au sol normalement plutôt que de
  disparaître sans effet.
- **FR-008**: Un objet lâché hors de portée de tout poste compatible DOIT tomber au sol normalement
  — ramassable et déplaçable par toute l'équipe, exactement comme le comportement existant.
- **FR-009**: Un dépôt automatique DOIT produire le même retour visuel/sonore et la même
  confirmation qu'un dépôt manuel au même poste, pour que le joueur comprenne toujours ce qu'il
  vient de se passer.
- **FR-010**: Le contenu et la jauge du sac affichés au joueur DOIVENT se mettre à jour
  immédiatement après chaque sortie d'objet, qu'elle soit unitaire, automatique ou complète.
- **FR-011**: Vider le sac (unitairement ou entièrement) DOIT continuer d'exiger que le sac soit
  équipé en main, sans exception — la règle déjà en place n'est pas assouplie.
- **FR-012**: Aucune séquence de sortie et de dépôt automatique NE DOIT créer ni détruire de
  ressource : la quantité totale transportée par un joueur reste identique, qu'un objet finisse au
  sol, dans un poste, ou de nouveau dans le sac.
- **FR-013**: Actionner la touche de vidage (brièvement ou en maintien) sans sac équipé ou avec un
  sac vide NE DOIT produire aucun effet ni message d'erreur intrusif.

### Key Entities

- **Contenu ordonné du sac** : la liste des objets transportés, désormais tracée dans leur ordre
  d'arrivée (et non plus seulement par un total par type), pour que « le dernier objet mis dans le
  sac » ait toujours un sens précis.
- **Correspondance objet-poste** : l'association entre un type d'objet transporté et le poste dont
  l'action existante sait le consommer (essence↔générateur, steak suspect/pain de
  route↔comptoir, ferraille↔bus). Conçue pour accueillir une future paire sans logique nouvelle,
  dans le même esprit que les types de sac de 004-sac-collecte.
- **Dépôt automatique** : un dépôt déclenché par la position d'arrivée de l'objet lâché lui-même
  (jamais celle du joueur), strictement équivalent à l'action manuelle du même poste — mêmes règles
  de capacité, même retour, même historique.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un joueur dépose de l'essence au générateur (ou tout autre objet compatible à son
  poste) en une seule action de vidage, sans visiter le poste séparément ni ouvrir de menu.
- **SC-002**: 100 % des objets lâchés à portée d'un poste compatible et disponible sont absorbés
  par ce poste plutôt que laissés au sol.
- **SC-003**: 100 % des objets lâchés hors de portée d'un poste compatible, ou près d'un poste déjà
  à sa limite, atterrissent normalement au sol — aucun n'est perdu.
- **SC-004**: Un joueur peut retirer un seul objet précis de son sac (le dernier ramassé) en une
  pression, sans affecter le reste du contenu, à chaque tentative.
- **SC-005**: Un joueur peut vider tout son sac en une seule action continue (maintenir la touche),
  sans avoir à répéter l'appui autant de fois qu'il y a d'objets.
- **SC-006**: Aucune ressource n'est créée ni perdue sur l'ensemble d'un cycle lâcher/déposer/
  reramasser, sur 100 % des essais (prolonge SC-008 de 004-sac-collecte).
- **SC-007**: Un nouveau joueur découvre le dépôt automatique sans tutoriel, simplement en vidant
  son sac près d'un poste et en reconnaissant le même retour qu'un dépôt manuel.

## Assumptions

- **Prolongement direct de 004-sac-collecte** : cette fonctionnalité révise le geste de vidage déjà
  livré (touche dédiée, sac équipé requis, objets lâchés redevenant des objets du monde) plutôt que
  d'introduire un système parallèle. Toutes les règles déjà établies (sac en main obligatoire,
  aucune réapparition d'un objet lâché, réinitialisation à chaque partie) restent en vigueur.
- **Tous les types actuels ont déjà une action de poste** : essence (générateur), steak suspect et
  pain de route (comptoir), ferraille (bus). Aucun type n'est donc concerné par un « lâcher sans
  dépôt possible » aujourd'hui ; la règle est néanmoins écrite de façon générique pour qu'un futur
  type sans poste associé tombe simplement au sol, comme le prévoit déjà FR-008.
- **Seuil de maintien** : la distinction entre pression brève et maintien repose sur une courte
  durée fixe de seuil ; sa valeur exacte est un réglage d'équilibrage à centraliser, pas un choix
  visible du joueur.
- **Portée du dépôt automatique** : réutilise la distance d'interaction déjà définie pour chaque
  poste (celle utilisée pour son action manuelle existante) ; aucune nouvelle distance n'est
  introduite conceptuellement. Seul le point de mesure change par rapport aux interactions
  manuelles existantes : c'est la position d'arrivée de l'objet qui est comparée à cette distance,
  pas celle du joueur (Clarifications, session 2026-09-18).
- **Périmètre du geste concerné** : cette mécanique s'applique uniquement aux objets qui quittent le
  sac par la touche de vidage (pression ou maintien). Déplacer à la souris un objet déjà au sol
  (004-sac-collecte, Story 3) reste inchangé et ne déclenche aucun dépôt automatique — ce geste sert
  à repositionner, pas à transporter depuis le sac.
- **Concurrence multijoueur** : les règles déjà en place pour les dépôts manuels simultanés à un
  même poste s'appliquent sans changement aux dépôts automatiques ; aucune règle de concurrence
  nouvelle n'est introduite.
- **Retour joueur** : le dépôt automatique réutilise exactement la confirmation déjà associée au
  dépôt manuel de ce poste, pour qu'un joueur n'ait qu'un seul signal à apprendre pour un même
  résultat.
