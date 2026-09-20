--!strict
-- Stock du sac, affiché au-dessus du joueur uniquement quand le sac est équipé (amélioration
-- visuelle : remplace la ligne détaillée qui vivait dans la box « Ressources »). Aucun détail par
-- ressource ici — juste le remplissage global ; le détail reste disponible via l'outil de dev
-- (Dev.ShowGameplayState). Créé côté client et parenté au personnage du joueur local : un Instance
-- créé par un LocalScript ne se réplique jamais aux autres clients, donc c'est déjà strictement
-- personnel sans code de filtrage supplémentaire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientFolder = Shared:WaitForChild("Client")
local Strings = require(Shared:WaitForChild("Strings") :: ModuleScript)
local GameplayStateClient = require(ClientFolder:WaitForChild("GameplayStateClient") :: ModuleScript)
local UiKit = require(ClientFolder:WaitForChild("UiKit") :: ModuleScript)

local OFFSET = Vector3.new(0, 3, 0)

local player = Players.LocalPlayer

local BagStatusController = { Name = "BagStatusController", Priority = 60 }

local activeFill: Frame? = nil
local activeText: TextLabel? = nil
local activeHint: TextLabel? = nil
local activeGui: BillboardGui? = nil

local function build(head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BagStatus"
	gui.Size = UDim2.fromOffset(130, 48)
	gui.StudsOffsetWorldSpace = OFFSET
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Parent = head

	local track, fill = UiKit.bar(gui, "Track", UDim2.new(1, 0, 0, 10))
	UiKit.corner(track, 5)
	UiKit.corner(fill, 5)

	local text = UiKit.label(gui, "Text", "", UDim2.new(1, 0, 0, 18), {
		position = UDim2.fromScale(0, 0.3),
		textSize = 14,
	})

	local hint = UiKit.label(gui, "Hint", "", UDim2.new(1, 0, 0, 14), {
		position = UDim2.fromScale(0, 0.74),
		textSize = 11,
		color = UiKit.Colors.Muted,
	})

	activeGui = gui
	activeFill = fill
	activeText = text
	activeHint = hint
end

local function refresh()
	local gui = activeGui
	local fill = activeFill
	local text = activeText
	local hint = activeHint
	if gui == nil or fill == nil or text == nil or hint == nil then
		return
	end

	local state = GameplayStateClient.get()
	gui.Enabled = state.bagEquipped
	if not state.bagEquipped then
		return
	end

	local ratio = if state.bagCapacity > 0 then math.clamp(state.bagUsed / state.bagCapacity, 0, 1) else 0
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.BackgroundColor3 = if state.bagCapacity > 0 and state.bagUsed >= state.bagCapacity
		then UiKit.Colors.Warn
		else UiKit.Colors.Good
	text.Text = Strings.format("Hud.Bag", { used = state.bagUsed, capacity = state.bagCapacity })
	hint.Text = if state.bagUsed > 0 then Strings.format("Hud.Bag.Drop") else ""
end

local function onCharacterAdded(character: Model)
	activeGui = nil
	activeFill = nil
	activeText = nil
	activeHint = nil
	local head = character:WaitForChild("Head", 10)
	if head == nil or not head:IsA("BasePart") then
		return
	end
	build(head)
	refresh()
end

function BagStatusController.Start()
	local character = player.Character
	if character then
		onCharacterAdded(character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	GameplayStateClient.Changed:Connect(refresh)
end

return BagStatusController
