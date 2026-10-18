-- [InterfaceJogo] HUD no estilo do video de referencia:
-- topo (WAVE/START, proximo chefe, Nucleo, restantes, SKIP WAVE/AUTO-SKIP),
-- esquerda (UPGRADES: C vida, V proxima arma, +$), direita (HABILIDADES + ULT com medidor),
-- centro inferior (dinheiro), loja do Nucleo, escolha de classe, derrota e barras de vida.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local WCfg = require(Config:WaitForChild("Weapons"))
local CCfg = require(Config:WaitForChild("Classes"))
local CoreCfg = require(Config:WaitForChild("Core"))
local ShopCfg = require(Config:WaitForChild("Shop"))
local Modelos = require(Shared:WaitForChild("ModelosArmas"))
local estado = Shared:WaitForChild("EstadoJogo")
local remotes = Shared:WaitForChild("Remotes")

-- ESTILO ---------------------------------------------------------------------
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local C = {
	mint = Color3.fromRGB(98, 226, 160), mintCard = Color3.fromRGB(92, 212, 148), mintKey = Color3.fromRGB(30, 84, 58),
	black = Color3.fromRGB(14, 14, 16), dark = Color3.fromRGB(32, 32, 36), grey = Color3.fromRGB(150, 150, 155),
	yellow = Color3.fromRGB(255, 206, 72), moneyBox = Color3.fromRGB(235, 178, 70), moneyTxt = Color3.fromRGB(245, 196, 96),
	blue = Color3.fromRGB(64, 160, 225), blueKey = Color3.fromRGB(26, 60, 92), orange = Color3.fromRGB(244, 172, 58),
	orangeKey = Color3.fromRGB(110, 62, 16), red = Color3.fromRGB(232, 72, 86), white = Color3.new(1, 1, 1),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function label(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or HEAVY
	props.TextColor3 = props.TextColor3 or C.white
	props.BorderSizePixel = 0
	return new("TextLabel", props, parent)
end
local function outline(o, t, color)
	new("UIStroke", { Thickness = t or 2, Color = color or Color3.fromRGB(20, 14, 6), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, o)
	return o
end
local function fmt(n)
	n = math.floor(n or 0)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then out = out:sub(2) end
	return (n < 0 and "-" or "") .. out
end

-- string.upper nao conhece acentos (UTF-8): "Médico" -> "MÉDICO"
local ACENTOS = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç" }
local function upperPT(s)
	s = string.upper(s)
	for a, b in pairs(ACENTOS) do s = s:gsub(a, b) end
	return s
end

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720), 0.6, 1.4) end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- TOPO: WAVE / START ----------------------------------------------------------
local waveGroup = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(186, 46), BackgroundColor3 = C.mint, BorderSizePixel = 0 }, gui)
new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 245, 200), Transparency = 0.3 }, waveGroup)
local waveText = label({ Size = UDim2.fromScale(1, 1), Text = "WAVE 1", TextSize = 30, TextColor3 = C.black }, waveGroup)
local startBox = new("Frame", { Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(0, 46), BackgroundColor3 = C.black, BorderSizePixel = 0, ClipsDescendants = true }, waveGroup)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 40, 44), C.black), Rotation = 0 }, startBox)
local startText = label({ Size = UDim2.fromOffset(130, 46), Text = "START", TextSize = 28 }, startBox)

-- "PROXIMA WAVE EM" + contagem
local nextGroup = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(170, 70), BackgroundTransparency = 1, Visible = false }, gui)
local nextLbl = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(170, 22), BackgroundTransparency = 0, BackgroundColor3 = C.black, Text = "PRÓXIMA WAVE EM", TextSize = 12, FontFace = MONO }, nextGroup)
local nextNum = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(46, 40), BackgroundTransparency = 0, BackgroundColor3 = C.mint, Text = "5", TextSize = 28, TextColor3 = C.black }, nextGroup)

-- PROXIMO CHEFE
local boss = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(256, 46), BackgroundColor3 = C.black, BorderSizePixel = 0 }, gui)
local bossPortrait = new("Frame", { Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(70, 30, 25), BorderSizePixel = 0 }, boss)
Modelos.Viewport("Verity", bossPortrait, { Zoom = 0.8, Dir = Vector3.new(0.3, 0.25, -1) })
local bossTag = label({ Position = UDim2.fromOffset(52, 5), Size = UDim2.fromOffset(104, 18), BackgroundTransparency = 0, BackgroundColor3 = C.red, Text = "PRÓXIMO CHEFE", TextSize = 11 }, boss)
local bossName = label({ Position = UDim2.fromOffset(160, 4), Size = UDim2.fromOffset(92, 20), Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true }, boss)
new("UITextSizeConstraint", { MaxTextSize = 15 }, bossName)
local segBar = new("Frame", { Position = UDim2.fromOffset(52, 30), Size = UDim2.fromOffset(198, 10), BackgroundTransparency = 1 }, boss)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2) }, segBar)
local segs = {}
for i = 1, 10 do
	segs[i] = new("Frame", { Size = UDim2.fromOffset(18, 10), BackgroundColor3 = Color3.fromRGB(58, 58, 62), BorderSizePixel = 0, LayoutOrder = i }, segBar)
