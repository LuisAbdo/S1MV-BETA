-- [ClassesVFX] Efeitos visuais das habilidades de classe (100% cliente).
-- O servidor calcula dano/cura e so avisa "ClasseFX" com posicoes; aqui fica todo o espetaculo:
-- luz, particulas, aneis, rastros, distorcao de camera e tremor proporcional a distancia.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local SONS = require(Shared.Config.Sons)

local rng = Random.new()
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "ClassesVFX"
folder.Parent = workspace

local TEX = {
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
	fogo = "rbxasset://textures/particles/fire_main.dds",
	faisca = "rbxasset://textures/particles/fire_sparks_main.dds",
}

-- BASICO -------------------------------------------------------------------------------------
local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function part(o)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = o.material or Enum.Material.Neon
	p.Color = o.color or Color3.new(1, 1, 1)
	if o.shape then p.Shape = o.shape end
	p.Size = o.size or Vector3.one
	p.CFrame = o.cf or CFrame.new()
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = o.parent or folder
	if o.life then Debris:AddItem(p, o.life) end
	return p
end

local function light(parent, color, range, brightness, dur)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false
	l.Parent = parent
	if dur then tween(l, dur, { Brightness = 0, Range = range * 0.4 }) end
	return l
end

local function emitter(parent, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or TEX.brilho
	e.Color = typeof(o.color) == "ColorSequence" and o.color or ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.LightEmission = o.emission or 0.8
	e.LightInfluence = 0
	e.Size = o.sizeSeq or NumberSequence.new(o.size or 1, o.sizeEnd or 0)
	e.Transparency = o.transp or NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(o.lifeMin or 0.4, o.lifeMax or 0.8)
	e.Speed = NumberRange.new(o.speedMin or 6, o.speedMax or 12)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	local rs = o.rot or 90
	e.RotSpeed = NumberRange.new(-rs, rs)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Rate = o.rate or 0
	e.Enabled = (o.rate or 0) > 0
	if o.shape then e.Shape = o.shape end
	if o.zoffset then e.ZOffset = o.zoffset end
	e.Parent = parent
	if o.emit then e:Emit(o.emit) end
	return e
end

-- uma "ancora" invisivel para particulas/luzes
local function anchor(pos, life)
	return part({ cf = CFrame.new(pos), transparency = 1, size = Vector3.one * 0.2, life = life })
end

local function sound(def, pos, vol, pitch)
	if not def or not def.Id then return end
	local p = anchor(pos, 6)
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.6) * (vol or 1)
	s.PlaybackSpeed = (def.P or 1) * (pitch or 1) * rng:NextNumber(0.94, 1.06)
	s.RollOffMaxDistance = 220
	s.RollOffMinDistance = 12
	s.Parent = p
	s:Play()
end

local function groundY(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	for _, n in ipairs({ "InimigosAtivos", "InimigosMortos", "Aliados", "Moedas", "Efeitos" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ignore, f) end
	end
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), rp)
	return hit and hit.Position or pos
end

-- CAMERA: tremor + "soco" de FOV + clarao de cor -------------------------------------------
local shake = 0
local fovPunch = 0
local baseFov
local function addShake(amount, pos)
	if pos then
		local cam = camera.CFrame.Position
		local d = (cam - pos).Magnitude
		amount *= math.clamp(1 - (d - 20) / 110, 0, 1)
	end
	shake = math.min(1.6, shake + amount)
end
local function punchFov(a) fovPunch = math.min(10, fovPunch + a) end

RunService:BindToRenderStep("ClassesVFXCamera", Enum.RenderPriority.Camera.Value + 3, function(dt)
	camera = workspace.CurrentCamera
	if shake > 0.002 then
		local s = shake * shake
		local t = os.clock() * 38
		local off = CFrame.Angles(
			math.rad(math.noise(t, 1.7) * 3.2 * s),
			math.rad(math.noise(t, 9.1) * 3.2 * s),
			math.rad(math.noise(t, 4.4) * 2.2 * s))
		camera.CFrame = camera.CFrame * off
		shake = math.max(0, shake - dt * 2.4)
	end
	if fovPunch > 0.01 then
		baseFov = baseFov or camera.FieldOfView
		fovPunch = math.max(0, fovPunch - dt * 26)
		camera.FieldOfView = baseFov + fovPunch
		if fovPunch <= 0.01 then camera.FieldOfView = baseFov; baseFov = nil end
	end
end)

local function screenTint(color, strength, dur)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = Color3.new(1, 1, 1):Lerp(color, strength)
	cc.Brightness = 0.08 * strength
	cc.Parent = Lighting
	tween(cc, dur, { TintColor = Color3.new(1, 1, 1), Brightness = 0 })
	Debris:AddItem(cc, dur + 0.1)
end

local function isNear(pos, d) return (camera.CFrame.Position - pos).Magnitude <= (d or 90) end

-- PECAS REUTILIZAVEIS ------------------------------------------------------------------------
-- anel "deitado" que expande no chao
local function groundRing(pos, radius, color, dur, thick, startR)
	local r0 = startR or 1
	local p = part({
		shape = Enum.PartType.Cylinder, color = color, transparency = 0.1,
		size = Vector3.new(thick or 0.25, r0 * 2, r0 * 2),
		cf = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		life = dur + 0.05,
	})
	tween(p, dur, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quint)
	return p
end

-- anel "de pe" (onda de choque) usando um disco fino com material ForceField
local function shockSphere(pos, radius, color, dur)
	local p = part({ shape = Enum.PartType.Ball, color = color, material = Enum.Material.ForceField, size = Vector3.one * 2, cf = CFrame.new(pos), life = dur + 0.05 })
	tween(p, dur, { Size = Vector3.one * radius * 2.1, Transparency = 1 }, Enum.EasingStyle.Quint)
	return p
