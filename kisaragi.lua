-- ==================== Services ====================
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ==================== Config Global & Save System ====================
local ESPNameEnabled   = true
local ESPAuraEnabled   = true
local BlindnessEnabled = false
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

-- [UserId] = { Color = {r, g, b}, CustomName = string }
local playerData = {}

local function saveConfig()
    if writefile then
        pcall(function()
            local rawData = {}
            for userId, data in pairs(playerData) do
                rawData[tostring(userId)] = {
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
            for userIdStr, data in pairs(decoded) do
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

-- ==================== Aura Própria (Vermelho Vinho) ====================
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
        -- Cor Vermelho Vinho elegante
        local vinhoColor = Color3.fromRGB(115, 10, 30)
        selfHighlight.FillColor = vinhoColor
        selfHighlight.OutlineColor = vinhoColor
        selfHighlight.Enabled = true
    else
        if selfHighlight then
            selfHighlight:Destroy()
        end
    end
end

-- ==================== Sistema de Cegueira ====================
local function setBlindnessMode(enable)
    BlindnessEnabled = enable

    if enable then
        -- Salva o estado original do Lighting
        originalLighting.ClockTime      = Lighting.ClockTime
        originalLighting.Brightness     = Lighting.Brightness
        originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
        originalLighting.Ambient        = Lighting.Ambient
        originalLighting.GlobalShadows  = Lighting.GlobalShadows
        originalLighting.FogStart       = Lighting.FogStart
        originalLighting.FogEnd         = Lighting.FogEnd
        originalLighting.FogColor       = Lighting.FogColor

        -- Deixa a iluminação do mapa em preto total
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
    else
        -- Restaura as configurações originais
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
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if BlindnessEnabled then
        updateSelfAura(true)
    end
end)

-- ==================== Tabela de Cores Deduplicada ====================
local COLOR_PALETTE = {
    { Name = "Vermelho",        Color = Color3.fromRGB(255, 0, 0) },
    { Name = "Azul",            Color = Color3.fromRGB(0, 120, 255) },
    { Name = "Amarelo",         Color = Color3.fromRGB(255, 230, 0) },
    { Name = "Verde",           Color = Color3.fromRGB(0, 220, 100) },
    { Name = "Laranja",         Color = Color3.fromRGB(255, 130, 0) },
    { Name = "Roxo",            Color = Color3.fromRGB(150, 40, 255) },
    { Name = "Rosa",            Color = Color3.fromRGB(255, 105, 180) },
    { Name = "Marrom",          Color = Color3.fromRGB(139, 69, 19) },
    { Name = "Preto",           Color = Color3.fromRGB(20, 20, 25) },
    { Name = "Branco",          Color = Color3.fromRGB(255, 255, 255) },
    { Name = "Cinza",           Color = Color3.fromRGB(128, 128, 128) },
    { Name = "Ciano",           Color = Color3.fromRGB(0, 230, 255) },
    { Name = "Magenta",         Color = Color3.fromRGB(255, 0, 255) },
    { Name = "Turquesa",        Color = Color3.fromRGB(64, 224, 208) },
    { Name = "Índigo",          Color = Color3.fromRGB(75, 0, 130) },
    { Name = "Violeta",         Color = Color3.fromRGB(170, 90, 255) },
    { Name = "Anil",            Color = Color3.fromRGB(15, 82, 186) },
    { Name = "Carmim",          Color = Color3.fromRGB(220, 20, 60) },
    { Name = "Escarlate",       Color = Color3.fromRGB(255, 36, 0) },
    { Name = "Bordô",           Color = Color3.fromRGB(128, 0, 32) },
    { Name = "Borgonha",        Color = Color3.fromRGB(128, 0, 32) },
    { Name = "Rubi",            Color = Color3.fromRGB(155, 17, 30) },
    { Name = "Coral",           Color = Color3.fromRGB(255, 127, 80) },
    { Name = "Salmão",          Color = Color3.fromRGB(250, 128, 114) },
    { Name = "Pêssego",         Color = Color3.fromRGB(255, 218, 185) },
    { Name = "Âmbar",           Color = Color3.fromRGB(255, 191, 0) },
    { Name = "Ocre",            Color = Color3.fromRGB(204, 119, 34) },
    { Name = "Mostarda",        Color = Color3.fromRGB(225, 173, 1) },
    { Name = "Dourado",         Color = Color3.fromRGB(255, 215, 0) },
    { Name = "Bronze",          Color = Color3.fromRGB(205, 127, 50) },
    { Name = "Cobre",           Color = Color3.fromRGB(184, 115, 51) },
    { Name = "Bege",            Color = Color3.fromRGB(245, 245, 220) },
    { Name = "Creme",           Color = Color3.fromRGB(255, 253, 208) },
    { Name = "Marfim",          Color = Color3.fromRGB(255, 255, 240) },
    { Name = "Caqui",           Color = Color3.fromRGB(195, 176, 145) },
    { Name = "Oliva",           Color = Color3.fromRGB(128, 128, 0) },
    { Name = "Esmeralda",       Color = Color3.fromRGB(80, 200, 120) },
    { Name = "Jade",            Color = Color3.fromRGB(0, 168, 107) },
    { Name = "Menta",           Color = Color3.fromRGB(152, 251, 152) },
    { Name = "Musgo",           Color = Color3.fromRGB(138, 154, 91) },
    { Name = "Pistache",        Color = Color3.fromRGB(147, 197, 114) },
    { Name = "Lima",            Color = Color3.fromRGB(191, 255, 0) },
    { Name = "Chartreuse",      Color = Color3.fromRGB(127, 255, 0) },
    { Name = "Água-marinha",    Color = Color3.fromRGB(127, 255, 212) },
    { Name = "Safira",          Color = Color3.fromRGB(15, 82, 186) },
    { Name = "Cobalto",         Color = Color3.fromRGB(0, 71, 171) },
    { Name = "Cerúleo",         Color = Color3.fromRGB(42, 82, 190) },
    { Name = "Ultramarino",     Color = Color3.fromRGB(18, 10, 143) },
    { Name = "Azul-petróleo",   Color = Color3.fromRGB(0, 95, 105) },
    { Name = "Lavanda",         Color = Color3.fromRGB(230, 230, 250) },
    { Name = "Lilás",           Color = Color3.fromRGB(200, 162, 200) },
    { Name = "Ameixa",          Color = Color3.fromRGB(221, 160, 221) },
    { Name = "Ametista",        Color = Color3.fromRGB(153, 102, 204) },
    { Name = "Púrpura",         Color = Color3.fromRGB(128, 0, 128) },
    { Name = "Fúcsia",          Color = Color3.fromRGB(255, 0, 255) },
    { Name = "Orquídea",        Color = Color3.fromRGB(218, 112, 214) },
    { Name = "Malva",           Color = Color3.fromRGB(224, 176, 255) },
    { Name = "Sépia",           Color = Color3.fromRGB(112, 66, 20) },
    { Name = "Terracota",       Color = Color3.fromRGB(226, 114, 91) },
    { Name = "Ferrugem",        Color = Color3.fromRGB(183, 65, 14) },
    { Name = "Canela",          Color = Color3.fromRGB(210, 105, 30) },
    { Name = "Caramelo",        Color = Color3.fromRGB(198, 115, 38) },
    { Name = "Chocolate",       Color = Color3.fromRGB(123, 63, 0) },
    { Name = "Café",            Color = Color3.fromRGB(111, 78, 55) },
    { Name = "Mogno",           Color = Color3.fromRGB(192, 64, 0) },
    { Name = "Ébano",           Color = Color3.fromRGB(40, 40, 45) },
    { Name = "Siena",           Color = Color3.fromRGB(160, 82, 45) },
    { Name = "Prata",           Color = Color3.fromRGB(192, 192, 192) },
    { Name = "Platina",         Color = Color3.fromRGB(229, 228, 226) },
    { Name = "Titânio",         Color = Color3.fromRGB(135, 134, 129) },
    { Name = "Grafite",         Color = Color3.fromRGB(56, 56, 56) },
    { Name = "Chumbo",          Color = Color3.fromRGB(80, 80, 90) },
    { Name = "Pérola",          Color = Color3.fromRGB(240, 234, 214) },
    { Name = "Opala",           Color = Color3.fromRGB(168, 195, 188) },
    { Name = "Granada",         Color = Color3.fromRGB(131, 29, 28) },
    { Name = "Topázio",         Color = Color3.fromRGB(255, 200, 124) },
    { Name = "Obsidiana",       Color = Color3.fromRGB(27, 26, 31) },
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
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "KisaragiEyes_Gui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== Main Frame ====================
local mainFrame = Instance.new("Frame")
mainFrame.Size                 = UDim2.new(0, 340, 0, 520)
mainFrame.Position             = UDim2.new(0.5, -170, 0.5, -260)
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

createSwitch(mainFrame, "Exibir Nomes ESP", ESPNameEnabled, 52, function(val)
    ESPNameEnabled = val
end)

createSwitch(mainFrame, "Exibir Aura Visual", ESPAuraEnabled, 84, function(val)
    ESPAuraEnabled = val
end)

createSwitch(mainFrame, "Cegueira / Visão Noturna", BlindnessEnabled, 116, function(val)
    setBlindnessMode(val)
end)

-- ==================== Dropdown 1: Seleção de Jogador ====================
local lblSelectPlayer = Instance.new("TextLabel")
lblSelectPlayer.Size                   = UDim2.new(1, -28, 0, 16)
lblSelectPlayer.Position               = UDim2.new(0, 14, 0, 150)
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
btnPlayerDropdown.Position         = UDim2.new(0, 14, 0, 168)
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

local playerDropContainer = Instance.new("Frame")
playerDropContainer.Size                 = UDim2.new(1, -28, 0, 145)
playerDropContainer.Position             = UDim2.new(0, 14, 0, 200)
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

-- Caixa de Pesquisa
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
    playerDropContainer.Visible = not playerDropContainer.Visible
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
task.defer(updatePlayerList)

-- ==================== Edição de Apelido ====================
local rowRename = Instance.new("Frame")
rowRename.Size                   = UDim2.new(1, -28, 0, 28)
rowRename.Position               = UDim2.new(0, 14, 0, 204)
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

-- ==================== Dropdown 2: Seleção de Cor ====================
local lblColor = Instance.new("TextLabel")
lblColor.Size                   = UDim2.new(1, -28, 0, 16)
lblColor.Position               = UDim2.new(0, 14, 0, 240)
lblColor.BackgroundTransparency = 1
lblColor.Text                   = "Cor da Aura:"
lblColor.TextColor3             = Color3.fromRGB(200, 160, 170)
lblColor.Font                   = Enum.Font.GothamSemibold
lblColor.TextSize               = 11
lblColor.TextXAlignment         = Enum.TextXAlignment.Left
lblColor.ZIndex                 = 7
lblColor.Parent                 = mainFrame

btnColorDropdown = Instance.new("TextButton")
btnColorDropdown.Size             = UDim2.new(1, -28, 0, 28)
btnColorDropdown.Position         = UDim2.new(0, 14, 0, 258)
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

local colorDropContainer = Instance.new("Frame")
colorDropContainer.Size                 = UDim2.new(1, -28, 0, 180)
colorDropContainer.Position             = UDim2.new(0, 14, 0, 290)
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

local colorListFrame = Instance.new("ScrollingFrame")
colorListFrame.Size               = UDim2.new(1, -12, 1, -12)
colorListFrame.Position           = UDim2.new(0, 6, 0, 6)
colorListFrame.BackgroundTransparency = 1
colorListFrame.BorderSizePixel    = 0
colorListFrame.CanvasSize         = UDim2.new(0, 0, 0, #COLOR_PALETTE * 25)
colorListFrame.ScrollBarThickness = 3
colorListFrame.ZIndex             = 31
colorListFrame.Parent             = colorDropContainer

local colorListLayout = Instance.new("UIListLayout")
colorListLayout.Padding = UDim.new(0, 3)
colorListLayout.Parent = colorListFrame

for _, cInfo in ipairs(COLOR_PALETTE) do
    local cBtn = Instance.new("TextButton")
    cBtn.Size             = UDim2.new(1, -4, 0, 22)
    cBtn.BackgroundColor3 = Color3.fromRGB(45, 12, 22)
    cBtn.Text             = "  " .. cInfo.Name
    cBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cBtn.Font             = Enum.Font.Gotham
    cBtn.TextSize         = 11
    cBtn.TextXAlignment   = Enum.TextXAlignment.Left
    cBtn.BorderSizePixel  = 0
    cBtn.ZIndex           = 32
    cBtn.Parent           = colorListFrame
    Instance.new("UICorner", cBtn).CornerRadius = UDim.new(0, 4)

    local preview = Instance.new("Frame")
    preview.Size             = UDim2.new(0, 14, 0, 14)
    preview.Position         = UDim2.new(1, -20, 0.5, -7)
    preview.BackgroundColor3 = cInfo.Color
    preview.BorderSizePixel  = 0
    preview.ZIndex           = 33
    preview.Parent           = cBtn
    Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 3)

    cBtn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            local data = getPlayerData(selectedPlayer)
            data.Color = cInfo.Color
            saveConfig()
            btnColorDropdown.Text = "  " .. cInfo.Name .. " ▼"
            colorDropContainer.Visible = false
        end
    end)
end

btnColorDropdown.MouseButton1Click:Connect(function()
    colorDropContainer.Visible = not colorDropContainer.Visible
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
