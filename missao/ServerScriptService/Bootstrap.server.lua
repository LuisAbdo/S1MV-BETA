-- [Bootstrap] Inicia todos os servicos em ordem: Init() de todos, depois Start().
local ServerScriptService = game:GetService("ServerScriptService")
local servicesFolder = ServerScriptService:WaitForChild("Services")

-- Ordem de inicializacao (novos servicos entram aqui nas proximas etapas)
local ORDER = {
	"CharacterService",
	"ReceiptService",
	"AreaService",
	"RescueService",
	"EconomyService",
	"CoreService",
	"ChunkService",
	"ColetaService",
	"MercadorService",
	"EnemyService",
	"BuildService",
	"AllyService",
	"ClassService",
	"WeaponService",
	"CorridaService",
	"WaveService",
	"VerityBossService",
	"GlitcityService",
	"LobbyService",
	"ReviveService",
	"CuriosityService",
}

local loaded = {}
for _, name in ipairs(ORDER) do
	local module = servicesFolder:FindFirstChild(name)
	if module then
		local ok, result = pcall(require, module)
		if ok then
			loaded[name] = result
		else
			warn("[Bootstrap] Falha ao carregar " .. name .. ": " .. tostring(result))
		end
	else
		warn("[Bootstrap] Servico ausente: " .. name)
	end
end

for _, name in ipairs(ORDER) do
	local s = loaded[name]
	if s and s.Init then
		local ok, err = pcall(s.Init, s)
		if not ok then warn("[Bootstrap] Init falhou em " .. name .. ": " .. tostring(err)) end
	end
end

for _, name in ipairs(ORDER) do
	local s = loaded[name]
	if s and s.Start then
		task.spawn(function()
			local ok, err = pcall(s.Start, s)
			if not ok then warn("[Bootstrap] Start falhou em " .. name .. ": " .. tostring(err)) end
		end)
	end
end

print("[Bootstrap] Servicos iniciados: " .. table.concat(ORDER, ", "))
