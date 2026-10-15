-- [ChunkService] Mapa gerado por chunks conforme os jogadores andam (estilo 99 Noites).
-- Tudo e feito de PECAS com textura de studs (estilo Roblox classico). O chao de cada chunk e
-- uma grade de colunas de 6x6 studs cuja altura vem de um ruido suave, arredondado de 1 em 1
-- stud: da colinas e vales naturais em degraus baixinhos (anda-se por cima sem pular).
-- Colunas vizinhas da mesma altura sao fundidas numa peca so (menos pecas, mais leve).
-- So existe uma clareira plana em volta do Nucleo e do spawn; as arvores nascem logo ao redor
-- dela, em manchas de floresta mais densas ou mais abertas. Tudo vem de uma semente da run.
-- Arvores/rochas ganham a tag "Recurso" (o ColetaService cuida delas).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia)
local C = Cfg.Chunk
local R = C.Relevo

local ChunkService = {}
local Core
local chao, recursos, nevoa
local generated = {}   -- "i,j" -> { instancias }
local origin = Vector3.zero
local corePos = Vector3.zero
local spawnPos
local seed, ox, oz = 1, 0, 0
local runId = 0
local decoracoes = {}

local S = C.Tamanho
local CELL = R.Celula or 6
local N = math.floor(S / CELL)
local FUNDO = C.AlturaChao - (R.Fundo or 16)   -- base das colunas (escondida embaixo)
local function log(...) print("[ChunkService]", ...) end
local function key(i, j) return i .. "," .. j end
local function flatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end

function ChunkService:ChunkOf(pos)
	return math.floor((pos.X - origin.X) / S + 0.5), math.floor((pos.Z - origin.Z) / S + 0.5)
end
function ChunkService:CenterOf(i, j)
	return Vector3.new(origin.X + i * S, C.AlturaChao, origin.Z + j * S)
end
local function inLimit(i, j) return math.abs(i) <= C.RaioMaximo and math.abs(j) <= C.RaioMaximo end
function ChunkService:IsGenerated(i, j) return generated[key(i, j)] ~= nil end
function ChunkService:InLimit(pos)
	local i, j = self:ChunkOf(pos)
	return inLimit(i, j)
end

-- RELEVO ----------------------------------------------------------------------------------
local function clamp01(v) return math.clamp(v, 0, 1) end
local function smooth(u) return u * u * (3 - 2 * u) end

-- quanto do relevo vale neste ponto (0 na clareira do Nucleo/spawn, 1 longe)
local function relief(x, z)
	local p = Vector3.new(x, 0, z)
	local a = smooth(clamp01((flatDist(p, corePos) - R.Clareira) / R.Rampa))
	if spawnPos then
		a = math.min(a, smooth(clamp01((flatDist(p, spawnPos) - R.SpawnLivre) / 24)))
	end
	return a
end

-- altura "continua" do relevo
local function rawHeight(x, z)
	local a = relief(x, z)
	if a <= 0 then return C.AlturaChao end
	local e = R.Escala
	local n = math.noise((x + ox) / e, (z + oz) / e, 0.37)
		+ math.noise((x + ox) / (e * 0.45), (z + oz) / (e * 0.45), 4.13) * 0.3
	local h = n * R.Altura
	if h < 0 then h *= 0.6 end   -- colinas sobem mais do que os vales descem
	return C.AlturaChao + h * a
end

-- celula da grade que contem (x, z): o chao e plano dentro de cada celula
local function cellCenter(x, z)
	local cx = origin.X - S / 2 + (math.floor((x - (origin.X - S / 2)) / CELL) + 0.5) * CELL
	local cz = origin.Z - S / 2 + (math.floor((z - (origin.Z - S / 2)) / CELL) + 0.5) * CELL
	return cx, cz
end

-- altura do topo do chao (em degraus de 1 stud) - usada para arvores, rochas e decoracao
function ChunkService:HeightAt(x, z)
	local cx, cz = cellCenter(x, z)
	return math.floor(rawHeight(cx, cz) + 0.5)
end

-- densidade da floresta (manchas): 0 = campo aberto, 1 = mata fechada
local function forest(x, z)
	return clamp01(math.noise((x + ox) / 85, (z + oz) / 85, 9.1) * 1.4 + 0.55)
end

