--[[
    99 Nights in the Forest — Custom Hub
    Собрано вручную. Без обфускации, весь код виден.
    Использовать только на изолированном аккаунте / VM.
    
    Возможности:
    - ESP предметов (Highlight + подпись)
    - Bring All / Bring Selected / Bring One
    - Поиск предметов по имени
    - Список инвентаря
    - Вкладки с анимациями, перетаскиваемое окно
--]]

--// ========== СЕРВИСЫ ==========
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

--// ========== КОНФИГ ==========
local Config = {
    ESPEnabled      = false,
    ESPColor        = Color3.fromRGB(0, 255, 100),
    ESPTransparency = 0.4,
    ShowNames       = true,
    BringRange      = 200,
    TargetItems = {
        "Log", "Coal", "Scrap", "Fuel", "Chest", "Diamond", "Ammo",
        "Seed", "Sapling", "Bolt", "Gears", "Tire", "Revolver", "Rifle",
        "Corpse", "Pelt", "Foot", "Rope", "Cloth", "Bandage"
    }
}

local ESPObjects = {}

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
    return (object.Position - hrp.Position).Magnitude
end

--// ========== ESP ==========
local function createESP(object)
    if ESPObjects[object] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "MyCustomESP"
    highlight.Adornee = object
    highlight.FillColor = Config.ESPColor
    highlight.FillTransparency = Config.ESPTransparency
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = object

    local billboard, label
    if Config.ShowNames then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "MyESPName"
        billboard.Adornee = object
        billboard.Size = UDim2.new(0, 100, 0, 20)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = object

        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = object.Name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
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
local function bringItem(item)
    local hrp = getHRP()
    if not hrp or not item or not item.Parent then return end
    local target = hrp.Position + Vector3.new(0, 3, 0)
    if item.Anchored then item.Anchored = false end
    local tween = TweenService:Create(
        item,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = target}
    )
    tween:Play()
end

local function bringAllItems()
    local count = 0
    for _, object in ipairs(Workspace:GetDescendants()) do
        if isTargetItem(object) and getDistance(object) <= Config.BringRange then
            bringItem(object)
            count = count + 1
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
            bringItem(object)
            count = count + 1
        end
    end
    return count
end

--// ========== INVENTORY SCAN ==========
local function getInventoryList()
    local list = {}
    local seen = {}
    local containers = {}
    if LocalPlayer:FindFirstChild("Backpack") then table.insert(containers, LocalPlayer.Backpack) end
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end

    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") or item:IsA("Accessory") then
                local key = item.Name
                if not seen[key] then
                    seen[key] = true
                    table.insert(list, {Name = item.Name, Class = item.ClassName})
                end
            end
        end
    end
    return list
end

