-- [ArmasCliente] Hotbar (1 = arma, 2 = martelo) e a SENSACAO do tiro no estilo do video:
-- camera de mira atras do jogador (PC) com a mira travada no centro, colchetes de trava no
-- inimigo, recuo e tremor de camera, braco acompanhando a mira, clarao grande com faiscas,
-- impactos, marcador de acerto/abate, numeros de dano que "pulam", corpos lancados ao morrer
-- e foguete visivel com explosao. Dano e dinheiro continuam decididos no servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local Modelos = require(Shared:WaitForChild("ModelosArmas"))
local remotes = Shared:WaitForChild("Remotes")
local SENS = Cfg.Sensacao or {}
local MIRA = Cfg.Mira or {}
local gameSettings = UserSettings():GetService("UserGameSettings")

-- esconde a mochila e a barra de vida padrao do Roblox
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

local MINT = Color3.fromRGB(98, 226, 160)
local HIT_RED = Color3.fromRGB(255, 70, 70)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local rng = Random.new()

local function weaponCfg(id)
	for _, w in ipairs(Cfg.Armas) do if w.Id == id then return w end end
end
local function feelOf(id) return SENS[id] or { Recuo = 1, Tremor = 0.2, Clarao = 1 } end

-- HOTBAR ---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Hotbar"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")
local scale = Instance.new("UIScale")
scale.Parent = gui
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720), 0.6, 1.4) end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local bar = Instance.new("Frame")
bar.Name = "Slots"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.Size = UDim2.fromOffset(52 * 2 + 4, 52)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 4)
layout.Parent = bar

local slots = {}
for i = 1, 2 do
	local f = Instance.new("TextButton")
	f.Name = "Slot" .. i
	f.Text = ""
	f.AutoButtonColor = false
	f.Size = UDim2.fromOffset(52, 52)
	f.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	f.LayoutOrder = i
	f.Parent = bar
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromOffset(14, 14)
	tag.Position = UDim2.fromOffset(3, 3)
	tag.BackgroundColor3 = MINT
	tag.BorderSizePixel = 0
	tag.Text = tostring(i)
	tag.FontFace = FONT
	tag.TextSize = 11
	tag.TextColor3 = Color3.fromRGB(10, 10, 10)
	tag.ZIndex = 3
	tag.Parent = f
	slots[i] = { frame = f, icon = nil, id = nil }
end

local function toolsBySlot()
	local list = {}
	local char = player.Character
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), char }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Slot") then list[t:GetAttribute("Slot")] = t end
			end
		end
	end
	return list
end

local function equipped()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Tool")
end

local function refreshHotbar()
	local list = toolsBySlot()
	local eq = equipped()
	for i, s in ipairs(slots) do
		local t = list[i]
		local id = t and t:GetAttribute("Arma")
		if id ~= s.id then
			if s.icon then s.icon:Destroy() end
			s.icon = id and Modelos.Viewport(id, s.frame, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 2, Zoom = 0.85 }) or nil
			s.id = id
		end
		local on = t ~= nil and t == eq
		s.frame.BackgroundColor3 = on and Color3.fromRGB(242, 242, 242) or Color3.fromRGB(40, 40, 40)
		s.frame.BackgroundTransparency = on and 0 or 0.35
	end
end

local function toggleSlot(i)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local t = toolsBySlot()[i]
	if not t then return end
	if t.Parent == char then
		hum:UnequipTools()
	else
		hum:EquipTool(t)
	end
end

for i, s in ipairs(slots) do
	s.frame.MouseButton1Click:Connect(function() toggleSlot(i) end)
end
ContextActionService:BindAction("Slot1", function(_, st)
	if st == Enum.UserInputState.Begin then toggleSlot(1) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.One, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("Slot2", function(_, st)
	if st == Enum.UserInputState.Begin then toggleSlot(2) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Two, Enum.KeyCode.G)

-- MIRA (interface) ----------------------------------------------------------------
local crossGui = Instance.new("ScreenGui")
crossGui.Name = "Mira"
crossGui.ResetOnSpawn = false
crossGui.IgnoreGuiInset = true
crossGui.DisplayOrder = 50
crossGui.Parent = player.PlayerGui

local function corners(parent, len, thick, color)
	local list = {}
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		for _, horiz in ipairs({ true, false }) do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(c[1], c[2])
			f.Position = UDim2.fromScale(c[1], c[2])
			f.Size = horiz and UDim2.fromOffset(len, thick) or UDim2.fromOffset(thick, len)
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			local st = Instance.new("UIStroke"); st.Thickness = 1; st.Color = Color3.fromRGB(10, 30, 20); st.Parent = f
			f.Parent = parent
			table.insert(list, f)
		end
	end
	return list
end

-- colchetes "[ ]" como no video
local cross = Instance.new("Frame")
cross.Name = "Colchetes"
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Size = UDim2.fromOffset(26, 26)
cross.BackgroundTransparency = 1
cross.Visible = false
cross.Parent = crossGui
local crossBars = corners(cross, 8, 2, MINT)
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(3, 3)
dot.BackgroundColor3 = MINT
dot.BorderSizePixel = 0
dot.Parent = cross
table.insert(crossBars, dot)

-- marcador de acerto (X)
local hitMark = Instance.new("Frame")
hitMark.AnchorPoint = Vector2.new(0.5, 0.5)
hitMark.Size = UDim2.fromOffset(34, 34)
hitMark.BackgroundTransparency = 1
hitMark.Visible = false
hitMark.Parent = crossGui
local hitLines = {}
for _, d in ipairs({ { -1, -1, 45 }, { 1, -1, -45 }, { -1, 1, -45 }, { 1, 1, 45 } }) do
	local l = Instance.new("Frame")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, d[1] * 10, 0.5, d[2] * 10)
	l.Size = UDim2.fromOffset(11, 3)
	l.Rotation = d[3]
	l.BorderSizePixel = 0
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 1; st.Color = Color3.fromRGB(20, 20, 20); st.Parent = l
	l.Parent = hitMark
	table.insert(hitLines, l)
end
local hitScale = Instance.new("UIScale"); hitScale.Parent = hitMark
local hitUntil, hitKill = 0, false

-- trava no inimigo (colchetes em volta do alvo)
local lockFrame = Instance.new("Frame")
lockFrame.AnchorPoint = Vector2.new(0.5, 0.5)
lockFrame.BackgroundTransparency = 1
lockFrame.Visible = false
lockFrame.Parent = crossGui
corners(lockFrame, 10, 2, MINT)

