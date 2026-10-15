-- [ColetaCliente] Machado (mira e golpe), efeitos de coleta, sucção no Nucleo e HUD do estoque.
-- O servidor (ColetaService) valida cada golpe; aqui so mira, anima e mostra.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local estado = Shared:WaitForChild("EstadoJogo")
local Cfg = require(Shared.Config.Sobrevivencia)
local SONS = require(Shared.Config.Sons)
local camera = workspace.CurrentCamera
local rng = Random.new()

local fx = Instance.new("Folder")
fx.Name = "ColetaFX"
fx.Parent = workspace

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local COR = { Madeira = Color3.fromRGB(196, 140, 84), Pedra = Color3.fromRGB(170, 172, 182) }
local ICONE = { Madeira = "MADEIRA", Pedra = "PEDRA" }

-- BASICO -------------------------------------------------------------------------------------
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function part(o)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Size = o.size or Vector3.one
	p.CFrame = o.cf or CFrame.new()
	p.Color = o.color or Color3.new(1, 1, 1)
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	if o.shape then p.Shape = o.shape end
	p.Parent = fx
	if o.life then Debris:AddItem(p, o.life) end
	return p
end

local function sound(def, pos, vol, pitch)
	if not def or not def.Id then return end
	local a = part({ cf = CFrame.new(pos), transparency = 1, size = Vector3.one * 0.2, life = 6 })
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.6) * (vol or 1)
	s.PlaybackSpeed = (def.P or 1) * (pitch or 1) * rng:NextNumber(0.93, 1.07)
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 140
	s.Parent = a
	s:Play()
end

local function burst(pos, color, n, speed, size, material, life)
	for _ = 1, n do
		local s = (size or 0.4) * rng:NextNumber(0.6, 1.3)
		local p = part({ size = Vector3.new(s, s, s * rng:NextNumber(0.6, 1.8)), cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), color = color, material = material or Enum.Material.Wood })
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.4), rng:NextNumber(-1, 1)) * (speed or 14)
		local spin = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4))
		local t0, L = os.clock(), life or 0.8
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - t0
			if t > L or not p.Parent then conn:Disconnect(); p:Destroy() return end
			v += Vector3.new(0, -workspace.Gravity * 0.6 * dt, 0)
			p.CFrame = (p.CFrame + v * dt) * spin
			if t > L * 0.6 then p.Transparency = (t - L * 0.6) / (L * 0.4) end
		end)
	end
end

