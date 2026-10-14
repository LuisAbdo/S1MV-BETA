-- [CuriosityCliente] Animacao local da CURIOSITY (flutua, gira para o alvo) e o painel de
-- tarefas (Pesquisa / Envio de suprimentos / Previsao). O cliente so pede; o servidor valida.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Curiosity"))
local remotes = Shared:WaitForChild("Remotes")
local T = Cfg.Tarefas

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local C = {
	mint = Color3.fromRGB(98, 226, 160), cyan = Color3.fromRGB(110, 210, 255), black = Color3.fromRGB(14, 14, 16),
	panel = Color3.fromRGB(20, 20, 24), row = Color3.fromRGB(34, 34, 40), dark = Color3.fromRGB(50, 50, 56),
	grey = Color3.fromRGB(150, 150, 155), white = Color3.new(1, 1, 1), gem = Color3.fromRGB(190, 120, 255),
}
local NOMES = { Verity = "Verity", Falsity = "Falsity", Cruelty = "Cruelty" }

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function label(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or HEAVY
	props.TextColor3 = props.TextColor3 or C.white
	props.BorderSizePixel = 0
	return new("TextLabel", props, parent)
end
local function clock(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%d:%02d", m, s)
end
local function timeMult() return RunService:IsStudio() and Cfg.MultTempoStudio or 1 end

-- ANIMACAO ----------------------------------------------------------------------
local model = workspace:WaitForChild("Curiosity", 60)
local rel, body, baseCF = {}, nil, nil
local yaw = 0
if model then
	body = model:WaitForChild("Corpo", 10)
	baseCF = body and body.CFrame
	if baseCF then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= body and p.Name ~= "Sombra" then rel[p] = baseCF:ToObjectSpace(p.CFrame) end
		end
		local _, y = baseCF:ToOrientation()
		yaw = y
	end
end

local function groundPoint()
	return baseCF and Vector3.new(baseCF.Position.X, baseCF.Position.Y - Cfg.Offset.Y, baseCF.Position.Z)
end

RunService.RenderStepped:Connect(function(dt)
	if not baseCF or not body.Parent then return end
	local t = os.clock()
	local g = groundPoint()
	-- alvo: inimigo mais perto no alcance, senao o jogador mais perto
	local target, bd
	local folder = workspace:FindFirstChild("InimigosAtivos")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local b = m:FindFirstChild("Corpo")
			if b then
				local d = Vector3.new(b.Position.X - g.X, 0, b.Position.Z - g.Z).Magnitude
				if d <= Cfg.Alcance and (not bd or d < bd) then target, bd = b.Position, d end
			end
		end
	end
	if not target then
		for _, pl in ipairs(Players:GetPlayers()) do
			local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - g).Magnitude
				if d < 40 and (not bd or d < bd) then target, bd = r.Position, d end
			end
		end
	end
	local want = yaw
	if target then
		local v = target - baseCF.Position
		if Vector3.new(v.X, 0, v.Z).Magnitude > 0.5 then want = math.atan2(-v.X, -v.Z) end
	else
		want = yaw + dt * 0.4
	end
	local diff = math.atan2(math.sin(want - yaw), math.cos(want - yaw))
	yaw += diff * math.min(1, dt * 6)
	local bob = math.sin(t * 2) * 0.6
	local tilt = math.sin(t * 1.3) * math.rad(4)
	local cf = CFrame.new(baseCF.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
	body.CFrame = cf
	for p, r in pairs(rel) do
		if p.Parent then
			if p.Name == "Lampada" then
				p.CFrame = cf * r * CFrame.new(0, math.sin(t * 4) * 0.1, 0)
			else
				p.CFrame = cf * r
			end
		end
	end
end)

-- PAINEL ---------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "PainelCuriosity", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Enabled = false }, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720), 0.6, 1.4) end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromOffset(640, 520), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, gui)
local head = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.cyan, BorderSizePixel = 0 }, panel)
label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -220, 1, 0), Text = "CURIOSITY", TextSize = 26, TextColor3 = C.black, TextXAlignment = Enum.TextXAlignment.Left }, head)
local gemsLbl = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -54, 0.5, 0), Size = UDim2.fromOffset(150, 32), BackgroundTransparency = 0, BackgroundColor3 = C.black, Text = "0 GEMAS", TextSize = 16, TextColor3 = C.gem }, head)
local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = C.black, BorderSizePixel = 0, Text = "X", FontFace = HEAVY, TextSize = 18, TextColor3 = C.white }, head)
close.MouseButton1Click:Connect(function() gui.Enabled = false end)

