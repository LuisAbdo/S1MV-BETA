-- [LobbyService] Lado da MISSAO da ligacao com o Main Lobby.
-- * Perfil compartilhado (mesmo DataStore do lobby): gemas, classes, classe ativa, nivel das armas, XP.
-- * Recebe o GRUPO que veio do caminhao (TeleportData.grupo) e so comeca a run quando todos chegam
--   (ou depois de Grupo.EsperaNaMissao segundos).
-- * Volta ao lobby (botao na derrota) e grava os placares MAIOR WAVE / MAIS ABATES.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Lobby)
local ClassCfg = require(Shared.Config.Classes)

local LobbyService = {}
local remotes, estado, store
local Class, Wave, Weapon, Economy, Character, Enemy
local profiles = {}
local expected = nil       -- userIds do grupo que deve chegar
local firstArrival = nil
local started = false
local lobbyId = nil
local runKills = {}        -- player -> abates nesta run (placar)
local bestWave = {}        -- player -> maior wave nesta sessao

local function log(...) print("[LobbyService]", ...) end

function LobbyService.InGame(player) return player:GetAttribute("EmJogo") == true end
function LobbyService.InGamePlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("EmJogo") == true then table.insert(list, p) end end
	return list
end

-- PERFIL ------------------------------------------------------------------------------
local function newData()
	return { Gemas = Cfg.GemasIniciais, Classes = { [ClassCfg.ClassePadrao] = true }, Ativa = ClassCfg.ClassePadrao, Armas = {}, XP = 0, Codigos = {} }
end

local function levelFromXP(xp)
	local nivel, rest = 1, xp
	while rest >= Cfg.XPNivel(nivel) and nivel < 200 do rest -= Cfg.XPNivel(nivel); nivel += 1 end
	return nivel, rest, Cfg.XPNivel(nivel)
end

local function publish(player, p)
	local d = p.data
	player:SetAttribute("Gemas", d.Gemas)
	player:SetAttribute("ClasseAtiva", d.Ativa)
	local list = {}
	for _, k in ipairs(ClassCfg.Ordem) do if d.Classes[k] then table.insert(list, k) end end
	player:SetAttribute("ClassesCompradas", table.concat(list, ","))
	player:SetAttribute("ArmasNiveis", HttpService:JSONEncode(d.Armas or {}))
	player:SetAttribute("ArmasEquipadas", HttpService:JSONEncode(typeof(d.Equip) == "table" and d.Equip or {}))
	player:SetAttribute("HabNiveis", HttpService:JSONEncode(typeof(d.Habs) == "table" and d.Habs or {}))
	player:SetAttribute("GemasEmDobro", typeof(d.Passes) == "table" and d.Passes.GemasEmDobro == true)
	local nivel = levelFromXP(d.XP or 0)
	player:SetAttribute("Nivel", nivel)
end

local function save(player, p)
	if not store or not p.persist then return true end
	p.dirty = false
	local ok, err = pcall(function() store:SetAsync("u_" .. player.UserId, p.data) end)
	if not ok then p.dirty = true warn("[LobbyService] Falha ao salvar " .. player.Name .. ": " .. tostring(err)) end
	return ok
end

local function load(player, p)
	if store then
		for attempt = 1, 3 do
			local ok, saved = pcall(function() return store:GetAsync("u_" .. player.UserId) end)
			if ok then
				if typeof(saved) == "table" then
					for k, v in pairs(saved) do p.data[k] = v end -- preserva os campos do lobby
					p.data.Gemas = math.max(0, math.floor(tonumber(p.data.Gemas) or 0))
					if typeof(p.data.Classes) ~= "table" then p.data.Classes = {} end
					p.data.Classes[ClassCfg.ClassePadrao] = true
					if typeof(p.data.Ativa) ~= "string" or not p.data.Classes[p.data.Ativa] then p.data.Ativa = ClassCfg.ClassePadrao end
					if typeof(p.data.Armas) ~= "table" then p.data.Armas = {} end
					p.data.XP = tonumber(p.data.XP) or 0
				end
				p.persist = true
				break
			end
			if RunService:IsStudio() then break end
			task.wait(attempt)
		end
		if not p.persist then warn("[LobbyService] DataStore indisponivel para " .. player.Name .. " (perfil so na memoria)") end
	end
	p.loaded = true
end

