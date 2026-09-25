--!strict
-- Lecture côté client de l'état de l'établi (009-craft-etabli, data-model.md) : la recette choisie
-- (attribut CraftRecipe) et les ingrédients déjà posés (attributs Craft_<Ressource>), tous écrits
-- par CraftService. Même esprit que BoutiqueStateClient : `State` est calculé à chaque appel à
-- partir des attributs déjà répliqués du joueur local — aucune donnée dupliquée, aucune autorité
-- côté client.

local Players = game:GetService("Players")

local Recipes = require(script.Parent.Parent.Craft.Recipes)
local Signal = require(script.Parent.Parent.Util.Signal)

export type State = {
	-- Recette choisie à l'établi ; nil tant que le joueur est encore à la liste des recettes.
	recipe: Recipes.Recipe?,
	-- Unités posées sur l'établi, par ressource attendue par la recette choisie.
	placed: { [string]: number },
	-- Vrai quand chaque ingrédient de la recette choisie est posé en quantité suffisante.
	complete: boolean,
}

local player = Players.LocalPlayer

local CraftStateClient = {
	Changed = Signal.new("CraftStateClient.Changed") :: Signal.Signal<()>,
}

local function numberAttribute(key: string): number
	local value = player:GetAttribute(key)
	return if typeof(value) == "number" then value else 0
end

function CraftStateClient.get(): State
	local id = player:GetAttribute("CraftRecipe")
	local recipe = if typeof(id) == "string" then Recipes.find(id) else nil
	local placed: { [string]: number } = {}
	local complete = recipe ~= nil
	if recipe ~= nil then
		for resourceType, required in recipe.Ingredients do
			local count = numberAttribute(`Craft_{resourceType}`)
			placed[resourceType] = count
			if count < required then
				complete = false
			end
		end
	end
	return { recipe = recipe, placed = placed, complete = complete }
end

task.spawn(function()
	if player then
		player.AttributeChanged:Connect(function()
			CraftStateClient.Changed:Fire()
		end)
	end
	CraftStateClient.Changed:Fire()
end)

return CraftStateClient
