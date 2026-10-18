-- [GlitcityCliente] Cutscene de chegada do GLITCITY e os efeitos dele na luta.
-- 1) ceu piscando entre dia e noite + estatica + artefatos na tela  2) HUD some e a camera vai
-- para a floresta  3) blocos neon sobem do chao em gravidade zero  4) estalo (bass drop) e o chefe
-- se materializa  5) texto corrompido [WARNING: GLITCITY DETECTED] e a camera volta.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = Shared:WaitForChild("Remotes")
local SONS = require(Shared.Config.Sons)
local WavesCfg = require(Shared.Config.Waves)
local rng = Random.new()
local NEON = { Color3.fromRGB(255, 230, 40), Color3.fromRGB(255, 70, 200), Color3.fromRGB(60, 200, 255) }

local fx = Instance.new("Folder")
fx.Name = "GlitchFX"
fx.Parent = workspace

local function tween(o, t, p, s, d) local tw = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out), p); tw:Play(); return tw end
local function sound(def, vol, pitch, looped)
	if not def then return end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.V or 0.6) * (vol or 1)
	s.PlaybackSpeed = pitch or def.P or 1
	s.Looped = looped or false
	s.Parent = game:GetService("SoundService")
	s:Play()
	if not looped then Debris:AddItem(s, 8) end
	return s
end
local function part(o)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = o.material or Enum.Material.Neon
	p.Color = o.color or Color3.new(1, 1, 1)
	p.Size = o.size or Vector3.one
	p.CFrame = o.cf or CFrame.new()
	p.Transparency = o.transparency or 0
	p.Parent = fx
	if o.life then Debris:AddItem(p, o.life) end
	return p
end

-- TELA CORROMPIDA ------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "GlitchTela"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")
local bars = {}
for i = 1, 14 do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = gui
	bars[i] = f
end
local avisoLbl = Instance.new("TextLabel")
avisoLbl.AnchorPoint = Vector2.new(0.5, 0.5)
avisoLbl.Position = UDim2.fromScale(0.5, 0.42)
avisoLbl.Size = UDim2.fromOffset(900, 70)
avisoLbl.BackgroundTransparency = 1
avisoLbl.Font = Enum.Font.Code
avisoLbl.TextScaled = true
avisoLbl.TextColor3 = Color3.fromRGB(255, 60, 90)
avisoLbl.TextTransparency = 1
avisoLbl.Text = ""
avisoLbl.Parent = gui
local warnStroke = Instance.new("UIStroke"); warnStroke.Thickness = 3; warnStroke.Color = Color3.fromRGB(30, 0, 40); warnStroke.Transparency = 1; warnStroke.Parent = avisoLbl
local warnShadow = avisoLbl:Clone(); warnShadow.TextColor3 = Color3.fromRGB(60, 200, 255); warnShadow.ZIndex = 0; warnShadow.Parent = gui
local letterbox = {}
for i, y in ipairs({ 0, 1 }) do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0, y)
	f.Position = UDim2.fromScale(0, y)
	f.Size = UDim2.new(1, 0, 0, 0)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = gui
	letterbox[i] = f
end

local glitching = false

-- TREMOR DE TELA: aplicado depois da camera do Roblox (funciona em Custom e Scriptable)
local shake = 0
RunService:BindToRenderStep("GlitchShake", Enum.RenderPriority.Camera.Value + 1, function()
	if shake <= 0 then return end
	local cam = workspace.CurrentCamera
	local a = shake
	cam.CFrame = cam.CFrame
		* CFrame.new(rng:NextNumber(-a, a) * 0.6, rng:NextNumber(-a, a) * 0.6, 0)
		* CFrame.Angles(math.rad(rng:NextNumber(-a, a) * 1.5), math.rad(rng:NextNumber(-a, a) * 1.5), math.rad(rng:NextNumber(-a, a) * 2))
end)
local function shakeFor(amount, dur)
	shake = math.max(shake, amount)
	task.delay(dur, function() if shake <= amount then shake = 0 end end)
