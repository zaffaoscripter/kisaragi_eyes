-- ==================== Anti-Re-Execution Check ====================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local guiParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
if guiParent:FindFirstChild("KisaragiEyes_Gui") then
    warn("[Kisaragi Eyes]: O script já está em execução! Cancelando duplicada.")
    return
end

-- ==================== Services ====================
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local Camera           = workspace.CurrentCamera

-- ==================== Config Global & Save System ====================
local ESPNameEnabled   = true
local ESPAuraEnabled   = true
local BlindnessEnabled = false
local SelfAuraColor    = Color3.fromRGB(115, 10, 30) -- Cor padrão do personagem (Vinho)
local SAVE_FILE_NAME   = "KisaragiEyes_Data.json"

-- Backup de configurações originais do Lighting
local originalLighting = {
    ClockTime      = Lighting.ClockTime,
    Brightness     = Lighting.Brightness,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient        = Lighting.Ambient,
    GlobalShadows  = Lighting.GlobalShadows,
    FogStart       = Lighting.FogStart,
    FogEnd         = Lighting.FogEnd,
    FogColor       = Lighting.FogColor
}

local colorCorrection = nil

-- [UserId] = { Color = Color3, CustomName = string }
local playerData = {}

local function saveConfig()
    if writefile then
        pcall(function()
            local rawData = {
                SelfAuraColor = { SelfAuraColor.R, SelfAuraColor.G, SelfAuraColor.B },
                Players = {}
            }
            for userId, data in pairs(playerData) do
                rawData.Players[tostring(userId)] = {
                    Color = { data.Color.R, data.Color.G, data.Color.B },
                    CustomName = data.CustomName
                }
            end
            writefile(SAVE_FILE_NAME, HttpService:JSONEncode(rawData))
        end)
    end
end

local function loadConfig()
    if readfile and isfile and isfile(SAVE_FILE_NAME) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(SAVE_FILE_NAME))
            
            if decoded.SelfAuraColor then
                SelfAuraColor = Color3.new(decoded.SelfAuraColor[1], decoded.SelfAuraColor[2], decoded.SelfAuraColor[3])
            end

            local playersList = decoded.Players or decoded
            for userIdStr, data in pairs(playersList) do
                local uid = tonumber(userIdStr)
                if uid and data.Color then
                    playerData[uid] = {
                        Color = Color3.new(data.Color[1], data.Color[2], data.Color[3]),
                        CustomName = data.CustomName or ""
                    }
                end
            end
        end)
    end
end

loadConfig()

-- ==================== Sistema de Partículas Fluorescentes (Profundidade/Branco) ====================
local particleContainer = Instance.new("Folder")
particleContainer.Name = "KisaragiParticles"

local activeParticles = {}
local PARTICLE_COUNT = 50 -- Reduzido de 65 para 50 para não poluir a tela

local function clearParticles()
    for _, p in ipairs(activeParticles) do
        if p.Frame then p.Frame:Destroy() end
    end
    activeParticles = {}
    particleContainer:ClearAllChildren()
end

local function setParticleMovement(pData)
    local angle = math.random() * math.pi * 2 -- Direção 360º aleatória
    
    -- Velocidade ajustada em Pixels Por Segundo (independente de FPS)
    local baseSpeed = math.random(15, 35) / 10 -- 1.5 a 3.5 px/s de base
    
    -- Multiplicador baseado na profundidade (Mais longe = Mais lento)
    local depthMult = (pData.Depth == 1) and 1 or (pData.Depth == 2 and 2.5 or 4)
    local finalSpeed = baseSpeed * depthMult
    
    pData.SpeedX = math.cos(angle) * finalSpeed
    pData.SpeedY = math.sin(angle) * finalSpeed
end

local function createParticle(guiHolder)
    local viewportSize = Camera.ViewportSize
    if viewportSize.X == 0 or viewportSize.Y == 0 then return end

    -- Camadas de profundidade: 1 = Longe (pequeno, lento), 2 = Média, 3 = Perto (maior, rápido)
    local depth = math.random(1, 3)
    local sizeMap = { [1] = math.random(1, 2), [2] = math.random(2, 3), [3] = math.random(4, 5) }
    local size = sizeMap[depth]

    local startX = math.random(30, math.max(31, viewportSize.X - 30))
    local startY = math.random(30, math.max(31, viewportSize.Y - 30))

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, size, 0, size)
    frame.Position = UDim2.new(0, startX, 0, startY)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Branco Puro Florescente
    
    local alphaMap = { [1] = 0.5, [2] = 0.25, [3] = 0.05 }
    frame.BackgroundTransparency = alphaMap[depth]
    frame.BorderSizePixel = 0
    frame.ZIndex = depth
    frame.Parent = particleContainer

    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

    -- Halo / Brilho Neon Fluorescente Branco
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = (depth == 3) and 1.8 or 1.0
    stroke.Parent = frame

    local pData = {
        Frame = frame,
        Stroke = stroke,
        Depth = depth,
        ExactX = startX, -- Armazena a posição exata em decimais
        ExactY = startY,
        PulseSpeed = math.random(10, 30) / 10,
        BaseTransparency = frame.BackgroundTransparency,
        Seed = math.random(1, 1000)
    }
    setParticleMovement(pData)
    
    table.insert(activeParticles, pData)
end

local function setupParticles(guiHolder)
    clearParticles()
    particleContainer.Parent = guiHolder
    for i = 1, PARTICLE_COUNT do
        createParticle(guiHolder)
    end
end

