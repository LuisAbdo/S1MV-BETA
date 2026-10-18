-- [NucleoVisual] Nucleo vivo: sobe/desce e gira, cor do TIER (Config.Core.VisualTier) em esfera, casca,
-- halo e luzes neon da base/pilones; com vida baixa pisca em vermelho. A cada tier ganha enfeites
-- (estilhacos orbitando, aneis de energia, mais faiscas). Ao EVOLUIR: clarao, esfera pulsa, ondas
-- de choque no chao, feixe de luz, explosao de faiscas, troca de cor animada, tremida e faixa na tela.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Core"))
local SONS = require(Shared.Config:WaitForChild("Sons"))
local SobCfg = require(Shared.Config:WaitForChild("Sobrevivencia"))
local estado = Shared:WaitForChild("EstadoJogo")
local remotes = Shared:WaitForChild("Remotes")
local rng = Random.new()

local core = CollectionService:GetTagged("Nucleo")[1]
while not core do
	CollectionService:GetInstanceAddedSignal("Nucleo"):Wait()
	core = CollectionService:GetTagged("Nucleo")[1]
end
local esf = core:WaitForChild("NucleoEsfera")
local casca = core:FindFirstChild("Casca")
local halo = core:FindFirstChild("Halo")
local light = esf:FindFirstChildOfClass("PointLight")
local center = esf.Position
local esfSize, cascaSize = esf.Size, casca and casca.Size
local bcf, bsz = core:GetBoundingBox()
local floorY = bcf.Position.Y - bsz.Y / 2

local floating = {}
local function add(p)
	if p and p:IsA("BasePart") then floating[p] = CFrame.new(center):ToObjectSpace(p.CFrame) end
end
add(esf); add(casca)
local haloParts = {}
if halo then
	for _, p in ipairs(halo:GetChildren()) do add(p); table.insert(haloParts, p) end
end
-- luzes neon ciano da base, pilones e painel: passam a usar a cor do tier
local neonParts = {}
for _, fname in ipairs({ "Pilones", "Base", "PainelLoja" }) do
	local f = core:FindFirstChild(fname)
	if f then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then table.insert(neonParts, p) end
		end
	end
end

