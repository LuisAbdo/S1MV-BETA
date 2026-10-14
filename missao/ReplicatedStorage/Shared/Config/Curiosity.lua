-- Config/Curiosity: a assistente fixa do hub (ataque, tarefas em segundo plano e falas).
return {
	Offset = Vector3.new(14, 7, 24),   -- posicao relativa ao centro do Nucleo (no chao)
	Alcance = 15,                      -- ataca inimigos a ate 15 studs (sem se mover)
	Dano = 14,
	Cadencia = 0.6,
	DistanciaInteracao = 14,

	MaxFila = 2,                       -- fila de ate 2 tarefas (uma depois da outra)
	DataStore = "Curiosity_v1",
	MultTempoStudio = 1 / 30,          -- no Studio as tarefas andam 30x mais rapido (teste)

	-- O cronometro e em tempo real: continua contando com o jogador offline.
	Tarefas = {
		Pesquisa = {
			Nome = "Pesquisa", Descricao = "Melhorias pequenas e permanentes.",
			DuracaoBase = 300, DuracaoPorNivel = 300,   -- 5 min no nivel 1, +5 min por nivel
			Ordem = { "Dano", "Vida", "Moedas" },
			Linhas = {
				Dano = { Nome = "Dano", PorNivel = 0.02, Max = 10, Texto = "+2% de dano" },
				Vida = { Nome = "Vida", PorNivel = 5, Max = 10, Texto = "+5 de vida máxima" },
				Moedas = { Nome = "Moedas", PorNivel = 0.03, Max = 10, Texto = "+3% de moedas por abate" },
			},
		},
		Suprimentos = {
			Nome = "Envio de suprimentos", Descricao = "Expedição que volta com Gemas e Moedas.",
			Duracao = 1800, GemasMin = 20, GemasMax = 40, Moedas = 150,
		},
		Previsao = {
			Nome = "Previsão", Descricao = "Mostra quem vem na próxima wave.",
			Duracao = 45,
		},
	},

	-- Falas curtas (balão em cima da Curiosity). {nome} = nome do jogador.
	Falas = {
		Inicio = { "Oi! Eu sou a CURIOSITY. Protejam o Núcleo!", "Aperte V para comprar uma arma melhor." },
		Wave2 = "Aperte B perto do Núcleo para abrir a LOJA e construir defesas.",
		Wave3 = "Estrutura quebrada? Pegue o MARTELO (G) e clique nela.",
		Wave4 = "Fale comigo (E) para pesquisas, suprimentos e previsões!",
		Noite1 = "Lá vêm eles! Clique para atacar.",
		Noite = { "Lá vêm eles!", "Fiquem perto do Núcleo!", "Mais Verities chegando!", "Preparem-se!" },
		NucleoFraco = "O Núcleo está fraco! Voltem para defender!",
		Morte = "Aguenta firme, {nome}! O Godrity pode te trazer de volta.",
		NovaArea = "Uma nova área se abriu! Sigam a luz.",
		Ataque = { "Toma!", "Fica longe do Núcleo!", "Pesquisa de campo!" },
	},
	DuracaoFala = 4.5,
}
