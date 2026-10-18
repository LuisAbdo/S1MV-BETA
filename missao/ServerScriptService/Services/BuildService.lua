-- [BuildService] Estruturas da Loja do Nucleo: colocacao validada no servidor,
-- vida/escudo, reparar/vender e um unico scheduler para torretas, minas, drone e gerador.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local SONS = require(Shared.Config.Sons)
local Custos = require(Shared.Custos)
local C = Shop.Construcao

-- SONS (posicionais) -------------------------------------------------------
local function sfx(parent, def, looped, maxDist)
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.V or 0.5
	s.PlaybackSpeed = def.P or 1
	s.Looped = looped or false
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = maxDist or 110
	s.Parent = parent
	return s
end
local function soundAt(pos, def, pitchJitter)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = sfx(a, def)
	if pitchJitter then s.PlaybackSpeed *= 1 + (math.random() - 0.5) * pitchJitter end
	s:Play()
	Debris:AddItem(a, 4)
end
local TIRO = { TorretaBasica = SONS.TorretaTiro, TorretaGelo = SONS.TorretaGelo, TorretaPesada = SONS.TorretaPesada }

local BuildService = {}
local remotes, estado, Core, Enemy, Economy, Coleta
local folder, fxFolder
local structures = {}   -- model -> data
local counts = {}       -- userId -> { total = n, [key] = n }
local total = 0
local lastPlace = {}

local function log(...) print("[BuildService]", ...) end

-- MODELOS (estilo studs) -------------------------------------------------
local function P(model, cf, size, offset, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf * offset
	p.Color = color
	p.Material = o.neon and Enum.Material.Neon or (o.material or Enum.Material.Plastic)
	p.TopSurface = o.smooth and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
	p.BottomSurface = o.smooth and Enum.SurfaceType.Smooth or Enum.SurfaceType.Inlet
	if o.shape then p.Shape = o.shape; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if o.transparency then p.Transparency = o.transparency end
	p.Name = o.name or "Peca"
	p.Parent = o.parent or model
	return p
end

local WOOD, WOOD2, WOODD = Color3.fromRGB(145, 98, 60), Color3.fromRGB(124, 82, 50), Color3.fromRGB(92, 60, 38)
local STONE, STONE2 = Color3.fromRGB(163, 162, 165), Color3.fromRGB(130, 128, 132)
local METAL, METAL2 = Color3.fromRGB(70, 72, 78), Color3.fromRGB(110, 112, 120)

local function turretHead(model, cf, y, kind)
	local head = Instance.new("Model")
	head.Name = "Cabeca"
	head.Parent = model
	local hc = cf * CFrame.new(0, y, 0)
	local body, barrelColor, accent
	if kind == "TorretaGelo" then
		body = P(model, hc, Vector3.new(2.6, 2, 2.6), CFrame.new(), Color3.fromRGB(235, 245, 255), { parent = head, name = "Corpo" })
		accent = Color3.fromRGB(120, 230, 255)
		barrelColor = Color3.fromRGB(200, 240, 255)
	elseif kind == "LancaChamas" then
		body = P(model, hc, Vector3.new(2.6, 2, 2.6), CFrame.new(), Color3.fromRGB(60, 50, 50), { parent = head, name = "Corpo" })
		accent = Color3.fromRGB(255, 130, 30)
		barrelColor = METAL
	elseif kind == "TorretaPesada" then
		body = P(model, hc, Vector3.new(4, 2.6, 4), CFrame.new(), Color3.fromRGB(70, 90, 60), { parent = head, name = "Corpo" })
		accent = Color3.fromRGB(255, 210, 60)
		barrelColor = METAL
	else
		body = P(model, hc, Vector3.new(2.6, 2, 2.6), CFrame.new(), METAL2, { parent = head, name = "Corpo" })
		accent = Color3.fromRGB(13, 105, 172)
		barrelColor = METAL
	end
	P(model, hc, Vector3.new(body.Size.X + 0.1, 0.35, body.Size.Z + 0.1), CFrame.new(0, 0.3, 0), accent, { parent = head, neon = kind ~= "TorretaBasica", smooth = true, name = "Faixa" })
	local muzzle
	if kind == "TorretaPesada" then
		for _, sx in ipairs({ -0.8, 0.8 }) do
			P(model, hc, Vector3.new(0.8, 0.8, 4), CFrame.new(sx, 0, -3.2), barrelColor, { parent = head, name = "Cano" })
		end
		muzzle = P(model, hc, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, -5.3), accent, { parent = head, neon = true, smooth = true, name = "Boca", transparency = 1 })
	elseif kind == "LancaChamas" then
		P(model, hc, Vector3.new(1, 1, 2.6), CFrame.new(0, 0, -2.2), barrelColor, { parent = head, name = "Cano" })
		muzzle = P(model, hc, Vector3.new(1.1, 1.1, 0.4), CFrame.new(0, 0, -3.6), accent, { parent = head, neon = true, smooth = true, name = "Boca" })
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Chamas"
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new(1, 4)
		fire.Transparency = NumberSequence.new(0.2, 1)
		fire.Lifetime = NumberRange.new(0.35, 0.5)
		fire.Speed = NumberRange.new(30, 38)
		fire.SpreadAngle = Vector2.new(14, 14)
		fire.Rate = 70
		fire.EmissionDirection = Enum.NormalId.Front
		fire.Enabled = false
		fire.Parent = muzzle
	else
		P(model, hc, Vector3.new(0.6, 0.6, 2.8), CFrame.new(0, 0, -2.6), barrelColor, { parent = head, name = "Cano" })
		muzzle = P(model, hc, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0, -4.1), accent, { parent = head, neon = true, smooth = true, name = "Boca", transparency = 1 })
	end
	head.PrimaryPart = body
	return head, muzzle, accent
end

local builders = {}
builders.Barricada = function(model, cf, s)
	for _, x in ipairs({ -3.5, 3.5 }) do P(model, cf, Vector3.new(1, 5, 1), CFrame.new(x, 2.5, 0), WOODD) end
	for i, y in ipairs({ 1.1, 2.6, 4.1 }) do P(model, cf, Vector3.new(8, 1.2, 0.7), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(i == 2 and -3 or 2)), i % 2 == 0 and WOOD2 or WOOD) end
	P(model, cf, Vector3.new(8.6, 0.6, 1.6), CFrame.new(0, 0.3, 0), WOODD)
end
builders.BarricadaReforcada = function(model, cf, s)
	for _, x in ipairs({ -3.5, 3.5 }) do P(model, cf, Vector3.new(1.2, 6, 1.2), CFrame.new(x, 3, 0), METAL) end
	for i, y in ipairs({ 1, 2.5, 4, 5.4 }) do P(model, cf, Vector3.new(8, 1.3, 1), CFrame.new(0, y, 0), i % 2 == 0 and WOOD2 or WOOD) end
	for _, x in ipairs({ -1.8, 1.8 }) do P(model, cf, Vector3.new(0.5, 6, 1.2), CFrame.new(x, 3, 0), METAL2) end
	for _, x in ipairs({ -3.5, 3.5 }) do P(model, cf, Vector3.new(1.4, 0.6, 1.4), CFrame.new(x, 6.2, 0), METAL2) end
