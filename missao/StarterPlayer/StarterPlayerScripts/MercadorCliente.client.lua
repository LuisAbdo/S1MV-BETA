-- [MercadorCliente] Loja do Mercador (Casa na floresta) e o minimapa comprado nela.
-- O servidor (MercadorService) valida distancia, nivel e custo; aqui so mostra.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local estado = Shared:WaitForChild("EstadoJogo")
local Cfg = require(Shared.Config.Sobrevivencia)
local Custos = require(Shared:WaitForChild("Custos"))
local SONS = require(Shared.Config.Sons)
local M = Cfg.Mercador

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local WOOD = Color3.fromRGB(120, 78, 44)
local WOOD2 = Color3.fromRGB(86, 56, 32)
local PAPER = Color3.fromRGB(246, 228, 190)
local INK = Color3.fromRGB(58, 36, 18)
local GREEN = Color3.fromRGB(96, 190, 96)
local ATTR = { Mochila = "NivelMochila", Machado = "NivelMachado", Mapa = "NivelMapa" }

local function tween(o, t, p, s, d) local tw = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out), p); tw:Play(); return tw end
local function sfx(def)
	if not def then return end
	local s = Instance.new("Sound"); s.SoundId = def.Id; s.Volume = def.V or 0.5; s.PlaybackSpeed = def.P or 1
	s.Parent = game:GetService("SoundService"); s:Play(); game:GetService("Debris"):AddItem(s, 3)
end
local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p end
local function stroke(p, col, t) local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t or 2; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s end
local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = props.FontFace or FONT
	t.TextColor3 = props.TextColor3 or INK
	for k, v in pairs(props) do if k ~= "FontFace" and k ~= "TextColor3" then t[k] = v end end
	t.Parent = parent
	return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "Mercador"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

-- LOJA ------------------------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "Loja"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.fromOffset(620, 330)
panel.BackgroundColor3 = WOOD
panel.Visible = false
panel.ZIndex = 20
panel.Parent = gui
corner(panel, 14)
stroke(panel, WOOD2, 4)
local sc = Instance.new("UIScale"); sc.Parent = panel
local sizeC = Instance.new("UISizeConstraint"); sizeC.MaxSize = Vector2.new(620, 330); sizeC.Parent = panel

local title = text(panel, { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 36), Text = "LOJA DO MERCADOR", TextSize = 28, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
stroke(title, WOOD2, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
local sub = text(panel, { Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -36, 0, 18), Text = "Pago com o estoque do Núcleo (madeira e pedra que vocês entregaram)", TextSize = 13, FontFace = BOLD, TextColor3 = Color3.fromRGB(240, 210, 160), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
local stockLbl = text(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -62, 0, 14), Size = UDim2.fromOffset(240, 26), Text = "", TextSize = 15, FontFace = BOLD, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Right, RichText = true, ZIndex = 21 })
local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(190, 70, 60)
close.Text = "X"; close.FontFace = FONT; close.TextSize = 20; close.TextColor3 = Color3.new(1, 1, 1)
close.ZIndex = 22
close.Parent = panel
corner(close, 8)

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Position = UDim2.fromOffset(16, 76)
row.Size = UDim2.new(1, -32, 1, -92)
row.ZIndex = 21
row.Parent = panel
local ll = Instance.new("UIListLayout"); ll.FillDirection = Enum.FillDirection.Horizontal; ll.Padding = UDim.new(0, 12); ll.Parent = row

local cards = {}
local ICON = { Mochila = "▣", Machado = "⚒", Mapa = "◎" }
for i, it in ipairs(M.Itens) do
	local c = Instance.new("Frame")
	c.LayoutOrder = i
	c.Size = UDim2.new(1 / #M.Itens, -8, 1, 0)
	c.BackgroundColor3 = PAPER
	c.ZIndex = 21
	c.Parent = row
	corner(c, 10)
	stroke(c, WOOD2, 2)
	local ic = text(c, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 50), Text = ICON[it.Id] or "★", TextSize = 44, TextColor3 = WOOD, ZIndex = 22 })
	text(c, { Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 0, 24), Text = it.Nome, TextSize = 19, ZIndex = 22 })
	text(c, { Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 34), Text = it.Texto, TextSize = 13, FontFace = BOLD, TextWrapped = true, TextColor3 = Color3.fromRGB(110, 80, 50), ZIndex = 22 })
	local lvl = text(c, { Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 18), Text = "", TextSize = 13, FontFace = BOLD, TextColor3 = WOOD, ZIndex = 22 })
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.Position = UDim2.new(0.5, 0, 1, -10)
	btn.Size = UDim2.new(1, -20, 0, 40)
	btn.BackgroundColor3 = GREEN
	btn.FontFace = FONT
	btn.TextScaled = true
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = true
	btn.ZIndex = 22
	btn.Parent = c
	corner(btn, 8)
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6); pad.Parent = btn
	local bs = stroke(btn, Color3.fromRGB(40, 90, 40), 2)
	bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.MouseButton1Click:Connect(function()
		sfx(SONS.UIClique)
		remotes.ComprarMercador:FireServer(it.Id)
		local s2 = Instance.new("UIScale", c); s2.Scale = 0.95; tween(s2, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		game:GetService("Debris"):AddItem(s2, 0.3)
	end)
	cards[it.Id] = { it = it, btn = btn, lvl = lvl, icon = ic }
end

local function refresh()
	stockLbl.Text = '<font color="#F2C08A">' .. (estado:GetAttribute("EstoqueMadeira") or 0) .. ' madeira</font>  ·  <font color="#E6E8EE">' .. (estado:GetAttribute("EstoquePedra") or 0) .. " pedra</font>"
	for id, c in pairs(cards) do
		local lv = player:GetAttribute(ATTR[id]) or 0
		local max = #c.it.Niveis
		c.lvl.Text = max > 1 and ("Nível " .. lv .. "/" .. max) or (lv > 0 and "Comprado" or "")
		local cost = c.it.Niveis[lv + 1]
		if not cost then
			c.btn.Text = max > 1 and "MÁXIMO" or "COMPRADO"
			c.btn.BackgroundColor3 = Color3.fromRGB(150, 140, 120)
		else
			c.btn.Text = Custos.Texto(cost)
			c.btn.BackgroundColor3 = Custos.Tem(estado, cost) and GREEN or Color3.fromRGB(176, 120, 96)
		end
	end
end
for _, a in ipairs({ "EstoqueMadeira", "EstoquePedra" }) do estado:GetAttributeChangedSignal(a):Connect(refresh) end
for _, a in pairs(ATTR) do player:GetAttributeChangedSignal(a):Connect(refresh) end

local function open()
	refresh()
	panel.Visible = true
	sc.Scale = 0.85
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	sfx(SONS.UIAbrir)
end
local function hide() panel.Visible = false end
close.MouseButton1Click:Connect(hide)
remotes:WaitForChild("AbrirMercador").OnClientEvent:Connect(open)
UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and panel.Visible and (i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace) then hide() end
end)
-- fecha sozinho ao se afastar da Casa
RunService.Heartbeat:Connect(function()
	if not panel.Visible then return end
	local casa = workspace:FindFirstChild("CasaMercador")
	local npc = casa and casa:FindFirstChild("Mercador")
	local r = npc and npc:FindFirstChild("HumanoidRootPart")
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r or not me or (r.Position - me.Position).Magnitude > M.DistanciaLoja + 6 then hide() end
end)

