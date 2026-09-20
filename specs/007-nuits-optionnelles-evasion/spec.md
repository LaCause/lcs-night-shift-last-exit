# Feature Specification: Nuits optionnelles après réparation du bus

**Feature Branch**: `007-nuits-optionnelles-evasion`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Nuits optionnelles après réparation du bus (push-your-luck). Une fois le bus réparé, les joueurs peuvent soit partir immédiatement (fin de partie en victoire), soit choisir de rester une nuit de plus pour gagner un bonus de jetons croissant, au risque d'une nuit plus difficile. Ça remplace le départ automatique dès le seuil de nuits minimum atteint par un vrai choix à chaque nuit supplémentaire."

## Clarifications

### Session 2026-09-20

- Q: Le risque des nuits supplémentaires doit-il réellement augmenter (nécessitant d'introduire
  une forme de scaling de difficulté par nuit, inexistante aujourd'hui), ou le risque reste-t-il
  celui, constant, d'une nuit normale du jeu ? → A: Risque croissant, mais scopé uniquement aux
  nuits au-delà du seuil minimum — les nuits normales nécessaires pour atteindre ce seuil ne sont
  pas modifiées par cette fonctionnalité.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Partir dès que possible (Priority: P1)

Une fois le nombre minimum de nuits survécu et le bus réparé, l'équipe peut choisir de partir
immédiatement et remporter la victoire, comme c'est déjà le cas aujourd'hui — mais ce départ
devient un choix explicite plutôt qu'une simple action disponible sans mise en scène.

**Why this priority**: C'est le comportement de référence, déjà en place (`003-bus-evasion`) ;
il doit continuer à fonctionner sans régression avant d'ajouter la possibilité de rester.

**Independent Test**: Survivre au nombre minimum de nuits, réparer le bus, puis quitter — la
partie se termine en victoire avec la récompense correspondant aux nuits réellement survécues,
exactement comme avant cette fonctionnalité.

**Acceptance Scenarios**:

1. **Given** l'équipe a survécu au nombre minimum de nuits et le bus est réparé, **When** elle
   se présente au bus, **Then** le jeu lui propose explicitement de partir maintenant ou de
   rester une nuit de plus.
2. **Given** ce choix est proposé, **When** l'équipe choisit de partir, **Then** la partie se
   termine en victoire immédiatement, sans nuit supplémentaire.

---

### User Story 2 - Rester pour une nuit de plus (Priority: P2)

Au lieu de partir, l'équipe peut choisir de rester une nuit supplémentaire pour augmenter sa
récompense finale, en acceptant un danger strictement supérieur à celui de la nuit précédente.
Une fois cette nuit survécue, le même choix se représente : repartir maintenant ou tenter encore
une nuit, plus dangereuse que la précédente.

**Why this priority**: C'est la mécanique de « push your luck » qui donne son sens à
« s'échapper avec le plus de nuits possible » — sans elle, le jeu s'arrête mécaniquement dès le
seuil minimum atteint.

**Independent Test**: Depuis l'écran de choix, sélectionner « rester » — une nuit
supplémentaire démarre normalement (mêmes phases, mêmes menaces qu'une nuit classique), puis le
même choix (partir / rester) est de nouveau proposé une fois cette nuit terminée.

**Acceptance Scenarios**:

1. **Given** le choix partir/rester est proposé, **When** l'équipe choisit de rester, **Then**
   une nouvelle nuit démarre comme n'importe quelle nuit du jeu (jour puis nuit, mêmes
   mécaniques existantes), mais strictement plus dangereuse que la nuit précédente.
2. **Given** l'équipe a survécu à une nuit supplémentaire, **When** cette nuit se termine,
   **Then** le choix partir/rester est de nouveau proposé, sans limite du nombre de fois où il
   peut être renouvelé, et la nuit suivante (si acceptée) sera encore plus dangereuse.
3. **Given** l'équipe enchaîne plusieurs nuits supplémentaires, **When** elle part finalement,
   **Then** la récompense obtenue est strictement supérieure à celle qu'elle aurait eue en
   partant plus tôt.

---

### User Story 3 - Conserver ses gains malgré l'échec d'une nuit supplémentaire (Priority: P3)

Si l'équipe choisit de tenter sa chance et échoue (élimination totale) pendant une nuit
supplémentaire, elle ne doit perdre que la récompense potentielle de cette tentative — pas les
gains déjà acquis lors des nuits précédentes.

**Why this priority**: Sans cette garantie, le risque de la mécanique de « push your luck »
serait disproportionné et découragerait toute tentative ; elle s'appuie directement sur la
persistance déjà garantie par `006-monnaie-jetons-fidelite`.

**Independent Test**: Choisir de rester, puis provoquer l'élimination de toute l'équipe pendant
cette nuit supplémentaire — la partie se termine en défaite, et le solde de jetons affiché reste
celui accumulé par les nuits déjà terminées, sans retrait ni bonus d'évasion.

**Acceptance Scenarios**:

1. **Given** l'équipe a choisi de rester pour une nuit supplémentaire, **When** elle est
   éliminée pendant cette nuit, **Then** la partie se termine en défaite et aucun bonus
   d'évasion n'est versé.
2. **Given** cette défaite, **When** le solde de jetons est consulté ensuite, **Then** il
   correspond exactement à ce qui avait été acquis avant la nuit supplémentaire tentée, sans
   perte.

---

### Edge Cases

- Que se passe-t-il si le bus est réparé avant que le nombre minimum de nuits soit atteint ?
  Rien ne se passe de plus qu'aujourd'hui : le départ (`DepartBus`) est déjà restreint à la phase
  Évasion, qui ne commence qu'une fois le seuil minimum atteint — il n'existe donc pas de départ
  anticipé à préserver, avec ou sans cette fonctionnalité (correction post-implémentation : voir
  `quickstart.md`, le comportement supposé initialement était inexact).
- Que se passe-t-il si personne ne se présente au bus une fois le choix disponible ? L'équipe
  reste en attente indéfiniment, comme le comportement actuel une fois le seuil de nuits
  atteint — aucun départ ni aucune nuit supplémentaire n'est forcé.
- Que se passe-t-il si un joueur rejoint la partie pendant qu'elle enchaîne des nuits
  supplémentaires ? Il profite du même choix aux décisions suivantes, comme n'importe quel
  joueur présent pour une nuit ou un départ classique aujourd'hui.
- Que se passe-t-il si l'équipe choisit de rester, puis qu'un joueur se déconnecte avant que la
  nuit supplémentaire démarre ? Les mêmes règles de présence et de disponibilité que pour un
  départ aujourd'hui s'appliquent (aucune règle nouvelle introduite par cette fonctionnalité).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Une fois le nombre minimum de nuits survécu et le bus réparé, le système DOIT
  proposer explicitement à l'équipe un choix entre partir immédiatement et rester une nuit de
  plus, plutôt que de laisser le départ comme seule issue implicite.
- **FR-002**: Choisir de partir DOIT déclencher la victoire immédiatement, avec exactement le
  comportement et la récompense qu'un départ produit aujourd'hui pour le nombre de nuits
  réellement survécues.
- **FR-003**: Choisir de rester DOIT démarrer une nuit supplémentaire avec les mêmes phases que
  n'importe quelle nuit du jeu (jour puis nuit).
- **FR-004**: À l'issue de chaque nuit supplémentaire survécue, le système DOIT proposer à
  nouveau le même choix (partir / rester), sans limite du nombre de fois où il peut être
  renouvelé.
- **FR-005**: Le système DOIT garantir qu'une équipe partant après une ou plusieurs nuits
  supplémentaires reçoit une récompense strictement supérieure à celle qu'elle aurait reçue en
  partant plus tôt.
- **FR-006**: Si l'équipe est éliminée pendant une nuit supplémentaire, la partie DOIT se
  terminer en défaite exactement comme aujourd'hui (aucun bonus d'évasion versé), sans annuler
  les gains déjà acquis lors des nuits précédentes.
