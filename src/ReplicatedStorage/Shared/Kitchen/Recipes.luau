--!strict
-- Table statique des recettes (002-premier-increment-jouable, data-model.md « Recette »,
-- research R7). Une seule entrée pour cet incrément ; OrderService tire quand même avec
-- MatchService.rng("order") pour qu'une future deuxième recette n'exige aucun changement de
-- logique de tirage. Ce module ne contient que des données, comme Assets/Catalog.luau : les
-- quantités d'une recette définissent la recette elle-même, ce ne sont pas des valeurs
-- d'équilibrage globales (contracts/config.md).

local Types = require(script.Parent.Parent.Types)

type ResourceType = Types.ResourceType

export type Recipe = {
	Id: string,
	Ingredients: { [ResourceType]: number },
	NameKey: string,
}

local Recipes: { Recipe } = {
	{
		Id = "SuspectBurger",
		Ingredients = {
			SuspectSteak = 1,
			RoadBread = 1,
		},
		NameKey = "Kitchen.Recipe.SuspectBurger",
	},
}

return table.freeze(Recipes)
