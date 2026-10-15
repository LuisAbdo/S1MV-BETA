-- Config/Sobrevivencia: mapa por chunks, coleta de recursos, estoque do Nucleo e o Verity Boss.
-- Estilo "99 Noites na Floresta": de dia coleta madeira/pedra, de noite defende o Nucleo.
return {
	-- MAPA POR CHUNKS ---------------------------------------------------------------
	Chunk = {
		Tamanho = 48,          -- cada chunk e um quadrado de 48x48 studs
		BaseRaio = 1,          -- chunks da base (0 = so o do Nucleo; 1 = 3x3 ao redor dele)
		RaioGeracao = 4,       -- gera ate 4 chunks em volta de cada jogador (a neblina esconde a borda)
		RaioInicial = 4,       -- ja nasce pronto ate 4 chunks do Nucleo (onde a horda aparece)
		RaioMaximo = 10,       -- limite do mapa (10 chunks = ~500 studs); depois disso, neblina
		Intervalo = 0.4,       -- segundos entre verificacoes de geracao
		PorPasso = 3,          -- chunks gerados por verificacao (evita travadas)
		AlturaChao = 21,       -- Y do topo do chao (igual a base)
		VariacaoAltura = 0.8,  -- degrauzinho entre chunks (como no video)
		-- quantidade por chunk: { min, max }
		Arvores = { 2, 5 },
		Rochas = { 0, 2 },
		Decoracao = { 3, 7 },
		ChanceClareira = 0.15, -- chunk sem arvores (campo aberto)
		CoresGrama = {
			Color3.fromRGB(86, 150, 62), Color3.fromRGB(78, 140, 58), Color3.fromRGB(94, 158, 66), Color3.fromRGB(82, 146, 70),
		},
	},

	-- RECURSOS ------------------------------------------------------------------------
	Recursos = {
		Arvore = { Vida = 4, Drops = { 2, 3 }, Item = "Madeira", Rebrota = 0 },   -- 0 = nao volta na mesma run
		Pinheiro = { Vida = 3, Drops = { 1, 2 }, Item = "Madeira", Rebrota = 0 },
		Rocha = { Vida = 5, Drops = { 2, 3 }, Item = "Pedra", Rebrota = 0 },
	},
	Itens = {
		Madeira = { Nome = "Tora", Cor = Color3.fromRGB(122, 82, 48), Tamanho = Vector3.new(4.2, 1.7, 1.7) }, -- cilindro deitado (eixo X)
		Pedra = { Nome = "Pedra", Cor = Color3.fromRGB(120, 120, 128), Tamanho = Vector3.new(2, 1.6, 2) },
	},
	DropsSomemEm = 300,       -- itens largados no chao somem depois de 5 min

	-- MACHADO (nasce com ele; corta arvores e quebra pedras) ---------------------------
	Machado = {
		Dano = 1,
		Cooldown = 0.45,
		Alcance = 10,          -- distancia maxima do jogador ate o recurso (validado no servidor)
	},

	-- CARREGAR ------------------------------------------------------------------------
	Mochila = 5,              -- quantos itens cabem na mochila (tecla E no item)
	ArrastarAlcance = 14,     -- distancia maxima para comecar a arrastar

	-- NUCLEO (estoque) ----------------------------------------------------------------
	Succao = {
		Raio = 26,             -- clicar no Nucleo suga os itens soltos ate esta distancia
		RaioAuto = 13,         -- item solto encostado no Nucleo e sugado sozinho
		AlcanceClique = 32,    -- distancia maxima do jogador para clicar no Nucleo
		Duracao = 0.9,         -- tempo da animacao de sugar
	},
	EstoqueInicial = { Madeira = 0, Pedra = 0 },

	-- VERITY BOSS (noite) ----------------------------------------------------------------
	Boss = {
		DistanciaMinima = 110, -- so aparece para quem esta a mais disso do Nucleo
		Checagem = 4,          -- segundos entre tentativas durante a noite
		AtrasoNoite = 8,       -- espera a noite comecar antes de cacar
		DistanciaSpawn = { 55, 75 }, -- nasce atras/longe do alvo
		Tamanho = 14,
		Velocidade = 13,       -- um pouco mais lento que um jogador correndo (16)
		Dano = 45,
		CooldownAtaque = 1.6,
		AlcanceAtaque = 7,
		RaioSeguro = 40,       -- quando o alvo chega a esta distancia do Nucleo, o boss se assusta e some
		DesisteEm = 140,       -- se o alvo fugir para mais longe que isso, ele some
		TremorRaio = 90,       -- ate onde a tela treme quando ele aterrissa
	},
}
