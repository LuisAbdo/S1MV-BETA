-- [EfeitosExtras] Animacoes e particulas extras (so visual, no cliente):
-- portal quando um inimigo nasce, poeira quando ele cai de cada pulo, respingos ao levar dano,
-- explosao de cubos coloridos ao morrer, capsulas saindo das armas, poeira nos passos e no pulo
-- do jogador, brilho ao comprar upgrade e estilhacos quando o Nucleo leva dano.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local estado = Shared:WaitForChild("EstadoJogo")
local WCfg = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local rng = Random.new()

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local fx = Instance.new("Folder")
fx.Name = "EfeitosExtras"
fx.Parent = workspace.CurrentCamera

-- limite de pecas de efeito vivas ao mesmo tempo (desempenho)
local MAX_PECAS = 260
local vivas = 0

local function part(props)
	if vivas >= MAX_PECAS then return nil end
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = fx
	vivas += 1
	p.Destroying:Connect(function() vivas -= 1 end)
	return p
end

local function emitAt(pos, props, n, life)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in pairs(props) do e[k] = v end
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, life or 2)
	return e
end

-- pedacinhos com fisica simples (gravidade + quique no chao), animados por um unico loop
local debris = {}
local function chunk(pos, color, size, vel, life, opts)
	opts = opts or {}
	local p = part({ Color = color, Size = Vector3.one * size, Material = opts.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Shape = opts.ball and Enum.PartType.Ball or Enum.PartType.Block, CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
	if not p then return end
	table.insert(debris, { p = p, vel = vel, spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)),
		t = 0, life = life, size = size, floorY = opts.floorY, bounce = opts.bounce or 0.35, grav = opts.grav or 90 })
end

RunService.RenderStepped:Connect(function(dt)
	for i = #debris, 1, -1 do
		local d = debris[i]
		d.t += dt
		if d.t >= d.life or not d.p.Parent then
			if d.p.Parent then d.p:Destroy() end
			table.remove(debris, i)
		else
			d.vel -= Vector3.new(0, d.grav * dt, 0)
			local pos = d.p.Position + d.vel * dt
			if d.floorY and pos.Y < d.floorY + d.size / 2 then
				pos = Vector3.new(pos.X, d.floorY + d.size / 2, pos.Z)
				d.vel = Vector3.new(d.vel.X * 0.6, -d.vel.Y * d.bounce, d.vel.Z * 0.6)
				d.spin *= 0.6
			end
			local rot = (d.p.CFrame - d.p.Position) * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
			d.p.CFrame = CFrame.new(pos) * rot
			local fade = math.clamp((d.t - d.life * 0.6) / (d.life * 0.4), 0, 1)
			d.p.Transparency = fade
			d.p.Size = Vector3.one * d.size * (1 - fade * 0.6)
		end
	end
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos)
	local ignore = { fx, workspace.CurrentCamera, workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("InimigosMortos"), workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Aliados") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), rayParams)
	return hit and hit.Position.Y or (pos.Y - 2)
end

-- anel que se expande no chao
local function ring(pos, color, from, to, dur, thick)
	local r = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.2,
		Size = Vector3.new(thick or 0.15, from * 2, from * 2), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
	if not r then return end
	TweenService:Create(r, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(thick or 0.15, to * 2, to * 2), Transparency = 1 }):Play()
	Debris:AddItem(r, dur + 0.05)
end

-- poeira de chao (blocos bege que se espalham e somem)
local DUST = Color3.fromRGB(226, 214, 186)
local function dust(pos, n, spread, color)
	for _ = 1, n do
		local s = rng:NextNumber(0.25, 0.55) * spread
		local p = part({ Color = color or DUST, Size = Vector3.one * s, Transparency = 0.25,
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.4, 0.4), s / 2, rng:NextNumber(-0.4, 0.4))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) })
		if p then
			local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
			local life = rng:NextNumber(0.35, 0.6)
			TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = p.CFrame + dir.Unit * spread * rng:NextNumber(1, 2) + Vector3.new(0, rng:NextNumber(0.3, 1), 0), Size = Vector3.one * 0.05, Transparency = 1 }):Play()
			Debris:AddItem(p, life + 0.05)
		end
	end
end