end

-- NUCLEO
local coreBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(256, 22), BackgroundColor3 = C.black, BorderSizePixel = 0 }, gui)
local coreFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.mint, BorderSizePixel = 0 }, coreBar)
local coreText = label({ Size = UDim2.fromScale(1, 1), Text = "NÚCLEO", TextSize = 13, ZIndex = 2 }, coreBar)
outline(coreText, 1.5)

-- restantes
local leftText = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 134), Size = UDim2.fromOffset(400, 28), Text = "", TextSize = 24 }, gui)
outline(leftText, 2)

-- SKIP WAVE
local skipBtn = new("TextButton", { Position = UDim2.new(0.5, 257, 0, 6), Size = UDim2.fromOffset(145, 46), BackgroundColor3 = C.mint, BorderSizePixel = 0, AutoButtonColor = true, Text = "SKIP WAVE", FontFace = HEAVY, TextSize = 22, TextColor3 = C.black }, gui)
local voteBox = new("Frame", { Position = UDim2.new(0.5, 402, 0, 6), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.black, BorderSizePixel = 0 }, gui)
local voteNum = label({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 26), Text = "0", TextSize = 22, TextColor3 = C.mint }, voteBox)
local voteMax = label({ Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 14), Text = "/1", TextSize = 11, TextColor3 = C.grey, FontFace = MONO }, voteBox)
local autoBtn = new("TextButton", { Position = UDim2.new(0.5, 257, 0, 54), Size = UDim2.fromOffset(191, 30), BackgroundColor3 = Color3.fromRGB(28, 28, 30), BorderSizePixel = 0, AutoButtonColor = true, Text = "" }, gui)
label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -60, 1, 0), Text = "AUTO-SKIP", TextSize = 13, FontFace = MONO, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Left }, autoBtn)
local autoState = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(40, 30), Text = "OFF", TextSize = 13, FontFace = MONO, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Right }, autoBtn)
-- sem waves/skip na tela: o jogo so conta os dias (DIA 1, DIA 2...)
skipBtn.Visible = false
voteBox.Visible = false
autoBtn.Visible = false
skipBtn.MouseButton1Click:Connect(function() remotes.VotarPular:FireServer() end)
autoBtn.MouseButton1Click:Connect(function()
	remotes.AutoSkip:FireServer(not (player:GetAttribute("AutoSkip") == true))
end)

-- AVISO central
local aviso = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 175), Size = UDim2.fromOffset(800, 40), Text = "", TextSize = 30, TextTransparency = 1 }, gui)
local avisoStroke = outline(aviso, 2.5):FindFirstChildOfClass("UIStroke")
local avisoToken = 0
local function showAviso(msg)
	avisoToken += 1
	local my = avisoToken
	aviso.Text = msg
	aviso.TextTransparency = 0
	avisoStroke.Transparency = 0
	aviso.Position = UDim2.new(0.5, 0, 0, 165)
	TweenService:Create(aviso, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 175) }):Play()
	task.delay(2.4, function()
		if my ~= avisoToken then return end
		TweenService:Create(aviso, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(avisoStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
end
remotes.Aviso.OnClientEvent:Connect(showAviso)

-- CARTOES ----------------------------------------------------------------------
local function card(parent, pos, anchor, colors, keyText, size)
	size = size or 92
	local holder = new("TextButton", { AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(size, size + 22), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, parent)
	local body = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = colors.bg, BorderSizePixel = 0 }, holder)
	new("UIGradient", { Color = ColorSequence.new(colors.bg:Lerp(C.white, 0.18), colors.bg), Rotation = 45 }, body)
	local edge = new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = colors.bg:Lerp(C.black, 0.25), BorderSizePixel = 0, ZIndex = 2 }, body)
	local iconHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, body)
	local key = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(19, 19), BackgroundTransparency = 0, BackgroundColor3 = colors.key, Text = keyText, TextSize = 13, ZIndex = 5 }, body)
	local price = label({ Position = UDim2.new(0, 6, 1, -26), Size = UDim2.new(1, -10, 0, 24), Text = "", TextSize = 19, TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 }, body)
	outline(price, 2, Color3.fromRGB(70, 45, 10))
	local shade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.black, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 4 }, body)
	local name = label({ Position = UDim2.fromOffset(0, size), Size = UDim2.fromOffset(size, 22), BackgroundTransparency = 0, BackgroundColor3 = C.black, Text = "", TextSize = 13, RichText = true, TextXAlignment = Enum.TextXAlignment.Left }, holder)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, name)
	return { holder = holder, body = body, iconHolder = iconHolder, key = key, price = price, name = name, shade = shade, icon = nil, iconId = nil }
