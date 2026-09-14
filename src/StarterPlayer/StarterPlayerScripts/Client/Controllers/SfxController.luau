--!strict
-- Sons courts sur les notifications de gameplay (002-premier-increment-jouable). Purement local :
-- une notification par joueur (récolte, dépôt, ravitaillement) ou diffusée (commande, générateur,
-- ennemi) déclenche un son, jamais l'inverse — le serveur ne sait rien de l'audio.
--
-- Les identifiants "rbxasset://sounds/..." sont les sons intégrés au moteur Roblox (aucun asset
-- externe, donc rien à publier ni à faire approuver) ; vérifiés chargeables en jeu avant usage.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NetClient = require(Shared:WaitForChild("Client"):WaitForChild("NetClient") :: ModuleScript)

type SfxDef = { id: string, volume: number, pitchMin: number?, pitchMax: number? }

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

	-- Retour d'équipe, occasionnel : un peu plus présent.
	OrderStarted = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	OrderPrepared = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	OrderDelivered = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.55 },
	OrderFailed = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5, pitchMin = 0.82, pitchMax = 0.88 },
	GeneratorEmpty = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.4, pitchMin = 0.82, pitchMax = 0.88 },
	GeneratorRefueled = { id = "rbxasset://sounds/switch.wav", volume = 0.5 },

	-- Contact ennemi (FR-018) : accompagne le flash rouge d'EnemyEffectController.
	EnemyHit = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitchMin = 0.68, pitchMax = 0.78 },
}

local function play(def: SfxDef)
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
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