local bloom = 0

local function showHit(kill)
	hitUntil = os.clock() + (kill and 0.35 or 0.14)
	hitKill = kill
	for _, l in ipairs(hitLines) do l.BackgroundColor3 = kill and HIT_RED or Color3.new(1, 1, 1) end
	hitScale.Scale = kill and 1.6 or 1.3
	TweenService:Create(hitScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- AUDIO ------------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "SonsArmas"
soundFolder.Parent = workspace.CurrentCamera
local function playSound(id, vol, speed, at)
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = vol or 0.5
	snd.PlaybackSpeed = speed or 1
	if at then
		local p = Instance.new("Attachment")
		p.WorldPosition = at
		p.Parent = workspace.Terrain
		snd.RollOffMaxDistance = 220
		snd.Parent = p
		Debris:AddItem(p, 3)
	else
		snd.Parent = soundFolder
		Debris:AddItem(snd, 3)
	end
	snd:Play()
end
-- sons do jogo (Config/Sons): nada de sons classicos do Roblox
local SONS = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sons"))
local SOM = {
	Tiro = SONS.Tiro.Padrao.Id,
	Estalo = SONS.Capsula.Id,
	Foguete = SONS.Explosao.Id,
	Explosao = SONS.Explosao.Id,
	Soco = SONS.Golpe.Id,
	Martelo = SONS.Martelo.Id,
	Acerto = SONS.Acerto.Id,
	Abate = SONS.Abate.Id,
	Impacto = SONS.Soco.Id,
}
-- som de tiro de cada arma
local function shotSound(w)
	local s = (w and SONS.Tiro[w.Id]) or SONS.Tiro.Padrao
	return s.Id, s.V or 0.4, s.P or 1
end
local lastHitSound = 0

-- EFEITOS ------------------------------------------------------------------------
local fx = Instance.new("Folder")
fx.Name = "EfeitosLocais"
fx.Parent = workspace.CurrentCamera

local function basePart(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = fx
	return p
end

local function emitter(parent, props, n)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	if n then e:Emit(n) end
	return e
end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function tracer(from, to, color, width)
	local d = (to - from).Magnitude
	if d < 0.1 then return end
	width = width or 0.22
	local p = basePart({ Color = color or Color3.fromRGB(255, 232, 140), Size = Vector3.new(width, width, d), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -d / 2) })
	TweenService:Create(p, TweenInfo.new(0.09, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(0.04, 0.04, d) }):Play()
	Debris:AddItem(p, 0.12)
end

local chips -- definido mais abaixo (lascas quadradas)
local kickFov -- definido mais abaixo (soco de FOV de cada tiro)

local function muzzleFlash(at, dir, size)
	if size <= 0 then return end
	dir = (dir and dir.Magnitude > 0.01) and dir.Unit or Vector3.new(0, 0, -1)
	local ball = basePart({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 226, 130), Size = Vector3.one * 0.9 * size, Position = at })
	-- clarao que ILUMINA o ambiente (chao, paredes, inimigos perto) + facho para a frente
	local light = Instance.new("PointLight"); light.Range = 16 + 6 * size; light.Brightness = 9; light.Color = Color3.fromRGB(255, 196, 100); light.Shadows = false; light.Parent = ball
	local spot = Instance.new("SpotLight"); spot.Face = Enum.NormalId.Front; spot.Angle = 70; spot.Range = 26 + 6 * size; spot.Brightness = 6; spot.Color = Color3.fromRGB(255, 214, 140); spot.Parent = ball
	ball.CFrame = CFrame.lookAt(at, at + dir)
	TweenService:Create(ball, TweenInfo.new(0.08), { Size = Vector3.one * 1.7 * size, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.11, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	TweenService:Create(spot, TweenInfo.new(0.09, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(ball, 0.13)
	local cone = basePart({ Color = Color3.fromRGB(255, 245, 190), Size = Vector3.new(0.35, 0.35, 1.6) * size, CFrame = CFrame.lookAt(at, at + dir) * CFrame.new(0, 0, -0.8 * size) })
	TweenService:Create(cone, TweenInfo.new(0.06), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 2.2) * size }):Play()
	Debris:AddItem(cone, 0.08)
	local att = Instance.new("Attachment")
	att.WorldCFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-90), 0, 0)
	att.Parent = workspace.Terrain
	emitter(att, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)), LightEmission = 1,
		Size = NumberSequence.new(0.35 * size, 0), Lifetime = NumberRange.new(0.08, 0.18), Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(22, 22) }, math.floor(4 + 3 * size))
	emitter(att, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(235, 230, 220)), Transparency = NumberSequence.new(0.55, 1),
		Size = NumberSequence.new(0.5 * size, 1.4 * size), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(20, 20) }, 1)
	Debris:AddItem(att, 0.6)
	chips(at + dir * 0.4, 2, 7)
end

-- LANCA-CHAMAS: jato de fogo no lugar do tracante
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local function flame(from, to)
	local dir = to - from
	local d = dir.Magnitude
	if d < 0.2 then return end
	local att = Instance.new("Attachment")
	att.WorldCFrame = CFrame.lookAt(from, to) * CFrame.Angles(math.rad(-90), 0, 0)
	att.Parent = workspace.Terrain
	local life = 0.32
	emitter(att, { Texture = FIRE, LightEmission = 0.9,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 160)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 20)) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(0.6, 2.6), Lifetime = NumberRange.new(life * 0.8, life), Speed = NumberRange.new(d / life * 0.85, d / life),
		SpreadAngle = Vector2.new(7, 7), RotSpeed = NumberRange.new(-200, 200), Rotation = NumberRange.new(0, 360) }, 4)
	Debris:AddItem(att, life + 0.2)
end

