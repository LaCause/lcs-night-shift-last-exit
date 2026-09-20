--!strict
-- Textes affichés aux joueurs, en français, regroupés en un seul endroit (FR-037).
-- Ton « meme horror » : absurde et légèrement inquiétant, jamais graphique (principe VIII).
-- Les paramètres s'écrivent {nom} et sont remplacés par Strings.format.

local Log = require(script.Parent.Util.Log)

local log = Log.new("Strings")

local TEXTS: { [string]: string } = {
	-- Phases (HUD)
	["Phase.Waiting"] = "En attente d'employés",
	["Phase.Countdown"] = "Ouverture imminente",
	["Phase.Day"] = "Jour {night}",
	["Phase.Night"] = "Nuit {night}",
	["Phase.Escape"] = "Évasion",
	["Phase.Ended"] = "Fin du service",

	-- HUD
	["Hud.NightCounter"] = "Nuit {night} / {totalNights}",
	["Hud.NightsToSurvive"] = "{totalNights} nuits à tenir",
	["Hud.CountdownPrefix"] = "Début dans {time}",
	["Hud.NoLimit"] = "sans limite",
	["Hud.Team"] = "Équipe",
	["Hud.Status.Alive"] = "en service",
	["Hud.Status.Eliminated"] = "hors service",

	-- Notifications (fil du HUD)
	["Notify.PhaseStarted.Countdown"] = "Le service commence dans {duration} s. Enfilez vos tabliers.",
	["Notify.PhaseStarted.Day"] = "Jour {night} : la forêt a l'air calme. Trop calme.",
	["Notify.PhaseStarted.Night"] = "Nuit {night} / {totalNights} : le drive-thru s'allume tout seul.",
	["Notify.PhaseStarted.Escape"] = "Dernière nuit tenue. Le vieux bus attend… peut-être.",
	["Notify.PlayerJoined"] = "{name} a pointé au travail.",
	["Notify.PlayerLeft"] = "{name} a quitté son poste sans prévenir.",
	["Notify.StatusChanged.Eliminated"] = "{name} est hors service.",
	["Notify.StatusChanged.Alive"] = "{name} reprend du service.",
	["Notify.MatchEnded.Victory"] = "Victoire ! Le dernier service est bouclé.",
	["Notify.MatchEnded.Defeat"] = "Défaite. Le restaurant a baissé le rideau.",

	-- Écran de fin
	["End.Victory"] = "Victoire",
	["End.Defeat"] = "Défaite",
	["End.NightReached"] = "Nuit atteinte : {night} / {totalNights}",
	["End.NextMatch"] = "Nouveau service dans {seconds} s",

	-- Monde et interactions
	["World.SignTitle"] = "LAST EXIT",
	["World.SignSubtitle"] = "DRIVE-THRU · OUVERT 24H/24 (en théorie)",

	-- Panneau de développement (Studio uniquement)
	["Dev.Title"] = "OUTILS DEV",
	["Dev.Ping"] = "Ping",
	["Dev.NextPhase"] = "Phase suivante",
	["Dev.TestProfile"] = "Profil test on/off",
	["Dev.Victory"] = "Victoire",
	["Dev.Defeat"] = "Défaite",
	["Dev.Eliminate"] = "M'éliminer",
	["Dev.Revive"] = "Me ranimer",
	["Dev.ShowState"] = "État",
	["Dev.SampleRng"] = "Tirages",
	["Dev.VisualFallback"] = "Test visuel de secours",
	["Dev.Checklist"] = "Checklist requêtes",
	["Dev.ContextPlaceholder"] = "contexte des tirages",
	["Dev.State"] = "{phase} · nuit {night}/{totalNights} · {time} · test : {testProfile}",

	-- 002-premier-increment-jouable : ressources (noms affichés)
	["Resource.Essence"] = "Essence",
	["Resource.SuspectSteak"] = "Steak suspect",
	["Resource.RoadBread"] = "Pain de route",
	["Resource.Scrap"] = "Ferraille",

	-- Forêt et récolte
	["Forest.HarvestAction"] = "Récolter",

	-- Comptoir : dépôt au stock partagé
	["Counter.DepositAction"] = "Déposer",
	["Counter.DepositObject"] = "Stock du restaurant",

	-- Générateur
	["Generator.RefuelAction"] = "Ravitailler",
	["Generator.RefuelObject"] = "Générateur",
	["Notify.GeneratorEmpty"] = "Le générateur est à sec. Le néon s'éteint.",
	["Notify.GeneratorRefueled"] = "Le générateur repart. Le néon se rallume.",
	["Hud.Fuel"] = "Carburant",
	["Hud.SafeZone.Active"] = "Néon allumé",
	["Hud.SafeZone.Inactive"] = "Néon éteint",

	-- Cuisine et commande
	["Kitchen.PrepareAction"] = "Préparer",
	["Kitchen.PrepareObject"] = "Plan de travail",
	["Kitchen.DeliverAction"] = "Livrer",
	["Kitchen.DeliverObject"] = "Fenêtre du drive-thru",
	["Kitchen.Recipe.SuspectBurger"] = "Burger suspect",
	["Notify.OrderStarted"] = "Nouvelle commande : {recipe}. Prête avant la fin de la nuit.",
	["Notify.OrderPrepared"] = "Commande prête : {recipe}. File vers la fenêtre !",
	["Notify.OrderDelivered"] = "Commande livrée : {recipe} !",
	["Notify.OrderFailed"] = "Commande manquée : {recipe}. Quelque chose approche…",
	["Hud.Order.Status.Pending"] = "en attente",
	["Hud.Order.Status.Preparing"] = "en cuisson",
	["Hud.Order.Status.Prepared"] = "prête à livrer",
	["Hud.Order.Status.Delivered"] = "livrée",
	["Hud.Order.Status.Failed"] = "manquée",

	-- Ennemi et santé
	["Notify.EnemyHit"] = "Une présence vous a touché dans le noir.",
	["Hud.Health"] = "Santé",

	-- 006-monnaie-jetons-fidelite : monnaie persistante
	["Hud.Currency"] = "Jetons fidélité",

	-- Panneau de développement, ajouts 002-premier-increment-jouable
	["Dev.GiveResources"] = "Ressources +1",
	["Dev.OrderDeliver"] = "Commande réussie",
	["Dev.OrderFail"] = "Commande échouée",
	["Dev.SpawnEnemy"] = "Invoquer l'ennemi",
	["Dev.ShowGameplayState"] = "État du gameplay",

	-- 003-bus-evasion : bus, réparation et départ.
	["Bus.RepairAction"] = "Déposer",
	["Bus.RepairObject"] = "Bus à réparer",
	["Bus.DepartAction"] = "Partir",
	["Bus.DepartObject"] = "Bus réparé",
	["Notify.ScrapDeposited"] = "Ferraille déposée : {amount}.",
	["Notify.BusRepaired"] = "Le bus est réparé. La sortie est possible.",
	["Hud.Bus.Progress"] = "Bus : {deposited} / {required} ferraille",
	["Hud.Bus.Repaired"] = "Bus réparé — en route !",

	-- Panneau de développement, ajouts 003-bus-evasion
	["Dev.RepairBus"] = "Réparer le bus",

	-- 004-sac-collecte : sac de portage, visée au pointeur et déplacement d'objets.
	["Bag.LittleBag"] = "Petit sac",
	["Hud.Bag"] = "Sac : {used}/{capacity}",
	["Pointer.Collect"] = "[F] Ramasser {resource}",
	["Pointer.Carry"] = "Clic maintenu : déplacer",
	["Pointer.BagFull"] = "Sac plein",
	["Pointer.NeedBag"] = "Équipez votre sac pour ramasser",
	["Notify.BagFull"] = "Sac plein ({capacity}) : videz-le au comptoir avant de ramasser.",
	-- Ne compte plus que ce qui atterrit réellement au sol (un dépôt automatique a sa propre
	-- confirmation) : texte agnostique du nombre, valable pour 1 comme pour tout le sac
	-- (005-depot-intelligent-sac, research R8).
	["Notify.BagDropped"] = "Au sol : {amount} objet(s). Ils n'attendront pas éternellement.",
	-- 005-depot-intelligent-sac : la touche distingue désormais pression brève (un objet) et
	-- maintien (tout le sac).
	["Hud.Bag.Drop"] = "[G] lâcher · maintenir : tout vider",

	-- Panneau de développement, ajouts 004-sac-collecte
	["Dev.FillBag"] = "Remplir le sac",
	["Dev.EmptyBag"] = "Vider le sac",
}

local warned: { [string]: boolean } = {}

local Strings = {}

function Strings.has(key: string): boolean
	return TEXTS[key] ~= nil
end

function Strings.format(key: string, params: { [string]: any }?): string
	local template = TEXTS[key]
	if template == nil then
		if not warned[key] then
			warned[key] = true
			log:warn("Texte manquant : %s", key)
		end
		return key
	end
	if params == nil then
		return template
	end
	local values = params
	local result = string.gsub(template, "{(%w+)}", function(name: string): string
		local value = values[name]
		if value == nil then
			return "{" .. name .. "}"
		end
		return tostring(value)
	end)
	return result
end

return table.freeze(Strings)
