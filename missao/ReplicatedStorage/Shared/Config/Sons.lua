-- Config/Sons: TODOS os efeitos sonoros do jogo (no lugar dos sons classicos do Roblox).
-- Fontes: Creator Store gratis (Pro Sound Effects, Daily Sounds e outros). Para trocar um som,
-- basta mudar o ID aqui. V = volume base, P = velocidade (tom) base.
-- Cada uso tem a SUA entrada (mesmo quando comeca com o mesmo ID), assim da para trocar um
-- som sem mexer nos outros. Uma entrada pode ser uma LISTA { {Id..}, {Id..} }: o jogo sorteia
-- uma a cada vez que toca.
local function id(n) return "rbxassetid://" .. n end
local SONS = {
	-- ARMAS
	Tiro = {
		Padrao = { Id = id(133335170193696), V = 0.45 },      -- pistola
		Pistola = { Id = id(133335170193696), V = 0.45 },
		Rifle = { Id = id(113879008765178), V = 0.32 },
		Estilingue = { Id = id(9119215650), V = 0.5, P = 1.15 },
		LancaChamas = { Id = id(138257634793906), V = 0.22 },
	},
	Capsula = { Id = id(103073385815737), V = 0.18 },          -- capsula caindo
	Golpe = { Id = id(139795256698131), V = 0.38 },                 -- swing corpo a corpo
	Soco = { Id = id(132176641904643), V = 0.5 },              -- impacto do golpe
	Martelo = { Id = id(9120812564), V = 0.6 },                -- martelo de reparo
	Explosao = { Id = id(138533090376585), V = 0.75 },
	Acerto = { Id = id(139520673393967), V = 0.35 },               -- hitmarker
	Abate = { Id = id(139459336979009), V = 0.6 },             -- Verity estoura
	Habilidade = { Id = id(140692796870442), V = 0.45, P = 1.2 },   -- whoosh das habilidades
	Laser = { Id = id(115842676995967), V = 0.35 },            -- torreta / Lovity

	-- ECONOMIA / PROGRESSO
	Moeda = { Id = id(134583420216867), V = 0.35 },
	Compra = { Id = id(80736831159506), V = 0.55 },           -- comprou arma/vida/upgrade
	AreaLiberada = { Id = id(122399158411452), V = 0.8, P = 0.8 },
	Ponte = { Id = id(9120812564), V = 0.35, P = 1.4 },        -- pecas da ponte encaixando
	Revive = { Id = id(1839901317), V = 0.7, P = 0.6 },

	-- WAVES / NUCLEO
	Corneta ={
		{ Id = id(4624851445), V = 0.6},  {Id = id(4624851445), V = 0.6 },  
	},-- comeca a noite (wave)
	Contagem = { Id = id(128707491647978), V = 0.45 },         -- ultimos segundos do dia
	WaveConcluida = { Id = id(122399158411452), V = 0.7, P = 1.1 },
	AlertaNucleo = { Id = id(1839901373), V = 0.4 },       -- Nucleo levando dano
	Derrota = { Id = id(121870043011805), V = 0.7 },
	Coracao = { Id = id(9116795681), V = 0.5 },           -- vida baixa

	-- PERSONAGEM
	Passos = { Id = id(84416955338599), V = 0.2 },
	Pulo = { Id = id(135162567109750), V = 0.25 },
	Queda = { Id = id(132504023010884), V = 0.18, P = 0.6 },

	-- AMBIENTE (loops)
	AmbienteDia = { Id = id(9112749254), V = 0.25 },           -- passaros
	AmbienteNoite = { Id = id(9112764546), V = 0.3 },

	-- inimigos
	PuloInimigo = { Id = id(836796971), V = 0.4 },
	PortalAbrindo = { Id = id(134847459602515), V = 1, P = 0.55 },     -- saida dos veritys abrindo (inicio da noite)

	-- jogador / estruturas levando dano
	JogadorDano = { Id = id(136811265205147), V = 0.45, P = 0.8 },
	EstruturaAcerto = { Id = id(9120858570), V = 0.45 },
	Portal = { Id = id(9125517884), V = 0.32, P = 0.9 },
	RugidoChefe = { Id = id(116576934219692), V = 0.95, P = 0.85 },
	AlertaSpawn = { Id = id(127119919079045), V = 0.45 },

	-- interface
	UIClique = { Id = id(87437544236708), V = 0.5 },
	UIHover = { Id = id(87437544236708), V = 0.12, P = 1.7 },
	UIErro = { Id = id(91660275693179), V = 0.3, P = 1.5 },
	UIAbrir = { Id = id(75547278361612), V = 0.28, P = 1.35 },
	Girar = { Id = id(87437544236708), V = 0.4, P = 0.75 },

	-- estruturas da Loja do Nucleo (tocadas no servidor, posicionais)
	Construir = { Id = id(130869638485735), V = 0.6, P = 0.85 },
	MontarTorreta = { Id = id(451660893), V = 0.45 },
	Quebrar = { Id = id(126645609816652), V = 0.75 },
	Vender = { Id = id(88168334908542), V = 0.5, P = 1.3 },
	TorretaTiro = { Id = id(112348789351877), V = 0.35, P = 1.15 },
	TorretaGelo = { Id = id(122218831341898), V = 0.4, P = 0.75 },
	TorretaFogo = { Id = id(108835547890095), V = 0.3 },
	TorretaPesada = { Id = id(18936762326), V = 0.55, P = 0.9 },
	MinaExplosao = { Id = id(139210252225248), V = 0.85, P = 1.05 },
	DroneCura = { Id = id(132624504008840), V = 0.25, P = 1.6 },
	GeradorZumbido = { Id = id(120250063764346), V = 0.22 },

	-- COLETA (madeira / pedra) e estoque do Nucleo
	MadeiraGolpe = { Id = id(115569575216445), V = 0.7 },      -- machado na arvore
	ArvoreCai = { Id = id(115569575216445), V = 0.9, P = 0.6 },
	PedraGolpe = { Id = id(139818366003696), V = 0.55, P = 1.2 },
	PedraQuebra = { Id = id(126645609816652), V = 0.8, P = 0.85 },
	PegarItem = { Id = id(88442833509532), V = 0.5, P = 1.3 },
	Sugar = { Id = id(9125807267), V = 0.8, P = 1.7 },          -- Nucleo sugando os itens
	Estoque = { Id = id(3120909354), V = 0.45, P = 1.5 },

	-- VERITY BOSS (noite, longe do Nucleo)
	BossSpawn = {
		{ Id = id(78392419910398), V = 1 }, { Id = id(119849669810833), V = 1 },
		{ Id = id(98163403305703), V = 1 }, { Id = id(98093396438828), V = 1 },
	},
	BossPulo = { Id = id(124499547710959), V = 1 },            -- "pe-grande" no chao (com tremor)
	BossAmbiente = { Id = id(672401637), V = 0.35 },          -- baixinho, so ouve quem esta perto
	BossSusto = { Id = id(9125471073), V = 0.9, P = 1.4 },

	-- evolucao do Nucleo
	NucleoEvolui = { Id = id(138826200740867), V = 0.9, P = 0.75 },
	NucleoFanfarra = { Id = id(7024302454), V = 0.7, P = 0.9 },          -- grilos

	-- NUCLEO (efeitos visuais novos)
	NucleoDano = { Id = id(9120858570), V = 0.5, P = 0.7 },          -- impacto no escudo do Nucleo
	NucleoRachando = { Id = id(126645609816652), V = 0.45, P = 0.6 },  -- vida baixa: rachaduras
	NucleoSuga = { Id = id(9125807267), V = 0.8, P = 1.7 },          -- vortice puxando os itens
	NucleoEngole = { Id = id(3120909354), V = 0.5, P = 1.3 },         -- cada item entrando

	-- CHEFES: presenca (tremor e coracao conforme chegam perto)
	ChefePerto = { Id = id(9116795681), V = 0.6, P = 0.8 },           -- batida grave em loop
	ChefePassos = { Id = id(124499547710959), V = 0.5, P = 1.1 },     -- passos pesados perto

	-- GLITCITY
	GlitchEstatica = { Id = id(91660275693179), V = 0.21, P = 0.6 },  -- chiado da cutscene (loop)
	GlitchEstalo = { Id = id(138533090376585), V = 1, P = 0.45 },     -- bass drop da materializacao
	GlitchRugido = { Id = id(116576934219692), V = 0.95, P = 0.7 },
	GlitchEMP = { Id = id(91660275693179), V = 0.27, P = 0.5 },
	GlitchVoxels = { Id = id(130869638485735), V = 0.5, P = 1.6 },
	GlitchMorte = { Id = id(138533090376585), V = 1, P = 0.6 },

	-- ARMADILHAS
	Armadilha = {
		Espinhos = { Id = id(139795256698131), V = 0.3 },
		Gelo = { Id = id(122218831341898), V = 0.25, P = 0.8 },
		Quicador = { Id = id(836796971), V = 0.4 },
		Dardo = { Id = id(9119215650), V = 0.5, P = 1.3 },
		Repulsor = { Id = id(138533090376585), V = 0.3, P = 1.4 },
		Prensa = { Id = id(9120812564), V = 0.6, P = 0.6 },
		Gas = { Id = id(120250063764346), V = 0.2, P = 0.7 },
		Eletrico = { Id = id(115842676995967), V = 0.4, P = 1.5 },
	},

	-- MERCADOR / CORRIDA
	MercadorAbrir = { Id = id(75547278361612), V = 0.3, P = 1.1 },
	MercadorCompra = { Id = id(80736831159506), V = 0.6, P = 0.9 },
	Cansado = { Id = id(136811265205147), V = 0.25, P = 1.3 },       -- stamina zerou

	-- DERROTA (cutscene: o Verity Boss destroi o Nucleo)
	DerrotaAlarme = { Id = id(1839901373), V = 0.5, P = 0.8 },
	DerrotaPouso = { Id = id(124499547710959), V = 1 },
	DerrotaRugido = { Id = id(116576934219692), V = 1, P = 0.75 },
	DerrotaImpacto = { Id = id(138533090376585), V = 0.9, P = 0.7 },
	DerrotaExplosao = { Id = id(139210252225248), V = 1, P = 0.6 },

	-- CLASSES: um som por habilidade (Z, X, C, Q e os efeitos delas)
	Classes = {
		Soldado = {
			GranadaLanca = { Id = id(140692796870442), V = 0.45, P = 1.1 },  -- Z: arremesso
			GranadaExplode = { Id = id(138533090376585), V = 0.75 },
			Onda = { Id = id(9120812564), V = 0.72, P = 0.8 },              -- X: onda de choque
			Grito = { Id = id(4624851445), V = 0.54, P = 1.15 },            -- C: grito de guerra
			ChuvaAlerta = { Id = id(127119919079045), V = 0.32, P = 1.3 },  -- Q: marca da chuva
			ChuvaExplode = { Id = id(139210252225248), V = 0.6, P = 1.1 },
		},
		Ninja = {
			Avanco = { Id = id(139795256698131), V = 0.38, P = 1.4 },       -- Z
			Fumaca = { Id = id(9125517884), V = 0.26, P = 1.45 },           -- X
			Estrelas = { Id = id(87437544236708), V = 0.4, P = 1.12 },      -- C
			EstrelaAcerto = { Id = id(132176641904643), V = 0.35, P = 1.5 },
			Sombras = { Id = id(9125517884), V = 0.32, P = 0.63 },          -- Q
		},
		Engenheiro = {
			Moggity = { Id = id(451660893), V = 0.4 },                      -- Z: torreta (implante)
			MoggityTiro = { Id = id(9119215650), V = 0.35, P = 1.45 },       -- "pop" da ervilha
			MoggityErvilha = { Id = id(132176641904643), V = 0.3, P = 1.6 },  -- ervilha estourando no alvo
			MoggityCarga = { Id = id(120250063764346), V = 0.5, P = 1.6 },    -- brilho antes da rajada
			MoggityRajada = { Id = id(113879008765178), V = 0.25, P = 1.3 },  -- metralhada de ervilhas
			Isca = { Id = id(130869638485735), V = 0.5, P = 1.2 },          -- X
			Plasma = { Id = id(120250063764346), V = 0.22 },                -- C: campo
			PlasmaZap = { Id = id(115842676995967), V = 0.21, P = 1.2 },
			Sobrecarga = { Id = id(120250063764346), V = 0.18, P = 1.3 },   -- Q
		},
		Medico = {
			Lovity = { Id = id(7024302454), V = 0.4, P = 1.3 },             -- Z
			Dardo = { Id = id(9116795681), V = 0.45, P = 1.2 },             -- X: dardo curativo
			Fase = { Id = id(9125517884), V = 0.29, P = 1.26 },             -- C: passo de fase
			Coro = { Id = id(7024302454), V = 0.56, P = 0.99 },             -- Q: coro de lovities
		},
	},
}

-- listas { {Id..}, {Id..} } sorteiam uma entrada sempre que o codigo le .Id/.V/.P
local sorteio = {
	__index = function(t, k)
		if (k == "Id" or k == "V" or k == "P") and #t > 0 then
			local e = t[math.random(1, #t)]
			return e[k]
		end
	end,
}
local function prep(t)
	for _, v in pairs(t) do
		if type(v) == "table" then
			if #v > 0 and rawget(v, "Id") == nil then setmetatable(v, sorteio) else prep(v) end
		end
	end
end
prep(SONS)
return SONS
