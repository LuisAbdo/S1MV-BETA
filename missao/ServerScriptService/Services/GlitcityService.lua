-- [GlitcityService] Primeiro chefe: GLITCITY (noite 15).
-- Na virada do dia 15 para a noite: o ceu pisca entre dia e noite, a tela corrompe, a camera
-- vai para a floresta, blocos neon sobem do chao e o chefe se materializa (cutscene no cliente:
-- GlitcityCliente). Na luta: movimento travado (frame-skip, no EnemyService), pulsos EMP que
-- desligam as torres perto e barreiras de blocos voxel que seguram os tiros.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia).Glitcity

local GlitcityService = {}
local remotes, estado, Enemy, Core, Wave, Chunk
local boss = nil
local barreiras
local rng = Random.new()
local NEON = { Color3.fromRGB(255, 230, 40), Color3.fromRGB(255, 70, 200), Color3.fromRGB(60, 200, 255) }

local function log(...) print("[Glitcity]", ...) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- ponto de surgimento: perto do lado de spawn, mas no trecho com MENOS arvores em volta
-- (assim a cutscene nao fica escondida atras da vegetacao)
local function treesNear(p, radius)
	local n = 0
	for _, m in ipairs(CollectionService:GetTagged("Recurso")) do
		if m:IsA("Model") and m:GetAttribute("Recurso") ~= "Rocha" then
			local pp = m.PrimaryPart
			if pp and flat(pp.Position - p).Magnitude < radius then n += 1 end
		end
	end
	return n
end

local function spawnPoint()
	local baseAng = rng:NextNumber(0, math.pi * 2)
	local p1 = estado:GetAttribute("SpawnPos1")
	if typeof(p1) == "Vector3" then
		local d = flat(p1 - Core.Position)
		if d.Magnitude > 1 then baseAng = math.atan2(d.Z, d.X) end
	end
	local best, bestScore = nil, math.huge
	for i = 0, 23 do
		local ang = baseAng + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * (math.pi / 12)
		for _, r in ipairs({ Cfg.DistanciaSurgir, Cfg.DistanciaSurgir * 0.8, Cfg.DistanciaSurgir * 1.2 }) do
			local x, z = Core.Position.X + math.cos(ang) * r, Core.Position.Z + math.sin(ang) * r
			local p = Vector3.new(x, Chunk:HeightAt(x, z), z)
			-- arvores perto contam muito; desviar do lado de spawn conta pouco
			local score = treesNear(p, Cfg.RaioLivre or 22) * 10 + math.ceil(i / 2) * 0.3
			if score < bestScore then best, bestScore = p, score end
		end
	end
	return best
end

local function bossData()
	if not boss or not boss.model.Parent then return nil end
	return boss
end

-- CUTSCENE + SURGIMENTO -----------------------------------------------------------------------
function GlitcityService:Summon(isAlive)
	if bossData() then return end
	local pos = spawnPoint()
	local T = Cfg.Cutscene
	remotes.Efeito:FireAllClients("GlitcityCutscene", pos, T)
	log("cutscene em " .. tostring(pos))
	-- espera ate o momento da materializacao
	task.wait(T.Glitch + T.Camera + T.Blocos)
	if isAlive and not isAlive() then return end
	local data = Enemy:Spawn("Glitcity", 1, { position = pos })
	local model = data and data.model
	if not model then warn("[Glitcity] nao conseguiu criar o chefe") return end
	CollectionService:AddTag(model, "Chefe")
	model:SetAttribute("Chefe", "GLITCITY")
	-- sem o modelo proprio ainda: pinta o corpo provisorio com cara de glitch
	local body = model:FindFirstChild("Corpo")
	local SS = game:GetService("ServerStorage")
	if body and not (SS:FindFirstChild("Glitchity") or SS:FindFirstChild("Glitcity")) then
		body.Color = Color3.fromRGB(150, 60, 255)
		body.Material = Enum.Material.Neon
	end
	boss = { model = model, nextEmp = os.clock() + Cfg.EMP.Intervalo * 0.6, nextWall = os.clock() + 3, nextTrail = 0 }
	estado:SetAttribute("ChefeAtivo", "GLITCITY")
	-- o resto da cutscene (texto [WARNING], camera voltando) roda no cliente
	task.wait(T.Texto)
end

