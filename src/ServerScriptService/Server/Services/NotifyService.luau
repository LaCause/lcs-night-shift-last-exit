--!strict
-- Diffusion des notifications de partie (FR-036) via le remote Notify (contracts/network.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Net.Remotes)
local NetService = require(script.Parent.NetService)

local log = Log.new("Notify")

local NotifyService = { Name = "NotifyService", Priority = 35 }

local function isDeclared(kind: string): boolean
	if table.find(Remotes.NotificationKinds, kind) ~= nil then
		return true
	end
	log:error("Type de notification non déclaré dans Remotes.luau : %s", kind)
	return false
end

function NotifyService.broadcast(kind: string, params: { [string]: any })
	if isDeclared(kind) then
		NetService.remote(Remotes.Notify):FireAllClients(kind, params)
		log:debug("%s → tous", kind)
	end
end

function NotifyService.send(player: Player, kind: string, params: { [string]: any })
	if isDeclared(kind) and player.Parent ~= nil then
		NetService.remote(Remotes.Notify):FireClient(player, kind, params)
		log:debug("%s → %s", kind, player.Name)
	end
end

return NotifyService
