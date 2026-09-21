--!strict
-- Fabrication à l'établi (009-craft-etabli, contracts/server-api.md). Un seul gestionnaire
-- d'intention (CraftItem) : recette connue, ressources personnelles suffisantes, effet non nul,
-- puis déduction et octroi de l'effet (santé ou carburant) en une seule passe serveur (principe
-- III ; aucune part de tirage, principe V).
--
-- L'invite de proximité de l'établi ne porte volontairement aucun attribut Intent/Target : elle
-- n'ouvre qu'un panneau côté client (research R5), jamais relayée par InteractionController
-- (celui-ci ignore déjà silencieusement toute invite sans Intent de type chaîne, confirmé par
-- lecture directe). La fabrication elle-même reste une intention réseau ordinaire ci-dessous.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Recipes = require(Shared.Craft.Recipes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local GeneratorService = require(script.Parent.GeneratorService)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local WorldService = require(script.Parent.WorldService)

local WORKBENCH_ID = "Workbench"

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

	NetService.registerIntent("CraftItem", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			if payload.target ~= WORKBENCH_ID then
				return "TargetMissing"
			end
			local recipe = Recipes.find(payload.recipeId)
			if recipe == nil then
				return "RecipeUnknown"
			end
			if not InventoryService.hasPersonal(player, recipe.Ingredients) then
				return "InsufficientResources"
			end

			if recipe.Effect == "Heal" then
				local current = HealthService.get(player)
				if current == nil or current >= maxHealthOf(player) then
					return "NoBenefit"
				end
				InventoryService.consumePersonal(player, recipe.Ingredients)
				HealthService.heal(player, Config.get("Craft", "HealAmount"))
			elseif recipe.Effect == "RefuelGenerator" then
				if GeneratorService.fuelRoom() <= 0 then
					return "NoBenefit"
				end
				InventoryService.consumePersonal(player, recipe.Ingredients)
				GeneratorService.deposit(Config.get("Craft", "FuelAmount"))
			end

			log:info("%s fabrique %s", player.Name, recipe.Id)
			return nil
		end,
	})

	log:info("Établi prêt (%d recette(s))", #Recipes.All)
end

return CraftService
