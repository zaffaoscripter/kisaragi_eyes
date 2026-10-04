-- ==================== Anti-Re-Execution ====================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local guiParent = (gethui and gethui()) or CoreGui
if guiParent:FindFirstChild("KisaragiEyes_Gui") then
	warn("[Kisaragi Eyes]: O script já está em execução! Cancelando duplicada.")
	return
end

-- ==================== Services & Locals ====================
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end)

-- Localizando globais para extrema performance
local os_clock = os.clock
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB
local ColorSequence_new = ColorSequence.new
local sin, floor, clamp, min, max, abs = math.sin, math.floor, math.clamp, math.min, math.max, math.abs

local TWEEN_SWITCH = TweenInfo.new(0.2)
local HEAD_OFF = Vector3_new(0, 0.8, 0)
local FEET_OFF = Vector3_new(0, -3, 0)
local CHEST_OFF = Vector3_new(0, 1.2, 0)

-- ==================== Config & Save ====================
local Config = {
	NameEnabled = true,
	HpEnabled = true,
	AuraEnabled = true,
	GlowEnabled = true,
	BlindnessEnabled = false,
	SelfAuraColor = Color3_fromRGB(115, 10, 30),
}

local SAVE_FILE_NAME = "KisaragiEyes_Data.json"

local originalLighting = {
	Brightness = Lighting.Brightness,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Ambient = Lighting.Ambient,
	GlobalShadows = Lighting.GlobalShadows,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
}

local colorCorrection
local playerData = {}
local screenGui
local selectedPlayer

local function saveConfig()
	if not writefile then return end
	pcall(function()
		local rawData = {
			SelfAuraColor = { Config.SelfAuraColor.R, Config.SelfAuraColor.G, Config.SelfAuraColor.B },
			Players = {},
		}
		for userId, data in pairs(playerData) do
			rawData.Players[tostring(userId)] = {
				Color = { data.Color.R, data.Color.G, data.Color.B },
				CustomName = data.CustomName,
				GlowActive = data.GlowActive,
			}
		end
		writefile(SAVE_FILE_NAME, HttpService:JSONEncode(rawData))
	end)
end

local function loadConfig()
	if not (readfile and isfile and isfile(SAVE_FILE_NAME)) then return end
	pcall(function()
		local decoded = HttpService:JSONDecode(readfile(SAVE_FILE_NAME))
		if decoded.SelfAuraColor then
			Config.SelfAuraColor = Color3_new(decoded.SelfAuraColor[1], decoded.SelfAuraColor[2], decoded.SelfAuraColor[3])
		end
		local playersList = decoded.Players or decoded
		for userIdStr, data in pairs(playersList) do
			local uid = tonumber(userIdStr)
			if uid and type(data) == "table" and data.Color then
				playerData[uid] = {
					Color = Color3_new(data.Color[1], data.Color[2], data.Color[3]),
					CustomName = data.CustomName or "",
					GlowActive = data.GlowActive or false,
				}
			end
		end
	end)
end
loadConfig()

local function getPlayerData(player)
	local uid = player.UserId
	local data = playerData[uid]
	if not data then
		data = { Color = Color3_fromRGB(220, 225, 235), CustomName = "", GlowActive = false }
		playerData[uid] = data
	end
	return data
end

-- ==================== Esferas de tela ====================
local PARTICLE_COUNT = 50
local WHITE = Color3_new(1, 1, 1)
local activeParticles = {}
local particlesReady = false
local hasDrawing = pcall(function() return Drawing ~= nil end)

local function setParticleMovement(pData)
	local angle = math.random() * math.pi * 2
	local baseSpeed = math.random(15, 35) / 10
	local depthMult = (pData.Depth == 1) and 1 or (pData.Depth == 2 and 2.5 or 4)
	local finalSpeed = baseSpeed * depthMult
	pData.SpeedX = math.cos(angle) * finalSpeed
	pData.SpeedY = sin(angle) * finalSpeed
end

local function clearParticles()
	for i = 1, #activeParticles do
		local p = activeParticles[i]
		if p.Circle then
			pcall(function() p.Circle:Remove() end)
		end
		activeParticles[i] = nil
	end
	particlesReady = false
end