end
local function setIcon(c, id, opts)
	if c.iconId == id then return end
	if c.icon then c.icon:Destroy() end
	c.icon = id and Modelos.Viewport(id, c.iconHolder, opts or { Size = UDim2.new(1, -10, 1, -18), Position = UDim2.fromOffset(5, 6), ZIndex = 3 }) or nil
	c.iconId = id
end

-- ESQUERDA: UPGRADES
label({ Position = UDim2.fromOffset(25, 146), Size = UDim2.fromOffset(120, 14), Text = "UPGRADES", TextSize = 11, FontFace = MONO, TextXAlignment = Enum.TextXAlignment.Left }, gui)
local healthCard = card(gui, UDim2.fromOffset(25, 163), Vector2.zero, { bg = C.mintCard, key = C.mintKey }, "C")
setIcon(healthCard, "Vida", { Size = UDim2.new(1, -24, 1, -30), Position = UDim2.fromOffset(12, 8), ZIndex = 3, Dir = Vector3.new(0.2, 0.25, -1) })
local weaponCard = card(gui, UDim2.fromOffset(25, 272), Vector2.zero, { bg = C.mintCard, key = C.mintKey }, "V")

local function moneyButton(pos, size, value, index)
	local b = new("TextButton", { Position = pos, Size = size, BackgroundColor3 = C.moneyBox, BorderSizePixel = 0, AutoButtonColor = true, Text = "" }, gui)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 205, 105), Color3.fromRGB(225, 150, 50)), Rotation = 90 }, b)
	local plus = label({ Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, 46, 1, 0), Text = "+$", TextSize = size.Y.Offset * 0.85, TextColor3 = C.black }, b)
	outline(plus, 2, C.white)
	local v = label({ Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -52, 1, 0), Text = fmt(value), TextSize = size.Y.Offset * 0.5, TextXAlignment = Enum.TextXAlignment.Left }, b)
	outline(v, 2, Color3.fromRGB(60, 40, 10))
	b.MouseButton1Click:Connect(function() remotes.ComprarDinheiro:FireServer(index) end)
	return b
end
for i, pack in ipairs(WCfg.PacotesDinheiro) do
	if i == 1 then moneyButton(UDim2.fromOffset(20, 384), UDim2.fromOffset(136, 46), pack.Valor, i)
	elseif i == 2 then moneyButton(UDim2.fromOffset(20, 440), UDim2.fromOffset(102, 40), pack.Valor, i) end
end
local classBtn = new("TextButton", { Position = UDim2.fromOffset(20, 492), Size = UDim2.fromOffset(136, 28), BackgroundColor3 = C.black, BorderSizePixel = 0, AutoButtonColor = true, Text = "CLASSE", FontFace = HEAVY, TextSize = 14, TextColor3 = C.mint }, gui)
local shopBtn = new("TextButton", { Position = UDim2.fromOffset(20, 524), Size = UDim2.fromOffset(136, 28), BackgroundColor3 = C.black, BorderSizePixel = 0, AutoButtonColor = true, Text = "LOJA  [B]", FontFace = HEAVY, TextSize = 14, TextColor3 = C.mint }, gui)

-- DIREITA: HABILIDADES
label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -25, 0, 144), Size = UDim2.fromOffset(140, 14), Text = "HABILIDADES", TextSize = 11, FontFace = MONO, TextXAlignment = Enum.TextXAlignment.Right }, gui)
-- (o martelo de reparo saiu do jogo: o card "G" nao existe mais)
local AB = { "Z", "X", "C", "Q" }
local abCards = {}
for i, slot in ipairs(AB) do
	local isUlt = slot == "Q"
	local colors = isUlt and { bg = C.orange, key = C.orangeKey } or { bg = C.blue, key = C.blueKey }
	local keyText = slot == "G" and "G" or CCfg.Teclas[slot]
	abCards[slot] = card(gui, UDim2.new(1, -25, 0, 160 + (i - 1) * 108), Vector2.new(1, 0), colors, keyText, 84)
