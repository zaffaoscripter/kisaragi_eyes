-- ==================== Services ====================
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ==================== Config Global ====================
local ESPNameEnabled = true

-- Tabela de configurações individuais por jogador
-- [UserId] = { Color = Color3, CustomName = string }
local playerData = {}

-- Paleta de cores expandida e suave
local COLOR_PALETTE = {
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
    { Name = "Prata",    Color = Color3.fromRGB(220, 225, 235) },
    { Name = "Lava",     Color = Color3.fromRGB(255, 90, 30) },
}

local selectedPlayer = nil -- Jogador selecionado no menu

-- ==================== Objects & Drawing ====================
local espObjects = {}  -- [character] = { label = Drawing, highlight = Highlight }

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

-- ==================== Aura Suave e Agradável ====================
local function applyAura(character, color)
    local highlight = character:FindFirstChild("KisaragiAura")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "KisaragiAura"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.65 -- Transparência mais suave para não poluir
        highlight.OutlineTransparency = 0.15
        highlight.Parent = character
    end
    highlight.FillColor = color
    highlight.OutlineColor = color
    return highlight
end

local function getPlayerData(player)
    if not playerData[player.UserId] then
        playerData[player.UserId] = {
            Color = Color3.fromRGB(170, 90, 255), -- Cor padrão inicial (Violeta)
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
    -- Pulsação suave e sutil na aura
    local pulse = (math.sin(tick() * 2.5) + 1) * 0.05

    for character, obj in pairs(espObjects) do
        local player = obj.player
        if player then
            local data = getPlayerData(player)

            -- Atualiza Cor da Aura Individual
            if obj.highlight then
                obj.highlight.FillColor = data.Color
                obj.highlight.OutlineColor = data.Color
                obj.highlight.FillTransparency = 0.65 + pulse
            end

            -- Atualiza Texto do Nome Individual
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
    playerData[p.UserId] = nil
end)

-- ==================== ScreenGui ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "KisaragiEyes_Gui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== Main Frame ====================
local mainFrame = Instance.new("Frame")
mainFrame.Size                   = UDim2.new(0, 340, 0, 390)
mainFrame.Position               = UDim2.new(0.5, -170, 0.5, -195)
mainFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 20)
mainFrame.BackgroundTransparency = 0.08
mainFrame.BorderSizePixel        = 0
mainFrame.Visible                = true
mainFrame.Active                 = true
mainFrame.Parent                 = screenGui
mainFrame.ZIndex                 = 5
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color        = Color3.fromRGB(170, 90, 255)
frameStroke.Thickness    = 1.4
frameStroke.Transparency = 0.3
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
titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextSize               = 17
titleLabel.ZIndex                 = 7
titleLabel.Parent                 = mainFrame

local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -28, 0, 1)
sep.Position         = UDim2.new(0, 14, 0, 42)
sep.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sep.BorderSizePixel  = 0
sep.ZIndex           = 7
sep.Parent           = mainFrame

-- ==================== Toggle Global ====================
local rowToggle = Instance.new("Frame")
rowToggle.Size               = UDim2.new(1, -28, 0, 28)
rowToggle.Position           = UDim2.new(0, 14, 0, 52)
rowToggle.BackgroundTransparency = 1
rowToggle.ZIndex             = 6
rowToggle.Parent             = mainFrame

local lblToggle = Instance.new("TextLabel")
lblToggle.Size               = UDim2.new(0.7, 0, 1, 0)
lblToggle.BackgroundTransparency = 1
lblToggle.Text               = "Exibir Nomes ESP"
lblToggle.TextColor3         = Color3.fromRGB(220, 220, 235)
lblToggle.Font               = Enum.Font.GothamSemibold
lblToggle.TextSize           = 13
lblToggle.TextXAlignment     = Enum.TextXAlignment.Left
lblToggle.ZIndex             = 7
lblToggle.Parent             = rowToggle

local btnToggle = Instance.new("TextButton")
btnToggle.Size             = UDim2.new(0, 55, 0, 24)
btnToggle.Position         = UDim2.new(1, -55, 0.5, -12)
btnToggle.BackgroundColor3 = ESPNameEnabled and Color3.fromRGB(170, 90, 255) or Color3.fromRGB(35, 35, 45)
btnToggle.Text             = ESPNameEnabled and "ON" or "OFF"
btnToggle.TextColor3       = Color3.fromRGB(255, 255, 255)
btnToggle.Font             = Enum.Font.GothamBold
btnToggle.TextSize         = 12
btnToggle.BorderSizePixel  = 0
btnToggle.ZIndex           = 8
btnToggle.Parent           = rowToggle
Instance.new("UICorner", btnToggle).CornerRadius = UDim.new(0, 6)