end
builders.Muro = function(model, cf, s)
	for r = 0, 3 do
		local off = (r % 2 == 0) and 0 or 1.25
		for i = -2, 2 do
			local x = i * 2.5 + off
			if math.abs(x) <= 4 then
				P(model, cf, Vector3.new(2.4, 1.7, 3), CFrame.new(x, 0.85 + r * 1.75, 0), (i + r) % 2 == 0 and STONE or STONE2)
			end
		end
	end
	P(model, cf, Vector3.new(10.4, 0.6, 3.4), CFrame.new(0, 7.1, 0), STONE2)
end
-- portao: dois pilares de pedra e duas folhas de madeira que abrem quando um jogador chega perto
builders.Portao = function(model, cf, s)
	for _, side in ipairs({ -1, 1 }) do
		for r = 0, 3 do
			P(model, cf, Vector3.new(1.9, 1.9, 3.2), CFrame.new(side * 5.05, 0.95 + r * 1.9, 0), (r % 2 == 0) and STONE or STONE2)
		end
		P(model, cf, Vector3.new(2.3, 0.6, 3.5), CFrame.new(side * 5.05, 7.9, 0), STONE2)
	end
	P(model, cf, Vector3.new(12.4, 1, 3.4), CFrame.new(0, 7.6, 0), STONE2)
	P(model, cf, Vector3.new(8, 0.5, 3), CFrame.new(0, 6.85, 0), STONE)
	for _, side in ipairs({ -1, 1 }) do
		local door = Instance.new("Model")
		door.Name = side < 0 and "PortaE" or "PortaD"
		door.Parent = model
		-- dobradica no pilar; a folha vai ate o meio
		local hinge = cf * CFrame.new(side * 4.05, 0, 0)
		local panel = P(model, hinge, Vector3.new(4, 6.4, 0.5), CFrame.new(-side * 2, 3.3, 0), WOOD, { parent = door, name = "Folha" })
		for _, y in ipairs({ 1.3, 5.3 }) do
			P(model, hinge, Vector3.new(4.1, 0.45, 0.65), CFrame.new(-side * 2, y, 0), WOODD, { parent = door })
		end
		P(model, hinge, Vector3.new(0.4, 0.4, 0.8), CFrame.new(-side * 3.4, 3.3, 0), METAL2, { parent = door })
		door.PrimaryPart = panel
		door:SetAttribute("Lado", side)
		door:SetAttribute("Dobradica", hinge)
	end
end

-- PECAS DE GRADE (fechar a base em 360°) -----------------------------------------------------
local function mainOf(model) return model:FindFirstChild("Base") end

builders.PisoReforcado = function(model, cf, s)
	for ix = -1, 1, 2 do
		for iz = -1, 1, 2 do
			P(model, cf, Vector3.new(3.9, 1, 3.9), CFrame.new(ix * 2, 0.5, iz * 2), (ix + iz) == 0 and STONE or STONE2)
		end
	end
	P(model, cf, Vector3.new(8.2, 0.3, 0.6), CFrame.new(0, 1.1, 0), WOODD)
	P(model, cf, Vector3.new(0.6, 0.3, 8.2), CFrame.new(0, 1.1, 0), WOODD)
end

builders.Teto = function(model, cf, s)
	for i = -1, 1 do
		P(model, cf, Vector3.new(8, 0.8, 2.6), CFrame.new(0, 0.4, i * 2.7), i == 0 and WOOD2 or WOOD)
	end
	P(model, cf, Vector3.new(8.4, 0.3, 8.4), CFrame.new(0, 0.95, 0), WOODD)
end

builders.Rampa = function(model, cf, s)
	local main = mainOf(model)
	if main then main.CanCollide = false end
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = s
	w.CFrame = cf * CFrame.new(0, s.Y / 2, 0)
	w.Color = WOOD
	w.TopSurface = Enum.SurfaceType.Studs
	w.CanCollide = true
	w.CanQuery = false
	w.CanTouch = false
	w.Name = "Rampa"
	w.Parent = model
	for i = 1, 4 do
		local z = s.Z / 2 - i * (s.Z / 5)
		local h = s.Y * (i / 5)
		P(model, cf, Vector3.new(s.X + 0.2, 0.3, 0.5), CFrame.new(0, h + 0.1, z) * CFrame.Angles(math.atan2(s.Y, s.Z), 0, 0), WOODD)
	end
end

-- muro com fenda: a parte de baixo segura os veritys; a de cima so bloqueia corpos (os tiros passam)
builders.MuroTiro = function(model, cf, s)
	local main = mainOf(model)
	if main then
		main.Size = Vector3.new(s.X, 3.6, s.Z)
		main.CFrame = cf * CFrame.new(0, 1.8, 0)
	end
	for r = 0, 1 do
		for i = -2, 2 do
			local x = i * 2.5 + ((r % 2 == 0) and 0 or 1.25)
			if math.abs(x) <= 4 then P(model, cf, Vector3.new(2.4, 1.75, s.Z), CFrame.new(x, 0.9 + r * 1.8, 0), (i + r) % 2 == 0 and STONE or STONE2) end
		end
	end
	local top = P(model, cf, Vector3.new(s.X + 0.2, 1.8, s.Z), CFrame.new(0, 6.1, 0), STONE2, { name = "Topo" })
	top.CanCollide = true -- corpo nao passa, raycast (tiro) passa
	for _, x in ipairs({ -4.4, 4.4 }) do
		local pil = P(model, cf, Vector3.new(1.2, 1.6, s.Z), CFrame.new(x, 4.4, 0), STONE, { name = "Pilar" })
		pil.CanCollide = true
	end
	P(model, cf, Vector3.new(7.6, 0.2, s.Z + 0.1), CFrame.new(0, 3.65, 0), METAL)
end

-- ARMADILHAS DE CHAO --------------------------------------------------------------------------
builders.Espinhos = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, 0.4, s.Z), CFrame.new(0, 0.2, 0), METAL)
	for ix = -2, 2 do
		for iz = -2, 2 do
			if (ix + iz) % 2 == 0 then
				local sp = Instance.new("WedgePart")
				sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.CanTouch = false
				sp.Size = Vector3.new(0.5, 1.2, 0.5)
				sp.Color = METAL2
				sp.CFrame = cf * CFrame.new(ix * 1.1, 1, iz * 1.1)
				sp.Name = "Espinho"
				sp.Parent = model
			end
		end
	end
end