-- Loop de animação das partículas usando dt (DeltaTime) para FPS constante
RunService.RenderStepped:Connect(function(dt)
    if not BlindnessEnabled then return end

    local viewportSize = Camera.ViewportSize
    local edgeMargin = 30 -- Distância da borda para começar a sumir

    for _, p in ipairs(activeParticles) do
        if p.Frame and p.Frame.Parent then
            -- Adiciona a velocidade com base no tempo passado (dt)
            p.ExactX = p.ExactX + (p.SpeedX * dt)
            p.ExactY = p.ExactY + (p.SpeedY * dt)

            -- Atualiza a posição visual
            p.Frame.Position = UDim2.new(0, math.floor(p.ExactX), 0, math.floor(p.ExactY))

            -- Calcula a distância para a borda mais próxima
            local distTop = p.ExactY
            local distBottom = viewportSize.Y - p.ExactY
            local distLeft = p.ExactX
            local distRight = viewportSize.X - p.ExactX
            
            local minEdgeDist = math.min(distTop, distBottom, distLeft, distRight)
            
            -- edgeAlpha = 1 (Centro da tela), edgeAlpha = 0 (Na borda)
            local edgeAlpha = math.clamp(minEdgeDist / edgeMargin, 0, 1)

            -- Pulsação suave padrão
            local pulse = (math.sin(tick() * p.PulseSpeed + p.Seed) + 1) / 2
            local alphaOffset = (p.Depth == 1) and 0.35 or 0.2
            
            -- Mistura a Transparência da Pulsação com o Efeito da Borda
            local baseT = math.clamp(p.BaseTransparency + (pulse * alphaOffset), 0.0, 0.95)
            local finalT = 1 - ((1 - baseT) * edgeAlpha) 

            p.Frame.BackgroundTransparency = finalT
            if p.Stroke then
                p.Stroke.Transparency = math.clamp(finalT + 0.1, 0, 1) 
            end

            -- Se saiu completamente da tela (fade-out completado)
            if minEdgeDist < -5 then
                p.ExactX = math.random(edgeMargin, math.max(edgeMargin + 1, viewportSize.X - edgeMargin))
                p.ExactY = math.random(edgeMargin, math.max(edgeMargin + 1, viewportSize.Y - edgeMargin))
                p.Frame.Position = UDim2.new(0, math.floor(p.ExactX), 0, math.floor(p.ExactY))
                setParticleMovement(p) -- Sorteia nova rota e velocidade suave
            end
        end
    end
end)

-- ==================== Aura Própria (Cegueira) ====================
local function updateSelfAura(enable)
    local char = LocalPlayer.Character
    if not char then return end

    local selfHighlight = char:FindFirstChild("KisaragiSelfAura")
    if enable then
        if not selfHighlight then
            selfHighlight = Instance.new("Highlight")
            selfHighlight.Name = "KisaragiSelfAura"
            selfHighlight.Adornee = char
            selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            selfHighlight.FillTransparency = 0.5
            selfHighlight.OutlineTransparency = 0.0
            selfHighlight.Parent = char
        end
        selfHighlight.FillColor = SelfAuraColor
        selfHighlight.OutlineColor = SelfAuraColor
        selfHighlight.Enabled = true
    else
        if selfHighlight then
            selfHighlight:Destroy()
        end
    end
end

-- ==================== Sistema de Cegueira ====================
local screenGui = nil

local function setBlindnessMode(enable)
    BlindnessEnabled = enable

    if enable then
        originalLighting.ClockTime      = Lighting.ClockTime
        originalLighting.Brightness     = Lighting.Brightness
        originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
        originalLighting.Ambient        = Lighting.Ambient
        originalLighting.GlobalShadows  = Lighting.GlobalShadows
        originalLighting.FogStart       = Lighting.FogStart
        originalLighting.FogEnd         = Lighting.FogEnd
        originalLighting.FogColor       = Lighting.FogColor

        Lighting.ClockTime      = 0
        Lighting.Brightness     = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Lighting.Ambient        = Color3.fromRGB(0, 0, 0)
        Lighting.GlobalShadows  = true
        Lighting.FogStart       = 0
        Lighting.FogEnd         = 1
        Lighting.FogColor       = Color3.fromRGB(0, 0, 0)

        if not colorCorrection then
            colorCorrection = Instance.new("ColorCorrectionEffect")
            colorCorrection.Name = "KisaragiBlindnessCC"
            colorCorrection.Brightness = -1
            colorCorrection.Contrast = 1
            colorCorrection.Saturation = -1
            colorCorrection.TintColor = Color3.fromRGB(0, 0, 0)
            colorCorrection.Parent = Lighting
        end
        colorCorrection.Enabled = true

        updateSelfAura(true)
        if screenGui then
            setupParticles(screenGui)
        end
    else
        Lighting.ClockTime      = originalLighting.ClockTime
        Lighting.Brightness     = originalLighting.Brightness
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Ambient        = originalLighting.Ambient
        Lighting.GlobalShadows  = originalLighting.GlobalShadows
        Lighting.FogStart       = originalLighting.FogStart
        Lighting.FogEnd         = originalLighting.FogEnd
        Lighting.FogColor       = originalLighting.FogColor

        if colorCorrection then
            colorCorrection.Enabled = false
        end

        updateSelfAura(false)
        clearParticles()
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if BlindnessEnabled then
        updateSelfAura(true)
    end
end)

