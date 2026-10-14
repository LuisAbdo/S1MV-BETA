-- SonsJogo: trilha ambiente (dia/noite), sons de eventos da partida e passos do personagem.
-- Tudo com sons do Config.Sons (nada dos sons classicos do Roblox).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SONS = require(Shared:WaitForChild("Config"):WaitForChild("Sons"))
local estado = Shared:WaitForChild("EstadoJogo")
local remotes = Shared:WaitForChild("Remotes")

local pasta = Instance.new("Folder")
pasta.Name = "SonsJogo"
pasta.Parent = SoundService

local function mk(def, props)
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.V or 0.5
	s.PlaybackSpeed = def.P or 1
	for k, v in pairs(props or {}) do s[k] = v end
	s.Parent = pasta
	return s
end

-- toca uma copia (permite sobrepor)
local function play(def, vol, pitch)
	local s = mk(def)
	if vol then s.Volume = vol end
	if pitch then s.PlaybackSpeed = pitch end
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(12, function() if s.Parent then s:Destroy() end end)
	return s
end

-- AMBIENTE ------------------------------------------------------------------------------
local ambDia = mk(SONS.AmbienteDia, { Looped = true, Volume = 0, Name = "AmbienteDia" })
local ambNoite = mk(SONS.AmbienteNoite, { Looped = true, Volume = 0, Name = "AmbienteNoite" })
ambDia:Play(); ambNoite:Play()

local function fade(s, v)
	TweenService:Create(s, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { Volume = v }):Play()
end

local function ambiente(fase)
	if fase == "Noite" then
		fade(ambDia, 0); fade(ambNoite, SONS.AmbienteNoite.V)
	elseif fase == "Derrota" then
		fade(ambDia, 0); fade(ambNoite, 0)
	else
		fade(ambDia, SONS.AmbienteDia.V); fade(ambNoite, 0)
	end
end

-- FASES ---------------------------------------------------------------------------------
local ultimaFase = estado:GetAttribute("Fase")
ambiente(ultimaFase)

estado:GetAttributeChangedSignal("Fase"):Connect(function()
	local f = estado:GetAttribute("Fase")
	if f == ultimaFase then return end
	if f == "Noite" then
		play(SONS.Corneta)
	elseif f == "Derrota" then
		play(SONS.Derrota)
	end
	ultimaFase = f
	ambiente(f)
end)

-- contagem regressiva nos ultimos 3s do dia
local ultimoTick = -1
RunService.Heartbeat:Connect(function()
	if estado:GetAttribute("Fase") ~= "Dia" then ultimoTick = -1 return end
	local fim = estado:GetAttribute("FimFase") or 0
	if fim <= 0 then return end
	local resta = math.ceil(fim - workspace:GetServerTimeNow())
	-- o som de contagem ja tem ~3.5s (3-2-1), entao toca uma vez so
	if resta == 3 and ultimoTick ~= 3 then
		ultimoTick = 3
		play(SONS.Contagem)
	elseif resta > 3 then
		ultimoTick = -1
	end
end)

-- NUCLEO sendo atacado (com intervalo)
local ultimoCore = estado:GetAttribute("CoreVida") or 0
local ultimoAlerta = 0
estado:GetAttributeChangedSignal("CoreVida"):Connect(function()
	local v = estado:GetAttribute("CoreVida") or 0
	if v < ultimoCore and estado:GetAttribute("Fase") == "Noite" and os.clock() - ultimoAlerta > 4 then
		ultimoAlerta = os.clock()
		local mx = math.max(1, estado:GetAttribute("CoreVidaMax") or 1)
		play(SONS.AlertaNucleo, nil, v / mx < 0.3 and 1.15 or 1)
	end
	ultimoCore = v
end)

-- (som de moeda e de fim de wave removidos a pedido)

-- HABILIDADES (whoosh posicional)
remotes.Efeito.OnClientEvent:Connect(function(tipo, quem)
	if tipo ~= "Habilidade" then return end
	local char = typeof(quem) == "Instance" and quem:IsA("Player") and quem.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local s = Instance.new("Sound")
		s.SoundId = SONS.Habilidade.Id
		s.Volume = SONS.Habilidade.V
		s.PlaybackSpeed = SONS.Habilidade.P or 1
		s.RollOffMaxDistance = 140
		s.Parent = root
		s:Play()
		s.Ended:Once(function() s:Destroy() end)
	else
		play(SONS.Habilidade)
	end
end)