- **FR-007**: Le choix partir/rester DOIT rester soumis aux mêmes conditions de présence
  d'équipe (joueurs vivants, à portée du bus) que le départ actuel.
- **FR-008**: Le départ (`DepartBus`) DOIT rester restreint à la phase Évasion exactement comme
  aujourd'hui — cette fonctionnalité ne doit ni l'étendre à d'autres phases, ni introduire de
  départ possible avant le seuil minimum de nuits (qui n'existe pas aujourd'hui : correction
  post-implémentation, voir `quickstart.md`).
- **FR-009**: L'interface DOIT indiquer clairement, au moment du choix, que rester est possible
  et qu'un bonus supplémentaire est en jeu, sans obliger l'équipe à deviner cette option.
- **FR-010**: Chaque nuit supplémentaire au-delà du seuil minimum DOIT être strictement plus
  dangereuse que la précédente (davantage d'ennemis, ennemis plus redoutables, ou combinaison
  des deux — le mécanisme précis relève du plan, pas de cette spec).
- **FR-011**: Le niveau de danger des nuits nécessaires pour atteindre le seuil minimum NE DOIT
  PAS être modifié par cette fonctionnalité — seules les nuits situées au-delà de ce seuil
  deviennent progressivement plus dangereuses.

### Key Entities

