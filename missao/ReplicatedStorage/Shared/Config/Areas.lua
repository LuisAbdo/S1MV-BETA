-- Config/Areas: todos os numeros de desbloqueio de areas e nevoa.
-- Ajuste aqui sem mexer na logica do AreaService.
return {
	-- Ordem de desbloqueio (tambem usada para restaurar checkpoint)
	Ordem = { "IlhaCasa", "Rio", "Estaleiro", "Templo", "ArenaFinal" },

	Areas = {
		IlhaCasa = { Wave = 5, Nome = "Casa dos Mercenários", Placa = "CASA", Apelidos = { "casa", "ilhacasa" } },
		Rio = { Wave = 10, Nome = "Rio da Ilha", Placa = "RIO", Apelidos = { "rio" } },
		Estaleiro = { Wave = 20, Nome = "Estaleiro", Placa = "ESTALEIRO", Apelidos = { "estaleiro" }, Depende = "IlhaCasa" },
		Templo = { Wave = 30, Nome = "Templo do Altar", Placa = "TEMPLO", Apelidos = { "templo" } },
		ArenaFinal = { Wave = 100, Nome = "Arena do Verity Maligno", Apelidos = { "arena", "arenafinal" }, SemPonte = true },
	},

	Animacao = {
		DuracaoPonte = 2.6,     -- segundos para a ponte inteira se montar
		AlturaQueda = 8,        -- de quantos studs acima cada peca "encaixa"
		DuracaoPeca = 0.35,     -- tween de cada peca
		DuracaoFeixe = 6,       -- feixe de luz apontando o caminho
		Panorama = true,        -- panoramica curta e pulavel no cliente
		DuracaoPanorama = 3.2,
		DuracaoBanner = 3.5,
	},

	-- Nevoa (Atmosphere no cliente). Indice = numero de areas abertas + 1.
	Nevoa = {
		Densidade = { 0.6, 0.5, 0.42, 0.36, 0.3 },
		Haze = { 2.6, 2.2, 1.8, 1.5, 1.2 },
		Cor = Color3.fromRGB(215, 228, 236),
		Deslocamento = 0.05,
		TempoTransicao = 2.5,
		-- Wave 100: a nevoa volta, vermelha
		DensidadeArena = 0.55,
		HazeArena = 2.4,
		CorArena = Color3.fromRGB(150, 40, 50),
	},

	-- Resgate: quem cai na agua volta ao ultimo chao firme
	Resgate = {
		AlturaAgua = 3,        -- abaixo deste Y o jogador esta na agua
		Atraso = 0.5,          -- segundos na agua antes de resgatar
		IntervaloRegistro = 0.5,
	},

	Debug = {
		ComandoNoStudio = true, -- /unlock <area> liberado em testes no Studio
		UserIds = {},           -- UserIds com acesso ao comando em servidores publicados
	},
}
