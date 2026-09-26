# Feature Specification: Système de craft à l'établi

**Feature Branch**: `009-craft-etabli`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Système de craft à l'établi"

## Clarifications

### Session 2026-09-20

- Q: Comment un joueur choisit-il quelle recette fabriquer à l'établi quand plusieurs sont
  disponibles ? → A: Un panneau à l'établi liste toutes les recettes connues, leur coût, et si le
  joueur a de quoi les fabriquer (même idiome que le panneau de la boutique, `008`).

### Amendement 2026-09-25 — fabrication en deux phases

- Demande : la fabrication se fait en deux temps. Première phase : on choisit la recette. Seconde
  phase : un plan de travail affiche les ingrédients nécessaires, et le joueur doit les y déposer
  lui-même, soit en les sortant du sac (touche **G** près de l'établi, ce qui les ajoute à la
  recette), soit en glissant-déposant un objet directement sur l'établi.
- Ce flux **remplace** le déclenchement en un clic de la version initiale : FR-001, FR-002 et
  FR-009 sont précisés par FR-011 à FR-016 ci-dessous (un ingrédient posé sur l'établi quitte le
  sac ; fabriquer consomme ce qui est posé, plus l'inventaire directement).
- Décisions prises sans arbitrage explicite du demandeur, à confirmer : (a) le glisser-déposer est
  celui des objets du monde déjà saisissables à la souris (`004`), pas un glisser depuis une
  interface du sac, qui n'existe pas ; (b) changer de recette ou la quitter rend les ingrédients
  posés au sac, et est refusé si le sac n'a pas la place (rien ne se perd) ; (c) l'établi est
  personnel (un état par joueur), pas partagé entre coéquipiers.

### Amendement 2026-09-25 (2) — la fabrication produit de vrais objets

- Demande : créer un objet pour chacune des deux recettes ; la trousse de soins doit être
  consommée par le joueur (elle ne soigne plus à la fabrication).
- Fabriquer **ne soigne plus et ne ravitaille plus directement** : cela produit un objet
  (`Recipe.Result` : `HealKit` ou `FuelCanister`) qui rejoint le sac. Ce remplacement d'effet
  immédiat par un objet supplante les scénarios d'acceptation initiaux des User Stories 1 et 2
  ci-dessous et FR-003 à FR-005 (le bénéfice est désormais obtenu à l'usage, voir FR-017 à
  FR-021).
- Décisions prises sans arbitrage explicite du demandeur, à confirmer : (a) la trousse s'utilise
  avec la touche **H** ; (b) le bidon se verse au générateur, comme l'essence — touche G devant
  lui, ou son invite de proximité ; (c) chaque objet fabriqué occupe une place du sac.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fabriquer une trousse de soins de fortune (Priority: P1)

Un joueur qui a récolté des ressources se rend à l'établi et y fabrique une trousse de soins de
fortune, qui le soigne immédiatement. Aujourd'hui, aucune ressource récoltée ne permet de
restaurer la santé — l'établi leur donne cette utilité nouvelle.

**Why this priority**: c'est l'entrée qui prouve la boucle de craft elle-même (apporter des
ressources → les consommer → obtenir un bénéfice concret), tout en comblant un vrai manque du jeu
actuel (aucun moyen de se soigner en dehors d'une réapparition) — renforce directement l'axe
« tension nocturne ».

**Independent Test**: avec les ressources requises dans son sac et une santé entamée, se rendre à
l'établi, fabriquer la trousse de soins — la santé du joueur augmente immédiatement du montant
prévu et les ressources utilisées disparaissent de son sac.

**Acceptance Scenarios**:

1. **Given** un joueur possédant assez de chaque ressource requise et une santé inférieure au
   maximum, **When** il fabrique la trousse de soins à l'établi, **Then** sa santé augmente
   exactement du montant prévu (sans jamais dépasser son maximum) et les ressources sont déduites
   exactement des quantités de la recette.
2. **Given** un joueur ne possédant pas assez d'une ressource requise, **When** il tente de
   fabriquer la trousse, **Then** la fabrication est refusée, rien n'est déduit, et la ressource
   manquante lui est indiquée.
3. **Given** un joueur déjà à sa santé maximale, **When** il tente de fabriquer la trousse de
   soins, **Then** la fabrication est refusée (aucun bénéfice possible) et rien n'est déduit — pour
   ne jamais gaspiller des ressources récoltées sans le moindre effet.

---

### User Story 2 - Fabriquer un bidon de carburant de secours (Priority: P2)

Un joueur fabrique à l'établi un bidon de carburant de secours à partir de ressources récoltées,
qui alimente immédiatement la réserve partagée du générateur — sans avoir à s'y déplacer avec de
l'essence en main. Renforce la « tension nocturne » et la « coopération » : l'équipe peut désormais
anticiper une pénurie de carburant depuis n'importe quel point de récolte.

**Why this priority**: réutilise exactement le même mécanisme que US1 (risque de conception
minimal, purement une seconde recette), tout en ajoutant un second levier réel à la gestion du
carburant partagé — l'idée précise qu'une fonctionnalité précédente (boutique, `008`) avait dû
écarter faute de s'appliquer à un joueur individuel plutôt qu'à toute l'équipe.

**Independent Test**: avec les ressources requises en poche et le générateur pas encore à pleine
réserve, fabriquer le bidon à l'établi — le niveau de carburant du générateur augmente
immédiatement du montant prévu, et les ressources sont déduites du sac du joueur qui a fabriqué.

**Acceptance Scenarios**:

1. **Given** un générateur dont la réserve n'est pas pleine et un joueur possédant assez de chaque
   ressource requise, **When** il fabrique le bidon de carburant, **Then** la réserve du générateur
   augmente exactement du montant prévu (sans jamais dépasser sa capacité) et les ressources sont
   déduites du sac de ce joueur.
2. **Given** un générateur déjà à pleine réserve, **When** un joueur tente de fabriquer le bidon,
   **Then** la fabrication est refusée (aucun bénéfice possible) et rien n'est déduit.

---

### Edge Cases

- Que se passe-t-il si deux joueurs fabriquent au même établi au même instant ? Chacun est résolu
  indépendamment contre ses propres ressources personnelles — aucune file d'attente partagée n'est
  nécessaire, la ferraille et l'essence ne rejoignant jamais un stock commun.
- Fabrication tentée avec exactement la quantité minimale requise ? Réussit normalement, les
  compteurs concernés retombent à zéro.
- Fabrication tentée hors d'une partie active (avant le compte à rebours ou après la fin de la
  partie) ? Refusée : contrairement à la boutique (accessible à tout moment), l'établi est un lieu
  du monde qui suppose un personnage en jeu.
- Fabrication tentée sans personnage vivant (juste après une élimination, avant réapparition) ?
  Refusée, comme toute autre interaction du monde.
- Fabrication tentée trop loin de l'établi ? Refusée, comme toute autre interaction du monde
  (portée définie en configuration).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT permettre à un joueur de fabriquer une recette en interagissant avec
  un établi, en consommant exactement les quantités d'ingrédients que cette recette définit,
  prélevées sur les ressources que ce joueur porte sur lui.
- **FR-002**: Le système DOIT refuser la fabrication d'une recette si le joueur ne possède pas
  assez d'un des ingrédients requis, sans rien déduire.
- **FR-003**: Le système DOIT refuser une fabrication dont l'effet n'apporterait aucun bénéfice
  (santé déjà maximale pour la trousse de soins ; générateur déjà à pleine réserve pour le bidon de
  carburant), sans rien déduire.
- **FR-004**: La recette de soins DOIT restaurer la santé du joueur qui fabrique d'un montant fixe
  et configurable, sans jamais dépasser sa santé maximale.
- **FR-005**: La recette de carburant DOIT ajouter à la réserve partagée du générateur un montant
  fixe et configurable, sans jamais dépasser sa capacité.
- **FR-006**: La fabrication DOIT n'être possible que pendant une partie activement jouable (mêmes
  phases que les autres interactions du monde), jamais avant son début ni après sa fin.
