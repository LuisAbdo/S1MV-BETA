-- [ClassService] Classes: passivas, bonus de time, habilidades Z/X/C e ultimate Q.
-- Cliente so envia a intencao (slot + ponto de mira); servidor valida evolucao, cooldown e alcance.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Classes)

local ClassService = {}
local remotes, estado
local Enemy, Ally, Weapon, Build
local fxFolder
local states = {}
local smokes = {}
local SLOTS = { Z = 1, X = 2, C = 3, Q = 3 }

local function log(...) print("[ClassService]", ...) end
local restoreVisibility -- definida mais abaixo (usada antes em SetFromLobby)

-- efeitos visuais ficam no cliente (ClassesVFX); o servidor so manda o que aconteceu e onde
local function vfx(name, ...)
	remotes.Efeito:FireAllClients("ClasseFX", name, ...)
end
local function now() return workspace:GetServerTimeNow() end

-- UTIL -----------------------------------------------------------------
local function charOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return char, root, hum end
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function groundAt(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { fxFolder, Enemy:Folder(), workspace:FindFirstChild("Aliados"), workspace:FindFirstChild("Moedas") }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), rp)
	return hit and hit.Position or pos
end

local function clampAim(root, aim, maxD)
	local d = flat(aim - root.Position)
	if d.Magnitude < 0.5 then d = flat(root.CFrame.LookVector) * 10 end
	if d.Magnitude > maxD then d = d.Unit * maxD end
	return groundAt(root.Position + d)
end

local function enemiesIn(pos, radius)
	local out = {}
	for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
		local b = mdl:FindFirstChild("Corpo")
		if b and (flat(b.Position - pos)).Magnitude <= radius then table.insert(out, mdl) end
	end
	return out
end

local function hitEnemy(player, mdl, dmg, showNumber)
	if Enemy:Damage(mdl, dmg, player) and showNumber ~= false then
		local b = mdl:FindFirstChild("Corpo")
		if b then remotes.NumeroDano:FireAllClients(b.Position, math.floor(dmg + 0.5), false, player.UserId) end
	end
end

local function fx(shape, color, size, cf, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = o.material or Enum.Material.Neon
	p.Color = color
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fxFolder
	return p
end

local function explosion(pos, radius, color)
	local p = fx(Enum.PartType.Ball, color or Color3.fromRGB(255, 150, 40), Vector3.one, CFrame.new(pos))
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.35)
end

local function ring(pos, radius, color, dur)
	local p = fx(Enum.PartType.Cylinder, color, Vector3.new(0.3, 2, 2), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), { transparency = 0.2 })
	TweenService:Create(p, TweenInfo.new(dur or 0.35), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, (dur or 0.35) + 0.05)
end

local function sparkle(pos, color, n)
	local p = fx(nil, color, Vector3.one, CFrame.new(pos), { transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color); e.LightEmission = 0.7
	e.Size = NumberSequence.new(1, 0); e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(6, 12); e.SpreadAngle = Vector2.new(180, 180); e.Enabled = false
	e.Parent = p; e:Emit(n or 20)
	Debris:AddItem(p, 1.2)
end

local function lob(from, to, color, duration, onLand)
	local ball = fx(Enum.PartType.Ball, color, Vector3.one * 1.2, CFrame.new(from))
	local mid = (from + to) / 2 + Vector3.new(0, 8, 0)
	local t1 = TweenService:Create(ball, TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid })
	t1:Play()
	t1.Completed:Connect(function()
		local t2 = TweenService:Create(ball, TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to + Vector3.new(0, 0.6, 0) })
		t2:Play()
		t2.Completed:Connect(function()
			ball:Destroy()
			onLand()
		end)
	end)
end

-- ESTADO ---------------------------------------------------------------
local function evoMult(st) return 1 + Cfg.BonusPorEvolucao * (st.evo - 1) end

