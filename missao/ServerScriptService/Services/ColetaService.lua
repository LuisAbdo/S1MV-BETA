-- [ColetaService] Coleta de madeira/pedra e estoque do Nucleo.
-- Machado bate em arvores/rochas (tag "Recurso") -> arvore cai / rocha racha -> toras e pedras no chao.
-- Os itens podem ser arrastados (DragDetector) ou guardados na mochila (F). Clicar no Nucleo suga
-- tudo o que estiver perto (e a mochila) para o ESTOQUE do Nucleo, usado para construir.
-- Tudo e validado aqui: distancia, cooldown, ferramenta na mao, capacidade da mochila.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia)

local ColetaService = {}
ColetaService.OnStockChanged = {}
local remotes, estado, Core
local itensFolder
local lastHit = {}
local rng = Random.new()
local KINDS = { "Madeira", "Pedra" }

local function log(...) print("[ColetaService]", ...) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- ESTOQUE ---------------------------------------------------------------------------------
function ColetaService:Get(kind) return estado:GetAttribute("Estoque" .. kind) or 0 end
function ColetaService:Add(kind, n)
	estado:SetAttribute("Estoque" .. kind, math.max(0, self:Get(kind) + n))
end
-- cost = { Madeira = n, Pedra = n } (ou numero antigo = Madeira)
local function norm(cost)
	if typeof(cost) == "number" then return { Madeira = cost } end
	return cost or {}
end
function ColetaService:Has(cost)
	for k, v in pairs(norm(cost)) do if self:Get(k) < v then return false end end
	return true
end
function ColetaService:Spend(cost)
	cost = norm(cost)
	if not self:Has(cost) then return false end
	for k, v in pairs(cost) do self:Add(k, -v) end
	return true
end
function ColetaService:Refund(cost, frac)
	for k, v in pairs(norm(cost)) do
		local n = math.floor(v * (frac or 1) + 0.5)
		if n > 0 then self:Add(k, n) end
	end
end
function ColetaService:Describe(cost)
	local t = {}
	for _, k in ipairs(KINDS) do
		local v = norm(cost)[k]
		if v and v > 0 then table.insert(t, v .. " " .. (k == "Madeira" and "madeira" or "pedra")) end
	end
	return table.concat(t, " + ")
end

-- UTIL ------------------------------------------------------------------------------------
local function charOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return char, root, hum end
end

local function holdingAxe(char)
	local t = char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("Arma") == "Machado"
end

local function footprint(model)
	local _, sz = model:GetBoundingBox()
	return math.min(sz.X, sz.Z) / 2
end

-- ITENS NO CHAO ---------------------------------------------------------------------------
local function makeItem(kind, cf)
	local info = Cfg.Itens[kind]
	local p = Instance.new("Part")
	p.Name = info.Nome
	p.Size = info.Tamanho
	p.CFrame = cf
	p.Color = info.Cor
	p.Material = kind == "Madeira" and Enum.Material.Wood or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "ItensChao"
	p.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.1)
	p:SetAttribute("Item", kind)
	if kind == "Madeira" then
		p.Shape = Enum.PartType.Cylinder -- tora redonda, deitada no eixo X
		-- pontas mais claras (anel da tora)
		for _, s in ipairs({ -1, 1 }) do
			local ring = Instance.new("Part")
			ring.Name = "Anel"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.12, info.Tamanho.Y * 0.84, info.Tamanho.Z * 0.84)
			ring.CFrame = cf * CFrame.new(s * (info.Tamanho.X / 2 + 0.03), 0, 0)
			ring.Color = Color3.fromRGB(205, 160, 105)
			ring.Material = Enum.Material.Wood
			ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false; ring.Massless = true
			ring.CollisionGroup = "ItensChao"
			ring.Parent = p
			local w = Instance.new("WeldConstraint"); w.Part0 = p; w.Part1 = ring; w.Parent = ring
		end
	end
	-- arrastar com o mouse/dedo (como no video)
	local dd = Instance.new("DragDetector")
	dd.ResponseStyle = Enum.DragDetectorResponseStyle.Physical
	dd.DragStyle = Enum.DragDetectorDragStyle.TranslateViewPlane
	dd.MaxActivationDistance = Cfg.ArrastarAlcance
	dd.MaxForce = 6000
	dd.Responsiveness = 18
	dd.ActivatedCursorIcon = "rbxasset://textures/Cursors/DragDetector/ActivatedCursor.png"
	dd.Parent = p
	dd.DragStart:Connect(function(player) p:SetAttribute("ArrastadoPor", player.UserId) end)
	dd.DragEnd:Connect(function() p:SetAttribute("ArrastadoPor", nil) end)
	-- guardar na mochila (F)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Guardar"
	pr.ActionText = "Guardar"
	pr.ObjectText = info.Nome
	pr.KeyboardKeyCode = Enum.KeyCode.F
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Default
	pr.Parent = p
	pr.Triggered:Connect(function(player) ColetaService:Store(player, p) end)
	p:SetAttribute("Nasceu", os.clock())
	CollectionService:AddTag(p, "ItemChao")
	p.Parent = itensFolder
	p:SetNetworkOwner(nil)
	return p
