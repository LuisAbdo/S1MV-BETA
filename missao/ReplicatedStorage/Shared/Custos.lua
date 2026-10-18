-- [Custos] Custos em materiais (madeira/pedra do estoque do Nucleo), usados no cliente e no servidor.
-- Custo = { Madeira = n, Pedra = n }. Um numero solto vale como madeira.
local M = {}
M.Tipos = { "Madeira", "Pedra" }
M.Icone = { Madeira = "madeira", Pedra = "pedra" } -- texto (so onde nao da para por imagem: avisos, prompts)
M.Nome = { Madeira = "madeira", Pedra = "pedra" }
-- icones usados na interface no lugar das palavras "madeira" e "pedra"
M.IconeId = { Madeira = "rbxassetid://102176390662444", Pedra = "rbxassetid://12085229140" }

function M.Norm(c)
	if typeof(c) == "number" then return { Madeira = c } end
	return c or {}
end

-- "4 madeira + 2 pedra"
function M.Texto(c, mult)
	c = M.Norm(c)
	local t = {}
	for _, k in ipairs(M.Tipos) do
		local v = c[k]
		if v and v > 0 then table.insert(t, math.floor(v * (mult or 1) + 0.5) .. " " .. M.Icone[k]) end
	end
	return #t > 0 and table.concat(t, " + ") or "grátis"
end

function M.Estoque(estado, k) return estado:GetAttribute("Estoque" .. k) or 0 end

-- Monta (ou refaz) dentro de `parent` uma linha "4 [icone] + 2 [icone]" (so no cliente).
-- o = { tamanho, cor, fonte, mult, prefixo, separador, zindex, alinhar, size, pos, anchor, mostrarZero,
--       icone (px), estoque (EstadoJogo: numero fica vermelho se faltar), contorno (Color3) }
function M.Linha(parent, c, o)
	o = o or {}
	local row = parent:FindFirstChild("CustoLinha")
	if not row then
		row = Instance.new("Frame")
		row.Name = "CustoLinha"
		row.BackgroundTransparency = 1
		row.Size = o.size or UDim2.fromScale(1, 1)
		row.Position = o.pos or UDim2.new()
		row.AnchorPoint = o.anchor or Vector2.zero
		row.ZIndex = o.zindex or (parent:IsA("GuiObject") and parent.ZIndex + 1) or 1
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = o.alinhar or Enum.HorizontalAlignment.Center
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.Padding = UDim.new(0, o.espaco or 3)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = row
		row.Parent = parent
	end
	for _, ch in ipairs(row:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	local ts = o.tamanho or 16
	local n = 0
	local function txt(s, color)
		n += 1
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, ts + 4)
		t.Text = s
		t.TextSize = ts
		t.FontFace = o.fonte or Font.fromEnum(Enum.Font.FredokaOne)
		t.TextColor3 = color or o.cor or Color3.new(1, 1, 1)
		t.LayoutOrder = n
		t.ZIndex = row.ZIndex
		if o.contorno then
			local s2 = Instance.new("UIStroke"); s2.Color = o.contorno; s2.Thickness = 1.5; s2.Parent = t
		end
		t.Parent = row
		return t
	end
	local function icon(k)
		n += 1
		local im = Instance.new("ImageLabel")
		im.Name = k
		im.BackgroundTransparency = 1
		local s = o.icone or math.floor(ts * 1.35)
		im.Size = UDim2.fromOffset(s, s)
		im.Image = M.IconeId[k]
		im.ScaleType = Enum.ScaleType.Fit
		im.LayoutOrder = n
		im.ZIndex = row.ZIndex
		im.Parent = row
	end
	c = M.Norm(c)
	local any = false
	for _, k in ipairs(M.Tipos) do
		local v = c[k]
		if o.mostrarZero then v = v or 0 end
		if v and (v > 0 or o.mostrarZero) then
			if any and o.separador ~= false then txt(o.separador or "+", o.corSeparador) end
			local amt = math.floor(v * (o.mult or 1) + 0.5)
			local color
			if o.estoque and M.Estoque(o.estoque, k) < amt then color = o.corFalta or Color3.fromRGB(255, 120, 110) end
			txt((o.prefixo or "") .. amt, color)
			icon(k)
			any = true
		end
	end
	if not any then txt(o.gratis or "grátis") end
	row.Visible = true
	return row
end

function M.Tem(estado, c)
	for k, v in pairs(M.Norm(c)) do if M.Estoque(estado, k) < v then return false end end
	return true
end

-- "Faltam 3 madeira e 2 pedra" (ou nil)
function M.Falta(estado, c)
	local t = {}
	for _, k in ipairs(M.Tipos) do
		local v = M.Norm(c)[k]
		local have = M.Estoque(estado, k)
		if v and have < v then table.insert(t, (v - have) .. " " .. M.Nome[k]) end
	end
	if #t == 0 then return nil end
	return "Faltam " .. table.concat(t, " e ")
end

return M
