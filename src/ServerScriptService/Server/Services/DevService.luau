--!strict
-- Commandes de développement, Studio uniquement (FR-042, FR-043). Elles passent par le même
-- pipeline que les actions de jeu : intentions Dev.* déclarées devOnly dans Remotes.luau, donc
-- refusées (NotAllowed) sur un serveur publié. Les résultats vont au seul demandeur (DevReport).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local EnemyService = require(script.Parent.EnemyService)
local GeneratorService = require(script.Parent.GeneratorService)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local NotifyService = require(script.Parent.NotifyService)
local OrderService = require(script.Parent.OrderService)
local SessionService = require(script.Parent.SessionService)
local VisualService = require(script.Parent.VisualService)

type CommandHandler = (player: Player, payload: { [string]: any }) -> Types.RejectCode?

-- Titre attendu par la checklist du panneau de dev (DevPanel.client.luau).
local REJECTIONS_TITLE = "Refus récents"
local RNG_MAX = 1000000

local log = Log.new("Dev")

local DevService = { Name = "DevService", Priority = 90 }

local function yesNo(value: boolean): string
	return if value then "oui" else "non"
end

function DevService.report(player: Player, title: string, lines: { string })
	NotifyService.send(player, "DevReport", { title = title, lines = lines })
end

function DevService.command(name: string, handler: CommandHandler)
	NetService.registerIntent(`Dev.{name}`, { handler = handler })
end

function DevService.Init()
	-- Sans effet : sert au test de cadence de la checklist.
	DevService.command("Ping", function()
		return nil
	end)

	DevService.command("NextPhase", function(player)
		local skipped = MatchService.skipPhase()
		DevService.report(player, "Phase suivante", {
			if skipped then `Nouvelle phase : {MatchService.getPhase()}` else "Rien à sauter",
		})
		return nil
	end)

	DevService.command("SetTestProfile", function(player, payload)
		MatchService.setTestProfile(payload.enabled)
		DevService.report(player, "Profil de test", {
			`Profil de test : {yesNo(payload.enabled)} (dès la phase suivante)`,
		})
		return nil
	end)

	DevService.command("EndMatch", function(player, payload)
		local accepted = MatchService.endMatch(payload.result, "commande de dev")
		DevService.report(player, "Fin de partie", {
			if accepted then `Résultat : {payload.result}` else "Ignorée : la partie est déjà terminée",
		})
		return nil
	end)

	DevService.command("SetStatus", function(player, payload)
		local target = player
		if payload.userId ~= nil then
			local found = Players:GetPlayerByUserId(payload.userId)
			if found == nil then
				DevService.report(player, "Statut", { `Joueur {payload.userId} introuvable` })
				return nil
			end
			target = found
		end
		SessionService.setStatus(target, payload.status)
		DevService.report(player, "Statut", { `{target.DisplayName} : {payload.status}` })
		return nil
	end)

	DevService.command("ShowState", function(player)
		local lines = {
			`Partie #{MatchService.getMatchId()} · seed {MatchService.getSeed()}`,
			`Phase {MatchService.getPhase()} · nuit {MatchService.getNight()}/{MatchService.getTotalNights()}`,
			`Profil de test : {yesNo(MatchService.isTestProfile())}`,
		}
		for _, session in SessionService.all() do
			table.insert(lines, `{session.Player.DisplayName} ({session.UserId}) : {session.Status}`)
		end
		DevService.report(player, "État de la partie", lines)
		return nil
	end)

	DevService.command("SampleRng", function(player, payload)
		local random = MatchService.rng(payload.context)
		local draws = {}
		for _ = 1, payload.count do
			table.insert(draws, tostring(random:NextInteger(1, RNG_MAX)))
		end
		DevService.report(player, `Tirages « {payload.context} »`, {
			`seed {MatchService.getSeed()}`,
			table.concat(draws, ", "),
		})
		return nil
	end)

	DevService.command("GetRejections", function(player, payload)
		local lines = {}
		for _, rejection in NetService.recentRejections(player, payload.count) do
			table.insert(lines, `{rejection.code} · {rejection.action} · {rejection.detail}`)
		end
		if #lines == 0 then
			table.insert(lines, "Aucun refus enregistré")
		end
		DevService.report(player, REJECTIONS_TITLE, lines)
		return nil
	end)

	DevService.command("TestVisualFallback", function(player)
		local model, usedFallback = VisualService.build("FallbackProbe")
		if model then
			model:Destroy()
		end
		DevService.report(player, "Visuel de secours", {
			`Modèle construit : {yesNo(model ~= nil)}`,
			`Remplaçant en primitives utilisé : {yesNo(usedFallback)}`,
		})
		return nil
	end)

	DevService.command("SpawnEnemy", function(player)
		EnemyService.spawnAt("EnemySpawn")
		DevService.report(player, "Ennemi", { "Apparition demandée à EnemySpawn" })
		return nil
	end)

	DevService.command("ForceOrderResult", function(player, payload)
		local applied = OrderService.forceResult(payload.result)
		DevService.report(player, "Commande", {
			if applied then `Résultat forcé : {payload.result}` else "Ignorée : aucune commande active",
		})
		return nil
	end)

	-- 002-premier-increment-jouable : commandes de test du gameplay.
	DevService.command("GiveResources", function(player, payload)
		local added = InventoryService.addPersonal(player, payload.resource, payload.amount)
		DevService.report(player, "Ressources", {
			if added then `+{payload.amount} {payload.resource}` else "Refusé : inventaire plein",
		})
		return nil
	end)

	DevService.command("ShowGameplayState", function(player)
		local lines = {}
		for _, resourceType in { "Essence", "SuspectSteak", "RoadBread" } do
			table.insert(lines, `{resourceType} porté : {player:GetAttribute(`Inv_{resourceType}`) or 0}`)
		end
		local stock = ReplicatedStorage:FindFirstChild("Stock")
		if stock then
			table.insert(
				lines,
				`Stock — SuspectSteak : {stock:GetAttribute("SuspectSteak") or 0}, RoadBread : {stock:GetAttribute("RoadBread") or 0}`
			)
		end
		local generatorState = ReplicatedStorage:FindFirstChild("GeneratorState")
		if generatorState then
			table.insert(
				lines,
				`Générateur — carburant : {generatorState:GetAttribute("Fuel") or 0}/{generatorState:GetAttribute("Capacity") or 0}, zone de sécurité : {yesNo(GeneratorService.isSafeZoneActive())}`
			)
		end
		local recipeId, status = OrderService.getStatus()
		table.insert(lines, `Commande — {if recipeId == "" then "aucune" else recipeId} : {if status == "" then "—" else status}`)
		table.insert(lines, `Santé : {HealthService.get(player) or 0}/{player:GetAttribute("MaxHealth") or 0}`)
		DevService.report(player, "État du gameplay", lines)
		return nil
	end)

	log:info("Commandes de développement prêtes (acceptées : %s)", yesNo(RunService:IsStudio()))
end

return DevService
