--!strict
-- Fabrication à l'établi en deux phases (009-craft-etabli, contracts/server-api.md) :
--   1. choisir la recette (SelectCraftRecipe) ;
--   2. déposer ses ingrédients sur le plan de travail, puis fabriquer (CraftItem).
-- Les ingrédients se déposent soit avec la touche G près de l'établi (StationDepositService passe
-- par tryPlaceFromBag), soit en glissant un objet du monde dessus (CarryService passe par
-- tryPlaceCarried). Tout est décidé ici, en une seule passe serveur (principe III ; aucune part de
-- tirage, principe V) : le client n'affiche que l'état répliqué (CraftStateClient).
--
-- Fabriquer produit un objet (Recipe.Result) qui rejoint le sac et occupe une place, comme une
-- ressource : la trousse de soins se consomme ensuite avec UseHealKit (touche H), le bidon de
-- carburant se verse au générateur (GeneratorService.depositCanister). Le soin n'est donc plus
-- accordé à la fabrication mais à l'usage.
--
-- État par joueur, répliqué en attributs du Player comme l'inventaire (Inv_*) : CraftRecipe (id de
-- la recette choisie, "" si aucune) et Craft_<Ressource> (unités déjà posées sur l'établi). Un
-- ingrédient posé quitte le sac : il n'existe qu'à un endroit à la fois, jamais dupliqué. Une
-- recette abandonnée ou changée rend tout au sac, ou rien du tout si le sac n'a pas la place
-- (principe VI : rien ne se perd en silence).
--
-- L'invite de proximité de l'établi ne porte volontairement aucun attribut Intent/Target : elle
-- n'ouvre qu'un panneau côté client (research R5), jamais relayée par InteractionController
-- (celui-ci ignore déjà silencieusement toute invite sans Intent de type chaîne, confirmé par
-- lecture directe).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Recipes = require(Shared.Craft.Recipes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ForestService = require(script.Parent.ForestService)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local SessionService = require(script.Parent.SessionService)
local WorldService = require(script.Parent.WorldService)

type ResourceType = Types.ResourceType
type PlayerStatus = Types.PlayerStatus

local WORKBENCH_ID = "Workbench"

-- Mêmes ressources que l'inventaire personnel (InventoryService.ALL_RESOURCE_TYPES).
local RESOURCE_TYPES: { ResourceType } = { "Essence", "SuspectSteak", "RoadBread", "Scrap" }

local log = Log.new("Craft")

local CraftService = { Name = "CraftService", Priority = 53 }

-- Santé maximale courante du joueur : attribut répliqué écrit par HealthService, jamais requis
-- directement (même précaution que InventoryService.bagCapacity vis-à-vis de BagService,
-- research R6 — éviter toute dépendance circulaire pour une simple lecture de plafond).
local function maxHealthOf(player: Player): number
	local value = player:GetAttribute("MaxHealth")
	if typeof(value) == "number" then
		return value
	end
	return Config.get("Players", "MaxHealth")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function placedKey(resourceType: ResourceType): string
	return `Craft_{resourceType}`
end

local function placedOf(player: Player, resourceType: ResourceType): number
	local value = player:GetAttribute(placedKey(resourceType))
	return if typeof(value) == "number" then value else 0
end

local function placedTotal(player: Player): number
	local total = 0
	for _, resourceType in RESOURCE_TYPES do
		total += placedOf(player, resourceType)
	end
	return total
end

local function selectedRecipe(player: Player): Recipes.Recipe?
	local id = player:GetAttribute("CraftRecipe")
	if typeof(id) ~= "string" then
		return nil
	end
	return Recipes.find(id)
end

-- Unités de `resourceType` que la recette attend encore ; 0 ou moins si elle n'en veut pas ou plus.
local function stillNeeded(player: Player, recipe: Recipes.Recipe, resourceType: ResourceType): number
	local required = recipe.Ingredients[resourceType] or 0
	return required - placedOf(player, resourceType)
end

local function isComplete(player: Player, recipe: Recipes.Recipe): boolean
	for resourceType in recipe.Ingredients do
		if stillNeeded(player, recipe, resourceType) > 0 then
			return false
		end
	end
	return true
end

local function addPlaced(player: Player, resourceType: ResourceType)
	player:SetAttribute(placedKey(resourceType), placedOf(player, resourceType) + 1)
end

local function clearPlaced(player: Player)
	for _, resourceType in RESOURCE_TYPES do
		player:SetAttribute(placedKey(resourceType), 0)
	end
end

local function resetPlayer(player: Player)
	clearPlaced(player)
	player:SetAttribute("CraftRecipe", "")
end

-- Rend tout ce qui est posé sur l'établi au sac, en tout ou rien : si le sac ne peut pas tout
-- reprendre, rien ne bouge et l'appelant refuse (l'état de l'établi reste cohérent).
local function refund(player: Player): boolean
	local total = placedTotal(player)
	if total == 0 then
		return true
	end
	if not InventoryService.canAddPersonal(player, total) then
		return false
	end
	for _, resourceType in RESOURCE_TYPES do
		local count = placedOf(player, resourceType)
		if count > 0 then
			InventoryService.addPersonal(player, resourceType, count)
		end
	end
	clearPlaced(player)
	return true
end

-- Le pipeline ne renvoie jamais un refus au client (il les journalise seulement) : sans cette
-- notification, un retour refusé faute de place resterait sans explication (même procédé que
-- ForestService pour la récolte).
local function notifyBagFull(player: Player)
	local capacity = player:GetAttribute("BagCapacity")
	NotifyService.send(player, "BagFull", { capacity = if typeof(capacity) == "number" then capacity else 0 })
end

local function consumePlaced(player: Player, recipe: Recipes.Recipe)
	for resourceType, amount in recipe.Ingredients do
		player:SetAttribute(placedKey(resourceType), placedOf(player, resourceType) - amount)
	end
end

local function nearWorkbench(position: Vector3): boolean
	local bench = WorldService.refPoint(WORKBENCH_ID)
	if bench == nil then
		return false
	end
	return (position - bench.Position).Magnitude <= Config.get("Craft", "InteractRange")
end

-- Pose 1 unité du sac sur l'établi, si le joueur en est proche et que sa recette en attend encore
-- (touche G, StationDepositService). Renvoie false sans avoir touché le sac dans tous les autres
-- cas : l'appelant garde alors le geste habituel (poste compatible, sinon sol).
function CraftService.tryPlaceFromBag(player: Player, resourceType: ResourceType): boolean
	local root = rootOf(player)
	if root == nil or not nearWorkbench(root.Position) then
		return false
	end
	local recipe = selectedRecipe(player)
	if recipe == nil or stillNeeded(player, recipe, resourceType) <= 0 then
		return false
	end
	if InventoryService.depositResource(player, resourceType, 1) <= 0 then
		return false
	end
	addPlaced(player, resourceType)
	-- Un dépôt automatique a sa propre confirmation sonore (voir BagService.handleDrop).
	NotifyService.send(player, "ResourceDeposited", { amount = 1 })
	return true
end

-- Consomme un objet du monde relâché sur l'établi (glisser-déposer à la souris, CarryService),
-- si sa recette en attend encore. La portée se mesure depuis l'objet lui-même, comme les autres
-- postes de dépôt (StationDepositService). Renvoie false sans rien toucher sinon : l'objet reste
-- alors où il a été posé. `at` : position où il se posera (il peut encore tomber), sinon la sienne.
function CraftService.tryPlaceCarried(player: Player, part: BasePart, at: Vector3?): boolean
	local resourceType = part:GetAttribute("ResourceType")
	if typeof(resourceType) ~= "string" then
		return false
	end
	local recipe = selectedRecipe(player)
	if recipe == nil or stillNeeded(player, recipe, resourceType :: ResourceType) <= 0 then
		return false
	end
	if not nearWorkbench(at or part.Position) then
		return false
	end
	local consumed = ForestService.consumeNode(part)
	if consumed == nil then
		return false
	end
	addPlaced(player, consumed)
	NotifyService.send(player, "ResourceDeposited", { amount = 1 })
	return true
end

local function buildCraftPrompt()
	local found = WorldService.refPoint(WORKBENCH_ID)
	if found == nil then
		error(`Point de référence {WORKBENCH_ID} introuvable : établi désactivé`)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CraftPrompt"
	prompt.ActionText = Strings.format("Craft.InteractAction")
	prompt.ObjectText = Strings.format("Craft.InteractObject")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.get("Craft", "InteractRange")
	prompt.RequiresLineOfSight = false
	-- Volontairement sans attribut Intent/Target (research R5) : cette invite n'ouvre qu'un
	-- panneau localement côté client, jamais relayée par InteractionController.
	prompt.Parent = found
end

function CraftService.Init()
	buildCraftPrompt()

	-- L'état de l'établi suit celui de l'inventaire : ce qui n'a pas été fabriqué est perdu à
	-- l'élimination et à chaque nouvelle partie, comme les ressources non déposées.
	SessionService.PlayerJoined:Connect(resetPlayer)
	SessionService.StatusChanged:Connect(function(player: Player, status: PlayerStatus)
		if status == "Eliminated" then
			resetPlayer(player)
		end
	end)
	MatchService.MatchStarting:Connect(function()
		for _, player in Players:GetPlayers() do
			resetPlayer(player)
		end
	end)

	-- Phase 1 : choisir la recette. Changer de recette rend d'abord les ingrédients déjà posés.
	NetService.registerIntent("SelectCraftRecipe", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WORKBENCH_ID then
				return "TargetMissing"
			end
			local recipe = Recipes.find(payload.recipeId)
			if recipe == nil then
				return "RecipeUnknown"
			end
			local current = selectedRecipe(player)
			if current ~= nil and current.Id == recipe.Id then
				return nil
			end
			if not refund(player) then
				notifyBagFull(player)
				return "InventoryFull"
			end
			player:SetAttribute("CraftRecipe", recipe.Id)
			return nil
		end,
	})

	-- Retour à la liste des recettes : abandonne la recette en cours, ingrédients rendus au sac.
	NetService.registerIntent("CancelCraft", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WORKBENCH_ID then
				return "TargetMissing"
			end
			if not refund(player) then
				notifyBagFull(player)
				return "InventoryFull"
			end
			player:SetAttribute("CraftRecipe", "")
			return nil
		end,
	})

	-- Phase 2 : fabriquer avec ce qui est posé sur l'établi. Revalide tout : recette choisie,
	-- ingrédients réellement posés (jamais ceux du sac), place pour l'objet fabriqué. L'objet
	-- rejoint le sac ; ses effets s'obtiennent ensuite en l'utilisant (UseHealKit, générateur).
	NetService.registerIntent("CraftItem", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WORKBENCH_ID then
				return "TargetMissing"
			end
			local recipe = Recipes.find(payload.recipeId)
			if recipe == nil then
				return "RecipeUnknown"
			end
			local selected = selectedRecipe(player)
			if selected == nil or selected.Id ~= recipe.Id then
				return "NoRecipeSelected"
			end
			if not isComplete(player, recipe) then
				return "InsufficientResources"
			end
			-- Les ingrédients sont sur l'établi, pas dans le sac : il faut donc une place libre
			-- pour l'objet. Sans elle, rien n'est consommé et le joueur en est prévenu.
			if not InventoryService.canAddPersonal(player, 1) then
				notifyBagFull(player)
				return "InventoryFull"
			end
			consumePlaced(player, recipe)
			InventoryService.addPersonal(player, recipe.Result, 1)
			NotifyService.send(player, "ItemCrafted", { item = Strings.format(`Resource.{recipe.Result}`) })
			log:info("%s fabrique %s", player.Name, recipe.Id)
			return nil
		end,
	})

	-- Utiliser une trousse de soins du sac (touche H). Ne vise rien : le pipeline saute ses étapes
	-- 7 à 9, donc le joueur vivant se vérifie ici. Refusée à santé pleine, la trousse reste alors
	-- dans le sac : elle ne se gaspille jamais. Un seul objet consommé par usage, et le soin est
	-- appliqué dans la même passe serveur (principe III).
	NetService.registerIntent("UseHealKit", {
		handler = function(player: Player): Types.RejectCode?
			local session = SessionService.get(player)
			if session == nil or session.Status ~= "Alive" then
				return "NoCharacter"
			end
			if not InventoryService.hasPersonal(player, { HealKit = 1 }) then
				return "InsufficientResources"
			end
			local current = HealthService.get(player)
			if current == nil or current >= maxHealthOf(player) then
				NotifyService.send(player, "HealKitUseless", {})
				return "NoBenefit"
			end
			InventoryService.consumePersonal(player, { HealKit = 1 })
			local amount: number = Config.get("Craft", "HealAmount")
			HealthService.heal(player, amount)
			NotifyService.send(player, "HealKitUsed", { amount = amount })
			log:info("%s utilise une trousse de soins", player.Name)
			return nil
		end,
	})

	log:info("Établi prêt (%d recette(s))", #Recipes.All)
end

return CraftService
