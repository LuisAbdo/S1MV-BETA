-- [ReviveCliente] Painel de morte (REVIVER / ESPERAR PROXIMA WAVE) e a animacao do GODRITY:
-- feixe de luz do ceu, particulas brancas subindo, Godrity (esfera branca com asas batendo
-- e aureola) surge ao lado do corpo e levanta o jogador, onda de luz no chao, penas, sino.
-- So visual: quem decide o revive e o servidor (ReviveService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Revive"))
local remotes = Shared:WaitForChild("Remotes")

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MINT = Color3.fromRGB(98, 226, 160)
local BLACK = Color3.fromRGB(14, 14, 16)
local GOLD = Color3.fromRGB(255, 214, 90)
local GREY = Color3.fromRGB(150, 150, 155)
local RED = Color3.fromRGB(232, 72, 86)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

-- PAINEL DE MORTE ---------------------------------------------------------------
local gui = new("ScreenGui", { Name = "PainelMorte", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 35, Enabled = false }, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720), 0.6, 1.4) end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 0, 4), BackgroundTransparency = 0.55, BorderSizePixel = 0 }, gui)
local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(500, 270), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0 }, gui)
local head = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = RED, BorderSizePixel = 0 }, card)
local title = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "VOCÊ CAIU!", FontFace = HEAVY, TextSize = 32, TextColor3 = Color3.new(1, 1, 1) }, head)
new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(60, 10, 16) }, title)
local info = new("TextLabel", { Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 34), BackgroundTransparency = 1, Text = "", FontFace = BOLD, TextSize = 15, TextColor3 = GREY, TextWrapped = true }, card)

local function bigButton(y, color, textColor)
	local b = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(440, 72), BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = true, Text = "" }, card)
	local t = new("TextLabel", { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, FontFace = HEAVY, TextSize = 26, TextColor3 = textColor, Text = "" }, b)
	local s = new("TextLabel", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 14, TextColor3 = textColor, TextTransparency = 0.2, Text = "" }, b)
	return b, t, s
end
local reviveBtn, reviveTxt, reviveSub = bigButton(104, GOLD, BLACK)
local waitBtn, waitTxt, waitSub = bigButton(184, BLACK, MINT)
new("UIStroke", { Thickness = 2, Color = MINT, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, waitBtn)
-- auréola desenhada no botao de reviver
local halo = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, reviveBtn)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)
new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 240, 160) }, halo)

local current
local canRevive = true
local function render(data)
	current = data
	if not data then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local waiting = data.escolha == "esperar"
	if waiting then
		if data.fase == "Dia" then
			info.Text = "Você volta em alguns segundos..."
		else
			info.Text = "Esperando o dia nascer. Você volta no início do próximo dia."
		end
	else
		info.Text = "O Núcleo ainda precisa de você!"
	end
	canRevive = true
	reviveTxt.Text = "REVIVER AGORA"
	if (data.credito or 0) > 0 then
		reviveSub.Text = "Usar revive guardado (" .. data.credito .. ")"
	elseif data.gratis then
		reviveSub.Text = "GRÁTIS · seu primeiro revive"
	elseif (data.pagos or 0) >= (data.max or 2) then
		reviveSub.Text = "Limite de " .. (data.max or 2) .. " revives pagos nesta run"
		canRevive = false
	else
		reviveSub.Text = "R$ " .. tostring(data.preco or 15) .. " · restam " .. ((data.max or 2) - (data.pagos or 0)) .. " nesta run"
	end
	reviveBtn.BackgroundColor3 = canRevive and GOLD or Color3.fromRGB(60, 60, 64)
	reviveTxt.TextColor3 = canRevive and BLACK or GREY
	reviveSub.TextColor3 = reviveTxt.TextColor3
	waitTxt.Text = waiting and "ESPERANDO..." or "ESPERAR PRÓXIMA WAVE"
	waitSub.Text = data.fase == "Dia" and ("Grátis · volta em " .. tostring(data.espera or 8) .. " s") or "Grátis · volta no início do próximo dia"
	waitBtn.AutoButtonColor = not waiting
end

reviveBtn.MouseButton1Click:Connect(function()
	if current and canRevive then remotes.Reviver:FireServer("agora") end
end)
waitBtn.MouseButton1Click:Connect(function()
	if current and current.escolha ~= "esperar" then remotes.Reviver:FireServer("esperar") end
end)
remotes.PainelMorte.OnClientEvent:Connect(render)

-- GODRITY ---------------------------------------------------------------------------
local fx = new("Folder", { Name = "Godrity" }, workspace.CurrentCamera)

