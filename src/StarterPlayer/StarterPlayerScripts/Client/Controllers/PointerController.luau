--!strict
-- Visée au pointeur (004-sac-collecte, FR-001, FR-002, FR-008). Ce contrôleur possède LE seul
-- lancer de rayon du pointeur et en dérive les deux gestes : la touche F ramasse l'objet visé
-- dans le sac, le clic maintenu le déplace. Viser n'est pas une règle de jeu — le serveur
-- revalide tout (research R3) ; ce contrôleur n'exprime que des intentions.
--
-- Un déplacement n'envoie que deux intentions (GrabItem au clic, ReleaseItem au relâchement) :
-- le suivi du pointeur est produit localement, la propriété réseau de la pièce ayant été confiée
-- au client par le serveur, qui borne la portée et tranche la position finale (research R4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local NetClient = require(ClientFolder:WaitForChild("NetClient") :: ModuleScript)

local COLLECT_KEY = Enum.KeyCode.F
local DROP_KEY = Enum.KeyCode.G
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 230, 120)
local HINT_COLOR = Color3.fromRGB(200, 195, 210)
local HINT_OFFSET = Vector3.new(0, 2.2, 0)

local player = Players.LocalPlayer

local PointerController = { Name = "PointerController", Priority = 12 }

local highlight: Highlight? = nil
local hintGui: BillboardGui? = nil
local hintLabel: TextLabel? = nil

local aimedPart: BasePart? = nil
local carriedPart: BasePart? = nil
local carryAlign: AlignPosition? = nil
local carryAttachment: Attachment? = nil

-- Minuteur de la touche de vidage (US2) : le client ne fait que choisir QUELLE intention envoyer
-- selon la durée d'appui, le serveur revalide entièrement les deux (clarification 2026-09-18, Q1).
local dropHoldStart: number? = nil
local dropHoldFired = false

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function nodeIdOf(part: BasePart): string?
	local id = part:GetAttribute("NodeId")
	return if typeof(id) == "string" then id else nil
end

-- Une cible est visable si elle est un nœud disponible que personne d'autre ne tient.
local function isAimable(part: BasePart): boolean
	if typeof(part:GetAttribute("ResourceType")) ~= "string" then
		return false
	end
	if part:GetAttribute("Available") ~= true then
		return false
	end
	local grabbedBy = part:GetAttribute("GrabbedBy")
	if typeof(grabbedBy) == "number" and grabbedBy ~= 0 and grabbedBy ~= player.UserId then
		return false
	end
	return nodeIdOf(part) ~= nil
end

local function ensureUi()
	if highlight ~= nil then
		return
	end
	local created = Instance.new("Highlight")
	created.Name = "PointerHighlight"
	created.FillTransparency = 0.7
	created.OutlineColor = HIGHLIGHT_COLOR
	created.FillColor = HIGHLIGHT_COLOR
	created.Enabled = false
	created.Parent = workspace
	highlight = created

	local gui = Instance.new("BillboardGui")
	gui.Name = "PointerHint"
	gui.Size = UDim2.fromOffset(240, 46)
	gui.StudsOffsetWorldSpace = HINT_OFFSET
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Parent = workspace

	-- Le fond passe sur un cadre : l'indice tient désormais deux lignes, l'action au pointeur et
	-- le rappel du déplacement à la souris, qui n'était indiqué nulle part jusqu'ici.
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 0.35
	panel.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = HIGHLIGHT_COLOR
	label.TextScaled = true
	label.Text = ""
	label.Parent = panel

	-- Texte fixe : il ne dépend d'aucun état, donc il est écrit une fois pour toutes ici.
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextColor3 = HINT_COLOR
	sub.TextScaled = true
	sub.Text = Strings.format("Pointer.Carry")
	sub.Parent = panel

	hintGui = gui
	hintLabel = label
end

local function showHint(part: BasePart?)
	ensureUi()
	local marker = highlight
	local gui = hintGui
	local label = hintLabel
	if marker == nil or gui == nil or label == nil then
		return
	end
	if part == nil then
		marker.Enabled = false
		gui.Enabled = false
		marker.Adornee = nil
		gui.Adornee = nil
		return
	end
	marker.Adornee = part
	marker.Enabled = true
	gui.Adornee = part
	gui.Enabled = true

	local state = GameplayStateClient.get()
	-- Trois messages possibles, du blocage le plus large au cas nominal : sans sac en main rien
	-- n'est ramassable (FR-019), sac plein il faut d'abord le vider, sinon on annonce la prise.
	if not state.bagEquipped then
		label.Text = Strings.format("Pointer.NeedBag")
	elseif state.bagCapacity > 0 and state.bagUsed >= state.bagCapacity then
		label.Text = Strings.format("Pointer.BagFull")
	else
		local resourceType = part:GetAttribute("ResourceType")
		label.Text = Strings.format("Pointer.Collect", {
			resource = Strings.format(`Resource.{tostring(resourceType)}`),
		})
	end
end

-- Lancer de rayon depuis la caméra vers le pointeur, limité à la forêt : aucune autre instance du
-- monde n'est visable, donc rien d'autre n'est testé.
local function aimedFromPointer(): (BasePart?, Vector3?)
	local camera = workspace.CurrentCamera
	local forest = workspace:FindFirstChild("Forest")
	if camera == nil or forest == nil then
		return nil, nil
	end
	local position = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { forest }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 512, params)
	if result == nil then
		return nil, nil
	end
	return result.Instance, result.Position