local function createParticle()
	local viewportSize = Camera.ViewportSize
	if viewportSize.X == 0 or viewportSize.Y == 0 then return end
	if not hasDrawing then return end

	local depth = math.random(1, 3)
	local radiusMap = { math.random(1, 2), math.random(2, 3), math.random(4, 5) }
	local radius = radiusMap[depth] * 0.55
	local startX = math.random(10, max(11, viewportSize.X - 10))
	local startY = math.random(10, max(11, viewportSize.Y - 10))
	local alphaMap = { 0.5, 0.25, 0.05 }

	local ok, circle = pcall(function()
		local c = Drawing.new("Circle")
		c.Filled = true
		c.NumSides = (depth == 3) and 12 or 8
		c.Thickness = (depth == 3) and 1.4 or 0.8
		c.Color = WHITE
		c.Radius = radius
		c.Position = Vector2_new(startX, startY)
		c.Transparency = alphaMap[depth]
		c.Visible = true
		c.ZIndex = depth
		return c
	end)
	if not ok or not circle then return end

	local pData = {
		Circle = circle,
		Depth = depth,
		ExactX = startX,
		ExactY = startY,
		PulseSpeed = math.random(10, 30) / 10,
		BaseTransparency = alphaMap[depth],
		Seed = math.random(1, 1000),
		AlphaOffset = (depth == 1) and 0.35 or 0.2,
		LastT = -1,
		lastX = startX,
		lastY = startY,
	}
	setParticleMovement(pData)
	activeParticles[#activeParticles + 1] = pData
end

local function setupParticles()
	clearParticles()
	for _ = 1, PARTICLE_COUNT do
		createParticle()
	end
	particlesReady = #activeParticles > 0
end

-- ==================== Aura própria ====================
local function stripLegacySelfParticles(char)
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local emitter = root:FindFirstChild("KisaragiSelfParticles")
		if emitter then emitter:Destroy() end
	end
	local leftover = char:FindFirstChild("KisaragiSelfParticles")
	if leftover then leftover:Destroy() end
end

local function updateSelfAura(enable)
	local char = LocalPlayer.Character
	if not char then return end

	stripLegacySelfParticles(char)

	local selfHighlight = char:FindFirstChild("KisaragiSelfAura")
	if enable then
		if not selfHighlight then
			selfHighlight = Instance.new("Highlight")
			selfHighlight.Name = "KisaragiSelfAura"
			selfHighlight.Adornee = char
			selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			selfHighlight.FillTransparency = 0.5
			selfHighlight.OutlineTransparency = 0
			selfHighlight.Parent = char
		end
		selfHighlight.FillColor = Config.SelfAuraColor
		selfHighlight.OutlineColor = Config.SelfAuraColor
		selfHighlight.Enabled = true
	elseif selfHighlight then
		selfHighlight:Destroy()
	end
end

-- ==================== Cegueira ====================
local function setBlindnessMode(enable)
	Config.BlindnessEnabled = enable

	if enable then
		originalLighting.Brightness = Lighting.Brightness
		originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
		originalLighting.Ambient = Lighting.Ambient
		originalLighting.GlobalShadows = Lighting.GlobalShadows
		originalLighting.FogStart = Lighting.FogStart
		originalLighting.FogEnd = Lighting.FogEnd
		originalLighting.FogColor = Lighting.FogColor

		Lighting.Brightness = 0
		Lighting.OutdoorAmbient = Color3_new(0, 0, 0)
		Lighting.Ambient = Color3_new(0, 0, 0)
		Lighting.GlobalShadows = true
		Lighting.FogStart = 0
		Lighting.FogEnd = 1
		Lighting.FogColor = Color3_new(0, 0, 0)

		if not colorCorrection then
			colorCorrection = Instance.new("ColorCorrectionEffect")
			colorCorrection.Name = "KisaragiBlindnessCC"
			colorCorrection.Brightness = -1
			colorCorrection.Contrast = 1
			colorCorrection.Saturation = -1
			colorCorrection.TintColor = Color3_new(0, 0, 0)
			colorCorrection.Parent = Lighting
		end
		colorCorrection.Enabled = true
		updateSelfAura(true)
		setupParticles()
	else
		Lighting.Brightness = originalLighting.Brightness
		Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
		Lighting.Ambient = originalLighting.Ambient
		Lighting.GlobalShadows = originalLighting.GlobalShadows
		Lighting.FogStart = originalLighting.FogStart
		Lighting.FogEnd = originalLighting.FogEnd
		Lighting.FogColor = originalLighting.FogColor

		if colorCorrection then colorCorrection.Enabled = false end
		updateSelfAura(false)
		clearParticles()
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	if Config.BlindnessEnabled then updateSelfAura(true) end
end)

-- ==================== ESP ====================
local GLIM_TEXTURE = "rbxassetid://867619398"
local GLOW_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.85),
	NumberSequenceKeypoint.new(1, 1),
})
local GLOW_SIZE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.8),
	NumberSequenceKeypoint.new(1, 2.5),
})
local GLOW_RATE = 2
local GLOW_PARTS = { Head = true, Torso = true, UpperTorso = true, LowerTorso = true }

local espObjects = {}
local espList = {}

local function createDrawing(className, props)
	if not hasDrawing then return nil end
	local ok, obj = pcall(function()
		local d = Drawing.new(className)
		for k, v in pairs(props) do d[k] = v end
		return d
	end)
	return ok and obj or nil
end

local function applyHighlight(character)
	local hl = character:FindFirstChild("KisaragiHighlight")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "KisaragiHighlight"
		hl.FillTransparency = 0.85
		hl.OutlineTransparency = 0.5
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = character
	end
	return hl
end

