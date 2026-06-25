-- Utils.lua
-- Utility and Helper Functions for Backrooms Automation

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

getgenv().BackroomsUtils = {}
local Utils = getgenv().BackroomsUtils
local Shared = getgenv().BackroomsShared

-- Compatibility mappings for external access
getgenv().DeadCoords = Shared.DeadCoords
getgenv()._EggSpawnWaitTime = Shared._EggSpawnWaitTime

function Utils.getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utils.getRootPart()
    local char = Utils.getCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

function Utils.getDaydreamKeyCount()
    local Save = require(ReplicatedStorage.Library.Client.Save)
    local saveFile = Save.Get()
    if not saveFile or not saveFile.Inventory then return 0 end

    local inventory = saveFile.Inventory
    local count = 0

    for categoryName, categoryData in pairs(inventory) do
        if type(categoryData) == "table" then
            for _, item in pairs(categoryData) do
                if type(item) == "table" and type(item.id) == "string" then
                    local idLower = string.lower(item.id)
                    local isDeepMode = getgenv().Config.DeepBackroomsMode
                    
                    if isDeepMode then
                        if idLower == "deep backrooms crayon key" or idLower == "deep daydream key" then
                            count = count + (item._am or 1)
                        end
                    else
                        if idLower == "backrooms crayon key" or idLower == "daydream key" or idLower == "backrooms key" then
                            count = count + (item._am or 1)
                        end
                    end
                end
            end
        end
    end

    return count
end

function Utils.safeTeleport(targetObj, fastMode)
    local root = Utils.getRootPart()
    if not root or not targetObj then return false end

    local initialCFrame = typeof(targetObj) == "CFrame" and targetObj
        or (targetObj:IsA("Model") and targetObj:GetPivot() or targetObj.CFrame)
    local safePosition = initialCFrame.Position + Vector3.new(0, 6, 0)

    local breakZone = nil
    if typeof(targetObj) == "Instance" then
        breakZone = targetObj:FindFirstChild("BREAK_ZONE")
    end

    if breakZone and breakZone:IsA("BasePart") then
        safePosition = Vector3.new(breakZone.Position.X, breakZone.Position.Y - breakZone.Size.Y / 2 + 5, breakZone.Position.Z)
    elseif typeof(targetObj) == "Instance" and targetObj:IsA("Model") then
        local boundingCFrame, size = targetObj:GetBoundingBox()
        safePosition = boundingCFrame.Position - Vector3.new(0, size.Y / 2, 0) + Vector3.new(0, 5, 0)
    end

    root.Anchored = true
    local setupOk = pcall(function()
        root.CFrame = CFrame.new(safePosition)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
    if not setupOk then
        root.Anchored = false
        return false
    end

    local Network = ReplicatedStorage:FindFirstChild("Network")
    if Network then
        local reqStream = Network:FindFirstChild("RequestStreaming")
        if reqStream then
            pcall(function() reqStream:FireServer(safePosition) end)
        end
    end

    local isRoom = typeof(targetObj) == "Instance" and targetObj:GetAttribute("RoomUID") ~= nil
    
    if not isRoom then
        task.wait(0.25)
        root.Anchored = false
        return true
    end

    local originalCFrame = root.CFrame
    local timeout = fastMode and 1.5 or 5
    local t = 0
    local loadedFloor = nil

    pcall(function() LocalPlayer:RequestStreamAroundAsync(safePosition, timeout) end)

    while t < timeout do
        local floorFound = false
        local priorityNames = {"Floor", "Base", "Ground", "Hitbox"}
        for _, name in ipairs(priorityNames) do
            local part = targetObj:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then
                loadedFloor = part
                floorFound = true
                break
            end
        end

        if not floorFound then
            for _, part in ipairs(targetObj:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide
                    and part.Size.X > 5 and part.Size.Z > 5 then
                    loadedFloor = part
                    floorFound = true
                    break
                end
            end
        end

        if loadedFloor then
            local exactPos
            if breakZone and breakZone:IsA("BasePart") then
                exactPos = Vector3.new(breakZone.Position.X, loadedFloor.Position.Y + (loadedFloor.Size.Y / 2) + 5, breakZone.Position.Z)
            else
                exactPos = loadedFloor.Position + Vector3.new(0, (loadedFloor.Size.Y / 2) + 5, 0)
            end
            safePosition = exactPos
            pcall(function() root.CFrame = CFrame.new(safePosition) end)
            break
        end

        task.wait(0.25)
        t = t + 0.25
    end

    if not loadedFloor then
        pcall(function() root.CFrame = originalCFrame end)
        if getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "⚠️ Teleport Failed!", Content = "Room didn't load physically! Returning to safe spot.", Duration = 3})
        end
        local roomUID = targetObj:GetAttribute("RoomUID")
        if roomUID then
            Shared.DeadEggRooms[roomUID] = os.clock()
            Shared.DeadChestRooms[roomUID] = os.clock()
        end
        task.wait(0.1)
        root.Anchored = false
        return false
    end

    task.wait(0.25)
    root.Anchored = false
    return true
