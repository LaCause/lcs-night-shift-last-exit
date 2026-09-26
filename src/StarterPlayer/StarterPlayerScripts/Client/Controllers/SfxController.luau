--!strict
-- Sons courts sur les notifications de gameplay (002-premier-increment-jouable). Purement local :
-- une notification par joueur (récolte, dépôt, ravitaillement) ou diffusée (commande, générateur,
-- ennemi) déclenche un son, jamais l'inverse — le serveur ne sait rien de l'audio.
--
-- Les identifiants "rbxasset://sounds/..." sont les sons intégrés au moteur Roblox (aucun asset
-- externe, donc rien à publier ni à faire approuver) ; vérifiés chargeables en jeu avant usage.
-- `assetName` (optionnel) pointe vers un Sound du marketplace inséré manuellement dans
-- ReplicatedStorage.Assets (même principe que ModelName dans Catalog.luau/VisualService : utilisé
-- s'il est présent, sinon repli sur `id`, jamais un plantage — FR-041).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetClient = require(Shared:WaitForChild("Client"):WaitForChild("NetClient") :: ModuleScript)

type SfxDef = { id: string, assetName: string?, volume: number, pitchMin: number?, pitchMax: number? }

local SFX: { [string]: SfxDef } = {
	-- Retour personnel, fréquent : volume bas pour ne pas fatiguer l'oreille.
	ResourceHarvested = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.32,
		pitchMin = 0.95,
		pitchMax = 1.1,
	},
	ResourceDeposited = { id = "rbxasset://sounds/snap.mp3", volume = 0.38, pitchMin = 0.95, pitchMax = 1.05 },
	GeneratorFueled = { id = "rbxasset://sounds/switch.wav", volume = 0.4 },
	ScrapDeposited = { id = "rbxasset://sounds/snap.mp3", volume = 0.38, pitchMin = 0.8, pitchMax = 0.9 },
	-- 004-sac-collecte : ramassage refusé, sac plein (retour personnel, jamais diffusé).
	BagFull = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.4, pitchMin = 0.9, pitchMax = 0.95 },
	-- Sac vidé au sol : volontairement sans variation de hauteur, le geste étant unique et net.
	BagDropped = { id = "rbxasset://sounds/snap.mp3", volume = 0.45 },
	-- 009-craft-etabli : objet fabriqué, trousse consommée (plus aigu), trousse refusée à santé pleine.
	ItemCrafted = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	HealKitUsed = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.45, pitchMin = 1.1, pitchMax = 1.2 },
	HealKitUseless = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.35, pitchMin = 0.9, pitchMax = 0.95 },
	-- 010-coin-stockage : rangement refusé, stock plein — même son que le refus de sac plein.
	StorageFull = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.4, pitchMin = 0.9, pitchMax = 0.95 },

	-- Retour d'équipe, occasionnel : un peu plus présent.
	OrderStarted = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	-- Début de cuisson (5 s au plan de travail) : distinct du son de fin (OrderPrepared). Le
	-- marketplace (FryingFoodSound) prime s'il est présent, sinon repli sur le son intégré.
	OrderPreparing = { id = "rbxasset://sounds/switch.wav", assetName = "FryingFoodSound", volume = 0.45 },
	OrderPrepared = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	OrderDelivered = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.55 },
	OrderFailed = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5, pitchMin = 0.82, pitchMax = 0.88 },
	GeneratorEmpty = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.4, pitchMin = 0.82, pitchMax = 0.88 },
	GeneratorRefueled = { id = "rbxasset://sounds/switch.wav", volume = 0.5 },
	BusRepaired = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.55 },

	-- Contact ennemi (FR-018) : accompagne le flash rouge d'EnemyEffectController.
	EnemyHit = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitchMin = 0.68, pitchMax = 0.78 },
}

local function resolveSoundId(def: SfxDef): string
	local assetName = def.assetName
	if assetName ~= nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local source = if assets then assets:FindFirstChild(assetName) else nil
		if source ~= nil and source:IsA("Sound") and source.SoundId ~= "" then
			return source.SoundId
		end
	end
	return def.id
end

local function play(def: SfxDef)
	local sound = Instance.new("Sound")
	sound.SoundId = resolveSoundId(def)
	sound.Volume = def.volume
	if def.pitchMin and def.pitchMax then
		sound.PlaybackSpeed = def.pitchMin + math.random() * (def.pitchMax - def.pitchMin)
	end
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	-- Filet de sécurité si l'asset ne se charge jamais (Ended ne se déclenche pas) : Sound ne fait
	-- pas de bruit tout seul, mais on évite d'accumuler des instances orphelines dans SoundService.
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local SfxController = { Name = "SfxController", Priority = 56 }

function SfxController.Start()
	for kind, def in SFX do
		NetClient.onNotify(kind, function()
			play(def)
		end)
	end
end

return SfxController
