# Research — Bus et victoire par évasion

Décisions techniques qui préparent la conception (Phase 1). Chaque décision explique comment
elle s'appuie sur `001-socle-technique` et `002-premier-increment-jouable` — deux d'entre elles
(R6, R7) modifient du code déjà livré, justifié explicitement.

## R1 — Le total de réparation requis est prévisualisé en direct avant l'Évasion, puis figé à son entrée

**Decision** : `BusService` calcule en continu `Required = Bus.ScrapPerPlayer *
SessionService.countPresent()` tant que la phase d'Évasion n'a pas commencé (recalculé à chaque
`SessionService.PlayerJoined`/`PlayerLeft`) ; dès que `MatchService.PhaseStarted` se déclenche
avec `phase == "Escape"`, la valeur courante est figée (plus aucun recalcul pour le reste de la
partie, quels que soient les arrivées/départs suivants).

**Rationale** : la clarification retenue (session du 2026-09-14) exige un total proportionnel à
l'effectif présent *au début de l'Évasion*, fixé à cet instant. Comme la spec autorise la récolte
et le dépôt dès le début de la partie (Assumptions), l'interface a besoin d'un total affichable
avant même que l'Évasion commence (FR-006) ; le prévisualiser en direct évite un état « en
attente » artificiel et donne une estimation honnête à l'équipe qui s'organise à l'avance.

**Alternatives considered** :
- N'afficher aucun total avant l'Évasion (seulement le nombre déposé) : rejeté, moins lisible
  (principe VII) et contredit légèrement FR-006, qui prévoit d'afficher la progression dès le
  premier dépôt, pas seulement pendant l'Évasion.
- Recalculer `Required` en continu même pendant l'Évasion (proportionnel aux joueurs encore en
  vie à chaque instant) : rejeté explicitement par la clarification (option C écartée).

## R2 — L'état du bus vit dans un nouveau dossier répliqué, sur le modèle du générateur

**Decision** : `BusService.Init` crée `ReplicatedStorage.BusState` avec les attributs
`Deposited` (entier), `Required` (entier), `Repaired` (bool) — même forme que
`ReplicatedStorage.GeneratorState` (`Fuel`/`Capacity`/`SafeZoneActive`).

**Rationale** : cohérence avec le patron déjà établi et déjà lu par les clients
(`GameplayStateClient`) ; aucune raison d'inventer une autre convention pour une donnée de même
nature (une progression plafonnée, un booléen dérivé du plafond atteint).

**Alternatives considered** : stocker `Repaired` uniquement côté serveur et le déduire côté
client de `Deposited >= Required` — rejeté, réplique un calcul trivial mais évite toute
divergence si jamais la formule change ; le coût (un attribut de plus) est négligeable.

## R3 — La ferraille est un quatrième type de ressource, sans aucun changement de `ForestService`

**Decision** : `"Scrap"` rejoint `Types.ResourceType`. Dans `ForestService`, la ferraille
s'ajoute aux trois tables de données existantes (`RESOURCE_TYPES`, `VISUAL_FOR`,
`NODE_COUNT_SETTING`) ; sa génération, sa récolte, son inventaire personnel
(`InventoryService.addPersonal`, déjà générique sur `ResourceType`) et sa notification
(`ResourceHarvested`, déjà générique) fonctionnent sans une seule ligne de logique nouvelle.

**Rationale** : `ForestService` a été conçu en 002 précisément comme une boucle sur
`RESOURCE_TYPES` ; ajouter un type est un changement de données, pas de comportement. C'est la
preuve que l'architecture générique du premier incrément tient sa promesse à l'usage.

**Alternatives considered** : un service de récolte séparé dédié à la ferraille (mimant
`ForestService`) — rejeté, duplication pure sans aucun bénéfice, contraire à la simplicité
attendue (principe VI).

## R4 — Le dépôt au bus généralise `InventoryService.depositEssence`, plutôt que de le dupliquer

