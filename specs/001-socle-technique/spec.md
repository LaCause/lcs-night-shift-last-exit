# Feature Specification: Socle technique du projet

**Feature Branch**: `main` (pas de branche dédiée ; fonctionnalité suivie via `.specify/feature.json`)

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "créer le socle technique du projet, tu peux voir les informations ici : @TECH.md"

**Axes d'évolutivité renforcés** : coopération (état de partie et d'équipe partagé par tous) et
rejouabilité (seed par partie, parties reproductibles). Le socle est un prérequis de tous les
autres axes.

## Clarifications

### Session 2026-09-13

- Q: Le socle inclut-il l'initialisation du dépôt avec Rojo ? → A: Oui, explicitement :
  `default.project.json` à la racine, synchronisation `rojo serve` avec le plugin Studio,
  génération de place avec `rojo build`, version de Rojo fixée dans le dépôt (FR-001 à FR-003,
  FR-008).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dépôt Rojo et première session jouable (Priority: P1)

Le dépôt est initialisé comme projet Rojo. Le développeur part d'une copie du dépôt et d'une
place vide dans Roblox Studio. Il suit les instructions, lance `rojo serve`, connecte le plugin
Rojo de Studio, puis démarre un test : son personnage apparaît devant un restaurant provisoire
construit en formes simples, avec son drive-thru, son interphone, son comptoir, sa cuisine, son
générateur, son enseigne néon et un vieux bus garé à côté. Aucun élément n'a été placé à la
main, et toute modification d'un fichier du dépôt apparaît aussitôt dans Studio. Il peut aussi
générer une place complète directement depuis le dépôt.

**Why this priority**: tout le projet repose sur cette base. Sans dépôt Rojo reproductible,
aucune fonctionnalité ne peut être testée ni partagée.

**Independent Test**: depuis une copie fraîche du dépôt et une place vide, suivre les
instructions, synchroniser avec `rojo serve`, puis lancer un test solo et un test à 2 joueurs :
chaque joueur apparaît au restaurant, tous les points de référence sont présents et la sortie
ne contient aucune erreur. Modifier ensuite un fichier et vérifier sa mise à jour dans Studio,
puis générer une place avec `rojo build` et la lancer.

**Acceptance Scenarios**:

1. **Étant donné** une copie fraîche du dépôt et une place vide, **Quand** le développeur lance
   `rojo serve`, connecte le plugin Rojo de Studio puis lance un test solo, **Alors** son
   personnage apparaît au point d'apparition du restaurant et la sortie ne contient aucune
   erreur.
2. **Étant donné** une session lancée, **Quand** on inspecte le monde de départ, **Alors** le
   restaurant provisoire, le point d'apparition, le bus provisoire et tous les points de
   référence nommés sont présents.
3. **Étant donné** un test multijoueur local à 2 joueurs, **Quand** les deux joueurs arrivent,
   **Alors** chacun apparaît au restaurant, sans erreur côté serveur ni côté joueurs.
4. **Étant donné** un système volontairement mis en échec au démarrage, **Quand** la session
   démarre, **Alors** les autres systèmes fonctionnent et un message d'erreur nomme le système
   fautif et le motif.
5. **Étant donné** un nouveau système de démonstration ajouté au projet, **Quand** la session
   démarre, **Alors** il est initialisé sans qu'aucun système existant n'ait été modifié.
6. **Étant donné** une session synchronisée par Rojo, **Quand** le développeur modifie un
   fichier de script dans le dépôt, **Alors** la modification apparaît dans Studio sans aucune
   manipulation.
7. **Étant donné** une copie fraîche du dépôt, **Quand** le développeur génère une place avec
   `rojo build` et l'ouvre dans Studio, **Alors** la place contient tout le nécessaire et un
   test solo se lance sans erreur.

---

### User Story 2 - Une partie qui se déroule pour toute l'équipe (Priority: P2)