local function applyGlowToLimbs(character)
	local glows = {}
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and GLOW_PARTS[part.Name] then
			local emitter = part:FindFirstChild("KisaragiLimbGlow")
			if not emitter then
				emitter = Instance.new("ParticleEmitter")
				emitter.Name = "KisaragiLimbGlow"
				emitter.Texture = GLIM_TEXTURE
				emitter.LightEmission = 0.8
				emitter.ZOffset = 0.5
				emitter.Transparency = GLOW_TRANSPARENCY
				emitter.Size = GLOW_SIZE
				emitter.Lifetime = NumberRange.new(1, 1.5)
				emitter.Speed = NumberRange.new(0.1, 0.4)
				emitter.Rate = GLOW_RATE
				emitter.Enabled = false
				emitter.Parent = part
			end
			glows[#glows + 1] = emitter
		end
	end
	return glows
end

local function hideHp(obj)
	if obj.hpShown then
		local hpBar = obj.hpBar
		if hpBar then
			hpBar.bg.Visible = false
			hpBar.fg.Visible = false
		end
		obj.hpShown = false
	end
end

local function hideDrawings(obj)
	if obj.drawn then
		if obj.label then obj.label.Visible = false end
		hideHp(obj)
		obj.drawn = false
	end
end

local function removeESP(character)
	local obj = espObjects[character]
	if not obj then return end
	if obj.label then pcall(function() obj.label:Remove() end) end
	if obj.hpBar then
		pcall(function()
			obj.hpBar.bg:Remove()
			obj.hpBar.fg:Remove()
		end)
	end
	if obj.hl then pcall(function() obj.hl:Destroy() end) end
	if obj.glows then
		for i = 1, #obj.glows do
			pcall(function() obj.glows[i]:Destroy() end)
		end
	end
	local idx = obj.index
	local last = espList[#espList]
	if idx and last then
		espList[idx] = last
		last.index = idx
		espList[#espList] = nil
	end
	espObjects[character] = nil
end

local function createESP(character, player)
	if espObjects[character] then return end
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 8)
	end
	if not character.Parent or espObjects[character] then return end

	local label = createDrawing("Text", {
		Size = 15, Center = true, Outline = true, Font = 2,
		Color = Color3_new(1, 1, 1), OutlineColor = Color3_new(0, 0, 0), Visible = false,
	})
	local bgBar = createDrawing("Square", {
		Filled = true, Color = Color3_new(0, 0, 0), Visible = false, ZIndex = 1, Thickness = 1,
	})
	local fgBar = createDrawing("Square", {
		Filled = true, Color = Color3_fromRGB(0, 255, 0), Visible = false, ZIndex = 2, Thickness = 1,
	})

	local data = getPlayerData(player)
	
	-- Cached Raycast Params para ultra performance
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local rayFilter = { LocalPlayer.Character, character }
	rayParams.FilterDescendantsInstances = rayFilter

	local obj = {
		character = character, label = label, hpBar = (bgBar and fgBar) and { bg = bgBar, fg = fgBar } or nil,
		hl = applyHighlight(character), glows = nil, player = player, data = data,
		hum = character:FindFirstChildOfClass("Humanoid"),
		root = character:FindFirstChild("HumanoidRootPart"),
		head = character:FindFirstChild("Head"),
		rayParams = rayParams, rayFilter = rayFilter,
		lastGlowColor = nil, lastGlowOn = false, lastHlColor = nil, lastHlOn = nil,
		lastFillT = -1, lastText = "", lastDist = -1, los = false, drawn = false, hpShown = false, labelShown = false,
		lastLx = -999, lastLy = -999,
		lastBgX = -999, lastBgY = -999, lastBgH = -999,
		lastFgX = -999, lastFgY = -999, lastFgH = -999,
	}

	character.ChildAdded:Connect(function(ch)
		if ch.Name == "HumanoidRootPart" then obj.root = ch
		elseif ch.Name == "Head" then obj.head = ch
		elseif ch:IsA("Humanoid") then obj.hum = ch end
	end)

	espList[#espList + 1] = obj
	obj.index = #espList
	espObjects[character] = obj
end

-- ==================== Render (Loop Otimizado) ====================
local EDGE_MARGIN = 25
local frameId = 0
local lastPulseT = 0
local pulse = 0

RunService.RenderStepped:Connect(function(dt)
	local cam = Camera
	if not cam then return end

	frameId += 1
	local now = os_clock()
	if now - lastPulseT >= 0.05 then
		lastPulseT = now
		pulse = (sin(now * 1.5) + 1) * 0.05
	end

	if Config.BlindnessEnabled and particlesReady then
		local viewportSize = cam.ViewportSize
		local vx, vy = viewportSize.X, viewportSize.Y
		for i = 1, #activeParticles do
			local p = activeParticles[i]
			local circle = p.Circle
			if circle then
				local x = p.ExactX + p.SpeedX * dt
				local y = p.ExactY + p.SpeedY * dt
				if x < -15 then x = vx + 10; setParticleMovement(p)
				elseif x > vx + 15 then x = -10; setParticleMovement(p) end
				if y < -15 then y = vy + 10; setParticleMovement(p)
				elseif y > vy + 15 then y = -10; setParticleMovement(p) end
				
				p.ExactX, p.ExactY = x, y
				
				if abs(p.lastX - x) > 0.2 or abs(p.lastY - y) > 0.2 then
					circle.Position = Vector2_new(x, y)
					p.lastX, p.lastY = x, y
				end

				local edgeAlpha = min(y, vy - y, x, vx - x) / EDGE_MARGIN
				if edgeAlpha < 0 then edgeAlpha = 0 elseif edgeAlpha > 1 then edgeAlpha = 1 end
				local wave = (sin(now * p.PulseSpeed + p.Seed) + 1) * 0.5
				local baseT = p.BaseTransparency + wave * p.AlphaOffset
				if baseT < 0 then baseT = 0 elseif baseT > 0.95 then baseT = 0.95 end
				
				local finalT = 1 - ((1 - baseT) * edgeAlpha)
				if p.LastT ~= finalT then
					p.LastT = finalT
					circle.Transparency = finalT
				end
			end
		end
	end

	local camPos = cam.CFrame.Position
	local auraOn = Config.AuraEnabled
	local glowOn = auraOn and Config.GlowEnabled
	local namesOn = Config.NameEnabled
	local hpOn = Config.HpEnabled
	local fillT = 0.85 + pulse

	for i = 1, #espList do
		local obj = espList[i]
		local character = obj.character
		if not character.Parent then
			hideDrawings(obj)
			continue
		end

		local data = obj.data
		local color = data.Color
		local hl = obj.hl

		if hl then
			if obj.lastHlOn ~= auraOn then
				hl.Enabled = auraOn
				obj.lastHlOn = auraOn
			end
			if auraOn then
				if obj.lastHlColor ~= color then
					hl.FillColor = color
					hl.OutlineColor = color
					obj.lastHlColor = color
				end
				if obj.lastFillT ~= fillT then
					hl.FillTransparency = fillT
					obj.lastFillT = fillT
				end
			end
		end

		local shouldGlow = glowOn and data.GlowActive
		if shouldGlow and not obj.glows then obj.glows = applyGlowToLimbs(character) end
		if obj.glows and (shouldGlow ~= obj.lastGlowOn or (shouldGlow and obj.lastGlowColor ~= color)) then
			local seq = shouldGlow and ColorSequence_new(color) or nil
			for g = 1, #obj.glows do
				local emitter = obj.glows[g]
				if emitter.Parent then
					emitter.Enabled = shouldGlow
					if seq then emitter.Color = seq end
				end
			end
			obj.lastGlowOn = shouldGlow
			obj.lastGlowColor = color
		end

		if not namesOn and not hpOn then
			hideDrawings(obj)
			continue
		end

		local hum, root, head = obj.hum, obj.root, obj.head
		if not (hum and root and head and hum.Health > 0) then
			hideDrawings(obj)
			continue
		end

		local rootPos = root.Position
		local topPos, topVis = cam:WorldToViewportPoint(head.Position + HEAD_OFF)
		if not (topVis and topPos.Z > 0) then
			hideDrawings(obj)
			continue
		end

		obj.drawn = true
		local label = obj.label
		if label then
			if namesOn then
				local distFloor = floor((camPos - rootPos).Magnitude)
				local posX, posY = topPos.X, topPos.Y - 18
				
				if obj.lastDist ~= distFloor then
					obj.lastDist = distFloor
					local displayName = (data.CustomName ~= "") and data.CustomName or obj.player.Name
					label.Text = displayName .. " [" .. distFloor .. "m]"
				end
				
				if obj.lastLabelColor ~= color then
					label.Color = color
					obj.lastLabelColor = color
				end
				
				if abs(obj.lastLx - posX) > 0.5 or abs(obj.lastLy - posY) > 0.5 then
					obj.lastLx = posX
					obj.lastLy = posY
					label.Position = Vector2_new(posX, posY)
				end

				if not obj.labelShown then
					label.Visible = true
					obj.labelShown = true
				end
			elseif obj.labelShown then
				label.Visible = false
				obj.labelShown = false
			end
		end

		local hpBar = obj.hpBar
		if hpBar then
			local showHp = false
			if hpOn then
				if (frameId + i) % 3 == 0 then
					local localChar = LocalPlayer.Character
					if obj.rayFilter[1] ~= localChar then
						obj.rayFilter[1] = localChar
						obj.rayParams.FilterDescendantsInstances = obj.rayFilter
					end
					obj.los = workspace:Raycast(camPos, (rootPos + CHEST_OFF) - camPos, obj.rayParams) == nil
				end
				
				if obj.los then
					local bottomPos, bottomVis = cam:WorldToViewportPoint(rootPos + FEET_OFF)
					if bottomVis then
						showHp = true
						local fullHeight = bottomPos.Y - topPos.Y
						local height = fullHeight * 0.70
						local width = clamp(fullHeight * 0.5, 10, 150)
						
						local barX = topPos.X + (width * 0.5) + 8
						local startY = topPos.Y + (fullHeight * 0.15)
						local hpPercent = clamp(hum.Health / hum.MaxHealth, 0, 1)
						local fillHeight = height * hpPercent
						
						-- Caching para prevenir FPS drop massivo
						if abs(obj.lastBgX - barX) > 0.5 or abs(obj.lastBgY - startY) > 0.5 then
							obj.lastBgX, obj.lastBgY = barX, startY
							hpBar.bg.Position = Vector2_new(barX, startY)
						end
						if abs(obj.lastBgH - height) > 0.5 then
							obj.lastBgH = height
							hpBar.bg.Size = Vector2_new(4, height)
						end
						
						local fgX = barX + 1
						local fgY = startY + 1 + (height - fillHeight)
						local fgH = max(0, fillHeight - 2)
						
						if abs(obj.lastFgX - fgX) > 0.5 or abs(obj.lastFgY - fgY) > 0.5 then
							obj.lastFgX, obj.lastFgY = fgX, fgY
							hpBar.fg.Position = Vector2_new(fgX, fgY)
						end
						if abs(obj.lastFgH - fgH) > 0.5 then
							obj.lastFgH = fgH
							hpBar.fg.Size = Vector2_new(2, fgH)
						end

						if obj.lastHpColor ~= color then
							hpBar.fg.Color = color
							obj.lastHpColor = color
						end
						
						if not obj.hpShown then
							hpBar.bg.Visible = true
							hpBar.fg.Visible = true
							obj.hpShown = true
						end
					end
				end
			end
			if not showHp then hideHp(obj) end
		end
	end
end)

-- ==================== Hooks ====================
local function hookPlayer(player)
	if player == LocalPlayer then return end
	player.CharacterAdded:Connect(function(char) task.spawn(createESP, char, player) end)
	player.CharacterRemoving:Connect(removeESP)
	if player.Character then task.spawn(createESP, player.Character, player) end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p)
	if p.Character then removeESP(p.Character) end
	if selectedPlayer == p then selectedPlayer = nil end
end)

-- ==================== Paletas ====================
local SELF_COLOR_CATEGORIES = {
	{ Category = "Vermelho", MainColor = Color3_fromRGB(255, 0, 0), Variations = {
		{ Name = "Vinho (Padrão)", Color = Color3_fromRGB(115, 10, 30) }, { Name = "Vermelho Puro", Color = Color3_fromRGB(255, 0, 0) }, { Name = "Escarlate", Color = Color3_fromRGB(255, 45, 0) }, { Name = "Carmim", Color = Color3_fromRGB(180, 0, 40) } } },
	{ Category = "Azul", MainColor = Color3_fromRGB(0, 120, 255), Variations = {
		{ Name = "Azul Principal", Color = Color3_fromRGB(0, 120, 255) }, { Name = "Azul Marinho", Color = Color3_fromRGB(15, 30, 110) }, { Name = "Azul Ciano", Color = Color3_fromRGB(0, 220, 255) }, { Name = "Azul Cobalto", Color = Color3_fromRGB(20, 80, 200) } } },
	{ Category = "Amarelo", MainColor = Color3_fromRGB(255, 230, 0), Variations = {
		{ Name = "Amarelo Principal", Color = Color3_fromRGB(255, 230, 0) }, { Name = "Dourado", Color = Color3_fromRGB(255, 195, 0) }, { Name = "Amarelo Limão", Color = Color3_fromRGB(230, 255, 50) }, { Name = "Âmbar", Color = Color3_fromRGB(255, 140, 0) } } },
	{ Category = "Verde", MainColor = Color3_fromRGB(0, 220, 100), Variations = {
		{ Name = "Verde Principal", Color = Color3_fromRGB(0, 220, 100) }, { Name = "Verde Esmeralda", Color = Color3_fromRGB(0, 180, 90) }, { Name = "Verde Menta", Color = Color3_fromRGB(80, 255, 160) }, { Name = "Verde Musgo", Color = Color3_fromRGB(30, 90, 40) } } },
	{ Category = "Roxo", MainColor = Color3_fromRGB(150, 40, 255), Variations = {
		{ Name = "Roxo Principal", Color = Color3_fromRGB(150, 40, 255) }, { Name = "Violeta Escuro", Color = Color3_fromRGB(80, 10, 160) }, { Name = "Lilás", Color = Color3_fromRGB(200, 140, 255) }, { Name = "Magenta", Color = Color3_fromRGB(230, 0, 180) } } },
	{ Category = "Laranja", MainColor = Color3_fromRGB(255, 130, 0), Variations = {
		{ Name = "Laranja Principal", Color = Color3_fromRGB(255, 130, 0) }, { Name = "Laranja Fogo", Color = Color3_fromRGB(255, 70, 0) }, { Name = "Pêssego", Color = Color3_fromRGB(255, 170, 120) }, { Name = "Terracota", Color = Color3_fromRGB(180, 75, 30) } } },
	{ Category = "Neutro / Monocromático", MainColor = Color3_fromRGB(255, 255, 255), Variations = {
		{ Name = "Branco Puro", Color = Color3_fromRGB(255, 255, 255) }, { Name = "Platina", Color = Color3_fromRGB(210, 215, 225) }, { Name = "Grafite", Color = Color3_fromRGB(80, 80, 95) }, { Name = "Sombra", Color = Color3_fromRGB(25, 20, 30) } } },
}

local PLAYER_COLOR_CATEGORIES = {
	{ Category = "Vermelhos & Rosas", MainColor = Color3_fromRGB(255, 0, 0), Variations = {
		{ Name = "Vermelho", Color = Color3_fromRGB(255, 0, 0) }, { Name = "Carmim", Color = Color3_fromRGB(220, 20, 60) }, { Name = "Escarlate", Color = Color3_fromRGB(255, 36, 0) }, { Name = "Bordô", Color = Color3_fromRGB(128, 0, 32) }, { Name = "Rubi", Color = Color3_fromRGB(155, 17, 30) }, { Name = "Coral", Color = Color3_fromRGB(255, 127, 80) }, { Name = "Salmão", Color = Color3_fromRGB(250, 128, 114) }, { Name = "Rosa", Color = Color3_fromRGB(255, 105, 180) }, { Name = "Magenta", Color = Color3_fromRGB(255, 0, 255) } } },
	{ Category = "Azuis & Cianos", MainColor = Color3_fromRGB(0, 120, 255), Variations = {
		{ Name = "Azul", Color = Color3_fromRGB(0, 120, 255) }, { Name = "Ciano", Color = Color3_fromRGB(0, 230, 255) }, { Name = "Turquesa", Color = Color3_fromRGB(64, 224, 208) }, { Name = "Safira", Color = Color3_fromRGB(15, 82, 186) }, { Name = "Cobalto", Color = Color3_fromRGB(0, 71, 171) }, { Name = "Anil", Color = Color3_fromRGB(15, 82, 186) } } },
	{ Category = "Verdes", MainColor = Color3_fromRGB(0, 220, 100), Variations = {
		{ Name = "Verde", Color = Color3_fromRGB(0, 220, 100) }, { Name = "Esmeralda", Color = Color3_fromRGB(80, 200, 120) }, { Name = "Jade", Color = Color3_fromRGB(0, 168, 107) }, { Name = "Menta", Color = Color3_fromRGB(152, 251, 152) }, { Name = "Oliva", Color = Color3_fromRGB(128, 128, 0) } } },
	{ Category = "Amarelos & Laranjas", MainColor = Color3_fromRGB(255, 230, 0), Variations = {
		{ Name = "Amarelo", Color = Color3_fromRGB(255, 230, 0) }, { Name = "Laranja", Color = Color3_fromRGB(255, 130, 0) }, { Name = "Âmbar", Color = Color3_fromRGB(255, 191, 0) }, { Name = "Dourado", Color = Color3_fromRGB(255, 215, 0) }, { Name = "Bronze", Color = Color3_fromRGB(205, 127, 50) }, { Name = "Bege", Color = Color3_fromRGB(245, 245, 220) } } },
	{ Category = "Roxos & Violetas", MainColor = Color3_fromRGB(150, 40, 255), Variations = {
		{ Name = "Roxo", Color = Color3_fromRGB(150, 40, 255) }, { Name = "Índigo", Color = Color3_fromRGB(75, 0, 130) }, { Name = "Violeta", Color = Color3_fromRGB(170, 90, 255) }, { Name = "Lavanda", Color = Color3_fromRGB(230, 230, 250) }, { Name = "Lilás", Color = Color3_fromRGB(200, 162, 200) }, { Name = "Púrpura", Color = Color3_fromRGB(128, 0, 128) } } },
	{ Category = "Neutros & Tons Escuros", MainColor = Color3_fromRGB(255, 255, 255), Variations = {
		{ Name = "Branco", Color = Color3_fromRGB(255, 255, 255) }, { Name = "Cinza", Color = Color3_fromRGB(128, 128, 128) }, { Name = "Prata", Color = Color3_fromRGB(192, 192, 192) }, { Name = "Grafite", Color = Color3_fromRGB(56, 56, 56) }, { Name = "Preto", Color = Color3_fromRGB(20, 20, 25) }, { Name = "Obsidiana", Color = Color3_fromRGB(27, 26, 31) }, { Name = "Marrom", Color = Color3_fromRGB(139, 69, 19) } } },
}

-- ==================== UI helpers ====================
local function new(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function colorSwatch(parent, color, size, pos, z)
	local f = new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, parent)
	corner(f, 3)
	return f
end

-- ==================== ScreenGui ====================
screenGui = new("ScreenGui", {
	Name = "KisaragiEyes_Gui", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
}, guiParent)

local mainFrame = new("Frame", {
	Size = UDim2.fromOffset(340, 490), Position = UDim2.new(0.5, -170, 0.5, -245),
	BackgroundColor3 = Color3_fromRGB(22, 6, 12), BackgroundTransparency = 0.15,
	BorderSizePixel = 0, Visible = true, Active = true, ClipsDescendants = false, ZIndex = 5,
}, screenGui)
corner(mainFrame, 12)

new("UIStroke", { Color = Color3_fromRGB(200, 30, 60), Thickness = 1.5, Transparency = 0.2 }, mainFrame)

local titleBar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, ZIndex = 9 }, mainFrame)

