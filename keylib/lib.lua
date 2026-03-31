-- RLW Professional UI Library v3.0
-- Full-featured Script Hub with Tabs, Toggles, Sliders, and Dropdowns
-- Smooth Key System to Main Hub Transition

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")

local Library = {
    Tabs = {},
    Elements = {},
    CurrentTab = nil
}

-- [[ UTILITIES ]]
local function CreateTween(instance, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

function Library.createElement(className, props, children)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            if type(v) == "function" and string.match(k, "^On") then
                local eventName = string.sub(k, 3)
                if eventName == "Click" then eventName = "MouseButton1Click" end
                if inst[eventName] then inst[eventName]:Connect(v) end
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
            if typeof(child) == "Instance" then child.Parent = inst end
        end
    end
    return inst
end

local el = Library.createElement

-- [[ COMPONENTS ]]

function Library:CreateToggle(parent, name, default, callback)
    local enabled = default or false
    local mainColor = Color3.fromRGB(99, 102, 241)
    
    local container = el("Frame", {
        Name = name .. "Toggle",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    local label = el("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Color3.fromRGB(220, 220, 225),
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    
    local bg = el("Frame", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = enabled and mainColor or Color3.fromRGB(30, 30, 35),
        CornerRadius = UDim.new(1, 0),
        Stroke = {Color = Color3.fromRGB(45, 45, 50), Thickness = 1},
        Parent = container
    })
    
    local circle = el("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        CornerRadius = UDim.new(1, 0),
        Parent = bg
    })
    
    local btn = el("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = container,
        OnClick = function()
            enabled = not enabled
            CreateTween(bg, {BackgroundColor3 = enabled and mainColor or Color3.fromRGB(30, 30, 35)}, 0.2)
            CreateTween(circle, {Position = enabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}, 0.2)
            callback(enabled)
        end
    })
end

function Library:CreateSlider(parent, name, min, max, default, callback)
    local value = default or min
    local mainColor = Color3.fromRGB(99, 102, 241)
    
    local container = el("Frame", {
        Name = name .. "Slider",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    local label = el("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Color3.fromRGB(220, 220, 225),
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    
    local valLabel = el("TextLabel", {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = mainColor,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })
    
    local track = el("Frame", {
        Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Color3.fromRGB(30, 30, 35),
        BorderSizePixel = 0,
        CornerRadius = UDim.new(1, 0),
        Parent = container
    })
    
    local fill = el("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = mainColor,
        BorderSizePixel = 0,
        CornerRadius = UDim.new(1, 0),
        Parent = track
    })
    
    local knob = el("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        CornerRadius = UDim.new(1, 0),
        Stroke = {Color = mainColor, Thickness = 2},
        Parent = fill
    })
    
    local dragging = false
    local function Update(input)
        local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pos)
        valLabel.Text = tostring(value)
        CreateTween(fill, {Size = UDim2.new(pos, 0, 1, 0)}, 0.1)
        callback(value)
    end
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then Update(input) end
    end)
end

-- [[ MAIN WINDOW ]]

