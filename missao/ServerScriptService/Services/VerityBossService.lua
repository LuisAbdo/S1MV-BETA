-- [VerityBossService] O Verity da noite: toda noite escolhe UM jogador que esteja longe do Nucleo,
-- nasce na floresta atras dele e o persegue pulando (mesma animacao dos veritys, so que gigante).
-- Cada aterrissagem treme o chao. Se o alvo chega perto do Nucleo, o boss se assusta e some.
-- Ao amanhecer ele tambem vai embora. So existe um por noite.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia).Boss
local EnemyCfg = require(Shared.Config.Enemies)
local SONS = require(Shared.Config.Sons)

local VerityBossService = {}
local remotes, estado, Core, Chunk
local folder
local boss = nil          -- estado do boss ativo
local spawnedThisNight = false
local nightStart = 0
local rng = Random.new()
local P = EnemyCfg.Pulo

local function log(...) print("[VerityBoss]", ...) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshFilter()
	local list = { folder }
	for _, n in ipairs({ "InimigosAtivos", "InimigosMortos", "Efeitos", "Recursos", "ItensChao", "Moedas", "Estruturas", "NevoaLimite", "Aliados" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	rayParams.FilterDescendantsInstances = list
end
local function groundAt(x, z, fromY)
	local hit = workspace:Raycast(Vector3.new(x, fromY + 30, z), Vector3.new(0, -90, 0), rayParams)
	return hit and hit.Position.Y or nil
end

local function charOf(player)
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return char, root, hum end
end

local function coreDist(pos) return (flat(pos - Core.Position)).Magnitude end

-- MODELO ----------------------------------------------------------------------------------
local function buildBody()
	local tmpl = ServerStorage:FindFirstChild("VerityBoss")
	local body
	if tmpl then
		body = tmpl:Clone()
		for _, d in ipairs(body:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then d:Destroy() end
		end
	else
		body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Color = Color3.fromRGB(255, 255, 0)
	end
	body.Name = "Corpo"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = true
	body.Size = Vector3.one * Cfg.Tamanho
	-- luz vermelha pulsando + nevoa escura em volta (bem mais amedrontador que os normais)
	local light = body:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 30
	light.Brightness = 3
	light.Shadows = false
	light.Parent = body
	local att = Instance.new("Attachment")
	att.Name = "Aura"
	att.Position = Vector3.new(0, -Cfg.Tamanho * 0.35, 0)
	att.Parent = body
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(20, 8, 12), Color3.fromRGB(60, 10, 15))
	e.LightInfluence = 0.2
	e.Size = NumberSequence.new(5, 11)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.4, 2.4)
	e.Rate = 14
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Parent = att
	-- som ambiente baixinho (so ouve quem esta perto)
	local amb = Instance.new("Sound")
	amb.Name = "Ambiente"
	amb.SoundId = SONS.BossAmbiente.Id
	amb.Volume = SONS.BossAmbiente.V or 0.35
	amb.Looped = true
	amb.RollOffMode = Enum.RollOffMode.Linear
	amb.RollOffMinDistance = 8
	amb.RollOffMaxDistance = 75
	amb.Parent = body
	amb:Play()
	return body
end

-- CICLO -----------------------------------------------------------------------------------
local function despawn(reason)
	local b = boss
	if not b then return end
	boss = nil
	if b.target then b.target:SetAttribute("CacadoPeloBoss", false) end
	remotes.Efeito:FireAllClients("BossSome", b.body.Position, Cfg.Tamanho, reason)
	log("some (" .. reason .. ")")
	local amb = b.body:FindFirstChild("Ambiente")
	if amb then TweenService:Create(amb, TweenInfo.new(0.8), { Volume = 0 }):Play() end
	if reason == "susto" then
		-- reacao de susto: treme, encolhe de surpresa, da um pulinho para tras e some
		local start = os.clock()
		local base = b.body.CFrame
		local back = flat(b.body.Position - Core.Position)
		back = back.Magnitude > 0.1 and back.Unit or Vector3.new(1, 0, 0)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - start
			if not b.body.Parent then conn:Disconnect() return end
			if t < 0.6 then
				local j = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 0.6
				b.body.CFrame = base + j
				b.body.Size = Vector3.new(Cfg.Tamanho * 0.9, Cfg.Tamanho * 1.15, Cfg.Tamanho * 0.9)
			else
				local u = math.clamp((t - 0.6) / 0.7, 0, 1)
				local hop = math.sin(u * math.pi) * 8
				b.body.CFrame = base + back * u * 14 + Vector3.new(0, hop, 0)
				b.body.Size = Vector3.one * Cfg.Tamanho * (1 - u * 0.95)
				b.body.Transparency = u
				if u >= 1 then conn:Disconnect(); b.body:Destroy() end
			end
		end)
	else
		TweenService:Create(b.body, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.5, Transparency = 1, CFrame = b.body.CFrame - Vector3.new(0, Cfg.Tamanho / 2, 0) }):Play()
		task.delay(1.3, function() b.body:Destroy() end)
	end
