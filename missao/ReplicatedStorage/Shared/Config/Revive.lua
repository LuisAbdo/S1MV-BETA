-- Config/Revive: GODRITY (reviver). Todos os numeros do revive ficam aqui.
return {
	-- Developer Product de 15 Robux. Crie no Creator Hub (Monetization > Developer Products)
	-- e cole o ID aqui. Com 0: no Studio o revive pago e entregue direto (so para teste).
	ProdutoId = 0,
	PrecoRobux = 15,
	MaxPagosPorRun = 2,
	PrimeiroGratis = true,      -- o 1o revive da CONTA e gratis (flag no DataStore)
	DataStore = "Revive_v1",
	EsperaDeDia = 8,            -- morreu de dia e escolheu "esperar": volta em 8 s

	-- Animacao do Godrity (nao e cutscene: a camera continua livre)
	Animacao = {
		AparecerEm = 0.5,       -- feixe de luz desce; Godrity surge ao lado do corpo
		Controle = 1.5,         -- o jogador volta a se mexer
		Total = 3,              -- Godrity some em particulas
		Invulneravel = 3,       -- segundos sem tomar dano depois de reviver
		AlturaLevantar = 4,     -- quanto o Godrity levanta o jogador
	},
	-- O Medico revive 30% mais rapido (valor em Config/Classes: Medico.Passiva.Revive)
}