do
	local dragging, dragMouse, dragOrigin = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragMouse = input.Position
			dragOrigin = mainFrame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - dragMouse
			mainFrame.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "Kisaragi Eyes",
	TextColor3 = Color3_fromRGB(255, 235, 240), Font = Enum.Font.GothamBlack, TextSize = 17, ZIndex = 7,
}, mainFrame)

new("Frame", {
	Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 42),
	BackgroundColor3 = Color3_fromRGB(100, 25, 45), BorderSizePixel = 0, ZIndex = 7,
}, mainFrame)

local function createSwitch(parent, labelText, initialValue, posY, callback)
	local row = new("Frame", { Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, posY), BackgroundTransparency = 1, ZIndex = 6 }, parent)
	new("TextLabel", { Size = UDim2.new(0.7, 0, 1, 0), BackgroundTransparency = 1, Text = labelText, TextColor3 = Color3_fromRGB(240, 220, 225), Font = Enum.Font.GothamSemibold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 }, row)

	local switchBg = new("Frame", { Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -44, 0.5, -11), BackgroundColor3 = initialValue and Color3_fromRGB(200, 30, 60) or Color3_fromRGB(45, 18, 25), BorderSizePixel = 0, ZIndex = 7 }, row)
	Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

	local switchDot = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = initialValue and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3_new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8 }, switchBg)
	Instance.new("UICorner", switchDot).CornerRadius = UDim.new(1, 0)

	local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 9 }, switchBg)
	local state = initialValue
	btn.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(switchDot, TWEEN_SWITCH, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }):Play()
		TweenService:Create(switchBg, TWEEN_SWITCH, { BackgroundColor3 = state and Color3_fromRGB(200, 30, 60) or Color3_fromRGB(45, 18, 25) }):Play()
		callback(state)
	end)