builders.Lentidao = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, 0.3, s.Z), CFrame.new(0, 0.15, 0), Color3.fromRGB(60, 50, 40))
	P(model, cf, Vector3.new(s.X - 0.8, 0.2, s.Z - 0.8), CFrame.new(0, 0.35, 0), Color3.fromRGB(140, 210, 255), { material = Enum.Material.Ice, smooth = true })
end

builders.Quicador = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, 0.5, s.Z), CFrame.new(0, 0.25, 0), METAL)
	P(model, cf, Vector3.new(0.8, 0.6, 0.8), CFrame.new(0, 0.8, 0), METAL2, { name = "Mola" })
	local pad = P(model, cf, Vector3.new(s.X - 0.6, 0.35, s.Z - 0.6), CFrame.new(0, 1.15, 0), Color3.fromRGB(255, 205, 60), { name = "Tampa" })
	return pad
end

-- ARMADILHAS DE PAREDE ------------------------------------------------------------------------
builders.LancaDardos = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, s.Y, s.Z), CFrame.new(0, s.Y / 2, 0), STONE2)
	local bico = P(model, cf, Vector3.new(0.9, 0.9, 1.2), CFrame.new(0, s.Y * 0.55, -s.Z / 2 - 0.5), METAL, { name = "Bico" })
	P(model, cf, Vector3.new(0.4, 0.4, 0.2), CFrame.new(0, s.Y * 0.55, -s.Z / 2 - 1.15), Color3.fromRGB(255, 80, 60), { neon = true })
	return nil, bico
end

builders.Repulsor = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, s.Y, s.Z), CFrame.new(0, s.Y / 2, 0), METAL)
	local disco = P(model, cf, Vector3.new(0.4, 3, 3), CFrame.new(0, s.Y * 0.55, -s.Z / 2 - 0.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 200, 255), { neon = true, shape = Enum.PartType.Cylinder, name = "Disco" })
	return nil, disco, disco
end

-- ARMADILHAS DE TETO (portico: os veritys passam por baixo) ------------------------------------
local function portico(model, cf, s, cor)
	for _, x in ipairs({ -s.X / 2 + 0.6, s.X / 2 - 0.6 }) do
		for _, z in ipairs({ -s.Z / 2 + 0.6, s.Z / 2 - 0.6 }) do
			P(model, cf, Vector3.new(1.2, s.Y, 1.2), CFrame.new(x, s.Y / 2, z), cor)
		end
	end
	P(model, cf, Vector3.new(s.X, 1, s.Z), CFrame.new(0, s.Y - 0.5, 0), cor)
end

builders.Prensa = function(model, cf, s)
	portico(model, cf, s, METAL)
	local head = Instance.new("Model")
	head.Name = "Prensa"
	head.Parent = model
	local bloco = P(model, cf, Vector3.new(s.X - 2.6, 1.6, s.Z - 2.6), CFrame.new(0, s.Y - 1.9, 0), METAL2, { parent = head, name = "Bloco" })
	P(model, cf, Vector3.new(0.8, 1.2, 0.8), CFrame.new(0, s.Y - 0.9, 0), METAL, { parent = head })
	head.PrimaryPart = bloco
	return head
end

builders.EmissorGas = function(model, cf, s)
	portico(model, cf, s, Color3.fromRGB(70, 90, 70))
	local bico = P(model, cf, Vector3.new(2, 1, 2), CFrame.new(0, s.Y - 1.5, 0), Color3.fromRGB(110, 200, 90), { neon = true, name = "Bico" })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(140, 230, 110))
	e.Size = NumberSequence.new(2, 5)
	e.Transparency = NumberSequence.new(0.5, 1)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Speed = NumberRange.new(2, 5)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.Rate = 0
	e.Name = "Gas"
	e.Parent = bico
	return nil, bico
end

-- DEFESAS AVANCADAS ---------------------------------------------------------------------------
builders.CampoForca = function(model, cf, s)
	for _, x in ipairs({ -s.X / 2 + 0.6, s.X / 2 - 0.6 }) do
		P(model, cf, Vector3.new(1.2, s.Y, 1.2), CFrame.new(x, s.Y / 2, 0), METAL)
		P(model, cf, Vector3.new(1.4, 0.6, 1.4), CFrame.new(x, s.Y + 0.3, 0), Color3.fromRGB(90, 200, 255), { neon = true })
	end
	local f = P(model, cf, Vector3.new(s.X - 2.4, s.Y - 0.6, 0.15), CFrame.new(0, s.Y / 2, 0), Color3.fromRGB(110, 210, 255), { neon = true, transparency = 0.65, name = "Laser" })
	return nil, nil, f
end

builders.Cupula = function(model, cf, s)
	P(model, cf, Vector3.new(s.X, 1.2, s.Z), CFrame.new(0, 0.6, 0), METAL)
	P(model, cf, Vector3.new(2, s.Y - 1.2, 2), CFrame.new(0, 0.6 + (s.Y - 1.2) / 2, 0), METAL2)
	local orb = P(model, cf, Vector3.one * 2, CFrame.new(0, s.Y + 0.4, 0), Color3.fromRGB(150, 120, 255), { neon = true, shape = Enum.PartType.Ball, name = "Orbe" })
	return nil, nil, orb
end

builders.GradeEletrica = function(model, cf, s)
	for _, side in ipairs({ -1, 1 }) do
		P(model, cf, Vector3.new(1.6, s.Y, s.Z), CFrame.new(side * (s.X / 2 - 0.8), s.Y / 2, 0), METAL)
		P(model, cf, Vector3.new(1.8, 0.5, s.Z + 0.2), CFrame.new(side * (s.X / 2 - 0.8), s.Y + 0.25, 0), Color3.fromRGB(255, 220, 60), { neon = true })
	end
	for _, side in ipairs({ -1, 1 }) do
		local door = Instance.new("Model")
		door.Name = side < 0 and "PortaE" or "PortaD"
		door.Parent = model
		local hinge = cf * CFrame.new(side * (s.X / 2 - 1.6), 0, 0)
		local w = s.X / 2 - 1.6
		local frame = P(model, hinge, Vector3.new(w, s.Y - 1.2, 0.3), CFrame.new(-side * w / 2, s.Y / 2, 0), METAL2, { parent = door, name = "Folha", transparency = 0.2 })
		for k = 1, 4 do
			P(model, hinge, Vector3.new(0.15, s.Y - 1.6, 0.35), CFrame.new(-side * w * k / 5, s.Y / 2, 0), Color3.fromRGB(255, 220, 60), { parent = door, neon = true })
		end
		door.PrimaryPart = frame
		door:SetAttribute("Lado", side)
		door:SetAttribute("Dobradica", hinge)
	end
end

builders.Mina = function(model, cf, s)
	P(model, cf, Vector3.new(0.6, 3, 3), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(45, 45, 50), { shape = Enum.PartType.Cylinder })
	P(model, cf, Vector3.new(0.3, 1.8, 1.8), CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 90, 95), { shape = Enum.PartType.Cylinder })
	P(model, cf, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1, 0), Color3.fromRGB(255, 40, 40), { neon = true, smooth = true, name = "Luz" })