end
ColetaService.MakeItem = makeItem

-- MOCHILA ---------------------------------------------------------------------------------
local function bagTotal(player)
	return (player:GetAttribute("Mochila_Madeira") or 0) + (player:GetAttribute("Mochila_Pedra") or 0)
end

local function updateSack(player)
	local char = player.Character
	local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
	if not torso then return end
	local n = bagTotal(player)
	player:SetAttribute("MochilaTotal", n)
	local sack = char:FindFirstChild("Saco")
	if n <= 0 then
		if sack then sack:Destroy() end
		return
	end
	if not sack then
		sack = Instance.new("Part")
		sack.Name = "Saco"
		sack.Shape = Enum.PartType.Ball
		sack.Color = Color3.fromRGB(150, 105, 62)
		sack.Material = Enum.Material.Fabric
		sack.CanCollide = false; sack.CanQuery = false; sack.CanTouch = false; sack.Massless = true
		sack.Parent = char
		local w = Instance.new("Weld"); w.Name = "SacoSolda"; w.Part0 = torso; w.Part1 = sack; w.Parent = sack
	end
	local s = 1.6 + n / Cfg.Mochila * 1.1
	sack.Size = Vector3.one * s
	local weld = sack:FindFirstChild("SacoSolda")
	if weld then weld.C0 = CFrame.new(0, 0.1, torso.Size.Z / 2 + s / 2 - 0.2) end
end

function ColetaService:Store(player, item)
	if not item or not item.Parent or not CollectionService:HasTag(item, "ItemChao") then return end
	local _, root = charOf(player)
	if not root or (root.Position - item.Position).Magnitude > 12 then return end
	if bagTotal(player) >= Cfg.Mochila then
		remotes.Aviso:FireClient(player, "Mochila cheia (" .. Cfg.Mochila .. "/" .. Cfg.Mochila .. ") - leve ao Núcleo")
		return
	end
	local kind = item:GetAttribute("Item")
	local pos = item.Position
	item:Destroy()
	player:SetAttribute("Mochila_" .. kind, (player:GetAttribute("Mochila_" .. kind) or 0) + 1)
	updateSack(player)
	remotes.Efeito:FireAllClients("ItemGuardado", player, pos, kind)
end

-- DEPOSITO NO NUCLEO -----------------------------------------------------------------------
local pendingSuck = {}
local function suck(list, player)
	-- list = { { kind = "Madeira", from = Vector3 } }
	if #list == 0 then return end
	local D = Cfg.Succao
	remotes.Efeito:FireAllClients("Sugar", player, list, Core.Center)
	local totals = {}
	for _, e in ipairs(list) do totals[e.kind] = (totals[e.kind] or 0) + 1 end
	task.delay(D.Duracao, function()
		for kind, n in pairs(totals) do ColetaService:Add(kind, n) end
		for _, cb in ipairs(ColetaService.OnStockChanged) do task.spawn(cb, totals, player) end
	end)
end

