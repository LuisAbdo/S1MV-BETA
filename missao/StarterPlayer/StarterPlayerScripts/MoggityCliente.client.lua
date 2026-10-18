-- [MoggityCliente] Visual e animacao do MOGGITY (habilidade Z do Engenheiro), no estilo peashooter:
-- ervilha soldado com capacete, focinho, olhinhos e folhas. Nasce brotando do chao com quique,
-- balanca parado, mira girando a cabeca e a cada tiro da um tranco para tras (squash no focinho)
-- soltando uma ervilha que voa ate o inimigo e estoura em respingos verdes.
-- RAJADA (ao nascer e na Sobrecarga): brilha branco com um feixe de luz do ceu e metralha uma
-- enxurrada de ervilhas em linha reta. O servidor (AllyService) cuida da mira e do dano.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local SONS = require(Shared.Config.Sons)
local SE = (SONS.Classes and SONS.Classes.Engenheiro) or {}
local rng = Random.new()

local fx = Instance.new("Folder")
fx.Name = "MoggityVisual"
fx.Parent = workspace

local GREEN = Color3.fromRGB(120, 205, 60)
local GREEN_D = Color3.fromRGB(80, 160, 45)
local LEAF = Color3.fromRGB(60, 145, 45)
local PEA = Color3.fromRGB(150, 225, 80)
local NAVY = Color3.fromRGB(36, 44, 72)
local GOLD = Color3.fromRGB(255, 205, 60)

local function P(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or fx
	return p
end
-- elipsoide (Part com SpecialMesh de esfera: segue o tamanho da peca)
local function ellipsoid(props, parent)
	local p = P(props, parent)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
local function sound(def, pos, vol)
	if not def or not def.Id then return end
	local a = P({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.5) * (vol or 1)
	s.PlaybackSpeed = (def.P or 1) * rng:NextNumber(0.93, 1.08)
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 160
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 3)
end

-- ERVILHAS ------------------------------------------------------------------------------------
local peas = {}   -- { p, from, to, t0, dur, splat }
local function splat(pos, big)
	local disc = P({ Shape = Enum.PartType.Cylinder, Color = PEA, Transparency = 0.15, Size = Vector3.new(0.1, big and 2.4 or 1.6, big and 2.4 or 1.6),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)) })
	TweenService:Create(disc, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = Vector3.new(0.1, big and 3.6 or 2.6, big and 3.6 or 2.6), Transparency = 1 }):Play()
	Debris:AddItem(disc, 0.4)
	for _ = 1, big and 8 or 5 do
		local b = P({ Shape = Enum.PartType.Ball, Color = PEA:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.35)), Size = Vector3.one * rng:NextNumber(0.25, 0.45), Position = pos })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = pos + dir * rng:NextNumber(1.5, 3), Size = Vector3.one * 0.05, Transparency = 0.6 }):Play()
		Debris:AddItem(b, 0.4)
	end
end
local function shootPea(from, to, speed, opts)
	opts = opts or {}
	local d = (to - from).Magnitude
	local p = P({ Shape = Enum.PartType.Ball, Color = PEA, Size = Vector3.one * (opts.size or 0.85) })
	-- brilhinho de cima (ervilha "de desenho")
	local glint = P({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.2, Size = Vector3.one * (opts.size or 0.85) * 0.3 })
	table.insert(peas, { p = p, g = glint, from = from, to = to, t0 = os.clock(), dur = math.max(0.05, d / speed), splat = opts.splat ~= false, big = opts.big, fade = opts.fade })
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #peas, 1, -1 do
		local e = peas[i]
		local u = (now - e.t0) / e.dur
		if u >= 1 then
			if e.splat then splat(e.to, e.big) end
			e.p:Destroy(); e.g:Destroy()
			table.remove(peas, i)
		else
			local pos = e.from:Lerp(e.to, u)
			e.p.Position = pos
			e.g.Position = pos + Vector3.new(-0.12, 0.18, 0) * e.p.Size.X
			if e.fade and u > 0.8 then
				local k = (u - 0.8) / 0.2
				e.p.Transparency = k; e.g.Transparency = 0.2 + 0.8 * k
			end
		end
	end
end)

