--!strict
-- Table statique des recettes d'établi (009-craft-etabli, data-model.md, research R2). Même
-- patron que Boutique/Catalog.luau et Kitchen/Recipes.luau : les ingrédients et le résultat d'une
-- recette sont des données qui la définissent, pas des réglages d'équilibrage globaux (FR-008).
--
-- Une recette produit un objet (Result) qui rejoint le sac du joueur ; ce que cet objet fait
-- ensuite ne se décide pas ici (la trousse se consomme avec H, le bidon se verse au générateur).

local Types = require(script.Parent.Parent.Types)

type ResourceType = Types.ResourceType

export type Recipe = {
	Id: string,
	Ingredients: { [ResourceType]: number },
	-- Objet fabriqué, en un exemplaire par fabrication.
	Result: ResourceType,
	NameKey: string,
	DescriptionKey: string,
}

-- Catalogue initial (research R6), indicatif — quantités d'ingrédients ici, montants d'effet des
-- objets fabriqués dans Settings.luau (Craft.HealAmount / Craft.FuelAmount).
local Recipes: { Recipe } = {
	{
		Id = "HealKit",
		Ingredients = { Essence = 2, Scrap = 1 },
		Result = "HealKit",
		NameKey = "Craft.Recipe.HealKit",
		DescriptionKey = "Craft.Recipe.HealKit.Desc",
	},
	{
		Id = "FuelCanister",
		Ingredients = { Essence = 3 },
		Result = "FuelCanister",
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
