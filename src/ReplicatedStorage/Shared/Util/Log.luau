--!strict
-- Journal préfixé par système, avec niveaux (research R12).
-- Une erreur journalisée n'interrompt jamais le système qui la signale : elle est écrite via
-- warn avec la mention « ERREUR ».

local LEVELS = table.freeze({ Debug = 1, Info = 2, Warn = 3, Error = 4 })

local currentLevel: number = LEVELS.Info

local Logger = {}
Logger.__index = Logger

type LoggerData = { prefix: string }
export type Logger = typeof(setmetatable({} :: LoggerData, Logger))

local function render(message: string, ...: any): string
	if select("#", ...) == 0 then
		return message
	end
	local ok, result = pcall(string.format, message, ...)
	return if ok then result else message
end

function Logger.debug(self: Logger, message: string, ...: any)
	if currentLevel <= LEVELS.Debug then
		print(self.prefix, render(message, ...))
	end
end

function Logger.info(self: Logger, message: string, ...: any)
	if currentLevel <= LEVELS.Info then
		print(self.prefix, render(message, ...))
	end
end

function Logger.warn(self: Logger, message: string, ...: any)
	if currentLevel <= LEVELS.Warn then
		warn(self.prefix, render(message, ...))
	end
end

function Logger.error(self: Logger, message: string, ...: any)
	-- Toujours affichée, quel que soit le niveau.
	warn(self.prefix, "ERREUR :", render(message, ...))
end

local Log = {}

function Log.new(system: string): Logger
	return setmetatable({ prefix = `[LastExit/{system}]` }, Logger)
end

-- Niveaux : "Debug", "Info", "Warn", "Error" (réglage Debug.LogLevel).
function Log.setLevel(level: string)
	local value = (LEVELS :: any)[level]
	if typeof(value) == "number" then
		currentLevel = value
	end
end

return Log
