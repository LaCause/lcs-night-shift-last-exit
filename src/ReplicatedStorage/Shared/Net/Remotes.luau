--!strict
-- Déclaration unique des remotes et des intentions (contracts/network.md, FR-030).
-- NetService crée les remotes et valide les intentions à partir d'ici ; les services
-- n'ajoutent que leurs gestionnaires (NetService.registerIntent).

local Config = require(script.Parent.Parent.Config)
local Validate = require(script.Parent.Validate)

export type IntentDecl = {
	schema: Validate.Check,
	phases: { string }?, -- nil = toutes les phases
	target: { field: string, rangeSetting: string }?,
	devOnly: boolean?,
}

local maxString: number = Config.get("Net", "MaxStringLength")
-- Garde-fou de validation des coordonnées de ReleaseItem (004-sac-collecte, contracts/config.md).
local maxCoordinate: number = Config.get("Bag", "MaxCoordinate")

local PLAYABLE = { "Countdown", "Day", "Night", "Escape" }
local ACTIVE = { "Day", "Night", "Escape" }
local NOT_WAITING = { "Countdown", "Day", "Night", "Escape", "Ended" }
local EMPTY = Validate.object({})

local NIGHT_ONLY = { "Night" }

local intents: { [string]: IntentDecl } = {
	-- 002-premier-increment-jouable (contracts/network.md).
	HarvestResource = {
		-- Clé "target" (et non "node") : InteractionController envoie {target = ...} pour toute
		-- invite de proximité, quelle que soit l'intention (research R8).
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Forest.HarvestRange" }, -- résolu par ForestService.findNode
	},
	-- Ces quatre intentions visent chacune un point de référence fixe unique ; le schéma reste
	-- un `target` générique et le gestionnaire vérifie l'identifiant exact (défense en profondeur).
	DepositResources = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Forest.HarvestRange" },
	},
	RefuelGenerator = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Generator.InteractRange" },
	},
	PrepareOrder = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = NIGHT_ONLY,
		target = { field = "target", rangeSetting = "Kitchen.PrepareRange" },
	},
	DeliverOrder = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = NIGHT_ONLY,
		target = { field = "target", rangeSetting = "Kitchen.DeliverRange" },
	},

	-- 003-bus-evasion (contracts/network.md).
	RepairBus = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Bus.InteractRange" },
	},
	DepartBus = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = { "Escape" },
		target = { field = "target", rangeSetting = "Bus.DepartureRange" },
	},
	-- 007-nuits-optionnelles-evasion : même déclaration que DepartBus (schéma, phase, portée) —
	-- les deux options du même choix, disponibles exactement dans les mêmes conditions.
	PushNight = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = { "Escape" },
		target = { field = "target", rangeSetting = "Bus.DepartureRange" },
	},

	-- 004-sac-collecte (contracts/network.md). Ces deux intentions visent la même cible qu'un
	-- ramassage (un nœud de forêt) : elles réutilisent le résolveur dynamique existant
	-- (ForestService.findNode), sans aucune extension du pipeline. Un déplacement complet ne
	-- coûte que ces deux intentions, jamais un flux par frame (research R4).
	GrabItem = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Forest.HarvestRange" },
	},
	ReleaseItem = {
		schema = Validate.object({
			target = Validate.string(maxString),
			x = Validate.number(-maxCoordinate, maxCoordinate),
			y = Validate.number(-maxCoordinate, maxCoordinate),
			z = Validate.number(-maxCoordinate, maxCoordinate),
		}),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Bag.CarryRange" },
	},
	-- Vider le sac au sol : la seule intention de cette fonctionnalité qui ne vise rien. Sans
	-- `target`, le pipeline saute ses étapes 7 à 9 — c'est donc le gestionnaire (BagService) qui
	-- vérifie lui-même le personnage vivant, puis décide où les objets tombent.
	DropBag = {
		schema = EMPTY,
		phases = PLAYABLE,
	},
	-- 005-depot-intelligent-sac : pendant complet de DropBag pour la pression brève — même forme
	-- (aucune cible), ne retire que le dernier objet ramassé.
	DropOneItem = {
		schema = EMPTY,
		phases = PLAYABLE,
	},

	["Dev.Ping"] = { schema = EMPTY, devOnly = true },
	["Dev.NextPhase"] = { schema = EMPTY, phases = NOT_WAITING, devOnly = true },
	["Dev.SetTestProfile"] = {
		schema = Validate.object({ enabled = Validate.boolean() }),
		devOnly = true,
	},
	["Dev.EndMatch"] = {
		schema = Validate.object({ result = Validate.enum({ "Victory", "Defeat" }) }),
		phases = ACTIVE,
		devOnly = true,
	},
	["Dev.SetStatus"] = {
		schema = Validate.object({
			status = Validate.enum({ "Alive", "Eliminated" }),
			-- Les UserId sont négatifs dans les tests locaux de Studio.
			userId = Validate.optional(Validate.integer(-1e15, 1e15)),
		}),
		devOnly = true,
	},
	["Dev.ShowState"] = { schema = EMPTY, devOnly = true },
	["Dev.SampleRng"] = {
		schema = Validate.object({
			context = Validate.string(maxString),
			count = Validate.integer(1, 20),
		}),
		devOnly = true,
	},
	["Dev.GetRejections"] = {
		schema = Validate.object({ count = Validate.integer(1, 50) }),
		devOnly = true,
	},
	["Dev.TestVisualFallback"] = { schema = EMPTY, devOnly = true },

	-- 002-premier-increment-jouable (contracts/server-api.md, commandes de dev ajoutées).
	["Dev.GiveResources"] = {
		schema = Validate.object({
			-- "Scrap" ajouté par 003-bus-evasion (contracts/network.md).
			resource = Validate.enum({ "Essence", "SuspectSteak", "RoadBread", "Scrap" }),
			amount = Validate.integer(1, 50),
		}),
		devOnly = true,
	},
	["Dev.ShowGameplayState"] = { schema = EMPTY, devOnly = true },
	["Dev.ForceOrderResult"] = {
		schema = Validate.object({ result = Validate.enum({ "Delivered", "Failed" }) }),
		devOnly = true,
	},
	["Dev.SpawnEnemy"] = { schema = EMPTY, devOnly = true },

	-- 003-bus-evasion (contracts/network.md, commande de dev ajoutée).
	["Dev.RepairBus"] = { schema = EMPTY, devOnly = true },

	-- 004-sac-collecte (contracts/network.md, commandes de dev ajoutées).
	["Dev.FillBag"] = { schema = EMPTY, devOnly = true },
	["Dev.EmptyBag"] = { schema = EMPTY, devOnly = true },

	-- 008-boutique-persistance (contracts/server-api.md, research R9). Déclenchées depuis un
	-- bouton d'interface, pas une invite de proximité : aucune cible, aucune restriction de phase
	-- (achetable à tout moment, en partie ou non — FR-001).
	BuyItem = {
		schema = Validate.object({ itemId = Validate.string(maxString) }),
	},
	SetActiveCosmetic = {
		schema = Validate.object({ itemId = Validate.string(maxString) }),
	},

	-- 009-craft-etabli (contracts/server-api.md, research R2/R6) : fabrication à l'établi en deux
	-- phases — choisir la recette (SelectCraftRecipe), déposer ses ingrédients (touche G ou objet
	-- glissé sur l'établi, sans intention dédiée : DropBag/DropOneItem/ReleaseItem s'en chargent),
	-- puis fabriquer (CraftItem). Une cible fixe unique comme RepairBus/RefuelGenerator — le
	-- gestionnaire vérifie l'identifiant exact en défense en profondeur ; recipeId reste de la
	-- responsabilité du gestionnaire.
	SelectCraftRecipe = {
		schema = Validate.object({
			recipeId = Validate.string(maxString),
			target = Validate.string(maxString),
		}),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Craft.InteractRange" },
	},
	-- Abandonne la recette en cours : les ingrédients déjà posés retournent dans le sac.
	CancelCraft = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Craft.InteractRange" },
	},
	-- Consomme une trousse de soins du sac (touche H). Ne vise rien, comme DropBag : le pipeline
	-- saute ses étapes 7 à 9, c'est donc le gestionnaire (CraftService) qui vérifie le joueur vivant.
	UseHealKit = {
		schema = EMPTY,
		phases = PLAYABLE,
	},
	CraftItem = {
		schema = Validate.object({
			recipeId = Validate.string(maxString),
			target = Validate.string(maxString),
		}),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Craft.InteractRange" },
	},
}