local A = Cfg.Animacao
local RED = Color3.fromRGB(255, 40, 40)
local WHITE = Color3.new(1, 1, 1)
local function tierColor(tier, t)
	local v = Cfg.VisualTier[math.clamp(tier, 1, #Cfg.VisualTier)]
	if v.Arcoiris and t then return Color3.fromHSV((t * 0.12) % 1, 0.55, 1) end
	return v.Cor
end

-- faiscas constantes saindo da esfera (mais por tier)
local att = Instance.new("Attachment")
att.Parent = esf
local sparks = Instance.new("ParticleEmitter")
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.LightEmission = 1
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
sparks.Transparency = NumberSequence.new(0.1, 1)
sparks.Lifetime = NumberRange.new(0.8, 1.6)
sparks.Speed = NumberRange.new(3, 7)
sparks.SpreadAngle = Vector2.new(180, 180)
sparks.Rate = 3
sparks.Parent = att

-- ENFEITES POR TIER --------------------------------------------------------------------------
local deco = Instance.new("Folder")
deco.Name = "NucleoEnfeites"
deco.Parent = workspace
local shards, rings = {}, {}
local decoScale = 1

local function neon(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or deco
	return p
end
local function makeRing(radius, n, gaps)
	local m = Instance.new("Model")
	m.Name = "Anel"
	local segs = {}
	local len = 2 * math.pi * radius / n * 0.75
	for i = 1, n do
		if not (gaps and i % gaps == 0) then
			local a = i / n * math.pi * 2
			table.insert(segs, { p = neon({ Name = "Seg", Size = Vector3.new(len, 0.18, 0.3), Parent = m }), cf = CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, radius) })
		end
	end
	m.Parent = deco
	return { model = m, segs = segs }
end

local function rebuildDecor(tier)
	deco:ClearAllChildren()
	shards, rings = {}, {}
	for i = 1, tier do
		table.insert(shards, { p = neon({ Name = "Estilhaco", Size = Vector3.new(0.6, 0.6, 0.6) }), phase = i / tier * math.pi * 2, r = 4.4 + (i % 2) * 0.9,
			speed = 0.9 + (i % 3) * 0.15, bob = (i % 2 == 0) and 1 or -1 })
	end
	if tier >= 4 then table.insert(rings, { r = makeRing(6.2, 36, 6), tilt = math.rad(18), spd = 0.7 }) end
	if tier >= 7 then table.insert(rings, { r = makeRing(7.2, 44, 5), tilt = math.rad(-28), spd = -0.5 }) end
	if tier >= 10 then table.insert(rings, { r = makeRing(8.2, 52, 4), tilt = math.rad(62), spd = 0.35 }) end
	sparks.Rate = 3 + tier * 1.6
end

-- ESTADO DE COR --------------------------------------------------------------------------------
local tier = estado:GetAttribute("CoreTier") or 1
local blend -- { from, to, t0, dur }
local flashUntil = 0
rebuildDecor(tier)

-- REACOES: dano (tranco, piscada vermelha, rachaduras) e succao (giro rapido, engolidas) ----------
local rotAcc = 0
local spinBoost, spinUntil = 0, 0   -- graus/s extras enquanto suga
local punchS, punchV = 1, 0         -- escala da esfera (mola)
local jitterUntil, jitterAmp = 0, 0
local hitK, hitCol = 0, WHITE
local evolving = false
local currentBase = CFrame.new(center)

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 30)
	local t = os.clock()
	local y = math.sin(t * 2 * math.pi / A.Periodo) * A.Amplitude
	-- giro acumulado (acelera durante a succao e volta devagar)
	if t < spinUntil then spinBoost = math.min(720, spinBoost + dt * 1400) else spinBoost = math.max(0, spinBoost - dt * 500) end
	rotAcc += math.rad(A.GiroGrausPorSeg + spinBoost) * dt
	local rot = rotAcc
	local pos = center + Vector3.new(0, y, 0)
	if t < jitterUntil then
		local k = jitterAmp * (jitterUntil - t) / 0.35
		pos += Vector3.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k) * 0.6, rng:NextNumber(-k, k))
	end
	local base = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	currentBase = base
	for p, rel in pairs(floating) do p.CFrame = base * rel end
	-- mola da escala: tranco no dano, "engolida" na succao
	punchV += (-(punchS - 1) * 260 - punchV * 13) * dt
	punchS += punchV * dt
	if not evolving then
		if math.abs(punchS - 1) > 0.002 or math.abs(punchV) > 0.02 then
			esf.Size = esfSize * punchS
			if casca then casca.Size = cascaSize * (1 + (punchS - 1) * 0.6) end
		elseif esf.Size ~= esfSize then
			esf.Size = esfSize
			if casca then casca.Size = cascaSize end
		end
	end

	-- cor: tier (ou transicao) + alerta vermelho com vida baixa
	local col = tierColor(tier, t)
	if blend then
		local a = math.clamp((t - blend.t0) / blend.dur, 0, 1)
		col = blend.from:Lerp(tierColor(tier, t), TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		if a >= 1 then blend = nil end
	end
	local maxV = estado:GetAttribute("CoreVidaMax") or 1
	local r = math.clamp((estado:GetAttribute("CoreVida") or maxV) / math.max(1, maxV), 0, 1)
	if r < 0.35 then
		local danger = (0.35 - r) / 0.35 * (0.55 + 0.45 * math.sin(t * 8))
		col = col:Lerp(RED, math.clamp(danger, 0, 1))
	end
	-- piscada do dano (vermelho) ou da engolida (cor do item)
	hitK = math.max(0, hitK - dt * 3.5)
	if hitK > 0 then col = col:Lerp(hitCol, math.min(1, hitK * 0.85)) end
	local esfCol = t < flashUntil and WHITE or col
	esf.Color = esfCol
	for _, p in ipairs(haloParts) do p.Color = col end
	if casca then casca.Color = col:Lerp(WHITE, 0.4) end
	for _, p in ipairs(neonParts) do p.Color = col end
	if light then
		light.Color = col
		light.Brightness = (t < flashUntil and 6 or 1.8) + 0.8 * math.sin(t * (r < 0.3 and 9 or 2.5))
	end
	sparks.Color = ColorSequence.new(col:Lerp(WHITE, 0.5), col)

	-- enfeites
	for _, s in ipairs(shards) do
		local a = t * s.speed + s.phase
		local p = pos + Vector3.new(math.cos(a) * s.r * decoScale, math.sin(t * 2 + s.phase) * 0.8 * s.bob, math.sin(a) * s.r * decoScale)
		s.p.CFrame = CFrame.new(p) * CFrame.Angles(t * 2, t * 3 + s.phase, math.rad(45))
		s.p.Size = Vector3.one * 0.6 * decoScale
		s.p.Color = col
	end
	for _, rg in ipairs(rings) do
		local cf = CFrame.new(pos) * CFrame.Angles(rg.tilt, t * rg.spd, 0) * CFrame.new()
		for _, sg in ipairs(rg.r.segs) do
			sg.p.CFrame = cf * CFrame.new(sg.cf.Position * decoScale) * (sg.cf - sg.cf.Position)
			sg.p.Color = col
			sg.p.Transparency = 0.25 + 0.2 * math.sin(t * 3)
		end
	end
end)