end
local function turretBase(model, cf, w)
	P(model, cf, Vector3.new(w, 1.6, w), CFrame.new(0, 0.8, 0), STONE2)
	P(model, cf, Vector3.new(w - 1.2, 0.5, w - 1.2), CFrame.new(0, 1.85, 0), METAL)
	P(model, cf, Vector3.new(1.6, 2, 1.6), CFrame.new(0, 3, 0), METAL)
end
builders.TorretaBasica = function(model, cf, s) turretBase(model, cf, 4); return turretHead(model, cf, 4.9, "TorretaBasica") end
builders.TorretaGelo = function(model, cf, s) turretBase(model, cf, 4); return turretHead(model, cf, 4.9, "TorretaGelo") end
builders.LancaChamas = function(model, cf, s) turretBase(model, cf, 4); return turretHead(model, cf, 4.9, "LancaChamas") end
builders.TorretaPesada = function(model, cf, s)
	P(model, cf, Vector3.new(6, 2, 6), CFrame.new(0, 1, 0), STONE2)
	P(model, cf, Vector3.new(5, 0.6, 5), CFrame.new(0, 2.3, 0), METAL)
	P(model, cf, Vector3.new(2.4, 2, 2.4), CFrame.new(0, 3.6, 0), METAL)
	return turretHead(model, cf, 5.8, "TorretaPesada")
end
builders.Drone = function(model, cf, s)
	P(model, cf, Vector3.new(4, 0.6, 4), CFrame.new(0, 0.3, 0), METAL2)
	P(model, cf, Vector3.new(3.4, 0.15, 0.6), CFrame.new(0, 0.66, 0), Color3.fromRGB(80, 230, 110), { neon = true, smooth = true })
	P(model, cf, Vector3.new(0.6, 0.15, 3.4), CFrame.new(0, 0.66, 0), Color3.fromRGB(80, 230, 110), { neon = true, smooth = true })
	local drone = Instance.new("Model")
	drone.Name = "DroneVoador"
	drone.Parent = model
	local dc = cf * CFrame.new(0, 5, 0)
	local body = P(model, dc, Vector3.new(1.8, 0.9, 1.8), CFrame.new(), Color3.fromRGB(240, 240, 240), { parent = drone, name = "Corpo" })
	P(model, dc, Vector3.new(0.7, 0.4, 0.7), CFrame.new(0, -0.6, 0), Color3.fromRGB(80, 230, 110), { parent = drone, neon = true, smooth = true })
	for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(model, dc, Vector3.new(0.3, 0.3, 0.3), CFrame.new(c[1] * 1.3, 0.2, c[2] * 1.3), METAL, { parent = drone, smooth = true })
		P(model, dc, Vector3.new(1.4, 0.1, 0.25), CFrame.new(c[1] * 1.3, 0.4, c[2] * 1.3), METAL2, { parent = drone, smooth = true, name = "Helice" })
	end
	drone.PrimaryPart = body
	return nil, nil, nil, drone
end
builders.GeradorEscudo = function(model, cf, s)
	P(model, cf, Vector3.new(5, 1.4, 5), CFrame.new(0, 0.7, 0), STONE2)
	P(model, cf, Vector3.new(1.6, 6, 1.6), CFrame.new(0, 4.4, 0), METAL)
	for i, y in ipairs({ 3, 5, 7 }) do
		P(model, cf, Vector3.new(2.6, 0.4, 2.6), CFrame.new(0, y, 0), Color3.fromRGB(0, 229, 255), { neon = true, smooth = true })
	end
	P(model, cf, Vector3.new(2, 2, 2), CFrame.new(0, 8.2, 0), Color3.fromRGB(150, 245, 255), { shape = Enum.PartType.Ball, neon = true })
	local r = Shop.Estruturas.GeradorEscudo.Raio
	P(model, cf, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(0, 0, 0), Color3.fromRGB(120, 220, 255), { shape = Enum.PartType.Ball, material = Enum.Material.ForceField, transparency = 0.2, name = "Bolha" })
end

-- BARRA DE VIDA ----------------------------------------------------------
-- mesma barra segmentada do jogador/inimigos (Shared.BarraVida), aparece quando a estrutura leva dano
local BarraVida = require(Shared:WaitForChild("BarraVida"))
local function healthBar(data)
	local s = data.cfg.Tamanho
	local barra = BarraVida.Create(data.main, {
		Largura = math.clamp(math.max(s.X, s.Z) * 0.6, 3, 5.5),
		Offset = Vector3.new(0, s.Y / 2 + 1.4, 0),
		MaxDistance = 90,
	})
	barra.Gui.Enabled = false
	data.barObj, data.barGui = barra, barra.Gui
end

local function refresh(data)
	local r = math.clamp(data.hp / data.maxHp, 0, 1)
	data.barObj:Set(r)
	data.barGui.Enabled = r < 1
	data.model:SetAttribute("Vida", math.floor(data.hp + 0.5))
	if data.repairPrompt then
		data.repairPrompt.Enabled = false
		data.repairPrompt.ActionText = "Reparar"
	end
end

local function poof(pos, color)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Size = Vector3.one; p.Position = pos; p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(200, 190, 170))
	e.Size = NumberSequence.new(2, 5); e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(0.5, 0.9); e.Speed = NumberRange.new(8, 14); e.SpreadAngle = Vector2.new(180, 180)
	e.Enabled = false; e.Parent = p; e:Emit(20)
	Debris:AddItem(p, 1.5)
end

-- CRIAR / DESTRUIR -------------------------------------------------------
local function countFor(userId)
	counts[userId] = counts[userId] or { total = 0 }
	return counts[userId]
end

