# Feature Specification: Monnaie de base, gain par nuit et bonus d'évasion

**Feature Branch**: `006-monnaie-jetons-fidelite`

**Created**: 2026-09-20

**Status**: Draft

**Input**: User description: "Monnaie de base + gain par nuit + bonus d'évasion. Il faut que si
le joueur meurt son nombre de jour soit persisté mais sans bonus d'évasion par exemple"

## Clarifications

### Session 2026-09-20

- Q: La monnaie doit-elle survivre à un redémarrage complet du serveur (persistance durable,
  façon « compte joueur »), ou seulement rester intacte tant que le serveur de partie en cours
  reste actif ? → A: Persistance durable, façon compte joueur — survit à un redémarrage du
  serveur, à une déconnexion prolongée, à un changement de serveur.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gagner de la monnaie en survivant (Priority: P1)

Un joueur qui termine une nuit voit son solde de « Jetons fidélité » augmenter. Plus il tient de
nuits dans la même partie, plus le gain de chaque nuit supplémentaire est élevé : rester plus
longtemps rapporte davantage, nuit après nuit.

**Why this priority**: c'est le cœur de la demande — sans ce gain de base, rien d'autre dans
cette fonctionnalité n'a de sens. C'est aussi la tranche la plus petite qui reste testable et
utile seule.

**Independent Test**: lancer une partie, survivre à plusieurs nuits consécutives, et constater
que le solde de monnaie affiché augmente à la fin de chaque nuit, d'un montant plus élevé que la
nuit précédente.

**Acceptance Scenarios**:

1. **Given** un joueur qui vient de terminer sa toute première nuit, **When** la nuit se termine,
   **Then** son solde de monnaie augmente d'un montant strictement positif.
2. **Given** un joueur qui a déjà survécu à plusieurs nuits dans la même partie, **When** il en
   termine une nouvelle, **Then** le montant crédité pour cette nuit est supérieur à celui crédité
   pour une nuit plus précoce de la même partie.
3. **Given** une partie à plusieurs joueurs, **When** une nuit se termine pour l'équipe, **Then**
   chaque joueur présent depuis le début de cette nuit reçoit son propre gain, indépendamment des
   autres.
4. **Given** un joueur qui rejoint la partie après qu'une ou plusieurs nuits soient déjà passées,
   **When** on regarde son solde, **Then** il n'a reçu aucun gain pour les nuits qu'il n'a pas
   personnellement vécues.

---

### User Story 2 - Bonus au moment de l'évasion (Priority: P2)

Quand l'équipe réussit son évasion (le bus réparé quitte le restaurant), chaque joueur encore de
la partie à ce moment reçoit, en plus de ce qu'il a déjà accumulé nuit après nuit, un bonus
supplémentaire qui dépend du nombre de nuits survécues pendant cette partie.

**Why this priority**: donne un sens fort à l'objectif « s'échapper avec le plus de nuits
possible » — sans ce bonus, rien ne distingue une évasion réussie d'un simple abandon en cours de
route du point de vue de la monnaie.

**Independent Test**: mener une partie jusqu'à l'évasion réussie, et constater qu'un montant
supplémentaire, distinct du cumul des gains nocturnes, est crédité au moment précis du départ du
bus.

**Acceptance Scenarios**:

1. **Given** une équipe qui vient de réussir son évasion, **When** le bus part, **Then** chaque
   joueur présent reçoit un bonus, distinct et additionnel par rapport à son solde déjà accumulé.
2. **Given** deux parties où l'équipe survit à un nombre de nuits différent avant de s'évader,
   **When** on compare les deux bonus d'évasion obtenus, **Then** la partie qui a duré le plus de
   nuits verse le bonus le plus élevé.
3. **Given** un joueur temporairement éliminé (en attente de réapparition) au moment où l'équipe
   s'évade, **When** le bus part, **Then** il reçoit quand même le bonus d'évasion : il fait
   toujours partie de l'équipe victorieuse à cet instant.

---

### User Story 3 - Conserver ses gains malgré un échec (Priority: P3)

Si la partie se termine sans évasion réussie (l'équipe est éliminée, ou le joueur quitte avant la
fin), le joueur ne perd pas ce qu'il a déjà accumulé nuit après nuit : ce montant reste acquis
pour la suite. Seul le bonus d'évasion, qui récompense une évasion effective, ne lui est pas versé.

**Why this priority**: c'est la garantie explicitement demandée qui rend le système juste — un
échec ne doit pas effacer une progression réelle, seulement priver de la récompense propre à la
réussite.

**Independent Test**: mener une partie jusqu'à la défaite de l'équipe (ou quitter volontairement
avant la fin), puis constater dans une partie suivante que le solde du joueur contient bien les
gains des nuits qu'il a terminées, et rien de plus.

**Acceptance Scenarios**:

1. **Given** un joueur qui a terminé deux nuits puis dont l'équipe est éliminée à la troisième,
   **When** la partie se termine, **Then** son solde conserve les gains des deux nuits terminées
   et aucun bonus d'évasion n'est crédité.
2. **Given** un joueur qui quitte la partie volontairement après avoir terminé une nuit,
   **When** il rejoint une partie ultérieure, **Then** son solde reflète toujours le gain de la
   nuit qu'il a terminée avant de partir.
3. **Given** un joueur dont la nuit en cours n'est pas encore terminée au moment de la défaite de
   l'équipe, **When** la partie se termine, **Then** cette nuit inachevée ne rapporte aucun gain.