--// ========== UI ==========
local function createUI()
    local old = LocalPlayer.PlayerGui:FindFirstChild("MyCustomHub")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MyCustomHub"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    --// Главное окно
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 520, 0, 360)
    mainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 75)
    stroke.Thickness = 1
    stroke.Parent = mainFrame

    --// Анимация открытия
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 520, 0, 360)}
    ):Play()

    --// Заголовок
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar

    local titleCover = Instance.new("Frame")
    titleCover.Size = UDim2.new(1, 0, 0, 12)
    titleCover.Position = UDim2.new(0, 0, 1, -12)
    titleCover.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    titleCover.BorderSizePixel = 0
    titleCover.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "99 NIGHTS — CUSTOM HUB"
    title.TextColor3 = Color3.fromRGB(230, 230, 240)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainFrame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 0, 0, 0)}
        ):Play()
        task.wait(0.3)
        screenGui:Destroy()
    end)

    --// Контейнер вкладок
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 36)
    tabBar.Position = UDim2.new(0, 0, 0, 40)
    tabBar.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabBar

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 8)
    tabPadding.PaddingTop = UDim.new(0, 4)
    tabPadding.Parent = tabBar

    --// Контейнер контента
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -20, 1, -96)
    contentFrame.Position = UDim2.new(0, 10, 0, 86)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    local tabs = {}
    local pages = {}

    local function switchTab(name)
        for tabName, tabBtn in pairs(tabs) do
            local isActive = (tabName == name)
            TweenService:Create(tabBtn,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                {BackgroundColor3 = isActive and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(40, 40, 50)}
            ):Play()
        end

        for pageName, pageFrame in pairs(pages) do
            local isActive = (pageName == name)
            pageFrame.Visible = isActive
            if isActive then
                pageFrame.GroupTransparency = 1
                TweenService:Create(pageFrame,
                    TweenInfo.new(0.25, Enum.EasingStyle.Quad),
                    {GroupTransparency = 0}
                ):Play()
            end
        end
    end

    local function createTab(name, label)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 110, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        btn.Text = label
        btn.TextColor3 = Color3.fromRGB(230, 230, 240)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = tabBar

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        tabs[name] = btn

        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 5
        page.Visible = false
        page.Parent = contentFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 4)
        padding.PaddingBottom = UDim.new(0, 4)
        padding.Parent = page

        pages[name] = page
        return page
    end

    --// Хелперы для элементов
    local function makeButton(parent, text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = color or Color3.fromRGB(50, 50, 65)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(240, 240, 245)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = color and Color3.fromRGB(
                    math.min(color.R * 255 + 30, 255),
                    math.min(color.G * 255 + 30, 255),
                    math.min(color.B * 255 + 30, 255)
                ) or Color3.fromRGB(70, 70, 90)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = color or Color3.fromRGB(50, 50, 65)
            }):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btn
    end

    local function makeToggle(parent, text, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = default and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(50, 50, 65)
        btn.Text = text .. (default and "  [ВКЛ]" or "  [ВЫКЛ]")
        btn.TextColor3 = Color3.fromRGB(240, 240, 245)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = text .. (state and "  [ВКЛ]" or "  [ВЫКЛ]")
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = state and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(50, 50, 65)
            }):Play()
            if callback then callback(state) end
        end)
        return btn
    end

    --// ============ ВКЛАДКА ESP ============
    local espPage = createTab("esp", "ESP")
    makeToggle(espPage, "ESP предметов", false, function(state)
        Config.ESPEnabled = state
        if not state then clearAllESP() end
    end)
    makeToggle(espPage, "Показывать имена", true, function(state)
        Config.ShowNames = state
        clearAllESP()
    end)
    makeButton(espPage, "Обновить ESP сейчас", Color3.fromRGB(0, 120, 200), function()
        updateESP()
    end)
    makeButton(espPage, "Очистить ESP", Color3.fromRGB(160, 60, 60), function()
        clearAllESP()
    end)

    --// ============ ВКЛАДКА BRING ============
    local bringPage = createTab("bring", "Bring")
    makeButton(bringPage, "ПРИТЯНУТЬ ВСЁ", Color3.fromRGB(0, 140, 90), function()
        local n = bringAllItems()
        print("[Bring] Притянуто:", n)
    end)

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, 0, 0, 32)
    inputBox.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    inputBox.PlaceholderText = "Имя предмета (Log, Coal, Chest...)"
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.fromRGB(240, 240, 245)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = bringPage

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox

    makeButton(bringPage, "Притянуть введённое", Color3.fromRGB(0, 120, 200), function()
        local text = inputBox.Text
        if text and text ~= "" then
            local n = bringSpecificItem(text)
            print("[Bring]", text, "->", n)
        end
    end)

    --// Кнопки по типам
    local quickTypes = {"Log", "Coal", "Scrap", "Fuel", "Chest", "Diamond", "Ammo"}
    for _, t in ipairs(quickTypes) do
        makeButton(bringPage, "Притянуть: " .. t, Color3.fromRGB(60, 60, 80), function()
            local n = bringSpecificItem(t)
            print("[Bring]", t, "->", n)
        end)
    end

    --// Ползунок радиуса
    local rangeLabel = Instance.new("TextLabel")
    rangeLabel.Size = UDim2.new(1, 0, 0, 20)
    rangeLabel.BackgroundTransparency = 1
    rangeLabel.Text = "Радиус Bring: " .. Config.BringRange
    rangeLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    rangeLabel.Font = Enum.Font.Gotham
    rangeLabel.TextSize = 12
    rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    rangeLabel.Parent = bringPage

    local rangeBar = Instance.new("Frame")
    rangeBar.Size = UDim2.new(1, 0, 0, 8)
    rangeBar.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    rangeBar.Parent = bringPage

    local rangeCorner = Instance.new("UICorner")
    rangeCorner.CornerRadius = UDim.new(1, 0)
    rangeCorner.Parent = rangeBar

    local rangeFill = Instance.new("Frame")
    rangeFill.Size = UDim2.new(Config.BringRange / 500, 0, 1, 0)
    rangeFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    rangeFill.BorderSizePixel = 0
    rangeFill.Parent = rangeBar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = rangeFill

    --// ============ ВКЛАДКА ИНВЕНТАРЬ ============
    local invPage = createTab("inv", "Инвентарь")

    local invList = Instance.new("Frame")
    invList.Size = UDim2.new(1, 0, 0, 200)
    invList.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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
            empty.TextColor3 = Color3.fromRGB(150, 150, 160)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 13
            empty.Parent = invScroll
        else
            for _, item in ipairs(items) do
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -10, 0, 22)
                label.BackgroundTransparency = 1
                label.Text = "• " .. item.Name .. "  (" .. item.Class .. ")"
                label.TextColor3 = Color3.fromRGB(220, 220, 230)
                label.Font = Enum.Font.Gotham
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = invScroll
            end
        end
    end

    makeButton(invPage, "Обновить список", Color3.fromRGB(0, 120, 200), refreshInventory)
    refreshInventory()

    --// ============ ВКЛАДКА ПОИСК ============
    local searchPage = createTab("search", "Поиск")

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, 0, 0, 32)
    searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    searchBox.PlaceholderText = "Что искать в workspace..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchPage

    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 8)
    searchCorner.Parent = searchBox

    local searchResults = Instance.new("TextLabel")
    searchResults.Size = UDim2.new(1, 0, 0, 24)
    searchResults.BackgroundTransparency = 1
    searchResults.Text = ""
    searchResults.TextColor3 = Color3.fromRGB(200, 200, 210)
    searchResults.Font = Enum.Font.Gotham
    searchResults.TextSize = 13
    searchResults.TextXAlignment = Enum.TextXAlignment.Left
    searchResults.Parent = searchPage

    makeButton(searchPage, "Найти и подсветить", Color3.fromRGB(0, 140, 90), function()
        local query = searchBox.Text
        if not query or query == "" then return end

        --// Удаляем старую подсветку поиска
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "SearchHighlight" then obj:Destroy() end
        end

        local found = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and string.find(obj.Name:lower(), query:lower(), 1, true) then
                local hl = Instance.new("Highlight")
                hl.Name = "SearchHighlight"
                hl.Adornee = obj
                hl.FillColor = Color3.fromRGB(255, 200, 0)
                hl.FillTransparency = 0.3
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = obj
                found = found + 1
            end
        end
        searchResults.Text = "Найдено: " .. found
    end)

    makeButton(searchPage, "Убрать подсветку", Color3.fromRGB(160, 60, 60), function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "SearchHighlight" then obj:Destroy() end
        end
        searchResults.Text = ""
    end)

    --// Стартовая вкладка
    switchTab("esp")
end

--// ========== ЗАПУСК ==========
createUI()
print("[CustomHub] Загружен. Весь код открыт, ничего лишнего.")
