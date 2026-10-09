--[[
    Painel: Velocidade | Vida | NoClip | Voar ao pegar item
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
    speed = nil,        -- velocidade personalizada (nil = não alterar)
    health = nil,       -- vida máxima personalizada (nil = não alterar)
    noclip = false,
    flyOnPickup = false,
    flyHeight = 100,    -- altura (studs) do impulso ao pegar item
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

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
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

-- Preenchida mais abaixo, quando a interface existir
local setStatus = function() end

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

-- Procura o Humanoid e a propriedade MaxHealth (etapa de "carregando")
-- Retorna o MaxHealth atual, ou nil se não achar
local function findMaxHealth()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then
        return nil
    end
    local ok, value = pcall(function()
        return hum.MaxHealth
    end)
    if ok then
        return value
    end
    return nil
end

local function applyHealth(value)
    state.health = value
    local hum = getHumanoid()
    if hum then
        hum.MaxHealth = value -- primeiro aumenta o limite...
        hum.Health = value    -- ...depois enche a vida
    end
end

local function setNoclip(enabled)
    state.noclip = enabled
end

-- Loop: NoClip + manter velocidade e vida máxima
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

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if state.speed and hum.WalkSpeed ~= state.speed then
            hum.WalkSpeed = state.speed
        end
        if state.health and hum.MaxHealth ~= state.health then
            hum.MaxHealth = state.health
        end
    end
end))

---------------------------------------------------------------------
-- Voar ao pegar item
-- Detecta item novo de 3 formas (qualquer uma dispara na hora):
--   1) Tool entrando na Backpack
--   2) Tool entrando direto no Character (alguns jogos fazem isso)
--   3) Quantidade total de Tools aumentando (Backpack + Character)
---------------------------------------------------------------------
local knownTools = setmetatable({}, { __mode = "k" }) -- ferramentas já vistas
local ignoreUntil = 0   -- ignora itens iniciais logo após renascer
local lastFly = 0
local backpackConn, charConn

local function launchUp()
    local char = player.Character
    local root = getRoot()
    if not (char and root) then
        return
    end
    root.AssemblyLinearVelocity = Vector3.zero
    char:PivotTo(char:GetPivot() + Vector3.new(0, state.flyHeight, 0))
end

local function onPickup(name)
    if not state.flyOnPickup then
        return
    end
    local now = os.clock()
    if now < ignoreUntil or now - lastFly < 0.5 then
        return
    end
    lastFly = now
    launchUp()
    setStatus("Item detectado: " .. tostring(name))
end

local function onToolAdded(item)
    if not item:IsA("Tool") then
        return
    end
    -- Se já era conhecido (ex.: equipou/desequipou), não é um "pegar"
    if knownTools[item] then
        return
    end
    knownTools[item] = true
    onPickup(item.Name)
end

local function watchBackpack(backpack)
    if backpackConn then
        backpackConn:Disconnect()
    end
    for _, item in ipairs(backpack:GetChildren()) do
        knownTools[item] = true
    end
    backpackConn = backpack.ChildAdded:Connect(onToolAdded)
    track(backpackConn)
end

local function watchCharacter(char)
    if charConn then
        charConn:Disconnect()
    end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            knownTools[item] = true
        end
    end
    charConn = char.ChildAdded:Connect(onToolAdded)
    track(charConn)
end

local function setupBackpack()
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
    if backpack then
        watchBackpack(backpack)
    end
end

local function countTools()
    local n = 0
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") then
                n += 1
            end
        end
    end
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then
                n += 1
            end
        end
    end
    return n
end

local lastCount = countTools()
track(RunService.Heartbeat:Connect(function()
    local count = countTools()
    if count > lastCount then
        onPickup("novo item")
    end
    lastCount = count
end))

task.spawn(setupBackpack)
if player.Character then
    watchCharacter(player.Character)
end

---------------------------------------------------------------------
-- Ao renascer: vida/velocidade novas já nascem aplicadas
---------------------------------------------------------------------
local function applyOnSpawn(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then
        return
    end

    if state.speed then
        hum.WalkSpeed = state.speed
    end

    if state.health then
        -- Durante ~2s força MaxHealth e Health, assim o jogo não
        -- consegue voltar para 100 logo depois do spawn
        local t0 = os.clock()
        repeat
            hum.MaxHealth = state.health
            hum.Health = state.health
            task.wait()
        until os.clock() - t0 > 2 or not hum.Parent
    end
end

track(player.CharacterAdded:Connect(function(char)
    ignoreUntil = os.clock() + 3 -- itens iniciais do spawn não contam
    watchCharacter(char)
    task.spawn(applyOnSpawn, char)
    task.spawn(setupBackpack)
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
    muted = Color3.fromRGB(150, 150, 165),
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

-- Arrastar (mouse e toque). Se soltar sem ter movido, chama onClick.
local function makeDraggable(handle, target, onClick)
    local dragging, moved, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onClick and not moved then
                        onClick()
                    end
                end
            end)
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then
                moved = true
            end
            if moved then
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end))
end

-- Painel principal (começa escondido; o ícone abre/fecha)
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 230, 0, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0, 68, 0.3, 0)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Visible = false
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