local Remotes = {
	FolderName = "Remotes",
	Intent = "Intent",
	Notify = "Notify",
	Intents = table.freeze(intents),
	NotificationKinds = table.freeze({
		"PhaseStarted",
		"PlayerJoined",
		"PlayerLeft",
		"StatusChanged",
		"MatchEnded",
		"DevReport",
		-- 002-premier-increment-jouable (contracts/network.md).
		"GeneratorEmpty",
		"GeneratorRefueled",
		"OrderStarted",
		"OrderDelivered",
		"OrderFailed",
		"EnemyHit",
		-- Retour son/visuel léger (ciblé ou diffusé selon le cas) : ne remplace aucune de ces
		-- notifications, ne sert qu'à déclencher un son/flash côté client (SfxController,
		-- FeedbackFxController). Volontairement absentes du fil de notifications du HUD.
		"ResourceHarvested",
		"ResourceDeposited",
		"GeneratorFueled",
		"OrderPreparing",
		"OrderPrepared",
		-- 003-bus-evasion (contracts/network.md) : ScrapDeposited suit le même patron que
		-- GeneratorFueled (send, retour personnel) ; BusRepaired celui de GeneratorRefueled
		-- (broadcast, uniquement à la transition).
		"ScrapDeposited",
		"BusRepaired",
		-- 004-sac-collecte : le pipeline journalise les refus mais ne les renvoie jamais au
		-- client. Sans cette notification, un joueur au sac plein verrait sa touche rester
		-- sans effet, sans explication (research R10).
		"BagFull",
		-- Sac vidé au sol : confirme au joueur combien d'objets sont partis, le contenu du sac
		-- tombant d'un coup à zéro sans autre trace à l'écran.
		"BagDropped",
		-- 009-craft-etabli : objet fabriqué (retour personnel), trousse consommée, trousse refusée
		-- faute de bénéfice — le pipeline ne renvoie jamais ses refus au client.
		"ItemCrafted",
		"HealKitUsed",
		"HealKitUseless",
		-- 010-coin-stockage : rangement refusé, stock plein — même raison que BagFull : le
		-- pipeline ne renvoie jamais ses refus au client. Aucune intention n'est ajoutée : le stock
		-- réutilise les gestes existants (DropBag/DropOneItem, ReleaseItem, HarvestResource, GrabItem).
		"StorageFull",
	}),
}

return table.freeze(Remotes)
