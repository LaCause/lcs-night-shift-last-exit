# Research — Premier incrément jouable

Décisions techniques qui préparent la conception (Phase 1). Chaque décision explique comment
elle s'appuie sur le socle technique (`001-socle-technique`) sans le modifier de façon
incompatible.

## R1 — Le moment de génération de la forêt suit la seed de la partie, pas le démarrage du serveur

**Decision** : la forêt (points de ressource) est (re)générée à chaque nouvelle partie, pas une
seule fois au démarrage du serveur. `MatchService` gagne un nouveau signal
`MatchStarting(matchId, seed)`, déclenché en tout premier dans `startNewMatch`, avant
`SessionService.resetAll()`. `ForestService` s'y abonne dans son `Init` et reconstruit
`Workspace.Forest` avec `MatchService.rng("forest")`.

**Rationale** : le monde statique (restaurant, bus, points de référence) ne dépend pas de la
seed et peut être construit une fois par `WorldService` au démarrage du serveur (inchangé,
décision R3 du socle). Les points de ressource, eux, DOIVENT varier avec la seed (SC-009 de
cette fonctionnalité) ; comme la seed change à chaque nouvelle partie (y compris au
redémarrage automatique après une fin de partie, FR-029 du socle), la forêt doit se
régénérer au même rythme. Une forêt figée au démarrage du serveur romprait la reproductibilité
par seed dès la deuxième partie d'une même session serveur.

**Alternatives considered** :
- Régénérer la forêt uniquement au tout premier démarrage (comme `WorldService`) : rejeté,
  incompatible avec SC-009 après un redémarrage automatique.
