-- [AllyService] Aliados temporarios das habilidades: MOGGITY (torreta), LOVITY (cura), Isca.
-- Um unico Heartbeat para todos. (Curiosity e Godrity entram na Etapa 8.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassCfg = require(Shared.Config.Classes)
local Modelos = require(Shared:WaitForChild("ModelosArmas"))

-- Reveste o corpo "logico" (que a IA move e anima) com o modelo feito no Blender
-- (ReplicatedStorage.Veritys_Itens). O modelo fica soldado no corpo e o corpo fica invisivel,
-- entao toda a logica e animacao continuam iguais. Retorna false se o item nao existir.
local function dressWith(body, itemName, size, forwardSuffix, hideList)
	local m = Modelos.ItemModel(itemName)
	if not m then return false end
	local _, sz = m:GetBoundingBox()
	local big = math.max(sz.X, sz.Y, sz.Z)
	if big > 0 then m:ScaleTo(size / big) end
	local cf
	cf, sz = m:GetBoundingBox()
	local fwd = Vector3.new(0, 0, -1)
	if forwardSuffix then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name:sub(-#forwardSuffix) == forwardSuffix then
				-- frente = eixo comprido da peca (ex.: o cano), apontando para fora do modelo
				local s = p.Size
				local axis = (s.X >= s.Y and s.X >= s.Z) and p.CFrame.RightVector or ((s.Y >= s.Z) and p.CFrame.UpVector or p.CFrame.LookVector)
				axis = Vector3.new(axis.X, 0, axis.Z)
				if axis.Magnitude > 0.05 then
					axis = axis.Unit
					if axis:Dot(p.Position - cf.Position) < 0 then axis = -axis end
					fwd = axis
				end
				break
			end
		end
	end
	-- base do modelo alinhada com a base do corpo; frente do modelo = frente do corpo
	local pivotPos = Vector3.new(cf.Position.X, cf.Position.Y - sz.Y / 2 + body.Size.Y / 2, cf.Position.Z)
	m.PrimaryPart = nil -- o pivo passa a ser do proprio Model (nao de uma peca)
	m.WorldPivot = CFrame.lookAt(pivotPos, pivotPos + fwd)
	m:PivotTo(body.CFrame)
	m.Name = "Visual"
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = p
		end
	end
	body.Transparency = 1
	for _, d in ipairs(body:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1
		elseif d:IsA("SurfaceGui") then d.Enabled = false end
	end
	for _, h in ipairs(hideList or {}) do h.Transparency = 1 end
	m.Parent = body.Parent
	return true
end

local AllyService = {}
local Enemy, Core, Build
local estado, remotes
local folder, fxFolder
local allies = {}

local function log(...) print("[AllyService]", ...) end

local function baseMesh()
	local t = ServerStorage:WaitForChild("Inimigos"):FindFirstChild("Meshes/Hollow Ball")
	local p = t:Clone()
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ValueBase") then d:Destroy() end
	end
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	return p
end

local function part(parent, size, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Size = size; p.Color = color
	p.Material = o.neon and Enum.Material.Neon or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then p.Shape = o.shape end
	p.Name = o.name or "Peca"
	p.Parent = parent
	return p
end

local function burst(pos, color, n, texture)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Size = Vector3.one; p.Position = pos; p.Parent = fxFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(1.2, 0)
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 6, 0)
	e.Enabled = false
	e.Parent = p
	e:Emit(n or 25)
	Debris:AddItem(p, 2)
end

local function groundAt(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder, fxFolder, Enemy:Folder() }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 15, 0), Vector3.new(0, -60, 0), rp)
	return hit and hit.Position or pos
end

function AllyService:Count() return #allies end

local function register(a)
	if #allies >= ClassCfg.MaxAliados then
		-- remove o mais antigo para abrir espaco
		AllyService:Remove(allies[1], true)
	end
	table.insert(allies, a)
	a.model.Parent = folder
	return a
end

function AllyService:Remove(a, effect)
	local i = table.find(allies, a)
	if i then table.remove(allies, i) end
	if a.removed then return end
	a.removed = true
	if effect then
		if a.kind == "Lovity" then
			-- o cliente faz a despedida (acena, encolhe e explode em coracoes)
			a.model:SetAttribute("Saindo", true)
			Debris:AddItem(a.model, 0.9)
			return
		else
			burst(a.body.Position, Color3.fromRGB(220, 220, 220), 20, "rbxasset://textures/particles/smoke_main.dds")
		end
	end
	a.model:Destroy()
end

function AllyService:ClearAll()
	for i = #allies, 1, -1 do self:Remove(allies[i], false) end
end

-- MOGGITY: torreta temporaria (Verity blindado com canhao)
function AllyService:SpawnMoggity(owner, pos, cfg, mult)
	local g = groundAt(pos)
	local model = Instance.new("Model")
	model.Name = "MOGGITY"
	local body = baseMesh()
	body.Name = "Corpo"
	body.Color = Color3.fromRGB(110, 115, 125)
	body.Material = Enum.Material.Metal
	body.Size = Vector3.one * 4.2
	body.Parent = model
	local helm = part(model, Vector3.new(4.6, 1.2, 4.6), Color3.fromRGB(70, 72, 80), { name = "Elmo" })
	local cano = part(model, Vector3.new(0.9, 0.9, 3.4), Color3.fromRGB(45, 45, 50), { name = "Cano" })
	local luz = part(model, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 180, 40), { neon = true, name = "Luz" })
	model.PrimaryPart = body
	body.CFrame = CFrame.new(g + Vector3.new(0, 2.1, 0))
	dressWith(body, "Moggity", 5.4, "_Canhao", { helm, cano, luz })
	local a = register({ kind = "Moggity", owner = owner, model = model, body = body, parts = { helm = helm, cano = cano, luz = luz },
		ground = g, born = os.clock(), expires = os.clock() + cfg.Duracao, cfg = cfg, mult = mult or 1, last = 0, face = Vector3.new(0, 0, -1), t = 0 })
	burst(g + Vector3.new(0, 2, 0), Color3.fromRGB(255, 190, 60), 20)
	return a