-- MONTAGEM ------------------------------------------------------------------------------------
-- cada peca: grupo ("base" fica no chao, "cabeca" mira/recua), CFrame relativo e tamanho base
local function build(owner)
	local list = {}
	local function add(p, group, rel, tag)
		table.insert(list, { p = p, group = group, rel = rel, size = p.Size, tag = tag })
		return p
	end
	-- caule e folhas da base
	add(P({ Shape = Enum.PartType.Cylinder, Color = GREEN_D, Size = Vector3.new(2.8, 0.7, 0.7) }, owner), "base", CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)))
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		add(ellipsoid({ Color = LEAF, Size = Vector3.new(0.4, 0.35, 2.2) }, owner), "base",
			CFrame.Angles(0, a, 0) * CFrame.new(0, 0.2, -1.1) * CFrame.Angles(math.rad(-10), 0, 0))
	end
	-- cabeca
	add(P({ Shape = Enum.PartType.Ball, Color = GREEN, Size = Vector3.one * 2.6 }, owner), "cabeca", CFrame.new())
	add(P({ Shape = Enum.PartType.Cylinder, Color = GREEN, Size = Vector3.new(1.5, 1.15, 1.15) }, owner), "cabeca", CFrame.new(0, -0.1, -1.55) * CFrame.Angles(0, math.rad(90), 0), "focinho")
	add(P({ Shape = Enum.PartType.Cylinder, Color = GREEN_D, Size = Vector3.new(0.35, 1.45, 1.45) }, owner), "cabeca", CFrame.new(0, -0.1, -2.3) * CFrame.Angles(0, math.rad(90), 0), "boca")
	add(P({ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(20, 40, 15), Size = Vector3.new(0.12, 0.85, 0.85) }, owner), "cabeca", CFrame.new(0, -0.1, -2.5) * CFrame.Angles(0, math.rad(90), 0), "boca")
	for _, sx in ipairs({ -1, 1 }) do
		add(P({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(15, 15, 20), Size = Vector3.one * 0.5 }, owner), "cabeca", CFrame.new(0.55 * sx, 0.45, -1.05))
		add(P({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Size = Vector3.one * 0.17 }, owner), "cabeca", CFrame.new(0.5 * sx, 0.56, -1.27))
	end
	-- folhinhas atras da cabeca
	for _, sx in ipairs({ -1, 1 }) do
		add(ellipsoid({ Color = LEAF, Size = Vector3.new(0.35, 0.3, 1.3) }, owner), "cabeca", CFrame.new(0.3 * sx, -0.2, 1.4) * CFrame.Angles(math.rad(-25), math.rad(18 * sx), 0))
	end
	-- capacete de soldado com estrelas e divisa
	add(ellipsoid({ Color = NAVY, Size = Vector3.new(2.95, 1.7, 2.95) }, owner), "cabeca", CFrame.new(0, 0.7, 0.1))
	add(P({ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(26, 32, 54), Size = Vector3.new(0.18, 3.2, 3.2) }, owner), "cabeca", CFrame.new(0, 0.2, 0.05) * CFrame.Angles(0, 0, math.rad(90)))
	for i = -1, 1 do
		add(P({ Color = GOLD, Material = Enum.Material.Neon, Size = Vector3.new(0.26, 0.26, 0.08) }, owner), "cabeca",
			CFrame.new(i * 0.55, 1.05 - math.abs(i) * 0.12, -1.25 + math.abs(i) * 0.12) * CFrame.Angles(math.rad(-30), 0, math.rad(45)))
	end
	for _, y in ipairs({ 0.75, 1.0 }) do
		add(P({ Color = GOLD, Size = Vector3.new(0.08, 0.14, 0.6) }, owner), "cabeca", CFrame.new(1.42, y, 0.15) * CFrame.Angles(0, 0, math.rad(15)))
	end
	return list
end

-- CONTROLADOR DE CADA MOGGITY -----------------------------------------------------------------
local active = {}

