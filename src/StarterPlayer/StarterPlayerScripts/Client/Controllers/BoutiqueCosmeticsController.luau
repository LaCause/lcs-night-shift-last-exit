--!strict
-- Application visuelle des cosmétiques actifs (008-boutique-persistance, US1/US2, research R5).
-- Purement client : une recoloration de pièces déjà construites, appliquée seulement au rendu
-- local de ce joueur — jamais renvoyée au serveur ni aux autres clients (principe III ; c'est
-- ainsi que la spec garde les cosmétiques "personnels", Assumptions). Aucun nouvel asset
-- (principe VIII).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Catalog = require(Shared:WaitForChild("Boutique"):WaitForChild("Catalog") :: ModuleScript)
local BoutiqueStateClient = require(ClientFolder:WaitForChild("BoutiqueStateClient") :: ModuleScript)

local WAIT_TIMEOUT = 30

local BoutiqueCosmeticsController = { Name = "BoutiqueCosmeticsController", Priority = 61 }

local player = Players.LocalPlayer

local function colorFor(slot: string): Color3?
	local state = BoutiqueStateClient.get()
	local itemId = state.active[slot]
	if itemId == nil or itemId == "" then
		return nil
	end
	local item = Catalog.find(itemId)
	return if item then item.Color else nil
end

-- Le sac est l'unique Tool du jeu (BagService.buildTool) : toute pièce (Handle et pièces soudées)
-- reprend la même teinte, où que le Tool se trouve (sac au sol du Backpack ou équipé au
-- personnage).
local function applyBagColor()
	local color = colorFor("Bag")
	if color == nil then
		return
	end
	local function tint(container: Instance?)
		if container == nil then
			return
		end
		local tool = container:FindFirstChildOfClass("Tool")
		if tool == nil then
			return
		end
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	tint(backpack)
	tint(player.Character)
end

local function applyBusColor()
	local color = colorFor("Bus")
	if color == nil then
		return
	end
	local world = workspace:FindFirstChild("World")
	local bus = if world then world:FindFirstChild("Bus") else nil
	local body = if bus then bus:FindFirstChild("Body") else nil
	if body and body:IsA("BasePart") then
		body.Color = color
	end
end

local function applyCounterColor()
	local color = colorFor("Counter")
	if color == nil then
		return
	end
	local world = workspace:FindFirstChild("World")
	local restaurant = if world then world:FindFirstChild("Restaurant") else nil
	local top = if restaurant then restaurant:FindFirstChild("CounterTop") else nil
	if top and top:IsA("BasePart") then
		top.Color = color
	end
end

local function refreshAll()
	applyBagColor()
	applyBusColor()
	applyCounterColor()
end

function BoutiqueCosmeticsController.Start()
	local world = workspace:WaitForChild("World", WAIT_TIMEOUT)
	local backpack = player:WaitForChild("Backpack", WAIT_TIMEOUT)

	BoutiqueStateClient.Changed:Connect(refreshAll)
	if backpack then
		backpack.ChildAdded:Connect(function()
			refreshAll()
		end)
	end
	player.CharacterAdded:Connect(function(character: Model)
		character.ChildAdded:Connect(function()
			refreshAll()
		end)
		refreshAll()
	end)

	if world == nil then
		return
	end
	refreshAll()
end

return BoutiqueCosmeticsController
