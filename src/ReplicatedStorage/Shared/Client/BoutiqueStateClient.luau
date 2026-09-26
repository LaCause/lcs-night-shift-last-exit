--!strict
-- Lecture côté client de l'état de boutique répliqué (008-boutique-persistance, data-model.md,
-- research R10). Contrairement à GameplayStateClient, `State` n'a pas de forme figée : elle est
-- calculée en parcourant Catalog.luau à chaque appel, pour rester correcte par construction si le
-- catalogue grossit, sans qu'aucune modification de ce module ne soit alors nécessaire.

local Players = game:GetService("Players")

local Catalog = require(script.Parent.Parent.Boutique.Catalog)
local Signal = require(script.Parent.Parent.Util.Signal)

export type State = {
	balance: number,
	owned: { [string]: boolean },
	active: { [string]: string },
}

local player = Players.LocalPlayer

local BoutiqueStateClient = {
	Changed = Signal.new("BoutiqueStateClient.Changed") :: Signal.Signal<()>,
}

function BoutiqueStateClient.get(): State
	local balance = player:GetAttribute("Currency")
	local owned: { [string]: boolean } = {}
	local active: { [string]: string } = {}
	for _, item in Catalog.Items do
		owned[item.Id] = player:GetAttribute(`Owned_{item.Id}`) == true
		if item.Category == "Cosmetic" and item.Slot ~= nil then
			local slot = item.Slot :: string
			if active[slot] == nil then
				local value = player:GetAttribute(`Active_{slot}`)
				active[slot] = if typeof(value) == "string" then value else ""
			end
		end
	end
	return {
		balance = if typeof(balance) == "number" then balance else 0,
		owned = owned,
		active = active,
	}
end

task.spawn(function()
	if player then
		player.AttributeChanged:Connect(function()
			BoutiqueStateClient.Changed:Fire()
		end)
	end
	BoutiqueStateClient.Changed:Fire()
end)

return BoutiqueStateClient
