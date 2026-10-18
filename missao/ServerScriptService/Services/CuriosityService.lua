-- [CuriosityService] CURIOSITY: assistente fixa ao lado do Nucleo.
-- Ataca inimigos a ate 15 studs (sem se mover), guia o tutorial com baloes de fala
-- e faz tarefas em segundo plano (fila de 2, tempo real, continua com o jogador offline):
--   Pesquisa (melhorias pequenas e permanentes), Envio de suprimentos (Gemas/Moedas),
--   Previsao (composicao da proxima wave).
-- O cliente so pede "iniciar tarefa X"; o servidor valida tudo (tipo, fila, nivel, distancia).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Curiosity)
local T = Cfg.Tarefas

local CuriosityService = {}
local Core, Enemy, Economy, Weapon, Wave
local remotes, estado, estadoAreas, store
local model, body, bubble, bubbleText, fxFolder
local groundPos
local data = {}      -- player -> { fila, pesq, gemas, loaded, dirty, lastReq }
local rng = Random.new()
local speakToken, speakingUntil = 0, 0

local function log(...) print("[CuriosityService]", ...) end
local function now() return os.time() end
local function timeMult() return RunService:IsStudio() and Cfg.MultTempoStudio or 1 end

-- FALAS ----------------------------------------------------------------------
function CuriosityService:Say(text, duration)
	if not bubble or typeof(text) ~= "string" then return end
	speakToken += 1
	local my = speakToken
	duration = duration or Cfg.DuracaoFala
	speakingUntil = os.clock() + duration
	bubbleText.Text = text
	bubble.Enabled = true
	task.delay(duration, function()
		if my == speakToken then bubble.Enabled = false end
	end)
end