De 1 à 6 joueurs rejoignent le serveur. Dès qu'un premier joueur est présent, un compte à
rebours annonce le début de la partie. Le serveur fait ensuite alterner jours et nuits selon
les durées configurées, compte les nuits jusqu'à la dernière, puis ouvre la phase d'évasion.
Chaque joueur voit en permanence la phase en cours, le numéro de nuit, le temps restant et
l'état de l'équipe ; un fil de notifications annonce les changements de phase ainsi que les
arrivées et départs de joueurs.

**Why this priority**: l'horloge de partie est la colonne vertébrale de la boucle de jeu
(principe I). Toutes les fonctionnalités du MVP (ambiance, générateur, commande, ennemi)
réagiront à ses phases.

**Independent Test**: en profil de test (durées courtes), lancer un test à 2 joueurs et
observer l'enchaînement complet jusqu'à la phase d'évasion, puis faire rejoindre un 3e joueur
en pleine nuit.

**Acceptance Scenarios**:

1. **Étant donné** un serveur sans partie en cours, **Quand** un premier joueur arrive,
   **Alors** un compte à rebours de début s'affiche, puis la partie démarre au Jour 1.
2. **Étant donné** une partie en cours, **Quand** la durée d'une phase est écoulée, **Alors**
   la phase suivante commence pour tous les joueurs en même temps, dans l'ordre
   Jour 1 → Nuit 1 → Jour 2 → … → Nuit 7 → Évasion.
3. **Étant donné** une partie en cours à plusieurs joueurs, **Quand** on compare leurs écrans,
   **Alors** tous affichent la même phase, le même numéro de nuit (ex. « Nuit 3 / 7 ») et le
   même temps restant, à 1 seconde près.
4. **Étant donné** une partie en pleine nuit, **Quand** un nouveau joueur rejoint, **Alors** il
   apparaît au restaurant comme joueur actif et voit immédiatement la phase, la nuit et le
   temps restant corrects.
5. **Étant donné** une partie en cours, **Quand** un joueur rejoint ou quitte, **Alors** l'état
   de l'équipe et le fil de notifications sont mis à jour chez tous les autres joueurs.
6. **Étant donné** le compte à rebours de début en cours, **Quand** tous les joueurs quittent,
   **Alors** le compte à rebours est annulé et le serveur revient en attente.

---

### User Story 3 - Des actions de joueurs validées par le serveur (Priority: P3)

Un joueur s'approche du comptoir et sonne la sonnette. Le serveur vérifie qu'il est assez
proche, que la sonnette n'est pas en délai de réutilisation et que la phase le permet ; tous
les joueurs voient alors la sonnette réagir et une notification indiquant qui a sonné. Un
client modifié qui tente de sonner à distance, d'envoyer des paramètres invalides ou de
marteler la sonnette n'obtient aucun effet, et chaque tentative est journalisée. Cette
interaction sert de modèle à toutes les interactions futures (ramasser, déposer, cuisiner,
alimenter le générateur, livrer).

**Why this priority**: l'autorité serveur est le seul principe non négociable de la
constitution (principe III). Poser le modèle dès le socle évite que chaque fonctionnalité
réinvente sa propre validation.

**Independent Test**: en test à 2 joueurs, sonner depuis le comptoir (retour visible chez les
deux joueurs), puis lancer la liste de contrôle des requêtes invalides via l'outil de
développement et vérifier qu'aucune n'a d'effet et que chacune est journalisée.

**Acceptance Scenarios**:

1. **Étant donné** un joueur à portée de la sonnette, **Quand** il l'actionne, **Alors** tous
   les joueurs voient la sonnette réagir et une notification « <joueur> a sonné » s'affiche.
2. **Étant donné** un joueur hors de portée, **Quand** une demande de sonner est envoyée en son
   nom, **Alors** elle est refusée, rien ne se passe et un avertissement indique le joueur,
   l'action et le motif « trop loin ».
3. **Étant donné** une sonnette en délai de réutilisation, **Quand** un joueur la sonne à
   nouveau, **Alors** la demande est ignorée, sans effet visible pour les autres.
