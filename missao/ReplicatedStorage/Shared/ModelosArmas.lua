-- [ModelosArmas] Modelos blocados (studs) das armas, ferramentas e icones.
-- Usado no servidor (Tools) e no cliente (icones em ViewportFrame).
-- Convencao: a peca "Handle" fica na origem, o cano aponta para -Z e o topo para +Y.
local M = {}

local rgb = Color3.fromRGB
local function P(model, name, size, cf, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = o.neon and Enum.Material.Neon or Enum.Material.Plastic
	if o.ball then p.Shape = Enum.PartType.Ball end
	if o.cyl then p.Shape = Enum.PartType.Cylinder end
	p.TopSurface = (o.ball or o.cyl or o.smooth) and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
	p.BottomSurface = (o.ball or o.cyl or o.smooth) and Enum.SurfaceType.Smooth or Enum.SurfaceType.Inlet
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end
M.Part = P

local function new(name)
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function finish(m, muzzle, grip)
	local h = m:FindFirstChild("Handle")
	m.PrimaryPart = h
	if muzzle then
		local a = Instance.new("Attachment")
		a.Name = "Boca"
		a.Position = muzzle
		a.Parent = h
	end
	m:SetAttribute("Grip", grip or Vector3.zero)
	return m
end

local R = CFrame.Angles

M.Armas = {}

M.Armas.Punhos = function()
	local m = new("Punhos")
	local skin = rgb(245, 205, 160)
	P(m, "Handle", Vector3.new(0.9, 0.8, 0.8), Vector3.new(0, 0, 0), skin)
	for i = 0, 3 do
		P(m, "Dedo", Vector3.new(0.2, 0.22, 0.32), Vector3.new(-0.33 + i * 0.22, 0.24, -0.5), skin)
	end
	P(m, "Polegar", Vector3.new(0.25, 0.25, 0.4), Vector3.new(0.5, -0.1, -0.25), skin)
	P(m, "Pulso", Vector3.new(0.7, 0.6, 0.5), Vector3.new(0, -0.05, 0.6), rgb(13, 105, 172))
	return finish(m, Vector3.new(0, 0, -0.6))
end

M.Armas.Revolver = function()
	local m = new("Revolver")
	local g, g2, w = rgb(95, 98, 108), rgb(125, 128, 140), rgb(125, 82, 50)
	P(m, "Handle", Vector3.new(0.35, 0.55, 0.9), Vector3.new(0, 0, 0), g)
	P(m, "Tambor", Vector3.new(0.5, 0.48, 0.5), Vector3.new(0, 0, -0.1), g2)
	P(m, "Cano", Vector3.new(0.22, 0.22, 1.1), Vector3.new(0, 0.12, -0.9), g)
	P(m, "Mira", Vector3.new(0.08, 0.14, 0.12), Vector3.new(0, 0.3, -1.35), g2)
	P(m, "Cabo", Vector3.new(0.32, 0.75, 0.38), CFrame.new(0, -0.5, 0.35) * R(math.rad(-15), 0, 0), w)
	P(m, "Guarda", Vector3.new(0.1, 0.28, 0.32), Vector3.new(0, -0.36, 0.02), g)
	return finish(m, Vector3.new(0, 0.12, -1.47), Vector3.new(0, -0.45, 0.38))
end

M.Armas.SMG = function()
	local m = new("SMG")
	local b, b2 = rgb(100, 108, 140), rgb(70, 75, 98)
	P(m, "Handle", Vector3.new(0.38, 0.55, 1.3), Vector3.new(0, 0, 0), b)
	P(m, "Topo", Vector3.new(0.3, 0.12, 0.9), Vector3.new(0, 0.33, 0.05), b2)
	P(m, "Cano", Vector3.new(0.2, 0.2, 0.5), Vector3.new(0, 0.08, -0.88), b2)
	P(m, "Carregador", Vector3.new(0.24, 0.9, 0.3), CFrame.new(0, -0.65, -0.3) * R(math.rad(8), 0, 0), b2)
	P(m, "Cabo", Vector3.new(0.3, 0.7, 0.34), CFrame.new(0, -0.5, 0.42) * R(math.rad(-12), 0, 0), b)
	return finish(m, Vector3.new(0, 0.08, -1.15), Vector3.new(0, -0.45, 0.42))
end

M.Armas.Fuzil = function()
	local m = new("Fuzil")
	local p1, gr, d = rgb(95, 95, 145), rgb(95, 180, 95), rgb(55, 55, 70)
	P(m, "Handle", Vector3.new(0.35, 0.55, 1.6), Vector3.new(0, 0, 0), p1)
	P(m, "Coronha", Vector3.new(0.3, 0.6, 0.8), Vector3.new(0, -0.08, 1.15), gr)
	P(m, "GuardaMao", Vector3.new(0.38, 0.45, 0.9), Vector3.new(0, 0, -1.2), gr)
	P(m, "Cano", Vector3.new(0.16, 0.16, 0.7), Vector3.new(0, 0.05, -1.95), d)
	P(m, "Carregador", Vector3.new(0.24, 0.8, 0.32), CFrame.new(0, -0.6, -0.35) * R(math.rad(10), 0, 0), d)
	P(m, "Cabo", Vector3.new(0.28, 0.65, 0.32), CFrame.new(0, -0.5, 0.45) * R(math.rad(-12), 0, 0), p1)
	P(m, "Mira", Vector3.new(0.2, 0.25, 0.5), Vector3.new(0, 0.4, 0), d)
	return finish(m, Vector3.new(0, 0.05, -2.3), Vector3.new(0, -0.45, 0.45))
end

M.Armas.Escopeta = function()
	local m = new("Escopeta")
	local g, d, w = rgb(85, 85, 95), rgb(50, 50, 58), rgb(150, 95, 52)
	P(m, "Handle", Vector3.new(0.36, 0.5, 1.2), Vector3.new(0, 0, 0), g)
	P(m, "Cano1", Vector3.new(0.18, 0.18, 1.6), Vector3.new(-0.1, 0.1, -1.3), d)
	P(m, "Cano2", Vector3.new(0.18, 0.18, 1.6), Vector3.new(0.1, 0.1, -1.3), d)
	P(m, "Telha", Vector3.new(0.34, 0.3, 0.9), Vector3.new(0, -0.18, -1.1), w)
	P(m, "Coronha", Vector3.new(0.32, 0.6, 1.1), CFrame.new(0, -0.15, 1.1) * R(math.rad(-6), 0, 0), w)
	P(m, "Cabo", Vector3.new(0.28, 0.6, 0.32), CFrame.new(0, -0.45, 0.45) * R(math.rad(-12), 0, 0), w)
	return finish(m, Vector3.new(0, 0.1, -2.1), Vector3.new(0, -0.42, 0.45))
end

M.Armas.Minigun = function()
	local m = new("Minigun")
	local y, d, g = rgb(235, 185, 50), rgb(55, 55, 62), rgb(120, 122, 130)
	P(m, "Handle", Vector3.new(0.8, 0.8, 1.4), Vector3.new(0, 0, 0), y)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		P(m, "Cano", Vector3.new(0.14, 0.14, 1.8), Vector3.new(math.cos(a) * 0.24, math.sin(a) * 0.24, -1.55), d)
	end
	P(m, "Anel", Vector3.new(0.75, 0.75, 0.15), Vector3.new(0, 0, -2.3), g)
	P(m, "Anel2", Vector3.new(0.7, 0.7, 0.15), Vector3.new(0, 0, -0.9), g)
	P(m, "Alca", Vector3.new(0.15, 0.15, 0.8), Vector3.new(0, 0.55, 0), d)
	P(m, "Cabo", Vector3.new(0.28, 0.6, 0.32), Vector3.new(0, -0.65, 0.3), d)
	return finish(m, Vector3.new(0, 0, -2.45), Vector3.new(0, -0.6, 0.3))
end

M.Armas.Bazuca = function()
	local m = new("Bazuca")
	local o, gr, d = rgb(230, 120, 40), rgb(110, 200, 90), rgb(55, 55, 62)
	P(m, "Handle", Vector3.new(0.7, 0.7, 3), Vector3.new(0, 0, -0.3), o)
	P(m, "Borda", Vector3.new(0.82, 0.82, 0.22), Vector3.new(0, 0, -1.85), d)
	P(m, "BordaTras", Vector3.new(0.82, 0.82, 0.22), Vector3.new(0, 0, 1.25), d)
	P(m, "Foguete", Vector3.new(0.45, 0.45, 0.5), Vector3.new(0, 0, -2.1), gr)
	P(m, "Cabo", Vector3.new(0.28, 0.6, 0.32), Vector3.new(0, -0.6, 0.1), d)
	P(m, "Mira", Vector3.new(0.15, 0.4, 0.3), Vector3.new(-0.42, 0.3, -0.6), d)
	return finish(m, Vector3.new(0, 0, -2.4), Vector3.new(0, -0.55, 0.4))
end

M.Armas.Martelo = function()
	local m = new("Martelo")
	P(m, "Handle", Vector3.new(0.3, 1.8, 0.3), Vector3.new(0, 0, 0), rgb(170, 95, 45))
	P(m, "Cabeca", Vector3.new(0.65, 0.65, 1.3), Vector3.new(0, 1.05, -0.15), rgb(240, 240, 245))
	P(m, "Anel", Vector3.new(0.4, 0.2, 0.4), Vector3.new(0, 0.7, 0), rgb(120, 120, 128))
	P(m, "Ponta", Vector3.new(0.6, 0.6, 0.18), Vector3.new(0, 1.05, -0.88), rgb(150, 150, 160))
	return finish(m, nil, Vector3.new(0, -0.5, 0))
end

-- ICONES (so visual) ------------------------------------------------------
M.Icones = {}
M.Icones.Vida = function()
	local m = new("Vida")
	local r = rgb(245, 95, 75)
	P(m, "Handle", Vector3.new(0.45, 1.4, 0.45), Vector3.new(0, 0, 0), r)
	P(m, "B", Vector3.new(1.4, 0.45, 0.45), Vector3.new(0, 0, 0), r)
	return finish(m)
end
M.Icones.Verity = function()
	local m = new("Verity")
	P(m, "Handle", Vector3.new(2, 2, 2), Vector3.new(0, 0, 0), rgb(150, 25, 30), { ball = true })
	P(m, "Olho1", Vector3.new(0.3, 0.45, 0.2), Vector3.new(-0.4, 0.25, -0.9), rgb(255, 230, 60), { neon = true, smooth = true })
	P(m, "Olho2", Vector3.new(0.3, 0.45, 0.2), Vector3.new(0.4, 0.25, -0.9), rgb(255, 230, 60), { neon = true, smooth = true })
	P(m, "Coroa", Vector3.new(1.2, 0.35, 1.2), Vector3.new(0, 1.05, 0), rgb(255, 200, 50))
	for i = -1, 1 do P(m, "Ponta", Vector3.new(0.25, 0.4, 0.25), Vector3.new(i * 0.45, 1.35, -0.45), rgb(255, 200, 50)) end
	return finish(m)
end
local function ball(name, color, extra)
	return function()
		local m = new(name)
		P(m, "Handle", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 0, 0), color, { ball = true })
		P(m, "Olho1", Vector3.new(0.18, 0.35, 0.15), Vector3.new(-0.3, 0.2, -0.75), rgb(30, 30, 30), { smooth = true })
		P(m, "Olho2", Vector3.new(0.18, 0.35, 0.15), Vector3.new(0.3, 0.2, -0.75), rgb(30, 30, 30), { smooth = true })
		if extra then extra(m) end
		return finish(m)
	end