end
-- medidor da ULT
local ultMeter = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -115, 0, 160 + 3 * 108), Size = UDim2.fromOffset(26, 106), BackgroundTransparency = 1 }, gui)
local ultNum = label({ Size = UDim2.fromOffset(26, 18), BackgroundTransparency = 0, BackgroundColor3 = C.black, Text = "0", TextSize = 12, TextColor3 = C.orange }, ultMeter)
local ultSegs = {}
for i = 1, 10 do
	ultSegs[i] = new("Frame", { Position = UDim2.fromOffset(2, 20 + (10 - i) * 8.6), Size = UDim2.fromOffset(22, 7), BackgroundColor3 = Color3.fromRGB(45, 30, 18), BorderSizePixel = 0 }, ultMeter)
end

-- CENTRO: DINHEIRO
local money = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.fromOffset(110, 52), BackgroundTransparency = 1 }, gui)
local moneyLayout = new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center }, money)
local dollar = label({ Size = UDim2.fromOffset(48, 52), BackgroundTransparency = 0, BackgroundColor3 = C.moneyBox, Text = "$", TextSize = 38, TextColor3 = C.black, LayoutOrder = 1 }, money)
local moneyVal = label({ Size = UDim2.fromOffset(60, 52), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, BackgroundColor3 = C.black, Text = "0", TextSize = 32, TextColor3 = C.moneyTxt, LayoutOrder = 2 }, money)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, moneyVal)

-- PAINEIS (loja, classe, derrota) ------------------------------------------------
local function panel(title, w, h)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Visible = false, ZIndex = 20 }, gui)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.mint, BorderSizePixel = 0, ZIndex = 21 }, f)
	label({ Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(14, 0), Text = title, TextSize = 24, TextColor3 = C.black, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, head)
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.black, BorderSizePixel = 0, Text = "X", FontFace = HEAVY, TextSize = 18, TextColor3 = C.white, ZIndex = 22 }, head)
	close.MouseButton1Click:Connect(function() f.Visible = false end)
	local body = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -68), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.mint, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21 }, f)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	return f, body
end
local function row(parent, order, h)
	return new("Frame", { Size = UDim2.new(1, -8, 0, h or 56), BackgroundColor3 = Color3.fromRGB(34, 34, 40), BorderSizePixel = 0, LayoutOrder = order, ZIndex = 22 }, parent)
end
local function rowButton(parent, text)
	return new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(150, 38), BackgroundColor3 = C.mint, BorderSizePixel = 0, Text = text, FontFace = HEAVY, TextSize = 15, TextColor3 = C.black, ZIndex = 23 }, parent)
end

-- LOJA DO NUCLEO (modulo Shared.LojaNucleoUI: secoes por cor + cartao do Nucleo por tier)
local function startBuild(key)
	local bc = player:WaitForChild("PlayerScripts"):FindFirstChild("BuildCliente")
	local ev = bc and bc:FindFirstChild("IniciarConstrucao")
	if ev then ev:Fire(key) end
end
local Loja = require(Shared:WaitForChild("LojaNucleoUI"))({
	gui = gui, player = player, estado = estado, remotes = remotes, fmt = fmt, startBuild = startBuild, showAviso = showAviso,
})
local shopPanel = Loja.Panel
local refreshShop = Loja.Refresh
local function toggleShop()
	local core = CollectionService:GetTagged("Nucleo")[1]
	local esf = core and core:FindFirstChild("NucleoEsfera")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if shopPanel.Visible then Loja.Close() return end
	if esf and root and (root.Position - esf.Position).Magnitude <= ShopCfg.Construcao.RaioConstrucao + 20 then
		Loja.Open()
	else
		showAviso("Volte para perto do Núcleo")
	end
end
remotes.AbrirLoja.OnClientEvent:Connect(function() Loja.Open() end)
shopBtn.MouseButton1Click:Connect(toggleShop)