local function setClass(player, name)
	local st = states[player]
	st.class = name
	local q = Cfg.Classes[name].Habilidades.Q
	player:SetAttribute("UltMax", q.Carga or 0)
	st.cd = {}
	st.hits = 0
	player:SetAttribute("Classe", name)
	for slot in pairs(SLOTS) do player:SetAttribute("CD_" .. slot, 0) end
end

-- chamado pelo LobbyService (classe comprada/ativada no Laboratorio)
function ClassService:SetFromLobby(player, name)
	if not states[player] or not Cfg.Classes[name] then return end
	if states[player].class ~= name then
		setClass(player, name)
		restoreVisibility(player)
	end
	player:SetAttribute("ClasseEscolhida", true)
end

function ClassService:GetClass(player)
	local st = states[player]
	return st and st.class
end

function ClassService:InSmoke(pos)
	local t = now()
	for i = #smokes, 1, -1 do
		local s = smokes[i]
		if t > s.untilT then
			table.remove(smokes, i)
		elseif (flat(pos - s.pos)).Magnitude <= s.radius then
			return true
		end
	end
	return false
end

function ClassService:OnWeaponHit(player, n)
	local st = states[player]
	if not st or st.class ~= "Ninja" then return end
	local pas = Cfg.Classes.Ninja.Passiva
	st.hits += n
	if st.hits >= pas.AcertosParaCura then
		st.hits = 0
		local _, root, hum = charOf(player)
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * pas.CuraAcerto)
			sparkle(root.Position, Color3.fromRGB(120, 255, 150), 10)
		end
	end
end

function restoreVisibility(player)
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("TranspOriginal") ~= nil then
			d.Transparency = d:GetAttribute("TranspOriginal")
			d:SetAttribute("TranspOriginal", nil)
		elseif d:IsA("Decal") and d:GetAttribute("TranspOriginal") ~= nil then
			d.Transparency = d:GetAttribute("TranspOriginal")
			d:SetAttribute("TranspOriginal", nil)
		end
	end
	player:SetAttribute("Oculto", false)
	player:SetAttribute("CriticoGarantido", false)
end

function ClassService:ResetRun()
	smokes = {}
	estado:SetAttribute("SobrecargaAte", 0)
	for player, st in pairs(states) do
		st.cd = {}
		st.warcryUntil = 0
		st.shadowUntil = 0
		st.ult = 0
		player:SetAttribute("UltCarga", 0)
		for slot in pairs(SLOTS) do player:SetAttribute("CD_" .. slot, 0) end
		restoreVisibility(player)
	end
end

-- HABILIDADES ------------------------------------------------------------
local A = {}

