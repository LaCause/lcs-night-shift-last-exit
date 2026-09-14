--!strict
-- Canal réseau unique (contracts/network.md) : crée les remotes et fait passer chaque intention
-- par un pipeline de validation en 10 étapes avant tout effet (principe III ; FR-030 à FR-033).
-- Aucune RemoteFunction : le serveur n'attend jamais la réponse d'un client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local RefPoints = require(Shared.World.RefPoints)
local Remotes = require(Shared.Net.Remotes)
local Types = require(Shared.Types)

type RejectCode = Types.RejectCode

export type Handler = (player: Player, payload: { [string]: any }) -> RejectCode?

-- Résolveur de cible optionnel (002-premier-increment-jouable, research R3) : remplace
-- RefPoints.find pour une cible dynamique (ex. un nœud de ressource). Doit lui-même valider le
-- type de l'identifiant et renvoyer nil si la cible n'existe pas ou n'est plus valide.
export type TargetResolver = (targetId: any) -> BasePart?

export type Rejection = {
	at: number,
	userId: number,
	action: string,
	code: RejectCode,
	detail: string,
}

type Bucket = { tokens: number, updated: number }
type Throttle = { last: number, suppressed: number }

-- Longueur maximale d'un nom d'action : constante du protocole, pas un réglage d'équilibrage.
local MAX_ACTION_LENGTH = 64

local log = Log.new("Net")
local isStudio = RunService:IsStudio()

local handlers: { [string]: Handler } = {}
local resolvers: { [string]: TargetResolver } = {}
local remotes: { [string]: RemoteEvent } = {}
local buckets: { [Player]: Bucket } = {}
local throttles: { [string]: Throttle } = {}
local history: { Rejection } = {}

local NetService = { Name = "NetService", Priority = 30 }

-- Seau à jetons par joueur : tout message reçu en consomme un, même malformé.
local function takeToken(player: Player): boolean
	local now = os.clock()
	local burst: number = Config.get("Net", "IntentBurst")
	local refill: number = Config.get("Net", "IntentRefillPerSecond")
	local bucket = buckets[player]
	if bucket == nil then
		local created = { tokens = burst, updated = now }
		buckets[player] = created
		bucket = created
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updated) * refill)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function reject(player: Player, action: string, code: RejectCode, detail: string)
	table.insert(history, {
		at = workspace:GetServerTimeNow(),
		userId = player.UserId,
		action = action,
		code = code,
		detail = detail,
	})
	local limit: number = Config.get("Net", "RejectionHistory")
	while #history > limit do
		table.remove(history, 1)
	end

	-- Journal limité : une ligne par joueur et par code toutes les Net.RejectLogCooldown secondes.
	local key = `{player.UserId}:{code}`
	local now = os.clock()
	local throttle = throttles[key]
	if throttle ~= nil and now - throttle.last < Config.get("Net", "RejectLogCooldown") then
		throttle.suppressed += 1
		return
	end
	local grouped = if throttle ~= nil and throttle.suppressed > 0
		then ` [+{throttle.suppressed} refus regroupés]`
		else ""
	throttles[key] = { last = now, suppressed = 0 }

	local line = `Refus {action} de {player.Name} ({player.UserId}) : {code} ({detail}){grouped}`
	if code == "HandlerError" then
		log:error(line)
	else
		log:warn(line)
	end
end

-- Phase lue dans l'état répliqué (écrit par MatchService) pour éviter une dépendance circulaire.
local function currentPhase(): string
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	local phase = if matchState then matchState:GetAttribute("Phase") else nil
	return if typeof(phase) == "string" then phase else "Waiting"
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function rangeFor(setting: string): number
	local domain, key = string.match(setting, "^(%w+)%.(%w+)$")
	if domain == nil or key == nil then
		error(`Réglage de portée mal formé : {setting}`)
	end
	return Config.get(domain, key)
end

