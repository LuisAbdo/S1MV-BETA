-- [DerrotaCliente] Cutscene de derrota: o Nucleo esta morrendo, o VERITY BOSS cai do ceu, ruge,
-- pula em cima do Nucleo e esmaga ele ate explodir. Depois a camera sobe devagar mostrando o
-- boss nas ruinas e a tela escurece (o servidor manda a tela de fim de jogo quando acaba).
-- Tudo local: o modelo vem de ReplicatedStorage.Shared.ModeloVerityBoss (copiado pelo servidor).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local estado = Shared:WaitForChild("EstadoJogo")
local SONS = require(Shared.Config.Sons)
local BossCfg = require(Shared.Config.Sobrevivencia).Boss
local rng = Random.new()

local fx = Instance.new("Folder")
fx.Name = "CutsceneDerrota"
fx.Parent = workspace

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function P(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or fx
	return p
end
local function sound(def, vol)
	if not def or not def.Id then return end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.6) * (vol or 1)
	s.PlaybackSpeed = def.P or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 10)
	return s
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- TELA: faixas pretas, fade e HUD escondido --------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DerrotaCutscene"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 250
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local bars = {}
for i, y in ipairs({ 0, 1 }) do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0, y)
	f.Position = UDim2.fromScale(0, y)
	f.Size = UDim2.new(1, 0, 0, 0)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = gui
	bars[i] = f
end
local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 1
black.BorderSizePixel = 0
black.ZIndex = 5
black.Parent = gui
local redFlash = black:Clone()
redFlash.BackgroundColor3 = Color3.fromRGB(255, 40, 30)
redFlash.ZIndex = 4
redFlash.Parent = gui

local hidden = {}
local function hideHud(on)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	if on then
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then hidden[g] = true; g.Enabled = false end
		end
	else
		for g in pairs(hidden) do if g.Parent then g.Enabled = true end end
		hidden = {}
	end
end

-- CAMERA: base animada + tremor por cima ------------------------------------------------------
local camBase = Instance.new("CFrameValue")
local shakeAmp, shakeUntil = 0, 0
local running = false
local function shake(amp, dur)
	shakeAmp = math.max(shakeAmp * math.clamp((shakeUntil - os.clock()) / 0.3, 0, 1), amp)
	shakeUntil = os.clock() + dur
end
RunService:BindToRenderStep("CameraDerrota", Enum.RenderPriority.Camera.Value + 10, function()
	if not running then return end
	local cam = workspace.CurrentCamera
	local cf = camBase.Value
	local left = shakeUntil - os.clock()
	if left > 0 then
		local a = shakeAmp * math.clamp(left / 0.4, 0, 1)
		cf = cf * CFrame.new(rng:NextNumber(-a, a) * 0.5, rng:NextNumber(-a, a) * 0.5, 0) * CFrame.Angles(math.rad(rng:NextNumber(-a, a) * 1.5), math.rad(rng:NextNumber(-a, a) * 1.5), math.rad(rng:NextNumber(-a, a)))
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
end)
local function camTo(cf, t, style)
	if not t or t <= 0 then camBase.Value = cf return end
	tween(camBase, t, { Value = cf }, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

-- NUCLEO: esconder/mostrar localmente ---------------------------------------------------------
local coreHidden = {}
local function setCoreHidden(on)
	if on then
		local core = CollectionService:GetTagged("Nucleo")[1]
		local targets = {}
		if core then table.insert(targets, core) end
		for _, n in ipairs({ "NucleoEnfeites", "VorticeNucleo" }) do
			local f = workspace:FindFirstChild(n)
			if f then table.insert(targets, f) end
		end
		for _, d in ipairs(workspace:GetChildren()) do
			if d.Name == "Rachadura" then table.insert(targets, d) end
		end
		for _, t in ipairs(targets) do
			local list = t:IsA("BasePart") and { t } or t:GetDescendants()
			for _, p in ipairs(list) do
				if p:IsA("BasePart") then p.LocalTransparencyModifier = 1; coreHidden[p] = true
				elseif p:IsA("Light") or p:IsA("ParticleEmitter") or p:IsA("BillboardGui") then
					if p.Enabled then coreHidden[p] = true; p.Enabled = false end
				end
			end
		end
	else
		for p in pairs(coreHidden) do
			if p.Parent then
				if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 else p.Enabled = true end
			end
		end
		coreHidden = {}
	end
end

-- BOSS (copia local do modelo) ----------------------------------------------------------------
local function makeBoss(size)
	local tmpl = Shared:FindFirstChild("ModeloVerityBoss")
	local b
	if tmpl and tmpl:IsA("BasePart") then
		b = tmpl:Clone()
		b.Size = Vector3.one * size
	elseif tmpl and tmpl:IsA("Model") then
		local m = tmpl:Clone()
		local _, s = m:GetBoundingBox()
		m:ScaleTo(size / math.max(s.X, s.Y, s.Z))
		b = m
	else
		b = P({ Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 230, 0), Material = Enum.Material.SmoothPlastic, Size = Vector3.one * size })
	end
	for _, d in ipairs(b:IsA("BasePart") and { b, unpack(b:GetDescendants()) } or b:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	local root = b:IsA("BasePart") and b or b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 30); light.Range = 28; light.Brightness = 4
	light.Parent = root
	local att = Instance.new("Attachment"); att.Parent = root
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(20, 8, 12), Color3.fromRGB(60, 10, 15))
	smoke.Size = NumberSequence.new(5, 11)
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Parent = att
	b.Parent = fx
	local function place(cf) if b:IsA("BasePart") then b.CFrame = cf else b:PivotTo(cf) end end
	local function squash(sx, sy)
		if b:IsA("BasePart") then b.Size = Vector3.new(size * sx, size * sy, size * sx) end
	end
	return b, place, squash, light