-- ==================== Paleta para Aura Própria (Categorias + Variações) ====================
local SELF_COLOR_CATEGORIES = {
    {
        Category = "Vermelho",
        MainColor = Color3.fromRGB(255, 0, 0),
        Variations = {
            { Name = "Vinho (Padrão)", Color = Color3.fromRGB(115, 10, 30) },
            { Name = "Vermelho Puro",  Color = Color3.fromRGB(255, 0, 0) },
            { Name = "Escarlate",      Color = Color3.fromRGB(255, 45, 0) },
            { Name = "Carmim",         Color = Color3.fromRGB(180, 0, 40) },
        }
    },
    {
        Category = "Azul",
        MainColor = Color3.fromRGB(0, 120, 255),
        Variations = {
            { Name = "Azul Principal", Color = Color3.fromRGB(0, 120, 255) },
            { Name = "Azul Marinho",   Color = Color3.fromRGB(15, 30, 110) },
            { Name = "Azul Ciano",     Color = Color3.fromRGB(0, 220, 255) },
            { Name = "Azul Cobalto",   Color = Color3.fromRGB(20, 80, 200) },
        }
    },
    {
        Category = "Amarelo",
        MainColor = Color3.fromRGB(255, 230, 0),
        Variations = {
            { Name = "Amarelo Principal", Color = Color3.fromRGB(255, 230, 0) },
            { Name = "Dourado",           Color = Color3.fromRGB(255, 195, 0) },
            { Name = "Amarelo Limão",     Color = Color3.fromRGB(230, 255, 50) },
            { Name = "Âmbar",             Color = Color3.fromRGB(255, 140, 0) },
        }
    },
    {
        Category = "Verde",
        MainColor = Color3.fromRGB(0, 220, 100),
        Variations = {
            { Name = "Verde Principal", Color = Color3.fromRGB(0, 220, 100) },
            { Name = "Verde Esmeralda", Color = Color3.fromRGB(0, 180, 90) },
            { Name = "Verde Menta",     Color = Color3.fromRGB(80, 255, 160) },
            { Name = "Verde Musgo",     Color = Color3.fromRGB(30, 90, 40) },
        }
    },
    {
        Category = "Roxo",
        MainColor = Color3.fromRGB(150, 40, 255),
        Variations = {
            { Name = "Roxo Principal", Color = Color3.fromRGB(150, 40, 255) },
            { Name = "Violeta Escuro",  Color = Color3.fromRGB(80, 10, 160) },
            { Name = "Lilás",           Color = Color3.fromRGB(200, 140, 255) },
            { Name = "Magenta",         Color = Color3.fromRGB(230, 0, 180) },
        }
    },
    {
        Category = "Laranja",
        MainColor = Color3.fromRGB(255, 130, 0),
        Variations = {
            { Name = "Laranja Principal", Color = Color3.fromRGB(255, 130, 0) },
            { Name = "Laranja Fogo",      Color = Color3.fromRGB(255, 70, 0) },
            { Name = "Pêssego",           Color = Color3.fromRGB(255, 170, 120) },
            { Name = "Terracota",         Color = Color3.fromRGB(180, 75, 30) },
        }
    },
    {
        Category = "Neutro / Monocromático",
        MainColor = Color3.fromRGB(255, 255, 255),
        Variations = {
            { Name = "Branco Puro", Color = Color3.fromRGB(255, 255, 255) },
            { Name = "Platina",     Color = Color3.fromRGB(210, 215, 225) },
            { Name = "Grafite",     Color = Color3.fromRGB(80, 80, 95) },
            { Name = "Sombra",      Color = Color3.fromRGB(25, 20, 30) },
        }
    }
}

-- ==================== Paleta de Cores para Jogadores (Sanfona) ====================
local PLAYER_COLOR_CATEGORIES = {
    {
        Category = "Vermelhos & Rosas",
        MainColor = Color3.fromRGB(255, 0, 0),
        Variations = {
            { Name = "Vermelho",  Color = Color3.fromRGB(255, 0, 0) },
            { Name = "Carmim",    Color = Color3.fromRGB(220, 20, 60) },
            { Name = "Escarlate", Color = Color3.fromRGB(255, 36, 0) },
            { Name = "Bordô",     Color = Color3.fromRGB(128, 0, 32) },
            { Name = "Rubi",      Color = Color3.fromRGB(155, 17, 30) },
            { Name = "Coral",     Color = Color3.fromRGB(255, 127, 80) },
            { Name = "Salmão",    Color = Color3.fromRGB(250, 128, 114) },
            { Name = "Rosa",      Color = Color3.fromRGB(255, 105, 180) },
            { Name = "Magenta",   Color = Color3.fromRGB(255, 0, 255) },
        }
    },
    {
        Category = "Azuis & Cianos",
        MainColor = Color3.fromRGB(0, 120, 255),
        Variations = {
            { Name = "Azul",     Color = Color3.fromRGB(0, 120, 255) },
            { Name = "Ciano",    Color = Color3.fromRGB(0, 230, 255) },
            { Name = "Turquesa", Color = Color3.fromRGB(64, 224, 208) },
            { Name = "Safira",   Color = Color3.fromRGB(15, 82, 186) },
            { Name = "Cobalto",  Color = Color3.fromRGB(0, 71, 171) },
            { Name = "Anil",     Color = Color3.fromRGB(15, 82, 186) },
        }
    },
    {
        Category = "Verdes",
        MainColor = Color3.fromRGB(0, 220, 100),
        Variations = {
            { Name = "Verde",     Color = Color3.fromRGB(0, 220, 100) },
            { Name = "Esmeralda",Color = Color3.fromRGB(80, 200, 120) },
            { Name = "Jade",      Color = Color3.fromRGB(0, 168, 107) },
            { Name = "Menta",     Color = Color3.fromRGB(152, 251, 152) },
            { Name = "Oliva",     Color = Color3.fromRGB(128, 128, 0) },
        }
    },
    {
        Category = "Amarelos & Laranjas",
        MainColor = Color3.fromRGB(255, 230, 0),
        Variations = {
            { Name = "Amarelo", Color = Color3.fromRGB(255, 230, 0) },
            { Name = "Laranja", Color = Color3.fromRGB(255, 130, 0) },
            { Name = "Âmbar",   Color = Color3.fromRGB(255, 191, 0) },
            { Name = "Dourado", Color = Color3.fromRGB(255, 215, 0) },
            { Name = "Bronze",  Color = Color3.fromRGB(205, 127, 50) },
            { Name = "Bege",    Color = Color3.fromRGB(245, 245, 220) },
        }
    },
    {
        Category = "Roxos & Violetas",
        MainColor = Color3.fromRGB(150, 40, 255),
        Variations = {
            { Name = "Roxo",    Color = Color3.fromRGB(150, 40, 255) },
            { Name = "Índigo",  Color = Color3.fromRGB(75, 0, 130) },
            { Name = "Violeta", Color = Color3.fromRGB(170, 90, 255) },
            { Name = "Lavanda", Color = Color3.fromRGB(230, 230, 250) },
            { Name = "Lilás",   Color = Color3.fromRGB(200, 162, 200) },
            { Name = "Púrpura", Color = Color3.fromRGB(128, 0, 128) },
        }
    },
    {
        Category = "Neutros & Tons Escuros",
        MainColor = Color3.fromRGB(255, 255, 255),
        Variations = {
            { Name = "Branco",   Color = Color3.fromRGB(255, 255, 255) },
            { Name = "Cinza",    Color = Color3.fromRGB(128, 128, 128) },
            { Name = "Prata",    Color = Color3.fromRGB(192, 192, 192) },
            { Name = "Grafite",  Color = Color3.fromRGB(56, 56, 56) },
            { Name = "Preto",    Color = Color3.fromRGB(20, 20, 25) },
            { Name = "Obsidiana",Color = Color3.fromRGB(27, 26, 31) },
            { Name = "Marrom",   Color = Color3.fromRGB(139, 69, 19) },
        }
    }
}

