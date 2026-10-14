-- [AvisoSpawn] Mostra DE ONDE os veritys vao sair (atributos SpawnLados / SpawnPos1 / SpawnPos2 do EstadoJogo).
-- No mundo: coluna de luz vermelha, aneis pulsando no chao, setas correndo em direcao ao Nucleo e placa
-- "VERITYS · NORTE". Na tela: seta na borda apontando para a saida (com distancia) quando ela esta fora
-- da vista, e faixa de alerta com sirene no inicio do dia / quando os lados mudam (wave 11: dois lados).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SONS = require(Shared:WaitForChild("Config"):WaitForChild("Sons"))
local WCfg = require(Shared.Config:WaitForChild("Waves"))
local estado = Shared:WaitForChild("EstadoJogo")

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local RED = Color3.fromRGB(255, 64, 56)
local ORANGE = Color3.fromRGB(255, 150, 50)
local WHITE = Color3.new(1, 1, 1)
local NOMES = { Norte = "NORTE", Sul = "SUL", Leste = "LESTE", Oeste = "OESTE" }

local function corePos()
	local core = CollectionService:GetTagged("Nucleo")[1]
	local esf = core and core:FindFirstChild("NucleoEsfera")
	return esf and esf.Position or Vector3.zero
end

local function play(def)
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.V or 0.5
	s.PlaybackSpeed = def.P or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 8)
end

local function neon(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- MARCADORES NO MUNDO ----------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "AvisoSpawn"
folder.Parent = workspace
local markers = {} -- { pos, name, beam, rings, chevrons, bb }

local function clearMarkers()
	for _, m in ipairs(markers) do m.model:Destroy() end
	markers = {}
end

local function groundY(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { folder }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ign, pl.Character) end end
	for _, n in ipairs({ "InimigosAtivos", "Estruturas", "Efeitos", "Moedas" }) do local f = workspace:FindFirstChild(n) if f then table.insert(ign, f) end end
	local z = workspace:FindFirstChild("Zona de spawn") if z then table.insert(ign, z) end
	rp.FilterDescendantsInstances = ign
	local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), rp)
	return hit and hit.Position.Y or pos.Y
end

