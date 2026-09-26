--!strict
-- Monnaie persistante du joueur (006-monnaie-jetons-fidelite, FR-001 à FR-010). Solde individuel
-- crédité à la fin de chaque nuit survécue et au moment d'une évasion réussie ; survit à la
-- partie en cours et à un redémarrage complet du serveur (clarification 2026-09-20).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local MatchService = require(script.Parent.MatchService)
local SessionService = require(script.Parent.SessionService)

local STORE_NAME = "PlayerCurrency"

local log = Log.new("Currency")

local CurrencyService = { Name = "CurrencyService", Priority = 70 }

local store = DataStoreService:GetDataStore(STORE_NAME)

-- Vrai une fois le chargement initial d'un joueur résolu (succès ou échec définitif) : tant que
-- c'est faux, ce joueur est ignoré par tout événement de crédit, pour ne jamais laisser un
-- chargement tardif écraser un gain obtenu entre-temps (research R7).
local loaded: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return tostring(player.UserId)
end

function CurrencyService.balanceOf(player: Player): number
	local value = player:GetAttribute("Currency")
	return if typeof(value) == "number" then value else 0
end

-- Gain de la nuit `night` (1-indexé) : strictement croissant tant que NightlyGrowth > 0 (SC-002).
local function gain(night: number): number
	local base: number = Config.get("Currency", "NightlyBase")
	local growth: number = Config.get("Currency", "NightlyGrowth")
	return base + growth * (night - 1)
end

-- Bonus versé une fois, au moment d'une évasion réussie, proportionnel aux nuits survécues.
local function escapeBonus(nightsSurvived: number): number
	local perNight: number = Config.get("Currency", "EscapeBonusPerNight")
	return perNight * nightsSurvived
end

-- Exécute `attempt` jusqu'à `Currency.SaveRetryAttempts` fois (chaque essai protégé par son
-- propre `pcall`), espacées de `Currency.SaveRetryDelay` secondes, jusqu'au premier succès.
-- Renvoie `(true, résultat)` au premier succès, ou `(false, dernière erreur)` si toutes les
-- tentatives échouent — jamais bloquant au-delà de ce nombre borné (research R8).
local function withRetry(attempt: () -> any): (boolean, any)
	local attempts: number = Config.get("Currency", "SaveRetryAttempts")
	local delay: number = Config.get("Currency", "SaveRetryDelay")
	local lastError: any = nil
	for try = 1, attempts do
		local ok, result = pcall(attempt)
		if ok then
			return true, result
		end
		lastError = result
		if try < attempts then
			task.wait(delay)
		end
	end
	return false, lastError
end

-- Écriture protégée par nouvelle(s) tentative(s) (research R8) ; part en arrière-plan, ne bloque
-- jamais l'appelant (research R6).
local function save(player: Player)
	local balance = CurrencyService.balanceOf(player)
	task.spawn(function()
		local ok, err = withRetry(function()
			store:SetAsync(keyFor(player), balance)
		end)
		if not ok then
			log:error(
				"Écriture du solde de %s en échec après nouvelle(s) tentative(s) : %s",
				player.Name,
				tostring(err)
			)
		end
	end)
end

-- Débite `amount` si le solde le permet (008-boutique-persistance, research R8) : décrémente
-- l'attribut Currency et réutilise `save` déjà existante, sans changer sa politique de nouvelle(s)
-- tentative(s). Ne fait rien et renvoie false si le solde est insuffisant — CurrencyService reste
-- l'unique écrivain de l'attribut Currency (principe III).
function CurrencyService.spend(player: Player, amount: number): boolean
	if CurrencyService.balanceOf(player) < amount then
		return false
	end
	player:SetAttribute("Currency", CurrencyService.balanceOf(player) - amount)
	save(player)
	return true
end

-- Crédite `amount` à chaque joueur présent (`SessionService.all()`, sans distinction de statut :
-- un joueur en attente de réapparition fait toujours partie de la partie à cet instant) dont le
-- chargement initial est résolu.
local function creditAll(amount: number)
	for _, session in SessionService.all() do
		local player = session.Player
		if loaded[player] then
			player:SetAttribute("Currency", CurrencyService.balanceOf(player) + amount)
			save(player)
		end
	end
end

-- Chargement protégé par nouvelle(s) tentative(s) (research R8) : ne pose l'attribut qu'une fois
-- résolu, succès ou échec définitif (research R7 — jamais un 0 par défaut immédiat, qui risquerait
-- d'écraser un gain crédité pendant le chargement).
local function loadPlayer(player: Player)
	local ok, result = withRetry(function()
		return store:GetAsync(keyFor(player))
	end)
	local balance = 0
	if ok and typeof(result) == "number" then
		balance = result
	elseif not ok then
		log:error(
			"Chargement du solde de %s en échec après nouvelle(s) tentative(s) : %s",
			player.Name,
			tostring(result)
		)
	end
	if player.Parent == nil then
		-- Le joueur est parti pendant le chargement asynchrone : ne rien poser, InventoryService
		-- et consorts n'attendent déjà plus rien de ce joueur.
		return
	end
	player:SetAttribute("Currency", balance)
	loaded[player] = true
end

function CurrencyService.Init()
	SessionService.PlayerJoined:Connect(function(player: Player)
		task.spawn(loadPlayer, player)
	end)
	SessionService.PlayerLeft:Connect(function(player: Player)
		loaded[player] = nil
	end)
	MatchService.PhaseEnded:Connect(function(previousPhase, previousNight: number)
		-- `enterPhase` pose la nouvelle phase AVANT de déclencher ce signal (MatchService.luau) :
		-- `getPhase()` reflète donc déjà la phase suivante ici. Une transition vers "Ended" ne
		-- vient jamais d'une progression naturelle (`advance`), seulement de `endMatch` (Victoire
		-- OU Défaite) — la nuit en cours a alors été interrompue, pas terminée, et ne doit rien
		-- rapporter (FR-002, Edge Cases : « nuit non terminée au moment de la défaite »).
		if previousPhase == "Night" and MatchService.getPhase() ~= "Ended" then
			creditAll(gain(previousNight))
		end
	end)
	MatchService.MatchEnded:Connect(function(result, night: number)
		-- Une Défaite ne déclenche rien ici : l'absence de bonus est déjà le comportement correct
		-- (FR-006), les gains nocturnes ayant chacun déjà été crédités au fil de l'eau (research R3).
		if result == "Victory" then
			creditAll(escapeBonus(night))
		end
	end)
	log:info("Monnaie prête (DataStore %s)", STORE_NAME)
end

return CurrencyService
