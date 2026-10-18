-- [CoreService] Vida, regeneracao, tiers e loja do Nucleo. Derrota quando chega a 0.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Core)

local CoreService = {}
CoreService.OnDestroyed = {}   -- callbacks()
CoreService.Position = Vector3.zero  -- centro no chao
CoreService.Center = Vector3.zero    -- centro da esfera

local estado, remotes, model, Economy
local health, maxHealth, tier, regen = 0, 0, 1, 0
local lastDamage = 0
local dead = false
local damageThisWave = 0

local function sync()
	estado:SetAttribute("CoreVida", math.floor(health + 0.5))
	estado:SetAttribute("CoreVidaMax", math.floor(maxHealth + 0.5))
	estado:SetAttribute("CoreTier", tier)
	estado:SetAttribute("CoreEscudoRaio", Cfg.EscudoRaioBase + Cfg.EscudoRaioPorTier * (tier - 1))
	model:SetAttribute("Vida", health)
	model:SetAttribute("VidaMax", maxHealth)
end

local function applyTier(t, keepRatio)
	local ratio = maxHealth > 0 and health / maxHealth or 1
	tier = t
	maxHealth = Cfg.VidaBase * Cfg.MultVidaPorTier ^ (t - 1)
	regen = Cfg.RegenBase + Cfg.RegenPorTier * (t - 1)
	if keepRatio then
		health = maxHealth * ratio
	end
	sync()
end

function CoreService:GetModel() return model end
function CoreService:IsDead() return dead end
function CoreService:GetTier() return tier end
function CoreService:GetHealthRatio() return maxHealth > 0 and health / maxHealth or 0 end

function CoreService:Damage(amount)
	if dead or typeof(amount) ~= "number" or amount <= 0 then return end
	-- Cupula Protetora (estrutura) segura o dano enquanto estiver de pe
	local okB, Build = pcall(require, script.Parent.BuildService)
	if okB and Build.AbsorbCoreDamage and Build:AbsorbCoreDamage(amount) then return end
	health = math.max(0, health - amount)
	damageThisWave += amount
	lastDamage = os.clock()
	sync()
	if health <= 0 then
		dead = true
		print("[CoreService] O Nucleo foi destruido")
		for _, cb in ipairs(self.OnDestroyed) do task.spawn(cb) end
	end
end

function CoreService:Heal(amount)
	if dead then return end
	health = math.min(maxHealth, health + amount)
	sync()
end

-- Fracao de vida perdida na wave atual (para o bonus de fim de wave)
function CoreService:BeginWave()
	damageThisWave = 0
end
function CoreService:WaveLossRatio()
	return maxHealth > 0 and damageThisWave / maxHealth or 0
end

function CoreService:ResetForRun(startTier)
	dead = false
	maxHealth = 0
	applyTier(startTier or 1, false)
	health = maxHealth
	sync()
end

function CoreService:Init()
	estado = Shared:WaitForChild("EstadoJogo")
	remotes = Shared:WaitForChild("Remotes")
	Economy = require(script.Parent.EconomyService)
	model = CollectionService:GetTagged("Nucleo")[1]
	if not model then
		model = workspace:WaitForChild("Mapa"):WaitForChild("Zona inicial"):WaitForChild("Nucleo")
	end
	local esf = model:WaitForChild("NucleoEsfera")
	self.Center = esf.Position
	-- chao = base do modelo (funciona com qualquer escala do Nucleo)
	local bcf, bsz = model:GetBoundingBox()
	local floorY = bcf.Position.Y - bsz.Y / 2
	self.Position = Vector3.new(esf.Position.X, floorY, esf.Position.Z)
	self:ResetForRun(1)
end

function CoreService:Start()
	-- regeneracao (1 Heartbeat, 1x por segundo)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then return end
		acc = 0
		if not dead and health < maxHealth and os.clock() - lastDamage >= Cfg.SemRegenAposDano then
			self:Heal(regen)
		end
	end)

	-- loja no painel holografico
	local painel = model:FindFirstChild("PainelLoja")
	local pedestal = painel and painel:FindFirstChild("Pedestal")
	if pedestal then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PromptLoja"
		prompt.ActionText = "Loja do Núcleo"
		prompt.ObjectText = "Núcleo"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = Cfg.DistanciaLoja
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal
		prompt.Triggered:Connect(function(player)
			remotes.AbrirLoja:FireClient(player)
		end)
	end

	remotes.ComprarTier.OnServerEvent:Connect(function(player)
		if dead then return end
		local nextTier = tier + 1
		local info = Cfg.Tiers[nextTier]
		if not info then return end
		local wave = estado:GetAttribute("Wave") or 0
		if wave < info.WaveMin then
			remotes.Aviso:FireClient(player, "Precisa chegar à wave " .. info.WaveMin)
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - self.Center).Magnitude > 40 then return end
		if not Economy:Spend(player, info.Custo) then
			remotes.Aviso:FireClient(player, "Moedas insuficientes")
			return
		end
		local before = maxHealth
		applyTier(nextTier, false)
		health = math.min(maxHealth, health + (maxHealth - before))
		sync()
		-- (o aviso de evolucao agora e a faixa animada do NucleoVisual no cliente)
		print("[CoreService] Tier " .. nextTier .. " comprado por " .. player.Name)
	end)
	print("[CoreService] Pronto. Vida " .. maxHealth)
end

return CoreService
