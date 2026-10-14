-- Config/Lobby: MAIN LOBBY + perfil compartilhado com a place da missao.
-- MANTENHA ESTE MODULO IGUAL NAS DUAS PLACES (Main Lobby e Missao).
return {
	-- PLACES: as duas precisam estar na MESMA experiencia (grupo fechado + mesmo DataStore).
	-- Com ID = 0 o jogo procura a place pelo NOME.
	Lugares = {
		LobbyId = 0, LobbyNome = "Main Lobby",
		MissaoId = 0, MissaoNome = "Missao",
	},

	-- PERFIL ---------------------------------------------------------------------------------
	DataStore = "PerfilLab_v1",
	GemasIniciais = 350,
	GemasPorWave = 3,
	GemasChefe = 20,
	AutoSalvar = 60,

	-- NIVEL DA CONTA
	XPPorWave = 40,
	XPPorAbate = 2,
	XPNivel = function(nivel) return math.floor(250 * nivel ^ 1.35) end,
	Patentes = {
		{ 1, "RECRUTA" }, { 5, "SOLDADO" }, { 10, "CABO" }, { 15, "SARGENTO" }, { 20, "TENENTE" },
		{ 30, "CAPITÃO" }, { 40, "MAJOR" }, { 50, "CORONEL" }, { 75, "GENERAL" },
	},

	-- RARIDADES (cor e nome)
	Raridades = {
		Comum = { Nome = "COMUM", Cor = Color3.fromRGB(170, 176, 186) },
		Incomum = { Nome = "INCOMUM", Cor = Color3.fromRGB(90, 230, 120) },
		Raro = { Nome = "RARO", Cor = Color3.fromRGB(80, 180, 240) },
		Epico = { Nome = "ÉPICO", Cor = Color3.fromRGB(200, 90, 255) },
		Lendario = { Nome = "LENDÁRIO", Cor = Color3.fromRGB(255, 196, 50) },
	},

	-- ARMAS -------------------------------------------------------------------------------------
	-- Na missao voce comeca com os PUNHOS e a tecla V compra o proximo TIER.
	-- Em cada tier voce leva a arma que EQUIPOU aqui no lobby. Preco = gemas (0 = gratis).
	-- Bloqueada = so sai em recompensa diaria / pacote (nao da para comprar com gemas).
	ArmaInicial = "Punhos",
	Tiers = {
		{ Nome = "TIER 1", Armas = { "Pistola", "Estilingue", "Cano" } },
		{ Nome = "TIER 2", Armas = { "Rifle", "Machete" } },
		{ Nome = "TIER 3", Armas = { "LancaChamas", "LaminaDeEnergia" } },
		{ Nome = "TIER 4", Armas = { "MarteloDoTrovao", "LaminaDoNucleo" } },
	},
	Armas = {
		Punhos =          { Nome = "PUNHOS",            Item = "Punhos",          Tipo = "CORPO A CORPO", Raridade = "Comum",    Dano = 25,  Cadencia = 0.4,  Preco = 0 },
		Pistola =         { Nome = "PISTOLA",           Item = "Pistola",         Tipo = "PISTOLA",       Raridade = "Comum",    Dano = 40,  Cadencia = 0.34, Preco = 0 },
		Estilingue =      { Nome = "ESTILINGUE",        Item = "Estilingue",      Tipo = "ESTILINGUE",    Raridade = "Comum",    Dano = 30,  Cadencia = 0.5,  Preco = 0 },
		Cano =            { Nome = "CANO DE METAL",     Item = "Cano",            Tipo = "CORPO A CORPO", Raridade = "Incomum",  Dano = 75,  Cadencia = 0.5,  Preco = 400 },
		Rifle =           { Nome = "RIFLE",             Item = "Rifle",           Tipo = "RIFLE",         Raridade = "Incomum",  Dano = 25,  Cadencia = 0.1,  Preco = 0 },
		Machete =         { Nome = "MACHETE",           Item = "Machete",         Tipo = "CORPO A CORPO", Raridade = "Raro",     Dano = 120, Cadencia = 0.36, Preco = 900 },
		LancaChamas =     { Nome = "LANÇA-CHAMAS",      Item = "LancaChamas",     Tipo = "LANÇA-CHAMAS",  Raridade = "Raro",     Dano = 11,  Cadencia = 0.08, Projeteis = 3, Preco = 0 },
		LaminaDeEnergia = { Nome = "LÂMINA DE ENERGIA", Item = "LaminaDeEnergia", Tipo = "CORPO A CORPO", Raridade = "Epico",    Dano = 210, Cadencia = 0.34, Preco = 2000 },
		MarteloDoTrovao = { Nome = "MARTELO DO TROVÃO", Item = "MarteloDoTrovao", Tipo = "ÁREA",          Raridade = "Epico",    Dano = 350, Cadencia = 0.7,  Preco = 0 },
		LaminaDoNucleo =  { Nome = "LÂMINA DO NÚCLEO",  Item = "LaminaDoNucleo",  Tipo = "CORPO A CORPO", Raridade = "Lendario", Dano = 520, Cadencia = 0.32, Bloqueada = "RECOMPENSA DO DIA 7" },
	},
	-- ordem usada para o custo de upgrade (indice)
	OrdemArmas = { "Punhos", "Pistola", "Estilingue", "Cano", "Rifle", "Machete", "LancaChamas", "LaminaDeEnergia", "MarteloDoTrovao", "LaminaDoNucleo" },
	NivelArmaMax = 5,
	BonusPorNivelArma = 0.10, -- +10% de dano por nivel (estrela)
	CustoNivelArma = function(indiceArma, nivelAtual)
		return math.floor((40 + indiceArma * 15) * (nivelAtual + 1) ^ 1.4 / 5 + 0.5) * 5
	end,

	-- CLASSES: raridade na lista e nivel (estrelas) de cada habilidade
	RaridadeClasse = { Soldado = "Comum", Ninja = "Incomum", Engenheiro = "Raro", Medico = "Epico" },
	NivelHabMax = 5,
	BonusPorNivelHab = 0.08,  -- +8% nos numeros da habilidade por estrela
	CustoNivelHab = function(nivelAtual) return math.floor(60 * (nivelAtual + 1) ^ 1.5 / 5 + 0.5) * 5 end,

	-- RECOMPENSA DIARIA (dia 1..7; o dia 7 e permanente)
	Diario = {
		Intervalo = 20 * 3600,   -- pode resgatar de novo depois de 20 h
		PerdeSequencia = 48 * 3600, -- passou 48 h sem resgatar: volta ao dia 1
		Dias = {
			{ Gemas = 50 }, { Gemas = 100 }, { Gemas = 150 }, { Gemas = 250 }, { Gemas = 400 }, { Gemas = 600 },
			{ Arma = "LaminaDoNucleo", GemasSeJaTem = 1000 },
		},
	},

	-- GRUPOS (caminhoes)
	Grupo = { Max = 4, Contagem = 20, ContagemCheio = 5, EsperaNaMissao = 20 },

	-- CODIGOS
	Codigos = {
		VERITY = { Gemas = 100 },
		LABORATORIO = { Gemas = 250 },
		NUCLEO = { Gemas = 50 },
	},

	-- LOJA (Robux). Crie os Developer Products / Game Pass no Creator Hub e coloque os IDs.
	-- Com ID = 0 a compra so funciona no Studio (para teste).
	Destaque = "PacoteNucleo",
	Pacotes = {
		PacoteNucleo = { Nome = "PACOTE DO NÚCLEO", Robux = 899, ProdutoId = 0, Classes = { "Medico" }, Armas = { "LaminaDoNucleo" }, Gemas = 5000 },
		PacoteDimitri = { Nome = "PACOTE DO DIMITRI", Robux = 649, Desconto = 50, ProdutoId = 0, Armas = { "Cano", "Machete", "LaminaDeEnergia", "LaminaDoNucleo" } },
		PacoteInicial = { Nome = "PACOTE INICIAL", Robux = 49, Desconto = 50, ProdutoId = 0, Armas = { "Cano" }, Classes = { "Ninja" }, Gemas = 1000, UmaVez = true },
	},
	OrdemPacotes = { "PacoteDimitri", "PacoteInicial" },
	PacotesGemas = {
		{ Gemas = 500, Robux = 49, ProdutoId = 0 },
		{ Gemas = 1500, Robux = 129, ProdutoId = 0 },
		{ Gemas = 5000, Robux = 349, ProdutoId = 0 },
		{ Gemas = 20000, Robux = 1099, ProdutoId = 0 },
	},
	Passes = {
		GemasEmDobro = { Nome = "GEMAS EM DOBRO", Texto = "PERMANENTE: dobra toda gema ganha nas missões", Robux = 359, PasseId = 0 },
	},

	-- PLACARES (OrderedDataStore)
	Placares = { Wave = "RecordeWave_v1", Abates = "RecordeAbates_v1", Tamanho = 15 },
}
