local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

----------------------------------------------------------
-- CONFIGURACAO
----------------------------------------------------------

local CONFIG = {
	ZoneName = "Zona de spawn",
	TemplateFolder = "Inimigos",

	RespawnDelay = 5,
	MinSpawnSeparation = 12,
	ZoneMargin = 4,

	MaxSpawnAttempts = 40,
}

----------------------------------------------------------
-- MODELOS DOS INIMIGOS
----------------------------------------------------------
-- O caminho pode ser uma pasta/modelo aninhado.
-- O spawner tambem aceita os modelos com nomes diretos
-- caso voce tenha organizado a pasta de outra maneira.

local ENEMIES = {
	{
		template = "Meshes/Hollow Ball",
		alternatives = {"Verity"},
		name = "Verity",
		health = 100,
		hopSpeed = 26,
		damage = 10,
		cooldown = 1.0,
	},

	{
		template = "Falsity",
		name = "Falsity",
		health = 120,
		hopSpeed = 24,
		damage = 12,
		cooldown = 1.1,
	},

	{
		template = "Cruelty",
		name = "Cruelty",
		health = 150,
		hopSpeed = 22,
		damage = 15,
		cooldown = 1.2,
	},
}

----------------------------------------------------------
-- REFERENCIAS
----------------------------------------------------------

local zone = workspace:WaitForChild(CONFIG.ZoneName)
local templates = ServerStorage:WaitForChild(CONFIG.TemplateFolder)

local activeFolder = workspace:FindFirstChild("InimigosAtivos")

if not activeFolder then
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "InimigosAtivos"
	activeFolder.Parent = workspace
end

local rng = Random.new()

-- Impede respawns duplicados da mesma definicao.
local spawning = {}

----------------------------------------------------------
-- ENCONTRAR MODELO PELO CAMINHO
----------------------------------------------------------

local function findByPath(root, path)
	local current = root

	for part in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(part)

		if not current then
			return nil
		end
	end

	return current
end

local function findTemplate(def)
	local template = findByPath(templates, def.template)

	if template and template:IsA("Model") then
		return template
	end

	for _, alternative in ipairs(def.alternatives or {}) do
		local candidate = findByPath(templates, alternative)

		if candidate and candidate:IsA("Model") then
			return candidate
		end
	end

	-- Procura diretamente pelo nome configurado.
	local direct = templates:FindFirstChild(def.name)

	if direct and direct:IsA("Model") then
		return direct
	end

	return nil
end

----------------------------------------------------------
-- FILTRO DE RAYCAST
----------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function refreshFilter()
	local excluded = {
		zone,
		activeFolder,
	}

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end

	rayParams.FilterDescendantsInstances = excluded
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

----------------------------------------------------------
-- POSICOES DOS INIMIGOS ATIVOS
----------------------------------------------------------

local function getEnemyPosition(model)
	local body = model:FindFirstChild("Corpo")

	if body and body:IsA("BasePart") then
		return body.Position
	end

	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end

	return model:GetPivot().Position
end

----------------------------------------------------------
-- POSICAO ALEATORIA DE SPAWN
----------------------------------------------------------

local function randomSpawnPoint()
	refreshFilter()

	local half = zone.Size / 2

	local rangeX = math.max(
		half.X - CONFIG.ZoneMargin,
		0
	)

	local rangeZ = math.max(
		half.Z - CONFIG.ZoneMargin,
		0
	)

	for attempt = 1, CONFIG.MaxSpawnAttempts do
		local localX = rng:NextNumber(-rangeX, rangeX)
		local localZ = rng:NextNumber(-rangeZ, rangeZ)

		local top = zone.CFrame:PointToWorldSpace(
			Vector3.new(localX, half.Y, localZ)
		)

		local hit = workspace:Raycast(
			top + Vector3.new(0, 60, 0),
			Vector3.new(0, -300, 0),
			rayParams
		)

		if hit then
			local point = hit.Position
			local free = true

			for _, other in ipairs(activeFolder:GetChildren()) do
				if other:IsA("Model") then
					local otherPosition = getEnemyPosition(other)

					if flat(point - otherPosition).Magnitude
						< CONFIG.MinSpawnSeparation then

						free = false
						break
					end
				end
			end

			if free then
				return point
			end
		end
	end

	warn(
		"[Spawner] Nao foi encontrada uma posicao livre. "
			.. "Verifique o tamanho da Zona de spawn."
	)

	return nil