-- MINIMAPA (so para quem comprou o mapa) ---------------------------------------------------------
local SIZE = 176
local ESCALA = 2.2  -- studs por pixel (176 px ~ 390 studs)
local map = Instance.new("Frame")
map.Name = "Minimapa"
map.AnchorPoint = Vector2.new(1, 0)
map.Position = UDim2.new(1, -20, 0, 16)
map.Size = UDim2.fromOffset(SIZE, SIZE)
map.BackgroundColor3 = Color3.fromRGB(70, 128, 58)
map.BackgroundTransparency = 0.1
map.ClipsDescendants = true
map.Visible = false
map.Parent = gui
corner(map, SIZE / 2)
stroke(map, PAPER, 3)
local mapInner = Instance.new("Frame")
mapInner.BackgroundTransparency = 1
mapInner.Size = UDim2.fromScale(1, 1)
mapInner.Parent = map
local norte = text(map, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(20, 16), Text = "N", TextSize = 14, TextColor3 = PAPER, ZIndex = 5 })

local function dot(color, size, z, shape)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	d.ZIndex = z or 3
	d.Parent = mapInner
	if shape ~= "quadrado" then corner(d, size) end
	stroke(d, Color3.fromRGB(20, 20, 20), 1.5)
	return d
end
local coreDot = dot(Color3.fromRGB(110, 230, 255), 12, 4)
local casaDot = dot(Color3.fromRGB(240, 170, 80), 11, 4, "quadrado")
local meDot = dot(Color3.new(1, 1, 1), 10, 6)
local meArrow = text(meDot, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(14, 12), Text = "▲", TextSize = 12, TextColor3 = Color3.new(1, 1, 1), ZIndex = 7 })
local others = {}

local function toMap(pos, center)
	local dx, dz = (pos.X - center.X) / ESCALA, (pos.Z - center.Z) / ESCALA
	local r = math.sqrt(dx * dx + dz * dz)
	local lim = SIZE / 2 - 8
	if r > lim then dx, dz = dx / r * lim, dz / r * lim end -- prende na borda (aponta a direcao)
	return UDim2.fromOffset(SIZE / 2 + dx, SIZE / 2 + dz)
end

local mapAcc = 0
RunService.RenderStepped:Connect(function(dt)
	local has = (player:GetAttribute("NivelMapa") or 0) > 0
	map.Visible = has
	if not has then return end
	mapAcc += dt
	if mapAcc < 0.05 then return end
	mapAcc = 0
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not me then return end
	local center = me.Position
	meDot.Position = UDim2.fromScale(0.5, 0.5)
	local look = workspace.CurrentCamera.CFrame.LookVector
	meDot.Rotation = math.deg(math.atan2(look.X, -look.Z))
	local core = CollectionService:GetTagged("Nucleo")[1]
	local esf = core and core:FindFirstChild("NucleoEsfera")
	if esf then coreDot.Position = toMap(esf.Position, center) end
	local cp = estado:GetAttribute("CasaPos")
	casaDot.Visible = typeof(cp) == "Vector3"
	if casaDot.Visible then casaDot.Position = toMap(cp, center) end
	local seen = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player then
			local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if r then
				seen[pl] = true
				others[pl] = others[pl] or dot(Color3.fromRGB(120, 255, 140), 8, 5)
				others[pl].Position = toMap(r.Position, center)
			end
		end
	end
	for pl, d in pairs(others) do if not seen[pl] then d:Destroy(); others[pl] = nil end end
end)