end

createSwitch(mainFrame, "Exibir Nomes ESP", Config.NameEnabled, 50, function(val) Config.NameEnabled = val end)
createSwitch(mainFrame, "Exibir Barra de HP", Config.HpEnabled, 80, function(val) Config.HpEnabled = val end)
createSwitch(mainFrame, "Exibir Aura Visual", Config.AuraEnabled, 110, function(val) Config.AuraEnabled = val end)
createSwitch(mainFrame, "Exibir Glow de Membros", Config.GlowEnabled, 140, function(val) Config.GlowEnabled = val end)
createSwitch(mainFrame, "Cegueira / Visão Noturna", Config.BlindnessEnabled, 170, function(val) setBlindnessMode(val) end)

local selfColorDropContainer, playerDropContainer, colorDropContainer

local function closeOtherDrops(keep)
	if keep ~= selfColorDropContainer then selfColorDropContainer.Visible = false end
	if keep ~= playerDropContainer then playerDropContainer.Visible = false end
	if keep ~= colorDropContainer then colorDropContainer.Visible = false end
end

local function populateAccordion(listFrame, categories, categoryFrames, onPick, zBase)
	local function relayout()
		local currentY = 0
		for _, catGroup in ipairs(categoryFrames) do
			catGroup.Header.Position = UDim2.fromOffset(2, currentY)
			currentY += 28
			if catGroup.Container.Visible then
				catGroup.Container.Position = UDim2.fromOffset(8, currentY)
				local containerHeight = #catGroup.Items * 25
				catGroup.Container.Size = UDim2.new(1, -12, 0, containerHeight)
				currentY += containerHeight + 4
			else
				currentY += 2
			end
		end
		listFrame.CanvasSize = UDim2.fromOffset(0, currentY + 10)
	end

	for _, categoryData in ipairs(categories) do
		local catHeader = new("TextButton", {
			Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = Color3_fromRGB(42, 12, 22),
			Text = "  ▶ " .. categoryData.Category, TextColor3 = Color3_fromRGB(255, 220, 225),
			Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = zBase,
		}, listFrame)
		corner(catHeader, 4)
		colorSwatch(catHeader, categoryData.MainColor, 12, UDim2.new(1, -22, 0.5, -6), zBase + 1)

		local varContainer = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = zBase, Visible = false }, listFrame)
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, varContainer)

		categoryFrames[#categoryFrames + 1] = { Header = catHeader, Container = varContainer, Items = categoryData.Variations }

		for vIdx, varItem in ipairs(categoryData.Variations) do
			local varBtn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = Color3_fromRGB(22, 6, 12),
				Text = "        " .. varItem.Name, TextColor3 = Color3_fromRGB(230, 230, 235),
				Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, LayoutOrder = vIdx, ZIndex = zBase + 1,
			}, varContainer)
			corner(varBtn, 4)
			colorSwatch(varBtn, varItem.Color, 10, UDim2.new(0, 12, 0.5, -5), zBase + 2)
			varBtn.MouseButton1Click:Connect(function() onPick(varItem) end)
		end

		local isExpanded = false
		catHeader.MouseButton1Click:Connect(function()
			isExpanded = not isExpanded
			varContainer.Visible = isExpanded
			catHeader.Text = (isExpanded and "  ▼ " or "  ▶ ") .. categoryData.Category
			relayout()
		end)
	end
	relayout()