local function setup(model)
	if active[model] then return end
	local body = model:WaitForChild("Corpo", 5)
	if not body then return end
	local holder = Instance.new("Model")
	holder.Name = "MoggityVisual"
	holder.Parent = fx
	local parts = build(holder)
	local st = {
		model = model, body = body, holder = holder, parts = parts,
		ground = model:GetAttribute("Chao") or (body.Position - Vector3.new(0, 2.6, 0)),
		yaw = math.atan2(-body.CFrame.LookVector.X, -body.CFrame.LookVector.Z),
		born = os.clock(), recoil = 0, glow = 0, firingUntil = 0, chargeUntil = 0, nextPea = 0, nextSnd = 0,
	}
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.OutlineColor = Color3.fromRGB(230, 255, 180)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = holder
	st.hl = hl
	active[model] = st
	-- brota do chao: poeira e folhas
	splat(st.ground + Vector3.new(0, 0.2, 0), true)
	sound(SE.Moggity or SONS.MontarTorreta, st.ground)
end

local function mouthPos(st)
	return st.headCF and (st.headCF * CFrame.new(0, -0.1, -2.6)).Position or (st.ground + Vector3.new(0, 3.3, 0))
end

local function teardown(model)
	local st = active[model]
	if not st then return end
	active[model] = nil
	-- some com um "puf" de folhas
	for _ = 1, 10 do
		local b = ellipsoid({ Color = LEAF, Size = Vector3.new(0.3, 0.2, 0.9), CFrame = CFrame.new(st.ground + Vector3.new(0, 2, 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1), rng:NextNumber(-1, 1)).Unit
		TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = b.CFrame + dir * 5, Transparency = 1 }):Play()
		Debris:AddItem(b, 0.65)
	end
	st.holder:Destroy()
end

local function backOut(x) local c1, c3 = 1.70158, 2.70158; return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2 end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, st in pairs(active) do
		if not model.Parent or not st.body.Parent then
			teardown(model)
		else
			-- mira: gira a cabeca suavemente para onde o corpo logico aponta
			local lv = st.body.CFrame.LookVector
			local targetYaw = math.atan2(-lv.X, -lv.Z)
			local dy = (targetYaw - st.yaw + math.pi) % (2 * math.pi) - math.pi
			st.yaw += dy * math.min(1, dt * 12)
			-- brotar do chao com quique
			local s = math.clamp((now - st.born) / 0.55, 0, 1)
			s = s < 1 and math.max(0.05, backOut(s)) or 1
			local charging = now < st.chargeUntil
			local firing = now >= st.chargeUntil and now < st.firingUntil
			-- recuo: decai rapido; na rajada fica tremendo
			st.recoil = math.max(0, st.recoil - dt * 6)
			if firing then st.recoil = 0.45 + 0.35 * math.abs(math.sin(now * 40)) end
			local idle = math.sin(now * 2.4)
			local root = CFrame.new(st.ground) * CFrame.Angles(0, st.yaw, 0)
			local jitter = (charging and Vector3.new(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)) or Vector3.zero)
			local headCF = root * CFrame.new(jitter + Vector3.new(0, (3.3 + idle * 0.12) * s, st.recoil * 0.7))
				* CFrame.Angles(math.rad(-st.recoil * 14 + idle * 2), 0, math.rad(math.sin(now * 1.7) * 3))
			st.headCF = headCF
			for _, e in ipairs(st.parts) do
				local rel = e.rel
				local size = e.size * s
				if e.group == "base" then
					-- folhas e caule balancam levemente
					local sway = CFrame.Angles(0, 0, math.rad(math.sin(now * 2 + rel.Position.X) * 2))
					e.p.CFrame = root * sway * CFrame.new(rel.Position * s) * (rel - rel.Position)
				else
					local pos = rel.Position * s
					if e.tag == "focinho" or e.tag == "boca" then
						-- squash do focinho no tiro: encolhe e volta esticando
						local k = 1 - st.recoil * 0.35
						pos = Vector3.new(pos.X, pos.Y, pos.Z * k)
						if e.tag == "boca" then size = Vector3.new(size.X, size.Y * (1 + st.recoil * 0.25), size.Z * (1 + st.recoil * 0.25)) end
					end
					e.p.CFrame = headCF * CFrame.new(pos) * (rel - rel.Position)
				end
				e.p.Size = size
			end
			-- brilho branco da carga (como o "plant food")
			local glowTarget = charging and (0.25 + 0.15 * math.sin(now * 25)) or (firing and 0.6 or 1)
			st.hl.FillTransparency += (glowTarget - st.hl.FillTransparency) * math.min(1, dt * 10)
			st.hl.OutlineTransparency = charging and 0 or (firing and 0.3 or 1)
			-- metralhada visual
			if firing and now >= st.nextPea then
				st.nextPea = now + 1 / 42
				local face = (root.LookVector)
				local right = root.RightVector
				local from = mouthPos(st) + right * rng:NextNumber(-0.5, 0.5) + Vector3.new(0, rng:NextNumber(-0.35, 0.35), 0)
				local to = from + face * (st.alcance or 40) + right * rng:NextNumber(-1.6, 1.6) + Vector3.new(0, rng:NextNumber(-0.7, 0.5), 0)
				shootPea(from, to, 110, { size = rng:NextNumber(0.9, 1.25), splat = false, fade = true })
				if now >= st.nextSnd then
					st.nextSnd = now + 0.12
					sound(SE.MoggityRajada, from, 0.8)
				end
			end
		end
	end