local function section(y, text)
	return label({ Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(400, 16), Text = text, TextSize = 12, FontFace = MONO, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Left }, panel)
end

-- fila
section(60, "FILA (máx. " .. Cfg.MaxFila .. " · o tempo corre mesmo com você offline)")
local queueRows = {}
for i = 1, Cfg.MaxFila do
	local r = new("Frame", { Position = UDim2.fromOffset(16, 80 + (i - 1) * 46), Size = UDim2.new(1, -32, 0, 40), BackgroundColor3 = C.row, BorderSizePixel = 0 }, panel)
	local name = label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.45, 0, 1, 0), Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }, r)
	local bar = new("Frame", { Position = UDim2.new(0.47, 0, 0.5, -6), Size = UDim2.new(0.36, 0, 0, 12), BackgroundColor3 = C.black, BorderSizePixel = 0 }, r)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.cyan, BorderSizePixel = 0 }, bar)
	local time = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), Text = "", TextSize = 15, FontFace = MONO, TextXAlignment = Enum.TextXAlignment.Right }, r)
	queueRows[i] = { frame = r, name = name, fill = fill, time = time, bar = bar }
end

local function taskRow(y, titleText, descText)
	local r = new("Frame", { Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 50), BackgroundColor3 = C.row, BorderSizePixel = 0 }, panel)
	local t = label({ Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -190, 0, 22), Text = titleText, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, r)
	local d = label({ Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -190, 0, 18), Text = descText, TextSize = 12, FontFace = BOLD, TextColor3 = C.grey, TextXAlignment = Enum.TextXAlignment.Left }, r)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(160, 36), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Text = "", FontFace = HEAVY, TextSize = 15, TextColor3 = C.black, AutoButtonColor = true }, r)
	return { title = t, desc = d, btn = b }
end

section(180, "PESQUISA — " .. T.Pesquisa.Descricao)
local researchRows = {}
for i, l in ipairs(T.Pesquisa.Ordem) do
	local L = T.Pesquisa.Linhas[l]
	local row = taskRow(200 + (i - 1) * 56, L.Nome, L.Texto .. " por nível")
	row.btn.MouseButton1Click:Connect(function() remotes.CuriosityAcao:FireServer("Pesquisa", l) end)
	researchRows[l] = row
end
section(372, "EXPEDIÇÕES")
local supplyRow = taskRow(392, T.Suprimentos.Nome, T.Suprimentos.Descricao)
supplyRow.btn.MouseButton1Click:Connect(function() remotes.CuriosityAcao:FireServer("Suprimentos") end)
local forecastRow = taskRow(448, T.Previsao.Nome, T.Previsao.Descricao)
forecastRow.btn.MouseButton1Click:Connect(function() remotes.CuriosityAcao:FireServer("Previsao") end)

-- resultado da previsao (fica visivel no canto da tela durante a wave)
local fgui = new("ScreenGui", { Name = "PrevisaoWave", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 11, Enabled = false }, player.PlayerGui)
local fscale = new("UIScale", { Scale = scale.Scale }, fgui)
scale:GetPropertyChangedSignal("Scale"):Connect(function() fscale.Scale = scale.Scale end)
local fcard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(330, 30), BackgroundColor3 = C.black, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, fgui)
new("UIStroke", { Thickness = 2, Color = C.cyan }, fcard)
local ftext = label({ Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "", TextSize = 14, TextColor3 = C.cyan, TextScaled = true }, fcard)
new("UITextSizeConstraint", { MaxTextSize = 15 }, ftext)
local forecastWave

local function decode()
	local raw = player:GetAttribute("CuriosityDados")
	if typeof(raw) ~= "string" then return nil end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and d or nil
end

local function queued(d, tipo, linha)
	local n = 0
	for _, it in ipairs(d.fila or {}) do
		if it.t == tipo and (linha == nil or it.l == linha) then n += 1 end
	end
	return n
