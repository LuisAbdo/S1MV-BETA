-- [ReviveService] GODRITY: painel de morte + revive animado (nao e cutscene).
-- 1o revive da CONTA e gratis (flag no DataStore). Depois: 15 Robux (Developer Product),
-- entregue SO pelo ProcessReceipt (ReceiptService, idempotente). Maximo 2 pagos por run.
-- "Esperar proxima wave" e sempre gratis: volta no inicio do proximo dia (nunca fica preso).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Revive)
local ClassCfg = require(Shared.Config.Classes)

local ReviveService = {}
local Character, Receipt, Class
local remotes, estado, store
local states = {}

local function log(...) print("[ReviveService]", ...) end

local function stateOf(player)
	local s = states[player]
	if not s then
		s = { paid = 0, credit = 0, freeUsed = false, dead = false, reviving = false, lastReq = 0 }
		states[player] = s
	end
	return s
end

local function phase() return estado:GetAttribute("Fase") or "Aguardando" end
local function runActive() local f = phase() return f == "Dia" or f == "Noite" end

-- Medico: revive 30% mais rapido
local function speedMult(player)
	if Class and Class:GetClass(player) == "Medico" then
		return 1 - (ClassCfg.Classes.Medico.Passiva.Revive or 0)
	end
	return 1
end

local function storeKey(player) return "u_" .. player.UserId end

local function loadFlag(player)
	local s = stateOf(player)
	if not store then return end
	local ok, data = pcall(function() return store:GetAsync(storeKey(player)) end)
	if ok and typeof(data) == "table" and data.Gratis then s.freeUsed = true end
end

-- Marca o revive gratis como usado de forma atomica. Retorna true se ESTE pedido ganhou o gratis.
local function claimFree(player)
	local s = stateOf(player)
	if s.freeUsed or not Cfg.PrimeiroGratis then return false end
	local granted = false
	local ok = store and pcall(function()
		store:UpdateAsync(storeKey(player), function(old)
			old = typeof(old) == "table" and old or {}
			if old.Gratis then granted = false return nil end
			old.Gratis = true
			granted = true
			return old
		end)
	end)
	if not ok then
		-- DataStore indisponivel (ex.: Studio sem acesso a API): usa so a memoria
		granted = not s.freeUsed
	end
	s.freeUsed = true
	return granted
end

local function panelInfo(player)
	local s = stateOf(player)
	return {
		gratis = Cfg.PrimeiroGratis and not s.freeUsed,
		credito = s.credit,
		pagos = s.paid,
		max = Cfg.MaxPagosPorRun,
		preco = Cfg.PrecoRobux,
		fase = phase(),
		escolha = s.choice,
		espera = Cfg.EsperaDeDia,
	}
end

