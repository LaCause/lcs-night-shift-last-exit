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

## Aucun état persisté par joueur

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
