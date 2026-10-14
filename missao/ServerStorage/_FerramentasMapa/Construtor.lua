-- Ferramenta de edicao: monta pecas do mapa no estilo studs.
local B = {}
local R = Random.new(20261012)
B.R = R
function B.rand(a, b) if a == nil then return R:NextNumber() end return R:NextNumber(a, b) end
function B.randi(a, b) return R:NextInteger(a, b) end
function B.pick(t) return t[R:NextInteger(1, #t)] end

local rgb = Color3.fromRGB
B.C = {
	grama = rgb(82,150,60), grama2 = rgb(95,162,68), gramaEscura = rgb(74,140,58),
	terra = rgb(124,88,58), terra2 = rgb(105,74,50),
	areia = rgb(226,207,152), areia2 = rgb(212,192,136),
	pedra = rgb(163,162,165), pedra2 = rgb(140,140,145), pedraEscura = rgb(99,95,98),
	pedraTemplo = rgb(215,197,154), pedraTemplo2 = rgb(196,177,135),
	madeira = rgb(124,82,50), madeira2 = rgb(145,98,60), madeiraEscura = rgb(92,60,38),
	tronco = rgb(105,70,45),
	pinho1 = rgb(44,110,58), pinho2 = rgb(58,128,64),
	folha1 = rgb(75,151,75), folha2 = rgb(96,170,80), folha3 = rgb(62,135,62),
	caminho = rgb(150,110,72), caminho2 = rgb(138,100,66),
	agua = rgb(70,190,200), leito = rgb(196,180,130),
	metal = rgb(70,72,78), metal2 = rgb(99,95,98), neonCiano = rgb(0,229,255),
	amarelo = rgb(245,205,48), laranja = rgb(218,133,65), branco = rgb(242,243,243),
	roxo = rgb(180,100,255), luzQuente = rgb(255,200,120),
}
local C = B.C
B.coresFlores = { rgb(255,102,204), rgb(255,240,90), rgb(250,250,250), rgb(110,153,255), rgb(255,90,90), rgb(200,130,255) }

function B.part(parent, size, cf, color, o)
	o = o or {}
	local p = Instance.new(o.class or "Part")
	if o.shape then p.Shape = o.shape end
	p.Anchored = true
	p.Size = size
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	p.CFrame = cf
	p.Color = color
	p.Material = o.material or Enum.Material.Plastic
	if o.smooth or o.shape then
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	else
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	if o.deco then p.CanCollide = false; p.CanQuery = false; p.CanTouch = false end
	if o.noShadow then p.CastShadow = false end
	if o.transparency then p.Transparency = o.transparency end
	p.Name = o.name or "Bloco"
	p.Parent = parent
	return p
end

function B.model(parent, name)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m
end
function B.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end

-- Bloco de terra com tampa de grama (lateral marrom, topo verde)
function B.land(parent, x1, z1, x2, z2, topY, o)
	o = o or {}
	local bottom = o.bottom or -3
	local sx, sz = math.abs(x2 - x1), math.abs(z2 - z1)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local body = topY - 1 - bottom
	if body > 0.05 then
		B.part(parent, Vector3.new(sx, body, sz), CFrame.new(cx, bottom + body / 2, cz), o.side or C.terra, { name = "Terra" })
	end
	return B.part(parent, Vector3.new(sx, 1, sz), CFrame.new(cx, topY - 0.5, cz), o.top or C.grama, { name = o.topName or "Grama" })
end

-- Recortes blocados nas margens (degraus de grama e praias de areia)
function B.edges(parent, x1, z1, x2, z2, topY, sides, count, o)
	o = o or {}
	for _, s in ipairs(sides) do
		for _ = 1, count do
			local len = B.rand(6, 18)
			local beach = B.rand() < (o.beach or 0.4)
			local depth = beach and B.rand(4, 9) or B.rand(2, 6)
			local ty = beach and (o.beachY or 3.5) or topY
			local a, b, c, d
			if s == "N" then local x = B.rand(x1, x2 - len); a, b, c, d = x, z1 - depth, x + len, z1 + 0.5
			elseif s == "S" then local x = B.rand(x1, x2 - len); a, b, c, d = x, z2 - 0.5, x + len, z2 + depth
			elseif s == "W" then local z = B.rand(z1, z2 - len); a, b, c, d = x1 - depth, z, x1 + 0.5, z + len
			else local z = B.rand(z1, z2 - len); a, b, c, d = x2 - 0.5, z, x2 + depth, z + len end
			if beach then
				B.land(parent, a, b, c, d, ty, { top = B.pick({ C.areia, C.areia2 }), side = C.areia2, topName = "Areia" })
			else
				B.land(parent, a, b, c, d, ty + (B.rand() < 0.3 and -1 or 0), { top = B.pick({ C.grama, C.grama2 }) })
			end
		end
	end
end

function B.pine(parent, pos, s, collide)
	s = s or 1
	local m = Instance.new("Model"); m.Name = "Pinheiro"
	local th = 4 * s
	B.part(m, Vector3.new(1.6, th, 1.6) * Vector3.new(s, 1, s), CFrame.new(pos.X, pos.Y + th / 2, pos.Z), C.tronco, { name = "Tronco", deco = not collide })
	local y = pos.Y + th - 0.6 * s
	local rot = R:NextNumber(0, math.pi / 2)
	for i, w in ipairs({ 9, 7.4, 5.8, 4.2, 2.6 }) do
		local h = 2.6 * s
		local col = (i % 2 == 1) and C.pinho1 or C.pinho2
		B.part(m, Vector3.new(w * s, h, w * s), CFrame.new(pos.X, y + h / 2, pos.Z) * CFrame.Angles(0, rot + (i % 2) * 0.2, 0), col, { name = "Folhas", deco = true })
		y += h * 0.82
	end
	B.part(m, Vector3.new(1, 1.8, 1) * s, CFrame.new(pos.X, y + 0.9 * s, pos.Z), C.pinho2, { name = "Ponta", deco = true })
	m.Parent = parent
	return m
end

function B.cubeTree(parent, pos, s, collide)
	s = s or 1
	local m = Instance.new("Model"); m.Name = "Arvore"
	local th = 6 * s
	B.part(m, Vector3.new(2 * s, th, 2 * s), CFrame.new(pos.X, pos.Y + th / 2, pos.Z), C.tronco, { name = "Tronco", deco = not collide })
	local top = pos.Y + th
	local base = CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, R:NextNumber(0, math.pi), 0)
	B.part(m, Vector3.new(9, 7, 9) * s, base * CFrame.new(0, top + 3 * s, 0), C.folha1, { name = "Copa", deco = true })
	B.part(m, Vector3.new(6, 5, 6) * s, base * CFrame.new(3 * s, top + 1.5 * s, 2 * s), C.folha2, { name = "Copa", deco = true })
	B.part(m, Vector3.new(5.5, 4.5, 5.5) * s, base * CFrame.new(-2.5 * s, top + 6 * s, -1.5 * s), C.folha3, { name = "Copa", deco = true })
	B.part(m, Vector3.new(5, 4, 5) * s, base * CFrame.new(-3 * s, top + 0.8 * s, 2.5 * s), C.folha2, { name = "Copa", deco = true })
	m.Parent = parent
	return m
end

function B.tree(parent, pos, collide)
	if B.rand() < 0.65 then return B.pine(parent, pos, B.rand(0.8, 1.35), collide) end
	return B.cubeTree(parent, pos, B.rand(0.75, 1.15), collide)
end

function B.bush(parent, pos, s)
	s = s or 1
	local m = Instance.new("Model"); m.Name = "Arbusto"
	local base = CFrame.new(pos) * CFrame.Angles(0, B.rand(0, 3), 0)
	B.part(m, Vector3.new(4, 3, 4) * s, base * CFrame.new(0, 1.5 * s, 0), C.folha1, { deco = true, name = "Folhas" })
	B.part(m, Vector3.new(3, 2.4, 3) * s, base * CFrame.new(1.8 * s, 1.1 * s, 1 * s), C.folha2, { deco = true, name = "Folhas" })
	B.part(m, Vector3.new(2.6, 2.2, 2.6) * s, base * CFrame.new(-1.5 * s, 1.8 * s, -1 * s), C.folha3, { deco = true, name = "Folhas" })
	m.Parent = parent
	return m
end

function B.flower(parent, pos, color)
	local m = Instance.new("Model"); m.Name = "Flor"
	color = color or B.pick(B.coresFlores)
	B.part(m, Vector3.new(0.25, 1, 0.25), CFrame.new(pos + Vector3.new(0, 0.5, 0)), C.folha3, { deco = true, smooth = true, noShadow = true, name = "Caule" })
	B.part(m, Vector3.new(0.9, 0.5, 0.9), CFrame.new(pos + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, B.rand(0, 1.5), 0), color, { deco = true, smooth = true, noShadow = true, name = "Petalas" })
	m.Parent = parent
	return m
end

function B.tuft(parent, pos)
	local m = Instance.new("Model"); m.Name = "Capim"
	for i = 1, 3 do
		local h = B.rand(1, 1.9)
		B.part(m, Vector3.new(0.3, h, 0.3), CFrame.new(pos + Vector3.new(B.rand(-0.5, 0.5), h / 2, B.rand(-0.5, 0.5))) * CFrame.Angles(B.rand(-0.25, 0.25), B.rand(0, 3), B.rand(-0.25, 0.25)), B.pick({ C.grama2, C.folha2, C.folha3 }), { deco = true, smooth = true, noShadow = true, name = "Folha" })
	end
	m.Parent = parent
	return m
end

function B.rock(parent, pos, s, collide)
	s = s or 1
	local m = Instance.new("Model"); m.Name = "Pedra"
	local cf = CFrame.new(pos) * CFrame.Angles(B.rand(-0.15, 0.15), B.rand(0, 3), B.rand(-0.15, 0.15))
	local sz = Vector3.new(B.rand(2.5, 3.5), B.rand(1.6, 2.4), B.rand(2.2, 3)) * s
	B.part(m, sz, cf * CFrame.new(0, sz.Y / 2 - 0.3, 0), B.pick({ C.pedra, C.pedra2 }), { deco = not collide, name = "Rocha" })
	B.part(m, sz * 0.6, cf * CFrame.new(sz.X * 0.45, sz.Y * 0.3 - 0.3, sz.Z * 0.2) * CFrame.Angles(0, 0.6, 0), C.pedra2, { deco = true, name = "Rocha" })
	m.Parent = parent
	return m
end

function B.log(parent, pos, len, yaw)
	local m = Instance.new("Model"); m.Name = "Tronco caido"
	local cf = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw or 0, 0)
	B.part(m, Vector3.new(len, 1.8, 1.8), cf, C.tronco, { shape = Enum.PartType.Cylinder, deco = true, name = "Tora" })
	B.part(m, Vector3.new(0.2, 1.5, 1.5), cf * CFrame.new(len / 2, 0, 0), C.madeira2, { shape = Enum.PartType.Cylinder, deco = true, name = "Ponta" })
	B.part(m, Vector3.new(0.2, 1.5, 1.5), cf * CFrame.new(-len / 2, 0, 0), C.madeira2, { shape = Enum.PartType.Cylinder, deco = true, name = "Ponta" })
	m.Parent = parent
	return m