4. **Étant donné** un client qui envoie des demandes plus vite que la limite configurée,
   **Quand** la limite est dépassée, **Alors** les demandes excédentaires sont ignorées et
   journalisées, et la partie continue normalement pour tous.
5. **Étant donné** une demande aux paramètres malformés ou visant une cible inexistante,
   **Quand** le serveur la reçoit, **Alors** elle est refusée sans erreur ni effet sur l'état
   de jeu.
6. **Étant donné** l'écran de fin de partie affiché, **Quand** un joueur tente de sonner,
   **Alors** la demande est refusée avec le motif « phase interdite ».

---

### User Story 4 - Fin de partie et nouvelle partie (Priority: P4)

Quand une partie se termine, par une victoire ou une défaite, tous les joueurs voient un écran
de fin avec le résultat, la nuit atteinte et un compte à rebours. Une nouvelle partie démarre
ensuite automatiquement avec une nouvelle seed : l'état est remis à zéro et les joueurs sont
replacés au restaurant. La défaite est déclenchée automatiquement dès que tous les joueurs
présents sont éliminés. Dans le socle, la victoire et l'élimination sont déclenchées par des
commandes de développement ; les fonctionnalités du bus et de la santé s'y brancheront plus
tard.

**Why this priority**: sans fin de partie ni redémarrage, une session de test ne peut pas
enchaîner plusieurs parties. La règle de défaite fait partie de la boucle canonique
(principe I).

**Independent Test**: en test à 2 joueurs, forcer une victoire, vérifier l'écran de fin et le
redémarrage ; puis éliminer les deux joueurs par commande et vérifier la défaite automatique.

**Acceptance Scenarios**:

1. **Étant donné** une partie en cours, **Quand** une victoire est déclenchée, **Alors** tous
   les joueurs voient l'écran de fin « Victoire » avec la nuit atteinte et un compte à rebours.
2. **Étant donné** une partie à 2 joueurs, **Quand** un seul joueur est éliminé, **Alors** la
   partie continue ; **Quand** le second est éliminé à son tour, **Alors** la partie se termine
   immédiatement en défaite.
3. **Étant donné** l'écran de fin affiché, **Quand** son compte à rebours se termine, **Alors**
   une nouvelle partie démarre avec une nouvelle seed, tous les joueurs sont replacés au
   restaurant avec le statut « en vie » et l'affichage repart au compte à rebours de début.
4. **Étant donné** l'écran de fin affiché, **Quand** un nouveau joueur rejoint, **Alors** il
   voit l'écran de fin, puis participe à la partie suivante.

---

### User Story 5 - Réglages centralisés, parties reproductibles et visuels de secours (Priority: P5)

Le game designer ajuste une valeur (durée du jour, nombre de nuits, portée de la sonnette…) à
un seul endroit et la retrouve appliquée au test suivant ; une valeur incohérente est signalée
et remplacée par sa valeur par défaut. Chaque partie a une seed visible des développeurs : en
la forçant, on rejoue les mêmes tirages aléatoires, ce qui permet de reproduire un bug. Enfin,
le jeu reste jouable sans aucun élément visuel externe : chaque visuel externe a un remplaçant
en formes simples, utilisé automatiquement.

**Why this priority**: rend l'équilibrage rapide et les bugs reproductibles (principes IV, V
et VIII). Moins urgent que les stories précédentes, car les valeurs par défaut suffisent pour
tester.

**Independent Test**: modifier la durée du jour et la portée de la sonnette puis relancer ;
saisir une valeur invalide ; lancer deux parties avec la même seed forcée et comparer les
tirages de contrôle ; activer le réglage « formes simples uniquement ».

**Acceptance Scenarios**:

1. **Étant donné** la configuration centrale, **Quand** le designer modifie la durée du jour,
   **Alors** le test suivant utilise la nouvelle durée, sans autre modification.