-- cor do chao: mais clara nas partes altas, mais escura nos vales (como no video)
local GRAMA_BAIXA = Color3.fromRGB(64, 128, 52)
local GRAMA_ALTA = Color3.fromRGB(110, 170, 70)
local function groundColor(h, x, z)
	local u = clamp01((h - (C.AlturaChao - R.Altura * 0.4)) / (R.Altura * 1.2))
	local c = GRAMA_BAIXA:Lerp(GRAMA_ALTA, u)
	local k = 1 + math.noise((x + ox) / 30, (z + oz) / 30, 5.5) * 0.12
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- PECAS ----------------------------------------------------------------------------------
-- tudo com studs em cima (estilo classico)
local function part(parent, size, cf, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	p.CanCollide = o.collide ~= false
	p.CanTouch = false
	p.CanQuery = o.query ~= false
	p.CastShadow = o.shadow ~= false
	if o.name then p.Name = o.name end
	p.Parent = parent
	return p
end

local function writeGround(i, j, list)
	local c = ChunkService:CenterOf(i, j)
	local x0, z0 = c.X - S / 2, c.Z - S / 2
	for iz = 1, N do
		local z = z0 + (iz - 0.5) * CELL
		-- funde colunas seguidas da mesma altura numa peca so
		local runStart, runH = 1, nil
		local hs = table.create(N)
		for ix = 1, N do
			local x = x0 + (ix - 0.5) * CELL
			hs[ix] = math.floor(rawHeight(x, z) + 0.5)
		end
		for ix = 1, N + 1 do
			local h = hs[ix]
			if ix == 1 then
				runH = h
			elseif h ~= runH then
				local w = (ix - runStart) * CELL
				local xc = x0 + (runStart - 1) * CELL + w / 2
				local top = runH
				local p = part(chao, Vector3.new(w, top - FUNDO, CELL), CFrame.new(xc, (top + FUNDO) / 2, z), groundColor(top, xc, z), { name = "Chao" })
				table.insert(list, p)
				runStart, runH = ix, h
			end
		end
	end
end

local function shade(c, rng, amt)
	local k = 1 + rng:NextNumber(-amt, amt)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- arvore "carvalho" blocada (copa quadrada como no video)
local function buildArvore(pos, rng)
	local m = Instance.new("Model")
	m.Name = "Arvore"
	local h = rng:NextNumber(10, 16)
	local w = math.floor(rng:NextNumber(2, 3.5) + 0.5)
	local rot = CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
	local base = CFrame.new(pos) * rot
	local tronco = part(m, Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), shade(Color3.fromRGB(112, 76, 46), rng, 0.1), { name = "Tronco" })
	local leaf = shade(Color3.fromRGB(62, 128, 50), rng, 0.14)
	local cw = math.floor(rng:NextNumber(9, 13) + 0.5)
	part(m, Vector3.new(cw, math.floor(rng:NextNumber(6, 8) + 0.5), cw), base * CFrame.new(0, h + 2, 0), leaf, { name = "Folhas", collide = false })
	if rng:NextNumber() < 0.7 then
		local c2 = math.floor(cw * rng:NextNumber(0.55, 0.75) + 0.5)
		part(m, Vector3.new(c2, 4, c2), base * CFrame.new(rng:NextInteger(-2, 2), h + 7, rng:NextInteger(-2, 2)), shade(leaf, rng, 0.08), { name = "Folhas", collide = false })
	end
	m.PrimaryPart = tronco
	return m
end

local function buildPinheiro(pos, rng)
	local m = Instance.new("Model")
	m.Name = "Pinheiro"
	local h = rng:NextNumber(13, 19)
	local rot = CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
	local base = CFrame.new(pos) * rot
	local tronco = part(m, Vector3.new(2, h, 2), base * CFrame.new(0, h / 2, 0), shade(Color3.fromRGB(100, 68, 42), rng, 0.1), { name = "Tronco" })
	local leaf = shade(Color3.fromRGB(40, 100, 52), rng, 0.14)
	local camadas = { { 9, 5, 0.42 }, { 7, 5, 0.66 }, { 4, 4, 0.88 }, { 2, 3, 1.02 } }
	for _, c in ipairs(camadas) do
		part(m, Vector3.new(c[1], c[2], c[1]), base * CFrame.new(0, h * c[3], 0), leaf, { name = "Folhas", collide = false })
	end
	m.PrimaryPart = tronco
	return m
end

