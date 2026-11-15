-- src/Systems/Pets/EggController.lua
-- Egg Stand Positioning, Cross-World Travel & Rate-Limit Protected Auto Hatch Worker

local EggController = {}

function EggController.Init(ctx)
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local Players = ctx.Roblox.Players or game:GetService("Players")
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local CONFIG = ctx.Config
    local W2_ISLAND_BOUNDS = ctx.W2_ISLAND_BOUNDS
    local HatchState = ctx.States.Hatch
    local getInstancePosition = ctx.Utils.getInstancePosition
    local getInstanceCFrame = ctx.Utils.getInstanceCFrame
    local requireSafe = ctx.Utils.requireSafe
    local getPlayerData = ctx.API.getPlayerData
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay

    local function getEggStandFootprint()
        if Mod.EggStandFootprint then return Mod.EggStandFootprint end
        if requireSafe then
            Mod.EggStandFootprint = requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.EggStandFootprint end)
        else
            local ok, m = pcall(function() return require(ReplicatedStorage.Modules.Client.Pets.EggStandFootprint) end)
            if ok then Mod.EggStandFootprint = m end
        end
        return Mod.EggStandFootprint
    end

    local function getEggPricing()
        if Mod.EggPricing then return Mod.EggPricing end
        if requireSafe then
            Mod.EggPricing = requireSafe(function() return ReplicatedStorage.Shared.Pets.EggPricing end)
        else
            local ok, m = pcall(function() return require(ReplicatedStorage.Shared.Pets.EggPricing) end)
            if ok then Mod.EggPricing = m end
        end
        return Mod.EggPricing
    end

    local function findEggModelInWorkspace(eggName)
        if not eggName then return nil end
        local eggsFolder = workspace:FindFirstChild("Eggs")
        local eggModel = (eggsFolder and eggsFolder:FindFirstChild(eggName))
            or (workspace:FindFirstChild("World2") and workspace.World2:FindFirstChild(eggName, true))
        if not eggModel and eggsFolder then
            local lowerTarget = string.lower(eggName)
            for _, child in ipairs(eggsFolder:GetChildren()) do
                if string.lower(child.Name) == lowerTarget then
                    eggModel = child
                    break
                end
            end
        end
        return eggModel
    end

    local function toHorizontalUnit(vec)
        if not vec then return nil end
        local flat = Vector3.new(vec.X, 0, vec.Z)
        if flat.Magnitude < 0.1 then return nil end
        return flat.Unit
    end

    local function isPointNearPartOBB(point, part, xzPad, yPad)
        local rel = part.CFrame:PointToObjectSpace(point)
        local half = part.Size * 0.5
        return math.abs(rel.X) <= (half.X + xzPad)
            and math.abs(rel.Y) <= (half.Y + yPad)
            and math.abs(rel.Z) <= (half.Z + xzPad)
    end

    local function buildGroundRaycastParams(eggModel)
        local exclude = { eggModel }
        if LocalPlayer.Character then
            table.insert(exclude, LocalPlayer.Character)
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and plr.Character ~= LocalPlayer.Character then
                table.insert(exclude, plr.Character)
            end
        end
        local diamondPets = workspace:FindFirstChild("DiamondPets")
        if diamondPets then
            table.insert(exclude, diamondPets)
        end
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = exclude
        return rayParams
    end

    local function getEggStandCFrame(eggName)
        local eggModel = findEggModelInWorkspace(eggName)
        if not eggModel then return nil end

        local eggInst = eggModel:FindFirstChild("Egg") or eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart")
        local eggCenter = getInstancePosition(eggInst)
        local eggCF = getInstanceCFrame(eggInst)
        if not eggCenter then return nil end

        local stand = eggModel:FindFirstChild("Stand")
        local priceTag = eggModel:FindFirstChild("PriceTag")
        local sign = eggModel:FindFirstChild("EggCostSign")
        local signInst = sign and (sign:FindFirstChild("Sign") or sign:FindFirstChildWhichIsA("BasePart"))
        local signCF = getInstanceCFrame(signInst)

        local priceTagPos = nil
        if priceTag then
            if priceTag:IsA("Model") then
                priceTagPos = priceTag:GetPivot().Position
            else
                priceTagPos = getInstancePosition(priceTag)
            end
        end

        local priceTagDir = priceTagPos and toHorizontalUnit(priceTagPos - eggCenter) or nil
        local signDir = signCF and toHorizontalUnit(signCF.LookVector) or nil
        local standPart = stand and (stand:FindFirstChild("CollisionSlab") or stand:FindFirstChild("Pedestal") or stand:FindFirstChildWhichIsA("BasePart"))
        local standCF = getInstanceCFrame(standPart)
        local standDir = standCF and toHorizontalUnit(standCF.LookVector) or nil
        local eggLookDir = eggCF and toHorizontalUnit(eggCF.LookVector) or nil

        -- Stand-mounted eggs (e.g. Glitched Egg) have an elevated CostSign rotated off-axis;
        -- PriceTag & Stand face directly out toward the walkable front.
        local forwardDir
        if stand then
            forwardDir = priceTagDir or standDir or signDir or eggLookDir or Vector3.new(0, 0, 1)
        else
            forwardDir = signDir or priceTagDir or eggLookDir or Vector3.new(0, 0, 1)
        end

        -- Measure horizontal extent along forwardDir for collidable Stand / PriceTag / base parts
        local maxCollideExtent = 0
        local collidableBaseParts = {}
        local minBaseY = eggCenter.Y
        for _, p in ipairs(eggModel:GetDescendants()) do
            if p:IsA("BasePart") then
                local isEggPart = eggInst and (p == eggInst or p:IsDescendantOf(eggInst))
                local isSignPart = sign and p:IsDescendantOf(sign)
                local isBasePart = (stand and p:IsDescendantOf(stand))
                    or (priceTag and p:IsDescendantOf(priceTag))
                    or (not isEggPart and not isSignPart and p.Position.Y < eggCenter.Y - 1)
                if isBasePart then
                    minBaseY = math.min(minBaseY, p.Position.Y - (p.Size.Y * 0.5))
                    if p.CanCollide then
                        table.insert(collidableBaseParts, p)
                        local half = p.Size * 0.5
                        local cf = p.CFrame
                        local projHalf = math.abs(forwardDir:Dot(cf.RightVector)) * half.X
                            + math.abs(forwardDir:Dot(cf.UpVector)) * half.Y
                            + math.abs(forwardDir:Dot(cf.LookVector)) * half.Z
                        local offset = Vector3.new(cf.Position.X - eggCenter.X, 0, cf.Position.Z - eggCenter.Z)
                        local partFront = forwardDir:Dot(offset) + projHalf
                        if partFront > maxCollideExtent then
                            maxCollideExtent = partFront
                        end
                    end
                end
            end
        end

        local standDist = stand and math.max(6.5, maxCollideExtent + 2.8) or math.max(6.5, maxCollideExtent + 1.0)
        local rayParams = buildGroundRaycastParams(eggModel)
        -- Start below overhead tree canopies (e.g. Mushroom) while well above floor/pedestal surface
        local rayTopY = math.min(eggCenter.Y + 1.5, minBaseY + 10)

        local function sampleTargetAt(dist)
            local p = Vector3.new(eggCenter.X, eggCenter.Y, eggCenter.Z) + (forwardDir * dist)
            local hit = workspace:Raycast(Vector3.new(p.X, rayTopY, p.Z), Vector3.new(0, -80, 0), rayParams)
            local floorY = hit and hit.Position.Y or (minBaseY < eggCenter.Y - 1 and minBaseY or (eggCenter.Y - 4.5))
            return Vector3.new(p.X, floorY + 3.0, p.Z)
        end

        local targetPosition = sampleTargetAt(standDist)

        -- Guarantee target stays outside collidable Stand / PriceTag OBBs and EggStandFootprint
        for _ = 1, 3 do
            local overlaps = false
            for _, p in ipairs(collidableBaseParts) do
                if isPointNearPartOBB(targetPosition, p, 1.0, 1.5) then
                    overlaps = true
                    break
                end
            end
            if not overlaps and stand then
                local footprint = getEggStandFootprint()
                if footprint and footprint.Distance then
                    local okFoot, dFoot = pcall(footprint.Distance, eggModel, eggCenter, targetPosition)
                    if okFoot and type(dFoot) == "number" and dFoot < 1.2 then
                        overlaps = true
                    end
                end
            end
            if not overlaps then break end
            standDist = standDist + 1.5
            targetPosition = sampleTargetAt(standDist)
        end

        return CFrame.new(targetPosition, Vector3.new(eggCenter.X, targetPosition.Y, eggCenter.Z))
    end

    local function isPhysicallyNearIsland(hrp, targetWorld, targetIsland)
        if not hrp then return false end
        if targetWorld == "TimeRift" then
            if hrp.Position.Y < 200 then return false end
            if type(W2_ISLAND_BOUNDS) == "table" then
                for _, b in ipairs(W2_ISLAND_BOUNDS) do
                    local bInternal = (b.name == "World 2 Spawn") and "Spawn" or b.name
                    if bInternal == targetIsland then
                        return (hrp.Position - b.center).Magnitude <= b.radius
                    end
                end
            end
            return true
        end
        if hrp.Position.Z > 3000 then return false end
        if targetIsland == "Spawn" then
            return hrp.Position.Y < -400
        end
        return true
    end

    local function goToEgg(eggName)
        if not eggName then return false, "NoEgg" end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return false, "NoCharacter" end

        local eggInfo = Mod.LaunchEggConfig and Mod.LaunchEggConfig[eggName]
        local targetWorld = (eggInfo and eggInfo.World) or "Main"
        local targetIsland = (eggInfo and eggInfo.Island) or "Spawn"

        if ctx.API.restoreCulledArea and not findEggModelInWorkspace(eggName) then
            pcall(function()
                if targetWorld == "TimeRift" then
                    ctx.API.restoreCulledArea("World2")
                    ctx.API.restoreCulledArea("World2Decor")
                    ctx.API.restoreCulledArea(targetIsland)
                else
                    ctx.API.restoreCulledArea("Map1")
                    ctx.API.restoreCulledArea("Ts2Islands")
                    ctx.API.restoreCulledArea(targetIsland)
                end
            end)
        end

        local data = getPlayerData()
        local curWorld = data and data.Progression and data.Progression.World or "Main"
        local curIsland = data and data.Progression and data.Progression.Island or "Spawn"
        local needTravel = (curWorld ~= targetWorld)
            or (curIsland ~= targetIsland)
            or (not isPhysicallyNearIsland(hrp, targetWorld, targetIsland))
            or (not findEggModelInWorkspace(eggName))

        if needTravel then
            local dest = (targetWorld == "TimeRift" and targetIsland == "Spawn") and "World 2 Spawn" or targetIsland
            if ctx.API.travelToIsland then
                ctx.API.travelToIsland(dest)
            end
            local waitStart = os.clock()
            while os.clock() - waitStart < 1.8 do
                local fresh = getPlayerData()
                local freshWorld = fresh and fresh.Progression and fresh.Progression.World
                if freshWorld == targetWorld and findEggModelInWorkspace(eggName) then
                    break
                end
                task.wait(0.15)
            end
        end

        local eggModel = findEggModelInWorkspace(eggName)
        if not eggModel then
            local startW = os.clock()
            while os.clock() - startW < 2.5 do
                task.wait(0.2)
                eggModel = findEggModelInWorkspace(eggName)
                if eggModel then break end
            end
        end

        local standCF = getEggStandCFrame(eggName)
        if standCF then
            hum.Sit = false
            local dist = (hrp.Position - standCF.Position).Magnitude
            local horizDist = Vector3.new(hrp.Position.X - standCF.Position.X, 0, hrp.Position.Z - standCF.Position.Z).Magnitude
            if dist > 2.8 or horizDist > 2.5 or math.abs(hrp.Position.Y - standCF.Position.Y) > 4.0 then
                hrp.CFrame = standCF
                task.wait(0.25)
            end
            return true
        end

        return false, "StandNotFound"
    end

    local function formatHatchSpeedTitle(speed, delay, isAuto)
        local modeStr = isAuto and "Auto" or "Manual"
        return string.format("Live Hatch Speed: %.2fx (~%.2fs) [%s]", speed, delay, modeStr)
    end

    local function updateHatchSpeedDisplay()
        local autoDelay, sp = getAutoHatchDelay()
        HatchState.LiveSpeed = sp
        local currentActiveDelay = HatchState.AutoSpeed and autoDelay or (HatchState.HatchDelay or CONFIG.HatchCooldown)
        local titleStr = formatHatchSpeedTitle(sp, currentActiveDelay, HatchState.AutoSpeed)
        local subStr = string.format("Server Delay: %.2fs | Multiplier: %.2fx", currentActiveDelay, sp)
        if ctx.UI.HatchSpeedText then
            pcall(function()
                if ctx.UI.HatchSpeedText.SetTitle then
                    ctx.UI.HatchSpeedText:SetTitle(titleStr)
                end
                if ctx.UI.HatchSpeedText.Set then
                    ctx.UI.HatchSpeedText:Set(subStr)
                end
            end)
        end
    end

    local function hatchCountToLabel(hc)
        if hc == 8 then return "8x"
        elseif hc == 3 then return "3x"
        elseif hc == 1 then return "1x"
        else return "Auto (8x / 3x / 1x)" end
    end

    ctx.API.findEggModelInWorkspace = findEggModelInWorkspace
    ctx.API.getEggStandCFrame = getEggStandCFrame
    ctx.API.goToEgg = goToEgg
    ctx.UI.formatHatchSpeedTitle = formatHatchSpeedTitle
    ctx.UI.updateHatchSpeedDisplay = updateHatchSpeedDisplay
    ctx.UI.hatchCountToLabel = hatchCountToLabel

    EggController.findEggModelInWorkspace = findEggModelInWorkspace
    EggController.getEggStandCFrame = getEggStandCFrame
    EggController.goToEgg = goToEgg
    return EggController
