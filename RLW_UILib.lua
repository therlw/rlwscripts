local RLW_Library = {}

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {
    MainBG = Color3.fromRGB(20, 20, 26),
    SidebarBG = Color3.fromRGB(15, 15, 20),
    Accent = Color3.fromRGB(114, 51, 255),
    ElementBG = Color3.fromRGB(30, 30, 38),
    ElementHover = Color3.fromRGB(40, 40, 50),
    Text = Color3.fromRGB(255, 255, 255),
    TextDark = Color3.fromRGB(160, 160, 175),
    Border = Color3.fromRGB(40, 40, 50)
}

local function tween(object, properties, time)
    local info = TweenInfo.new(time or 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tw = TweenService:Create(object, info, properties)
    tw:Play()
    return tw
end

local function makeDraggable(topbarObject, object)
    local dragging, dragInput, dragStart, startPos
    topbarObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    topbarObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local endPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            tween(object, {Position = endPos}, 0.1) -- 0.1 saniyelik çok hafif bir gecikme (smooth inertia)
        end
    end)
end

function RLW_Library:CreateWindow(options)
    options = options or {}
    local TitleText = options.Title or "RLW"
    local SubtitleText = options.Subtitle or "</> SCRIPTS"

    local RLWGui = Instance.new("ScreenGui")
    RLWGui.Name = "RLW_UI"
    RLWGui.ResetOnSpawn = false
    RLWGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    if not pcall(function() RLWGui.Parent = CoreGui end) then
        RLWGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = RLWGui
    MainFrame.BackgroundColor3 = Theme.MainBG
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Size = UDim2.new(0, 600, 0, 400)
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
    
    local DropShadow = Instance.new("ImageLabel", MainFrame)
    DropShadow.Name = "Shadow"
    DropShadow.BackgroundTransparency = 1
    DropShadow.Position = UDim2.new(0, -15, 0, -15)
    DropShadow.Size = UDim2.new(1, 30, 1, 30)
    DropShadow.ZIndex = -5
    DropShadow.Image = "rbxassetid://6015897733"
    DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    DropShadow.ImageTransparency = 0.5
    DropShadow.ScaleType = Enum.ScaleType.Slice
    DropShadow.SliceCenter = Rect.new(31, 31, 225, 225)
    
    local MainScale = Instance.new("UIScale", MainFrame)
    MainScale.Scale = 1
    
    local isMobile = game:GetService("UserInputService").TouchEnabled
    local Camera = workspace.CurrentCamera
    local currentScale = 1
    local function updateScale()
        local viewportSize = Camera.ViewportSize
        local scaleX = viewportSize.X / 700
        local scaleY = viewportSize.Y / 500
        local finalScale = math.min(scaleX, scaleY, 1)
        finalScale = math.max(finalScale, 0.45)
        currentScale = finalScale
        MainScale.Scale = finalScale
    end
    updateScale()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    
    local UIStroke = Instance.new("UIStroke", MainFrame)
    UIStroke.Color = Theme.Border
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Parent = MainFrame
    Sidebar.BackgroundColor3 = Theme.SidebarBG
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

    local SidebarFix = Instance.new("Frame", Sidebar)
    SidebarFix.BackgroundColor3 = Theme.SidebarBG
    SidebarFix.BorderSizePixel = 0
    SidebarFix.Position = UDim2.new(1, -5, 0, 0)
    SidebarFix.Size = UDim2.new(0, 5, 1, 0)

    local LogoArea = Instance.new("Frame", Sidebar)
    LogoArea.BackgroundTransparency = 1
    LogoArea.Size = UDim2.new(1, 0, 0, 60)

    local LogoTitle = Instance.new("TextLabel", LogoArea)
    LogoTitle.BackgroundTransparency = 1
    LogoTitle.Position = UDim2.new(0, 15, 0, 15)
    LogoTitle.Size = UDim2.new(1, -30, 0, 20)
    LogoTitle.Font = Enum.Font.Ubuntu
    LogoTitle.Text = TitleText
    LogoTitle.TextColor3 = Theme.Accent
    LogoTitle.TextSize = 22
    LogoTitle.TextXAlignment = Enum.TextXAlignment.Left

    local LogoSub = Instance.new("TextLabel", LogoArea)
    LogoSub.BackgroundTransparency = 1
    LogoSub.Position = UDim2.new(0, 15, 0, 35)
    LogoSub.Size = UDim2.new(1, -30, 0, 15)
    LogoSub.Font = Enum.Font.Ubuntu
    LogoSub.Text = SubtitleText
    LogoSub.TextColor3 = Theme.Text
    LogoSub.TextSize = 14
    LogoSub.TextXAlignment = Enum.TextXAlignment.Left

    local Line = Instance.new("Frame", Sidebar)
    Line.BackgroundColor3 = Theme.Border
    Line.BorderSizePixel = 0
    Line.Position = UDim2.new(0, 0, 0, 65)
    Line.Size = UDim2.new(1, 0, 0, 1)

    local TabContainer = Instance.new("ScrollingFrame", Sidebar)
    TabContainer.Active = true
    TabContainer.BackgroundTransparency = 1
    TabContainer.Position = UDim2.new(0, 0, 0, 75)
    TabContainer.Size = UDim2.new(1, 0, 1, -85)
    TabContainer.ScrollBarThickness = 2
    TabContainer.ScrollBarImageColor3 = Theme.Accent
    TabContainer.BorderSizePixel = 0
    
    local TabListLayout = Instance.new("UIListLayout", TabContainer)
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Padding = UDim.new(0, 5)
    TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local ContentContainer = Instance.new("Frame", MainFrame)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Position = UDim2.new(0, 170, 0, 45) -- İçerikleri aşağı kaydırdık
    ContentContainer.Size = UDim2.new(1, -180, 1, -60) -- Taştığı için boyunu kısalttık

    local DragArea = Instance.new("Frame", MainFrame)
    DragArea.BackgroundTransparency = 1
    DragArea.Size = UDim2.new(1, -40, 0, 40) -- Çarpı butonuna taşmaması için küçültüldü
    makeDraggable(DragArea, MainFrame)

    -- Kapatma (X) Butonu
    local CloseBtn = Instance.new("TextButton", MainFrame)
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Theme.TextDark
    CloseBtn.TextSize = 18
    CloseBtn.Font = Enum.Font.Ubuntu

    -- Açma (Show UI) Butonu (Mobil Uyumlu)
    local openBtnY = isMobile and 55 or 15 -- Mobile: below Roblox top bar
    local openBtnHideY = -50
    
    local OpenBtn = Instance.new("TextButton", RLWGui)
    OpenBtn.Size = UDim2.new(0, 120, 0, 35)
    OpenBtn.Position = UDim2.new(0.5, -60, 0, openBtnHideY)
    OpenBtn.BackgroundColor3 = Theme.MainBG
    OpenBtn.Text = "Show UI"
    OpenBtn.TextColor3 = Theme.Accent
    OpenBtn.Font = Enum.Font.Ubuntu
    OpenBtn.TextSize = 14
    OpenBtn.Visible = false
    Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 8)
    local OpenStroke = Instance.new("UIStroke", OpenBtn)
    OpenStroke.Color = Theme.Border
    OpenStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- Open/Close Animation Logic
    local uiVisible = true
    local isAnimating = false -- Prevents double-click race conditions

    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, {TextColor3 = Color3.fromRGB(255, 75, 75)}, 0.2) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, {TextColor3 = Theme.TextDark}, 0.2) end)

    CloseBtn.MouseButton1Click:Connect(function()
        if not uiVisible or isAnimating then return end
        isAnimating = true
        uiVisible = false
        tween(MainScale, {Scale = 0}, 0.3)
        task.wait(0.3)
        MainFrame.Visible = false
        OpenBtn.Visible = true
        OpenBtn.Position = UDim2.new(0.5, -60, 0, openBtnHideY)
        tween(OpenBtn, {Position = UDim2.new(0.5, -60, 0, openBtnY)}, 0.35)
        task.wait(0.35)
        isAnimating = false
    end)

    OpenBtn.MouseEnter:Connect(function() tween(OpenBtn, {Size = UDim2.new(0, 126, 0, 38), Position = UDim2.new(0.5, -63, 0, openBtnY - 2)}, 0.2) end)
    OpenBtn.MouseLeave:Connect(function() tween(OpenBtn, {Size = UDim2.new(0, 120, 0, 35), Position = UDim2.new(0.5, -60, 0, openBtnY)}, 0.2) end)

    OpenBtn.MouseButton1Click:Connect(function()
        if uiVisible or isAnimating then return end
        isAnimating = true
        uiVisible = true
        tween(OpenBtn, {Position = UDim2.new(0.5, -60, 0, openBtnHideY)}, 0.25)
        task.wait(0.25)
        OpenBtn.Visible = false
        MainFrame.Visible = true
        MainScale.Scale = 0 -- Start from zero so the open animation is always smooth
        tween(MainScale, {Scale = currentScale}, 0.35)
        task.wait(0.35)
        isAnimating = false
    end)

    local NotifyContainer = Instance.new("Frame", RLWGui)
    NotifyContainer.Name = "NotifyContainer"
    NotifyContainer.BackgroundTransparency = 1
    NotifyContainer.Size = UDim2.new(0, 300, 1, -60) -- Alttan 60px boşluk bıraktık (aşağıya yapışmasın)
    NotifyContainer.Position = UDim2.new(1, -310, 0, 30) -- Sağ duvardan 10px boşluk (duvara yapışmasın)
    NotifyContainer.ZIndex = 100
    
    local NotifyLayout = Instance.new("UIListLayout", NotifyContainer)
    NotifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifyLayout.Padding = UDim.new(0, 0)
    NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local Window = {
        CurrentTab = nil,
        Tabs = {},
        Flags = {},
        Elements = {},
        ConfigSaving = options.ConfigurationSaving
    }
    
    local HttpService = game:GetService("HttpService")

    function Window:SaveConfiguration()
        if not self.ConfigSaving or not self.ConfigSaving.Enabled then return end
        if not writefile then return end
        
        local folder = self.ConfigSaving.FolderName or "RLW_Configs"
        local file = self.ConfigSaving.FileName or "Config"
        
        if not isfolder(folder) then pcall(function() makefolder(folder) end) end
        
        local success, json = pcall(function() return HttpService:JSONEncode(self.Flags) end)
        if success then
            pcall(function() writefile(folder .. "/" .. file .. ".json", json) end)
        end
    end

    function Window:LoadConfiguration()
        if not self.ConfigSaving or not self.ConfigSaving.Enabled then return end
        if not readfile or not isfile then return end
        
        local folder = self.ConfigSaving.FolderName or "RLW_Configs"
        local file = self.ConfigSaving.FileName or "Config"
        local path = folder .. "/" .. file .. ".json"
        
        if isfile(path) then
            local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
            if success and type(decoded) == "table" then
                for flag, value in pairs(decoded) do
                    if self.Elements[flag] then
                        self.Elements[flag]:Set(value)
                    else
                        self.Flags[flag] = value
                    end
                end
            end
        end
    end

    function Window:Notify(opts)
        opts = opts or {}
        local duration = opts.Duration or 3
        
        -- Görünmez Taşıyıcı (Alan açmak için)
        local WrapperFrame = Instance.new("Frame", NotifyContainer)
        WrapperFrame.BackgroundTransparency = 1
        WrapperFrame.Size = UDim2.new(1, 0, 0, 0)
        WrapperFrame.ClipsDescendants = false

        -- Asıl Bildirim Kutusu
        local NotifFrame = Instance.new("Frame", WrapperFrame)
        NotifFrame.Size = UDim2.new(0, 280, 0, 75)
        NotifFrame.Position = UDim2.new(1, 50, 0, 5) -- Başlangıçta ekranın sağında gizli
        NotifFrame.BackgroundColor3 = Theme.ElementBG
        NotifFrame.ClipsDescendants = false -- Gölge kesilmesin diye false
        Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 6)
        
        local Shadow = Instance.new("ImageLabel", NotifFrame)
        Shadow.BackgroundTransparency = 1
        Shadow.Position = UDim2.new(0, -15, 0, -15)
        Shadow.Size = UDim2.new(1, 30, 1, 30)
        Shadow.ZIndex = -5
        Shadow.Image = "rbxassetid://6015897733"
        Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
        Shadow.ImageTransparency = 0.5
        Shadow.ScaleType = Enum.ScaleType.Slice
        Shadow.SliceCenter = Rect.new(31, 31, 225, 225)

        local NTitle = Instance.new("TextLabel", NotifFrame)
        NTitle.BackgroundTransparency = 1
        NTitle.Position = UDim2.new(0, 15, 0, 10)
        NTitle.Size = UDim2.new(1, -30, 0, 20)
        NTitle.Font = Enum.Font.Ubuntu
        NTitle.Text = opts.Title or "Notification"
        NTitle.TextColor3 = Theme.Accent
        NTitle.TextSize = 16
        NTitle.TextXAlignment = Enum.TextXAlignment.Left
        
        local NContent = Instance.new("TextLabel", NotifFrame)
        NContent.BackgroundTransparency = 1
        NContent.Position = UDim2.new(0, 15, 0, 30)
        NContent.Size = UDim2.new(1, -30, 0, 35)
        NContent.Font = Enum.Font.Ubuntu
        NContent.Text = opts.Content or "..."
        NContent.TextColor3 = Theme.Text
        NContent.TextSize = 14
        NContent.TextWrapped = true
        NContent.TextXAlignment = Enum.TextXAlignment.Left
        NContent.TextYAlignment = Enum.TextYAlignment.Top
        
        local BarBG = Instance.new("Frame", NotifFrame)
        BarBG.Size = UDim2.new(1, -30, 0, 4)
        BarBG.Position = UDim2.new(0, 15, 1, -12)
        BarBG.BackgroundColor3 = Theme.SidebarBG
        BarBG.BorderSizePixel = 0
        Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)
        
        local Bar = Instance.new("Frame", BarBG)
        Bar.Size = UDim2.new(1, 0, 1, 0)
        Bar.BackgroundColor3 = Theme.Accent
        Bar.BorderSizePixel = 0
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)
        
        -- 1. Animasyon: Önce listede yer açılır
        tween(WrapperFrame, {Size = UDim2.new(1, 0, 0, 85)}, 0.25)
        task.wait(0.1)
        
        -- 2. Animasyon: Bildirim sağdan sola doğru kayarak gelir
        tween(NotifFrame, {Position = UDim2.new(0, 20, 0, 5)}, 0.4)
        
        -- Süre barı akar
        tween(Bar, {Size = UDim2.new(0, 0, 1, 0)}, duration)
        
        task.delay(duration, function()
            -- 3. Animasyon: Sağa doğru kayarak ekrandan çıkar
            tween(NotifFrame, {Position = UDim2.new(1, 50, 0, 5)}, 0.4)
            task.wait(0.3)
            -- 4. Animasyon: Listede açılan yer kapanır
            tween(WrapperFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.25)
            task.wait(0.25)
            pcall(function() WrapperFrame:Destroy() end)
        end)
    end

    function Window:CreateTab(tabName)
        local TabBtn = Instance.new("TextButton", TabContainer)
        TabBtn.Size = UDim2.new(1, -20, 0, 32)
        TabBtn.BackgroundColor3 = Theme.ElementBG
        TabBtn.Text = tabName
        TabBtn.Font = Enum.Font.Ubuntu
        TabBtn.TextColor3 = Theme.TextDark
        TabBtn.TextSize = 13
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

        local TabPage = Instance.new("ScrollingFrame", ContentContainer)
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 3
        TabPage.ScrollBarImageColor3 = Theme.Accent
        TabPage.BorderSizePixel = 0
        TabPage.Visible = false

        local PageLayout = Instance.new("UIListLayout", TabPage)
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 8)

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 10)
        end)

        TabBtn.MouseButton1Click:Connect(function()
            if Window.CurrentTab == tabName then return end
            
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                tween(t.Button, {BackgroundColor3 = Theme.ElementBG, TextColor3 = Theme.TextDark}, 0.35)
            end
            
            TabPage.Visible = true
            -- Yumuşak sayfa geçişi için basit bir "pop" efekti (opsiyonel ama şık durur)
            TabPage.GroupTransparency = 1
            tween(TabPage, {GroupTransparency = 0}, 0.3)

            tween(TabBtn, {BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Text}, 0.35)
            Window.CurrentTab = tabName
        end)

        if not Window.CurrentTab then
            TabPage.Visible = true
            TabBtn.BackgroundColor3 = Theme.Accent
            TabBtn.TextColor3 = Theme.Text
            Window.CurrentTab = tabName
        end

        local Tab = {Page = TabPage, Button = TabBtn}
        table.insert(Window.Tabs, Tab)

        function Tab:CreateToggle(opts)
            opts = opts or {}
            local state = opts.CurrentValue or false

            local ToggleFrame = Instance.new("TextButton", TabPage)
            ToggleFrame.Size = UDim2.new(1, -10, 0, 40)
            ToggleFrame.BackgroundColor3 = Theme.ElementBG
            ToggleFrame.Text = ""
            ToggleFrame.AutoButtonColor = false
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)

            ToggleFrame.MouseEnter:Connect(function() tween(ToggleFrame, {BackgroundColor3 = Theme.ElementHover}, 0.2) end)
            ToggleFrame.MouseLeave:Connect(function() tween(ToggleFrame, {BackgroundColor3 = Theme.ElementBG}, 0.2) end)

            local Title = Instance.new("TextLabel", ToggleFrame)
            Title.BackgroundTransparency = 1
            Title.Position = UDim2.new(0, 15, 0, 0)
            Title.Size = UDim2.new(1, -60, 1, 0)
            Title.Font = Enum.Font.Ubuntu
            Title.Text = opts.Name or "Toggle"
            Title.TextColor3 = Theme.Text
            Title.TextSize = 14
            Title.TextXAlignment = Enum.TextXAlignment.Left

            local SwitchBG = Instance.new("Frame", ToggleFrame)
            SwitchBG.Size = UDim2.new(0, 40, 0, 20)
            SwitchBG.Position = UDim2.new(1, -55, 0.5, -10)
            SwitchBG.BackgroundColor3 = state and Theme.Accent or Theme.Border
            Instance.new("UICorner", SwitchBG).CornerRadius = UDim.new(1, 0)

            local SwitchCircle = Instance.new("Frame", SwitchBG)
            SwitchCircle.Size = UDim2.new(0, 16, 0, 16)
            SwitchCircle.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            SwitchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", SwitchCircle).CornerRadius = UDim.new(1, 0)

            local Element = {}
            if opts.Flag then
                Window.Flags[opts.Flag] = state
                Window.Elements[opts.Flag] = Element
            end

            function Element:Set(newState)
                if type(newState) ~= "boolean" then return end
                state = newState
                tween(SwitchBG, {BackgroundColor3 = state and Theme.Accent or Theme.Border}, 0.35)
                tween(SwitchCircle, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.4)
                if opts.Flag then Window.Flags[opts.Flag] = state; Window:SaveConfiguration() end
                if opts.Callback then opts.Callback(state) end
            end

            ToggleFrame.MouseButton1Click:Connect(function()
                Element:Set(not state)
            end)
            
            return Element
        end

        function Tab:CreateButton(opts)
            opts = opts or {}
            local BtnFrame = Instance.new("TextButton", TabPage)
            BtnFrame.Size = UDim2.new(1, -10, 0, 36)
            BtnFrame.BackgroundColor3 = Theme.ElementBG
            BtnFrame.Text = opts.Name or "Button"
            BtnFrame.Font = Enum.Font.Ubuntu
            BtnFrame.TextColor3 = Theme.Text
            BtnFrame.TextSize = 14
            Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(0, 6)

            BtnFrame.MouseEnter:Connect(function() tween(BtnFrame, {BackgroundColor3 = Theme.ElementHover}, 0.3) end)
            BtnFrame.MouseLeave:Connect(function() tween(BtnFrame, {BackgroundColor3 = Theme.ElementBG}, 0.3) end)
            BtnFrame.MouseButton1Click:Connect(function()
                -- Soft tıklama efekti: Hafifçe küçült ve mor yap, sonra eski haline pürüzsüzce dön
                tween(BtnFrame, {BackgroundColor3 = Theme.Accent, Size = UDim2.new(1, -16, 0, 32)}, 0.15)
                task.wait(0.15)
                tween(BtnFrame, {BackgroundColor3 = Theme.ElementHover, Size = UDim2.new(1, -10, 0, 36)}, 0.3)
                if opts.Callback then opts.Callback() end
            end)
        end

        function Tab:CreateSlider(opts)
            opts = opts or {}
            local min = opts.Range[1] or 0
            local max = opts.Range[2] or 100
            local val = opts.CurrentValue or min

            local SliderFrame = Instance.new("Frame", TabPage)
            SliderFrame.Size = UDim2.new(1, -10, 0, 50)
            SliderFrame.BackgroundColor3 = Theme.ElementBG
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)

            local Title = Instance.new("TextLabel", SliderFrame)
            Title.BackgroundTransparency = 1
            Title.Position = UDim2.new(0, 15, 0, 5)
            Title.Size = UDim2.new(0.5, 0, 0, 20)
            Title.Font = Enum.Font.Ubuntu
            Title.Text = opts.Name or "Slider"
            Title.TextColor3 = Theme.Text
            Title.TextSize = 14
            Title.TextXAlignment = Enum.TextXAlignment.Left

            local ValueLabel = Instance.new("TextLabel", SliderFrame)
            ValueLabel.BackgroundTransparency = 1
            ValueLabel.Position = UDim2.new(0.5, -15, 0, 5)
            ValueLabel.Size = UDim2.new(0.5, 0, 0, 20)
            ValueLabel.Font = Enum.Font.Ubuntu
            ValueLabel.Text = tostring(val)
            ValueLabel.TextColor3 = Theme.Accent
            ValueLabel.TextSize = 14
            ValueLabel.TextXAlignment = Enum.TextXAlignment.Right

            local Track = Instance.new("TextButton", SliderFrame)
            Track.Size = UDim2.new(1, -30, 0, 6)
            Track.Position = UDim2.new(0, 15, 0, 32)
            Track.BackgroundColor3 = Theme.Border
            Track.Text = ""
            Track.AutoButtonColor = false
            Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

            local Fill = Instance.new("Frame", Track)
            Fill.Size = UDim2.new((val - min)/(max - min), 0, 1, 0)
            Fill.BackgroundColor3 = Theme.Accent
            Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

            local Element = {}
            if opts.Flag then
                Window.Flags[opts.Flag] = val
                Window.Elements[opts.Flag] = Element
            end

            function Element:Set(newVal)
                newVal = tonumber(newVal)
                if not newVal then return end
                val = math.clamp(newVal, min, max)
                ValueLabel.Text = tostring(val)
                local p = (val - min) / (max - min)
                tween(Fill, {Size = UDim2.new(p, 0, 1, 0)}, 0.15)
                if opts.Flag then Window.Flags[opts.Flag] = val; Window:SaveConfiguration() end
                if opts.Callback then opts.Callback(val) end
            end

            local dragging = false
            
            local function updateSliderFromInput(input)
                local p = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                local scaled = math.floor(min + (max - min) * p)
                if val ~= scaled then
                    Element:Set(scaled)
                end
            end
            
            Track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateSliderFromInput(input) -- Instantly set value on first click/tap
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSliderFromInput(input)
                end
            end)
            
            return Element
        end

        function Tab:CreateSection(title)
            local SectionLabel = Instance.new("TextLabel", TabPage)
            SectionLabel.Size = UDim2.new(1, -10, 0, 25)
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text = title or "Section"
            SectionLabel.Font = Enum.Font.Ubuntu
            SectionLabel.TextColor3 = Theme.Accent
            SectionLabel.TextSize = 15
            SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        end

        function Tab:CreateInput(opts)
            opts = opts or {}
            local InputFrame = Instance.new("Frame", TabPage)
            InputFrame.Size = UDim2.new(1, -10, 0, 40)
            InputFrame.BackgroundColor3 = Theme.ElementBG
            Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 6)
            
            local Title = Instance.new("TextLabel", InputFrame)
            Title.BackgroundTransparency = 1
            Title.Position = UDim2.new(0, 15, 0, 0)
            Title.Size = UDim2.new(0.5, 0, 1, 0)
            Title.Font = Enum.Font.Ubuntu
            Title.Text = opts.Name or "Input"
            Title.TextColor3 = Theme.Text
            Title.TextSize = 14
            Title.TextXAlignment = Enum.TextXAlignment.Left
            
            local TextBoxBG = Instance.new("Frame", InputFrame)
            TextBoxBG.Size = UDim2.new(0.5, 0, 0, 26) -- Biraz daha genişlettim ki URL sığsın
            TextBoxBG.Position = UDim2.new(0.5, -10, 0.5, -13)
            TextBoxBG.BackgroundColor3 = Theme.SidebarBG
            TextBoxBG.ClipsDescendants = true
            Instance.new("UICorner", TextBoxBG).CornerRadius = UDim.new(0, 4)
            
            local TextBox = Instance.new("TextBox", TextBoxBG)
            TextBox.Size = UDim2.new(1, -10, 1, 0)
            TextBox.Position = UDim2.new(0, 5, 0, 0)
            TextBox.BackgroundTransparency = 1
            TextBox.Font = Enum.Font.Ubuntu
            TextBox.PlaceholderText = opts.PlaceholderText or "Type..."
            TextBox.Text = ""
            TextBox.TextColor3 = Theme.Text
            TextBox.TextSize = 13
            TextBox.TextXAlignment = Enum.TextXAlignment.Right
            TextBox.ClearTextOnFocus = false
            TextBox.ClipsDescendants = true
            
            local Element = {}
            if opts.Flag then
                Window.Flags[opts.Flag] = TextBox.Text
                Window.Elements[opts.Flag] = Element
            end

            function Element:Set(txt)
                TextBox.Text = tostring(txt)
                if opts.Flag then Window.Flags[opts.Flag] = TextBox.Text; Window:SaveConfiguration() end
                if opts.Callback then opts.Callback(TextBox.Text) end
            end

            TextBox.FocusLost:Connect(function()
                local txt = TextBox.Text
                Element:Set(txt)
                if opts.RemoveTextAfterFocusLost then
                    TextBox.Text = ""
                end
            end)
            
            return Element
        end

        function Tab:CreateDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local current = opts.CurrentOption and opts.CurrentOption[1] or (options[1] or "")
            
            local DropdownFrame = Instance.new("Frame", TabPage)
            DropdownFrame.Size = UDim2.new(1, -10, 0, 40)
            DropdownFrame.BackgroundColor3 = Theme.ElementBG
            DropdownFrame.ClipsDescendants = true
            Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 6)
            
            local Title = Instance.new("TextLabel", DropdownFrame)
            Title.BackgroundTransparency = 1
            Title.Position = UDim2.new(0, 15, 0, 0)
            Title.Size = UDim2.new(1, -60, 0, 40)
            Title.Font = Enum.Font.Ubuntu
            Title.Text = opts.Name or "Dropdown"
            Title.TextColor3 = Theme.Text
            Title.TextSize = 14
            Title.TextXAlignment = Enum.TextXAlignment.Left
            
            local SelectedText = Instance.new("TextLabel", DropdownFrame)
            SelectedText.BackgroundTransparency = 1
            SelectedText.Position = UDim2.new(0.5, -45, 0, 0)
            SelectedText.Size = UDim2.new(0.5, 0, 0, 40)
            SelectedText.Font = Enum.Font.Ubuntu
            SelectedText.Text = current
            SelectedText.TextColor3 = Theme.Accent
            SelectedText.TextSize = 13
            SelectedText.TextXAlignment = Enum.TextXAlignment.Right
            
            local ArrowLabel = Instance.new("TextLabel", DropdownFrame)
            ArrowLabel.BackgroundTransparency = 1
            ArrowLabel.Position = UDim2.new(1, -30, 0, 0)
            ArrowLabel.Size = UDim2.new(0, 20, 0, 40)
            ArrowLabel.Font = Enum.Font.Ubuntu
            ArrowLabel.Text = "v"
            ArrowLabel.TextColor3 = Theme.TextDark
            ArrowLabel.TextSize = 16
            
            local ToggleBtn = Instance.new("TextButton", DropdownFrame)
            ToggleBtn.Size = UDim2.new(1, 0, 0, 40)
            ToggleBtn.BackgroundTransparency = 1
            ToggleBtn.Text = ""
            
            local ListContainer = Instance.new("ScrollingFrame", DropdownFrame)
            ListContainer.Size = UDim2.new(1, -10, 1, -45)
            ListContainer.Position = UDim2.new(0, 5, 0, 40)
            ListContainer.BackgroundTransparency = 1
            ListContainer.ScrollBarThickness = 2
            ListContainer.ScrollBarImageColor3 = Theme.Accent
            ListContainer.BorderSizePixel = 0
            
            local ListLayout = Instance.new("UIListLayout", ListContainer)
            ListLayout.Padding = UDim.new(0, 4)
            ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            
            local isOpen = false
            
            local Element = {}
            if opts.Flag then
                Window.Flags[opts.Flag] = current
                Window.Elements[opts.Flag] = Element
            end

            function Element:Set(optName)
                current = tostring(optName)
                SelectedText.Text = current
                if opts.Flag then Window.Flags[opts.Flag] = current; Window:SaveConfiguration() end
                if opts.Callback then opts.Callback({current}) end
            end

            local function refreshList()
                for _, child in ipairs(ListContainer:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                
                for _, opt in ipairs(options) do
                    local optBtn = Instance.new("TextButton", ListContainer)
                    optBtn.Size = UDim2.new(1, -10, 0, 28)
                    optBtn.BackgroundColor3 = Theme.SidebarBG
                    optBtn.Text = tostring(opt)
                    optBtn.Font = Enum.Font.Ubuntu
                    optBtn.TextColor3 = Theme.TextDark
                    optBtn.TextSize = 13
                    Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)
                    
                    optBtn.MouseEnter:Connect(function() tween(optBtn, {BackgroundColor3 = Theme.ElementHover, TextColor3 = Theme.Text}, 0.2) end)
                    optBtn.MouseLeave:Connect(function() tween(optBtn, {BackgroundColor3 = Theme.SidebarBG, TextColor3 = Theme.TextDark}, 0.2) end)
                    
                    optBtn.MouseButton1Click:Connect(function()
                        Element:Set(opt)
                        isOpen = false
                        tween(ArrowLabel, {Rotation = 0}, 0.3)
                        tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, 40)}, 0.3)
                    end)
                end
                ListContainer.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 5)
            end
            refreshList()
            
            ToggleBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    local totalHeight = 45 + math.min(#options * 32, 130)
                    tween(ArrowLabel, {Rotation = 180}, 0.3)
                    tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, totalHeight)}, 0.3)
                else
                    tween(ArrowLabel, {Rotation = 0}, 0.3)
                    tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, 40)}, 0.3)
                end
            end)
            
            return Element
        end

        return Tab
    end

    return Window
end

return RLW_Library
