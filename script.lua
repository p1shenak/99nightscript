--[[
    FONDI HUB FIX — 99 Nights in the Forest
    Полностью открытый код. Без обфускации.
    
    Возможности:
    - Плавное появление с масштабированием
    - Градиент внутри окна (не перекрывает игру)
    - Светящаяся рамка (пульсация)
    - Боковые вкладки с подсветкой активной
    - Hover-анимации кнопок
    - Анимированные тогглы
    - Поиск предметов с карточками
    - Счётчик найденных
    - Всплывающие уведомления
    - Bring через Model / BasePart
    - Settings: цвет ESP, радиус, сброс
    - Горячая клавиша RightShift — показать/скрыть
--]]

--// ========== СЕРВИСЫ ==========
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

--// ========== КОНФИГ ==========
local Config = {
    ESPEnabled      = false,
    ESPColor        = Color3.fromRGB(0, 255, 140),
    ESPTransparency = 0.35,
    ShowNames       = true,
    BringRange      = 250,
    TargetItems = {
        "Log", "Coal", "Scrap", "Fuel", "Chest", "Diamond", "Ammo",
        "Seed", "Sapling", "Bolt", "Gears", "Tire", "Revolver", "Rifle",
        "Corpse", "Pelt", "Foot", "Rope", "Cloth", "Bandage", "Meat", "Berry"
    }
}

local ESPObjects = {}
local UI = {}

