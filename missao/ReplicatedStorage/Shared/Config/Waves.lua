-- Config/Waves: ciclo dia/noite, orcamento, economia de fim de wave.
return {
	-- LADOS DE SPAWN: ate a wave LadoUnicoAte os veritys saem todos de UM lado (sorteado por run,
	-- nunca o lado do spawn dos jogadores). Depois saem desse lado E do oposto.
	LadoUnicoAte = 10,
	AberturaLado = 26, -- graus de cada lado do centro da saida
	LadosPossiveis = { "Norte", "Leste", "Oeste" },

	-- CICLO (estilo 99 Noites): o DIA e para coletar madeira/pedra e construir; a NOITE dura mais
	-- e tem tempo fixo. Os veritys vao chegando durante a noite e recuam quando amanhece.
	DiaPrimeiraWave = 90,
	DiaDuracao = 70,
	NoiteDuracao = 95,
	NoiteEspalhar = 0.65,          -- a horda inteira chega ate 65% da noite (depois so os que sobraram)
	TransicaoLuz = 5,

	-- DIFICULDADE = QUANTIDADE: a vida dos veritys NAO cresce; cada wave traz mais bichos
	-- orcamento = Base + PorWave*w + Quad*w^Expoente  (w10 ~32, w20 ~63, w30 ~97, w40 ~134 inimigos)
	OrcamentoBase = 6,
	OrcamentoPorWave = 2.6,
	OrcamentoQuad = 0.12,
	OrcamentoExpoente = 1.6,
	EscalaPorJogadorExtra = 0.35,  -- +35% de orcamento por jogador a mais
	VidaPorWave = 0,               -- vida FIXA: matar continua facil em qualquer wave
	VidaPorWaveInfinito = 0,

	Grupo = { Min = 2, Max = 4 },               -- inimigos por leva (cada um num ponto aleatorio)
	IntervaloGrupos = { Min = 1.2, Max = 2.6 },
	-- ritmo: as levas crescem e chegam mais rapido conforme a wave
	Ritmo = { GrupoExtraACada = 6, IntervaloMenosPorWave = 0.025, IntervaloMinimoMult = 0.3 },
	ChanceAgrupar = 0.3,                        -- chance de nascer colado no anterior (duplas)

	BonusFimWave = { Base = 40, PorWave = 6, PerdaMaxima = 0.25 },
	BonusCoopPorJogador = 0.10,

	CheckpointACada = 10,
	DiaAposPular = 5,              -- "NEXT WAVE IN 5" quando o time pula a wave
	Chefes = {
		[10] = "O REI VERITY", [20] = "FALSITY SUPREMO", [30] = "CRUELTY COLOSSAL",
		[40] = "O ECO SOMBRIO", [50] = "A RAINHA DAS ILUSÕES", [60] = "O ESMAGADOR",
		[70] = "O ENXAME", [80] = "O GUARDIÃO CAÍDO", [90] = "O ARAUTO", [100] = "VERITY MALIGNO",
	},
	VotacaoPular = 0.5,            -- fracao de jogadores para pular o dia

	Luz = {
		Dia = { ClockTime = 13, Brightness = 2, OutdoorAmbient = Color3.fromRGB(128, 128, 138), Tint = Color3.fromRGB(255, 255, 255) },
		Noite = { ClockTime = 1, Brightness = 1, OutdoorAmbient = Color3.fromRGB(60, 70, 110), Tint = Color3.fromRGB(190, 205, 255) },
	},
}