2. **Étant donné** une valeur de configuration manquante, de mauvais type ou hors bornes,
   **Quand** la session démarre, **Alors** la valeur par défaut est utilisée et un
   avertissement nomme le réglage et la valeur rejetée.
3. **Étant donné** une seed forcée dans la configuration, **Quand** deux parties sont lancées,
   **Alors** elles ont la même seed et produisent les mêmes tirages de contrôle pour un même
   contexte.
4. **Étant donné** aucune seed forcée, **Quand** une nouvelle partie démarre, **Alors** une
   nouvelle seed est tirée et apparaît dans le journal et dans l'outil de diagnostic.
5. **Étant donné** un visuel externe indisponible ou le réglage « formes simples uniquement »
   actif, **Quand** ce visuel doit être affiché, **Alors** son remplaçant en formes simples est
   utilisé et un avertissement est journalisé.
6. **Étant donné** le profil de test activé, **Quand** une partie démarre, **Alors** toutes les
   phases utilisent les durées courtes, sans que les valeurs de référence aient été modifiées.

---

### Edge Cases

- Un joueur quitte pendant une phase : sa session est supprimée, l'état de l'équipe est mis à
  jour chez les autres en moins de 2 secondes et la partie continue.
- Tous les joueurs quittent en cours de partie : la partie est abandonnée et le serveur revient
  en attente ; le prochain joueur démarre une nouvelle partie avec une nouvelle seed.
- Le dernier joueur encore en vie quitte alors que les autres sont éliminés : tous les joueurs
  présents sont éliminés, la partie se termine en défaite.
- Un joueur rejoint pendant le compte à rebours de début : il participe à la partie qui démarre.
- Un 7e joueur tente de rejoindre : le serveur est plein (capacité de 6), il n'entre pas.
- Le personnage d'un joueur tombe hors du monde ou réapparaît : il réapparaît au point
  d'apparition du restaurant (la réapparition limitée arrivera avec le système de santé).
- L'interface d'un joueur se charge après un changement de phase : elle affiche l'état courant
  complet, pas seulement les changements suivants.
- Une durée de phase configurée à zéro, négative ou absente : la valeur par défaut est utilisée
  avec un avertissement ; aucune phase ne dure 0 seconde.
- Un système qui réagit à un changement de phase échoue : l'erreur est journalisée, l'horloge
  et les autres systèmes continuent.
- Une commande de développement est tentée dans un serveur publié : elle est refusée et
  journalisée, sans effet.
- Une victoire et une défaite sont déclenchées au même instant : seul le premier résultat reçu
  par le serveur est retenu, et la fin de partie ne se produit qu'une fois.
- Plusieurs joueurs sonnent en même temps : une seule sonnerie est acceptée, les autres tombent
  dans le délai de réutilisation.
- Le plugin Rojo de Studio et la version de Rojo fixée dans le dépôt diffèrent : la connexion
  échoue avec un message explicite, et les instructions indiquent comment aligner les versions.
- Un élément géré par Rojo est modifié directement dans Studio : la modification n'est pas
  enregistrée dans le dépôt et peut être écrasée à la synchronisation suivante ; les
  instructions rappellent que toute modification se fait dans le dépôt.

## Requirements *(mandatory)*

### Functional Requirements

**Initialisation Rojo, structure et installation**

- **FR-001**: Le dépôt DOIT être initialisé comme projet Rojo : un fichier `default.project.json`
  à la racine décrit l'arborescence et la relie aux services Roblox `ReplicatedStorage`,
  `ServerScriptService`, `StarterPlayer` (`StarterPlayerScripts`), `StarterGui` et `Workspace`.
- **FR-002**: Le projet DOIT fonctionner selon deux modes : synchronisation en direct vers Studio
  (`rojo serve` et plugin Rojo de Studio), où toute modification d'un fichier du dépôt apparaît
  dans Studio sans manipulation ; génération d'une place complète depuis le dépôt
  (`rojo build`).
