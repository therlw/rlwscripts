-- src/Systems/Pets/EggController.lua
-- Egg Stand Positioning, Cross-World Travel & Rate-Limit Protected Auto Hatch Worker

local EggController = {}

function EggController.Init(ctx)
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CONFIG = ctx.Config
    local HatchState = ctx.States.Hatch
    local getInstancePosition = ctx.Utils.getInstancePosition
    local getInstanceCFrame = ctx.Utils.getInstanceCFrame
    local getPlayerData = ctx.API.getPlayerData
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay

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

    local function getEggStandCFrame(eggName)
        local eggModel = findEggModelInWorkspace(eggName)
        if not eggModel then return nil end

        local eggInst = eggModel:FindFirstChild("Egg") or eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart")
        local eggCenter = getInstancePosition(eggInst)
        local eggCF = getInstanceCFrame(eggInst)
        if not eggCenter then return nil end

        local sign = eggModel:FindFirstChild("EggCostSign")
        local signInst = sign and (sign:FindFirstChild("Sign") or sign:FindFirstChildWhichIsA("BasePart"))
        local signCF = getInstanceCFrame(signInst)

        local forwardDir = nil
        if signCF then
            local lv = signCF.LookVector
            forwardDir = Vector3.new(lv.X, 0, lv.Z)
        end

        if (not forwardDir or forwardDir.Magnitude < 0.1) and eggCF then
            local lv = eggCF.LookVector
            forwardDir = Vector3.new(lv.X, 0, lv.Z)
        end

        if not forwardDir or forwardDir.Magnitude < 0.1 then
            forwardDir = Vector3.new(0, 0, 1)
        else
            forwardDir = forwardDir.Unit
        end

        local standPos = Vector3.new(eggCenter.X, eggCenter.Y, eggCenter.Z) + (forwardDir * 6.5)

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { eggModel, LocalPlayer.Character }
        local hit = workspace:Raycast(Vector3.new(standPos.X, eggCenter.Y + 4, standPos.Z), Vector3.new(0, -30, 0), rayParams)
        local floorY = hit and hit.Position.Y or (eggCenter.Y - 4.5)

        local targetPosition = Vector3.new(standPos.X, floorY + 3.0, standPos.Z)
        return CFrame.new(targetPosition, Vector3.new(eggCenter.X, targetPosition.Y, eggCenter.Z))
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

        local data = getPlayerData()
        local curWorld = data and data.Progression and data.Progression.World or "Main"
        local curIsland = data and data.Progression and data.Progression.Island or "Spawn"
        if curWorld ~= targetWorld or curIsland ~= targetIsland then
            local dest = (targetWorld == "TimeRift" and targetIsland == "Spawn") and "World 2 Spawn" or targetIsland
            if ctx.API.travelToIsland then
                ctx.API.travelToIsland(dest)
            end
            task.wait(1.0)
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
            if dist > 2.5 then
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
    local getCoins = ctx.API.getCoins
    local getPetStorageInfo = ctx.API.getPetStorageInfo
    local hasX8Gamepass = ctx.API.hasX8Gamepass
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay
    local safeNotify = function(opts)
        if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
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
                            local coins = getCoins()
                            local eggPrice = 0
                            if Mod.LaunchEggConfig and Mod.LaunchEggConfig[HatchState.SelectedEgg] then
                                eggPrice = Mod.LaunchEggConfig[HatchState.SelectedEgg].Price or 0
                            end

                            local actualCount = 1
                            if HatchState.HatchCount == "Auto" then
                                if hasX8Gamepass() and coins >= (eggPrice * 8) and freeSlots >= 8 then
                                    actualCount = 8
                                elseif coins >= (eggPrice * 3) and freeSlots >= 3 then
                                    actualCount = 3
                                elseif coins >= eggPrice and freeSlots >= 1 then
                                    actualCount = 1
                                else
                                    return
                                end
                            elseif HatchState.HatchCount == 8 then
                                if coins < (eggPrice * 8) or freeSlots < 8 then return end
                                actualCount = 8
                            elseif HatchState.HatchCount == 3 then
                                if coins < (eggPrice * 3) or freeSlots < 3 then return end
                                actualCount = 3
                            else
                                if coins < eggPrice or freeSlots < 1 then return end
                                actualCount = 1
                            end

                            local atStand = EggController.goToEgg(HatchState.SelectedEgg)
                            if atStand and Svc.EggService and Svc.EggService:FindFirstChild("RE") and Svc.EggService.RE:FindFirstChild("EggHatchRequested") then
                                Runtime.isHatchingBusy = true
                                Runtime.lastHatchSent = os.clock()
                                if ctx.API.invalidateVelocityMeasurement then
                                    ctx.API.invalidateVelocityMeasurement("Coin spend: Manual Hatch", coins)
                                end
                                Svc.EggService.RE.EggHatchRequested:FireServer({
                                    Egg = HatchState.SelectedEgg,
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