local function buildRocha(pos, rng)
	local m = Instance.new("Model")
	m.Name = "Rocha"
	local cor = shade(Color3.fromRGB(150, 150, 155), rng, 0.1)
	local big = Vector3.new(rng:NextInteger(4, 6), rng:NextInteger(3, 4), rng:NextInteger(4, 5))
	local rot = CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
	local main = part(m, big, CFrame.new(pos + Vector3.new(0, big.Y / 2, 0)) * rot, cor, { name = "Pedra" })
	for _ = 1, rng:NextInteger(1, 3) do
		local s = Vector3.new(rng:NextInteger(2, 3), rng:NextInteger(1, 2), rng:NextInteger(2, 3))
		local off = Vector3.new(rng:NextInteger(-2, 2), 0, rng:NextInteger(-2, 2))
		local y = ChunkService:HeightAt(pos.X + off.X, pos.Z + off.Z)
		part(m, s, CFrame.new(pos.X + off.X, y + s.Y / 2, pos.Z + off.Z) * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0), shade(cor, rng, 0.1), { name = "Pedra" })
	end
	m.PrimaryPart = main
	return m
end

local BUILDERS = { Arvore = buildArvore, Pinheiro = buildPinheiro, Rocha = buildRocha }

local function registerResource(m, kind, chunkKey)
	local r = Cfg.Recursos[kind]
	m:SetAttribute("Recurso", kind)
	m:SetAttribute("Vida", r.Vida)
	m:SetAttribute("VidaMax", r.Vida)
	m:SetAttribute("Chunk", chunkKey)
	CollectionService:AddTag(m, "Recurso")
	m.Parent = recursos
end

-- GERACAO -------------------------------------------------------------------------------
local function chunkRng(i, j)
	return Random.new((seed * 31 + (i + 1000) * 7919 + (j + 1000) * 104729) % 2147483647)
end

-- livre de arvores/rochas? (clareira do Nucleo, spawn dos jogadores)
local function freeSpot(p)
	if flatDist(p, corePos) < R.Clareira + 2 then return false end
	if spawnPos and flatDist(p, spawnPos) < R.SpawnLivre + 4 then return false end
	return true
end

