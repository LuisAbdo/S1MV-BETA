-- Config/Shop: estruturas da Loja do Nucleo (pagas com moedas da run).
-- (Pacotes de Gemas/Robux entram aqui na Etapa 11.)
return {
	Construcao = {
		RaioConstrucao = 60,       -- distancia maxima do Nucleo
		RaioMinimoNucleo = 16,     -- nao pode colar na base do Nucleo
		Grade = 2,
		LimitePorJogador = 45,
		LimiteGlobal = 160,
		RetornoVenda = 0.6,        -- vender devolve 60%
		CustoReparoPorVida = 0.12, -- moedas por ponto de vida reparado
		EscudoNucleoReducao = 0.25,-- estruturas dentro do Escudo do Nucleo levam -25% de dano
	},

	-- Ordem em que aparecem na loja
	Ordem = { "Barricada", "BarricadaReforcada", "Muro", "Mina", "TorretaBasica", "TorretaGelo", "LancaChamas", "TorretaPesada", "Drone", "GeradorEscudo" },

	Estruturas = {
		Barricada = { Nome = "Barricada de madeira", Custo = 60, Vida = 300, Limite = 25, TierMin = 1, Tamanho = Vector3.new(8, 5, 2), Tipo = "Bloqueio" },
		BarricadaReforcada = { Nome = "Barricada reforçada", Custo = 160, Vida = 800, Limite = 20, TierMin = 3, Tamanho = Vector3.new(8, 6, 2.5), Tipo = "Bloqueio" },
		Muro = { Nome = "Muro de pedra", Custo = 130, Vida = 650, Limite = 20, TierMin = 1, Tamanho = Vector3.new(10, 7, 3), Tipo = "Bloqueio" },
		Mina = { Nome = "Mina de proximidade", Custo = 70, Vida = 40, Limite = 16, TierMin = 1, Tamanho = Vector3.new(3, 1, 3), Tipo = "Mina",
			Gatilho = 3.5, Raio = 9, Dano = 140 },
		TorretaBasica = { Nome = "Torreta básica", Custo = 260, Vida = 400, Limite = 10, TierMin = 1, Tamanho = Vector3.new(4, 6, 4), Tipo = "Torreta",
			Dano = 14, Cadencia = 0.55, Alcance = 40 },
		TorretaGelo = { Nome = "Torreta de gelo", Custo = 450, Vida = 420, Limite = 8, TierMin = 2, Tamanho = Vector3.new(4, 6, 4), Tipo = "Torreta",
			Dano = 8, Cadencia = 0.8, Alcance = 35, Lentidao = 0.5, DuracaoLentidao = 2 },
		LancaChamas = { Nome = "Torreta lança-chamas", Custo = 600, Vida = 500, Limite = 8, TierMin = 4, Tamanho = Vector3.new(4, 5, 4), Tipo = "Torreta",
			Dano = 7, Cadencia = 0.15, Alcance = 18, Cone = 40 },
		TorretaPesada = { Nome = "Torreta pesada", Custo = 1300, Vida = 900, Limite = 5, TierMin = 6, Tamanho = Vector3.new(6, 7, 6), Tipo = "Torreta",
			Dano = 90, Cadencia = 1.6, Alcance = 55, Area = 7 },
		Drone = { Nome = "Drone reparador", Custo = 400, Vida = 250, Limite = 4, TierMin = 2, Tamanho = Vector3.new(4, 7, 4), Tipo = "Drone",
			Cura = 15, Raio = 25 },
		GeradorEscudo = { Nome = "Gerador de escudo", Custo = 700, Vida = 600, Limite = 4, TierMin = 5, Tamanho = Vector3.new(5, 8, 5), Tipo = "Gerador",
			Raio = 20, Reducao = 0.3 },
	},
}