end

new("TextLabel", { Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 202), BackgroundTransparency = 1, Text = "Cor da Sua Aura (Cegueira):", TextColor3 = Color3_fromRGB(200, 160, 170), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 }, mainFrame)

local btnSelfColorDropdown = new("TextButton", { Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 220), BackgroundColor3 = Color3_fromRGB(35, 10, 18), Text = "  Vinho (Padrão) ▼", TextColor3 = Color3_new(1, 1, 1), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 7 }, mainFrame)
corner(btnSelfColorDropdown, 6)

selfColorDropContainer = new("Frame", { Size = UDim2.new(1, -28, 0, 190), Position = UDim2.fromOffset(14, 252), BackgroundColor3 = Color3_fromRGB(25, 8, 14), BorderSizePixel = 0, Visible = false, ZIndex = 35 }, mainFrame)
corner(selfColorDropContainer, 6)
new("UIStroke", { Color = Color3_fromRGB(150, 30, 50), Thickness = 1 }, selfColorDropContainer)

local selfColorListFrame = new("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3, ZIndex = 36 }, selfColorDropContainer)

populateAccordion(selfColorListFrame, SELF_COLOR_CATEGORIES, {}, function(varItem)
	Config.SelfAuraColor = varItem.Color
	btnSelfColorDropdown.Text = "  " .. varItem.Name .. " ▼"
	selfColorDropContainer.Visible = false
	saveConfig()
	if Config.BlindnessEnabled then updateSelfAura(true) end
end, 37)

btnSelfColorDropdown.MouseButton1Click:Connect(function()
	closeOtherDrops(selfColorDropContainer)
	selfColorDropContainer.Visible = not selfColorDropContainer.Visible
end)

new("TextLabel", { Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 256), BackgroundTransparency = 1, Text = "Jogador Selecionado:", TextColor3 = Color3_fromRGB(200, 160, 170), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 }, mainFrame)