local selectedPlayer = nil

-- ==================== Objects & Drawing ====================
local espObjects = {}
local hasDrawing = pcall(function() return Drawing ~= nil end)

local function newLabel()
    if not hasDrawing then return nil end
    local ok, t = pcall(function()
        local d = Drawing.new("Text")
        d.Size         = 15
        d.Center       = true
        d.Outline      = true
        d.Font         = 2
        d.Color        = Color3.fromRGB(255, 255, 255)
        d.OutlineColor = Color3.fromRGB(0, 0, 0)
        d.Visible      = false
        return d
    end)
    return ok and t or nil
end

local function applyAura(character, color)
    local highlight = character:FindFirstChild("KisaragiAura")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "KisaragiAura"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.65
        highlight.OutlineTransparency = 0.15
        highlight.Parent = character
    end
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.Enabled = ESPAuraEnabled
    return highlight
end

local function getPlayerData(player)
    if not playerData[player.UserId] then
        playerData[player.UserId] = {
            Color = Color3.fromRGB(220, 225, 235),
            CustomName = ""
        }
    end
    return playerData[player.UserId]
end

local function createESP(character, player)
    if espObjects[character] then return end
    local data = getPlayerData(player)
    local label = newLabel()
    local highlight = applyAura(character, data.Color)
    espObjects[character] = { label = label, highlight = highlight, player = player }
end

local function removeESP(character)
    local obj = espObjects[character]
    if not obj then return end
    if obj.label then pcall(function() obj.label:Remove() end) end
    if obj.highlight then pcall(function() obj.highlight:Destroy() end) end
    espObjects[character] = nil
end

local function hideLabel(obj)
    if obj and obj.label then obj.label.Visible = false end
end

-- ==================== Render Loop ====================
RunService.RenderStepped:Connect(function()
    local pulse = (math.sin(tick() * 2.5) + 1) * 0.05

    for character, obj in pairs(espObjects) do
        local player = obj.player
        if player then
            local data = getPlayerData(player)

            if obj.highlight then
                obj.highlight.Enabled = ESPAuraEnabled
                if ESPAuraEnabled then
                    obj.highlight.FillColor = data.Color
                    obj.highlight.OutlineColor = data.Color
                    obj.highlight.FillTransparency = 0.65 + pulse
                end
            end

            if not ESPNameEnabled then
                hideLabel(obj)
            else
                local hum  = character:FindFirstChildOfClass("Humanoid")
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")

                if hum and root and head and hum.Health > 0 then
                    local topPos, topVis = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
                    
                    if topVis and topPos.Z > 0 then
                        if obj.label then
                            local dist = (Camera.CFrame.Position - root.Position).Magnitude
                            local displayName = (data.CustomName ~= "") and data.CustomName or player.Name
                            
                            obj.label.Position = Vector2.new(topPos.X, topPos.Y - 18)
                            obj.label.Text     = displayName .. " [" .. math.floor(dist) .. "m]"
                            obj.label.Color    = data.Color
                            obj.label.Visible  = true
                        end
                    else
                        hideLabel(obj)
                    end
                else
                    hideLabel(obj)
                end
            end
        end
    end
end)

-- ==================== Hook Players ====================
local function hookPlayer(player)
    if player == LocalPlayer then return end
    local function onChar(char) createESP(char, player) end
    local function onCharRemove(char) removeESP(char) end
    
    player.CharacterAdded:Connect(onChar)
    player.CharacterRemoving:Connect(onCharRemove)
    if player.Character then onChar(player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(p)
    if p.Character then removeESP(p.Character) end
end)

-- ==================== ScreenGui ====================
screenGui = Instance.new("ScreenGui")
screenGui.Name           = "KisaragiEyes_Gui"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = guiParent

-- ==================== Main Frame ====================
local mainFrame = Instance.new("Frame")
mainFrame.Size                 = UDim2.new(0, 340, 0, 430)
mainFrame.Position             = UDim2.new(0.5, -170, 0.5, -215)
mainFrame.BackgroundColor3     = Color3.fromRGB(22, 6, 12)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel          = 0
mainFrame.Visible              = true
mainFrame.Active               = true
mainFrame.ClipsDescendants      = false
mainFrame.Parent               = screenGui
mainFrame.ZIndex               = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color        = Color3.fromRGB(200, 30, 60)
frameStroke.Thickness    = 1.5
frameStroke.Transparency = 0.2
frameStroke.Parent       = mainFrame

-- ==================== Drag System ====================
local titleBar = Instance.new("Frame")
titleBar.Size                   = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex                 = 9
titleBar.Parent                 = mainFrame

do
    local dragging, dragMouse, dragOrigin = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging   = true
            dragMouse  = input.Position
            dragOrigin = mainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragMouse
            mainFrame.Position = UDim2.new(
                dragOrigin.X.Scale, dragOrigin.X.Offset + d.X,
                dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ==================== Título ====================
local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, 0, 0, 42)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "Kisaragi Eyes"
titleLabel.TextColor3             = Color3.fromRGB(255, 235, 240)
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextSize               = 17
titleLabel.ZIndex                 = 7
titleLabel.Parent                 = mainFrame

local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -28, 0, 1)
sep.Position         = UDim2.new(0, 14, 0, 42)
sep.BackgroundColor3 = Color3.fromRGB(100, 25, 45)
sep.BorderSizePixel  = 0
sep.ZIndex           = 7
sep.Parent           = mainFrame

-- ==================== Helper Switch (Chave Ativar/Desativar) ====================
local function createSwitch(parent, labelText, initialValue, posY, callback)
    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(1, -28, 0, 26)
    row.Position               = UDim2.new(0, 14, 0, posY)
    row.BackgroundTransparency = 1
    row.ZIndex                 = 6
    row.Parent                 = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = Color3.fromRGB(240, 220, 225)
    lbl.Font                   = Enum.Font.GothamSemibold
    lbl.TextSize               = 12
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = row

    local switchBg = Instance.new("Frame")
    switchBg.Size             = UDim2.new(0, 44, 0, 22)
    switchBg.Position         = UDim2.new(1, -44, 0.5, -11)
    switchBg.BackgroundColor3 = initialValue and Color3.fromRGB(200, 30, 60) or Color3.fromRGB(45, 18, 25)
    switchBg.BorderSizePixel  = 0
    switchBg.ZIndex           = 7
    switchBg.Parent           = row
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local switchDot = Instance.new("Frame")
    switchDot.Size             = UDim2.new(0, 16, 0, 16)
    switchDot.Position         = initialValue and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    switchDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchDot.BorderSizePixel  = 0
    switchDot.ZIndex           = 8
    switchDot.Parent           = switchBg
    Instance.new("UICorner", switchDot).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.ZIndex                 = 9
    btn.Parent                 = switchBg

    local state = initialValue
    btn.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetBg  = state and Color3.fromRGB(200, 30, 60) or Color3.fromRGB(45, 18, 25)
        
        TweenService:Create(switchDot, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = targetBg}):Play()
        
        callback(state)
    end)