---

### Edge Cases

- Que se passe-t-il si un joueur se déconnecte pendant une nuit non terminée ? Cette nuit ne
  rapporte aucun gain ; les nuits déjà terminées avant sa déconnexion restent acquises.
- Que se passe-t-il si toute l'équipe est éliminée avant la fin d'une nuit ? Les gains des nuits
  déjà terminées sont conservés, la nuit en cours ne rapporte rien, aucun bonus d'évasion n'est
  versé.
- Que se passe-t-il si un joueur est en attente de réapparition (temporairement éliminé, pas
  définitivement hors jeu) au moment où l'équipe réussit son évasion ? Il reçoit quand même le
  bonus : la réapparition est une mécanique existante, pas un échec de partie.
- Que se passe-t-il si l'enregistrement du solde d'un joueur échoue temporairement au moment
  critique (fin de nuit ou évasion) ? La partie continue normalement pour tout le monde ; le
  système doit retenter l'enregistrement plutôt que de perdre silencieusement le gain.
- Que se passe-t-il si un joueur rejoint une partie déjà commencée ? Il ne reçoit de gains qu'à
  partir des nuits qu'il vit réellement à partir de son arrivée, jamais rétroactivement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT attribuer à chaque joueur un solde individuel de monnaie (« Jetons
  fidélité »), consultable par le joueur à tout moment pendant la partie.
- **FR-002**: Le système DOIT créditer un gain au solde de chaque joueur à la fin de chaque nuit
  qu'il a terminée en étant présent dans la partie depuis le début de cette nuit.
- **FR-003**: Le montant du gain nocturne DOIT augmenter avec le numéro de la nuit au sein d'une
  même partie : une nuit plus tardive rapporte davantage qu'une nuit précoce.
- **FR-004**: Le système DOIT créditer, au moment où l'équipe réussit son évasion, un bonus
  supplémentaire distinct des gains nocturnes, à chaque joueur présent dans la partie à cet
  instant.
- **FR-005**: Le montant du bonus d'évasion DOIT dépendre du nombre de nuits survécues pendant
  cette partie : plus la partie a duré, plus le bonus est élevé.
- **FR-006**: Le système NE DOIT PAS créditer le bonus d'évasion si la partie se termine sans
  évasion réussie, quelle qu'en soit la raison (défaite de l'équipe, déconnexion du joueur avant
  la fin).
- **FR-007**: Les gains nocturnes déjà crédités à un joueur DOIVENT rester acquis au-delà de la
  fin de la partie où ils ont été obtenus, y compris en cas de défaite ou de déconnexion.
- **FR-008**: Le solde de monnaie d'un joueur DOIT être retrouvé identique à ce qu'il était
  lorsqu'il rejoint une partie ultérieure, y compris après une interruption complète du serveur.
- **FR-009**: Si l'enregistrement du solde échoue temporairement, le système DOIT retenter
  l'opération sans interrompre ni dégrader le reste de la partie pour personne.
- **FR-010**: Un joueur qui rejoint une partie déjà commencée NE DOIT PAS recevoir de gain pour
  les nuits terminées avant son arrivée.

### Key Entities

- **Solde de monnaie du joueur** : quantité de Jetons fidélité possédée par un joueur ; propre à
  chaque joueur, existe indépendamment d'une partie précise et survit à sa fin.
- **Gain nocturne** : montant crédité à un joueur à la fin d'une nuit qu'il a terminée ; dépend du
  numéro de cette nuit au sein de la partie en cours.
- **Bonus d'évasion** : montant crédité une seule fois par partie réussie, à chaque joueur présent
  au moment de l'évasion ; dépend du nombre total de nuits survécues pendant cette partie.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : après chaque nuit terminée, le joueur voit son solde de monnaie augmenter avant
  que la nuit suivante ne commence.
- **SC-002** : dans une même partie, le gain de chaque nuit est strictement supérieur au gain de
  la nuit précédente, sans exception.
- **SC-003** : une évasion réussie crédite toujours un montant additionnel clairement distinct des
  gains nocturnes déjà accumulés, à 100 % des joueurs présents à cet instant.
- **SC-004** : une partie qui se termine sans évasion (défaite ou départ anticipé) laisse au
  joueur l'intégralité des gains des nuits qu'il a terminées, et jamais le bonus d'évasion.
- **SC-005** : un joueur retrouve son solde de monnaie inchangé en rejoignant une partie
  ultérieure, même après un redémarrage complet du serveur.

## Assumptions

- Le nom « Jetons fidélité » est une valeur par défaut, facilement renommée plus tard sans impact
  sur cette spécification.
- La monnaie est individuelle par joueur (comme l'inventaire personnel existant), pas un pot
  commun à l'équipe.
- Les montants exacts des gains nocturnes et du bonus d'évasion (formule précise, valeurs de
  départ) sont des valeurs de configuration ajustables, pas des règles figées par cette
  spécification.
- La dépense de la monnaie (boutique, achats, déblocages) est hors périmètre : une fonctionnalité
  séparée à venir.
- Un mécanisme permettant de tenir volontairement plus de nuits que le minimum requis avant de
  s'évader n'existe pas encore et est hors périmètre ; cette spécification rend seulement le
  bonus d'évasion proportionnel au nombre de nuits survécues, pour rester valable le jour où un
  tel mécanisme sera ajouté.