end

function Utils.CollectOrbs()
    local orbs_container = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Orbs")
    if not orbs_container then return end
    local orbsToCollect = {}
    for _, orb in ipairs(orbs_container:GetChildren()) do
        local orbId = tonumber(orb.Name)
        if orbId then 
            table.insert(orbsToCollect, orbId) 
            orb:Destroy() 
        end
    end
    if #orbsToCollect > 0 then 
        local Network = ReplicatedStorage:FindFirstChild("Network")
        local remote = Network and Network:FindFirstChild("Orbs: Collect")
        if remote then 
            remote:FireServer(orbsToCollect) 
        end
    end
end

function Utils.isEggAlive(room)
    local expireTime = room:GetAttribute("EggExpireTimestamp")
    if type(expireTime) == "number" and workspace:GetServerTimeNow() > expireTime then
        return false
    end
    
    local isNear = false
    do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and (room:IsA("Model") or room:IsA("BasePart")) then
            local dist = (root.Position - room:GetPivot().Position).Magnitude
            if dist < 250 then
                isNear = true
            end
        end
    end
    
    if isNear then
        local eggUID = room:GetAttribute("EggUID")
        if type(eggUID) == "string" then
            local customEggs = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("CustomEggs")
            if customEggs then
                local eggModel = customEggs:FindFirstChild(eggUID)
                if not eggModel then
                    if not Shared._EggSpawnWaitTime[eggUID] then
                        Shared._EggSpawnWaitTime[eggUID] = os.clock()
                        return true
                    end
                    if os.clock() - Shared._EggSpawnWaitTime[eggUID] < 10 then
                        return true
                    end
                    return false
                end
                
                Shared._EggSpawnWaitTime[eggUID] = nil
                
                local actualEgg = eggModel:FindFirstChild("Egg") or eggModel:FindFirstChild("EggLock")
                if not actualEgg then
                    local hasPart = false
                    for _, v in ipairs(eggModel:GetChildren()) do
                        if v:IsA("BasePart") then
                            hasPart = true
                            break
                        end
                    end
                    if not hasPart then
                        return false
                    end
                end
            end
        end
    end
    
    return true
end

function Utils.areRoomsAdjacent(a, b)
    local touchX = (a.x + a.w == b.x) or (b.x + b.w == a.x)
    local overlapY = (a.y < b.y + b.h) and (b.y < a.y + a.h)
    
    local touchY = (a.y + a.h == b.y) or (b.y + b.h == a.y)
    local overlapX = (a.x < b.x + b.w) and (b.x < a.x + a.w)
    
    return (touchX and overlapY) or (touchY and overlapX)
end

function Utils.buildNavGraph(descriptor)
    if getgenv().NavGraph and getgenv().NavGraphDesc == descriptor then
        return getgenv().NavGraph
    end
    local graph = {}
    for i, roomA in ipairs(descriptor.rooms) do
        graph[i] = {}
        for j, roomB in ipairs(descriptor.rooms) do
            if i ~= j and Utils.areRoomsAdjacent(roomA, roomB) then
                table.insert(graph[i], j)
            end
        end
    end
    getgenv().NavGraph = graph
    getgenv().NavGraphDesc = descriptor
    return graph
end