end

local function glitchFrame()
	for _, b in ipairs(bars) do
		if rng:NextNumber() < 0.6 then
			b.Visible = true
			b.Position = UDim2.fromScale(rng:NextNumber(-0.1, 0.9), rng:NextNumber(0, 1))
			b.Size = UDim2.new(rng:NextNumber(0.1, 0.6), 0, 0, rng:NextInteger(2, 26))
			b.BackgroundColor3 = rng:NextNumber() < 0.5 and NEON[rng:NextInteger(1, 3)] or Color3.new(rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
			b.BackgroundTransparency = rng:NextNumber(0.1, 0.6)
		else
			b.Visible = false
		end
	end
end
local function clearGlitch() for _, b in ipairs(bars) do b.Visible = false end end

local CHARS = "!@#$%&*?<>/\\|=+_01"
local function corrupt(text, amount)
	local out = {}
	for i = 1, #text do
		local c = text:sub(i, i)
		if c ~= " " and rng:NextNumber() < amount then
			local k = rng:NextInteger(1, #CHARS)
			c = CHARS:sub(k, k)
		end
		table.insert(out, c)
	end
	return table.concat(out)
end

-- HUD some durante a cutscene
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

-- CUTSCENE -------------------------------------------------------------------------------------
local function cutscene(pos, T)
	local cam = workspace.CurrentCamera
	glitching = true
	-- 1) ceu enlouquecido + estatica + congeladas na tela
	local static = sound(SONS.GlitchEstatica or SONS.UIErro, 1, nil, true)
	local t0 = os.clock()
	while os.clock() - t0 < T.Glitch do
		shake = 0.35 + 0.65 * ((os.clock() - t0) / T.Glitch)   -- tremor cresce junto com o glitch
		local day = rng:NextNumber() < 0.5
		Lighting.ClockTime = day and 13 or 0.5
		Lighting.Brightness = day and 3 or 0.4
		glitchFrame()
		if static then static.PlaybackSpeed = rng:NextNumber(0.4, 1.4) end
		if rng:NextNumber() < 0.15 then
			-- "congelamento": a camera trava por um instante
			local held = cam.CFrame
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = held
			task.wait(rng:NextNumber(0.08, 0.18))
			cam.CameraType = Enum.CameraType.Custom
		else
			task.wait(rng:NextNumber(0.04, 0.12))
		end
	end
	clearGlitch()
	shake = 0
	-- 2) HUD some, faixas pretas e a camera vai para a floresta
	hideHud(true)
	for _, f in ipairs(letterbox) do tween(f, 0.4, { Size = UDim2.new(1, 0, 0.11, 0) }) end
	local L = WavesCfg.Luz.Noite
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	local back = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local from = root and Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z) or Vector3.new(1, 0, 0)
	from = from.Magnitude > 0.1 and from.Unit or Vector3.new(1, 0, 0)
	-- escolhe um angulo de camera sem arvore/folhas na frente do ponto de surgimento
	local shot
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { fx, player.Character }
		local look = pos + Vector3.new(0, 6, 0)
		local baseAng = math.atan2(-from.Z, -from.X)
		local best, bestScore = nil, math.huge
		for i = 0, 15 do
			local ang = baseAng + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * (math.pi / 8)
			for _, dist in ipairs({ 30, 22 }) do
				local camPos = pos + Vector3.new(math.cos(ang) * dist, 14, math.sin(ang) * dist)
				local blocked = 0
				for _, off in ipairs({ Vector3.zero, Vector3.new(0, 4, 0), Vector3.new(0, -3, 0) }) do
					local tgt = look + off
					local hit = workspace:Raycast(camPos, (tgt - camPos) * 0.92, params)
					if hit then blocked += 1 end
				end
				local score = blocked * 10 + i * 0.1 + (dist == 22 and 0.5 or 0)
				if score < bestScore then best, bestScore = camPos, score end
			end
			if bestScore < 1 then break end
		end
		shot = CFrame.lookAt(best or (pos - from * 30 + Vector3.new(0, 14, 0)), look)
	end
	tween(cam, T.Camera, { CFrame = shot }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.wait(T.Camera)
	-- 3) blocos neon subindo do chao em gravidade zero
	if static then tween(static, T.Blocos, { Volume = 0.1 }) end
	local blocks = {}
	for i = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, 14)
		local s = rng:NextNumber(0.8, 2.4)
		local start = pos + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)
		local b = part({ color = NEON[(i % 3) + 1], size = Vector3.one * s, cf = CFrame.new(start), life = T.Blocos + T.Texto + 2 })
		local l = Instance.new("PointLight"); l.Color = b.Color; l.Range = 8; l.Brightness = 2; l.Parent = b
		table.insert(blocks, b)
		task.delay(rng:NextNumber(0, T.Blocos * 0.5), function()
			tween(b, T.Blocos * 1.4, { CFrame = CFrame.new(start + Vector3.new(0, rng:NextNumber(5, 16), 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)) }, Enum.EasingStyle.Sine)
		end)
	end
	local t1 = os.clock()
	while os.clock() - t1 < T.Blocos do
		cam.CFrame = shot * CFrame.Angles(0, 0, math.rad(math.sin(os.clock() * 30) * 0.4))
		if rng:NextNumber() < 0.25 then glitchFrame() else clearGlitch() end
		task.wait(0.05)
	end
	clearGlitch()
	-- 4) estalo bitcrush / bass drop: o chefe aparece (o servidor cria agora)
	if static then static:Destroy() end
	sound(SONS.GlitchEstalo or SONS.Explosao)
	sound(SONS.GlitchRugido or SONS.RugidoChefe)
	shakeFor(1.2, 0.5)
	local flash = part({ shape = nil, color = Color3.new(1, 1, 1), size = Vector3.one * 4, cf = CFrame.new(pos + Vector3.new(0, 6, 0)), life = 0.6 })
	flash.Shape = Enum.PartType.Ball
	tween(flash, 0.5, { Size = Vector3.one * 40, Transparency = 1 })
	local cc = Instance.new("ColorCorrectionEffect"); cc.Brightness = 0.6; cc.Contrast = 0.5; cc.Saturation = -1; cc.Parent = Lighting
	tween(cc, 0.6, { Brightness = 0, Contrast = 0, Saturation = 0 }); Debris:AddItem(cc, 0.7)
	for _, b in ipairs(blocks) do
		if b.Parent then tween(b, 2.5, { CFrame = b.CFrame * CFrame.Angles(3, 2, 1) + Vector3.new(0, 2, 0) }, Enum.EasingStyle.Sine) end
	end
	-- 5) texto corrompido e a camera volta
	local TXT = "[WARNING: GLITCITY DETECTED]"
	avisoLbl.TextTransparency = 0; warnStroke.Transparency = 0; warnShadow.TextTransparency = 0.3
	local t2 = os.clock()
	while os.clock() - t2 < T.Texto do
		local k = 1 - (os.clock() - t2) / T.Texto
		avisoLbl.Text = corrupt(TXT, 0.35 * k + 0.05)
		warnShadow.Text = avisoLbl.Text
		avisoLbl.Position = UDim2.new(0.5, rng:NextInteger(-6, 6), 0.42, rng:NextInteger(-3, 3))
		warnShadow.Position = avisoLbl.Position + UDim2.fromOffset(rng:NextInteger(-8, 8), rng:NextInteger(-3, 3))
		if rng:NextNumber() < 0.2 then glitchFrame(); shakeFor(0.5, 0.1) else clearGlitch() end
		task.wait(0.06)
	end
	clearGlitch()
	tween(avisoLbl, 0.5, { TextTransparency = 1 }); tween(warnStroke, 0.5, { Transparency = 1 }); tween(warnShadow, 0.5, { TextTransparency = 1 })
	for _, f in ipairs(letterbox) do tween(f, 0.4, { Size = UDim2.new(1, 0, 0, 0) }) end
	local ret = root and root.Parent and (CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 6, 0), root.Position)) or back
	tween(cam, 0.8, { CFrame = ret }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
	cam.CameraType = Enum.CameraType.Custom
	hideHud(false)
	glitching = false
end

-- EFEITOS DA LUTA ----------------------------------------------------------------------------
local function emp(pos, radius, dur)
	sound(SONS.GlitchEMP or SONS.UIErro)
	local ring = part({ size = Vector3.new(0.4, 4, 4), cf = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = NEON[3], transparency = 0.2, life = 1 })
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, 0.7, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quint)
	local sph = part({ size = Vector3.one * 4, cf = CFrame.new(pos), color = NEON[2], material = Enum.Material.ForceField, life = 0.8 })
	sph.Shape = Enum.PartType.Ball
	tween(sph, 0.7, { Size = Vector3.one * radius * 2, Transparency = 1 })
	-- torres desligadas piscam (local)
	for _, st in ipairs(game:GetService("CollectionService"):GetTagged("Estrutura")) do
		local pp = st.PrimaryPart
		if pp and (pp.Position - pos).Magnitude <= radius then
			local h = Instance.new("Highlight")
			h.FillColor = NEON[3]; h.OutlineColor = NEON[2]; h.FillTransparency = 0.6
			h.Parent = st
			Debris:AddItem(h, dur)
			task.spawn(function()
				local t0 = os.clock()
				while h.Parent and os.clock() - t0 < dur do
					h.Enabled = rng:NextNumber() < 0.6
					task.wait(0.08)
				end
			end)
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - pos).Magnitude <= radius * 1.5 and not glitching then
		shakeFor(0.6, 0.3)
		task.spawn(function()
			for _ = 1, 5 do glitchFrame(); task.wait(0.05) end
			clearGlitch()
		end)
	end