**Decision** : `InventoryService.depositEssence(player, maxAmount?)` devient
`InventoryService.depositResource(player, resourceType, maxAmount?)`, paramétrée sur le type de
ressource au lieu de coder `"Essence"` en dur. `GeneratorService.RefuelGenerator` adapte son
unique appel (`depositResource(player, "Essence", maxEssence)`) ; `BusService.RepairBus` l'appelle
avec `"Scrap"`. Le comportement pour l'appelant existant est strictement identique (même
signature de retour, même sémantique).

**Rationale** : les deux mécaniques (« vider un type de ressource de l'inventaire personnel dans
un compteur plafonné, surplus conservé ») sont identiques au type de ressource près. Dupliquer la
fonction pour la ferraille aurait recopié une logique déjà testée pour un gain nul ; la
généraliser est une modification mécanique et sûre (paramétrer une chaîne déjà locale à la
fonction), qui ne change rien pour `GeneratorService`.

**Alternatives considered** : garder `depositEssence` intact et ajouter `depositScrap` en copie —
rejeté, viole la simplicité attendue (principe VI) pour éviter de toucher un seul appelant déjà
trivial à adapter.

## R5 — Le départ exige une vérification propre au gestionnaire, au-delà du pipeline générique

**Decision** : `DepartBus` déclare `target = { field = "target", rangeSetting =
"Bus.DepartureRange" }` comme toute intention ciblée (étapes 7-9 du pipeline valident déjà la
distance du joueur *appelant*). Le gestionnaire de `BusService` ajoute, avant d'appeler
`MatchService.endMatch`, une vérification propre au domaine : pour chaque session dont
`Status == "Alive"`, la distance de son `HumanoidRootPart` à `BusSpot` DOIT être ≤
`Bus.DepartureRange` (+ `Net.DistanceTolerance`, comme le reste des portées) ; un joueur en vie
sans personnage chargé (fenêtre de réapparition) compte comme hors de portée. Le premier
manquant fait refuser `TeamNotReady`.

**Rationale** : le pipeline générique (contracts/network.md du socle) ne valide que la distance
de l'appelant à sa cible — il n'a jamais eu besoin de vérifier la position d'autres joueurs.
Étendre le pipeline générique pour ce seul cas romprait sa simplicité pour tous les autres
systèmes ; une vérification dans le gestionnaire, comme `PrepareOrder` vérifie le stock partagé
au-delà de ce que le pipeline sait faire, garde le générique générique (principe III : un seul
endroit de validation générique, des règles métier dans le système propriétaire).

**Alternatives considered** :
- Généraliser `target` pour accepter une liste de joueurs à vérifier — rejeté, sur-conçu pour un
  unique cas d'usage actuel.
- Réutiliser `Bus.InteractRange` (portée de dépôt) pour le départ aussi — rejeté : le bus mesure
  22 studs de long, une portée pensée pour une interaction ponctuelle au point de dépôt serait
  trop stricte pour que toute une équipe de 6 se rassemble sans se sentir contrainte à un seul
  point exact ; `Bus.DepartureRange` (plus large) reste un réglage centralisé et ajustable.

## R6 — La provision « Évasion → défaite » de `MatchService` est retirée, pas contournée