end

local function setBtn(btn, enabled, text)
	btn.Text = text
	btn.BackgroundColor3 = enabled and C.cyan or C.dark
	btn.TextColor3 = enabled and C.black or C.grey
	btn.AutoButtonColor = enabled
end

local function refresh()
	local d = decode()
	if not d then return end
	local now = workspace:GetServerTimeNow()
	gemsLbl.Text = tostring(player:GetAttribute("Gemas") or 0) .. " GEMAS"
	local fila = d.fila or {}
	for i, r in ipairs(queueRows) do
		local it = fila[i]
		if it then
			local nome = T[it.t] and T[it.t].Nome or it.t
			if it.t == "Pesquisa" and it.l and T.Pesquisa.Linhas[it.l] then nome = "Pesquisa: " .. T.Pesquisa.Linhas[it.l].Nome end
			r.name.Text = nome
			r.name.TextColor3 = C.white
			local total = math.max(1, it.fim - it.ini)
			local started = now >= it.ini
			r.fill.Size = UDim2.fromScale(started and math.clamp((now - it.ini) / total, 0, 1) or 0, 1)
			r.time.Text = started and clock(it.fim - now) or "na fila"
			r.bar.Visible = true
		else
			r.name.Text = "— vazio —"
			r.name.TextColor3 = C.grey
			r.time.Text = ""
			r.bar.Visible = false
		end
	end
	local full = #fila >= Cfg.MaxFila
	for l, row in pairs(researchRows) do
		local L = T.Pesquisa.Linhas[l]
		local lvl = (d.pesq and d.pesq[l]) or 0
		local q = queued(d, "Pesquisa", l)
		row.title.Text = L.Nome .. "  ·  nível " .. lvl .. "/" .. L.Max .. (q > 0 and ("  (+" .. q .. " na fila)") or "")
		if lvl + q >= L.Max then
			setBtn(row.btn, false, "MÁXIMO")
		else
			local dur = (T.Pesquisa.DuracaoBase + T.Pesquisa.DuracaoPorNivel * (lvl + q)) * timeMult()
			setBtn(row.btn, not full, full and "FILA CHEIA" or ("INICIAR " .. clock(dur)))
		end
	end
	for _, pair in ipairs({ { supplyRow, "Suprimentos" }, { forecastRow, "Previsao" } }) do
		local row, tipo = pair[1], pair[2]
		if queued(d, tipo) > 0 then
			setBtn(row.btn, false, "NA FILA")
		else
			setBtn(row.btn, not full, full and "FILA CHEIA" or ("INICIAR " .. clock(T[tipo].Duracao * timeMult())))
		end
	end
end

remotes.CuriosityInfo.OnClientEvent:Connect(function(kind, info)
	if kind == "abrir" then
		refresh()
		gui.Enabled = true
	elseif kind == "previsao" and typeof(info) == "table" then
		local parts = {}
		for _, e in ipairs(info.lista or {}) do table.insert(parts, tostring(e[2]) .. "x " .. (NOMES[e[1]] or tostring(e[1]))) end
		ftext.Text = "PREVISÃO WAVE " .. tostring(info.wave) .. ":  " .. (#parts > 0 and table.concat(parts, " · ") or "nenhum inimigo")
		forecastWave = info.wave
		fgui.Enabled = true
	end
end)

-- some quando a wave prevista termina
local estado = Shared:WaitForChild("EstadoJogo")
estado:GetAttributeChangedSignal("Wave"):Connect(function()
	if forecastWave and (estado:GetAttribute("Wave") or 0) > forecastWave then fgui.Enabled = false end
end)
estado:GetAttributeChangedSignal("Fase"):Connect(function()
	local f = estado:GetAttribute("Fase")
	if f == "Derrota" or f == "Aguardando" then fgui.Enabled = false end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	if not gui.Enabled then return end
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	refresh()
	-- fecha se o jogador se afastar
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local g = groundPoint()
	if root and g and Vector3.new(root.Position.X - g.X, 0, root.Position.Z - g.Z).Magnitude > Cfg.DistanciaInteracao + 12 then
		gui.Enabled = false
	end
end)
