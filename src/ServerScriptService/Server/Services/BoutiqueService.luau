--!strict
-- Boutique d'objets cosmétiques et avantages de départ (008-boutique-persistance, FR-001 à
-- FR-013). Objets possédés et objet actif par emplacement, représentés par des attributs
-- individuels sur `Player` (`Owned_<Id>`, `Active_<Slot>`), exactement le même patron que
-- `Currency`/`Health`/`BagCapacity` (data-model.md). Persistance dans un second DataStore,
-- `PlayerBoutique`, indépendant de `PlayerCurrency` (research R3).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Boutique.Catalog)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)
local BagService = require(script.Parent.BagService)
local CurrencyService = require(script.Parent.CurrencyService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)
local SessionService = require(script.Parent.SessionService)

local STORE_NAME = "PlayerBoutique"

local log = Log.new("Boutique")

local BoutiqueService = { Name = "BoutiqueService", Priority = 71 }

local store = DataStoreService:GetDataStore(STORE_NAME)

-- Vrai une fois le chargement initial d'un joueur résolu (succès ou échec définitif) : tant que
-- c'est faux, tout achat de ce joueur est refusé (NotAllowed), pour ne jamais laisser un
-- chargement tardif écraser un achat obtenu entre-temps (même garde que CurrencyService, research
-- R7 de 006).
local loaded: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return tostring(player.UserId)
end

function BoutiqueService.isOwned(player: Player, itemId: string): boolean
	return player:GetAttribute(`Owned_{itemId}`) == true
end

function BoutiqueService.activeItem(player: Player, slot: string): string?
	local value = player:GetAttribute(`Active_{slot}`)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

-- Exécute `attempt` jusqu'à `Boutique.SaveRetryAttempts` fois, espacées de
-- `Boutique.SaveRetryDelay` secondes, jusqu'au premier succès (même patron générique que
-- CurrencyService.withRetry, research R3 : copié plutôt que factorisé, deux copies de dix lignes
-- n'appelant pas encore une extraction).
local function withRetry(attempt: () -> any): (boolean, any)
	local attempts: number = Config.get("Boutique", "SaveRetryAttempts")
	local delay: number = Config.get("Boutique", "SaveRetryDelay")
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

-- Recompose la forme persistée { owned, active } à partir des attributs actuels (data-model.md).
local function snapshot(player: Player): { owned: { string }, active: { [string]: string } }
	local owned: { string } = {}
	local active: { [string]: string } = {}
	for _, item in Catalog.Items do
		if BoutiqueService.isOwned(player, item.Id) then
			table.insert(owned, item.Id)
		end
	end
	for _, item in Catalog.Items do
		if item.Category == "Cosmetic" and item.Slot ~= nil then
			local slot = item.Slot :: string
			if active[slot] == nil then
				local value = BoutiqueService.activeItem(player, slot)
				if value ~= nil then
					active[slot] = value
				end
			end
		end
	end
	return { owned = owned, active = active }
end

-- Écriture protégée par nouvelle(s) tentative(s) ; part en arrière-plan, ne bloque jamais
-- l'appelant (FR-013, principe VI).
local function save(player: Player)
	local data = snapshot(player)
	task.spawn(function()
		local ok, err = withRetry(function()
			store:SetAsync(keyFor(player), data)
		end)
		if not ok then
			log:error(
				"Écriture de la boutique de %s en échec après nouvelle(s) tentative(s) : %s",
				player.Name,
				tostring(err)
			)
		end
	end)
end

-- Applique l'avantage "sac de départ agrandi" si possédé (research R6). N'a d'effet que sur les
-- attributs BagType/BagCapacity : le sac déjà en main n'est jamais changé en cours de partie
-- (BagService.setType, FR-010) — seule la prochaine apparition du personnage (respawnAll, au
-- début de la partie suivante) reprend le nouveau type.
local function applyOwnedAdvantages(player: Player)
	if BoutiqueService.isOwned(player, "BiggerBag") then
		BagService.setType(player, "MediumBag")
	end
end

