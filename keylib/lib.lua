-- KeySystemLibrary.lua
-- A detailed, React-like GUI Library for Roblox Key Systems

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {}

-- [[ REACT-LIKE ELEMENT CREATOR ]]
-- This function acts like React.createElement, allowing nested, declarative UI building.
function Library.createElement(className, props, children)
    local inst = Instance.new(className)
    
    if props then
        for k, v in pairs(props) do
            -- Event binding (e.g., OnClick -> MouseButton1Click)
            if type(v) == "function" and string.match(k, "^On") then
                local eventName = string.sub(k, 3)
                if eventName == "Click" then eventName = "MouseButton1Click" end
                if eventName == "Change" then eventName = "Changed" end
                if eventName == "FocusLost" then eventName = "FocusLost" end
                
                if inst[eventName] then
                    inst[eventName]:Connect(v)
                end
            -- Custom declarative properties
            elseif k == "CornerRadius" then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = v
                corner.Parent = inst
            elseif k == "Stroke" then
                local stroke = Instance.new("UIStroke")
                stroke.Color = v.Color or Color3.new(0,0,0)
                stroke.Thickness = v.Thickness or 1
                stroke.ApplyStrokeMode = v.ApplyStrokeMode or Enum.ApplyStrokeMode.Border
                stroke.Parent = inst
            elseif k == "Gradient" then
                local grad = Instance.new("UIGradient")
                grad.Color = v.Color
                grad.Rotation = v.Rotation or 0
                grad.Parent = inst
            else
                -- Standard properties
                inst[k] = v
            end
        end
    end
    
    -- Append children
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

function Library.Button(props)
    local defaultColor = props.BackgroundColor3 or Color3.fromRGB(45, 45, 45)
    local hoverColor = props.HoverColor or Color3.fromRGB(65, 65, 65)
    
    local btn = el("TextButton", {
        Name = props.Name or "Button",
        Size = props.Size or UDim2.new(1, 0, 0, 40),
        Position = props.Position,
        BackgroundColor3 = defaultColor,
        Text = props.Text or "Button",
        TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
        Font = props.Font or Enum.Font.GothamBold,
        TextSize = props.TextSize or 14,
        AutoButtonColor = false,
        CornerRadius = props.CornerRadius or UDim.new(0, 8),
        OnClick = props.OnClick
    })
    
    -- Hover animations
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = defaultColor}):Play()
    end)
    
    return btn
end

function Library.Input(props)
    local input = el("TextBox", {
        Name = props.Name or "Input",
        Size = props.Size or UDim2.new(1, 0, 0, 40),
        Position = props.Position,
        BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(25, 25, 25),
        Text = "",
        PlaceholderText = props.PlaceholderText or "Enter text...",
        TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
        PlaceholderColor3 = props.PlaceholderColor3 or Color3.fromRGB(120, 120, 120),
        Font = props.Font or Enum.Font.Gotham,
        TextSize = props.TextSize or 14,
        ClearTextOnFocus = false,
        CornerRadius = props.CornerRadius or UDim.new(0, 8),
        Stroke = props.Stroke,
        OnFocusLost = props.OnFocusLost
    })
    return input
end

-- [[ MAIN SYSTEM BUILDER ]]

function Library:CreateKeySystem(config)
    config = config or {}
    local titleText = config.Title or "RLWSCRIPTS"
    local descText = config.Description or "Please enter your key to continue."
    local mainColor = config.MainColor or Color3.fromRGB(80, 0, 255)
    local bgDark = Color3.fromRGB(15, 15, 15)
    local bgLighter = Color3.fromRGB(25, 25, 25)
    
    local screenGui = el("ScreenGui", {
        Name = "ReactLikeKeySystem",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    -- Exploit GUI Protection
    if gethui then
        screenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(screenGui)
        screenGui.Parent = CoreGui
    else
        screenGui.Parent = CoreGui
    end

    -- Declarative UI Tree (React Style)
    local mainFrame = el("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 420, 0, 280),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bgDark,
        CornerRadius = UDim.new(0, 12),
        Stroke = {Color = mainColor, Thickness = 2},
        ClipsDescendants = true
    }, {
        -- Close Button
        el("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -10, 0, 10),
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Text = "✖",
            TextColor3 = Color3.fromRGB(150, 150, 150),
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            OnClick = function()
                -- Exit Animation
                local tween = TweenService:Create(screenGui.Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
                tween:Play()
                tween.Completed:Wait()
                screenGui:Destroy()
            end
        }),
        
        -- Title
        el("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, 25),
            BackgroundTransparency = 1,
            Text = titleText,
            TextColor3 = mainColor,
            TextSize = 24,
            Font = Enum.Font.GothamBlack
        }),
        
        -- Description
        el("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 0, 60),
            BackgroundTransparency = 1,
            Text = descText,
            TextColor3 = Color3.fromRGB(150, 150, 150),
            TextSize = 14,
            Font = Enum.Font.Gotham
        }),
        
        -- Input & Buttons Container
        el("Frame", {
            Name = "Container",
            Size = UDim2.new(1, -60, 0, 160),
            Position = UDim2.new(0, 30, 0, 100),
            BackgroundTransparency = 1
        }, {
            Library.Input({
                Name = "KeyInput",
                Size = UDim2.new(1, 0, 0, 45),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = bgLighter,
                PlaceholderText = "Paste your key here...",
                CornerRadius = UDim.new(0, 8)
            }),
            
            Library.Button({
                Name = "ValidateBtn",
                Size = UDim2.new(1, 0, 0, 45),
                Position = UDim2.new(0, 0, 0, 55),
                BackgroundColor3 = mainColor,
                HoverColor = Color3.fromRGB(100, 40, 255),
                Text = "Validate & Start",
                CornerRadius = UDim.new(0, 8),
                OnClick = function()
                    local input = screenGui.Main.Container.KeyInput
                    local key = input.Text
                    if config.OnValidate then
                        local success = config.OnValidate(key)
                        if success then
                            local tween = TweenService:Create(screenGui.Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
                            tween:Play()
                            tween.Completed:Wait()
                            screenGui:Destroy()
                        else
                            input.Text = ""
                            input.PlaceholderText = "Invalid Key!"
                            input.PlaceholderColor3 = Color3.fromRGB(255, 50, 50)
                            task.wait(1.5)
                            input.PlaceholderText = "Paste your key here..."
                            input.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                        end
                    end
                end
            }),
            
            Library.Button({
                Name = "GetKeyBtn",
                Size = UDim2.new(1, 0, 0, 45),
                Position = UDim2.new(0, 0, 0, 110),
                BackgroundColor3 = bgLighter,
                HoverColor = Color3.fromRGB(35, 35, 35),
                Text = "Get Free Key (Copy URL)",
                TextColor3 = Color3.fromRGB(200, 200, 200),
                CornerRadius = UDim.new(0, 8),
                OnClick = function()
                    if config.OnGetKey then
                        config.OnGetKey()
                    end
                end
            })
        })
    })
    
    mainFrame.Parent = screenGui
    
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
            TweenService:Create(mainFrame, TweenInfo.new(0.1), {
                Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
            }):Play()
        end
    end)
    
    -- Entrance Animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 420, 0, 280)}):Play()
    
    return screenGui
end

return Library