-- ANIMACAO DE EVOLUCAO ------------------------------------------------------------------------
local function playSound(def, delay)
	task.delay(delay or 0, function()
		local s = Instance.new("Sound")
		s.SoundId = def.Id
		s.Volume = def.V or 0.6
		s.PlaybackSpeed = def.P or 1
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 8)
	end)
end

local function shockwave(color, delay, maxD, dur)
	task.delay(delay or 0, function()
		local ring = neon({ Name = "Onda", Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.15, Size = Vector3.new(0.3, 4, 4),
			CFrame = CFrame.new(center.X, floorY + 0.3, center.Z) * CFrame.Angles(0, 0, math.rad(90)), Parent = workspace })
		TweenService:Create(ring, TweenInfo.new(dur or 1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, maxD, maxD), Transparency = 1 }):Play()
		Debris:AddItem(ring, (dur or 1) + 0.1)
	end)
end

local function beam(color)
	local b = neon({ Name = "Feixe", Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.1, Size = Vector3.new(160, 7, 7),
		CFrame = CFrame.new(center.X, floorY + 80, center.Z) * CFrame.Angles(0, 0, math.rad(90)), Parent = workspace })
	TweenService:Create(b, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(160, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(b, 1.4)
end

local function shake(dur, power)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - center).Magnitude > 140 then return end
	local t0 = os.clock()
	local name = "TremidaNucleo" .. tostring(t0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 5, function()
		local a = os.clock() - t0
		if a > dur then RunService:UnbindFromRenderStep(name) return end
		local k = power * (1 - a / dur)
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end

-- faixa na tela
local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "NucleoEvoluiu"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = true
bannerGui.DisplayOrder = 35
bannerGui.Parent = player:WaitForChild("PlayerGui")
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local band = Instance.new("Frame")
band.AnchorPoint = Vector2.new(0.5, 0.5)
band.Position = UDim2.fromScale(0.5, 0.3)
band.Size = UDim2.new(1, 0, 0, 0)
band.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
band.BackgroundTransparency = 0.25
band.BorderSizePixel = 0
band.ClipsDescendants = true
band.Visible = false
band.Parent = bannerGui
local bandGrad = Instance.new("UIGradient")
bandGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1) })
bandGrad.Parent = band
local function bandLabel(y, size, txtSize)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, 0, 0.5, y)
	l.Size = UDim2.new(1, 0, 0, size)
	l.BackgroundTransparency = 1
	l.FontFace = HEAVY
	l.TextSize = txtSize
	l.TextColor3 = WHITE
	l.Parent = band
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(10, 10, 14)
	s.Parent = l
	return l
