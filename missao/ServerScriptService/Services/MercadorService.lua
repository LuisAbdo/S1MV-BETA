-- [MercadorService] A Casa do Mercador (ServerStorage.Casa) nasce num ponto do mapa gerado a
-- cada run, com um NPC dentro. A loja dele vende melhorias PESSOAIS (mochila, machado, mapa)
-- pagas com o ESTOQUE do Nucleo (madeira/pedra entregues ao Nucleo). Tudo validado aqui.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia)
local Custos = require(Shared.Custos)
local M = Cfg.Mercador

local MercadorService = {}
local remotes, estado, Chunk, Coleta, Core
local casa, npcRoot
local ATTR = { Mochila = "NivelMochila", Machado = "NivelMachado", Mapa = "NivelMapa" }

local function log(...) print("[Mercador]", ...) end

local function itemById(id)
	for _, it in ipairs(M.Itens) do if it.Id == id then return it end end
end

-- NPC simples em R6 (sem scripts de terceiros), parado atras do balcao
local function makeNpc(cf)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(234, 184, 146)
	desc.LeftArmColor = desc.HeadColor; desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = Color3.fromRGB(120, 78, 44)
	desc.LeftLegColor = Color3.fromRGB(60, 52, 46); desc.RightLegColor = desc.LeftLegColor
	local ok, npc = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not ok or not npc then return nil end
	npc.Name = "Mercador"
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	local hum = npc:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local root = npc:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	npc:PivotTo(cf)
	-- chapeu de palha (pecas simples)
	local head = npc:FindFirstChild("Head")
	if head then
		local aba = Instance.new("Part")
		aba.Name = "Chapeu"
		aba.Size = Vector3.new(2.8, 0.2, 2.8)
		aba.Color = Color3.fromRGB(214, 180, 98)
		aba.CanCollide = false; aba.Massless = true
		aba.CFrame = head.CFrame * CFrame.new(0, 0.65, 0)
		aba.Parent = npc
		local topo = aba:Clone()
		topo.Size = Vector3.new(1.4, 0.7, 1.4)
		topo.CFrame = head.CFrame * CFrame.new(0, 1, 0)
		topo.Parent = npc
		for _, p in ipairs({ aba, topo }) do
			local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = p; w.Parent = p
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 30)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 60
		bb.Parent = head
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true
		t.Text = "MERCADOR"; t.TextColor3 = Color3.fromRGB(255, 220, 140)
		t.Parent = bb
		local s = Instance.new("UIStroke"); s.Thickness = 2; s.Color = Color3.fromRGB(50, 30, 10); s.Parent = t
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Loja"
	pr.ActionText = "Loja do Mercador"
	pr.ObjectText = "Mercador"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = root
	pr.Triggered:Connect(function(player) remotes.AbrirMercador:FireClient(player) end)
	return npc, root
end

