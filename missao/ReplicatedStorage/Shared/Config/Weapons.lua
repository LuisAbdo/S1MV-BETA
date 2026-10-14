-- Config/Weapons: armas da run (resetam a cada run), no estilo do video de referencia.
-- V compra a PROXIMA arma da lista. C compra +vida. Tudo validado no servidor.
return {
	-- Corpo a corpo (Punhos)
	Combo = {
		JanelaCombo = 1.0,
		MultTerceiro = 1.5,
		ChanceCritico = 0.1, MultCritico = 2,
		Empurrao = 2.5, EmpurraoTerceiro = 5,
	},

	-- Ordem de compra (os modelos vem de ReplicatedStorage.Veritys_Itens, ver ModelosArmas.Itens).
	-- Tipo: "Corpo" (golpe em area na frente), "Tiro" (hitscan) ou "Foguete" (explode em area).
	-- Cor = cor do tracante; Fogo = desenha chamas no lugar do tracante; Area = golpe acerta em volta.
	Armas = {
		{ Id = "Punhos",          Nome = "PUNHOS",             Tipo = "Corpo", Dano = 25,  Alcance = 5.5, Cadencia = 0.4,  Custo = 0 },
		{ Id = "Estilingue",      Nome = "ESTILINGUE",         Tipo = "Tiro",  Dano = 30,  Alcance = 110, Cadencia = 0.5,  Espalhamento = 1.5, Custo = 40, Cor = Color3.fromRGB(235, 215, 170) },
		{ Id = "Pistola",         Nome = "PISTOLA",            Tipo = "Tiro",  Dano = 40,  Alcance = 150, Cadencia = 0.34, Espalhamento = 1,   Custo = 150 },
		{ Id = "Cano",            Nome = "CANO DE METAL",      Tipo = "Corpo", Dano = 75,  Alcance = 7,   Cadencia = 0.5,  Custo = 400 },
		{ Id = "Rifle",           Nome = "RIFLE",              Tipo = "Tiro",  Dano = 25,  Alcance = 180, Cadencia = 0.1,  Espalhamento = 2.5, Custo = 900, Automatica = true },
		{ Id = "Machete",         Nome = "MACHETE",            Tipo = "Corpo", Dano = 120, Alcance = 7.5, Cadencia = 0.36, Custo = 2000 },
		{ Id = "LancaChamas",     Nome = "LANÇA-CHAMAS",       Tipo = "Tiro",  Dano = 11,  Alcance = 40,  Cadencia = 0.08, Espalhamento = 9,   Custo = 4000, Automatica = true, Projeteis = 3, Fogo = true },
		{ Id = "LaminaDeEnergia", Nome = "LÂMINA DE ENERGIA",  Tipo = "Corpo", Dano = 210, Alcance = 9,   Cadencia = 0.34, Custo = 7000, Cor = Color3.fromRGB(4, 175, 236) },
		{ Id = "MarteloDoTrovao", Nome = "MARTELO DO TROVÃO",  Tipo = "Corpo", Dano = 350, Alcance = 10,  Cadencia = 0.7,  Custo = 11000, Area = true, Cor = Color3.fromRGB(255, 225, 40) },
		{ Id = "LaminaDoNucleo",  Nome = "LÂMINA DO NÚCLEO",   Tipo = "Corpo", Dano = 520, Alcance = 10,  Cadencia = 0.32, Custo = 18000, Cor = Color3.fromRGB(4, 175, 236) },
	},
	-- SEQUENCIA DA RUN: Punhos -> arma equipada no TIER 1 -> TIER 2 -> TIER 3 -> TIER 4 (escolhidas no Main Lobby).
	-- CustoTier[n] = moedas para comprar o passo n com a tecla V. (O campo Custo de cada arma nao e mais usado.)
	CustoTier = { 0, 120, 600, 2000, 5500 },  -- T2 ~wave 4, T3 ~wave 10, T4 ~wave 16 (dividindo com defesas)
	TiersPadrao = { "Pistola", "Rifle", "LancaChamas", "MarteloDoTrovao" },
	TiersPermitidos = {
		{ Pistola = true, Estilingue = true, Cano = true },
		{ Rifle = true, Machete = true },
		{ LancaChamas = true, LaminaDeEnergia = true },
		{ MarteloDoTrovao = true, LaminaDoNucleo = true },
	},
	ChanceCritico = 0.08,
	MultCritico = 2,

	-- Sensacao do tiro (so visual, no cliente): recuo da camera em graus, tremor, tamanho do clarao
	Sensacao = {
		Punhos          = { Recuo = 0,   Tremor = 0.12, Clarao = 0 },
		Estilingue      = { Recuo = 1.4, Tremor = 0.22, Clarao = 0.6, Som = 1.35 },
		Pistola         = { Recuo = 3.0, Tremor = 0.46, Clarao = 1.8, Som = 0.85 },
		Cano            = { Recuo = 0,   Tremor = 0.20, Clarao = 0 },
		Rifle           = { Recuo = 1.1, Tremor = 0.26, Clarao = 1.35, Som = 1.1 },
		Machete         = { Recuo = 0,   Tremor = 0.22, Clarao = 0 },
		LancaChamas     = { Recuo = 0.4, Tremor = 0.16, Clarao = 1.1, Som = 0.6 },
		LaminaDeEnergia = { Recuo = 0,   Tremor = 0.26, Clarao = 0 },
		MarteloDoTrovao = { Recuo = 0,   Tremor = 0.70, Clarao = 0 },
		LaminaDoNucleo  = { Recuo = 0,   Tremor = 0.34, Clarao = 0 },
		Bazuca          = { Recuo = 6.5, Tremor = 0.80, Clarao = 2.6, VelocidadeFoguete = 170, TremorExplosao = 1.2 },
	},

	-- Mira no PC (estilo do video): Modo = "Livre" -> mouse solto com a mira de colchetes no
	-- cursor, camera em terceira pessoa por cima do ombro e o personagem vira para onde o mouse
	-- aponta. Modo = "Centro" -> camera de ombro com a mira travada no centro (modo antigo).
	Mira = {
		Ativa = true,
		Modo = "Livre",
		ZoomInicial = 22, ZoomMin = 10, ZoomMax = 40, -- distancia da camera no modo Livre
		AnguloInicial = 38,                         -- graus olhando para baixo ao nascer
		GiroPersonagem = 18,                        -- quao rapido o corpo vira para a mira
		Distancia = 12, DistanciaMin = 6, DistanciaMax = 18,
		Altura = 3.6, Lado = 0.4,     -- foco acima da cabeca: a mira fica sobre o personagem (como no video)
		Sensibilidade = 0.30,          -- graus por pixel (multiplicado pela sensibilidade do Roblox)
		PitchMin = -60, PitchMax = 55,
		AssistPixels = 70,             -- inimigo a ate 70 px do centro trava a mira (colchetes)
		RecuperacaoRecuo = 10,         -- quao rapido a camera volta depois do recuo
	},

	-- Upgrade de vida (tecla C)
	Vida = { Base = 100, PorNivel = 10, CustoBase = 10, Mult = 1.18, Max = 15 }, -- limite: +150 de vida por run
	RegenPorSegundo = 1,          -- regeneracao natural fora de combate
	VelocidadeBaseJogador = 16,

	-- Martelo de reparo (tecla G / slot 2)
	Martelo = { Alcance = 16, Cadencia = 0.5 },

	-- Botoes "+$" (Developer Products). Crie no Creator Hub e coloque o ID aqui.
	-- Com ProdutoId = 0, no Studio o botao entrega o valor direto (so para teste).
	PacotesDinheiro = {
		{ Valor = 99999, ProdutoId = 0 },
		{ Valor = 1000, ProdutoId = 0 },
	},
}
