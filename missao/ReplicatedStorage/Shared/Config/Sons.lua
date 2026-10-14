-- Config/Sons: TODOS os efeitos sonoros do jogo (no lugar dos sons classicos do Roblox).
-- Fontes: Creator Store gratis (Pro Sound Effects, Daily Sounds e outros). Para trocar um som,
-- basta mudar o ID aqui. V = volume base, P = velocidade (tom) base.
local function id(n) return "rbxassetid://" .. n end
return {
	-- ARMAS
	Tiro = {
		Padrao = { Id = id(133335170193696), V = 0.45 },      -- pistola
		Pistola = { Id = id(133335170193696), V = 0.45 },
		Rifle = { Id = id(113879008765178), V = 0.32 },
		Estilingue = { Id = id(9119215650), V = 0.5, P = 1.15 },
		LancaChamas = { Id = id(138257634793906), V = 0.22 },
	},
	Capsula = { Id = id(103073385815737), V = 0.18 },          -- capsula caindo
	Golpe = { Id = id(5789211405), V = 0.38 },                 -- swing corpo a corpo
	Soco = { Id = id(132504023010884), V = 0.5 },              -- impacto do golpe
	Martelo = { Id = id(9120812564), V = 0.6 },                -- martelo de reparo
	Explosao = { Id = id(94978851787238), V = 0.75 },
	Acerto = { Id = id(3748776946), V = 0.35 },               -- hitmarker
	Abate = { Id = id(106984966606682), V = 0.6 },             -- Verity estoura
	Habilidade = { Id = id(9114156829), V = 0.45, P = 1.2 },   -- whoosh das habilidades
	Laser = { Id = id(115842676995967), V = 0.35 },            -- torreta / Lovity

	-- ECONOMIA / PROGRESSO
	Moeda = { Id = id(130378474223829), V = 0.35 },
	Compra = { Id = id(122399158411452), V = 0.55 },           -- comprou arma/vida/upgrade
	AreaLiberada = { Id = id(122399158411452), V = 0.8, P = 0.8 },
	Ponte = { Id = id(9120812564), V = 0.35, P = 1.4 },        -- pecas da ponte encaixando
	Revive = { Id = id(122399158411452), V = 0.7, P = 0.6 },

	-- WAVES / NUCLEO
	Corneta = { Id = id(4624851445), V = 0.6 },                -- comeca a noite (wave)
	Contagem = { Id = id(136924498052589), V = 0.45 },         -- ultimos segundos do dia
	WaveConcluida = { Id = id(122399158411452), V = 0.7, P = 1.1 },
	AlertaNucleo = { Id = id(80890994815283), V = 0.4 },       -- Nucleo levando dano
	Derrota = { Id = id(96795857757261), V = 0.7 },
	Coracao = { Id = id(132163421525060), V = 0.5 },           -- vida baixa

	-- PERSONAGEM
	Passos = { Id = id(84416955338599), V = 0.35 },
	Pulo = { Id = id(133564751966469), V = 0.25 },
	Queda = { Id = id(132504023010884), V = 0.18, P = 0.6 },

	-- AMBIENTE (loops)
	AmbienteDia = { Id = id(9112749254), V = 0.25 },           -- passaros
	AmbienteNoite = { Id = id(9112764546), V = 0.3 },

	-- inimigos
	PuloInimigo = { Id = id(836796971), V = 0.4 },
	PortalAbrindo = { Id = id(9114156829), V = 1, P = 0.55 },     -- saida dos veritys abrindo (inicio da noite)

	-- jogador / estruturas levando dano
	JogadorDano = { Id = id(5789211405), V = 0.45, P = 0.8 },
	EstruturaAcerto = { Id = id(9120858570), V = 0.45 },
	Portal = { Id = id(9125517884), V = 0.32, P = 0.9 },
	RugidoChefe = { Id = id(9125471073), V = 0.95, P = 0.85 },
	AlertaSpawn = { Id = id(1173184846), V = 0.45 },

	-- interface
	UIClique = { Id = id(88442833509532), V = 0.5 },
	UIHover = { Id = id(88442833509532), V = 0.12, P = 1.7 },
	UIErro = { Id = id(80890994815283), V = 0.3, P = 1.5 },
	UIAbrir = { Id = id(9119467863), V = 0.28, P = 1.35 },
	Girar = { Id = id(88442833509532), V = 0.4, P = 0.75 },

	-- estruturas da Loja do Nucleo (tocadas no servidor, posicionais)
	Construir = { Id = id(9116488438), V = 0.6, P = 0.85 },
	MontarTorreta = { Id = id(9118340555), V = 0.45 },
	Quebrar = { Id = id(126645609816652), V = 0.75 },
	Vender = { Id = id(122399158411452), V = 0.5, P = 1.3 },
	TorretaTiro = { Id = id(133335170193696), V = 0.35, P = 1.15 },
	TorretaGelo = { Id = id(115842676995967), V = 0.4, P = 0.75 },
	TorretaFogo = { Id = id(138257634793906), V = 0.3 },
	TorretaPesada = { Id = id(94978851787238), V = 0.55, P = 0.9 },
	MinaExplosao = { Id = id(94978851787238), V = 0.85, P = 1.05 },
	DroneCura = { Id = id(122399158411452), V = 0.25, P = 1.6 },
	GeradorZumbido = { Id = id(120250063764346), V = 0.22 },

	-- evolucao do Nucleo
	NucleoEvolui = { Id = id(9114156829), V = 0.9, P = 0.75 },
	NucleoFanfarra = { Id = id(122399158411452), V = 0.7, P = 0.9 },          -- grilos
}