-- INIMIGOS -------------------------------------------------------------------------------
local ativos = workspace:WaitForChild("InimigosAtivos", 30)
local tracked = {} -- [model] = { body, lastY, vy, landedAt, color }

local function colorOf(body)
	local c = body.Color
	if c.R > 0.9 and c.G > 0.9 and c.B > 0.9 then return Color3.fromRGB(150, 210, 255) end
	return c
end

-- sons de chegada: portal (limitado) e rugido dos grandes (Cruelty)
local SONS_E = require(Shared.Config:WaitForChild("Sons"))
local portais, ultimoRugido = {}, 0
local function spawnSound(body, tipo, ill)
	if ill then return end
	local now = os.clock()
	for i = #portais, 1, -1 do if now - portais[i] > 0.5 then table.remove(portais, i) end end
	local function at(def, pitch)
		local s = Instance.new("Sound")
		s.SoundId = def.Id
		s.Volume = def.V
		s.PlaybackSpeed = (def.P or 1) * (pitch or 1)
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
		s.Parent = body
		s:Play()
		Debris:AddItem(s, 5)
	end
	if #portais < 3 then
		table.insert(portais, now)
		at(SONS_E.Portal, rng:NextNumber(0.9, 1.15))
	end
	if tipo == "Cruelty" and now - ultimoRugido > 2.5 then
		ultimoRugido = now
		task.delay(0.35, function() if body.Parent then at(SONS_E.RugidoChefe, rng:NextNumber(0.9, 1.05)) end end)
	end
end

local function onEnemyAdded(m)
	local body = m:WaitForChild("Corpo", 2)
	if not body then return end
	spawnSound(body, m:GetAttribute("Tipo"), m:GetAttribute("Ilusao"))
	local ill = m:GetAttribute("Ilusao")
	local g = groundY(body.Position)
	local base = Vector3.new(body.Position.X, g + 0.1, body.Position.Z)
	local col = ill and Color3.fromRGB(130, 150, 255) or Color3.fromRGB(150, 60, 220)
	-- portal: disco escuro + anel roxo + fagulhas subindo
	local disc = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(40, 10, 60), Transparency = 0.1,
		Size = Vector3.new(0.1, 0.5, 0.5), CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) })
	if disc then
		local s = body.Size.X * 1.6
		TweenService:Create(disc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, s, s) }):Play()
		task.delay(0.45, function()
			if disc.Parent then TweenService:Create(disc, TweenInfo.new(0.35), { Size = Vector3.new(0.1, 0.2, 0.2), Transparency = 1 }):Play() end
		end)
		Debris:AddItem(disc, 0.9)
	end
	ring(base + Vector3.new(0, 0.05, 0), col, 0.5, body.Size.X * 1.3, 0.45, 0.2)
	emitAt(base, { Texture = SPARK, Color = ColorSequence.new(col), LightEmission = 1, Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 4, 0) }, 14, 1.5)
	tracked[m] = { body = body, lastY = body.Position.Y, vy = 0, landedAt = 0, jumpedAt = 0, color = colorOf(body) }
end

if ativos then
	for _, m in ipairs(ativos:GetChildren()) do task.spawn(onEnemyAdded, m) end
	ativos.ChildAdded:Connect(function(m) task.spawn(onEnemyAdded, m) end)
	ativos.ChildRemoved:Connect(function(m) tracked[m] = nil end)
end

-- som a cada pulo dos inimigos (posicional, com limite para nao virar barulho com muitos inimigos)
local SONS = require(Shared.Config:WaitForChild("Sons"))
local PULO = SONS.PuloInimigo
local pulosRecentes = {}
local function jumpSound(body)
	local now = os.clock()
	for i = #pulosRecentes, 1, -1 do if now - pulosRecentes[i] > 0.3 then table.remove(pulosRecentes, i) end end
	if #pulosRecentes >= 5 then return end
	table.insert(pulosRecentes, now)
	local s = Instance.new("Sound")
	s.SoundId = PULO.Id
	s.Volume = PULO.V
	s.PlaybackSpeed = (PULO.P or 1) * rng:NextNumber(0.9, 1.12) * math.clamp(3 / math.max(1, body.Size.X), 0.75, 1.15)
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 90
	s.Parent = body
	s:Play()
	Debris:AddItem(s, 3)
end