- **FR-003**: La version de Rojo DOIT être fixée dans le dépôt, pour que tout développeur utilise
  la même version de l'outil et du plugin Studio ; les fichiers générés (places construites,
  fichiers temporaires de Studio) DOIVENT être exclus du versionnement.
- **FR-004**: Le projet DOIT être entièrement reproductible depuis le dépôt : code, interface et
  contenu indispensable du monde de départ s'obtiennent par synchronisation Rojo dans une place
  vide, sans aucun placement ni déplacement manuel dans Studio.
- **FR-005**: Le projet DOIT séparer ses éléments par responsabilité, selon la répartition par
  service de la constitution (logique d'autorité côté serveur ; éléments partagés :
  configuration, déclaration des échanges, visuels réutilisables ; logique locale du joueur ;
  interface ; monde de départ), puis par domaine fonctionnel.
- **FR-006**: L'ajout d'un nouveau système, côté serveur ou côté joueur, NE DOIT exiger aucune
  modification des systèmes existants.
- **FR-007**: Le monde de départ DOIT contenir, en formes simples low-poly : un restaurant
  provisoire, un point d'apparition, un bus provisoire et des points de référence nommés
  (fenêtre du drive-thru, interphone, comptoir avec sonnette, plan de travail, friteuse,
  générateur, enseigne néon, centre de la zone de sécurité, emplacement du bus).
- **FR-008**: Le socle DOIT être livré avec des instructions pas à pas (installation de Rojo et du
  plugin Studio de même version, lancement de `rojo serve` et connexion depuis Studio,
  génération d'une place avec `rojo build`, rappel que toute modification se fait dans le
  dépôt et non dans Studio, réglages de publication dont la capacité de 6 joueurs, test solo,
  test multijoueur local) et une checklist de test solo et multijoueur.

**Démarrage, robustesse et diagnostics**

- **FR-009**: Au démarrage, côté serveur comme côté joueur, chaque système DOIT s'initialiser
  indépendamment ; l'échec d'un système DOIT être journalisé avec son nom et le motif, sans
  empêcher les autres de démarrer.
- **FR-010**: L'échec d'un système qui réagit à un événement de partie NE DOIT interrompre ni
  l'horloge de partie ni les autres systèmes.
- **FR-011**: Chaque message de journal DOIT indiquer le système émetteur et un niveau
  (information, avertissement, erreur) ; le niveau de détail affiché DOIT être réglable.
- **FR-012**: Le démarrage d'une partie, les changements de phase et l'arrivée d'un joueur NE
  DOIVENT provoquer aucun gel perceptible pour les joueurs.

**Configuration**

- **FR-013**: Toutes les valeurs d'équilibrage et de réglage DOIVENT être regroupées dans une
  configuration centrale unique, organisée par domaine.
- **FR-014**: La configuration DOIT fournir au minimum : durée du jour (4 min), durée de la nuit
  (5 min), nombre de nuits (7), nombre maximal de joueurs (6), compte à rebours de début
  (15 s), délai avant nouvelle partie (15 s), durée de la phase d'évasion (sans limite par
  défaut), portée et délai de réutilisation de la sonnette, limite de fréquence des requêtes.
- **FR-015**: Chaque réglage DOIT avoir une valeur par défaut et des bornes ; au démarrage, toute
  valeur manquante, de mauvais type ou hors bornes DOIT être remplacée par sa valeur par défaut
  avec un avertissement nommant le réglage.
- **FR-016**: Un profil de test DOIT permettre, par un seul réglage, de raccourcir toutes les
  durées de phase (15 s par phase par défaut) sans modifier les valeurs de référence.

**Horloge de partie**

- **FR-017**: Le serveur DOIT être seul à décider du déroulement de la partie. Les phases
  s'enchaînent dans cet ordre : Attente → Compte à rebours → Jour 1 → Nuit 1 → … → Jour N →
  Nuit N → Évasion → Fin, N étant le nombre de nuits configuré.
