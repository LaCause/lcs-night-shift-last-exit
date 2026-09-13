--!strict
-- Signal à écouteurs isolés (research R9, FR-010) : chaque écouteur tourne dans son propre
-- thread, sous xpcall. Un écouteur en erreur est journalisé et n'empêche pas les autres.

local Log = require(script.Parent.Log)

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Listener = {
	fn: (...any) -> (),
	once: boolean,
	connection: { Connected: boolean },
}

local Signal = {}

local function run(logger: Log.Logger, fn: (...any) -> (), ...: any)
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		logger:error("Écouteur en erreur : %s", tostring(err))
	end
end

function Signal.new<T...>(owner: string): Signal<T...>
	local logger = Log.new(owner)
	local listeners: { Listener } = {}

	local function remove(listener: Listener)
		if not listener.connection.Connected then
			return
		end
		listener.connection.Connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end

	local function connect(fn: (...any) -> (), once: boolean): Connection
		local connection = { Connected = true }
		local listener: Listener = { fn = fn, once = once, connection = connection }
		table.insert(listeners, listener)
		local handle = connection :: any
		function handle.Disconnect(_self: any)
			remove(listener)
		end
		return handle
	end

	local signal = {}

	function signal.Connect(_self: any, fn: (...any) -> ()): Connection
		return connect(fn, false)
	end

	function signal.Once(_self: any, fn: (...any) -> ()): Connection
		return connect(fn, true)
	end

	function signal.Fire(_self: any, ...: any)
		for _, listener in table.clone(listeners) do
			if listener.connection.Connected then
				if listener.once then
					remove(listener)
				end
				task.spawn(run, logger, listener.fn, ...)
			end
		end
	end

	function signal.DisconnectAll(_self: any)
		for _, listener in table.clone(listeners) do
			remove(listener)
		end
	end

	return (signal :: any) :: Signal<T...>
end

return Signal