end

local function trySpawn(debug)
	-- quem esta longe do Nucleo?
	local cands = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local _, root = charOf(pl)
		if root and pl:GetAttribute("EmJogo") == true and coreDist(root.Position) >= Cfg.DistanciaMinima then
			table.insert(cands, { pl, root })
		end
	end
	if #cands == 0 then return false end
	local pick = cands[rng:NextInteger(1, #cands)]
	local player, root = pick[1], pick[2]
	refreshFilter()
	-- nasce mais para dentro da floresta, atras do jogador
	local out = flat(root.Position - Core.Position).Unit
	local pos
	for _ = 1, 14 do
		local ang = math.atan2(out.Z, out.X) + math.rad(rng:NextNumber(-70, 70))
		local d = rng:NextNumber(Cfg.DistanciaSpawn[1], Cfg.DistanciaSpawn[2])
		local p = root.Position + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
		if Chunk:InLimit(p) and coreDist(p) > coreDist(root.Position) - 10 then
			local y = groundAt(p.X, p.Z, root.Position.Y)
			if y then pos = Vector3.new(p.X, y, p.Z) break end
		end
	end
	if not pos then return false end
	local body = buildBody()
	body.CFrame = CFrame.new(pos - Vector3.new(0, Cfg.Tamanho, 0))
	body.Parent = folder
	boss = {
		body = body, target = player, pos = pos, hopT = 0, face = flat(root.Position - pos).Unit,
		lastAttack = 0, emerging = os.clock(), lastLand = 0, debug = debug == true,
	}
	player:SetAttribute("CacadoPeloBoss", true)
	local snd = SONS.BossSpawn[rng:NextInteger(1, #SONS.BossSpawn)]
	remotes.Efeito:FireAllClients("BossSurge", pos, Cfg.Tamanho, player, snd.Id)
	log("apareceu para " .. player.Name .. " a " .. math.floor((pos - root.Position).Magnitude) .. " studs")
	return true
end

local SURGIR = 1.6
local DUR = P.Duracao * 1.5     -- pulos mais lentos e pesados
local AR0, AR1 = P.InicioAr * 1.5, P.FimAr * 1.5

local function step(dt)
	local b = boss
	if not b then return end
	local _, root, hum = charOf(b.target)
	if not root or not b.target.Parent then despawn("perdeu o alvo") return end
	if not b.debug and estado:GetAttribute("Fase") ~= "Noite" then despawn("amanheceu") return end
	local dTarget = (flat(root.Position - b.pos)).Magnitude
	if coreDist(root.Position) <= Cfg.RaioSeguro then despawn("susto") return end
	if dTarget > Cfg.DesisteEm then despawn("desistiu") return end
	-- saindo do chao
	local emergeT = os.clock() - b.emerging
	if emergeT < SURGIR then
		local u = emergeT / SURGIR
		local e = 1 - (1 - u) ^ 3
		b.body.Size = Vector3.one * Cfg.Tamanho
		local shake = Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) * (1 - u)
		b.body.CFrame = CFrame.lookAt(b.pos + Vector3.new(0, -Cfg.Tamanho + e * (Cfg.Tamanho * 1.5), 0) + shake, b.pos + Vector3.new(0, Cfg.Tamanho / 2, 0) + b.face)
		return
	end
	-- pulo (mesmas chaves de animacao dos veritys comuns)
	local prevT = b.hopT
	b.hopT = (b.hopT + dt) % DUR
	local t = b.hopT / 1.5
	local dir = flat(root.Position - b.pos)
	if dir.Magnitude > 0.1 then b.face = dir.Unit end
	local reach = Cfg.AlcanceAtaque + Cfg.Tamanho / 2
	if b.hopT >= AR0 and b.hopT <= AR1 and dTarget > reach * 0.7 then
		local speed = Cfg.Velocidade * (DUR / (AR1 - AR0))
		local np = b.pos + b.face * math.min(speed * dt, dTarget)
		local y = groundAt(np.X, np.Z, b.pos.Y)
		if y and y - b.pos.Y < 12 then b.pos = Vector3.new(np.X, y, np.Z) end
	end
	-- aterrissou: tremor e som de "pe-grande"
	if prevT < AR1 and b.hopT >= AR1 then
		remotes.Efeito:FireAllClients("BossPulo", b.pos, Cfg.Tamanho, Cfg.TremorRaio)
	end
	-- ataque
	local now = os.clock()
	if dTarget <= reach and now - b.lastAttack >= Cfg.CooldownAtaque then
		b.lastAttack = now
		hum:TakeDamage(Cfg.Dano)
		local push = flat(root.Position - b.pos)
		push = push.Magnitude > 0.1 and push.Unit or b.face
		root.AssemblyLinearVelocity = push * 70 + Vector3.new(0, 35, 0)
		remotes.Efeito:FireAllClients("BossAtaque", b.target, root.Position)
	end
	-- desenho (squash/stretch igual ao dos veritys)
	local scaleY = lerpKeys(P.EscalaY, t)
	local h = 0
	if b.hopT >= AR0 and b.hopT <= AR1 then
		local u = (b.hopT - AR0) / (AR1 - AR0)
		h = math.sin(u * math.pi) * 0.55 * Cfg.Tamanho
	end
	local sy = Cfg.Tamanho * scaleY
	local sxz = Cfg.Tamanho * (1 + (1 - scaleY) * 0.25)
	b.body.Size = Vector3.new(sxz, sy, sxz)
	local center = b.pos + Vector3.new(0, sy / 2 + h, 0)
	b.body.CFrame = CFrame.lookAt(center, center + b.face)
	local light = b.body:FindFirstChildOfClass("PointLight")
	if light then light.Brightness = 2.5 + math.sin(os.clock() * 6) * 1.2 end
end

function VerityBossService:ResetRun()
	if boss then despawn("reset") end
	spawnedThisNight = false
end

function VerityBossService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Core = require(script.Parent.CoreService)
	Chunk = require(script.Parent.ChunkService)
	folder = workspace:FindFirstChild("VerityBoss") or Instance.new("Folder")
	folder.Name = "VerityBoss"
	folder.Parent = workspace
end

function VerityBossService:Start()
	estado:GetAttributeChangedSignal("Fase"):Connect(function()
		if estado:GetAttribute("Fase") == "Noite" then
			spawnedThisNight = false
			nightStart = os.clock()
		end
	end)
	local acc, filterAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if boss then
			filterAcc += dt
			if filterAcc > 2 then filterAcc = 0; refreshFilter() end
			step(dt)
			return
		end
		if estado:GetAttribute("Fase") ~= "Noite" or spawnedThisNight then return end
		if os.clock() - nightStart < Cfg.AtrasoNoite then return end
		acc += dt
		if acc < Cfg.Checagem then return end
		acc = 0
		if trySpawn() then spawnedThisNight = true end
	end)
	-- comando de teste no Studio: /boss
	local function onChat(pl, msg)
		if RunService:IsStudio() and typeof(msg) == "string" and msg:lower() == "/boss" and not boss then
			if not trySpawn(true) then
				remotes.Aviso:FireClient(pl, "Boss: vá para mais de " .. Cfg.DistanciaMinima .. " studs do Núcleo")
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do p.Chatted:Connect(function(m) onChat(p, m) end) end
	Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(m) onChat(p, m) end) end)
	pcall(function()
		local cmds = game:GetService("TextChatService"):FindFirstChild("TextChatCommands")
		local c = Instance.new("TextChatCommand")
		c.Name = "ComandoBoss"
		c.PrimaryAlias = "/boss"
		c.Parent = cmds
		c.Triggered:Connect(function(src)
			local pl = Players:GetPlayerByUserId(src.UserId)
			if pl then onChat(pl, "/boss") end
		end)
	end)
	VerityBossService.DebugSpawn = trySpawn
	log("Pronto")
end

return VerityBossService