- **FR-018**: La partie DOIT rester en Attente tant qu'aucun joueur n'est présent ; l'arrivée du
  premier joueur lance le compte à rebours ; si tous les joueurs quittent, pendant le compte à
  rebours ou en cours de partie, le serveur DOIT abandonner la partie et revenir en Attente.
- **FR-019**: L'état de partie (phase, numéro de nuit, nombre total de nuits, temps restant,
  résultat) DOIT être diffusé à tous les joueurs ; un joueur qui arrive, ou dont l'interface se
  charge, DOIT recevoir l'état courant complet.
- **FR-020**: Les systèmes DOIVENT pouvoir réagir au début et à la fin de chaque phase ainsi
  qu'à la fin de partie, sans dépendre les uns des autres.

**Joueurs et équipe**

- **FR-021**: Chaque joueur qui rejoint DOIT recevoir une session de partie (statut « en vie »
  par défaut), supprimée proprement à son départ.
- **FR-022**: Un joueur qui rejoint en cours de partie DOIT y participer comme joueur actif ;
  s'il rejoint pendant l'écran de fin, il participe à la partie suivante.
- **FR-023**: Les joueurs DOIVENT toujours apparaître et réapparaître au point d'apparition du
  restaurant.
- **FR-024**: L'état de l'équipe (joueurs présents et statut de chacun) DOIT être visible par
  tous et mis à jour à chaque arrivée, départ ou changement de statut.
- **FR-025**: Le jeu DOIT fonctionner de 1 à 6 joueurs par serveur.

**Fin de partie**

- **FR-026**: Une partie DOIT se terminer par un seul résultat, victoire ou défaite, décidé
  uniquement par le serveur ; tout déclenchement postérieur au premier est ignoré.
- **FR-027**: La partie DOIT se terminer en défaite dès que tous les joueurs présents ont le
  statut « éliminé ».
- **FR-028**: À la fin de partie, tous les joueurs DOIVENT voir un écran de fin indiquant le
  résultat, la nuit atteinte et le compte à rebours avant la nouvelle partie.
- **FR-029**: À la fin de ce compte à rebours, une nouvelle partie DOIT démarrer
  automatiquement avec une nouvelle seed : état de partie réinitialisé, sessions remises « en
  vie », joueurs replacés au restaurant, reprise au compte à rebours de début.

**Actions des joueurs**

- **FR-030**: Toute action d'un joueur susceptible de modifier l'état de jeu DOIT passer par des
  échanges déclarés en un seul endroit ; le joueur envoie une intention (ex. « sonner la
  sonnette »), jamais un résultat.
- **FR-031**: Avant tout effet, le serveur DOIT valider chaque requête : forme et bornes des
  paramètres, existence de la cible, distance entre le joueur et la cible, phase autorisée,
  fréquence d'envoi.
- **FR-032**: Une requête refusée NE DOIT produire aucun effet et DOIT être journalisée avec le
  joueur, l'action et le motif ; les demandes au-delà de la limite de fréquence sont ignorées.
- **FR-033**: Le serveur NE DOIT jamais attendre la réponse d'un joueur pour faire avancer la
  logique de jeu.
- **FR-034**: Le socle DOIT inclure une interaction de référence, la sonnette du comptoir : un
  joueur à portée peut la sonner pendant le compte à rebours et toutes les phases de jeu (pas
  pendant l'écran de fin) ; tous les joueurs voient la sonnette réagir et une notification
  nommant le joueur ; un délai de réutilisation configurable s'applique.

**Interface**

- **FR-035**: L'interface DOIT afficher en permanence la phase en cours, le numéro de nuit sur le
  total (ex. « Nuit 3 / 7 »), le temps restant et l'état de l'équipe.
- **FR-036**: Un fil de notifications DOIT annoncer au minimum : le début de chaque phase,
  l'arrivée et le départ d'un joueur, la sonnette et la fin de partie.
- **FR-037**: Les textes affichés aux joueurs DOIVENT être en français et regroupés en un seul
  endroit.
- **FR-038**: L'interface DOIT rester lisible sur un écran d'ordinateur comme sur un écran de
  téléphone.

**Seed et reproductibilité**

- **FR-039**: Chaque partie DOIT avoir une seed, tirée au hasard par défaut et forçable par la
  configuration ; elle DOIT apparaître dans le journal au début de chaque partie.
- **FR-040**: Le socle DOIT fournir aux futurs systèmes des tirages aléatoires dérivés de la
  seed et d'un contexte nommé (ex. coordonnées d'une zone) : même seed et même contexte DOIVENT
  donner les mêmes tirages, quel que soit l'ordre des demandes.