end

createSwitch(mainFrame, "Exibir Nomes ESP", ESPNameEnabled, 50, function(val)
    ESPNameEnabled = val
end)

createSwitch(mainFrame, "Exibir Aura Visual", ESPAuraEnabled, 80, function(val)
    ESPAuraEnabled = val
end)

createSwitch(mainFrame, "Cegueira / Visão Noturna", BlindnessEnabled, 110, function(val)
    setBlindnessMode(val)
end)

-- Referências para fechar gavetas automaticamente
local selfColorDropContainer = nil
local playerDropContainer    = nil
local colorDropContainer     = nil

-- ==================== Gaveta 1: Cor da Aura Própria (Cegueira) ====================
local lblSelfColor = Instance.new("TextLabel")
lblSelfColor.Size                   = UDim2.new(1, -28, 0, 16)
lblSelfColor.Position               = UDim2.new(0, 14, 0, 142)
lblSelfColor.BackgroundTransparency = 1
lblSelfColor.Text                   = "Cor da Sua Aura (Cegueira):"
lblSelfColor.TextColor3             = Color3.fromRGB(200, 160, 170)
lblSelfColor.Font                   = Enum.Font.GothamSemibold
lblSelfColor.TextSize               = 11
lblSelfColor.TextXAlignment         = Enum.TextXAlignment.Left
lblSelfColor.ZIndex                 = 7
lblSelfColor.Parent                 = mainFrame

local btnSelfColorDropdown = Instance.new("TextButton")
btnSelfColorDropdown.Size             = UDim2.new(1, -28, 0, 28)
btnSelfColorDropdown.Position         = UDim2.new(0, 14, 0, 160)
btnSelfColorDropdown.BackgroundColor3 = Color3.fromRGB(35, 10, 18)
btnSelfColorDropdown.Text             = "  Vinho (Padrão) ▼"
btnSelfColorDropdown.TextColor3       = Color3.fromRGB(255, 255, 255)
btnSelfColorDropdown.Font             = Enum.Font.GothamSemibold
btnSelfColorDropdown.TextSize         = 11
btnSelfColorDropdown.TextXAlignment   = Enum.TextXAlignment.Left
btnSelfColorDropdown.BorderSizePixel  = 0
btnSelfColorDropdown.ZIndex           = 7
btnSelfColorDropdown.Parent           = mainFrame
Instance.new("UICorner", btnSelfColorDropdown).CornerRadius = UDim.new(0, 6)

selfColorDropContainer = Instance.new("Frame")
selfColorDropContainer.Size                 = UDim2.new(1, -28, 0, 190)
selfColorDropContainer.Position             = UDim2.new(0, 14, 0, 192)
selfColorDropContainer.BackgroundColor3     = Color3.fromRGB(25, 8, 14)
selfColorDropContainer.BorderSizePixel      = 0
selfColorDropContainer.Visible              = false
selfColorDropContainer.ZIndex               = 35
selfColorDropContainer.Parent               = mainFrame
Instance.new("UICorner", selfColorDropContainer).CornerRadius = UDim.new(0, 6)

local scDropStroke = Instance.new("UIStroke")
scDropStroke.Color = Color3.fromRGB(150, 30, 50)
scDropStroke.Thickness = 1
scDropStroke.Parent = selfColorDropContainer

local selfColorListFrame = Instance.new("ScrollingFrame")
selfColorListFrame.Size                = UDim2.new(1, -12, 1, -12)
selfColorListFrame.Position            = UDim2.new(0, 6, 0, 6)
selfColorListFrame.BackgroundTransparency = 1
selfColorListFrame.BorderSizePixel    = 0
selfColorListFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
selfColorListFrame.ScrollBarThickness = 3
selfColorListFrame.ZIndex              = 36
selfColorListFrame.Parent              = selfColorDropContainer

local selfCategoryFrames = {}

local function updateSelfListCanvas()
    local currentY = 0
    for _, catGroup in ipairs(selfCategoryFrames) do
        catGroup.Header.Position = UDim2.new(0, 2, 0, currentY)
        currentY = currentY + 28
        
        if catGroup.Container.Visible then
            catGroup.Container.Position = UDim2.new(0, 8, 0, currentY)
            local containerHeight = #catGroup.Items * 25
            catGroup.Container.Size = UDim2.new(1, -12, 0, containerHeight)
            currentY = currentY + containerHeight + 4
        else
            currentY = currentY + 2
        end
    end
    selfColorListFrame.CanvasSize = UDim2.new(0, 0, 0, currentY + 10)
end