local function dust(pos, color, amount, size, spread)
	local a = part({ cf = CFrame.new(pos), transparency = 1, size = Vector3.one * 0.2, life = 3 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightInfluence = 0.7
	e.Size = NumberSequence.new(size or 2, (size or 2) * 2.2)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(spread or 5, (spread or 5) * 1.8)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Drag = 3
	e.Enabled = false
	e.Parent = a
	e:Emit(amount or 12)
end

-- tremor de camera simples (somado depois da camera do jogo)
local shake = 0
RunService:BindToRenderStep("ColetaShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if shake > 0.003 then
		local s = shake * shake
		local t = os.clock() * 40
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(math.noise(t, 2.1) * 2.4 * s), math.rad(math.noise(t, 7.3) * 2.4 * s), 0)
		shake = math.max(0, shake - dt * 3)
	end
end)
local function addShake(a, pos)
	if pos then a *= math.clamp(1 - ((camera.CFrame.Position - pos).Magnitude - 15) / 60, 0, 1) end
	shake = math.min(1.2, shake + a)
end

-- BALANCO DO BRACO (R6) ------------------------------------------------------------------------
local bases = setmetatable({}, { __mode = "k" })
local function swing(char)
	local torso = char and char:FindFirstChild("Torso")
	local m = torso and torso:FindFirstChild("Right Shoulder")
	if not m then return end
	bases[m] = bases[m] or m.C0
	local base = bases[m]
	local up = tween(m, 0.1, { C0 = base * CFrame.Angles(0, 0, math.rad(150)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	up.Completed:Once(function()
		local down = tween(m, 0.09, { C0 = base * CFrame.Angles(0, 0, math.rad(40)) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		down.Completed:Once(function() tween(m, 0.18, { C0 = base }) end)
	end)
end

-- MIRA DO MACHADO ---------------------------------------------------------------------------
local lastSwing = 0
local function equippedAxe()
	local char = player.Character
	local t = char and char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("Arma") == "Machado" and t or nil
end

local function resourceOf(inst)
	while inst and inst ~= workspace do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "Recurso") then return inst end
		inst = inst.Parent
	end
end

local function reachOf(model, root)
	local main = model.PrimaryPart
	if not main then return math.huge end
	local _, sz = model:GetBoundingBox()
	local d = Vector3.new(main.Position.X - root.Position.X, 0, main.Position.Z - root.Position.Z).Magnitude
	return d - math.min(sz.X, sz.Z) / 2
end

local function pickTarget(screenPos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local reach = Cfg.Machado.Alcance
	-- 1) o que esta sob o mouse
	if screenPos then
		local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace:FindFirstChild("Recursos") }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 120, rp)
		local m = hit and resourceOf(hit.Instance)
		if m and reachOf(m, root) <= reach then return m end
	end
	-- 2) o recurso mais perto na frente do personagem
	local best, bd
	for _, m in ipairs(CollectionService:GetTagged("Recurso")) do
		local main = m.PrimaryPart
		if main then
			local d = reachOf(m, root)
			local dir = Vector3.new(main.Position.X - root.Position.X, 0, main.Position.Z - root.Position.Z)
			local facing = dir.Magnitude < 0.1 or dir.Unit:Dot(root.CFrame.LookVector) > 0.1
			if d <= reach and facing and (not bd or d < bd) then best, bd = m, d end
		end
	end
	return best
end

local function chop(screenPos)
	if not equippedAxe() or player:GetAttribute("Construindo") then return end
	local now = os.clock()
	if now - lastSwing < Cfg.Machado.Cooldown then return end
	lastSwing = now
	swing(player.Character)
	local target = pickTarget(screenPos)
	if target then
		local root = player.Character.HumanoidRootPart
		local main = target.PrimaryPart
		-- vira para o alvo
		local look = Vector3.new(main.Position.X, root.Position.Y, main.Position.Z)
		if (look - root.Position).Magnitude > 0.5 then root.CFrame = CFrame.lookAt(root.Position, look) end
		task.delay(0.12, function() remotes.Coletar:FireServer(target) end)
	else
		sound(SONS.Golpe, player.Character.HumanoidRootPart.Position, 0.6, 1.2)
	end
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if equippedAxe() then chop(UserInputService:GetMouseLocation()) end
	end
end)
-- toque/controle
local function hook(t)
	if not t:IsA("Tool") or t:GetAttribute("Arma") ~= "Machado" or t:GetAttribute("_hook") then return end
	t:SetAttribute("_hook", true)
	t.Activated:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then return end
		chop(nil)
	end)
end
local function watch(holder)
	for _, c in ipairs(holder:GetChildren()) do hook(c) end
	holder.ChildAdded:Connect(hook)
end
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end

-- BARRA DE VIDA DO RECURSO -------------------------------------------------------------------------
local bars = {}
local function showBar(model, ratio, kind)
	local main = model.PrimaryPart
	if not main then return end
	local b = bars[model]
	if not b then
		local _, sz = model:GetBoundingBox()
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(90, 12)
		bb.StudsOffsetWorldSpace = Vector3.new(0, math.min(sz.Y, 6) / 2 + 1.5, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = main
		bb.Parent = fx
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		bg.BorderSizePixel = 0
		bg.Parent = bb
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
		local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = Color3.fromRGB(15, 15, 18); st.Parent = bg
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = kind == "Rocha" and Color3.fromRGB(190, 195, 210) or Color3.fromRGB(255, 150, 40)
		fill.BorderSizePixel = 0
		fill.Parent = bg
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
		b = { gui = bb, fill = fill, t = 0 }
		bars[model] = b
	end
	b.t = os.clock()
	tween(b.fill, 0.15, { Size = UDim2.fromScale(math.max(0.02, ratio), 1) })
	local my = b.t
	task.delay(2.5, function()
		if bars[model] and bars[model].t == my then bars[model].gui:Destroy(); bars[model] = nil end
	end)
	if ratio <= 0 then task.delay(0.3, function() if bars[model] then bars[model].gui:Destroy(); bars[model] = nil end end) end
end

-- balanço da arvore/pedra ao levar o golpe (so visual, local)
local function wobble(model, from)
	local main = model.PrimaryPart
	if not main or model:GetAttribute("Caindo") then return end
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts, { p, p.CFrame }) end end
	local base = main.Position - Vector3.new(0, main.Size.Y / 2, 0)
	local away = Vector3.new(main.Position.X - from.X, 0, main.Position.Z - from.Z)
	if away.Magnitude < 0.1 then return end
	local axis = Vector3.new(0, 1, 0):Cross(away.Unit)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.35 or model:GetAttribute("Caindo") then
			conn:Disconnect()
			if not model:GetAttribute("Caindo") then for _, e in ipairs(parts) do if e[1].Parent then e[1].CFrame = e[2] end end end
			return
		end
		local ang = math.sin(t * 40) * math.rad(3) * (1 - t / 0.35)
		local rot = CFrame.new(base) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-base)
		for _, e in ipairs(parts) do if e[1].Parent then e[1].CFrame = rot * e[2] end end
	end)