end

function B.lamp(parent, pos, withLight)
	local m = Instance.new("Model"); m.Name = "Poste de luz"
	B.part(m, Vector3.new(1.8, 0.8, 1.8), CFrame.new(pos + Vector3.new(0, 0.4, 0)), C.pedra2, { name = "Base" })
	B.part(m, Vector3.new(0.8, 7, 0.8), CFrame.new(pos + Vector3.new(0, 4.3, 0)), C.madeiraEscura, { name = "Haste" })
	B.part(m, Vector3.new(2.2, 0.4, 2.2), CFrame.new(pos + Vector3.new(0, 9.9, 0)), C.metal, { name = "Tampa", deco = true })
	local l = B.part(m, Vector3.new(1.3, 1.3, 1.3), CFrame.new(pos + Vector3.new(0, 9.05, 0)), C.luzQuente, { name = "Lampada", material = Enum.Material.Neon, deco = true, smooth = true })
	if withLight ~= false then
		local pl = Instance.new("PointLight"); pl.Range = 18; pl.Brightness = 1.3; pl.Color = C.luzQuente; pl.Shadows = false; pl.Parent = l
	end
	m.Parent = parent
	return m
end

function B.fence(parent, a, b, y, color)
	local m = Instance.new("Model"); m.Name = "Cerca"
	local A, Bp = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	local L = (Bp - A).Magnitude
	local cf = CFrame.lookAt(A, Bp)
	local n = math.max(1, math.floor(L / 4 + 0.5))
	for i = 0, n do
		B.part(m, Vector3.new(0.7, 3.2, 0.7), cf * CFrame.new(0, 1.6, -L * i / n), color or C.madeiraEscura, { name = "Mourao" })
	end
	B.part(m, Vector3.new(0.35, 0.45, L), cf * CFrame.new(0, 2.6, -L / 2), C.madeira2, { name = "Ripa", smooth = true })
	B.part(m, Vector3.new(0.35, 0.45, L), cf * CFrame.new(0, 1.3, -L / 2), C.madeira2, { name = "Ripa", smooth = true })
	m.Parent = parent
	return m
