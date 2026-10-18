-- [PresencaChefes] Imersao quando um chefe (Verity Boss ou Glitcity) chega perto de VOCE:
-- a tela treme cada vez mais forte (ronco continuo + tranco a cada passo), as bordas escurecem
-- na cor do chefe, o coracao bate mais alto e mais rapido e os passos ficam pesados.
-- Tudo local (so visual/som). Numeros em Config/Sobrevivencia.Presenca.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local P = require(Shared.Config.Sobrevivencia).Presenca or { Longe = 110, Perto = 10, Tremor = 1.1, Passo = 0.55, Vinheta = 0.7 }
local SONS = require(Shared.Config.Sons)

local COR_BOSS = Color3.fromRGB(120, 0, 10)       -- Verity Boss: vermelho escuro
local COR_GLITCH = Color3.fromRGB(90, 0, 120)     -- Glitcity: roxo

-- corpos dos chefes vivos: Verity Boss (pasta workspace.VerityBoss) e modelos com a tag "Chefe"
local function bosses()
	local out = {}
	local vb = workspace:FindFirstChild("VerityBoss")
	if vb then
		for _, d in ipairs(vb:GetDescendants()) do
			if d.Name == "Corpo" and d:IsA("BasePart") then table.insert(out, { body = d, cor = COR_BOSS }) end
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("Chefe")) do
		local b = m:FindFirstChild("Corpo")
		if b and b:IsA("BasePart") then table.insert(out, { body = b, cor = COR_GLITCH }) end
	end
	return out
end

-- VINHETA: 4 faixas com degrade nas bordas da tela ------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PresencaChefe"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")
local edges = {}
for _, e in ipairs({
	{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90 },      -- topo (degrade para baixo)
	{ UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), -90 },  -- base
	{ UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0 },       -- esquerda
	{ UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180 },  -- direita
}) do
	local f = Instance.new("Frame")
	f.Position = e[1]
	f.Size = e[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = COR_BOSS
	f.BackgroundTransparency = 1
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = e[3]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	table.insert(edges, f)
end

-- SONS ---------------------------------------------------------------------------------------
local heart = Instance.new("Sound")
heart.Name = "CoracaoChefe"
heart.Looped = true
heart.Volume = 0
heart.Parent = SoundService
local heartDef = SONS.ChefePerto or SONS.Coracao
if heartDef then heart.SoundId = heartDef.Id end

local function stepSound(k)
	local def = SONS.ChefePassos or SONS.BossPulo
	if not def then return end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.5) * k
	s.PlaybackSpeed = (def.P or 1) * (0.9 + math.random() * 0.2)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 3)
end

-- LOOP ---------------------------------------------------------------------------------------
local level = 0        -- intensidade suavizada (0..1)
local thump = 0        -- tranco do passo (decai rapido)
local nextStep = 0
local cor = COR_BOSS
local scanAcc, nearest, nearestCor = 1, nil, COR_BOSS

RunService:BindToRenderStep("PresencaChefes", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- procura chefes 4x por segundo (barato); a distancia e medida todo frame
	scanAcc += dt
	if scanAcc > 0.25 then
		scanAcc = 0
		nearest = nil
		if root then
			local best = math.huge
			for _, b in ipairs(bosses()) do
				local d = (b.body.Position - root.Position).Magnitude
				if d < best then best, nearest, nearestCor = d, b.body, b.cor end
			end
		end
	end
	local target = 0
	if root and nearest and nearest.Parent then
		local d = (nearest.Position - root.Position).Magnitude
		target = math.clamp((P.Longe - d) / (P.Longe - P.Perto), 0, 1)
		target = target ^ 1.5  -- cresce devagar de longe e dispara quando esta muito perto
		cor = nearestCor
	end
	level += (target - level) * math.min(1, dt * 3)
	if level < 0.002 then level = 0 end

	-- passos pesados: tranco + som, mais rapidos quando esta perto
	local now = os.clock()
	if level > 0.08 and now >= nextStep then
		nextStep = now + P.Passo * (1.3 - 0.5 * level)
		thump = level
		if level > 0.25 then stepSound(level) end
	end
	thump = math.max(0, thump - dt * 5)

	-- tremor: ronco suave (ruido) + tranco do passo; nao mexe na camera de cutscene
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType ~= Enum.CameraType.Scriptable and (level > 0 or thump > 0) then
		local amp = math.rad(P.Tremor) * (level * 0.6 + thump * 1.2)
		local tt = now * 18
		local rx = math.noise(tt, 0.3) * amp
		local ry = math.noise(0.7, tt) * amp
		local rz = math.noise(tt, tt * 0.5) * amp * 0.6
		local off = Vector3.new(math.noise(tt * 0.8, 3.1), math.noise(5.2, tt * 0.8), 0) * (level * 0.15 + thump * 0.35)
		cam.CFrame = cam.CFrame * CFrame.new(off) * CFrame.Angles(rx, ry, rz)
	end

	-- bordas escuras pulsando junto com o coracao
	local pulse = 0.5 + 0.5 * math.sin(now * (4 + 6 * level))
	local tr = 1 - P.Vinheta * level * (0.75 + 0.25 * pulse)
	for _, f in ipairs(edges) do
		f.BackgroundTransparency = tr
		f.BackgroundColor3 = cor
	end

	-- coracao: mais alto e mais rapido conforme chega perto
	if heartDef then
		if level > 0.05 then
			if not heart.IsPlaying then heart:Play() end
			heart.Volume = (heartDef.V or 0.5) * level
			heart.PlaybackSpeed = (heartDef.P or 1) * (0.85 + 0.6 * level)
		elseif heart.IsPlaying then
			heart:Stop()
		end
	end
end)