local function onIntent(player: Player, action: any, payload: any)
	local label = if typeof(action) == "string"
		then string.sub(action, 1, MAX_ACTION_LENGTH)
		else `<{typeof(action)}>`

	-- 1. Cadence.
	if not takeToken(player) then
		reject(player, label, "RateLimited", "cadence dépassée")
		return
	end
	-- 2. Enveloppe.
	if typeof(action) ~= "string" or #action > MAX_ACTION_LENGTH then
		reject(player, label, "BadEnvelope", "action invalide")
		return
	end
	if payload ~= nil and typeof(payload) ~= "table" then
		reject(player, label, "BadEnvelope", `payload de type {typeof(payload)}`)
		return
	end
	-- 3. Intention déclarée.
	local declaration = Remotes.Intents[action]
	if declaration == nil then
		reject(player, label, "UnknownAction", "intention non déclarée")
		return
	end
	-- 4. Réservée au développement.
	if declaration.devOnly and not isStudio then
		reject(player, label, "NotAllowed", "réservée aux sessions de test Studio")
		return
	end
	-- 5. Schéma strict.
	local data: { [string]: any } = if payload == nil then {} else payload
	local valid, reason = declaration.schema(data)
	if not valid then
		reject(player, label, "BadPayload", reason or "payload invalide")
		return
	end
	-- 6. Phase autorisée.
	local phases = declaration.phases
	if phases ~= nil then
		local phase = currentPhase()
		if table.find(phases, phase) == nil then
			reject(player, label, "WrongPhase", `phase {phase}`)
			return
		end
	end
	-- 7 à 9. Cible : personnage vivant, cible existante, distance.
	local targetSpec = declaration.target
	if targetSpec ~= nil then
		local root = rootOf(player)
		if root == nil then
			reject(player, label, "NoCharacter", "aucun personnage vivant")
			return
		end
		local targetId = data[targetSpec.field]
		local resolve = resolvers[action]
		local target = if resolve ~= nil
			then resolve(targetId)
			elseif RefPoints.isValid(targetId) then RefPoints.find(targetId)
			else nil
		if target == nil then
			reject(player, label, "TargetMissing", `cible {tostring(targetId)}`)
			return
		end
		local range = rangeFor(targetSpec.rangeSetting) + Config.get("Net", "DistanceTolerance")
		local distance = (root.Position - target.Position).Magnitude
		if distance > range then
			reject(player, label, "TooFar", string.format("distance %.1f > %.1f", distance, range))
			return
		end
	end
	-- 10. Gestionnaire du système propriétaire.
	local handler = handlers[action]
	if handler == nil then
		reject(player, label, "UnknownAction", "aucun système ne traite cette intention")
		return
	end
	local ok, result = xpcall(handler, debug.traceback, player, data)
	if not ok then
		reject(player, label, "HandlerError", tostring(result))
	elseif result ~= nil then
		reject(player, label, result, "refusée par le système")
	end
end

-- Associe un gestionnaire à une intention déclarée dans Remotes.luau. Les métadonnées de
-- validation (schéma, phases, cible, devOnly) viennent de la déclaration, jamais d'ici.
-- `resolve` est optionnel (research R3) : fourni par le service propriétaire pour une cible
-- dynamique (ex. un nœud de ressource) ; sans lui, la cible est cherchée par RefPoints.find.
function NetService.registerIntent(name: string, definition: { handler: Handler, resolve: TargetResolver? })
	local declaration = Remotes.Intents[name]
	if declaration == nil then
		error(`Intention non déclarée dans Remotes.luau : {name}`, 2)
	end
	if handlers[name] ~= nil then
		error(`Intention déjà enregistrée : {name}`, 2)
	end
	local targetSpec = declaration.target
	if targetSpec ~= nil then
		rangeFor(targetSpec.rangeSetting) -- vérifie dès l'enregistrement que la portée existe
	end
	handlers[name] = definition.handler
	if definition.resolve ~= nil then
		resolvers[name] = definition.resolve
	end
end

function NetService.remote(name: string): RemoteEvent
	local remote = remotes[name]
	if remote == nil then
		error(`Remote {name} indisponible : NetService n'est pas initialisé`, 2)
	end
	return remote
end

-- Derniers refus d'un joueur, du plus ancien au plus récent (outil de développement).
function NetService.recentRejections(player: Player, count: number): { Rejection }
	local result: { Rejection } = {}
	for index = #history, 1, -1 do
		local entry = history[index]
		if entry.userId == player.UserId then
			table.insert(result, 1, entry)
			if #result >= count then
				break
			end
		end
	end
	return result
end

function NetService.Init()
	local previous = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if previous then
		previous:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for _, name in { Remotes.Intent, Remotes.Notify } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

function NetService.Start()
	NetService.remote(Remotes.Intent).OnServerEvent:Connect(onIntent)
	Players.PlayerRemoving:Connect(function(player: Player)
		buckets[player] = nil
		local prefix = `{player.UserId}:`
		for key in throttles do
			if string.sub(key, 1, #prefix) == prefix then
				throttles[key] = nil
			end
		end
	end)

	local declared, handled = 0, 0
	for name in Remotes.Intents do
		declared += 1
		if handlers[name] ~= nil then
			handled += 1
		end
	end
	log:info("Canal d'intentions ouvert : %d intentions gérées sur %d déclarées", handled, declared)
end

return NetService