A.Soldado = {
	Z = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Soldado.Passiva
		local target = clampAim(root, aim, h.Alcance)
		vfx("Granada", root.Position + Vector3.new(0, 2, 0), target + Vector3.new(0, 0.6, 0), h.Atraso)
		task.delay(h.Atraso, function()
			vfx("Explosao", target, h.Raio)
			local dmg = h.Dano * mult * (1 + pas.DanoArea) * (player:GetAttribute("MultDano") or 1)
			for _, mdl in ipairs(enemiesIn(target, h.Raio)) do hitEnemy(player, mdl, dmg) end
		end)
		return true
	end,
	X = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Soldado.Passiva
		local pos = root.Position - Vector3.new(0, 2.5, 0)
		vfx("Onda", player, pos, h.Raio)
		local dmg = h.Dano * mult * (1 + pas.DanoArea) * (player:GetAttribute("MultDano") or 1)
		for _, mdl in ipairs(enemiesIn(root.Position, h.Raio)) do
			local b = mdl:FindFirstChild("Corpo")
			hitEnemy(player, mdl, dmg)
			if b then Enemy:Knockback(mdl, b.Position - root.Position, h.Empurrao) end
			Enemy:Stun(mdl, h.Atordoamento)
		end
		return true
	end,
	C = function(player, st, root, aim, h, mult)
		local untilT = now() + h.Duracao * mult
		local buffed = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local _, r = charOf(pl)
			if r and (r.Position - root.Position).Magnitude <= h.Raio and states[pl] then
				states[pl].warcryUntil = untilT
				table.insert(buffed, pl)
			end
		end
		vfx("Grito", player, root.Position - Vector3.new(0, 2.5, 0), h.Raio, buffed, h.Duracao * mult)
		remotes.Aviso:FireAllClients("GRITO DE GUERRA! +" .. math.floor(h.BonusDano * 100) .. "% de dano")
		return true
	end,
	Q = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Soldado.Passiva
		local center = clampAim(root, aim, h.Alcance)
		local dmg = h.Dano * mult * (1 + pas.DanoArea) * (player:GetAttribute("MultDano") or 1)
		vfx("ChuvaMarca", center, h.Raio, h.Duracao + 0.5)
		task.spawn(function()
			for i = 1, h.Granadas do
				local a = math.random() * math.pi * 2
				local r = math.sqrt(math.random()) * h.Raio
				local p = groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				vfx("GranadaCai", p, h.RaioExplosao, 0.45)
				task.delay(0.45, function()
					if player.Parent then
						for _, mdl in ipairs(enemiesIn(p, h.RaioExplosao)) do hitEnemy(player, mdl, dmg) end
					end
				end)
				task.wait(h.Duracao / h.Granadas)
			end
		end)
		return true
	end,
}

A.Ninja = {
	Z = function(player, st, root, aim, h, mult)
		local dir = flat(aim - root.Position)
		if dir.Magnitude < 0.5 then dir = flat(root.CFrame.LookVector) end
		dir = dir.Unit
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { player.Character, Enemy:Folder(), fxFolder, workspace:FindFirstChild("Aliados") }
		local start = root.Position
		local dist = h.Distancia
		local hit = workspace:Raycast(start, dir * dist, rp)
		if hit then dist = math.max(0, (hit.Position - start).Magnitude - 2) end
		local finish = start + dir * dist
		root.CFrame = CFrame.lookAt(finish, finish + dir)
		local dmg = h.Dano * mult * (player:GetAttribute("MultDano") or 1)
		local hitPos = {}
		for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
			local b = mdl:FindFirstChild("Corpo")
			if b then
				local rel = flat(b.Position - start)
				local along = rel:Dot(dir)
				if along >= -1 and along <= dist + 2 and (rel - dir * along).Magnitude <= h.Largura then
					hitEnemy(player, mdl, dmg)
					if #hitPos < 12 then table.insert(hitPos, b.Position) end
				end
			end
		end
		vfx("Dash", player, start, finish, hitPos)
		return true
	end,
	X = function(player, st, root, aim, h, mult)
		local pos = root.Position - Vector3.new(0, 2, 0)
		local radius = h.Raio
		local dur = h.Duracao * mult
		table.insert(smokes, { pos = pos, radius = radius, untilT = now() + dur })
		vfx("Fumaca", pos, radius, dur)
		-- inimigos dentro perdem o alvo na hora
		for _, mdl in ipairs(enemiesIn(pos, radius)) do Enemy:DropTarget(mdl) end
		return true
	end,
	C = function(player, st, root, aim, h, mult)
		local dir = flat(aim - root.Position)
		if dir.Magnitude < 0.5 then dir = flat(root.CFrame.LookVector) end
		dir = dir.Unit
		local start = root.Position
		local dmg = h.Dano * mult * (player:GetAttribute("MultDano") or 1)
		local dirs = {}
		for i = 1, h.Quantidade do
			local ang = math.rad((i - (h.Quantidade + 1) / 2) * h.Espalhamento)
			local d = (CFrame.Angles(0, ang, 0) * CFrame.new(Vector3.zero, dir)).LookVector
			d = flat(d).Unit
			local finish = start + d * h.Alcance
			table.insert(dirs, d)
			local already = {}
			for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
				local b = mdl:FindFirstChild("Corpo")
				if b and not already[mdl] then
					local rel = flat(b.Position - start)
					local along = rel:Dot(d)
					if along >= 0 and along <= h.Alcance and (rel - d * along).Magnitude <= 2.5 + b.Size.X / 2 then
						already[mdl] = true
						task.delay(along / h.Alcance * 0.35, function()
							if mdl.Parent then
								local bb = mdl:FindFirstChild("Corpo")
								if bb then vfx("ShurikenHit", bb.Position) end
								hitEnemy(player, mdl, dmg)
							end
						end)
					end
				end
			end
		end
		vfx("Shuriken", start, dirs, h.Alcance)
		return true
	end,
	Q = function(player, st, root, aim, h, mult)
		local char = player.Character
		local dur = h.Duracao * mult
		for _, d in ipairs(char:GetDescendants()) do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
				if d:GetAttribute("TranspOriginal") == nil then d:SetAttribute("TranspOriginal", d.Transparency) end
				d.Transparency = 0.82
			end
		end
		player:SetAttribute("Oculto", true)
		player:SetAttribute("CriticoGarantido", true)
		st.shadowUntil = now() + dur
		vfx("Sombra", player, dur)
		task.delay(dur, function()
			if states[player] and now() >= (states[player].shadowUntil or 0) - 0.05 then restoreVisibility(player) end
		end)
		return true
	end,
}

