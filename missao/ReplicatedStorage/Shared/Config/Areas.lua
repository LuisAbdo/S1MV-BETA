-- Config/Areas: todos os numeros de desbloqueio de areas e nevoa.
-- Ajuste aqui sem mexer na logica do AreaService.
return {
	-- As areas que abriam com as waves (Casa, Rio, Estaleiro, Templo, Arena) foram desligadas:
	-- o mapa agora e gerado por chunks (ChunkService / Config.Sobrevivencia). Os modelos antigos
	-- ficaram em ServerStorage.Backup_Areas_Zonas. Para religar, devolva a lista abaixo.
	Ordem = {},
	Areas = {},

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