-- Ícone quadrado pequeno (arrastável; clique abre/fecha o painel)
local icon = Instance.new("TextButton")
icon.Name = "Icone"
icon.Size = UDim2.new(0, 44, 0, 44)
icon.Position = UDim2.new(0, 12, 0.3, 0)
icon.BackgroundColor3 = COLORS.accent
icon.Text = ""
icon.AutoButtonColor = false
icon.BorderSizePixel = 0
icon.Parent = screenGui
corner(icon, 10)

for i = 0, 2 do
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 22, 0, 3)
    bar.Position = UDim2.new(0, 11, 0, 12 + i * 9)
    bar.BackgroundColor3 = COLORS.text
    bar.BorderSizePixel = 0
    bar.Parent = icon
    corner(bar, 2)
end

makeDraggable(icon, icon, function()
    main.Visible = not main.Visible
end)

-- Barra de título (arrastar o painel por aqui)
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

-- X: fecha tudo de vez (painel + ícone) e desliga as funções.
-- Para abrir de novo, execute o script outra vez.
closeBtn.MouseButton1Click:Connect(function()
    state.noclip = false
    state.speed = nil
    state.health = nil
    state.flyOnPickup = false
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    screenGui:Destroy()
end)

makeDraggable(titleBar, main)

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

local function makeBox(placeholder, order)
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
    box.LayoutOrder = order
    box.Parent = main
    corner(box, 8)
    return box
end

-- Botão que mostra/oculta uma caixa de texto logo abaixo.
-- prepare (opcional): roda ANTES de mostrar a caixa, com etapa de
-- "carregando". Deve retornar o novo placeholder (ou nil se falhar).
local function makeInputSection(label, placeholder, order, onApply, prepare)
    local btn = makeButton(label, order)
    local box = makeBox(placeholder, order + 1) -- fica logo abaixo do botão
    local busy = false

    local function showBox(text)
        if text then
            box.PlaceholderText = text
        end
        box.Visible = true
        btn.Text = label
        btn.BackgroundColor3 = COLORS.accent
        box:CaptureFocus()
    end

    btn.MouseButton1Click:Connect(function()
        if busy then
            return
        end

        if box.Visible then
            box.Visible = false
            btn.BackgroundColor3 = COLORS.button
            return
        end

        if not prepare then
            showBox()
            return
        end

        busy = true
        task.spawn(function()
            local dots = 0
            local loading = true

            task.spawn(function()
                while loading do
                    dots = (dots % 3) + 1
                    btn.Text = "Procurando propriedade" .. string.rep(".", dots)
                    task.wait(0.3)
                end
            end)

            task.wait(1)
            local result = prepare()
            loading = false

            if result then
                showBox(result)
            else
                btn.Text = "Não encontrado :("
                btn.BackgroundColor3 = COLORS.error
                task.wait(1.5)
                btn.Text = label
                btn.BackgroundColor3 = COLORS.button
            end
            busy = false
        end)
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

-- Ordens: cada seção usa dois números (botão = n, caixa = n + 1)
makeInputSection("Aumentar velocidade", "Velocidade (padrão: 16)", 10, applySpeed)

makeInputSection("Aumentar vida", "Vida (padrão: 100)", 20, applyHealth, function()
    local current = findMaxHealth()
    if current then
        return "Vida máxima (atual: " .. tostring(math.floor(current)) .. ")"
    end
    return nil
end)

-- NoClip (ativa só de clicar)
local noclipBtn = makeButton("NoClip: OFF", 30)
noclipBtn.MouseButton1Click:Connect(function()
    setNoclip(not state.noclip)
    noclipBtn.Text = state.noclip and "NoClip: ON" or "NoClip: OFF"
    noclipBtn.BackgroundColor3 = state.noclip and COLORS.buttonOn or COLORS.button
end)

-- Voar ao pegar item (ativável) + altura + status de detecção
local flyBtn = makeButton("Voar ao pegar item: OFF", 40)
local flyBox = makeBox("Altura em studs (padrão: 100)", 41)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Aguardando item..."
statusLabel.TextColor3 = COLORS.muted
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Visible = false
statusLabel.LayoutOrder = 42
statusLabel.Parent = main

setStatus = function(text)
    statusLabel.Text = text
end

flyBtn.MouseButton1Click:Connect(function()
    state.flyOnPickup = not state.flyOnPickup
    flyBtn.Text = state.flyOnPickup and "Voar ao pegar item: ON" or "Voar ao pegar item: OFF"
    flyBtn.BackgroundColor3 = state.flyOnPickup and COLORS.buttonOn or COLORS.button
    flyBox.Visible = state.flyOnPickup
    statusLabel.Visible = state.flyOnPickup
    if state.flyOnPickup then
        statusLabel.Text = "Aguardando item..."
    end
end)

flyBox.FocusLost:Connect(function()
    local value = tonumber(flyBox.Text)
    if value and value > 0 then
        state.flyHeight = value
    elseif flyBox.Text ~= "" then
        flyBox.Text = ""
        flyBox.PlaceholderText = "Digite um número válido"
    end
end)
