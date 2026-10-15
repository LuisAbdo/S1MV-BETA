-- [VerityBossCliente] Efeitos do Verity da noite: surgir do chao, tremor a cada pulo (som de
-- "pe-grande"), vinheta vermelha quando ele esta perto, golpe e o susto quando o alvo chega no Nucleo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local SONS = require(Shared.Config.Sons)
local camera = workspace.CurrentCamera
local rng = Random.new()

local fx = Instance.new("Folder")
fx.Name = "BossFX"
fx.Parent = workspace

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function anchor(pos, life)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.one * 0.2; p.Position = pos
	p.Parent = fx
	Debris:AddItem(p, life or 6)
	return p
end

local function sound(id, pos, vol, pitch, maxDist)
	local a = anchor(pos, 8)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = pitch or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 15
	s.RollOffMaxDistance = maxDist or 160
	s.Parent = a
	s:Play()
	return s
end

local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function distTo(pos)
	local r = myRoot()
	return r and (r.Position - pos).Magnitude or (camera.CFrame.Position - pos).Magnitude
end

-- TREMOR (forte e grave; somado depois da camera) ---------------------------------------------
local shake = 0
RunService:BindToRenderStep("BossShake", Enum.RenderPriority.Camera.Value + 4, function(dt)
	if shake > 0.003 then
		local s = shake * shake
		local t = os.clock() * 22
		camera.CFrame = camera.CFrame
			* CFrame.new(math.noise(t, 3.3) * 0.9 * s, math.noise(t, 8.1) * 1.3 * s, 0)
			* CFrame.Angles(math.rad(math.noise(t, 5.5) * 3 * s), math.rad(math.noise(t, 1.9) * 2 * s), math.rad(math.noise(t, 6.6) * 2.5 * s))
		shake = math.max(0, shake - dt * 2.2)
	end
end)
local function addShake(a) shake = math.min(1.5, shake + a) end

local function dustRing(pos, radius, amount)
	local a = anchor(pos + Vector3.new(0, 0.5, 0), 4)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 110, 95))
	e.LightInfluence = 0.8
	e.Size = NumberSequence.new(3, 8)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Speed = NumberRange.new(radius * 1.4, radius * 2.2)
	e.SpreadAngle = Vector2.new(4, 180)
	e.Drag = 4
	e.EmissionDirection = Enum.NormalId.Top
	e.Enabled = false
	e.Parent = a
	a.CFrame = CFrame.new(a.Position) * CFrame.Angles(0, 0, math.rad(90))
	e:Emit(amount or 20)
	-- anel de impacto no chao
	local ring = Instance.new("Part")
	ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(70, 55, 45)
	ring.Transparency = 0.4
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fx
	tween(ring, 0.5, { Size = Vector3.new(0.05, radius * 2.6, radius * 2.6), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(ring, 0.6)
end

-- VINHETA VERMELHA QUANDO ELE ESTA PERTO ------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BossVinheta"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(60, 0, 8)
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Parent = gui
local grad = Instance.new("UIGradient")
grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0) })
grad.Parent = frame
local frame2 = frame:Clone()
frame2.Parent = gui
frame2.UIGradient.Rotation = 90

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "BossMedo"
cc.Parent = Lighting

RunService.RenderStepped:Connect(function()
	local f = workspace:FindFirstChild("VerityBoss")
	local body = f and f:FindFirstChild("Corpo")
	local k = 0
	if body then
		local d = distTo(body.Position)
		k = math.clamp(1 - (d - 15) / 70, 0, 1)
	end
	local pulse = 0.85 + math.sin(os.clock() * 5) * 0.15
	local tr = 1 - k * 0.6 * pulse
	frame.BackgroundTransparency = tr
	frame2.BackgroundTransparency = tr
	cc.Saturation = -0.3 * k
	cc.TintColor = Color3.new(1, 1 - 0.1 * k, 1 - 0.12 * k)
end)

-- EVENTOS -------------------------------------------------------------------------------------
remotes.Efeito.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "BossSurge" then
		local pos, size, target, snd = a, b, c, d
		if typeof(pos) ~= "Vector3" then return end
		if typeof(snd) == "string" then sound(snd, pos, 1.4, 1, 220) end
		dustRing(pos, size or 14, 36)
		-- pedacos de terra saindo
		for _ = 1, 14 do
			local p = Instance.new("Part")
			p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
			p.Size = Vector3.one * rng:NextNumber(0.6, 1.4)
			p.Color = Color3.fromRGB(80, 62, 44)
			p.Material = Enum.Material.Ground
			p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-4, 4), 1, rng:NextNumber(-4, 4)))
			p.Parent = fx
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(25, 45), rng:NextNumber(-18, 18))
			Debris:AddItem(p, 2.5)
		end
		local d0 = distTo(pos)
		addShake(math.clamp(1.1 - d0 / 120, 0, 1))
		if target == player then
			-- aviso so para a vitima: tela escurece por um instante
			local blk = Instance.new("ColorCorrectionEffect")
			blk.Brightness = -0.25
			blk.Contrast = 0.3
			blk.TintColor = Color3.fromRGB(255, 170, 170)
			blk.Parent = Lighting
			tween(blk, 2, { Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
			Debris:AddItem(blk, 2.2)
		end
	elseif kind == "BossPulo" then
		local pos, size, radius = a, b, c
		if typeof(pos) ~= "Vector3" then return end
		local dist = distTo(pos)
		sound(SONS.BossPulo.Id, pos, SONS.BossPulo.V or 1, rng:NextNumber(0.92, 1.05), 220)
		dustRing(pos, (size or 14) * 0.6, 14)
		local r = radius or 90
		if dist < r then addShake(0.95 * (1 - dist / r) ^ 1.2 + 0.08) end
	elseif kind == "BossAtaque" then
		local who, pos = a, b
		if who == player then
			addShake(1.2)
			local red = Instance.new("ColorCorrectionEffect")
			red.TintColor = Color3.fromRGB(255, 120, 120)
			red.Brightness = 0.1
			red.Parent = Lighting
			tween(red, 0.6, { TintColor = Color3.new(1, 1, 1), Brightness = 0 })
			Debris:AddItem(red, 0.7)
		end
		if typeof(pos) == "Vector3" then sound(SONS.Soco.Id, pos, 1, 0.6, 100) end
	elseif kind == "BossSome" then
		local pos, size, reason = a, b, c
		if typeof(pos) ~= "Vector3" then return end
		if reason == "susto" then
			sound(SONS.BossSusto.Id, pos, SONS.BossSusto.V or 1, SONS.BossSusto.P or 1.4, 180)
			-- "!" de susto em cima dele
			local an = anchor(pos + Vector3.new(0, (size or 14) * 1.3, 0), 2)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(120, 120)
			bb.AlwaysOnTop = true
			bb.Parent = an
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = "!!"
			t.TextColor3 = Color3.fromRGB(255, 230, 60)
			t.Parent = bb
			local st = Instance.new("UIStroke"); st.Thickness = 4; st.Color = Color3.fromRGB(80, 20, 0); st.Parent = t
			local sc = Instance.new("UIScale"); sc.Scale = 0.2; sc.Parent = t
			tween(sc, 0.2, { Scale = 1.2 }, Enum.EasingStyle.Back)
			task.delay(1.2, function() tween(t, 0.4, { TextTransparency = 1 }); tween(st, 0.4, { Transparency = 1 }) end)
		else
			dustRing(pos, (size or 14) * 0.5, 16)
		end
	end
end)