end

-- EFEITOS VINDOS DO SERVIDOR --------------------------------------------------------------------
local function flyIntoCore(entry, center, i, n, dur)
	local kind = entry.kind
	local info = Cfg.Itens[kind]
	local from = entry.from
	local g = part({
		size = info.Tamanho, cf = CFrame.new(from), color = info.Cor,
		material = Enum.Material.Plastic,
		shape = kind == "Madeira" and Enum.PartType.Cylinder or nil,
	})
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.5, 0); a0.Parent = g
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.5, 0); a1.Parent = g
	local tr = Instance.new("Trail"); tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Lifetime = 0.25
	tr.LightEmission = 1; tr.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(80, 150, 255)); tr.Transparency = NumberSequence.new(0.2, 1); tr.Parent = g
	local delay = (i - 1) * math.min(0.06, 0.5 / n)
	local T = dur * 0.75
	local rel = from - center
	local r0 = Vector3.new(rel.X, 0, rel.Z).Magnitude
	local a0ang = math.atan2(rel.Z, rel.X)
	local y0 = rel.Y
	local spinDir = (i % 2 == 0) and 1 or -1
	local t0 = os.clock() + delay
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / T, 0, 1)
		if os.clock() < t0 then return end
		local e = u * u * (3 - 2 * u)
		local r = r0 * (1 - e)
		local ang = a0ang + spinDir * e * math.pi * 1.5
		local y = y0 * (1 - e) + math.sin(u * math.pi) * 4
		local p = center + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)
		g.CFrame = CFrame.new(p) * CFrame.Angles(u * 9, u * 7, 0)
		g.Size = info.Tamanho * (1 - e * 0.85)
		if u >= 1 then
			conn:Disconnect()
			g:Destroy()
		end
	end)
end

