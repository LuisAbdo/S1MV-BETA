-- LojaNucleoUI: Loja do Nucleo dividida por cores.
-- Esquerda: cartao do Nucleo (emblema animado na cor do tier, barra dos 10 tiers, o que o proximo
-- tier libera e botao EVOLUIR na cor do proximo tier). Direita: secoes DEFESA (laranja),
-- TORRETAS (azul) e SUPORTE (verde) com cards de imagem 3D, contador colocados/limite e preco.
-- A moldura inteira (borda, cabecalho, brilhos) acompanha a cor do tier atual do Nucleo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoreCfg = require(Shared.Config:WaitForChild("Core"))
local ShopCfg = require(Shared.Config:WaitForChild("Shop"))
local Custos = require(Shared:WaitForChild("Custos"))

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.fromRGB(12, 12, 14)
local BG, CARD, CARD2 = Color3.fromRGB(15, 17, 21), Color3.fromRGB(24, 28, 34), Color3.fromRGB(32, 37, 45)
local GREY, DIM = Color3.fromRGB(150, 156, 164), Color3.fromRGB(70, 74, 82)

local SECOES = {
	{ Nome = "DEFESA", Sub = "Barreiras para segurar o caminho", Cor = Color3.fromRGB(255, 150, 60), Itens = { "Barricada", "Muro", "MuroTiro", "BarricadaReforcada", "Portao" } },
	{ Nome = "CONSTRUÇÃO", Sub = "Peças de grade para fechar a base em 360° (empilham)", Cor = Color3.fromRGB(210, 170, 110), Itens = { "PisoReforcado", "Teto", "Rampa" } },
	{ Nome = "ARMADILHAS", Sub = "Chão, parede e teto: os veritys passam e sofrem", Cor = Color3.fromRGB(255, 90, 90), Itens = { "Mina", "Espinhos", "Lentidao", "Quicador", "LancaDardos", "Repulsor", "Prensa", "EmissorGas" } },
	{ Nome = "TORRETAS", Sub = "Atiram sozinhas nos veritys perto", Cor = Color3.fromRGB(70, 175, 255), Itens = { "TorretaBasica", "TorretaGelo", "LancaChamas", "TorretaPesada" } },
	{ Nome = "SUPORTE", Sub = "Reparam e protegem as outras estruturas", Cor = Color3.fromRGB(90, 230, 140), Itens = { "Drone", "GeradorEscudo" } },
	{ Nome = "AVANÇADAS", Sub = "Liberam com a evolução do Núcleo", Cor = Color3.fromRGB(180, 130, 255), Itens = { "GradeEletrica", "CampoForca", "Cupula" } },
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
	props.TextColor3 = props.TextColor3 or WHITE
	props.BorderSizePixel = 0
	return new("TextLabel", props, parent)
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) return o end
local function stroke(o, c, t, tr) return new("UIStroke", { Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function tw(o, p, t, style) TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play() end
-- sons da interface
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local SONS = require(Shared.Config:WaitForChild("Sons"))
local lastHover = 0
local function sfx(def, pitch)
	if not def then return end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.V or 0.5
	s.PlaybackSpeed = (def.P or 1) * (pitch or 1)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end
local function hover(o, s)
	local sc = new("UIScale", {}, o)
	o.MouseEnter:Connect(function()
		tw(sc, { Scale = s or 1.04 }, 0.12)
		if os.clock() - lastHover > 0.06 then lastHover = os.clock() sfx(SONS.UIHover) end
	end)
	o.MouseLeave:Connect(function() tw(sc, { Scale = 1 }, 0.12) end)
end
local function shake(o)
	local base = o.Position
	task.spawn(function()
		for i, dx in ipairs({ -7, 6, -4, 3, 0 }) do
			o.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		o.Position = base
	end)
end

-- descricao curta de cada estrutura (aparece no balao ao passar o mouse)
local DESC = {
	Barricada = "Barata e rápida de montar. Ótima para segurar os primeiros veritys longe do Núcleo.",
	Muro = "Bloco de pedra resistente. Use para fechar o caminho principal.",
	BarricadaReforcada = "Madeira com ferro: aguenta muito mais pancada que a comum.",
	Mina = "Fica escondida no chão e explode quando um verity chega perto.",
	TorretaBasica = "Atira sozinha no verity mais perto. A base de qualquer defesa.",
	TorretaGelo = "Deixa os veritys lentos. Combine com torretas de dano.",
	LancaChamas = "Queima tudo num cone curto na frente dela. Perfeita em corredores.",
	TorretaPesada = "Canhão de longo alcance com explosão em área.",
	Drone = "Voa sobre a base e conserta as estruturas em volta.",
	GeradorEscudo = "Cria uma bolha que reduz o dano nas estruturas perto dele.",
	Portao = "Abre sozinho para os jogadores. Os veritys batem nele como num muro.",
	MuroTiro = "Muro com fenda: segura os veritys, mas você e os tiros passam pela abertura.",
	PisoReforcado = "Base para armadilhas ou para um segundo andar. Pode ir em cima de muros.",
	Teto = "Cobre o Núcleo e as torres. Coloque em cima dos muros para fechar a base.",
	Rampa = "Sobe rápido para plataformas e atira de cima.",
	Espinhos = "Dano constante em quem pisa. Ótima nos corredores de entrada.",
	Lentidao = "Gelo no chão: os veritys andam 50% mais devagar em cima.",
	Quicador = "Arremessa os veritys para trás, longe do Núcleo.",
	LancaDardos = "Atira em linha reta quando um verity passa na frente.",
	Repulsor = "Empurra uma fileira de veritys de volta pelo corredor.",
	Prensa = "Esmaga quem passa por baixo: muito dano de uma vez.",
	EmissorGas = "Nuvem de gás que machuca grupos de veritys fracos.",
	GradeEletrica = "Portão que abre para jogadores e eletrocuta os veritys que encostam.",
	CampoForca = "Parede de laser: jogadores e tiros passam, veritys não.",
	Cupula = "Domo em volta do Núcleo que segura o dano até quebrar.",
}

local function tierColor(tier, t)
	local v = CoreCfg.VisualTier[math.clamp(tier, 1, #CoreCfg.VisualTier)]
	if v.Arcoiris and t then return Color3.fromHSV((t * 0.12) % 1, 0.55, 1) end
	return v.Cor
end

return function(ctx)
	local player, estado, remotes, fmt = ctx.player, ctx.estado, ctx.remotes, ctx.fmt
	local M = {}

	local root = new("Frame", { Name = "LojaNucleo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(830, 548),
		BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, ZIndex = 20 }, ctx.gui)
	corner(root, 12)
	local rootStroke = stroke(root, CoreCfg.VisualTier[1].Cor, 2, 0.1)
	local pop = new("UIScale", {}, root)

	-- CABECALHO (degrade na cor do tier) -----------------------------------------------------
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = CoreCfg.VisualTier[1].Cor, BorderSizePixel = 0, ZIndex = 21 }, root)
	corner(head, 12)
	new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = CoreCfg.VisualTier[1].Cor, BorderSizePixel = 0, ZIndex = 21, Name = "Tampa" }, head)
	local headGrad = new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(120, 120, 120)), Rotation = 0 }, head)
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(120, 120, 120)), Rotation = 0 }, head.Tampa)
	label({ Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(400, 54), Text = "LOJA DO NÚCLEO", TextSize = 26, TextColor3 = BLACK, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, head)
	local moneyL = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(170, 34), BackgroundTransparency = 0, BackgroundColor3 = BLACK,
		Text = "$ 0", TextSize = 20, TextColor3 = Color3.fromRGB(245, 196, 96), ZIndex = 22 }, head)
	corner(moneyL, 8)
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(38, 34), BackgroundColor3 = BLACK, BorderSizePixel = 0,
		Text = "X", FontFace = HEAVY, TextSize = 18, TextColor3 = WHITE, ZIndex = 22 }, head)
	corner(close, 8)
	hover(close, 1.1)
	close.MouseButton1Click:Connect(function() M.Close() end)

	-- ESQUERDA: CARTAO DO NUCLEO -----------------------------------------------------------
	local coreCard = new("Frame", { Position = UDim2.fromOffset(14, 66), Size = UDim2.fromOffset(250, 468), BackgroundColor3 = CARD, BorderSizePixel = 0, ZIndex = 21 }, root)
	corner(coreCard, 10)
	local coreStroke = stroke(coreCard, CoreCfg.VisualTier[1].Cor, 1.5, 0.4)
	local glow = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundColor3 = CoreCfg.VisualTier[1].Cor, BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 21 }, coreCard)
	corner(glow, 10)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = 90 }, glow)
	label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 14), Text = "NÚCLEO", TextSize = 12, FontFace = MONO, TextColor3 = GREY, ZIndex = 22 }, coreCard)
	-- emblema: anel girando + orbe pulsando + numeral
	local emb = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(126, 126), BackgroundTransparency = 1, ZIndex = 22 }, coreCard)
	local ringF = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, emb)
	corner(ringF, 999)
	local ringStroke = stroke(ringF, WHITE, 4, 0)
	local ringGrad = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.1), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }) }, ringStroke)
	local ring2 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84), BackgroundTransparency = 1, ZIndex = 22 }, emb)
	corner(ring2, 999)
	local ring2Stroke = stroke(ring2, WHITE, 2, 0.5)
	local orb = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = CoreCfg.VisualTier[1].Cor, BorderSizePixel = 0, ZIndex = 23 }, emb)
	corner(orb, 999)
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 150, 150)), Rotation = 60 }, orb)
	local numL = label({ Size = UDim2.fromScale(1, 1), Text = "I", TextSize = 34, TextColor3 = BLACK, ZIndex = 24 }, orb)
	local orbScale = new("UIScale", {}, orb)
	local tierName = label({ Position = UDim2.fromOffset(0, 162), Size = UDim2.new(1, 0, 0, 28), Text = "CENTELHA", TextSize = 26, ZIndex = 22 }, coreCard)
	local tierSub = label({ Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 16), Text = "TIER 1/10", TextSize = 13, FontFace = MONO, TextColor3 = GREY, ZIndex = 22 }, coreCard)
	-- barra dos 10 tiers (cada segmento na cor do proprio tier)
	local segF = new("Frame", { Position = UDim2.fromOffset(16, 214), Size = UDim2.new(1, -32, 0, 10), BackgroundTransparency = 1, ZIndex = 22 }, coreCard)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) }, segF)
	local segs = {}
	local nT = #CoreCfg.Tiers
	for i = 1, nT do
		segs[i] = new("Frame", { Size = UDim2.new(1 / nT, -3, 1, 0), BackgroundColor3 = tierColor(i), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22 }, segF)
		corner(segs[i], 3)
	end
	-- detalhes do proximo tier
	local nextBox = new("Frame", { Position = UDim2.fromOffset(14, 236), Size = UDim2.new(1, -28, 0, 160), BackgroundColor3 = CARD2, BorderSizePixel = 0, ZIndex = 22 }, coreCard)
	corner(nextBox, 8)
	local nextStroke = stroke(nextBox, WHITE, 1, 0.6)
	local nextTitle = label({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), Text = "PRÓXIMO", TextSize = 12, FontFace = MONO, TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, nextBox)
	local nextSwatch = new("Frame", { Position = UDim2.fromOffset(12, 30), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 23 }, nextBox)
	corner(nextSwatch, 9)
	local nextName = label({ Position = UDim2.fromOffset(38, 28), Size = UDim2.new(1, -50, 0, 22), Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, nextBox)
	local nextInfo = label({ Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 96), Text = "", RichText = true, TextSize = 13, FontFace = BOLD, TextColor3 = Color3.fromRGB(205, 210, 215),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23 }, nextBox)
	local evoBtn = new("TextButton", { Position = UDim2.fromOffset(14, 408), Size = UDim2.new(1, -28, 0, 46), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false,
		Text = "", ZIndex = 22, ClipsDescendants = true }, coreCard)
	corner(evoBtn, 8)
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 175, 175)), Rotation = 90 }, evoBtn)
	local evoTxt = label({ Size = UDim2.fromScale(1, 1), Text = "EVOLUIR", TextSize = 20, TextColor3 = BLACK, RichText = true, ZIndex = 24 }, evoBtn)
	local shine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.3, 0, 0.5, 0), Size = UDim2.new(0, 30, 3, 0), Rotation = 20, BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 23 }, evoBtn)
	hover(evoBtn, 1.04)
	evoBtn.MouseButton1Click:Connect(function()
		local tier = estado:GetAttribute("CoreTier") or 1
		local nxt = CoreCfg.Tiers[tier + 1]
		if not nxt or (estado:GetAttribute("Wave") or 0) < nxt.WaveMin or (player:GetAttribute("Moedas") or 0) < nxt.Custo then
			sfx(SONS.UIErro)
			shake(evoBtn)
		end
		remotes.ComprarTier:FireServer()
	end)

	-- DIREITA: SECOES COLORIDAS -------------------------------------------------------------
	-- abas: pulam para a secao (cada uma na cor da sua secao)
	-- 6 abas dividem a largura toda da coluna (antes cada uma tinha 120 px e saiam da janela)
	local tabs = new("Frame", { Position = UDim2.fromOffset(278, 66), Size = UDim2.fromOffset(530, 32), BackgroundTransparency = 1, ZIndex = 21 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
	local tabBtns = {}
	local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(278, 108), Size = UDim2.fromOffset(538, 426), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		ScrollBarImageColor3 = GREY, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21 }, root)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroll)

	local sectionHeads = {}
	local function selectTab(i)
		for j, b in ipairs(tabBtns) do
			local on = j == i
			tw(b.btn, { BackgroundTransparency = on and 0 or 0.82 }, 0.15)
			b.btn.TextColor3 = on and BLACK or b.cor
		end
	end
	for i, sec in ipairs(SECOES) do
		local b = new("TextButton", { Size = UDim2.new(1 / #SECOES, -5 * (#SECOES - 1) / #SECOES, 1, 0), BackgroundColor3 = sec.Cor, BackgroundTransparency = 0.82, BorderSizePixel = 0, AutoButtonColor = false,
			Text = sec.Nome, FontFace = HEAVY, TextScaled = true, TextColor3 = sec.Cor, LayoutOrder = i, ZIndex = 22 }, tabs)
		new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }, b)
		new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		corner(b, 16)
		stroke(b, sec.Cor, 1.5, 0.2)
		hover(b, 1.06)
		tabBtns[i] = { btn = b, cor = sec.Cor }
		b.MouseButton1Click:Connect(function()
			sfx(SONS.UIClique)
			selectTab(i)
			local h = sectionHeads[i]
			if h then
				local y = h.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
				tw(scroll, { CanvasPosition = Vector2.new(0, math.max(0, y)) }, 0.35, Enum.EasingStyle.Quint)
			end
		end)
	end
	-- dica no cabecalho (antes ficava em cima das abas)
	local hint = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -246, 0, 27), Size = UDim2.fromOffset(110, 20), Text = "[B] fecha", TextSize = 12, FontFace = MONO,
		TextColor3 = BLACK, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23 }, root)

	-- balao de detalhes (segue o mouse)
	local tip = new("Frame", { Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(10, 12, 15), BackgroundTransparency = 0.04,
		BorderSizePixel = 0, Visible = false, ZIndex = 60 }, ctx.gui)
	corner(tip, 8)
	local tipStroke = stroke(tip, WHITE, 1.5, 0.1)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, tip)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tip)
	local tipName = label({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 61 }, tip)
	local tipDesc = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", TextSize = 12, FontFace = BOLD, TextColor3 = Color3.fromRGB(200, 205, 210),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 61 }, tip)
	local tipStats = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", RichText = true, TextSize = 12, FontFace = MONO, TextColor3 = WHITE,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, ZIndex = 61 }, tip)
	-- custo com icones de madeira/pedra + situacao (falta / clique para construir)
	local tipCost = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 61 }, tip)
	label({ Size = UDim2.fromOffset(62, 20), Text = "⚒ Custo", TextSize = 12, FontFace = MONO, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61 }, tipCost)
	local tipCostRow = new("Frame", { Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1, ZIndex = 61 }, tipCost)
	local tipStatus = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", RichText = true, TextSize = 12, FontFace = MONO, TextColor3 = WHITE,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5, ZIndex = 61 }, tip)
	local tipKey
	local UserInputService = game:GetService("UserInputService")

	local cards = {}
	local function statsOf(ic)
		if ic.Tipo == "Torreta" then
			local extra = ic.Lentidao and ("Lentidão " .. math.floor(ic.Lentidao * 100) .. "%") or (ic.Area and ("Área " .. ic.Area)) or (ic.Cone and "Cone de fogo") or "Tiro rápido"
			return "Dano " .. ic.Dano .. "  ·  Alcance " .. ic.Alcance, extra
		elseif ic.Tipo == "Mina" then return "Explode: " .. ic.Dano .. " de dano", "Raio " .. ic.Raio
		elseif ic.Tipo == "Drone" then return "Repara " .. ic.Cura .. " vida/s", "Raio " .. ic.Raio
		elseif ic.Tipo == "Gerador" then return "-" .. math.floor(ic.Reducao * 100) .. "% de dano recebido", "Raio " .. ic.Raio
		elseif ic.Tipo == "Armadilha" then
			if ic.Lentidao then return "Lentidão " .. math.floor(ic.Lentidao * 100) .. "%", "Não bloqueia" end
			if ic.Forca and not ic.Dano then return "Empurra os veritys", "A cada " .. ic.Cadencia .. "s" end
			return "Dano " .. (ic.Dano or 0) .. (ic.Intervalo and (" a cada " .. ic.Intervalo .. "s") or ""), ic.Portao and "Portão elétrico" or (ic.NaoBloqueia and "Não bloqueia" or "Vida " .. ic.Vida)
		elseif ic.Tipo == "Suporte" then return "Segura o dano do Núcleo", "Vida " .. ic.Vida
		end
		if ic.Empilhavel then return "Peça de grade (empilha)", "Vida " .. ic.Vida end
		if ic.PassaJogador then return "Jogadores e tiros passam", "Vida " .. ic.Vida end
		return "Bloqueia o caminho", "Vida " .. ic.Vida
	end

	local function previewViewport(key, parent, size, accent)
		local vp = new("ViewportFrame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(18, 21, 26), BorderSizePixel = 0,
			Ambient = Color3.fromRGB(165, 165, 170), LightColor = WHITE, LightDirection = Vector3.new(-0.6, -1, -0.4), ZIndex = 23 }, parent)
		corner(vp, 8)
		new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 160, 170)), Rotation = 90 }, vp)
		stroke(vp, accent, 1, 0.55)
		task.spawn(function()
			local folder = Shared:WaitForChild("PreviewsEstruturas", 20)
			local src = folder and folder:WaitForChild(key, 5)
			if not src then return end
			local m = src:Clone()
			m.Parent = vp
			local cf, sz = m:GetBoundingBox()
			local cam = new("Camera", { FieldOfView = 35 }, vp)
			vp.CurrentCamera = cam
			local dist = (sz.Magnitude / 2) / math.tan(math.rad(17.5)) * 1.02
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.85, 0.75, -1.15).Unit * dist, cf.Position)
		end)
		return vp
	end

	for si, sec in ipairs(SECOES) do
		-- cabecalho da secao
		local sh = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = sec.Cor, BackgroundTransparency = 0.82, BorderSizePixel = 0, LayoutOrder = si * 10, ZIndex = 22 }, scroll)
		sectionHeads[si] = sh
		corner(sh, 8)
		new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, sh)
		new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = sec.Cor, BorderSizePixel = 0, ZIndex = 23 }, sh)
		label({ Position = UDim2.fromOffset(16, 3), Size = UDim2.fromOffset(300, 20), Text = sec.Nome, TextSize = 19, TextColor3 = sec.Cor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, sh)
		label({ Position = UDim2.fromOffset(16, 23), Size = UDim2.fromOffset(420, 14), Text = sec.Sub, TextSize = 11, FontFace = BOLD, TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, sh)
		-- grade de cards
		local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = si * 10 + 1, ZIndex = 22 }, scroll)
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 140), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		for ii, key in ipairs(sec.Itens) do
			local ic = ShopCfg.Estruturas[key]
			if ic then
				local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = ii, ZIndex = 22 }, grid)
				local card = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CARD, BorderSizePixel = 0, ZIndex = 22 }, cell)
				corner(card, 10)
				local intro = new("UIScale", { Name = "Intro" }, card)
				card.MouseEnter:Connect(function()
					tipKey = key
					tipName.Text = ic.Nome
					tipName.TextColor3 = sec.Cor
					tipStroke.Color = sec.Cor
					tipDesc.Text = DESC[key] or ""
					local lines = { "♥ Vida " .. ic.Vida }
					if ic.Dano then table.insert(lines, "⚔ Dano " .. ic.Dano .. (ic.Cadencia and ("  ·  a cada " .. ic.Cadencia .. "s") or "")) end
					if ic.Alcance then table.insert(lines, "◎ Alcance " .. ic.Alcance) end
					if ic.Raio then table.insert(lines, "◎ Raio " .. ic.Raio) end
					if ic.Cura then table.insert(lines, "✚ Repara " .. ic.Cura .. "/s") end
					table.insert(lines, "▣ Limite " .. ic.Limite .. " por jogador")
					Custos.Linha(tipCostRow, ic.Custo, { tamanho = 13, fonte = MONO, alinhar = Enum.HorizontalAlignment.Left, estoque = estado, zindex = 62 })
					local falta = Custos.Falta(estado, ic.Custo)
					if (estado:GetAttribute("CoreTier") or 1) < ic.TierMin then
						tipStatus.Text = '<font color="#FF7A7A">🔒 Evolua o Núcleo para o tier ' .. ic.TierMin .. "</font>"
					elseif falta then
						tipStatus.Text = '<font color="#FF7A7A">Falta material no estoque</font>'
					else
						tipStatus.Text = '<font color="#6EF0A0">Clique para construir</font>'
					end
					tipStats.Text = table.concat(lines, "\n")
					tip.Visible = true
				end)
				card.MouseLeave:Connect(function() if tipKey == key then tip.Visible = false tipKey = nil end end)
				local cs = stroke(card, sec.Cor, 1, 0.65)
				local vp = previewViewport(key, card, 80, sec.Cor)
				local lock = label({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.3, BackgroundColor3 = BLACK, Text = "", TextSize = 14, Visible = false, ZIndex = 25 }, vp)
				corner(lock, 8)
				label({ Position = UDim2.fromOffset(102, 12), Size = UDim2.new(1, -110, 0, 36), Text = ic.Nome, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23 }, card)
				local s1, s2 = statsOf(ic)
				label({ Position = UDim2.fromOffset(102, 50), Size = UDim2.new(1, -110, 0, 14), Text = s1, TextSize = 11, FontFace = BOLD, TextColor3 = Color3.fromRGB(210, 214, 220), TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23 }, card)
				label({ Position = UDim2.fromOffset(102, 66), Size = UDim2.new(1, -110, 0, 14), Text = s2, TextSize = 11, FontFace = BOLD, TextColor3 = sec.Cor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23 }, card)
				local count = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 74), Size = UDim2.fromOffset(60, 14), Text = "0/" .. ic.Limite, TextSize = 11, FontFace = MONO, TextColor3 = GREY,
					TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23 }, card)
				local buy = new("TextButton", { Position = UDim2.new(0, 12, 1, -42), Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = sec.Cor, BorderSizePixel = 0, AutoButtonColor = false,
					Text = "", FontFace = HEAVY, TextSize = 17, TextScaled = true, TextColor3 = BLACK, ZIndex = 23 }, card)
				Custos.Linha(buy, ic.Custo, { tamanho = 15, fonte = HEAVY, cor = BLACK, zindex = 24 })
				new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9 }, buy)
				new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, buy)
				corner(buy, 7)
				hover(buy, 1.04)
				buy.MouseEnter:Connect(function() tw(cs, { Transparency = 0 }, 0.12) end)
				buy.MouseLeave:Connect(function() tw(cs, { Transparency = 0.65 }, 0.12) end)
				buy.MouseButton1Click:Connect(function()
					local c = cards[key]
					local function fail(msg) sfx(SONS.UIErro) shake(card) tw(cs, { Color = Color3.fromRGB(255, 80, 80), Transparency = 0 }, 0.05) task.delay(0.35, function() tw(cs, { Color = sec.Cor, Transparency = 0.65 }, 0.3) end) ctx.showAviso(msg) end
					if (estado:GetAttribute("CoreTier") or 1) < ic.TierMin then fail("Exige Núcleo tier " .. ic.TierMin) return end
					if c and c.full then fail("Limite deste item: " .. ic.Limite) return end
					local falta = Custos.Falta(estado, ic.Custo)
					if falta then fail("Falta material - colete na floresta") return end
					sfx(SONS.UIClique)
					M.Close()
					ctx.startBuild(key)
				end)
				cards[key] = { ic = ic, sec = sec, vp = vp, lock = lock, buy = buy, count = count, card = card, intro = intro }
			end
		end
	end

	-- quantos de cada item este jogador ja colocou
	local function placed()
		local n = {}
		local f = workspace:FindFirstChild("Estruturas")
		if f then
			for _, m in ipairs(f:GetChildren()) do
				if m:GetAttribute("Dono") == player.UserId then
					local k = m:GetAttribute("Item")
					if k then n[k] = (n[k] or 0) + 1 end
				end
			end
		end
		return n
	end

	local curTier = 0
	function M.Refresh()
		local tier = estado:GetAttribute("CoreTier") or 1
		local wave = estado:GetAttribute("Wave") or 0
		local coins = player:GetAttribute("Moedas") or 0
		curTier = tier
		local col = tierColor(tier, os.clock())
		local vis = CoreCfg.VisualTier[math.clamp(tier, 1, #CoreCfg.VisualTier)]
		moneyL.Text = "$ " .. fmt(coins)
		numL.Text = CoreCfg.Romano[tier] or tostring(tier)
		tierName.Text = vis.Nome
		tierSub.Text = "TIER " .. tier .. "/" .. nT .. "  ·  VIDA " .. fmt(estado:GetAttribute("CoreVidaMax") or 0)
		for i, s in ipairs(segs) do
			s.BackgroundTransparency = i <= tier and 0 or 0.78
			s.Size = UDim2.new(1 / nT, -3, i == tier and 1.6 or 1, 0)
		end
		local nxt = CoreCfg.Tiers[tier + 1]
		if nxt then
			local nv = CoreCfg.VisualTier[tier + 1]
			local ncol = tierColor(tier + 1)
			nextTitle.Text = "PRÓXIMA EVOLUÇÃO"
			nextSwatch.BackgroundColor3 = ncol
			nextStroke.Color = ncol
			nextName.Text = "TIER " .. (CoreCfg.Romano[tier + 1] or tier + 1) .. " · " .. nv.Nome
			nextName.TextColor3 = ncol
			local vidaN = math.floor(CoreCfg.VidaBase * CoreCfg.MultVidaPorTier ^ tier + 0.5)
			local libera = {}
			for _, k in ipairs(ShopCfg.Ordem) do
				local e = ShopCfg.Estruturas[k]
				if e.TierMin == tier + 1 then table.insert(libera, e.Nome) end
			end
			local txt = "♥ Vida " .. fmt(estado:GetAttribute("CoreVidaMax") or 0) .. ' <font color="#6EF0A0">→ ' .. fmt(vidaN) .. "</font>\n✚ Mais regeneração e escudo"
			if #libera > 0 then txt ..= '\n<font color="#' .. ncol:ToHex() .. '">▲ Libera: ' .. table.concat(libera, ", ") .. "</font>" end
			nextInfo.Text = txt
			local canWave = wave >= nxt.WaveMin
			local canPay = coins >= nxt.Custo
			if not canWave then
				evoTxt.Text = "🔒 LIBERA NA WAVE " .. nxt.WaveMin
				evoBtn.BackgroundColor3 = DIM
				evoTxt.TextColor3 = Color3.fromRGB(200, 200, 205)
			else
				evoTxt.Text = "EVOLUIR  <font size=\"16\">$" .. fmt(nxt.Custo) .. "</font>"
				evoBtn.BackgroundColor3 = canPay and ncol or ncol:Lerp(DIM, 0.6)
				evoTxt.TextColor3 = BLACK
			end
		else
			nextTitle.Text = "EVOLUÇÃO MÁXIMA"
			nextSwatch.BackgroundColor3 = col
			nextName.Text = "O NÚCLEO ESTÁ COMPLETO"
			nextName.TextColor3 = WHITE
			nextInfo.Text = "Todas as estruturas liberadas.\nDefenda até o fim!"
			evoTxt.Text = "TIER MÁXIMO"
			evoBtn.BackgroundColor3 = col
			evoTxt.TextColor3 = BLACK
		end
		-- cards
		local n = placed()
		for key, c in pairs(cards) do
			local locked = tier < c.ic.TierMin
			local have = n[key] or 0
			local full = have >= c.ic.Limite
			c.lock.Visible = locked
			c.lock.Text = locked and ("🔒 TIER " .. c.ic.TierMin) or ""
			c.vp.ImageColor3 = locked and Color3.fromRGB(100, 100, 105) or WHITE
			c.full = full
			c.count.Text = have .. "/" .. c.ic.Limite
			c.count.TextColor3 = full and Color3.fromRGB(255, 110, 110) or GREY
			local row = c.buy:FindFirstChild("CustoLinha")
			if row then row.Visible = not (locked or full) end
			if locked then
				c.buy.Text = "TIER " .. c.ic.TierMin
				c.buy.BackgroundColor3 = DIM
				c.buy.TextColor3 = Color3.fromRGB(190, 190, 195)
			elseif full then
				c.buy.Text = "LIMITE"
				c.buy.BackgroundColor3 = DIM
				c.buy.TextColor3 = Color3.fromRGB(255, 150, 150)
			else
				local ok = Custos.Tem(estado, c.ic.Custo)
				c.buy.Text = ""
				Custos.Linha(c.buy, c.ic.Custo, { tamanho = 15, fonte = HEAVY, cor = ok and BLACK or Color3.fromRGB(200, 200, 205), zindex = 24 })
				c.buy.BackgroundColor3 = ok and c.sec.Cor or c.sec.Cor:Lerp(DIM, 0.65)
				c.buy.TextColor3 = ok and BLACK or Color3.fromRGB(200, 200, 205)
			end
		end
	end

	-- animacao continua enquanto aberta (cor do tier, anel girando, brilho no botao)
	local conn
	local shineT = 0
	local function animate(dt)
		local t = os.clock()
		local col = tierColor(curTier, t)
		rootStroke.Color = col
		head.BackgroundColor3 = col
		head.Tampa.BackgroundColor3 = col
		coreStroke.Color = col
		glow.BackgroundColor3 = col
		orb.BackgroundColor3 = col
		tierName.TextColor3 = col
		ringStroke.Color = col
		ring2Stroke.Color = col
		ringGrad.Rotation = (t * 160) % 360
		ring2.Rotation = -(t * 40) % 360
		orbScale.Scale = 1 + math.sin(t * 3) * 0.05
		shineT += dt
		if shineT > 2.4 then
			shineT = 0
			shine.Position = UDim2.new(-0.3, 0, 0.5, 0)
			tw(shine, { Position = UDim2.new(1.3, 0, 0.5, 0) }, 0.6)
		end
		if tip.Visible then
			local mp = UserInputService:GetMouseLocation()
			local vs = workspace.CurrentCamera.ViewportSize
			local x = mp.X + 18
			if x + 260 > vs.X then x = mp.X - 268 end
			tip.Position = UDim2.fromOffset(x, math.min(mp.Y + 10, vs.Y - tip.AbsoluteSize.Y - 10))
		end
		if CoreCfg.VisualTier[curTier] and CoreCfg.VisualTier[curTier].Arcoiris then
			for i, s in ipairs(segs) do if i == curTier then s.BackgroundColor3 = col end end
		end
	end

	function M.Open()
		M.Refresh()
		if root.Visible then return end
		root.Visible = true
		sfx(SONS.UIAbrir)
		pop.Scale = 0.85
		tw(pop, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		selectTab(1)
		scroll.CanvasPosition = Vector2.zero
		-- cards entram um apos o outro
		local i = 0
		for _, sec in ipairs(SECOES) do
			for _, key in ipairs(sec.Itens) do
				local c = cards[key]
				if c then
					i += 1
					c.intro.Scale = 0.6
					task.delay(0.03 * i, function() tw(c.intro, { Scale = 1 }, 0.3, Enum.EasingStyle.Back) end)
				end
			end
		end
		if not conn then conn = RunService.RenderStepped:Connect(animate) end
	end
	function M.Close()
		if root.Visible then sfx(SONS.UIAbrir, 0.8) end
		root.Visible = false
		tip.Visible = false
		if conn then conn:Disconnect() conn = nil end
	end
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible then
			tip.Visible = false
			if conn then conn:Disconnect() conn = nil end
		end
	end)
	-- aba ativa acompanha a rolagem
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local best = 1
		for i, h in ipairs(sectionHeads) do
			if h.AbsolutePosition.Y - scroll.AbsolutePosition.Y <= 60 then best = i end
		end
		for j, b in ipairs(tabBtns) do
			local on = j == best
			b.btn.BackgroundTransparency = on and 0 or 0.82
			b.btn.TextColor3 = on and BLACK or b.cor
		end
	end)

	-- atualiza sozinho quando algo muda com a loja aberta
	local function maybe() if root.Visible then M.Refresh() end end
	for _, a in ipairs({ "CoreTier", "Wave", "CoreVidaMax", "EstoqueMadeira", "EstoquePedra" }) do estado:GetAttributeChangedSignal(a):Connect(maybe) end
	player:GetAttributeChangedSignal("Moedas"):Connect(maybe)
	task.spawn(function()
		local f = workspace:WaitForChild("Estruturas", 30)
		if f then f.ChildAdded:Connect(function() task.defer(maybe) end) f.ChildRemoved:Connect(maybe) end
	end)

	M.Panel = root
	return M
end