local btnPlayerDropdown = new("TextButton", { Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 274), BackgroundColor3 = Color3_fromRGB(35, 10, 18), Text = "  Clique para escolher um jogador ▼", TextColor3 = Color3_new(1, 1, 1), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 7 }, mainFrame)
corner(btnPlayerDropdown, 6)

playerDropContainer = new("Frame", { Size = UDim2.new(1, -28, 0, 145), Position = UDim2.fromOffset(14, 304), BackgroundColor3 = Color3_fromRGB(25, 8, 14), BorderSizePixel = 0, Visible = false, ZIndex = 20 }, mainFrame)
corner(playerDropContainer, 6)
new("UIStroke", { Color = Color3_fromRGB(150, 30, 50), Thickness = 1 }, playerDropContainer)

local searchBox = new("TextBox", { Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3_fromRGB(15, 5, 8), TextColor3 = Color3_new(1, 1, 1), PlaceholderText = "Pesquisar jogador...", Text = "", Font = Enum.Font.Gotham, TextSize = 11, BorderSizePixel = 0, ClearTextOnFocus = false, ZIndex = 21 }, playerDropContainer)
corner(searchBox, 4)

local playerListFrame = new("ScrollingFrame", { Size = UDim2.new(1, -12, 0, 105), Position = UDim2.fromOffset(6, 34), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3, ZIndex = 21 }, playerDropContainer)
new("UIListLayout", { Padding = UDim.new(0, 3) }, playerListFrame)

local playerButtons = {}
local boxRename
local btnGlowToggle
local updatePlayerList