function Utils.getRoomIndexFromPosition(pos, descriptor)
    local res = descriptor.res or 45
    local x0 = descriptor.x0 or 1
    local y0 = descriptor.y0 or 1
    local rootVec = descriptor.root or Vector3.new(0,0,0)
    
    local relX = pos.X - rootVec.X
    local relZ = pos.Z - rootVec.Z
    
    local gridX = (relX / res) - (x0 - 1)
    local gridY = (relZ / res) - (y0 - 1)
    
    local bestIdx = 1
    local bestDist = math.huge
    
    for i, room in ipairs(descriptor.rooms) do
        if gridX >= room.x and gridX <= room.x + room.w and gridY >= room.y and gridY <= room.y + room.h then
            return i
        end
        local cx = room.x + (room.w / 2)
        local cy = room.y + (room.h / 2)
        local dist = math.sqrt((gridX - cx)^2 + (gridY - cy)^2)
        if dist < bestDist then
            bestDist = dist
            bestIdx = i
        end
    end
    return bestIdx
end

function Utils.findPathAStar(startIdx, targetIdx, graph, descriptor)
    if not startIdx or not targetIdx or not descriptor.rooms[startIdx] or not descriptor.rooms[targetIdx] then return nil end
    
    local openSet = {startIdx}
    local cameFrom = {}
    local gScore = {[startIdx] = 0}
    local fScore = {}
    
    local bestNode = startIdx
    local bestHeur = math.huge
    
    local function heuristic(a, b)
        local rA = descriptor.rooms[a]
        local rB = descriptor.rooms[b]
        if not rA or not rB then return 0 end
        return math.abs((rA.x or 0) - (rB.x or 0)) + math.abs((rA.y or 0) - (rB.y or 0))
    end
    
    fScore[startIdx] = heuristic(startIdx, targetIdx)
    bestHeur = fScore[startIdx]
    
    while #openSet > 0 do
        local lowest = math.huge
        local current = nil
        local currentTableIdx = nil
        for i, node in ipairs(openSet) do
            local f = fScore[node] or math.huge
            if f < lowest then lowest = f; current = node; currentTableIdx = i end
        end
        
        local h = heuristic(current, targetIdx)
        if h < bestHeur then
            bestHeur = h
            bestNode = current
        end
        
        if current == targetIdx then
            local path = {current}
            while cameFrom[current] do
                current = cameFrom[current]
                table.insert(path, 1, current)
            end
            return path
        end
        
        table.remove(openSet, currentTableIdx)
        
        for _, neighbor in ipairs(graph[current] or {}) do
            local tentative_gScore = (gScore[current] or math.huge) + 1
            if tentative_gScore < (gScore[neighbor] or math.huge) then
                cameFrom[neighbor] = current
                gScore[neighbor] = tentative_gScore
                fScore[neighbor] = tentative_gScore + heuristic(neighbor, targetIdx)
                
                local inOpen = false
                for _, node in ipairs(openSet) do
                    if node == neighbor then inOpen = true break end
                end
                if not inOpen then table.insert(openSet, neighbor) end
            end
        end
    end
    
    if bestNode and bestNode ~= startIdx then
        local path = {bestNode}
        local curr = bestNode
        while cameFrom[curr] do
            curr = cameFrom[curr]
            table.insert(path, 1, curr)
        end
        return path
    end
    
    return nil
end

