-- [AliadosCliente] Animacao local da LOVITY (o servidor so cuida da cura):
-- chega caindo do ceu com quique, pula feliz com squash & stretch, da piruetas,
-- bochechas coradas, asinhas batendo, antena de coracao que balanca, coracoes subindo,
-- coracoes orbitando a area de cura, pulso + feixes + "+N" verdes a cada cura,
-- e na despedida acena, gira, encolhe e explode em coracoes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")

local PINK = Color3.fromRGB(255, 120, 180)
local HOT = Color3.fromRGB(255, 70, 140)
local SOFT = Color3.fromRGB(255, 180, 215)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local rng = Random.new()

local fx = Instance.new("Folder")
fx.Name = "EfeitosLovity"
fx.Parent = workspace.CurrentCamera

local function P(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or fx
	return p
end

-- CORACAO (2 bolinhas + losango) ----------------------------------------------------
local function newHeart(parent, color, neon)
	local h = {
		l = P({ Shape = Enum.PartType.Ball, Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic }, parent),
		r = P({ Shape = Enum.PartType.Ball, Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic }, parent),
		d = P({ Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic }, parent),
	}
	return h
end
local function placeHeart(h, cf, s, transp)
	s = math.max(0.02, s)
	h.l.Size = Vector3.one * s * 0.62
	h.r.Size = Vector3.one * s * 0.62
	h.d.Size = Vector3.new(s * 0.6, s * 0.6, s * 0.4)
	h.l.CFrame = cf * CFrame.new(-s * 0.2, s * 0.12, 0)
	h.r.CFrame = cf * CFrame.new(s * 0.2, s * 0.12, 0)
	h.d.CFrame = cf * CFrame.new(0, -s * 0.12, 0) * CFrame.Angles(0, 0, math.rad(45))
	if transp then
		h.l.Transparency, h.r.Transparency, h.d.Transparency = transp, transp, transp
	end
end
local function destroyHeart(h) h.l:Destroy(); h.r:Destroy(); h.d:Destroy() end

-- coracao que sobe balancando e some
local function floatHeart(pos, size, rise, dur, color)
	local h = newHeart(fx, color or PINK, true)
	local t0 = os.clock()
	local sway = rng:NextNumber(0, math.pi * 2)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / dur
		if u >= 1 then conn:Disconnect(); destroyHeart(h) return end
		local p = pos + Vector3.new(math.sin(u * 6 + sway) * 0.5, rise * (1 - (1 - u) ^ 2), 0)
		local cam = workspace.CurrentCamera
		local cf = cam and CFrame.lookAt(p, p + (cam.CFrame.Position - p) * Vector3.new(1, 0, 1)) or CFrame.new(p)
		local pop = u < 0.15 and (u / 0.15) or 1
		placeHeart(h, cf * CFrame.Angles(0, 0, math.sin(u * 8 + sway) * 0.3), size * pop * (1 - u * 0.4), math.clamp((u - 0.55) / 0.45, 0, 1))
	end)
end

-- coracao lancado para fora (explosao de coracoes)
local function burstHearts(pos, n, speed)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local vel = Vector3.new(math.cos(a), rng:NextNumber(0.6, 1.3), math.sin(a)) * (speed or 12)
		local h = newHeart(fx, i % 2 == 0 and PINK or HOT, true)
		local p = pos
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			local u = (os.clock() - t0) / 0.8
			if u >= 1 then conn:Disconnect(); destroyHeart(h) return end
			vel += Vector3.new(0, -20 * dt, 0)
			vel *= math.exp(-2.5 * dt)
			p += vel * dt
			placeHeart(h, CFrame.new(p) * CFrame.Angles(0, u * 6, 0), 0.9 * (1 - u * 0.6), math.clamp((u - 0.5) * 2, 0, 1))
		end)
	end
end

local function ringPulse(center, from, to, color, dur)
	local ring = P({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, from * 2, from * 2), Color = color, Material = Enum.Material.Neon, Transparency = 0.25,
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, to * 2, to * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, dur + 0.05)
end