end

local function flash(pos, color, size, dur, rangeL)
	local p = part({ shape = Enum.PartType.Ball, color = color, size = Vector3.one * size * 0.3, cf = CFrame.new(pos), life = dur + 0.05 })
	tween(p, dur, { Size = Vector3.one * size, Transparency = 1 }, Enum.EasingStyle.Quart)
	light(p, color, rangeL or size * 3, 6, dur)
	return p
end

-- pedacos que voam e quicam (detritos / faiscas solidas)
local function debris(pos, n, color, speed, material, sizeMul)
	for _ = 1, n do
		local s = rng:NextNumber(0.25, 0.7) * (sizeMul or 1)
		local p = part({ color = color, material = material or Enum.Material.Slate, size = Vector3.new(s, s, s), cf = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.9, 1.8), rng:NextNumber(-1, 1)) * (speed or 18)
		local spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		local floorY = pos.Y + 0.2
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not p.Parent or os.clock() - t0 > 1.6 then
				conn:Disconnect()
				if p.Parent then
					tween(p, 0.3, { Transparency = 1, Size = p.Size * 0.3 })
					Debris:AddItem(p, 0.35)
				end
				return
			end
			v += Vector3.new(0, -workspace.Gravity * 0.5 * dt, 0)
			local np = p.Position + v * dt
			if np.Y < floorY and v.Y < 0 then np = Vector3.new(np.X, floorY, np.Z); v = Vector3.new(v.X * 0.5, -v.Y * 0.35, v.Z * 0.5) end
			p.CFrame = CFrame.new(np) * (p.CFrame - p.Position) * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
		end)
	end
end

-- raio em zigue-zague entre dois pontos
local function lightning(a, b, color, width, life, segs)
	segs = segs or 7
	local prev = a
	local dir = b - a
	for i = 1, segs do
		local t = i / segs
		local nxt = a + dir * t
		if i < segs then nxt += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * math.min(2.2, dir.Magnitude * 0.12) end
		local len = (nxt - prev).Magnitude
		if len > 0.05 then
			local p = part({ color = color, size = Vector3.new(width or 0.18, width or 0.18, len), cf = CFrame.lookAt(prev, nxt) * CFrame.new(0, 0, -len / 2), life = (life or 0.12) + 0.05 })
			tween(p, life or 0.12, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) })
		end
		prev = nxt
	end
end

-- texto/icone flutuante (coracoes, "+")
local function floatIcon(pos, text, color, size, rise, life)
	local p = anchor(pos, life + 0.1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size, size)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = color:Lerp(Color3.new(0, 0, 0), 0.6); st.Parent = t
	local sc = Instance.new("UIScale"); sc.Scale = 0.2; sc.Parent = t
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(p, life, { Position = pos + Vector3.new(rng:NextNumber(-1, 1), rise, rng:NextNumber(-1, 1)) }, Enum.EasingStyle.Sine)
	task.delay(life * 0.55, function()
		tween(t, life * 0.45, { TextTransparency = 1 })
		tween(st, life * 0.45, { Transparency = 1 })
	end)
end

-- fantasma do personagem (pos-imagem)
local function afterimage(char, color, life, offset)
	if not char then return end
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 then
			local g = part({ color = color, size = d.Size, cf = d.CFrame + (offset or Vector3.zero), transparency = 0.35, material = Enum.Material.Neon, life = life + 0.05 })
			if d.Name == "Head" then g.Shape = Enum.PartType.Ball end
			tween(g, life, { Transparency = 1, Size = d.Size * 1.15 })
		end
	end
end

local function charOf(pl)
	local c = typeof(pl) == "Instance" and pl:IsA("Player") and pl.Character
	return c, c and c:FindFirstChild("HumanoidRootPart")
end

-- aura presa ao personagem por um tempo
local function attachAura(root, life, o)
	local att = Instance.new("Attachment")
	att.Parent = root
	local e = emitter(att, o)
	local l = o.light and light(root, o.lightColor or (typeof(o.color) == "Color3" and o.color) or Color3.new(1, 1, 1), o.light, 2.5)
	task.delay(life, function()
		e.Enabled = false
		if l then tween(l, 0.4, { Brightness = 0 }) end
		Debris:AddItem(att, 1.5)
		if l then Debris:AddItem(l, 0.5) end
	end)
	return e