function ColetaService:Deposit(player)
	local _, root = charOf(player)
	if not root then return end
	local D = Cfg.Succao
	if (flat(root.Position - Core.Center)).Magnitude > D.AlcanceClique then
		remotes.Aviso:FireClient(player, "Chegue mais perto do Núcleo")
		return
	end
	local list = {}
	-- mochila
	local back = root.Position + root.CFrame.LookVector * -1.2 + Vector3.new(0, 1, 0)
	for _, kind in ipairs(KINDS) do
		local n = player:GetAttribute("Mochila_" .. kind) or 0
		for _ = 1, n do table.insert(list, { kind = kind, from = back }) end
		player:SetAttribute("Mochila_" .. kind, 0)
	end
	updateSack(player)
	-- itens soltos perto do Nucleo (inclusive os que estao sendo arrastados)
	for _, item in ipairs(CollectionService:GetTagged("ItemChao")) do
		if item.Parent and (flat(item.Position - Core.Center)).Magnitude <= D.Raio then
			table.insert(list, { kind = item:GetAttribute("Item"), from = item.Position })
			item:Destroy()
		end
	end
	if #list == 0 then
		remotes.Aviso:FireClient(player, "Traga madeira ou pedra para o Núcleo sugar")
		return
	end
	suck(list, player)
end

-- CORTAR / QUEBRAR -------------------------------------------------------------------------
local function fellTree(model, fromPos)
	local pivot = model:GetPivot()
	local trunk = model.PrimaryPart
	local basePos = trunk.Position - Vector3.new(0, trunk.Size.Y / 2, 0)
	local away = flat(basePos - fromPos)
	if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
	away = away.Unit
	local axis = Vector3.new(0, 1, 0):Cross(away).Unit
	local hinge = CFrame.new(basePos)
	local rel = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			rel[p] = hinge:ToObjectSpace(p.CFrame)
		end
	end
	local T = 1.1
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / T, 0, 1)
		local ang = (u * u) * math.rad(88)   -- acelera como uma arvore caindo de verdade
		local rot = CFrame.fromAxisAngle(axis, ang)
		for p, r in pairs(rel) do
			if p.Parent then p.CFrame = hinge * rot * r end
		end
		if u >= 1 then
			conn:Disconnect()
			remotes.Efeito:FireAllClients("ArvoreCaiu", basePos + away * trunk.Size.Y * 0.6, away, trunk.Size.Y)
			-- toras ao longo do tronco caido
			local r = Cfg.Recursos[model:GetAttribute("Recurso")]
			local n = rng:NextInteger(r.Drops[1], r.Drops[2])
			for i = 1, n do
				local along = trunk.Size.Y * (i / (n + 1))
				local pos = basePos + away * along + Vector3.new(0, 1.2, 0) + axis * rng:NextNumber(-0.8, 0.8)
				local item = makeItem("Madeira", CFrame.lookAt(pos, pos + axis) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0))
				item.AssemblyLinearVelocity = Vector3.new(0, 8, 0) + axis * rng:NextNumber(-4, 4)
			end
			for p in pairs(rel) do
				if p.Parent then
					game:GetService("TweenService"):Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
			Debris:AddItem(model, 0.55)
		end
	end)
end

local function breakRock(model)
	local cf, sz = model:GetBoundingBox()
	local center = cf.Position
	remotes.Efeito:FireAllClients("RochaQuebrou", center, math.max(sz.X, sz.Z))
	local r = Cfg.Recursos.Rocha
	local n = rng:NextInteger(r.Drops[1], r.Drops[2])
	for i = 1, n do
		local a = i / n * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * 1.5, 1.5, math.sin(a) * 1.5)
		local item = makeItem("Pedra", CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0))
		item.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 10, 16, math.sin(a) * 10)
	end
	model:Destroy()
end