end

function EggController.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local trackConnection = ctx.Lifecycle.TrackConnection
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local HatchState = ctx.States.Hatch
    local KaitunState = ctx.States.Kaitun
    local OptimizationState = ctx.States.Optimization
    local UI = ctx.UI
    local Runtime = ctx.Runtime
    local debugWarn = ctx.Utils.debugWarn
    local formatCompact = ctx.Utils.formatCompact or function(n) return tostring(n) end
    local getCoins = ctx.API.getCoins
    local getCoinsForEgg = ctx.API.getCoinsForEgg or getCoins
    local getPlayerData = ctx.API.getPlayerData
    local getPetStorageInfo = ctx.API.getPetStorageInfo
    local hasX8Gamepass = ctx.API.hasX8Gamepass
    local canUseX8Hatch = ctx.API.canUseX8Hatch or hasX8Gamepass
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local requireSafe = ctx.Utils.requireSafe
    local safeNotify = function(opts)
        if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
    end

    local lastNotifyAt = {}
    local function notifyThrottled(key, cooldown, title, content, duration)
        local now = os.clock()
        if (now - (lastNotifyAt[key] or 0)) < (cooldown or 15) then
            return
        end
        lastNotifyAt[key] = now
        safeNotify({
            title = title,
            content = content,
            duration = duration or 5,
        })
    end

    local function getEggCurrencyLabel(eggName)
        local eggInfo = eggName and Mod.LaunchEggConfig and Mod.LaunchEggConfig[eggName]
        if eggInfo and eggInfo.World == "TimeRift" then
            return "RiftCoins"
        end
        return "Coins"
    end

    local function getTotalEggCost(data, eggName, unitPrice, count)
        local pricing = Mod.EggPricing
        if not pricing and requireSafe then
            pricing = requireSafe(function() return ReplicatedStorage.Shared.Pets.EggPricing end)
            Mod.EggPricing = pricing
        end
        if pricing and pricing.GetTotal and data then
            local ok, total = pcall(pricing.GetTotal, data, eggName, unitPrice, count, LocalPlayer)
            if ok and type(total) == "number" then
                return total
            end
        end
        return unitPrice * count
    end

    if Svc.EggService and Svc.EggService:FindFirstChild("RE") then
        local hatchResultRemote = Svc.EggService.RE:FindFirstChild("EggHatchResult")
        if hatchResultRemote then
            pcall(function()
                trackConnection(hatchResultRemote.OnClientEvent:Connect(function(res)
                    if not isCurrentGeneration() then return end
                    Runtime.isHatchingBusy = false
                    if type(res) == "table" and res.Success == false then
                        local err = tostring(res.Error or res.Reason or "")
                        local lowerErr = string.lower(err)
                        local eggName = res.Egg or HatchState.SelectedEgg
                        if string.find(lowerErr, "storage") or string.find(lowerErr, "full") or string.find(lowerErr, "slot") or string.find(lowerErr, "inventory") then
                            HatchState.AutoHatch = false
                            if UI.AutoHatchToggle and UI.AutoHatchToggle.Set then
                                pcall(function() UI.AutoHatchToggle:Set(false, true) end)
                            end
                            local ownedCount, maxStorage = getPetStorageInfo()
                            safeNotify({
                                title = "Inventory Full!",
                                content = string.format("Storage is full (%d/%d). Please delete or craft pets to free up space to keep hatching!", ownedCount, maxStorage),
                                duration = 6
                            })
                        elseif res.Error == "RateLimited" then
                            Runtime.lastHatchSent = os.clock() + 0.35
                        elseif res.Error == "NeedsHatch8" then
                            Runtime.noHatch8Until = os.clock() + 30
                            if HatchState.HatchCount == 8 then
                                notifyThrottled("NeedsHatch8", 15, "8x Hatch Locked", "8x Hatch requires x8Egg Gamepass or OctoHatch boost. Switch Hatch Amount to Auto (8x/3x/1x) or 3x/1x.", 6)
                            end
                        elseif res.Error == "NotEnoughCoins" then
                            local curLabel = getEggCurrencyLabel(eggName)
                            local curBal = getCoinsForEgg(eggName)
                            notifyThrottled("NotEnoughCoins_" .. tostring(eggName), 15, "Insufficient " .. curLabel,
                                string.format("Not enough %s for %s (Balance: %s).", curLabel, tostring(eggName), formatCompact(curBal)), 5)
                        elseif res.Error == "TooFar" then
                            Runtime.lastHatchSent = 0
                            debugWarn("AutoHatch", "Server returned TooFar for " .. tostring(eggName) .. " - re-positioning at stand.")
                            task.defer(function()
                                if isCurrentGeneration() and HatchState.AutoHatch then
                                    pcall(EggController.goToEgg, eggName)
                                end
                            end)
                        elseif res.Error == "IslandLocked" then
                            HatchState.AutoHatch = false
                            if UI.AutoHatchToggle and UI.AutoHatchToggle.Set then
                                pcall(function() UI.AutoHatchToggle:Set(false, true) end)
                            end
                            notifyThrottled("IslandLocked_" .. tostring(eggName), 10, "Island Locked",
                                string.format("Unlock the island for %s before auto-hatching it!", tostring(eggName)), 6)
                        elseif res.Error == "WrongWorld" then
                            Runtime.lastHatchSent = 0
                            debugWarn("AutoHatch", "Server returned WrongWorld for " .. tostring(eggName) .. " - re-traveling.")
                            task.defer(function()
                                if isCurrentGeneration() and HatchState.AutoHatch then
                                    pcall(EggController.goToEgg, eggName)
                                end
                            end)
                        elseif res.Error == "Cancelled" then
                            Runtime.lastHatchSent = 0
                        elseif err ~= "" then
                            debugWarn("AutoHatch", string.format("EggHatchResult refused (%s): %s", tostring(eggName), err))
                            notifyThrottled("HatchRefused_" .. err, 15, "Hatch Notice",
                                string.format("%s: %s", tostring(eggName), err), 5)
                        end
                    end
                end))
            end)
        end
    end

    -- Live Hatch Speed Display Updater
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            local waitCadence = (OptimizationState and OptimizationState.CpuSaver) and 3.0 or 1.0
            task.wait(waitCadence)
            pcall(function()
                if UI.updateHatchSpeedDisplay then
                    UI.updateHatchSpeedDisplay()
                end
            end)
        end
    end)

    -- 4. Auto Hatch Worker
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            if not HatchState.AutoHatch or KaitunState.Enabled then
                task.wait(0.5)
            else
                task.wait(CONFIG.HatchLoopDelay)
                local neededSlots = (HatchState.HatchCount == 8) and 8 or ((HatchState.HatchCount == 3) and 3 or 1)
                local ownedCount, maxStorage, freeSlots = getPetStorageInfo()
                if freeSlots < neededSlots and (HatchState.HatchCount ~= "Auto" or freeSlots < 1) then
                    HatchState.AutoHatch = false
                    if UI.AutoHatchToggle and UI.AutoHatchToggle.Set then
                        pcall(function() UI.AutoHatchToggle:Set(false) end)
                    end
                    safeNotify({
                        title = "Inventory Full!",
                        content = string.format("Storage is full (%d/%d). This hatch needs %d free slot(s) - please delete or craft pets to keep hatching!", ownedCount, maxStorage, neededSlots),
                        duration = 6
                    })
                else
                    local now = os.clock()
                    local targetDelay = HatchState.HatchDelay or CONFIG.HatchCooldown
                    if HatchState.AutoSpeed then
                        targetDelay = getAutoHatchDelay()
                    end

                    if Runtime.isHatchingBusy and (now - Runtime.lastHatchSent > CONFIG.HatchBusyTimeout) then
                        Runtime.isHatchingBusy = false
                        debugWarn("AutoHatch", "isHatchingBusy timed out after 5s - auto-resetting busy flag.")
                    end

                    if (now - Runtime.lastHatchSent >= targetDelay) and not Runtime.isHatchingBusy then
                        pcall(function()
                            local eggName = HatchState.SelectedEgg
                            local data = getPlayerData and getPlayerData() or nil
                            local coins = getCoinsForEgg(eggName)
                            local curLabel = getEggCurrencyLabel(eggName)
                            local eggPrice = 0
                            if Mod.LaunchEggConfig and Mod.LaunchEggConfig[eggName] then
                                eggPrice = Mod.LaunchEggConfig[eggName].Price or 0
                            end

                            local allowX8 = (canUseX8Hatch() == true) and (os.clock() >= (Runtime.noHatch8Until or 0))
                            local actualCount = nil

                            if HatchState.HatchCount == "Auto" then
                                for _, candidateCount in ipairs({ 8, 3, 1 }) do
                                    if (candidateCount ~= 8 or allowX8) and freeSlots >= candidateCount then
                                        if coins >= getTotalEggCost(data, eggName, eggPrice, candidateCount) then
                                            actualCount = candidateCount
                                            break
                                        end
                                    end
                                end
                                if not actualCount then
                                    local cost1 = getTotalEggCost(data, eggName, eggPrice, 1)
                                    if freeSlots >= 1 and coins < cost1 then
                                        notifyThrottled("NeedCoins_" .. tostring(eggName), 15, "Waiting for " .. curLabel,
                                            string.format("%s costs %s %s (You have %s).", tostring(eggName), formatCompact(cost1), curLabel, formatCompact(coins)), 5)
                                    end
                                    return
                                end
                            else
                                local fixedCount = (HatchState.HatchCount == 8 and 8) or (HatchState.HatchCount == 3 and 3) or 1
                                if fixedCount == 8 and not allowX8 then
                                    notifyThrottled("NeedX8_" .. tostring(eggName), 15, "8x Hatch Locked",
                                        "8x Hatch requires x8Egg Gamepass or OctoHatch boost. Switch Hatch Amount to Auto (8x/3x/1x) or 3x/1x.", 6)
                                    return
                                end
                                local fixedCost = getTotalEggCost(data, eggName, eggPrice, fixedCount)
                                if coins < fixedCost then
                                    notifyThrottled("NeedCoins_" .. tostring(eggName), 15, "Waiting for " .. curLabel,
                                        string.format("%dx %s costs %s %s (You have %s).", fixedCount, tostring(eggName), formatCompact(fixedCost), curLabel, formatCompact(coins)), 5)
                                    return
                                end
                                if freeSlots < fixedCount then return end
                                actualCount = fixedCount
                            end

                            local atStand, standErr = EggController.goToEgg(eggName)
                            if not atStand then
                                notifyThrottled("GoToEggFail_" .. tostring(eggName), 10, "Egg Navigation",
                                    string.format("Could not reach %s (%s).", tostring(eggName), tostring(standErr or "Unknown")), 5)
                                return
                            end
                            if Svc.EggService and Svc.EggService:FindFirstChild("RE") and Svc.EggService.RE:FindFirstChild("EggHatchRequested") then
                                Runtime.isHatchingBusy = true
                                Runtime.lastHatchSent = os.clock()
                                if ctx.API.invalidateVelocityMeasurement then
                                    ctx.API.invalidateVelocityMeasurement("Coin spend: Manual Hatch", coins)
                                end
                                Svc.EggService.RE.EggHatchRequested:FireServer({
                                    Egg = eggName,
                                    Count = actualCount,
                                    Auto = false,
                                    Roam = false
                                })
                            end
                        end)
                    end
                end
            end
        end
    end)
end

return EggController