function Utils.getTargetRoomVector(roomTypeStr, altTypeStr, VisitedRooms, rooms_raw, DeadChestRooms)
    local Network = ReplicatedStorage:FindFirstChild("Network")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    if not invokeCustom then return nil end

    local modeKey = getgenv().Config.DeepBackroomsMode and "Deep" or "Normal"
    if not getgenv().MapDescriptors then getgenv().MapDescriptors = {} end
    
    local descriptor = getgenv().MapDescriptors[modeKey]
    local success = true
    if not descriptor then
        local desc = invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", getgenv().Config.DeepBackroomsMode)
        if desc then
            descriptor = desc
            getgenv().MapDescriptors[modeKey] = desc
        else
            success = false
        end
    end

    if success and descriptor and type(descriptor) == "table" and descriptor.rooms then
        local t1 = roomTypeStr and string.lower(roomTypeStr)
        local t2 = altTypeStr and string.lower(altTypeStr)
        
        local bestDeadVec = nil
        local lowestCooldown = math.huge
        
        for i, roomInfo in ipairs(descriptor.rooms) do
            local c = string.lower(roomInfo.class or "")
            if (t1 and c:find(t1)) or (t2 and c:find(t2)) then
                local isChoosingRoom = c:find("choose")
                local targetIsChoosing = (t1 and t1:find("choose")) or (t2 and t2:find("choose"))
                
                if isChoosingRoom and not targetIsChoosing then
                    continue
                end
                
                local res = descriptor.res or 45
                local x0 = descriptor.x0 or 1
                local y0 = descriptor.y0 or 1
                local rootVec = descriptor.root or Vector3.new(0,0,0)
                
                local centerGridX = roomInfo.x + (roomInfo.w / 2)
                local centerGridY = roomInfo.y + (roomInfo.h / 2)
                
                local worldX = (centerGridX + (x0 - 1)) * res + rootVec.X
                local worldZ = (centerGridY + (y0 - 1)) * res + rootVec.Z
                
                local targetY = rootVec and rootVec.Y
                if not targetY or targetY == 0 then
                    targetY = getgenv().Config.DeepBackroomsMode and 2006.05 or 1606.05
                end
                
                local targetVec = Vector3.new(worldX, targetY + 15, worldZ)
                local coordKey = string.format("%d_%d", math.floor(targetVec.X), math.floor(targetVec.Z))
                if Shared.DeadCoords[coordKey] and Shared.DeadCoords[coordKey] > workspace:GetServerTimeNow() then
                    local timeLeft = Shared.DeadCoords[coordKey] - workspace:GetServerTimeNow()
                    if timeLeft < lowestCooldown and not (getgenv().Config.DeepBackroomsMode and timeLeft > 9999999) then
                        lowestCooldown = timeLeft
                        bestDeadVec = targetVec
                    end
                    continue
                end
                
                local isVisited = false
                local isPhysicallyLoaded = false
                if rooms_raw then
                    for _, r in ipairs(rooms_raw) do
                        local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
                        if (pos - targetVec).Magnitude < 70 then
                            isPhysicallyLoaded = true
                            local uid = r:GetAttribute("RoomUID")
                            local respawnTime = r:GetAttribute("RespawnTimestamp")
                            
                            if respawnTime and respawnTime > workspace:GetServerTimeNow() then
                                Shared.DeadCoords[coordKey] = respawnTime
                                isVisited = true
                                break
                            end
                            
                            if uid and VisitedRooms and VisitedRooms[uid] then
                                local cLower = string.lower(roomInfo.class or "")
                                local isBossClass = cLower:find("gamemaster") or cLower:find("masterboss") or cLower:find("daydream") or cLower:find("deepboss") or cLower:find("boss") or cLower:find("chest") or cLower:find("vault")
                                
                                if not isBossClass then
                                    if not DeadChestRooms or not DeadChestRooms[uid] or DeadChestRooms[uid] > workspace:GetServerTimeNow() then
                                        isVisited = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                if not isVisited then
                    Shared.CurrentRadarTargetCoordKey = coordKey
                    if not isPhysicallyLoaded then
                        local currentRoot = Utils.getRootPart()
                        local currentPos = currentRoot and currentRoot.Position or Vector3.zero
                        
                        local startIdx = Utils.getRoomIndexFromPosition(currentPos, descriptor)
                        local targetIdx = i
                        local graph = Utils.buildNavGraph(descriptor)
                        local path = Utils.findPathAStar(startIdx, targetIdx, graph, descriptor)
                        
                        if path and #path > 1 then
                            local bestEdgeVec = nil
                            for k = #path, 2, -1 do
                                local pIdx = path[k]
                                local pRoom = descriptor.rooms[pIdx]
                                local pWorldX = descriptor.root.X + (pRoom.x - 1 + descriptor.x0) * descriptor.res
                                local pWorldZ = descriptor.root.Z + (pRoom.y - 1 + descriptor.y0) * descriptor.res
                                local pVec = Vector3.new(pWorldX, targetY + 15, pWorldZ)
                                
                                local isLoaded = false
                                local loadedPos = nil
                                if rooms_raw then
                                    for _, physR in ipairs(rooms_raw) do
                                        local physPos = physR:IsA("Model") and physR:GetPivot().Position or (physR:IsA("BasePart") and physR.Position or Vector3.zero)
                                        if (physPos - pVec).Magnitude < 70 then
                                            if physR:GetAttribute("RoomUID") then
                                                isLoaded = true
                                                loadedPos = physPos
                                            end
                                            break
                                        end
                                    end
                                end
                                
                                if isLoaded then
                                    if (loadedPos - currentPos).Magnitude > 30 then
                                        bestEdgeVec = Vector3.new(loadedPos.X, targetY + 15, loadedPos.Z)
                                    end
                                    break
                                end
                            end
                            
                            if bestEdgeVec then
                                return bestEdgeVec, nil, nil, true
                            else
                                return targetVec, nil, nil, false, true
                            end
                        end
                        
                        return targetVec, nil, nil, false, true
                    end
                    return targetVec, nil, nil, false
                end
            end
        end
        
        if bestDeadVec then
            return nil, bestDeadVec, lowestCooldown, false
        end
    end
    
    return nil, nil, nil, false