end
-- EXPLOSAO "BONITA" (usada por granadas, chuva e plasma) ------------------------------------
local function bigExplosion(pos, radius, color, opts)
	opts = opts or {}
	color = color or Color3.fromRGB(255, 150, 40)
	local hot = color:Lerp(Color3.new(1, 1, 0.85), 0.55)
	local g = groundY(pos)
	-- nucleo branco + bola de fogo em camadas
	flash(pos + Vector3.new(0, 0.8, 0), Color3.new(1, 1, 0.95), radius * 0.9, 0.12, radius * 5)
	local fire = part({ shape = Enum.PartType.Ball, color = hot, size = Vector3.one * radius * 0.4, cf = CFrame.new(pos + Vector3.new(0, 1, 0)), life = 0.5 })
	tween(fire, 0.22, { Size = Vector3.one * radius * 1.7, Color = color }, Enum.EasingStyle.Quint)
	task.delay(0.16, function() if fire.Parent then tween(fire, 0.3, { Transparency = 1, Size = Vector3.one * radius * 1.9 }) end end)
	shockSphere(pos, radius * 1.1, color, 0.4)
	groundRing(g, radius * 1.35, hot, 0.45, 0.3, radius * 0.3)
	groundRing(g, radius * 0.9, Color3.new(1, 1, 1), 0.25, 0.2, radius * 0.2)
	-- marca queimada no chao
	if not opts.semMarca then
		local scorch = part({ shape = Enum.PartType.Cylinder, color = Color3.fromRGB(25, 20, 18), material = Enum.Material.SmoothPlastic, transparency = 0.25, size = Vector3.new(0.06, radius * 1.3, radius * 1.3), cf = CFrame.new(g + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = 4.2 })
		task.delay(2.6, function() if scorch.Parent then tween(scorch, 1.5, { Transparency = 1 }) end end)
	end
	-- particulas: fogo, fumaca subindo, faiscas
	local a = anchor(pos + Vector3.new(0, 1, 0), 3.5)
	emitter(a, { texture = TEX.fogo, color = ColorSequence.new(hot, color), sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.5), NumberSequenceKeypoint.new(1, radius * 0.9) }), lifeMin = 0.25, lifeMax = 0.45, speedMin = radius * 0.8, speedMax = radius * 1.6, emit = 14, drag = 4 })
	emitter(a, { texture = TEX.fumaca, color = Color3.fromRGB(70, 64, 60), emission = 0, sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.4), NumberSequenceKeypoint.new(1, radius * 1.1) }), transp = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }), lifeMin = 1.2, lifeMax = 2.2, speedMin = 3, speedMax = 8, accel = Vector3.new(0, 6, 0), drag = 2, emit = 10 })
	emitter(a, { texture = TEX.faisca, color = Color3.fromRGB(255, 210, 120), size = 0.5, lifeMin = 0.4, lifeMax = 0.9, speedMin = radius * 2, speedMax = radius * 3.5, accel = Vector3.new(0, -40, 0), emit = 30, drag = 1 })
	if not opts.semDetritos then debris(g, opts.detritos or 7, Color3.fromRGB(85, 75, 65), radius * 1.6) end
	sound(SONS.Explosao, pos, opts.vol or 1, opts.pitch)
	addShake(opts.shake or (0.25 + radius * 0.035), pos)
	if isNear(pos, 40) then punchFov(opts.fov or 2.5) end
end

-- SOLDADO -----------------------------------------------------------------------------------
local FX = {}

-- granada: arco com rastro, piscando
function FX.Granada(from, to, dur)
	local g = part({ shape = Enum.PartType.Ball, color = Color3.fromRGB(70, 90, 50), material = Enum.Material.Metal, size = Vector3.one * 1.1, cf = CFrame.new(from) })
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.4, 0); a0.Parent = g
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.4, 0); a1.Parent = g
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0; tr.Attachment1 = a1
	tr.Lifetime = 0.35; tr.LightEmission = 1; tr.FaceCamera = true
	tr.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 120, 40))
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Parent = g
	emitter(a0, { texture = TEX.fumaca, color = Color3.fromRGB(180, 180, 180), emission = 0, size = 0.7, sizeEnd = 1.6, transp = NumberSequence.new(0.5, 1), lifeMin = 0.4, lifeMax = 0.6, speedMin = 0, speedMax = 1, rate = 40 })
	local l = light(g, Color3.fromRGB(255, 80, 60), 8, 2)
	local h = math.max(8, (to - from).Magnitude * 0.35)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / dur, 0, 1)
		local p = from:Lerp(to, t) + Vector3.new(0, 4 * h * t * (1 - t), 0)
		g.CFrame = CFrame.new(p) * CFrame.Angles(t * 14, t * 9, 0)
		l.Brightness = (math.floor(t * 10) % 2 == 0) and 4 or 0.5
		if t >= 1 then conn:Disconnect(); g:Destroy() end
	end)
end

function FX.Explosao(pos, radius, color, big)
	bigExplosion(pos, radius, color, { shake = big and 0.6 or nil, fov = big and 4 or nil })
end

-- onda de choque: soco no chao, poeira, pedras, anel duplo
function FX.Onda(pl, pos, radius)
	local char, root = charOf(pl)
	local g = groundY(pos)
	local col = Color3.fromRGB(255, 220, 120)
	flash(g + Vector3.new(0, 1, 0), Color3.new(1, 0.95, 0.8), 5, 0.15)
	groundRing(g, radius, col, 0.35, 0.5, 1.5)
	task.delay(0.08, function() groundRing(g, radius * 1.25, Color3.new(1, 1, 1), 0.45, 0.2, 2) end)
	shockSphere(g, radius * 0.9, col, 0.3)
	local a = anchor(g + Vector3.new(0, 0.5, 0), 3)
	emitter(a, { texture = TEX.fumaca, color = Color3.fromRGB(150, 135, 110), emission = 0, size = 2.5, sizeEnd = 5, transp = NumberSequence.new(0.35, 1), lifeMin = 0.6, lifeMax = 1.1, speedMin = radius * 1.8, speedMax = radius * 2.6, spread = Vector2.new(5, 180), drag = 5, emit = 26 })
	-- rachaduras radiais no chao
	for i = 1, 9 do
		local ang = (i / 9) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = radius * rng:NextNumber(0.5, 0.9)
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local base = CFrame.lookAt(g + Vector3.new(0, 0.08, 0), g + dir + Vector3.new(0, 0.08, 0))
		local c = part({ color = col, size = Vector3.new(0.35, 0.08, 0.1), cf = base, life = 1.4 })
		tween(c, 0.12, { Size = Vector3.new(0.35, 0.08, len), CFrame = base * CFrame.new(0, 0, -len / 2) })
		task.delay(0.5, function() if c.Parent then tween(c, 0.8, { Transparency = 1, Color = Color3.fromRGB(60, 50, 40) }) end end)
	end
	debris(g, 12, Color3.fromRGB(110, 100, 85), 22)
	if root then afterimage(char, col, 0.25) end
	sound(SONS.Martelo, g, 1.2, 0.8)
	addShake(0.65, g)
	if isNear(g, 30) then punchFov(4) end
