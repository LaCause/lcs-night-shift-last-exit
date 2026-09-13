--!strict
-- Tirages déterministes dérivés de la seed et d'un contexte (research R11 ; FR-040).
-- Chaque contexte a son propre flux : les tirages ne dépendent pas de l'ordre des demandes.
-- Le jeu n'utilise jamais math.random (principe V).

local FNV_OFFSET = 2166136261
local TWO_POW_32 = 4294967296

local Rng = {}

-- Hachage FNV-1a 32 bits. Le premier FNV (16777619 = 2^24 + 403) est appliqué en deux termes pour
-- rester exact en double précision : h * 403 + (h << 24), modulo 2^32.
function Rng.hash32(text: string): number
	local hash = FNV_OFFSET
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		hash = (hash * 403 + bit32.lshift(hash, 24)) % TWO_POW_32
	end
	return hash
end

-- Générateur propre au contexte (ex. Rng.forContext(seed, "chunk", 3, -2)).
function Rng.forContext(seed: number, ...: string | number): Random
	local parts = { tostring(seed) }
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	return Random.new(Rng.hash32(table.concat(parts, "|")))
end

return table.freeze(Rng)