end

function Utils.getMapDescriptor()
    local Network = ReplicatedStorage:FindFirstChild("Network")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    if not invokeCustom then return nil end

    local modeKey = getgenv().Config.DeepBackroomsMode and "Deep" or "Normal"
    if not getgenv().MapDescriptors then getgenv().MapDescriptors = {} end
    
    local descriptor = getgenv().MapDescriptors[modeKey]
    if not descriptor then
        local desc = invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", getgenv().Config.DeepBackroomsMode)
        if desc then
            descriptor = desc
            getgenv().MapDescriptors[modeKey] = desc
        end
    end
    return descriptor
end

function Utils.IsInBackroomsInstance()
    local container = workspace:FindFirstChild("__THINGS")
    if container then
        local instanceContainer = container:FindFirstChild("__INSTANCE_CONTAINER")
        if instanceContainer and instanceContainer:FindFirstChild("Active") then
            return instanceContainer.Active:FindFirstChild("Backrooms") ~= nil
        end
    end
    return false
end

function Utils.HandleInstanceEntry()
    if Utils.IsInBackroomsInstance() then return end
    if os.clock() - Shared.LastInstanceJoinAttempt < 60 then return end
    Shared.LastInstanceJoinAttempt = os.clock()
    
    getgenv().SmartFarmState.EggRoomUID = nil
    getgenv().SmartFarmState.BossRoomUID = nil
    getgenv().SmartFarmState.BossRespawningUntil = 0
    
    if getgenv().RLW_Window then
        getgenv().RLW_Window:Notify({Title = "🚀 Backrooms", Content = "Auto-joining Backrooms...", Duration = 5})
    end

    do
        local InstancingCmds = require(ReplicatedStorage.Library.Client.InstancingCmds)
        if InstancingCmds and InstancingCmds.Enter then
            InstancingCmds.Enter("Backrooms")
        else
            local Network = ReplicatedStorage:WaitForChild("Network", 10)
            local enterInstance = Network and Network:WaitForChild("Instancing_PlayerEnterInstance", 10)
            if enterInstance then
                enterInstance:InvokeServer("Backrooms")
            end
        end
    end
    task.wait(5)
end

function Utils.isBossRoom(r)
    local roomID = string.lower(r:GetAttribute("RoomID") or "")
    local bossChestAttr = r:GetAttribute("BossChestUID")
    return roomID:find("gamemaster") or roomID:find("masterboss") or roomID:find("bosschest") or bossChestAttr
end

