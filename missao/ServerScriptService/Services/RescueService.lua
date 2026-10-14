-- [RescueService] Quem cai na agua volta ao ultimo chao firme (ou ao spawn).
-- Evita jogador preso no fundo e impede atravessar nadando ate areas trancadas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Areas"))

local RescueService = {}
local lastSafe = {}
local inWaterSince = {}

local function spawnCFrame()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then return d.CFrame + Vector3.new(0, 4, 0) end
	end
	return CFrame.new(0, 50, 0)
end

function RescueService:Init() end

function RescueService:Start()
	local cfg = Config.Resgate
	local acc = 0
	-- um unico Heartbeat para todos os jogadores
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local record = acc >= cfg.IntervaloRegistro
		if record then acc = 0 end
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local y = root.Position.Y
				if y < cfg.AlturaAgua then
					inWaterSince[player] = inWaterSince[player] or os.clock()
					if os.clock() - inWaterSince[player] >= cfg.Atraso then
						inWaterSince[player] = nil
						local target = lastSafe[player] or spawnCFrame()
						root.AssemblyLinearVelocity = Vector3.zero
						char:PivotTo(target)
						print("[RescueService] " .. player.Name .. " resgatado da agua")
					end
				else
					inWaterSince[player] = nil
					if record and hum.FloorMaterial ~= Enum.Material.Air and y > cfg.AlturaAgua + 6 then
						lastSafe[player] = CFrame.new(root.Position + Vector3.new(0, 2, 0))
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastSafe[p] = nil
		inWaterSince[p] = nil
	end)
	print("[RescueService] Pronto")
end

return RescueService