end
local bandTop = bandLabel(-18, 30, 18)
local bandMain = bandLabel(14, 46, 40)
local function showBanner(newTier, color)
	bandTop.Text = "NÚCLEO EVOLUIU!"
	bandTop.TextColor3 = WHITE
	bandMain.Text = "TIER " .. (Cfg.Romano[newTier] or newTier) .. "  ·  " .. Cfg.VisualTier[newTier].Nome
	bandMain.TextColor3 = color
	band.Visible = true
	band.Size = UDim2.new(1, 0, 0, 0)
	bandMain.Position = UDim2.new(0.5, 60, 0.5, 14)
	TweenService:Create(band, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 96) }):Play()
	TweenService:Create(bandMain, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 14) }):Play()
	local my = newTier
	task.delay(3, function()
		if bandMain.Text:find(Cfg.VisualTier[my].Nome, 1, true) then
			TweenService:Create(band, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
			task.delay(0.32, function() band.Visible = false end)
		end
	end)
end

local function evolve(oldTier, newTier)
	local oldCol = tierColor(oldTier, os.clock())
	local newCol = tierColor(newTier, os.clock())
	evolving = true
	task.delay(1.4, function() evolving = false end)
	playSound(SONS.NucleoEvolui)
	playSound(SONS.NucleoFanfarra, 0.55)
	-- 1) carrega: a esfera encolhe e as faiscas sugam
	flashUntil = os.clock() + 0.6
	TweenService:Create(esf, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = esfSize * 0.6 }):Play()
	task.delay(0.35, function()
		-- 2) explode: esfera estoura maior e volta, cor nova, ondas, feixe, faiscas
		blend = { from = oldCol, t0 = os.clock(), dur = 1.4 }
		tier = newTier
		rebuildDecor(newTier)
		decoScale = 0.1
		local dv = Instance.new("NumberValue")
		dv.Value = 0.1
		dv.Changed:Connect(function(v) decoScale = v end)
		TweenService:Create(dv, TweenInfo.new(0.9, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = 1 }):Play()
		Debris:AddItem(dv, 1.2)
		esf.Size = esfSize * 1.7
		TweenService:Create(esf, TweenInfo.new(0.9, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = esfSize }):Play()
		if casca then
			casca.Size = cascaSize * 1.45
			TweenService:Create(casca, TweenInfo.new(0.9, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = cascaSize }):Play()
		end
		shockwave(newCol, 0, 80, 1.1)
		shockwave(WHITE, 0.12, 50, 0.8)
		shockwave(newCol, 0.3, 110, 1.4)
		beam(newCol)
		sparks.Color = ColorSequence.new(WHITE, newCol)
		sparks.Speed = NumberRange.new(18, 34)
		sparks:Emit(90)
		task.delay(0.1, function() sparks.Speed = NumberRange.new(3, 7) end)
		shake(0.6, 1.6)
		showBanner(newTier, newCol)
	end)
end

-- DANO NO NUCLEO -----------------------------------------------------------------------------
-- tranco + tremida proporcionais ao dano, esfera pisca vermelho, faiscas, som; com a vida
-- caindo aparecem rachaduras brilhando na esfera (e fumaca quando esta critico).
local cracks = {}
local smoke
local R = esfSize.X / 2
local function addCrack()
	local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(-1, 1))
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.yAxis
	local pnt = currentBase.Position + dir * (R * 1.02)
	local tan = dir:Cross(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))).Unit
	local len = rng:NextNumber(R * 0.5, R * 0.95)
	local p = neon({ Name = "Rachadura", Size = Vector3.new(0.24, 0.24, len), Color = Color3.fromRGB(255, 90, 40), Transparency = 1, Parent = workspace })
	p.CFrame = CFrame.lookAt(pnt, pnt + tan)
	floating[p] = currentBase:ToObjectSpace(p.CFrame)
	TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 0.1 }):Play()
	table.insert(cracks, p)
end
local function updateCracks(ratio)
	local want = ratio < 0.15 and 12 or ratio < 0.35 and 8 or ratio < 0.6 and 4 or 0
	while #cracks < want do addCrack() end
	while #cracks > want do
		local p = table.remove(cracks)
		floating[p] = nil
		p:Destroy()
	end
	if ratio < 0.15 and not smoke then
		smoke = Instance.new("ParticleEmitter")
		smoke.Name = "FumacaCritico"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(60, 50, 50))
		smoke.Size = NumberSequence.new(1.2, 4)
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(2, 4)
		smoke.Acceleration = Vector3.new(0, 4, 0)
		smoke.Rate = 10
		smoke.Parent = att
	elseif ratio >= 0.15 and smoke then
		smoke:Destroy(); smoke = nil
	end
end
local lastHp = estado:GetAttribute("CoreVida")
local lastHitSnd, lastCrackSnd = 0, 0
estado:GetAttributeChangedSignal("CoreVida"):Connect(function()
	local v = estado:GetAttribute("CoreVida") or 0
	local maxV = math.max(1, estado:GetAttribute("CoreVidaMax") or 1)
	local before = #cracks
	if lastHp and v < lastHp then
		local k = math.clamp((lastHp - v) / (maxV * 0.015), 0.3, 1.3)
		punchV -= 3.2 * k
		jitterUntil = os.clock() + 0.35
		jitterAmp = 0.35 * k
		hitK = 1
		hitCol = Color3.fromRGB(255, 60, 50)
		sparks:Emit(math.floor(4 + 6 * k))
		if os.clock() - lastHitSnd > 0.18 and SONS.NucleoDano then
			lastHitSnd = os.clock()
			playSound(SONS.NucleoDano)
		end
	end
	lastHp = v
	updateCracks(v / maxV)
	if #cracks > before and os.clock() - lastCrackSnd > 1 and SONS.NucleoRachando then
		lastCrackSnd = os.clock()
		playSound(SONS.NucleoRachando)
	end
end)