- **FR-007**: La fabrication DOIT exiger que le joueur ait un personnage vivant présent à portée de
  l'établi, comme toute autre interaction du monde.
- **FR-008**: La liste des recettes et leurs coûts en ingrédients DOIVENT être des données, pas de
  la logique codée en dur, pour qu'une future recette s'ajoute sans modifier celles qui existent
  déjà.
- **FR-009**: Le système DOIT présenter à l'établi la liste de toutes les recettes connues, avec
  pour chacune son coût en ingrédients et si le joueur en a assez pour la fabriquer, afin qu'il
  choisisse laquelle fabriquer (clarification 2026-09-20).
- **FR-010**: Aucune fabrication NE DOIT dépendre d'une validation côté client : le serveur seul
  décide qu'un joueur possède assez de ressources, et seul lui accorde l'effet (santé, carburant) —
  un client NE DOIT jamais pouvoir s'attribuer directement l'un de ces effets.
- **FR-011** *(amendement 2026-09-25)*: Le système DOIT séparer la fabrication en deux phases : le
  joueur choisit d'abord une recette, puis dépose ses ingrédients sur le plan de travail avant de
  pouvoir fabriquer.
- **FR-012**: Le plan de travail DOIT afficher, pour la recette choisie, chaque ingrédient requis
  avec la quantité déjà posée et la quantité attendue, et refléter immédiatement chaque dépôt. Le
  bouton de fabrication DOIT dire pourquoi il n'agit pas (ingrédients manquants) : le serveur
  refuse en silence, un clic sans effet visible laisserait le joueur sans explication.
- **FR-013**: Lorsqu'un joueur proche de l'établi lâche un objet de son sac avec la touche G, et
  que sa recette attend encore cet objet, celui-ci DOIT être ajouté à la recette au lieu de tomber
  au sol. Un objet que la recette n'attend pas (ou plus) garde le comportement habituel du lâcher.
