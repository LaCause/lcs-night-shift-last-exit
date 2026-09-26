# Feature Specification: Boutique et persistance entre parties

**Feature Branch**: `008-boutique-persistance`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Boutique + persistance entre parties"

## Clarifications

### Session 2026-09-20

- Q: Quand un joueur possède plusieurs objets cosmétiques pour le même emplacement visuel (le
  sac, le bus, le comptoir), comment le jeu décide-t-il lequel est effectivement affiché ? → B:
  Un joueur peut posséder plusieurs objets pour le même emplacement et choisit lequel est actif
  via une interface d'équipement dédiée (nouvelle user story, voir US2 ci-dessous).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Acheter un objet cosmétique (Priority: P1)

Un joueur consulte la boutique, voit les objets cosmétiques disponibles avec leur prix en jetons
fidélité, et en achète un que son solde permet de payer. L'objet lui appartient désormais et reste
visible pour lui dans les parties suivantes.

**Why this priority**: C'est le socle transactionnel de toute la fonctionnalité — sans lui, rien
d'autre n'a de sens. Purement cosmétique, donc sans risque d'équilibrage du jeu : le plus sûr des
trois incréments à livrer en premier.

**Independent Test**: Avec un solde suffisant, ouvrir la boutique, acheter un objet cosmétique —
le solde diminue exactement du prix affiché, l'objet apparaît comme possédé, et reste visible pour
ce joueur après avoir rejoint une nouvelle partie.

**Acceptance Scenarios**:

1. **Given** un joueur dont le solde couvre le prix d'un objet cosmétique non possédé, **When** il
   confirme l'achat, **Then** son solde diminue exactement du prix affiché et l'objet devient
   possédé.
2. **Given** un joueur dont le solde ne couvre pas le prix d'un objet, **When** il tente de
   l'acheter, **Then** l'achat est refusé, son solde reste inchangé, et le refus lui est indiqué
   clairement.
3. **Given** un objet déjà possédé, **When** le joueur consulte la boutique, **Then** cet objet
   est signalé comme déjà possédé et ne peut pas être acheté une seconde fois.

---

### User Story 2 - Choisir son cosmétique actif parmi ceux possédés (Priority: P2)

Un joueur qui possède plusieurs objets cosmétiques pour le même emplacement visuel (par exemple
deux teintes de sac) choisit lequel des deux est effectivement affiché. Un objet fraîchement
acheté devient automatiquement l'objet actif de son emplacement ; le joueur peut ensuite revenir
à un autre objet déjà possédé du même emplacement, sans rien racheter.

**Why this priority**: Sans elle, la garantie de US1 (« un objet possédé est visible ») devient
ambiguë dès qu'un joueur possède deux objets du même emplacement — un trou réel de la version la
plus simple. Reste toutefois secondaire par rapport à l'avantage de départ, qui touche la boucle
de jeu elle-même plutôt que sa seule présentation.

**Independent Test**: Posséder deux cosmétiques du même emplacement, changer l'actif depuis
l'interface — c'est bien le nouvel objet choisi qui s'affiche, jamais les deux à la fois ni
l'ancien.

**Acceptance Scenarios**:

1. **Given** un joueur achète un premier cosmétique pour un emplacement donné, **When** l'achat
   est confirmé, **Then** cet objet devient automatiquement l'objet actif de cet emplacement.
2. **Given** un joueur possède déjà un objet actif pour un emplacement, **When** il achète un
   second objet du même emplacement, **Then** ce nouvel objet devient l'actif à la place du
   précédent.
3. **Given** un joueur possède plusieurs objets pour un même emplacement, **When** il sélectionne
   depuis l'interface un objet déjà possédé autre que l'actif courant, **Then** cet objet devient
   l'actif, sans nouvel achat.

---

### User Story 3 - Démarrer avec un avantage acheté (Priority: P3)

Un joueur achète un avantage de départ (par exemple un sac plus grand ou une réserve de carburant
de départ). Dès la partie suivante, cet avantage s'applique automatiquement, sans action
supplémentaire de sa part.

**Why this priority**: C'est ce qui relie la boutique à la boucle de jeu elle-même plutôt qu'à la
simple décoration — l'axe « rejouabilité » explicitement visé par la demande initiale. Vient après
US1 et US2 car elle réutilise exactement le même mécanisme d'achat, en y ajoutant un effet en jeu.

**Independent Test**: Acheter un avantage de départ, puis rejoindre une nouvelle partie — la
condition de départ modifiée (capacité du sac, réserve de carburant) est visible dès le début de
cette partie, sans que le joueur n'ait rien d'autre à faire.

**Acceptance Scenarios**:

1. **Given** un joueur qui vient d'acheter un avantage de départ, **When** une nouvelle partie
   démarre pour lui, **Then** l'effet de cet avantage est déjà actif dès le début de la partie.
2. **Given** un joueur possédant plusieurs avantages de départ, **When** une nouvelle partie
   démarre, **Then** tous les avantages possédés s'appliquent simultanément, sans conflit ni
   sélection à faire.