function BuildService:Create(key, cf, ownerId, hpRatio)
	local ic = Shop.Estruturas[key]
	local model = Instance.new("Model")
	model.Name = ic.Nome
	local s = ic.Tamanho
	-- caixa de colisao unica (invisivel): bloqueia jogadores e inimigos
	local main = Instance.new("Part")
	main.Name = "Base"
	main.Anchored = true
	main.Size = s
	main.CFrame = cf * CFrame.new(0, s.Y / 2, 0)
	main.Transparency = 1
	-- armadilhas de chao/teto nao bloqueiam ninguem; portoes e o campo de forca bloqueiam os veritys
	-- (o raycast de obstaculo deles respeita CanCollide) mas deixam os JOGADORES passar (grupo de colisao)
	main.CanCollide = ic.Tipo ~= "Mina" and not ic.NaoBloqueia
	if ic.Portao or ic.PassaJogador then main.CollisionGroup = "PassaJogador" end
	main.CanQuery = true
	main.CanTouch = false
	main.Parent = model
	model.PrimaryPart = main
	local head, muzzle, accent, drone = builders[key](model, cf, s)
	if key == "Cupula" then
		-- domo em volta do Nucleo (so visual; o dano e absorvido em AbsorbCoreDamage)
		local dome = Instance.new("Part")
		dome.Name = "Domo"
		dome.Shape = Enum.PartType.Ball
		dome.Size = Vector3.one * (ic.RaioDomo or 18) * 2
		dome.CFrame = CFrame.new(Core.Center)
		dome.Material = Enum.Material.ForceField
		dome.Color = Color3.fromRGB(150, 120, 255)
		dome.Anchored = true; dome.CanCollide = false; dome.CanQuery = false; dome.CanTouch = false; dome.CastShadow = false
		dome.Parent = model
	end
	model:SetAttribute("Item", key)
	if ic.NaoBloqueia or ic.Tipo == "Mina" then model:SetAttribute("NaoBloqueia", true) end
	model:SetAttribute("Dono", ownerId)
	model:SetAttribute("VidaMax", ic.Vida)
	CollectionService:AddTag(model, "Estrutura")
	model.Parent = folder

	local data = {
		key = key, cfg = ic, model = model, main = main, owner = ownerId, cf = cf,
		maxHp = ic.Vida, hp = ic.Vida * (hpRatio or 1), last = 0, head = head, muzzle = muzzle,
		accent = accent, drone = drone, droneT = math.random() * 10, born = os.clock(),
	}
	healthBar(data)

	-- sons da estrutura
	soundAt(main.Position, SONS.Construir, 0.15)
	if ic.Tipo == "Torreta" then task.delay(0.2, function() if model.Parent then soundAt(main.Position, SONS.MontarTorreta, 0.1) end end) end
	if TIRO[key] then data.shotSnd = sfx(main, TIRO[key], false, 120) end
	if key == "LancaChamas" then data.fireSnd = sfx(main, SONS.TorretaFogo, true, 80) end
	if key == "GeradorEscudo" then sfx(main, SONS.GeradorZumbido, true, 45):Play() end
	if key == "Drone" then data.healSnd = sfx(main, SONS.DroneCura, false, 60) end

	-- reparar (qualquer jogador paga) e vender (so o dono)
	local rp = Instance.new("ProximityPrompt")
	rp.Name = "Reparar"
	rp.ObjectText = ic.Nome
	rp.KeyboardKeyCode = Enum.KeyCode.E
	rp.GamepadKeyCode = Enum.KeyCode.ButtonX
	rp.HoldDuration = 0.4
	rp.MaxActivationDistance = 10
	rp.RequiresLineOfSight = false
	rp.Enabled = false -- reparo agora e feito com o MARTELO (slot 2 / tecla G)
	rp.Parent = main
	rp.Triggered:Connect(function(player) self:Repair(player, model) end)
	data.repairPrompt = rp
	local sp = Instance.new("ProximityPrompt")
	sp.Name = "Vender"
	sp.ObjectText = ic.Nome
	sp.ActionText = "Vender (+" .. Custos.Texto(ic.Custo, C.RetornoVenda) .. ")"
	sp.KeyboardKeyCode = Enum.KeyCode.H
	sp.GamepadKeyCode = Enum.KeyCode.ButtonY
	sp.HoldDuration = 0.8
	sp.MaxActivationDistance = 10
	sp.RequiresLineOfSight = false
	sp.UIOffset = Vector2.new(0, 80)
	sp.Parent = main
	sp.Triggered:Connect(function(player) self:Sell(player, model) end)

	structures[model] = data
	local cnt = countFor(ownerId)
	cnt.total += 1
	cnt[key] = (cnt[key] or 0) + 1
	total += 1
	refresh(data)
	-- efeito de "encaixe": sobe do chao
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= main and p.Name ~= "Bolha" then
			local final = p.CFrame
			p.CFrame = final * CFrame.new(0, -1.5, 0)
			TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final }):Play()
		end
	end
	return data
end

function BuildService:Remove(model, effect)
	local data = structures[model]
	if not data then return end
	structures[model] = nil
	local cnt = countFor(data.owner)
	cnt.total = math.max(0, cnt.total - 1)
	cnt[data.key] = math.max(0, (cnt[data.key] or 1) - 1)
	total = math.max(0, total - 1)
	if effect then
		poof(data.main.Position, data.key == "Muro" and STONE or nil)
		soundAt(data.main.Position, SONS.Quebrar, 0.2)
	end
	model:Destroy()
end

function BuildService:IsAlive(model)
	return structures[model] ~= nil
end

function BuildService:ModelFromPart(part)
	local mdl = part and part:FindFirstAncestorOfClass("Model")
	while mdl and not structures[mdl] do mdl = mdl.Parent and mdl.Parent:FindFirstAncestorOfClass("Model") end
	return mdl
end

function BuildService:Damage(model, amount)
	local data = structures[model]
	if not data or amount <= 0 then return end
	local pos = data.main.Position
	local mult = 1
	local shieldR = estado:GetAttribute("CoreEscudoRaio") or 0
	if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(Core.Position.X, 0, Core.Position.Z)).Magnitude <= shieldR + 14 then
		mult *= (1 - C.EscudoNucleoReducao)
	end
	local best = 0
	for _, g in pairs(structures) do
		if g.key == "GeradorEscudo" and g ~= data and (g.main.Position - pos).Magnitude <= g.cfg.Raio then
			best = math.max(best, g.cfg.Reducao)
		end
	end
	mult *= (1 - best)
	-- passiva do Engenheiro (Etapa 7): armadura extra perto das estruturas do dono
	local armor = model:GetAttribute("ArmaduraExtra") or 0
	local dmg = math.max(1, amount * mult * 100 / (100 + armor))
	data.hp -= dmg
	-- pancada na estrutura (no maximo 1 a cada 0,4s por estrutura)
	local now = os.clock()
	if data.hp > 0 and now - (data.lastHitSnd or 0) > 0.4 and SONS.EstruturaAcerto then
		data.lastHitSnd = now
		local pitch = (data.key == "Muro" or data.key == "TorretaPesada") and 0.75 or (data.cfg.Tipo == "Torreta" and 1.2 or 1)
		soundAt(pos, { Id = SONS.EstruturaAcerto.Id, V = SONS.EstruturaAcerto.V, P = pitch }, 0.2)
	end
	if data.hp <= 0 then
		self:Remove(model, true)
	else
		refresh(data)
	end
end

function BuildService:Heal(model, amount)
	local data = structures[model]
	if not data then return end
	data.hp = math.min(data.maxHp, data.hp + amount)
	refresh(data)
end