-- Chargement protégé par nouvelle(s) tentative(s) : ne pose les attributs qu'une fois résolu,
-- succès ou échec définitif (repli sur un état vide — rien possédé, comportement de secours,
-- principe VI). Applique aussi tout avantage déjà possédé pour un joueur qui rejoint en cours de
-- session (data-model.md, "Avantage de départ, à la résolution du chargement").
local function loadPlayer(player: Player)
	local ok, result = withRetry(function()
		return store:GetAsync(keyFor(player))
	end)
	local owned: { string } = {}
	local active: { [string]: string } = {}
	if ok and typeof(result) == "table" then
		if typeof(result.owned) == "table" then
			owned = result.owned
		end
		if typeof(result.active) == "table" then
			active = result.active
		end
	elseif not ok then
		log:error(
			"Chargement de la boutique de %s en échec après nouvelle(s) tentative(s) : %s",
			player.Name,
			tostring(result)
		)
	end
	if player.Parent == nil then
		-- Le joueur est parti pendant le chargement asynchrone : rien à poser.
		return
	end

	local ownedSet: { [string]: boolean } = {}
	for _, id in owned do
		ownedSet[id] = true
	end
	for _, item in Catalog.Items do
		player:SetAttribute(`Owned_{item.Id}`, ownedSet[item.Id] == true)
	end
	for _, item in Catalog.Items do
		if item.Category == "Cosmetic" and item.Slot ~= nil then
			local slot = item.Slot :: string
			if player:GetAttribute(`Active_{slot}`) == nil then
				local value = active[slot]
				player:SetAttribute(`Active_{slot}`, if typeof(value) == "string" then value else "")
			end
		end
	end
	loaded[player] = true
	applyOwnedAdvantages(player)
end

function BoutiqueService.Init()
	SessionService.PlayerJoined:Connect(function(player: Player)
		task.spawn(loadPlayer, player)
	end)
	SessionService.PlayerLeft:Connect(function(player: Player)
		loaded[player] = nil
	end)
	-- Un joueur qui achète l'avantage en pleine partie n'a plus de PlayerJoined à venir : c'est
	-- donc ici, à chaque début de partie future (research, FR-008), que son avantage est repris —
	-- avant SessionService.respawnAll (appelé juste après MatchStarting par MatchService), pour
	-- que le sac reconstruit à cette apparition soit déjà le bon.
	MatchService.MatchStarting:Connect(function()
		for _, session in SessionService.all() do
			if loaded[session.Player] then
				applyOwnedAdvantages(session.Player)
			end
		end
	end)

	NetService.registerIntent("BuyItem", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			local itemId = payload.itemId :: string
			local item = Catalog.find(itemId)
			if item == nil then
				return "ItemUnknown"
			end
			if not loaded[player] then
				return "NotAllowed"
			end
			if BoutiqueService.isOwned(player, itemId) then
				return "AlreadyOwned"
			end
			if CurrencyService.balanceOf(player) < item.Price then
				return "InsufficientFunds"
			end
			if not CurrencyService.spend(player, item.Price) then
				return "InsufficientFunds"
			end
			player:SetAttribute(`Owned_{itemId}`, true)
			if item.Category == "Cosmetic" and item.Slot ~= nil then
				player:SetAttribute(`Active_{item.Slot}`, itemId)
			end
			save(player)
			log:info("%s achète %s (%d jetons)", player.Name, itemId, item.Price)
			return nil
		end,
	})

	NetService.registerIntent("SetActiveCosmetic", {
		handler = function(player: Player, payload: { [string]: any }): Types.RejectCode?
			local itemId = payload.itemId :: string
			local item = Catalog.find(itemId)
			if item == nil or item.Category ~= "Cosmetic" or item.Slot == nil then
				return "ItemUnknown"
			end
			if not BoutiqueService.isOwned(player, itemId) then
				return "NotOwned"
			end
			player:SetAttribute(`Active_{item.Slot}`, itemId)
			save(player)
			return nil
		end,
	})

	log:info("Boutique prête (DataStore %s, %d objets au catalogue)", STORE_NAME, #Catalog.Items)
end

return BoutiqueService