end

-- EFEITOS ------------------------------------------------------------------------------------
local function groundRing(pos, color, to, dur)
	local r = P({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.15, Size = Vector3.new(0.3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	tween(r, dur, { Size = Vector3.new(0.15, to, to), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(r, dur + 0.1)
end
local function dust(pos, n, spread)
	for _ = 1, n do
		local s = rng:NextNumber(2, 4.5)
		local d = P({ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 110, 95), Transparency = 0.3, Size = Vector3.one * s, Position = pos })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 0.4), rng:NextNumber(-1, 1)).Unit
		tween(d, 1.2, { Position = pos + dir * spread, Size = Vector3.one * s * 2.2, Transparency = 1 })
		Debris:AddItem(d, 1.3)
	end
end
local function shards(pos, color, n, speed)
	for _ = 1, n do
		local s = rng:NextNumber(0.5, 1.6)
		local p = P({ Color = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.4)), Size = Vector3.one * s, CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1.2), rng:NextNumber(-1, 1)).Unit
		local dist = speed * rng:NextNumber(0.6, 1.2)
		tween(p, 1.4, { CFrame = CFrame.new(pos + dir * dist + Vector3.new(0, -dist * 0.3, 0)) * CFrame.Angles(rng:NextNumber(0, 9), rng:NextNumber(0, 9), 0), Transparency = 1, Size = Vector3.one * s * 0.3 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, 1.5)
	end
end

-- CUTSCENE -----------------------------------------------------------------------------------
local function cutscene(center, T)
	local cam = workspace.CurrentCamera
	local core = CollectionService:GetTagged("Nucleo")[1]
	local esf = core and core:FindFirstChild("NucleoEsfera")
	center = esf and esf.Position or center
	local floorY = center.Y - 9
	if core then
		local bcf, bsz = core:GetBoundingBox()
		floorY = bcf.Position.Y - bsz.Y / 2
	end
	local ground = Vector3.new(center.X, floorY, center.Z)
	local toCam = flat(cam.CFrame.Position - center)
	toCam = toCam.Magnitude > 0.1 and toCam.Unit or Vector3.new(0, 0, 1)
	local side = toCam:Cross(Vector3.yAxis).Unit
	local size = BossCfg.Tamanho or 14
	local land = ground + side * 17 + toCam * 4
	local bossY = size / 2

	running = true
	gui.Enabled = true
	hideHud(true)
	camBase.Value = cam.CFrame
	for _, f in ipairs(bars) do tween(f, 0.4, { Size = UDim2.new(1, 0, 0.12, 0) }) end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DerrotaCor"
	cc.Parent = Lighting

	-- 1) Nucleo morrendo: camera aberta, alarme, piscadas vermelhas
	sound(SONS.DerrotaAlarme or SONS.AlertaNucleo)
	camTo(CFrame.lookAt(center + toCam * 36 + Vector3.new(0, 12, 0), center), 0.6)
	task.delay(0.6, function() camTo(CFrame.lookAt(center + toCam * 30 + Vector3.new(0, 9, 0), center), 1.2) end)
	for i = 0, 2 do
		task.delay(i * 0.35, function()
			redFlash.BackgroundTransparency = 0.75
			tween(redFlash, 0.3, { BackgroundTransparency = 1 })
		end)
	end
	task.wait(1.1)

	-- 2) o Verity Boss cai do ceu ao lado do Nucleo
	local boss, place, squash, light = makeBoss(size)
	local faceCore = CFrame.lookAt(land + Vector3.new(0, bossY, 0), Vector3.new(center.X, land.Y + bossY, center.Z))
	local away = CFrame.lookAt(land + Vector3.new(0, bossY, 0), land + Vector3.new(0, bossY, 0) + toCam)
	local fallFrom = away + Vector3.new(0, 80, 0)
	place(fallFrom)
	local cv = Instance.new("CFrameValue")
	cv.Value = fallFrom
	cv.Changed:Connect(function(v) place(v) end)
	camTo(CFrame.lookAt(land + toCam * 30 + Vector3.new(0, 6, 0), land + Vector3.new(0, 8, 0)), 0.5)
	tween(cv, 0.55, { Value = away }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.55)
	sound(SONS.DerrotaPouso or SONS.BossPulo)
	shake(2.2, 0.8)
	squash(1.35, 0.6)
	task.delay(0.08, function() squash(0.9, 1.15) end)
	task.delay(0.22, function() squash(1, 1) end)
	groundRing(land, Color3.fromRGB(150, 130, 110), 40, 0.8)
	dust(land, 12, 14)
	task.wait(0.7)

	-- 3) vira para o Nucleo e ruge (camera perto do Nucleo olhando para o boss)
	tween(cv, 0.5, { Value = faceCore }, Enum.EasingStyle.Back)
	camTo(CFrame.lookAt(center + (land - center).Unit * 5 + Vector3.new(0, 3, 0) - side * 3, land + Vector3.new(0, bossY + 1, 0)), 0.5)
	task.wait(0.5)
	sound(SONS.DerrotaRugido or SONS.RugidoChefe)
	shake(1.1, 1.3)
	light.Brightness = 8
	tween(cc, 0.3, { TintColor = Color3.fromRGB(255, 190, 180), Contrast = 0.2 })
	for k = 0, 5 do task.delay(k * 0.2, function() squash(1 + (k % 2) * 0.08, 1 - (k % 2) * 0.06) end) end
	task.wait(1.3)
	squash(1, 1)

	-- 4) pula e esmaga o Nucleo (3 pancadas)
	camTo(CFrame.lookAt(center - side * 34 + toCam * 22 + Vector3.new(0, 14, 0), center + Vector3.new(0, 4, 0)), 0.5)
	local top = CFrame.lookAt(center + Vector3.new(0, 24, 0), center + Vector3.new(0, 24, 0) + (center - land).Unit)
	local onCore = top - Vector3.new(0, 24 - bossY - 1.5, 0)
	tween(cv, 0.55, { Value = top }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(0.55)
	for hit = 1, 3 do
		tween(cv, hit == 1 and 0.22 or 0.16, { Value = onCore }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(hit == 1 and 0.22 or 0.16)
		sound(SONS.DerrotaImpacto or SONS.Explosao, hit == 3 and 1.2 or 0.8)
		shake(hit == 3 and 2.6 or 1.6, 0.6)
		squash(1.4, 0.55)
		task.delay(0.1, function() squash(1, 1) end)
		groundRing(ground, Color3.fromRGB(255, 80, 60), 26 + hit * 8, 0.6)
		shards(center, Color3.fromRGB(80, 220, 255), 10, 14)
		redFlash.BackgroundTransparency = 0.6
		tween(redFlash, 0.25, { BackgroundTransparency = 1 })
		if hit < 3 then
			tween(cv, 0.22, { Value = onCore + Vector3.new(0, 7, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.24)
		end
	end

	-- 5) o Nucleo implode e explode
	setCoreHidden(true)
	local orb = P({ Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 1), Transparency = 0, Size = Vector3.one * 3, Position = center })
	local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(180, 230, 255); l.Range = 60; l.Brightness = 10; l.Parent = orb
	sound(SONS.DerrotaExplosao or SONS.MinaExplosao, 1.3)
	tween(orb, 0.6, { Size = Vector3.one * 55, Transparency = 1 }, Enum.EasingStyle.Quint)
	tween(l, 0.8, { Brightness = 0 })
	Debris:AddItem(orb, 0.9)
	for k = 0, 2 do task.delay(k * 0.12, function() groundRing(ground, k == 1 and Color3.new(1, 1, 1) or Color3.fromRGB(90, 220, 255), 70 + k * 25, 1.1) end) end
	shards(center, Color3.fromRGB(90, 220, 255), 40, 34)
	dust(ground, 18, 26)
	shake(3.2, 1.2)
	black.BackgroundColor3 = Color3.new(1, 1, 1)
	black.BackgroundTransparency = 0.1
	tween(black, 0.5, { BackgroundTransparency = 1 })
	tween(cc, 1.2, { Saturation = -0.7, Contrast = 0.3, TintColor = Color3.fromRGB(255, 170, 160) })
	-- o boss e jogado para cima e cai nas ruinas
	local ruins = CFrame.lookAt(ground + Vector3.new(0, bossY, 0), ground + Vector3.new(0, bossY, 0) + toCam)
	tween(cv, 0.45, { Value = onCore + Vector3.new(0, 14, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.45, function()
		tween(cv, 0.4, { Value = ruins }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.4, function()
			shake(1.6, 0.5)
			squash(1.3, 0.65)
			task.delay(0.12, function() squash(1, 1) end)
			dust(ground, 10, 12)
		end)
	end)
	-- fumaca subindo das ruinas
	local smokeA = P({ Transparency = 1, Size = Vector3.one * 0.2, Position = ground + Vector3.new(0, 1, 0) })
	local sm = Instance.new("ParticleEmitter")
	sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
	sm.Color = ColorSequence.new(Color3.fromRGB(40, 36, 36))
	sm.Size = NumberSequence.new(4, 12)
	sm.Transparency = NumberSequence.new(0.35, 1)
	sm.Lifetime = NumberRange.new(2, 3.5)
	sm.Speed = NumberRange.new(4, 8)
	sm.SpreadAngle = Vector2.new(25, 25)
	sm.Rate = 18
	sm.Parent = smokeA

	-- 6) camera sobe devagar mostrando o boss nas ruinas
	camTo(CFrame.lookAt(ground + toCam * 26 + Vector3.new(0, 6, 0), ground + Vector3.new(0, bossY, 0)), 0.01)
	task.wait(0.9)
	camTo(CFrame.lookAt(ground + toCam * 44 + side * 10 + Vector3.new(0, 30, 0), ground + Vector3.new(0, bossY * 0.6, 0)), math.max(1, T - 6.9), Enum.EasingStyle.Sine)
	local left = math.max(0.8, T - 6.9 - 0.7)
	task.wait(left)

	-- 7) escurece e devolve a camera (a tela de fim de jogo chega do servidor)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	tween(black, 0.6, { BackgroundTransparency = 0 })
	task.wait(0.65)
	running = false
	cam.CameraType = Enum.CameraType.Custom
	sm.Enabled = false
	Debris:AddItem(smokeA, 4)
	if boss.Parent then boss:Destroy() end
	cv:Destroy()
	for _, f in ipairs(bars) do f.Size = UDim2.new(1, 0, 0, 0) end
	hideHud(false)
	tween(black, 0.8, { BackgroundTransparency = 1 })
	tween(cc, 1.5, { Saturation = -0.25, Contrast = 0.1, TintColor = Color3.fromRGB(255, 225, 220) })
	task.delay(0.85, function() gui.Enabled = false end)
end

remotes.Efeito.OnClientEvent:Connect(function(kind, center, T)
	if kind ~= "DerrotaCutscene" or running then return end
	task.spawn(function()
		local ok, err = pcall(cutscene, typeof(center) == "Vector3" and center or Vector3.zero, tonumber(T) or 8.5)
		if not ok then
			warn("[DerrotaCliente] " .. tostring(err))
			running = false
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			hideHud(false)
			gui.Enabled = false
		end
	end)
end)

-- nova run: o Nucleo volta, a cor normal volta e os restos somem
estado:GetAttributeChangedSignal("Fase"):Connect(function()
	if estado:GetAttribute("Fase") ~= "Derrota" then
		setCoreHidden(false)
		local cc = Lighting:FindFirstChild("DerrotaCor")
		if cc then tween(cc, 1, { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }); Debris:AddItem(cc, 1.1) end
		fx:ClearAllChildren()
	end
end)
