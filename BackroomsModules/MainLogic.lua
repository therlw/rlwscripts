-- MainLogic.lua
-- Backrooms Automation Main Coordinator Loop

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Utils = getgenv().BackroomsUtils
local Shared = getgenv().BackroomsShared

local LastInstanceJoinAttempt = 0

task.spawn(function()
    while task.wait(0.2) do
        -- GodMode Toggle
        if getgenv().Config.GodMode then
            _G.BACKROOMS_GODMODE = true
            if getrenv then getrenv()._G.BACKROOMS_GODMODE = true end
        else
            _G.BACKROOMS_GODMODE = false
            if getrenv then getrenv()._G.BACKROOMS_GODMODE = false end
        end

        local root = Utils.getRootPart()
        if not root then continue end

        if not (getgenv().Config.AutoBossHunt or getgenv().Config.AutoFarmChests or getgenv().Config.AutoFarmEvents or getgenv().Config.AutoFarmEggs or getgenv().Config.AutoFarmCoins) then
            continue
        end

        Utils.HandleInstanceEntry()

        local charPos = root.Position

        -- Deep entry check (performed before room scanning so we don't skip it when targetDeep filter leaves rooms_raw empty)
        if getgenv().Config.DeepBackroomsMode then
            local inDeep = false
            
            -- Safeguard the Signal Invoke call from crashing/yielding forever
            local signalOk, signal = pcall(function()
                return require(ReplicatedStorage.Library.Signal)
            end)
            if signalOk and signal and signal.Invoke then
                local invokeOk, invokeRes = pcall(function()
                    return signal.Invoke("Backrooms_IsInDeep")
                end)
                if invokeOk then
                    inDeep = invokeRes
                end
            end
            
            -- Fallback Y-coordinate check (Deep Backrooms Y is ~2006, Normal is ~1606)
            if not inDeep and root.Position.Y > 1800 then
                inDeep = true
            end
            
            if not inDeep then
                local curtain = CollectionService:GetTagged("DeepCurtainTarget")[1]
                if curtain then
                    local distToCurtain = (charPos - curtain.Position).Magnitude
                    if distToCurtain < 10000 then
                        local Network = ReplicatedStorage:FindFirstChild("Network")
                        local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                        if invokeCustom then
                            do
                                invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", 1, "UnlockDeep")
                                task.wait(1)
                                invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", true)
                            end
                        end
                        
                        if getgenv().RLW_Window then
                            getgenv().RLW_Window:Notify({Title = "🌌 Deep Entry!", Content = "Entering Deep Backrooms...", Duration = 3})
                        end
                        
                        local char = LocalPlayer.Character
                        if char then
                            local ff = Instance.new("ForceField")
                            ff.Visible = false
                            ff.Parent = char
                            task.delay(5, function() if ff then ff:Destroy() end end)
                        end
                        
                        Utils.safeTeleport(curtain, true)
                        task.wait(0.5)
                        
                        local currentRoot = Utils.getRootPart()
                        if currentRoot then
                            if firetouchinterest then
                                firetouchinterest(currentRoot, curtain, 0)
                                task.wait(0.1)
                                firetouchinterest(currentRoot, curtain, 1)
                            end
                            do
                                currentRoot.CFrame = curtain.CFrame * CFrame.new(0, 0, 5)
                                task.wait(0.2)
                                currentRoot.AssemblyLinearVelocity = curtain.CFrame.LookVector * -100
                            end
                        end
                        
                        task.wait(3)
                        continue
                    end
                end
            end
        end

        local currentKeys = Utils.getDaydreamKeyCount()
        local rooms_raw = {}
        for _, r in ipairs(CollectionService:GetTagged("Backrooms")) do
            local isDeep = r:GetAttribute("DeepRoom") == true
            local targetDeep = getgenv().Config.DeepBackroomsMode == true
            if isDeep == targetDeep then
                table.insert(rooms_raw, r)
            end
        end
        
        -- If player is inside an already open boss room, don't run away for keys
        local inOpenBossRoom = false
        local openBossRoomRef = nil
        for _, r in ipairs(rooms_raw) do
            local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
            if (pos - charPos).Magnitude < 500 then
                if Utils.isBossRoom(r) and not r:FindFirstChild("LockedDoors") then
                    local respawnTime = r:GetAttribute("RespawnTimestamp")
                    local hasLoot = r:GetAttribute("BossChestUID") or r:GetAttribute("ActiveMinichests")
                    local isCooldown = respawnTime and respawnTime > workspace:GetServerTimeNow() and not hasLoot
                    
                    if not isCooldown then
                        inOpenBossRoom = true
                        openBossRoomRef = r
                        break
                    end
                end
            end
        end

        if inOpenBossRoom and openBossRoomRef and getgenv().Config.AutoBossHunt then
            getgenv().LiveStats.BossStatus = "Fighting Boss ⚔️"
            -- Don't idle or skip the loop; let combat flow continue naturally.
            -- inBossArena check below prevents radar teleport away,
            -- and room selection will re-call BossHunter if needed.
        end

        if #rooms_raw == 0 then
            Shared.VisitedRooms = {}
            task.wait(1)
            continue
        end

        -- Filter rooms for current height
        local rooms = {}
        for _, r in ipairs(rooms_raw) do
            local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
            local yDiff = math.abs(pos.Y - charPos.Y)
            if yDiff < 500 and (pos - charPos).Magnitude < 20000 then
                table.insert(rooms, r)
            end
        end

        if #rooms == 0 then
            task.wait(1)
            continue
        end

        local bestRoom = nil
        local bestRoomType = 0
        
        local forceExplore = false
        if getgenv().Config.ExploreMapFirst then
            forceExplore = true
        end

        local roomsFolderRadar = nil
        local activeBackrooms = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER") 
            and workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active") 
            and workspace.__THINGS.__INSTANCE_CONTAINER.Active:FindFirstChild("Backrooms")
        if activeBackrooms and activeBackrooms:FindFirstChild("GeneratedBackrooms") then
            roomsFolderRadar = activeBackrooms.GeneratedBackrooms
        elseif workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Instances") then
            roomsFolderRadar = workspace.__THINGS.Instances
        end

        local inBossArena = false
        local currentRoot = Utils.getRootPart()
        local charPosRadar = currentRoot and currentRoot.Position or Vector3.new(0,0,0)
        for _, r in ipairs(rooms_raw) do
            local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
            if (pos - charPosRadar).Magnitude < 800 then
                if Utils.isBossRoom(r) then
                    local respawnTime = r:GetAttribute("RespawnTimestamp")
                    local hasLoot = r:GetAttribute("BossChestUID") or r:GetAttribute("ActiveMinichests")
                    local isCooldown = respawnTime and respawnTime > workspace:GetServerTimeNow() and not hasLoot
                    
                    if not isCooldown then
                        inBossArena = true
                        break
                    end
                end
            end
        end

        local teleportedByRadar = false
        local radarFoundBoss = false
        local isParkedAtRadarTarget = false
        local bestWaitVec = nil
        local bestWaitCooldown = math.huge
        
        -- Check if boss room exists at all in this server's map (for server hopping when absent)
        if getgenv().Config.AutoBossHunt then
            local inBackrooms = Utils.IsInBackroomsInstance()
            local charRoot = Utils.getRootPart()
            local currentY = charRoot and charRoot.Position.Y or 0
            
            local inCorrectZone = false
            if inBackrooms then
                if getgenv().Config.DeepBackroomsMode then
                    if currentY > 1800 then
                        inCorrectZone = true
                    end
                else
                    if currentY <= 1800 and currentY > 1000 then
                        inCorrectZone = true
                    end
                end
            end
            
            if inCorrectZone then
                local modeKey = getgenv().Config.DeepBackroomsMode and "Deep" or "Normal"
                if not getgenv().MapDescriptors then getgenv().MapDescriptors = {} end
                local descriptor = getgenv().MapDescriptors[modeKey]
                
                if not descriptor then
                    local retries = 5
                    while retries > 0 and not descriptor do
                        local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                        local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                        if invokeCustom then
                            local ok, desc = pcall(function()
                                return invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", getgenv().Config.DeepBackroomsMode)
                            end)
                            if ok and desc then
                                descriptor = desc
                                getgenv().MapDescriptors[modeKey] = desc
                                break
                            end
                        end
                        retries = retries - 1
                        task.wait(2)
                    end
                end

                if descriptor and descriptor.rooms then
                    local bossExistsInMap = false
                    local foundClasses = {}
                    for _, roomInfo in ipairs(descriptor.rooms) do
                        local c = string.lower(roomInfo.class or "")
                        if c ~= "" then
                            table.insert(foundClasses, c)
                        end
                        if c:find("gamemaster") or c:find("gamemastersstage") or c:find("masterboss") or c:find("daydream") or c:find("deepboss") or c:find("deepportal") or c:find("boss") then
                            bossExistsInMap = true
                        end
                    end
                    
                    -- Determine exploration threshold dynamically from the minimap UI if possible
                    local totalRooms = nil
                    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if pGui and pGui:FindFirstChild("BackroomsMiniMap") then
                        local miniMapFrame = pGui.BackroomsMiniMap:FindFirstChild("MiniMap")
                        if miniMapFrame then
                            for _, c in ipairs(miniMapFrame:GetChildren()) do
                                if c:IsA("TextLabel") and c.Text:find("Rooms found:") then
                                    local fStr, tStr = c.Text:match("Rooms found: (%d+) / (%d+)")
                                    if tStr then
                                        totalRooms = tonumber(tStr)
                                    end
                                end
                            end
                        end
                    end
                    
                    local threshold = totalRooms and math.max(10, totalRooms - 5) or (getgenv().Config.DeepBackroomsMode and 80 or 80)
                    local generatedCount = #descriptor.rooms
                    
                    print("[DEBUG] === BACKROOMS MAP INSPECTION ===")
                    print("[DEBUG] Mode: " .. (getgenv().Config.DeepBackroomsMode and "Deep" or "Normal"))
                    print("[DEBUG] Generated Rooms: " .. tostring(generatedCount) .. " / Threshold: " .. tostring(threshold) .. " (Total: " .. tostring(totalRooms or "Unknown") .. ")")
                    print("[DEBUG] All Room Classes Found: " .. table.concat(foundClasses, ", "))
                    print("[DEBUG] GameMaster Room Found: " .. tostring(bossExistsInMap))
                    print("[DEBUG] ==================================")
                    
                    if bossExistsInMap then
                        pcall(function()
                            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                                Text = "[BOT] 🎉 GameMaster Odası Bulundu! Odalar: " .. table.concat(foundClasses, ", "),
                                Color = Color3.fromRGB(80, 255, 80),
                                Font = Enum.Font.SourceSansBold,
                                FontSize = Enum.FontSize.Size18
                            })
                        end)
                    else
                        if generatedCount < threshold then
                            -- Map is still generating dynamically. Do not hop yet. Keep exploring.
                            pcall(function()
                                game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                                    Text = string.format("[BOT] GameMaster aranıyor... (Harita Oluşturuluyor: %d/%d Oda)", generatedCount, threshold),
                                    Color = Color3.fromRGB(255, 200, 100),
                                    Font = Enum.Font.SourceSansBold,
                                    FontSize = Enum.FontSize.Size18
                                })
                            end)
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({
                                    Title = "🔍 Generating Map...",
                                    Content = string.format("Odalar: %d/%d. Exploring to generate more...", generatedCount, threshold),
                                    Duration = 3
                                })
                            end
                        else
                            -- Map fully generated and still no GameMaster room → hop!
                            pcall(function()
                                game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                                    Text = "[BOT] Haritada GameMaster yok! Sınıflar: " .. table.concat(foundClasses, ", "),
                                    Color = Color3.fromRGB(255, 80, 80),
                                    Font = Enum.Font.SourceSansBold,
                                    FontSize = Enum.FontSize.Size18
                                })
                            end)
                            
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({
                                    Title = "🚀 No GameMaster!",
                                    Content = "Map explored. Hopping in 5s!",
                                    Duration = 5
                                })
                            end
                            
                            getgenv().LiveStats.BossStatus = "No Boss Room - Hopping in 5s 🚀"
                            task.wait(5)
                            Utils.serverHop()
                            task.wait(8)
                            continue
                        end
                    end
                else
                    warn("Failed to retrieve map descriptor. Skipping boss check this tick.")
                end
            end
        end

        if getgenv().Config.RadarTeleport and not inBossArena and not forceExplore then
            local radarTargets = {}
            
            if getgenv().Config.AutoBossHunt then
                table.insert(radarTargets, {"gamemaster", "gamemastersstage"})
                table.insert(radarTargets, {"masterboss", "masterboss"})
                table.insert(radarTargets, {"daydream", "daydream"})
                table.insert(radarTargets, {"deepboss", "deepboss"})
                table.insert(radarTargets, {"deepportal", "deepportal"})
                table.insert(radarTargets, {"boss", "boss"})
            end
            
            if getgenv().Config.AutoFarmEvents then
                table.insert(radarTargets, {"chalkboardkeypad", "code"})
                table.insert(radarTargets, {"simonfloor", "deeplaserpattern"})
                table.insert(radarTargets, {"buttons", "colorbutton"})
                table.insert(radarTargets, {"keyforge", "chestchoose"})
                table.insert(radarTargets, {"vending", "garden"})
            end
            
            if getgenv().Config.AutoFarmChests then 
                if getgenv().Config.DeepBackroomsMode then
                    table.insert(radarTargets, {"deepchestroom3", "deepchestroom3"})
                    table.insert(radarTargets, {"deepchestroom2", "deepchestroom2"})
                    table.insert(radarTargets, {"deepchestroom", "deepchestroom"})
                    table.insert(radarTargets, {"deepvault", "deepvault"})
                else
                    table.insert(radarTargets, {"vault", "chest"}) 
                end
            end
            if getgenv().Config.AutoFarmCoins then
                table.insert(radarTargets, {"deepcoinroom", "deepcoinroom"})
            end

            if getgenv().Config.AutoFarmEggs then
                table.insert(radarTargets, {"titanicegg", "hugeegg"})
                table.insert(radarTargets, {"deepfreeegg", "deeplockedegg"})
                table.insert(radarTargets, {"freeegg", "keepout"})
                table.insert(radarTargets, {"egg", "egg"})
            end
            
            for _, tData in ipairs(radarTargets) do
                local targetClass = tData[1]
                local altClass = tData[2]
                local targetVec, deadVec, deadCooldown, isPathNode, isWaitingAtBoundary = Utils.getTargetRoomVector(targetClass, altClass, Shared.VisitedRooms, rooms_raw, Shared.DeadChestRooms)
                
                if targetVec and not (isWaitingAtBoundary and not (targetClass == "gamemaster" or targetClass == "masterboss" or targetClass == "daydream" or targetClass == "deepboss")) then
                    local targetKey = tostring(math.floor(targetVec.X)) .. "_" .. tostring(math.floor(targetVec.Z))
                    if Shared.RadarAntiCheatBlacklist[targetKey] and os.clock() < Shared.RadarAntiCheatBlacklist[targetKey] then
                        continue
                    end

                    if targetClass == "boss" or targetClass == "miniboss" or targetClass == "gamemaster" or targetClass == "masterboss" or targetClass == "daydream" or targetClass == "deepboss" then
                        radarFoundBoss = true
                        getgenv().LiveStats.BossStatus = "Radar Locked 📡"
                    end
                    local currentRoot = Utils.getRootPart()
                    if currentRoot then
                        local dist = (currentRoot.Position - targetVec).Magnitude
                        
                        if getgenv().RadarLastTeleportTime and (os.clock() - getgenv().RadarLastTeleportTime) < 15 then
                            if getgenv().RadarLastTeleportPos and (getgenv().RadarLastTeleportPos - targetVec).Magnitude < 10 then
                                if dist > 1000 then
                                    local msgTitle = "Boss Room Found"
                                    local msgContent = "Waiting 60s for the room to reset... Exploring nearby!"
                                    
                                    do
                                        local MiscItem = require(ReplicatedStorage.Library.Items.MiscItem)
                                        local keyName = (targetClass == "deepboss") and "Deep Backrooms Crayon Key" or "Backrooms Crayon Key"
                                        local keyItem = MiscItem(keyName)
                                        
                                        if keyItem and keyItem.HasAny and keyItem:HasAny() then
                                            msgTitle = "🗝️ Unlocking Boss Door!"
                                            msgContent = "We have a " .. keyName .. "! The door is currently opening. Waiting 60s to return safely!"
                                        else
                                            msgTitle = "🔒 Locked Boss Room!"
                                            msgContent = "We don't have a " .. keyName .. " yet! Exploring for 60s to find one..."
                                        end
                                    end
                                    
                                    if getgenv().RLW_Window then
                                        getgenv().RLW_Window:Notify({Title = msgTitle, Content = msgContent, Duration = 4})
                                    end
                                    Shared.RadarAntiCheatBlacklist[targetKey] = os.clock() + 60
                                    continue
                                end
                            end
                        end
                        
                        if radarFoundBoss then
                            getgenv().LiveStats.BossStatus = string.format("Radar Locked 📡 (%d studs)", math.floor(dist))
                        end
                        local minDist = isPathNode and 50 or 300
                        if dist > minDist then
                            local Network = ReplicatedStorage:FindFirstChild("Network")
                            
                            if isPathNode then
                                if getgenv().RLW_Window then
                                    getgenv().RLW_Window:Notify({Title = "🗺️ Pathfinding!", Content = "Jumping to next room towards " .. targetClass .. "!", Duration = 1})
                                end
                            else
                                if getgenv().RLW_Window then
                                    getgenv().RLW_Window:Notify({Title = "📡 Radar Locked!", Content = "Teleporting to " .. targetClass .. "!", Duration = 2})
                                end
                            end
                            
                            getgenv().RadarLastTeleportTime = os.clock()
                            getgenv().RadarLastTeleportPos = targetVec
                            
                            local originalPos = currentRoot.CFrame
                            currentRoot.Anchored = true
                            local tpOk, tpErr = pcall(function()
                                currentRoot.CFrame = CFrame.new(targetVec + Vector3.new(0, 5, 0))
                                LocalPlayer:RequestStreamAroundAsync(targetVec, 2)
                                local reqStream = Network and Network:FindFirstChild("RequestStreaming")
                                if reqStream then
                                    reqStream:FireServer(targetVec)
                                end
                            end)
                            if not tpOk then
                                currentRoot.CFrame = originalPos
                                currentRoot.Anchored = false
                                if getgenv().RLW_Window then
                                    getgenv().RLW_Window:Notify({Title = "⚠️ Radar TP Failed!", Content = "Teleport error: " .. tostring(tpErr), Duration = 3})
                                end
                                continue
                            end
                            
                            local timeout = 5
                            local t = 0
                            local floorFound = false
                            local targetRoom = nil
                            while t < timeout do
                                local rayParams = RaycastParams.new()
                                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                rayParams.FilterDescendantsInstances = {Utils.getCharacter()}
                                local hit = workspace:Raycast(currentRoot.Position, Vector3.new(0, -100, 0), rayParams)
                                
                                if hit and hit.Instance and hit.Instance.CanCollide then
                                    floorFound = true
                                    if not targetRoom then
                                        targetRoom = hit.Instance:FindFirstAncestorWhichIsA("Model")
                                    end
                                end
                                
                                if not targetRoom then
                                    for _, r in ipairs(roomsFolderRadar:GetChildren()) do
                                        local pos = r:IsA("Model") and r:GetPivot().Position or Vector3.zero
                                        local roomID = string.lower(r:GetAttribute("RoomID") or "")
                                        if (pos - targetVec).Magnitude < 300 and (roomID:find(string.lower(targetClass)) or roomID:find(string.lower(altClass))) then
                                            targetRoom = r
                                            break
                                        end
                                    end
                                end
                                
                                if targetRoom then
                                    local lockedDoors = targetRoom:FindFirstChild("LockedDoors")
                                    if lockedDoors then
                                        for _, door in ipairs(lockedDoors:GetChildren()) do
                                            local lock = door:FindFirstChild("Lock")
                                            if lock and (lock:IsA("BasePart") or (lock:IsA("Model") and lock.PrimaryPart)) then
                                                floorFound = true
                                                break
                                            end
                                        end
                                    else
                                        if targetRoom:FindFirstChildWhichIsA("BasePart", true) then
                                            floorFound = true
                                        end
                                    end
                                end
                                
                                if floorFound then
                                    break
                                end
                                
                                task.wait(0.25)
                                t = t + 0.25
                            end
                            
                            if not floorFound then
                                currentRoot.CFrame = originalPos
                                if getgenv().RLW_Window then
                                    getgenv().RLW_Window:Notify({Title = "⚠️ Blocked!", Content = "Room didn't load! Returning to safety!", Duration = 3})
                                end
                                local targetRoomForBlacklist = isPathNode and nextRoom or targetRoom
                                local uid = targetRoomForBlacklist and targetRoomForBlacklist:GetAttribute("RoomUID")
                                if uid then
                                    Shared.DeadEggRooms[uid] = os.clock()
                                    Shared.DeadChestRooms[uid] = os.clock()
                                end
                            end
                            
                            currentRoot.Anchored = false

                            if floorFound and targetRoom then
                                local lockWaitTimeout = 3
                                local lt = 0
                                while not targetRoom:FindFirstChild("LockedDoors") and lt < lockWaitTimeout do
                                    task.wait(0.25)
                                    lt = lt + 0.25
                                end
                                
                                if targetRoom:FindFirstChild("LockedDoors") then
                                    local roomUID = targetRoom:GetAttribute("RoomUID")
                                    if roomUID then
                                        if getgenv().RLW_Window then
                                            getgenv().RLW_Window:Notify({Title = "🚪 Radar Unlock", Content = "Unlocking room door...", Duration = 3})
                                        end
                                        Utils.unlockDoors(targetRoom, roomUID)
                                        local root = Utils.getRootPart()
                                        if root then
                                            root.CFrame = CFrame.new(targetVec)
                                            task.wait(1)
                                        end
                                    end
                                end
                            end
                            
                            teleportedByRadar = true
                            break
                        else
                            isParkedAtRadarTarget = true
                            break
                        end
                    end
                elseif deadVec and deadCooldown then
                    if deadCooldown < bestWaitCooldown then
                        bestWaitCooldown = deadCooldown
                        bestWaitVec = deadVec
                    end
                end
            end
            
            if teleportedByRadar then
                continue
            end
            
            if bestWaitVec and not (getgenv().Config.AutoBossHunt and getgenv().Config.HopOnBossCooldown) then
                local currentRoot = Utils.getRootPart()
                if currentRoot then
                    local dist = (currentRoot.Position - bestWaitVec).Magnitude
                    if dist > 300 then
                        if getgenv().RLW_Window then
                            getgenv().RLW_Window:Notify({Title = "⏳ Waiting...", Content = "All rooms are dead! Waiting at nearest respawn...", Duration = 3})
                        end
                        local originalPos = currentRoot.CFrame
                        currentRoot.Anchored = true
                        local tpOk = pcall(function()
                            currentRoot.CFrame = CFrame.new(bestWaitVec + Vector3.new(0, 5, 0))
                            LocalPlayer:RequestStreamAroundAsync(bestWaitVec, 2)
                        end)
                        if not tpOk then
                            currentRoot.CFrame = originalPos
                            currentRoot.Anchored = false
                            continue
                        end
                        
                        local timeout = 5
                        local t = 0
                        local floorFound = false
                        while t < timeout do
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {Utils.getCharacter()}
                            local hit = workspace:Raycast(currentRoot.Position, Vector3.new(0, -100, 0), rayParams)
                            if hit and hit.Instance and hit.Instance.CanCollide then
                                floorFound = true
                                break
                            end
                            task.wait(0.25)
                            t = t + 0.25
                        end
                        
                        if not floorFound then
                            currentRoot.CFrame = originalPos
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "⚠️ Blocked!", Content = "Room didn't load! Returning to safety!", Duration = 3})
                            end
                        end
                        currentRoot.Anchored = false
                    end
                    task.wait(2)
                    continue
                end
            end
        end

        local checkEggCache = getgenv().Config.AutoFarmEggs
        if checkEggCache and getgenv().SmartFarmState.EggRoomUID then
            for _, room in ipairs(rooms) do
                if room:GetAttribute("RoomUID") == getgenv().SmartFarmState.EggRoomUID then
                    if Utils.isEggAlive(room) then
                        bestRoom = room
                        bestRoomType = 4
                    else
                        local deadUID = getgenv().SmartFarmState.EggRoomUID
                        getgenv().SmartFarmState.EggRoomUID = nil
                        Shared.DeadEggRooms[deadUID] = os.clock()
                    end
                    break
                end
            end
        end

        if not bestRoom and not forceExplore then
            for _, room in ipairs(rooms) do
                local roomUID = room:GetAttribute("RoomUID")
                
                if getgenv().LiveStats and roomUID and not getgenv().LiveStats._seenRooms[roomUID] then
                    getgenv().LiveStats._seenRooms[roomUID] = true
                    getgenv().LiveStats.RoomsExplored = getgenv().LiveStats.RoomsExplored + 1
                    
                    local mult = room:GetAttribute("EggMultiplier")
                    local roomID = room:GetAttribute("RoomID") or ""
                    local isFreeEggStats = string.lower(roomID):find("freeegg")
                    
                    if not isFreeEggStats and mult and type(mult) == "number" and mult > getgenv().LiveStats.HighestMultiplier then
                        getgenv().LiveStats.HighestMultiplier = mult
                        
                        local eggName = "Egg"
                        local lowerID = string.lower(roomID)
                        if lowerID:find("keepout") then eggName = "Keep Out"
                        elseif lowerID:find("titanicegg") then eggName = "Titanic"
                        elseif lowerID:find("hugeegg") then eggName = "Huge"
                        else
                            local attr = room:GetAttribute("EggType") or room:GetAttribute("EggName") or room:GetAttribute("Egg")
                            if attr then eggName = tostring(attr) end
                        end
                        getgenv().LiveStats.HighestMultiplierName = eggName
                    end
                end
                
                local roomID = room:GetAttribute("RoomID") or ""
                local lowerID = string.lower(roomID)

                local isEgg = lowerID:find("egg") or lowerID:find("keepout")
                if isEgg and Shared.DeadEggRooms[roomUID] and (os.clock() - Shared.DeadEggRooms[roomUID]) < Shared.DEAD_EGG_COOLDOWN then
                    isEgg = false
                end
                
                if isEgg and not Utils.isEggAlive(room) then
                    isEgg = false
                    Shared.DeadEggRooms[roomUID] = os.clock()
                end
                
                if isEgg and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end

                local isFreeEgg = lowerID:find("freeegg")
                if isFreeEgg and not Utils.isEggAlive(room) then isFreeEgg = false end
                
                local multiplier = tonumber(room:GetAttribute("EggMultiplier")) or 0
                
                local matchSpecificEgg = true
                if getgenv().Config.TargetEggType ~= "Any" then
                    local targetStr = string.lower(string.gsub(getgenv().Config.TargetEggType, " ", ""))
                    local eggAttr = tostring(room:GetAttribute("EggType") or room:GetAttribute("EggName") or room:GetAttribute("Egg") or "")
                    local attrStr = string.lower(string.gsub(eggAttr, " ", ""))
                    if not lowerID:find(targetStr) and not attrStr:find(targetStr) then
                        matchSpecificEgg = false
                    end
                end
                
                local isBoss = Utils.isBossRoom(room)
                
                local isVault = false
                local isBreakable = false
                
                if getgenv().Config.DeepBackroomsMode then
                    isVault = lowerID:find("deepchestroom") or lowerID:find("deepvault")
                    isBreakable = lowerID:find("deepcoinroom")
                else
                    isVault = lowerID:find("vault") or lowerID:find("chest")
                    isBreakable = lowerID:find("breakable")
                end
                
                local isEvent = getgenv().Config.FarmDeepEvents and (
                    lowerID:find("chalkboardkeypad") or lowerID:find("code") or lowerID:find("simonfloor")
                    or lowerID:find("deeplaserpattern") or lowerID:find("buttons") or lowerID:find("colorbutton")
                    or lowerID:find("keyforge") or lowerID:find("chestchoose") or lowerID:find("vending")
                    or lowerID:find("garden")
                )

                if isEvent and bestRoomType < 6 then
                    bestRoom = room
                    bestRoomType = 6
                    break
                end

                if getgenv().Config.AutoFarmEggs and isFreeEgg and matchSpecificEgg and multiplier >= getgenv().Config.TargetEggMultiplier and bestRoomType < 5 then
                    bestRoom = room
                    bestRoomType = 5
                    break
                end

                if isEgg then
                    if getgenv().Config.AutoFarmEggs and matchSpecificEgg and multiplier >= getgenv().Config.TargetEggMultiplier then
                        if bestRoomType < 4 then
                            bestRoom = room
                            bestRoomType = 4
                            break
                        end
                    else
                        Shared.VisitedRooms[roomUID] = true
                    end
                end

                if getgenv().Config.AutoBossHunt and isBoss and bestRoomType < 3 then
                    -- Prevent re-entry if BossHunter guard is active
                    local guard = getgenv().BackroomsShared._bossHunterGuard
                    local guardActive = guard and guard.roomUID == roomUID and os.clock() - guard.time < 12
                    if not guardActive then
                        bestRoom = room
                        bestRoomType = 3
                        getgenv().LiveStats.BossStatus = "Fighting Boss ⚔️"
                        break
                    end
                end

                if getgenv().Config.AutoFarmChests and isVault and bestRoomType < 2 then
                    bestRoom = room
                    bestRoomType = 2
                elseif getgenv().Config.AutoFarmCoins and isBreakable and bestRoomType < 1 then
                    bestRoom = room
                    bestRoomType = 1
                end
            end
        end

        if bestRoom and bestRoomType > 0 then
            local roomUID = bestRoom:GetAttribute("RoomUID")
            local roomID = bestRoom:GetAttribute("RoomID") or ""
            local lowerID = string.lower(roomID)

            Utils.safeTeleport(bestRoom, false)

            if bestRoomType == 6 then
                local Solvers = getgenv().BackroomsSolvers
                if Solvers then Solvers.solve(bestRoom, roomUID) end
            elseif bestRoomType == 5 then
                if bestRoom:FindFirstChild("LockedDoors") then
                    Utils.unlockDoors(bestRoom, roomUID)
                    Utils.safeTeleport(bestRoom, false)
                end
                local EggHatcher = getgenv().BackroomsEggHatcher
                if EggHatcher then EggHatcher.hatchRoom(bestRoom, roomUID, lowerID, 5) end
            elseif bestRoomType == 4 then
                if bestRoom:FindFirstChild("LockedDoors") then
                    Utils.unlockDoors(bestRoom, roomUID)
                    Utils.safeTeleport(bestRoom, false)
                end
                local EggHatcher = getgenv().BackroomsEggHatcher
                if EggHatcher then EggHatcher.hatchRoom(bestRoom, roomUID, lowerID, 4) end
            elseif bestRoomType == 3 then
                if bestRoom:FindFirstChild("LockedDoors") then
                    Utils.unlockDoors(bestRoom, roomUID)
                    Utils.safeTeleport(bestRoom, false)
                end
                local BossHunter = getgenv().BackroomsBossHunter
                if BossHunter then BossHunter.hunt(bestRoom, roomUID) end
            elseif bestRoomType == 1 or bestRoomType == 2 then
                if bestRoom:FindFirstChild("LockedDoors") then
                    Utils.unlockDoors(bestRoom, roomUID)
                    Utils.safeTeleport(bestRoom, false)
                end
                local ChestFarmer = getgenv().BackroomsChestFarmer
                if ChestFarmer then ChestFarmer.farm(bestRoom, roomUID, bestRoomType) end
            end
        else
            if isParkedAtRadarTarget then
                local root = Utils.getRootPart()
                if root then
                    root.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
                    local Network = ReplicatedStorage:FindFirstChild("Network")
                    if Network and Network:FindFirstChild("RequestStreaming") then
                        Network.RequestStreaming:FireServer(root.Position)
                    end
                end
                task.wait(1)
            else
                local Explorer = getgenv().BackroomsExplorer
                if Explorer then Explorer.explore(rooms, radarFoundBoss) end
            end
        end
    end
end)

return true