- Faire dépendre `ForestService` de `MatchService` par un appel direct (`MatchService`
  appelle `ForestService.regenerate(seed)`) : rejeté, car cela romprait le graphe de
  dépendances acyclique du socle (`MatchService` ne doit pas connaître les systèmes de
  gameplay qui s'y greffent). Le signal `MatchStarting` garde le sens du couplage : les
  systèmes de gameplay dépendent de `MatchService`, jamais l'inverse — même sens que
  `SessionService.PlayerJoined` consommé par `MatchService`.

## R2 — La forêt vit dans son propre dossier, séparé de `Workspace.World`

**Decision** : `ForestService` construit et détruit `Workspace.Forest`, indépendant du
`Workspace.World` construit une seule fois par `WorldService`.

**Rationale** : `WorldService.Init` détruit et reconstruit `Workspace.World` en entier ; s'il
fallait reconstruire la forêt à chaque partie, la mêler à `World` obligerait soit à rejouer
tout `WorldService.Init` à chaque partie (fragile, effets de bord sur les points de référence),
soit à faire connaître `ForestService` à `WorldService` (couplage inutile). Un dossier séparé
laisse chaque système responsable de son propre cycle de vie (principe VI).

**Alternatives considered** : sous-dossier `Workspace.World.Forest` — rejeté pour la raison
ci-dessus.

## R3 — Généralisation minimale du pipeline réseau pour une cible dynamique

**Decision** : `NetService.registerIntent(name, { handler, resolve? })` accepte un résolveur de
cible optionnel. Quand une intention est enregistrée avec `resolve`, le pipeline (étapes 7 à 9,
contracts/network.md du socle) appelle `resolve(targetId)` au lieu de
`RefPoints.find(targetId)`. Sans `resolve`, le comportement existant (recherche par
`RefPoints`) est inchangé — aucune intention du socle (`RingBell`, `Dev.*`) n'est affectée.
`Remotes.luau` reste purement déclaratif : il continue de ne porter que `field` et
`rangeSetting` pour `target` ; c'est le service propriétaire (ici `ForestService`) qui fournit
la fonction `resolve` au moment de l'enregistrement, au même endroit que `handler`.

**Rationale** : les points de référence du socle (`RefPointId`) forment une liste fermée de
lieux fixes. Les points de ressource de la forêt sont dynamiques (apparaissent, deviennent
indisponibles, réapparaissent) et nombreux : les faire entrer dans `RefPointId` romprait le
principe même de ce type (un identifiant fermé = un point unique du monde). Un résolveur
injecté garde le pipeline générique (un seul endroit valide forme, cadence, phase, cible,
distance — principe III) sans lui faire connaître la notion de « ressource ».

**Alternatives considered** :
- Étendre `RefPointId` avec un identifiant par nœud généré dynamiquement : rejeté, la liste
  ne serait plus fermée ni stable, et `RefPoints.find` bouclerait sur un nombre croissant
  d'instances taguées pour rien.
- Dupliquer un mini-pipeline de validation dans `ForestService` : rejeté, viole FR-030/FR-031
  du socle (« un seul endroit » de validation).

## R4 — La santé du joueur est une valeur serveur distincte, pas `Humanoid.Health`

**Decision** : `HealthService` maintient `health: { [Player]: number }`, répliquée par
l'attribut `Player.Health` (et `Player.MaxHealth`), séparée de `Humanoid.Health`. Seuls les
dégâts de l'ennemi (`EnemyService`) et la remise à zéro de partie
(`MatchService.MatchStarting`) modifient cette valeur. À 0, `HealthService` appelle
`SessionService.setStatus(player, "Eliminated")` — l'existant, inchangé.

**Rationale** : `SessionService` traite déjà `Humanoid.Died` comme un incident local sans
conséquence (chute du monde → réapparition simple, comportement du socle à ne pas modifier).
Faire porter les dégâts de l'ennemi sur `Humanoid.Health` réutiliserait le même signal `Died`
pour deux significations différentes (chute accidentelle vs élimination réelle) et forcerait à
distinguer leur cause dans `SessionService`, un système du socle déjà validé. Une valeur
serveur dédiée garde l'autorité claire (principe III : une seule source de vérité par donnée)
et n'exige aucune modification de `SessionService` ni de `WorldService`.

**Alternatives considered** : dériver la santé du joueur de `Humanoid.Health` avec un indicateur
de cause — rejeté, plus complexe et touche un système déjà livré et testé.

## R5 — La zone de sécurité est une lumière attachée au point de référence existant

**Decision** : `GeneratorService.Init` ajoute un `PointLight` (et un indicateur visuel simple)
comme enfant de la pièce déjà construite par `WorldService` au point de référence
`SafeZoneCenter`. Son état (`Enabled`, `Brightness`) suit le niveau de carburant.

**Rationale** : `SafeZoneCenter` existe déjà comme point de référence du socle, prévu
explicitement pour les fonctionnalités futures. Y attacher une lumière évite de dupliquer un
sous-système de construction de monde ; c'est le même principe que `BellService` qui attache un
`ProximityPrompt` à `CounterBell` sans reconstruire de géométrie.

**Alternatives considered** : construire un nouveau modèle de zone de sécurité dans
`Catalog.luau` — rejeté pour cet incrément, complexité inutile pour un simple halo lumineux ;
pourra être enrichi visuellement plus tard sans changer l'API de `GeneratorService`.

## R6 — L'ambiance jour/nuit est pilotée par le serveur, sans nouveau contrôleur client

**Decision** : un nouveau service serveur `AmbianceService` règle `Lighting` (Brightness,
ClockTime, FogEnd, FogColor) via `TweenService`, déclenché par
`MatchService.PhaseStarted`/`PhaseEnded`. Aucun script client n'est nécessaire : les propriétés
de `Lighting` se répliquent comme celles de `Workspace` (déjà utilisé par le socle pour
`FallenPartsDestroyHeight`).

**Rationale** : ce n'est pas une donnée de jeu (pas de logique à valider), donc la placer côté
serveur n'ajoute aucune charge réseau ; ça évite en revanche que chaque client recalcule sa
propre transition (qui pourrait diverger, contraire au principe III sur la cohérence de
l'affichage).

**Alternatives considered** : contrôleur client tweenant `Lighting` localement à la réception de
`PhaseStarted` (déjà diffusé par notification) — rejeté, aucune donnée cliente n'est nécessaire
ici et un contrôleur par joueur pourrait légèrement diverger (léger différentiel de tween).

## R7 — Une seule recette pour cet incrément, mais un catalogue extensible

**Decision** : `Shared/Kitchen/Recipes.luau` déclare un dictionnaire de recettes (une seule
entrée pour cet incrément : `SuspectBurger`). `OrderService` choisit une recette avec
`MatchService.rng("order")`, même s'il n'y en a qu'une, pour que l'ajout d'une deuxième recette
plus tard n'exige aucun changement de logique de tirage.

**Rationale** : anticipe l'assumption de la spec (« les commandes aléatoires multiples
arriveront dans un incrément ultérieur ») sans sur-construire maintenant.

**Alternatives considered** : coder la recette en dur dans `OrderService` — rejeté, viole
FR-026 (toute valeur d'équilibrage centralisée) : les quantités d'ingrédients doivent rester
ajustables sans toucher au code.

## R8 — L'ennemi se déplace sans `Humanoid`

**Decision** : l'ennemi est un `Model` avec un `PrimaryPart`, déplacé par mise à jour de CFrame
le long des points de cheminement retournés par `PathfindingService:CreatePath` /
`ComputeAsync`. En cas d'échec (chemin incomplet ou erreur), il se déplace en ligne droite vers
sa cible (repli direct, principe VI). Aucun `Humanoid` : pas d'animation, pas de calcul de
santé propre à l'ennemi, aucun risque de confusion avec le `Humanoid` des joueurs.

**Rationale** : garde l'ennemi simple et robuste (principe VI : « chercher le joueur proche,
attaquer, puis repartir ou disparaître »). Un `Humanoid` apporterait de la complexité
(physique, `WalkToPoint`, ragdoll potentiel) sans bénéfice pour ce premier archétype.

**Alternatives considered** : `Humanoid:MoveTo` avec waypoints — rejeté pour cet incrément ;
resterait une option pour un futur ennemi plus élaboré, sans changer l'API `EnemyService`.

## R9 — L'échec d'une commande déclenche l'ennemi par signal, jamais par couplage direct

**Decision** : `OrderService` expose un signal `OrderFailed(recipeId)`, déclenché quand la nuit
se termine (`MatchService.PhaseEnded` avec `previousPhase == "Night"`) sans livraison réussie.
`EnemyService` s'y abonne dans son `Init`. `OrderService` ne connaît pas `EnemyService`.

**Rationale** : même principe que R1 — le système qui décide (l'échec d'une commande) ne doit
pas connaître celui qui réagit (l'apparition d'un ennemi), pour garder le graphe de dépendances
acyclique et permettre d'ajouter d'autres réactions futures (ex. coupure partielle de
l'électricité mentionnée dans `TECH.md`) sans toucher `OrderService`.

**Alternatives considered** : `EnemyService` interroge l'état de `OrderState` à chaque fin de
nuit par sondage — rejeté, plus complexe et moins immédiat qu'un signal.

## R10 — Un nouveau point de référence pour l'apparition de l'ennemi

**Decision** : `RefPoints.Ids` et `Types.RefPointId` gagnent un nouvel identifiant,
`EnemySpawn`, positionné en lisière de forêt dans `Layout.luau`. C'est une extension additive
du socle (la spec 001 prévoyait explicitement des points de référence « utilisés par les
fonctionnalités futures »), pas une modification de son comportement existant.

**Rationale** : réutilise l'infrastructure déjà validée (`RefPoints.find`, construction par
`WorldService`) plutôt que d'inventer un second mécanisme de point nommé.

**Alternatives considered** : faire apparaître l'ennemi à la position d'un nœud de ressource
aléatoire — rejeté, moins prévisible pour le playtest et plus difficile à équilibrer (portée
initiale par rapport à la zone de sécurité).

## R11 — Nouveaux codes de refus, additifs au type existant

**Decision** : `Types.RejectCode` gagne cinq codes : `NodeUnavailable`, `InventoryFull`,
`MissingIngredients`, `NotPrepared`, `OrderClosed`. Les onze codes du socle ne changent pas de
sens.

**Rationale** : chaque nouveau gestionnaire (récolte, préparation, livraison) a des refus
propres à sa logique métier, distincts des refus déjà couverts par le pipeline générique
(cadence, forme, phase, cible, distance). Type union, donc extension non cassante.

**Alternatives considered** : réutiliser `HandlerError` pour tous ces cas — rejeté, `HandlerError`
signale une exception interne (bug), pas un refus métier normal ; les distinguer garde le
journal exploitable (FR-032 du socle).
