-- ChestFarmer.lua
-- Vault & Giant Chest farming inside rooms

local Shared = getgenv().BackroomsShared
local Utils = getgenv().BackroomsUtils

local ChestFarmer = {}

function ChestFarmer.farm(bestRoom, roomUID, bestRoomType)
    local label = bestRoomType == 2 and "🏦 Vault/Chest Odası" or "⛏️ Breakable Oda"
    local emptySeconds = 0
    local bigCheckTimer = 0
    
    while (bestRoomType == 2 and getgenv().Config.AutoFarmChests) or (bestRoomType == 1 and getgenv().Config.AutoFarmCoins) do
        task.wait(1)
        local currentKeys = Utils.getDaydreamKeyCount()
        getgenv().LiveStats.CurrentKeys = currentKeys

        local breakablesExist = false
        local foundBig = false
        local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
            
        if breakablesFolder then
            local pos = Utils.getRootPart() and Utils.getRootPart().Position or Vector3.new(0,0,0)
            for _, b in ipairs(breakablesFolder:GetChildren()) do
                local part = b:FindFirstChild("Hitbox")
                    or (b:IsA("Model") and b.PrimaryPart)
                    or b:FindFirstChildWhichIsA("BasePart")
                    
                if part and (part.Position - pos).Magnitude < 150 then
                    breakablesExist = true
                    
                    local bName = string.lower(b.Name)
                    local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                    local health = b:GetAttribute("MaxHealth") or b:GetAttribute("Health") or 0
                    
                    if health > 200 or bId:find("chest") or bId:find("vault") or bId:find("giant") or bId:find("huge") or bId:find("big") or bName:find("chest") then
                        foundBig = true
                    end
                end
            end
        end
        
        bigCheckTimer = bigCheckTimer + 1
        if bigCheckTimer == 3 and not foundBig then
            Shared.VisitedRooms[roomUID] = true
            local respawnTs = nil
            respawnTs = bestRoom:GetAttribute("RespawnTimestamp")
            
            if respawnTs and respawnTs > workspace:GetServerTimeNow() then
                if Shared.CurrentRadarTargetCoordKey then
                    Shared.DeadCoords[Shared.CurrentRadarTargetCoordKey] = respawnTs
                end
                Shared.DeadChestRooms[roomUID] = respawnTs
            end
            break
        end

        if not breakablesExist then
            emptySeconds = emptySeconds + 1
            if emptySeconds >= 4 then
                Shared.VisitedRooms[roomUID] = true
                local respawnTs = nil
                respawnTs = bestRoom:GetAttribute("RespawnTimestamp")
                
                if respawnTs and respawnTs > workspace:GetServerTimeNow() then
                    if Shared.CurrentRadarTargetCoordKey then
                        Shared.DeadCoords[Shared.CurrentRadarTargetCoordKey] = respawnTs
                    end
                    Shared.DeadChestRooms[roomUID] = respawnTs
                end
                break
            end
        else
            emptySeconds = 0
        end
    end
end

getgenv().BackroomsChestFarmer = ChestFarmer
return ChestFarmer