end

-- LOVITY: cura em area. Toda a animacao (chegada do ceu, pulos, coracoes, pulso de cura,
-- despedida) roda no cliente (AliadosCliente); aqui ficam o corpo parado e a logica de cura.
function AllyService:SpawnLovity(owner, pos, cfg, mult)
	local g = groundAt(pos)
	local model = Instance.new("Model")
	model.Name = "LOVITY"
	local body = baseMesh()
	body.Name = "Corpo"
	body.Color = Color3.fromRGB(255, 130, 190)
	body.Size = Vector3.one * 3.6
	body.CFrame = CFrame.new(g + Vector3.new(0, 1.8, 0))
	body.Parent = model
	model.PrimaryPart = body
	dressWith(body, "Lovity", 4.8)
	local t = workspace:GetServerTimeNow()
	model:SetAttribute("Chao", g)
	model:SetAttribute("Raio", cfg.Raio)
	model:SetAttribute("Nasceu", t)
	model:SetAttribute("Expira", t + cfg.Duracao)
	CollectionService:AddTag(model, "Lovity")
	local a = register({ kind = "Lovity", owner = owner, model = model, body = body, ground = g, born = os.clock(),
		expires = os.clock() + cfg.Duracao, cfg = cfg, mult = mult or 1, last = os.clock() + 0.6, face = Vector3.new(0, 0, -1), t = math.random() })
	return a
end

-- ISCA: Verity de papelao que atrai inimigos
function AllyService:SpawnDecoy(owner, pos, cfg)
	local g = groundAt(pos)
	local model = Instance.new("Model")
	model.Name = "Isca"
	local body = part(model, Vector3.new(4, 4, 0.5), Color3.fromRGB(190, 150, 100), { name = "Corpo" })
	body.Material = Enum.Material.Cardboard
	body.CFrame = CFrame.new(g + Vector3.new(0, 3, 0))
	local stand = part(model, Vector3.new(0.4, 2, 0.4), Color3.fromRGB(120, 90, 60), { name = "Suporte" })
	stand.CFrame = CFrame.new(g + Vector3.new(0, 1, 0))
	local face = Instance.new("SurfaceGui"); face.Face = Enum.NormalId.Front; face.Parent = body
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = ":)"; t.TextScaled = true; t.Font = Enum.Font.FredokaOne; t.TextColor3 = Color3.fromRGB(60, 40, 20); t.Parent = face
	local face2 = face:Clone(); face2.Face = Enum.NormalId.Back; face2.Parent = body
	model.PrimaryPart = body
	body.CFrame = CFrame.new(g + Vector3.new(0, 2.3, 0))
	dressWith(body, "Isca", 4.6, nil, { stand })
	local a = register({ kind = "Isca", owner = owner, model = model, body = body, ground = g, born = os.clock(),
		expires = os.clock() + cfg.Duracao, cfg = cfg, hp = cfg.Vida, decoy = true, t = 0 })
	return a
end

