-- Explorer.lua
-- Map exploration, room traversal, A* scanning, and generic room solvers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Shared = getgenv().BackroomsShared
local Utils = getgenv().BackroomsUtils

local Explorer = {}

function Explorer.explore(rooms, radarFoundBoss)
    -- Explore Mode: Expand map (teleport to furthest room)
    local sortedRooms = {}
    local isEggSearchMode = getgenv().Config.AutoFarmEggs
    for _, room in ipairs(rooms) do
        local uid = room:GetAttribute("RoomUID")
        if not Shared.VisitedRooms[uid] then
            if isEggSearchMode and Shared.DeadEggRooms[uid] and (os.clock() - Shared.DeadEggRooms[uid]) < Shared.DEAD_EGG_COOLDOWN then
                continue
            end
            local pos = room:IsA("Model") and room:GetPivot().Position or Vector3.new(0,0,0)
            local charPos = Utils.getRootPart() and Utils.getRootPart().Position or Vector3.zero
            table.insert(sortedRooms, {Room = room, Dist = (pos - charPos).Magnitude, UID = uid})
        end
    end

    table.sort(sortedRooms, function(a, b) return a.Dist > b.Dist end)

    if #sortedRooms == 0 then
        local isMinimapFull = false
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and pGui:FindFirstChild("BackroomsMiniMap") then
            local miniMapFrame = pGui.BackroomsMiniMap:FindFirstChild("MiniMap")
            if miniMapFrame then
                for _, c in ipairs(miniMapFrame:GetChildren()) do
                    if c:IsA("TextLabel") and c.Text:find("Rooms found:") then
                        local f, t = c.Text:match("Rooms found: (%d+) / (%d+)")
                        if f and t then
                            local ratio = tonumber(f) / tonumber(t)
                            if tonumber(f) >= tonumber(t) or ratio >= 0.95 then
                                  isMinimapFull = true
                            end
                        end
                    end
                end
            end
        else
            isMinimapFull = true
        end

        if isMinimapFull then
            if getgenv().Config.ExploreMapFirst then
                getgenv().Config.ExploreMapFirst = false
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "✅ Map Fully Explored!", Content = "Exploration complete. Resuming farm!", Duration = 5})
                end
            end
            
            if Shared.visitedCount > 300 and getgenv().Config.HopOnBossCooldown then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "🚀 Dead Server!", Content = "Map fully explored. Hopping servers...", Duration = 5})
                end
                Utils.serverHop()
                task.wait(5)
            end
        else
            if getgenv().RLW_Window and getgenv().Config.ExploreMapFirst then
                getgenv().RLW_Window:Notify({Title = "🔍 Scanning...", Content = "Minimap not full yet. Re-scanning physical rooms!", Duration = 3})
            end
        end
        
        Shared.VisitedRooms = {}
        Shared.visitedCount = 0
        if getgenv().Config.AutoFarmEggs then
            Shared.DeadEggRooms = {}
            Shared._EggSpawnWaitTime = {}
            task.wait(3)
        else
            task.wait(1)
        end
        return
    end

    local isSearchingOnly = getgenv().Config.AutoBossHunt or getgenv().Config.AutoFarmEggs

    local roomData = sortedRooms[1]
    local room = roomData.Room
    local roomUID = roomData.UID
    
    Utils.safeTeleport(room, true)
    task.wait(0.25)
    
    local edgeParts = {}
    local namesToFind = {"door", "exit", "entrance", "portal", "hallway", "corridor"}
    for _, part in ipairs(room:GetDescendants()) do
        if part:IsA("BasePart") then
            local pName = string.lower(part.Name)
            for _, n in ipairs(namesToFind) do
                if pName:find(n) then
                    table.insert(edgeParts, part)
                    break
                end
            end
        end
    end
    
    if #edgeParts > 0 then
        for i = 1, math.min(5, #edgeParts) do
            Utils.safeTeleport(edgeParts[i], true)
            task.wait(0.65)
        end
    elseif room:IsA("Model") then
        local pivot = room:GetPivot()
        local size = room:GetExtentsSize()
        local halfX, halfZ = size.X / 2, size.Z / 2
        
        local offsets = {
            Vector3.new(halfX, 0, 0),
            Vector3.new(-halfX, 0, 0),
            Vector3.new(0, 0, halfZ),
            Vector3.new(0, 0, -halfZ)
        }
        
        for _, offset in ipairs(offsets) do
            local root = Utils.getRootPart()
            if root then
                root.CFrame = pivot * CFrame.new(offset)
                task.wait(0.15)
            end
        end
    end
    
    local teleportSuccess = Utils.safeTeleport(room, isSearchingOnly)
    if teleportSuccess == false then
        return
    end

    local roomID = room:GetAttribute("RoomID") or ""
    local lowerID = string.lower(roomID)

    local Network = ReplicatedStorage:FindFirstChild("Network")
    local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")

    if fireCustom then
        if room:FindFirstChild("LockedDoors") then
            local isBossRoom = Utils.isBossRoom(room)
            local isEggRoom = lowerID:find("titanicegg") or lowerID:find("hugeegg") or lowerID:find("egg") or lowerID:find("keepout")
            local shouldUnlock = false

            if getgenv().Config.AutoBossHunt and isBossRoom then
                shouldUnlock = true
            elseif getgenv().Config.AutoFarmEggs and isEggRoom then
                shouldUnlock = true
            elseif getgenv().Config.AutoBossHunt and not radarFoundBoss then
                shouldUnlock = true
            end

            if shouldUnlock then
                Utils.unlockDoors(room, roomUID)
                Utils.safeTeleport(room, isSearchingOnly)
            end
        end

        if lowerID:find("chestchoose") then
            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "PickChest", 1)
        end

        local buttons = room:FindFirstChild("Buttons")
        if buttons then
            for _, btn in ipairs(buttons:GetChildren()) do
                local num = tonumber(btn.Name) or tonumber(string.match(btn.Name, "%d+"))
                if num then
                    fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", num)
                end
            end
            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed")
        end

        local levers = room:FindFirstChild("Levers")
        if levers then
            for _, lever in ipairs(levers:GetChildren()) do
                local num = tonumber(lever.Name) or tonumber(string.match(lever.Name, "%d+"))
                if num then
                    fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "FlipLever", num)
                end
            end
        end

        local faucets = room:FindFirstChild("Faucets")
        if faucets then
            for _, faucet in ipairs(faucets:GetChildren()) do
                local num = tonumber(faucet.Name) or tonumber(string.match(faucet.Name, "%d+"))
                if num then
                    fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "FaucetTurned", num)
                end
            end
        end
    end

    if getgenv().Config.AutoLoot and invokeCustom then
        for _, obj in ipairs(room:GetDescendants()) do
            if obj.Name:find("RandomReward") and obj:IsA("Model") then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    Utils.safeTeleport(part, false)
                    task.wait(0.2)
                    invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ClaimRandomReward", obj)
                end
            end
        end
    end

    for _, prompt in ipairs(room:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local parentPart = prompt.Parent
            if parentPart and parentPart:IsA("BasePart") then
                Utils.safeTeleport(parentPart, false)
                task.wait(0.1)
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.1)
                    prompt:InputHoldEnd()
                end
            end
        end
    end

    if not Shared.VisitedRooms[roomUID] then
        Shared.VisitedRooms[roomUID] = true
        Shared.visitedCount = Shared.visitedCount + 1
    end

    if Shared.visitedCount > 500 then
        Shared.VisitedRooms = {}
        Shared.visitedCount = 0
    end
end

getgenv().BackroomsExplorer = Explorer
return Explorer