function BuildService:Repair(player, model)
	local data = structures[model]
	if not data or data.hp >= data.maxHp then return end
	-- reparo custa materiais do estoque, proporcional ao dano (B.A.S.E. do Engenheiro da desconto)
	local frac = (1 - data.hp / data.maxHp) * (C.ReparoFracao or 0.5) * (1 - (data.model:GetAttribute("DescontoReparo") or 0))
	local cost = {}
	for k, v in pairs(Custos.Norm(data.cfg.Custo)) do cost[k] = math.ceil(v * frac) end
	if Coleta:Spend(cost) then
		data.hp = data.maxHp
		refresh(data)
	else
		remotes.Aviso:FireClient(player, (Custos.Falta(estado, cost) or "Materiais insuficientes") .. " para reparar")
	end
end

function BuildService:Sell(player, model)
	local data = structures[model]
	if not data then return end
	if data.owner ~= player.UserId then
		remotes.Aviso:FireClient(player, "Só quem construiu pode vender")
		return
	end
	Coleta:Refund(data.cfg.Custo, C.RetornoVenda * (data.hp / data.maxHp))
	soundAt(data.main.Position, SONS.Vender)
	self:Remove(model, true)
end

-- VALIDACAO DE COLOCACAO (o cliente usa a mesma regra para pintar o fantasma) --
function BuildService:Validate(player, key, cf)
	local ic = Shop.Estruturas[key]
	if not ic then return nil, "Item inválido" end
	if Core:GetTier() < ic.TierMin then return nil, "Exige Núcleo tier " .. ic.TierMin end
	local g = C.Grade
	local pos = cf.Position
	local x = math.floor(pos.X / g + 0.5) * g
	local z = math.floor(pos.Z / g + 0.5) * g
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	yaw = math.floor(yaw / (math.pi / 2) + 0.5) * (math.pi / 2)
	local flatD = (Vector3.new(x, 0, z) - Vector3.new(Core.Position.X, 0, Core.Position.Z)).Magnitude
	if flatD > C.RaioConstrucao then return nil, "Longe demais do Núcleo" end
	if flatD < C.RaioMinimoNucleo then return nil, "Perto demais do Núcleo" end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - Vector3.new(x, root.Position.Y, z)).Magnitude > 70 then return nil, "Chegue mais perto" end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	-- pecas empilhaveis (piso, teto, rampa...) podem ir em cima de outras estruturas
	local ignore = { Enemy:Folder(), fxFolder }
	if not ic.Empilhavel then table.insert(ignore, folder) end
	for _, n in ipairs({ "Moedas", "Recursos", "ItensChao" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ignore, f) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rp.FilterDescendantsInstances = ignore
	-- o chao agora tem relevo: aceita colinas suaves, recusa barranco
	local fromY = ic.Empilhavel and math.max(Core.Position.Y + 24, cf.Position.Y + 3) or Core.Position.Y + 24
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -(fromY - Core.Position.Y + 26), 0), rp)
	local maxUp = ic.Empilhavel and 30 or 10
	if not hit or (hit.Position.Y - Core.Position.Y) > maxUp or (Core.Position.Y - hit.Position.Y) > 10 or hit.Normal.Y < 0.82 then return nil, "Terreno inválido" end
	if ic.Empilhavel and (cf.Position.Y - hit.Position.Y) > 4 then
		-- o cliente mirou num ponto mais alto (ex.: em cima de um muro): usa o que o servidor achou
	end
	local placeCF = CFrame.new(x, hit.Position.Y, z) * CFrame.Angles(0, yaw, 0)
	local s = ic.Tamanho
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { Enemy:Folder(), fxFolder, workspace:FindFirstChild("Moedas") }
	op.RespectCanCollide = true
	local boxCF = placeCF * CFrame.new(0, s.Y / 2 + 0.3, 0)
	local boxSize = Vector3.new(math.max(0.5, s.X - 0.4), math.max(0.5, s.Y - 0.6), math.max(0.5, s.Z - 0.4))
	if #workspace:GetPartBoundsInBox(boxCF, boxSize, op) > 0 then return nil, "Espaço ocupado" end
	-- minas (sem colisao) tambem nao podem sobrepor outras estruturas
	local op2 = OverlapParams.new()
	op2.FilterType = Enum.RaycastFilterType.Include
	op2.FilterDescendantsInstances = { folder }
	if #workspace:GetPartBoundsInBox(boxCF, boxSize, op2) > 0 then return nil, "Espaço ocupado" end
	local cnt = countFor(player.UserId)
	if (cnt[key] or 0) >= ic.Limite then return nil, "Limite deste item: " .. ic.Limite end
	if cnt.total >= C.LimitePorJogador then return nil, "Limite por jogador: " .. C.LimitePorJogador end
	if total >= C.LimiteGlobal then return nil, "Limite do servidor atingido" end
	return placeCF
end