local function onHit(player, model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then return end
	if not CollectionService:HasTag(model, "Recurso") or model:GetAttribute("Caindo") then return end
	local char, root = charOf(player)
	if not char or not holdingAxe(char) then return end
	local now = os.clock()
	if now - (lastHit[player] or 0) < Cfg.Machado.Cooldown * 0.85 then return end
	local main = model.PrimaryPart
	if not main then return end
	local d = (flat(main.Position - root.Position)).Magnitude - footprint(model)
	if d > Cfg.Machado.Alcance then return end
	lastHit[player] = now
	local kind = model:GetAttribute("Recurso")
	local hp = (model:GetAttribute("Vida") or 1) - Cfg.Machado.Dano
	model:SetAttribute("Vida", hp)
	local hitPos = main.Position + flat(root.Position - main.Position).Unit * math.min(footprint(model), 1.6)
	hitPos = Vector3.new(hitPos.X, math.min(root.Position.Y + 0.5, main.Position.Y + main.Size.Y / 2 - 0.5), hitPos.Z)
	remotes.Efeito:FireAllClients("Machadada", player, model, hitPos, kind, math.max(0, hp) / (model:GetAttribute("VidaMax") or 1))
	if hp <= 0 then
		model:SetAttribute("Caindo", true)
		CollectionService:RemoveTag(model, "Recurso")
		if kind == "Rocha" then breakRock(model) else fellTree(model, root.Position) end
	end
end

-- RUN -------------------------------------------------------------------------------------
function ColetaService:ResetRun()
	itensFolder:ClearAllChildren()
	for _, kind in ipairs(KINDS) do
		estado:SetAttribute("Estoque" .. kind, (Cfg.EstoqueInicial and Cfg.EstoqueInicial[kind]) or 0)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		for _, kind in ipairs(KINDS) do pl:SetAttribute("Mochila_" .. kind, 0) end
		updateSack(pl)
	end
end

function ColetaService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Core = require(script.Parent.CoreService)
	itensFolder = workspace:FindFirstChild("ItensChao") or Instance.new("Folder")
	itensFolder.Name = "ItensChao"
	itensFolder.Parent = workspace
	for _, n in ipairs({ "Coletar", "DepositarNucleo" }) do
		if not remotes:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
		end
	end
	-- itens no chao nao empurram os jogadores
	pcall(function()
		PhysicsService:RegisterCollisionGroup("ItensChao")
		PhysicsService:RegisterCollisionGroup("Jogadores")
		PhysicsService:CollisionGroupSetCollidable("ItensChao", "Jogadores", false)
		PhysicsService:CollisionGroupSetCollidable("ItensChao", "ItensChao", true)
	end)
	self:ResetRun()
end

function ColetaService:Start()
	remotes.Coletar.OnServerEvent:Connect(onHit)
	remotes.DepositarNucleo.OnServerEvent:Connect(function(player) self:Deposit(player) end)
	-- clicar no Nucleo = depositar
	local model = Core:GetModel()
	for _, n in ipairs({ "Hitbox", "NucleoEsfera", "Casca" }) do
		local p = model and model:FindFirstChild(n)
		if p and not p:FindFirstChildOfClass("ClickDetector") then
			local cd = Instance.new("ClickDetector")
			cd.MaxActivationDistance = Cfg.Succao.AlcanceClique + 6
			cd.CursorIcon = "rbxasset://textures/Cursors/DragDetector/HoverCursor.png"
			cd.Parent = p
			cd.MouseClick:Connect(function(player) self:Deposit(player) end)
		end
	end
	local function onChar(player, char)
		for _, kind in ipairs(KINDS) do player:SetAttribute("Mochila_" .. kind, 0) end
		player:SetAttribute("MochilaTotal", 0)
		local function set(d) if d:IsA("BasePart") and d.Name ~= "Saco" then d.CollisionGroup = "Jogadores" end end
		for _, d in ipairs(char:GetDescendants()) do set(d) end
		char.DescendantAdded:Connect(set)
	end
	local function onPlayer(player)
		if player.Character then onChar(player, player.Character) end
		player.CharacterAdded:Connect(function(c) onChar(player, c) end)
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p) lastHit[p] = nil end)
	-- item solto encostado no Nucleo e sugado sozinho; itens velhos somem
	task.spawn(function()
		while true do
			task.wait(0.3)
			local list = {}
			for _, item in ipairs(CollectionService:GetTagged("ItemChao")) do
				if item.Parent then
					if (flat(item.Position - Core.Center)).Magnitude <= Cfg.Succao.RaioAuto and item.Position.Y < Core.Center.Y + 12 then
						table.insert(list, { kind = item:GetAttribute("Item"), from = item.Position })
						item:Destroy()
					elseif os.clock() - (item:GetAttribute("Nasceu") or 0) > Cfg.DropsSomemEm or item.Position.Y < -20 then
						item:Destroy()
					end
				end
			end
			suck(list, nil)
		end
	end)
	log("Pronto (estoque Madeira/Pedra no Núcleo)")
end

return ColetaService