-- poeira ao cair de cada pulo (so inimigos perto da camera)
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or dt <= 0 then return end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for _, t in pairs(tracked) do
		local b = t.body
		if b.Parent then
			local vyNow = (b.Position.Y - t.lastY) / dt
			-- estava parado/descendo e comecou a subir: decolou
			if t.vy <= 1 and vyNow > 4 and now - t.jumpedAt > 0.35 and (b.Position - camPos).Magnitude < 90 then
				t.jumpedAt = now
				jumpSound(b)
			end
		end
	end
	for m, t in pairs(tracked) do
		local b = t.body
		if not b.Parent then
			tracked[m] = nil
		else
			local y = b.Position.Y
			local vy = (y - t.lastY) / dt
			-- estava caindo e parou: aterrissou
			if t.vy < -4 and vy > -1 and now - t.landedAt > 0.4 and (b.Position - camPos).Magnitude < 90 then
				t.landedAt = now
				local feet = Vector3.new(b.Position.X, y - b.Size.Y / 2 + 0.1, b.Position.Z)
				dust(feet, 4, b.Size.X * 0.35)
			end
			t.vy = vy
			t.lastY = y
		end
	end
end)

-- respingos ao levar dano (cor do inimigo)
remotes.NumeroDano.OnClientEvent:Connect(function(pos, amount, crit)
	if typeof(pos) ~= "Vector3" then return end
	local color = Color3.fromRGB(150, 210, 255)
	if ativos then
		local best, bd
		for _, m in ipairs(ativos:GetChildren()) do
			local b = m:FindFirstChild("Corpo")
			if b then local d = (b.Position - pos).Magnitude if d < 4 and (not bd or d < bd) then best, bd = b, d end end
		end
		if best then color = colorOf(best) end
	end
	local floorY = groundY(pos)
	local n = crit and 7 or 4
	for _ = 1, n do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(10, 18)
		chunk(pos, color, rng:NextNumber(0.25, 0.45), v, rng:NextNumber(0.5, 0.8), { ball = true, floorY = floorY, bounce = 0.15 })
	end
	if crit then ring(pos, Color3.fromRGB(255, 220, 60), 0.5, 3.5, 0.25, 0.12) end
end)

-- morte: cubos coloridos + onda + moedinhas douradas subindo
local mortos = workspace:WaitForChild("InimigosMortos", 30)
if mortos then
	mortos.ChildAdded:Connect(function(m)
		local body = m:WaitForChild("Corpo", 1)
		if not body then return end
		local pos = body.Position
		local color = colorOf(body)
		local size = body.Size.X
		local floorY = groundY(pos)
		for _ = 1, math.clamp(math.floor(size * 3), 8, 18) do
			local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.5, 1.6), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(16, 30)
			chunk(pos, rng:NextNumber() < 0.25 and Color3.new(1, 1, 1) or color, rng:NextNumber(0.3, 0.7) * size / 4, v, rng:NextNumber(0.9, 1.4), { floorY = floorY, bounce = 0.4 })
		end
		ring(Vector3.new(pos.X, floorY + 0.1, pos.Z), color, 0.6, size * 1.6, 0.35, 0.25)
		ring(Vector3.new(pos.X, floorY + 0.12, pos.Z), Color3.new(1, 1, 1), 0.4, size * 1.1, 0.25, 0.12)
		local flash = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), Transparency = 0.1, Size = Vector3.one * size * 0.6, Position = pos })
		if flash then
			TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size * 1.8, Transparency = 1 }):Play()
			Debris:AddItem(flash, 0.2)
		end
		if m:GetAttribute("Assassino") == player.UserId then
			emitAt(pos, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 205, 60)), LightEmission = 1,
				Size = NumberSequence.new(0.7, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(6, 12),
				SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -8, 0) }, 12, 1.6)
		end
	end)
end

-- ARMAS: capsulas ejetadas ------------------------------------------------------------
local SEM_CAPSULA = { Estilingue = true, LancaChamas = true }
local function weaponCfg(id)
	for _, w in ipairs(WCfg.Armas) do if w.Id == id then return w end end
