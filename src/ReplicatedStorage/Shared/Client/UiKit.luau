--!strict
-- Briques d'interface partagées (FR-038) : tailles relatives et texte contraint entre 14 et 32 px
-- pour rester lisible sur téléphone ; palette sombre et néon originale.

local Players = game:GetService("Players")

export type LabelOptions = {
	position: UDim2?,
	anchor: Vector2?,
	font: Enum.Font?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	minSize: number?,
	maxSize: number?,
	autoHeight: boolean?,
	textSize: number?,
	background: boolean?,
}

local UiKit = {}

UiKit.Colors = table.freeze({
	Ink = Color3.fromRGB(16, 14, 24),
	Panel = Color3.fromRGB(30, 26, 42),
	Text = Color3.fromRGB(242, 238, 250),
	Muted = Color3.fromRGB(172, 162, 194),
	Neon = Color3.fromRGB(255, 70, 170),
	Cyan = Color3.fromRGB(70, 235, 255),
	Good = Color3.fromRGB(122, 240, 142),
	Bad = Color3.fromRGB(255, 96, 96),
	Warn = Color3.fromRGB(255, 204, 86),
})

UiKit.Fonts = table.freeze({
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Mono = Enum.Font.RobotoMono,
})

function UiKit.screen(name: string): ScreenGui?
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local found = playerGui:WaitForChild(name, 10)
	return if found and found:IsA("ScreenGui") then found else nil
end

function UiKit.corner(parent: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

function UiKit.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UiKit.Colors.Neon
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UiKit.padding(parent: GuiObject, pixels: number): UIPadding
	local padding = Instance.new("UIPadding")
	local value = UDim.new(0, pixels)
	padding.PaddingTop = value
	padding.PaddingBottom = value
	padding.PaddingLeft = value
	padding.PaddingRight = value
	padding.Parent = parent
	return padding
end

function UiKit.sizeLimits(parent: GuiObject, minSize: Vector2, maxSize: Vector2): UISizeConstraint
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minSize
	constraint.MaxSize = maxSize
	constraint.Parent = parent
	return constraint
end

function UiKit.frame(parent: Instance, name: string, size: UDim2, position: UDim2?, anchor: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position or UDim2.new()
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = UiKit.Colors.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function UiKit.label(parent: Instance, name: string, text: string, size: UDim2, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = opts.position or UDim2.new()
	label.AnchorPoint = opts.anchor or Vector2.zero
	label.BackgroundColor3 = UiKit.Colors.Ink
	label.BackgroundTransparency = if opts.background then 0.25 else 1
	label.BorderSizePixel = 0
	label.Font = opts.font or UiKit.Fonts.Body
	label.Text = text
	label.TextColor3 = opts.color or UiKit.Colors.Text
	label.TextXAlignment = opts.align or Enum.TextXAlignment.Center
	label.TextWrapped = true
	if opts.autoHeight then
		label.TextScaled = false
		label.TextSize = opts.textSize or 16
		label.AutomaticSize = Enum.AutomaticSize.Y
	else
		label.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = opts.minSize or 14
		constraint.MaxTextSize = opts.maxSize or 32
		constraint.Parent = label
	end
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, name: string, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = UiKit.Colors.Ink
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = UiKit.Fonts.Body
	button.Text = text
	button.TextColor3 = UiKit.Colors.Text
	button.TextScaled = true
	button.TextWrapped = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 14
	constraint.MaxTextSize = 18
	constraint.Parent = button
	UiKit.corner(button, 6)
	UiKit.stroke(button, UiKit.Colors.Cyan, 1)
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

-- Barre de progression : piste + remplissage. L'appelant fait varier `fill.Size` (fromScale(ratio,
-- 1)) et `fill.BackgroundColor3` selon l'état ; la piste ne bouge jamais.
function UiKit.bar(parent: Instance, name: string, size: UDim2, position: UDim2?, fillColor: Color3?): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name
	track.Size = size
	track.Position = position or UDim2.new()
	track.BackgroundColor3 = UiKit.Colors.Ink
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor or UiKit.Colors.Good
	fill.BorderSizePixel = 0
	fill.Parent = track

	return track, fill
end

function UiKit.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 4)
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

return table.freeze(UiKit)
