-- [BuildCliente] Modo de construcao: fantasma verde/vermelho, grade de 2 studs, R gira,
-- clique coloca, Q sai. Botoes na tela para celular. O servidor revalida tudo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared:WaitForChild("Config"):WaitForChild("Shop"))
local estado = Shared:WaitForChild("EstadoJogo")
local Custos = require(Shared:WaitForChild("Custos"))
local remotes = Shared:WaitForChild("Remotes")
local C = Shop.Construcao
local SONS = require(Shared.Config:WaitForChild("Sons"))
local function sfx(def)
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.V or 0.5
	s.PlaybackSpeed = def.P or 1
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 3)
end
local lastWhy = nil

local startEvent = Instance.new("BindableEvent")
startEvent.Name = "IniciarConstrucao"
startEvent.Parent = script

local currentKey, rot = nil, 0
local ghost, ghostBox, ring
local valid, lastCF = false, nil
local hint

-- centro do Nucleo no chao: MESMA regra do CoreService (base do modelo), para o fantasma
-- nao marcar "Terreno invalido" quando o Nucleo muda de escala/posicao
local cachedCore, cachedPos
local function corePos()
	local core = CollectionService:GetTagged("Nucleo")[1]
	local esf = core and core:FindFirstChild("NucleoEsfera")
	if not esf then return Vector3.zero end
	if core ~= cachedCore or not cachedPos then
		local bcf, bsz = core:GetBoundingBox()
		cachedCore = core
		cachedPos = Vector3.new(esf.Position.X, bcf.Position.Y - bsz.Y / 2, esf.Position.Z)
	end
	return cachedPos
end
CollectionService:GetInstanceAddedSignal("Nucleo"):Connect(function() cachedPos = nil end)

local function makeHint()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DicaConstrucao"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.Position = UDim2.new(0.5, 0, 1, -100)
	t.Size = UDim2.fromOffset(640, 70)
	t.BackgroundColor3 = Color3.fromRGB(38, 32, 52)
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextSize = 22
	t.TextWrapped = true
	t.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = t
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Color = Color3.fromRGB(18, 14, 26); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = t
	return gui, t
end

local function makeRing(center)
	local m = Instance.new("Model")
	m.Name = "AnelConstrucao"
	for _, r in ipairs({ C.RaioConstrucao, C.RaioMinimoNucleo }) do
		local n = math.floor(r * 0.8)
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			local p = Instance.new("Part")
			p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = r == C.RaioConstrucao and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 120, 120)
			p.Transparency = 0.35
			p.Size = Vector3.new(0.4, 0.15, (2 * math.pi * r / n) * 0.6)
			p.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, 0.25, math.sin(a) * r)) * CFrame.Angles(0, -a, 0)
			p.Parent = m
		end
	end
	m.Parent = workspace.CurrentCamera
	return m
end

local function stop()
	currentKey = nil
	player:SetAttribute("Construindo", false)
	if ghost then ghost:Destroy(); ghost = nil end
	if ring then ring:Destroy(); ring = nil end
	if hint then hint:Destroy(); hint = nil end
	ContextActionService:UnbindAction("ColocarEstrutura")
	ContextActionService:UnbindAction("GirarEstrutura")
	ContextActionService:UnbindAction("SairConstrucao")
end

local function aimRay()
	local cam = workspace.CurrentCamera
	local pos
	if UserInputService.MouseEnabled then
		pos = UserInputService:GetMouseLocation()
	else
		pos = cam.ViewportSize / 2 + Vector2.new(0, cam.ViewportSize.Y * 0.1)
	end
	return cam:ViewportPointToRay(pos.X, pos.Y)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true
local overlap2 = OverlapParams.new()
overlap2.FilterType = Enum.RaycastFilterType.Include

