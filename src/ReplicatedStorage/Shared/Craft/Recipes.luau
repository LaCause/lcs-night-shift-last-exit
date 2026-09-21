--!strict
-- Table statique des recettes d'établi (009-craft-etabli, data-model.md, research R2). Même
-- patron que Boutique/Catalog.luau et Kitchen/Recipes.luau : les ingrédients et l'effet d'une
-- recette sont des données qui la définissent, pas des réglages d'équilibrage globaux (FR-008).

local Types = require(script.Parent.Parent.Types)

type ResourceType = Types.ResourceType

-- Identifiant fermé reconnu par CraftService (research R2) : le rôle qu'Effect joue déjà dans
-- Boutique/Catalog.luau pour les avantages de départ.
export type Effect = "Heal" | "RefuelGenerator"

export type Recipe = {
	Id: string,
	Ingredients: { [ResourceType]: number },
	Effect: Effect,
	NameKey: string,
	DescriptionKey: string,
}

-- Catalogue initial (research R6), indicatif — quantités en ingrédients ici, montants d'effet
-- dans Settings.luau (Craft.HealAmount / Craft.FuelAmount).
local Recipes: { Recipe } = {
	{
		Id = "HealKit",
		Ingredients = { Essence = 2, Scrap = 1 },
		Effect = "Heal",
		NameKey = "Craft.Recipe.HealKit",
		DescriptionKey = "Craft.Recipe.HealKit.Desc",
	},
	{
		Id = "FuelCanister",
		Ingredients = { Essence = 3 },
		Effect = "RefuelGenerator",
		NameKey = "Craft.Recipe.FuelCanister",
		DescriptionKey = "Craft.Recipe.FuelCanister.Desc",
	},
}

local byId: { [string]: Recipe } = {}
for _, recipe in Recipes do
	byId[recipe.Id] = recipe
end

local RecipesModule = { All = Recipes }

function RecipesModule.find(recipeId: string): Recipe?
	return byId[recipeId]
end

return table.freeze(RecipesModule)