local function popText(pos, text, color)
	local p = P({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 34); bb.AlwaysOnTop = true; bb.LightInfluence = 0
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.FontFace = FONT; t.TextScaled = true
	t.Text = text; t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = Color3.new(1, 1, 1); st.Parent = t
	local us = Instance.new("UIScale"); us.Scale = 1.7; us.Parent = t
	TweenService:Create(us, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, 3, 0) }):Play()
	task.delay(0.5, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(p, 0.85)
end

local function playSound(id, vol, speed, at)
	local a = Instance.new("Attachment"); a.WorldPosition = at; a.Parent = workspace.Terrain
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = vol; s.PlaybackSpeed = speed; s.RollOffMaxDistance = 120; s.Parent = a
	s:Play()
	Debris:AddItem(a, 2)
end

local function easeOutBounce(x)
	local n1, d1 = 7.5625, 2.75
	if x < 1 / d1 then return n1 * x * x
	elseif x < 2 / d1 then x -= 1.5 / d1 return n1 * x * x + 0.75
	elseif x < 2.5 / d1 then x -= 2.25 / d1 return n1 * x * x + 0.9375
	else x -= 2.625 / d1 return n1 * x * x + 0.984375 end
end

-- CONTROLADOR DE CADA LOVITY ------------------------------------------------------------
local controllers = {}

local function setup(model)
	if controllers[model] then return end
	local body = model:WaitForChild("Corpo", 5)
	if not body then return end
	local ground = model:GetAttribute("Chao") or (body.Position - Vector3.new(0, 1.8, 0))
	local radius = model:GetAttribute("Raio") or 12
	local born = model:GetAttribute("Nasceu") or workspace:GetServerTimeNow()
	local SIZE = 3.6
	local deco = Instance.new("Folder")
	deco.Name = "DecoLocal"
	deco.Parent = fx

	local cheeks = {
		P({ Shape = Enum.PartType.Cylinder, Color = HOT, Material = Enum.Material.Neon, Transparency = 0.2 }, deco),
		P({ Shape = Enum.PartType.Cylinder, Color = HOT, Material = Enum.Material.Neon, Transparency = 0.2 }, deco),
	}
	local wings = { {}, {} }
	for side = 1, 2 do
		for i = 1, 2 do
			table.insert(wings[side], P({ Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic }, deco))
		end
	end
	local stem = P({ Color = Color3.fromRGB(255, 150, 200), Material = Enum.Material.SmoothPlastic }, deco)
	local antHeart = newHeart(deco, HOT, true)
	-- area de cura: anel no chao + disco suave
	local disc = P({ Shape = Enum.PartType.Cylinder, Color = SOFT, Material = Enum.Material.Neon, Transparency = 0.88,
		Size = Vector3.new(0.08, radius * 2, radius * 2), CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, deco)
	local SEG = 28
	for i = 0, SEG - 1 do
		local a = i / SEG * math.pi * 2
		local len = 2 * math.pi * radius / SEG * 0.55
		P({ Color = PINK, Material = Enum.Material.Neon, Transparency = 0.3, Size = Vector3.new(0.35, 0.12, len),
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * radius, 0.18, math.sin(a) * radius)) * CFrame.Angles(0, -a, 0) }, deco)
	end
	local orbit = { newHeart(deco, PINK, true), newHeart(deco, HOT, true), newHeart(deco, PINK, true) }

	-- com o modelo feito no Blender ("Visual"), os enfeites procedurais do corpo saem de cena
	-- (o modelo ja tem antena e coracao); a area de cura e os coracoes em volta continuam.
	local visual = model:WaitForChild("Visual", 1)
	if visual then
		for _, c in ipairs(cheeks) do c.Parent = nil end
		for _, side in ipairs(wings) do for _, w in ipairs(side) do w.Parent = nil end end
		stem.Parent = nil
		antHeart.l.Parent = nil; antHeart.r.Parent = nil; antHeart.d.Parent = nil
	end

	local ctrl = { excite = 0, yaw = rng:NextNumber(0, math.pi * 2), landed = false }
	controllers[model] = ctrl
	local t0 = os.clock()
	local nextSpin = os.clock() + rng:NextNumber(2.5, 4)
	local spinStart
	local nextFloat = 0
	local leaveStart
	local burstDone = false

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not model.Parent or not body.Parent then
			conn:Disconnect()
			controllers[model] = nil
			deco:Destroy()
			return
		end
		local now = os.clock()
		local t = now - t0
		local age = workspace:GetServerTimeNow() - born

		-- chegada: cai do ceu e quica
		local drop = 0
		if age < 0.7 then
			drop = (1 - easeOutBounce(math.clamp(age / 0.7, 0, 1))) * 16
		elseif not ctrl.landed then
			ctrl.landed = true
			ringPulse(ground, 1, radius, PINK, 0.5)
			burstHearts(ground + Vector3.new(0, 2, 0), 8, 10)
			playSound("rbxassetid://115842676995967", 0.45, 1.1, ground)
		end

		-- pulo feliz com squash & stretch
		local cyc = 0.7
		local u = (t % cyc) / cyc
		local h, sy = 0, 1
		local jump = 1.5 + ctrl.excite * 1.6
		if u < 0.2 then
			sy = 1 - 0.28 * math.sin(u / 0.2 * math.pi)
		elseif u < 0.85 then
			local a = (u - 0.2) / 0.65
			h = math.sin(a * math.pi) * jump
			sy = 1 + 0.16 * math.sin(a * math.pi)
		else
			sy = 1 - 0.22 * math.sin((u - 0.85) / 0.15 * math.pi)
		end
		ctrl.excite = math.max(0, ctrl.excite - dt * 1.2)

		-- pirueta de vez em quando
		local spinAngle = 0
		if not spinStart and now >= nextSpin and u < 0.05 then spinStart = now end
		if spinStart then
			local s = (now - spinStart) / cyc
			if s >= 1 then
				spinStart = nil
				nextSpin = now + rng:NextNumber(3, 5)
			else
				spinAngle = (1 - (1 - s) ^ 2) * math.pi * 2
				h *= 1.5
			end
		end

		-- olha para o jogador mais perto
		local target
		local bd
		for _, pl in ipairs(Players:GetPlayers()) do
			local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - ground).Magnitude
				if d < 40 and (not bd or d < bd) then target, bd = r.Position, d end
			end
		end
		if target then
			local v = target - ground
			local want = math.atan2(-v.X, -v.Z)
			ctrl.yaw += math.atan2(math.sin(want - ctrl.yaw), math.cos(want - ctrl.yaw)) * math.min(1, dt * 5)
		else
			ctrl.yaw += dt * 0.6
		end

		-- despedida: acena, gira, encolhe e explode em coracoes
		local shrink = 1
		local wave = 0
		if model:GetAttribute("Saindo") then
			leaveStart = leaveStart or now
			local l = (now - leaveStart) / 0.65
			wave = math.sin(l * 30) * math.rad(18)
			shrink = l < 0.35 and (1 + 0.25 * math.sin(l / 0.35 * math.pi)) or math.max(0, 1 - (l - 0.35) / 0.3)
			spinAngle += l * math.pi * 3
			if visual then
				local a = math.clamp((l - 0.35) / 0.3, 0, 1)
				for _, p in ipairs(visual:GetChildren()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = a end end
			end
			if l >= 0.5 and not burstDone then
				burstDone = true
				burstHearts(body.Position, 14, 14)
				ringPulse(ground, 1, radius * 0.6, PINK, 0.4)
				playSound("rbxassetid://115842676995967", 0.35, 1.25, body.Position)
			end
		end

		local s = SIZE * shrink
		local sx = 1 + (1 - sy) * 0.4
		local tilt = math.sin(t * 3.2) * math.rad(7) + wave
		local center = ground + Vector3.new(0, s * sy / 2 + h + drop, 0)
		local cf = CFrame.new(center) * CFrame.Angles(0, ctrl.yaw + spinAngle, 0) * CFrame.Angles(0, 0, tilt)
		body.Size = Vector3.new(s * sx, s * sy, s * sx)
		body.CFrame = cf
		local hw, hh = s * sx / 2, s * sy / 2

		-- bochechas
		for i, c in ipairs(cheeks) do
			local sgn = i == 1 and -1 or 1
			c.Size = Vector3.new(0.06, 0.62 * shrink, 0.62 * shrink)
			c.CFrame = cf * CFrame.new(sgn * hw * 0.62, -hh * 0.12, -hw * 0.8) * CFrame.Angles(0, math.rad(90) + sgn * math.rad(35), 0)
		end
		-- asinhas batendo
		local flap = math.sin(t * 20) * math.rad(35)
		for side = 1, 2 do
			local sgn = side == 1 and -1 or 1
			local root = cf * CFrame.new(sgn * hw * 0.85, hh * 0.25, hw * 0.35) * CFrame.Angles(0, 0, sgn * (flap + math.rad(20)))
			for i, w in ipairs(wings[side]) do
				w.Size = Vector3.new(0.15, 0.7, 1.3 - i * 0.3) * shrink
				w.CFrame = root * CFrame.Angles(0, 0, sgn * math.rad(-10 + i * 25)) * CFrame.new(sgn * 0.55 * shrink, 0, 0) * CFrame.Angles(0, sgn * math.rad(55), 0)
			end
		end
		-- antena com coracao que balanca atrasado
		local lag = math.sin(t * 6) * math.rad(14) - (h > 0 and math.rad(6) or 0)
		local base = cf * CFrame.new(0, hh, 0) * CFrame.Angles(lag, 0, lag * 0.5)
		stem.Size = Vector3.new(0.12, 1 * shrink, 0.12)
		stem.CFrame = base * CFrame.new(0, 0.5 * shrink, 0)
		placeHeart(antHeart, base * CFrame.new(0, 1.15 * shrink, 0), 0.8 * shrink * (1 + 0.12 * math.sin(t * 8)))

		-- coracoes orbitando a area de cura
		for i, oh in ipairs(orbit) do
			local a = t * 0.8 + i / #orbit * math.pi * 2
			local p = ground + Vector3.new(math.cos(a) * radius * 0.92, 1.3 + math.sin(t * 3 + i) * 0.35, math.sin(a) * radius * 0.92)
			placeHeart(oh, CFrame.new(p) * CFrame.Angles(0, -a, 0), 0.9 * math.min(1, shrink + 0.2))
		end
		disc.Transparency = 0.86 + math.sin(t * 2.5) * 0.04

		-- coracoes subindo
		if now >= nextFloat and shrink > 0.5 and drop == 0 then
			nextFloat = now + rng:NextNumber(0.25, 0.45)
			floatHeart(center + Vector3.new(rng:NextNumber(-1.2, 1.2), hh * 0.6, rng:NextNumber(-1.2, 1.2)), rng:NextNumber(0.45, 0.75), rng:NextNumber(4, 6), rng:NextNumber(1.1, 1.5))
		end
	end)