-- SUCCAO DOS MATERIAIS ------------------------------------------------------------------------
-- (os itens voando ficam no ColetaCliente; aqui o Nucleo reage: vortice no chao, giro rapido,
-- uma "engolida" para cada item que chega e um estouro no fim)
local function vortex(dur, col)
	local folder = Instance.new("Folder")
	folder.Name = "VorticeNucleo"
	folder.Parent = workspace
	local arms = {}
	for a = 1, 3 do
		for j = 1, 12 do
			table.insert(arms, { p = neon({ Name = "Espiral", Size = Vector3.new(1.3, 0.1, 0.45), Color = col, Transparency = 1, Parent = folder }), a = a, f = j / 12 })
		end
	end
	local column = neon({ Name = "Coluna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(center.Y - floorY, 1.6, 1.6), Color = col, Transparency = 1, Parent = folder,
		CFrame = CFrame.new(center.X, (center.Y + floorY) / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)) })
	local t0 = os.clock()
	local total = dur * 1.25
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / total
		if u >= 1 then conn:Disconnect(); folder:Destroy() return end
		local fadeIn = math.clamp(u / 0.15, 0, 1)
		local fadeOut = math.clamp((1 - u) / 0.25, 0, 1)
		local vis = fadeIn * fadeOut
		local Rv = 15 * (1 - 0.7 * u)
		for _, e in ipairs(arms) do
			local r = 1.5 + Rv * e.f
			local ang = e.a / 3 * math.pi * 2 + e.f * 2.8 - os.clock() * 6
			local pnt = Vector3.new(center.X + math.cos(ang) * r, floorY + 0.25, center.Z + math.sin(ang) * r)
			e.p.CFrame = CFrame.lookAt(pnt, pnt + Vector3.new(-math.sin(ang), 0, math.cos(ang)))
			e.p.Transparency = 1 - vis * (1 - e.f * 0.65)
		end
		column.Transparency = 1 - vis * (0.45 + 0.2 * math.sin(os.clock() * 30))
		column.Size = Vector3.new(column.Size.X, 1.2 + 0.6 * math.sin(os.clock() * 18), 1.2 + 0.6 * math.sin(os.clock() * 18))
	end)
end

local lastGulp = 0
local function gulp(color, strong)
	punchV += strong and 4.5 or 2.2
	hitK = strong and 1 or 0.75
	hitCol = color
	sparks:Emit(strong and 30 or 4)
	if os.clock() - lastGulp > 0.07 and SONS.NucleoEngole then
		lastGulp = os.clock()
		local s = Instance.new("Sound")
		s.SoundId = SONS.NucleoEngole.Id
		s.Volume = (SONS.NucleoEngole.V or 0.5) * (strong and 1.3 or 0.7)
		s.PlaybackSpeed = (SONS.NucleoEngole.P or 1) * rng:NextNumber(0.9, 1.25)
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 3)
	end
end

remotes:WaitForChild("Efeito").OnClientEvent:Connect(function(kind, _, list)
	if kind ~= "Sugar" or typeof(list) ~= "table" then return end
	local n = #list
	if n == 0 then return end
	local dur = SobCfg.Succao.Duracao
	local col = tierColor(tier, os.clock())
	spinUntil = os.clock() + dur
	vortex(dur, col)
	-- mesmo calculo de tempo do voo no ColetaCliente: cada item chega em (i-1)*atraso + 75% da duracao
	local last = 0
	for i, entry in ipairs(list) do
		local arrive = (i - 1) * math.min(0.06, 0.5 / n) + dur * 0.75
		last = math.max(last, arrive)
		local info = typeof(entry) == "table" and SobCfg.Itens[entry.kind]
		task.delay(arrive, function() gulp(info and info.Cor or col, false) end)
	end
	task.delay(last + 0.08, function()
		gulp(Color3.new(1, 1, 1), true)
		shockwave(col, 0, 26, 0.55)
	end)
end)

estado:GetAttributeChangedSignal("CoreTier"):Connect(function()
	local nt = estado:GetAttribute("CoreTier") or 1
	if nt > tier then
		evolve(tier, nt)
	else
		-- reinicio da run: volta direto, sem animacao
		tier = nt
		blend = nil
		rebuildDecor(nt)
	end
end)