--// ========== УТИЛИТЫ ==========
local function isTargetItem(object)
    if not object or not object.Parent or not object:IsA("BasePart") then return false end
    local lower = object.Name:lower()
    for _, name in ipairs(Config.TargetItems) do
        if string.find(lower, name:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function getHRP()
    if LocalPlayer.Character then
        return LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getDistance(object)
    local hrp = getHRP()
    if not hrp or not object then return math.huge end
    return math.floor((object.Position - hrp.Position).Magnitude)
end

local function getBringTarget(object)
    if not object then return nil end
    local parent = object.Parent
    if parent and parent:IsA("Model") and parent.PrimaryPart then
        return parent, true
    end
    if parent and parent:IsA("Model") then
        return parent, true
    end
    return object, false
end

--// ========== ESP ==========
local function createESP(object)
    if ESPObjects[object] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "FondiESP"
    highlight.Adornee = object
    highlight.FillColor = Config.ESPColor
    highlight.FillTransparency = Config.ESPTransparency
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = object

    local billboard, label
    if Config.ShowNames then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "FondiESPName"
        billboard.Adornee = object
        billboard.Size = UDim2.new(0, 110, 0, 22)
        billboard.StudsOffset = Vector3.new(0, 2.2, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = object

        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = object.Name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = billboard
    end

    ESPObjects[object] = {highlight, billboard, label}
end

local function removeESP(object)
    if not ESPObjects[object] then return end
    for _, gui in ipairs(ESPObjects[object]) do
        if gui and gui.Parent then gui:Destroy() end
    end
    ESPObjects[object] = nil
end

local function clearAllESP()
    for obj, _ in pairs(ESPObjects) do removeESP(obj) end
end

local function updateESP()
    if not Config.ESPEnabled then return end
    for _, object in ipairs(Workspace:GetDescendants()) do
        if isTargetItem(object) then createESP(object) end
    end
end

Workspace.DescendantAdded:Connect(function(object)
    task.wait(0.1)
    if Config.ESPEnabled and isTargetItem(object) then createESP(object) end
end)
Workspace.DescendantRemoving:Connect(removeESP)

task.spawn(function()
    while task.wait(2) do updateESP() end
end)

--// ========== BRING ==========
local function bringObject(object)
    local hrp = getHRP()
    if not hrp then return false end

    local target, isModel = getBringTarget(object)
    if not target then return false end

    local targetPos = hrp.Position + Vector3.new(0, 4, 0)

    if isModel then
        local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        if not primary then return false end
        if not target.PrimaryPart then
            target.PrimaryPart = primary
        end
        local offset = target:GetPivot().Position - primary.Position
        local goal = CFrame.new(targetPos + offset)
        local ok = pcall(function()
            target:PivotTo(goal)
        end)
        if not ok then
            for _, part in ipairs(target:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                    part.CFrame = goal
                end
            end
        end
        return true
    else
        if target.Anchored then target.Anchored = false end
        local tween = TweenService:Create(
            target,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {CFrame = CFrame.new(targetPos)}
        )
        tween:Play()
        return true
    end
end

local function bringAllItems()
    local count = 0
    for _, object in ipairs(Workspace:GetDescendants()) do
        if isTargetItem(object) and getDistance(object) <= Config.BringRange then
            if bringObject(object) then count = count + 1 end
        end
    end
    return count
end

local function bringSpecificItem(itemName)
    local count = 0
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("BasePart")
            and string.find(object.Name:lower(), itemName:lower(), 1, true)
            and getDistance(object) <= Config.BringRange then
            if bringObject(object) then count = count + 1 end
        end
    end
    return count
end

--// ========== ИНВЕНТАРЬ ==========
local function getInventoryList()
    local list, seen = {}, {}
    local containers = {}
    if LocalPlayer:FindFirstChild("Backpack") then table.insert(containers, LocalPlayer.Backpack) end
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end

    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") or item:IsA("Accessory") then
                if not seen[item.Name] then
                    seen[item.Name] = true
                    table.insert(list, {Name = item.Name, Class = item.ClassName})
                end
            end
        end
    end
    return list
end

--// ========== UI ==========
local function createUI()
    local old = LocalPlayer.PlayerGui:FindFirstChild("FondiHub")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FondiHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- ====== ГЛАВНОЕ ОКНО ======
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 620, 0, 400)
    mainFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 34)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    mainFrame.ZIndex = 5

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainFrame

    -- Градиент ТОЛЬКО внутри окна
    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 20, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 12, 28))
    })
    mainGradient.Rotation = 90
    mainGradient.Parent = mainFrame

    -- Светящаяся рамка
    local glow = Instance.new("UIStroke")
    glow.Color = Color3.fromRGB(180, 80, 255)
    glow.Thickness = 1.5
    glow.Transparency = 0.2
    glow.Parent = mainFrame

    task.spawn(function()
        while mainFrame.Parent do
            TweenService:Create(glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.65,
                Thickness = 2.2
            }):Play()
            task.wait(1.5)
            TweenService:Create(glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.15,
                Thickness = 1.2
            }):Play()
            task.wait(1.5)
        end
    end)

    -- Плавное появление
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 620, 0, 400)}
    ):Play()
    TweenService:Create(mainFrame,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0}
    ):Play()

    -- ====== ЗАГОЛОВОК ======
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = Color3.fromRGB(32, 22, 46)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar

    local titleCover = Instance.new("Frame")
    titleCover.Size = UDim2.new(1, 0, 0, 14)
    titleCover.Position = UDim2.new(0, 0, 1, -14)
    titleCover.BackgroundColor3 = Color3.fromRGB(32, 22, 46)
    titleCover.BorderSizePixel = 0
    titleCover.Parent = titleBar

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(0, 30, 0, 30)
    logo.Position = UDim2.new(0, 12, 0, 7)
    logo.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
    logo.Text = "F"
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.Font = Enum.Font.GothamBlack
    logo.TextSize = 18
    logo.Parent = titleBar

    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 8)
    logoCorner.Parent = logo

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -140, 1, 0)
    title.Position = UDim2.new(0, 52, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "FONDI HUB"
    title.TextColor3 = Color3.fromRGB(240, 230, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0, 200, 0, 12)
    subtitle.Position = UDim2.new(0, 52, 0, 24)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "99 Nights in the Forest"
    subtitle.TextColor3 = Color3.fromRGB(160, 130, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 70)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(230, 70, 90)
        }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(180, 50, 70)
        }):Play()
    end)

    -- ====== БОКОВОЕ МЕНЮ ======
    local sideBar = Instance.new("Frame")
    sideBar.Name = "SideBar"
    sideBar.Size = UDim2.new(0, 150, 1, -60)
    sideBar.Position = UDim2.new(0, 10, 0, 50)
    sideBar.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
    sideBar.BackgroundTransparency = 0.3
    sideBar.BorderSizePixel = 0
    sideBar.Parent = mainFrame

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 10)
    sideCorner.Parent = sideBar

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 6)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sideBar

    local sidePadding = Instance.new("UIPadding")
    sidePadding.PaddingTop = UDim.new(0, 10)
    sidePadding.PaddingLeft = UDim.new(0, 8)
    sidePadding.PaddingRight = UDim.new(0, 8)
    sidePadding.Parent = sideBar

    -- ====== КОНТЕНТ ======
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -180, 1, -70)
    contentFrame.Position = UDim2.new(0, 170, 0, 56)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    local tabs, pages = {}, {}

    local function switchTab(name)
        for tabName, tabBtn in pairs(tabs) do
            local isActive = (tabName == name)
            TweenService:Create(tabBtn,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                {BackgroundColor3 = isActive and Color3.fromRGB(120, 50, 200) or Color3.fromRGB(35, 25, 50)}
            ):Play()
            TweenService:Create(tabBtn,
                TweenInfo.new(0.2),
                {TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 160, 210)}
            ):Play()
        end

        for pageName, pageFrame in pairs(pages) do
            local isActive = (pageName == name)
            if isActive then
                pageFrame.Visible = true
                pageFrame.GroupTransparency = 1
                TweenService:Create(pageFrame,
                    TweenInfo.new(0.25, Enum.EasingStyle.Quad),
                    {GroupTransparency = 0}
                ):Play()
            else
                pageFrame.Visible = false
            end
        end
    end

    local function createTab(name, label, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
        btn.Text = "  " .. (icon or "") .. "  " .. label
        btn.TextColor3 = Color3.fromRGB(180, 160, 210)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = sideBar

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        btn.MouseEnter:Connect(function()
            if not pages[name] or not pages[name].Visible then
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(50, 35, 75)
                }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if not pages[name] or not pages[name].Visible then
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(35, 25, 50)
                }):Play()
            end
        end)
        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        tabs[name] = btn

        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 5
        page.ScrollBarImageColor3 = Color3.fromRGB(120, 50, 200)
        page.Visible = false
        page.Parent = contentFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 4)
        padding.PaddingBottom = UDim.new(0, 4)
        padding.PaddingRight = UDim.new(0, 4)
        padding.Parent = page

        pages[name] = page
        return page
    end

    -- ====== УВЕДОМЛЕНИЯ ======
    local notifContainer = Instance.new("Frame")
    notifContainer.Name = "Notifications"
    notifContainer.Size = UDim2.new(0, 260, 0, 200)
    notifContainer.Position = UDim2.new(1, -280, 0, 60)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui
    notifContainer.ZIndex = 100

    local notifLayout = Instance.new("UIListLayout")
    notifLayout.Padding = UDim.new(0, 6)
    notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifLayout.Parent = notifContainer

    local function notify(text, color)
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(1, 0, 0, 38)
        notif.BackgroundColor3 = color or Color3.fromRGB(40, 25, 60)
        notif.Text = text
        notif.TextColor3 = Color3.fromRGB(240, 230, 255)
        notif.Font = Enum.Font.GothamMedium
        notif.TextSize = 13
        notif.TextXAlignment = Enum.TextXAlignment.Left
        notif.Parent = notifContainer

        local nc = Instance.new("UICorner")
        nc.CornerRadius = UDim.new(0, 8)
        nc.Parent = notif

        local np = Instance.new("UIPadding")
        np.PaddingLeft = UDim.new(0, 12)
        np.Parent = notif

        local ns = Instance.new("UIStroke")
        ns.Color = Color3.fromRGB(180, 80, 255)
        ns.Thickness = 1
        ns.Transparency = 0.4
        ns.Parent = notif

        notif.Position = UDim2.new(1, 0, 0, 0)
        notif.BackgroundTransparency = 1
        TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0
        }):Play()

        task.delay(3, function()
            if notif.Parent then
                TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1
                }):Play()
                task.wait(0.35)
                notif:Destroy()
            end
        end)
    end

    UI.notify = notify

    -- ====== ЭЛЕМЕНТЫ UI ======
    local function makeButton(parent, text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = color or Color3.fromRGB(45, 30, 65)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(240, 230, 255)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(120, 50, 200)
        stroke.Thickness = 1
        stroke.Transparency = 0.7
        stroke.Parent = btn

        local baseColor = color or Color3.fromRGB(45, 30, 65)

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(baseColor.R * 255 + 40, 255),
                    math.min(baseColor.G * 255 + 40, 255),
                    math.min(baseColor.B * 255 + 40, 255)
                )
            }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.2}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btn
    end

    local function makeToggle(parent, text, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 36)
        container.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
        container.Parent = parent

        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = container

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 210, 240)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local switchBg = Instance.new("Frame")
        switchBg.Size = UDim2.new(0, 42, 0, 22)
        switchBg.Position = UDim2.new(1, -54, 0.5, -11)
        switchBg.BackgroundColor3 = default and Color3.fromRGB(120, 50, 200) or Color3.fromRGB(55, 45, 70)
        switchBg.Parent = container

        local sbCorner = Instance.new("UICorner")
        sbCorner.CornerRadius = UDim.new(1, 0)
        sbCorner.Parent = switchBg

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Parent = switchBg

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.Parent = container

        local state = default

        local function update()
            TweenService:Create(switchBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                BackgroundColor3 = state and Color3.fromRGB(120, 50, 200) or Color3.fromRGB(55, 45, 70)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            }):Play()
        end

        clickBtn.MouseButton1Click:Connect(function()
            state = not state
            update()
            if callback then callback(state) end
        end)

        return {container = container, get = function() return state end, set = function(v) state = v; update() end}
    end

    -- ====== ВКЛАДКА ESP ======
    local espPage = createTab("esp", "ESP", "👁")
    makeToggle(espPage, "ESP предметов", false, function(state)
        Config.ESPEnabled = state
        if not state then clearAllESP() else updateESP() end
        notify(state and "ESP включён" or "ESP выключен")
    end)
    makeToggle(espPage, "Показывать имена", true, function(state)
        Config.ShowNames = state
        clearAllESP()
        if Config.ESPEnabled then updateESP() end
    end)
    makeButton(espPage, "Обновить ESP сейчас", Color3.fromRGB(80, 40, 140), function()
        updateESP()
        notify("ESP обновлён")
    end)
    makeButton(espPage, "Очистить ESP", Color3.fromRGB(140, 40, 60), function()
        clearAllESP()
        notify("ESP очищен")
    end)

    -- ====== ВКЛАДКА BRING ======
    local bringPage = createTab("bring", "Bring", "🧲")
    makeButton(bringPage, "ПРИТЯНУТЬ ВСЁ", Color3.fromRGB(80, 40, 140), function()
        local n = bringAllItems()
        notify("Bring: найдено " .. n, Color3.fromRGB(60, 35, 90))
    end)

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, 0, 0, 34)
    inputBox.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
    inputBox.PlaceholderText = "Имя предмета (Log, Coal, Chest...)"
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.fromRGB(240, 230, 255)
    inputBox.PlaceholderTextColor3 = Color3.fromRGB(140, 120, 170)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = bringPage

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(120, 50, 200)
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.6
    inputStroke.Parent = inputBox

    makeButton(bringPage, "Притянуть введённое", Color3.fromRGB(80, 40, 140), function()
        local text = inputBox.Text
        if text and text ~= "" then
            local n = bringSpecificItem(text)
            notify("Bring [" .. text .. "]: " .. n, Color3.fromRGB(60, 35, 90))
        end
    end)

    local quickTypes = {"Log", "Coal", "Scrap", "Fuel", "Chest", "Diamond", "Ammo"}
    for _, t in ipairs(quickTypes) do
        makeButton(bringPage, "Притянуть: " .. t, Color3.fromRGB(45, 30, 65), function()
            local n = bringSpecificItem(t)
            notify("Bring [" .. t .. "]: " .. n, Color3.fromRGB(60, 35, 90))
        end)
    end

    -- ====== ВКЛАДКА ПОИСК ======
    local searchPage = createTab("search", "Поиск", "🔍")

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, 0, 0, 34)
    searchBox.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
    searchBox.PlaceholderText = "Что искать в workspace..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(240, 230, 255)
    searchBox.PlaceholderTextColor3 = Color3.fromRGB(140, 120, 170)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchPage

    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 8)
    sc.Parent = searchBox

    local searchResults = Instance.new("TextLabel")
    searchResults.Size = UDim2.new(1, 0, 0, 20)
    searchResults.BackgroundTransparency = 1
    searchResults.Text = "Найдено: 0"
    searchResults.TextColor3 = Color3.fromRGB(180, 160, 210)
    searchResults.Font = Enum.Font.Gotham
    searchResults.TextSize = 12
    searchResults.TextXAlignment = Enum.TextXAlignment.Left
    searchResults.Parent = searchPage

    local resultsFrame = Instance.new("ScrollingFrame")
    resultsFrame.Size = UDim2.new(1, 0, 0, 220)
    resultsFrame.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
    resultsFrame.BorderSizePixel = 0
    resultsFrame.ScrollBarThickness = 4
    resultsFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 50, 200)
    resultsFrame.Parent = searchPage

    local rfCorner = Instance.new("UICorner")
    rfCorner.CornerRadius = UDim.new(0, 8)
    rfCorner.Parent = resultsFrame

    local rfLayout = Instance.new("UIListLayout")
    rfLayout.Padding = UDim.new(0, 6)
    rfLayout.Parent = resultsFrame

    local rfPad = Instance.new("UIPadding")
    rfPad.PaddingTop = UDim.new(0, 6)
    rfPad.PaddingLeft = UDim.new(0, 6)
    rfPad.PaddingRight = UDim.new(0, 6)
    rfPad.Parent = resultsFrame

    local function makeItemCard(parent, obj)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -12, 0, 46)
        card.BackgroundColor3 = Color3.fromRGB(38, 26, 56)
        card.Parent = parent

        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = card

        local cs = Instance.new("UIStroke")
        cs.Color = Color3.fromRGB(120, 50, 200)
        cs.Thickness = 1
        cs.Transparency = 0.6
        cs.Parent = card

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -110, 0, 20)
        nameLbl.Position = UDim2.new(0, 10, 0, 5)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = obj.Name
        nameLbl.TextColor3 = Color3.fromRGB(240, 230, 255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card

        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size = UDim2.new(1, -110, 0, 16)
        infoLbl.Position = UDim2.new(0, 10, 0, 24)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = obj.ClassName .. "  •  " .. getDistance(obj) .. " studs"
        infoLbl.TextColor3 = Color3.fromRGB(160, 130, 200)
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.TextSize = 11
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.Parent = card

        local bringBtn = Instance.new("TextButton")
        bringBtn.Size = UDim2.new(0, 80, 0, 30)
        bringBtn.Position = UDim2.new(1, -90, 0.5, -15)
        bringBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 140)
        bringBtn.Text = "Bring"
        bringBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        bringBtn.Font = Enum.Font.GothamMedium
        bringBtn.TextSize = 12
        bringBtn.Parent = card

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = bringBtn

        bringBtn.MouseEnter:Connect(function()
            TweenService:Create(bringBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(120, 60, 200)
            }):Play()
        end)
        bringBtn.MouseLeave:Connect(function()
            TweenService:Create(bringBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(80, 40, 140)
            }):Play()
        end)
        bringBtn.MouseButton1Click:Connect(function()
            if bringObject(obj) then
                notify("Bring: " .. obj.Name .. " ✓", Color3.fromRGB(50, 90, 60))
            end
        end)

        return card
    end

    makeButton(searchPage, "Найти и показать карточки", Color3.fromRGB(80, 40, 140), function()
        local query = searchBox.Text
        if not query or query == "" then return end

        for _, c in ipairs(resultsFrame:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        for _, o in ipairs(Workspace:GetDescendants()) do
            if o.Name == "FondiSearchHL" then o:Destroy() end
        end

        local found = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and string.find(obj.Name:lower(), query:lower(), 1, true) then
                local hl = Instance.new("Highlight")
                hl.Name = "FondiSearchHL"
                hl.Adornee = obj
                hl.FillColor = Color3.fromRGB(255, 200, 0)
                hl.FillTransparency = 0.4
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = obj

                makeItemCard(resultsFrame, obj)
                found = found + 1

                if found >= 50 then break end
            end
        end

        searchResults.Text = "Найдено: " .. found
        notify("Поиск: " .. found .. " объектов", Color3.fromRGB(60, 35, 90))
    end)

    makeButton(searchPage, "Убрать подсветку", Color3.fromRGB(140, 40, 60), function()
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o.Name == "FondiSearchHL" then o:Destroy() end
        end
        for _, c in ipairs(resultsFrame:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        searchResults.Text = "Найдено: 0"
    end)

    -- ====== ВКЛАДКА ИНВЕНТАРЬ ======
    local invPage = createTab("inv", "Инвентарь", "🎒")

    local invList = Instance.new("Frame")
    invList.Size = UDim2.new(1, 0, 0, 240)
    invList.BackgroundColor3 = Color3.fromRGB(25, 18, 38)
    invList.BorderSizePixel = 0
    invList.Parent = invPage

    local invCorner = Instance.new("UICorner")
    invCorner.CornerRadius = UDim.new(0, 8)
    invCorner.Parent = invList

    local invScroll = Instance.new("ScrollingFrame")
    invScroll.Size = UDim2.new(1, -10, 1, -10)
    invScroll.Position = UDim2.new(0, 5, 0, 5)
    invScroll.BackgroundTransparency = 1
    invScroll.BorderSizePixel = 0
    invScroll.ScrollBarThickness = 4
    invScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 50, 200)
    invScroll.Parent = invList

    local invLayout = Instance.new("UIListLayout")
    invLayout.Padding = UDim.new(0, 4)
    invLayout.Parent = invScroll

    local function refreshInventory()
        for _, child in ipairs(invScroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        local items = getInventoryList()
        if #items == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 24)
            empty.BackgroundTransparency = 1
            empty.Text = "Пусто"
            empty.TextColor3 = Color3.fromRGB(150, 130, 180)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 13
            empty.Parent = invScroll
        else
            for _, item in ipairs(items) do
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -10, 0, 22)
                label.BackgroundTransparency = 1
                label.Text = "• " .. item.Name .. "  (" .. item.Class .. ")"
                label.TextColor3 = Color3.fromRGB(220, 210, 240)
                label.Font = Enum.Font.Gotham
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = invScroll
            end
        end
    end

    makeButton(invPage, "Обновить список", Color3.fromRGB(80, 40, 140), refreshInventory)
    refreshInventory()

    -- ====== ВКЛАДКА SETTINGS ======
    local settingsPage = createTab("settings", "Settings", "⚙")

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(1, 0, 0, 20)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "Цвет ESP"
    colorLabel.TextColor3 = Color3.fromRGB(200, 180, 230)
    colorLabel.Font = Enum.Font.GothamMedium
    colorLabel.TextSize = 12
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = settingsPage

    local colorPresets = {
        {name = "Зелёный",  color = Color3.fromRGB(0, 255, 140)},
        {name = "Голубой",  color = Color3.fromRGB(0, 200, 255)},
        {name = "Розовый",  color = Color3.fromRGB(255, 80, 200)},
        {name = "Золотой",  color = Color3.fromRGB(255, 200, 0)},
        {name = "Красный",  color = Color3.fromRGB(255, 60, 60)}
    }
    for _, preset in ipairs(colorPresets) do
        makeButton(settingsPage, "  ●  " .. preset.name, preset.color, function()
            Config.ESPColor = preset.color
            for obj, data in pairs(ESPObjects) do
                if data[1] then data[1].FillColor = preset.color end
            end
            notify("Цвет ESP: " .. preset.name)
        end)
    end

    local rangeLabel = Instance.new("TextLabel")
    rangeLabel.Size = UDim2.new(1, 0, 0, 20)
    rangeLabel.BackgroundTransparency = 1
    rangeLabel.Text = "Радиус Bring: " .. Config.BringRange
    rangeLabel.TextColor3 = Color3.fromRGB(200, 180, 230)
    rangeLabel.Font = Enum.Font.GothamMedium
    rangeLabel.TextSize = 12
    rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    rangeLabel.Parent = settingsPage

    local rangeRow = Instance.new("Frame")
    rangeRow.Size = UDim2.new(1, 0, 0, 30)
    rangeRow.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
    rangeRow.Parent = settingsPage

    local rrCorner = Instance.new("UICorner")
    rrCorner.CornerRadius = UDim.new(0, 8)
    rrCorner.Parent = rangeRow

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 30, 1, 0)
    minusBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
    minusBtn.Text = "−"
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.TextSize = 16
    minusBtn.Parent = rangeRow

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 30, 1, 0)
    plusBtn.Position = UDim2.new(1, -30, 0, 0)
    plusBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.TextSize = 16
    plusBtn.Parent = rangeRow

    minusBtn.MouseButton1Click:Connect(function()
        Config.BringRange = math.max(50, Config.BringRange - 50)
        rangeLabel.Text = "Радиус Bring: " .. Config.BringRange
    end)
    plusBtn.MouseButton1Click:Connect(function()
        Config.BringRange = math.min(1000, Config.BringRange + 50)
        rangeLabel.Text = "Радиус Bring: " .. Config.BringRange
    end)

    makeButton(settingsPage, "Сбросить настройки", Color3.fromRGB(140, 40, 60), function()
        Config.ESPColor = Color3.fromRGB(0, 255, 140)
        Config.BringRange = 250
        Config.ESPTransparency = 0.35
        rangeLabel.Text = "Радиус Bring: " .. Config.BringRange
        notify("Настройки сброшены")
    end)

    -- ====== ГОРЯЧАЯ КЛАВИША ======
    local isOpen = true
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            isOpen = not isOpen
            if isOpen then
                mainFrame.Visible = true
                mainFrame.Size = UDim2.new(0, 0, 0, 0)
                TweenService:Create(mainFrame,
                    TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0, 620, 0, 400)}
                ):Play()
            else
                TweenService:Create(mainFrame,
                    TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {Size = UDim2.new(0, 0, 0, 0)}
                ):Play()
                task.wait(0.28)
                mainFrame.Visible = false
            end
        end
    end)

    -- ====== ЗАКРЫТИЕ ======
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainFrame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}
        ):Play()
        task.wait(0.3)
        screenGui:Destroy()
    end)

    switchTab("esp")

    task.delay(0.6, function()
        notify("FONDI HUB загружен", Color3.fromRGB(80, 40, 140))
    end)
end

--// ========== ЗАПУСК ==========
createUI()
print("[FONDI HUB] Загружен. RightShift — скрыть/показать.")
