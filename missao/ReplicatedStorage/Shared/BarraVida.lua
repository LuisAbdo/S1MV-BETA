-- [BarraVida] Barra de vida segmentada no estilo do video de referencia.
-- A MESMA barra e usada nos jogadores (cliente) e nos inimigos (servidor):
-- moldura escura, 10 segmentos verdes com brilho em cima e um rastro branco
-- que "escorre" depois do dano.
local TweenService = game:GetService("TweenService")

local M = {}

M.Segmentos = 10
M.Verde = Color3.fromRGB(86, 232, 96)
M.VerdeEscuro = Color3.fromRGB(38, 150, 52)
M.Brilho = Color3.fromRGB(175, 255, 170)
M.Fundo = Color3.fromRGB(22, 40, 24)
M.Moldura = Color3.fromRGB(10, 16, 10)

local function frame(props, parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

-- opts: Largura (studs), Altura (studs), Offset (Vector3), MaxDistance
function M.Create(adornee, opts)
	opts = opts or {}
	local w = opts.Largura or 3.6
	local h = opts.Altura or math.max(0.32, w * 0.105)
	local bb = Instance.new("BillboardGui")
	bb.Name = "BarraVida"
	bb.Size = UDim2.new(w, 0, h, 0)
	bb.StudsOffset = opts.Offset or Vector3.new(0, 2.3, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = opts.MaxDistance or 140
	bb.Adornee = adornee

	local border = frame({ Name = "Moldura", Size = UDim2.fromScale(1, 1), BackgroundColor3 = M.Moldura }, bb)
	local inner = frame({ Name = "Fundo", Position = UDim2.fromScale(0.015, 0.16), Size = UDim2.fromScale(0.97, 0.68), BackgroundColor3 = M.Fundo, ClipsDescendants = true }, border)
	local lag = frame({ Name = "Rastro", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, ZIndex = 1 }, inner)
	local fill = frame({ Name = "Preenchimento", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 }, inner)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, M.Brilho),
		ColorSequenceKeypoint.new(0.35, M.Verde),
		ColorSequenceKeypoint.new(1, M.VerdeEscuro),
	})
	grad.Parent = fill
	-- divisorias dos segmentos
	for i = 1, M.Segmentos - 1 do
		frame({ Name = "Divisoria", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / M.Segmentos, 0),
			Size = UDim2.new(0.012, 0, 1, 0), BackgroundColor3 = M.Moldura, BackgroundTransparency = 0.15, ZIndex = 3 }, inner)
	end

	bb.Parent = opts.Parent or adornee

	local obj = { Gui = bb, Fill = fill, Lag = lag, Ratio = 1 }
	local lagTween
	function obj:Set(r)
		r = math.clamp(r or 0, 0, 1)
		if r < self.Ratio then
			fill.Size = UDim2.fromScale(r, 1)
			if lagTween then lagTween:Cancel() end
			lagTween = TweenService:Create(lag, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.18), { Size = UDim2.fromScale(r, 1) })
			lagTween:Play()
		else
			if lagTween then lagTween:Cancel() end
			lag.Size = UDim2.fromScale(r, 1)
			TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(r, 1) }):Play()
		end
		self.Ratio = r
	end
	function obj:Destroy() bb:Destroy() end
	return obj
end

return M
