-- ==================== Services ====================
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ==================== Config Global & Save System ====================
local ESPNameEnabled = true
local ESPAuraEnabled = true
local SAVE_FILE_NAME = "KisaragiEyes_Data.json"

-- [UserId] = { Color = {r, g, b}, CustomName = string }
local playerData = {}

-- Função para Salvar Chaves no File System do Executor
local function saveConfig()
    if writefile then
        local success, err = pcall(function()
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

-- Função para Carregar Chaves Salvas
local function loadConfig()
    if readfile and isfile and isfile(SAVE_FILE_NAME) then
        local success, result = pcall(function()
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

-- Paleta de cores expandida e suave
local COLOR_PALETTE = {
    { Name = "Prata",    Color = Color3.fromRGB(220, 225, 235) },
    { Name = "Ciano",    Color = Color3.fromRGB(0, 230, 255) },
    { Name = "Violeta",  Color = Color3.fromRGB(170, 90, 255) },
    { Name = "Magenta",  Color = Color3.fromRGB(255, 60, 180) },
    { Name = "Menta",    Color = Color3.fromRGB(80, 255, 175) },
    { Name = "Ouro",     Color = Color3.fromRGB(255, 215, 60) },
    { Name = "Pêssego",  Color = Color3.fromRGB(255, 140, 90) },
    { Name = "Carmim",   Color = Color3.fromRGB(255, 55, 80) },
    { Name = "Coral",    Color = Color3.fromRGB(255, 110, 150) },
    { Name = "Oceano",   Color = Color3.fromRGB(50, 150, 255) },
    { Name = "Esmeralda",Color = Color3.fromRGB(40, 220, 120) },
    { Name = "Lava",     Color = Color3.fromRGB(255, 90, 30) },
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
            Color = Color3.fromRGB(220, 225, 235), -- Cor padrão Prata
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

-- ==================== Main Frame (Vermelho Carmesim Transparente) ====================
local mainFrame = Instance.new("Frame")
mainFrame.Size                   = UDim2.new(0, 340, 0, 420)
mainFrame.Position               = UDim2.new(0.5, -170, 0.5, -210)
mainFrame.BackgroundColor3       = Color3.fromRGB(35, 5, 12) -- Carmesim Bem Escuro
mainFrame.BackgroundTransparency = 0.25 -- Transparência Elegante
mainFrame.BorderSizePixel        = 0
mainFrame.Visible                = true
mainFrame.Active                 = true
mainFrame.Parent                 = screenGui
mainFrame.ZIndex                 = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color        = Color3.fromRGB(180, 20, 50)
frameStroke.Thickness    = 1.5
frameStroke.Transparency = 0.2
frameStroke.Parent       = mainFrame

-- ==================== Drag System ====================
local titleBar = Instance.new("Frame")
titleBar.Size               = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex             = 9
titleBar.Parent             = mainFrame

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
titleLabel.TextColor3             = Color3.fromRGB(255, 220, 225)
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextSize               = 17
titleLabel.ZIndex                 = 7
titleLabel.Parent                 = mainFrame

local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -28, 0, 1)
sep.Position         = UDim2.new(0, 14, 0, 42)
sep.BackgroundColor3 = Color3.fromRGB(80, 20, 35)
sep.BorderSizePixel  = 0
sep.ZIndex           = 7
sep.Parent           = mainFrame

-- ==================== Toggles (Nomes & Aura) ====================
local rowToggleNames = Instance.new("Frame")
rowToggleNames.Size               = UDim2.new(1, -28, 0, 24)
rowToggleNames.Position           = UDim2.new(0, 14, 0, 50)
rowToggleNames.BackgroundTransparency = 1
rowToggleNames.ZIndex             = 6
rowToggleNames.Parent             = mainFrame

local lblToggleNames = Instance.new("TextLabel")
lblToggleNames.Size               = UDim2.new(0.7, 0, 1, 0)
lblToggleNames.BackgroundTransparency = 1
lblToggleNames.Text               = "Exibir Nomes ESP"
lblToggleNames.TextColor3         = Color3.fromRGB(240, 220, 225)
lblToggleNames.Font               = Enum.Font.GothamSemibold
lblToggleNames.TextSize           = 12
lblToggleNames.TextXAlignment     = Enum.TextXAlignment.Left
lblToggleNames.ZIndex             = 7
lblToggleNames.Parent             = rowToggleNames

local btnToggleNames = Instance.new("TextButton")
btnToggleNames.Size             = UDim2.new(0, 50, 0, 20)
btnToggleNames.Position         = UDim2.new(1, -50, 0.5, -10)
btnToggleNames.BackgroundColor3 = ESPNameEnabled and Color3.fromRGB(180, 20, 50) or Color3.fromRGB(45, 15, 25)
btnToggleNames.Text             = ESPNameEnabled and "ON" or "OFF"
btnToggleNames.TextColor3       = Color3.fromRGB(255, 255, 255)
btnToggleNames.Font             = Enum.Font.GothamBold
btnToggleNames.TextSize         = 11
btnToggleNames.BorderSizePixel  = 0
btnToggleNames.ZIndex           = 8
btnToggleNames.Parent           = rowToggleNames
Instance.new("UICorner", btnToggleNames).CornerRadius = UDim.new(0, 5)

btnToggleNames.MouseButton1Click:Connect(function()
    ESPNameEnabled = not ESPNameEnabled
    btnToggleNames.BackgroundColor3 = ESPNameEnabled and Color3.fromRGB(180, 20, 50) or Color3.fromRGB(45, 15, 25)
    btnToggleNames.Text             = ESPNameEnabled and "ON" or "OFF"
end)

local rowToggleAura = Instance.new("Frame")
rowToggleAura.Size               = UDim2.new(1, -28, 0, 24)
rowToggleAura.Position           = UDim2.new(0, 14, 0, 78)
rowToggleAura.BackgroundTransparency = 1
rowToggleAura.ZIndex             = 6
rowToggleAura.Parent             = mainFrame

local lblToggleAura = Instance.new("TextLabel")
lblToggleAura.Size               = UDim2.new(0.7, 0, 1, 0)
lblToggleAura.BackgroundTransparency = 1
lblToggleAura.Text               = "Exibir Aura Visual"
lblToggleAura.TextColor3         = Color3.fromRGB(240, 220, 225)
lblToggleAura.Font               = Enum.Font.GothamSemibold
lblToggleAura.TextSize           = 12
lblToggleAura.TextXAlignment     = Enum.TextXAlignment.Left
lblToggleAura.ZIndex             = 7
lblToggleAura.Parent             = rowToggleAura

local btnToggleAura = Instance.new("TextButton")
btnToggleAura.Size             = UDim2.new(0, 50, 0, 20)
btnToggleAura.Position         = UDim2.new(1, -50, 0.5, -10)
btnToggleAura.BackgroundColor3 = ESPAuraEnabled and Color3.fromRGB(180, 20, 50) or Color3.fromRGB(45, 15, 25)
btnToggleAura.Text             = ESPAuraEnabled and "ON" or "OFF"
btnToggleAura.TextColor3       = Color3.fromRGB(255, 255, 255)
btnToggleAura.Font             = Enum.Font.GothamBold
btnToggleAura.TextSize         = 11
btnToggleAura.BorderSizePixel  = 0
btnToggleAura.ZIndex           = 8
btnToggleAura.Parent           = rowToggleAura
Instance.new("UICorner", btnToggleAura).CornerRadius = UDim.new(0, 5)

btnToggleAura.MouseButton1Click:Connect(function()
    ESPAuraEnabled = not ESPAuraEnabled
    btnToggleAura.BackgroundColor3 = ESPAuraEnabled and Color3.fromRGB(180, 20, 50) or Color3.fromRGB(45, 15, 25)
    btnToggleAura.Text             = ESPAuraEnabled and "ON" or "OFF"
end)

-- ==================== Lista de Jogadores ====================
local lblPlayerList = Instance.new("TextLabel")
lblPlayerList.Size               = UDim2.new(1, -28, 0, 16)
lblPlayerList.Position           = UDim2.new(0, 14, 0, 108)
lblPlayerList.BackgroundTransparency = 1
lblPlayerList.Text               = "Selecione um Jogador:"
lblPlayerList.TextColor3         = Color3.fromRGB(200, 160, 170)
lblPlayerList.Font               = Enum.Font.GothamSemibold
lblPlayerList.TextSize           = 11
lblPlayerList.TextXAlignment     = Enum.TextXAlignment.Left
lblPlayerList.ZIndex             = 7
lblPlayerList.Parent             = mainFrame

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size               = UDim2.new(1, -28, 0, 75)
playerListFrame.Position           = UDim2.new(0, 14, 0, 126)
playerListFrame.BackgroundColor3   = Color3.fromRGB(20, 5, 10)
playerListFrame.BackgroundTransparency = 0.3
playerListFrame.BorderSizePixel    = 0
playerListFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
playerListFrame.ScrollBarThickness = 4
playerListFrame.ZIndex             = 6
playerListFrame.Parent             = mainFrame
Instance.new("UICorner", playerListFrame).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = playerListFrame

local playerButtons = {}
local boxRename = nil
local updatePlayerList = nil

updatePlayerList = function()
    for _, btn in pairs(playerButtons) do btn:Destroy() end
    playerButtons = {}

    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            count = count + 1
            local btn = Instance.new("TextButton")
            btn.Size             = UDim2.new(1, -6, 0, 22)
            btn.BackgroundColor3 = (selectedPlayer == p) and Color3.fromRGB(120, 20, 40) or Color3.fromRGB(45, 10, 20)
            btn.Text             = "  " .. p.Name
            btn.TextColor3       = Color3.fromRGB(255, 255, 255)
            btn.Font             = Enum.Font.Gotham
            btn.TextSize         = 12
            btn.TextXAlignment   = Enum.TextXAlignment.Left
            btn.BorderSizePixel  = 0
            btn.ZIndex           = 7
            btn.Parent           = playerListFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            btn.MouseButton1Click:Connect(function()
                selectedPlayer = p
                updatePlayerList()
                if boxRename and selectedPlayer then
                    local data = getPlayerData(selectedPlayer)
                    boxRename.Text = data.CustomName
                end
            end)
            
            table.insert(playerButtons, btn)
        end
    end
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 25)
end

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
task.defer(updatePlayerList)

-- ==================== Edição Individual ====================
local rowRename = Instance.new("Frame")
rowRename.Size               = UDim2.new(1, -28, 0, 28)
rowRename.Position           = UDim2.new(0, 14, 0, 210)
rowRename.BackgroundTransparency = 1
rowRename.ZIndex             = 6
rowRename.Parent             = mainFrame

local lblRename = Instance.new("TextLabel")
lblRename.Size               = UDim2.new(0.4, 0, 1, 0)
lblRename.BackgroundTransparency = 1
lblRename.Text               = "Apelido:"
lblRename.TextColor3         = Color3.fromRGB(240, 220, 225)
lblRename.Font               = Enum.Font.GothamSemibold
lblRename.TextSize           = 12
lblRename.TextXAlignment     = Enum.TextXAlignment.Left
lblRename.ZIndex             = 7
lblRename.Parent             = rowRename

boxRename = Instance.new("TextBox")
boxRename.Size             = UDim2.new(0.6, 0, 0, 24)
boxRename.Position         = UDim2.new(0.4, 0, 0.5, -12)
boxRename.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
boxRename.BackgroundTransparency = 0.3
boxRename.TextColor3       = Color3.fromRGB(255, 255, 255)
boxRename.PlaceholderText  = "Selecione um player"
boxRename.Text             = ""
boxRename.Font             = Enum.Font.Gotham
boxRename.TextSize         = 12
boxRename.BorderSizePixel  = 0
boxRename.ClearTextOnFocus = false
boxRename.ZIndex           = 8
boxRename.Parent           = rowRename
Instance.new("UICorner", boxRename).CornerRadius = UDim.new(0, 6)

boxRename.FocusLost:Connect(function()
    if selectedPlayer then
        local data = getPlayerData(selectedPlayer)
        data.CustomName = boxRename.Text
        saveConfig() -- Salva as alterações no ficheiro
    end
end)

-- Paleta de Cores
local lblPalette = Instance.new("TextLabel")
lblPalette.Size               = UDim2.new(1, -28, 0, 16)
lblPalette.Position           = UDim2.new(0, 14, 0, 246)
lblPalette.BackgroundTransparency = 1
lblPalette.Text               = "Cor da Aura:"
lblPalette.TextColor3         = Color3.fromRGB(240, 220, 225)
lblPalette.Font               = Enum.Font.GothamSemibold
lblPalette.TextSize           = 12
lblPalette.TextXAlignment     = Enum.TextXAlignment.Left
lblPalette.ZIndex             = 7
lblPalette.Parent             = mainFrame

local paletteGrid = Instance.new("Frame")
paletteGrid.Size               = UDim2.new(1, -28, 0, 95)
paletteGrid.Position           = UDim2.new(0, 14, 0, 266)
paletteGrid.BackgroundTransparency = 1
paletteGrid.ZIndex             = 6
paletteGrid.Parent             = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 72, 0, 22)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 5)
gridLayout.Parent = paletteGrid