---

### User Story 4 - Conserver ses achats malgré un redémarrage du serveur (Priority: P4)

Les objets achetés par un joueur (cosmétiques et avantages de départ), ainsi que l'objet actif de
chaque emplacement cosmétique, restent associés à ce joueur même après un redémarrage complet du
serveur, exactement comme son solde de jetons.

**Why this priority**: Une boutique dont les achats disparaissent au premier redémarrage serait
inutilisable en production — mais c'est un filet de robustesse, pas une mécanique de jeu ; elle
vient logiquement en dernier, une fois US1, US2 et US3 fonctionnelles.

**Independent Test**: Acheter un objet, choisir un objet actif différent de celui acheté en
dernier, noter le solde restant, arrêter complètement le serveur de test puis le relancer,
rejoindre en tant que le même joueur — l'objet reste possédé, l'objet actif choisi est toujours
celui-là (pas le dernier acheté), et le solde affiché est identique à celui noté avant l'arrêt.

**Acceptance Scenarios**:

1. **Given** un joueur ayant acheté au moins un objet et choisi un objet actif, **When** le
   serveur redémarre complètement, **Then** cet objet reste possédé et l'objet actif choisi reste
   le même pour ce joueur à sa reconnexion.
2. **Given** une tentative d'écriture de sauvegarde en échec juste après un achat, **When** la
   partie en cours continue, **Then** l'objet reste possédé pour la session en cours (rien n'est
   perdu localement), et la sauvegarde est retentée en arrière-plan.

---

### Edge Cases

- Que se passe-t-il si le solde est juste insuffisant pour un objet (par exemple 1 jeton
  manquant) ? L'achat est refusé sans aucun débit, avec une indication claire du manque.
- Que se passe-t-il si un joueur tente d'acheter deux objets coup sur coup alors que son solde ne
  couvre que le premier ? Seul le premier achat traité par le serveur réussit ; le second échoue
  faute de solde suffisant à cet instant — jamais de double-dépense.
- Que se passe-t-il si un joueur achète un avantage de départ en pleine partie, avant la fin de
  celle-ci ? L'achat est accepté immédiatement (aucune raison de l'en empêcher), mais l'avantage
  ne change rien à la partie en cours — il ne s'applique qu'à partir de la prochaine.