-- ESCOLHA DE CLASSE
local classPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(960, 440), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Visible = false, ZIndex = 30 }, gui)
local cHead = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.mint, BorderSizePixel = 0, ZIndex = 31 }, classPanel)
label({ Size = UDim2.fromScale(1, 1), Text = "ESCOLHA SUA CLASSE", TextSize = 28, TextColor3 = C.black, ZIndex = 32 }, cHead)
local cClose = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = C.black, BorderSizePixel = 0, Text = "X", FontFace = HEAVY, TextSize = 18, TextColor3 = C.white, ZIndex = 32 }, cHead)
cClose.MouseButton1Click:Connect(function() classPanel.Visible = false end)
local cRow = new("Frame", { Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 1, -74), BackgroundTransparency = 1, ZIndex = 31 }, classPanel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }, cRow)
local classCards = {}
for i, key in ipairs(CCfg.Ordem) do
	local c = CCfg.Classes[key]
	local cardF = new("Frame", { Size = UDim2.fromOffset(224, 364), BackgroundColor3 = Color3.fromRGB(34, 34, 40), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 32 }, cRow)
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = c.Cor, BorderSizePixel = 0, ZIndex = 33 }, cardF)
	label({ Size = UDim2.fromScale(1, 1), Text = upperPT(c.Nome), TextSize = 22, ZIndex = 34 }, top)
	local icons = new("Frame", { Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 0, 50), BackgroundTransparency = 1, ZIndex = 33 }, cardF)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }, icons)
	for _, sl in ipairs({ "Z", "X", "C", "Q" }) do
		local box = new("Frame", { Size = UDim2.fromOffset(48, 48), BackgroundColor3 = sl == "Q" and C.orange or C.blue, BorderSizePixel = 0, ZIndex = 33 }, icons)
		Modelos.Viewport(Modelos.IconeHabilidade[key][sl], box, { ZIndex = 34, Zoom = 0.9 })
	end
	local lines = { c.Descricao, "", "Passiva: " .. c.Passiva.Texto, c.BonusTime.Texto, "" }
	for _, sl in ipairs({ "Z", "X", "C", "Q" }) do table.insert(lines, CCfg.Teclas[sl] .. ": " .. c.Habilidades[sl].Nome) end
	label({ Position = UDim2.fromOffset(10, 102), Size = UDim2.new(1, -20, 1, -158), Text = table.concat(lines, "\n"), TextSize = 13, FontFace = BOLD, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33 }, cardF)
	local b = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = C.mint, BorderSizePixel = 0, Text = "ESCOLHER", FontFace = HEAVY, TextSize = 18, TextColor3 = C.black, ZIndex = 34 }, cardF)
	b.MouseButton1Click:Connect(function()
		remotes.EscolherClasse:FireServer(key)
		classPanel.Visible = false
	end)
	classCards[key] = b
end
classBtn.MouseButton1Click:Connect(function() classPanel.Visible = not classPanel.Visible end)

-- DERROTA
local over = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 0, 4), BackgroundTransparency = 0.35, Visible = false, ZIndex = 40 }, gui)
local overCard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 372), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, ZIndex = 41 }, over)
local overHead = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 42 }, overCard)
label({ Size = UDim2.fromScale(1, 1), Text = "O NÚCLEO CAIU!", TextSize = 34, ZIndex = 43 }, overHead)
local overInfo = label({ Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 20, ZIndex = 42 }, overCard)
local cpBtn = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(440, 52), BackgroundColor3 = C.mint, BorderSizePixel = 0,
	Text = "RECOMEÇAR DO CHECKPOINT", FontFace = HEAVY, TextSize = 18, TextColor3 = C.black, ZIndex = 42 }, overCard)
local startBtn = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.fromOffset(440, 52), BackgroundColor3 = C.black, BorderSizePixel = 0,
	Text = "RECOMEÇAR DO INÍCIO", FontFace = HEAVY, TextSize = 18, TextColor3 = C.mint, ZIndex = 42 }, overCard)
local labBtn = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 262), Size = UDim2.fromOffset(440, 52), BackgroundColor3 = Color3.fromRGB(40, 90, 140), BorderSizePixel = 0,
	Text = "VOLTAR AO LOBBY", FontFace = HEAVY, TextSize = 18, TextColor3 = C.white, ZIndex = 42 }, overCard)
local overGems = label({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 24), Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(110, 230, 255), ZIndex = 42 }, overCard)
cpBtn.MouseButton1Click:Connect(function() remotes.Reiniciar:FireServer("checkpoint") end)
startBtn.MouseButton1Click:Connect(function() remotes.Reiniciar:FireServer("inicio") end)
labBtn.MouseButton1Click:Connect(function()
	over.Visible = false
	remotes.LobbyAcao:FireServer("voltar")
end)
player:GetAttributeChangedSignal("EmJogo"):Connect(function()
	if player:GetAttribute("EmJogo") ~= true then over.Visible = false; shopPanel.Visible = false; classPanel.Visible = false end
end)
remotes.FimDeJogo.OnClientEvent:Connect(function(info)
	overInfo.Text = "Você chegou à wave " .. tostring(info.wave) .. " · " .. tostring(info.abates) .. " abates"
	overGems.Text = "+" .. tostring(info.gemas or 0) .. " GEMAS nesta run"
	cpBtn.Visible = info.checkpoint ~= nil
	if info.checkpoint then cpBtn.Text = "RECOMEÇAR DO CHECKPOINT (WAVE " .. info.checkpoint .. ")" end
	shopPanel.Visible = false
	classPanel.Visible = false
	over.Visible = true
end)