end
-- Capsula de latao de verdade: sai QUENTE (luz laranja que esfria), gira, quica no chao com
-- "tlim" a cada batida, rola um pouco e fica deitada alguns segundos antes de sumir.
local SONS_C = require(Shared.Config:WaitForChild("Sons"))
local BRASS = Color3.fromRGB(226, 178, 72)
local HOT = Color3.fromRGB(255, 140, 40)
local TAM_CAPSULA = { Pistola = 0.6, Rifle = 0.7, Bazuca = 1.1 }
local casings = {}
local MAX_CASINGS = 45
local function tink(pos, pitch, vol)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = SONS_C.Capsula.Id
	s.Volume = (SONS_C.Capsula.V or 0.2) * (vol or 1)
	s.PlaybackSpeed = pitch
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = 45
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 2)
end
local function ejectCasing(origin, cf, len)
	if #casings >= MAX_CASINGS then
		local old = table.remove(casings, 1)
		if old.p.Parent then old.p:Destroy() end
	end
	local p = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = HOT, Reflectance = 0.25,
		Size = Vector3.new(len, len * 0.34, len * 0.34), CFrame = cf })
	if not p then return end
	local glow = Instance.new("PointLight")
	glow.Color = HOT
	glow.Range = 3.5
	glow.Brightness = 2.2
	glow.Parent = p
	local right, look = cf.RightVector, cf.LookVector
	local v = right * rng:NextNumber(8, 12) + Vector3.new(0, rng:NextNumber(9, 14), 0) - look * rng:NextNumber(1, 3)
	table.insert(casings, { p = p, light = glow, vel = v, spin = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(-30, 30), rng:NextNumber(-25, 25)),
		t = 0, floorY = groundY(origin), bounces = 0, rest = false, len = len })
end
RunService.Heartbeat:Connect(function(dt)
	for i = #casings, 1, -1 do
		local c = casings[i]
		local p = c.p
		if not p.Parent then table.remove(casings, i) continue end
		c.t += dt
		-- esfria: laranja -> latao, luz apaga
		local heat = math.clamp(1 - c.t / 0.7, 0, 1)
		p.Color = BRASS:Lerp(HOT, heat)
		c.light.Brightness = 2.2 * heat
		if not c.rest then
			c.vel -= Vector3.new(0, 75 * dt, 0)
			local pos = p.Position + c.vel * dt
			local floorTop = c.floorY + c.len * 0.17
			if pos.Y <= floorTop and c.vel.Y < 0 then
				pos = Vector3.new(pos.X, floorTop, pos.Z)
				c.bounces += 1
				local impactV = -c.vel.Y
				if impactV > 3 then tink(pos, 1.2 + rng:NextNumber() * 0.5 + c.bounces * 0.12, math.clamp(impactV / 14, 0.3, 1)) end
				c.vel = Vector3.new(c.vel.X * 0.55, impactV * 0.38, c.vel.Z * 0.55)
				c.spin *= 0.5
				if impactV < 3 or c.bounces >= 4 then
					-- deita de lado e rola um pouquinho
					c.rest = true
					local yaw = rng:NextNumber(0, math.pi * 2)
					local final = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
					TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ CFrame = final + Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) * rng:NextNumber(0.2, 0.7) }):Play()
					c.restAt = c.t
				end
			end
			if not c.rest then
				p.CFrame = CFrame.new(pos) * (p.CFrame - p.Position) * CFrame.Angles(c.spin.X * dt, c.spin.Y * dt, c.spin.Z * dt)
			end
		elseif c.t - c.restAt > 5 then
			p.Transparency = math.min(1, p.Transparency + dt * 1.5)
			if p.Transparency >= 1 then p:Destroy() table.remove(casings, i) end
		end
	end
end)

remotes.Tiro.OnClientEvent:Connect(function(shooter, weaponId, muzzle)
	if SEM_CAPSULA[weaponId] then return end
	local w = weaponCfg(weaponId)
	if not w or w.Tipo ~= "Tiro" then return end
	local char = typeof(shooter) == "Instance" and shooter:IsA("Player") and shooter.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local h = tool and tool:FindFirstChild("Handle")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not h or not root then return end
	local cam = workspace.CurrentCamera
	if cam and (h.Position - cam.CFrame.Position).Magnitude > 90 then return end
	local len = TAM_CAPSULA[weaponId] or 0.6
	local at = h.Position + root.CFrame.RightVector * 0.3 + Vector3.new(0, 0.3, 0)
	ejectCasing(at, CFrame.new(at) * (root.CFrame - root.CFrame.Position), len)
	if w.Projeteis and w.Projeteis > 1 then
		for _ = 2, math.min(w.Projeteis, 3) do ejectCasing(at, CFrame.new(at) * (root.CFrame - root.CFrame.Position) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), len) end
	end