updatePlayerList = function()
	for i = 1, #playerButtons do playerButtons[i]:Destroy(); playerButtons[i] = nil end
	local filter = searchBox.Text:lower()
	local count = 0

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local data = getPlayerData(p)
			local customName = data.CustomName:lower()
			local pName = p.Name:lower()
			if filter == "" or string.find(pName, filter, 1, true) or string.find(customName, filter, 1, true) then
				count += 1
				local btn = new("TextButton", { Size = UDim2.new(1, -4, 0, 22), BackgroundColor3 = (selectedPlayer == p) and Color3_fromRGB(160, 25, 50) or Color3_fromRGB(45, 12, 22), Text = "  " .. p.Name .. ((data.CustomName ~= "") and (" [" .. data.CustomName .. "]") or ""), TextColor3 = Color3_new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 22 }, playerListFrame)
				corner(btn, 4)
				btn.MouseButton1Click:Connect(function()
					selectedPlayer = p
					btnPlayerDropdown.Text = "  " .. p.Name .. " ▼"
					playerDropContainer.Visible = false
					updatePlayerList()
					if boxRename then boxRename.Text = data.CustomName end
					if btnGlowToggle then
						btnGlowToggle.Text = data.GlowActive and "  Glow Individual: [ATIVADO]" or "  Glow Individual: [DESATIVADO]"
						btnGlowToggle.BackgroundColor3 = data.GlowActive and Color3_fromRGB(160, 25, 50) or Color3_fromRGB(35, 10, 18)
					end
				end)
				playerButtons[#playerButtons + 1] = btn
			end
		end
	end
	playerListFrame.CanvasSize = UDim2.fromOffset(0, count * 25)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(updatePlayerList)
btnPlayerDropdown.MouseButton1Click:Connect(function() closeOtherDrops(playerDropContainer); playerDropContainer.Visible = not playerDropContainer.Visible end)
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
task.defer(updatePlayerList)

local rowRename = new("Frame", { Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 310), BackgroundTransparency = 1, ZIndex = 6 }, mainFrame)
new("TextLabel", { Size = UDim2.new(0.35, 0, 1, 0), BackgroundTransparency = 1, Text = "Apelido:", TextColor3 = Color3_fromRGB(240, 220, 225), Font = Enum.Font.GothamSemibold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 }, rowRename)

boxRename = new("TextBox", { Size = UDim2.new(0.65, 0, 0, 26), Position = UDim2.new(0.35, 0, 0.5, -13), BackgroundColor3 = Color3_fromRGB(20, 5, 10), TextColor3 = Color3_new(1, 1, 1), PlaceholderText = "Selecione um player...", Text = "", Font = Enum.Font.Gotham, TextSize = 11, BorderSizePixel = 0, ClearTextOnFocus = false, ZIndex = 8 }, rowRename)
corner(boxRename, 6)

boxRename.FocusLost:Connect(function()
	if selectedPlayer then
		getPlayerData(selectedPlayer).CustomName = boxRename.Text
		saveConfig()
		updatePlayerList()
	end
end)

btnGlowToggle = new("TextButton", { Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 344), BackgroundColor3 = Color3_fromRGB(35, 10, 18), Text = "  Glow Individual: [DESATIVADO]", TextColor3 = Color3_new(1, 1, 1), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 7 }, mainFrame)
corner(btnGlowToggle, 6)

btnGlowToggle.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	local data = getPlayerData(selectedPlayer)
	data.GlowActive = not data.GlowActive
	btnGlowToggle.Text = data.GlowActive and "  Glow Individual: [ATIVADO]" or "  Glow Individual: [DESATIVADO]"
	btnGlowToggle.BackgroundColor3 = data.GlowActive and Color3_fromRGB(160, 25, 50) or Color3_fromRGB(35, 10, 18)
	saveConfig()
end)

new("TextLabel", { Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 378), BackgroundTransparency = 1, Text = "Cor da Aura do Jogador:", TextColor3 = Color3_fromRGB(200, 160, 170), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 }, mainFrame)

local btnColorDropdown = new("TextButton", { Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 396), BackgroundColor3 = Color3_fromRGB(35, 10, 18), Text = "  Selecione uma cor ▼", TextColor3 = Color3_new(1, 1, 1), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 7 }, mainFrame)
corner(btnColorDropdown, 6)

colorDropContainer = new("Frame", { Size = UDim2.new(1, -28, 0, 190), Position = UDim2.fromOffset(14, 428), BackgroundColor3 = Color3_fromRGB(25, 8, 14), BorderSizePixel = 0, Visible = false, ZIndex = 30 }, mainFrame)
corner(colorDropContainer, 6)
new("UIStroke", { Color = Color3_fromRGB(150, 30, 50), Thickness = 1 }, colorDropContainer)

local playerColorListFrame = new("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3, ZIndex = 31 }, colorDropContainer)

populateAccordion(playerColorListFrame, PLAYER_COLOR_CATEGORIES, {}, function(varItem)
	if selectedPlayer then
		getPlayerData(selectedPlayer).Color = varItem.Color
		btnColorDropdown.Text = "  " .. varItem.Name .. " ▼"
		colorDropContainer.Visible = false
		saveConfig()
	end
end, 32)

btnColorDropdown.MouseButton1Click:Connect(function() closeOtherDrops(colorDropContainer); colorDropContainer.Visible = not colorDropContainer.Visible end)

new("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -22), BackgroundTransparency = 1, Text = "[RightShift] Ocultar / Mostrar Menu", TextColor3 = Color3_fromRGB(160, 100, 110), Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 6 }, mainFrame)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then mainFrame.Visible = not mainFrame.Visible end
end)

print("Kisaragi Eyes [Otimizado] carregado.")