-- golpe corpo a corpo: rastro em arco na frente do personagem
local function slashArc(root, color, reach, idx)
	local cf = root.CFrame * CFrame.new(0, 0.5, 0)
	local n = 9
	local a0, a1 = -75, 75
	if idx == 2 then a0, a1 = 75, -75 end
	local tilt = idx == 3 and math.rad(70) or math.rad(idx == 2 and -18 or 18)
	local r = math.max(2.6, reach * 0.62)
	for i = 0, n - 1 do
		local a = math.rad(a0 + (a1 - a0) * i / (n - 1))
		local seg = basePart({ Color = color, Transparency = 0.1 + i * 0.05,
			Size = Vector3.new(0.16, 0.55 * (1 - i / n * 0.6), r * 0.32),
			CFrame = cf * CFrame.Angles(0, 0, tilt) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r) * CFrame.Angles(0, math.rad(90), 0) })
		TweenService:Create(seg, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, i * 0.012),
			{ Transparency = 1, Size = seg.Size * Vector3.new(1, 0.2, 1) }):Play()
		Debris:AddItem(seg, 0.32)
	end
end

-- golpe no chao (Martelo do Trovao): onda que se espalha + lascas
local function groundSlam(root, color, radius)
	local pos = root.Position - Vector3.new(0, 2.9, 0)
	local ring = basePart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.15, Size = Vector3.new(0.25, 2, 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.25, radius * 2.2, radius * 2.2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
	local flash = basePart({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 255, 220), Size = Vector3.one * 2, Position = pos + Vector3.new(0, 0.6, 0) })
	TweenService:Create(flash, TweenInfo.new(0.18), { Size = Vector3.one * radius, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.2)
	chips(pos + Vector3.new(0, 0.8, 0), 14, 22)
end

-- "lascas" quadradas amarelas/laranja voando (as particulas blocadas do video)
local CHIP_COLORS = { Color3.fromRGB(255, 232, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 248, 200) }
function chips(pos, n, speed, color)
	for _ = 1, n do
		local s = rng:NextNumber(0.16, 0.36)
		local p = basePart({ Color = color or CHIP_COLORS[rng:NextInteger(1, #CHIP_COLORS)], Size = Vector3.one * s,
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1.3), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(speed * 0.5, speed)
		local life = rng:NextNumber(0.22, 0.42)
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = (p.CFrame + dir * life - Vector3.new(0, 2.5 * life, 0)) * CFrame.Angles(2, 1, 0), Size = Vector3.one * 0.04, Transparency = 0.5 }):Play()
		Debris:AddItem(p, life + 0.03)
	end
end

local function impact(at, onEnemy)
	chips(at, onEnemy and 6 or 3, onEnemy and 14 or 8)
	if onEnemy then
		local p = basePart({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Size = Vector3.one * 0.6, Position = at, Transparency = 0.1 })
		TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 2.4, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.2)
		local att = Instance.new("Attachment"); att.WorldPosition = at; att.Parent = workspace.Terrain
		emitter(att, { Texture = SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.8,
			Size = NumberSequence.new(0.45, 0), Lifetime = NumberRange.new(0.12, 0.25), Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(180, 180) }, 6)
		Debris:AddItem(att, 0.5)
	else
		local p = basePart({ Color = Color3.fromRGB(255, 240, 170), Size = Vector3.one * 0.35, Position = at })
		TweenService:Create(p, TweenInfo.new(0.12), { Size = Vector3.one * 0.9, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.15)
		local att = Instance.new("Attachment"); att.WorldPosition = at; att.Parent = workspace.Terrain
		emitter(att, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 190, 170)), Transparency = NumberSequence.new(0.4, 1),
			Size = NumberSequence.new(0.4, 1.3), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top }, 2)
		Debris:AddItem(att, 0.7)
	end
end

local function enemyNear(pos, maxD)
	local folder = workspace:FindFirstChild("InimigosAtivos")
	if not folder then return nil end
	local best, bd
	for _, m in ipairs(folder:GetChildren()) do
		local b = m:FindFirstChild("Corpo")
		if b then
			local d = (b.Position - pos).Magnitude - b.Size.X / 2
			if d <= (maxD or 2) and (not bd or d < bd) then best, bd = m, d end
		end
	end
	return best
end

local flashing = setmetatable({}, { __mode = "k" })
local function hitFlash(model)
	if not model or flashing[model] then return end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = fx
	flashing[model] = true
	task.delay(0.07, function()
		h:Destroy()
		flashing[model] = nil
	end)
end

-- CAMERA: recuo, tremor e camera de mira ---------------------------------------------
local recoilPitch, recoilYaw, shake, armKick = 0, 0, 0, 0
local function addShake(amount) shake = math.min(2.5, shake + amount) end

local function explosion(pos, radius)
	local cam = workspace.CurrentCamera
	local core = basePart({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 160), Size = Vector3.one * 2, Position = pos })
	local ball = basePart({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 140, 40), Size = Vector3.one * 2, Position = pos, Transparency = 0.1 })
	local light = Instance.new("PointLight"); light.Range = radius * 3; light.Brightness = 6; light.Color = Color3.fromRGB(255, 170, 80); light.Parent = core
	TweenService:Create(core, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 1.2, Transparency = 1 }):Play()
	TweenService:Create(ball, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 2.3, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	Debris:AddItem(core, 0.25)
	Debris:AddItem(ball, 0.45)
	local att = Instance.new("Attachment"); att.WorldPosition = pos; att.Parent = workspace.Terrain
	emitter(att, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(90, 80, 75)), Transparency = NumberSequence.new(0.2, 1),
		Size = NumberSequence.new(radius * 0.4, radius * 0.9), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180), Drag = 3, Acceleration = Vector3.new(0, 4, 0) }, 14)
	emitter(att, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)), LightEmission = 1,
		Size = NumberSequence.new(0.7, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(25, 45),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -50, 0) }, 22)
	Debris:AddItem(att, 1.6)
	playSound(SOM.Explosao, 0.7, 0.95 + rng:NextNumber() * 0.1, pos)
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 50
	addShake((feelOf("Bazuca").TremorExplosao or 1.2) * math.clamp(1 - d / 90, 0.15, 1))
end