end)

-- JOGADOR: poeira nos passos, pouso do pulo, brilho de upgrade ---------------------------
local function watchCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then return end
	local nextStep = 0
	local conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then return end
		local v = root.AssemblyLinearVelocity
		local flatV = Vector3.new(v.X, 0, v.Z).Magnitude
		if hum.FloorMaterial ~= Enum.Material.Air and flatV > 8 and os.clock() >= nextStep then
			nextStep = os.clock() + 0.22
			dust(root.Position - Vector3.new(0, 2.9, 0) - root.CFrame.LookVector * 0.6, 2, 0.8)
		end
	end)
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			local feet = root.Position - Vector3.new(0, 2.9, 0)
			dust(feet, 7, 1.4)
			ring(feet + Vector3.new(0, 0.05, 0), DUST, 0.5, 3.2, 0.3, 0.1)
		elseif new == Enum.HumanoidStateType.Jumping then
			dust(root.Position - Vector3.new(0, 2.9, 0), 3, 0.9)
		end
	end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then conn:Disconnect() end end)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.spawn(watchCharacter, player.Character) end

local function upgradeBurst(color)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local feet = root.Position - Vector3.new(0, 2.9, 0)
	ring(feet + Vector3.new(0, 0.1, 0), color, 0.5, 6, 0.5, 0.25)
	ring(feet + Vector3.new(0, 0.12, 0), Color3.new(1, 1, 1), 0.5, 4, 0.35, 0.12)
	emitAt(feet + Vector3.new(0, 0.5, 0), { Texture = SPARK, Color = ColorSequence.new(color), LightEmission = 1,
		Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top }, 24, 1.6)
	-- coluna de luz rapida
	local col = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.35,
		Size = Vector3.new(9, 2.6, 2.6), CFrame = CFrame.new(feet + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	if col then
		TweenService:Create(col, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(12, 0.2, 0.2), Transparency = 1 }):Play()
		Debris:AddItem(col, 0.5)
	end
end
local lastTier = player:GetAttribute("ArmaTier")
player:GetAttributeChangedSignal("ArmaTier"):Connect(function()
	local t = player:GetAttribute("ArmaTier")
	if lastTier and t and t > lastTier then upgradeBurst(Color3.fromRGB(98, 226, 160)) end
	lastTier = t
end)
local lastVida = player:GetAttribute("NivelVida")
player:GetAttributeChangedSignal("NivelVida"):Connect(function()
	local v = player:GetAttribute("NivelVida")
	if lastVida and v and v > lastVida then upgradeBurst(Color3.fromRGB(255, 90, 90)) end
	lastVida = v
end)

-- NUCLEO: estilhacos e brilho quando leva dano ------------------------------------------
-- (com StreamingEnabled o Nucleo pode ainda nao ter chegado quando o script comeca: busca na hora)
local esf
local function getEsf()
	if esf and esf.Parent then return esf end
	local core = CollectionService:GetTagged("Nucleo")[1]
	esf = core and core:FindFirstChild("NucleoEsfera")
	return esf