- **Choix d'évasion** : représente si l'équipe fait actuellement face à la décision
  partir/rester (disponible dès que le seuil minimum de nuits est atteint et le bus réparé) ou
  si elle est engagée dans une nuit supplémentaire déjà en cours.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Une équipe ayant atteint le seuil minimum de nuits avec le bus réparé peut partir
  immédiatement, avec le même résultat qu'aujourd'hui, sans aucune régression.
- **SC-002**: Une équipe qui enchaîne des nuits supplémentaires obtient, à chaque fois qu'elle
  finit par partir, une récompense strictement supérieure à celle d'un départ plus précoce dans
  la même partie.
- **SC-003**: Le choix partir/rester est renouvelé après 100 % des nuits supplémentaires
  survécues, sans plafond imposé par la fonctionnalité elle-même.
- **SC-004**: Une défaite survenue pendant une nuit supplémentaire ne retire jamais les gains
  acquis lors des nuits précédentes.
- **SC-005**: Le départ (`DepartBus`) reste restreint à la phase Évasion, exactement comme avant
  l'introduction de cette fonctionnalité — aucune régression sur cette restriction déjà existante.
- **SC-006**: Chaque nuit supplémentaire mesurée est strictement plus dangereuse que la
  précédente (davantage d'ennemis rencontrés, ou ennemis individuellement plus dangereux), sans
  qu'aucune nuit nécessaire pour atteindre le seuil minimum ne soit affectée par cette montée en
  danger.

## Assumptions

- Le départ (`DepartBus`) est déjà restreint à la phase Évasion depuis `003-bus-evasion`
  (déclaration `phases = { "Escape" }` dans `Remotes.luau`) : il n'existe donc pas de départ
  anticipé avant le seuil minimum à préserver. Ce point avait été supposé à tort à l'écriture
  initiale de cette spec (une lecture du gestionnaire `BusService` seul, sans vérifier la
  déclaration séparée de `Remotes.luau`, laissait croire qu'aucune restriction de phase
  n'existait) — corrigé après l'avoir constaté en direct pendant l'implémentation
  (`quickstart.md`).
- La décision partir/rester suit les mêmes règles de présence d'équipe que le départ actuel
  (n'importe quel joueur présent et à portée peut déclencher le choix pour toute l'équipe) ; il
  n'existe aujourd'hui aucun système de vote dans le jeu, et cette fonctionnalité n'en introduit
  pas.
- Le scaling de difficulté des nuits supplémentaires (FR-010) est une nouveauté introduite par
  cette fonctionnalité, scopée aux seules nuits au-delà du seuil minimum ; aucun système de
  difficulté progressive n'existe aujourd'hui ailleurs dans le jeu (les nuits normales n'ont
  actuellement aucune variation de danger selon leur numéro), et cette fonctionnalité ne comble
  pas cette absence pour les nuits normales — seulement pour les nuits optionnelles qu'elle
  introduit.
- La récompense croissante réutilise la progression déjà en place dans
  `006-monnaie-jetons-fidelite` (gain nocturne croissant par nuit, bonus d'évasion proportionnel
  au nombre total de nuits survécues) ; cette fonctionnalité n'introduit aucune nouvelle
  mécanique de monnaie, seulement la possibilité de prolonger la partie pour en bénéficier
  davantage.
- Aucun plafond du nombre de nuits supplémentaires n'est imposé par défaut.