local function makeMarker(pos, sideName)
	local m = Instance.new("Model")
	m.Name = "Saida_" .. sideName
	local gy = groundY(pos)
	local base = Vector3.new(pos.X, gy, pos.Z)
	local core = corePos()
	local toCore = Vector3.new(core.X - base.X, 0, core.Z - base.Z)
	local dist = toCore.Magnitude
	local dir = dist > 0.1 and toCore.Unit or Vector3.new(0, 0, 1)
	-- coluna de luz
	local beam = neon({ Name = "Coluna", Shape = Enum.PartType.Cylinder, Color = RED, Transparency = 0.55, Size = Vector3.new(90, 5, 5),
		CFrame = CFrame.new(base + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, m)
	local core2 = neon({ Name = "Nucleo", Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 200, 190), Transparency = 0.3, Size = Vector3.new(90, 1.2, 1.2),
		CFrame = beam.CFrame }, m)
	-- aneis no chao
	local rings = {}
	for i = 1, 2 do
		rings[i] = neon({ Name = "Anel", Shape = Enum.PartType.Cylinder, Color = RED, Transparency = 0.5, Size = Vector3.new(0.2, 6, 6),
			CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, m)
	end
	-- setas no chao (em forma de V) correndo para o Nucleo
	local chevrons = {}
	for i = 1, 5 do
		local holder = Instance.new("Model")
		holder.Name = "Seta"
		local a = neon({ Size = Vector3.new(0.9, 0.2, 4.2), Color = ORANGE, Transparency = 0.2 }, holder)
		local b = neon({ Size = Vector3.new(0.9, 0.2, 4.2), Color = ORANGE, Transparency = 0.2 }, holder)
		holder.Parent = m
		table.insert(chevrons, { a = a, b = b, phase = (i - 1) / 5 })
	end
	-- placa
	local anchor = neon({ Name = "Placa", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(base + Vector3.new(0, 14, 0)) }, m)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 74)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 1000
	bb.Adornee = anchor
	bb.Parent = anchor
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Color = RED
	st.Thickness = 2
	st.Parent = card
	local t1 = Instance.new("TextLabel")
	t1.BackgroundTransparency = 1
	t1.Size = UDim2.new(1, 0, 0, 22)
	t1.Position = UDim2.fromOffset(0, 8)
	t1.FontFace = BOLD
	t1.TextSize = 14
	t1.TextColor3 = Color3.fromRGB(255, 180, 170)
	t1.Text = "⚠ SAÍDA DOS VERITYS"
	t1.Parent = card
	local t2 = Instance.new("TextLabel")
	t2.BackgroundTransparency = 1
	t2.Size = UDim2.new(1, 0, 0, 34)
	t2.Position = UDim2.fromOffset(0, 30)
	t2.FontFace = HEAVY
	t2.TextSize = 30
	t2.TextColor3 = RED
	t2.Text = NOMES[sideName] or sideName
	t2.Parent = card
	local sc = Instance.new("UIScale")
	sc.Parent = card
	m.Parent = folder
	return { model = m, base = base, dir = dir, dist = dist, name = sideName, beam = beam, core2 = core2, rings = rings, chevrons = chevrons, bb = bb, card = card, scale = sc }
end

-- SETA NA BORDA DA TELA + FAIXA ------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AvisoSpawn"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

local edges = {}
local function edgeArrow()
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(84, 84)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(52, 52)
	arrow.BackgroundTransparency = 1
	arrow.FontFace = HEAVY
	arrow.Text = "▲"
	arrow.TextSize = 46
	arrow.TextColor3 = RED
	arrow.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(40, 0, 0)
	s.Parent = arrow
	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	lbl.Position = UDim2.new(0.5, 0, 1, -8)
	lbl.Size = UDim2.fromOffset(150, 34)
	lbl.BackgroundTransparency = 1
	lbl.FontFace = HEAVY
	lbl.TextSize = 15
	lbl.TextColor3 = WHITE
	lbl.Parent = f
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2
	s2.Color = Color3.fromRGB(40, 0, 0)
	s2.Parent = lbl
	return { frame = f, arrow = arrow, label = lbl }
end
edges[1], edges[2] = edgeArrow(), edgeArrow()

local band = Instance.new("Frame")
band.AnchorPoint = Vector2.new(0.5, 0)
band.Position = UDim2.new(0.5, 0, 0, 150)
band.Size = UDim2.fromOffset(620, 0)
band.BackgroundColor3 = Color3.fromRGB(28, 6, 6)
band.BackgroundTransparency = 0.1
band.BorderSizePixel = 0
band.ClipsDescendants = true
band.Visible = false
band.Parent = gui
Instance.new("UICorner", band).CornerRadius = UDim.new(0, 10)
local bandStroke = Instance.new("UIStroke")
bandStroke.Color = RED
bandStroke.Thickness = 2
bandStroke.Parent = band
local stripes = Instance.new("Frame")
stripes.Size = UDim2.new(1, 0, 0, 6)
stripes.BackgroundColor3 = RED
stripes.BorderSizePixel = 0
stripes.Parent = band
local bTop = Instance.new("TextLabel")
bTop.BackgroundTransparency = 1
bTop.Position = UDim2.fromOffset(0, 14)
bTop.Size = UDim2.new(1, 0, 0, 20)
bTop.FontFace = BOLD
bTop.TextSize = 15
bTop.TextColor3 = Color3.fromRGB(255, 180, 170)
bTop.Parent = band
local bMain = Instance.new("TextLabel")
bMain.BackgroundTransparency = 1
bMain.Position = UDim2.fromOffset(0, 36)
bMain.Size = UDim2.new(1, 0, 0, 40)
bMain.FontFace = HEAVY
bMain.TextSize = 32
bMain.TextColor3 = WHITE
bMain.RichText = true
bMain.Parent = band
local bandToken = 0
local function showBand(top, main, secs)
	bandToken += 1
	local my = bandToken
	bTop.Text = top
	bMain.Text = main
	band.Visible = true
	band.Size = UDim2.fromOffset(620, 0)
	TweenService:Create(band, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(620, 88) }):Play()
	play(SONS.AlertaSpawn)
	task.delay(secs or 4.5, function()
		if bandToken ~= my then return end
		TweenService:Create(band, TweenInfo.new(0.25), { Size = UDim2.fromOffset(620, 0) }):Play()
		task.delay(0.27, function() if bandToken == my then band.Visible = false end end)
	end)