- **FR-014**: Un objet du monde relâché sur l'établi par glisser-déposer DOIT s'ajouter à la
  recette si elle l'attend encore, et disparaître du monde ; sinon il reste où il a été posé.
- **FR-015**: Un ingrédient posé sur l'établi DOIT quitter le sac (jamais présent aux deux
  endroits), et la fabrication DOIT consommer uniquement ce qui est posé, une fois la recette
  complète.
- **FR-016**: Changer de recette ou la quitter DOIT rendre au sac tous les ingrédients posés, en
  tout ou rien ; si le sac ne peut pas les reprendre, l'action DOIT être refusée sans rien
  déplacer. Ce qui est posé et non fabriqué est perdu à l'élimination et à chaque nouvelle partie,
  comme les ressources non déposées.

- **FR-017** *(amendement 2026-09-25 (2))*: Fabriquer une recette DOIT consommer les ingrédients
  posés sur l'établi et ajouter au sac du joueur un objet fabriqué (`HealKit`, `FuelCanister`), qui
  occupe une place du sac comme n'importe quelle ressource. Sans place libre, la fabrication DOIT
  être refusée sans rien consommer, et le joueur en être prévenu.
- **FR-018**: Un objet fabriqué DOIT se porter, se lâcher au sol (avec un visuel propre) et se
  ramasser comme une ressource ordinaire ; aucun nœud de forêt n'en génère jamais.
- **FR-019**: Le joueur DOIT pouvoir consommer une trousse de soins de son sac (touche H) : elle
  restaure la santé du montant configuré (`Craft.HealAmount`), sans dépasser le maximum, et
  disparaît du sac. À santé déjà pleine, l'usage DOIT être refusé, la trousse rester dans le sac et
  le joueur en être prévenu.
- **FR-020**: Un bidon de carburant DOIT pouvoir être versé au générateur (touche G devant lui, ou
  son invite de proximité) : il ajoute `Craft.FuelAmount` à la réserve, plafonné par sa capacité, et
  disparaît du sac. Il n'est accepté que si la réserve peut en absorber au moins une part.
- **FR-021**: Le nombre de trousses possédées DOIT être visible en permanence (rappel de la touche
  d'usage) dès que le sac en contient une.

### Key Entities

- **Recette d'établi** : un identifiant, une liste d'ingrédients (type de ressource récoltée et
  quantité requise), et l'effet qu'elle produit une fois fabriquée.
- **Effet de fabrication** : le bénéfice obtenu (montant de soin, ou montant de carburant ajouté),
  appliqué immédiatement et entièrement au moment de la fabrication — aucun objet fabriqué ne reste
  ensuite dans le sac du joueur.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un joueur possédant les ressources requises peut fabriquer un objet et en observer
  l'effet (santé ou carburant modifié) en moins de 10 secondes, sans quitter le flux de jeu.
- **SC-002**: 100 % des tentatives de fabrication à ressources insuffisantes sont refusées sans
  aucune perte de ressource.
- **SC-003**: 100 % des fabrications réussies déduisent exactement les quantités de la recette, ni
  plus ni moins.
- **SC-004**: 100 % des effets de soin ou de carburant restent dans leurs bornes respectives
  (jamais au-delà de la santé maximale ou de la capacité du générateur).
- **SC-005**: Au moins deux recettes distinctes sont disponibles dès cet incrément, donnant chacune
  une seconde utilité à des ressources récoltées (dont la ferraille, aujourd'hui réservée à la
  seule réparation du bus).

## Assumptions

- L'établi est un nouveau lieu physique du restaurant, atteint comme le générateur, le bus ou le
  plan de travail (interaction de proximité) — pas un menu accessible à tout moment comme la
  boutique : la demande initiale (« à l'établi ») situe explicitement cette fonctionnalité dans le
  monde, pas dans une interface hors-partie.
- Les ingrédients proviennent des ressources personnelles du joueur qui fabrique (son sac), jamais
  du stock partagé du restaurant — cohérent avec le fait que la ferraille et l'essence n'entrent
  déjà jamais dans ce stock aujourd'hui, et avec le patron déjà établi par le bus et le générateur
  (le joueur apporte ce qu'il porte jusqu'au poste).
- Chaque effet s'applique immédiatement et intégralement au moment de la fabrication : aucun objet
  fabriqué ne persiste ensuite dans le sac ou l'inventaire — garde le périmètre de cet incrément à
  « des ressources entrent, un bénéfice sort », en repoussant à plus tard l'idée d'un objet fabriqué
  qui se stockerait.
- Les deux recettes initiales (trousse de soins, bidon de carburant) sont indicatives ; leurs
  quantités d'ingrédients exactes et l'ampleur de leur effet relèvent de la configuration, pas de
  cette spec.
- Aucun délai de recharge ni limite de fabrications par partie au-delà de la disponibilité des
  ressources elles-mêmes — cohérent avec le reste du jeu, qui n'ajoute jamais d'attente artificielle
  au-delà de celle qu'impose déjà la récolte.
