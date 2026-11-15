-- src/Systems/Worlds/IslandManager.lua
-- Bridge Progression, World 1 / World 2 / Medieval Travel, Portal Discovery & Island Unlock

local IslandManager = {}

function IslandManager.Init(ctx)
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local W2_ISLAND_BOUNDS = ctx.W2_ISLAND_BOUNDS

    local getPlayerData = ctx.API.getPlayerData
    local safeInvoke = ctx.Utils.safeInvoke
    local requireSafe = ctx.Utils.requireSafe

    local travelToIsland

    local function getBridgeStatus()
        local data = getPlayerData()
        local lowered = data and data.Progression and data.Progression.BridgeLowered == true
        if lowered then
            return { lowered = true, ready = true, power = 0, req = 0 }
        end
        local power = 0
        local req = 700
        local ready = false
        if Mod.OnboardingConfig and data then
            pcall(function()
                power = Mod.OnboardingConfig.GetBridgePower(data)
                req = Mod.OnboardingConfig.BridgeReadyPowerFor(LocalPlayer)
                ready = Mod.OnboardingConfig.BridgeChallengeReady(data)
            end)
        end
        if power >= req then ready = true end
        return { lowered = false, ready = ready, power = power, req = req }
    end

    local function pushBridge(timeout)
        timeout = timeout or 6
        local data = getPlayerData()
        if data and data.Progression and data.Progression.BridgeLowered then
            return true
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return false, "No character" end

        hum.Sit = false
        local oldCF = hrp.CFrame
        hrp.CFrame = CFrame.new(-50.4, -515.5, -1810.0)
        task.wait(0.35)

        if Svc.BridgeService and Svc.BridgeService:FindFirstChild("RE") and Svc.BridgeService.RE:FindFirstChild("EngageChanged") then
            pcall(function()
                Svc.BridgeService.RE.EngageChanged:FireServer({ Engaged = true })
            end)
        end

        local startTime = os.clock()
        local lowered = false
        while os.clock() - startTime < timeout do
            local cur = getPlayerData()
            if cur and cur.Progression and cur.Progression.BridgeLowered then
                lowered = true
                break
            end
            if Mod.TapController and type(Mod.TapController.Tap) == "function" then
                Mod.TapController:Tap()
            elseif Svc.TapService and Svc.TapService:FindFirstChild("RE") and Svc.TapService.RE:FindFirstChild("TapRequested") then
                Svc.TapService.RE.TapRequested:FireServer()
            end
            task.wait(0.05)
        end

        task.wait(0.3)
        hrp.CFrame = oldCF
        return lowered
    end

    local function isWorld2Unlocked()
        local data = getPlayerData()
        return data and data.Progression and data.Progression.UnlockedWorlds and data.Progression.UnlockedWorlds.TimeRift == true
    end

    local function unlockWorld2()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return false, "NoCharacter" end
        hum.Sit = false
        local oldCF = hrp.CFrame
        hrp.CFrame = CFrame.new(-51.9, -406.5, -1513.0)
        task.wait(0.35)
        if Svc.TimeRiftService and Svc.TimeRiftService:FindFirstChild("RE") and Svc.TimeRiftService.RE:FindFirstChild("UnlockRequested") then
            Svc.TimeRiftService.RE.UnlockRequested:FireServer()
        end
        task.wait(0.5)
        hrp.CFrame = oldCF
        return isWorld2Unlocked()
    end

    local function getPortalPart(islandName, portalName)
        portalName = portalName or islandName

        -- 1. Check World 2 Portal Platforms: workspace.World2["World 2 Spawn"].Future.PortalPlatforms
        local w2 = workspace:FindFirstChild("World2")
        local w2Spawn = w2 and w2:FindFirstChild("World 2 Spawn")
        local w2Future = w2Spawn and w2Spawn:FindFirstChild("Future")
        local w2Platforms = w2Future and w2Future:FindFirstChild("PortalPlatforms")
        if w2Platforms then
            local p = w2Platforms:FindFirstChild(portalName) or w2Platforms:FindFirstChild(islandName)
            if p then
                local part = p:FindFirstChild("Portal") or p:FindFirstChild("Portal_Hitbox", true) or p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
                if part then return part end
            end
        end

        -- 2. Check workspace.World2.NextPortals
        local w2NextPortals = w2 and w2:FindFirstChild("NextPortals")
        if w2NextPortals then
            local p = w2NextPortals:FindFirstChild(portalName) or w2NextPortals:FindFirstChild(islandName)
            if p then
                local part = p:FindFirstChild("Portal") or p:FindFirstChild("Portal_Hitbox", true) or p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
                if part then return part end
            end
        end

        -- 3. Check workspace.Portals.Portals
        local portalsFolder = workspace:FindFirstChild("Portals")
        local portals = portalsFolder and portalsFolder:FindFirstChild("Portals")
        if portals then
            local p = portals:FindFirstChild(portalName) or portals:FindFirstChild(islandName)
            if p then
                local part = p:FindFirstChild("Portal") or p:FindFirstChild("Portal_Hitbox", true) or p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
                if part then return part end
            end
        end

        -- 4. Check workspace.NextPortals
        local nextPortals = workspace:FindFirstChild("NextPortals")
        if nextPortals then
            local p = nextPortals:FindFirstChild(portalName) or nextPortals:FindFirstChild(islandName)
            if p then
                local part = p:FindFirstChild("Portal") or p:FindFirstChild("Portal_Hitbox", true) or p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
                if part then return part end
            end
        end

        -- 5. Check World 2 Portal Platform from World 1 Spawn Hub (W2Platform)
        if islandName == "World 2 (Time Rift)" or portalName == "World2" or string.find(string.lower(tostring(islandName)), "world 2") then
            local w2p = workspace:FindFirstChild("Map1") and workspace.Map1:FindFirstChild("W2Platform")
            if w2p then
                local part = w2p:FindFirstChildWhichIsA("BasePart", true)
                if part then return part end
            end
        end

        return nil
    end

    local function isIslandNameUnlocked(unlocked, name)
        if not (unlocked and name) then return false end
        if unlocked[name] == true then return true end
        if type(unlocked) == "table" then
            for _, val in pairs(unlocked) do
                if val == name then
                    return true
                end
            end
        end
        return false
    end

    local function getNextLockedIsland(worldOverride)
        local data = getPlayerData()
        if not (data and data.Progression and Mod.IslandConfig and Mod.IslandConfig.Islands) then
            return nil
        end
        local unlocked = data.Progression.UnlockedIslands or {}
        local unlockedWorlds = data.Progression.UnlockedWorlds or {}
        local curWorld = data.Progression.World or "Main"
        local scope = worldOverride or curWorld

        local function findNextMainIsland()
            local sorted = {}
            for name, info in pairs(Mod.IslandConfig.Islands) do
                table.insert(sorted, {
                    name = name,
                    order = info.Order or 0,
                    price = info.Price or 0,
                    portalName = info.PortalName or name,
                    multiplier = info.Multiplier,
                    world = "Main",
                    isRift = false,
                })
            end
            table.sort(sorted, function(a, b) return a.order < b.order end)
            for _, isl in ipairs(sorted) do
                if not isIslandNameUnlocked(unlocked, isl.name) then
                    return isl
                end
            end
            if unlockedWorlds["TimeRift"] ~= true then
                return {
                    name = "World 2 (Time Rift)",
                    order = 9,
                    price = 2e19,
                    portalName = "World2",
                    isWorld2 = true,
                    world = "Main",
                    isRift = false,
                }
            end
            return nil
        end

        local function findNextRiftIsland()
            if not (Mod.RiftIslandConfig and Mod.RiftIslandConfig.Islands) then
                return nil
            end
            local riftSorted = {}
            for name, info in pairs(Mod.RiftIslandConfig.Islands) do
                table.insert(riftSorted, {
                    name = name,
                    order = (info.Order or 0) + 10,
                    price = info.Price or 0,
                    portalName = info.PortalName or name,
                    multiplier = info.Multiplier,
                    isRift = true,
                    world = "TimeRift",
                })
            end
            table.sort(riftSorted, function(a, b) return a.order < b.order end)
            for _, isl in ipairs(riftSorted) do
                if not isIslandNameUnlocked(unlocked, isl.name) then
                    return isl
                end
            end
            return nil
        end

        if scope == "TimeRift" then
            return findNextRiftIsland()
        elseif scope == "Main" then
            return findNextMainIsland()
        end

        return findNextMainIsland() or findNextRiftIsland()
    end

    local function unlockIsland(isl)
        if not isl then return false, "No island specified" end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return false, "No character" end

        local data = getPlayerData()
        local curWorld = data and data.Progression and data.Progression.World or "Main"

        if isl.isWorld2 then
            hum.Sit = false
            local oldCF = hrp.CFrame
            hrp.CFrame = CFrame.new(-51.9, -406.5, -1513.0)
            task.wait(0.5)
            if Svc.TimeRiftService and Svc.TimeRiftService:FindFirstChild("RE") and Svc.TimeRiftService.RE:FindFirstChild("UnlockRequested") then
                Svc.TimeRiftService.RE.UnlockRequested:FireServer()
            end
            local unlocked = false
            for _ = 1, 10 do
                task.wait(0.2)
                if isWorld2Unlocked() then
                    unlocked = true
                    break
                end
            end
            if not unlocked then
                hrp.CFrame = oldCF
            end
            return unlocked
        end

        if isl.isRift and curWorld ~= "TimeRift" then
            travelToIsland("World 2 Spawn")
            task.wait(1.0)
        end

        local portalPart = getPortalPart(isl.name, isl.portalName)
        if not portalPart then
            return false, "Portal part not found in workspace for " .. tostring(isl.name)
        end

        hum.Sit = false
        local oldCF = hrp.CFrame
        hrp.CFrame = CFrame.new(portalPart.Position + Vector3.new(0, 3, 0))
        task.wait(0.5)

        local unlocked = false
        local service = (isl.isRift and Svc.TimeRiftIslandService) or Svc.IslandService
        if service and service:FindFirstChild("RE") and service.RE:FindFirstChild("IslandUnlockRequested") then
            pcall(function()
                service.RE.IslandUnlockRequested:FireServer({ Action = "Purchase", Island = isl.name })
            end)
            for _ = 1, 12 do
                task.wait(0.2)
                local freshData = getPlayerData()
                if freshData and freshData.Progression and freshData.Progression.UnlockedIslands then
                    if freshData.Progression.UnlockedIslands[isl.name] or (type(freshData.Progression.UnlockedIslands) == "table" and table.find(freshData.Progression.UnlockedIslands, isl.name)) then
                        unlocked = true
                        break
                    end
                end
            end
        end

        if not unlocked then
            hrp.CFrame = oldCF
        end
        return unlocked
    end

    local function getBestUnlockedIsland()
        local data = getPlayerData()
        if not (data and data.Progression) then
            return "Spawn"
        end
        local unlocked = data.Progression.UnlockedIslands or {}
        local curWorld = data.Progression.World or "Main"
        local w2Unlocked = (data.Progression.UnlockedWorlds and data.Progression.UnlockedWorlds.TimeRift == true) or (isWorld2Unlocked and isWorld2Unlocked())

        if w2Unlocked and Mod.RiftIslandConfig and Mod.RiftIslandConfig.Islands then
            local riftSorted = {}
            for name, info in pairs(Mod.RiftIslandConfig.Islands) do
                table.insert(riftSorted, { name = name, order = info.Order or 0 })
            end
            table.sort(riftSorted, function(a, b) return a.order > b.order end)
            for _, isl in ipairs(riftSorted) do
                if unlocked[isl.name] == true or (type(unlocked) == "table" and table.find(unlocked, isl.name)) then
                    return isl.name
                end
            end
            if curWorld == "TimeRift" then
                return "Spawn"
            else
                return "World 2 Spawn"
            end
        end

        if Mod.IslandConfig and Mod.IslandConfig.Islands then
            local sorted = {}
            for name, info in pairs(Mod.IslandConfig.Islands) do
                table.insert(sorted, { name = name, order = info.Order or 0 })
            end
            table.sort(sorted, function(a, b) return a.order > b.order end)
            for _, isl in ipairs(sorted) do
                if unlocked[isl.name] == true or (type(unlocked) == "table" and table.find(unlocked, isl.name)) then
                    return isl.name
                end
            end
        end
        return "Spawn"
    end

    travelToIsland = function(target)
        if not target then return false end
        target = ctx.API.normalizeIslandName(target)
        local OptimizationState = ctx.States.Optimization
        local updateRegionalCulling = ctx.API.updateRegionalCulling
        local restoreCulledArea = ctx.API.restoreCulledArea

        local function notifyTravelCulling()
            if OptimizationState and OptimizationState.CpuSaver and updateRegionalCulling then
                task.defer(function()
                    task.wait(0.5)
                    pcall(updateRegionalCulling)
                end)
            end
        end

        local data = getPlayerData()
        local curWorld = data and data.Progression and data.Progression.World or "Main"
        local curIsland = data and data.Progression and data.Progression.Island
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local isPhysicallyAtSpawn = hrp and (curWorld == "Main" and hrp.Position.Y < -400)

        local isW2SpawnAlias = (target == "World 2 Spawn" or target == "World 2 (Time Rift)" or target == "World 2")
        local isRiftIsland = isW2SpawnAlias
            or target == "Prehistoric Island" or target == "Ice Age" or target == "Medieval Island"
            or (Mod.RiftIslandConfig and Mod.RiftIslandConfig.Islands and Mod.RiftIslandConfig.Islands[target] ~= nil)

        if isRiftIsland and restoreCulledArea then
            pcall(function()
                restoreCulledArea("World2")
                restoreCulledArea("World2Decor")
                restoreCulledArea("World 2 Spawn")
                restoreCulledArea("Medieval Island")
            end)
        elseif restoreCulledArea then
            pcall(function()
                restoreCulledArea("Map1")
                restoreCulledArea("Spawn")
                restoreCulledArea("Ts2Islands")
            end)
        end

        if isW2SpawnAlias then
            if curWorld == "TimeRift" then
                target = "Spawn"
            else
                if Svc.TimeRiftIslandService and Svc.TimeRiftIslandService:FindFirstChild("RF") and Svc.TimeRiftIslandService.RF:FindFirstChild("Travel") then
                    pcall(function()
                        Svc.TimeRiftIslandService.RF.Travel:InvokeServer({ Island = "Spawn", Source = "Menu" })
                    end)
                end
                task.wait(0.3)
                local freshData = getPlayerData()
                if freshData and freshData.Progression and freshData.Progression.World == "Main" and hrp then
                    if hum then hum.Sit = false end
                    hrp.CFrame = CFrame.new(-54.0, -376.0, -1536.0)
                    task.wait(0.5)
                end
                notifyTravelCulling()
                return true
            end
        end

        if isRiftIsland and curWorld ~= "TimeRift" and target ~= "Spawn" then
            if Svc.TimeRiftIslandService and Svc.TimeRiftIslandService:FindFirstChild("RF") and Svc.TimeRiftIslandService.RF:FindFirstChild("Travel") then
                pcall(function()
                    Svc.TimeRiftIslandService.RF.Travel:InvokeServer({ Island = "Spawn", Source = "Menu" })
                end)
                task.wait(0.4)
                data = getPlayerData()
                curWorld = data and data.Progression and data.Progression.World or curWorld
                curIsland = data and data.Progression and data.Progression.Island or curIsland
            end
        end

        local useRiftService = isRiftIsland
        local physicallyAtTarget = true
        if hrp then
            if useRiftService then
                for _, b in ipairs(W2_ISLAND_BOUNDS) do
                    local bInternal = (b.name == "World 2 Spawn") and "Spawn" or b.name
                    if bInternal == target then
                        physicallyAtTarget = ((hrp.Position - b.center).Magnitude <= b.radius)
                        break
                    end
                end
            elseif target == "Spawn" then
                physicallyAtTarget = (hrp.Position.Y < -400)
            elseif target ~= "Spawn" and isPhysicallyAtSpawn then
                physicallyAtTarget = false
            end
        end

        if curIsland == target and physicallyAtTarget and ((useRiftService and curWorld == "TimeRift") or (not useRiftService and curWorld == "Main")) then
            return true
        end

        if useRiftService then
            local res = safeInvoke(Svc.TimeRiftIslandService, "RF", "Travel", { Island = target, Source = "Menu" })
            if type(res) == "table" and res.Success == true then
                notifyTravelCulling()
                return true
            end
        else
            local res = safeInvoke(Svc.IslandService, "RF", "Travel", { Island = target, Source = "Menu" })
            if type(res) == "table" and res.Success == true then
                notifyTravelCulling()
                return true
            end
        end

        local IslandController = requireSafe(function() return ReplicatedStorage.Controllers.Game.IslandController end)
        if IslandController and type(IslandController.TravelFromMenu) == "function" then
            local ok, res = pcall(function()
                return IslandController:TravelFromMenu(target, nil, nil, useRiftService)
            end)
            if ok and res then
                notifyTravelCulling()
                return true
            end
        end

        if useRiftService and hrp then
            if hum then hum.Sit = false end
            local w2Coords = {
                ["Spawn"] = CFrame.new(46, 568, 7031),
                ["Prehistoric Island"] = CFrame.new(957, 903, 7131.2),
                ["Ice Age"] = CFrame.new(1533.8, 1350, 7116.5),
                ["Medieval Island"] = CFrame.new(2544, 1940, 7050),
            }
            if w2Coords[target] then
                hrp.CFrame = w2Coords[target]
                notifyTravelCulling()
                return true
            end
        end

        return false
    end

    ctx.API.getBridgeStatus = getBridgeStatus
    ctx.API.pushBridge = pushBridge
    ctx.API.isWorld2Unlocked = isWorld2Unlocked
    ctx.API.unlockWorld2 = unlockWorld2
    ctx.API.getPortalPart = getPortalPart
    ctx.API.getNextLockedIsland = getNextLockedIsland
    ctx.API.unlockIsland = unlockIsland
    ctx.API.getBestUnlockedIsland = getBestUnlockedIsland
    ctx.API.travelToIsland = travelToIsland

    IslandManager.getBridgeStatus = getBridgeStatus
    IslandManager.pushBridge = pushBridge
    IslandManager.isWorld2Unlocked = isWorld2Unlocked
    IslandManager.unlockWorld2 = unlockWorld2
    IslandManager.getPortalPart = getPortalPart
    IslandManager.getNextLockedIsland = getNextLockedIsland
    IslandManager.unlockIsland = unlockIsland
    IslandManager.getBestUnlockedIsland = getBestUnlockedIsland
    IslandManager.travelToIsland = travelToIsland
    return IslandManager