end

-- ESTADO -----------------------------------------------------------------------------------
local lastLados = nil
local function sidesList()
	local s = estado:GetAttribute("SpawnLados")
	local t = {}
	if s then for n in string.gmatch(s, "[^,]+") do table.insert(t, n) end end
	return t
end
local function namesText(list)
	local t = {}
	for _, n in ipairs(list) do table.insert(t, '<font color="#FF4038">' .. (NOMES[n] or n) .. "</font>") end
	return table.concat(t, " e ")
end

local function rebuild()
	clearMarkers()
	local list = sidesList()
	local p1, p2 = estado:GetAttribute("SpawnPos1"), estado:GetAttribute("SpawnPos2")
	if list[1] and typeof(p1) == "Vector3" then table.insert(markers, makeMarker(p1, list[1])) end
	if list[2] and typeof(p2) == "Vector3" then table.insert(markers, makeMarker(p2, list[2])) end
end

local function announce(force)
	local list = sidesList()
	if #list == 0 then return end
	local key = table.concat(list, ",")
	local wave = estado:GetAttribute("Wave") or 1
	local unico = WCfg.LadoUnicoAte or 10
	if key ~= lastLados and lastLados ~= nil and #list > 1 then
		showBand("⚠ ATENÇÃO: AGORA ELES VÊM DOS DOIS LADOS!", namesText(list), 6)
	elseif wave == unico then
		showBand("⚠ WAVE " .. wave .. " · ÚLTIMA SÓ PELO " .. (NOMES[list[1]] or list[1]) .. " — DEPOIS VÊM DOS DOIS LADOS!", namesText(list), 6)
	elseif force or key ~= lastLados then
		showBand("⚠ WAVE " .. wave .. " · OS VERITYS VÃO SAIR PELO", namesText(list), 4.5)
	end
	lastLados = key
end

local fase = estado:GetAttribute("Fase")
estado:GetAttributeChangedSignal("SpawnPos1"):Connect(function() task.defer(rebuild) end)
estado:GetAttributeChangedSignal("SpawnPos2"):Connect(function() task.defer(rebuild) end)
estado:GetAttributeChangedSignal("SpawnLados"):Connect(function() task.defer(rebuild) end)
estado:GetAttributeChangedSignal("Fase"):Connect(function()
	local f = estado:GetAttribute("Fase")
	if f == "Dia" and fase ~= "Dia" then
		task.delay(0.4, function()
			local wave = estado:GetAttribute("Wave") or 1
			-- avisa em TODA wave enquanto eles saem de um lado so (1-10), quando os lados mudam,
			-- e a cada 5 waves como lembrete
			announce(wave <= (WCfg.LadoUnicoAte or 10) or wave % 5 == 0)
		end)
	elseif f == "Aguardando" or f == "Derrota" then
		lastLados = nil
	end
	fase = f
end)
rebuild()