end

local function trail(pos)
	for _ = 1, 2 do
		local s = rng:NextNumber(1.2, 3)
		local p = part({ size = Vector3.new(s, 0.1, s), cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-4, 4), 0.1, rng:NextNumber(-4, 4))), color = NEON[rng:NextInteger(1, 3)], transparency = 0.3, life = 3 })
		task.spawn(function()
			for _ = 1, 8 do
				if not p.Parent then return end
				p.Transparency = rng:NextNumber(0.2, 0.9)
				task.wait(0.12)
			end
			if p.Parent then tween(p, 1.5, { Transparency = 1 }) end
		end)
	end
end

remotes.Efeito.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "GlitcityCutscene" and typeof(a) == "Vector3" and typeof(b) == "table" then
		task.spawn(function()
			local ok, err = pcall(cutscene, a, b)
			if not ok then
				shake = 0
				warn("[GlitcityCliente] " .. tostring(err))
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				hideHud(false)
				clearGlitch()
			end
		end)
	elseif kind == "GlitchEMP" and typeof(a) == "Vector3" then
		emp(a, b or 30, c or 4)
	elseif kind == "GlitchRastro" and typeof(a) == "Vector3" then
		trail(a)
	elseif kind == "GlitchVoxels" then
		sound(SONS.GlitchVoxels or SONS.Construir)
	elseif kind == "GlitcityMorreu" and typeof(a) == "Vector3" then
		sound(SONS.GlitchMorte or SONS.Explosao)
		for i = 1, 30 do
			local b2 = part({ size = Vector3.one * rng:NextNumber(0.6, 2), cf = CFrame.new(a), color = NEON[(i % 3) + 1], life = 2 })
			tween(b2, 1.6, { CFrame = CFrame.new(a + Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(4, 24), rng:NextNumber(-20, 20))), Transparency = 1 })
		end
		shakeFor(0.9, 0.5)
		task.spawn(function() for _ = 1, 8 do glitchFrame(); task.wait(0.05) end; clearGlitch() end)
	end
end)
