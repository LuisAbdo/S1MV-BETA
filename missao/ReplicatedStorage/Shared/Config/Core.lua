-- Config/Core: Nucleo, tiers e loja.
return {
	VidaBase = 5000,
	MultVidaPorTier = 1.35,     -- cada tier multiplica a vida maxima
	RegenBase = 2,              -- vida por segundo
	RegenPorTier = 1.5,
	EscudoRaioBase = 12,        -- raio do Escudo do Nucleo (usado nas construcoes, Etapa 6)
	EscudoRaioPorTier = 2,
	SemRegenAposDano = 4,       -- segundos sem tomar dano antes de regenerar

	-- Tier N+1 exige a wave minima e o custo em moedas
	Tiers = {
		{ WaveMin = 0, Custo = 0 },
		{ WaveMin = 10, Custo = 400 },
		{ WaveMin = 20, Custo = 900 },
		{ WaveMin = 30, Custo = 1600 },
		{ WaveMin = 40, Custo = 2600 },
		{ WaveMin = 50, Custo = 4000 },
		{ WaveMin = 60, Custo = 6000 },
		{ WaveMin = 70, Custo = 8500 },
		{ WaveMin = 80, Custo = 12000 },
		{ WaveMin = 90, Custo = 17000 },
	},

	Animacao = {
		Amplitude = 1.2,        -- studs de subida e descida
		Periodo = 4,            -- segundos por ciclo
		GiroGrausPorSeg = 25,
	},
	Cores = {
		Cheia = Color3.fromRGB(0, 229, 255),
		Media = Color3.fromRGB(255, 210, 40),
		Baixa = Color3.fromRGB(255, 50, 50),
	},
	DistanciaLoja = 12,

	-- Visual de cada tier: cor do Nucleo (esfera, halo, pilones, loja) e nome da evolucao.
	-- O tier 10 (Prisma) fica trocando de cor sem parar.
	VisualTier = {
		{ Nome = "CENTELHA", Cor = Color3.fromRGB(0, 229, 255) },
		{ Nome = "PULSO", Cor = Color3.fromRGB(40, 255, 190) },
		{ Nome = "FLUXO", Cor = Color3.fromRGB(120, 255, 80) },
		{ Nome = "RADIANTE", Cor = Color3.fromRGB(255, 225, 60) },
		{ Nome = "FORNALHA", Cor = Color3.fromRGB(255, 140, 40) },
		{ Nome = "RUBI", Cor = Color3.fromRGB(255, 60, 90) },
		{ Nome = "PLASMA", Cor = Color3.fromRGB(255, 80, 210) },
		{ Nome = "NEBULOSA", Cor = Color3.fromRGB(165, 90, 255) },
		{ Nome = "ABISSAL", Cor = Color3.fromRGB(70, 110, 255) },
		{ Nome = "PRISMA", Cor = Color3.fromRGB(255, 245, 210), Arcoiris = true },
	},
	Romano = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" },
}