end
local lastCore = estado:GetAttribute("CoreVida")
local lastCoreFx = 0
-- IMPACTO NO ESCUDO DO NUCLEO: o inimigo bate num escudo de energia (nao direto no nucleo).
-- Ondulacao hexagonal no ponto atingido (na cor do tier), arco eletrico ate a esfera, anel de
-- choque virado para o atacante, faiscas, e o atacante pisca branco.
local CoreCfgE = require(Shared.Config:WaitForChild("Core"))
local SHIELD_R = 8.5
local function tierCol()
	local t = estado:GetAttribute("CoreTier") or 1
	local v = CoreCfgE.VisualTier and CoreCfgE.VisualTier[math.clamp(t, 1, #CoreCfgE.VisualTier)]
	if v and v.Arcoiris then return Color3.fromHSV((os.clock() * 0.12) % 1, 0.55, 1) end
	return v and v.Cor or Color3.fromRGB(0, 229, 255)
end
local function attackerNearCore(center)
	if not ativos then return nil end
	local best, bd
	for _, m in ipairs(ativos:GetChildren()) do
		local b = m:FindFirstChild("Corpo")
		if b then
			local d = (Vector3.new(b.Position.X, 0, b.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			if d < 22 and (not bd or d < bd) then best, bd = b, d end
		end
	end
	return best
end
local function arc(from, to, color)
	local pts = { from }
	local n = 6
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n) + Vector3.new(rng:NextNumber(-0.9, 0.9), rng:NextNumber(-0.9, 0.9), rng:NextNumber(-0.9, 0.9))
		table.insert(pts, p)
	end
	table.insert(pts, to)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = (b - a).Magnitude
		local seg = part({ Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Size = Vector3.new(0.14, 0.14, d), CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -d / 2) })
		if seg then
			TweenService:Create(seg, TweenInfo.new(0.16), { Transparency = 1, Size = Vector3.new(0.03, 0.03, d) }):Play()
			Debris:AddItem(seg, 0.18)
		end
	end
end
estado:GetAttributeChangedSignal("CoreVida"):Connect(function()
	local v = estado:GetAttribute("CoreVida")
	if lastCore and v and v < lastCore and getEsf() and os.clock() - lastCoreFx > 0.12 then
		lastCoreFx = os.clock()
		local center = esf.Position
		local col = tierCol()
		local enemy = attackerNearCore(center)
		local dir = enemy and (enemy.Position - center) or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		dir = Vector3.new(dir.X, math.clamp(dir.Y, -2, 3), dir.Z)
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(1, 0, 0)
		local hit = center + dir * SHIELD_R
		-- 1) bolha do escudo acende inteira bem fraca + ondulacao forte no ponto do impacto
		local bubble = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = col, Transparency = 0.55, Size = Vector3.one * SHIELD_R * 2, Position = center })
		if bubble then
			TweenService:Create(bubble, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.one * SHIELD_R * 2.08 }):Play()
			Debris:AddItem(bubble, 0.4)
		end
		local ripple = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = col, Transparency = 0, Size = Vector3.one * 1.5, Position = hit })
		if ripple then
			TweenService:Create(ripple, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * 7, Transparency = 1 }):Play()
			Debris:AddItem(ripple, 0.35)
		end
		-- 2) anel de choque virado para o atacante
		local ringP = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = col, Transparency = 0.1, Size = Vector3.new(0.12, 1, 1),
			CFrame = CFrame.lookAt(hit, hit + dir) * CFrame.Angles(0, math.rad(90), 0) })
		if ringP then
			TweenService:Create(ringP, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, 6, 6), Transparency = 1 }):Play()
			Debris:AddItem(ringP, 0.3)
		end
		-- 3) arco eletrico do impacto ate a esfera + clarao
		arc(hit, center + dir * esf.Size.X * 0.5, col)
		local flash = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), Transparency = 0.1, Size = Vector3.one * 0.8, Position = hit })
		if flash then
			local l = Instance.new("PointLight"); l.Color = col; l.Range = 14; l.Brightness = 5; l.Parent = flash
			TweenService:Create(flash, TweenInfo.new(0.15), { Size = Vector3.one * 2.4, Transparency = 1 }):Play()
			TweenService:Create(l, TweenInfo.new(0.2), { Brightness = 0 }):Play()
			Debris:AddItem(flash, 0.22)
		end
		-- 4) faiscas espirrando para fora do escudo
		for _ = 1, 6 do
			local sd = (dir + Vector3.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 0.9), rng:NextNumber(-0.7, 0.7))).Unit
			chunk(hit, col:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.6)), rng:NextNumber(0.12, 0.25), sd * rng:NextNumber(12, 20), 0.45, { neon = true, grav = 40 })
		end
		-- 5) o atacante pisca branco
		if enemy then
			local hl = enemy:FindFirstChild("PiscaEscudo") or Instance.new("Highlight")
			hl.Name = "PiscaEscudo"
			hl.FillColor = Color3.new(1, 1, 1)
			hl.OutlineTransparency = 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.FillTransparency = 0.2
			hl.Adornee = enemy
			hl.Parent = enemy
			TweenService:Create(hl, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
			Debris:AddItem(hl, 0.2)
		end
	end
	lastCore = v
end)
