local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Library.Client.Network)
local RunService = game:GetService("RunService")

local leverPulled = false
local doorOpened = false
local door = nil
local initialPosition = nil


local function getDoor()
    local room10 = workspace:FindFirstChild("__THINGS") and
                   workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER") and
                   workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active") and
                   workspace.__THINGS.__INSTANCE_CONTAINER.Active:FindFirstChild("LuckyRaid") and
                   workspace.__THINGS.__INSTANCE_CONTAINER.Active.LuckyRaid:FindFirstChild("Rooms") and
                   workspace.__THINGS.__INSTANCE_CONTAINER.Active.LuckyRaid.Rooms:FindFirstChild("Room10") and
                   workspace.__THINGS.__INSTANCE_CONTAINER.Active.LuckyRaid.Rooms.Room10:FindFirstChild("Door")
    return room10
end


local function isHeroic()
    local boss3 = workspace:FindFirstChild("__THINGS") and
                  workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER") and
                  workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active") and
                  workspace.__THINGS.__INSTANCE_CONTAINER.Active:FindFirstChild("LuckyRaid") and
                  workspace.__THINGS.__INSTANCE_CONTAINER.Active.LuckyRaid:FindFirstChild("Rooms") and
                  workspace.__THINGS.__INSTANCE_CONTAINER.Active.LuckyRaid.Rooms:FindFirstChild("Boss3")
    return boss3 ~= nil
end


RunService.Heartbeat:Connect(function()
    local currentDoor = getDoor()
    
    if currentDoor then
        
        if not door then
            door = currentDoor
            initialPosition = door:GetPivot()
            print("🚪 Door found, tracking position...")
        end
        
        -- Kapı hareket etti mi?
        if initialPosition and not doorOpened then
            local currentPos = door:GetPivot()
            local distance = (currentPos.Position - initialPosition.Position).Magnitude
            
            
            if distance > 1 then
                doorOpened = true
                print("🚪 Room10 door OPENED! (moved by " .. distance .. ")")
                
                
                if isHeroic() and not leverPulled then
                    print("⚡ Heroic mode detected! Waiting 0.7 seconds before pulling lever...")
                    
                    
                    task.wait(0.7)
                    
                    
                    for i = 1, 5 do
                        local success = pcall(function()
                            return Network.Invoke("LuckyRaid_PullLever", 3)
                        end)
                        if success then
                            leverPulled = true
                            print("✅ Boss3 lever pulled!")
                            break
                        end
                        task.wait(0.5)
                    end
                end
            end
        end
    else
        
        if door then
            door = nil
            initialPosition = nil
            doorOpened = false
            leverPulled = false
            print("🔄 Door gone, resetting.")
        end
    end
end)

print("🚀 Script active - Waiting for Room10 door to open...")
