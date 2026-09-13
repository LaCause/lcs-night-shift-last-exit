--!strict
-- Côté client : envoi des intentions et écoute des notifications (contracts/network.md).
-- Le client n'envoie que des intentions ; c'est le serveur qui décide (principe III).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(script.Parent.Parent.Util.Log)
local Remotes = require(script.Parent.Parent.Net.Remotes)

type Listener = (params: { [string]: any }) -> ()

local TIMEOUT = 10

local log = Log.new("NetClient")

local intentRemote: RemoteEvent? = nil
local listeners: { [string]: { Listener } } = {}
local status: "idle" | "resolving" | "ready" | "failed" = "idle"

local function dispatch(kind: any, params: any)
	if typeof(kind) ~= "string" then
		return
	end
	local list = listeners[kind]
	if list == nil or #list == 0 then
		log:debug("Notification ignorée : %s", kind)
		return
	end
	local safeParams = if typeof(params) == "table" then params else {}
	for _, listener in table.clone(list) do
		task.spawn(function()
			local ok, err = xpcall(listener, debug.traceback, safeParams)
			if not ok then
				log:error("Écouteur de %s en erreur : %s", kind, tostring(err))
			end
		end)
	end
end

-- Attend les remotes une seule fois pour tout le client (10 s au plus).
local function resolve(): boolean
	if status == "ready" then
		return true
	elseif status == "failed" then
		return false
	elseif status == "resolving" then
		while status == "resolving" do
			task.wait()
		end
		return status == "ready"
	end

	status = "resolving"
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, TIMEOUT)
	local intent = if folder then folder:WaitForChild(Remotes.Intent, TIMEOUT) else nil
	local notify = if folder then folder:WaitForChild(Remotes.Notify, TIMEOUT) else nil
	if intent == nil or notify == nil or not intent:IsA("RemoteEvent") or not notify:IsA("RemoteEvent") then
		log:error("Remotes introuvables après %d s (ReplicatedStorage.%s)", TIMEOUT, Remotes.FolderName)
		status = "failed"
		return false
	end
	intentRemote = intent
	notify.OnClientEvent:Connect(dispatch)
	status = "ready"
	return true
end

local NetClient = {}

function NetClient.send(action: string, payload: { [string]: any }?)
	if not resolve() then
		return
	end
	local remote = intentRemote
	if remote then
		remote:FireServer(action, payload or {})
	end
end

function NetClient.onNotify(kind: string, fn: Listener): { Disconnect: (...any) -> () }
	local list = listeners[kind]
	if list == nil then
		list = {}
		listeners[kind] = list
	end
	local registered: { Listener } = list
	table.insert(registered, fn)
	task.spawn(resolve)
	return {
		Disconnect = function()
			local index = table.find(registered, fn)
			if index then
				table.remove(registered, index)
			end
		end,
	}
end

-- Réservé au panneau de dev : permet d'envoyer des requêtes volontairement malformées.
function NetClient.rawIntent(): RemoteEvent?
	resolve()
	return intentRemote
end

return table.freeze(NetClient)