local function rocket(from, to, onArrive)
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.5 then onArrive() return end
	local speed = feelOf("Bazuca").VelocidadeFoguete or 170
	local body = basePart({ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 120, 40), Size = Vector3.new(0.45, 0.45, 1.4), CFrame = CFrame.lookAt(from, to) })
	local tip = basePart({ Color = Color3.fromRGB(110, 220, 90), Size = Vector3.new(0.4, 0.4, 0.4), CFrame = body.CFrame * CFrame.new(0, 0, -0.85) })
	local flame = basePart({ Color = Color3.fromRGB(255, 200, 90), Size = Vector3.new(0.35, 0.35, 0.6), CFrame = body.CFrame * CFrame.new(0, 0, 0.95) })
	local trail = emitter(body, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(220, 215, 205)), Transparency = NumberSequence.new(0.3, 1),
		Size = NumberSequence.new(0.6, 1.8), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.5, 1.5), Rate = 90,
		EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(10, 10) })
	trail.Enabled = true
	local t, total = 0, dist / speed
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local u = math.min(1, t / total)
		local cf = CFrame.lookAt(from + dir * u, to) * CFrame.Angles(0, 0, t * 20)
		body.CFrame = cf
		tip.CFrame = cf * CFrame.new(0, 0, -0.85)
		flame.CFrame = cf * CFrame.new(0, 0, 0.95)
		flame.Size = Vector3.new(0.35, 0.35, 0.5 + rng:NextNumber() * 0.5)
		if u >= 1 then
			conn:Disconnect()
			trail.Enabled = false
			tip:Destroy(); flame:Destroy()
			body.Transparency = 1
			Debris:AddItem(body, 0.9)
			onArrive()
		end
	end)
end

-- MIRA (ponto no mundo) -----------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ignoreList()
	local list = { fx, workspace.CurrentCamera, workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Aliados"), workspace:FindFirstChild("Estruturas"), workspace:FindFirstChild("InimigosMortos"), workspace:FindFirstChild("Curiosity") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	return list
end

local aiming = false
local lockTarget -- corpo do inimigo travado

local function screenRay()
	local cam = workspace.CurrentCamera
	if aiming then
		return cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	end
	local m = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(m.X, m.Y)
end

local function nearestEnemyForward(origin, look, maxD)
	local best, bs
	local folder = workspace:FindFirstChild("InimigosAtivos")
	if not folder then return nil end
	for _, m in ipairs(folder:GetChildren()) do
		local b = m:FindFirstChild("Corpo")
		if b and not m:GetAttribute("Ilusao") then
			local v = b.Position - origin
			local d = v.Magnitude
			if d < maxD and d > 0.1 then
				local dot = Vector3.new(v.X, 0, v.Z).Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit)
				if dot > 0.5 then
					local score = d * (2 - dot)
					if not bs or score < bs then best, bs = b, score end
				end
			end
		end
	end
	return best
end

-- inimigo mais perto do centro da mira (em pixels), na frente e visivel
local function findLock()
	local cam = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("InimigosAtivos")
	if not folder or not cam then return nil end
	local center
	if aiming then
		center = cam.ViewportSize / 2
	elseif UserInputService.MouseEnabled then
		center = UserInputService:GetMouseLocation()
	else
		return nil
	end
	local maxPx = (MIRA.AssistPixels or 70) * scale.Scale
	local best, bd
	for _, m in ipairs(folder:GetChildren()) do
		local b = m:FindFirstChild("Corpo")
		if b then
			local sp, onScreen = cam:WorldToViewportPoint(b.Position)
			if onScreen and sp.Z > 0 and sp.Z < 220 then
				local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
				if d <= maxPx and (not bd or d < bd) then best, bd = b, d end
			end
		end
	end
	if best then
		rayParams.FilterDescendantsInstances = ignoreList()
		local from = cam.CFrame.Position
		local hit = workspace:Raycast(from, best.Position - from, rayParams)
		if hit and not hit.Instance:IsDescendantOf(folder) then return nil end
	end
	return best
end

local function aimPoint(range)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	if lockTarget and lockTarget.Parent then return lockTarget.Position end
	if UserInputService.MouseEnabled or aiming then
		rayParams.FilterDescendantsInstances = ignoreList()
		local ray = screenRay()
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
		return hit and hit.Position or (ray.Origin + ray.Direction * range)
	end
	local e = nearestEnemyForward(root.Position, root.CFrame.LookVector, range)
	return e and e.Position or (root.Position + root.CFrame.LookVector * 50 + Vector3.new(0, 1.5, 0))
end

-- ANIMACAO DE BRACOS (R6) -------------------------------------------------------------------
local baseC0 = setmetatable({}, { __mode = "k" })
local function baseOf(motor)
	local b = baseC0[motor]
	if not b then b = motor.C0; baseC0[motor] = b end
	return b
end
local function swingMotor(motor, angle, sign)
	if not motor then return end
	local base = baseOf(motor)
	local out = TweenService:Create(motor, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * CFrame.Angles(0, 0, math.rad(angle) * sign) })
	out:Play()
	out.Completed:Connect(function()
		TweenService:Create(motor, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = base }):Play()
	end)
end
local function swing(char, idx)
	local torso = char and char:FindFirstChild("Torso")
	if not torso then return end
	local r, l = torso:FindFirstChild("Right Shoulder"), torso:FindFirstChild("Left Shoulder")
	if idx == 1 then swingMotor(r, 90, 1)
	elseif idx == 2 then swingMotor(l, 90, -1)
	else swingMotor(r, 120, 1); swingMotor(l, 120, -1) end
end

-- ACOES ------------------------------------------------------------------------
local lastShot, lastMelee, lastRepair = 0, 0, 0
local holding = false

local function busy()
	return player:GetAttribute("Construindo") == true
end

local function muzzleOf(tool)
	local h = tool and tool:FindFirstChild("Handle")
	local a = h and h:FindFirstChild("Boca")
	return a and a.WorldPosition or (h and h.Position)
end

