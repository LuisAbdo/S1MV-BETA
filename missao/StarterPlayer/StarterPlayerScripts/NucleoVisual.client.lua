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
local estado = Shared:WaitForChild("EstadoJogo")

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

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local y = math.sin(t * 2 * math.pi / A.Periodo) * A.Amplitude
	local rot = math.rad(A.GiroGrausPorSeg * t)
	local pos = center + Vector3.new(0, y, 0)
	local base = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	for p, rel in pairs(floating) do p.CFrame = base * rel end

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
