--[[
    RLW SIMPLE TOOLS - ULTIMATE PRO (FINAL POLISH)
    --------------------------------------------------------------
    - Fix: Technical note now has a transparent background and theme-matching color.
    - Save/Load: Auto-saves to RLW_Settings.json
    - Universal Shield: Full element detection
    - Ghost Anti-AFK v3: Randomized human simulation
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local StartTime = os.time()
local FileName = "RLW_Settings.json"

-- THEME
local Theme = {
    Accent = Color3.fromRGB(0, 210, 255),
    Background = Color3.fromRGB(10, 10, 12),
    Panel = Color3.fromRGB(18, 18, 22),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(140, 140, 150), -- Bu renk kullanılacak
    Border = Color3.fromRGB(40, 40, 45)
}

-- DEFAULT CONFIG
local Config = {
    ClickerEnabled = false,
    AntiAFKEnabled = false,
    FPSLimit = 60,
    Jitter = 10,
    OffsetX = 45,
    OffsetY = 45
}

-- [SYSTEM] SAVE/LOAD
local function SaveConfig()
    if writefile then
        local data = HttpService:JSONEncode(Config)
        writefile(FileName, data)
    end
end

local function LoadConfig()
    if isfile and isfile(FileName) then
        local status, result = pcall(function()
            return HttpService:JSONDecode(readfile(FileName))
        end)
        if status then
            for k, v in pairs(result) do Config[k] = v end
        end
    end
end

LoadConfig()
setfpscap(Config.FPSLimit)

-- [GUI] CORE SETUP
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "RLW_Ultimate_Pro"

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 230, 0, 320)
Main.Position = UDim2.new(0.8, 0, 0.4, 0)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = Theme.Border

-- [LOGIC] FULL ELEMENT SHIELD
local function IsOverGui()
    local mousePos = UserInputService:GetMouseLocation()
    local objects = PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
    
    for _, obj in pairs(objects) do
        if not obj:IsDescendantOf(ScreenGui) and obj:IsA("GuiObject") and obj.Visible then
            if obj.BackgroundTransparency < 1 or (obj:IsA("TextLabel") and obj.TextTransparency < 1) or (obj:IsA("ImageLabel") and obj.ImageTransparency < 1) then
                return true
            end
        end
    end
    
    local mP, mS = Main.AbsolutePosition, Main.AbsoluteSize
    if mousePos.X >= mP.X and mousePos.X <= mP.X + mS.X and mousePos.Y >= mP.Y and mousePos.Y <= mP.Y + mS.Y then
        return true
    end
    return false
end

-- [LOGIC] GHOST ANTI-AFK v3
task.spawn(function()
    while task.wait(math.random(15, 30)) do
        if Config.AntiAFKEnabled then
            local action = math.random(1, 4)
            if action == 1 then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.1) VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            elseif action == 2 then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                task.wait(0.1) VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, game)
                task.wait(0.1) VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
            elseif action == 3 then
                workspace.CurrentCamera.CFrame *= CFrame.Angles(0, math.rad(math.random(-2, 2)), 0)
            elseif action == 4 then
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(math.random(100,500), math.random(100,500)))
                task.wait(0.1) VirtualUser:Button1Up(Vector2.new(0,0))
            end
        end
    end
end)

-- [UI] COMPONENTS
local Container = Instance.new("ScrollingFrame", Main)
Container.Position = UDim2.new(0, 15, 0, 55)
Container.Size = UDim2.new(1, -30, 1, -115)
Container.BackgroundTransparency = 1
Container.ScrollBarThickness = 0
Instance.new("UIListLayout", Container).Padding = UDim.new(0, 10)