end
M.Icones.Granada = function()
	local m = new("Granada")
	P(m, "Handle", Vector3.new(1.2, 1.4, 1.2), Vector3.new(0, 0, 0), rgb(80, 120, 60))
	P(m, "Tampa", Vector3.new(0.6, 0.35, 0.6), Vector3.new(0, 0.85, 0), rgb(120, 120, 128))
	P(m, "Alavanca", Vector3.new(0.18, 0.9, 0.2), Vector3.new(0.45, 0.5, 0), rgb(160, 160, 170))
	P(m, "Pino", Vector3.new(0.4, 0.4, 0.1), Vector3.new(-0.4, 1.05, 0), rgb(255, 210, 60))
	return finish(m)
end
M.Icones.Onda = function()
	local m = new("Onda")
	P(m, "Handle", Vector3.new(0.3, 2.2, 2.2), CFrame.Angles(0, 0, math.rad(90)), rgb(255, 215, 90), { cyl = true })
	P(m, "Centro", Vector3.new(0.35, 1.2, 1.2), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 150, 60), { cyl = true })
	P(m, "Punho", Vector3.new(0.7, 0.8, 0.7), Vector3.new(0, 0.55, 0), rgb(245, 205, 160))
	return finish(m)
end
M.Icones.Grito = function()
	local m = new("Grito")
	P(m, "Handle", Vector3.new(0.6, 0.6, 0.8), Vector3.new(0, 0, 0.4), rgb(220, 60, 50))
	P(m, "Boca", Vector3.new(1.2, 1.2, 0.5), Vector3.new(0, 0, -0.3), rgb(240, 240, 245))
	P(m, "Cabo", Vector3.new(0.25, 0.6, 0.25), Vector3.new(0, -0.5, 0.45), rgb(60, 60, 66))
	return finish(m)