function Utils.unlockDoors(room, roomUID)
    local LockedDoors = room:FindFirstChild("LockedDoors")
    if not LockedDoors then return true end

    local Network = ReplicatedStorage:FindFirstChild("Network")
    local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    
    if not fireCustom then return false end


    -- Normal Mode Unlock (uses lock position verification)
    local targetLockPart = nil
    for _, door in ipairs(LockedDoors:GetChildren()) do
        local lock = door:FindFirstChild("Lock")
        if lock then
            if lock:IsA("BasePart") then
                targetLockPart = lock
            elseif lock:IsA("Model") and lock.PrimaryPart then
                targetLockPart = lock.PrimaryPart
            end
            if targetLockPart then break end
        end
    end

    local root = Utils.getRootPart()
    if targetLockPart and root then
        local originalPos = root.CFrame
        root.Anchored = true
        local setupOk = pcall(function() root.CFrame = targetLockPart.CFrame end)
        if not setupOk then
            root.Anchored = false
            return false
        end
        task.wait(1.5) -- Wait for server to register position
        
        local lastSend = 0
        local unlockTimeout = os.clock() + 30 -- Limit try to 30 seconds
        while os.clock() < unlockTimeout do
            if not room:FindFirstChild("LockedDoors") then break end
            if not targetLockPart.Parent then break end
            if targetLockPart.Transparency >= 0.99 then break end
            
            pcall(function() root.CFrame = targetLockPart.CFrame end)
            
            if targetLockPart.Transparency <= 0.05 then
                if os.clock() - lastSend >= 5 then
                    pcall(function() fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", tonumber(roomUID), "UnlockDoors") end)
                    lastSend = os.clock()
                    if getgenv().RLW_Window then
                        getgenv().RLW_Window:Notify({Title = "🔑 Unlocking...", Content = "Waiting for key...", Duration = 3})
                    end
                end
            else
                if getgenv().RLW_Window and os.clock() - lastSend >= 5 then
                    getgenv().RLW_Window:Notify({Title = "⏳ Opening...", Content = "Door is opening, please wait...", Duration = 3})
                    lastSend = os.clock()
                end
            end
            task.wait(0.2)
        end
        root.Anchored = false
        task.wait(0.5)
    else
        local lastSend = 0
        local unlockTimeout = os.clock() + 30
        while os.clock() < unlockTimeout do
            if not room:FindFirstChild("LockedDoors") then break end
            if os.clock() - lastSend >= 5 then
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", tonumber(roomUID), "UnlockDoors")
                lastSend = os.clock()
            end
            task.wait(0.2)
        end
    end
    
    return not room:FindFirstChild("LockedDoors")
end

function Utils.debugMessage(text, color)
    warn("[BOT-HOP] " .. tostring(text))
    pcall(function()
        local window = getgenv().RLW_Window
        if window and window.Notify then
            window:Notify({
                Title = "🚀 Server Hop",
                Content = tostring(text),
                Duration = 6
            })
        end
    end)
    pcall(function()
        local rprint = rconsoleprint or consoleprint or printconsole
        if rprint then
            rprint("[BOT-HOP] " .. tostring(text) .. "\n")
        end
    end)
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "[BOT-HOP] " .. tostring(text),
            Color = color or Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.SourceSansBold,
            FontSize = Enum.FontSize.Size18
        })
    end)
end

