-- BossHunter.lua
-- Auto Boss Hunt Combat Loop & Server Hopping

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Shared = getgenv().BackroomsShared
local Utils = getgenv().BackroomsUtils
local ClientNetwork = require(ReplicatedStorage.Library.Client.Network)

local BossHunter = {}

local function getBossRoomCenter(room)
    local breakZone = room:FindFirstChild("BREAK_ZONE")
    if breakZone and breakZone:IsA("BasePart") then
        return Vector3.new(breakZone.Position.X, breakZone.Position.Y - breakZone.Size.Y / 2 + 5, breakZone.Position.Z)
    end
    return room:GetPivot().Position + Vector3.new(0, 5, 0)
end

-- Re-entry guard to prevent infinite hybrid mode loops
local function canEnterHunt(roomUID)
    local guard = Shared._bossHunterGuard
    if guard and guard.roomUID == roomUID and os.clock() - guard.time < 12 then
        return false
    end
    return true
end

local function setHuntGuard(roomUID)
    Shared._bossHunterGuard = {roomUID = roomUID, time = os.clock()}
end

-- Fire damage to any breakable (boss NPC, chest, etc.) within range
local function fireDamageToBreakable(uid)
    if ClientNetwork and ClientNetwork.UnreliableFire then
        ClientNetwork.UnreliableFire("Breakables_PlayerDealDamage", uid)
    end
end

-- Deal damage to everything in breakables folder near the target position
local function damageNearbyBreakables(rootPos, radius)
    local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if not breakablesFolder then return end
    for _, b in ipairs(breakablesFolder:GetChildren()) do
        local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
        if part and (part.Position - rootPos).Magnitude < radius then
            fireDamageToBreakable(b.Name)
        end
    end
end