-- ACOES DE TECLADO ---------------------------------------------------------------
local function busy() return player:GetAttribute("Construindo") == true end
local function buyHealth() remotes.ComprarUpgrade:FireServer("Vida") end
local function buyWeapon() remotes.ComprarUpgrade:FireServer("Arma") end
healthCard.holder.MouseButton1Click:Connect(buyHealth)
weaponCard.holder.MouseButton1Click:Connect(buyWeapon)

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimPoint()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	if UserInputService.MouseEnabled then
		aimParams.FilterDescendantsInstances = { char, workspace.CurrentCamera, workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("Efeitos") }
		local m = UserInputService:GetMouseLocation()
		local ray = workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, aimParams)
		return hit and hit.Position or (ray.Origin + ray.Direction * 40)
	end
	return root.Position + root.CFrame.LookVector * 18
end
local NEED = { Z = 1, X = 2, C = 3, Q = 3 }
local function useAbility(slot)
	if busy() then return end
	if (player:GetAttribute("Evolucao") or 1) < NEED[slot] then return end
	if slot == "Q" then
		if (player:GetAttribute("UltCarga") or 0) < (player:GetAttribute("UltMax") or 1) then return end
	elseif (player:GetAttribute("CD_" .. slot) or 0) > workspace:GetServerTimeNow() then
		return
	end
	local aim = aimPoint()
	if aim then remotes.UsarHabilidade:FireServer(slot, aim) end
end
for _, slot in ipairs({ "Z", "X", "C", "Q" }) do
	abCards[slot].holder.MouseButton1Click:Connect(function() useAbility(slot) end)
end
if abCards.G then abCards.G.holder.MouseButton1Click:Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		for _, t in ipairs(holder and holder:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("Slot") == 2 then
				if t.Parent == player.Character then hum:UnequipTools() else hum:EquipTool(t) end
				return
			end
		end
	end
end) end

local keyMap = {
	[Enum.KeyCode.C] = buyHealth, [Enum.KeyCode.V] = buyWeapon,
	[Enum.KeyCode.Z] = function() useAbility("Z") end, [Enum.KeyCode.X] = function() useAbility("X") end,
	[Enum.KeyCode.T] = function() useAbility("C") end, [Enum.KeyCode.Q] = function() useAbility("Q") end,
	[Enum.KeyCode.B] = toggleShop,
	[Enum.KeyCode.ButtonL1] = function() useAbility("Z") end, [Enum.KeyCode.ButtonR1] = function() useAbility("X") end,
	[Enum.KeyCode.ButtonL2] = function() useAbility("C") end, [Enum.KeyCode.ButtonL3] = function() useAbility("Q") end,
	[Enum.KeyCode.DPadLeft] = buyHealth, [Enum.KeyCode.DPadRight] = buyWeapon, [Enum.KeyCode.DPadUp] = toggleShop,
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if busy() and input.KeyCode ~= Enum.KeyCode.B then return end
	local f = keyMap[input.KeyCode]
	if f then f() end
end)