local function waitProfile(player, timeout)
	local t0 = os.clock()
	while player.Parent and (not profiles[player] or not profiles[player].loaded) do
		if os.clock() - t0 > (timeout or 15) then return nil end
		task.wait(0.2)
	end
	return profiles[player]
end

function LobbyService:AddGems(player, n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return end
	task.spawn(function()
		local p = waitProfile(player)
		if not p then return end
		-- Game Pass GEMAS EM DOBRO
		if typeof(p.data.Passes) == "table" and p.data.Passes.GemasEmDobro then n *= 2 end
		p.data.Gemas += n
		p.dirty = true
		publish(player, p)
		player:SetAttribute("GemasRun", (player:GetAttribute("GemasRun") or 0) + n)
	end)
end

function LobbyService:AddXP(player, n)
	local p = profiles[player]
	if not p or not p.loaded or n <= 0 then return end
	local before = levelFromXP(p.data.XP or 0)
	p.data.XP = (p.data.XP or 0) + n
	p.dirty = true
	publish(player, p)
	local after = levelFromXP(p.data.XP)
	if after > before then remotes.Aviso:FireClient(player, "SUBIU DE NÍVEL! LV " .. after) end
end

function LobbyService:GetActiveClass(player)
	local p = profiles[player]
	return p and p.data.Ativa or ClassCfg.ClassePadrao
end

function LobbyService:Owns(player, name)
	local p = profiles[player]
	return p ~= nil and p.data.Classes[name] == true
end

-- PLACARES ------------------------------------------------------------------------------
local function writeBoards(player)
	if RunService:IsStudio() then return end
	local key = "u_" .. player.UserId
	local w = bestWave[player] or 0
	local k = runKills[player] or 0
	runKills[player] = 0
	pcall(function()
		if w > 0 then
			DataStoreService:GetOrderedDataStore(Cfg.Placares.Wave):UpdateAsync(key, function(old) return math.max(tonumber(old) or 0, w) end)
		end
		if k > 0 then
			DataStoreService:GetOrderedDataStore(Cfg.Placares.Abates):IncrementAsync(key, k)
		end
	end)
end

-- VOLTAR AO LOBBY -------------------------------------------------------------------------
local function findLobbyId(player)
	if Cfg.Lugares.LobbyId and Cfg.Lugares.LobbyId > 0 then return Cfg.Lugares.LobbyId end
	local jd = player:GetJoinData()
	local td = jd and jd.TeleportData
	if typeof(td) == "table" and tonumber(td.origem) then return tonumber(td.origem) end
	if lobbyId then return lobbyId end
	local ok, pages = pcall(function() return AssetService:GetGamePlacesAsync() end)
	if ok and pages then
		while true do
			for _, place in ipairs(pages:GetCurrentPage()) do
				local n = string.lower(place.Name)
				if place.PlaceId ~= game.PlaceId and (n == string.lower(Cfg.Lugares.LobbyNome) or n:find("lobby")) then
					lobbyId = place.PlaceId
					return lobbyId
				end
			end
			if pages.IsFinished then break end
			if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
		end
	end
end

function LobbyService:SendToLobby(player)
	if not player.Parent then return end
	local p = profiles[player]
	if p then save(player, p) end
	writeBoards(player)
	local id = findLobbyId(player)
	if not id then
		remotes.Aviso:FireClient(player, "Lobby não encontrado (Config.Lobby.Lugares.LobbyId)")
		return
	end
	local ok, err = pcall(function() TeleportService:TeleportAsync(id, { player }) end)
	if not ok then
		remotes.Aviso:FireClient(player, RunService:IsStudio() and "(Studio) O teleporte só funciona no jogo publicado" or ("Falha ao voltar: " .. tostring(err)))
	end
end

-- CHEGADA DO GRUPO -------------------------------------------------------------------------
local function startIfReady()
	if started then return end
	local present = #LobbyService.InGamePlayers()
	if present == 0 then return end
	local need = expected and #expected or 1
	local waited = firstArrival and (os.clock() - firstArrival) or 0
	if present >= need or waited >= (Cfg.Grupo.EsperaNaMissao or 20) then
		started = true
		estado:SetAttribute("EsperandoGrupo", false)
		log("Grupo pronto (" .. present .. "/" .. need .. "). Começando a run")
		Wave:StartRun(false)
	else
		estado:SetAttribute("EsperandoGrupo", true)
		estado:SetAttribute("GrupoChegou", present)
		estado:SetAttribute("GrupoTotal", need)
	end
end

function LobbyService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Class = require(script.Parent.ClassService)
	Wave = require(script.Parent.WaveService)
	Weapon = require(script.Parent.WeaponService)
	Economy = require(script.Parent.EconomyService)
	Character = require(script.Parent.CharacterService)
	Enemy = require(script.Parent.EnemyService)
	local ok, s = pcall(function() return DataStoreService:GetDataStore(Cfg.DataStore) end)
	if ok then store = s end
end

function LobbyService:Start()
	local function onPlayer(player)
		player:SetAttribute("EmJogo", true)
		player:SetAttribute("GemasRun", 0)
		runKills[player] = 0
		-- grupo esperado (vem do caminhao do lobby)
		local jd = player:GetJoinData()
		local td = jd and jd.TeleportData
		if not expected and typeof(td) == "table" and typeof(td.grupo) == "table" then
			expected = td.grupo
			log("Grupo esperado: " .. #expected .. " jogador(es)")
		end
		firstArrival = firstArrival or os.clock()
		local p = { data = newData(), loaded = false, persist = false, dirty = false }
		profiles[player] = p
		publish(player, p)
		load(player, p)
		if not player.Parent then return end
		publish(player, p)
		Class:SetFromLobby(player, p.data.Ativa)
		-- entrou com a run ja rodando: arma inicial e nasce no mapa
		if started then
			local fase = estado:GetAttribute("Fase")
			if fase == "Dia" or fase == "Noite" then Economy:Set(player, 0) Weapon:ResetPlayer(player) end
		end
		startIfReady()
	end
	for _, pl in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, pl) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(pl)
		local p = profiles[pl]
		profiles[pl] = nil
		if p then save(pl, p) end
		writeBoards(pl)
		runKills[pl] = nil
		bestWave[pl] = nil
	end)
	game:BindToClose(function()
		for pl, p in pairs(profiles) do save(pl, p) writeBoards(pl) end
	end)
	task.spawn(function()
		while true do
			task.wait(Cfg.AutoSalvar)
			for pl, p in pairs(profiles) do if p.dirty and pl.Parent then save(pl, p) end end
		end
	end)
	-- espera o grupo chegar
	task.spawn(function()
		while not started do task.wait(0.5) startIfReady() end
	end)
	-- XP e placar
	table.insert(Enemy.OnDied, function(_, killerUserId)
		local pl = killerUserId and Players:GetPlayerByUserId(killerUserId)
		if pl then
			runKills[pl] = (runKills[pl] or 0) + 1
			LobbyService:AddXP(pl, Cfg.XPPorAbate)
		end
	end)
	estado:GetAttributeChangedSignal("Wave"):Connect(function()
		local w = estado:GetAttribute("Wave") or 0
		if w <= 1 then return end
		for _, pl in ipairs(LobbyService.InGamePlayers()) do
			bestWave[pl] = math.max(bestWave[pl] or 0, w - 1)
			LobbyService:AddXP(pl, Cfg.XPPorWave)
		end
	end)
	estado:GetAttributeChangedSignal("Fase"):Connect(function()
		if estado:GetAttribute("Fase") == "Derrota" then
			for pl, p in pairs(profiles) do task.spawn(save, pl, p) task.spawn(writeBoards, pl) end
		end
	end)

	remotes.LobbyAcao.OnServerEvent:Connect(function(player, action)
		if action == "voltar" then LobbyService:SendToLobby(player) end
	end)

	-- debug no Studio: /gemas N
	local recent = {}
	local function onChat(player, msg)
		if not RunService:IsStudio() or typeof(msg) ~= "string" then return end
		local key = player.UserId .. msg
		if recent[key] and os.clock() - recent[key] < 1 then return end
		recent[key] = os.clock()
		local n = string.match(string.lower(msg), "^/gemas%s*(%d*)")
		if n then LobbyService:AddGems(player, tonumber(n) or 1000) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do pl.Chatted:Connect(function(m) onChat(pl, m) end) end
	Players.PlayerAdded:Connect(function(pl) pl.Chatted:Connect(function(m) onChat(pl, m) end) end)
	log("Pronto (missão ligada ao Main Lobby)")
end

return LobbyService