local function shoot(tool, w)
	local now = os.clock()
	if now - lastShot < w.Cadencia then return end
	lastShot = now
	local aim = aimPoint(w.Alcance)
	if not aim then return end
	remotes.Disparar:FireServer(aim)
	local feel = feelOf(w.Id)
	local n = w.Rajada or 1
	for i = 1, n do
		task.delay((i - 1) * (w.IntervaloRajada or 0), function()
			local from = muzzleOf(tool)
			if not from or tool.Parent ~= player.Character then return end
			local dirMain = aim - from
			muzzleFlash(from, dirMain, feel.Clarao or 1)
			if w.Tipo == "Foguete" then
				playSound(SOM.Foguete, 0.6, 1)
			else
				local sid, sv, sp = shotSound(w)
				playSound(sid, sv, sp * (0.94 + rng:NextNumber() * 0.12))
				-- (o "tlim" da capsula agora toca quando ela bate no chao, em EfeitosExtras)
			end
			-- recuo e tremor
			recoilPitch += math.rad(feel.Recuo or 1) * (0.85 + rng:NextNumber() * 0.3)
			recoilYaw += math.rad((feel.Recuo or 1) * 0.35) * (rng:NextNumber() - 0.5)
			armKick += math.rad((feel.Recuo or 1) * 5)
			bloom = math.min(22, bloom + (feel.Recuo or 1) * 2.5 + 2)
			addShake(feel.Tremor or 0.2)
			if kickFov then kickFov(0.25 + (feel.Recuo or 1) * 0.3) end
			if w.Tipo == "Foguete" then
				rocket(from, aim, function() explosion(aim, w.Raio or 10) end)
				return
			end
			-- tracantes ate onde a bala realmente bate (raycast local, so visual)
			rayParams.FilterDescendantsInstances = ignoreList()
			for _ = 1, (w.Projeteis or 1) do
				if dirMain.Magnitude > 0.1 then
					local cf = CFrame.lookAt(Vector3.zero, dirMain.Unit) * CFrame.Angles(0, 0, rng:NextNumber() * math.pi * 2) * CFrame.Angles(math.rad(rng:NextNumber() * (w.Espalhamento or 0)), 0, 0)
					local res = workspace:Raycast(from, cf.LookVector * w.Alcance, rayParams)
					local to = res and res.Position or (from + cf.LookVector * math.min(dirMain.Magnitude + 20, w.Alcance))
					if w.Fogo then flame(from, to) else tracer(from, to, w.Cor, 0.22) end
				end
			end
		end)
	end
end

local meleeCombo = 0
local function punch(w)
	local now = os.clock()
	w = w or Cfg.Armas[1]
	if now - lastMelee < w.Cadencia then return end
	if now - lastMelee > 1 then meleeCombo = 0 end
	lastMelee = now
	meleeCombo = meleeCombo % 3 + 1
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	swing(char, meleeCombo)
	local heavy = w.Id ~= "Punhos"
	playSound(SOM.Soco, SONS.Golpe.V, (heavy and 0.75 or 1) * (0.9 + rng:NextNumber() * 0.3))
	addShake(0.08 + (feelOf(w.Id).Tremor or 0) * 0.25)
	if root then
		if w.Area then
			groundSlam(root, w.Cor or Color3.fromRGB(255, 225, 40), w.Alcance)
			addShake(feelOf(w.Id).Tremor or 0.6)
			playSound(SOM.Explosao, 0.4, 1.5)
		else
			slashArc(root, w.Cor or Color3.new(1, 1, 1), w.Alcance, meleeCombo)
		end
	end
	remotes.Atacar:FireServer()
end

local function repair()
	local now = os.clock()
	if now - lastRepair < Cfg.Martelo.Cadencia then return end
	lastRepair = now
	swing(player.Character, 1)
	local target
	local folder = workspace:FindFirstChild("Estruturas")
	if not folder then return end
	if UserInputService.MouseEnabled or aiming then
		local ray = screenRay()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, rp)
		if hit then
			local mdl = hit.Instance
			while mdl and mdl.Parent ~= folder do mdl = mdl.Parent end
			target = mdl
		end
	end
	if not target then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bd
		for _, mdl in ipairs(folder:GetChildren()) do
			if mdl.PrimaryPart and root then
				local d = (mdl.PrimaryPart.Position - root.Position).Magnitude
				local hurt = (mdl:GetAttribute("Vida") or 0) < (mdl:GetAttribute("VidaMax") or 0)
				if hurt and d < Cfg.Martelo.Alcance + 4 and (not bd or d < bd) then best, bd = mdl, d end
			end
		end
		target = best
	end
	if target then
		playSound(SOM.Martelo, SONS.Martelo.V, 1 + rng:NextNumber() * 0.2, target.PrimaryPart and target.PrimaryPart.Position)
		remotes.Reparar:FireServer(target)
	end
end

local function useTool(tool)
	if not tool or busy() then return end
	local id = tool:GetAttribute("Arma")
	if id == "Martelo" then repair() return end
	local w = weaponCfg(id)
	if not w then return end
	if w.Tipo == "Corpo" then punch(w) else shoot(tool, w) end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		useTool(equipped())
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then holding = false end
end)

-- toque / controle: Tool.Activated
local hooked = setmetatable({}, { __mode = "k" })
local function hookTool(t)
	if hooked[t] or not t:IsA("Tool") then return end
	hooked[t] = true
	t.Activated:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then return end
		useTool(t)
	end)
end

-- CAMERA DE MIRA (PC) ------------------------------------------------------------------
local yaw, pitch = 0, 0
local camDist = MIRA.Distancia or 11
local altHeld = false
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Exclude

local function panelOpen()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return false end
	local morte = pg:FindFirstChild("PainelMorte")
	if morte and morte.Enabled then return true end
	local cur = pg:FindFirstChild("PainelCuriosity")
	if cur and cur.Enabled then return true end
	local hud = pg:FindFirstChild("HUD")
	if hud then
		for _, f in ipairs(hud:GetChildren()) do
			if f:IsA("Frame") and f.ZIndex >= 20 and f.Visible then return true end
		end
	end
	return false
end

local LIVRE = MIRA.Modo == "Livre"

local function wantAim()
	if LIVRE then return false end -- modo do video: sem camera travada no centro
	if not MIRA.Ativa or not UserInputService.MouseEnabled then return false end
	if altHeld or busy() or player:GetAttribute("Morto") == true then return false end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if not equipped() then return false end
	local cam = workspace.CurrentCamera
	if cam:GetAttribute("Panorama") then return false end -- panoramica de nova area
	if not aiming and cam.CameraType == Enum.CameraType.Scriptable then return false end -- outra cena usando a camera
	return not panelOpen()
end

local function enterAim()
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), math.rad(-30), math.rad(30))
	cam.CameraType = Enum.CameraType.Scriptable
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.AutoRotate = false end
	aiming = true
end

local function exitAim()
	aiming = false
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable and not cam:GetAttribute("Panorama") then cam.CameraType = Enum.CameraType.Custom end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.AutoRotate = true end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then altHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then altHeld = false end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if aiming and input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		camDist = math.clamp(camDist - input.Position.Z * 1.5, MIRA.DistanciaMin or 6, MIRA.DistanciaMax or 18)
	end
end)

