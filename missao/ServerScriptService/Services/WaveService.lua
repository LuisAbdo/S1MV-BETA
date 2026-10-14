-- [WaveService] Ciclo DIA (preparacao) -> NOITE (combate), orcamento de inimigos,
-- bonus de fim de wave, checkpoint a cada 10 waves, derrota e recomeco.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Waves)
local EnemyCfg = require(Shared.Config.Enemies)
local LobbyCfg = require(Shared.Config.Lobby)

local WaveService = {}
local estado, remotes
local Core, Enemy, Economy, Weapon, Area, Build, Ally, Class, Lobby
local wave = 0
local phase = "Aguardando"
local votes = {}
local runId = 0
local kills = 0
local checkpoint = nil
local plans = {}   -- wave -> lista de inimigos (a Previsao da Curiosity le daqui)
local rng = Random.new()

local function log(...) print("[WaveService]", ...) end

local function setPhase(p, duration)
	phase = p
	estado:SetAttribute("Fase", p)
	estado:SetAttribute("FimFase", duration and (workspace:GetServerTimeNow() + duration) or 0)
end

local function tweenLight(kind)
	local L = Cfg.Luz[kind]
	local info = TweenInfo.new(Cfg.TransicaoLuz, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { ClockTime = L.ClockTime, Brightness = L.Brightness, OutdoorAmbient = L.OutdoorAmbient }):Play()
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then TweenService:Create(cc, info, { TintColor = L.Tint }):Play() end
end

-- so conta quem esta na missao (quem esta no Laboratorio fica de fora)
local function inGame()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("EmJogo") == true then table.insert(list, p) end
	end
	return list
end

