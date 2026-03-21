local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = require(ReplicatedStorage.Library.Client.Network)

local wantMythic = true 
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "PS99 Auto Levers",
    Icon = 0,
    LoadingTitle = "Auto Levers Loading...",
    LoadingSubtitle = "by RLW",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = { 
        Enabled = true,
        FolderName = "PS99_AutoRaid_Configs",
        FileName = "LeverConfig"
    },
    KeySystem = false
})

local Tab = Window:CreateTab("Settings", 4483362458)
Tab:CreateSection("Raid Settings")

local HeroicToggle
local MythicToggle

HeroicToggle = Tab:CreateToggle({
    Name = "Heroic Mode (Pull 1 Time)",
    CurrentValue = false,
    Flag = "HeroicToggle",
    Callback = function(Value)
        if Value then
            wantMythic = false
            if MythicToggle then 
                MythicToggle:Set(false) 
            end
        else
            if not wantMythic and MythicToggle then 
                MythicToggle:Set(true) 
            end
        end
    end,
})

MythicToggle = Tab:CreateToggle({
    Name = "Mythic Mode (Pull 2 Times)",
    CurrentValue = true,
    Flag = "MythicToggle",
    Callback = function(Value)
        if Value then
            wantMythic = true
            if HeroicToggle then 
                HeroicToggle:Set(false) 
            end
        else
            if wantMythic and HeroicToggle then 
                HeroicToggle:Set(true) 
            end
        end
    end,
})

Rayfield:LoadConfiguration()

local pulledLevers = { Boss3 = 0, Boss2 = 0, Boss1 = 0 }
local leverOrder = { 3, 2, 1 }
local room10Opened = false
local door = nil
local startPos = nil
local isPulling = false

local function getRaid()
    local things = workspace:FindFirstChild("__THINGS")
    local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
    local active = container and container:FindFirstChild("Active")
    return active and active:FindFirstChild("LuckyRaid")
end

local function getDoor()
    local raid = getRaid()
    if raid and raid.Rooms:FindFirstChild("Room10") then
        return raid.Rooms.Room10:FindFirstChild("Door")
    end
    return nil
end

local function checkHeroic()
    local raid = getRaid()
    return raid and raid.Rooms:FindFirstChild("Boss3") ~= nil
end

local function pullLever(bossNumber)
    local leverName = "Boss" .. bossNumber
    local targetPulls = wantMythic and 2 or 1
    
    if pulledLevers[leverName] >= targetPulls then return true end
    
    print("🔧 Pulling " .. leverName .. " lever... (Target: " .. targetPulls .. " times)")
    
    while pulledLevers[leverName] < targetPulls do
        local successForThisPull = false
        for i = 1, 5 do
            local ok = pcall(function()
                return Network.Invoke("LuckyRaid_PullLever", bossNumber)
            end)
            
            if ok then
                pulledLevers[leverName] = pulledLevers[leverName] + 1
                print("✅ " .. leverName .. " lever pulled successfully! (" .. pulledLevers[leverName] .. "/" .. targetPulls .. ")")
                successForThisPull = true
                break
            else
                warn("❌ " .. leverName .. " lever failed, retrying... (" .. i .. "/5)")
            end
            task.wait(0.2)
        end
        
        if not successForThisPull then
            return false
        end
        
        if pulledLevers[leverName] < targetPulls then
            task.wait(0.1)
        end
    end
    
    return true
end

local function pullAllLeversInOrder()
    if isPulling then return end
    isPulling = true
    
    if not checkHeroic() then
        print("Not heroic mode, skipping levers.")
        isPulling = false
        return
    end
    
    print("⚡ Heroic mode detected! Pulling levers in MULTI-THREAD INSTANTLY!")
    
    for _, bossNumber in ipairs(leverOrder) do
        task.spawn(function()
            pullLever(bossNumber)
        end)
    end
    
    print("🎉 All heroic levers trigger sequence started!")
    isPulling = false
end

print("Raid monitor started, waiting for Room10 door to open...")

RunService.Heartbeat:Connect(function()
    local targetDoor = getDoor()
    
    if targetDoor then
        if not door then
            door = targetDoor
            startPos = door:GetPivot()
            print("🚪 Room10 door found, tracking movement.")
        end
        
        if startPos and not room10Opened then
            local currentPos = door:GetPivot()
            if (currentPos.Position - startPos.Position).Magnitude > 1 then
                room10Opened = true
                print("🚪 Room10 door opened!")
                task.spawn(pullAllLeversInOrder)
            end
        end
    else
        if door then
            door = nil
            startPos = nil
            room10Opened = false
            isPulling = false
            for k in pairs(pulledLevers) do
                pulledLevers[k] = 0
            end
            print("🔄 Raid ended, resetting.")
        end
    end
end)