end

-- grito de guerra: coluna vermelha, ondas e aura nos aliados
function FX.Grito(pl, pos, radius, buffed, dur)
	local _, root = charOf(pl)
	local red = Color3.fromRGB(255, 70, 50)
	local g = groundY(pos)
	local pillar = part({ shape = Enum.PartType.Cylinder, color = red, transparency = 0.25, size = Vector3.new(30, 1, 1), cf = CFrame.new(g + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = 0.7 })
	tween(pillar, 0.15, { Size = Vector3.new(30, 6, 6) }, Enum.EasingStyle.Back)
	task.delay(0.15, function() if pillar.Parent then tween(pillar, 0.5, { Size = Vector3.new(36, 0.2, 0.2), Transparency = 1 }) end end)
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			groundRing(g, radius * (0.5 + i * 0.25), red:Lerp(Color3.new(1, 0.85, 0.4), i / 3), 0.6, 0.35, 2)
		end)
	end
	if root then
		local a = anchor(root.Position, 2)
		emitter(a, { color = ColorSequence.new(Color3.new(1, 0.85, 0.4), red), size = 1.2, lifeMin = 0.6, lifeMax = 1, speedMin = 10, speedMax = 22, spread = Vector2.new(25, 25), accel = Vector3.new(0, -10, 0), emit = 40 })
	end
	if typeof(buffed) == "table" then
		for _, b in ipairs(buffed) do
			local _, r = charOf(b)
			if r then
				attachAura(r, dur or 6, { texture = TEX.fogo, color = ColorSequence.new(Color3.fromRGB(255, 160, 60), red), lightColor = red, size = 1.4, sizeEnd = 0.2, transp = NumberSequence.new(0.35, 1), lifeMin = 0.35, lifeMax = 0.6, speedMin = 2, speedMax = 5, accel = Vector3.new(0, 9, 0), rate = 22, light = 10 })
				floatIcon(r.Position + Vector3.new(0, 3, 0), "▲", red, 44, 4, 1)
			end
		end
	end
	if isNear(g, radius + 10) then screenTint(red, 0.35, 0.6) end
	sound(SONS.Corneta, g, 0.9, 1.15)
	addShake(0.35, g)
end

-- chuva: area marcada que pulsa durante o bombardeio
function FX.ChuvaMarca(center, radius, dur)
	local g = groundY(center)
	local red = Color3.fromRGB(255, 60, 40)
	local disc = part({ shape = Enum.PartType.Cylinder, color = red, transparency = 1, size = Vector3.new(0.06, radius * 2, radius * 2), cf = CFrame.new(g + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = dur + 0.6 })
	tween(disc, 0.25, { Transparency = 0.75 })
	local edge = part({ shape = Enum.PartType.Cylinder, color = red, transparency = 0.2, material = Enum.Material.ForceField, size = Vector3.new(4, radius * 2, radius * 2), cf = CFrame.new(g + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = dur + 0.6 })
	for _, ang in ipairs({ 45, -45 }) do
		part({ color = red, size = Vector3.new(0.4, 0.1, radius * 0.6), cf = CFrame.new(g + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, math.rad(ang), 0), life = dur + 0.3 })
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur and disc.Parent do
			groundRing(g, radius, red, 0.5, 0.2, radius * 0.2)
			task.wait(0.5)
		end
		if disc.Parent then tween(disc, 0.4, { Transparency = 1 }) end
		if edge.Parent then tween(edge, 0.4, { Transparency = 1 }) end
	end)
	sound(SONS.AlertaSpawn, g, 0.7, 1.3)
end

-- uma granada caindo do ceu (rastro de fogo), explode quando chega
function FX.GranadaCai(pos, radius, fall)
	local top = pos + Vector3.new(rng:NextNumber(-6, 6), 45, rng:NextNumber(-6, 6))
	local b = part({ color = Color3.fromRGB(60, 70, 45), material = Enum.Material.Metal, size = Vector3.new(0.9, 0.9, 2), cf = CFrame.lookAt(top, pos) })
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0.35, 0, 0.8); a0.Parent = b
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(-0.35, 0, 0.8); a1.Parent = b
	local tr = Instance.new("Trail"); tr.Attachment0 = a0; tr.Attachment1 = a1
	tr.Lifetime = 0.25; tr.LightEmission = 1; tr.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 90, 30))
	tr.Transparency = NumberSequence.new(0, 1); tr.Parent = b
	light(b, Color3.fromRGB(255, 140, 60), 10, 3)
	local tw = tween(b, fall, { CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.6, 0), pos + (pos - top).Unit) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Once(function()
		b:Destroy()
		bigExplosion(pos, radius, Color3.fromRGB(255, 130, 40), { detritos = 4, vol = 0.7, shake = 0.18, fov = 1.2 })
	end)