function BossHunter.hunt(bestRoom, roomUID)
    if not canEnterHunt(roomUID) then return end
    setHuntGuard(roomUID)
    
    local hasNotifySpawned = false
    local bossWasAlive = true
    while getgenv().Config.AutoBossHunt do
        task.wait(1)
        
        -- Deal damage to nearby breakables while in boss room
        local root = Utils.getRootPart()
        if root then
            damageNearbyBreakables(root.Position, 250)
        end
        
        local respawnTs = nil
        respawnTs = bestRoom:GetAttribute("RespawnTimestamp")
        local now = workspace:GetServerTimeNow()
        if respawnTs and respawnTs > now then
            local remaining = math.ceil(respawnTs - now)

            local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
            local bossChestExists = false
            if breakablesFolder then
                local root = Utils.getRootPart()
                local charPos = root and root.Position or Vector3.new(0,0,0)
                for _, b in ipairs(breakablesFolder:GetChildren()) do
                    local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                    local bName = string.lower(b.Name)
                    if bId:find("bosschest") or bName:find("bosschest") or bId:find("chest") or bName:find("chest") then
                        local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
                        if part and (part.Position - charPos).Magnitude < 300 then
                            bossChestExists = true
                            break
                        end
                    end
                end
            end

            if bossChestExists then
                if getgenv().RLW_Window and not Shared.NotifiedBossChest then
                    getgenv().RLW_Window:Notify({Title = "💰 Boss Chest!", Content = "Looting the Boss Chest...", Duration = 3})
                    Shared.NotifiedBossChest = true
                end
                task.wait(1)
                continue
            end
            Shared.NotifiedBossChest = false

            if remaining > 15 and getgenv().Config.AutoFarmEggs then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "🚀 Hybrid Mode Active!", Content = "Farming eggs while waiting for Boss...", Duration = 5})
                end
                getgenv().SmartFarmState.BossRespawningUntil = respawnTs
                getgenv().SmartFarmState.BossRoomUID = roomUID
                Shared.VisitedRooms[roomUID] = true
                break
            end

            if getgenv().Config.HopOnBossCooldown then
                Utils.serverHop()
                task.wait(5)
            end

            getgenv().LiveStats.BossStatus = "Respawn: " .. tostring(remaining) .. "s ⏳"
            
            local rootC = Utils.getRootPart()
            local targetPos = getBossRoomCenter(bestRoom)
            if rootC and (rootC.Position - targetPos).Magnitude > 100 then
                Utils.safeTeleport(CFrame.new(targetPos), false)
            end
        else
            getgenv().LiveStats.BossStatus = "Fighting Boss ⚔️"
            
            local hasSpawned = bestRoom:GetAttribute("BossChestUID")
            local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
            
            -- If BossChestUID attribute is missing, visually check for the boss chest in Breakables
            if not hasSpawned and breakablesFolder then
                local pivot = bestRoom:GetPivot().Position
                for _, b in ipairs(breakablesFolder:GetChildren()) do
                    local bId = string.lower(tostring(b:GetAttribute("BreakableID") or b.Name))
                    if bId:find("bosschest") or bId:find("boss chest") or bId:find("gamemaster chest") or bId:find("masterboss chest") then
                        local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
                        if part and (part.Position - pivot).Magnitude < 800 then
                            hasSpawned = b.Name
                            break
                        end
                    end
                end
            end

            if hasSpawned and bossWasAlive then
                bossWasAlive = false
                getgenv().LiveStats.BossesKilled = (getgenv().LiveStats.BossesKilled or 0) + 1
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "💀 Boss Defeated!", Content = "Boss killed! Looting chest...", Duration = 3})
                end
            end

            if not hasSpawned then
                bossWasAlive = true
                local bossObj = nil
                for _, v in ipairs(bestRoom:GetDescendants()) do
                    if v:IsA("Model") and (v.Name:lower():find("gamemaster") or v.Name:lower():find("masterboss")) then
                        bossObj = v
                        break
                    end
                end
                
                -- Fallback: check workspace.__THINGS.Instances for the boss NPC if not inside the room model
                if not bossObj then
                    local instancesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances")
                    if instancesFolder then
                        local pivot = bestRoom:GetPivot().Position
                        for _, v in ipairs(instancesFolder:GetChildren()) do
                            if v:IsA("Model") and (v.Name:lower():find("gamemaster") or v.Name:lower():find("masterboss")) then
                                local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                                if part and (part.Position - pivot).Magnitude < 800 then
                                    bossObj = v
                                    break
                                end
                            end
                        end
                    end
                end

                -- Teleport to room center (offset by y + 5) and stay there
                local roomCenter = getBossRoomCenter(bestRoom)
                local rootC = Utils.getRootPart()
                if rootC and (rootC.Position - roomCenter).Magnitude > 15 then
                    Utils.safeTeleport(CFrame.new(roomCenter), false)
                end

                if bossObj then
                    local part = bossObj.PrimaryPart or bossObj:FindFirstChildWhichIsA("BasePart")
                    -- Fire damage directly to boss NPC if it's in breakables
                    if part then
                        local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
                        if breakablesFolder then
                            for _, b in ipairs(breakablesFolder:GetChildren()) do
                                local bPart = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
                                if bPart and (bPart.Position - part.Position).Magnitude < 30 then
                                    fireDamageToBreakable(b.Name)
                                end
                            end
                        end
                    end
                end
            else
                local targetChest = nil
                if breakablesFolder then
                    for _, b in ipairs(breakablesFolder:GetChildren()) do
                        local bUid = b:GetAttribute("BreakableUID")
                        if b.Name == tostring(hasSpawned) or (bUid and bUid == hasSpawned) or (type(hasSpawned) == "table" and table.find(hasSpawned, b.Name)) then
                            targetChest = b
                            break
                        end
                    end
                end

                -- Teleport to room center (offset by y + 5) and stay there
                local roomCenter = getBossRoomCenter(bestRoom)
                local rootC = Utils.getRootPart()
                if rootC and (rootC.Position - roomCenter).Magnitude > 15 then
                    Utils.safeTeleport(CFrame.new(roomCenter), false)
                end

                if targetChest then
                    -- Fire damage directly to the chest from the room center
                    fireDamageToBreakable(targetChest.Name)
                end
            end
            
            if not hasNotifySpawned then
                hasNotifySpawned = true
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "⚔️ Boss Fight!", Content = "Attacking the Boss...", Duration = 3})
                end
            end
        end
    end
end

getgenv().BackroomsBossHunter = BossHunter
return BossHunter
