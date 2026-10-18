-- [CorridaCliente] Segure SHIFT (ou o botao CORRER no celular) para correr.
-- A stamina e do servidor (atributos Stamina/StaminaMax/Correndo/Cansado no jogador);
-- aqui so pedimos para correr e desenhamos a barra (some sozinha quando esta cheia).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local correr = remotes:WaitForChild("Correr")

local quer = false
local function want(on)
	if quer == on then return end
	quer = on
	correr:FireServer(on)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		want(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		want(false)
	end
end)
UserInputService.WindowFocusReleased:Connect(function() want(false) end)

-- BARRA -----------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Stamina"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local back = Instance.new("Frame")
back.AnchorPoint = Vector2.new(0.5, 1)
back.Position = UDim2.new(0.5, 0, 1, -152)
back.Size = UDim2.fromOffset(180, 9)
back.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
back.BackgroundTransparency = 0.35
back.BorderSizePixel = 0
back.Parent = gui
Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(10, 10, 14); stroke.Thickness = 1.5; stroke.Parent = back
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Color3.fromRGB(120, 230, 120)
fill.BorderSizePixel = 0
fill.Parent = back
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
-- fade: anima a transparencia de cada parte (a barra comeca escondida)
local fade = Instance.new("NumberValue")
fade.Value = 1
local function applyFade()
	local a = fade.Value
	back.BackgroundTransparency = 0.35 + 0.65 * a
	fill.BackgroundTransparency = a
	stroke.Transparency = a
	back.Visible = a < 0.99
end
fade.Changed:Connect(applyFade)
applyFade()

-- botao para celular
if UserInputService.TouchEnabled then
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -110, 1, -200)
	b.Size = UDim2.fromOffset(72, 72)
	b.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
	b.BackgroundTransparency = 0.25
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = "CORRER"
	b.Parent = gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = b
	b.MouseButton1Click:Connect(function()
		want(not quer)
		b.BackgroundColor3 = quer and Color3.fromRGB(70, 140, 70) or Color3.fromRGB(30, 34, 42)
	end)
end

local shown = false
RunService.RenderStepped:Connect(function(dt)
	local max = player:GetAttribute("StaminaMax") or 100
	local s = player:GetAttribute("Stamina") or max
	local k = math.clamp(s / math.max(max, 1), 0, 1)
	local cansado = player:GetAttribute("Cansado") == true
	local running = player:GetAttribute("Correndo") == true
	fill.Size = fill.Size:Lerp(UDim2.fromScale(k, 1), math.min(1, dt * 12))
	fill.BackgroundColor3 = cansado and Color3.fromRGB(230, 90, 80) or Color3.fromRGB(120, 230, 120):Lerp(Color3.fromRGB(240, 200, 70), 1 - k)
	local want = k < 0.995 or running
	if want ~= shown then
		shown = want
		TweenService:Create(fade, TweenInfo.new(want and 0.15 or 0.6), { Value = want and 0 or 1 }):Play()
	end
end)