local aimArm -- motor do ombro direito que estamos dirigindo
local facing = false -- modo Livre: estamos girando o corpo para a mira
local freeAim -- modo Livre: ponto do mundo sob o mouse

-- MODO LIVRE: camera em terceira pessoa por cima (como no video) ao nascer
local function setupFreeCamera()
	if not LIVRE then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	task.wait(0.25)
	local zMin, zMax = MIRA.ZoomMin or 10, MIRA.ZoomMax or 40
	local z = MIRA.ZoomInicial or 22
	-- trava o zoom no valor inicial por um instante (o modulo de camera adota a distancia) e solta
	player.CameraMinZoomDistance = z
	player.CameraMaxZoomDistance = z
	local cam = workspace.CurrentCamera
	local ang = math.rad(MIRA.AnguloInicial or 38)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
	flatLook = flatLook.Unit
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	cam.CFrame = CFrame.lookAt(focus - flatLook * z * math.cos(ang) + Vector3.new(0, z * math.sin(ang), 0), focus)
	task.wait(0.1)
	player.CameraMinZoomDistance = zMin
	player.CameraMaxZoomDistance = zMax
end

RunService:BindToRenderStep("CameraMira", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	local want = wantAim()
	if want and not aiming then enterAim() elseif not want and aiming then exitAim() end
	local recover = MIRA.RecuperacaoRecuo or 10
	local decay = math.exp(-recover * dt)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if aiming and root then
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local d = UserInputService:GetMouseDelta()
		local sens = math.rad(MIRA.Sensibilidade or 0.3) * gameSettings.MouseSensitivity
		yaw -= d.X * sens
		pitch = math.clamp(pitch - d.Y * sens, math.rad(MIRA.PitchMin or -60), math.rad(MIRA.PitchMax or 55))
		local p = math.clamp(pitch + recoilPitch, math.rad(MIRA.PitchMin or -60), math.rad(MIRA.PitchMax or 55))
		local y = yaw + recoilYaw
		local focus = root.Position + Vector3.new(0, MIRA.Altura or 2.2, 0)
		local rot = CFrame.Angles(0, y, 0) * CFrame.Angles(p, 0, 0)
		local desired = focus + rot:VectorToWorldSpace(Vector3.new(MIRA.Lado or 0.9, 0, camDist))
		camParams.FilterDescendantsInstances = { char, fx, workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("InimigosMortos"), workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Aliados"), workspace:FindFirstChild("Curiosity") }
		local hit = workspace:Raycast(focus, desired - focus, camParams)
		if hit then desired = hit.Position + (focus - hit.Position).Unit * 0.6 end
		local cf = CFrame.new(desired) * rot
		if shake > 0.001 then
			cf = cf * CFrame.new(rng:NextNumber(-1, 1) * shake * 0.12, rng:NextNumber(-1, 1) * shake * 0.12, 0) * CFrame.Angles(rng:NextNumber(-1, 1) * shake * 0.012, rng:NextNumber(-1, 1) * shake * 0.012, 0)
		end
		cam.CFrame = cf
		cam.Focus = CFrame.new(focus)
		-- o personagem olha para onde a camera olha
		if not root.Anchored then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
		end
	elseif shake > 0.001 then
		-- camera padrao (modo Livre): so tremor de POSICAO. Girar a camera aqui faz o modulo de
		-- camera do Roblox herdar o giro e a mira "sobe" sozinha em armas automaticas.
		cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-1, 1) * shake * 0.1, rng:NextNumber(-1, 1) * shake * 0.1, 0)
	end
	recoilPitch *= decay
	recoilYaw *= decay
	shake *= math.exp(-12 * dt)
	armKick *= math.exp(-14 * dt)
	bloom *= math.exp(-9 * dt)

	-- MODO LIVRE (video): mouse solto, o corpo vira para o ponto sob a mira
	local tool = equipped()
	local w = tool and weaponCfg(tool:GetAttribute("Arma"))
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local canFace = LIVRE and UserInputService.MouseEnabled and tool ~= nil and hum ~= nil and hum.Health > 0
		and not busy() and player:GetAttribute("Morto") ~= true and not altHeld and not panelOpen()
	if canFace and root and not root.Anchored then
		local ap = aimPoint(w and w.Alcance or 100)
		freeAim = ap
		if ap then
			local v = Vector3.new(ap.X - root.Position.X, 0, ap.Z - root.Position.Z)
			if v.Magnitude > 0.8 then
				local want = math.atan2(-v.X, -v.Z)
				local _, cur = root.CFrame:ToEulerAnglesYXZ()
				local diff = math.atan2(math.sin(want - cur), math.cos(want - cur))
				local newYaw = cur + diff * math.min(1, dt * (MIRA.GiroPersonagem or 18))
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, newYaw, 0)
			end
		end
		if not facing then hum.AutoRotate = false; facing = true end
	elseif facing then
		if hum then hum.AutoRotate = true end
		facing = false
		freeAim = nil
	end

	-- braco acompanha a mira (so com arma de fogo)
	local torso = char and char:FindFirstChild("Torso")
	local motor = torso and torso:FindFirstChild("Right Shoulder")
	if motor and w and w.Tipo ~= "Corpo" then
		local base = baseOf(motor)
		local armPitch = 0
		if aiming then
			armPitch = math.clamp(pitch + recoilPitch, math.rad(-50), math.rad(50))
		elseif freeAim and torso then
			local shoulder = (torso.CFrame * CFrame.new(1, 0.5, 0)).Position
			local d = freeAim - shoulder
			if d.Magnitude > 0.5 then armPitch = math.clamp(math.asin(math.clamp(d.Unit.Y, -1, 1)), math.rad(-50), math.rad(50)) end
		end
		motor.C0 = base * CFrame.Angles(0, 0, armPitch + armKick)
		aimArm = motor
	elseif aimArm then
		if aimArm.Parent then aimArm.C0 = baseOf(aimArm) end
		aimArm = nil
	end
end)

-- com a mira travada no centro, prompts (Loja, Curiosity...) so abrem pela tecla, nao por clique
game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt)
	prompt.ClickablePrompt = not aiming
end)

player.CharacterAdded:Connect(function()
	if aiming then exitAim() end
	recoilPitch, recoilYaw, shake, armKick = 0, 0, 0, 0
	facing, freeAim = false, nil
	task.spawn(setupFreeCamera)
end)
if player.Character then task.spawn(setupFreeCamera) end

