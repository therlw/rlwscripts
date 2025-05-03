-- Rayfield UI Load
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "RLWSCRİPTS",
    Icon = 0, -- Lucide icon
    LoadingTitle = "Premium Fishing System",
    LoadingSubtitle = "Auto Sell, Auto Fish & Complete",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FishingAutomation",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Modules
local Network, ItemLib, Message, FishingModule, FishGame

-- Load Modules Safely
local function LoadModules()
    local success, err = pcall(function()
        Network = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Network"))
        ItemLib = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Items"):WaitForChild("CatchItem"))
        Message = require(ReplicatedStorage:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Message"))
        FishingModule = require(ReplicatedStorage.Library.Client.EventFishingCmds)
        FishGame = require(ReplicatedStorage.Library.Client.EventFishingCmds.Game)
    end)
    
    if not success then
        Rayfield:Notify({
            Title = "Module Error",
            Content = "Failed to load modules: "..tostring(err),
            Duration = 6.5,
            Actions = {
                {
                    Name = "OK",
                    Callback = function() end
                },
            },
        })
        return false
    end
    return true
end


-- Create Tabs
local AutoSellTab = Window:CreateTab("Auto Sell", "dollar-sign")
local AutoFishTab = Window:CreateTab("Auto Fish", "fish")
local AutoCompleteTab = Window:CreateTab("Auto Complete", "zap")

-- Auto Sell Section
local SellSection = AutoSellTab:CreateSection("Auto Selling Settings")

local AutoSellToggle = AutoSellTab:CreateToggle({
    Name = "Enable Auto Sell",
    CurrentValue = false,
    Flag = "AutoSellToggle",
    Callback = function(Value)
        _G.AutoSellEnabled = Value
        if Value then
            coroutine.wrap(function()
                while _G.AutoSellEnabled do
                    local allFish = {}
                    for itemId, _ in pairs(ItemLib:All()) do
                        table.insert(allFish, itemId)
                    end
                    
                    if #allFish > 0 then
                        pcall(function()
                            local result = Network.Invoke("FishingEvent_Sell", allFish)
                            Rayfield:Notify({
                                Title = "Auto Sell",
                                Content = "Sold fish for: "..tostring(result),
                                Duration = 3,
                            })
                        end)
                    end
                    task.wait(_G.SellInterval)
                end
            end)()
        end
    end
})

AutoSellTab:CreateSlider({
    Name = "Sell Interval (seconds)",
    Range = {60, 600},
    Increment = 30,
    Suffix = "s",
    CurrentValue = 240,
    Flag = "SellInterval",
    Callback = function(Value)
        _G.SellInterval = Value
    end
})

-- Auto Fish Section
local FishSection = AutoFishTab:CreateSection("Auto Fishing Settings")

local AutoFishToggle = AutoFishTab:CreateToggle({
    Name = "Enable Auto Fish",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(Value)
        _G.AutoFishEnabled = Value
        if Value then
            coroutine.wrap(function()
                while _G.AutoFishEnabled do
                    if LocalPlayer.Character then
                        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            pcall(function()
                                FishingModule.LocalCast(hrp.Position + Vector3.new(0, -2, -10))
                            end)
                        end
                    end
                    task.wait(_G.FishDelay)
                end
            end)()
        end
    end
})

AutoFishTab:CreateSlider({
    Name = "Cast Delay (seconds)",
    Range = {0.5, 3},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "FishDelay",
    Callback = function(Value)
        _G.FishDelay = Value
    end
})

-- Auto Complete Section
local CompleteSection = AutoCompleteTab:CreateSection("Auto Complete Settings")

-- Önce FishGame modülünü yükleyelim ve hook'u bir kere tanımlayalım
local FishGame
local success, err = pcall(function()
    FishGame = require(game:GetService("ReplicatedStorage").Library.Client.EventFishingCmds.Game)
    
    if not FishGame.BeginOld then
        FishGame.BeginOld = FishGame.Begin
        FishGame.Begin = function(arg1, arg2, arg3)
            if _G.AutoCompleteEnabled then
                arg2.BarSize = 1  -- Balık yakalama çubuğunu tam boy yap
            end
            return FishGame.BeginOld(arg1, arg2, arg3)
        end
    end
end)

if not success then
    warn("FishGame modülü yüklenemedi:", err)
end

local AutoCompleteToggle = AutoCompleteTab:CreateToggle({
    Name = "Enable Auto Complete",
    CurrentValue = false,
    Flag = "AutoCompleteToggle",
    Callback = function(Value)
        _G.AutoCompleteEnabled = Value
        
        if Value then
            Rayfield:Notify({
                Title = "Auto Complete",
                Content = "Balık yakalama mini oyunu otomatikleştirildi",
                Duration = 3,
            })
        end
    end
})



-- Initialize
if LoadModules() then
    Rayfield:Notify({
        Title = "System Ready",
        Content = "Fishing automation initialized successfully!",
        Duration = 3,
    })
else
    Rayfield:Destroy()
end

-- Destroy button (optional)
Window:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        Rayfield:Destroy()
    end,
})
