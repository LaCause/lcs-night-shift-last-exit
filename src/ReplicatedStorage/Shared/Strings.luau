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
	["Notify.BellRang"] = "{name} a sonné. Personne n'est venu.",
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
	["Bell.Action"] = "Sonner",
	["Bell.Object"] = "Sonnette",

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
