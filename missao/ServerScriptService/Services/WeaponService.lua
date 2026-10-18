-- [WeaponService] Armas da run no estilo do video: Tools (slot 1 arma, slot 2 martelo),
-- tiro hitscan validado no servidor, soco corpo a corpo, V = proxima arma, C = +vida.
-- O cliente so manda a intencao (atirar para um ponto, socar, reparar, comprar).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Weapons)
local Modelos = require(Shared.ModelosArmas)

local WeaponService = {}
local remotes, Enemy, Economy, Build, Receipt
local fxFolder
local states = {}
local rng = Random.new()
local overlap = OverlapParams.new()
local rayParams = RaycastParams.new()

local function log(...) print("[WeaponService]", ...) end

local function newState()
	return { tier = 1, levels = { Vida = 0 }, lastAttack = 0, lastShot = 0, combo = 0, lastCombo = 0, lastRepair = 0, lastHurt = 0 }
end

-- sequencia de armas da run (Punhos + arma equipada em cada tier no Main Lobby)
local byId = {}
for _, a in ipairs(Cfg.Armas) do byId[a.Id] = a end
local function sequenceFor(player)
	local eq = {}
	pcall(function() eq = game:GetService("HttpService"):JSONDecode(player:GetAttribute("ArmasEquipadas") or "[]") end)
	local seq = { byId.Punhos or Cfg.Armas[1] }
	for t = 1, #Cfg.TiersPadrao do
		local id = eq[t]
		if typeof(id) ~= "string" or not (Cfg.TiersPermitidos[t] and Cfg.TiersPermitidos[t][id]) or not byId[id] then id = Cfg.TiersPadrao[t] end
		table.insert(seq, byId[id])
	end
	return seq
end
local DEFAULT_SEQ = { byId.Punhos or Cfg.Armas[1] }
for _, id in ipairs(Cfg.TiersPadrao) do table.insert(DEFAULT_SEQ, byId[id]) end
local function weaponOf(st) local seq = st.seq or DEFAULT_SEQ return seq[st.tier] or seq[1] end

local function healthCost(lvl) return math.floor(Cfg.Vida.CustoBase * Cfg.Vida.Mult ^ lvl + 0.5) end
WeaponService.HealthCost = healthCost

-- vida maxima = base + upgrades da run + pesquisa da Curiosity (permanente)
local function maxHpOf(player, st)
	return Cfg.Vida.Base + Cfg.Vida.PorNivel * st.levels.Vida + (player:GetAttribute("BonusPesquisaVida") or 0)
end

local function sync(player, st)
	st.seq = sequenceFor(player)
	local ids = {}
	for _, a in ipairs(st.seq) do table.insert(ids, a.Id) end
	player:SetAttribute("SequenciaArmas", table.concat(ids, ","))
	player:SetAttribute("ArmaTier", st.tier)
	player:SetAttribute("NivelVida", st.levels.Vida)
	player:SetAttribute("VidaMaxima", maxHpOf(player, st))
end

local function charOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return char, root, hum end
end

-- FERRAMENTAS --------------------------------------------------------------
local function clearTools(player)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Slot") then t:Destroy() end
			end
		end
	end
end

local function giveTools(player, st, equip)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if not backpack or not char then return end
	local wasEquipped = equip
	if not wasEquipped then
		local cur = char:FindFirstChildOfClass("Tool")
		wasEquipped = cur ~= nil and cur:GetAttribute("Slot") == 1
	end
	clearTools(player)
	if player:GetAttribute("EmJogo") ~= true then return end -- no laboratorio ninguem anda armado
	local w = weaponOf(st)
	local tool = Modelos.MakeTool(w.Id, w.Nome)
	tool:SetAttribute("Slot", 1)
	tool:SetAttribute("Arma", w.Id)
	tool.Parent = backpack
	-- (o martelo de reparo saiu do jogo)
	-- todo jogador nasce com o machado de coleta (madeira e pedra)
	local axe = Modelos.MakeTool("Machado", "MACHADO")
	axe:SetAttribute("Slot", 2)
	axe:SetAttribute("Arma", "Machado")
	axe.Parent = backpack
	if wasEquipped then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:EquipTool(tool) end
	end
end

local function applyStats(player, st, heal)
	local _, _, hum = charOf(player)
	if not hum then return end
	local maxHp = maxHpOf(player, st)
	local ratio = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	hum.MaxHealth = maxHp
	hum.Health = heal and maxHp or math.max(1, maxHp * ratio)
	WeaponService:RefreshSpeed(player)
