--!strict
-- Lecture côté client de la disponibilité des recettes d'établi (009-craft-etabli, data-model.md).
-- Même esprit que BoutiqueStateClient : `State` n'a pas de forme figée, calculée en parcourant
-- Craft/Recipes.luau à chaque appel, en croisant les attributs Inv_* déjà répliqués du joueur
-- local — aucune nouvelle donnée répliquée.

local Players = game:GetService("Players")

local Recipes = require(script.Parent.Parent.Craft.Recipes)
local Signal = require(script.Parent.Parent.Util.Signal)

export type State = {
	recipes: { [string]: { available: boolean } },
}

local player = Players.LocalPlayer

local CraftStateClient = {
	Changed = Signal.new("CraftStateClient.Changed") :: Signal.Signal<()>,
}

local function carried(resourceType: string): number
	local value = player:GetAttribute(`Inv_{resourceType}`)
	return if typeof(value) == "number" then value else 0
end

function CraftStateClient.get(): State
	local recipes: { [string]: { available: boolean } } = {}
	for _, recipe in Recipes.All do
		local available = true
		for resourceType, amount in recipe.Ingredients do
			if carried(resourceType) < amount then
				available = false
				break
			end
		end
		recipes[recipe.Id] = { available = available }
	end
	return { recipes = recipes }
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
