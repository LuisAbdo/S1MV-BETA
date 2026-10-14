-- Config/Enemies: atributos dos inimigos e parametros da IA.
return {
	MaxVivos = 85,   -- mais bichos ao mesmo tempo nas waves altas

	-- Pulo reaproveitado da animacao antiga (0,83 s). Valores relativos ao tamanho.
	Pulo = {
		Duracao = 0.833,
		InicioAr = 0.183,  -- so se desloca entre InicioAr e FimAr
		FimAr = 0.583,
		Altura = { {0, 0}, {0.183, -0.40}, {0.433, 0.92}, {0.583, -0.34}, {0.733, -0.09}, {0.833, 0} },
		EscalaY = { {0, 1}, {0.183, 0.38}, {0.317, 1}, {0.383, 1.33}, {0.617, 0.57}, {0.733, 1}, {0.833, 1} },
	},

	Tipos = {
		Verity = {
			Template = "Meshes/Hollow Ball", Nome = "Verity",
			Vida = 60, Dano = 10, Tamanho = 4, Velocidade = 11, Cooldown = 1.2, Custo = 1, WaveMin = 1,
		},
		Falsity = {
			Template = "Falsity", Nome = "Falsity",
			Vida = 40, Dano = 8, Tamanho = 3.6, Velocidade = 15, Cooldown = 0.9, Custo = 1.2, WaveMin = 2,
			Ilusoes = 2, DistanciaIlusao = 32,   -- cria as copias ao chegar a esta distancia do alvo
		},
		Cruelty = {
			Template = "Cruelty", Nome = "Cruelty",
			Vida = 150, Dano = 16, Tamanho = 6, Velocidade = 7, Cooldown = 1.6, Custo = 3, WaveMin = 4,
			ImuneEmpurrao = true,
			AcumuloPorGolpe = 0.10, MaxAcumulos = 5, TempoZerarAcumulo = 5,
			FuriaLimiar = 0.5, FuriaVelocidade = 1.5,
			Esmagamento = { Intervalo = 7, Telegrafia = 1.2, Raio = 11, DanoJogador = 25, DanoNucleo = 40, DanoEstrutura = 120, Atordoamento = 1 },
		},
	},

	IA = {
		Aggro = 18,            -- raio para trocar o alvo para um jogador
		Leash = 30,            -- distancia em que desiste do jogador
		MaxPorJogador = 3,
		Slots = 16,
		RaioSlot = 11,         -- anel de ataque (o Nucleo agora tem base de ~17 studs)
		RaioEspera = 18,       -- anel externo para quem esta sem slot
		AlcanceAtaque = 4,
		MultDanoNucleo = 0.5,
		MultDanoJogador = 0.5, -- fracao do dano aplicada aos jogadores
		HitStun = 0.5,         -- levar golpe atrasa o proximo ataque do inimigo  -- fracao do dano aplicada ao Nucleo (jogadores levam o dano cheio)
		PresoTempo = 2,
		IntervaloLonge = 0.2,  -- IA de quem esta longe de jogadores atualiza a cada 0,2 s
		DistanciaPerto = 120,
		DegrauMax = 4,         -- altura maxima que um pulo sobe
	},

	Spawn = {
		Setores = 8,
		RaioMinNucleo = 45,    -- distancia minima do Nucleo; o resto da Zona de spawn e sorteado
		DistanciaMinima = 6,
		SpawnSeguro = 22,     -- nao nasce a menos disso do spawn dos jogadores
	},

	Moedas = { Base = 5, PorWave = 0.25 },  -- por abate (com mais inimigos a renda ja cresce sozinha)
}
