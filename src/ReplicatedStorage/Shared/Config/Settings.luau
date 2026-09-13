--!strict
-- LE fichier de réglages du jeu (contracts/config.md). C'est le seul endroit où modifier une
-- valeur d'équilibrage : on change `value` ; `default` et les bornes ne bougent qu'après revue.
--
-- Forme d'une entrée : { value, default, min?, max?, choices?, test?, kind?, maxLength? }
--   value   : valeur utilisée (modifiée par le designer)
--   default : valeur sûre, utilisée si `value` est absente ou invalide
--   test    : valeur utilisée quand le profil de test est actif (Match.TestProfile)
--   kind    : "integer" pour un nombre entier (sinon déduit de `default`)

return {
	Match = {
		-- Durée du jour, en secondes.
		DayDuration = { value = 240, default = 240, min = 10, max = 3600, test = 15 },
		-- Durée de la nuit, en secondes.
		NightDuration = { value = 300, default = 300, min = 10, max = 3600, test = 15 },
		-- Nombre de nuits à tenir avant l'évasion.
		NightCount = { value = 7, default = 7, min = 1, max = 30, kind = "integer" },
		-- Compte à rebours avant le Jour 1, en secondes.
		CountdownDuration = { value = 15, default = 15, min = 3, max = 120, test = 5 },
		-- Durée de l'écran de fin avant la nouvelle partie, en secondes.
		EndScreenDuration = { value = 15, default = 15, min = 3, max = 120, test = 5 },
		-- Durée de l'évasion, en secondes ; 0 = sans limite (définie plus tard par le bus).
		EscapeDuration = { value = 0, default = 0, min = 0, max = 3600 },
		-- Seed forcée pour rejouer une partie ; 0 = seed aléatoire à chaque partie.
		ForcedSeed = { value = 0, default = 0, min = 0, max = 2147483647, kind = "integer" },
		-- Profil de test : durées courtes (valeurs `test`) sans toucher aux valeurs de référence.
		TestProfile = { value = false, default = false },
	},

	Players = {
		-- Affichage et avertissement ; la vraie limite se règle à la publication de la place.
		MaxPlayers = { value = 6, default = 6, min = 1, max = 6, kind = "integer" },
		-- Délai de réapparition d'un joueur en vie, en secondes.
		RespawnDelay = { value = 5, default = 5, min = 0, max = 60, test = 1 },
	},

	Net = {
		-- Capacité du seau à jetons (intentions en rafale).
		IntentBurst = { value = 10, default = 10, min = 1, max = 100, kind = "integer" },
		-- Recharge du seau, en jetons par seconde.
		IntentRefillPerSecond = { value = 5, default = 5, min = 0.5, max = 50 },
		-- Longueur maximale des chaînes reçues des clients.
		MaxStringLength = { value = 64, default = 64, min = 8, max = 256, kind = "integer" },
		-- Marge de latence ajoutée aux portées, en studs.
		DistanceTolerance = { value = 3, default = 3, min = 0, max = 10 },
		-- Une ligne de journal par joueur et par motif de refus toutes les N secondes.
		RejectLogCooldown = { value = 2, default = 2, min = 0, max = 60 },
		-- Nombre de refus gardés en mémoire pour l'outil de développement.
		RejectionHistory = { value = 100, default = 100, min = 10, max = 1000, kind = "integer" },
	},

	Bell = {
		-- Portée de la sonnette, en studs.
		Range = { value = 10, default = 10, min = 4, max = 30 },
		-- Délai de réutilisation, en secondes (commun à tous les joueurs).
		Cooldown = { value = 2, default = 2, min = 0.5, max = 30 },
	},

	Ui = {
		-- Durée d'affichage d'une notification, en secondes.
		NotificationLifetime = { value = 8, default = 8, min = 2, max = 30 },
		-- Nombre de notifications visibles à la fois.
		NotificationMax = { value = 5, default = 5, min = 1, max = 10, kind = "integer" },
	},

	Visuals = {
		-- Force les remplaçants en primitives pour tous les visuels.
		PrimitivesOnly = { value = false, default = false },
	},

	Debug = {
		-- Seuil du journal : "Debug", "Info", "Warn" ou "Error".
		LogLevel = { value = "Info", default = "Info", choices = { "Debug", "Info", "Warn", "Error" } },
		-- Nom d'un système à faire échouer au démarrage (Studio uniquement), pour tester l'isolation.
		FailSystemAtInit = { value = "", default = "", maxLength = 64 },
	},
}