function MercadorService:SpawnCasa()
	if casa then casa:Destroy() casa = nil end
	local tmpl = ServerStorage:FindFirstChild("Casa")
	local pos = Chunk:GetCasaPos()
	if not tmpl or not pos then warn("[Mercador] sem ServerStorage.Casa ou posicao") return end
	casa = tmpl:Clone()
	casa.Name = "CasaMercador"
	for _, d in ipairs(casa:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true end
	end
	local porta = casa:FindFirstChild("porta casa", true)
	if porta then porta.CanCollide = false; porta.Transparency = math.max(porta.Transparency, 0.35) end
	local cf, sz = casa:GetBoundingBox()
	local floorOff = (cf.Position.Y - sz.Y / 2) - casa:GetPivot().Position.Y
	-- a porta (lado +X do modelo) fica virada para o Nucleo
	local toCore = Vector3.new(Core.Position.X - pos.X, 0, Core.Position.Z - pos.Z)
	toCore = toCore.Magnitude > 0.1 and toCore.Unit or Vector3.new(1, 0, 0)
	local right = toCore
	local ground = Chunk:HeightAt(pos.X, pos.Z)
	local target = CFrame.fromMatrix(Vector3.new(pos.X, ground - floorOff + 0.05, pos.Z), right, Vector3.yAxis)
	casa:PivotTo(target)
	-- plataforma de grama embaixo da casa (com studs): nunca fica flutuando sobre degraus/vazio
	local base = Instance.new("Part")
	base.Name = "PlataformaGrama"
	base.Anchored = true
	base.Material = Enum.Material.Plastic
	base.Color = Color3.fromRGB(76, 140, 58)
	base.TopSurface = Enum.SurfaceType.Studs
	base.BottomSurface = Enum.SurfaceType.Inlet
	local depth = 24
	base.Size = Vector3.new(sz.X + 22, depth, sz.Z + 14)
	-- um pouco deslocada para a frente (lado da porta) para caber o balcao e o NPC
	base.CFrame = target * CFrame.new(5, 0, 0)
	base.Position = Vector3.new(base.Position.X, ground + 0.05 - depth / 2, base.Position.Z)
	base.Parent = casa
	casa.Parent = workspace
	-- a casa e um bloco macico: o NPC fica na frente da porta, de costas para ela, atras de um balcao
	local floorY = ground + 0.05
	local dz = porta and target:PointToObjectSpace(porta.Position).Z or -5
	local npcPos = (target * CFrame.new(sz.X / 2 + 4, 0, dz)).Position
	npcPos = Vector3.new(npcPos.X, floorY + 3, npcPos.Z)
	local doorDir = (target * CFrame.new(sz.X / 2 + 30, 0, dz)).Position
	-- balcao de madeira com studs
	local balcao = Instance.new("Part")
	balcao.Name = "Balcao"
	balcao.Anchored = true
	balcao.Size = Vector3.new(2, 3, 7)
	balcao.Color = Color3.fromRGB(150, 98, 56)
	balcao.TopSurface = Enum.SurfaceType.Studs
	balcao.CFrame = target * CFrame.new(sz.X / 2 + 6.5, 0, dz)
	balcao.Position = Vector3.new(balcao.Position.X, floorY + 1.5, balcao.Position.Z)
	balcao.Parent = casa
	local npc, root = makeNpc(CFrame.lookAt(npcPos, Vector3.new(doorDir.X, npcPos.Y, doorDir.Z)))
	if npc then npc.Parent = casa; npcRoot = root end
	estado:SetAttribute("CasaPos", pos)
	log("Casa do Mercador em " .. math.floor((pos - Core.Position).Magnitude) .. " studs do Nucleo")
end

function MercadorService:ResetRun()
	for _, p in ipairs(Players:GetPlayers()) do
		for _, a in pairs(ATTR) do p:SetAttribute(a, 0) end
	end
	self:SpawnCasa()
end

local function buy(player, id)
	if typeof(id) ~= "string" then return end
	local it = itemById(id)
	if not it or not npcRoot then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - npcRoot.Position).Magnitude > M.DistanciaLoja then
		remotes.Aviso:FireClient(player, "Chegue perto do Mercador")
		return
	end
	local attr = ATTR[id]
	local lvl = player:GetAttribute(attr) or 0
	local cost = it.Niveis[lvl + 1]
	if not cost then remotes.Aviso:FireClient(player, it.Nome .. ": nível máximo") return end
	if not Coleta:Spend(cost) then
		remotes.Aviso:FireClient(player, (Custos.Falta(estado, cost) or "Materiais insuficientes") .. " no Núcleo")
		return
	end
	player:SetAttribute(attr, lvl + 1)
	remotes.Aviso:FireClient(player, it.Nome .. (#it.Niveis > 1 and (" nível " .. (lvl + 1)) or "") .. " comprado!")
	remotes.Efeito:FireAllClients("MercadorCompra", player, npcRoot.Position, id)
end

function MercadorService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Chunk = require(script.Parent.ChunkService)
	Coleta = require(script.Parent.ColetaService)
	Core = require(script.Parent.CoreService)
	for _, n in ipairs({ "AbrirMercador", "ComprarMercador" }) do
		if not remotes:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
		end
	end
end

function MercadorService:Start()
	remotes.ComprarMercador.OnServerEvent:Connect(buy)
	Players.PlayerAdded:Connect(function(p)
		for _, a in pairs(ATTR) do p:SetAttribute(a, 0) end
	end)
	self:SpawnCasa()
	log("Pronto")
end

return MercadorService
