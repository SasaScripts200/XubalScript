--[[
    Painel simples: Velocidade | Vida | NoClip
    Uso (executor):
        loadstring(game:HttpGet("SEU_LINK_RAW_AQUI"))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GUI_NAME = "PainelFuncoes"

---------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------
local state = {
    speed = nil,      -- velocidade personalizada (nil = não alterar)
    noclip = false,
}
local connections = {}

local function track(conn)
    table.insert(connections, conn)
    return conn
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getGuiParent()
    local ok, ui = pcall(function()
        return gethui and gethui()
    end)
    if ok and ui then
        return ui
    end
    ok, ui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and ui then
        return ui
    end
    return player:WaitForChild("PlayerGui")
end

local parent = getGuiParent()

-- Remove versão anterior caso o script seja executado de novo
local old = parent:FindFirstChild(GUI_NAME)
if old then
    old:Destroy()
end

---------------------------------------------------------------------
-- Funções
---------------------------------------------------------------------
local function applySpeed(value)
    state.speed = value
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = value
    end
end

local function applyHealth(value)
    local hum = getHumanoid()
    if hum then
        hum.MaxHealth = value
        hum.Health = value
    end
end

local function setNoclip(enabled)
    state.noclip = enabled
end

-- Mantém a velocidade (alguns jogos tentam resetar) e aplica NoClip
track(RunService.Stepped:Connect(function()
    local char = player.Character
    if not char then
        return
    end

    if state.noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    if state.speed then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= state.speed then
            hum.WalkSpeed = state.speed
        end
    end
end))

-- Reaplica a velocidade ao renascer
track(player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum and state.speed then
        hum.WalkSpeed = state.speed
    end
end))

---------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------
local COLORS = {
    bg = Color3.fromRGB(25, 25, 32),
    button = Color3.fromRGB(45, 45, 58),
    buttonOn = Color3.fromRGB(60, 160, 90),
    accent = Color3.fromRGB(90, 120, 255),
    box = Color3.fromRGB(35, 35, 45),
    text = Color3.fromRGB(240, 240, 245),
    error = Color3.fromRGB(200, 70, 70),
}

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = parent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 230, 0, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0.5, -115, 0.3, 0)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = screenGui
corner(main, 12)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = main

-- Barra de título (arrastar a janela por aqui)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundTransparency = 1
titleBar.LayoutOrder = 0
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 1, 0)
title.BackgroundTransparency = 1
title.Text = "Painel"
title.TextColor3 = COLORS.text
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -26, 0, 1)
closeBtn.BackgroundColor3 = COLORS.error
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
corner(closeBtn, 6)

closeBtn.MouseButton1Click:Connect(function()
    state.noclip = false
    state.speed = nil
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    screenGui:Destroy()
end)

-- Arrastar (mouse e toque)
do
    local dragging, dragStart, startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local function makeButton(text, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = COLORS.button
    btn.Text = text
    btn.TextColor3 = COLORS.text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.LayoutOrder = order
    btn.AutoButtonColor = true
    btn.Parent = main
    corner(btn, 8)
    return btn
end

-- Cria um botão que, ao clicar, mostra/oculta uma caixa de texto logo abaixo
local function makeInputSection(label, placeholder, order, onApply)
    local btn = makeButton(label, order)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 32)
    box.BackgroundColor3 = COLORS.box
    box.Text = ""
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
    box.TextColor3 = COLORS.text
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.ClearTextOnFocus = false
    box.Visible = false
    box.LayoutOrder = order + 1 -- fica logo abaixo do botão
    box.Parent = main
    corner(box, 8)

    btn.MouseButton1Click:Connect(function()
        box.Visible = not box.Visible
        btn.BackgroundColor3 = box.Visible and COLORS.accent or COLORS.button
        if box.Visible then
            box:CaptureFocus()
        end
    end)

    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value and value >= 0 then
            onApply(value)
        elseif box.Text ~= "" then
            box.Text = ""
            box.PlaceholderText = "Digite um número válido"
        end
    end)
end

-- Ordens: botão = 10 / 20 (caixa = 11 / 21), NoClip = 30
makeInputSection("Aumentar velocidade", "Velocidade (padrão: 16)", 10, applySpeed)
makeInputSection("Aumentar vida", "Vida (padrão: 100)", 20, applyHealth)

local noclipBtn = makeButton("NoClip: OFF", 30)
noclipBtn.MouseButton1Click:Connect(function()
    setNoclip(not state.noclip)
    noclipBtn.Text = state.noclip and "NoClip: ON" or "NoClip: OFF"
    noclipBtn.BackgroundColor3 = state.noclip and COLORS.buttonOn or COLORS.button
end)