local function AddToggle(name, configKey)
    local Frame = Instance.new("TextButton", Container)
    Frame.Size = UDim2.new(1, 0, 0, 36)
    Frame.BackgroundColor3 = Theme.Panel
    Frame.Text = ""
    Frame.AutoButtonColor = false
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Frame).Color = Theme.Border

    local Label = Instance.new("TextLabel", Frame)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.Text = name
    Label.TextColor3 = Theme.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1

    local Switch = Instance.new("Frame", Frame)
    Switch.Position = UDim2.new(1, -34, 0.5, -8)
    Switch.Size = UDim2.new(0, 24, 0, 16)
    Switch.BackgroundColor3 = Config[configKey] and Theme.Accent or Color3.fromRGB(40, 40, 45)
    Instance.new("UICorner", Switch).CornerRadius = UDim.new(1, 0)

    local Dot = Instance.new("Frame", Switch)
    Dot.Position = Config[configKey] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    Dot.Size = UDim2.new(0, 12, 0, 12)
    Dot.BackgroundColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

    Frame.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = Config[configKey] and Theme.Accent or Color3.fromRGB(40, 40, 45)}):Play()
        TweenService:Create(Dot, TweenInfo.new(0.2), {Position = Config[configKey] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play()
        SaveConfig()
    end)
end

local function AddSlider(name, configKey, min, max, callback, note)
    local SFrame = Instance.new("Frame", Container)
    SFrame.Size = UDim2.new(1, 0, 0, note and 65 or 45) -- Not varsa biraz daha yer aç
    SFrame.BackgroundTransparency = 1

    local Label = Instance.new("TextLabel", SFrame)
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.Text = name .. ": " .. Config[configKey]
    Label.TextColor3 = Theme.SubText
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1

    local Bar = Instance.new("TextButton", SFrame)
    Bar.Position = UDim2.new(0, 0, 0, 25)
    Bar.Size = UDim2.new(1, 0, 0, 4)
    Bar.BackgroundColor3 = Theme.Panel
    Bar.Text = ""
    Bar.AutoButtonColor = false
    Instance.new("UICorner", Bar)

    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((Config[configKey]-min)/(max-min), 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Instance.new("UICorner", Fill)

    -- *** DÜZELTİLEN KISIM BURASI ***
    if note then
        local NoteLabel = Instance.new("TextLabel", SFrame)
        NoteLabel.Position = UDim2.new(0, 0, 0, 32) -- Biraz daha yukarı aldık
        NoteLabel.Size = UDim2.new(1, 0, 0, 30)
        NoteLabel.Text = note
        NoteLabel.TextColor3 = Theme.SubText -- Temaya uygun renk
        NoteLabel.Font = Enum.Font.GothamMedium -- Daha modern font
        NoteLabel.TextSize = 9 -- Biraz daha okunaklı
        NoteLabel.TextWrapped = true
        NoteLabel.TextXAlignment = Enum.TextXAlignment.Left
        NoteLabel.BackgroundTransparency = 1 -- TAMAMEN ŞEFFAF
    end

    local function Update(input)
        local ratio = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * ratio)
        Fill.Size = UDim2.new(ratio, 0, 1, 0)
        Label.Text = name .. ": " .. val
        Config[configKey] = val
        SaveConfig()
        callback(val)
    end

    Bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local con; con = UserInputService.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement then Update(m) end
            end)
            Update(i)
            UserInputService.InputEnded:Connect(function(e) if e.UserInputType == Enum.UserInputType.MouseButton1 then con:Disconnect() end end)
        end
    end)
end

-- [UI] HEADER & FOOTER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, 0, 1, 0)
Title.RichText = true
Title.Text = '<font color="#00D2FF">RLW</font> <font color="#FFFFFF">SIMPLE TOOLS</font>'
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.BackgroundTransparency = 1

local StatusPanel = Instance.new("Frame", Main)
StatusPanel.Position = UDim2.new(0, 15, 1, -45)
StatusPanel.Size = UDim2.new(1, -30, 0, 35)
StatusPanel.BackgroundTransparency = 1

local SessionInfo = Instance.new("TextLabel", StatusPanel)
SessionInfo.Size = UDim2.new(1, 0, 0, 15)
SessionInfo.Text = "RUNTIME: 00:00:00"
SessionInfo.TextColor3 = Theme.SubText
SessionInfo.Font = Enum.Font.Code
SessionInfo.TextSize = 10
SessionInfo.BackgroundTransparency = 1

local ShieldIndicator = Instance.new("TextLabel", StatusPanel)
ShieldIndicator.Position = UDim2.new(0, 0, 0, 15)
ShieldIndicator.Size = UDim2.new(1, 0, 0, 15)
ShieldIndicator.Text = "• SHIELD READY"
ShieldIndicator.TextColor3 = Color3.fromRGB(80, 80, 85)
ShieldIndicator.Font = Enum.Font.GothamBold
ShieldIndicator.TextSize = 9
ShieldIndicator.BackgroundTransparency = 1

-- [MAIN RUNNER]
RunService.Heartbeat:Connect(function()
    local elapsed = os.time() - StartTime
    SessionInfo.Text = string.format("RUNTIME: %02d:%02d:%02d", math.floor(elapsed/3600), math.floor(elapsed/60)%60, elapsed%60)
    
    if Config.ClickerEnabled then
        if IsOverGui() then
            ShieldIndicator.Text = "• SHIELD: BLOCKED (FULL SCAN)"
            ShieldIndicator.TextColor3 = Color3.fromRGB(255, 150, 0)
        else
            ShieldIndicator.Text = "• SHIELD: ACTIVE (CLICKING)"
            ShieldIndicator.TextColor3 = Theme.Accent
            local tX = Config.OffsetX + math.random(-Config.Jitter, Config.Jitter)
            local tY = (workspace.CurrentCamera.ViewportSize.Y - Config.OffsetY) + math.random(-Config.Jitter, Config.Jitter)
            VirtualInputManager:SendMouseButtonEvent(tX, tY, 0, true, game, 1)
            VirtualInputManager:SendMouseButtonEvent(tX, tY, 0, false, game, 1)
        end
    else
        ShieldIndicator.Text = "• SHIELD READY"
        ShieldIndicator.TextColor3 = Color3.fromRGB(80, 80, 85)
    end
end)

-- INITIALIZE FEATURES
AddToggle("Enable Auto Clicker", "ClickerEnabled")
AddToggle("Updated! Anti-AFK", "AntiAFKEnabled")
AddSlider("FPS Limit", "FPSLimit", 10, 240, function(v) setfpscap(v) end, "Available for executors that support setfpscap()")

-- DRAG & HIDE
local dS, sP, dG
Header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dG = true dS = i.Position sP = Main.Position end end)
UserInputService.InputChanged:Connect(function(i) if dG and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dS Main.Position = UDim2.new(sP.X.Scale, sP.X.Offset + d.X, sP.Y.Scale, sP.Y.Offset + d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dG = false end end)
UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.H then ScreenGui.Enabled = not ScreenGui.Enabled end end)

print("RLW Ultimate Pro: UI Polished & Ready.")