end

----------------------------------------------------------
-- POSICIONAR O MODEL PELO CORPO
----------------------------------------------------------

local function positionModel(model, body, groundPosition)
	-- Posiciona a parte inferior do Corpo no chao.
	local targetBodyCFrame = CFrame.new(
		groundPosition + Vector3.new(0, body.Size.Y / 2, 0)
	)

	-- Preserva a posicao relativa das demais partes
	-- em relacao ao Corpo.
	local pivotOffset = body.CFrame:ToObjectSpace(
		model:GetPivot()
	)

	model:PivotTo(targetBodyCFrame * pivotOffset)
end

----------------------------------------------------------
-- APLICAR CONFIGURACAO AO HUMANOID
----------------------------------------------------------

local function configureEnemy(model, def)
	model.Name = def.name

	model:SetAttribute("Inimigo", true)
	model:SetAttribute("Tipo", def.name)

	-- Permite que a IA encontre o Corpo.
	local body = model:FindFirstChild("Corpo")

	if not body or not body:IsA("BasePart") then
		warn(
			"[Spawner] " .. def.name
				.. " precisa ter uma BasePart chamada Corpo."
		)

		return false
	end

	model.PrimaryPart = body

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		warn(
			"[Spawner] " .. def.name
				.. " precisa ter um Humanoid ou usar a IA fornecida."
		)

		return false
	end

	-- Os valores sao configurados aqui tambem para
	-- garantir a vida correta desde o nascimento.
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health

	-- A movimentacao continua sob controle da IA.
	body.Anchored = true
	body.CanCollide = false

	return true
end

----------------------------------------------------------
-- SPAWN E RESPAWN
----------------------------------------------------------

local spawnEnemy

spawnEnemy = function(def)
	if spawning[def] then
		return
	end

	spawning[def] = true

	local template = findTemplate(def)

	if not template then
		warn(
			"[Spawner] Modelo nao encontrado para "
				.. def.name
				.. ". Confira ServerStorage.Inimigos."
		)

		spawning[def] = nil
		return
	end

	local groundPosition = randomSpawnPoint()

	if not groundPosition then
		spawning[def] = nil
		return
	end

	local model = template:Clone()

	-- Mantem os Scripts que estao dentro do modelo.
	-- Nao destrua os LuaSourceContainer!
	local body = model:FindFirstChild("Corpo")

	if not body or not body:IsA("BasePart") then
		warn(
			"[Spawner] O template de "
				.. def.name
				.. " nao possui a peca Corpo."
		)

		model:Destroy()
		spawning[def] = nil
		return
	end

	if not configureEnemy(model, def) then
		model:Destroy()
		spawning[def] = nil
		return
	end

	positionModel(model, body, groundPosition)

	-- Parent somente depois de posicionar e configurar.
	model.Parent = activeFolder

	-- Libera o proximo spawn desta definicao.
	spawning[def] = nil

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local deathHandled = false

	humanoid.Died:Connect(function()
		if deathHandled then
			return
		end

		deathHandled = true

		task.delay(CONFIG.RespawnDelay, function()
			-- O modelo antigo pode ja ter sido destruido
			-- pelo Script de IA. Isso e esperado.
			if not spawning[def] then
				spawnEnemy(def)
			end
		end)
	end)

	print("[Spawner] " .. def.name .. " nasceu com sucesso.")
end

----------------------------------------------------------
-- INICIAR SISTEMA
----------------------------------------------------------

for _, def in ipairs(ENEMIES) do
	task.spawn(function()
		spawnEnemy(def)
	end)
end

print("[Spawner] Sistema de inimigos iniciado.")