**Visuels de secours**

- **FR-041**: Tout visuel issu d'une source externe DOIT être déclaré avec un remplaçant en
  formes simples ; si la source est indisponible, ou si le réglage « formes simples
  uniquement » est actif, le remplaçant DOIT être utilisé automatiquement, avec un
  avertissement.

**Outils de développement**

- **FR-042**: Des commandes de développement DOIVENT permettre de : passer à la phase suivante,
  activer ou désactiver le profil de test, déclencher une victoire ou une défaite, changer le
  statut d'un joueur (« en vie » / « éliminé »), afficher l'état de partie et la seed, afficher
  des tirages de contrôle pour un contexte donné, lancer la liste de contrôle des requêtes
  invalides et afficher le résultat de chacune.
- **FR-043**: Ces commandes DOIVENT être disponibles uniquement dans les sessions de test de
  l'éditeur ; dans un serveur publié, toute tentative DOIT être refusée et journalisée.

### Key Entities

- **Partie** : une partie du début à la fin ; seed, phase courante, numéro de nuit, nombre total
  de nuits, échéance de la phase en cours, résultat (en cours, victoire, défaite).
- **Phase** : étape de la partie (Attente, Compte à rebours, Jour, Nuit, Évasion, Fin) ; durée
  issue de la configuration, ou sans limite, et phase suivante.
- **Session joueur** : lien entre un joueur et la partie en cours ; statut (en vie, éliminé) et
  moment d'arrivée. Accueillera plus tard la santé, l'inventaire et les réapparitions.
- **Équipe** : ensemble des sessions présentes ; nombre de joueurs en vie. Déclenche la défaite
  quand tous les joueurs présents sont éliminés.
- **Réglage** : valeur de configuration appartenant à un domaine ; valeur par défaut, bornes,
  éventuelle valeur du profil de test.
- **Requête de joueur** : intention envoyée par un joueur (action, cible, paramètres) ; résultat
  accepté ou refusé, avec motif.
- **Point de référence** : emplacement nommé du monde de départ (point d'apparition, fenêtre du
  drive-thru, interphone, comptoir, plan de travail, friteuse, générateur, enseigne néon, centre
  de la zone de sécurité, bus), utilisé par les fonctionnalités futures.
- **Visuel catalogué** : élément visuel réutilisable ; source externe facultative et remplaçant
  en formes simples obligatoire.
- **Notification** : message de partie diffusé aux joueurs (type, texte, moment).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En suivant les instructions, un développeur passe d'une copie fraîche du dépôt à
  une session de test solo fonctionnelle en moins de 5 minutes (outils déjà installés), sans
  aucun placement manuel dans l'éditeur.
- **SC-002**: Au lancement d'une session, en solo comme à 6 joueurs, 100 % des joueurs
  apparaissent au restaurant et la sortie ne contient aucune erreur.
- **SC-003**: En test à plusieurs joueurs (2 à 6), tous affichent la même phase et le même temps
  restant, avec un écart d'au plus 1 seconde.
- **SC-004**: Un joueur qui rejoint en cours de partie voit la phase, la nuit et le temps
  restant corrects moins de 3 secondes après son apparition.
- **SC-005**: En profil de test, l'enchaînement du compte à rebours jusqu'à la phase d'évasion
  (7 jours et 7 nuits) se déroule sans intervention ni erreur en moins de 5 minutes.