local function votesNeeded()
	return math.max(1, math.ceil(#inGame() * Cfg.VotacaoPular))
end

local function countVotes()
	local n = 0
	for _, p in ipairs(inGame()) do
		if votes[p] or p:GetAttribute("AutoSkip") == true then n += 1 end
	end
	estado:SetAttribute("VotosPular", n)
	estado:SetAttribute("VotosNecessarios", votesNeeded())
	return n
end

local function budgetFor(w)
	local b = Cfg.OrcamentoBase + w * Cfg.OrcamentoPorWave + (Cfg.OrcamentoQuad or 0) * w ^ (Cfg.OrcamentoExpoente or 1)
	return b * (1 + Cfg.EscalaPorJogadorExtra * math.max(0, #inGame() - 1))
end

local function hpMultFor(w)
	if w <= 100 then return 1 + Cfg.VidaPorWave * (w - 1) end
	return (1 + Cfg.VidaPorWave * 99) + Cfg.VidaPorWaveInfinito * (w - 100)
end

local function pickType(w, remaining)
	local pool, total = {}, 0
	local weights = { Verity = 6, Falsity = 3, Cruelty = 1.6 }
	for name, t in pairs(EnemyCfg.Tipos) do
		if w >= (t.WaveMin or 1) and t.Custo <= remaining + 0.01 then
			local wt = weights[name] or 1
			table.insert(pool, { name, wt, t.Custo })
			total += wt
		end
	end
	if #pool == 0 then return nil end
	local r = rng:NextNumber(0, total)
	for _, e in ipairs(pool) do
		r -= e[2]
		if r <= 0 then return e[1], e[3] end
	end
	return pool[1][1], pool[1][3]
end

function WaveService:GetWave() return wave end
function WaveService:GetPhase() return phase end

-- Composicao da wave e sorteada uma vez e guardada: a Previsao mostra exatamente o que vem.
function WaveService:GetPlan(w)
	w = w or ((phase == "Dia" or phase == "Aguardando") and math.max(1, wave) or wave + 1)
	if not plans[w] then
		local list, budget = {}, budgetFor(w)
		while budget >= 1 - 0.01 do
			local name, cost = pickType(w, budget)
			if not name then break end
			table.insert(list, name)
			budget -= cost
		end
		plans[w] = list
	end
	return plans[w], w
end

local function runNight(myRun)
	setPhase("Noite")
	tweenLight("Noite")
	Core:BeginWave()
	votes = {}
	countVotes()
	local plan = WaveService:GetPlan(wave)
	plans[wave] = nil
	local idx = 1
	local function remaining()
		estado:SetAttribute("Restantes", Enemy:CountAlive() + math.max(0, #plan - idx + 1))
	end
	local hpMult = hpMultFor(wave)
	log(string.format("Wave %d: %d inimigos, vida x%.2f", wave, #plan, hpMult))
	remaining()
	task.wait(2)
	-- ritmo da wave: levas maiores e mais rapidas conforme a wave sobe
	local R = Cfg.Ritmo or {}
	local extra = math.floor((wave - 1) / (R.GrupoExtraACada or 1e9))
	local pace = math.max(R.IntervaloMinimoMult or 1, 1 - (R.IntervaloMenosPorWave or 0) * (wave - 1))
	while runId == myRun and idx <= #plan do
		local groupSize = rng:NextInteger(Cfg.Grupo.Min + extra, Cfg.Grupo.Max + extra * 2)
		-- cada inimigo nasce num ponto aleatorio; as vezes em dupla com o anterior
		local base = Enemy:PickSpawnPoint()
		for _ = 1, groupSize do
			if idx > #plan then break end
			while runId == myRun and Enemy:CountAll() >= EnemyCfg.MaxVivos do task.wait(0.5) end
			if runId ~= myRun then return end
			if rng:NextNumber() > (Cfg.ChanceAgrupar or 0) then base = Enemy:PickSpawnPoint() end
			local off = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			Enemy:Spawn(plan[idx], hpMult, { position = base + off })
			idx += 1
			remaining()
			task.wait(0.15)
		end
		if idx <= #plan then task.wait(rng:NextNumber(Cfg.IntervaloGrupos.Min, Cfg.IntervaloGrupos.Max) * pace) end
	end
	-- espera o ultimo inimigo cair (ou o time votar SKIP WAVE)
	while runId == myRun and Enemy:CountAlive() > 0 do
		remaining()
		if countVotes() >= votesNeeded() then
			return true
		end
		task.wait(0.25)
	end
	remaining()
	return false
end

-- LADOS DE SPAWN -----------------------------------------------------------------------
-- angulo no plano XZ (cos -> X, sin -> Z): Norte = -Z, Sul = +Z, Leste = +X, Oeste = -X
local ANGULO = { Norte = -math.pi / 2, Sul = math.pi / 2, Leste = 0, Oeste = math.pi }
local OPOSTO = { Norte = "Sul", Sul = "Norte", Leste = "Oeste", Oeste = "Leste" }
local runSide = "Norte"
local function sidePoint(name)
	local zona = workspace:FindFirstChild("Zona de spawn")
	local c = zona and zona.Position or Core.Position
	local hx = zona and zona.Size.X / 2 or 60
	local hz = zona and zona.Size.Z / 2 or 60
	local a = ANGULO[name]
	local reach = math.min(hx / math.max(math.abs(math.cos(a)), 1e-3), hz / math.max(math.abs(math.sin(a)), 1e-3))
	local r = reach * 0.72
	return Vector3.new(c.X + math.cos(a) * r, Core.Position.Y, c.Z + math.sin(a) * r)
end
local function applySides(w)
	local names = { runSide }
	if w > (Cfg.LadoUnicoAte or 10) then table.insert(names, OPOSTO[runSide]) end
	local angles = {}
	for _, n in ipairs(names) do table.insert(angles, ANGULO[n]) end
	Enemy:SetSpawnSides(angles, Cfg.AberturaLado or 38)
	estado:SetAttribute("SpawnLados", table.concat(names, ","))
	estado:SetAttribute("SpawnPos1", sidePoint(names[1]))
	estado:SetAttribute("SpawnPos2", names[2] and sidePoint(names[2]) or nil)
end
WaveService.ApplySides = applySides

local function runLoop(myRun)
	local skippedLast = false
	while runId == myRun do
		wave += 1
		applySides(wave)
		estado:SetAttribute("Wave", wave)
		Area:OnWaveReached(wave)
		votes = {}
		countVotes()
		local dayLen = (wave == 1) and Cfg.DiaPrimeiraWave or Cfg.DiaDuracao
		if skippedLast then dayLen = Cfg.DiaAposPular or 5 end
		local bossWave = math.ceil(wave / 10) * 10
		estado:SetAttribute("ProximoChefe", (Cfg.Chefes and Cfg.Chefes[bossWave]) or "CHEFE")
		estado:SetAttribute("ProximoChefeWave", bossWave)
		setPhase("Dia", dayLen)
		if not skippedLast then tweenLight("Dia") end
		local t0 = os.clock()
		while runId == myRun and os.clock() - t0 < dayLen do
			if countVotes() >= votesNeeded() then break end
			task.wait(0.25)
		end
		if runId ~= myRun then return end
		skippedLast = runNight(myRun)
		if runId ~= myRun then return end
		-- fim de wave
		local lost = Core:WaveLossRatio()
		local gems = LobbyCfg.GemasPorWave + ((wave % 10 == 0) and LobbyCfg.GemasChefe or 0)
		local bonus = (lost < Cfg.BonusFimWave.PerdaMaxima) and (Cfg.BonusFimWave.Base + Cfg.BonusFimWave.PorWave * wave) or 0
		for _, p in ipairs(inGame()) do
			if bonus > 0 then Economy:Add(p, bonus) end
			Lobby:AddGems(p, gems)
			remotes.Aviso:FireClient(p, "WAVE " .. wave .. " CONCLUÍDA!" .. (bonus > 0 and ("  +$" .. bonus) or "") .. "  +" .. (p:GetAttribute("GemasEmDobro") and gems * 2 or gems) .. " GEMAS")
		end
		if wave % Cfg.CheckpointACada == 0 then
			local coins, weapons = {}, {}
			for _, p in ipairs(Players:GetPlayers()) do
				coins[p.UserId] = Economy:Get(p)
				local st = Weapon:GetState(p)
				if st then weapons[p.UserId] = { tier = st.tier, levels = table.clone(st.levels) } end
			end
			checkpoint = { wave = wave + 1, coins = coins, weapons = weapons, coreTier = Core:GetTier(), areas = Area:GetState(), estruturas = Build:GetState() }
			estado:SetAttribute("Checkpoint", wave + 1)
			remotes.Aviso:FireAllClients("CHECKPOINT SALVO (wave " .. (wave + 1) .. ")")
			log("Checkpoint salvo na wave " .. (wave + 1))
		end
		if not skippedLast then task.wait(2) end
	end
end

function WaveService:StartRun(fromCheckpoint, startWave)
	runId += 1
	local myRun = runId
	Enemy:ClearAll()
	Economy:ClearOrbs()
	Area:ResetAll()
	Build:ClearAll()
	Ally:ClearAll()
	Class:ResetRun()
	kills = 0
	plans = {}
	local lados = Cfg.LadosPossiveis or { "Norte" }
	runSide = lados[rng:NextInteger(1, #lados)]
	log("Lado de spawn desta run: " .. runSide)
	local Revive = require(script.Parent.ReviveService)
	if Revive.ResetRun then Revive:ResetRun() end
	local cp = fromCheckpoint and checkpoint or nil
	if cp then
		Core:ResetForRun(cp.coreTier)
		Area:RestoreState(cp.areas)
		Build:RestoreState(cp.estruturas)
		for _, p in ipairs(Players:GetPlayers()) do
			Economy:Set(p, cp.coins[p.UserId] or 0)
			local w = cp.weapons[p.UserId]
			if w then Weapon:SetState(p, w.tier, w.levels) else Weapon:ResetPlayer(p) end
		end
		wave = cp.wave - 1
	else
		checkpoint = nil
		estado:SetAttribute("Checkpoint", 0)
		Core:ResetForRun(1)
		Weapon:ResetAll()
		for _, p in ipairs(inGame()) do Economy:Set(p, 0) end
		wave = math.max(0, (startWave or 1) - 1)
		if startWave and startWave > 1 then Area:OnWaveReached(startWave - 1) end
	end
	for _, p in ipairs(inGame()) do
		p:SetAttribute("GemasRun", 0)
		require(script.Parent.CharacterService):Respawn(p)
	end
	estado:SetAttribute("Abates", 0)
	log("Run iniciada" .. (cp and (" do checkpoint (wave " .. cp.wave .. ")") or ""))
	task.spawn(runLoop, myRun)
end

-- Todo mundo voltou ao Laboratorio: a ilha volta ao estado inicial e espera o proximo JOGAR
function WaveService:StopRun()
	runId += 1
	Enemy:ClearAll()
	Economy:ClearOrbs()
	Area:ResetAll()
	Build:ClearAll()
	Ally:ClearAll()
	Class:ResetRun()
	Core:ResetForRun(1)
	checkpoint = nil
	estado:SetAttribute("Checkpoint", 0)
	wave = 0
	kills = 0
	plans = {}
	votes = {}
	estado:SetAttribute("Wave", 0)
	estado:SetAttribute("Abates", 0)
	setPhase("Aguardando")
	tweenLight("Dia")
	log("Run encerrada (ilha vazia). Aguardando JOGAR no Laboratorio")
end

local function onDefeat()
	if phase == "Derrota" then return end
	runId += 1
	setPhase("Derrota")
	tweenLight("Noite")
	for _, p in ipairs(inGame()) do
		remotes.FimDeJogo:FireClient(p, { wave = wave, abates = kills, checkpoint = checkpoint and checkpoint.wave or nil, gemas = p:GetAttribute("GemasRun") or 0 })
	end
	log("Derrota na wave " .. wave)
	task.delay(2, function()
		if phase == "Derrota" then Enemy:ClearAll() end
	end)
end

function WaveService:Init()
	estado = Shared:WaitForChild("EstadoJogo")
	remotes = Shared:WaitForChild("Remotes")
	Core = require(script.Parent.CoreService)
	Enemy = require(script.Parent.EnemyService)
	Economy = require(script.Parent.EconomyService)
	Weapon = require(script.Parent.WeaponService)
	Area = require(script.Parent.AreaService)
	Build = require(script.Parent.BuildService)
	Ally = require(script.Parent.AllyService)
	Class = require(script.Parent.ClassService)
	Lobby = require(script.Parent.LobbyService)
	setPhase("Aguardando")
	estado:SetAttribute("Wave", 0)
	estado:SetAttribute("Abates", 0)
end

function WaveService:Start()
	table.insert(Core.OnDestroyed, onDefeat)
	table.insert(Enemy.OnDied, function()
		kills += 1
		estado:SetAttribute("Abates", kills)
	end)
	remotes.AutoSkip.OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" then return end
		player:SetAttribute("AutoSkip", on)
		countVotes()
	end)
	remotes.VotarPular.OnServerEvent:Connect(function(player)
		if phase ~= "Dia" and phase ~= "Noite" then return end
		votes[player] = true
		countVotes()
	end)
	remotes.Reiniciar.OnServerEvent:Connect(function(player, mode)
		if phase ~= "Derrota" or player:GetAttribute("EmJogo") ~= true then return end
		self:StartRun(mode == "checkpoint" and checkpoint ~= nil)
	end)
	Players.PlayerRemoving:Connect(function(p) votes[p] = nil end)
	-- comandos de debug (Studio): /spawn N [tipo]  |  /wave N
	local RunService = game:GetService("RunService")
	local TextChatService = game:GetService("TextChatService")
	local recent = {}
	local function onCmd(player, msg)
		if not RunService:IsStudio() or typeof(msg) ~= "string" then return end
		local key = player.UserId .. msg
		if recent[key] and os.clock() - recent[key] < 1 then return end
		recent[key] = os.clock()
		local cmd, a, b = string.match(string.lower(msg), "^/(%a+)%s*(%d*)%s*(%a*)")
		if cmd == "spawn" then
			local n = math.clamp(tonumber(a) or 10, 1, 60)
			local tipos = { verity = "Verity", falsity = "Falsity", cruelty = "Cruelty" }
			local tipo = tipos[b] or "Verity"
			for _ = 1, n do Enemy:Spawn(tipo, 1) end
			log("debug: " .. n .. "x " .. tipo)
		elseif cmd == "moedas" then
			Economy:Add(player, tonumber(a) or 1000)
		elseif cmd == "tier" then
			Core:ResetForRun(math.clamp(tonumber(a) or 1, 1, 10))
		elseif cmd == "derrota" then
			Core:Damage(1e9)
		elseif cmd == "matar" then
			for _, m in ipairs(Enemy:Folder():GetChildren()) do Enemy:Damage(m, 1e7, player) end
		elseif cmd == "wave" then
			local n = math.clamp(tonumber(a) or 1, 1, 200)
			log("debug: pulando para a wave " .. n)
			self:StartRun(false, n)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do p.Chatted:Connect(function(m) onCmd(p, m) end) end
	Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(m) onCmd(p, m) end) end)
	pcall(function()
		local cmds = TextChatService:FindFirstChild("TextChatCommands")
		for _, alias in ipairs({ "/spawn", "/wave", "/matar", "/derrota", "/moedas", "/tier" }) do
			local c = Instance.new("TextChatCommand")
			c.Name = "Comando" .. alias:sub(2)
			c.PrimaryAlias = alias
			c.Parent = cmds
			c.Triggered:Connect(function(src, text)
				local pl = Players:GetPlayerByUserId(src.UserId)
				if pl then onCmd(pl, text) end
			end)
		end
	end)

	-- a run comeca quando o grupo que veio do Main Lobby chega (LobbyService -> StartRun)
	tweenLight("Dia")
	log("Pronto (aguardando o grupo do Main Lobby)")
end

return WaveService