-- QUADRO A QUADRO: tiro automatico, mira, trava ----------------------------------------
RunService.RenderStepped:Connect(function()
	local tool = equipped()
	local id = tool and tool:GetAttribute("Arma")
	local w = id and weaponCfg(id)
	local isGun = w ~= nil and w.Tipo ~= "Corpo"
	if holding and tool and not busy() then
		if w and w.Automatica then useTool(tool)
		elseif id == "Martelo" or (w and w.Tipo == "Corpo") then useTool(tool) end
	end
	local dead = player:GetAttribute("Morto") == true
	-- trava no inimigo (com arma de fogo)
	lockTarget = (isGun and not busy() and not dead) and findLock() or nil
	if not lockTarget and isGun and not UserInputService.MouseEnabled and not dead then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then lockTarget = nearestEnemyForward(root.Position, root.CFrame.LookVector, w.Alcance) end
	end
	local cam = workspace.CurrentCamera
	if lockTarget then
		local sp, on = cam:WorldToViewportPoint(lockTarget.Position)
		local edge = cam:WorldToViewportPoint(lockTarget.Position + cam.CFrame.RightVector * lockTarget.Size.X * 0.6)
		local r = math.clamp(math.abs(edge.X - sp.X), 10, 120)
		lockFrame.Visible = on
		lockFrame.Position = UDim2.fromOffset(sp.X, sp.Y)
		lockFrame.Size = UDim2.fromOffset(r * 2 + 8, r * 2 + 8)
	else
		lockFrame.Visible = false
	end
	-- mira
	local showCross = (aiming or ((isGun or (LIVRE and tool ~= nil)) and UserInputService.MouseEnabled)) and not busy() and not dead
	cross.Visible = showCross
	UserInputService.MouseIconEnabled = not showCross and not aiming
	local center
	if aiming then
		center = cam.ViewportSize / 2
	else
		center = UserInputService:GetMouseLocation()
	end
	if showCross then
		cross.Position = UDim2.fromOffset(center.X, center.Y)
		local s = 26 + bloom
		cross.Size = UDim2.fromOffset(s, s)
		local c = lockTarget and Color3.fromRGB(255, 255, 255) or MINT
		for _, b in ipairs(crossBars) do b.BackgroundColor3 = c end
	end
	hitMark.Visible = os.clock() < hitUntil
	if hitMark.Visible then hitMark.Position = UDim2.fromOffset(center.X, center.Y) end
end)

local function watchCharacter(char)
	for _, t in ipairs(char:GetChildren()) do hookTool(t) end
	char.ChildAdded:Connect(function(c) hookTool(c); task.defer(refreshHotbar) end)
	char.ChildRemoved:Connect(function() task.defer(refreshHotbar) end)
	refreshHotbar()
end
local function watchBackpack(bp)
	for _, t in ipairs(bp:GetChildren()) do hookTool(t) end
	bp.ChildAdded:Connect(function(c) hookTool(c); task.defer(refreshHotbar) end)
	bp.ChildRemoved:Connect(function() task.defer(refreshHotbar) end)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watchBackpack(c) end end)
local bp = player:FindFirstChildOfClass("Backpack")
if bp then watchBackpack(bp) end

-- TIROS (meus e dos outros) ----------------------------------------------------------------
remotes.Tiro.OnClientEvent:Connect(function(shooter, weaponId, muzzle, hits, hitAny)
	local w = weaponCfg(weaponId)
	if shooter == player then
		if w and w.Tipo == "Foguete" then return end -- o meu foguete ja foi desenhado
		for _, h in ipairs(hits) do
			local e = enemyNear(h, 1.5)
			impact(h, e ~= nil)
		end
		if hitAny then
			showHit(false)
			if os.clock() - lastHitSound > 0.06 then
				lastHitSound = os.clock()
				playSound(SOM.Acerto, SONS.Acerto.V, 1 + rng:NextNumber() * 0.15)
			end
		end
		return
	end
	local feel = feelOf(weaponId)
	local dir = hits[1] and (hits[1] - muzzle) or Vector3.new(0, 0, -1)
	muzzleFlash(muzzle, dir, (feel.Clarao or 1) * 0.8)
	if w and w.Tipo == "Foguete" then
		playSound(SOM.Foguete, 0.4, 1, muzzle)
		local to = hits[1] or muzzle
		rocket(muzzle, to, function() explosion(to, w.Raio or 10) end)
		return
	end
	do
		local sid, sv, sp = shotSound(w)
		playSound(sid, sv * 0.6, sp, muzzle)
	end
	for _, h in ipairs(hits) do
		if w and w.Fogo then flame(muzzle, h) else tracer(muzzle, h, w and w.Cor) end
		impact(h, enemyNear(h, 1.5) ~= nil)
	end
end)

remotes.Efeito.OnClientEvent:Connect(function(kind, who, a, b, c)
	if kind ~= "Golpe" and kind ~= "Martelo" then return end
	if typeof(who) ~= "Instance" or not who:IsA("Player") then return end
	if who == player then
		if kind == "Golpe" and c then showHit(false); addShake(0.18) end
		return
	end
	if not who.Character then return end
	if kind == "Golpe" then swing(who.Character, a)
	elseif kind == "Martelo" then swing(who.Character, 1) end
end)

-- NUMEROS QUE "PULAM" ----------------------------------------------------------------
local function popText(pos, text, color, size, rise, strokeColor)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = pos
	p.Parent = fx
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size * 3.2, size * 1.4)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = strokeColor or Color3.fromRGB(30, 8, 8); st.Parent = t
	local us = Instance.new("UIScale"); us.Scale = 1.9; us.Parent = t
	TweenService:Create(us, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local drift = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
	TweenService:Create(p, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, rise or 3.2, 0) + drift }):Play()
	task.delay(0.45, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(p, 0.8)
end

remotes.NumeroDano.OnClientEvent:Connect(function(pos, amount, crit, attackerId)
	hitFlash(enemyNear(pos, 2))
	local mine = attackerId == player.UserId
	local size = (crit and 34 or 26) * (mine and 1 or 0.75)
	popText(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 1.6, rng:NextNumber(-0.8, 0.8)),
		crit and ("-" .. amount .. "!") or ("-" .. amount),
		crit and Color3.fromRGB(255, 200, 30) or Color3.fromRGB(240, 55, 60), size, nil,
		crit and Color3.fromRGB(70, 35, 0) or Color3.fromRGB(45, 8, 8))
end)

