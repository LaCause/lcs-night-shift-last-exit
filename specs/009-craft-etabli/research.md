# Recherche — Système de craft à l'établi

## R1 — Emplacement de l'établi : nouveau point de référence, pas un lieu orphelin recyclé

**Décision** : un nouveau `RefPointId`, `"Workbench"`, construit exactement comme `Worktop`/
`Fryer`/`Counter` — quelques pièces de plus dans le modèle `Restaurant` déjà bâti par
`Assets/Catalog.luau` (`buildRestaurant`), avec une entrée `Layout.RefPoints.Workbench` dont les
coordonnées X/Z sont hand-matchées à la nouvelle géométrie (même convention que `Worktop`/`Fryer`
aujourd'hui — un marqueur invisible et sa géométrie visible restent deux listes de coordonnées
tenues à la main, jamais liées programmatiquement). Pas de nouvelle entrée `Layout.Visuals` : ce
poste n'a aucun état visuel à basculer (pas d'équivalent à `RustPatch`/`RepairLight` du bus), donc
aucune raison d'exister comme modèle indépendant nommé.

**Alternative rejetée** : deux points de référence existants, `Fryer` et `Intercom`, se sont
révélés totalement inutilisés par aucun service (confirmé par lecture directe de tous les appels
`WorldService.refPoint(...)`) — un candidat tentant pour économiser une nouvelle géométrie.
Écartée : recycler une friteuse ou un interphone sous l'étiquette « établi » tromperait quiconque
relit `RefPoints.luau`/`Assets/Catalog.luau` plus tard (le nom de la pièce ne correspondrait plus à
sa fonction), et la demande initiale (« à l'établi ») nomme explicitement un lieu nouveau, pas une
réinterprétation d'un poste existant. Le coût d'un nouveau point de référence est de toute façon
minime : quelques `Part` primitives de plus dans un modèle déjà construit, pas un nouveau système.

## R2 — Recettes : module de données statique, même patron que `Recipes.luau`/`Catalog.luau`

**Décision** : `ReplicatedStorage/Shared/Craft/Recipes.luau`, une table Lua figée
(`table.freeze`), même esprit que `Kitchen/Recipes.luau` et `Boutique/Catalog.luau` — les
ingrédients et l'effet d'une recette sont des données qui la définissent, pas des réglages
d'équilibrage globaux (FR-008).

**Forme retenue** (par entrée) :

```text
{ Id: string, Ingredients: { [ResourceType]: number }, Effect: "Heal" | "RefuelGenerator",
  NameKey: string, DescriptionKey: string }
```

`Effect` est un identifiant fermé reconnu par `CraftService` (deux valeurs à cet incrément), exactement
le rôle que joue déjà `Effect` dans `Boutique/Catalog.luau` pour les avantages de départ.

## R3 — Consommation d'ingrédients : nouvelles fonctions miroir sur `InventoryService`

**Décision** : deux fonctions additives, exact miroir de `hasStock`/`consumeStock` (déjà
existantes, lignes 219-236 d'`InventoryService.luau`) mais sur l'inventaire **personnel** plutôt
que le stock partagé :

```text
InventoryService.hasPersonal(player, requirements: {[string]: number}): boolean
InventoryService.consumePersonal(player, requirements: {[string]: number})
```

**Rationale** : le module ne propose aujourd'hui aucune vérification/déduction **multi-ressources
atomique** sur l'inventaire personnel — seulement `depositResource` (une seule ressource à la
fois, "best effort" : déduit jusqu'à `maxAmount` ou ce que le joueur porte, jamais un refus net).
Une recette de craft exige plusieurs types d'ingrédients à la fois, tout ou rien (FR-002) : recoder
cette logique dans `CraftService` dupliquerait `hasStock`/`consumeStock` presque mot pour mot pour
une différence d'une seule ligne (la source lue). Le miroir direct est la solution la plus honnête.

**Contrainte héritée** : `consumePersonal` DOIT appeler `removeFromOrder` pour chaque ressource
déduite, comme le fait déjà `depositResource` — c'est ce qui maintient l'invariant documenté en
tête du module (`#order[player] == somme(Inv_*) de ce joueur, à tout moment`), qui conditionne
l'ordre de dépôt utilisé par `BagService.drop`/`dropOne`. Une déduction qui l'ignorerait
laisserait `order` désynchronisé sans qu'aucune erreur immédiate ne le révèle.

## R4 — Effets : une fonction additive (`HealthService.heal`), une fonction déjà publique réutilisée (`GeneratorService.deposit`)

**Décision** :

- `HealthService.heal(player: Player, amount: number)` — nouvelle fonction additive, miroir
  symétrique de `HealthService.damage` déjà existante (clamp à `MaxHealth` au lieu de 0, aucun
  changement de statut associé — soigner un joueur déjà `Eliminated` n'a pas de sens, mais ce cas
  ne se présente pas ici : FR-007 exige déjà un personnage vivant présent à l'établi).
- `GeneratorService.deposit(amount): number` — **déjà publique**, déjà utilisée par
  `StationDepositService`/`GeneratorService` lui-même ; renvoie la quantité réellement ajoutée
  (bornée par la capacité). `GeneratorService.fuelRoom(): number` — **déjà publique** — sert à
  vérifier FR-003 (réserve déjà pleine) avant toute déduction. Aucune modification de
  `GeneratorService` nécessaire pour cet incrément.

**Rationale** : garder l'effet du bidon de carburant sur le même chemin que le ravitaillement
manuel (`RefuelGenerator`) plutôt que d'écrire directement l'attribut `Fuel` — un seul écrivain de
la réserve, `GeneratorService`, comme le principe III l'exige déjà pour tout état d'autorité.

## R5 — Ouverture du panneau : invite de proximité sans intention réseau

**Décision** : une `ProximityPrompt` à l'établi, **sans** attribut `Intent`/`Target`, dont
l'événement `Triggered` est écouté directement par un nouveau contrôleur client
(`CraftPanelController.luau`) pour ouvrir/fermer localement le panneau — aucun aller-retour
serveur pour un simple affichage d'interface (clarification 2026-09-20 : le choix de la recette se
fait via un panneau, pas des invites séparées par recette).

**Rationale** : `InteractionController.luau` (`research R8` du projet) relaie déjà **uniquement**
les invites portant un attribut `Intent` de type chaîne — celles qui n'en portent pas sont
silencieusement ignorées (`if typeof(intent) ~= "string" then return end`), confirmé par lecture
directe : aucune modification de ce contrôleur générique n'est nécessaire, et aucune intention
réseau n'a besoin d'exister juste pour ouvrir un panneau (ce serait un aller-retour serveur sans
aucun effet de jeu, contraire à SC-001 qui vise un retour immédiat). C'est la première invite du
projet sans `Intent` — un patron nouveau, mais justifié : elle ne décide jamais rien, elle affiche
seulement (principe III respecté : aucune autorité déléguée).

**La fabrication elle-même reste une intention réseau ordinaire** (`CraftItem`), revalidée
entièrement côté serveur, avec un `target` borné par portée (`Craft.InteractRange`) comme
`RepairBus`/`RefuelGenerator` — seul le geste d'ouvrir le panneau évite le réseau, jamais celui de
fabriquer.

## R6 — Deux recettes initiales, calibrées contre les ressources déjà en jeu

**Décision** :

- **Trousse de soins de fortune** (`HealKit`) : 2× Essence + 1× Scrap → restaure `Craft.HealAmount`
  (défaut 30) points de santé, jamais au-delà de `Players.MaxHealth` (100 par défaut) — un mélange
  de ressources deux nœuds différents, pour que la fabrication encourage une récolte variée
  (renforce aussi l'axe « exploration procédurale » du filtre d'évolutivité, en plus de « tension
  nocturne » déjà porté par la spec).
- **Bidon de carburant de secours** (`FuelCanister`) : 3× Essence → ajoute `Craft.FuelAmount`
  (défaut 25) au carburant du générateur, jamais au-delà de `Generator.Capacity` (100 par défaut).

**Rationale du calibrage** : un tiers de la capacité du générateur par bidon (25/100) le rend
clairement utile sans rendre `RefuelGenerator` (le dépôt manuel direct d'essence) inutile — un
joueur peut toujours ravitailler directement sans jamais passer par l'établi (principe II, aucune
fonctionnalité ne doit devenir nécessaire pour rester jouable). Même raisonnement pour la trousse
de soins : 30 points sur 100 soigne une part significative des dégâts de contact (`Enemy.ContactDamage`
par défaut 20) sans rendre la santé illimitée. Ces deux recettes et leurs quantités sont indicatives
(spec, Assumptions) : ajustables en configuration sans toucher au mécanisme.