A.Engenheiro = {
	Z = function(player, st, root, aim, h, mult)
		local pos = clampAim(root, aim, h.Distancia)
		vfx("Implantar", pos, Color3.fromRGB(80, 200, 255), 4)
		Ally:SpawnMoggity(player, pos, h, mult * (1 + (estado:GetAttribute("BonusTorreta") or 0)))
		return true
	end,
	X = function(player, st, root, aim, h, mult)
		local pos = clampAim(root, aim, h.Distancia)
		vfx("Implantar", pos, Color3.fromRGB(255, 170, 60), 4)
		Ally:SpawnDecoy(player, pos, { Duracao = h.Duracao * mult, Vida = h.Vida * mult, RaioAtracao = h.RaioAtracao })
		return true
	end,
	C = function(player, st, root, aim, h, mult)
		local pos = clampAim(root, aim, h.Distancia)
		local corePos = pos + Vector3.new(0, 2.6, 0)
		vfx("Plasma", pos, h.Raio, h.Duracao)
		local dmg = h.Dano * mult * (player:GetAttribute("MultDano") or 1)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < h.Duracao and player.Parent do
				local a = math.random() * math.pi * 2
				local r = math.random() * h.Raio
				local p = groundAt(pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				vfx("PlasmaZap", corePos, p, h.RaioExplosao)
				for _, mdl in ipairs(enemiesIn(p, h.RaioExplosao)) do hitEnemy(player, mdl, dmg) end
				task.wait(h.Intervalo)
			end
		end)
		return true
	end,
	Q = function(player, st, root, aim, h, mult)
		estado:SetAttribute("SobrecargaAte", now() + h.Duracao * mult)
		remotes.Aviso:FireAllClients("SOBRECARGA! Torretas atiram 2x")
		vfx("Sobrecarga", h.Duracao * mult)
		return true
	end,
}