-- COMPRA de arma (novo tier)
local tierAtual = player:GetAttribute("ArmaTier")
player:GetAttributeChangedSignal("ArmaTier"):Connect(function()
	local t = player:GetAttribute("ArmaTier")
	if tierAtual and t and t > tierAtual then play(SONS.Compra) end
	tierAtual = t
end)

-- PERSONAGEM: passos/pulo/queda + coracao com vida baixa ----------------------------------
local coracao = mk(SONS.Coracao, { Looped = true, Volume = 0, Name = "Coracao" })
coracao:Play()

local TROCA = {
	Running = SONS.Passos,
	Jumping = SONS.Pulo,
	Landing = SONS.Queda,
	Climbing = SONS.Passos,
}
local SILENCIO = { FreeFalling = true, GettingUp = true, Splash = true, Died = true }

local function ajustarSom(s)
	if not s:IsA("Sound") then return end
	local def = TROCA[s.Name]
	if def then
		s.SoundId = def.Id
		s.Volume = def.V
		if def.P then s.PlaybackSpeed = def.P end
	elseif SILENCIO[s.Name] then
		s.Volume = 0
	end
end

local function onChar(char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not root or not hum then return end
	for _, s in ipairs(root:GetChildren()) do ajustarSom(s) end
	root.ChildAdded:Connect(function(s) task.defer(ajustarSom, s) end)
	-- o script padrao pode redefinir propriedades; reforca por alguns segundos
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.5)
			if not root.Parent then return end
			for _, s in ipairs(root:GetChildren()) do
				if s:IsA("Sound") and TROCA[s.Name] and s.SoundId ~= TROCA[s.Name].Id then ajustarSom(s) end
			end
		end
	end)
	-- som ao levar dano (com intervalo)
	local lastHp, lastHurt = hum.Health, 0
	hum.HealthChanged:Connect(function(h)
		if h < lastHp - 0.5 and h > 0 and os.clock() - lastHurt > 0.35 then
			lastHurt = os.clock()
			play(SONS.JogadorDano, nil, (SONS.JogadorDano.P or 1) * (0.9 + math.random() * 0.2))
		end
		lastHp = h
	end)
	local function vida()
		local r = hum.Health / math.max(1, hum.MaxHealth)
		local alvo = (hum.Health > 0 and r < 0.3) and SONS.Coracao.V or 0
		if math.abs(coracao.Volume - alvo) > 0.01 then fade(coracao, alvo) end
		coracao.PlaybackSpeed = r < 0.15 and 1.25 or 1
	end
	hum.HealthChanged:Connect(vida)
	hum.Died:Connect(function() fade(coracao, 0) end)
	vida()
end

if player.Character then task.spawn(onChar, player.Character) end
player.CharacterAdded:Connect(onChar)

-- INTERFACE: hover/clique em todos os botoes do jogo + erro quando algo e negado ----------------
-- (a Loja do Nucleo ja tem sons proprios: os botoes dela ficam de fora)
local lastHover = 0
local function hookButton(b)
	if not b:IsA("GuiButton") or b:GetAttribute("SemSom") then return end
	local loja = b:FindFirstAncestor("LojaNucleo")
	if loja then return end
	b.MouseEnter:Connect(function()
		if os.clock() - lastHover > 0.05 then lastHover = os.clock() play(SONS.UIHover) end
	end)
	b.Activated:Connect(function() play(SONS.UIClique, nil, 0.95 + math.random() * 0.1) end)
end
local pg = player:WaitForChild("PlayerGui")
for _, d in ipairs(pg:GetDescendants()) do hookButton(d) end
pg.DescendantAdded:Connect(function(d) task.defer(hookButton, d) end)

local NEGADO = { "insuficiente", "Limite", "Exige", "Longe", "Perto demais", "ocupado", "inválido", "Volte", "Chegue", "máximo" }
local lastErr = 0
remotes.Aviso.OnClientEvent:Connect(function(msg)
	if typeof(msg) ~= "string" then return end
	for _, w in ipairs(NEGADO) do
		if msg:find(w, 1, true) then
			if os.clock() - lastErr > 0.25 then lastErr = os.clock() play(SONS.UIErro) end
			return
		end
	end
end)
-- avisos locais (loja/construcao) usam este evento para tocar o erro tambem
local errEv = Instance.new("BindableEvent")
errEv.Name = "SomErro"
errEv.Parent = script
errEv.Event:Connect(function() if os.clock() - lastErr > 0.25 then lastErr = os.clock() play(SONS.UIErro) end end)