end
-- NINJA -------------------------------------------------------------------------------------
-- avanco: pos-imagens ao longo do caminho, corte de luz, vento
function FX.Dash(pl, start, finish, hits)
	local char = charOf(pl)
	local cyan = Color3.fromRGB(140, 210, 255)
	local dist = (finish - start).Magnitude
	-- o personagem ja esta no destino, entao as copias sao desenhadas "para tras"
	if char then
		local n = math.clamp(math.floor(dist / 3), 3, 7)
		for i = 1, n do
			local back = start - finish
			task.delay(i * 0.015, function() afterimage(char, cyan:Lerp(Color3.fromRGB(70, 40, 160), i / n), 0.3 + i * 0.03, back * (1 - i / (n + 1))) end)
		end
	end
	if dist > 0.5 then
		local mid = start:Lerp(finish, 0.5)
		local slash = part({ color = Color3.new(1, 1, 1), size = Vector3.new(0.15, 0.15, dist), cf = CFrame.lookAt(start, finish) * CFrame.new(0, 0, -dist / 2), life = 0.4 })
		tween(slash, 0.3, { Size = Vector3.new(0.02, 0.02, dist * 1.1), Transparency = 1 })
		local glow = part({ color = cyan, transparency = 0.4, size = Vector3.new(1.6, 4, dist), cf = CFrame.lookAt(start, finish) * CFrame.new(0, 0, -dist / 2), life = 0.35 })
		tween(glow, 0.3, { Size = Vector3.new(0.1, 4.5, dist), Transparency = 1 })
		local a = anchor(mid, 1.5)
		a.Size = Vector3.new(1, 3, dist)
		a.CFrame = CFrame.lookAt(mid, finish)
		emitter(a, { color = cyan, size = 0.6, lifeMin = 0.25, lifeMax = 0.5, speedMin = 4, speedMax = 10, shape = Enum.ParticleEmitterShape.Box, emit = 30 })
		groundRing(groundY(start), 4, cyan, 0.3, 0.2)
		groundRing(groundY(finish), 5, Color3.new(1, 1, 1), 0.3, 0.2)
	end
	-- cortes em X nos inimigos atingidos
	if typeof(hits) == "table" then
		for _, p in ipairs(hits) do
			if typeof(p) == "Vector3" then
				task.delay(0.06, function()
					for _, ang in ipairs({ 40, -40 }) do
						local c = part({ color = Color3.new(1, 1, 1), size = Vector3.new(0.12, 5, 0.12), cf = CFrame.lookAt(p, camera.CFrame.Position) * CFrame.Angles(0, 0, math.rad(ang)), life = 0.3 })
						tween(c, 0.25, { Size = Vector3.new(0.02, 7, 0.02), Transparency = 1 })
					end
					flash(p, cyan, 3, 0.15, 8)
				end)
			end
		end
	end
	sound(SONS.Golpe, finish, 1, 1.4)
	if pl == player then punchFov(6); addShake(0.2) end
end

-- bomba de fumaca: estouro + nuvem densa que dura o tempo da habilidade
function FX.Fumaca(pos, radius, dur)
	local g = groundY(pos)
	flash(g + Vector3.new(0, 1.5, 0), Color3.new(1, 1, 1), 6, 0.15)
	groundRing(g, radius, Color3.fromRGB(200, 200, 215), 0.5, 0.3, 2)
	local a = anchor(g + Vector3.new(0, 2, 0), dur + 4)
	emitter(a, { texture = TEX.fumaca, color = Color3.fromRGB(215, 215, 225), emission = 0, size = 4, sizeEnd = 9, transp = NumberSequence.new(0.1, 1), lifeMin = 1.2, lifeMax = 2, speedMin = radius * 1.2, speedMax = radius * 2, drag = 3, emit = 34 })
	local cloud = part({ transparency = 1, size = Vector3.new(radius * 1.8, 4, radius * 1.8), cf = CFrame.new(g + Vector3.new(0, 2.5, 0)), life = dur + 4 })
	local e = emitter(cloud, { texture = TEX.fumaca, color = ColorSequence.new(Color3.fromRGB(205, 205, 215), Color3.fromRGB(150, 150, 170)), emission = 0, sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 12) }), transp = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) }), lifeMin = 2, lifeMax = 3, speedMin = 0.5, speedMax = 2, shape = Enum.ParticleEmitterShape.Box, rate = 34, rot = 25 })
	local e2 = emitter(cloud, { color = Color3.fromRGB(170, 140, 255), size = 0.5, lifeMin = 0.6, lifeMax = 1.2, speedMin = 0.5, speedMax = 2, shape = Enum.ParticleEmitterShape.Box, rate = 10 })
	task.delay(dur, function() e.Enabled = false; e2.Enabled = false end)
	sound(SONS.Portal, g, 0.8, 1.6)
	addShake(0.15, g)
end

-- shurikens: estrelas girando com rastro de luz
function FX.Shuriken(start, dirs, range)
	if typeof(dirs) ~= "table" then return end
	local col = Color3.fromRGB(200, 205, 225)
	for i, d in ipairs(dirs) do
		if typeof(d) == "Vector3" then
			task.delay(i * 0.025, function()
				local finish = start + d * range
				local star = Instance.new("Model")
				local a = part({ color = col, material = Enum.Material.Metal, size = Vector3.new(1.5, 0.12, 0.35), cf = CFrame.new(start), parent = star })
				local b = part({ color = col, material = Enum.Material.Metal, size = Vector3.new(0.35, 0.12, 1.5), cf = CFrame.new(start), parent = star })
				local hub = part({ shape = Enum.PartType.Cylinder, color = Color3.fromRGB(40, 40, 50), size = Vector3.new(0.14, 0.5, 0.5), cf = CFrame.new(start), parent = star })
				star.Parent = folder
				local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0.75, 0, 0); a0.Parent = a
				local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(-0.75, 0, 0); a1.Parent = a
				local tr = Instance.new("Trail"); tr.Attachment0 = a0; tr.Attachment1 = a1
				tr.Lifetime = 0.12; tr.LightEmission = 1; tr.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255)); tr.Transparency = NumberSequence.new(0.3, 1); tr.Parent = a
				local t0 = os.clock()
				local T = 0.35
				local conn
				conn = RunService.RenderStepped:Connect(function()
					local t = math.clamp((os.clock() - t0) / T, 0, 1)
					local p = start:Lerp(finish, t)
					local spin = CFrame.Angles(0, t * 40, 0)
					a.CFrame = CFrame.new(p) * spin
					b.CFrame = CFrame.new(p) * spin
					hub.CFrame = CFrame.new(p) * spin * CFrame.Angles(0, 0, math.rad(90))
					if t >= 1 then conn:Disconnect(); star:Destroy() end
				end)
			end)
		end
	end
	local sw = anchor(start, 1)
	emitter(sw, { color = Color3.fromRGB(170, 220, 255), size = 0.5, lifeMin = 0.2, lifeMax = 0.35, speedMin = 8, speedMax = 16, spread = Vector2.new(35, 35), emit = 14 })
	sound(SONS.Girar, start, 1, 1.5)