btnToggle.MouseButton1Click:Connect(function()
    ESPNameEnabled = not ESPNameEnabled
    btnToggle.BackgroundColor3 = ESPNameEnabled and Color3.fromRGB(170, 90, 255) or Color3.fromRGB(35, 35, 45)
    btnToggle.Text             = ESPNameEnabled and "ON" or "OFF"
end)

-- ==================== Lista de Jogadores ====================
local lblPlayerList = Instance.new("TextLabel")
lblPlayerList.Size               = UDim2.new(1, -28, 0, 18)
lblPlayerList.Position           = UDim2.new(0, 14, 0, 86)
lblPlayerList.BackgroundTransparency = 1
lblPlayerList.Text               = "Selecione um Jogador:"
lblPlayerList.TextColor3         = Color3.fromRGB(170, 170, 190)
lblPlayerList.Font               = Enum.Font.GothamSemibold
lblPlayerList.TextSize           = 12
lblPlayerList.TextXAlignment     = Enum.TextXAlignment.Left
lblPlayerList.ZIndex             = 7
lblPlayerList.Parent             = mainFrame

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size               = UDim2.new(1, -28, 0, 75)
playerListFrame.Position           = UDim2.new(0, 14, 0, 108)
playerListFrame.BackgroundColor3   = Color3.fromRGB(22, 22, 30)
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
            btn.BackgroundColor3 = (selectedPlayer == p) and Color3.fromRGB(50, 50, 75) or Color3.fromRGB(28, 28, 38)
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

-- ==================== Painel de Edição Individual ====================

-- Renomear
local rowRename = Instance.new("Frame")
rowRename.Size               = UDim2.new(1, -28, 0, 28)
rowRename.Position           = UDim2.new(0, 14, 0, 194)
rowRename.BackgroundTransparency = 1
rowRename.ZIndex             = 6
rowRename.Parent             = mainFrame

local lblRename = Instance.new("TextLabel")
lblRename.Size               = UDim2.new(0.4, 0, 1, 0)
lblRename.BackgroundTransparency = 1
lblRename.Text               = "Apelido:"
lblRename.TextColor3         = Color3.fromRGB(220, 220, 235)
lblRename.Font               = Enum.Font.GothamSemibold
lblRename.TextSize           = 13
lblRename.TextXAlignment     = Enum.TextXAlignment.Left
lblRename.ZIndex             = 7
lblRename.Parent             = rowRename

boxRename = Instance.new("TextBox")
boxRename.Size             = UDim2.new(0.6, 0, 0, 24)
boxRename.Position         = UDim2.new(0.4, 0, 0.5, -12)
boxRename.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
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
    end
end)

-- Paleta de Cores Expandida
local lblPalette = Instance.new("TextLabel")
lblPalette.Size               = UDim2.new(1, -28, 0, 18)
lblPalette.Position           = UDim2.new(0, 14, 0, 230)
lblPalette.BackgroundTransparency = 1
lblPalette.Text               = "Cor da Aura:"
lblPalette.TextColor3         = Color3.fromRGB(220, 220, 235)
lblPalette.Font               = Enum.Font.GothamSemibold
lblPalette.TextSize           = 13
lblPalette.TextXAlignment     = Enum.TextXAlignment.Left
lblPalette.ZIndex             = 7
lblPalette.Parent             = mainFrame

local paletteGrid = Instance.new("Frame")
paletteGrid.Size               = UDim2.new(1, -28, 0, 95)
paletteGrid.Position           = UDim2.new(0, 14, 0, 252)
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
        end
    end)
end

-- Rodapé
local hint = Instance.new("TextLabel")
hint.Size               = UDim2.new(1, 0, 0, 20)
hint.Position           = UDim2.new(0, 0, 1, -22)
hint.BackgroundTransparency = 1
hint.Text               = "[RightShift] Ocultar / Mostrar Menu"
hint.TextColor3         = Color3.fromRGB(110, 110, 130)
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

print("Kisaragi Eyes Carregado!")