end

-- Point du monde que suit l'objet déplacé : le décor sous le pointeur, ou un point à distance
-- fixe devant la caméra si le rayon ne touche rien.
local function carryTarget(): Vector3?
	local camera = workspace.CurrentCamera
	local root = rootPart()
	if camera == nil or root == nil then
		return nil
	end
	local range: number = Config.get("Bag", "CarryRange")
	local position = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(position.X, position.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions: { Instance } = {}
	if player.Character then
		table.insert(exclusions, player.Character)
	end
	local carried = carriedPart
	if carried ~= nil then
		local model = carried.Parent
		table.insert(exclusions, if model ~= nil then model else carried)
	end
	params.FilterDescendantsInstances = exclusions

	local result = workspace:Raycast(ray.Origin, ray.Direction * (range * 2), params)
	local point = if result ~= nil then result.Position + Vector3.new(0, 1, 0) else ray.Origin + ray.Direction * range

	-- Bornage local : le serveur applique le même plafond, ce n'est qu'un confort d'affichage.
	local delta = point - root.Position
	if delta.Magnitude > range then
		point = root.Position + delta.Unit * range
	end
	return point
end

local function stopCarry(sendRelease: boolean)
	local part = carriedPart
	carriedPart = nil
	if carryAlign ~= nil then
		carryAlign:Destroy()
		carryAlign = nil
	end
	if carryAttachment ~= nil then
		carryAttachment:Destroy()
		carryAttachment = nil
	end
	if part == nil then
		return
	end
	local id = nodeIdOf(part)
	if sendRelease and id ~= nil then
		local position = part.Position
		NetClient.send("ReleaseItem", { target = id, x = position.X, y = position.Y, z = position.Z })
	end
end

local function startCarry(part: BasePart)
	local id = nodeIdOf(part)
	if id == nil then
		return
	end
	NetClient.send("GrabItem", { target = id })

	local attachment = Instance.new("Attachment")
	attachment.Name = "CarryAttachment"
	attachment.Parent = part

	local align = Instance.new("AlignPosition")
	align.Name = "CarryAlign"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.MaxForce = 120000
	align.Responsiveness = 40
	align.Position = part.Position
	align.Parent = part

	carryAttachment = attachment
	carryAlign = align
	carriedPart = part
end

function PointerController.Start()
	ensureUi()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == COLLECT_KEY then
			local part = aimedPart
			local id = if part ~= nil then nodeIdOf(part) else nil
			-- Sans le sac en main le serveur refuserait (FR-019) : on n'envoie rien et on laisse
			-- l'indice au pointeur expliquer pourquoi, plutôt que de gâcher un jeton de cadence.
			-- Le sac plein, lui, part quand même : le refus est ce qui déclenche « sac plein ».
			if id ~= nil and GameplayStateClient.get().bagEquipped then
				NetClient.send("HarvestResource", { target = id })
			end
		elseif input.KeyCode == DROP_KEY then
			-- Vider le sac ne vise rien : aucune cible à pointer, l'intention part telle quelle
			-- et le serveur décide seul où les objets tombent (FR-020). Le maintien démarre ici ;
			-- laquelle des deux intentions part se décide à RenderStepped (seuil franchi) ou à
			-- InputEnded (relâché avant, FR-003).
			local state = GameplayStateClient.get()
			if state.bagEquipped and state.bagUsed > 0 then
				dropHoldStart = os.clock()
				dropHoldFired = false
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local part = aimedPart
			if part ~= nil and carriedPart == nil then
				startCarry(part)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and carriedPart ~= nil then
			stopCarry(true)
		elseif input.KeyCode == DROP_KEY then
			-- Relâché avant le seuil : une pression brève ne retire qu'un seul objet (FR-003).
			-- Après le seuil, DropBag est déjà parti (RenderStepped) : rien de plus à envoyer, et
			-- il ne se redéclenche pas tant que la touche reste enfoncée (clarification Q1).
			if dropHoldStart ~= nil and not dropHoldFired then
				NetClient.send("DropOneItem", {})
			end
			dropHoldStart = nil
			dropHoldFired = false
		end
	end)

	-- Un objet ramassé ou repris par le serveur pendant un déplacement : on lâche proprement.
	local refresh = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if dropHoldStart ~= nil and not dropHoldFired then
			local threshold: number = Config.get("Bag", "DropHoldThreshold")
			if os.clock() - dropHoldStart >= threshold then
				dropHoldFired = true
				NetClient.send("DropBag", {})
			end
		end

		local carried = carriedPart
		if carried ~= nil then
			if carried.Parent == nil or carried:GetAttribute("Available") ~= true then
				stopCarry(false)
			else
				local align = carryAlign
				local point = carryTarget()
				if align ~= nil and point ~= nil then
					align.Position = point
				end
			end
			showHint(carried)
			return
		end

		refresh += dt
		if refresh < 1 / Config.get("Bag", "PointerRefreshRate") then
			return
		end
		refresh = 0

		local part = aimedFromPointer()
		local root = rootPart()
		local range: number = Config.get("Forest", "HarvestRange")
		if part ~= nil and root ~= nil and isAimable(part) and (part.Position - root.Position).Magnitude <= range then
			aimedPart = part
			showHint(part)
		else
			aimedPart = nil
			showHint(nil)
		end
	end)
end

return PointerController
