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

local PLAYABLE = { "Countdown", "Day", "Night", "Escape" }
local ACTIVE = { "Day", "Night", "Escape" }
local NOT_WAITING = { "Countdown", "Day", "Night", "Escape", "Ended" }
local EMPTY = Validate.object({})

local NIGHT_ONLY = { "Night" }

local intents: { [string]: IntentDecl } = {
	RingBell = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Bell.Range" },
	},

	-- 002-premier-increment-jouable (contracts/network.md).
	HarvestResource = {
		-- Clé "target" (et non "node") : InteractionController envoie {target = ...} pour toute
		-- invite de proximité, quelle que soit l'intention (research R8).
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Forest.HarvestRange" }, -- résolu par ForestService.findNode
	},
	-- Ces quatre intentions visent chacune un point de référence fixe unique ; le schéma reste
	-- un `target` générique (comme RingBell) et le gestionnaire vérifie l'identifiant exact
	-- (défense en profondeur, même motif que BellService).
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
		"BellRang",
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
	}),
}

return table.freeze(Remotes)
