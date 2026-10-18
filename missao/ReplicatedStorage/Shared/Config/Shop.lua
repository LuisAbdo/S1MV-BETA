-- Config/Shop: estruturas da Loja do Nucleo, pagas com MATERIAIS do estoque do Nucleo
-- (madeira e pedra coletadas de dia). Custo = { Madeira = n, Pedra = n }.
-- O dinheiro ($) fica so para as armas, a vida e a evolucao do Nucleo.
return {
	Construcao = {
		RaioConstrucao = 60,       -- distancia maxima do Nucleo
		RaioMinimoNucleo = 16,     -- nao pode colar na base do Nucleo
		Grade = 2,
		LimitePorJogador = 45,
		LimiteGlobal = 160,
		RetornoVenda = 0.6,        -- vender devolve 60% dos materiais
		ReparoFracao = 0.5,        -- reparar do zero custa 50% dos materiais do item
		EscudoNucleoReducao = 0.25,-- estruturas dentro do Escudo do Nucleo levam -25% de dano
	},

	-- Ordem em que aparecem na loja
	Ordem = { "Barricada", "BarricadaReforcada", "Muro", "MuroTiro", "Portao", "PisoReforcado", "Teto", "Rampa",
		"Mina", "Espinhos", "Lentidao", "Quicador", "LancaDardos", "Repulsor", "Prensa", "EmissorGas",
		"TorretaBasica", "TorretaGelo", "LancaChamas", "TorretaPesada", "Drone", "GeradorEscudo",
		"GradeEletrica", "CampoForca", "Cupula" },

	Estruturas = {
		-- PECAS DE GRADE (fechar a base em 360°; piso/teto/rampa podem ir em cima de outras pecas)
		PisoReforcado = { Nome = "Piso reforçado", Custo = { Madeira = 4, Pedra = 4 }, Vida = 500, Limite = 40, TierMin = 1, Tamanho = Vector3.new(8, 1.2, 8), Tipo = "Bloqueio",
			Empilhavel = true, NaoBloqueia = true },
		Teto = { Nome = "Teto / cobertura", Custo = { Madeira = 4, Pedra = 4 }, Vida = 450, Limite = 40, TierMin = 1, Tamanho = Vector3.new(8, 1.1, 8), Tipo = "Bloqueio",
			Empilhavel = true, NaoBloqueia = true },
		Rampa = { Nome = "Rampa de acesso", Custo = { Madeira = 5, Pedra = 5 }, Vida = 450, Limite = 12, TierMin = 1, Tamanho = Vector3.new(8, 6, 10), Tipo = "Bloqueio",
			Empilhavel = true },
		MuroTiro = { Nome = "Muro de tiro (com fenda)", Custo = { Pedra = 7, Madeira = 2 }, Vida = 600, Limite = 20, TierMin = 1, Tamanho = Vector3.new(10, 7, 3), Tipo = "Bloqueio" },
		-- ARMADILHAS (nao bloqueiam: os veritys passam por cima/por baixo e tomam o efeito)
		Espinhos = { Nome = "Placa de espinhos", Custo = { Madeira = 3, Pedra = 5 }, Vida = 300, Limite = 16, TierMin = 1, Tamanho = Vector3.new(6, 1, 6), Tipo = "Armadilha",
			NaoBloqueia = true, Raio = 3.6, Dano = 9, Intervalo = 0.5 },
		Lentidao = { Nome = "Placa de gelo (lentidão)", Custo = { Madeira = 4, Pedra = 2 }, Vida = 300, Limite = 16, TierMin = 1, Tamanho = Vector3.new(6, 0.6, 6), Tipo = "Armadilha",
			NaoBloqueia = true, Raio = 3.6, Lentidao = 0.5 },
		Quicador = { Nome = "Quicador", Custo = { Madeira = 6, Pedra = 3 }, Vida = 300, Limite = 10, TierMin = 1, Tamanho = Vector3.new(4, 1.4, 4), Tipo = "Armadilha",
			NaoBloqueia = true, Raio = 3, Forca = 18, Cadencia = 1.5 },
		LancaDardos = { Nome = "Lança-dardos de parede", Custo = { Madeira = 6, Pedra = 6 }, Vida = 350, Limite = 10, TierMin = 2, Tamanho = Vector3.new(4, 4, 2), Tipo = "Armadilha",
			Alcance = 26, Largura = 2.5, Dano = 30, Cadencia = 1.1 },
		Repulsor = { Nome = "Repulsor de parede", Custo = { Madeira = 8, Pedra = 8 }, Vida = 400, Limite = 6, TierMin = 2, Tamanho = Vector3.new(4, 4, 2), Tipo = "Armadilha",
			Alcance = 18, Largura = 5, Forca = 16, Cadencia = 4 },
		Prensa = { Nome = "Prensa de impacto", Custo = { Madeira = 10, Pedra = 14 }, Vida = 500, Limite = 6, TierMin = 3, Tamanho = Vector3.new(8, 9, 8), Tipo = "Armadilha",
			NaoBloqueia = true, Dano = 160, Cadencia = 3 },
		EmissorGas = { Nome = "Emissor de gás", Custo = { Madeira = 10, Pedra = 10 }, Vida = 450, Limite = 6, TierMin = 3, Tamanho = Vector3.new(8, 9, 8), Tipo = "Armadilha",
			NaoBloqueia = true, Raio = 5.5, Dano = 5, Intervalo = 0.5 },
		-- DEFESAS AVANCADAS (liberam com a evolucao do Nucleo)
		GradeEletrica = { Nome = "Grade eletrificada", Custo = { Madeira = 10, Pedra = 16 }, Vida = 800, Limite = 4, TierMin = 2, Tamanho = Vector3.new(12, 8, 3), Tipo = "Armadilha",
			Portao = true, Raio = 5, Dano = 20, Forca = 6, Intervalo = 0.8 },
		CampoForca = { Nome = "Campo de força", Custo = { Madeira = 12, Pedra = 18 }, Vida = 900, Limite = 6, TierMin = 3, Tamanho = Vector3.new(10, 7, 1.2), Tipo = "Bloqueio",
			PassaJogador = true },
		Cupula = { Nome = "Cúpula protetora", Custo = { Madeira = 20, Pedra = 30 }, Vida = 1500, Limite = 1, TierMin = 4, Tamanho = Vector3.new(5, 4, 5), Tipo = "Suporte",
			RaioDomo = 18 },
		Barricada = { Nome = "Barricada de madeira", Custo = { Madeira = 4 }, Vida = 300, Limite = 25, TierMin = 1, Tamanho = Vector3.new(8, 5, 2), Tipo = "Bloqueio" },
		BarricadaReforcada = { Nome = "Barricada reforçada", Custo = { Madeira = 8, Pedra = 3 }, Vida = 800, Limite = 20, TierMin = 3, Tamanho = Vector3.new(8, 6, 2.5), Tipo = "Bloqueio" },
		Muro = { Nome = "Muro de pedra", Custo = { Pedra = 6 }, Vida = 650, Limite = 20, TierMin = 1, Tamanho = Vector3.new(10, 7, 3), Tipo = "Bloqueio" },
		-- portao: os jogadores passam, os veritys nao (eles batem nele como num muro)
		Portao = { Nome = "Portão de pedra", Custo = { Pedra = 8, Madeira = 3 }, Vida = 700, Limite = 6, TierMin = 1, Tamanho = Vector3.new(12, 8, 3), Tipo = "Bloqueio", Portao = true },
		Mina = { Nome = "Mina de proximidade", Custo = { Pedra = 3, Madeira = 1 }, Vida = 40, Limite = 16, TierMin = 1, Tamanho = Vector3.new(3, 1, 3), Tipo = "Mina",
			Gatilho = 3.5, Raio = 9, Dano = 140 },
		TorretaBasica = { Nome = "Torreta básica", Custo = { Madeira = 10, Pedra = 6 }, Vida = 400, Limite = 10, TierMin = 1, Tamanho = Vector3.new(4, 6, 4), Tipo = "Torreta",
			Dano = 14, Cadencia = 0.55, Alcance = 40 },
		TorretaGelo = { Nome = "Torreta de gelo", Custo = { Madeira = 12, Pedra = 10 }, Vida = 420, Limite = 8, TierMin = 2, Tamanho = Vector3.new(4, 6, 4), Tipo = "Torreta",
			Dano = 8, Cadencia = 0.8, Alcance = 35, Lentidao = 0.5, DuracaoLentidao = 2 },
		LancaChamas = { Nome = "Torreta lança-chamas", Custo = { Madeira = 16, Pedra = 12 }, Vida = 500, Limite = 8, TierMin = 4, Tamanho = Vector3.new(4, 5, 4), Tipo = "Torreta",
			Dano = 7, Cadencia = 0.15, Alcance = 18, Cone = 40 },
		TorretaPesada = { Nome = "Torreta pesada", Custo = { Madeira = 20, Pedra = 26 }, Vida = 900, Limite = 5, TierMin = 6, Tamanho = Vector3.new(6, 7, 6), Tipo = "Torreta",
			Dano = 90, Cadencia = 1.6, Alcance = 55, Area = 7 },
		Drone = { Nome = "Drone reparador", Custo = { Madeira = 10, Pedra = 8 }, Vida = 250, Limite = 4, TierMin = 2, Tamanho = Vector3.new(4, 7, 4), Tipo = "Drone",
			Cura = 15, Raio = 25 },
		GeradorEscudo = { Nome = "Gerador de escudo", Custo = { Madeira = 14, Pedra = 20 }, Vida = 600, Limite = 4, TierMin = 5, Tamanho = Vector3.new(5, 8, 5), Tipo = "Gerador",
			Raio = 20, Reducao = 0.3 },
	},
}