end)

-- ESTADO / EVENTOS -------------------------------------------------------------------------------
local aliados = workspace:WaitForChild("Aliados", 30)
if aliados then
	for _, m in ipairs(aliados:GetChildren()) do if m.Name == "MOGGITY" then task.spawn(setup, m) end end
	aliados.ChildAdded:Connect(function(m) if m.Name == "MOGGITY" then task.spawn(setup, m) end end)
end

remotes:WaitForChild("Efeito").OnClientEvent:Connect(function(kind, model, a, b, c, d)
	if kind == "MoggityTiro" then
		local st = active[model]
		if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return end
		local from = st and mouthPos(st) or a
		if st then st.recoil = 1 end
		-- baforada verde na boca
		local puff = P({ Shape = Enum.PartType.Ball, Color = PEA:Lerp(Color3.new(1, 1, 1), 0.5), Material = Enum.Material.Neon, Transparency = 0.3, Size = Vector3.one * 0.6, Position = from })
		TweenService:Create(puff, TweenInfo.new(0.15), { Size = Vector3.one * 1.6, Transparency = 1 }):Play()
		Debris:AddItem(puff, 0.2)
		shootPea(from, b, tonumber(c) or 75)
		sound(SE.MoggityTiro or SONS.Habilidade, from)
		task.delay((b - from).Magnitude / (tonumber(c) or 75), function() sound(SE.MoggityErvilha, b, 0.8) end)
	elseif kind == "MoggityRajada" then
		local st = active[model]
		if not st then return end
		local carga, dur = tonumber(b) or 0.8, tonumber(c) or 2.2
		st.alcance = tonumber(d) or 40
		st.chargeUntil = os.clock() + carga
		st.firingUntil = st.chargeUntil + dur
		sound(SE.MoggityCarga or SONS.GeradorZumbido, st.ground)
		-- feixe de luz do ceu durante a carga
		local beam = P({ Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(240, 255, 210), Material = Enum.Material.Neon, Transparency = 0.6,
			Size = Vector3.new(60, 5, 5), CFrame = CFrame.new(st.ground + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		TweenService:Create(beam, TweenInfo.new(carga + 0.4, Enum.EasingStyle.Sine), { Size = Vector3.new(60, 0.3, 0.3), Transparency = 1 }):Play()
		Debris:AddItem(beam, carga + 0.5)
		-- estouro branco no chao quando comeca a atirar (a "estrela" do video)
		task.delay(carga, function()
			if not st.holder.Parent then return end
			local ring = P({ Shape = Enum.PartType.Cylinder, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.1,
				Size = Vector3.new(0.15, 2, 2), CFrame = CFrame.new(st.ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = Vector3.new(0.1, 11, 11), Transparency = 1 }):Play()
			Debris:AddItem(ring, 0.5)
			local flash = P({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.2, Size = Vector3.one * 2, Position = mouthPos(st) })
			TweenService:Create(flash, TweenInfo.new(0.25), { Size = Vector3.one * 6, Transparency = 1 }):Play()
			Debris:AddItem(flash, 0.3)
		end)
	end
end)
