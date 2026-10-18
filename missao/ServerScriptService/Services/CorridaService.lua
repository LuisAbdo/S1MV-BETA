-- [CorridaService] Correr com Shift gastando stamina. A stamina e calculada AQUI (servidor):
-- o cliente so avisa se quer correr (remote "Correr") e mostra a barra pelo atributo "Stamina".
-- A velocidade em si e aplicada pelo WeaponService:RefreshSpeed (atributo "Correndo").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Sobrevivencia).Corrida

local CorridaService = {}
local remotes, Weapon
local st = {}   -- player -> { quer, stamina, cansado, ultimaCorrida }

local function stateOf(p)
	local s = st[p]
	if not s then
		s = { quer = false, stamina = Cfg.Maxima, cansado = false, ultima = 0 }
		st[p] = s
	end
	return s
end

local function setRunning(p, on)
	if (p:GetAttribute("Correndo") == true) == on then return end
	p:SetAttribute("Correndo", on)
	Weapon:RefreshSpeed(p)
end

function CorridaService:Init()
	remotes = Shared:WaitForChild("Remotes")
	if not remotes:FindFirstChild("Correr") then
		local r = Instance.new("RemoteEvent"); r.Name = "Correr"; r.Parent = remotes
	end
	Weapon = require(script.Parent.WeaponService)
end

function CorridaService:Start()
	remotes.Correr.OnServerEvent:Connect(function(p, quer)
		if typeof(quer) ~= "boolean" then return end
		stateOf(p).quer = quer
	end)
	local function setup(p)
		local s = stateOf(p)
		s.stamina = Cfg.Maxima; s.cansado = false; s.quer = false
		p:SetAttribute("Stamina", Cfg.Maxima)
		p:SetAttribute("StaminaMax", Cfg.Maxima)
		p:SetAttribute("Correndo", false)
		p.CharacterAdded:Connect(function()
			s.stamina = Cfg.Maxima; s.cansado = false; s.quer = false
			p:SetAttribute("Correndo", false)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do setup(p) end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(p) st[p] = nil end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		dt, acc = acc, 0
		local now = os.clock()
		for p, s in pairs(st) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local moving = hum and hum.Health > 0 and hum.MoveDirection.Magnitude > 0.1
			local stunned = hum and (hum:GetAttribute("AtordoadoAte") or 0) > now
			local run = s.quer and moving and not stunned and not s.cansado and s.stamina > 0
			if run then
				s.stamina = math.max(0, s.stamina - Cfg.Gasto * dt)
				s.ultima = now
				if s.stamina <= 0 then s.cansado = true; run = false end
			elseif now - s.ultima >= Cfg.AtrasoRecuperar then
				s.stamina = math.min(Cfg.Maxima, s.stamina + Cfg.Recupera * dt)
				if s.cansado and s.stamina >= Cfg.MinimoVoltar then s.cansado = false end
			end
			if hum then setRunning(p, run) end
			local shown = math.floor(s.stamina + 0.5)
			if p:GetAttribute("Stamina") ~= shown then p:SetAttribute("Stamina", shown) end
			if p:GetAttribute("Cansado") ~= s.cansado then p:SetAttribute("Cansado", s.cansado) end
		end
	end)
	print("[CorridaService] Pronto")
end

return CorridaService