end

function B.crate(parent, pos, s, yaw)
	s = s or 3
	local m = Instance.new("Model"); m.Name = "Caixote"
	local cf = CFrame.new(pos + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, yaw or B.rand(-0.3, 0.3), 0)
	B.part(m, Vector3.new(s, s, s), cf, C.madeira2, { name = "Caixa" })
	B.part(m, Vector3.new(s + 0.1, 0.35, s + 0.1), cf * CFrame.new(0, s * 0.25, 0), C.madeiraEscura, { name = "Cinta", deco = true })
	B.part(m, Vector3.new(s + 0.1, 0.35, s + 0.1), cf * CFrame.new(0, -s * 0.25, 0), C.madeiraEscura, { name = "Cinta", deco = true })
	m.Parent = parent
	return m
end

function B.barrel(parent, pos)
	local m = Instance.new("Model"); m.Name = "Barril"
	local cf = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	B.part(m, Vector3.new(3.2, 2.4, 2.4), cf, C.madeira, { shape = Enum.PartType.Cylinder, name = "Corpo" })
	B.part(m, Vector3.new(0.3, 2.55, 2.55), cf * CFrame.new(0.9, 0, 0), C.metal, { shape = Enum.PartType.Cylinder, deco = true, name = "Aro" })
	B.part(m, Vector3.new(0.3, 2.55, 2.55), cf * CFrame.new(-0.9, 0, 0), C.metal, { shape = Enum.PartType.Cylinder, deco = true, name = "Aro" })
	m.Parent = parent
	return m
