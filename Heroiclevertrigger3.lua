local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = require(ReplicatedStorage.Library.Client.Network)

local pulled = false
local opened = false
local door = nil
local startPos = nil

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

local function handleLever()
    if pulled then return end
    pulled = true
    
    print("Heroic mode detected, pulling lever in 0.7s...")
    task.wait(0.7)
    
    for i = 1, 5 do
        local ok = pcall(function()
            return Network.Invoke("LuckyRaid_PullLever", 3)
        end)
        
        if ok then
            print("Lever pulled successfully! (Attempt: " .. i .. ")")
            break
        else
            warn("Lever pull failed, retrying... (" .. i .. "/5)")
        end
        task.wait(0.5)
    end
end

print("Raid monitor started, waiting for door...")

RunService.Heartbeat:Connect(function()
    local targetDoor = getDoor()
    
    if targetDoor then
        if not door then
            door = targetDoor
            startPos = door:GetPivot()
            print("Door found, monitoring movement.")
        end
        
        if startPos and not opened then
            local currentPos = door:GetPivot()
            if (currentPos.Position - startPos.Position).Magnitude > 1 then
                opened = true
                print("Door opened! Checking conditions...")
                
                if checkHeroic() then
                    task.spawn(handleLever)
                else
                    print("Not heroic mode, skipping lever.")
                end
            end
        end
    else
        if door then
            door = nil
            startPos = nil
            opened = false
            pulled = false
            print("Raid ended or door removed, resetting state.")
        end
    end
end)