end
M.Icones.Chuva = function()
	local m = new("Chuva")
	P(m, "Handle", Vector3.new(0.8, 0.9, 0.8), Vector3.new(0, 0, 0), rgb(80, 120, 60))
	P(m, "G2", Vector3.new(0.7, 0.8, 0.7), Vector3.new(-0.9, 0.7, 0.2), rgb(80, 120, 60))
	P(m, "G3", Vector3.new(0.7, 0.8, 0.7), Vector3.new(0.9, 0.9, -0.2), rgb(80, 120, 60))
	P(m, "Fogo", Vector3.new(0.9, 0.5, 0.9), Vector3.new(0, -0.7, 0), rgb(255, 140, 40), { neon = true })
	return finish(m)
end
M.Icones.Avanco = function()
	local m = new("Avanco")
	P(m, "Handle", Vector3.new(0.25, 0.25, 2.2), CFrame.Angles(0, math.rad(30), 0), rgb(150, 210, 255), { neon = true })
	P(m, "R1", Vector3.new(0.2, 0.2, 1.4), CFrame.new(0.3, 0.4, 0.3) * CFrame.Angles(0, math.rad(30), 0), rgb(200, 235, 255), { neon = true })
	P(m, "R2", Vector3.new(0.2, 0.2, 1.4), CFrame.new(-0.3, -0.4, -0.3) * CFrame.Angles(0, math.rad(30), 0), rgb(200, 235, 255), { neon = true })
	return finish(m)