end

function WeaponService:RefreshSpeed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local speed = Cfg.VelocidadeBaseJogador * (player:GetAttribute("MultVelocidade") or 1)
	hum:SetAttribute("VelocidadeBase", speed)
	if (hum:GetAttribute("AtordoadoAte") or 0) < os.clock() then hum.WalkSpeed = speed end
end

function WeaponService:ResetPlayer(player)
	local st = newState()
	states[player] = st
	sync(player, st)
	applyStats(player, st, true)
	giveTools(player, st, true)
end

function WeaponService:ResetAll()
	for _, p in ipairs(Players:GetPlayers()) do self:ResetPlayer(p) end
end

function WeaponService:GetState(player) return states[player] end

-- recalcula a vida maxima (ex.: pesquisa de Vida concluida) sem curar
function WeaponService:RefreshHealth(player)
	local st = states[player]
	if not st then return end
	sync(player, st)
	applyStats(player, st, false)
end

function WeaponService:SetState(player, tier, levels)
	local st = newState()
	st.tier = math.clamp(tier or 1, 1, #Cfg.CustoTier)
	if levels and levels.Vida then st.levels.Vida = levels.Vida end
	states[player] = st
	sync(player, st)
	applyStats(player, st, true)
	giveTools(player, st, true)
end

local function equippedId(player)
	local char = player.Character
	local t = char and char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("Arma"), t
end

local function dmgMult(player) return player:GetAttribute("MultDano") or 1 end

local function rollCrit(player)
	return player:GetAttribute("CriticoGarantido") == true or rng:NextNumber() < Cfg.ChanceCritico
end

-- nivel permanente da arma comprado com gemas no Main Lobby (+X% de dano por nivel)
local LobbyCfg = require(Shared.Config.Lobby)
local HttpService = game:GetService("HttpService")
local levelCache = {}
local function weaponLevelMult(player)
	local st = states[player]
	if not st then return 1 end
	local raw = player:GetAttribute("ArmasNiveis") or "{}"
	local c = levelCache[player]
	if not c or c.raw ~= raw then
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		c = { raw = raw, t = ok and t or {} }
		levelCache[player] = c
	end
	local lvl = tonumber(c.t[weaponOf(st).Id]) or 0
	return 1 + math.clamp(lvl, 0, LobbyCfg.NivelArmaMax or 5) * (LobbyCfg.BonusPorNivelArma or 0.1)
end

local function hitEnemyModel(player, mdl, base)
	local crit = rollCrit(player)
	local dmg = math.floor(base * dmgMult(player) * weaponLevelMult(player) * (crit and Cfg.MultCritico or 1) + 0.5)
	if Enemy:Damage(mdl, dmg, player) then
		local b = mdl:FindFirstChild("Corpo")
		remotes.NumeroDano:FireAllClients(b and b.Position or mdl:GetPivot().Position, dmg, crit, player.UserId)
		return true
	end
	return false
end

-- SOCO (Punhos) --------------------------------------------------------------
local function onMelee(player)
	local st = states[player]
	local _, root = charOf(player)
	if not st or not root then return end
	local w = weaponOf(st)
	if w.Tipo ~= "Corpo" or equippedId(player) ~= w.Id then return end
	local now = os.clock()
	if now - st.lastAttack < w.Cadencia * 0.8 then return end
	st.lastAttack = now
	if now - st.lastCombo > Cfg.Combo.JanelaCombo then st.combo = 0 end
	st.combo = st.combo % 3 + 1
	st.lastCombo = now
	local third = st.combo == 3
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { Enemy:Folder() }
	local range = w.Alcance
	local parts
	if w.Area then
		-- golpe no chao: acerta tudo em volta do jogador
		parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(range * 2, 8, range * 2), overlap)
	else
		local cf = root.CFrame * CFrame.new(0, 0, -range / 2)
		parts = workspace:GetPartBoundsInBox(cf, Vector3.new(range * 1.2, 8, range + 1.5), overlap)
	end
	local pushMult = math.clamp(w.Dano / 60, 1, 3)
	local seen, nHits = {}, 0
	for _, p in ipairs(parts) do
		local mdl = p:FindFirstAncestorOfClass("Model")
		if mdl and not seen[mdl] and Enemy:GetData(mdl) then
			seen[mdl] = true
			if hitEnemyModel(player, mdl, w.Dano * (third and Cfg.Combo.MultTerceiro or 1)) then
				nHits += 1
				local b = mdl:FindFirstChild("Corpo")
				if b then Enemy:Knockback(mdl, b.Position - root.Position, (third and Cfg.Combo.EmpurraoTerceiro or Cfg.Combo.Empurrao) * pushMult) end
			end
		end
	end
	if nHits > 0 then require(script.Parent.ClassService):OnWeaponHit(player, nHits) end
	remotes.Efeito:FireAllClients("Golpe", player, st.combo, st.tier, nHits > 0)