local function generate(i, j)
	local k = key(i, j)
	if generated[k] or not inLimit(i, j) then return end
	local rng = chunkRng(i, j)
	local list = {}
	generated[k] = list
	writeGround(i, j, list)
	local center = ChunkService:CenterOf(i, j)
	local used = {}
	-- pontos no meio de uma celula (assim tronco e pedra ficam em cima de um degrau so)
	local function spot(margin, spacing, avoidClear)
		for _ = 1, 14 do
			local x = center.X + rng:NextNumber(-S / 2 + margin, S / 2 - margin)
			local z = center.Z + rng:NextNumber(-S / 2 + margin, S / 2 - margin)
			x, z = cellCenter(x, z)
			local p = Vector3.new(x, 0, z)
			local ok = (not avoidClear) or freeSpot(p)
			if ok then
				for _, u in ipairs(used) do
					if (p - u).Magnitude < spacing then ok = false break end
				end
			end
			if ok then
				table.insert(used, p)
				return Vector3.new(x, ChunkService:HeightAt(x, z), z)
			end
		end
		return nil
	end
	-- arvores: mais densas nas manchas de floresta e num anel logo depois da clareira do Nucleo
	local dens = forest(center.X, center.Z)
	local dCore = flatDist(center, corePos)
	if dCore < R.Clareira + 60 then dens = math.max(dens, R.AnelFloresta or 0.55) end
	local nArv = math.floor(C.Arvores[1] + (C.Arvores[2] - C.Arvores[1]) * dens + rng:NextNumber(-0.5, 0.99))
	for _ = 1, math.max(0, nArv) do
		local p = spot(3, C.DistanciaArvores, true)
		if p then
			local kind = rng:NextNumber() < 0.45 and "Pinheiro" or "Arvore"
			local m = BUILDERS[kind](p, rng)
			registerResource(m, kind, k)
			table.insert(list, m)
		end
	end
	for _ = 1, rng:NextInteger(C.Rochas[1], C.Rochas[2] + (dens < 0.3 and 1 or 0)) do
		local p = spot(4, 8, true)
		if p then
			local m = buildRocha(p, rng)
			registerResource(m, "Rocha", k)
			table.insert(list, m)
		end
	end
	if #decoracoes > 0 then
		for _ = 1, rng:NextInteger(C.Decoracao[1], C.Decoracao[2]) do
			local p = spot(1, 3, false)
			if p and flatDist(p, corePos) > 12 then
				local d = decoracoes[rng:NextInteger(1, #decoracoes)]:Clone()
				d:PivotTo(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				d.Parent = chao
				table.insert(list, d)
			end
		end
	end
end

local function clearAll()
	for _, list in pairs(generated) do
		for _, inst in ipairs(list) do inst:Destroy() end
	end
	generated = {}
	recursos:ClearAllChildren()
	chao:ClearAllChildren()
end

-- gera em volta de um ponto, do mais perto para o mais longe
local function wanted(ci, cj, radius)
	local out = {}
	for i = ci - radius, ci + radius do
		for j = cj - radius, cj + radius do
			if inLimit(i, j) and not generated[key(i, j)] then
				table.insert(out, { i, j, (i - ci) ^ 2 + (j - cj) ^ 2 })
			end
		end
	end
	table.sort(out, function(a, b) return a[3] < b[3] end)
	return out
end

function ChunkService:GenerateAround(pos, radius, budget)
	local ci, cj = self:ChunkOf(pos)
	local n = 0
	for _, c in ipairs(wanted(ci, cj, radius)) do
		generate(c[1], c[2])
		n += 1
		if budget and n >= budget then break end
	end
	return n
end

-- PAREDE DE NEBLINA NO LIMITE (branca, junto com a neblina do Atmosphere no cliente) ------------
local function buildFogWall()
	nevoa:ClearAllChildren()
	local half = (C.RaioMaximo + 0.5) * S
	local seg = 72
	local n = math.ceil(half * 2 / seg)
	local sides = {
		{ Vector3.new(0, 0, -half), true }, { Vector3.new(0, 0, half), true },
		{ Vector3.new(-half, 0, 0), false }, { Vector3.new(half, 0, 0), false },
	}
	for _, sd in ipairs(sides) do
		for s = 1, n do
			local along = -half + (s - 0.5) * seg
			local off = sd[2] and Vector3.new(along, 0, 0) or Vector3.new(0, 0, along)
			local pos = Vector3.new(origin.X, C.AlturaChao + 30, origin.Z) + sd[1] + off
			local size = sd[2] and Vector3.new(seg, 80, 4) or Vector3.new(4, 80, seg)
			local wall = part(nevoa, size, CFrame.new(pos), Color3.new(1, 1, 1), { name = "ParedeNevoa", shadow = false })
			wall.Transparency = 1
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(250, 251, 255))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 20) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(5, 8)
			e.Rate = 8
			e.Speed = NumberRange.new(0.4, 1.4)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.LightInfluence = 0.3
			e.Parent = wall
		end
	end
end

-- RUN -------------------------------------------------------------------------------------
local function newSeed()
	seed = Random.new():NextInteger(1, 1e8)
	local r = Random.new(seed)
	ox, oz = r:NextNumber(-5000, 5000), r:NextNumber(-5000, 5000)
end

function ChunkService:ResetRun()
	runId += 1
	local my = runId
	clearAll()
	newSeed()
	-- o centro fica pronto na hora (ninguem nasce caindo na agua)
	self:GenerateAround(origin, C.Sincrono)
	task.spawn(function()
		while runId == my do
			local n = self:GenerateAround(origin, C.RaioInicial, 4)
			if n == 0 then break end
			task.wait()
		end
		log("Mapa inicial pronto (semente " .. seed .. ")")
	end)
end

function ChunkService:Init()
	Core = require(script.Parent.CoreService)
	chao = workspace:FindFirstChild("Chunks") or Instance.new("Folder")
	chao.Name = "Chunks"
	chao.Parent = workspace
	recursos = workspace:FindFirstChild("Recursos") or Instance.new("Folder")
	recursos.Name = "Recursos"
	recursos.Parent = workspace
	nevoa = workspace:FindFirstChild("NevoaLimite") or Instance.new("Folder")
	nevoa.Name = "NevoaLimite"
	nevoa.Parent = workspace
	local dec = ServerStorage:FindFirstChild("Recursos")
	dec = dec and dec:FindFirstChild("Decoracao")
	if dec then
		for _, d in ipairs(dec:GetChildren()) do
			if d:IsA("Model") then
				for _, p in ipairs(d:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false end
				end
				table.insert(decoracoes, d)
			end
		end
	end
	corePos = Core.Position
	origin = Vector3.new(corePos.X, C.AlturaChao, corePos.Z)
	local sp = workspace:FindFirstChild("SpawnJogadores", true)
	spawnPos = sp and sp.Position or nil
	buildFogWall()
	-- chao do centro pronto antes de qualquer jogador nascer
	self:ResetRun()
end

function ChunkService:Start()
	-- gera conforme os jogadores andam
	task.spawn(function()
		while true do
			task.wait(C.Intervalo)
			local budget = C.PorPasso
			for _, pl in ipairs(Players:GetPlayers()) do
				local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if root and pl:GetAttribute("EmJogo") == true and budget > 0 then
					budget -= self:GenerateAround(root.Position, C.RaioGeracao, budget)
				end
			end
		end
	end)
	log("Pronto. Chunk " .. S .. " studs, celula " .. CELL .. ", relevo " .. R.Altura .. " studs")
end

return ChunkService
