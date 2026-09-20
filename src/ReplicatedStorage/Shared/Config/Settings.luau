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
		-- Durée de l'évasion, en secondes ; 0 = sans limite (le départ du bus déclenche la
		-- victoire directement, indépendamment de toute minuterie de phase, 003-bus-evasion).
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
		-- Santé au début de chaque partie (002-premier-increment-jouable).
		MaxHealth = { value = 100, default = 100, min = 10, max = 500, kind = "integer" },
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

	Ui = {
		-- Durée d'affichage d'une notification, en secondes.
		NotificationLifetime = { value = 8, default = 8, min = 2, max = 30 },
		-- Nombre de notifications visibles à la fois.
		NotificationMax = { value = 5, default = 5, min = 1, max = 10, kind = "integer" },
		-- Délai avant disparition d'une carte de commande terminée (livrée/ratée), en secondes.
		OrderCardLinger = { value = 2.5, default = 2.5, min = 0, max = 10 },
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

	-- Décor statique du monde : construit une seule fois au démarrage du serveur (WorldService),
	-- jamais régénéré par partie contrairement à la forêt — c'est de l'habillage, pas du gameplay.
	World = {
		-- Nombre d'arbres plantés autour du restaurant.
		TreeCount = { value = 60, default = 60, min = 0, max = 300, kind = "integer" },
		-- Distance minimale au centre, en studs : reste hors du complexe du restaurant (mêmes
		-- proportions que Forest.AreaMinRadius, qui protège déjà cette zone).
		TreeMinRadius = { value = 40, default = 40, min = 10, max = 200 },
		-- Distance maximale au centre, en studs : un peu au-delà de Forest.AreaMaxRadius, pour
		-- que le décor déborde légèrement de la zone de récolte.
		TreeMaxRadius = { value = 170, default = 170, min = 20, max = 300 },
		-- Distance minimale à tout point de référence (Bus, enseigne néon, etc.), en studs : évite
		-- qu'un arbre pousse à travers un poste ou un décor existant.
		TreeExclusionRadius = { value = 14, default = 14, min = 4, max = 40 },
	},

	-- 002-premier-increment-jouable : forêt et points de ressource.
	Forest = {
		-- Nombre de nœuds générés par partie, par type de ressource.
		NodeCountEssence = { value = 8, default = 8, min = 1, max = 40, kind = "integer" },
		NodeCountSuspectSteak = { value = 8, default = 8, min = 1, max = 40, kind = "integer" },
		NodeCountRoadBread = { value = 8, default = 8, min = 1, max = 40, kind = "integer" },
		-- 003-bus-evasion : nœuds de ferraille.
		NodeCountScrap = { value = 8, default = 8, min = 1, max = 40, kind = "integer" },
		-- Distance au centre du restaurant, en studs.
		AreaMinRadius = { value = 40, default = 40, min = 20, max = 100 },
		AreaMaxRadius = { value = 150, default = 150, min = 60, max = 400 },
		-- Portée de récolte d'un nœud, en studs.
		HarvestRange = { value = 8, default = 8, min = 4, max = 20 },
		-- Délai avant qu'un nœud récolté redevienne disponible, en secondes.
		RespawnDelay = { value = 90, default = 90, min = 10, max = 600, test = 15 },
	},

	-- 002-premier-increment-jouable : générateur, néon et zone de sécurité.
	Generator = {
		-- Niveau maximal de carburant.
		Capacity = { value = 100, default = 100, min = 10, max = 1000 },
		-- Niveau au début de chaque partie.
		InitialFuel = { value = 60, default = 60, min = 0, max = 1000 },
		-- Consommation par seconde pendant une phase active (Jour/Nuit/Évasion).
		DrainPerSecond = { value = 0.2, default = 0.2, min = 0, max = 10, test = 2 },
		-- Carburant ajouté par unité d'essence déposée.
		FuelPerEssence = { value = 15, default = 15, min = 1, max = 200, kind = "integer" },
		-- Portée pour déposer de l'essence, en studs.
		InteractRange = { value = 8, default = 8, min = 4, max = 20 },
		-- Rayon de la zone de sécurité autour de SafeZoneCenter, en studs.
		SafeZoneRadius = { value = 20, default = 20, min = 5, max = 100 },
	},

	-- 002-premier-increment-jouable : préparation et livraison de la commande.
	Kitchen = {
		-- Portée pour préparer la commande au plan de travail, en studs.
		PrepareRange = { value = 8, default = 8, min = 4, max = 20 },
		-- Portée pour livrer à la fenêtre du drive-thru, en studs.
		DeliverRange = { value = 8, default = 8, min = 4, max = 20 },
		-- Durée de la cuisson au plan de travail, en secondes (statut "Preparing").
		PrepareDuration = { value = 5, default = 5, min = 1, max = 60, test = 2 },
	},

	-- 002-premier-increment-jouable : ennemi apparu après une commande en échec.
	Enemy = {
		-- Dégâts infligés par contact.
		ContactDamage = { value = 20, default = 20, min = 1, max = 100 },
		-- Distance de contact, en studs.
		ContactRange = { value = 5, default = 5, min = 1, max = 20 },
		-- Délai minimal entre deux contacts sur un même joueur, en secondes.
		ContactCooldown = { value = 1.5, default = 1.5, min = 0.2, max = 10 },
		-- Vitesse de déplacement, en studs par seconde.
		MoveSpeed = { value = 14, default = 14, min = 1, max = 50 },
		-- Fréquence de recalcul du chemin, en secondes.
		RepathInterval = { value = 1, default = 1, min = 0.2, max = 10 },
		-- Délai sans cible atteignable avant repli, en secondes.
		GiveUpDelay = { value = 12, default = 12, min = 1, max = 120, test = 5 },
		-- Durée de vie maximale avant disparition, en secondes.
		MaxLifetime = { value = 90, default = 90, min = 5, max = 600, test = 20 },
	},

	-- 003-bus-evasion : réparation du bus et départ.
	Bus = {
		-- Ferraille requise par joueur présent au début de l'Évasion, pour une réparation
		-- complète (Required = ScrapPerPlayer × effectif, figé à l'entrée en Évasion).
		ScrapPerPlayer = { value = 6, default = 6, min = 1, max = 50, kind = "integer" },
		-- Portée pour déposer de la ferraille au bus, en studs.
		InteractRange = { value = 8, default = 8, min = 4, max = 20 },
		-- Portée à laquelle chaque joueur en vie doit se trouver pour que le départ soit
		-- possible, en studs (plus large que InteractRange : le bus mesure 22 studs de long).
		DepartureRange = { value = 15, default = 15, min = 5, max = 40 },
	},

	-- 004-sac-collecte : sac de portage et manipulation des objets à la souris.
	Bag = {
		-- Type de sac attribué à un joueur qui rejoint la partie.
		DefaultType = { value = "LittleBag", default = "LittleBag", choices = { "LittleBag" } },
		-- Contenance totale du sac, toutes ressources confondues. Remplace l'ancien
		-- Forest.InventoryCapacity : la contenance est une propriété du sac, pas de la forêt.
		SmallCapacity = { value = 5, default = 5, min = 1, max = 50, kind = "integer" },
		-- Distance maximale entre un joueur et l'objet qu'il déplace, en studs ; au-delà, le
		-- serveur ramène l'objet et force le relâchement.
		CarryRange = { value = 18, default = 18, min = 5, max = 40 },
		-- Période de la surveillance serveur d'un objet saisi, en secondes.
		CarryCheckInterval = { value = 0.2, default = 0.2, min = 0.05, max = 2 },
		-- Rayon du cercle sur lequel les objets lâchés du sac sont posés autour du joueur, en
		-- studs : assez près pour les reprendre d'un pas, assez loin pour ne pas les empiler.
		DropRadius = { value = 4, default = 4, min = 2, max = 12 },
		-- 005-depot-intelligent-sac : durée d'appui, en secondes, au-delà de laquelle la touche de
		-- vidage compte comme un maintien (vide tout) plutôt qu'une pression brève (un objet).
		DropHoldThreshold = { value = 0.4, default = 0.4, min = 0.15, max = 1.5 },
		-- Borne absolue des coordonnées acceptées dans ReleaseItem, en studs : garde-fou de
		-- validation, pas un réglage de jeu (la vraie contrainte est CarryRange).
		MaxCoordinate = { value = 2000, default = 2000, min = 100, max = 10000 },
		-- Fréquence du lancer de rayon du pointeur côté client, en Hz.
		PointerRefreshRate = { value = 15, default = 15, min = 5, max = 60, kind = "integer" },
	},

	-- 002-premier-increment-jouable : transition d'éclairage et de brouillard entre phases.
	Ambiance = {
		-- Durée du fondu entre l'état Jour et l'état Nuit, en secondes.
		TransitionDuration = { value = 8, default = 8, min = 1, max = 60, test = 2 },
		-- Lighting.Brightness pour chaque état.
		DayBrightness = { value = 2, default = 2, min = 0, max = 5 },
		NightBrightness = { value = 0.4, default = 0.4, min = 0, max = 5 },
		-- Lighting.FogEnd pour chaque état ; une valeur élevée = brouillard quasi absent.
		DayFogEnd = { value = 100000, default = 100000, min = 100, max = 100000, kind = "integer" },
		NightFogEnd = { value = 220, default = 220, min = 20, max = 2000, kind = "integer" },
	},
}