end

-- TIRO ----------------------------------------------------------------------
local function spreadDir(dir, deg)
	if deg <= 0 then return dir end
	local cf = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2)) * CFrame.Angles(math.rad(rng:NextNumber(0, deg)), 0, 0)
	return cf.LookVector
end

local function explode(player, pos, w)
	-- o visual (foguete voando + bola de fogo + fumaca) e desenhado nos clientes (ArmasCliente)
	for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
		local b = mdl:FindFirstChild("Corpo")
		if b and (b.Position - pos).Magnitude <= w.Raio + b.Size.X / 2 then hitEnemyModel(player, mdl, w.Dano) end
	end
end

local function fireOnce(player, w, aim)
	local char, root = charOf(player)
	if not root then return end
	local head = char:FindFirstChild("Head")
	local origin = head and head.Position or root.Position + Vector3.new(0, 1.5, 0)
	local _, tool = equippedId(player)
	local handle = tool and tool:FindFirstChild("Handle")
	local boca = handle and handle:FindFirstChild("Boca")
	local muzzle = boca and boca.WorldPosition or origin
	local dir = aim - origin
	if dir.Magnitude < 0.5 then dir = root.CFrame.LookVector end
	dir = dir.Unit
	local ignore = { char, fxFolder, workspace:FindFirstChild("Aliados"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Estruturas") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local hits = {}
	local hitAny = false
	for _ = 1, (w.Projeteis or 1) do
		local d = spreadDir(dir, w.Espalhamento or 0)
		local res = workspace:Raycast(origin, d * w.Alcance, rayParams)
		local endPos = res and res.Position or origin + d * w.Alcance
		table.insert(hits, endPos)
		if w.Tipo == "Foguete" then
			explode(player, endPos, w)
			hitAny = true
		elseif res then
			local mdl = res.Instance:FindFirstAncestorOfClass("Model")
			if mdl and res.Instance:IsDescendantOf(Enemy:Folder()) and Enemy:GetData(mdl) then
				if hitEnemyModel(player, mdl, w.Dano) then hitAny = true end
			end
		end
	end
	remotes.Tiro:FireAllClients(player, w.Id, muzzle, hits, hitAny)
end

local function onFire(player, aim)
	if typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Magnitude > 1e5 then return end
	local st = states[player]
	if not st or not charOf(player) then return end
	local w = weaponOf(st)
	if w.Tipo == "Corpo" or equippedId(player) ~= w.Id then return end
	local now = os.clock()
	if now - st.lastShot < w.Cadencia * 0.8 then return end
	st.lastShot = now
	local n = w.Rajada or 1
	for i = 1, n do
		if i == 1 then
			fireOnce(player, w, aim)
		else
			task.delay((i - 1) * (w.IntervaloRajada or 0.07), function()
				if states[player] == st and equippedId(player) == w.Id then fireOnce(player, w, aim) end
			end)
		end
	end
end

-- MARTELO (reparo) ----------------------------------------------------------
local function onRepair(player, model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	local st = states[player]
	local _, root = charOf(player)
	if not st or not root or equippedId(player) ~= "Martelo" then return end
	local now = os.clock()
	if now - st.lastRepair < Cfg.Martelo.Cadencia then return end
	st.lastRepair = now
	if not Build:IsAlive(model) or not model.PrimaryPart then return end
	local reach = Cfg.Martelo.Alcance + model.PrimaryPart.Size.Magnitude / 2
	if (model.PrimaryPart.Position - root.Position).Magnitude > reach then return end
	Build:Repair(player, model)
	remotes.Efeito:FireAllClients("Martelo", player, model.PrimaryPart.Position)
end

-- COMPRAS -------------------------------------------------------------------
local function onBuy(player, kind)
	local st = states[player]
	if not st or typeof(kind) ~= "string" then return end
	if kind == "Arma" then
		local seq = st.seq or sequenceFor(player)
		local nxt = seq[st.tier + 1]
		local cost = Cfg.CustoTier[st.tier + 1]
		if not nxt or not cost then return end
		if Economy:Spend(player, cost) then
			st.tier += 1
			sync(player, st)
			giveTools(player, st, true)
			remotes.Aviso:FireClient(player, nxt.Nome .. "!")
		else
			remotes.Aviso:FireClient(player, "Dinheiro insuficiente")
		end
	elseif kind == "Vida" then
		local lvl = st.levels.Vida
		if lvl >= Cfg.Vida.Max then
			remotes.Aviso:FireClient(player, "Vida no máximo (" .. Cfg.Vida.Max .. "/" .. Cfg.Vida.Max .. ")")
			return
		end
		if Economy:Spend(player, healthCost(lvl)) then
			st.levels.Vida = lvl + 1
			sync(player, st)
			local _, _, hum = charOf(player)
			if hum then
				hum.MaxHealth = maxHpOf(player, st)
				hum.Health = math.min(hum.MaxHealth, hum.Health + Cfg.Vida.PorNivel)
			end
		else
			remotes.Aviso:FireClient(player, "Dinheiro insuficiente")
		end
	end
end

local function onBuyMoney(player, index)
	if typeof(index) ~= "number" then return end
	local pack = Cfg.PacotesDinheiro[index]
	if not pack then return end
	if pack.ProdutoId and pack.ProdutoId > 0 then
		MarketplaceService:PromptProductPurchase(player, pack.ProdutoId)
	elseif RunService:IsStudio() then
		Economy:Add(player, pack.Valor)
		remotes.Aviso:FireClient(player, "(Teste no Studio) +$" .. pack.Valor)
	else
		remotes.Aviso:FireClient(player, "Produto ainda não configurado")
	end
end

function WeaponService:Init()
	remotes = Shared:WaitForChild("Remotes")
	Enemy = require(script.Parent.EnemyService)
	Economy = require(script.Parent.EconomyService)
	Build = require(script.Parent.BuildService)
	Receipt = require(script.Parent.ReceiptService)
	fxFolder = workspace:FindFirstChild("Efeitos")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "Efeitos"
		fxFolder.Parent = workspace
	end
	for _, pack in ipairs(Cfg.PacotesDinheiro) do
		Receipt:Register(pack.ProdutoId, function(player)
			Economy:Add(player, pack.Valor)
			return true
		end)
	end
end

function WeaponService:Start()
	local function onPlayer(player)
		states[player] = states[player] or newState()
		sync(player, states[player])
		-- o perfil (armas equipadas no lobby) chega depois: recalcula a sequencia
		player:GetAttributeChangedSignal("ArmasEquipadas"):Connect(function()
			local st = states[player]
			if not st then return end
			local before = weaponOf(st)
			sync(player, st)
			if weaponOf(st) ~= before then giveTools(player, st, false) end
		end)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid", 5)
			task.wait(0.1)
			local st = states[player]
			local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
			if st and hum and player.Character == char then
				applyStats(player, st, true)
				giveTools(player, st, true)
				hum.HealthChanged:Connect(function(h)
					if h < (st.lastHp or h) then st.lastHurt = os.clock() end
					st.lastHp = h
				end)
			end
		end)
		if player.Character then
			applyStats(player, states[player], true)
			giveTools(player, states[player], true)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p) states[p] = nil levelCache[p] = nil end)

	remotes.Atacar.OnServerEvent:Connect(onMelee)
	remotes.Disparar.OnServerEvent:Connect(onFire)
	remotes.Reparar.OnServerEvent:Connect(onRepair)
	remotes.ComprarUpgrade.OnServerEvent:Connect(onBuy)
	remotes.ComprarDinheiro.OnServerEvent:Connect(onBuyMoney)

	-- regeneracao natural (1 vez por segundo, um unico Heartbeat)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then return end
		acc = 0
		for player, st in pairs(states) do
			local _, _, hum = charOf(player)
			if hum and hum.Health < hum.MaxHealth and os.clock() - st.lastHurt > 4 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + Cfg.RegenPorSegundo)
			end
		end
	end)
	log("Pronto. Armas: " .. #Cfg.Armas)
end

return WeaponService