end

function B.reed(parent, pos)
	local m = Instance.new("Model"); m.Name = "Taboa"
	local h = B.rand(2.5, 4)
	local cf = CFrame.new(pos) * CFrame.Angles(B.rand(-0.12, 0.12), 0, B.rand(-0.12, 0.12))
	B.part(m, Vector3.new(0.22, h, 0.22), cf * CFrame.new(0, h / 2, 0), C.folha3, { deco = true, smooth = true, noShadow = true, name = "Haste" })
	B.part(m, Vector3.new(0.45, 1, 0.45), cf * CFrame.new(0, h - 0.6, 0), C.madeiraEscura, { deco = true, smooth = true, noShadow = true, name = "Espiga" })
	m.Parent = parent
	return m
end

function B.sign(parent, pos, yaw, text)
	local m = Instance.new("Model"); m.Name = "Placa"
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	B.part(m, Vector3.new(0.6, 4, 0.6), cf * CFrame.new(0, 2, 0), C.madeiraEscura, { name = "Poste" })
	local board = B.part(m, Vector3.new(4.5, 2.2, 0.4), cf * CFrame.new(0, 4, 0), C.madeira2, { name = "Tabua" })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.Parent = board
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.Text = text or "???"
		t.TextColor3 = rgb(255, 245, 220); t.TextStrokeTransparency = 0.3; t.TextStrokeColor3 = rgb(60, 35, 20); t.Name = "Texto"; t.Parent = g
	end
	m.Parent = parent
	return m
end