end

for _, m in ipairs(CollectionService:GetTagged("Lovity")) do task.spawn(setup, m) end
CollectionService:GetInstanceAddedSignal("Lovity"):Connect(function(m) task.spawn(setup, m) end)

-- PULSO DE CURA ------------------------------------------------------------------------
remotes.Efeito.OnClientEvent:Connect(function(kind, model, alvos, amount)
	if kind ~= "LovityCura" or typeof(model) ~= "Instance" then return end
	local ctrl = controllers[model]
	if ctrl then ctrl.excite = 1 end
	local body = model:FindFirstChild("Corpo")
	local ground = model:GetAttribute("Chao")
	local radius = model:GetAttribute("Raio") or 12
	if not body or typeof(ground) ~= "Vector3" then return end
	ringPulse(ground, 1.5, radius, HOT, 0.55)
	if typeof(alvos) ~= "table" then return end
	for _, pos in ipairs(alvos) do
		if typeof(pos) == "Vector3" then
			local from = body.Position + Vector3.new(0, 1, 0)
			local d = (pos - from).Magnitude
			if d > 0.5 then
				local beam = P({ Color = PINK, Material = Enum.Material.Neon, Transparency = 0.15, Size = Vector3.new(0.3, 0.3, d), CFrame = CFrame.lookAt(from, pos) * CFrame.new(0, 0, -d / 2) })
				TweenService:Create(beam, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.05, 0.05, d) }):Play()
				Debris:AddItem(beam, 0.35)
			end
			local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain
			local e = Instance.new("ParticleEmitter")
			e.Texture = SPARK; e.Color = ColorSequence.new(Color3.fromRGB(120, 255, 160)); e.LightEmission = 0.8
			e.Size = NumberSequence.new(0.6, 0); e.Lifetime = NumberRange.new(0.4, 0.7); e.Speed = NumberRange.new(3, 6)
			e.SpreadAngle = Vector2.new(180, 180); e.Acceleration = Vector3.new(0, 6, 0); e.Enabled = false
			e.Parent = a
			e:Emit(8)
			Debris:AddItem(a, 1)
			if amount and amount > 0 then popText(pos + Vector3.new(0, 2.5, 0), "+" .. tostring(amount), Color3.fromRGB(70, 220, 110)) end
		end
	end
end)
