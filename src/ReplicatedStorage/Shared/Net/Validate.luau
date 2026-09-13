--!strict
-- Validateurs de schéma pour les données reçues des clients (research R7).
-- Module pur, sans dépendance : les bornes sont passées par l'appelant.

export type Check = (value: any) -> (boolean, string?)

local Validate = {}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.string(maxLength: number?): Check
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "string" then
			return false, "chaîne attendue"
		end
		if maxLength ~= nil and #value > maxLength then
			return false, `chaîne trop longue ({#value} > {maxLength})`
		end
		return true, nil
	end
end

function Validate.number(min: number, max: number): Check
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "number" then
			return false, "nombre attendu"
		end
		if not isFinite(value) then
			return false, "nombre non fini"
		end
		if value < min or value > max then
			return false, `hors bornes [{min}, {max}]`
		end
		return true, nil
	end
end

function Validate.integer(min: number, max: number): Check
	local number = Validate.number(min, max)
	return function(value: any): (boolean, string?)
		local ok, reason = number(value)
		if not ok then
			return false, reason
		end
		if value % 1 ~= 0 then
			return false, "entier attendu"
		end
		return true, nil
	end
end

function Validate.boolean(): Check
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "boolean" then
			return false, "booléen attendu"
		end
		return true, nil
	end
end

function Validate.enum(choices: { string }): Check
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "string" or table.find(choices, value) == nil then
			return false, `valeur hors liste ({table.concat(choices, ", ")})`
		end
		return true, nil
	end
end

function Validate.optional(check: Check): Check
	return function(value: any): (boolean, string?)
		if value == nil then
			return true, nil
		end
		return check(value)
	end
end

-- Table dont les clés sont exactement celles de `fields` : toute clé inconnue est refusée.
function Validate.object(fields: { [string]: Check }): Check
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "table" then
			return false, "table attendue"
		end
		for key in value do
			if typeof(key) ~= "string" or fields[key] == nil then
				return false, `clé inconnue : {tostring(key)}`
			end
		end
		for key, check in fields do
			local ok, reason = check(value[key])
			if not ok then
				return false, `{key} : {reason or "invalide"}`
			end
		end
		return true, nil
	end
end

function Validate.check(schema: Check, value: any): (boolean, string?)
	return schema(value)
end

return table.freeze(Validate)