-- Escada blocada descendo de topY ate bottomY, na direcao dir (XZ)
function B.steps(parent, top, dir, width, topY, bottomY, depth, color)
	depth = depth or 1.5
	local m = Instance.new("Model"); m.Name = "Escada"
	local base = CFrame.lookAt(Vector3.new(top.X, 0, top.Z), Vector3.new(top.X + dir.X, 0, top.Z + dir.Z))
	local n = math.floor(topY - bottomY + 0.5)
	for i = 1, n do
		local st = topY - i
		local h = st - (bottomY - 2)
		local along = (i - 0.5) * depth
		B.part(m, Vector3.new(width, h, depth), base * CFrame.new(0, (st + bottomY - 2) / 2, -along), (i % 2 == 0) and C.pedra or C.pedra2, { name = "Degrau" })
		for _, sx in ipairs({ -width / 2 - 0.5, width / 2 + 0.5 }) do
			B.part(m, Vector3.new(1, h + 1.2, depth), base * CFrame.new(sx, (st + 1.2 + bottomY - 2) / 2, -along), C.pedraEscura, { name = "Mureta" })
		end
	end
	m.Parent = parent
	return m, n * depth
end

function B.path(parent, a, b, width, y, color)
	local m = Instance.new("Model"); m.Name = "Trilha"
	local A, Bp = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	local L = (Bp - A).Magnitude
	local cf = CFrame.lookAt(A, Bp)
	B.part(m, Vector3.new(width, 0.4, L + 1), cf * CFrame.new(0, 0.2, -L / 2), color or C.caminho, { name = "Terra" })
	local k = math.floor(L / 6)
	for i = 1, k do
		local side = (i % 2 == 0) and 1 or -1
		B.part(m, Vector3.new(B.rand(1.5, 3), 0.4, B.rand(2, 4)), cf * CFrame.new(side * (width / 2 + 0.6), 0.18, -L * i / (k + 1)), C.caminho2, { name = "Terra", deco = true })
	end
	m.Parent = parent
	return m
end

function B.invis(parent, a, b, baseY, height, name)
	local A, Bp = Vector3.new(a.X, baseY, a.Z), Vector3.new(b.X, baseY, b.Z)
	local L = (Bp - A).Magnitude
	local cf = CFrame.lookAt(A, Bp) * CFrame.new(0, height / 2, -L / 2)
	local p = B.part(parent, Vector3.new(1, height, L + 0.5), cf, C.branco, { smooth = true, transparency = 1, noShadow = true, name = name or "Barreira" })
	p.CanQuery = false; p.CanTouch = false
	return p
end

