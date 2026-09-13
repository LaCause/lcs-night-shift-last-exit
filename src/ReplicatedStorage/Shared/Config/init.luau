--!strict
-- Chargeur de configuration (contracts/config.md, FR-013 à FR-016) : valide Settings.luau au
-- chargement, remplace toute valeur invalide par son défaut (avec avertissement), puis gèle le
-- résultat. Une valeur invalide ne casse jamais le démarrage.

local Log = require(script.Parent.Util.Log)
local Settings = require(script.Settings)

type Entry = {
	value: any,
	default: any,
	min: number?,
	max: number?,
	choices: { string }?,
	test: any,
	kind: string?,
	maxLength: number?,
}

local log = Log.new("Config")

local function kindOf(entry: Entry): string
	if entry.kind ~= nil then
		return entry.kind
	elseif entry.choices ~= nil then
		return "enum"
	end
	return typeof(entry.default)
end

local function isValid(kind: string, entry: Entry, value: any): boolean
	if kind == "number" or kind == "integer" then
		if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false
		end
		if kind == "integer" and value % 1 ~= 0 then
			return false
		end
		if entry.min ~= nil and value < entry.min then
			return false
		end
		if entry.max ~= nil and value > entry.max then
			return false
		end
		return true
	elseif kind == "boolean" then
		return typeof(value) == "boolean"
	elseif kind == "string" then
		return typeof(value) == "string" and (entry.maxLength == nil or #value <= entry.maxLength)
	elseif kind == "enum" then
		local choices = entry.choices
		return typeof(value) == "string" and choices ~= nil and table.find(choices, value) ~= nil
	end
	return false
end

local function show(value: any): string
	if typeof(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

local values: { [string]: { [string]: any } } = {}
local testValues: { [string]: { [string]: any } } = {}
local unusable: { [string]: boolean } = {}

for domain, entries in (Settings :: any) :: { [string]: { [string]: Entry } } do
	local domainValues = {}
	local domainTests = {}
	for key, entry in entries do
		local path = `{domain}.{key}`
		local kind = kindOf(entry)
		if not isValid(kind, entry, entry.default) then
			log:error("Réglage %s : valeur par défaut invalide (%s)", path, show(entry.default))
			unusable[path] = true
		else
			local value = entry.value
			if value == nil then
				log:warn("Réglage %s absent : défaut %s utilisé", path, show(entry.default))
				value = entry.default
			elseif not isValid(kind, entry, value) then
				log:warn("Réglage %s invalide (%s) : défaut %s utilisé", path, show(value), show(entry.default))
				value = entry.default
			end
			domainValues[key] = value
			if entry.test ~= nil then
				if isValid(kind, entry, entry.test) then
					domainTests[key] = entry.test
				else
					log:warn("Réglage %s : valeur de test invalide (%s) ignorée", path, show(entry.test))
				end
			end
		end
	end
	values[domain] = table.freeze(domainValues)
	testValues[domain] = table.freeze(domainTests)
end

local Config = {}

-- Renvoie la valeur résolue d'un réglage ; avec useTest, la valeur `test` si elle existe.
-- Lève une erreur pour un réglage inconnu ou dont la valeur par défaut est invalide : le système
-- qui le lit ne démarre alors pas (règle 6 de contracts/config.md).
function Config.get(domain: string, key: string, useTest: boolean?): any
	local path = `{domain}.{key}`
	if unusable[path] then
		error(`Réglage {path} inutilisable : sa valeur par défaut est invalide`, 2)
	end
	local domainValues = values[domain]
	local value = if domainValues then domainValues[key] else nil
	if value == nil then
		error(`Réglage inconnu : {path}`, 2)
	end
	if useTest then
		local testValue = testValues[domain][key]
		if testValue ~= nil then
			return testValue
		end
	end
	return value
end

local testProfileOk, testProfile = pcall(Config.get, "Match", "TestProfile")
Config.TestProfileDefault = testProfileOk and testProfile == true

local levelOk, level = pcall(Config.get, "Debug", "LogLevel")
if levelOk then
	Log.setLevel(level)
end

return table.freeze(Config)