-- BARRAS DE VIDA ACIMA DOS JOGADORES ------------------------------------------------
local function overhead(char)
	local head = char:WaitForChild("Head", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not head or not hum then return end
	-- mesma barra segmentada dos inimigos (ReplicatedStorage.Shared.BarraVida)
	local BarraVida = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BarraVida"))
	local old = head:FindFirstChild("BarraVida")
	if old then old:Destroy() end
	local barra = BarraVida.Create(head, { Largura = 3.6, Offset = Vector3.new(0, 2.3, 0), MaxDistance = 140 })
	local function upd()
		barra:Set(hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 0)
	end
	hum.HealthChanged:Connect(upd)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(upd)
	upd()
end
local function watchPlayer(p)
	p.CharacterAdded:Connect(function(c) task.spawn(overhead, c) end)
	if p.Character then task.spawn(overhead, p.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- ATUALIZACAO -----------------------------------------------------------------
local lastPhase, lastWave = nil, nil
local function playStart()
	startBox.Size = UDim2.fromOffset(130, 46)
	task.delay(2.5, function()
		TweenService:Create(startBox, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(0, 46) }):Play()
	end)
end

local function refreshUpgrades()
	local coins = player:GetAttribute("Moedas") or 0
	-- vida
	local lvl = player:GetAttribute("NivelVida") or 0
	local maxHp = player:GetAttribute("VidaMaxima") or WCfg.Vida.Base
	if lvl >= WCfg.Vida.Max then
		healthCard.price.Text = "MÁX"
	else
		healthCard.price.Text = "$" .. fmt(math.floor(WCfg.Vida.CustoBase * WCfg.Vida.Mult ^ lvl + 0.5))
	end
	healthCard.name.Text = 'VIDA <font color="#62E2A0">[' .. maxHp .. ']</font> <font color="#9AA4AA" size="10">' .. lvl .. '/' .. WCfg.Vida.Max .. '</font>'
	-- arma
	local tier = player:GetAttribute("ArmaTier") or 1
	-- sequencia da run: Punhos + arma equipada em cada tier no Main Lobby
	local seqIds = string.split(player:GetAttribute("SequenciaArmas") or "", ",")
	local function wById(id) for _, a in ipairs(WCfg.Armas) do if a.Id == id then return a end end end
	local nxt = seqIds[tier + 1] and wById(seqIds[tier + 1])
	local nxtCost = WCfg.CustoTier[tier + 1] or 0
	if nxt then
		setIcon(weaponCard, nxt.Id)
		weaponCard.price.Text = "$" .. fmt(nxtCost)
		weaponCard.name.Text = nxt.Nome
		weaponCard.body.BackgroundColor3 = C.mintCard
	else
		local cur = (seqIds[tier] and wById(seqIds[tier])) or WCfg.Armas[1]
		setIcon(weaponCard, cur.Id)
		weaponCard.price.Text = "MÁX"
		weaponCard.name.Text = cur.Nome
	end
	healthCard.price.TextColor3 = (lvl < WCfg.Vida.Max and coins >= math.floor(WCfg.Vida.CustoBase * WCfg.Vida.Mult ^ lvl + 0.5)) and C.yellow or Color3.fromRGB(255, 150, 120)
	weaponCard.price.TextColor3 = (nxt and coins >= nxtCost) and C.yellow or Color3.fromRGB(255, 150, 120)
end

local function refreshClass()
	local cls = player:GetAttribute("Classe") or CCfg.ClassePadrao
	local c = CCfg.Classes[cls]
	if not c then return end
	local evo = player:GetAttribute("Evolucao") or 1
	for _, slot in ipairs({ "Z", "X", "C", "Q" }) do
		local card = abCards[slot]
		setIcon(card, Modelos.IconeHabilidade[cls][slot], { Size = UDim2.new(1, -14, 1, -26), Position = UDim2.fromOffset(7, 6), ZIndex = 3 })
		card.name.Text = c.Habilidades[slot].Nome
		local locked = evo < NEED[slot]
		card.holder.Visible = not locked
	end
	ultMeter.Visible = abCards.Q.holder.Visible
	for key, b in pairs(classCards) do
		b.Text = key == cls and "ATUAL" or "ESCOLHER"
		b.BackgroundColor3 = key == cls and C.dark or C.mint
		b.TextColor3 = key == cls and C.grey or C.black
	end
end
player:GetAttributeChangedSignal("Classe"):Connect(refreshClass)
player:GetAttributeChangedSignal("Evolucao"):Connect(refreshClass)
player.AttributeChanged:Connect(function(n)
	if n == "Moedas" or n == "ArmaTier" or n == "SequenciaArmas" or n == "NivelVida" or n == "VidaMaxima" then
		refreshUpgrades()
		if shopPanel.Visible then refreshShop() end
	end
end)
refreshClass()
refreshUpgrades()

estado:GetAttributeChangedSignal("Fase"):Connect(function()
	if estado:GetAttribute("Fase") ~= "Derrota" then over.Visible = false end
end)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	-- cooldowns e ULT (todo quadro)
	local cls = player:GetAttribute("Classe") or CCfg.ClassePadrao
	local c = CCfg.Classes[cls]
	if c then
		for _, slot in ipairs({ "Z", "X", "C" }) do
			local card = abCards[slot]
			local left = (player:GetAttribute("CD_" .. slot) or 0) - now
			if left > 0 then
				card.shade.Size = UDim2.fromScale(1, math.clamp(left / c.Habilidades[slot].Cooldown, 0, 1))
				card.price.Text = math.ceil(left) .. "s"
			else
				card.shade.Size = UDim2.fromScale(1, 0)
				card.price.Text = c.Habilidades[slot].Cooldown .. "s"
			end
		end
		local carga = player:GetAttribute("UltCarga") or 0
		local maxC = math.max(1, player:GetAttribute("UltMax") or 1)
		ultNum.Text = tostring(carga)
		local filled = math.floor(carga / maxC * 10 + 0.001)
		for i = 1, 10 do ultSegs[i].BackgroundColor3 = i <= filled and C.orange or Color3.fromRGB(45, 30, 18) end
		local ready = carga >= maxC
		abCards.Q.price.Text = "ULT"
		abCards.Q.price.TextColor3 = C.white
		abCards.Q.shade.Size = UDim2.fromScale(1, ready and 0 or (1 - carga / maxC))
		abCards.Q.body.BackgroundColor3 = ready and C.orange:Lerp(C.white, (math.sin(os.clock() * 6) + 1) * 0.12) or C.orange
	end

	acc += dt
	if acc < 0.15 then return end
	acc = 0
	moneyVal.Text = fmt(player:GetAttribute("Moedas") or 0)
	local fase = estado:GetAttribute("Fase") or "Aguardando"
	local wave = estado:GetAttribute("Wave") or 0
	-- topo
	-- topo: so o contador de dias (sem waves, sem contagem, sem chefe)
	nextGroup.Visible = false
	boss.Visible = false
	if fase == "Dia" then
		waveGroup.Visible = true
		waveText.Text = "DIA " .. math.max(1, wave)
		leftText.Text = ""
		coreBar.Position = UDim2.new(0.5, 0, 0, 58)
	elseif fase == "Noite" then
		waveGroup.Visible = true
		waveText.Text = "NOITE " .. wave
		coreBar.Position = UDim2.new(0.5, 0, 0, 58)
		local r = estado:GetAttribute("Restantes") or estado:GetAttribute("InimigosVivos") or 0
		leftText.Text = r > 0 and (r .. (r == 1 and " verity" or " veritys")) or ""
	else
		waveGroup.Visible = true
		nextGroup.Visible = false
		waveText.Text = fase == "Derrota" and "DERROTA" or "DIA " .. math.max(1, wave)
		if fase == "Aguardando" and estado:GetAttribute("EsperandoGrupo") then
			waveText.Text = "GRUPO " .. (estado:GetAttribute("GrupoChegou") or 0) .. "/" .. (estado:GetAttribute("GrupoTotal") or 1)
			leftText.Text = "aguardando o grupo chegar..."
		end
		leftText.Text = ""
		coreBar.Position = UDim2.new(0.5, 0, 0, 58)
	end
	leftText.Position = UDim2.new(0.5, 0, 0, 84)
	lastPhase, lastWave = fase, wave
	-- chefe
	bossName.Text = estado:GetAttribute("ProximoChefe") or "O REI VERITY"
	local bw = estado:GetAttribute("ProximoChefeWave") or 10
	local done = 10 - math.max(0, bw - wave)
	if fase == "Noite" or fase == "Derrota" then done -= 1 end
	for i = 1, 10 do segs[i].BackgroundColor3 = i <= done and C.red or Color3.fromRGB(58, 58, 62) end
	-- nucleo
	local v = estado:GetAttribute("CoreVida") or 0
	local mx = math.max(1, estado:GetAttribute("CoreVidaMax") or 1)
	local r = math.clamp(v / mx, 0, 1)
	coreFill.Size = UDim2.fromScale(r, 1)
	coreFill.BackgroundColor3 = r > 0.5 and C.mint or (r > 0.25 and C.yellow or C.red)
	coreText.Text = "NÚCLEO  " .. fmt(v) .. " / " .. fmt(mx) .. "  ·  TIER " .. (estado:GetAttribute("CoreTier") or 1)
	-- votos
	voteNum.Text = tostring(estado:GetAttribute("VotosPular") or 0)
	voteMax.Text = "/" .. tostring(estado:GetAttribute("VotosNecessarios") or 1)
	local auto = player:GetAttribute("AutoSkip") == true
	autoState.Text = auto and "ON" or "OFF"
	autoState.TextColor3 = auto and C.mint or C.grey
	-- botao classe so de dia
	classBtn.Visible = false -- troca de classe so no Laboratorio
	-- loja fecha se afastar
	if shopPanel.Visible then
		local core = CollectionService:GetTagged("Nucleo")[1]
		local esf = core and core:FindFirstChild("NucleoEsfera")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and esf and (root.Position - esf.Position).Magnitude > ShopCfg.Construcao.RaioConstrucao + 25 then shopPanel.Visible = false end
	end
end)

-- a classe agora e escolhida no Laboratorio Verity (LobbyCliente), antes da missao