local function corePulse(center)
	-- esfera de "vacuo" que se fecha + clarao no final
	local vac = part({ shape = Enum.PartType.Ball, size = Vector3.one * 26, cf = CFrame.new(center), color = Color3.fromRGB(120, 210, 255), material = Enum.Material.ForceField, transparency = 0.2, life = 1.2 })
	tween(vac, Cfg.Succao.Duracao, { Size = Vector3.one * 3, Transparency = 0.6 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local ring = part({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 30, 30), cf = CFrame.new(center - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(150, 230, 255), material = Enum.Material.Neon, transparency = 0.4, life = 1.2 })
	tween(ring, Cfg.Succao.Duracao, { Size = Vector3.new(0.3, 2, 2), Transparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local a = part({ cf = CFrame.new(center), transparency = 1, size = Vector3.one * 0.2, life = 3 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(170, 235, 255))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.6, 0)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(-26, -18)   -- velocidade negativa: particulas vao PARA DENTRO
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Rate = 90
	e.Parent = a
	a.Size = Vector3.one * 22
	task.delay(Cfg.Succao.Duracao * 0.8, function() e.Enabled = false end)
	task.delay(Cfg.Succao.Duracao, function()
		local f = part({ shape = Enum.PartType.Ball, size = Vector3.one * 4, cf = CFrame.new(center), color = Color3.new(1, 1, 1), material = Enum.Material.Neon, life = 0.4 })
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(150, 220, 255); l.Range = 24; l.Brightness = 6; l.Parent = f
		tween(f, 0.35, { Size = Vector3.one * 12, Transparency = 1 })
		tween(l, 0.35, { Brightness = 0 })
	end)
end

local function popText(pos, text, color)
	local a = part({ cf = CFrame.new(pos), transparency = 1, size = Vector3.one * 0.2, life = 1.6 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 46)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(30, 22, 12); st.Parent = t
	local sc = Instance.new("UIScale"); sc.Scale = 0.3; sc.Parent = t
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(a, 1.4, { Position = pos + Vector3.new(0, 4, 0) }, Enum.EasingStyle.Sine)
	task.delay(0.9, function() tween(t, 0.5, { TextTransparency = 1 }); tween(st, 0.5, { Transparency = 1 }) end)
end

remotes.Efeito.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Machadada" then
		local who, model, pos, rk, ratio = a, b, c, d, e
		if who ~= player and typeof(who) == "Instance" and who.Character then swing(who.Character) end
		if typeof(pos) ~= "Vector3" then return end
		if rk == "Rocha" then
			sound(SONS.PedraGolpe, pos)
			burst(pos, Color3.fromRGB(130, 130, 138), 6, 12, 0.35, Enum.Material.Slate, 0.6)
			dust(pos, Color3.fromRGB(170, 170, 170), 5, 1.2, 3)
		else
			sound(SONS.MadeiraGolpe, pos)
			burst(pos, Color3.fromRGB(205, 160, 100), 7, 13, 0.3, Enum.Material.Wood, 0.7)
		end
		if typeof(model) == "Instance" and model.Parent then
			if typeof(who) == "Instance" and who.Character and who.Character:FindFirstChild("HumanoidRootPart") then wobble(model, who.Character.HumanoidRootPart.Position) end
		end
		if who == player then addShake(0.12) end
	elseif kind == "ArvoreCaiu" then
		local pos, dir, len = a, b, c
		if typeof(pos) ~= "Vector3" then return end
		sound(SONS.ArvoreCai, pos, 1)
		for i = 0, 3 do
			dust(pos + (dir or Vector3.zero) * (i - 1.5) * (len or 10) / 4, Color3.fromRGB(160, 145, 120), 6, 2.5, 6)
		end
		burst(pos + (dir or Vector3.zero) * (len or 10) * 0.4 + Vector3.new(0, 2, 0), Color3.fromRGB(70, 130, 55), 14, 16, 0.6, Enum.Material.Grass, 1)
		addShake(0.35, pos)
	elseif kind == "RochaQuebrou" then
		local pos, size = a, b
		if typeof(pos) ~= "Vector3" then return end
		sound(SONS.PedraQuebra, pos, 1)
		burst(pos, Color3.fromRGB(115, 115, 122), 14, 20, 0.6, Enum.Material.Slate, 1)
		dust(pos, Color3.fromRGB(175, 172, 165), 14, 3, 7)
		addShake(0.3, pos)
	elseif kind == "ItemGuardado" then
		local pos, k = b, c
		if typeof(pos) ~= "Vector3" then return end
		sound(SONS.PegarItem, pos, 0.8)
		dust(pos, COR[k] or Color3.new(1, 1, 1), 5, 1, 2)
	elseif kind == "Sugar" then
		local list, center = b, c
		if typeof(list) ~= "table" or typeof(center) ~= "Vector3" then return end
		local dur = Cfg.Succao.Duracao
		sound(SONS.Sugar, center, 1)
		corePulse(center)
		local tot = {}
		for i, entry in ipairs(list) do
			if typeof(entry) == "table" and typeof(entry.from) == "Vector3" and Cfg.Itens[entry.kind] then
				flyIntoCore(entry, center, i, #list, dur)
				tot[entry.kind] = (tot[entry.kind] or 0) + 1
			end
		end
		task.delay(dur, function()
			sound(SONS.Estoque, center, 1)
			local parts = {}
			for _, k in ipairs({ "Madeira", "Pedra" }) do
				if tot[k] then table.insert(parts, "+" .. tot[k] .. " " .. (k == "Madeira" and "madeira" or "pedra")) end
			end
			if #parts > 0 then popText(center + Vector3.new(0, 5, 0), table.concat(parts, "  "), Color3.fromRGB(255, 225, 140)) end
		end)
	end
end)

-- HUD: ESTOQUE DO NUCLEO + MOCHILA -------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUDEstoque"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Estoque"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -20, 0, 64)
panel.Size = UDim2.fromOffset(250, 34)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
panel.BackgroundTransparency = 0.2
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local pst = Instance.new("UIStroke"); pst.Color = Color3.fromRGB(120, 210, 255); pst.Thickness = 1.5; pst.Transparency = 0.3; pst.Parent = panel
local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center; lay.VerticalAlignment = Enum.VerticalAlignment.Center; lay.Padding = UDim.new(0, 14); lay.Parent = panel

local labels = {}
for i, k in ipairs({ "Madeira", "Pedra" }) do
	local t = Instance.new("TextLabel")
	t.LayoutOrder = i
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromOffset(110, 30)
	t.FontFace = FONT
	t.TextSize = 19
	t.TextColor3 = COR[k]
	t.Text = ICONE[k] .. " 0"
	t.Parent = panel
	local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Color = Color3.fromRGB(10, 10, 14); st.Parent = t
	labels[k] = t
end

local function refreshStock(k, animate)
	local n = estado:GetAttribute("Estoque" .. k) or 0
	labels[k].Text = ICONE[k] .. " " .. n
	if animate then
		local sc = labels[k]:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", labels[k])
		sc.Scale = 1.35
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end
for _, k in ipairs({ "Madeira", "Pedra" }) do
	refreshStock(k)
	estado:GetAttributeChangedSignal("Estoque" .. k):Connect(function() refreshStock(k, true) end)
end

-- mochila (aparece quando tem algo)
local bag = Instance.new("TextLabel")
bag.Name = "Mochila"
bag.AnchorPoint = Vector2.new(0.5, 1)
bag.Position = UDim2.new(0.5, 0, 1, -132)
bag.Size = UDim2.fromOffset(340, 26)
bag.BackgroundTransparency = 1
bag.FontFace = FONT
bag.TextSize = 18
bag.TextColor3 = Color3.fromRGB(255, 230, 160)
bag.Visible = false
bag.Parent = gui
local bst = Instance.new("UIStroke"); bst.Thickness = 2; bst.Color = Color3.fromRGB(30, 20, 8); bst.Parent = bag

local function refreshBag()
	local n = player:GetAttribute("MochilaTotal") or 0
	bag.Visible = n > 0
	bag.Text = "MOCHILA " .. n .. "/" .. Cfg.Mochila .. "  •  clique no Núcleo para depositar"
	bag.TextColor3 = n >= Cfg.Mochila and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(255, 230, 160)
end
player:GetAttributeChangedSignal("MochilaTotal"):Connect(refreshBag)
refreshBag()

-- dica rapida quando pega o machado pela primeira vez
local hinted = false
local function onTool(t)
	if hinted or not t:IsA("Tool") or t:GetAttribute("Arma") ~= "Machado" then return end
	hinted = true
	local h = Instance.new("TextLabel")
	h.AnchorPoint = Vector2.new(0.5, 1)
	h.Position = UDim2.new(0.5, 0, 1, -160)
	h.Size = UDim2.fromOffset(560, 26)
	h.BackgroundTransparency = 1
	h.FontFace = FONT
	h.TextSize = 17
	h.TextColor3 = Color3.new(1, 1, 1)
	h.Text = "Clique nas árvores e pedras • segure para ARRASTAR • F guarda na mochila"
	h.Parent = gui
	local st = Instance.new("UIStroke"); st.Thickness = 2; st.Parent = h
	task.delay(7, function() tween(h, 0.6, { TextTransparency = 1 }); tween(st, 0.6, { Transparency = 1 }); Debris:AddItem(h, 0.7) end)
end
player.CharacterAdded:Connect(function(c) c.ChildAdded:Connect(onTool) end)
if player.Character then player.Character.ChildAdded:Connect(onTool) end