-- ARMADILHAS / DEFESAS ESPECIAIS ----------------------------------------------------------------
local function flatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
function BuildService:_trap(data, list, now, dt)
	local ic, key = data.cfg, data.key
	local pos = data.main.Position
	local pl = ownerPlayer(data)
	data.tick = (data.tick or 0) + dt
	if key == "Espinhos" or key == "EmissorGas" then
		if data.tick < (ic.Intervalo or 0.5) then return end
		data.tick = 0
		local hitAny = false
		for _, e in ipairs(list) do
			if flatDist(e.pos, pos) <= ic.Raio then
				Enemy:Damage(e.model, ic.Dano, pl)
				hitAny = true
			end
		end
		if key == "EmissorGas" then
			local bico = data.muzzle
			local gas = bico and bico:FindFirstChild("Gas")
			if gas then gas.Rate = hitAny and 18 or 2 end
		elseif hitAny then
			soundAt(pos, SONS.Golpe, 0.3)
		end
	elseif key == "Lentidao" then
		if data.tick < 0.25 then return end
		data.tick = 0
		for _, e in ipairs(list) do
			if flatDist(e.pos, pos) <= ic.Raio then
				Enemy:Slow(e.model, ic.Lentidao, 0.6)
				if ic.Dano then Enemy:Damage(e.model, ic.Dano, pl) end
			end
		end
	elseif key == "Quicador" then
		if now - (data.lastFire or 0) < ic.Cadencia then return end
		for _, e in ipairs(list) do
			if flatDist(e.pos, pos) <= ic.Raio then
				data.lastFire = now
				local away = Vector3.new(e.pos.X - Core.Position.X, 0, e.pos.Z - Core.Position.Z)
				for _, t in ipairs(enemiesNear(list, pos, ic.Raio + 1)) do
					if ic.Dano then Enemy:Damage(t.model, ic.Dano, pl) end
					Enemy:Knockback(t.model, away, ic.Forca)
				end
				if data.head then
					local base = data.head.CFrame
					data.head.CFrame = base * CFrame.new(0, 0.8, 0)
					TweenService:Create(data.head, TweenInfo.new(0.35, Enum.EasingStyle.Bounce), { CFrame = base }):Play()
				end
				soundAt(pos, SONS.PuloInimigo or SONS.Golpe, 0.2)
				break
			end
		end
	elseif key == "LancaDardos" or key == "Repulsor" then
		if now - (data.lastFire or 0) < ic.Cadencia then return end
		local fwd = -data.cf.LookVector
		local origin = data.muzzle and data.muzzle.Position or pos
		local hits = {}
		for _, e in ipairs(list) do
			local rel = Vector3.new(e.pos.X - origin.X, 0, e.pos.Z - origin.Z)
			local along = rel:Dot(Vector3.new(fwd.X, 0, fwd.Z).Unit)
			local side = (rel - Vector3.new(fwd.X, 0, fwd.Z).Unit * along).Magnitude
			if along > 0 and along <= ic.Alcance and side <= (ic.Largura or 2.5) then table.insert(hits, { e = e, along = along }) end
		end
		if #hits == 0 then return end
		data.lastFire = now
		if key == "LancaDardos" then
			table.sort(hits, function(a, b) return a.along < b.along end)
			local alvo = hits[1].e
			Enemy:Damage(alvo.model, ic.Dano, pl)
			remotes.Efeito:FireAllClients("TorretaTiro", data.model, origin, alvo.pos, "Dardo")
			soundAt(origin, SONS.Estilingue or SONS.Golpe, 0.2)
		else
			for _, h in ipairs(hits) do
				if ic.Dano then Enemy:Damage(h.e.model, ic.Dano, pl) end
				Enemy:Knockback(h.e.model, Vector3.new(fwd.X, 0, fwd.Z), ic.Forca)
			end
			boom(origin, 4, Color3.fromRGB(120, 200, 255))
			soundAt(origin, SONS.Explosao, 0.2)
		end
	elseif key == "Prensa" then
		if now - (data.lastFire or 0) < ic.Cadencia then return end
		local under = {}
		for _, e in ipairs(list) do
			if math.abs(e.pos.X - pos.X) <= ic.Tamanho.X / 2 and math.abs(e.pos.Z - pos.Z) <= ic.Tamanho.Z / 2 then table.insert(under, e) end
		end
		if #under == 0 then return end
		data.lastFire = now
		if data.head and data.head.PrimaryPart then
			local up = data.head:GetPivot()
			local down = up * CFrame.new(0, -(ic.Tamanho.Y - 3.5), 0)
			data.head:PivotTo(down)
			task.delay(0.35, function() if data.head.Parent then data.head:PivotTo(up) end end)
		end
		for _, e in ipairs(under) do Enemy:Damage(e.model, ic.Dano, pl); Enemy:Stun(e.model, 0.6) end
		boom(pos - Vector3.new(0, ic.Tamanho.Y / 2 - 0.5, 0), 5, Color3.fromRGB(200, 200, 210))
		soundAt(pos, SONS.Martelo, 0.15)
	elseif key == "GradeEletrica" then
		if data.tick < (ic.Intervalo or 0.6) then return end
		data.tick = 0
		for _, e in ipairs(list) do
			if flatDist(e.pos, pos) <= ic.Raio then
				Enemy:Damage(e.model, ic.Dano, pl)
				Enemy:Knockback(e.model, Vector3.new(e.pos.X - pos.X, 0, e.pos.Z - pos.Z), ic.Forca or 4)
				remotes.Efeito:FireAllClients("TorretaTiro", data.model, pos + Vector3.new(0, 4, 0), e.pos, "Raio")
			end
		end
	end
end

-- CUPULA PROTETORA: segura o dano que iria para o Nucleo ate quebrar
function BuildService:AbsorbCoreDamage(amount)
	for model, data in pairs(structures) do
		if data.key == "Cupula" and data.hp > 0 then
			self:Damage(model, amount)
			return true
		end
	end
	return false
end

-- CHECKPOINT ------------------------------------------------------------
function BuildService:GetState()
	local list = {}
	for _, d in pairs(structures) do
		table.insert(list, { key = d.key, cf = d.cf, owner = d.owner, hp = d.hp / d.maxHp })
	end
	return list
end

function BuildService:RestoreState(list)
	for _, e in ipairs(list or {}) do self:Create(e.key, e.cf, e.owner, e.hp) end
end

function BuildService:ClearAll()
	for model in pairs(structures) do model:Destroy() end
	structures = {}
	counts = {}
	total = 0
end

function BuildService:Folder() return folder end

-- DISPAROS --------------------------------------------------------------
local function tracer(from, to, color, width)
	local d = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(width or 0.3, width or 0.3, d)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -d / 2)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.15)
end

local function boom(pos, radius, color)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 160, 50)
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.35)
end

local function enemiesNear(list, pos, radius)
	local out = {}
	for _, e in ipairs(list) do
		if (e.pos - pos).Magnitude <= radius then table.insert(out, e) end
	end
	return out
end

local function ownerPlayer(data) return Players:GetPlayerByUserId(data.owner) end

local function updateTurret(data, list, now)
	local ic = data.cfg
	-- pulso eletromagnetico do Glitcity: torre desligada por alguns segundos
	if (data.model:GetAttribute("EMPAte") or 0) > workspace:GetServerTimeNow() then return end
	local origin = data.muzzle and data.muzzle.Position or data.main.Position
	local best, bd
	for _, e in ipairs(list) do
		local d = (e.pos - data.main.Position).Magnitude
		if d <= ic.Alcance and (not bd or d < bd) then best, bd = e, d end
	end
	local fire = data.muzzle and data.muzzle:FindFirstChild("Chamas")
	if not best then
		if fire then fire.Enabled = false end
		if data.fireSnd and data.fireSnd.IsPlaying then data.fireSnd:Stop() end
		return
	end
	if data.fireSnd and not data.fireSnd.IsPlaying then data.fireSnd:Play() end
	-- gira a cabeca (so no eixo Y)
	if data.head then
		local hp = data.head:GetPivot().Position
		local tgt = Vector3.new(best.pos.X, hp.Y, best.pos.Z)
		if (tgt - hp).Magnitude > 0.1 then data.head:PivotTo(CFrame.lookAt(hp, tgt)) end
	end
	if fire then fire.Enabled = true end
	local overcharge = (estado:GetAttribute("SobrecargaAte") or 0) > workspace:GetServerTimeNow()
	local dmgMult = 1 + (estado:GetAttribute("BonusTorreta") or 0)
	if now - data.last < ic.Cadencia / (overcharge and 2 or 1) then return end
	data.last = now
	if data.shotSnd then
		data.shotSnd.PlaybackSpeed = ((TIRO[data.key] and TIRO[data.key].P) or 1) * (0.93 + math.random() * 0.14)
		data.shotSnd.TimePosition = 0
		data.shotSnd:Play()
	end
	local pl = ownerPlayer(data)
	if data.key == "LancaChamas" then
		local fwd = data.head and data.head:GetPivot().LookVector or (best.pos - origin).Unit
		local cosHalf = math.cos(math.rad(ic.Cone / 2))
		for _, e in ipairs(list) do
			local v = e.pos - data.main.Position
			local flatV = Vector3.new(v.X, 0, v.Z)
			if flatV.Magnitude <= ic.Alcance and flatV.Magnitude > 0.1 and Vector3.new(fwd.X, 0, fwd.Z).Unit:Dot(flatV.Unit) >= cosHalf then
				Enemy:Damage(e.model, ic.Dano * dmgMult, pl)
			end
		end
	elseif data.key == "TorretaPesada" then
		tracer(origin, best.pos, Color3.fromRGB(255, 200, 80), 0.8)
		boom(best.pos, ic.Area, Color3.fromRGB(255, 150, 40))
		for _, e in ipairs(enemiesNear(list, best.pos, ic.Area)) do Enemy:Damage(e.model, ic.Dano * dmgMult, pl) end
	else
		local isIce = data.key == "TorretaGelo"
		tracer(origin, best.pos, isIce and Color3.fromRGB(150, 235, 255) or Color3.fromRGB(255, 230, 120), isIce and 0.45 or 0.3)
		Enemy:Damage(best.model, ic.Dano * dmgMult, pl)
		if isIce then Enemy:Slow(best.model, ic.Lentidao, ic.DuracaoLentidao) end
	end