- **SC-006**: 100 % des requêtes de la liste de contrôle (paramètre malformé, hors bornes, cible
  inexistante, joueur trop loin, phase interdite, envoi trop fréquent) sont refusées sans aucun
  effet sur l'état de jeu, chacune avec une ligne de journal nommant le joueur et le motif.
- **SC-007**: Après une fin de partie, une nouvelle partie démarre dans le délai configuré, à
  1 seconde près, avec une seed différente et tous les joueurs replacés au restaurant « en vie ».
- **SC-008**: Modifier un réglage demande d'intervenir à un seul endroit, et la nouvelle valeur
  s'applique dès la session de test suivante.
- **SC-009**: Deux parties lancées avec la même seed forcée produisent 100 % de tirages de
  contrôle identiques pour un même contexte.
- **SC-010**: Une session de 30 minutes à 6 joueurs se déroule sans erreur, sans gel perceptible
  aux changements de phase et sans ralentissement progressif.
- **SC-011**: L'échec simulé d'un système au démarrage laisse tous les autres systèmes
  opérationnels, et le message d'erreur nomme le système fautif.
- **SC-012**: Lors d'un playtest, chaque testeur sait dire en moins de 5 secondes, sans
  explication, la phase en cours, le numéro de nuit et le temps restant.
- **SC-013**: Pendant la synchronisation, une modification d'un fichier du dépôt apparaît dans
  Studio en moins de 2 secondes, sans aucune manipulation.

## Assumptions

- **Plateforme et outillage** : le jeu cible Roblox et se développe en Luau. Rojo est imposé par
  la constitution (principe IV) et son initialisation fait partie de ce socle : c'est pourquoi
  il est nommé explicitement dans cette spec. Rojo 7.7.0 est déjà installé sur le poste ; le
  choix du gestionnaire d'outils qui fixera sa version dans le dépôt (ex. Rokit) relève du
  plan, tout comme l'intégration éventuelle de selene (0.28.0, également installé).
- **Dépendances** : aucune fonctionnalité antérieure ; la spec s'appuie sur la constitution
  v1.0.0 et sur `TECH.md`.
- **Incrément 0 (pré-MVP)** : le socle ne contient pas encore de boucle de jeu jouable. Le
  critère « chaque incrément laisse le jeu jouable de bout en bout » (principe II) s'applique à
  partir du MVP ; le socle doit néanmoins être lançable et testable en solo et en multijoueur,
  sans erreur. Point à signaler dans le Constitution Check du plan.
- **Valeurs par défaut choisies** (ajustables dans la configuration) : compte à rebours de début
  de 15 s, délai avant nouvelle partie de 15 s, profil de test à 15 s par phase, phase
  d'évasion sans limite de temps (sa durée et sa fin seront définies par la fonctionnalité du
  bus).
- **Arrivée en cours de partie** : le joueur participe immédiatement comme joueur actif (pas de
  mode spectateur).
- **Redémarrage** : automatique à la fin du compte à rebours de fin, sans vote des joueurs.
- **Commandes de développement** : réservées aux sessions de test de l'éditeur ; aucun accès
  dans les serveurs publiés, même pour le propriétaire de la place.
- **Capacité** : la limite de 6 joueurs est un réglage de publication de la place ; les
  instructions expliquent comment la définir.
- **Langue** : textes en français, centralisés ; la traduction est hors périmètre.
- **Écrans** : ordinateur en priorité ; l'interface reste lisible sur téléphone, sans contrôles
  tactiles dédiés à ce stade.
- **Persistance** : aucune sauvegarde entre les sessions (pas de progression conservée).
- **Hors périmètre** (fonctionnalités suivantes) : éclairage, brouillard et ambiance sonore du
  jour et de la nuit ; génération de la forêt ; ressources, collecte, inventaire et stockage ;
  générateur, carburant et effet de la zone néon ; commandes, recettes et postes de cuisine
  (seuls leurs points de référence existent) ; ennemis ; santé, dégâts et réapparition
  limitée ; réparation du bus et vraie condition de victoire.
