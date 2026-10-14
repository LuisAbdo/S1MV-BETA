-- [EnemyService] IA de todos os inimigos num unico Heartbeat.
-- Movimento cinematico por pulos (animacao antiga reaproveitada), 16 slots de ataque
-- em anel ao redor do Nucleo, anel de espera, aggro/leash, spawn por setores.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Enemies)

local EnemyService = {}
EnemyService.OnDied = {} -- callbacks(data, killerUserId)

local Core, Economy, Build, Ally, Class
local obstacleParams = RaycastParams.new()
local estado
local folder, fxFolder, deadFolder
local enemies = {}
local byModel = {}
local slots = {}
local playerCounts = {}
local sectorHeat = {}
local rayParams = RaycastParams.new()
local rng = Random.new()
local lastFilterRefresh = 0

local P = Cfg.Pulo
local IA = Cfg.IA

local function log(...) print("[EnemyService]", ...) end

local function lerpKeys(keys, t)
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a[1] and t <= b[1] then
			local u = (t - a[1]) / math.max(1e-6, b[1] - a[1])
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[#keys][2]
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function refreshFilter()
	local list = { folder, fxFolder, deadFolder, Core:GetModel(), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Estruturas") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(list, pl.Character) end
	end
	local zona = workspace:FindFirstChild("Zona de spawn")
	if zona then table.insert(list, zona) end
	rayParams.FilterDescendantsInstances = list
end

local function groundAt(x, z, fromY)
	local hit = workspace:Raycast(Vector3.new(x, fromY + 6, z), Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position.Y or nil
end

local function waveNumber() return estado:GetAttribute("Wave") or 1 end

-- SLOTS ---------------------------------------------------------------
local function slotPosition(i)
	local a = (i - 1) / IA.Slots * math.pi * 2
	return Core.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * IA.RaioSlot
end

local function releaseSlot(data)
	if data.slot and slots[data.slot] == data then slots[data.slot] = nil end
	data.slot = nil
end

local function reserveSlot(data)
	if data.slot then return true end
	local rel = flat(data.pos - Core.Position)
	local myA = math.atan2(rel.Z, rel.X)
	local best, bestD
	for i = 1, IA.Slots do
		if not slots[i] then
			local a = (i - 1) / IA.Slots * math.pi * 2
			local d = math.abs(math.atan2(math.sin(a - myA), math.cos(a - myA)))
			if not bestD or d < bestD then best, bestD = i, d end
		end
	end
	if best then slots[best] = data; data.slot = best; return true end
	return false
end

local function releasePlayer(data)
	if data.player then
		playerCounts[data.player] = math.max(0, (playerCounts[data.player] or 1) - 1)
		data.player = nil
	end
end

-- VISUAL --------------------------------------------------------------
-- mesma barra segmentada dos jogadores (ReplicatedStorage.Shared.BarraVida)
local BarraVida = require(Shared:WaitForChild("BarraVida"))
local function makeHealthBar(data)
	local largura = math.max(3, data.size * 1.15)
	local barra = BarraVida.Create(data.body, {
		Largura = largura,
		Offset = Vector3.new(0, data.size * 0.5 + 1.1, 0),
		MaxDistance = 110,
	})
	data.barObj = barra
	data.bar = barra.Fill
	data.barGui = barra.Gui
end

local function poof(pos, color, size)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.one; p.Position = pos
	p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(240, 240, 240))
	e.Size = NumberSequence.new(size or 2, (size or 2) * 2.2)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(8, 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Enabled = false
	e.Parent = p
	e:Emit(16)
	Debris:AddItem(p, 1.5)
end

local function templateFor(typeCfg)
	local inimigos = ServerStorage:WaitForChild("Inimigos")
	local t = inimigos:FindFirstChild(typeCfg.Template)
	if t and t:IsA("Model") then
		t = t:FindFirstChildWhichIsA("MeshPart") or t:FindFirstChildWhichIsA("BasePart")
	end
	return t
end

-- SPAWN ---------------------------------------------------------------
-- Lados ativos (angulos em radianos no plano XZ, a partir do centro da zona). nil = qualquer lugar.
local spawnSides, sideSpread = nil, math.rad(38)
function EnemyService:SetSpawnSides(angles, spreadDeg)
	spawnSides = angles
	if spreadDeg then sideSpread = math.rad(spreadDeg) end
end
function EnemyService:GetSpawnSides() return spawnSides end

-- ponto aleatorio dentro do "leque" de um lado (respeita a zona, o raio minimo e o spawn dos jogadores)
function EnemyService:PointOnSide(angle, center, hx, hz, relaxed)
	local S = Cfg.Spawn
	local sp = workspace:FindFirstChild("SpawnJogadores", true)
	for _ = 1, 16 do
		local a = angle + rng:NextNumber(-sideSpread, sideSpread)
		local c, s = math.cos(a), math.sin(a)
		local rMax = math.min(hx / math.max(math.abs(c), 1e-3), hz / math.max(math.abs(s), 1e-3)) - 3
		-- nascem na faixa de fora (perto da coluna de aviso), nao espalhados ate o meio do mapa
		local r = rng:NextNumber(math.max(math.min(S.RaioMinNucleo + 8, rMax - 1), rMax * 0.7), rMax)
		local x, z = center.X + c * r, center.Z + s * r
		local nearSpawn = sp and (Vector3.new(x, 0, z) - Vector3.new(sp.Position.X, 0, sp.Position.Z)).Magnitude < (S.SpawnSeguro or 20)
		local y = (not nearSpawn) and groundAt(x, z, Core.Position.Y + 10)
		if y then
			local ok = true
			if not relaxed then
				for _, e in ipairs(enemies) do
					if (flat(e.pos) - Vector3.new(x, 0, z)).Magnitude < S.DistanciaMinima then ok = false break end
				end
			end
			if ok then return Vector3.new(x, y, z) end
		end
	end
	return nil
end

function EnemyService:PickSpawnPoint()
	local zona = workspace:FindFirstChild("Zona de spawn")
	local hx = zona and zona.Size.X / 2 or 40
	local hz = zona and zona.Size.Z / 2 or 35
	local center = zona and zona.Position or Core.Position
	local S = Cfg.Spawn
	if spawnSides and #spawnSides > 0 then
		-- com lados definidos o inimigo SEMPRE sai pelo lado avisado (nunca cai no sorteio geral)
		local ang = spawnSides[rng:NextInteger(1, #spawnSides)]
		local p = self:PointOnSide(ang, center, hx, hz)
		if p then return p end
		p = self:PointOnSide(ang, center, hx, hz, true) -- aceita ficar perto de outro inimigo
		if p then return p end
		local c, s = math.cos(ang), math.sin(ang)
		local rMax = math.min(hx / math.max(math.abs(c), 1e-3), hz / math.max(math.abs(s), 1e-3)) - 6
		local x, z = center.X + c * rMax + rng:NextNumber(-4, 4), center.Z + s * rMax + rng:NextNumber(-4, 4)
		return Vector3.new(x, groundAt(x, z, Core.Position.Y + 10) or Core.Position.Y, z)
	end
	-- ponto aleatorio em QUALQUER lugar da zona (como no video: inimigos chegam de todos os lados)
	local sp = workspace:FindFirstChild("SpawnJogadores", true)
	for _ = 1, 20 do
		local x = center.X + rng:NextNumber(-hx + 2, hx - 2)
		local z = center.Z + rng:NextNumber(-hz + 2, hz - 2)
		local flatD = (Vector3.new(x, 0, z) - Vector3.new(Core.Position.X, 0, Core.Position.Z)).Magnitude
		local nearSpawn = sp and (Vector3.new(x, 0, z) - Vector3.new(sp.Position.X, 0, sp.Position.Z)).Magnitude < (S.SpawnSeguro or 20)
		if flatD >= S.RaioMinNucleo and not nearSpawn then
			local y = groundAt(x, z, Core.Position.Y + 10)
			if y then
				local ok = true
				for _, e in ipairs(enemies) do
					if (flat(e.pos) - Vector3.new(x, 0, z)).Magnitude < S.DistanciaMinima then ok = false break end
				end
				if ok then return Vector3.new(x, y, z) end
			end
		end
	end
	-- fallback: setor (garante um ponto valido)
	local sector = rng:NextInteger(1, S.Setores)
	return self:PointInSector(sector, center, hx, hz)
end

function EnemyService:PointInSector(sector, center, hx, hz)
	local S = Cfg.Spawn
	for _ = 1, 12 do
		local a = ((sector - 1) + rng:NextNumber(0.1, 0.9)) / S.Setores * math.pi * 2
		local c, s = math.cos(a), math.sin(a)
		local rMax = math.min(hx / math.max(math.abs(c), 1e-3), hz / math.max(math.abs(s), 1e-3)) - 2
		local r = rng:NextNumber(math.min(S.RaioMinNucleo, rMax - 1), rMax)
		local x, z = center.X + c * r, center.Z + s * r
		local y = groundAt(x, z, Core.Position.Y + 10)
		local sp = workspace:FindFirstChild("SpawnJogadores", true)
		local nearSpawn = sp and (Vector3.new(x, 0, z) - Vector3.new(sp.Position.X, 0, sp.Position.Z)).Magnitude < (S.SpawnSeguro or 20)
		if y and not nearSpawn then
			local ok = true
			for _, e in ipairs(enemies) do
				if (flat(e.pos) - Vector3.new(x, 0, z)).Magnitude < S.DistanciaMinima then ok = false break end
			end
			if ok then return Vector3.new(x, y, z) end
		end
	end
	return Vector3.new(center.X + hx * 0.8, Core.Position.Y, center.Z)
end

function EnemyService:CountAlive()
	local n = 0
	for _, e in ipairs(enemies) do if not e.illusion then n += 1 end end
	return n
end

function EnemyService:CountAll() return #enemies end

function EnemyService:Spawn(typeName, hpMult, opts)
	opts = opts or {}
	if #enemies >= Cfg.MaxVivos and not opts.illusion then return nil end
	local t = Cfg.Tipos[typeName]
	if not t then return nil end
	local tmpl = templateFor(t)
	if not tmpl then warn("[EnemyService] Template ausente: " .. tostring(t.Template)) return nil end
	local pos = opts.position or self:PickSpawnPoint()
	local model = Instance.new("Model")
	model.Name = opts.illusion and (t.Nome .. " (ilusão)") or t.Nome
	local body = tmpl:Clone()
	for _, d in ipairs(body:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ValueBase") then d:Destroy() end
	end
	body.Name = "Corpo"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = true
	body.Size = Vector3.one * t.Tamanho
	body.Parent = model
	local hum = Instance.new("Humanoid")
	local maxHp = opts.illusion and 1 or math.floor(t.Vida * (hpMult or 1))
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = model
	model.PrimaryPart = body
	model:SetAttribute("Tipo", typeName)
	CollectionService:AddTag(model, "Inimigo")

	local data = {
		model = model, body = body, hum = hum, cfg = t, typeName = typeName,
		size = t.Tamanho, pos = pos, hopT = rng:NextNumber(0, P.Duracao),
		lastAttack = 0, acc = 0, illusion = opts.illusion == true, parentData = opts.parent,
		children = {}, stacks = 0, lastHit = 0, fury = false, nextCrush = os.clock() + rng:NextNumber(3, 6),
		crushing = false, stuckT = 0, progressPos = pos, face = Vector3.new(0, 0, -1),
		speedMult = 1, lastHealth = maxHp,
	}
	if data.illusion then
		model:SetAttribute("Ilusao", true)
	end
	makeHealthBar(data)
	self:_render(data)
	model.Parent = folder

	hum.HealthChanged:Connect(function(h)
		if data.dead then return end
		local ratio = math.clamp(h / hum.MaxHealth, 0, 1)
		data.barObj:Set(ratio)
		if h <= 0 then
			self:_kill(data, model:GetAttribute("UltimoAtacante"), false)
		elseif typeName == "Cruelty" and not data.fury and ratio < t.FuriaLimiar then
			data.fury = true
			data.speedMult = t.FuriaVelocidade
			body.Color = Color3.fromRGB(140, 0, 0)
			local decal = body:FindFirstChildOfClass("Decal")
			if decal then decal.Color3 = Color3.fromRGB(255, 60, 60) end
			poof(body.Position, Color3.fromRGB(255, 60, 40), 3)
		end
	end)

	byModel[model] = data
	table.insert(enemies, data)
	return data
end

-- DANO / MORTE --------------------------------------------------------
function EnemyService:GetData(model) return byModel[model] end

function EnemyService:Damage(model, amount, player)
	local data = byModel[model]
	if not data or data.dead then return false end
	if player then model:SetAttribute("UltimoAtacante", player.UserId) end
	data.lastAttack = math.max(data.lastAttack, os.clock() - data.cfg.Cooldown + (IA.HitStun or 0))
	data.hum:TakeDamage(amount)
	return true
end

function EnemyService:Knockback(model, dir, amount)
	local data = byModel[model]
	if not data or data.dead or data.cfg.ImuneEmpurrao then return end
	dir = flat(dir)
	if dir.Magnitude < 1e-3 then return end
	local np = data.pos + dir.Unit * amount
	local y = groundAt(np.X, np.Z, data.pos.Y)
	if y and y - data.pos.Y <= IA.DegrauMax then
		data.pos = Vector3.new(np.X, y, np.Z)
	end
end

function EnemyService:Stun(model, duration)
	local data = byModel[model]
	if not data or data.dead then return end
	data.stunUntil = math.max(data.stunUntil or 0, os.clock() + duration)
end

function EnemyService:DropTarget(model)
	local data = byModel[model]
	if not data or data.dead then return end
	releasePlayer(data)
end

function EnemyService:Slow(model, factor, duration)
	local data = byModel[model]
	if not data or data.dead then return end
	data.slowUntil = os.clock() + duration
	data.slowFactor = factor
	local body = data.body
	if not data.slowFx then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Gelo"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(170, 235, 255))
		e.Size = NumberSequence.new(0.6, 0)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Rate = 14
		e.Speed = NumberRange.new(1, 3)
		e.Parent = body
		data.slowFx = e
	end
	data.slowFx.Enabled = true
	task.delay(duration, function()
		if data.slowFx and data.slowUntil and os.clock() >= data.slowUntil - 0.05 then data.slowFx.Enabled = false end
	end)
end

function EnemyService:_kill(data, killerUserId, silent)
	if data.dead then return end
	data.dead = true
	releaseSlot(data)
	releasePlayer(data)
	byModel[data.model] = nil
	local idx = table.find(enemies, data)
	if idx then table.remove(enemies, idx) end
	if data.telegraph then data.telegraph:Destroy() end
	if not silent then
		poof(data.body.Position, data.illusion and Color3.fromRGB(150, 170, 255) or nil, data.size * 0.5)
	end
	if not data.illusion and not silent then
		local coins = math.floor((Cfg.Moedas.Base + Cfg.Moedas.PorWave * waveNumber()) * Economy:CoopMultiplier() + 0.5)
		local killer = killerUserId and Players:GetPlayerByUserId(killerUserId)
		local remotes = Shared:FindFirstChild("Remotes")
		if killer then
			-- pesquisa "Moedas" da Curiosity: bonus por abate
			local kc = math.floor(coins * (1 + (killer:GetAttribute("BonusPesquisaMoedas") or 0)) + 0.5)
			Economy:Add(killer, kc)
			if remotes then remotes.Dinheiro:FireClient(killer, data.body.Position, kc) end
		else
			local all = {}
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl:GetAttribute("EmJogo") == true then table.insert(all, pl) end
			end
			local each = math.max(1, math.floor(coins / math.max(1, #all) + 0.5))
			for _, pl in ipairs(all) do
				Economy:Add(pl, each)
				if remotes then remotes.Dinheiro:FireClient(pl, data.body.Position, each) end
			end
		end
		for _, cb in ipairs(self.OnDied) do task.spawn(cb, data, killerUserId) end
	end
	for _, child in ipairs(data.children) do
		if not child.dead then self:_kill(child, nil, false) end
	end
	if silent then
		data.model:Destroy()
		return
	end
	-- o corpo sai da pasta de inimigos: o cliente lanca uma copia voando (estilo do video) e esconde este
	local killer = killerUserId and Players:GetPlayerByUserId(killerUserId)
	local kroot = killer and killer.Character and killer.Character:FindFirstChild("HumanoidRootPart")
	local push = kroot and flat(data.body.Position - kroot.Position) or -data.face
	if push.Magnitude < 0.1 then push = Vector3.new(0, 0, 1) end
	data.body.CanQuery = false
	if data.barGui then data.barGui.Enabled = false end
	data.model:SetAttribute("Empurrao", push.Unit)
	data.model:SetAttribute("Assassino", killerUserId or 0)
	data.model.Parent = deadFolder
	Debris:AddItem(data.model, 0.35)
end

function EnemyService:ClearAll()
	for i = #enemies, 1, -1 do
		self:_kill(enemies[i], nil, true)
	end
	slots = {}
	playerCounts = {}
end

-- ESPECIAIS -----------------------------------------------------------
local function spawnIllusions(self, data)
	data.madeIllusions = true
	local side = Vector3.new(-data.face.Z, 0, data.face.X)
	for i = 1, data.cfg.Ilusoes do
		local off = side * ((i % 2 == 0) and 5 or -5) * math.ceil(i / 2)
		local p = data.pos + off
		local y = groundAt(p.X, p.Z, data.pos.Y) or data.pos.Y
		local ill = self:Spawn(data.typeName, 1, { illusion = true, parent = data, position = Vector3.new(p.X, y, p.Z) })
		if ill then
			ill.hopT = data.hopT
			table.insert(data.children, ill)
			poof(Vector3.new(p.X, y + 2, p.Z), Color3.fromRGB(120, 140, 255), 2)
		end
	end
end

local function startCrush(self, data)
	local E = data.cfg.Esmagamento
	data.crushing = true
	data.nextCrush = os.clock() + E.Intervalo
	local ring = Instance.new("Part")
	ring.Name = "Telegrafia"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(data.pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder
	data.telegraph = ring
	TweenService:Create(ring, TweenInfo.new(E.Telegrafia, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, E.Raio * 2, E.Raio * 2) }):Play()
	task.delay(E.Telegrafia, function()
		if data.dead then return end
		data.crushing = false
		if data.telegraph then data.telegraph:Destroy(); data.telegraph = nil end
		local center = data.pos
		-- onda de choque
		local wave = Instance.new("Part")
		wave.Shape = Enum.PartType.Cylinder
		wave.Anchored = true; wave.CanCollide = false; wave.CanQuery = false; wave.CanTouch = false
		wave.Material = Enum.Material.Neon; wave.Color = Color3.fromRGB(255, 120, 60); wave.Transparency = 0.3
		wave.Size = Vector3.new(0.4, 2, 2)
		wave.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		wave.Parent = fxFolder
		TweenService:Create(wave, TweenInfo.new(0.35), { Size = Vector3.new(0.4, E.Raio * 2.2, E.Raio * 2.2), Transparency = 1 }):Play()
		Debris:AddItem(wave, 0.5)
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and (flat(root.Position - center)).Magnitude <= E.Raio then
				hum:TakeDamage(E.DanoJogador)
				local base = hum:GetAttribute("VelocidadeBase") or 16
				hum.WalkSpeed = 0
				hum:SetAttribute("AtordoadoAte", os.clock() + E.Atordoamento)
				task.delay(E.Atordoamento, function()
					if hum.Parent and (hum:GetAttribute("AtordoadoAte") or 0) <= os.clock() + 0.05 then
						hum.WalkSpeed = hum:GetAttribute("VelocidadeBase") or base
					end
				end)
			end
		end
		if (flat(Core.Position - center)).Magnitude <= E.Raio + 14 then
			Core:Damage(E.DanoNucleo)
		end
		if Build then
			for _, st in ipairs(CollectionService:GetTagged("Estrutura")) do
				local part = st.PrimaryPart
				if part and (flat(part.Position - center)).Magnitude <= E.Raio + 2 then Build:Damage(st, E.DanoEstrutura) end
			end
		end
	end)
end

-- RENDER --------------------------------------------------------------
function EnemyService:_render(data)
	local t = data.hopT
	local scaleY = lerpKeys(P.EscalaY, t)
	local h = 0
	if t >= P.InicioAr and t <= P.FimAr then
		local u = (t - P.InicioAr) / (P.FimAr - P.InicioAr)
		h = math.sin(u * math.pi) * (P.AlturaMax or 0.9) * data.size
	end
	local sy = data.size * scaleY
	local sxz = data.size * (1 + (1 - scaleY) * 0.25)
	data.body.Size = Vector3.new(sxz, sy, sxz)
	local center = data.pos + Vector3.new(0, sy / 2 + h, 0)
	data.body.CFrame = CFrame.lookAt(center, center + data.face)
	if data.illusion == false and data.typeName == "Falsity" then
		-- sinal sutil do Falsity real: olhos "glitchando"
		local decal = data.body:FindFirstChildOfClass("Decal")
		if decal then decal.Transparency = (math.random() < 0.08) and 0.6 or 0 end
	end
end

-- IA ------------------------------------------------------------------
local function nearestPlayerDist(pos, plist)
	local best = math.huge
	for _, p in ipairs(plist) do
		local d = (p.root.Position - pos).Magnitude
		if d < best then best = d end
	end
	return best
end

function EnemyService:_think(data, dt, plist, now)
	local t = data.cfg
	local inSmoke = Class and Class:InSmoke(data.pos)
	data.decoy = nil
	-- a Isca rouba o alvo de quem esta no raio de atracao
	local decoyNear = (not data.illusion) and Ally and Ally:NearestDecoy(data.pos) or nil
	if decoyNear and data.player then releasePlayer(data) end
	-- alvo jogador
	if data.player then
		local entry
		for _, p in ipairs(plist) do if p.player == data.player then entry = p break end end
		if not entry or inSmoke or entry.player:GetAttribute("Oculto") or (flat(entry.root.Position - data.pos)).Magnitude > IA.Leash then
			releasePlayer(data)
		else
			data.playerRoot = entry.root
			data.playerHum = entry.hum
		end
	end
	if not data.player and not data.illusion and not inSmoke and not decoyNear then
		for _, p in ipairs(plist) do
			if not p.player:GetAttribute("Oculto") and (playerCounts[p.player] or 0) < IA.MaxPorJogador and (flat(p.root.Position - data.pos)).Magnitude <= IA.Aggro then
				data.player = p.player
				data.playerRoot = p.root
				data.playerHum = p.hum
				playerCounts[p.player] = (playerCounts[p.player] or 0) + 1
				releaseSlot(data)
				break
			end
		end
	end

	-- destino
	local goal, attackReady = nil, false
	if data.player and data.playerRoot then
		goal = flat(data.playerRoot.Position) + Vector3.new(0, data.pos.Y, 0)
		local d = (flat(data.playerRoot.Position - data.pos)).Magnitude
		attackReady = d <= IA.AlcanceAtaque + data.size / 2
	else
		local decoy = Ally and Ally:NearestDecoy(data.pos)
		if decoy then
			data.decoy = decoy
			releaseSlot(data)
			goal = Vector3.new(decoy.ground.X, data.pos.Y, decoy.ground.Z)
			attackReady = (flat(goal - data.pos)).Magnitude <= IA.AlcanceAtaque + data.size / 2 + 1
		elseif reserveSlot(data) then
			goal = slotPosition(data.slot)
			attackReady = (flat(goal - data.pos)).Magnitude <= 2.5
		else
			local rel = flat(data.pos - Core.Position)
			if rel.Magnitude < 1 then rel = Vector3.new(1, 0, 0) end
			goal = Core.Position + rel.Unit * IA.RaioEspera
		end
	end

	-- estrutura bloqueando: vira o alvo
	if data.blockedBy then
		if not (Build and Build:IsAlive(data.blockedBy)) then
			data.blockedBy = nil
		else
			attackReady = true
		end
	end

	-- especiais
	if data.typeName == "Falsity" and not data.illusion and not data.madeIllusions then
		if (flat(goal - data.pos)).Magnitude <= t.DistanciaIlusao then spawnIllusions(self, data) end
	end
	if data.typeName == "Cruelty" then
		if data.stacks > 0 and now - data.lastHit > t.TempoZerarAcumulo then data.stacks = 0 end
		if not data.crushing and now >= data.nextCrush and attackReady then startCrush(self, data) end
	end

	-- ataque
	if attackReady and not data.crushing and now - data.lastAttack >= t.Cooldown then
		data.lastAttack = now
		local dmg = data.illusion and 0 or t.Dano
		if data.typeName == "Cruelty" then dmg = dmg * (1 + t.AcumuloPorGolpe * data.stacks) end
		if dmg > 0 then
			if data.blockedBy and Build then
				Build:Damage(data.blockedBy, dmg)
			elseif data.player and data.playerHum then
				data.playerHum:TakeDamage(dmg * (IA.MultDanoJogador or 1))
			elseif data.decoy then
				Ally:DamageDecoy(data.decoy, dmg)
			else
				Core:Damage(dmg * (IA.MultDanoNucleo or 1))
			end
			if data.typeName == "Cruelty" then
				data.stacks = math.min(t.MaxAcumulos, data.stacks + 1)
				data.lastHit = now
			end
		end
	end

	-- direcao
	local to = flat(goal - data.pos)
	if data.blockedBy then
		local bp = data.blockedBy.PrimaryPart
		if bp then
			local f = flat(bp.Position - data.pos)
			if f.Magnitude > 0.1 then data.face = f.Unit end
		end
		data.moveDir = nil
	elseif to.Magnitude > 1.5 and not data.crushing then
		data.moveDir = to.Unit
		data.face = to.Unit
	else
		data.moveDir = nil
		if data.player and data.playerRoot then
			local f = flat(data.playerRoot.Position - data.pos)
			if f.Magnitude > 0.1 then data.face = f.Unit end
		else
			local f = flat(Core.Position - data.pos)
			if f.Magnitude > 0.1 then data.face = f.Unit end
		end
	end
end

function EnemyService:_move(data, dt)
	local prevT = data.hopT
	data.hopT = (data.hopT + dt) % P.Duracao
	if data.moveDir then
		local airT = 0
		-- tempo no ar dentro deste passo (aproximado)
		if data.hopT >= P.InicioAr and data.hopT <= P.FimAr then airT = dt end
		if airT > 0 then
			local slow = (data.slowUntil and os.clock() < data.slowUntil) and data.slowFactor or 1
			local speed = data.cfg.Velocidade * data.speedMult * slow * (P.Duracao / (P.FimAr - P.InicioAr))
			local np = data.pos + data.moveDir * speed * airT
			-- estrutura no caminho: para e ataca
			local obst = workspace:Raycast(data.pos + Vector3.new(0, data.size * 0.5, 0), data.moveDir * (data.size * 0.5 + speed * airT + 0.6), obstacleParams)
			local blocker = obst and Build and Build:ModelFromPart(obst.Instance)
			if blocker then
				data.blockedBy = blocker
				data.stuckT = 0
				data.progressPos = data.pos
				return
			end
			data.blockedBy = nil
			local y = groundAt(np.X, np.Z, data.pos.Y)
			if y and y - data.pos.Y <= IA.DegrauMax then
				data.pos = Vector3.new(np.X, y, np.Z)
			end
		end
		-- deteccao de travamento
		data.stuckT += dt
		if data.stuckT >= IA.PresoTempo then
			if (flat(data.pos - data.progressPos)).Magnitude < 1 then
				local np = data.pos + data.moveDir * 6
				local y = groundAt(np.X, np.Z, data.pos.Y + 8)
				if y then data.pos = Vector3.new(np.X, y, np.Z) end
			end
			data.stuckT = 0
			data.progressPos = data.pos
		end
	else
		data.stuckT = 0
		data.progressPos = data.pos
	end
end

-- separacao: empurra inimigos sobrepostos para os lados (evita empilhar)
local function separate(dt)
	local n = #enemies
	for i = 1, n do
		local a = enemies[i]
		for j = i + 1, n do
			local b = enemies[j]
			local dx, dz = a.pos.X - b.pos.X, a.pos.Z - b.pos.Z
			local minD = (a.size + b.size) * 0.45
			local d2 = dx * dx + dz * dz
			if d2 < minD * minD then
				local d = math.sqrt(d2)
				local nx, nz
				if d < 1e-3 then
					local ang = rng:NextNumber(0, math.pi * 2)
					nx, nz, d = math.cos(ang), math.sin(ang), 0
				else
					nx, nz = dx / d, dz / d
				end
				local push = math.min((minD - d) * 0.5, 12 * dt)
				local aFixed = a.slot ~= nil and not a.moveDir
				local bFixed = b.slot ~= nil and not b.moveDir
				if not aFixed then a.pos = a.pos + Vector3.new(nx * push, 0, nz * push) end
				if not bFixed then b.pos = b.pos - Vector3.new(nx * push, 0, nz * push) end
			end
		end
	end
end

-- troca o rosto (Decal da frente) dos modelos de inimigo pelos IDs de Config/Rostos
local function applyFaces()
	local ok, R = pcall(require, Shared.Config:FindFirstChild("Rostos"))
	local templates = game:GetService("ServerStorage"):FindFirstChild("Inimigos")
	if not ok or type(R) ~= "table" or not templates then return end
	for modelName, who in pairs(R.Modelos or {}) do
		local id = tonumber(R[who]) or 0
		local m = templates:FindFirstChild(modelName)
		if id > 0 and m then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("Decal") and d.Face == Enum.NormalId.Front then d.Texture = "rbxassetid://" .. id end
			end
		end
	end
end

function EnemyService:Init()
	applyFaces()
	Core = require(script.Parent.CoreService)
	Economy = require(script.Parent.EconomyService)
	Build = require(script.Parent.BuildService)
	Ally = require(script.Parent.AllyService)
	Class = require(script.Parent.ClassService)
	estado = Shared:WaitForChild("EstadoJogo")
	folder = workspace:FindFirstChild("InimigosAtivos")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InimigosAtivos"
		folder.Parent = workspace
	end
	fxFolder = workspace:FindFirstChild("Efeitos")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "Efeitos"
		fxFolder.Parent = workspace
	end
	deadFolder = workspace:FindFirstChild("InimigosMortos")
	if not deadFolder then
		deadFolder = Instance.new("Folder")
		deadFolder.Name = "InimigosMortos"
		deadFolder.Parent = workspace
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	refreshFilter()
	obstacleParams.FilterType = Enum.RaycastFilterType.Include
	obstacleParams.RespectCanCollide = true
	task.defer(function()
		obstacleParams.FilterDescendantsInstances = { workspace:WaitForChild("Estruturas") }
	end)
	Players.PlayerRemoving:Connect(function(pl) playerCounts[pl] = nil end)
end

function EnemyService:Folder() return folder end

function EnemyService:Start()
	-- Scheduler unico de IA
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if now - lastFilterRefresh > 1 then
			lastFilterRefresh = now
			refreshFilter()
			for i in pairs(sectorHeat) do sectorHeat[i] = sectorHeat[i] * 0.9 end
		end
		local plist = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and pl:GetAttribute("EmJogo") == true then
				table.insert(plist, { player = pl, root = root, hum = hum })
			end
		end
		separate(dt)
		estado:SetAttribute("InimigosVivos", self:CountAlive())
		for i = #enemies, 1, -1 do
			local data = enemies[i]
			if data and not data.dead then
				data.acc += dt
				local far = nearestPlayerDist(data.pos, plist) > IA.DistanciaPerto
				if not far or data.acc >= IA.IntervaloLonge then
					local step = math.min(data.acc, 0.25)
					data.acc = 0
					if data.stunUntil and now < data.stunUntil then
						data.hopT = (data.hopT + step * 0.3) % P.Duracao
					else
						self:_think(data, step, plist, now)
						self:_move(data, step)
					end
					if not data.dead then self:_render(data) end
				end
			end
		end
	end)
	log("Pronto. Max vivos: " .. Cfg.MaxVivos)
end

return EnemyService