function Library:CreateWindow(config)
    config = config or {}
    local titleText = config.Title or "RLWSCRIPTS"
    local mainColor = config.MainColor or Color3.fromRGB(99, 102, 241)
    
    local screenGui = el("ScreenGui", {Name = "RLW_Hub", ResetOnSpawn = false})
    if gethui then screenGui.Parent = gethui() else screenGui.Parent = CoreGui end
    
    local blur = Instance.new("BlurEffect", Lighting)
    blur.Size = 0
    CreateTween(blur, {Size = 15}, 0.5)
    
    local mainFrame = el("CanvasGroup", {
        Name = "Main",
        Size = UDim2.new(0, 400, 0, 270),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(12, 12, 14),
        CornerRadius = UDim.new(0, 12),
        Stroke = {Color = Color3.fromRGB(35, 35, 40), Thickness = 1},
        ClipsDescendants = true,
        Parent = screenGui
    })
    
    local shadow = el("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 8),
        Size = UDim2.new(0, 420, 0, 290),
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.92,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        ZIndex = -1,
        Parent = screenGui
    })

    -- Key System UI
    local keySystem = el("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = mainFrame
    })
    
    local header = el("Frame", {
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundTransparency = 1,
        Parent = keySystem,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24), Top = UDim.new(0, 24)}
    })
    
    el("TextLabel", {
        Text = titleText,
        Size = UDim2.new(1, 0, 0, 24),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Parent = header
    })
    
    local content = el("Frame", {
        Size = UDim2.new(1, 0, 1, -80),
        Position = UDim2.new(0, 0, 0, 80),
        BackgroundTransparency = 1,
        Parent = keySystem,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24), Bottom = UDim.new(0, 24)}
    })
    
    local inputFrame = el("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Color3.fromRGB(15, 15, 17),
        CornerRadius = UDim.new(0, 8),
        Stroke = {Color = Color3.fromRGB(45, 45, 50), Thickness = 1},
        Parent = content
    })
    
    local inputBox = el("TextBox", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        PlaceholderText = "Enter key (123)...",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        Padding = {Left = UDim.new(0, 16)},
        Parent = inputFrame
    })
    
    -- Hub UI (Hidden initially)
    local hubUI = el("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = mainFrame
    })
    
    local tabContainer = el("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = hubUI,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24)}
    })
    
    local tabList = el("Frame", {
        Size = UDim2.new(1, -100, 1, 0),
        BackgroundTransparency = 1,
        Parent = tabContainer
    })
    el("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 15), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tabList})
    
    el("TextLabel", {
        Text = titleText,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        TextColor3 = mainColor,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        BackgroundTransparency = 1,
        Parent = tabContainer
    })
    
    local pageContainer = el("Frame", {
        Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = hubUI,
        Padding = {Left = UDim.new(0, 24), Right = UDim.new(0, 24), Bottom = UDim.new(0, 24)}
    })

    local function Transition()
        CreateTween(keySystem, {GroupTransparency = 1}, 0.3).Completed:Wait()
        keySystem.Visible = false
        hubUI.Visible = true
        hubUI.GroupTransparency = 1
        
        CreateTween(mainFrame, {Size = UDim2.new(0, 550, 0, 350)}, 0.5, Enum.EasingStyle.Back)
        CreateTween(shadow, {Size = UDim2.new(0, 570, 0, 370)}, 0.5, Enum.EasingStyle.Back)
        task.wait(0.2)
        CreateTween(hubUI, {GroupTransparency = 0}, 0.3)
    end

    local validateBtn = el("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 1, -44),
        BackgroundColor3 = mainColor,
        Text = "Validate Key",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        CornerRadius = UDim.new(0, 8),
        Parent = content,
        OnClick = function()
            if inputBox.Text == "123" then
                Transition()
            end
        end
    })

    local window = {
        TabList = tabList,
        PageContainer = pageContainer,
        Tabs = {}
    }

    function window:AddTab(name)
        local page = el("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = mainColor,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Parent = pageContainer
        })
        el("UIListLayout", {Padding = UDim.new(0, 10), Parent = page})
        el("UIPadding", {PaddingTop = UDim.new(0, 5), Parent = page})
        
        local tabBtn = el("TextButton", {
            Text = name,
            Size = UDim2.new(0, 0, 0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(150, 150, 160),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            Parent = tabList
        })
        
        local underline = el("Frame", {
            Size = UDim2.new(0, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = mainColor,
            BorderSizePixel = 0,
            Visible = false,
            Parent = tabBtn
        })

        local function Select()
            for _, t in pairs(window.Tabs) do
                t.Button.TextColor3 = Color3.fromRGB(150, 150, 160)
                t.Underline.Visible = false
                t.Page.Visible = false
            end
            tabBtn.TextColor3 = Color3.new(1, 1, 1)
            underline.Visible = true
            underline.Size = UDim2.new(0, 0, 0, 2)
            CreateTween(underline, {Size = UDim2.new(1, 0, 0, 2)}, 0.3)
            page.Visible = true
        end

        tabBtn.MouseButton1Click:Connect(Select)
        
        local tabObj = {Button = tabBtn, Underline = underline, Page = page}
        table.insert(window.Tabs, tabObj)
        
        if #window.Tabs == 1 then Select() end

        function tabObj:AddToggle(name, default, callback)
            Library:CreateToggle(page, name, default, callback)
            page.CanvasSize = UDim2.new(0, 0, 0, page.UIListLayout.AbsoluteContentSize.Y + 20)
        end
        
        function tabObj:AddSlider(name, min, max, default, callback)
            Library:CreateSlider(page, name, min, max, default, callback)
            page.CanvasSize = UDim2.new(0, 0, 0, page.UIListLayout.AbsoluteContentSize.Y + 20)
        end

        function tabObj:AddButton(name, callback)
            local btn = el("TextButton", {
                Text = name,
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Color3.fromRGB(25, 25, 30),
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamMedium,
                TextSize = 14,
                CornerRadius = UDim.new(0, 6),
                Stroke = {Color = Color3.fromRGB(45, 45, 50), Thickness = 1},
                Parent = page,
                OnClick = callback
            })
            page.CanvasSize = UDim2.new(0, 0, 0, page.UIListLayout.AbsoluteContentSize.Y + 20)
        end

        function tabObj:AddDropdown(name, options, callback)
            local expanded = false
            local selected = options[1] or "None"
            
            local container = el("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Parent = page
            })
            
            local btn = el("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Color3.fromRGB(25, 25, 30),
                Text = name .. ": " .. selected,
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamMedium,
                TextSize = 14,
                CornerRadius = UDim.new(0, 6),
                Stroke = {Color = Color3.fromRGB(45, 45, 50), Thickness = 1},
                Parent = container,
                OnClick = function()
                    expanded = not expanded
                    CreateTween(container, {Size = expanded and UDim2.new(1, 0, 0, 40 + (#options * 30)) or UDim2.new(1, 0, 0, 40)}, 0.3)
                    page.CanvasSize = UDim2.new(0, 0, 0, page.UIListLayout.AbsoluteContentSize.Y + 20)
                end
            })
            
            local list = el("Frame", {
                Size = UDim2.new(1, 0, 0, #options * 30),
                Position = UDim2.new(0, 0, 0, 40),
                BackgroundTransparency = 1,
                Parent = container
            })
            el("UIListLayout", {Parent = list})
            
            for _, opt in pairs(options) do
                el("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = opt,
                    TextColor3 = Color3.fromRGB(180, 180, 190),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    Parent = list,
                    OnClick = function()
                        selected = opt
                        btn.Text = name .. ": " .. selected
                        expanded = false
                        CreateTween(container, {Size = UDim2.new(1, 0, 0, 40)}, 0.3)
                        callback(opt)
                    end
                })
            end
            page.CanvasSize = UDim2.new(0, 0, 0, page.UIListLayout.AbsoluteContentSize.Y + 20)
        end

        return tabObj
    end

    return window
end

return Library
