-- [CharacterService] Todos os jogadores nascem em R6 (com a aparencia do proprio avatar).
-- Players.CharacterAutoLoads fica desligado; este servico cria e recria o personagem.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local CharacterService = {}
local descCache = {}
local RESPAWN = 4

local function log(...) print("[CharacterService]", ...) end

-- Jogador no laboratorio (EmJogo ~= true) nasce no SpawnLobby; na missao, no SpawnJogadores.
local function lobbyCFrame()
	local lab = workspace:FindFirstChild("LaboratorioVerity")
	local pad = lab and lab:FindFirstChild("SpawnLobby")
	if pad then
		local pos = pad.Position + Vector3.new(math.random(-2, 2), 3.5, math.random(-2, 2))
		return CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
	end
end

local function spawnCFrame(player)
	if player and player:GetAttribute("EmJogo") ~= true then
		local cf = lobbyCFrame()
		if cf then return cf end
	end
	local best = workspace:FindFirstChild("SpawnJogadores", true)
	if not best or not best:IsA("BasePart") then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("SpawnLocation") and d.Enabled then best = d break end
		end
	end
	if best then
		local off = Vector3.new(math.random(-2, 2), best.Size.Y / 2 + 3, math.random(-2, 2))
		return CFrame.new(best.Position + off) -- olhando para -Z (para o Nucleo)
	end
	return CFrame.new(0, 50, 0)
end

local function getDescription(player)
	if descCache[player] then return descCache[player]:Clone() end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
	end)
	if not ok or not desc then desc = Instance.new("HumanoidDescription") end
	descCache[player] = desc
	return desc:Clone()
end

function CharacterService:Spawn(player, cframe)
	if not player.Parent then return end
	local old = player.Character
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(getDescription(player), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[CharacterService] Falha ao criar R6: " .. tostring(model))
		return
	end
	model.Name = player.Name
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	for _, s in ipairs(StarterPlayer:WaitForChild("StarterCharacterScripts"):GetChildren()) do
		s:Clone().Parent = model
	end
	model:PivotTo(cframe or spawnCFrame(player))
	player.Character = model
	model.Parent = workspace
	if old and old ~= model then old:Destroy() end
	hum.Died:Connect(function()
		-- o ReviveService decide (painel de morte / Godrity); se nao tratar, renasce sozinho
		if self.HandleDeath and self.HandleDeath(player, model) then return end
		task.delay(RESPAWN, function()
			if player.Parent and player.Character == model then
				self:Spawn(player)
			end
		end)
	end)
	return model
end

function CharacterService:Respawn(player)
	return self:Spawn(player)
end

function CharacterService:SpawnCFrame()
	return spawnCFrame()
end

function CharacterService:Init()
	Players.CharacterAutoLoads = false
end

function CharacterService:Start()
	local function onPlayer(player)
		-- nesta place todo mundo esta na missao (o lobby agora e a place Main Lobby)
		player:SetAttribute("EmJogo", true)
		task.spawn(function() self:Spawn(player) end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if not p.Character then onPlayer(p) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p) descCache[p] = nil end)
	log("Pronto (R6)")
end

return CharacterService