end

function FX.ShurikenHit(pos)
	flash(pos, Color3.fromRGB(170, 220, 255), 2.2, 0.12, 6)
	local a = anchor(pos, 1)
	emitter(a, { texture = TEX.faisca, color = Color3.fromRGB(220, 240, 255), size = 0.3, lifeMin = 0.15, lifeMax = 0.3, speedMin = 10, speedMax = 18, emit = 8 })
end

-- postura das sombras: implosao roxa + aura escura + pos-imagens enquanto se move
function FX.Sombra(pl, dur)
	local char, root = charOf(pl)
	if not root then return end
	local purple = Color3.fromRGB(110, 70, 200)
	local g = groundY(root.Position)
	local sph = part({ shape = Enum.PartType.Ball, color = purple, material = Enum.Material.ForceField, size = Vector3.one * 16, cf = root.CFrame, life = 0.45 })
	tween(sph, 0.4, { Size = Vector3.one * 1, Transparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(0.35, function()
		flash(root.Position, Color3.fromRGB(60, 20, 120), 10, 0.25, 20)
		groundRing(g, 12, purple, 0.5, 0.3, 2)
	end)
	attachAura(root, dur, { texture = TEX.fumaca, color = ColorSequence.new(Color3.fromRGB(40, 20, 70), Color3.fromRGB(10, 5, 20)), emission = 0, size = 2.2, sizeEnd = 0.5, transp = NumberSequence.new(0.3, 1), lifeMin = 0.5, lifeMax = 0.9, speedMin = 0.5, speedMax = 2, accel = Vector3.new(0, 3, 0), rate = 28 })
	attachAura(root, dur, { color = Color3.fromRGB(180, 130, 255), size = 0.35, lifeMin = 0.4, lifeMax = 0.8, speedMin = 1, speedMax = 3, rate = 14, light = 8 })
	task.spawn(function()
		local t0 = os.clock()
		local last = root.Position
		while os.clock() - t0 < dur and root.Parent do
			if (root.Position - last).Magnitude > 1.5 then afterimage(char, purple, 0.35); last = root.Position end
			task.wait(0.12)
		end
	end)
	if pl == player then
		punchFov(5)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0; cc.TintColor = Color3.new(1, 1, 1); cc.Parent = Lighting
		tween(cc, 0.4, { Saturation = -0.45, TintColor = Color3.fromRGB(215, 205, 255) })
		task.delay(dur, function() tween(cc, 0.5, { Saturation = 0, TintColor = Color3.new(1, 1, 1) }); Debris:AddItem(cc, 0.6) end)
	end
	sound(SONS.Portal, root.Position, 1, 0.7)
end

-- ENGENHEIRO --------------------------------------------------------------------------------
-- holograma de implantacao: cubo que "compila" de cima pra baixo + faiscas (Moggity, Isca, Lovity)
function FX.Implantar(pos, color, size)
	local g = groundY(pos)
	size = size or 4
	local col = color or Color3.fromRGB(80, 200, 255)
	local cube = part({ color = col, material = Enum.Material.ForceField, size = Vector3.new(size, size * 1.4, size), cf = CFrame.new(g + Vector3.new(0, size * 0.7, 0)), life = 0.7 })
	tween(cube, 0.6, { Size = Vector3.new(size * 0.2, 0.1, size * 0.2), CFrame = CFrame.new(g + Vector3.new(0, 0.1, 0)), Transparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local scan = part({ color = col, transparency = 0.2, size = Vector3.new(size * 1.3, 0.08, size * 1.3), cf = CFrame.new(g + Vector3.new(0, size * 1.4, 0)), life = 0.6 })
	tween(scan, 0.5, { CFrame = CFrame.new(g + Vector3.new(0, 0.1, 0)), Transparency = 1 }, Enum.EasingStyle.Sine)
	task.delay(0.45, function()
		flash(g + Vector3.new(0, 1, 0), col, size * 1.3, 0.2)
		groundRing(g, size * 1.6, col, 0.45, 0.25, 1)
		local a = anchor(g + Vector3.new(0, 0.5, 0), 1.5)
		emitter(a, { texture = TEX.faisca, color = col:Lerp(Color3.new(1, 1, 1), 0.4), size = 0.4, lifeMin = 0.3, lifeMax = 0.6, speedMin = 10, speedMax = 20, spread = Vector2.new(60, 60), accel = Vector3.new(0, -35, 0), emit = 22 })
		sound(SONS.MontarTorreta, g, 0.9)
	end)
end

-- pulso de plasma: dispositivo com nucleo flutuando e aneis girando
function FX.Plasma(pos, radius, dur)
	local g = groundY(pos)
	local purple = Color3.fromRGB(170, 110, 255)
	local base = part({ color = Color3.fromRGB(70, 70, 82), material = Enum.Material.Metal, size = Vector3.new(2, 0.8, 2), cf = CFrame.new(g + Vector3.new(0, 0.4, 0)), life = dur + 0.6 })
	local core = part({ shape = Enum.PartType.Ball, color = purple, size = Vector3.one * 0.1, cf = CFrame.new(g + Vector3.new(0, 2.6, 0)), life = dur + 0.6 })
	local l = light(core, purple, 16, 3)
	local rings = {}
	for i = 1, 2 do
		rings[i] = part({ shape = Enum.PartType.Cylinder, color = purple:Lerp(Color3.new(1, 1, 1), 0.3), material = Enum.Material.ForceField, size = Vector3.new(0.3, 2.6 + i, 2.6 + i), cf = core.CFrame, life = dur + 0.6 })
	end
	local area = part({ shape = Enum.PartType.Cylinder, color = purple, transparency = 0.85, size = Vector3.new(0.05, radius * 2, radius * 2), cf = CFrame.new(g + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = dur + 0.6 })
	emitter(core, { color = purple, size = 0.4, lifeMin = 0.3, lifeMax = 0.6, speedMin = 2, speedMax = 6, rate = 30 })
	tween(core, 0.35, { Size = Vector3.one * 1.3 }, Enum.EasingStyle.Back)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > dur or not core.Parent then
			conn:Disconnect()
			for _, p in ipairs({ base, core, rings[1], rings[2], area }) do if p.Parent then tween(p, 0.4, { Transparency = 1 }) end end
			tween(l, 0.4, { Brightness = 0 })
			return
		end
		local bob = math.sin(t * 4) * 0.25
		core.CFrame = CFrame.new(g + Vector3.new(0, 2.6 + bob, 0))
		rings[1].CFrame = core.CFrame * CFrame.Angles(t * 3, t * 5, 0)
		rings[2].CFrame = core.CFrame * CFrame.Angles(-t * 4, 0, t * 3)
		l.Brightness = 2.5 + math.sin(t * 20)
	end)
	sound(SONS.GeradorZumbido, g, 1)
end

-- cada descarga do plasma: raio do nucleo ate o ponto + explosao roxa
function FX.PlasmaZap(from, to, radius)
	local purple = Color3.fromRGB(170, 110, 255)
	lightning(from, to, Color3.fromRGB(230, 200, 255), 0.25, 0.14, 8)
	lightning(from, to, purple, 0.12, 0.2, 6)
	bigExplosion(to, radius, purple, { semDetritos = true, semMarca = true, vol = 0.45, pitch = 1.4, shake = 0.08, fov = 0.6 })
	sound(SONS.Laser, from, 0.6, 1.2)
end

-- sobrecarga: arcos eletricos nas estruturas durante o tempo
function FX.Sobrecarga(dur)
	local yellow = Color3.fromRGB(255, 225, 70)
	local list = {}
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Estrutura")) do
		local pp = m:IsA("Model") and m.PrimaryPart
		if pp then table.insert(list, pp) end
	end
	screenTint(yellow, 0.3, 0.6)
	for _, pp in ipairs(list) do
		flash(pp.Position + Vector3.new(0, 2, 0), yellow, 5, 0.25, 12)
		attachAura(pp, dur, { texture = TEX.faisca, color = yellow, size = 0.35, lifeMin = 0.15, lifeMax = 0.35, speedMin = 6, speedMax = 12, rate = 12, light = 9 })
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			for _, pp in ipairs(list) do
				if pp.Parent and rng:NextNumber() < 0.45 and isNear(pp.Position, 120) then
					local top = pp.Position + Vector3.new(0, pp.Size.Y / 2 + 1, 0)
					lightning(top, top + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(1, 4), rng:NextNumber(-3, 3)), yellow, 0.14, 0.1, 4)
				end
			end
			task.wait(0.15)
		end
	end)
	sound(SONS.GeradorZumbido, camera.CFrame.Position, 0.8, 1.3)
	addShake(0.2)
end
-- MEDICO ------------------------------------------------------------------------------------
local PINK = Color3.fromRGB(255, 140, 200)
local GREEN = Color3.fromRGB(120, 255, 160)

-- dardo curativo: dardo em arco com rastro de coracoes, explode em cura no alvo
function FX.Cura(from, pl, amount)
	local _, tr = charOf(pl)
	if not tr then return end
	local to = tr.Position
	local dart = part({ color = GREEN, size = Vector3.new(0.3, 0.3, 1.4), cf = CFrame.lookAt(from, to + Vector3.new(0, 0.01, 0)) })
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.2, 0.6); a0.Parent = dart
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.2, 0.6); a1.Parent = dart
	local trail = Instance.new("Trail"); trail.Attachment0 = a0; trail.Attachment1 = a1
	trail.Lifetime = 0.3; trail.LightEmission = 1; trail.Color = ColorSequence.new(GREEN, Color3.new(1, 1, 1)); trail.Transparency = NumberSequence.new(0.1, 1); trail.Parent = dart
	light(dart, GREEN, 8, 3)
	local d = (to - from).Magnitude
	local T = math.clamp(d / 70, 0.12, 0.45)
	local t0 = os.clock()
	local lastHeart = -1
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / T, 0, 1)
		local target = tr.Parent and tr.Position or to
		local p = from:Lerp(target, t) + Vector3.new(0, math.sin(t * math.pi) * (2 + d * 0.15), 0)
		local ahead = from:Lerp(target, math.min(1, t + 0.05)) + Vector3.new(0, math.sin(math.min(1, t + 0.05) * math.pi) * (2 + d * 0.15), 0)
		if (ahead - p).Magnitude > 0.01 then dart.CFrame = CFrame.lookAt(p, ahead) else dart.Position = p end
		if t - lastHeart > 0.2 then lastHeart = t; floatIcon(p, "♥", PINK, 22, 1.5, 0.6) end
		if t >= 1 then
			conn:Disconnect()
			dart:Destroy()
			flash(target, GREEN, 6, 0.25, 14)
			groundRing(groundY(target), 6, GREEN, 0.5, 0.25, 1)
			local a = anchor(target, 2)
			emitter(a, { color = ColorSequence.new(GREEN, Color3.new(1, 1, 1)), size = 0.7, lifeMin = 0.6, lifeMax = 1.1, speedMin = 3, speedMax = 7, accel = Vector3.new(0, 8, 0), emit = 26 })
			for i = 1, 4 do task.delay(i * 0.08, function() floatIcon(target + Vector3.new(rng:NextNumber(-1.5, 1.5), 1, rng:NextNumber(-1.5, 1.5)), "+", GREEN, 34, 4, 0.9) end) end
			if typeof(amount) == "number" then floatIcon(target + Vector3.new(0, 3.5, 0), "+" .. math.floor(amount), GREEN, 46, 3, 1.1) end
			sound(SONS.Coracao, target, 0.9, 1.2)
			if pl == player then screenTint(GREEN, 0.25, 0.5) end
		end
	end)
