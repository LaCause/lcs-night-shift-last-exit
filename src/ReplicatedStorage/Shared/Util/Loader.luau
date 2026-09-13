--!strict
-- Chargeur de systèmes commun au serveur et au client (contracts/server-api.md, research R9).
-- Découvre les ModuleScripts enfants directs d'un dossier, les trie par Priority puis Name,
-- appelle tous les Init, puis chaque Start dans son propre thread, le tout sous xpcall :
-- un système en échec est journalisé et n'empêche pas les autres de démarrer (FR-006, FR-009).

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)
local Log = require(script.Parent.Log)

type Entry = { name: string, priority: number, module: any }

local DEFAULT_PRIORITY = 100

local Loader = {}

function Loader.run(folder: Instance?, label: string)
	local log = Log.new(`Loader/{label}`)
	if folder == nil then
		log:info("Aucun dossier de systèmes : rien à charger")
		return
	end

	-- Panne simulée (SC-011), honorée uniquement dans Studio.
	local failAtInit: string = if RunService:IsStudio() then Config.get("Debug", "FailSystemAtInit") else ""

	local entries: { Entry } = {}
	local failures = 0

	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = xpcall(require, debug.traceback, child)
			if not ok then
				failures += 1
				log:error("Chargement de %s impossible : %s", child.Name, tostring(result))
			elseif typeof(result) ~= "table" then
				failures += 1
				log:error("%s ne respecte pas le contrat de système (table attendue)", child.Name)
			else
				local name = if typeof(result.Name) == "string" then result.Name else child.Name
				local priority = if typeof(result.Priority) == "number" then result.Priority else DEFAULT_PRIORITY
				table.insert(entries, { name = name, priority = priority, module = result })
			end
		end
	end

	table.sort(entries, function(a: Entry, b: Entry): boolean
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.name < b.name
	end)

	local ready: { Entry } = {}
	for _, entry in entries do
		local ok, err = xpcall(function()
			if failAtInit ~= "" and entry.name == failAtInit then
				error("échec simulé par Debug.FailSystemAtInit")
			end
			local init = entry.module.Init
			if typeof(init) == "function" then
				init(entry.module)
			end
		end, debug.traceback)
		if ok then
			table.insert(ready, entry)
		else
			failures += 1
			log:error("Init de %s en échec, système non démarré : %s", entry.name, tostring(err))
		end
	end

	for _, entry in ready do
		local start = entry.module.Start
		if typeof(start) == "function" then
			task.spawn(function()
				local ok, err = xpcall(start, debug.traceback, entry.module)
				if not ok then
					log:error("Start de %s en échec : %s", entry.name, tostring(err))
				end
			end)
		end
		log:debug("%s démarré", entry.name)
	end

	log:info("%d systèmes démarrés, %d en échec", #ready, failures)
end

return Loader
