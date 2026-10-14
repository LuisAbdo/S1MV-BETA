-- [AreasCliente] Nevoa local, banner de nova area e panoramica curta (pulavel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Areas"))
local estado = Shared:WaitForChild("EstadoAreas")
local remote = Shared:WaitForChild("Remotes"):WaitForChild("AreaDesbloqueada")

-- NEVOA ------------------------------------------------------------
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then
	atm = Instance.new("Atmosphere")
	atm.Parent = Lighting
end
local fogTween

local function applyFog(instant)
	local N = Config.Nevoa
	local count = 0
	for _, name in ipairs(Config.Ordem) do
		if name ~= "ArenaFinal" and estado:GetAttribute(name) then count += 1 end
	end
	local idx = math.clamp(count + 1, 1, #N.Densidade)
	local goal = {
		Density = N.Densidade[idx],
		Haze = N.Haze[idx],
		Color = N.Cor,
		Offset = N.Deslocamento,
	}
	if estado:GetAttribute("ArenaFinal") then
		goal.Density = N.DensidadeArena
		goal.Haze = N.HazeArena
		goal.Color = N.CorArena
	end
	if fogTween then fogTween:Cancel() end
	if instant then
		for k, v in pairs(goal) do atm[k] = v end
	else
		fogTween = TweenService:Create(atm, TweenInfo.new(N.TempoTransicao, Enum.EasingStyle.Sine), goal)
		fogTween:Play()
	end
end

applyFog(true)
for _, name in ipairs(Config.Ordem) do
	estado:GetAttributeChangedSignal(name):Connect(function() applyFog(false) end)
end

-- BANNER -----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BannerAreas"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local scale = Instance.new("UIScale")
scale.Parent = gui
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then
		scale.Scale = math.clamp(cam.ViewportSize.X / 1280, 0.6, 1.25)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local frame = Instance.new("Frame")
frame.Name = "Banner"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, -200)
frame.Size = UDim2.fromOffset(560, 120)
frame.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
frame.Visible = false
frame.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 16); corner.Parent = frame
local stroke = Instance.new("UIStroke"); stroke.Thickness = 5; stroke.Color = Color3.fromRGB(60, 35, 20); stroke.Parent = frame

local top = Instance.new("TextLabel")
top.Name = "Titulo"
top.BackgroundTransparency = 1
top.Size = UDim2.new(1, 0, 0, 40)
top.Position = UDim2.fromOffset(0, 10)
top.Font = Enum.Font.FredokaOne
top.TextSize = 30
top.TextColor3 = Color3.fromRGB(255, 255, 255)
top.Text = "NOVA ÁREA!"
top.Parent = frame
local s1 = Instance.new("UIStroke"); s1.Thickness = 3; s1.Color = Color3.fromRGB(60, 35, 20); s1.Parent = top

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "Nome"
nameLabel.BackgroundTransparency = 1
nameLabel.Size = UDim2.new(1, -30, 0, 54)
nameLabel.Position = UDim2.fromOffset(15, 52)
nameLabel.Font = Enum.Font.FredokaOne
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(60, 35, 20)
nameLabel.Parent = frame

local fanfare = Instance.new("Sound")
fanfare.SoundId = "rbxassetid://122399158411452"
fanfare.Volume = 0.7
fanfare.Parent = SoundService

local bannerToken = 0
local function showBanner(text)
	bannerToken += 1
	local my = bannerToken
	nameLabel.Text = text
	frame.Visible = true
	frame.Position = UDim2.new(0.5, 0, 0, -200)
	fanfare:Play()
	TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	task.delay(Config.Animacao.DuracaoBanner, function()
		if my ~= bannerToken then return end
		local t = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -200) })
		t:Play()
		t.Completed:Wait()
		if my == bannerToken then frame.Visible = false end
	end)
end

-- PANORAMICA (3 s, nao trava o jogo, pula com qualquer tecla/toque) --
local panning = false
local function panorama(anchorPos)
	if panning or not Config.Animacao.Panorama then return end
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not cam or not root then return end
	panning = true
	local original = cam.CFrame
	local fromDir = (root.Position - anchorPos) * Vector3.new(1, 0, 1)
	if fromDir.Magnitude < 1 then fromDir = Vector3.new(1, 0, 1) end
	local camPos = anchorPos + fromDir.Unit * 55 + Vector3.new(0, 35, 0)
	local target = CFrame.lookAt(camPos, anchorPos)
	local skipped = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Gamepad1 then
			skipped = true
		end
	end)
	local ok, err = pcall(function()
		cam:SetAttribute("Panorama", true)
		cam.CameraType = Enum.CameraType.Scriptable
		local dur = Config.Animacao.DuracaoPanorama
		local t1 = TweenService:Create(cam, TweenInfo.new(dur * 0.4, Enum.EasingStyle.Sine), { CFrame = target })
		t1:Play()
		local elapsed = 0
		while elapsed < dur * 0.75 and not skipped do
			elapsed += task.wait()
		end
		t1:Cancel()
		if not skipped then
			local t2 = TweenService:Create(cam, TweenInfo.new(dur * 0.25, Enum.EasingStyle.Sine), { CFrame = original })
			t2:Play()
			local e2 = 0
			while e2 < dur * 0.25 and not skipped do e2 += task.wait() end
		end
	end)
	conn:Disconnect()
	cam.CameraType = Enum.CameraType.Custom
	cam:SetAttribute("Panorama", false)
	panning = false
	if not ok then warn("[AreasCliente] Panoramica falhou: " .. tostring(err)) end
end

remote.OnClientEvent:Connect(function(name, displayName, anchorPos, instant)
	if instant then return end
	showBanner(displayName or name)
	if typeof(anchorPos) == "Vector3" then
		task.spawn(panorama, anchorPos)
	end
end)