end

-- passo de fase: portal rosa na saida e na chegada, rastro de luz
function FX.Fase(pl, start, finish)
	local char = charOf(pl)
	local function portal(pos, grow)
		local g = groundY(pos)
		local disc = part({ shape = Enum.PartType.Cylinder, color = PINK, material = Enum.Material.ForceField, size = Vector3.new(0.2, 0.5, 0.5), cf = CFrame.new(g + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = 0.9 })
		tween(disc, 0.25, { Size = Vector3.new(0.2, 7, 7) }, Enum.EasingStyle.Back)
		task.delay(0.35, function() if disc.Parent then tween(disc, 0.45, { Size = Vector3.new(0.2, 0.3, 0.3), Transparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end end)
		local col = part({ shape = Enum.PartType.Cylinder, color = Color3.new(1, 0.9, 0.95), transparency = 0.3, size = Vector3.new(grow and 0.1 or 9, 2.4, 2.4), cf = CFrame.new(g + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = 0.6 })
		tween(col, 0.4, { Size = Vector3.new(9, 0.1, 0.1), Transparency = 1 })
		local a = anchor(g + Vector3.new(0, 1, 0), 2)
		emitter(a, { color = ColorSequence.new(PINK, Color3.new(1, 1, 1)), size = 0.6, lifeMin = 0.5, lifeMax = 1, speedMin = 2, speedMax = 6, accel = Vector3.new(0, 6, 0), emit = 24 })
		light(a, PINK, 14, 4, 0.6)
	end
	portal(start, false)
	task.delay(0.05, function() portal(finish, true) end)
	if char then afterimage(char, PINK, 0.4, start - finish) end
	local d = (finish - start).Magnitude
	if d > 0.5 then
		local streak = part({ color = PINK, transparency = 0.3, size = Vector3.new(0.6, 0.6, d), cf = CFrame.lookAt(start, finish) * CFrame.new(0, 0, -d / 2), life = 0.4 })
		tween(streak, 0.35, { Size = Vector3.new(0.05, 0.05, d), Transparency = 1 })
	end
	sound(SONS.Portal, finish, 0.9, 1.4)
	if pl == player then punchFov(5); screenTint(PINK, 0.3, 0.4) end
end

-- coro de lovities: coluna de luz, coracoes por todo lado e ondas de cura
function FX.Coro(pl, center, count)
	local g = groundY(center)
	local beam = part({ shape = Enum.PartType.Cylinder, color = Color3.new(1, 0.9, 0.95), transparency = 0.2, size = Vector3.new(80, 0.5, 0.5), cf = CFrame.new(g + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)), life = 1.2 })
	tween(beam, 0.25, { Size = Vector3.new(80, 9, 9) }, Enum.EasingStyle.Back)
	task.delay(0.3, function() if beam.Parent then tween(beam, 0.8, { Size = Vector3.new(80, 0.1, 0.1), Transparency = 1 }) end end)
	light(anchor(g + Vector3.new(0, 4, 0), 1.5), PINK, 40, 6, 1.2)
	for i = 0, 3 do task.delay(i * 0.15, function() groundRing(g, 10 + i * 6, i % 2 == 0 and PINK or GREEN, 0.7, 0.3, 2) end) end
	for i = 1, 14 do
		task.delay(i * 0.04, function()
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(2, 9)
			floatIcon(g + Vector3.new(math.cos(a) * r, 1.5, math.sin(a) * r), "♥", PINK:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.4)), rng:NextInteger(28, 48), rng:NextNumber(5, 9), 1.3)
		end)
	end
	local a = anchor(g + Vector3.new(0, 2, 0), 3)
	emitter(a, { color = ColorSequence.new(PINK, Color3.new(1, 1, 1)), size = 1, lifeMin = 0.8, lifeMax = 1.5, speedMin = 8, speedMax = 18, spread = Vector2.new(40, 40), accel = Vector3.new(0, -6, 0), emit = 60 })
	local n = typeof(count) == "number" and math.clamp(count, 1, 8) or 3
	for i = 1, n do
		local ang = i / n * math.pi * 2
		task.delay(0.2 + i * 0.1, function() FX.Implantar(g + Vector3.new(math.cos(ang) * 7, 0, math.sin(ang) * 7), PINK, 3) end)
	end
	if isNear(g, 60) then screenTint(PINK, 0.35, 0.8) end
	sound(SONS.NucleoFanfarra, g, 0.8, 1.1)
	addShake(0.3, g)
end

-- DESPACHO -----------------------------------------------------------------------------------
remotes.Efeito.OnClientEvent:Connect(function(kind, name, ...)
	if kind ~= "ClasseFX" or typeof(name) ~= "string" then return end
	local fn = FX[name]
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[ClassesVFX] " .. name .. ": " .. tostring(err)) end
end)