end
M.Icones.Fumaca = function()
	local m = new("Fumaca")
	P(m, "Handle", Vector3.new(1, 1, 1), Vector3.new(0, -0.3, 0), rgb(45, 45, 55), { ball = true })
	P(m, "N1", Vector3.new(1, 1, 1), Vector3.new(-0.6, 0.5, 0), rgb(220, 220, 230), { ball = true })
	P(m, "N2", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0.4, 0.7, 0), rgb(235, 235, 240), { ball = true })
	return finish(m)
end
M.Icones.Estrelas = function()
	local m = new("Estrelas")
	local c = rgb(200, 200, 215)
	P(m, "Handle", Vector3.new(1.8, 0.15, 0.45), CFrame.Angles(math.rad(70), 0, 0), c)
	P(m, "B", Vector3.new(0.45, 0.15, 1.8), CFrame.Angles(math.rad(70), 0, 0), c)
	P(m, "C", Vector3.new(0.4, 0.2, 0.4), CFrame.Angles(math.rad(70), 0, 0), rgb(60, 60, 70))
	return finish(m)
end
M.Icones.Sombras = ball("Sombras", rgb(70, 50, 110), function(m)
	P(m, "Faixa", Vector3.new(1.7, 0.3, 1.7), Vector3.new(0, 0.2, 0), rgb(200, 40, 40))
end)
M.Icones.Moggity = ball("Moggity", rgb(120, 125, 135), function(m)
	P(m, "Elmo", Vector3.new(1.7, 0.5, 1.7), Vector3.new(0, 0.75, 0), rgb(75, 78, 88))
	P(m, "Cano", Vector3.new(0.45, 0.45, 1.3), Vector3.new(0, 0.25, -1.1), rgb(45, 45, 52))
end)
M.Icones.Isca = function()
	local m = new("Isca")
	P(m, "Handle", Vector3.new(1.8, 1.8, 0.2), Vector3.new(0, 0, 0), rgb(195, 155, 100))
	P(m, "Olho1", Vector3.new(0.2, 0.35, 0.05), Vector3.new(-0.35, 0.25, -0.12), rgb(60, 40, 20))
	P(m, "Olho2", Vector3.new(0.2, 0.35, 0.05), Vector3.new(0.35, 0.25, -0.12), rgb(60, 40, 20))
	P(m, "Boca", Vector3.new(0.8, 0.15, 0.05), Vector3.new(0, -0.3, -0.12), rgb(60, 40, 20))
	P(m, "Pe", Vector3.new(0.2, 0.8, 0.2), Vector3.new(0, -1.2, 0), rgb(120, 90, 60))
	return finish(m)
