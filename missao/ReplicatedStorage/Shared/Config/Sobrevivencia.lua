-- Config/Sobrevivencia: mapa por chunks, coleta de recursos, estoque do Nucleo e o Verity Boss.
-- Estilo "99 Noites na Floresta": de dia coleta madeira/pedra, de noite defende o Nucleo.
return {
	-- MAPA POR CHUNKS ---------------------------------------------------------------
	-- O chao e feito de PECAS com studs: colunas de 6x6 studs com altura por ruido suave,
	-- em degraus de 1 stud (colinas naturais). So uma clareira plana em volta do Nucleo;
	-- as arvores nascem logo depois dela.
	Chunk = {
		Tamanho = 48,          -- cada chunk e um quadrado de 48x48 studs
		Sincrono = 1,          -- chunks ate esta distancia do Nucleo ficam prontos antes de todo mundo nascer
		RaioGeracao = 4,       -- gera ate 4 chunks em volta de cada jogador (a neblina esconde a borda)
		RaioInicial = 4,       -- ja nasce pronto ate 4 chunks do Nucleo (onde a horda aparece)
		RaioMaximo = 10,       -- limite do mapa (10 chunks = ~500 studs); depois disso, neblina
		Intervalo = 0.4,       -- segundos entre verificacoes de geracao
		PorPasso = 3,          -- chunks gerados por verificacao (evita travadas)
		AlturaChao = 21,       -- Y do chao na clareira do Nucleo
		Relevo = {
			Altura = 20,       -- diferenca maxima de altura das colinas (studs)
			Escala = 190,      -- tamanho das colinas (maior = mais suave, degraus mais baixos)
			Celula = 6,        -- tamanho de cada coluna do chao (studs)
			Fundo = 16,        -- quanto as colunas descem abaixo do chao da clareira
			Clareira = 32,     -- raio plano em volta do Nucleo (sem arvores)
			AnelFloresta = 0.55, -- densidade minima da mata logo depois da clareira (arvores ao redor do Nucleo)
			Rampa = 80,        -- distancia em que o relevo vai de plano a altura cheia
			SpawnLivre = 10,   -- raio plano e sem arvores em volta do spawn dos jogadores
			CasaDistancia = { 220, 300 }, -- distancia da Casa do Mercador ate o Nucleo (longe do spawn)
			CasaClareira = 42, -- raio plano e sem arvores em volta da Casa (a plataforma tem ~60 studs)
		},
		-- quantidade por chunk: { min, max } (a densidade varia por "manchas" de floresta)
		Arvores = { 2, 6 },
		Rochas = { 0, 2 },
		Decoracao = { 3, 6 },
		DistanciaArvores = 7,  -- espaco minimo entre arvores
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

	-- MERCADOR (Casa na floresta) ------------------------------------------------------
	-- Melhorias pessoais pagas com o ESTOQUE do Nucleo (madeira/pedra levadas ao Nucleo).
	Mercador = {
		DistanciaLoja = 14,
		Itens = {
			{ Id = "Mochila", Nome = "Mochila maior", Texto = "+3 espaços na mochila",
				Niveis = { { Madeira = 6 }, { Madeira = 10, Pedra = 4 }, { Madeira = 16, Pedra = 10 } }, PorNivel = 3 },
			{ Id = "Machado", Nome = "Machado afiado", Texto = "Corta e quebra mais rápido",
				Niveis = { { Madeira = 5, Pedra = 5 }, { Madeira = 10, Pedra = 10 }, { Madeira = 18, Pedra = 16 } },
				DanoPorNivel = 1, CooldownPorNivel = 0.06 },
			{ Id = "Mapa", Nome = "Mapa da floresta", Texto = "Minimapa com você, o Núcleo e a Casa",
				Niveis = { { Madeira = 8, Pedra = 6 } } },
		},
	},

	-- CORRIDA (Shift) -----------------------------------------------------------------
	-- Stamina fica no servidor; o cliente so pede para correr e mostra a barra.
	Corrida = {
		Multiplicador = 1.55,  -- velocidade correndo = base x isto (16 -> ~25)
		Maxima = 100,
		Gasto = 22,            -- stamina por segundo correndo (~4,5 s de corrida cheia)
		Recupera = 18,         -- stamina por segundo parado/andando
		AtrasoRecuperar = 0.8, -- segundos sem correr antes de recuperar
		MinimoVoltar = 25,     -- se zerar, so corre de novo depois de recuperar isto
	},

	-- PRESENCA DOS CHEFES (Verity Boss e Glitcity) ---------------------------------------
	-- Quanto mais perto, mais a tela treme, as bordas escurecem e o coracao bate mais rapido.
	Presenca = {
		Longe = 110,           -- a partir desta distancia comeca a sentir
		Perto = 10,            -- intensidade maxima
		Tremor = 1.1,          -- graus de tremor no maximo
		Passo = 0.55,          -- segundos entre os "passos" pesados (tranco extra)
		Vinheta = 0.7,         -- quanto as bordas escurecem no maximo (0-1)
	},

	-- NUCLEO (estoque) ----------------------------------------------------------------
	Succao = {
		Raio = 26,             -- clicar no Nucleo suga os itens soltos ate esta distancia
		RaioAuto = 13,         -- item solto encostado no Nucleo e sugado sozinho
		AlcanceClique = 32,    -- distancia maxima do jogador para clicar no Nucleo
		Duracao = 0.9,         -- tempo da animacao de sugar
	},
	EstoqueInicial = { Madeira = 0, Pedra = 0 },

	-- GLITCITY (primeiro chefe, noite 15) ------------------------------------------------
	-- Vida/dano/tamanho ficam em Config/Enemies.Tipos.Glitcity.
	Glitcity = {
		Wave = 15,
		DistanciaSurgir = 70,          -- surge na floresta, a esta distancia do Nucleo
		RaioLivre = 22,                -- procura o trecho com menos arvores neste raio (cutscene limpa)
		Cutscene = { Glitch = 3, Camera = 1.4, Blocos = 2.2, Texto = 2.6 }, -- segundos de cada etapa
		EMP = { Intervalo = 11, Raio = 32, Duracao = 4 },        -- desliga as torres perto
		Voxels = { Intervalo = 9, Quantidade = 8, Raio = 10, Tamanho = 3, Duracao = 7 }, -- barreiras
	},

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
