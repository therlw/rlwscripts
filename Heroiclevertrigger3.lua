local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = require(ReplicatedStorage.Library.Client.Network)

local pulledLevers = {
    Boss3 = false,
    Boss2 = false,
    Boss1 = false
}

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
    if pulledLevers[leverName] then return true end
    
    print("🔧 Pulling " .. leverName .. " lever...")
    
    for i = 1, 5 do
        local ok = pcall(function()
            return Network.Invoke("LuckyRaid_PullLever", bossNumber)
        end)
        
        if ok then
            pulledLevers[leverName] = true
            print("✅ " .. leverName .. " lever pulled successfully!")
            return true
        else
            warn("❌ " .. leverName .. " lever failed, retrying... (" .. i .. "/5)")
        end
        task.wait(0.5)
    end
    return false
end

local function pullAllLeversInOrder()
    if isPulling then return end
    isPulling = true
    
    if not checkHeroic() then
        print("Not heroic mode, skipping levers.")
        isPulling = false
        return
    end
    
    print("⚡ Heroic mode detected! Pulling levers in order: Boss3 → Boss2 → Boss1")
    task.wait(0.7)
    
    
    for _, bossNumber in ipairs(leverOrder) do
        task.spawn(function()
            pullLever(bossNumber)
        end)
        
    end
    
    print("🎉 All heroic levers triggered!")
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
                pulledLevers[k] = false
            end
            print("🔄 Raid ended, resetting.")
        end
    end
end)
