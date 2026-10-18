-- [Config/Rostos] Rosto (decal) de cada personagem. So o NUMERO do ID (sem "rbxassetid://").
-- 0 = manter o rosto atual. Os modelos em ServerStorage.Inimigos sao atualizados quando o servidor inicia.
return {
	Verity = 0,                 -- verde (0 = mantem o rosto do modelo)
	Cruelty = 138633192141672,  -- vermelho
	Falsity = 120621676530648,  -- azul
	Lovity = 85970786896369,    -- rosa, aliado do Medico
	Curiosity = 97190804040803, -- NPC da Curiosity (corpo verde floresta)

	-- qual modelo de ServerStorage.Inimigos usa qual rosto
	Modelos = {
		["Meshes/Hollow Ball"] = "Verity",
		["Cruelty"] = "Cruelty",
		["Falsity"] = "Falsity",
	},
}