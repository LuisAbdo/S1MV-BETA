-- Config/Waves: ciclo dia/noite, orcamento, economia de fim de wave.
return {
	-- LADOS DE SPAWN: ate a wave LadoUnicoAte os veritys saem todos de UM lado (sorteado por run,
	-- nunca o lado do spawn dos jogadores). Depois saem desse lado E do oposto.
	LadoUnicoAte = 10,
	AberturaLado = 26, -- graus de cada lado do centro da saida
	LadosPossiveis = { "Norte", "Leste", "Oeste" },

	DiaPrimeiraWave = 60,
	DiaDuracao = 35,
	TransicaoLuz = 5,

	OrcamentoBase = 6,
	OrcamentoPorWave = 2.4,
	EscalaPorJogadorExtra = 0.35,  -- +35% de orcamento por jogador a mais
	VidaPorWave = 0.05,            -- HP = base * (1 + 0.05*(wave-1))
	VidaPorWaveInfinito = 0.12,    -- apos a 100

	Grupo = { Min = 2, Max = 4 },               -- inimigos por leva (cada um num ponto aleatorio)
	IntervaloGrupos = { Min = 1.2, Max = 2.6 },
	ChanceAgrupar = 0.3,                        -- chance de nascer colado no anterior (duplas)

	BonusFimWave = { Base = 50, PorWave = 10, PerdaMaxima = 0.25 },
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
