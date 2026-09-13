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

local intents: { [string]: IntentDecl } = {
	RingBell = {
		schema = Validate.object({ target = Validate.string(maxString) }),
		phases = PLAYABLE,
		target = { field = "target", rangeSetting = "Bell.Range" },
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
	}),
}

return table.freeze(Remotes)