A.Medico = {
	Z = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Medico.Passiva
		local pos = clampAim(root, aim, h.Distancia)
		vfx("Implantar", pos, Color3.fromRGB(255, 140, 200), 3)
		Ally:SpawnLovity(player, pos, h, mult * (1 + pas.Cura))
		return true
	end,
	X = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Medico.Passiva
		local dir = flat(aim - root.Position)
		if dir.Magnitude < 0.5 then dir = flat(root.CFrame.LookVector) end
		dir = dir.Unit
		local best, bestScore
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= player then
				local _, r, hum = charOf(pl)
				if r and hum.Health < hum.MaxHealth then
					local rel = flat(r.Position - root.Position)
					if rel.Magnitude <= h.Alcance and rel.Magnitude > 0.1 and rel.Unit:Dot(dir) > 0.6 then
						local score = rel.Magnitude
						if not bestScore or score < bestScore then best, bestScore = pl, score end
					end
				end
			end
		end
		local target = best or player
		local _, tr, th = charOf(target)
		if not th then return false end
		local heal = h.Cura * mult * (1 + pas.Cura)
		th.Health = math.min(th.MaxHealth, th.Health + heal)
		vfx("Cura", root.Position + Vector3.new(0, 1, 0), target, heal)
		return true
	end,
	C = function(player, st, root, aim, h, mult)
		local dir = flat(aim - root.Position)
		if dir.Magnitude < 0.5 then dir = flat(root.CFrame.LookVector) end
		dir = dir.Unit
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { player.Character, Enemy:Folder(), fxFolder, workspace:FindFirstChild("Aliados") }
		local dist = h.Distancia * mult
		local hit = workspace:Raycast(root.Position, dir * dist, rp)
		if hit then dist = math.max(0, (hit.Position - root.Position).Magnitude - 2) end
		local start = root.Position
		local finish = start + dir * dist
		root.CFrame = CFrame.lookAt(finish, finish + dir)
		vfx("Fase", player, start, finish)
		return true
	end,
	Q = function(player, st, root, aim, h, mult)
		local pas = Cfg.Classes.Medico.Passiva
		local lov = Cfg.Classes.Medico.Habilidades.Z
		for i = 1, h.Quantidade do
			local a = i / h.Quantidade * math.pi * 2
			Ally:SpawnLovity(player, root.Position + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7), lov, mult * (1 + pas.Cura))
		end
		vfx("Coro", player, root.Position, h.Quantidade)
		remotes.Aviso:FireAllClients("CORO DE LOVITIES!")
		return true
	end,
}

local function unlocked(st, slot)
	local need = (slot == "Z") and 1 or (slot == "X" and 2 or 3)
	return st.evo >= need
end

local function useAbility(player, slot, aim)
	if typeof(slot) ~= "string" or not SLOTS[slot] then return end
	local st = states[player]
	if not st or not st.class then return end
	if estado:GetAttribute("Fase") == "Derrota" then return end
	if not unlocked(st, slot) then return end
	local _, root = charOf(player)
	if not root then return end
	if typeof(aim) ~= "Vector3" or aim.Magnitude ~= aim.Magnitude then aim = root.Position + root.CFrame.LookVector * 10 end
	local t = now()
	if (st.cd[slot] or 0) > t then return end
	local h = Cfg.Classes[st.class].Habilidades[slot]
	if slot == "Q" and h.Carga and (st.ult or 0) < h.Carga then return end
	local fn = A[st.class] and A[st.class][slot]
	if not fn then return end
	-- estrelas da habilidade compradas no Main Lobby (+X% por estrela)
	local habMult = 1
	pcall(function()
		local t = game:GetService("HttpService"):JSONDecode(player:GetAttribute("HabNiveis") or "{}")
		local lvl = tonumber(t[st.class] and t[st.class][slot]) or 0
		local LCfg = require(Shared.Config.Lobby)
		habMult = 1 + math.clamp(lvl, 0, LCfg.NivelHabMax or 5) * (LCfg.BonusPorNivelHab or 0.08)
	end)
	local ok = fn(player, st, root, aim, h, evoMult(st) * habMult)
	if ok then
		st.cd[slot] = t + h.Cooldown
		player:SetAttribute("CD_" .. slot, st.cd[slot])
		if slot == "Q" and h.Carga then
			st.ult = 0
			player:SetAttribute("UltCarga", 0)
		end
		remotes.Efeito:FireAllClients("Habilidade", player, slot, st.class)
	end
end