local function populateSelfColorList()
    for _, categoryData in ipairs(SELF_COLOR_CATEGORIES) do
        local catHeader = Instance.new("TextButton")
        catHeader.Size = UDim2.new(1, -4, 0, 26)
        catHeader.BackgroundColor3 = Color3.fromRGB(42, 12, 22)
        catHeader.Text = "  ▶ " .. categoryData.Category
        catHeader.TextColor3 = Color3.fromRGB(255, 220, 225)
        catHeader.Font = Enum.Font.GothamBold
        catHeader.TextSize = 11
        catHeader.TextXAlignment = Enum.TextXAlignment.Left
        catHeader.BorderSizePixel = 0
        catHeader.ZIndex = 37
        catHeader.Parent = selfColorListFrame
        Instance.new("UICorner", catHeader).CornerRadius = UDim.new(0, 4)

        local catSample = Instance.new("Frame")
        catSample.Size = UDim2.new(0, 12, 0, 12)
        catSample.Position = UDim2.new(1, -22, 0.5, -6)
        catSample.BackgroundColor3 = categoryData.MainColor
        catSample.BorderSizePixel = 0
        catSample.ZIndex = 38
        catSample.Parent = catHeader
        Instance.new("UICorner", catSample).CornerRadius = UDim.new(0, 3)

        local varContainer = Instance.new("Frame")
        varContainer.BackgroundTransparency = 1
        varContainer.BorderSizePixel = 0
        varContainer.ZIndex = 37
        varContainer.Visible = false
        varContainer.Parent = selfColorListFrame

        local varLayout = Instance.new("UIListLayout")
        varLayout.Padding = UDim.new(0, 2)
        varLayout.SortOrder = Enum.SortOrder.LayoutOrder
        varLayout.Parent = varContainer

        table.insert(selfCategoryFrames, {
            Header = catHeader,
            Container = varContainer,
            Items = categoryData.Variations
        })

        for vIdx, varItem in ipairs(categoryData.Variations) do
            local varBtn = Instance.new("TextButton")
            varBtn.Size = UDim2.new(1, 0, 0, 23)
            varBtn.BackgroundColor3 = Color3.fromRGB(22, 6, 12)
            varBtn.Text = "        " .. varItem.Name
            varBtn.TextColor3 = Color3.fromRGB(230, 230, 235)
            varBtn.Font = Enum.Font.Gotham
            varBtn.TextSize = 11
            varBtn.TextXAlignment = Enum.TextXAlignment.Left
            varBtn.BorderSizePixel = 0
            varBtn.LayoutOrder = vIdx
            varBtn.ZIndex = 38
            varBtn.Parent = varContainer
            Instance.new("UICorner", varBtn).CornerRadius = UDim.new(0, 4)

            local sample = Instance.new("Frame")
            sample.Size = UDim2.new(0, 10, 0, 10)
            sample.Position = UDim2.new(0, 12, 0.5, -5)
            sample.BackgroundColor3 = varItem.Color
            sample.BorderSizePixel = 0
            sample.ZIndex = 39
            sample.Parent = varBtn
            Instance.new("UICorner", sample).CornerRadius = UDim.new(0, 3)

            varBtn.MouseButton1Click:Connect(function()
                SelfAuraColor = varItem.Color
                btnSelfColorDropdown.Text = "  " .. varItem.Name .. " ▼"
                selfColorDropContainer.Visible = false
                saveConfig()
                if BlindnessEnabled then
                    updateSelfAura(true)
                end
            end)
        end

        local isExpanded = false
        catHeader.MouseButton1Click:Connect(function()
            isExpanded = not isExpanded
            varContainer.Visible = isExpanded
            catHeader.Text = (isExpanded and "  ▼ " or "  ▶ ") .. categoryData.Category
            updateSelfListCanvas()
        end)
    end

    updateSelfListCanvas()
end

populateSelfColorList()

btnSelfColorDropdown.MouseButton1Click:Connect(function()
    if playerDropContainer then playerDropContainer.Visible = false end
    if colorDropContainer then colorDropContainer.Visible = false end
    selfColorDropContainer.Visible = not selfColorDropContainer.Visible
end)

-- ==================== Gaveta 2: Seleção de Jogador ====================
local lblSelectPlayer = Instance.new("TextLabel")
lblSelectPlayer.Size                   = UDim2.new(1, -28, 0, 16)
lblSelectPlayer.Position               = UDim2.new(0, 14, 0, 196)
lblSelectPlayer.BackgroundTransparency = 1
lblSelectPlayer.Text                   = "Jogador Selecionado:"
lblSelectPlayer.TextColor3             = Color3.fromRGB(200, 160, 170)
lblSelectPlayer.Font                   = Enum.Font.GothamSemibold
lblSelectPlayer.TextSize               = 11
lblSelectPlayer.TextXAlignment         = Enum.TextXAlignment.Left
lblSelectPlayer.ZIndex                 = 7
lblSelectPlayer.Parent                 = mainFrame

local btnPlayerDropdown = Instance.new("TextButton")
btnPlayerDropdown.Size             = UDim2.new(1, -28, 0, 28)
btnPlayerDropdown.Position         = UDim2.new(0, 14, 0, 214)
btnPlayerDropdown.BackgroundColor3 = Color3.fromRGB(35, 10, 18)
btnPlayerDropdown.Text             = "  Clique para escolher um jogador ▼"
btnPlayerDropdown.TextColor3       = Color3.fromRGB(255, 255, 255)
btnPlayerDropdown.Font             = Enum.Font.GothamSemibold
btnPlayerDropdown.TextSize         = 11
btnPlayerDropdown.TextXAlignment   = Enum.TextXAlignment.Left
btnPlayerDropdown.BorderSizePixel  = 0
btnPlayerDropdown.ZIndex           = 7
btnPlayerDropdown.Parent           = mainFrame
Instance.new("UICorner", btnPlayerDropdown).CornerRadius = UDim.new(0, 6)

playerDropContainer = Instance.new("Frame")
playerDropContainer.Size                 = UDim2.new(1, -28, 0, 145)
playerDropContainer.Position             = UDim2.new(0, 14, 0, 244)
playerDropContainer.BackgroundColor3     = Color3.fromRGB(25, 8, 14)
playerDropContainer.BorderSizePixel      = 0
playerDropContainer.Visible              = false
playerDropContainer.ZIndex               = 20
playerDropContainer.Parent               = mainFrame
Instance.new("UICorner", playerDropContainer).CornerRadius = UDim.new(0, 6)

local pDropStroke = Instance.new("UIStroke")
pDropStroke.Color = Color3.fromRGB(150, 30, 50)
pDropStroke.Thickness = 1
pDropStroke.Parent = playerDropContainer

local searchBox = Instance.new("TextBox")
searchBox.Size             = UDim2.new(1, -12, 0, 24)
searchBox.Position         = UDim2.new(0, 6, 0, 6)
searchBox.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
searchBox.TextColor3       = Color3.fromRGB(255, 255, 255)
searchBox.PlaceholderText  = "🔍 Pesquisar jogador..."
searchBox.Text             = ""
searchBox.Font             = Enum.Font.Gotham
searchBox.TextSize         = 11
searchBox.BorderSizePixel  = 0
searchBox.ClearTextOnFocus = false
searchBox.ZIndex           = 21
searchBox.Parent           = playerDropContainer
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 4)

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size               = UDim2.new(1, -12, 0, 105)
playerListFrame.Position           = UDim2.new(0, 6, 0, 34)
playerListFrame.BackgroundTransparency = 1
playerListFrame.BorderSizePixel    = 0
playerListFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
playerListFrame.ScrollBarThickness = 3
playerListFrame.ZIndex             = 21
playerListFrame.Parent             = playerDropContainer

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = playerListFrame