function B.fogWall(parent, pos, dir, width, height, area)
	local center = pos + Vector3.new(0, height / 2, 0)
	local p = B.part(parent, Vector3.new(width, height, 3), CFrame.lookAt(center, center + Vector3.new(dir.X, 0, dir.Z)), C.branco, { smooth = true, transparency = 1, noShadow = true, name = "ParedeNevoa_" .. area })
	p.CanQuery = false; p.CanTouch = false
	p:SetAttribute("Area", area)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Bruma"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(245, 248, 255))
	e.LightEmission = 0.15
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 13) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.35), NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 10
	e.Speed = NumberRange.new(0.4, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.RotSpeed = NumberRange.new(-12, 12)
	e.Rotation = NumberRange.new(0, 360)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	return p
end

-- Ponte de tabuas com postes, vigas e corrimao. Retorna lista ordenada.
function B.woodBridge(parent, a, b, width, deckY, bedY)
	bedY = bedY or -3
	local A, Bp = Vector3.new(a.X, deckY, a.Z), Vector3.new(b.X, deckY, b.Z)
	local L = (Bp - A).Magnitude
	local cf0 = CFrame.lookAt(A, Bp)
	local pieces = {}
	local function add(p) table.insert(pieces, p); p:SetAttribute("Ordem", #pieces) end
	local n = math.max(2, math.floor(L / 2 + 0.5))
	local pitch = L / n
	local hw = width / 2
	local postsZ = {}
	local woods = { C.madeira, C.madeira2, C.madeiraEscura }
	for i = 0, n - 1 do
		local z = -(i + 0.5) * pitch
		add(B.part(parent, Vector3.new(width + B.rand(-0.5, 0.3), 0.8, pitch - 0.25), cf0 * CFrame.new(B.rand(-0.15, 0.15), -0.4, z) * CFrame.Angles(0, B.rand(-0.03, 0.03), 0), woods[(i % 3) + 1], { name = "Tabua" }))
		add(B.part(parent, Vector3.new(1, 1, pitch), cf0 * CFrame.new(-hw + 0.7, -1.3, z), C.madeiraEscura, { name = "Viga" }))
		add(B.part(parent, Vector3.new(1, 1, pitch), cf0 * CFrame.new(hw - 0.7, -1.3, z), C.madeiraEscura, { name = "Viga" }))
		if i % 3 == 0 or i == n - 1 then
			local zp = (i == n - 1) and -(n * pitch - 0.45) or -(i * pitch + 0.45)
			table.insert(postsZ, zp)
			local topY, botY = deckY + 3.4, bedY
			for _, sx in ipairs({ -hw - 0.45, hw + 0.45 }) do
				add(B.part(parent, Vector3.new(0.9, topY - botY, 0.9), cf0 * CFrame.new(sx, (topY + botY) / 2 - deckY, zp), C.tronco, { name = "Poste" }))
			end
			if #postsZ >= 2 then
				local z1, z2 = postsZ[#postsZ - 1], postsZ[#postsZ]
				local len = math.abs(z2 - z1)
				for _, sx in ipairs({ -hw - 0.45, hw + 0.45 }) do
					add(B.part(parent, Vector3.new(0.5, 0.45, len), cf0 * CFrame.new(sx, 3, (z1 + z2) / 2), C.madeira2, { name = "Corrimao", smooth = true }))
					add(B.part(parent, Vector3.new(0.35, 0.35, len), cf0 * CFrame.new(sx, 1.6, (z1 + z2) / 2), C.madeira, { name = "Corrimao", smooth = true }))
				end
			end
		end
	end
	return pieces, L, cf0
end

-- Ponte de pedra em arco. Retorna lista ordenada.
function B.stoneBridge(parent, a, b, width, deckY, bedY)
	bedY = bedY or -3
	local A, Bp = Vector3.new(a.X, deckY, a.Z), Vector3.new(b.X, deckY, b.Z)
	local L = (Bp - A).Magnitude
	local cf0 = CFrame.lookAt(A, Bp)
	local pieces = {}
	local function add(p) table.insert(pieces, p); p:SetAttribute("Ordem", #pieces) end
	local n = math.max(3, math.floor(L / 3 + 0.5))
	local pitch = L / n
	local hw = width / 2
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local z = -(i + 0.5) * pitch
		add(B.part(parent, Vector3.new(width, 1.5, pitch), cf0 * CFrame.new(0, -0.75, z), (i % 2 == 0) and C.pedra or C.pedra2, { name = "Piso" }))
		local u = (2 * t - 1) ^ 4
		local under = (deckY - 4.5) - ((deckY - 4.5) - bedY) * u
		local h = (deckY - 1.5) - under
		if h > 0.3 then
			add(B.part(parent, Vector3.new(width - 1, h, pitch), cf0 * CFrame.new(0, (under + deckY - 1.5) / 2 - deckY, z), C.pedraEscura, { name = "Arco" }))
		end
		for _, sx in ipairs({ -hw + 0.6, hw - 0.6 }) do
			add(B.part(parent, Vector3.new(1.2, 1.8, pitch), cf0 * CFrame.new(sx, 0.9, z), C.pedra2, { name = "Parapeito" }))
			if i % 2 == 0 then
				add(B.part(parent, Vector3.new(1.6, 0.6, 1.6), cf0 * CFrame.new(sx, 2.1, z), C.pedra, { name = "Capitel" }))
			end
		end
	end
	return pieces, L, cf0
end

function B.forest(parent, x1, z1, x2, z2, n, y, avoid, collide)
	local made = 0
	for _ = 1, n * 3 do
		if made >= n then break end
		local x, z = B.rand(x1, x2), B.rand(z1, z2)
		if not (avoid and avoid(x, z)) then
			B.tree(parent, Vector3.new(x, y, z), collide)
			made += 1
		end
	end
	return made
end

return B
