# Modèle de données — Système de craft à l'établi

## Recette d'établi (catalogue, statique)

Définie dans `Shared/Craft/Recipes.luau` (research R2), jamais modifiée à l'exécution :

| Champ | Type | Description |
| --- | --- | --- |
| `Id` | `string` | identifiant unique et stable de la recette |
| `Ingredients` | `{ [ResourceType]: number }` | quantités requises, prélevées sur l'inventaire personnel |
| `Effect` | `"Heal" \| "RefuelGenerator"` | identifiant interne reconnu par `CraftService` |
| `NameKey` / `DescriptionKey` | `string` | clés `Strings.luau` |

Catalogue initial (research R6), indicatif — quantités et montants en `Settings.luau` :

| Id | Ingredients | Effect | Montant (config) |
| --- | --- | --- | --- |
| `HealKit` | `{ Essence = 2, Scrap = 1 }` | `Heal` | `Craft.HealAmount` (défaut 30) |
| `FuelCanister` | `{ Essence = 3 }` | `RefuelGenerator` | `Craft.FuelAmount` (défaut 25) |

## Amendement 2026-09-25 — état de l'établi par joueur (fabrication en deux phases)

Le flux en un clic décrit plus bas est **remplacé** : la fabrication se fait en deux phases (voir
`spec.md`, FR-011 à FR-016). L'état de l'établi est désormais porté par des attributs répliqués du
`Player`, écrits uniquement par `CraftService` — le même patron que `Inv_*` :

| Attribut | Type | Sens |
| --- | --- | --- |
| `CraftRecipe` | `string` | id de la recette choisie, `""` si le joueur est encore à la liste |
| `Craft_<ResourceType>` | `number` | unités déjà posées sur l'établi (`Essence`, `SuspectSteak`, `RoadBread`, `Scrap`) |

Transitions (toutes décidées par `CraftService`, principe III) :

```text
SelectCraftRecipe(recipeId)  : rend d'abord le posé au sac (refus InventoryFull si le sac ne peut
                               pas tout reprendre), puis CraftRecipe = recipeId
CancelCraft                  : rend le posé au sac (même refus), puis CraftRecipe = ""
Touche G près de l'établi    : StationDepositService → CraftService.tryPlaceFromBag : si la
                               recette attend encore ce type, 1 unité passe du sac à Craft_<type>
Objet du monde relâché       : CarryService → CraftService.tryPlaceCarried : si la recette attend
                               encore ce type et que l'objet est à portée, le nœud est consommé
                               (ForestService.consumeNode) et Craft_<type> += 1
CraftItem(recipeId)          : recette choisie == recipeId sinon NoRecipeSelected ; tous les
                               Craft_<type> >= requis sinon InsufficientResources ; plus de place
                               dans le sac → InventoryFull (rien n'est consommé, le posé reste) ;
                               sinon Craft_<type> -= requis et 1 objet Recipe.Result est ajouté au
                               sac (la recette reste choisie, pour en refaire une)
Élimination / MatchStarting  : CraftRecipe = "" et tous les Craft_<type> = 0 (posé perdu)
```

La portée du dépôt par G se mesure depuis le **joueur** (`Craft.InteractRange`), celle du
glisser-déposer depuis l'**objet**, comme les postes de `005`. `CraftStateClient.get()` devient
`{ recipe: Recipe?, placed: { [type]: number }, complete: boolean }` (lecture croisée de ces
attributs).

## Amendement 2026-09-25 (2) — les recettes produisent des objets

- `Recipe.Effect` (`"Heal" | "RefuelGenerator"`) est **remplacé** par `Recipe.Result: ResourceType`.
- `Types.ResourceType` gagne `HealKit` et `FuelCanister` : compteurs `Inv_HealKit` /
  `Inv_FuelCanister` (`InventoryService`, `BagService.CARRIED_TYPES`, `GameplayStateClient`),
  comptés dans la place du sac. Visuels au sol : `HealKitItem` / `FuelCanisterItem` (`Catalog`,
  primitives), volontairement distincts du nœud d'essence (visuel `FuelCanister`).
- Aucun nœud de forêt n'en génère (`ForestService.RESOURCE_TYPES` inchangé) ; ils n'apparaissent
  qu'au sol quand un joueur les lâche (`VISUAL_FOR`).

```text
UseHealKit (touche H, aucune cible) :
  joueur pas vivant                    → NoCharacter
  aucune HealKit dans le sac           → InsufficientResources
  santé >= MaxHealth                   → NoBenefit (la trousse reste dans le sac ; notif HealKitUseless)
  sinon : consomme 1 HealKit, HealthService.heal(Craft.HealAmount) ; notif HealKitUsed

Bidon versé au générateur (G devant lui : StationDepositService ; ou RefuelGenerator) :
  GeneratorService.depositCanister : fuelRoom() <= 0 → refusé, le bidon reste ;
  sinon consomme 1 FuelCanister, GeneratorService.deposit(Craft.FuelAmount) (plafonné)
```

`CraftStateClient.get()` redevient `{ recipe, placed, complete }` : plus aucun calcul d'« utilité »
côté client, l'établi produit toujours un objet.

## Aucun état persisté par joueur (version initiale, en un clic)

Contrairement à `006`/`008`, cette fonctionnalité ne crée aucune donnée qui survit au-delà de
l'instant de la fabrication (spec, Key Entities : « aucun objet fabriqué ne reste ensuite dans le
sac du joueur »). Les seuls effets observables passent par des mécanismes déjà existants :

| Effet | Écrivain | Borne |
| --- | --- | --- |
| Santé restaurée | `HealthService.heal` (research R4) | `Players.MaxHealth` |
| Carburant ajouté | `GeneratorService.deposit` (déjà public) | `Generator.Capacity` |

## Transitions

```text
Fabrication (CraftItem, recipeId) :
  Recipes.find(recipeId) == nil                          → rejet RecipeUnknown
  not InventoryService.hasPersonal(player, recipe.Ingredients) → rejet InsufficientResources
  effet sans bénéfice possible                            → rejet NoBenefit
    (Heal : HealthService.get(player) >= MaxHealth)
    (RefuelGenerator : GeneratorService.fuelRoom() <= 0)
  sinon :
    InventoryService.consumePersonal(player, recipe.Ingredients)
    si Effect == "Heal"            : HealthService.heal(player, Craft.HealAmount)
    si Effect == "RefuelGenerator" : GeneratorService.deposit(Craft.FuelAmount)
```

Aucune sauvegarde en arrière-plan : la fabrication est entièrement synchrone, sans dépendance à
`DataStoreService` (contrairement à `006`/`008`).

## Exposition client (`CraftStateClient.get()`, miroir léger de `BoutiqueStateClient`)

```text
{
  recipes: {
    [recipeId: string]: {
      available: boolean,  -- InventoryService.hasPersonal reflété côté client (lecture des Inv_*)
    }
  }
}
```

Calculé en parcourant `Craft/Recipes.luau` et en lisant les attributs `Inv_<ResourceType>` déjà
répliqués du joueur local — aucune nouvelle donnée répliquée, seulement une lecture croisée de ce
qui existe déjà (comme `GameplayStateClient` le fait pour `bagUsed`).