local function pick(list) return list[rng:NextInteger(1, #list)] end

-- MODELO -----------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = model
	return p
end

local function buildModel()
	local old = workspace:FindFirstChild("Curiosity")
	if old then old:Destroy() end
	model = Instance.new("Model")
	model.Name = "Curiosity"
	local center = groundPos + Vector3.new(0, Cfg.Offset.Y, 0)
	local tmpl = ServerStorage:WaitForChild("Inimigos"):FindFirstChild("Meshes/Hollow Ball")
	if tmpl then
		body = tmpl:Clone()
		for _, d in ipairs(body:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("ValueBase") then d:Destroy() end
		end
	else
		body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
	end
	body.Name = "Corpo"
	body.Anchored = true; body.CanCollide = false; body.CanTouch = false; body.CanQuery = true
	body.Size = Vector3.one * 4.4
	body.Color = Color3.fromRGB(34, 139, 34) -- verde floresta (Forest green)
	-- rosto proprio (Config/Rostos.Curiosity)
	local okR, Rostos = pcall(require, ReplicatedStorage.Shared.Config:FindFirstChild("Rostos"))
	local faceId = okR and type(Rostos) == "table" and tonumber(Rostos.Curiosity) or 0
	if faceId > 0 then
		for _, d in ipairs(body:GetDescendants()) do
			if d:IsA("Decal") and d.Face == Enum.NormalId.Front then d.Texture = "rbxassetid://" .. faceId end
		end
	end
	body.CFrame = CFrame.lookAt(center, center + Vector3.new(0, 0, 10)) -- olhando para o spawn dos jogadores
	body.Parent = model
	model.PrimaryPart = body
	local cf = body.CFrame
	-- antena com lampada
	part({ Name = "Antena", Size = Vector3.new(0.25, 1.6, 0.25), Color = Color3.fromRGB(70, 80, 100), CFrame = cf * CFrame.new(0.3, 2.8, 0) * CFrame.Angles(0, 0, math.rad(-12)) })
	part({ Name = "Lampada", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Color = Color3.fromRGB(255, 230, 90), Material = Enum.Material.Neon, CFrame = cf * CFrame.new(0.5, 3.7, 0) })
	-- lupa flutuando ao lado (pesquisadora)
	local lupa = cf * CFrame.new(-3.1, -0.2, -0.6)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		part({ Name = "Aro", Size = Vector3.new(0.3, 0.3, 0.55), Color = Color3.fromRGB(240, 190, 70), CFrame = lupa * CFrame.new(math.cos(a) * 0.95, math.sin(a) * 0.95, 0) * CFrame.Angles(0, 0, a) })
	end
	part({ Name = "Lente", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.8, 1.8), Color = Color3.fromRGB(190, 240, 255), Transparency = 0.45, Material = Enum.Material.Glass, CFrame = lupa * CFrame.Angles(0, math.rad(90), 0) })
	part({ Name = "Cabo", Size = Vector3.new(0.3, 1.4, 0.3), Color = Color3.fromRGB(120, 75, 40), CFrame = lupa * CFrame.new(0.35, -1.55, 0) * CFrame.Angles(0, 0, math.rad(-20)) })
	-- olho do laser
	local olho = part({ Name = "Olho", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, Color = Color3.fromRGB(80, 255, 230), Material = Enum.Material.Neon, CFrame = cf * CFrame.new(0, 0.5, -2.1) })
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(120, 220, 255); luz.Range = 10; luz.Brightness = 1.2
	luz.Parent = body
	-- sombra no chao
	part({ Name = "Sombra", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3.6, 3.6), Color = Color3.fromRGB(20, 20, 30), Transparency = 0.6, CFrame = CFrame.new(groundPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	-- nome
	local tag = Instance.new("BillboardGui")
	tag.Name = "Nome"
	tag.Size = UDim2.fromOffset(160, 26)
	tag.StudsOffset = Vector3.new(0, 4.6, 0)
	tag.MaxDistance = 70
	tag.Parent = body
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1
	tl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	tl.Text = "CURIOSITY"; tl.TextScaled = true; tl.TextColor3 = Color3.fromRGB(120, 230, 255)
	tl.Parent = tag
	local ts = Instance.new("UIStroke"); ts.Thickness = 2; ts.Color = Color3.fromRGB(10, 20, 30); ts.Parent = tl
	-- balao de fala
	bubble = Instance.new("BillboardGui")
	bubble.Name = "Balao"
	bubble.Size = UDim2.fromOffset(300, 74)
	bubble.StudsOffset = Vector3.new(0, 7.6, 0)
	bubble.AlwaysOnTop = true
	bubble.MaxDistance = 140
	bubble.Enabled = false
	bubble.Parent = body
	local bf = Instance.new("Frame")
	bf.Size = UDim2.new(1, 0, 1, -12); bf.BackgroundColor3 = Color3.new(1, 1, 1); bf.BorderSizePixel = 0
	bf.Parent = bubble
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 14); bc.Parent = bf
	local bs = Instance.new("UIStroke"); bs.Thickness = 3; bs.Color = Color3.fromRGB(14, 14, 16); bs.Parent = bf
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5); tail.Position = UDim2.new(0.5, 0, 1, -12); tail.Size = UDim2.fromOffset(16, 16)
	tail.Rotation = 45; tail.BackgroundColor3 = Color3.new(1, 1, 1); tail.BorderSizePixel = 0; tail.ZIndex = 0
	tail.Parent = bubble
	local ts2 = Instance.new("UIStroke"); ts2.Thickness = 3; ts2.Color = Color3.fromRGB(14, 14, 16); ts2.Parent = tail
	bubbleText = Instance.new("TextLabel")
	bubbleText.Size = UDim2.new(1, -18, 1, -10); bubbleText.Position = UDim2.fromOffset(9, 5)
	bubbleText.BackgroundTransparency = 1; bubbleText.TextWrapped = true; bubbleText.TextScaled = true
	bubbleText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	bubbleText.TextColor3 = Color3.fromRGB(14, 14, 16); bubbleText.Text = ""; bubbleText.ZIndex = 2
	bubbleText.Parent = bf
	local lim = Instance.new("UITextSizeConstraint"); lim.MaxTextSize = 20; lim.Parent = bubbleText
	-- conversar
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Falar"
	prompt.ActionText = "Falar"
	prompt.ObjectText = "CURIOSITY"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Cfg.DistanciaInteracao + 4 -- o corpo flutua ~7 studs acima
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		remotes.CuriosityInfo:FireClient(player, "abrir")
	end)
	model:SetAttribute("Alcance", Cfg.Alcance)
	model.Parent = workspace
	return olho
end

-- DADOS / PERSISTENCIA ---------------------------------------------------------------
local function newData()
	local pesq = {}
	for _, l in ipairs(T.Pesquisa.Ordem) do pesq[l] = 0 end
	return { fila = {}, pesq = pesq, gemas = 0, loaded = false, dirty = false, lastReq = 0 }
end

local function publish(player, d)
	-- as Gemas agora moram no perfil do Laboratorio (LobbyService -> atributo "Gemas")
	player:SetAttribute("CuriosityDados", HttpService:JSONEncode({ fila = d.fila, pesq = d.pesq }))
end

local function applyBonuses(player, d)
	local L = T.Pesquisa.Linhas
	player:SetAttribute("BonusPesquisaDano", (d.pesq.Dano or 0) * L.Dano.PorNivel)
	player:SetAttribute("BonusPesquisaVida", (d.pesq.Vida or 0) * L.Vida.PorNivel)
	player:SetAttribute("BonusPesquisaMoedas", (d.pesq.Moedas or 0) * L.Moedas.PorNivel)
	if Weapon and Weapon.RefreshHealth then Weapon:RefreshHealth(player) end
end

local function save(player, d)
	if not store or not d.loaded then return end -- se o load falhou, nunca sobrescreve
	d.dirty = false
	local payload = { fila = d.fila, pesq = d.pesq, gemas = d.gemas }
	local ok, err = pcall(function() store:SetAsync("u_" .. player.UserId, payload) end)
	if not ok then
		d.dirty = true
		warn("[CuriosityService] Falha ao salvar " .. player.Name .. ": " .. tostring(err))
	end
end

local function load(player, d)
	if not store then return end
	for attempt = 1, 3 do
		local ok, saved = pcall(function() return store:GetAsync("u_" .. player.UserId) end)
		if ok then
			if typeof(saved) == "table" then
				if typeof(saved.fila) == "table" then d.fila = saved.fila end
				if typeof(saved.pesq) == "table" then
					for l in pairs(d.pesq) do d.pesq[l] = tonumber(saved.pesq[l]) or 0 end
				end
				d.gemas = tonumber(saved.gemas) or 0
			end
			d.loaded = true
			return
		end
		task.wait(attempt)
	end
	warn("[CuriosityService] DataStore indisponivel para " .. player.Name .. " (dados so na memoria)")
end

-- TAREFAS ----------------------------------------------------------------------
local function queuedCount(d, tipo, linha)
	local n = 0
	for _, it in ipairs(d.fila) do
		if it.t == tipo and (linha == nil or it.l == linha) then n += 1 end
	end
	return n
end

local function durationFor(d, tipo, linha)
	local base
	if tipo == "Pesquisa" then
		local lvl = (d.pesq[linha] or 0) + queuedCount(d, "Pesquisa", linha)
		base = T.Pesquisa.DuracaoBase + T.Pesquisa.DuracaoPorNivel * lvl
	else
		base = T[tipo].Duracao
	end
	return math.max(1, math.floor(base * timeMult() + 0.5))
end

local function startTask(player, tipo, linha)
	local d = data[player]
	if not d then return end
	if typeof(tipo) ~= "string" or not T[tipo] then return end
	if #d.fila >= Cfg.MaxFila then
		remotes.Aviso:FireClient(player, "A fila da Curiosity está cheia (máx. " .. Cfg.MaxFila .. ")")
		return
	end
	if tipo == "Pesquisa" then
		if typeof(linha) ~= "string" or not T.Pesquisa.Linhas[linha] then return end
		local L = T.Pesquisa.Linhas[linha]
		if (d.pesq[linha] or 0) + queuedCount(d, "Pesquisa", linha) >= L.Max then
			remotes.Aviso:FireClient(player, "Pesquisa de " .. L.Nome .. " no máximo")
			return
		end
	else
		linha = nil
		if queuedCount(d, tipo) > 0 then
			remotes.Aviso:FireClient(player, T[tipo].Nome .. " já está na fila")
			return
		end
	end
	local start = now()
	local last = d.fila[#d.fila]
	if last and last.fim > start then start = last.fim end
	local item = { t = tipo, l = linha, ini = start, fim = start + durationFor(d, tipo, linha) }
	table.insert(d.fila, item)
	d.dirty = true
	publish(player, d)
	remotes.Aviso:FireClient(player, "Curiosity: " .. T[tipo].Nome .. (linha and (" (" .. T.Pesquisa.Linhas[linha].Nome .. ")") or "") .. " iniciada!")
end

local function forecast()
	local plan, w = Wave:GetPlan()
	local counts, order = {}, {}
	for _, name in ipairs(plan) do
		if not counts[name] then counts[name] = 0; table.insert(order, name) end
		counts[name] += 1
	end
	local list = {}
	for _, name in ipairs(order) do table.insert(list, { name, counts[name] }) end
	return { wave = w, lista = list, total = #plan }
end

local function complete(player, d, item)
	if item.t == "Pesquisa" then
		local L = T.Pesquisa.Linhas[item.l]
		if L then
			d.pesq[item.l] = math.min(L.Max, (d.pesq[item.l] or 0) + 1)
			applyBonuses(player, d)
			remotes.Aviso:FireClient(player, "Pesquisa concluída: " .. L.Nome .. " nível " .. d.pesq[item.l])
		end
	elseif item.t == "Suprimentos" then
		local S = T.Suprimentos
		local g = rng:NextInteger(S.GemasMin, S.GemasMax)
		require(script.Parent.LobbyService):AddGems(player, g)
		local f = estado:GetAttribute("Fase")
		local extra = ""
		if f == "Dia" or f == "Noite" then
			Economy:Add(player, S.Moedas)
			extra = "  +$" .. S.Moedas
		end
		remotes.Aviso:FireClient(player, "Suprimentos chegaram! +" .. g .. " Gemas" .. extra)
	elseif item.t == "Previsao" then
		local ok, info = pcall(forecast)
		if ok then
			remotes.CuriosityInfo:FireClient(player, "previsao", info)
			remotes.Aviso:FireClient(player, "Previsão pronta: wave " .. info.wave .. " (" .. info.total .. " inimigos)")
		end
	end
	d.dirty = true
end

local function processPlayer(player, d)
	local changed = false
	local t = now()
	while d.fila[1] and t >= d.fila[1].fim do
		local item = table.remove(d.fila, 1)
		complete(player, d, item)
		changed = true
	end
	if changed then publish(player, d) end
end

-- ATAQUE ------------------------------------------------------------------------
local function tracer(from, to)
	local dist = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(90, 255, 230)
	p.Size = Vector3.new(0.35, 0.35, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
	Debris:AddItem(p, 0.2)
end

-- TUTORIAL ------------------------------------------------------------------------
local warnedCore = false
local lastAreaTalk = 0
local function onPhase()
	local f = estado:GetAttribute("Fase")
	local w = estado:GetAttribute("Wave") or 0
	local F = Cfg.Falas
	if f == "Dia" then
		if w == 1 then
			CuriosityService:Say(F.Inicio[1])
			task.delay(Cfg.DuracaoFala + 0.5, function()
				if estado:GetAttribute("Fase") == "Dia" then CuriosityService:Say(F.Inicio[2]) end
			end)
		elseif w == 2 then CuriosityService:Say(F.Wave2)
		elseif w == 3 then CuriosityService:Say(F.Wave3)
		elseif w == 4 then CuriosityService:Say(F.Wave4) end
	elseif f == "Noite" then
		warnedCore = false
		CuriosityService:Say(w == 1 and F.Noite1 or pick(F.Noite), 3)
	end
end

function CuriosityService:Init()
	Core = require(script.Parent.CoreService)
	Enemy = require(script.Parent.EnemyService)
	Economy = require(script.Parent.EconomyService)
	Weapon = require(script.Parent.WeaponService)
	Wave = require(script.Parent.WaveService)
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	estadoAreas = Shared:WaitForChild("EstadoAreas")
	fxFolder = workspace:FindFirstChild("Efeitos") or workspace
	local ok, s = pcall(function() return DataStoreService:GetDataStore(Cfg.DataStore) end)
	if ok then store = s end
	groundPos = Core.Position + Vector3.new(Cfg.Offset.X, 0, Cfg.Offset.Z)
end

function CuriosityService:Start()
	local olho = buildModel()

	local function onPlayer(player)
		local d = newData()
		data[player] = d
		load(player, d)
		if not player.Parent then return end
		-- migracao: gemas antigas guardadas na Curiosity vao para o perfil do Laboratorio
		if (d.gemas or 0) > 0 then
			require(script.Parent.LobbyService):AddGems(player, d.gemas)
			d.gemas = 0
			d.dirty = true
		end
		processPlayer(player, d) -- tarefas que terminaram enquanto estava offline
		applyBonuses(player, d)
		publish(player, d)
		player:GetAttributeChangedSignal("Morto"):Connect(function()
			if player:GetAttribute("Morto") then
				CuriosityService:Say((Cfg.Falas.Morte:gsub("{nome}", player.DisplayName)))
			end
		end)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			if data[player] then applyBonuses(player, data[player]) end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p)
		local d = data[p]
		data[p] = nil
		if d then save(p, d) end
	end)
	game:BindToClose(function()
		for p, d in pairs(data) do save(p, d) end
	end)

	remotes.CuriosityAcao.OnServerEvent:Connect(function(player, tipo, linha)
		local d = data[player]
		if not d then return end
		local t = os.clock()
		if t - d.lastReq < 0.4 then return end
		d.lastReq = t
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local flat = Vector3.new(root.Position.X - groundPos.X, 0, root.Position.Z - groundPos.Z)
		if flat.Magnitude > Cfg.DistanciaInteracao + 8 then return end
		startTask(player, tipo, linha)
	end)

	estado:GetAttributeChangedSignal("Fase"):Connect(onPhase)
	estado:GetAttributeChangedSignal("CoreVida"):Connect(function()
		local mx = estado:GetAttribute("CoreVidaMax") or 1
		if not warnedCore and estado:GetAttribute("Fase") == "Noite" and (estado:GetAttribute("CoreVida") or mx) / math.max(1, mx) < 0.3 then
			warnedCore = true
			CuriosityService:Say(Cfg.Falas.NucleoFraco)
		end
	end)
	estadoAreas.AttributeChanged:Connect(function(name)
		if estadoAreas:GetAttribute(name) == true and os.clock() - lastAreaTalk > 8 then
			lastAreaTalk = os.clock()
			CuriosityService:Say(Cfg.Falas.NovaArea)
		end
	end)

	-- loop unico: ataque (cadencia) + tarefas (1x por segundo) + salvamento (a cada 15 s)
	local atkAcc, taskAcc, saveAcc, lastQuip = 0, 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		atkAcc += dt
		taskAcc += dt
		saveAcc += dt
		if atkAcc >= Cfg.Cadencia then
			atkAcc = 0
			local best, bd
			for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
				local b = mdl:FindFirstChild("Corpo")
				if b then
					local d = Vector3.new(b.Position.X - groundPos.X, 0, b.Position.Z - groundPos.Z).Magnitude
					if d <= Cfg.Alcance and (not bd or d < bd) then best, bd = mdl, d end
				end
			end
			if best then
				local b = best:FindFirstChild("Corpo")
				tracer(olho.Position, b.Position)
				Enemy:Damage(best, Cfg.Dano, nil)
				if os.clock() > speakingUntil and os.clock() - lastQuip > 14 and rng:NextNumber() < 0.25 then
					lastQuip = os.clock()
					CuriosityService:Say(pick(Cfg.Falas.Ataque), 2)
				end
			end
		end
		if taskAcc >= 1 then
			taskAcc = 0
			for p, d in pairs(data) do
				if p.Parent then processPlayer(p, d) end
			end
		end
		if saveAcc >= 15 then
			saveAcc = 0
			for p, d in pairs(data) do
				if d.dirty and p.Parent then task.spawn(save, p, d) end
			end
		end
	end)
	log("Pronto em " .. tostring(groundPos))
end

return CuriosityService