function Utils.serverHop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local req = request or http_request or (syn and syn.request)
    
    local function debugMessage(text, color)
        Utils.debugMessage(text, color)
    end

    if getgenv().RLW_Window then
        getgenv().RLW_Window:Notify({Title = "🚀 Server Hopping", Content = "Searching for a different server...", Duration = 5})
    end
    getgenv().MapDescriptors = nil
    
    -- In-memory session tracking fallback
    if not Shared.VisitedServersList then
        Shared.VisitedServersList = {}
    end
    
    local AllIDs = {}
    local actualHour = os.date("!*t").hour
    
    local fileReadOk, fileContent = pcall(function()
        if isfile and isfile("server-hop-temp.json") then
            return readfile("server-hop-temp.json")
        end
    end)
    
    if fileReadOk and fileContent then
        pcall(function()
            AllIDs = HttpService:JSONDecode(fileContent)
        end)
    end
    
    if type(AllIDs) == "table" and #AllIDs > 0 then
        local firstElement = AllIDs[1]
        if tonumber(actualHour) ~= tonumber(firstElement) then
            AllIDs = {}
            Shared.VisitedServersList = {}
            pcall(function() if delfile then delfile("server-hop-temp.json") end end)
        end
    end
    
    if type(AllIDs) ~= "table" or #AllIDs == 0 then
        AllIDs = {actualHour}
    end
    
    local currentJobId = tostring(game.JobId)
    if currentJobId ~= "" and currentJobId ~= "nil" then
        local foundCurrent = false
        for idx, id in ipairs(AllIDs) do
            if idx > 1 and tostring(id) == currentJobId then
                foundCurrent = true
                break
            end
        end
        if not foundCurrent then
            table.insert(AllIDs, currentJobId)
            pcall(function()
                if writefile then
                    writefile("server-hop-temp.json", HttpService:JSONEncode(AllIDs))
                end
            end)
        end
        if not table.find(Shared.VisitedServersList, currentJobId) then
            table.insert(Shared.VisitedServersList, currentJobId)
        end
    end
    
    debugMessage("Yeni sunucu araniyor... Kara listedeki sunucu sayisi: " .. tostring(#AllIDs - 1), Color3.fromRGB(255, 255, 100))
    
    local placeId = game.PlaceId
    local foundAnything = ""
    local siteData = nil
    
    -- Cache buster parameter
    local cacheBuster = tostring(math.random(1, 999999))
    
    for attempt = 1, 3 do
        local url = "https://games.roproxy.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100&cb=" .. cacheBuster
        if foundAnything ~= "" then
            url = url .. "&cursor=" .. foundAnything .. "&cb=" .. cacheBuster
        end
        
        local ok, body = pcall(function()
            if req then
                local res = req({Url = url})
                return res and res.Body
            else
                return game:HttpGet(url)
            end
        end)
        
        if not ok then
            debugMessage("HTTP hatasi (Deneme " .. attempt .. "): " .. tostring(body), Color3.fromRGB(255, 100, 100))
        end
        
        if ok and body then
            local ok2, decoded = pcall(function() return HttpService:JSONDecode(body) end)
            if ok2 and decoded and decoded.data then
                siteData = decoded
                if decoded.nextPageCursor and decoded.nextPageCursor ~= "null" and decoded.nextPageCursor ~= nil then
                    foundAnything = decoded.nextPageCursor
                else
                    foundAnything = ""
                end
                
                for _, v in ipairs(siteData.data) do
                    if type(v) == "table" and v.id and v.playing and v.maxPlayers then
                        local serverId = tostring(v.id)
                        
                        if serverId ~= currentJobId and serverId ~= "" then
                            local alreadyVisited = false
                            for idx, existingId in ipairs(AllIDs) do
                                if idx > 1 and tostring(existingId) == serverId then
                                    alreadyVisited = true
                                    break
                                end
                            end
                            
                            if not alreadyVisited then
                                if table.find(Shared.VisitedServersList, serverId) then
                                    alreadyVisited = true
                                end
                            end
                            
                            if not alreadyVisited and tonumber(v.playing) < tonumber(v.maxPlayers) then
                                table.insert(AllIDs, serverId)
                                table.insert(Shared.VisitedServersList, serverId)
                                pcall(function()
                                    if writefile then
                                        writefile("server-hop-temp.json", HttpService:JSONEncode(AllIDs))
                                    end
                                end)
                                
                                debugMessage("Hedef sunucu bulundu! Oyuncu: " .. tostring(v.playing) .. "/" .. tostring(v.maxPlayers) .. " | Baglaniliyor...", Color3.fromRGB(100, 255, 100))
                                
                                local teleOk = pcall(function()
                                    TeleportService:TeleportToPlaceInstance(placeId, v.id, LocalPlayer)
                                end)
                                if teleOk then
                                    task.wait(10)
                                    -- If we are still here after 10s, it means the teleport failed!
                                    debugMessage("Teleport basarisiz oldu veya askida kaldi. Diger sunucu deneniyor...", Color3.fromRGB(255, 150, 100))
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if foundAnything == "" then
            break
        end
    end
    
    debugMessage("Uygun sunucu bulunamadi veya HTTP hatasi olustu. Varsayilan matchmaking ile baglaniliyor...", Color3.fromRGB(255, 80, 80))
    local teleOk = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
    if teleOk then
        task.wait(5)
    end
end

pcall(function()
    local TeleportService = game:GetService("TeleportService")
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
        Utils.debugMessage("⚠️ Işınlanma Başarısız! Sebep: " .. tostring(teleportResult.Name or teleportResult) .. " - " .. tostring(errorMessage), Color3.fromRGB(255, 80, 80))
    end)
end)

return Utils