local function update()
	if not currentKey or not ghost then return end
	local ic = Shop.Estruturas[currentKey]
	local ignore = { ghost, workspace.CurrentCamera, workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Efeitos"), workspace:FindFirstChild("Estruturas") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rayParams.FilterDescendantsInstances = ignore
	local ray = aimRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, rayParams)
	if not hit then ghost.Parent = nil return end
	ghost.Parent = workspace.CurrentCamera
	local g = C.Grade
	local x = math.floor(hit.Position.X / g + 0.5) * g
	local z = math.floor(hit.Position.Z / g + 0.5) * g
	local cp = corePos()
	local cf = CFrame.new(x, hit.Position.Y, z) * CFrame.Angles(0, rot * math.pi / 2, 0)
	local s = ic.Tamanho
	ghostBox.CFrame = cf * CFrame.new(0, s.Y / 2, 0)
	local why
	local d = (Vector3.new(x, 0, z) - Vector3.new(cp.X, 0, cp.Z)).Magnitude
	if d > C.RaioConstrucao then why = "Longe demais do Núcleo"
	elseif d < C.RaioMinimoNucleo then why = "Perto demais do Núcleo"
	elseif math.abs(hit.Position.Y - cp.Y) > 1.5 then why = "Terreno inválido"
	elseif (estado:GetAttribute("CoreTier") or 1) < ic.TierMin then why = "Exige Núcleo tier " .. ic.TierMin
	elseif not Custos.Tem(estado, ic.Custo) then why = Custos.Falta(estado, ic.Custo)
	else
		overlap.FilterDescendantsInstances = { ghost, workspace:FindFirstChild("InimigosAtivos"), workspace:FindFirstChild("Moedas"), workspace:FindFirstChild("Efeitos") }
		local boxCF = cf * CFrame.new(0, s.Y / 2 + 0.3, 0)
		local boxSize = Vector3.new(math.max(0.5, s.X - 0.4), math.max(0.5, s.Y - 0.6), math.max(0.5, s.Z - 0.4))
		if #workspace:GetPartBoundsInBox(boxCF, boxSize, overlap) > 0 then why = "Espaço ocupado" end
		overlap2.FilterDescendantsInstances = { workspace:FindFirstChild("Estruturas") }
		if not why and #workspace:GetPartBoundsInBox(boxCF, boxSize, overlap2) > 0 then why = "Espaço ocupado" end
	end
	valid = why == nil
	lastCF = cf
	ghostBox.Color = valid and Color3.fromRGB(80, 255, 110) or Color3.fromRGB(255, 70, 70)
	ghostBox.SelectionBox.Color3 = ghostBox.Color
	if hint then
		hint.Text = ic.Nome .. " · " .. Custos.Texto(ic.Custo) .. (why and ("  —  " .. why) or "") .. "\n" ..
			(UserInputService.TouchEnabled and not UserInputService.MouseEnabled and "COLOCAR · GIRAR · SAIR (botões)" or "Clique: colocar  ·  R: girar  ·  Q: sair")
		hint.TextColor3 = valid and Color3.new(1, 1, 1) or Color3.fromRGB(255, 160, 160)
	end
end