for _, item in ipairs(COLOR_PALETTE) do
    local cBtn = Instance.new("TextButton")
    cBtn.Text             = item.Name
    cBtn.BackgroundColor3 = item.Color
    cBtn.TextColor3       = Color3.fromRGB(15, 15, 20)
    cBtn.Font             = Enum.Font.GothamBold
    cBtn.TextSize         = 9.5
    cBtn.BorderSizePixel  = 0
    cBtn.ZIndex           = 8
    cBtn.Parent           = paletteGrid
    Instance.new("UICorner", cBtn).CornerRadius = UDim.new(0, 5)

    cBtn.MouseButton1Click:Connect(function()
        if selectedPlayer then
            local data = getPlayerData(selectedPlayer)
            data.Color = item.Color
            saveConfig() -- Salva a nova cor
        end
    end)
end

-- Rodapé
local hint = Instance.new("TextLabel")
hint.Size               = UDim2.new(1, 0, 0, 20)
hint.Position           = UDim2.new(0, 0, 1, -22)
hint.BackgroundTransparency = 1
hint.Text               = "[RightShift] Ocultar / Mostrar Menu"
hint.TextColor3         = Color3.fromRGB(160, 100, 110)
hint.Font               = Enum.Font.Gotham
hint.TextSize           = 11
hint.ZIndex             = 6
hint.Parent             = mainFrame

-- ==================== Hotkeys ====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("Kisaragi Eyes Carregado com Sucesso!")
