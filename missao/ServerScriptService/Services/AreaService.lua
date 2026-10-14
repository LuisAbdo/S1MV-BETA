-- [AreaService] Desbloqueio das areas do mapa unico.
-- As areas ficam em ServerStorage/Areas e so sao clonadas para o Workspace
-- quando desbloqueadas (ninguem as ve antes, nem por exploit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Areas"))

local AreaService = {}
AreaService.Unlocked = {}

local estado, remote, ativas, hub

local function log(...)
	print("[AreaService]", ...)
end

local function resolveName(text)
	text = string.lower(text or "")
	for name, info in pairs(Config.Areas) do
		if string.lower(name) == text then return name end
		for _, alias in ipairs(info.Apelidos or {}) do
			if alias == text then return name end
		end
	end
	return nil
end

local function findFogWalls(name)
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Area") == name and string.sub(d.Name, 1, 11) == "ParedeNevoa" then
			table.insert(list, d)
		end
	end
	return list
end

local function dissolveFog(wall, instant)
	wall.CanCollide = false
	local maxLife = 0
	for _, e in ipairs(wall:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
			if instant then e:Clear() end
			maxLife = math.max(maxLife, e.Lifetime.Max)
		end
	end
	if instant then
		wall:Destroy()
	else
		task.delay(maxLife + 0.5, function()
			if wall.Parent then wall:Destroy() end
		end)
	end
end

local function updateSign(name, text)
	if not hub then return end
	local saidas = hub:FindFirstChild("Saidas")
	local saida = saidas and saidas:FindFirstChild("Saida_" .. name)
	if not saida then return end
	for _, d in ipairs(saida:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "Texto" then d.Text = text end
	end
end

local function makeSound(parent, id, volume, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 250
	s.Parent = parent
	return s
end

-- Prepara a ponte: guarda o estado final e esconde as pecas acima do lugar
local function prepareBridge(model)
	local ponte = model:FindFirstChild("Ponte")
	if not ponte then return nil end
	local pieces = {}
	for _, p in ipairs(ponte:GetDescendants()) do
		if p:IsA("BasePart") then table.insert(pieces, p) end
	end
	table.sort(pieces, function(a, b)
		return (a:GetAttribute("Ordem") or 0) < (b:GetAttribute("Ordem") or 0)
	end)
	local data = {}
	local lift = Config.Animacao.AlturaQueda
	for i, p in ipairs(pieces) do
		data[i] = { cf = p.CFrame, tr = p.Transparency, cc = p.CanCollide }
		p.Transparency = 1
		p.CanCollide = false
		p.CFrame = p.CFrame * CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(12), 0)
	end
	return { pieces = pieces, data = data }
end

local function assembleBridge(prep, soundParent)
	local anim = Config.Animacao
	local n = #prep.pieces
	if n == 0 then return end
	local click = makeSound(soundParent, "rbxassetid://9120812564", 0.6)
	local info = TweenInfo.new(anim.DuracaoPeca, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local perFrame = math.max(1, math.ceil(n / (anim.DuracaoPonte * 60)))
	local i = 0
	while i < n do
		for _ = 1, perFrame do
			i += 1
			if i > n then break end
			local p, d = prep.pieces[i], prep.data[i]
			if p.Parent then
				TweenService:Create(p, info, { CFrame = d.cf, Transparency = d.tr }):Play()
				task.delay(anim.DuracaoPeca, function()
					if p.Parent then p.CanCollide = d.cc end
				end)
			end
			if i % 8 == 0 then
				click.PlaybackSpeed = 0.9 + math.random() * 0.3
				click:Play()
			end
		end
		task.wait()
	end
	task.delay(anim.DuracaoPeca + 0.2, function() click:Destroy() end)
end

-- Feixe de luz do caminho (do ponto de partida ate a area)
local function guideBeam(fromPos, toPos)
	local terrain = workspace.Terrain
	local a0 = Instance.new("Attachment"); a0.Name = "FeixeGuiaA"; a0.WorldPosition = fromPos + Vector3.new(0, 4, 0); a0.Parent = terrain
	local a1 = Instance.new("Attachment"); a1.Name = "FeixeGuiaB"; a1.WorldPosition = toPos + Vector3.new(0, 8, 0); a1.Parent = terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0; beam.Attachment1 = a1
	beam.Width0 = 2.5; beam.Width1 = 2.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 245, 190))
	beam.Transparency = NumberSequence.new(0.2)
	beam.CurveSize0 = 8; beam.CurveSize1 = -8
	beam.Parent = terrain
	local col = Instance.new("Part")
	col.Name = "ColunaDeLuz"
	col.Anchored = true; col.CanCollide = false; col.CanQuery = false; col.CanTouch = false; col.CastShadow = false
	col.Material = Enum.Material.Neon
	col.Color = Color3.fromRGB(255, 245, 190)
	col.Shape = Enum.PartType.Cylinder
	col.Size = Vector3.new(160, 4, 4)
	col.CFrame = CFrame.new(toPos + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90))
	col.Transparency = 0.35
	col.Parent = workspace
	local dur = Config.Animacao.DuracaoFeixe
	task.spawn(function()
		task.wait(dur * 0.6)
		local steps = 20
		for k = 1, steps do
			local t = 0.2 + 0.8 * (k / steps)
			beam.Transparency = NumberSequence.new(t)
			col.Transparency = 0.35 + 0.65 * (k / steps)
			task.wait(dur * 0.4 / steps)
		end
		beam:Destroy(); a0:Destroy(); a1:Destroy(); col:Destroy()
	end)
end

function AreaService:IsUnlocked(name)
	return self.Unlocked[name] == true
end

function AreaService:Unlock(name, opts)
	opts = opts or {}
	local info = Config.Areas[name]
	if not info then return false, "area desconhecida" end
	if self.Unlocked[name] then return false, "ja desbloqueada" end
	if info.Depende and not self.Unlocked[info.Depende] then
		self:Unlock(info.Depende, opts)
	end
	local folder = ServerStorage:FindFirstChild("Areas")
	local src = folder and folder:FindFirstChild(name)
	if not src then
		warn("[AreaService] Modelo da area nao encontrado em ServerStorage/Areas: " .. name)
		return false, "modelo ausente"
	end
	self.Unlocked[name] = true

	local walls = findFogWalls(name)
	local startPos = walls[1] and walls[1].Position or Vector3.new(0, 16, 0)

	local clone = src:Clone()
	local prep = (not opts.instant) and prepareBridge(clone) or nil
	clone.Parent = ativas
	estado:SetAttribute(name, true)

	for _, w in ipairs(walls) do dissolveFog(w, opts.instant) end
	if info.Placa then updateSign(name, info.Placa) end

	local anchorPos = clone.PrimaryPart and clone.PrimaryPart.Position or startPos
	if not opts.instant then
		if prep then
			task.spawn(assembleBridge, prep, clone.PrimaryPart or workspace)
		end
		guideBeam(startPos, anchorPos)
	end
	remote:FireAllClients(name, info.Nome, anchorPos, opts.instant == true)
	log("Area desbloqueada: " .. name .. (opts.instant and " (instantanea)" or ""))
	return true
end

-- Chamado pelo WaveService quando uma nova wave e alcancada
function AreaService:OnWaveReached(wave)
	for _, name in ipairs(Config.Ordem) do
		local info = Config.Areas[name]
		if info.Wave <= wave and not self.Unlocked[name] then
			self:Unlock(name)
		end
	end
end

-- Para o checkpoint da run
function AreaService:GetState()
	local list = {}
	for _, name in ipairs(Config.Ordem) do
		if self.Unlocked[name] then table.insert(list, name) end
	end
	return list
end

function AreaService:RestoreState(list)
	for _, name in ipairs(Config.Ordem) do
		if table.find(list, name) then self:Unlock(name, { instant = true }) end
	end
end

local function canDebug(player)
	if Config.Debug.ComandoNoStudio and RunService:IsStudio() then return true end
	if table.find(Config.Debug.UserIds, player.UserId) then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

function AreaService:HandleCommand(player, message)
	if typeof(message) ~= "string" or #message > 60 then return end
	local cmd, arg = string.match(string.lower(message), "^/(%a+)%s*(%S*)")
	if cmd ~= "unlock" then return end
	if not canDebug(player) then return end
	if arg == "all" or arg == "tudo" then
		for _, name in ipairs(Config.Ordem) do
			if not self.Unlocked[name] then
				self:Unlock(name)
				task.wait(1.5)
			end
		end
		return
	end
	local name = resolveName(arg)
	if not name then
		log("Area desconhecida no comando: " .. tostring(arg))
		return
	end
	local ok, why = self:Unlock(name)
	if not ok then log(name .. ": " .. tostring(why)) end
end

local fogCache = {}
local signCache = {}

function AreaService:ResetAll()
	for _, c in ipairs(ativas:GetChildren()) do c:Destroy() end
	self.Unlocked = {}
	for _, name in ipairs(Config.Ordem) do estado:SetAttribute(name, false) end
	-- recoloca as paredes de nevoa que ficam no hub
	for _, entry in ipairs(fogCache) do
		if not entry.parent:FindFirstChild(entry.clone.Name) then
			entry.clone:Clone().Parent = entry.parent
		end
	end
	for name in pairs(Config.Areas) do updateSign(name, "???") end
end

function AreaService:Init()
	estado = Shared:WaitForChild("EstadoAreas")
	remote = Shared:WaitForChild("Remotes"):WaitForChild("AreaDesbloqueada")
	local mapa = workspace:WaitForChild("Mapa")
	hub = mapa:WaitForChild("Zona inicial")
	ativas = mapa:FindFirstChild("AreasAtivas")
	if not ativas then
		ativas = Instance.new("Folder")
		ativas.Name = "AreasAtivas"
		ativas.Parent = mapa
	end
	for _, name in ipairs(Config.Ordem) do
		estado:SetAttribute(name, false)
	end
	for _, d in ipairs(mapa:GetDescendants()) do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 11) == "ParedeNevoa" then
			table.insert(fogCache, { parent = d.Parent, clone = d:Clone() })
		end
	end
end

function AreaService:Start()
	-- Comando de debug: /unlock <area> | /unlock all
	local recent = {}
	local function onMessage(player, message)
		local key = player.UserId .. "|" .. tostring(message)
		if recent[key] and os.clock() - recent[key] < 1 then return end
		recent[key] = os.clock()
		self:HandleCommand(player, message)
	end
	local function hook(player)
		player.Chatted:Connect(function(msg) onMessage(player, msg) end)
	end
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	Players.PlayerAdded:Connect(hook)

	local ok = pcall(function()
		local cmds = TextChatService:FindFirstChild("TextChatCommands")
		if cmds and not cmds:FindFirstChild("ComandoUnlock") then
			local c = Instance.new("TextChatCommand")
			c.Name = "ComandoUnlock"
			c.PrimaryAlias = "/unlock"
			c.Parent = cmds
			c.Triggered:Connect(function(source, text)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then onMessage(player, text) end
			end)
		end
	end)
	if not ok then log("TextChatCommand indisponivel; usando apenas Player.Chatted") end
	log("Pronto. Areas: " .. table.concat(Config.Ordem, ", "))
end

return AreaService