end
M.Icones.Plasma = function()
	local m = new("Plasma")
	P(m, "Handle", Vector3.new(1.4, 0.8, 1.4), Vector3.new(0, -0.4, 0), rgb(70, 70, 80))
	P(m, "Nucleo", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0.35, 0), rgb(170, 110, 255), { ball = true, neon = true })
	return finish(m)
end
M.Icones.Sobrecarga = function()
	local m = new("Sobrecarga")
	local y = rgb(255, 215, 50)
	P(m, "Handle", Vector3.new(0.4, 1, 0.4), CFrame.new(0.2, 0.5, 0) * CFrame.Angles(0, 0, math.rad(-25)), y, { neon = true })
	P(m, "B", Vector3.new(0.9, 0.3, 0.4), Vector3.new(0, 0, 0), y, { neon = true })
	P(m, "C", Vector3.new(0.4, 1, 0.4), CFrame.new(-0.2, -0.5, 0) * CFrame.Angles(0, 0, math.rad(-25)), y, { neon = true })
	return finish(m)
end
M.Icones.Lovity = ball("Lovity", rgb(255, 135, 190), function(m)
	P(m, "Coracao", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.75, 0.8, -0.3) * CFrame.Angles(0, 0, math.rad(45)), rgb(255, 60, 110), { neon = true })
end)
M.Icones.Dardo = function()
	local m = new("Dardo")
	P(m, "Handle", Vector3.new(0.45, 0.45, 1.4), CFrame.Angles(0, math.rad(35), 0), rgb(235, 240, 245))
	P(m, "Liquido", Vector3.new(0.48, 0.48, 0.8), CFrame.new(0.15, 0, 0.2) * CFrame.Angles(0, math.rad(35), 0), rgb(110, 240, 150), { neon = true })
	P(m, "Agulha", Vector3.new(0.08, 0.08, 0.8), CFrame.new(-0.55, 0, -0.8) * CFrame.Angles(0, math.rad(35), 0), rgb(180, 180, 190))
	return finish(m)
end
M.Icones.Passo = function()
	local m = new("Passo")
	P(m, "Handle", Vector3.new(1, 1, 1), CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(255, 150, 210), { neon = true })
	P(m, "B", Vector3.new(0.5, 0.5, 0.5), CFrame.new(-1, 0.7, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(255, 190, 230), { neon = true })
	return finish(m)
end
M.Icones.Coro = function()
	local m = new("Coro")
	P(m, "Handle", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 0, 0), rgb(255, 135, 190), { ball = true })
	P(m, "B", Vector3.new(1, 1, 1), Vector3.new(-1.1, -0.2, 0.3), rgb(255, 160, 205), { ball = true })
	P(m, "C", Vector3.new(1, 1, 1), Vector3.new(1.1, -0.2, 0.3), rgb(255, 160, 205), { ball = true })
	return finish(m)