remotes.Dinheiro.OnClientEvent:Connect(function(pos, amount)
	popText(pos + Vector3.new(0, 2.6, 0), "$ +" .. amount, Color3.fromRGB(250, 196, 70), 26, 4, Color3.fromRGB(70, 42, 0))
end)

-- SEQUENCIA DE ABATES + "soco" de FOV + aviso de vida baixa -------------------------------
local streakGui = Instance.new("ScreenGui")
streakGui.Name = "Sequencia"
streakGui.ResetOnSpawn = false
streakGui.IgnoreGuiInset = true
streakGui.DisplayOrder = 40
streakGui.Enabled = false -- mensagens de combo de abates desligadas (pedido do jogo)
streakGui.Parent = player.PlayerGui
local streakLabel = Instance.new("TextLabel")
streakLabel.AnchorPoint = Vector2.new(0.5, 0.5)
streakLabel.Position = UDim2.fromScale(0.5, 0.3)
streakLabel.Size = UDim2.fromOffset(420, 60)
streakLabel.BackgroundTransparency = 1
streakLabel.FontFace = FONT
streakLabel.TextSize = 40
streakLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
streakLabel.TextTransparency = 1
streakLabel.Text = ""
streakLabel.Parent = streakGui
local streakStroke = Instance.new("UIStroke"); streakStroke.Thickness = 3; streakStroke.Color = Color3.fromRGB(60, 30, 0); streakStroke.Transparency = 1; streakStroke.Parent = streakLabel
local streakScale = Instance.new("UIScale"); streakScale.Parent = streakLabel
local STREAK_TXT = { [2] = "DOUBLE KILL!", [3] = "TRIPLE KILL!", [4] = "MEGA KILL!", [5] = "MASSACRE!" }
local streakN, streakLast, streakHide = 0, 0, nil

local fovKick = 0
kickFov = function(a) fovKick = math.min(6, fovKick + a) end
function registerKill()
	local now = os.clock()
	streakN = (now - streakLast <= 2.5) and streakN + 1 or 1
	streakLast = now
	fovKick = math.min(6, fovKick + 2.5)
	if streakN < 2 then return end
	streakLabel.Text = STREAK_TXT[streakN] or ("x" .. streakN .. " COMBO!")
	streakLabel.TextColor3 = streakN >= 5 and Color3.fromRGB(255, 90, 70) or Color3.fromRGB(255, 220, 70)
	streakLabel.TextTransparency = 0
	streakStroke.Transparency = 0
	streakScale.Scale = 1.7
	TweenService:Create(streakScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	playSound(SOM.Abate, SONS.Abate.V, 1 + streakN * 0.08)
	if streakHide then task.cancel(streakHide) end
	streakHide = task.delay(1.2, function()
		TweenService:Create(streakLabel, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(streakStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end)
end

-- vinheta vermelha quando a vida esta baixa
local vignette = Instance.new("Frame")
vignette.Name = "VidaBaixa"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Parent = streakGui
local edges = {}
for _, e in ipairs({ { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90 }, { UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), -90 },
	{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 }, { UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 } }) do
	local f = Instance.new("Frame")
	f.Position, f.Size = e[1], e[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient")
	g.Rotation = e[3]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	f.Parent = vignette
	table.insert(edges, f)
end

local baseFov
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	-- soco de FOV no abate
	if fovKick > 0.01 then
		baseFov = baseFov or cam.FieldOfView
		cam.FieldOfView = baseFov + fovKick
		fovKick *= math.exp(-10 * dt)
	elseif baseFov then
		cam.FieldOfView = baseFov
		baseFov = nil
		fovKick = 0
	end
	-- vida baixa: bordas vermelhas pulsando
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local r = (hum and hum.MaxHealth > 0) and hum.Health / hum.MaxHealth or 1
	local a = 1
	if hum and hum.Health > 0 and r < 0.35 then
		a = 0.35 + 0.25 * math.sin(os.clock() * 6) + r
	end
	for _, f in ipairs(edges) do f.BackgroundTransparency = math.clamp(a, 0, 1) end
end)

-- INIMIGOS ABATIDOS: lancados voando (como os macacos do video) -----------------------------
local function launchCorpse(m)
	local body = m:WaitForChild("Corpo", 1)
	if not body then return end
	local push = m:GetAttribute("Empurrao")
	if typeof(push) ~= "Vector3" then push = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) end
	if m:GetAttribute("Assassino") == player.UserId then
		showHit(true)
		playSound(SOM.Abate, 0.45, 1.5)
		registerKill()
	end
	local c = body:Clone()
	for _, d in ipairs(c:GetChildren()) do
		if not (d:IsA("Decal") or d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance")) then d:Destroy() end
	end
	c.Anchored = true
	c.CanCollide = false; c.CanQuery = false; c.CanTouch = false
	c.Parent = fx
	-- esconde o original (o servidor apaga em seguida)
	body.Transparency = 1
	for _, d in ipairs(body:GetDescendants()) do
		if d:IsA("Decal") then d.Transparency = 1 elseif d:IsA("BillboardGui") then d.Enabled = false end
	end
	local vel = push.Unit * rng:NextNumber(30, 42) + Vector3.new(0, rng:NextNumber(36, 46), 0)
	local spin = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-10, 10), rng:NextNumber(-14, 14))
	local pos, rot = c.Position, c.CFrame - c.Position
	local life, t = 0.95, 0
	local decals = {}
	for _, d in ipairs(c:GetChildren()) do if d:IsA("Decal") then table.insert(decals, d) end end
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		vel += Vector3.new(0, -115 * dt, 0)
		pos += vel * dt
		rot = rot * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
		c.CFrame = CFrame.new(pos) * rot
		if t > life - 0.3 then
			local a = math.clamp((t - (life - 0.3)) / 0.3, 0, 1)
			c.Transparency = a
			for _, d in ipairs(decals) do d.Transparency = a end
		end
		if t >= life then
			conn:Disconnect()
			c:Destroy()
		end
	end)
	-- poeirinha no lugar
	impact(body.Position, true)
end

local mortos = workspace:WaitForChild("InimigosMortos", 30)
if mortos then
	mortos.ChildAdded:Connect(function(m) task.spawn(launchCorpse, m) end)
end