-- DEV: troca livre de classe para testes (so desenvolvedores; tudo validado aqui) ----------
local function isDev(player)
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	for _, id in ipairs(Cfg.Desenvolvedores or {}) do
		if player.UserId == id then return true end
	end
	return false
end

local function devSwitch(player, name, evo, opts)
	if not isDev(player) then return end
	local st = states[player]
	if not st or typeof(name) ~= "string" or not Cfg.Classes[name] then return end
	if typeof(evo) ~= "number" or evo ~= evo then evo = st.evo end
	evo = math.clamp(math.floor(evo), 1, 3)
	opts = typeof(opts) == "table" and opts or {}
	setClass(player, name)
	st.evo = evo
	player:SetAttribute("Evolucao", evo)
	player:SetAttribute("ClasseEscolhida", true)
	restoreVisibility(player)
	if opts.UltCheia == true then
		st.ult = Cfg.Classes[name].Habilidades.Q.Carga or 0
		player:SetAttribute("UltCarga", st.ult)
	end
	local _, root = charOf(player)
	if root then vfx("Implantar", root.Position - Vector3.new(0, 2.5, 0), Cfg.Classes[name].Cor, 5) end
	remotes.Aviso:FireClient(player, "[DEV] " .. Cfg.Classes[name].Nome .. " - Evolução " .. evo)
	log("[DEV] " .. player.Name .. " -> " .. name .. " evo " .. evo)
end

-- PASSIVAS / BONUS DE TIME (loop unico) ---------------------------------
local function teamBonuses()
	local present = {}
	for pl, st in pairs(states) do
		if pl.Parent and st.class and pl:GetAttribute("EmJogo") == true and charOf(pl) then present[st.class] = true end
	end
	return present
end

function ClassService:Init()
	remotes = Shared:WaitForChild("Remotes")
	estado = Shared:WaitForChild("EstadoJogo")
	Enemy = require(script.Parent.EnemyService)
	Ally = require(script.Parent.AllyService)
	Weapon = require(script.Parent.WeaponService)
	Build = require(script.Parent.BuildService)
	fxFolder = workspace:WaitForChild("Efeitos", 5) or workspace
	estado:SetAttribute("SobrecargaAte", 0)
	estado:SetAttribute("BonusTorreta", 0)
end