local function sendPanel(player)
	local s = stateOf(player)
	if s.dead and not s.reviving then
		remotes.PainelMorte:FireClient(player, panelInfo(player))
	else
		remotes.PainelMorte:FireClient(player, nil)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos)
	local ignore = { workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Aliados") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

-- REVIVE ------------------------------------------------------------------
-- where: "corpo" (onde caiu) ou "spawn" (inicio do dia)
local function doRevive(player, where)
	local s = stateOf(player)
	if not s.dead or s.reviving or not player.Parent then return end
	s.reviving = true
	remotes.PainelMorte:FireClient(player, nil)
	local A = Cfg.Animacao
	local k = speedMult(player)
	local cf = (where == "corpo" and s.body) or Character:SpawnCFrame()
	local ground = groundAt(cf.Position)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	-- o efeito (feixe, Godrity, onda de luz, penas, som) e desenhado em cada cliente
	remotes.Efeito:FireAllClients("Godrity", player, ground, k)
	task.wait(A.AparecerEm * k)
	if not player.Parent then return end
	s.dead = false
	s.choice = nil
	player:SetAttribute("Morto", false)
	local standPos = ground + Vector3.new(0, 3, 0)
	local model = Character:Spawn(player, CFrame.lookAt(standPos, standPos + look.Unit))
	if not model then s.reviving = false return end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local ff = Instance.new("ForceField")
	ff.Name = "ProtecaoGodrity"
	ff.Visible = false
	ff.Parent = model
	Debris:AddItem(ff, A.Invulneravel)
	if root then
		root.Anchored = true
		local base = root.CFrame
		local liftT = math.max(0.3, (A.Controle - A.AparecerEm) * k)
		local up = TweenService:Create(root, TweenInfo.new(liftT * 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = base + Vector3.new(0, A.AlturaLevantar, 0) })
		up:Play()
		task.wait(liftT * 0.6)
		if root.Parent then
			TweenService:Create(root, TweenInfo.new(liftT * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = base }):Play()
		end
		task.wait(liftT * 0.4)
		if root.Parent then root.Anchored = false end
	end
	s.reviving = false
	log(player.Name .. " revivido (" .. where .. ")")
end

-- MORTE ---------------------------------------------------------------------
local function onDeath(player, model)
	if not runActive() then return false end -- fora da run: renasce sozinho
	if player:GetAttribute("EmJogo") ~= true then return false end -- no laboratorio: renasce sozinho
	local s = stateOf(player)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	s.dead = true
	s.choice = nil
	s.body = root and root.CFrame or Character:SpawnCFrame()
	player:SetAttribute("Morto", true)
	sendPanel(player)
	return true
end

local function waitDay(player)
	local s = stateOf(player)
	s.choice = "esperar"
	sendPanel(player)
	local f = phase()
	if f == "Dia" or f == "Aguardando" then
		-- de dia nao ha proximo "inicio de dia" logo: volta em poucos segundos
		task.delay(Cfg.EsperaDeDia, function()
			if s.dead and s.choice == "esperar" and not s.reviving then doRevive(player, "spawn") end
		end)
	end
end

local function reviveNow(player)
	local s = stateOf(player)
	if s.credit > 0 then
		s.credit -= 1
		task.spawn(doRevive, player, "corpo")
		return
	end
	if Cfg.PrimeiroGratis and not s.freeUsed then
		if claimFree(player) then
			remotes.Aviso:FireClient(player, "Revive grátis usado!")
			task.spawn(doRevive, player, "corpo")
		else
			sendPanel(player)
		end
		return
	end
	if s.paid >= Cfg.MaxPagosPorRun then
		remotes.Aviso:FireClient(player, "Limite de revives pagos nesta run")
		return
	end
	if Cfg.ProdutoId and Cfg.ProdutoId > 0 then
		MarketplaceService:PromptProductPurchase(player, Cfg.ProdutoId)
	elseif RunService:IsStudio() then
		s.paid += 1
		remotes.Aviso:FireClient(player, "(Teste no Studio) revive pago")
		task.spawn(doRevive, player, "corpo")
	else
		remotes.Aviso:FireClient(player, "Produto de revive ainda não configurado")
	end
end

-- chamado pelo WaveService:StartRun (nova run ou checkpoint)
function ReviveService:ResetRun()
	for player, s in pairs(states) do
		s.paid = 0
		s.dead = false
		s.choice = nil
		if player.Parent then
			player:SetAttribute("Morto", false)
			remotes.PainelMorte:FireClient(player, nil)
		end
	end
end

function ReviveService:IsDead(player)
	local s = states[player]
	return s ~= nil and s.dead
end

function ReviveService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Character = require(script.Parent.CharacterService)
	Receipt = require(script.Parent.ReceiptService)
	Class = require(script.Parent.ClassService)
	local ok, s = pcall(function() return DataStoreService:GetDataStore(Cfg.DataStore) end)
	if ok then store = s end
	Character.HandleDeath = onDeath
	-- compra com Robux: so o ProcessReceipt entrega (o ReceiptService guarda o PurchaseId)
	Receipt:Register(Cfg.ProdutoId, function(player)
		local st = stateOf(player)
		st.paid += 1
		if st.dead and not st.reviving then
			task.defer(doRevive, player, "corpo")
		else
			-- ja voltou (ex.: o dia comecou): vira credito para a proxima queda
			st.credit += 1
			remotes.Aviso:FireClient(player, "Revive guardado para a próxima queda")
		end
		return true
	end)
end

function ReviveService:Start()
	local function onPlayer(player)
		stateOf(player)
		player:SetAttribute("Morto", false)
		task.spawn(loadFlag, player)
		player.CharacterAdded:Connect(function()
			local s = stateOf(player)
			-- renasceu por outro caminho (nova run, checkpoint): limpa o estado de morto
			if s.dead and not s.reviving then
				s.dead = false
				s.choice = nil
				player:SetAttribute("Morto", false)
				remotes.PainelMorte:FireClient(player, nil)
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p) states[p] = nil end)

	remotes.Reviver.OnServerEvent:Connect(function(player, choice)
		if choice ~= "agora" and choice ~= "esperar" then return end
		local s = stateOf(player)
		if not s.dead or s.reviving then return end
		local now = os.clock()
		if now - s.lastReq < 0.5 then return end
		s.lastReq = now
		if choice == "esperar" then waitDay(player) else reviveNow(player) end
	end)

	-- inicio do dia: todo mundo que caiu volta (opcao gratis)
	estado:GetAttributeChangedSignal("Fase"):Connect(function()
		local f = phase()
		if f == "Dia" then
			for player, s in pairs(states) do
				if s.dead and not s.reviving and player.Parent then task.spawn(doRevive, player, "spawn") end
			end
		elseif f == "Derrota" or f == "Aguardando" then
			for player, s in pairs(states) do
				if s.dead and player.Parent then remotes.PainelMorte:FireClient(player, nil) end
			end
		else
			for player, s in pairs(states) do
				if s.dead and player.Parent then sendPanel(player) end
			end
		end
	end)
	log("Pronto. Produto: " .. tostring(Cfg.ProdutoId) .. (Cfg.ProdutoId == 0 and " (configure o ID em Config/Revive)" or ""))
end

return ReviveService