-- ANIMACAO + SETA NA BORDA ------------------------------------------------------------------
local nightStart = 0
estado:GetAttributeChangedSignal("Fase"):Connect(function()
	if estado:GetAttribute("Fase") == "Noite" then
		nightStart = os.clock()
		-- lembrete rapido na hora do ataque
		local list = sidesList()
		if #list > 0 then
			task.delay(0.6, function() showBand("⚔ ELES ESTÃO CHEGANDO!", namesText(list), 2.8) end)
		end
		-- som da saida (posicional, perto da coluna)
		for _, m in ipairs(markers) do
			local s = Instance.new("Sound")
			s.SoundId = SONS.PortalAbrindo.Id
			s.Volume = SONS.PortalAbrindo.V
			s.PlaybackSpeed = SONS.PortalAbrindo.P or 1
			s.RollOffMinDistance = 30
			s.RollOffMaxDistance = 400
			s.Parent = m.beam
			s:Play()
			Debris:AddItem(s, 8)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local f = estado:GetAttribute("Fase")
	local active = (f == "Dia" or f == "Noite") and player:GetAttribute("EmJogo") ~= false
	-- de dia: aviso forte; de noite: forte nos primeiros 12s, depois so a coluna fraca
	local strong = f == "Dia" or (f == "Noite" and t - nightStart < 12)
	folder.Parent = active and workspace or nil
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for i, e in ipairs(edges) do
		local m = markers[i]
		if not (active and strong and m) then
			e.frame.Visible = false
		else
			local target = m.base + Vector3.new(0, 6, 0)
			local sp, onScreen = cam:WorldToViewportPoint(target)
			local d = root and math.floor((root.Position - m.base).Magnitude) or 0
			if onScreen and sp.Z > 0 and sp.X > 60 and sp.X < vp.X - 60 and sp.Y > 60 and sp.Y < vp.Y - 60 then
				e.frame.Visible = false
			else
				-- direcao na tela (se estiver atras da camera, inverte)
				local center = vp / 2
				local v = Vector2.new(sp.X, sp.Y) - center
				if sp.Z < 0 then v = -v end
				if v.Magnitude < 1 then v = Vector2.new(0, -1) end
				local dirv = v.Unit
				-- margem larga nas laterais (colunas de UPGRADES/HABILIDADES) e no topo (placar da wave)
				local marginX, marginY = 190, 130
				local sx = (center.X - marginX) / math.max(math.abs(dirv.X), 1e-3)
				local sy = (center.Y - marginY) / math.max(math.abs(dirv.Y), 1e-3)
				local pos = center + dirv * math.min(sx, sy)
				e.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
				e.arrow.Rotation = math.deg(math.atan2(dirv.Y, dirv.X)) + 90
				e.arrow.TextTransparency = 0.1 + 0.25 * math.sin(t * 6)
				e.label.Text = (NOMES[m.name] or m.name) .. "\n" .. d .. " m"
				e.frame.Visible = true
			end
		end
	end
	if not active then return end
	for _, m in ipairs(markers) do
		local pulse = 0.5 + 0.5 * math.sin(t * 4)
		m.beam.Transparency = strong and (0.45 + 0.25 * pulse) or 0.85
		m.core2.Transparency = strong and (0.25 + 0.3 * pulse) or 0.8
		m.bb.Enabled = strong
		m.scale.Scale = 1 + 0.06 * pulse
		for i, r in ipairs(m.rings) do
			local k = ((t * 0.7) + (i - 1) * 0.5) % 1
			local d = 6 + k * 26
			r.Size = Vector3.new(0.2, d, d)
			r.Transparency = strong and (0.35 + 0.65 * k) or 1
		end
		-- setas: andam da saida ate ~70% do caminho para o Nucleo
		local right = Vector3.new(-m.dir.Z, 0, m.dir.X)
		local look = CFrame.lookAt(Vector3.zero, m.dir)
		for _, c in ipairs(m.chevrons) do
			local k = (t * 0.35 + c.phase) % 1
			local p = m.base + m.dir * (6 + k * m.dist * 0.6) + Vector3.new(0, 0.2, 0)
			local cf = CFrame.new(p) * look.Rotation
			c.a.CFrame = cf * CFrame.new(-1.3, 0, 0.9) * CFrame.Angles(0, math.rad(-38), 0)
			c.b.CFrame = cf * CFrame.new(1.3, 0, 0.9) * CFrame.Angles(0, math.rad(38), 0)
			local tr = strong and (0.1 + 0.9 * math.max(0, (k - 0.6) / 0.4)) or 1
			if k < 0.08 then tr = math.max(tr, 1 - k / 0.08) end
			c.a.Transparency = tr
			c.b.Transparency = tr
		end
	end
end)