local function P(props)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = props.Parent or fx
	return p
end

local function chime(at, k)
	local holder = new("Attachment", { WorldPosition = at }, workspace.Terrain)
	-- jingle magico de reviver (um so som, levemente mais grave)
	local s = new("Sound", { SoundId = "rbxassetid://122399158411452", Volume = 0.7, PlaybackSpeed = 0.75 / math.max(k or 1, 0.5), RollOffMaxDistance = 160 }, holder)
	s:Play()
	Debris:AddItem(holder, 4)
end

local function buildGodrity()
	local m = Instance.new("Model")
	m.Name = "GODRITY"
	local parts = {}
	local body = P({ Name = "Corpo", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = Color3.fromRGB(250, 250, 255), Material = Enum.Material.SmoothPlastic, Parent = m })
	new("PointLight", { Color = Color3.fromRGB(255, 250, 220), Range = 14, Brightness = 2.5 }, body)
	parts.body = body
	parts.eyes = {
		P({ Name = "Olho", Size = Vector3.new(0.22, 0.42, 0.1), Color = Color3.fromRGB(30, 30, 40), Parent = m }),
		P({ Name = "Olho", Size = Vector3.new(0.22, 0.42, 0.1), Color = Color3.fromRGB(30, 30, 40), Parent = m }),
	}
	-- aureola: anel de pecas neon
	parts.halo = {}
	for i = 1, 14 do
		table.insert(parts.halo, P({ Name = "Aureola", Size = Vector3.new(0.22, 0.18, 0.5), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon, Parent = m }))
	end
	-- asas: 3 "penas" em leque de cada lado
	parts.wings = { {}, {} }
	for side = 1, 2 do
		for i = 1, 3 do
			table.insert(parts.wings[side], P({ Name = "Pena", Size = Vector3.new(0.18, 0.55, 1.7 - i * 0.25), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Parent = m }))
		end
	end
	m.Parent = fx
	return m, parts
end

local function placeGodrity(parts, cf, flap, scale)
	scale = math.max(0.01, scale)
	parts.body.Size = Vector3.one * 2.4 * scale
	parts.body.CFrame = cf
	parts.eyes[1].CFrame = cf * CFrame.new(-0.38 * scale, 0.2 * scale, -1.15 * scale)
	parts.eyes[2].CFrame = cf * CFrame.new(0.38 * scale, 0.2 * scale, -1.15 * scale)
	parts.eyes[1].Size = Vector3.new(0.22, 0.42, 0.1) * scale
	parts.eyes[2].Size = Vector3.new(0.22, 0.42, 0.1) * scale
	for i, h in ipairs(parts.halo) do
		local a = i / #parts.halo * math.pi * 2
		h.Size = Vector3.new(0.22, 0.18, 0.5) * scale
		h.CFrame = cf * CFrame.new(math.cos(a) * 0.95 * scale, 1.75 * scale, math.sin(a) * 0.95 * scale) * CFrame.Angles(0, -a, 0)
	end
	for side = 1, 2 do
		local sgn = side == 1 and -1 or 1
		local root = cf * CFrame.new(sgn * 1.05 * scale, 0.25 * scale, 0.35 * scale) * CFrame.Angles(0, 0, sgn * flap)
		for i, f in ipairs(parts.wings[side]) do
			f.Size = Vector3.new(0.18, 0.55, 1.7 - i * 0.25) * scale
			f.CFrame = root * CFrame.Angles(0, 0, sgn * math.rad(-20 + i * 22)) * CFrame.new(sgn * 0.9 * scale, 0, 0) * CFrame.Angles(0, sgn * math.rad(60), 0)
		end
	end
end

local function sparkBurst(pos, n, upward)
	local p = P({ Transparency = 1, Size = Vector3.one, Position = pos })
	local e = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 240, 180)),
		LightEmission = 1, Size = NumberSequence.new(0.9, 0), Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(upward and 4 or 8, upward and 9 or 16), SpreadAngle = upward and Vector2.new(25, 25) or Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, upward and 6 or 0, 0), Enabled = false,
	}, p)
	e:Emit(n)
	Debris:AddItem(p, 1.6)
end