function ClassService:Start()
	local function onPlayer(player)
		states[player] = { evo = Cfg.EvolucaoPadrao, cd = {}, hits = 0, warcryUntil = 0, shadowUntil = 0 }
		player:SetAttribute("Evolucao", Cfg.EvolucaoPadrao)
		player:SetAttribute("MultDano", 1)
		player:SetAttribute("MultVelocidade", 1)
		-- a classe ativa vem do Laboratorio (LobbyService:SetFromLobby)
		setClass(player, Cfg.ClassePadrao)
		player:SetAttribute("ClasseEscolhida", false)
		player:SetAttribute("Dev", isDev(player))
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Oculto", false)
			player:SetAttribute("CriticoGarantido", false)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p) states[p] = nil end)

	remotes.EscolherClasse.OnServerEvent:Connect(function(player, name)
		if typeof(name) ~= "string" or not Cfg.Classes[name] then return end
		local fase = estado:GetAttribute("Fase")
		if Cfg.TrocarSoDeDia and fase == "Noite" then
			remotes.Aviso:FireClient(player, "Troque de classe durante o dia")
			return
		end
		if not Cfg.TodasLiberadasSemLobby then
			local Lobby = require(script.Parent.LobbyService)
			if not Lobby:Owns(player, name) then
				remotes.Aviso:FireClient(player, "Desbloqueie essa classe no Laboratório")
				return
			end
		end
		setClass(player, name)
		player:SetAttribute("ClasseEscolhida", true)
		restoreVisibility(player)
		remotes.Aviso:FireClient(player, "Classe: " .. Cfg.Classes[name].Nome)
		log(player.Name .. " escolheu " .. name)
	end)
	remotes.UsarHabilidade.OnServerEvent:Connect(useAbility)
	local devRemote = remotes:FindFirstChild("TrocarClasseDev")
	if not devRemote then
		devRemote = Instance.new("RemoteEvent")
		devRemote.Name = "TrocarClasseDev"
		devRemote.Parent = remotes
	end
	devRemote.OnServerEvent:Connect(devSwitch)
	-- ULT carrega com abates (como o medidor do video)
	table.insert(Enemy.OnDied, function(_, killerUserId)
		local pl = killerUserId and Players:GetPlayerByUserId(killerUserId)
		local st = pl and states[pl]
		if not st or not st.class then return end
		local maxC = Cfg.Classes[st.class].Habilidades.Q.Carga or 0
		st.ult = math.min(maxC, (st.ult or 0) + 1)
		pl:SetAttribute("UltCarga", st.ult)
	end)

	local acc, regenAcc, baseAcc = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		local step = acc
		acc = 0
		regenAcc += step
		baseAcc += step
		local present = teamBonuses()
		local t = now()
		estado:SetAttribute("BonusTorreta", present.Engenheiro and Cfg.Classes.Engenheiro.BonusTime.DanoTorreta or 0)
		for player, st in pairs(states) do
			if player.Parent then
				local dmg = 1 + (player:GetAttribute("BonusPesquisaDano") or 0)
				if present.Soldado then dmg += Cfg.Classes.Soldado.BonusTime.Dano end
				if (st.warcryUntil or 0) > t then dmg += Cfg.Classes.Soldado.Habilidades.C.BonusDano end
				local spd = 1
				if present.Ninja then spd += Cfg.Classes.Ninja.BonusTime.Velocidade end
				if st.class == "Ninja" then spd += Cfg.Classes.Ninja.Passiva.Velocidade end
				if (st.shadowUntil or 0) > t then spd += Cfg.Classes.Ninja.Habilidades.Q.Velocidade end
				if math.abs((player:GetAttribute("MultDano") or 1) - dmg) > 1e-3 then player:SetAttribute("MultDano", dmg) end
				if math.abs((player:GetAttribute("MultVelocidade") or 1) - spd) > 1e-3 then
					player:SetAttribute("MultVelocidade", spd)
					Weapon:RefreshSpeed(player)
				end
			end
		end
		-- Medico no time: +1 vida/s para todos
		if regenAcc >= 1 then
			regenAcc = 0
			if present.Medico then
				for _, pl in ipairs(Players:GetPlayers()) do
					local _, _, hum = charOf(pl)
					if hum and hum.Health < hum.MaxHealth then hum.Health = math.min(hum.MaxHealth, hum.Health + Cfg.Classes.Medico.BonusTime.Regen) end
				end
			end
		end
		-- B.A.S.E. do Engenheiro: armadura e reparo barato perto das estruturas dele
		if baseAcc >= 1 then
			baseAcc = 0
			local pas = Cfg.Classes.Engenheiro.Passiva
			local engOwned = {}
			for _, st2 in ipairs(CollectionService:GetTagged("Estrutura")) do
				local owner = Players:GetPlayerByUserId(st2:GetAttribute("Dono") or 0)
				if owner and states[owner] and states[owner].class == "Engenheiro" and st2.PrimaryPart then
					table.insert(engOwned, st2.PrimaryPart.Position)
				end
			end
			for _, st2 in ipairs(CollectionService:GetTagged("Estrutura")) do
				local inBase = false
				if st2.PrimaryPart then
					for _, p in ipairs(engOwned) do
						if (p - st2.PrimaryPart.Position).Magnitude <= pas.Raio then inBase = true break end
					end
				end
				st2:SetAttribute("ArmaduraExtra", inBase and pas.Armadura or 0)
				st2:SetAttribute("DescontoReparo", inBase and pas.DescontoReparo or 0)
			end
		end
	end)
	log("Pronto. Classes: " .. table.concat(Cfg.Ordem, ", "))
end

return ClassService