- Que se passe-t-il si l'écriture de sauvegarde d'un achat échoue juste après ? L'objet reste
  possédé en mémoire pour la session en cours (le joueur n'est jamais pénalisé par un échec
  d'infrastructure), et l'écriture est retentée en arrière-plan selon la même politique que la
  monnaie (`006-monnaie-jetons-fidelite`).
- Que se passe-t-il si un joueur sans aucun jeton consulte la boutique ? Il voit le catalogue
  complet avec les prix, mais aucun achat n'est possible tant que son solde est insuffisant.
- Que se passe-t-il si un joueur sélectionne comme actif un objet déjà actif pour son
  emplacement ? Aucun effet, l'objet reste actif.
- Un emplacement cosmétique peut-il n'avoir aucun objet actif ? Oui, tant qu'aucun objet de cet
  emplacement n'a été acheté — l'apparence par défaut du jeu s'applique.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT permettre à un joueur de consulter un catalogue d'objets de
  boutique (nom, catégorie, prix en jetons, description) depuis l'interface du jeu, à tout moment
  qu'il soit ou non en partie.
- **FR-002**: Le système DOIT permettre l'achat d'un objet non encore possédé si le solde du
  joueur couvre son prix, en déduisant exactement ce prix et en marquant l'objet comme possédé.
- **FR-003**: Le système DOIT refuser tout achat dont le prix dépasse le solde actuel du joueur,
  sans déduction ni changement de possession.
- **FR-004**: Le système NE DOIT PAS permettre l'achat d'un objet déjà possédé par ce joueur.
- **FR-005**: Chaque objet cosmétique DOIT appartenir à un emplacement (sac, bus, comptoir, …) ;
  au plus un objet possédé par emplacement et par joueur DOIT être affiché à la fois — jamais
  plusieurs simultanément pour le même emplacement.
- **FR-006**: L'achat d'un objet cosmétique DOIT le rendre automatiquement actif pour son
  emplacement, remplaçant l'objet actif précédent de cet emplacement le cas échéant.
- **FR-007**: Le système DOIT permettre à un joueur de changer l'objet actif d'un emplacement
  parmi tous les objets de cet emplacement qu'il possède déjà, sans nouvel achat.
- **FR-008**: Un avantage de départ possédé DOIT s'appliquer automatiquement au début de chaque
  partie future de ce joueur, sans sélection ni action supplémentaire.
- **FR-009**: Les objets cosmétiques DOIVENT rester purement visuels — ils NE DOIVENT avoir
  aucun effet sur les ressources, la durée, les capacités ou toute autre mécanique de jeu.
- **FR-010**: Les avantages de départ DOIVENT se limiter à modifier les conditions de tout début
  de partie (par exemple une capacité ou une réserve initiale) — ils NE DOIVENT fournir aucun
  effet exploitable en cours de partie au-delà de cette condition de départ.
- **FR-011**: Les objets possédés par un joueur, ainsi que l'objet actif de chaque emplacement
  cosmétique, DOIVENT persister au-delà de la partie en cours, et au-delà d'un redémarrage
  complet du serveur, selon les mêmes garanties de persistance que le solde de jetons
  (`006-monnaie-jetons-fidelite`).
- **FR-012**: Le solde du joueur, la validation des achats, la liste des objets possédés et
  l'objet actif de chaque emplacement DOIVENT être entièrement déterminés côté serveur — un
  client NE DOIT jamais pouvoir s'attribuer un objet, changer l'objet actif d'un emplacement sans
  le posséder, ou modifier son propre solde directement.
- **FR-013**: Un échec de sauvegarde d'un achat ou d'un changement d'objet actif NE DOIT ni
  annuler l'état déjà accordé en mémoire pour la session en cours, ni bloquer le reste de la
  partie.

### Key Entities

- **Objet de boutique** : un identifiant, un nom, un emplacement (pour un cosmétique) ou une
  catégorie « avantage de départ », un prix en jetons, une description, et pour un avantage de
  départ, l'effet qu'il applique en début de partie.
- **Objet possédé** : l'association entre un joueur et un objet de boutique qu'il a acheté,
  persistée au même titre que son solde de jetons.
- **Objet actif** : pour un joueur et un emplacement cosmétique donnés, l'objet possédé
  actuellement affiché parmi tous ceux que ce joueur possède pour cet emplacement ; persistée au
  même titre que la possession elle-même.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un joueur peut consulter la boutique et finaliser un achat valide en moins de 10
  secondes, sans quitter le flux de jeu.
- **SC-002**: 100 % des achats valides déduisent exactement le prix affiché et marquent l'objet
  comme possédé, sans exception.
- **SC-003**: 100 % des tentatives d'achat à solde insuffisant sont refusées sans aucun débit.
- **SC-004**: Un avantage de départ acheté s'applique automatiquement à 100 % des parties
  suivantes de ce joueur, sans action supplémentaire.
- **SC-005**: Les objets possédés, l'objet actif de chaque emplacement, et le solde restant
  survivent à un redémarrage complet du serveur, à l'identique de ce qui est déjà garanti pour la
  monnaie seule.
- **SC-006**: Aucune possession d'objet n'est jamais observée sans que le débit correspondant
  n'ait eu lieu (intégrité achat/débit garantie côté serveur, à 100 %).
- **SC-007**: À tout instant, au plus un objet actif est affiché par emplacement et par joueur,
  jamais deux simultanément, quel que soit le nombre d'objets possédés pour cet emplacement.

## Assumptions

- La boutique est accessible depuis l'interface du jeu à tout moment (en partie ou non), sans
  lieu dédié dans le monde — il n'existe aujourd'hui aucun lobby entre les parties, et exiger un
  nouveau point de référence physique ajouterait une complexité que la demande initiale
  n'exigeait pas.
- Les objets cosmétiques sont personnels : visibles uniquement par le joueur qui les a achetés
  dans cette version. Un décor de restaurant ou une peinture de bus partagée et visible par toute
  l'équipe poserait un problème de résolution de conflit distinct (quel choix l'emporte si
  plusieurs joueurs choisissent des décors différents pour le même restaurant partagé) hors du
  périmètre de cette fonctionnalité ; un partage visuel entre coéquipiers pourra être une
  fonctionnalité séparée, ultérieure.
- Chaque avantage de départ est un déblocage permanent : une fois acheté, il s'applique
  automatiquement à toutes les parties suivantes sans qu'aucune sélection de « équipement de
  départ » ne soit nécessaire à chaque partie (contrairement aux cosmétiques, qui ont désormais
  leur propre notion d'objet actif par emplacement — clarification 2026-09-20).
- Catalogue initial indicatif (les valeurs précises et la liste complète relèvent de la
  configuration, pas de cette spec) — chaque emplacement cosmétique propose désormais plusieurs
  objets, puisque le mécanisme d'objet actif (US2) permet d'en posséder plusieurs par emplacement :
  - Cosmétiques : plusieurs teintes de sac de portage, plusieurs peintures de bus, plusieurs
    éclairages de comptoir.
  - Avantages de départ : capacité de sac de départ agrandie, réserve de carburant de départ.
- Les achats réutilisent le mécanisme de sauvegarde à distance déjà en place pour la monnaie
  (`006-monnaie-jetons-fidelite`) : mêmes garanties de robustesse, mêmes limites déjà connues en
  environnement de test.
- Un joueur qui rejoint pour la première fois n'a aucun objet possédé ; le solde de départ suit
  les règles déjà établies par `006-monnaie-jetons-fidelite`.