end

function IslandManager.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local IslandState = ctx.States.Island
    local UI = ctx.UI
    local getCoins = ctx.API.getCoins
    local getPlayerData = ctx.API.getPlayerData
    local formatCompact = ctx.Utils.formatCompact
    local safeNotify = function(opts)
        if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
    end

    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            task.wait(2.0)
            pcall(function()
                local bridgeStatus = IslandManager.getBridgeStatus()
                local coins = getCoins()
                local nextIsl = IslandManager.getNextLockedIsland()

                if UI.BridgeStatusText and UI.BridgeStatusText.SetTitle then
                    if bridgeStatus.lowered then
                        UI.BridgeStatusText:SetTitle("Drawbridge: Unlocked & Lowered (100%)")
                    elseif bridgeStatus.ready then
                        UI.BridgeStatusText:SetTitle(string.format("Drawbridge: READY TO PUSH! (%s / %s)", formatCompact(bridgeStatus.power), formatCompact(bridgeStatus.req)))
                    else
                        UI.BridgeStatusText:SetTitle(string.format("Drawbridge: Locked (%s / %s power)", formatCompact(bridgeStatus.power), formatCompact(bridgeStatus.req)))
                    end
                end

                if UI.NextIslandStatusText and UI.NextIslandStatusText.SetTitle then
                    if not nextIsl then
                        UI.NextIslandStatusText:SetTitle("All Islands Unlocked!")
                    else
                        local pct = math.clamp(math.floor((coins / math.max(nextIsl.price, 1)) * 100), 0, 100)
                        UI.NextIslandStatusText:SetTitle(string.format("Next: %s [%s / %s (%d%%)]", nextIsl.name, formatCompact(coins), formatCompact(nextIsl.price), pct))
                    end
                end

                if UI.World2StatusText and UI.World2StatusText.SetTitle then
                    if IslandManager.isWorld2Unlocked() then
                        UI.World2StatusText:SetTitle("World 2 (Time Rift): Unlocked & Active!")
                    else
                        local pct = math.clamp(math.floor((coins / 2e19) * 100), 0, 100)
                        UI.World2StatusText:SetTitle(string.format("World 2: Locked [%s / 20.00QN (%d%%)]", formatCompact(coins), pct))
                    end
                end

                if (IslandState.AutoPushBridge or IslandState.AutoUnlockNext) and not bridgeStatus.lowered and bridgeStatus.ready then
                    local ok = IslandManager.pushBridge(6)
                    if ok then
                        pcall(function()
                            safeNotify({
                                title = "Drawbridge Lowered!",
                                content = "The drawbridge was pushed down and unlocked!"
                            })
                        end)
                    end
                    task.wait(1)
                    return
                end

                if IslandState.AutoUnlockNext and nextIsl then
                    if not bridgeStatus.lowered then
                        if bridgeStatus.ready then
                            IslandManager.pushBridge(6)
                        end
                        return
                    end

                    if coins >= nextIsl.price then
                        local ok = IslandManager.unlockIsland(nextIsl)
                        if ok then
                            pcall(function()
                                safeNotify({
                                    title = "Island Unlocked!",
                                    content = string.format("Unlocked %s for %s Coins!", nextIsl.name, formatCompact(nextIsl.price))
                                })
                            end)
                            if IslandState.AutoBestTeleport then
                                task.wait(0.5)
                                IslandManager.travelToIsland(nextIsl.name)
                            end
                            task.wait(1.5)
                        end
                    end
                end

                if IslandState.AutoBestTeleport then
                    local best = IslandManager.getBestUnlockedIsland()
                    local curData = getPlayerData()
                    if curData and curData.Progression and curData.Progression.Island ~= best and best ~= "Spawn" then
                        IslandManager.travelToIsland(best)
                        task.wait(2.0)
                    end
                end
            end)
        end
    end)
end

return IslandManager