**Decision** : `MatchService.advance()` perd sa branche `elseif phase == "Escape" then ... end`
(elle appelait `endMatch("Defeat", "le bus n'est pas parti à temps")`, marquée
`-- Provisoire : la fonctionnalité du bus redéfinira la fin de l'évasion.`). `skipPhase()` gagne
une garde : `if state.phase == "Waiting" or state.phase == "Escape" then return false end`, pour
que la commande de dev « Phase suivante » n'ait plus aucun effet pendant l'Évasion (elle rapporte
proprement « Rien à sauter », comme pendant l'Attente).

**Rationale** : cette branche était un placeholder explicitement destiné à être remplacé par
cette fonctionnalité — ce n'est pas une modification arbitraire du socle, c'est la résolution du
TODO qu'il annonçait lui-même. En pratique, elle n'était de toute façon atteignable qu'en
Studio via « Phase suivante » (`Match.EscapeDuration` vaut `0`, donc aucune minuterie ne
déclenche `advance()` automatiquement en Évasion) : sans cette modification, un développeur
testant `003-bus-evasion` qui cliquerait par réflexe sur « Phase suivante » pendant l'Évasion
déclencherait une fausse défaite contredisant le nouveau comportement voulu. Le vrai départ ne
passe plus du tout par `advance()` : `BusService.DepartBus` appelle directement
`MatchService.endMatch("Victory", ...)`, exactement comme `Dev.EndMatch` le fait déjà pour les
autres résultats.

**Alternatives considered** :
- Laisser la branche intacte et espérer qu'elle ne se déclenche jamais en pratique — rejeté,
  fragile (un clic de dev suffit à la déclencher) et laisse un TODO non résolu alors que cette
  fonctionnalité est précisément censée le résoudre.
- Faire déclencher la victoire par `advance()` (au lieu d'un appel direct de `BusService`) —
  rejeté : `advance()` avance une *horloge*, pas un événement conditionnel (bus réparé ET équipe
  rassemblée) ; le modèle déjà en place pour la victoire/défaite (`MatchService.endMatch` appelé
  directement par le système qui constate la condition) est le bon, déjà utilisé par
  `Dev.EndMatch` et par la défaite déclenchée depuis `checkDefeat()`.

## R7 — L'état « réparé » du bus réutilise le modèle déjà construit, pas un nouveau visuel de scène

**Decision** : `Catalog.buildBus()` gagne une pièce supplémentaire, `RepairLight` (un voyant néon
au même patron que `GeneratorLight`, rouge par défaut). `BusService` retrouve l'instance déjà
construite par `WorldService` au démarrage (`WorldService.visual("Bus")`, nouvelle API additive)
et, au passage à `Repaired = true`, masque `RustPatch` (`Transparency = 1`) et fait passer
`RepairLight.Color` au vert. Aucune nouvelle instance de premier niveau dans `Workspace`, aucun
nouveau dossier.

**Rationale** : le bus est construit une seule fois au démarrage du serveur par `WorldService`
(comme le reste de `Workspace.World`), pas par partie — contrairement à la forêt. Modifier ses
pièces déjà nommées est strictement moins de travail et plus cohérent visuellement (la rouille
qui disparaît raconte la réparation) qu'un second modèle à superposer ou à échanger. C'est le
même principe que R5 de `002-premier-increment-jouable` (la zone de sécurité attache une lumière
à un point déjà construit plutôt que de dupliquer de la géométrie).

**Alternatives considered** :
- Un second modèle « Bus réparé » qui remplace le premier — rejeté, complexité et coût mémoire
  inutiles pour un simple changement d'état visuel.
- Un repère visuel flottant façon `FeedbackVisualService` (comme pour le comptoir/plan de
  travail/fenêtre) — rejeté ici : ces repères signalent une action à faire à un endroit précis
  du restaurant ; l'état du bus lui-même (pas une action à son sujet) se lit mieux en modifiant
  l'objet concerné directement, visible à distance sans avoir à s'approcher.

## R8 — Aucune extension de `RefPointId` : `BusSpot` existe déjà

**Decision** : `RepairBus` et `DepartBus` ciblent tous les deux le point de référence `BusSpot`,
déjà présent dans `Types.RefPointId` et construit par `WorldService` depuis le socle technique
(`001-socle-technique`), explicitement prévu pour « les fonctionnalités futures ».

**Rationale** : aucune ambiguïté ni conflit à résoudre — c'est exactement l'usage annoncé de ce
point de référence. Contrairement à `EnemySpawn` en 002 (research R10), aucune extension n'est
nécessaire ici.

**Alternatives considered** : aucune — un nouveau point de référence dédié n'aurait aucune
justification, `BusSpot` couvrant déjà exactement ce besoin.