-- PODERES -----------------------------------------------------------------------------------
local function emp(pos)
	local untilT = workspace:GetServerTimeNow() + Cfg.EMP.Duracao
	local n = 0
	for _, st in ipairs(CollectionService:GetTagged("Estrutura")) do
		local pp = st.PrimaryPart
		if pp and flat(pp.Position - pos).Magnitude <= Cfg.EMP.Raio then
			st:SetAttribute("EMPAte", untilT)
			n += 1
		end
	end
	remotes.Efeito:FireAllClients("GlitchEMP", pos, Cfg.EMP.Raio, Cfg.EMP.Duracao)
end

local function voxelWall(pos)
	local V = Cfg.Voxels
	for i = 1, V.Quantidade do
		local a = (i / V.Quantidade) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = V.Raio + rng:NextNumber(-1, 1)
		local x, z = pos.X + math.cos(a) * r, pos.Z + math.sin(a) * r
		local y = Chunk:HeightAt(x, z)
		for k = 0, rng:NextInteger(0, 1) do
			local b = Instance.new("Part")
			b.Name = "Voxel"
			b.Anchored = true
			b.Size = Vector3.one * V.Tamanho
			b.Color = NEON[rng:NextInteger(1, #NEON)]
			b.Material = Enum.Material.Neon
			b.Transparency = 0.15
			b.CanCollide = true
			b.CanQuery = true     -- segura os tiros (raycast das armas para nele)
			b.CanTouch = false
			b.CFrame = CFrame.new(x, y - V.Tamanho, z) * CFrame.Angles(0, a, 0)
			b.Parent = barreiras
			TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = CFrame.new(x, y + V.Tamanho / 2 + k * V.Tamanho, z) * CFrame.Angles(0, a, 0) }):Play()
			task.delay(V.Duracao, function()
				if b.Parent then
					TweenService:Create(b, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.one * 0.5 }):Play()
					Debris:AddItem(b, 0.45)
				end
			end)
		end
	end
	remotes.Efeito:FireAllClients("GlitchVoxels", pos)
end

function GlitcityService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Enemy = require(script.Parent.EnemyService)
	Core = require(script.Parent.CoreService)
	Wave = require(script.Parent.WaveService)
	Chunk = require(script.Parent.ChunkService)
	barreiras = workspace:FindFirstChild("GlitchBarreiras") or Instance.new("Folder")
	barreiras.Name = "GlitchBarreiras"
	barreiras.Parent = workspace
end

function GlitcityService:Start()
	-- entra na transicao do dia 15 para a noite
	table.insert(Wave.AntesDaNoite, function(wave, isAlive)
		if wave == Cfg.Wave then self:Summon(isAlive) end
	end)
	-- a noite so acaba com o chefe morto (ele ja conta como inimigo vivo no EnemyService)
	table.insert(Enemy.OnDied, function(data)
		if boss and data and data.model == boss.model then
			boss = nil
			estado:SetAttribute("ChefeAtivo", nil)
			barreiras:ClearAllChildren()
			remotes.Aviso:FireAllClients("GLITCITY DERROTADO!")
			remotes.Efeito:FireAllClients("GlitcityMorreu", data.body and data.body.Position)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local b = bossData()
		if not b then
			if boss then boss = nil; estado:SetAttribute("ChefeAtivo", nil) end
			return
		end
		local body = b.model:FindFirstChild("Corpo")
		if not body then return end
		local now = os.clock()
		if now >= b.nextEmp then
			b.nextEmp = now + Cfg.EMP.Intervalo
			emp(body.Position)
		end
		if now >= b.nextWall then
			b.nextWall = now + Cfg.Voxels.Intervalo
			voxelWall(body.Position)
		end
		if now >= b.nextTrail then
			b.nextTrail = now + 0.5
			remotes.Efeito:FireAllClients("GlitchRastro", body.Position - Vector3.new(0, body.Size.Y / 2, 0))
		end
	end)
	-- teste no Studio: /glitcity
	local function onChat(pl, msg)
		if RunService:IsStudio() and typeof(msg) == "string" and msg:lower() == "/glitcity" then
			task.spawn(function() self:Summon() end)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do p.Chatted:Connect(function(m) onChat(p, m) end) end
	Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(m) onChat(p, m) end) end)
	pcall(function()
		local cmds = game:GetService("TextChatService"):FindFirstChild("TextChatCommands")
		local c = Instance.new("TextChatCommand")
		c.Name = "ComandoGlitcity"
		c.PrimaryAlias = "/glitcity"
		c.Parent = cmds
		c.Triggered:Connect(function(src)
			local pl = Players:GetPlayerByUserId(src.UserId)
			if pl then onChat(pl, "/glitcity") end
		end)
	end)
	log("Pronto (aparece na noite " .. Cfg.Wave .. ")")
end

return GlitcityService