local playerButtons = {}
local boxRename = nil
local btnColorDropdown = nil
local updatePlayerList = nil

updatePlayerList = function()
    for _, btn in pairs(playerButtons) do btn:Destroy() end
    playerButtons = {}

    local filter = searchBox.Text:lower()
    local count = 0

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local data = getPlayerData(p)
            local customName = data.CustomName:lower()
            local pName = p.Name:lower()
            
            if filter == "" or pName:find(filter) or customName:find(filter) then
                count = count + 1
                local btn = Instance.new("TextButton")
                btn.Size             = UDim2.new(1, -4, 0, 22)
                btn.BackgroundColor3 = (selectedPlayer == p) and Color3.fromRGB(160, 25, 50) or Color3.fromRGB(45, 12, 22)
                btn.Text             = "  " .. p.Name .. ((data.CustomName ~= "") and (" [" .. data.CustomName .. "]") or "")
                btn.TextColor3       = Color3.fromRGB(255, 255, 255)
                btn.Font             = Enum.Font.Gotham
                btn.TextSize         = 11
                btn.TextXAlignment   = Enum.TextXAlignment.Left
                btn.BorderSizePixel  = 0
                btn.ZIndex           = 22
                btn.Parent           = playerListFrame
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

                btn.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    btnPlayerDropdown.Text = "  " .. p.Name .. " ▼"
                    playerDropContainer.Visible = false
                    updatePlayerList()
                    if boxRename and selectedPlayer then
                        boxRename.Text = data.CustomName
                    end
                end)
                
                table.insert(playerButtons, btn)
            end
        end
    end
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 25)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(updatePlayerList)

