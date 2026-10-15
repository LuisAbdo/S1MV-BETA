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
	-- Neblina BRANCA e densa: o jogador nunca ve o fim do mapa nem os chunks sendo gerados.
	Nevoa = {
		Densidade = { 0.74, 0.5, 0.42, 0.36, 0.3 },
		Haze = { 3.2, 2.2, 1.8, 1.5, 1.2 },
		Cor = Color3.fromRGB(246, 248, 252),
		Decaimento = Color3.fromRGB(240, 243, 248),
		Deslocamento = 0,
		-- desfoque do fundo (DepthOfField): o que esta longe fica borrado
		Desfoque = { Distancia = 55, Raio = 45, Intensidade = 0.45 },
		-- neblina classica (Lighting.Fog): parede branca garantida a partir de Fim studs.
		-- Quando ligada, o Atmosphere sai (o Roblox ignora o Fog se existir Atmosphere).
		Classica = {
			Inicio = 30,
			Fim = 170,
			CorDia = Color3.fromRGB(246, 248, 252),
			CorNoite = Color3.fromRGB(205, 210, 222), -- branco mais apagado a noite
		},
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