local function godrity(who, ground, k)
	k = k or 1
	local A = Cfg.Animacao
	local appear, control, total = A.AparecerEm * k, A.Controle * k, A.Total * k
	local t0 = os.clock()
	chime(ground + Vector3.new(0, 3, 0), k)
	-- feixe de luz do ceu
	local beam = P({ Name = "Feixe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(160, 0.5, 0.5), Color = Color3.fromRGB(255, 252, 235), Material = Enum.Material.Neon, Transparency = 0.45, CFrame = CFrame.new(ground + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(beam, TweenInfo.new(0.35 * k, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(160, 3.5, 3.5) }):Play()
	-- particulas brancas subindo
	local disc = P({ Transparency = 1, Size = Vector3.new(5, 0.2, 5), CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) })
	local rise = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 1, Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(1, 1.6), Rate = 70,
		Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(8, 8), EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
	}, disc)
	-- Godrity surge ao lado do corpo
	local side = Vector3.new(3.6, 0, 0)
	local cam = workspace.CurrentCamera
	if cam then
		local r = cam.CFrame.RightVector
		side = Vector3.new(r.X, 0, r.Z)
		side = side.Magnitude > 0.1 and side.Unit * 3.6 or Vector3.new(3.6, 0, 0)
	end
	local m, parts = buildGodrity()
	placeGodrity(parts, CFrame.new(ground + side + Vector3.new(0, 4.5, 0)), 0, 0.01)
	local waved, feathered, vanished = false, false, false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		-- levantar (mesma curva do servidor)
		local lift = 0
		if t > appear and t < control then
			local u = (t - appear) / (control - appear)
			lift = u < 0.6 and math.sin(u / 0.6 * math.pi / 2) * A.AlturaLevantar or (1 - ((u - 0.6) / 0.4) ^ 2) * A.AlturaLevantar
		end
		local pop = t < appear and 0 or math.clamp((t - appear) / (0.25 * k), 0, 1)
		pop = pop < 1 and (1 - (1 - pop) ^ 3) * 1.15 or 1
		local fade = t > total - 0.35 * k and math.clamp(1 - (t - (total - 0.35 * k)) / (0.35 * k), 0, 1) or 1
		local bob = math.sin(t * 5) * 0.25
		local look = cam and Vector3.new(cam.CFrame.Position.X, 0, cam.CFrame.Position.Z) or Vector3.zero
		local pos = ground + side + Vector3.new(0, 4.5 + lift + bob, 0)
		local face = Vector3.new(look.X, pos.Y, look.Z)
		local cf = (face - pos).Magnitude > 0.5 and CFrame.lookAt(pos, face) or CFrame.new(pos)
		placeGodrity(parts, cf, math.sin(t * 16) * math.rad(35), pop * fade * 1.35)
		if not waved and t >= appear then
			waved = true
			-- o feixe afina para nao esconder o Godrity
			TweenService:Create(beam, TweenInfo.new(0.6 * k), { Transparency = 0.82, Size = Vector3.new(160, 1.6, 1.6) }):Play()
			-- onda de luz no chao
			local ring = P({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2, 2), Color = Color3.fromRGB(255, 245, 200), Material = Enum.Material.Neon, Transparency = 0.15, CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			TweenService:Create(ring, TweenInfo.new(0.7 * k, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }):Play()
			Debris:AddItem(ring, 0.8 * k)
			sparkBurst(ground + side + Vector3.new(0, 4.5, 0), 25, false)
		end
		if not feathered and t >= appear + 0.2 * k then
			feathered = true
			-- penas caindo
			for _ = 1, 12 do
				local start = ground + Vector3.new(math.random(-50, 50) / 10, math.random(55, 85) / 10, math.random(-50, 50) / 10)
				local f = P({ Name = "Pena", Size = Vector3.new(0.12, 0.05, 0.7), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) })
				local dur = (1.4 + math.random() * 0.8) * k
				TweenService:Create(f, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(start - Vector3.new(math.random(-20, 20) / 10, 4.5, math.random(-20, 20) / 10)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
					Transparency = 1,
				}):Play()
				Debris:AddItem(f, dur + 0.1)
			end
		end
		if not vanished and t >= total - 0.35 * k then
			vanished = true
			sparkBurst(pos, 40, false)
			rise.Enabled = false
			TweenService:Create(beam, TweenInfo.new(0.35 * k), { Transparency = 1, Size = Vector3.new(160, 0.2, 0.2) }):Play()
		end
		if t >= total then
			conn:Disconnect()
			m:Destroy()
			beam:Destroy()
			Debris:AddItem(disc, 1.7)
		end
	end)
end

remotes.Efeito.OnClientEvent:Connect(function(kind, who, ground, k)
	if kind == "Godrity" and typeof(ground) == "Vector3" then
		godrity(who, ground, typeof(k) == "number" and k or 1)
		if who == player then render(nil) end
	end
end)
