-- Config/Classes: classes, passivas, habilidades (Z/X/C) e ultimate (Q).
-- Evolucao I libera Z + passiva; II libera X; III libera C e Q.
return {
	ClassePadrao = "Soldado",
	-- Classes sao compradas com Gemas no Laboratorio Verity (lobby). Evolucao fixa por enquanto.
	EvolucaoPadrao = 3,
	TodasLiberadasSemLobby = false,
	TrocarSoDeDia = true,
	-- Desenvolvedores (UserId): podem trocar de classe/evolucao a qualquer momento pelo painel DEV (F2).
	-- O dono do jogo e quem roda no Studio ja entram automaticamente. Validado no servidor (ClassService).
	Desenvolvedores = { 532717024 },
	-- Teclas mostradas na tela (o slot interno continua Z/X/C/Q)
	Teclas = { Z = "Z", X = "X", C = "T", Q = "Q" },
	MaxAliados = 12,

	-- Requisitos de desbloqueio (usados pelo lobby na Etapa 11)
	Desbloqueio = {
		Soldado = { Gratis = true },
		Ninja = { NivelConta = 5, Gemas = 300, Wave = 10 },
		Engenheiro = { NivelConta = 10, Gemas = 800, Wave = 25 },
		Medico = { NivelConta = 15, Gemas = 1500, Wave = 40 },
	},
	Evolucao = {
		[2] = { Gemas = 400, XPClasse = 1500 },
		[3] = { Gemas = 1200, XPClasse = 5000 },
	},
	BonusPorEvolucao = 0.10,   -- cada evolucao acima da I melhora os numeros das habilidades em 10%

	Ordem = { "Soldado", "Ninja", "Engenheiro", "Medico" },

	Classes = {
		Soldado = {
			Nome = "Soldado", Cor = Color3.fromRGB(90, 140, 60),
			Descricao = "Dano em área. Granadas e onda de choque.",
			Passiva = { Nome = "Explosivista", Texto = "+10% de dano em área", DanoArea = 0.10 },
			BonusTime = { Texto = "Time: +5% de dano", Dano = 0.05 },
			Habilidades = {
				Z = { Nome = "Granada", Cooldown = 8, Dano = 60, Raio = 10, Alcance = 45, Atraso = 0.8 },
				X = { Nome = "Onda de choque", Cooldown = 12, Dano = 30, Raio = 13, Empurrao = 12, Atordoamento = 1.5 },
				C = { Nome = "Grito de guerra", Cooldown = 25, BonusDano = 0.15, Duracao = 6, Raio = 40 },
				Q = { Nome = "Chuva de granadas", Cooldown = 1, Carga = 40, Granadas = 12, Duracao = 3, Raio = 16, Dano = 50, RaioExplosao = 8, Alcance = 50 },
			},
		},
		Ninja = {
			Nome = "Ninja", Cor = Color3.fromRGB(60, 60, 80),
			Descricao = "Mobilidade e espada. Golpes curam.",
			Passiva = { Nome = "Caminho do vento", Texto = "+10% velocidade; a cada 4º acerto cura 5% da vida", Velocidade = 0.10, CuraAcerto = 0.05, AcertosParaCura = 4 },
			BonusTime = { Texto = "Time: +5% de velocidade", Velocidade = 0.05 },
			Habilidades = {
				Z = { Nome = "Avanço relâmpago", Cooldown = 6, Distancia = 18, Dano = 40, Largura = 6 },
				X = { Nome = "Bomba de fumaça", Cooldown = 18, Duracao = 5, Raio = 12 },
				C = { Nome = "Estrelas ninja", Cooldown = 7, Quantidade = 5, Dano = 25, Alcance = 45, Espalhamento = 8 },
				Q = { Nome = "Postura das Sombras", Cooldown = 1, Carga = 40, Duracao = 6, Velocidade = 0.4, Critico = true },
			},
		},
		Engenheiro = {
			Nome = "Engenheiro", Cor = Color3.fromRGB(230, 160, 40),
			Descricao = "Defesa. Torretas, iscas e minas.",
			Passiva = { Nome = "B.A.S.E.", Texto = "Estruturas a 15 studs das suas: +60 de armadura e reparo 50% mais barato", Raio = 15, Armadura = 60, DescontoReparo = 0.5 },
			BonusTime = { Texto = "Time: torretas +10% de dano", DanoTorreta = 0.10 },
			Habilidades = {
				Z = { Nome = "MOGGITY", Cooldown = 25, Duracao = 20, Alcance = 40, Dano = 12, Cadencia = 0.4, Distancia = 25 },
				X = { Nome = "Isca", Cooldown = 18, Duracao = 6, Vida = 200, RaioAtracao = 30, Distancia = 25 },
				C = { Nome = "Pulso de plasma", Cooldown = 20, Duracao = 6, Intervalo = 0.6, Raio = 11, Dano = 40, RaioExplosao = 5, Distancia = 25 },
				Q = { Nome = "Sobrecarga", Cooldown = 1, Carga = 45, Duracao = 8, MultCadencia = 2 },
			},
		},
		Medico = {
			Nome = "Médico", Cor = Color3.fromRGB(240, 110, 160),
			Descricao = "Suporte. Cura e resgate.",
			Passiva = { Nome = "Mãos que curam", Texto = "+20% de cura; revive 30% mais rápido", Cura = 0.20, Revive = 0.30 },
			BonusTime = { Texto = "Time: +1 de vida por segundo", Regen = 1 },
			Habilidades = {
				Z = { Nome = "LOVITY", Cooldown = 18, Duracao = 10, Raio = 12, Cura = 8, CuraNucleo = 0.004, Distancia = 25 },
				X = { Nome = "Dardo curativo", Cooldown = 8, Cura = 40, Alcance = 50 },
				C = { Nome = "Passo de fase", Cooldown = 8, Distancia = 12 },
				Q = { Nome = "Coro de Lovities", Cooldown = 1, Carga = 40, Quantidade = 3 },
			},
		},
	},
}
