-- [Custos] Custos em materiais (madeira/pedra do estoque do Nucleo), usados no cliente e no servidor.
-- Custo = { Madeira = n, Pedra = n }. Um numero solto vale como madeira.
local M = {}
M.Tipos = { "Madeira", "Pedra" }
M.Icone = { Madeira = "madeira", Pedra = "pedra" } -- (emoji de tora/pedra nao renderiza no Roblox)
M.Nome = { Madeira = "madeira", Pedra = "pedra" }

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