end

-- habilidade -> icone
M.IconeHabilidade = {
	Soldado = { Z = "Granada", X = "Onda", C = "Grito", Q = "Chuva" },
	Ninja = { Z = "Avanco", X = "Fumaca", C = "Estrelas", Q = "Sombras" },
	Engenheiro = { Z = "Moggity", X = "Isca", C = "Plasma", Q = "Sobrecarga" },
	Medico = { Z = "Lovity", X = "Dardo", C = "Passo", Q = "Coro" },
}

-- ITENS FEITOS NO BLENDER (ReplicatedStorage.Veritys_Itens) ----------------------------
-- Quando existe um item com o nome mapeado, ele SUBSTITUI o modelo gerado por codigo
-- (na Tool, no icone da interface e nos aliados). Sem a pasta, cai no modelo antigo.
M.Itens = {
	-- armas (Config.Weapons)
	Punhos = "Arma_Punhos", Estilingue = "Arma_Estilingue", Pistola = "Arma_Pistola", Cano = "Arma_Cano",
	Rifle = "Arma_Rifle", Machete = "Arma_Machete", LancaChamas = "Arma_LancaChamas",
	LaminaDeEnergia = "Arma_LaminaDeEnergia", MarteloDoTrovao = "Arma_MarteloDoTrovao", LaminaDoNucleo = "Arma_LaminaDoNucleo",
	-- habilidades (icones) e aliados
	Granada = "Soldado_Granada", Grito = "Soldado_Megafone", Onda = "Soldado_AnelDeChoque",
	Avanco = "Ninja_Katana", Fumaca = "Ninja_BombaDeFumaca", Estrelas = "Ninja_EstrelaNinja",
	Moggity = "Engenheiro_Moggity", Isca = "Engenheiro_Isca", Plasma = "Engenheiro_PulsoDePlasma", Base = "Engenheiro_BASE",
	Lovity = "Medico_Lovity", Dardo = "Medico_LancaDardos", DardoProjetil = "Medico_DardoCurativo",
	Passo = "Medico_PortalDeFase", Aura = "Medico_AuraDeCura",
}

-- tamanho maximo (studs) de cada item na mao; os maiores sao reduzidos proporcionalmente
M.TamanhoMax = { Rifle = 3.6, LancaChamas = 2.8, LaminaDoNucleo = 4.2, LaminaDeEnergia = 4.0, Katana = 4.0 }

-- pecas cujo fim marca a boca da arma (de onde sai o tiro)
local BOCAS = { "_Boca", "_Bico", "_Chama", "_Cano", "_Corneta", "_Forquilha", "_Lamina", "_Cabeca" }

local function itemFolder()
	return game:GetService("ReplicatedStorage"):FindFirstChild("Veritys_Itens")
end

function M.ItemSource(name)
	local id = M.Itens[name]
	local f = id and itemFolder()
	return f and f:FindFirstChild(id) or nil
end

-- Copia do item como Model ancorado (para icones e aliados). PrimaryPart = Handle (ou a 1a peca).
function M.ItemModel(name)
	local src = M.ItemSource(name)
	if not src then return nil end
	local m = Instance.new("Model")
	m.Name = name
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			local c = d:Clone()
			for _, k in ipairs(c:GetChildren()) do
				if k:IsA("JointInstance") or k:IsA("WeldConstraint") or k:IsA("TouchTransmitter") or k:IsA("LuaSourceContainer") then k:Destroy() end
			end
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = true
			c.PivotOffset = CFrame.new() -- o importador de FBX deixa o pivo girado 90 graus
			c.Parent = m
		end
	end
	m.PrimaryPart = m:FindFirstChild("Handle") or m:FindFirstChildWhichIsA("BasePart")
	return m
