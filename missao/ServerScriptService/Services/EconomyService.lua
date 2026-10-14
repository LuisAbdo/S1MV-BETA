-- [EconomyService] Moedas da run (servidor e autoridade). Orbes com ima.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WavesCfg = require(Shared.Config.Waves)

local EconomyService = {}
local orbs = {}
local folder
local IMA = 12
local VIDA_ORBE = 45
local rng = Random.new()

local function setCoins(player, v)
	player:SetAttribute("Moedas", v)
	local ls = player:FindFirstChild("leaderstats")
	local m = ls and ls:FindFirstChild("Moedas")
	if m then m.Value = v end
end

function EconomyService:Get(player)
	return player:GetAttribute("Moedas") or 0
end

function EconomyService:Add(player, amount)
	amount = math.floor(amount + 0.5)
	if amount <= 0 then return end
	setCoins(player, self:Get(player) + amount)
end

function EconomyService:Spend(player, amount)
	if typeof(amount) ~= "number" or amount < 0 then return false end
	local v = self:Get(player)
	if v < amount then return false end
	setCoins(player, v - amount)
	return true
end

function EconomyService:Set(player, amount)
	setCoins(player, math.max(0, math.floor(amount)))
end

function EconomyService:CoopMultiplier()
	return 1 + WavesCfg.BonusCoopPorJogador * math.max(0, #Players:GetPlayers() - 1)
end

function EconomyService:ClearOrbs()
	for orb in pairs(orbs) do orb:Destroy() end
	orbs = {}
end

-- Solta moedas em orbes no chao (groundPos = ponto no chao)
function EconomyService:DropCoins(groundPos, total)
	total = math.floor(total * self:CoopMultiplier() + 0.5)
	if total <= 0 then return end
	local n = math.clamp(math.ceil(total / 6), 1, 5)
	local per = math.floor(total / n)
	local extra = total - per * n
	for i = 1, n do
		local value = per + (i == 1 and extra or 0)
		local p = Instance.new("Part")
		p.Name = "Moeda"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.3, 1.3, 1.3)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 200, 40)
		p.Anchored = true
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.CastShadow = false
		p.Position = groundPos + Vector3.new(0, 2.5, 0)
		p.Parent = folder
		local target = groundPos + Vector3.new(rng:NextNumber(-3.5, 3.5), 0.9, rng:NextNumber(-3.5, 3.5))
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target }):Play()
		orbs[p] = { value = value, born = os.clock() }
	end
end

function EconomyService:Init()
	folder = workspace:FindFirstChild("Moedas")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Moedas"
		folder.Parent = workspace
	end
end

function EconomyService:Start()
	local function onPlayer(player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local m = Instance.new("IntValue")
		m.Name = "Moedas"
		m.Parent = ls
		ls.Parent = player
		setCoins(player, 0)
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		local now = os.clock()
		local roots = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then table.insert(roots, { pl, root }) end
		end
		for orb, info in pairs(orbs) do
			if now - info.born > VIDA_ORBE then
				orbs[orb] = nil
				orb:Destroy()
			elseif now - info.born > 0.5 then
				for _, r in ipairs(roots) do
					if (r[2].Position - orb.Position).Magnitude <= IMA then
						orbs[orb] = nil
						self:Add(r[1], info.value)
						local t = TweenService:Create(orb, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = r[2].Position, Size = Vector3.new(0.4, 0.4, 0.4) })
						t:Play()
						t.Completed:Connect(function() orb:Destroy() end)
						break
					end
				end
			end
		end
	end)
	print("[EconomyService] Pronto")
end

return EconomyService
