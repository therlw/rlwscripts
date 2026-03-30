-- Advanced React-Like Key System Library v2.0
-- Professional, Modern, Sleek UI Design with Animations & Premium Features

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Library = {}

-- [[ UTILITIES ]]
local function CreateTween(instance, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Exploit File System Wrappers (Safe)
local function SaveKeyToFile(key)
    if writefile then
        pcall(function() writefile("RLW_SavedKey.txt", key) end)
    end
end

local function LoadKeyFromFile()
    if readfile and isfile then
        local success, result = pcall(function()
            if isfile("RLW_SavedKey.txt") then
                return readfile("RLW_SavedKey.txt")
            end
        end)
        if success and result then return result end
    end
    return ""
end

-- [[ REACT-LIKE ELEMENT CREATOR ]]
function Library.createElement(className, props, children)
    local inst = Instance.new(className)
    
    if props then
        for k, v in pairs(props) do
            if type(v) == "function" and string.match(k, "^On") then
                local eventName = string.sub(k, 3)
                if eventName == "Click" then eventName = "MouseButton1Click" end
                if eventName == "Change" then eventName = "Changed" end
                if eventName == "FocusLost" then eventName = "FocusLost" end
                if eventName == "FocusGained" then eventName = "Focused" end
                if eventName == "MouseEnter" then eventName = "MouseEnter" end
                if eventName == "MouseLeave" then eventName = "MouseLeave" end
                
                if inst[eventName] then
                    inst[eventName]:Connect(v)
                end
            elseif k == "CornerRadius" then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = v
                corner.Parent = inst
            elseif k == "Stroke" then
                local stroke = Instance.new("UIStroke")
                stroke.Color = v.Color or Color3.new(0,0,0)
                stroke.Thickness = v.Thickness or 1
                stroke.Transparency = v.Transparency or 0
                stroke.ApplyStrokeMode = v.ApplyStrokeMode or Enum.ApplyStrokeMode.Border
                stroke.Parent = inst
            elseif k == "Gradient" then
                local grad = Instance.new("UIGradient")
                grad.Color = v.Color
                grad.Rotation = v.Rotation or 0
                grad.Parent = inst
            elseif k == "Padding" then
                local pad = Instance.new("UIPadding")
                pad.PaddingTop = v.Top or UDim.new(0,0)
                pad.PaddingBottom = v.Bottom or UDim.new(0,0)
                pad.PaddingLeft = v.Left or UDim.new(0,0)
                pad.PaddingRight = v.Right or UDim.new(0,0)
                pad.Parent = inst
            else
                inst[k] = v
            end
        end
    end
    
    if children then
        for _, child in ipairs(children) do
            if typeof(child) == "Instance" then
                child.Parent = inst
            end
        end
    end
    
    return inst
end

local el = Library.createElement

-- [[ REUSABLE COMPONENTS ]]

function Library.PrimaryButton(props)
    local mainColor = props.Color or Color3.fromRGB(99, 102, 241)
    local h, s, v = mainColor:ToHSV()
    local hoverColor = Color3.fromHSV(h, s, math.clamp(v - 0.1, 0, 1))
    
    local btn = el("TextButton", {
        Name = props.Name or "PrimaryButton",
        Size = props.Size or UDim2.new(1, 0, 0, 44),
        Position = props.Position,
        BackgroundColor3 = mainColor,
        Text = props.Text or "Button",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        AutoButtonColor = false,
        CornerRadius = UDim.new(0, 8),
        ClipsDescendants = true,
        OnClick = props.OnClick
    })
    
    btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("Disabled") then
            CreateTween(btn, {BackgroundColor3 = hoverColor}, 0.2)
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("Disabled") then
            CreateTween(btn, {BackgroundColor3 = mainColor}, 0.2)
        end
    end)
    
    return btn
end