end

-- ponto da boca (no espaco do Handle) seguindo a direcao em que a Tool aponta (Grip)
local function muzzleLocal(tool, handle)
	local d = tool.Grip.LookVector -- direcao "para frente" no espaco do Handle
	local best
	for _, suf in ipairs(BOCAS) do
		for _, p in ipairs(tool:GetChildren()) do
			if p:IsA("BasePart") and p ~= handle and p.Name:sub(-#suf) == suf then best = p break end
		 end
		if best then break end
	end
	if not best then return d * (handle.Size.Magnitude / 2) end
	local rel = handle.CFrame:PointToObjectSpace(best.Position)
	local dw = handle.CFrame:VectorToWorldSpace(d)
	local dp = best.CFrame:VectorToObjectSpace(dw)
	local ext = (math.abs(dp.X) * best.Size.X + math.abs(dp.Y) * best.Size.Y + math.abs(dp.Z) * best.Size.Z) / 2
	-- leva o ponto ate a frente da peca, no eixo do cano
	local along = rel:Dot(d)
	local side = rel - d * along
	return side + d * (along + ext)
end

function M.ItemTool(name, toolName)
	local src = M.ItemSource(name)
	if not src or not src:IsA("Tool") then return nil end
	local tool = src:Clone()
	tool.Name = toolName or name
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	tool.RequiresHandle = true
	local handle = tool:FindFirstChild("Handle")
	if not handle then tool:Destroy() return nil end
	-- reduz itens grandes demais para a mao do personagem
	local alvo = M.TamanhoMax[name]
	if alvo then
		local mdl = Instance.new("Model")
		for _, c in ipairs(tool:GetChildren()) do c.Parent = mdl end
		mdl.PrimaryPart = handle
		local _, sz = mdl:GetBoundingBox()
		local big = math.max(sz.X, sz.Y, sz.Z)
		if big > alvo then mdl:ScaleTo(alvo / big) end
		for _, c in ipairs(mdl:GetChildren()) do c.Parent = tool end
		mdl:Destroy()
	end
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
		end
	end
	local old = handle:FindFirstChild("Boca")
	if old then old:Destroy() end
	local a = Instance.new("Attachment")
	a.Name = "Boca"
	a.Position = muzzleLocal(tool, handle)
	a.Parent = handle
	return tool
end

function M.Build(name)
	local item = M.ItemModel(name)
	if item then return item end
	local f = M.Armas[name] or M.Icones[name]
	if not f then return nil end
	return f()
end

-- Converte um modelo em Tool (servidor)
function M.MakeTool(name, toolName)
	local itemTool = M.ItemTool(name, toolName)
	if itemTool then return itemTool end
	local model = M.Build(name)
	local tool = Instance.new("Tool")
	tool.Name = toolName or name
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	local handle = model.PrimaryPart
	local grip = model:GetAttribute("Grip") or Vector3.zero
	if name == "Punhos" then
		tool.RequiresHandle = false
		model:Destroy()
		return tool
	end
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(grip)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Parent = tool
			if p ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	model:Destroy()
	return tool
end

-- Icone 3D para a interface (cliente)
function M.Viewport(name, parent, opts)
	opts = opts or {}
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Icone"
	vf.BackgroundTransparency = 1
	vf.Size = opts.Size or UDim2.fromScale(1, 1)
	vf.Position = opts.Position or UDim2.new()
	vf.AnchorPoint = opts.AnchorPoint or Vector2.zero
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -2, -0.6)
	vf.ZIndex = opts.ZIndex or 1
	local model = M.Build(name)
	if model then
		model.Parent = vf
		local cf, sz = model:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dir = (opts.Dir or Vector3.new(1, 0.45, -0.35)).Unit
		local dist = sz.Magnitude / (2 * math.tan(math.rad(15))) * (opts.Zoom or 0.95)
		cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
		cam.Parent = vf
		vf.CurrentCamera = cam
	end
	vf.Parent = parent
	return vf
end

return M
