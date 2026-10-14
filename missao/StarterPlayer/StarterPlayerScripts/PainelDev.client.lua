-- [PainelDev] Painel so para desenvolvedores: troca de classe/evolucao dentro da partida (F2).
-- O servidor decide quem e dev (atributo "Dev") e revalida tudo no TrocarClasseDev.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local Cfg = require(Shared.Config.Classes)

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BG = Color3.fromRGB(22, 20, 34)
local CARD = Color3.fromRGB(36, 33, 54)
local ACCENT = Color3.fromRGB(255, 200, 60)

local gui, panel, built
local evoSel = 3
local ultCheia = true

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p end
local function stroke(p, col, t) local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t or 2; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s end
local function label(parent, text, size, col)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = text
	t.TextSize = size
	t.TextColor3 = col or Color3.new(1, 1, 1)
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.Parent = parent
	return t
end

local function setOpen(open)
	if not panel then return end
	panel.Visible = true
	local target = open and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0.5, 0, 1.6, 0)
	local tw = TweenService:Create(panel, TweenInfo.new(0.3, open and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target })
	tw:Play()
	if not open then tw.Completed:Once(function() if panel.Position == target then panel.Visible = false end end) end
	panel:SetAttribute("Aberto", open)
end

local refreshers = {}
local function refresh()
	for _, f in ipairs(refreshers) do f() end
end

local function build()
	if built then return end
	built = true
	gui = Instance.new("ScreenGui")
	gui.Name = "PainelDev"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- botaozinho fixo
	local btn = Instance.new("TextButton")
	btn.Name = "BotaoDev"
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 12, 1, -12)
	btn.Size = UDim2.fromOffset(74, 30)
	btn.BackgroundColor3 = BG
	btn.FontFace = FONT
	btn.Text = "DEV [F2]"
	btn.TextSize = 14
	btn.TextColor3 = ACCENT
	btn.Parent = gui
	corner(btn, 8); stroke(btn, ACCENT, 1.5)

	panel = Instance.new("Frame")
	panel.Name = "Painel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 1.6, 0)
	panel.Size = UDim2.fromOffset(560, 300)
	panel.BackgroundColor3 = BG
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 16); stroke(panel, ACCENT, 2)
	local sc = Instance.new("UISizeConstraint"); sc.MaxSize = Vector2.new(560, 300); sc.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12); pad.PaddingLeft = UDim.new(0, 14); pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = panel

	local title = label(panel, "PAINEL DEV  •  TROCAR CLASSE", 22, ACCENT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
	close.FontFace = FONT; close.Text = "X"; close.TextSize = 16; close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = panel
	corner(close, 8)
	close.Activated:Connect(function() setOpen(false) end)

	-- cards das classes
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 40)
	row.Size = UDim2.new(1, 0, 0, 150)
	row.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.Padding = UDim.new(0, 10)
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.Parent = row
	for i, name in ipairs(Cfg.Ordem) do
		local c = Cfg.Classes[name]
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(0.25, -8, 1, 0)
		b.BackgroundColor3 = CARD
		b.AutoButtonColor = false
		b.Text = ""
		b.Parent = row
		corner(b, 12)
		local st = stroke(b, c.Cor, 2)
		local band = Instance.new("Frame")
		band.Size = UDim2.new(1, 0, 0, 56)
		band.BackgroundColor3 = c.Cor
		band.Parent = b
		corner(band, 12)
		local ic = label(band, string.upper(string.sub(c.Nome, 1, 1)), 34)
		ic.Size = UDim2.fromScale(1, 1)
		local nm = label(b, c.Nome, 18)
		nm.Position = UDim2.fromOffset(0, 62)
		local ds = label(b, c.Descricao or "", 12, Color3.fromRGB(190, 185, 210))
		ds.Position = UDim2.fromOffset(6, 88)
		ds.Size = UDim2.new(1, -12, 0, 54)
		ds.TextWrapped = true
		ds.TextYAlignment = Enum.TextYAlignment.Top
		table.insert(refreshers, function()
			local on = player:GetAttribute("Classe") == name
			st.Thickness = on and 4 or 2
			st.Color = on and ACCENT or c.Cor
			b.BackgroundColor3 = on and Color3.fromRGB(52, 46, 76) or CARD
		end)
		b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.new(0.25, -4, 1, 4) }):Play() end)
		b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.new(0.25, -8, 1, 0) }):Play() end)
		b.Activated:Connect(function()
			remotes.TrocarClasseDev:FireServer(name, evoSel, { UltCheia = ultCheia })
		end)
	end

	-- evolucao + ult
	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.new(0, 0, 1, -50)
	bottom.Size = UDim2.new(1, 0, 0, 44)
	bottom.Parent = panel
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.Padding = UDim.new(0, 8)
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.Parent = bottom
	local ev = label(bottom, "Evolução:", 18)
	ev.Size = UDim2.fromOffset(96, 40)
	for e = 1, 3 do
		local b = Instance.new("TextButton")
		b.LayoutOrder = e
		b.Size = UDim2.fromOffset(52, 36)
		b.FontFace = FONT; b.TextSize = 18; b.Text = ({ "I", "II", "III" })[e]
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = bottom
		corner(b, 8)
		table.insert(refreshers, function()
			b.BackgroundColor3 = evoSel == e and ACCENT or CARD
			b.TextColor3 = evoSel == e and BG or Color3.new(1, 1, 1)
		end)
		b.Activated:Connect(function() evoSel = e; refresh() end)
	end
	local ult = Instance.new("TextButton")
	ult.LayoutOrder = 10
	ult.Size = UDim2.fromOffset(170, 36)
	ult.FontFace = FONT; ult.TextSize = 16
	ult.Parent = bottom
	corner(ult, 8)
	table.insert(refreshers, function()
		ult.Text = ultCheia and "ULT CHEIA: SIM" or "ULT CHEIA: NÃO"
		ult.BackgroundColor3 = ultCheia and Color3.fromRGB(70, 170, 110) or CARD
		ult.TextColor3 = Color3.new(1, 1, 1)
	end)
	ult.Activated:Connect(function() ultCheia = not ultCheia; refresh() end)

	btn.Activated:Connect(function() setOpen(not panel:GetAttribute("Aberto")) end)
	player:GetAttributeChangedSignal("Classe"):Connect(refresh)
	player:GetAttributeChangedSignal("Evolucao"):Connect(function()
		evoSel = player:GetAttribute("Evolucao") or evoSel
		refresh()
	end)
	evoSel = player:GetAttribute("Evolucao") or 3
	refresh()
end

local function check()
	if player:GetAttribute("Dev") == true then build() elseif gui then gui:Destroy(); gui = nil; panel = nil; built = false; refreshers = {} end
end
player:GetAttributeChangedSignal("Dev"):Connect(check)
check()

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or input.KeyCode ~= Enum.KeyCode.F2 then return end
	if player:GetAttribute("Dev") ~= true or not panel then return end
	setOpen(not panel:GetAttribute("Aberto"))
end)
