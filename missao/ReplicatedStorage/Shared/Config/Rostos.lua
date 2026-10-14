-- [Config/Rostos] Rosto de cada personagem (imagens PNG transparentes em assets/rostos no repositorio).
-- Depois de enviar as imagens pelo Asset Manager (Bulk Import), cole aqui o ID de cada uma.
-- 0 = manter o rosto atual. Os modelos em ServerStorage.Inimigos sao atualizados quando o servidor inicia.
return {
	Verity = 0,  -- Rosto_Verity.png  (verde)
	Cruelty = 0, -- Rosto_Cruelty.png (vermelho)
	Falsity = 0, -- Rosto_Falsity.png (azul)
	Lovity = 0,  -- Rosto_Lovity.png  (rosa, aliado do Medico)

	-- qual modelo de ServerStorage.Inimigos usa qual rosto
	Modelos = {
		["Meshes/Hollow Ball"] = "Verity",
		Cruelty = "Cruelty",
		Falsity = "Falsity",
	},
}