local function start(key)
	stop()
	-- guarda a arma/martelo na mao para nao disparar enquanto constroi
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
	local ic = Shop.Estruturas[key]
	if not ic then return end
	currentKey = key
	player:SetAttribute("Construindo", true)
	ghost = Instance.new("Model")
	ghost.Name = "Fantasma"
	ghostBox = Instance.new("Part")
	ghostBox.Anchored = true; ghostBox.CanCollide = false; ghostBox.CanQuery = false; ghostBox.CanTouch = false; ghostBox.CastShadow = false
	ghostBox.Size = ic.Tamanho
	ghostBox.Material = Enum.Material.Neon
	ghostBox.Transparency = 0.6
	ghostBox.Parent = ghost
	local sb = Instance.new("SelectionBox")
	sb.Adornee = ghostBox
	sb.LineThickness = 0.08
	sb.Parent = ghostBox
	-- seta indicando a frente
	local arrow = Instance.new("Part")
	arrow.Anchored = true; arrow.CanCollide = false; arrow.CanQuery = false; arrow.CanTouch = false
	arrow.Size = Vector3.new(0.6, 0.2, 2)
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.new(1, 1, 1)
	arrow.Name = "Seta"
	arrow.Parent = ghost
	ghost.PrimaryPart = ghostBox
	ghost.Parent = workspace.CurrentCamera
	cachedPos = nil
	ring = makeRing(corePos())
	local g; g, hint = makeHint()
	hint = hint
	local gui = g
	hint.Destroying:Connect(function() if gui then gui:Destroy() end end)
	hint.AncestryChanged:Connect(function() end)
	ContextActionService:BindActionAtPriority("ColocarEstrutura", function(_, state)
		if state == Enum.UserInputState.Begin then
			if valid and lastCF and currentKey then
				remotes.Construir:FireServer(currentKey, lastCF)
			elseif currentKey then
				sfx(SONS.UIErro)
				if hint then
					local sc = hint:FindFirstChild("Tremer") or Instance.new("UIScale")
					sc.Name = "Tremer"; sc.Parent = hint; sc.Scale = 1.08
					game:GetService("TweenService"):Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, 3000, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("ColocarEstrutura", "COLOCAR")
	ContextActionService:SetPosition("ColocarEstrutura", UDim2.new(1, -150, 1, -150))
	ContextActionService:BindActionAtPriority("GirarEstrutura", function(_, state)
		if state == Enum.UserInputState.Begin then rot = (rot + 1) % 4; sfx(SONS.Girar) end
		return Enum.ContextActionResult.Sink
	end, true, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("GirarEstrutura", "GIRAR")
	ContextActionService:SetPosition("GirarEstrutura", UDim2.new(1, -230, 1, -60))
	ContextActionService:BindActionAtPriority("SairConstrucao", function(_, state)
		if state == Enum.UserInputState.Begin then stop() end
		return Enum.ContextActionResult.Sink
	end, true, 3000, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("SairConstrucao", "SAIR")
	ContextActionService:SetPosition("SairConstrucao", UDim2.new(1, -90, 1, -230))
end

startEvent.Event:Connect(start)

RunService.RenderStepped:Connect(function()
	if currentKey then
		update()
		if ghost and ghostBox and ghost:FindFirstChild("Seta") then
			ghost.Seta.CFrame = ghostBox.CFrame * CFrame.new(0, ghostBox.Size.Y / 2 + 0.3, -ghostBox.Size.Z / 2 - 1.2)
		end
	end
end)

-- sai do modo ao trocar de item: teclas 1-9 (hotbar) ou ao equipar qualquer ferramenta
local SLOT_KEYS = {
	[Enum.KeyCode.One] = true, [Enum.KeyCode.Two] = true, [Enum.KeyCode.Three] = true, [Enum.KeyCode.Four] = true, [Enum.KeyCode.Five] = true,
	[Enum.KeyCode.Six] = true, [Enum.KeyCode.Seven] = true, [Enum.KeyCode.Eight] = true, [Enum.KeyCode.Nine] = true,
	[Enum.KeyCode.KeypadOne] = true, [Enum.KeyCode.KeypadTwo] = true, [Enum.KeyCode.KeypadThree] = true,
	[Enum.KeyCode.ButtonL1] = true, [Enum.KeyCode.ButtonR1] = true,
}
UserInputService.InputBegan:Connect(function(input)
	if currentKey and SLOT_KEYS[input.KeyCode] and not UserInputService:GetFocusedTextBox() then stop() end
end)
local function watchTools(char)
	char.ChildAdded:Connect(function(ch)
		if currentKey and ch:IsA("Tool") then stop() end
	end)
end
if player.Character then watchTools(player.Character) end
player.CharacterAdded:Connect(watchTools)

-- sai do modo ao morrer ou na derrota
player.CharacterAdded:Connect(stop)
estado:GetAttributeChangedSignal("Fase"):Connect(function()
	if estado:GetAttribute("Fase") == "Derrota" then stop() end
end)
