--!strict
-- Table statique du catalogue de boutique (008-boutique-persistance, data-model.md, research R2).
-- Même patron que Kitchen/Recipes.luau et Assets/Catalog.luau : ce module ne contient que des
-- données, jamais modifiées à l'exécution — les prix et effets d'un objet définissent l'objet
-- lui-même, ce ne sont pas des valeurs d'équilibrage globales (contracts/config.md).

export type Category = "Cosmetic" | "Advantage"

export type Item = {
	Id: string,
	Category: Category,
	Slot: string?, -- emplacement visuel, uniquement pour un objet Cosmetic
	Price: number,
	NameKey: string,
	DescriptionKey: string,
	Effect: string?, -- identifiant reconnu par BoutiqueService, uniquement pour un objet Advantage
	Color: Color3?, -- couleur appliquée par le client, uniquement pour un objet Cosmetic (research R5)
}

local Catalog: { Item } = {
	{
		Id = "BagTintRed",
		Category = "Cosmetic",
		Slot = "Bag",
		Price = 50,
		NameKey = "Boutique.Item.BagTintRed",
		DescriptionKey = "Boutique.Item.BagTintRed.Desc",
		Color = Color3.fromRGB(200, 50, 50),
	},
	{
		Id = "BagTintBlue",
		Category = "Cosmetic",
		Slot = "Bag",
		Price = 50,
		NameKey = "Boutique.Item.BagTintBlue",
		DescriptionKey = "Boutique.Item.BagTintBlue.Desc",
		Color = Color3.fromRGB(60, 90, 210),
	},
	{
		Id = "BusPaintTeal",
		Category = "Cosmetic",
		Slot = "Bus",
		Price = 75,
		NameKey = "Boutique.Item.BusPaintTeal",
		DescriptionKey = "Boutique.Item.BusPaintTeal.Desc",
		Color = Color3.fromRGB(50, 160, 150),
	},
	{
		Id = "CounterGlowPink",
		Category = "Cosmetic",
		Slot = "Counter",
		Price = 60,
		NameKey = "Boutique.Item.CounterGlowPink",
		DescriptionKey = "Boutique.Item.CounterGlowPink.Desc",
		Color = Color3.fromRGB(255, 110, 190),
	},
	{
		Id = "BiggerBag",
		Category = "Advantage",
		Price = 150,
		NameKey = "Boutique.Item.BiggerBag",
		DescriptionKey = "Boutique.Item.BiggerBag.Desc",
		Effect = "BiggerBag",
	},
}

local byId: { [string]: Item } = {}
for _, item in Catalog do
	byId[item.Id] = item
end

local CatalogModule = { Items = Catalog }

function CatalogModule.find(itemId: string): Item?
	return byId[itemId]
end

return table.freeze(CatalogModule)