function Library.SecondaryButton(props)
    local defaultBg = Color3.fromRGB(20, 20, 22)
    local hoverBg = Color3.fromRGB(30, 30, 35)
    
    local btn = el("TextButton", {
        Name = props.Name or "SecondaryButton",
        Size = props.Size or UDim2.new(1, 0, 0, 44),
        Position = props.Position,
        BackgroundColor3 = defaultBg,
        Text = props.Text or "Button",
        TextColor3 = Color3.fromRGB(220, 220, 225),
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        AutoButtonColor = false,
        CornerRadius = UDim.new(0, 8),
        Stroke = {Color = Color3.fromRGB(45, 45, 50), Thickness = 1},
        OnClick = props.OnClick
    })
    
    btn.MouseEnter:Connect(function()
        CreateTween(btn, {BackgroundColor3 = hoverBg}, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        CreateTween(btn, {BackgroundColor3 = defaultBg}, 0.2)
    end)
    
    return btn
end

function Library.Input(props)
    local strokeColor = Color3.fromRGB(45, 45, 50)
    local focusColor = props.FocusColor or Color3.fromRGB(99, 102, 241)
    
    local container = el("Frame", {
        Name = props.Name or "InputContainer",
        Size = props.Size or UDim2.new(1, 0, 0, 44),
        Position = props.Position,
        BackgroundColor3 = Color3.fromRGB(15, 15, 17),
        CornerRadius = UDim.new(0, 8),
        Stroke = {Color = strokeColor, Thickness = 1}
    })
    
    local input = el("TextBox", {
        Name = "TextBox",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = props.DefaultText or "",
        PlaceholderText = props.PlaceholderText or "Enter text...",
        TextColor3 = Color3.fromRGB(240, 240, 245),
        PlaceholderColor3 = Color3.fromRGB(110, 110, 115),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Padding = {Left = UDim.new(0, 16), Right = UDim.new(0, 16)},
        Parent = container
    })
    
    local stroke = container:FindFirstChild("UIStroke")
    
    input.Focused:Connect(function()
        if stroke then CreateTween(stroke, {Color = focusColor}, 0.2) end
    end)
    
    input.FocusLost:Connect(function()
        if stroke then CreateTween(stroke, {Color = strokeColor}, 0.2) end
        if props.OnFocusLost then props.OnFocusLost(input.Text) end
    end)
    
    return container, input
end

-- [[ MAIN SYSTEM BUILDER ]]

function Library:CreateKeySystem(config)
    config = config or {}
    local titleText = config.Title or "RLWSCRIPTS"
    local descText = config.Description or "Please enter your key to continue."
    local mainColor = config.MainColor or Color3.fromRGB(99, 102, 241)
    local useBlur = config.UseBlur == nil and true or config.UseBlur
    local saveKey = config.SaveKey == nil and true or config.SaveKey
    
    local screenGui = el("ScreenGui", {
        Name = "ProfessionalKeySystem",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    if gethui then screenGui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(screenGui); screenGui.Parent = CoreGui
    else screenGui.Parent = CoreGui end

    -- Blur Effect
    local blurEffect
    if useBlur then
        blurEffect = Instance.new("BlurEffect")
        blurEffect.Size = 0
        blurEffect.Parent = Lighting
        CreateTween(blurEffect, {Size = 15}, 0.5)
    end

    -- Main Card
    local mainFrame = el("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 400, 0, 270),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(12, 12, 14),
        CornerRadius = UDim.new(0, 12),
        Stroke = {Color = Color3.fromRGB(35, 35, 40), Thickness = 1},
        ClipsDescendants = false
    })
    
    -- Drop Shadow (Fake)
    el("ImageLabel", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 4),
        Size = UDim2.new(1, 60, 1, 60),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.4,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = -1,
        Parent = mainFrame
    })

    -- Top Accent Line (Animated)
    local accentLine = el("Frame", {
        Name = "AccentLine",
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = mainFrame,
        Gradient = {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 14)),
                ColorSequenceKeypoint.new(0.5, mainColor),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 14))
            })
        }
    })
    
    -- Animate Gradient
    local grad = accentLine:FindFirstChildOfClass("UIGradient")
    task.spawn(function()
        local offset = 0
        while grad and grad.Parent do
            offset = offset + 0.01
            grad.Offset = Vector2.new(math.sin(offset), 0)
            task.wait(0.03)
        end
    end)
    
    -- Header Container
    local header = el("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundTransparency = 1,
        Parent = mainFrame,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24), Top = UDim.new(0, 24)}
    })
    
    -- Title
    el("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -30, 0, 24),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = Color3.fromRGB(250, 250, 255),
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    -- Description
    el("TextLabel", {
        Name = "Description",
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = descText,
        TextColor3 = Color3.fromRGB(160, 160, 170),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    -- Close Function
    local function CloseUI()
        if blurEffect then
            CreateTween(blurEffect, {Size = 0}, 0.3)
            task.delay(0.3, function() blurEffect:Destroy() end)
        end
        local tween = CreateTween(mainFrame, {Size = UDim2.new(0, 380, 0, 250), Position = UDim2.new(0.5, 0, 0.5, 20)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        -- Fade out elements manually since GroupTransparency is buggy on Frames
        for _, v in pairs(mainFrame:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
                CreateTween(v, {TextTransparency = 1}, 0.2)
            elseif v:IsA("Frame") and v.Name ~= "Main" then
                CreateTween(v, {BackgroundTransparency = 1}, 0.2)
            elseif v:IsA("UIStroke") then
                CreateTween(v, {Transparency = 1}, 0.2)
            end
        end
        CreateTween(mainFrame, {BackgroundTransparency = 1}, 0.3)
        
        tween.Completed:Wait()
        screenGui:Destroy()
    end

    -- Close Button
    el("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Text = "✕",
        TextColor3 = Color3.fromRGB(120, 120, 130),
        TextSize = 16,
        Font = Enum.Font.GothamMedium,
        Parent = header,
        OnMouseEnter = function(self) CreateTween(self, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2) end,
        OnMouseLeave = function(self) CreateTween(self, {TextColor3 = Color3.fromRGB(120, 120, 130)}, 0.2) end,
        OnClick = CloseUI
    })
    
    -- Content Container
    local content = el("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -80),
        Position = UDim2.new(0, 0, 0, 80),
        BackgroundTransparency = 1,
        Parent = mainFrame,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24), Bottom = UDim.new(0, 24)}
    })
    
    -- Input Field
    local initialKey = saveKey and LoadKeyFromFile() or ""
    local inputContainer, inputBox = Library.Input({
        Name = "KeyInput",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 10),
        PlaceholderText = "Enter your license key...",
        DefaultText = initialKey,
        FocusColor = mainColor
    })
    inputContainer.Parent = content
    
    -- Status Label
    local statusLabel = el("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 58),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(255, 80, 80),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = content
    })
    
    local function ShowStatus(text, color)
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(255, 80, 80)
        CreateTween(statusLabel, {TextTransparency = 0}, 0.2)
        task.delay(2.5, function()
            CreateTween(statusLabel, {TextTransparency = 1}, 0.2)
        end)
    end

    local function ShakeUI()
        local origPos = mainFrame.Position
        for i = 1, 6 do
            mainFrame.Position = origPos + UDim2.new(0, math.random(-4, 4), 0, math.random(-4, 4))
            task.wait(0.04)
        end
        mainFrame.Position = origPos
    end

    -- Buttons
    local validating = false
    local validateBtn = Library.PrimaryButton({
        Name = "ValidateBtn",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -96),
        Text = "Validate Key",
        Color = mainColor,
        OnClick = function(self)
            if validating then return end
            local key = inputBox.Text
            if key == "" then
                ShowStatus("Please enter a key first.")
                ShakeUI()
                return
            end
            
            if config.OnValidate then
                validating = true
                self:SetAttribute("Disabled", true)
                
                -- Loading Animation
                local originalText = self.Text
                local originalColor = self.BackgroundColor3
                self.Text = "Validating..."
                CreateTween(self, {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}, 0.2)
                
                -- Simulate Network Delay for premium feel
                task.wait(0.6)
                
                local success = config.OnValidate(key)
                if success then
                    if saveKey then SaveKeyToFile(key) end
                    self.Text = "Success!"
                    CreateTween(self, {BackgroundColor3 = Color3.fromRGB(46, 204, 113)}, 0.2)
                    ShowStatus("Successfully authenticated!", Color3.fromRGB(46, 204, 113))
                    task.wait(0.6)
                    CloseUI()
                else
                    self.Text = "Invalid Key"
                    CreateTween(self, {BackgroundColor3 = Color3.fromRGB(231, 76, 60)}, 0.2)
                    ShowStatus("Invalid key provided. Please try again.")
                    ShakeUI()
                    inputBox.Text = ""
                    task.wait(1)
                    self.Text = originalText
                    CreateTween(self, {BackgroundColor3 = originalColor}, 0.2)
                    self:SetAttribute("Disabled", false)
                    validating = false
                end
            end
        end
    })
    validateBtn.Parent = content
    
    local getKeyBtn = Library.SecondaryButton({
        Name = "GetKeyBtn",
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -44),
        Text = "Get Free Key",
        OnClick = function()
            if config.OnGetKey then
                config.OnGetKey()
                ShowStatus("Link copied to clipboard!", Color3.fromRGB(150, 150, 160))
            end
        end
    })
    getKeyBtn.Parent = content

    -- Smooth Dragging Logic
    local dragging, dragInput, mousePos, framePos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            CreateTween(mainFrame, {
                Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
            }, 0.1, Enum.EasingStyle.Linear)
        end
    end)
    
    -- Entrance Animation
    mainFrame.Size = UDim2.new(0, 380, 0, 250)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 20)
    mainFrame.BackgroundTransparency = 1
    
    -- Fade in elements
    for _, v in pairs(mainFrame:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
            v.TextTransparency = 1
            CreateTween(v, {TextTransparency = 0}, 0.4)
        elseif v:IsA("Frame") and v.Name ~= "Main" then
            local origTrans = v.BackgroundTransparency
            v.BackgroundTransparency = 1
            CreateTween(v, {BackgroundTransparency = origTrans}, 0.4)
        elseif v:IsA("UIStroke") then
            local origTrans = v.Transparency
            v.Transparency = 1
            CreateTween(v, {Transparency = origTrans}, 0.4)
        end
    end
    
    CreateTween(mainFrame, {Size = UDim2.new(0, 400, 0, 270), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    
    mainFrame.Parent = screenGui
    return screenGui
end

return Library