btnPlayerDropdown.MouseButton1Click:Connect(function()
    selfColorDropContainer.Visible = false
    if colorDropContainer then colorDropContainer.Visible = false end
    playerDropContainer.Visible = not playerDropContainer.Visible
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
task.defer(updatePlayerList)

-- ==================== Edição de Apelido ====================
local rowRename = Instance.new("Frame")
rowRename.Size                   = UDim2.new(1, -28, 0, 28)
rowRename.Position               = UDim2.new(0, 14, 0, 250)
rowRename.BackgroundTransparency = 1
rowRename.ZIndex                 = 6
rowRename.Parent                 = mainFrame

local lblRename = Instance.new("TextLabel")
lblRename.Size                   = UDim2.new(0.35, 0, 1, 0)
lblRename.BackgroundTransparency = 1
lblRename.Text                   = "Apelido:"
lblRename.TextColor3             = Color3.fromRGB(240, 220, 225)
lblRename.Font                   = Enum.Font.GothamSemibold
lblRename.TextSize               = 12
lblRename.TextXAlignment         = Enum.TextXAlignment.Left
lblRename.ZIndex                 = 7
lblRename.Parent                 = rowRename

boxRename = Instance.new("TextBox")
boxRename.Size             = UDim2.new(0.65, 0, 0, 26)
boxRename.Position         = UDim2.new(0.35, 0, 0.5, -13)
boxRename.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
boxRename.TextColor3       = Color3.fromRGB(255, 255, 255)
boxRename.PlaceholderText  = "Selecione um player..."
boxRename.Text             = ""
boxRename.Font             = Enum.Font.Gotham
boxRename.TextSize         = 11
boxRename.BorderSizePixel  = 0
boxRename.ClearTextOnFocus = false
boxRename.ZIndex           = 8
boxRename.Parent           = rowRename
Instance.new("UICorner", boxRename).CornerRadius = UDim.new(0, 6)

boxRename.FocusLost:Connect(function()
    if selectedPlayer then
        local data = getPlayerData(selectedPlayer)
        data.CustomName = boxRename.Text
        saveConfig()
        updatePlayerList()
    end
end)

-- ==================== Gaveta 3: Cor da Aura (Jogadores Selecionados) ====================
local lblColor = Instance.new("TextLabel")
lblColor.Size                   = UDim2.new(1, -28, 0, 16)
lblColor.Position               = UDim2.new(0, 14, 0, 284)
lblColor.BackgroundTransparency = 1
lblColor.Text                   = "Cor da Aura do Jogador:"
lblColor.TextColor3             = Color3.fromRGB(200, 160, 170)
lblColor.Font                   = Enum.Font.GothamSemibold
lblColor.TextSize               = 11
lblColor.TextXAlignment         = Enum.TextXAlignment.Left
lblColor.ZIndex                 = 7
lblColor.Parent                 = mainFrame

btnColorDropdown = Instance.new("TextButton")
btnColorDropdown.Size             = UDim2.new(1, -28, 0, 28)
btnColorDropdown.Position         = UDim2.new(0, 14, 0, 302)
btnColorDropdown.BackgroundColor3 = Color3.fromRGB(35, 10, 18)
btnColorDropdown.Text             = "  Selecione uma cor ▼"
btnColorDropdown.TextColor3       = Color3.fromRGB(255, 255, 255)
btnColorDropdown.Font             = Enum.Font.GothamSemibold
btnColorDropdown.TextSize         = 11
btnColorDropdown.TextXAlignment   = Enum.TextXAlignment.Left
btnColorDropdown.BorderSizePixel  = 0
btnColorDropdown.ZIndex           = 7
btnColorDropdown.Parent           = mainFrame
Instance.new("UICorner", btnColorDropdown).CornerRadius = UDim.new(0, 6)

colorDropContainer = Instance.new("Frame")
colorDropContainer.Size                 = UDim2.new(1, -28, 0, 190)
colorDropContainer.Position             = UDim2.new(0, 14, 0, 334)
colorDropContainer.BackgroundColor3     = Color3.fromRGB(25, 8, 14)
colorDropContainer.BorderSizePixel      = 0
colorDropContainer.Visible              = false
colorDropContainer.ZIndex               = 30
colorDropContainer.Parent               = mainFrame
Instance.new("UICorner", colorDropContainer).CornerRadius = UDim.new(0, 6)

local cDropStroke = Instance.new("UIStroke")
cDropStroke.Color = Color3.fromRGB(150, 30, 50)
cDropStroke.Thickness = 1
cDropStroke.Parent = colorDropContainer

local playerColorListFrame = Instance.new("ScrollingFrame")
playerColorListFrame.Size               = UDim2.new(1, -12, 1, -12)
playerColorListFrame.Position           = UDim2.new(0, 6, 0, 6)
playerColorListFrame.BackgroundTransparency = 1
playerColorListFrame.BorderSizePixel    = 0
playerColorListFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
playerColorListFrame.ScrollBarThickness = 3
playerColorListFrame.ZIndex             = 31
playerColorListFrame.Parent             = colorDropContainer

local playerCategoryFrames = {}

local function updatePlayerColorListCanvas()
    local currentY = 0
    for _, catGroup in ipairs(playerCategoryFrames) do
        catGroup.Header.Position = UDim2.new(0, 2, 0, currentY)
        currentY = currentY + 28
        
        if catGroup.Container.Visible then
            catGroup.Container.Position = UDim2.new(0, 8, 0, currentY)
            local containerHeight = #catGroup.Items * 25
            catGroup.Container.Size = UDim2.new(1, -12, 0, containerHeight)
            currentY = currentY + containerHeight + 4
        else
            currentY = currentY + 2
        end
    end
    playerColorListFrame.CanvasSize = UDim2.new(0, 0, 0, currentY + 10)
end

local function populatePlayerColorList()
    for _, categoryData in ipairs(PLAYER_COLOR_CATEGORIES) do
        local catHeader = Instance.new("TextButton")
        catHeader.Size = UDim2.new(1, -4, 0, 26)
        catHeader.BackgroundColor3 = Color3.fromRGB(42, 12, 22)
        catHeader.Text = "  ▶ " .. categoryData.Category
        catHeader.TextColor3 = Color3.fromRGB(255, 220, 225)
        catHeader.Font = Enum.Font.GothamBold
        catHeader.TextSize = 11
        catHeader.TextXAlignment = Enum.TextXAlignment.Left
        catHeader.BorderSizePixel = 0
        catHeader.ZIndex = 32
        catHeader.Parent = playerColorListFrame
        Instance.new("UICorner", catHeader).CornerRadius = UDim.new(0, 4)

        local catSample = Instance.new("Frame")
        catSample.Size = UDim2.new(0, 12, 0, 12)
        catSample.Position = UDim2.new(1, -22, 0.5, -6)
        catSample.BackgroundColor3 = categoryData.MainColor
        catSample.BorderSizePixel = 0
        catSample.ZIndex = 33
        catSample.Parent = catHeader
        Instance.new("UICorner", catSample).CornerRadius = UDim.new(0, 3)

        local varContainer = Instance.new("Frame")
        varContainer.BackgroundTransparency = 1
        varContainer.BorderSizePixel = 0
        varContainer.ZIndex = 32
        varContainer.Visible = false
        varContainer.Parent = playerColorListFrame

        local varLayout = Instance.new("UIListLayout")
        varLayout.Padding = UDim.new(0, 2)
        varLayout.SortOrder = Enum.SortOrder.LayoutOrder
        varLayout.Parent = varContainer

        table.insert(playerCategoryFrames, {
            Header = catHeader,
            Container = varContainer,
            Items = categoryData.Variations
        })

        for vIdx, varItem in ipairs(categoryData.Variations) do
            local varBtn = Instance.new("TextButton")
            varBtn.Size = UDim2.new(1, 0, 0, 23)
            varBtn.BackgroundColor3 = Color3.fromRGB(22, 6, 12)
            varBtn.Text = "        " .. varItem.Name
            varBtn.TextColor3 = Color3.fromRGB(230, 230, 235)
            varBtn.Font = Enum.Font.Gotham
            varBtn.TextSize = 11
            varBtn.TextXAlignment = Enum.TextXAlignment.Left
            varBtn.BorderSizePixel = 0
            varBtn.LayoutOrder = vIdx
            varBtn.ZIndex = 33
            varBtn.Parent = varContainer
            Instance.new("UICorner", varBtn).CornerRadius = UDim.new(0, 4)

            local sample = Instance.new("Frame")
            sample.Size = UDim2.new(0, 10, 0, 10)
            sample.Position = UDim2.new(0, 12, 0.5, -5)
            sample.BackgroundColor3 = varItem.Color
            sample.BorderSizePixel = 0
            sample.ZIndex = 34
            sample.Parent = varBtn
            Instance.new("UICorner", sample).CornerRadius = UDim.new(0, 3)

            varBtn.MouseButton1Click:Connect(function()
                if selectedPlayer then
                    local data = getPlayerData(selectedPlayer)
                    data.Color = varItem.Color
                    btnColorDropdown.Text = "  " .. varItem.Name .. " ▼"
                    colorDropContainer.Visible = false
                    saveConfig()
                end
            end)
        end

        local isExpanded = false
        catHeader.MouseButton1Click:Connect(function()
            isExpanded = not isExpanded
            varContainer.Visible = isExpanded
            catHeader.Text = (isExpanded and "  ▼ " or "  ▶ ") .. categoryData.Category
            updatePlayerColorListCanvas()
        end)
    end

    updatePlayerColorListCanvas()
end

populatePlayerColorList()

btnColorDropdown.MouseButton1Click:Connect(function()
    selfColorDropContainer.Visible = false
    playerDropContainer.Visible    = false
    colorDropContainer.Visible     = not colorDropContainer.Visible
end)

-- Rodapé
local hint = Instance.new("TextLabel")
hint.Size                   = UDim2.new(1, 0, 0, 20)
hint.Position               = UDim2.new(0, 0, 1, -22)
hint.BackgroundTransparency = 1
hint.Text                   = "[RightShift] Ocultar / Mostrar Menu"
hint.TextColor3             = Color3.fromRGB(160, 100, 110)
hint.Font                   = Enum.Font.Gotham
hint.TextSize               = 11
hint.ZIndex                 = 6
hint.Parent                 = mainFrame

-- Hotkey Hide/Show
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("Kisaragi Eyes Carregado com Sucesso!")