end

function BuildService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Core = require(script.Parent.CoreService)
	Enemy = require(script.Parent.EnemyService)
	Economy = require(script.Parent.EconomyService)
	Coleta = require(script.Parent.ColetaService)
	-- portoes / campo de forca: bloqueiam veritys, mas jogadores atravessam
	pcall(function()
		local PS = game:GetService("PhysicsService")
		PS:RegisterCollisionGroup("PassaJogador")
		PS:RegisterCollisionGroup("Jogadores")
		PS:CollisionGroupSetCollidable("PassaJogador", "Jogadores", false)
	end)
	folder = workspace:FindFirstChild("Estruturas")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Estruturas"
		folder.Parent = workspace
	end
	fxFolder = workspace:FindFirstChild("Efeitos")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "Efeitos"
		fxFolder.Parent = workspace
	end
	-- miniaturas para a Loja do Nucleo: o mesmo modelo que aparece no mapa (sem a bolha do escudo)
	local prev = Shared:FindFirstChild("PreviewsEstruturas")
	if prev then prev:Destroy() end
	prev = Instance.new("Folder")
	prev.Name = "PreviewsEstruturas"
	for key, ic in pairs(Shop.Estruturas) do
		if builders[key] then
			local m = Instance.new("Model")
			m.Name = key
			local ok = pcall(builders[key], m, CFrame.new(), ic.Tamanho)
			local bolha = m:FindFirstChild("Bolha", true)
			if bolha then bolha:Destroy() end
			if ok then m.Parent = prev else m:Destroy() end
		end
	end
	prev.Parent = Shared
end

function BuildService:Start()
	remotes.Construir.OnServerEvent:Connect(function(player, key, cf)
		if typeof(key) ~= "string" or typeof(cf) ~= "CFrame" then return end
		local now = os.clock()
		if lastPlace[player] and now - lastPlace[player] < 0.25 then return end
		lastPlace[player] = now
		if Core:IsDead() then return end
		local placeCF, why = self:Validate(player, key, cf)
		if not placeCF then
			remotes.Aviso:FireClient(player, why)
			return
		end
		local ic = Shop.Estruturas[key]
		if not Coleta:Spend(ic.Custo) then
			remotes.Aviso:FireClient(player, Custos.Falta(estado, ic.Custo) or "Materiais insuficientes")
			return
		end
		self:Create(key, placeCF, player.UserId, 1)
	end)
	Players.PlayerRemoving:Connect(function(p) lastPlace[p] = nil end)

	-- scheduler unico das estruturas
	local healAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local list = {}
		for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
			local body = mdl:FindFirstChild("Corpo")
			if body then table.insert(list, { model = mdl, pos = body.Position }) end
		end
		healAcc += dt
		local doHeal = healAcc >= 1
		if doHeal then healAcc = 0 end
		for model, data in pairs(structures) do
			local tipo = data.cfg.Tipo
			if tipo == "Armadilha" then self:_trap(data, list, now, dt) end
			if data.cfg.Portao and now - data.born > 0.5 then
				-- portao abre sozinho quando um jogador chega perto
				if not data.doors then
					data.doors, data.gateT = {}, 0
					for _, d in ipairs(model:GetChildren()) do
						local h = d:IsA("Model") and d:GetAttribute("Dobradica")
						if h then table.insert(data.doors, { m = d, h = h, rel = h:ToObjectSpace(d:GetPivot()), side = d:GetAttribute("Lado") or 1 }) end
					end
				end
				local near = false
				for _, pl in ipairs(Players:GetPlayers()) do
					local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if r and (r.Position - data.main.Position).Magnitude < 9 then near = true break end
				end
				local goal = near and 1 or 0
				if math.abs(data.gateT - goal) > 0.001 then
					if (goal == 1) ~= (data.gateGoal == 1) then soundAt(data.main.Position, SONS.Martelo, 0.2) end
					data.gateGoal = goal
					data.gateT += math.clamp(goal - data.gateT, -dt * 3, dt * 3)
					local e = data.gateT * data.gateT * (3 - 2 * data.gateT)
					for _, d in ipairs(data.doors) do
						if d.m.Parent then d.m:PivotTo(d.h * CFrame.Angles(0, d.side * e * math.rad(100), 0) * d.rel) end
					end
				end
			end
			if tipo == "Torreta" then
				updateTurret(data, list, now)
			elseif tipo == "Mina" then
				for _, e in ipairs(list) do
					local v = e.pos - data.main.Position
					if Vector3.new(v.X, 0, v.Z).Magnitude <= data.cfg.Gatilho then
						boom(data.main.Position, data.cfg.Raio, Color3.fromRGB(255, 120, 40))
						soundAt(data.main.Position, SONS.MinaExplosao, 0.15)
						local pl = ownerPlayer(data)
						for _, t in ipairs(enemiesNear(list, data.main.Position, data.cfg.Raio)) do Enemy:Damage(t.model, data.cfg.Dano, pl) end
						self:Remove(model, false)
						break
					end
				end
			elseif tipo == "Drone" then
				data.droneT += dt
				if data.drone then
					local base = data.cf * CFrame.new(0, 5 + math.sin(data.droneT * 2) * 0.5, 0) * CFrame.Angles(0, data.droneT * 0.8, 0)
					data.drone:PivotTo(base)
				end
				if doHeal then
					local healed = false
					for _, other in pairs(structures) do
						if other ~= data and other.hp < other.maxHp and (other.main.Position - data.main.Position).Magnitude <= data.cfg.Raio then
							self:Heal(other.model, data.cfg.Cura)
							healed = true
						end
					end
					if healed and data.healSnd then data.healSnd:Play() end
				end
			end
		end
	end)
	log("Pronto. Itens: " .. #Shop.Ordem)
end

return BuildService