-- usado pelo EnemyService
function AllyService:NearestDecoy(pos, maxD)
	local best, bd
	for _, a in ipairs(allies) do
		if a.decoy and not a.removed then
			local d = (Vector3.new(a.ground.X, 0, a.ground.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if d <= (maxD or a.cfg.RaioAtracao) and d <= a.cfg.RaioAtracao and (not bd or d < bd) then best, bd = a, d end
		end
	end
	return best, bd
end

function AllyService:DamageDecoy(a, amount)
	if a.removed then return end
	a.hp -= amount
	TweenService:Create(a.body, TweenInfo.new(0.08), { Color = Color3.fromRGB(255, 120, 100) }):Play()
	task.delay(0.1, function() if a.body.Parent then a.body.Color = Color3.fromRGB(190, 150, 100) end end)
	if a.hp <= 0 then self:Remove(a, true) end
end

local function hop(a, dt, size)
	a.t += dt
	local cyc = (a.t % 0.833) / 0.833
	local h = cyc > 0.22 and cyc < 0.7 and math.sin((cyc - 0.22) / 0.48 * math.pi) * size * 0.6 or 0
	local sq = (cyc < 0.22) and (1 - 0.35 * math.sin(cyc / 0.22 * math.pi)) or 1
	local sy = size * sq
	a.body.Size = Vector3.new(size * (1 + (1 - sq) * 0.3), sy, size * (1 + (1 - sq) * 0.3))
	local c = a.ground + Vector3.new(0, sy / 2 + h, 0)
	a.body.CFrame = CFrame.lookAt(c, c + a.face)
	return c
end

local function tracer(from, to, color)
	local d = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = color
	p.Size = Vector3.new(0.35, 0.35, d)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -d / 2)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.15)
end

function AllyService:Init()
	Enemy = require(script.Parent.EnemyService)
	Core = require(script.Parent.CoreService)
	Build = require(script.Parent.BuildService)
	estado = Shared:WaitForChild("EstadoJogo")
	remotes = Shared:WaitForChild("Remotes")
	folder = workspace:FindFirstChild("Aliados")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Aliados"
		folder.Parent = workspace
	end
	fxFolder = workspace:WaitForChild("Efeitos", 5) or workspace
end

function AllyService:Start()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local enemyList
		for i = #allies, 1, -1 do
			local a = allies[i]
			if a and not a.removed then
				if now >= a.expires then
					self:Remove(a, true)
				elseif a.kind == "Moggity" then
					if not enemyList then
						enemyList = {}
						for _, mdl in ipairs(Enemy:Folder():GetChildren()) do
							local b = mdl:FindFirstChild("Corpo")
							if b then table.insert(enemyList, { model = mdl, pos = b.Position }) end
						end
					end
					local best, bd
					for _, e in ipairs(enemyList) do
						local d = (e.pos - a.ground).Magnitude
						if d <= a.cfg.Alcance and (not bd or d < bd) then best, bd = e, d end
					end
					if best then
						local f = Vector3.new(best.pos.X - a.ground.X, 0, best.pos.Z - a.ground.Z)
						if f.Magnitude > 0.1 then a.face = f.Unit end
					end
					local c = hop(a, dt, 4.2)
					local cf = CFrame.lookAt(c, c + a.face)
					a.parts.helm.CFrame = cf * CFrame.new(0, 1.6, 0)
					a.parts.cano.CFrame = cf * CFrame.new(0, 0.6, -2.6)
					a.parts.luz.CFrame = cf * CFrame.new(0, 2.4, 0)
					local overcharge = (estado:GetAttribute("SobrecargaAte") or 0) > workspace:GetServerTimeNow()
					local cad = a.cfg.Cadencia / (overcharge and 2 or 1)
					if best and now - a.last >= cad then
						a.last = now
						local muzzle = (cf * CFrame.new(0, 0.6, -4.3)).Position
						tracer(muzzle, best.pos, Color3.fromRGB(255, 200, 60))
						local owner = a.owner and a.owner.Parent and a.owner or nil
						Enemy:Damage(best.model, a.cfg.Dano * a.mult, owner)
					end
				elseif a.kind == "Lovity" then
					if now - a.last >= 1 then
						a.last = now
						local heal = a.cfg.Cura * a.mult
						local alvos = {}
						for _, pl in ipairs(Players:GetPlayers()) do
							local char = pl.Character
							local root = char and char:FindFirstChild("HumanoidRootPart")
							local hum = char and char:FindFirstChildOfClass("Humanoid")
							if root and hum and hum.Health > 0 and (root.Position - a.ground).Magnitude <= a.cfg.Raio + 2 then
								hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
								table.insert(alvos, root.Position)
							end
						end
						for _, st in ipairs(CollectionService:GetTagged("Estrutura")) do
							if st.PrimaryPart and (st.PrimaryPart.Position - a.ground).Magnitude <= a.cfg.Raio + 2 then
								Build:Heal(st, heal)
								table.insert(alvos, st.PrimaryPart.Position)
							end
						end
						if (Vector3.new(Core.Position.X, 0, Core.Position.Z) - Vector3.new(a.ground.X, 0, a.ground.Z)).Magnitude <= a.cfg.Raio + 15 then
							local maxV = estado:GetAttribute("CoreVidaMax") or 0
							Core:Heal(maxV * a.cfg.CuraNucleo * a.mult)
							table.insert(alvos, Core.Center)
						end
						-- pulso, feixes e "+N" sao desenhados no cliente
						remotes.Efeito:FireAllClients("LovityCura", a.model, alvos, math.floor(heal + 0.5))
					end
				end
			end
		end
	end)
	log("Pronto")
end

return AllyService
