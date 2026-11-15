-- src/Systems/Automation/FarmWorkers.lua
-- High-Performance Auto Tap (~13.3 taps/s Upvalue Patcher + Safe Fallback) & Auto Rebirth Worker

local FarmWorkers = {}

function FarmWorkers.Init(ctx)
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local Runtime = ctx.Runtime
    local debugLog = ctx.Utils.debugLog

    local function optimizeTapControllerCooldown()
        if Runtime.tapControllerOptimized then return end
        local patched = false
        pcall(function()
            if Mod.TapController and type(Mod.TapController.Tap) == "function" and debug and debug.getupvalues and debug.setupvalue then
                local uvs = debug.getupvalues(Mod.TapController.Tap)
                local innerFn = uvs and uvs[1]
                if type(innerFn) == "function" then
                    local innerUvs = debug.getupvalues(innerFn)
                    for i, v in ipairs(innerUvs) do
                        if type(v) == "number" then
                            local matches = false
                            for _, orig in ipairs(CONFIG.OriginalTapCooldowns) do
                                if math.abs(v - orig) < 0.005 then matches = true; break end
                            end
                            if matches or math.abs(v - CONFIG.TapLoopDelay) < 0.005 then
                                debug.setupvalue(innerFn, i, CONFIG.TapLoopDelay)
                                patched = true
                                Runtime.tapControllerOptimized = true
                                break
                            end
                        end
                    end
                end
            end
        end)

        if not patched and Mod.TapController and type(Mod.TapController.Tap) == "function" and not Mod.TapController._RLW_Hooked then
            pcall(function()
                local originalTap = Mod.TapController.Tap
                Mod.TapController._RLW_OriginalTap = originalTap
                Mod.TapController._RLW_Hooked = true
                Mod.TapController.Tap = function(...)
                    return originalTap(...)
                end
                debugLog("TapController safe wrapper active (no duplicate remote dispatch)")
                Runtime.tapControllerOptimized = true
            end)
        end
    end

    ctx.API.optimizeTapControllerCooldown = optimizeTapControllerCooldown
    FarmWorkers.optimizeTapControllerCooldown = optimizeTapControllerCooldown
    return FarmWorkers
end

function FarmWorkers.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local AutoFarmState = ctx.States.AutoFarm
    local KaitunState = ctx.States.Kaitun
    local Runtime = ctx.Runtime
    local safeFire = ctx.Utils.safeFire
    local getPlayerData = ctx.API.getPlayerData
    local getCoins = ctx.API.getCoins
    local getRebirthCount = ctx.API.getRebirthCount
    local invalidateVelocityMeasurement = ctx.API.invalidateVelocityMeasurement

    -- 1. High-Performance Auto Tap Worker
    task.spawn(function()
        FarmWorkers.optimizeTapControllerCooldown()
        local lastOptCheck = 0
        local tapBtn = nil
        local tapConnections = nil

        local function resolveTapButton()
            if not tapBtn or not tapBtn.Parent then
                pcall(function()
                    local pg = LocalPlayer and LocalPlayer.PlayerGui
                    local g = pg and pg:FindFirstChild("Game")
                    local b = g and g:FindFirstChild("Bottom")
                    local t = b and b:FindFirstChild("Tap")
                    tapBtn = t and t:FindFirstChild("Button")
                end)
                tapConnections = nil
            end
            if tapBtn and not tapConnections then
                tapConnections = {}
                pcall(function()
                    for _, c in ipairs(getconnections(tapBtn.Activated)) do table.insert(tapConnections, c) end
                    for _, c in ipairs(getconnections(tapBtn.MouseButton1Down)) do table.insert(tapConnections, c) end
                end)
            end
            return tapBtn, tapConnections
        end

        while true do
            if not isCurrentGeneration() then break end
            local isTapping = AutoFarmState.AutoTap or KaitunState.Enabled
            if not isTapping then
                task.wait(0.15)
            else
                task.wait(CONFIG.TapLoopDelay)
                local now = os.clock()
                if not Runtime.tapControllerOptimized and (now - lastOptCheck >= 10.0) then
                    lastOptCheck = now
                    FarmWorkers.optimizeTapControllerCooldown()
                end

                pcall(function()
                    if Mod.TapController and type(Mod.TapController.Tap) == "function" then
                        Mod.TapController.Tap("button")
                    end
                    local _, conns = resolveTapButton()
                    if conns and #conns > 0 then
                        for _, c in ipairs(conns) do c:Fire() end
                    elseif Svc.TapService and Svc.TapService:FindFirstChild("RE") and Svc.TapService.RE:FindFirstChild("TapRequested") then
                        Svc.TapService.RE.TapRequested:FireServer({ Auto = false, Source = "button" })
                    end
                end)
            end
        end
    end)

    -- 2. Auto Rebirth Worker
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            if not AutoFarmState.AutoRebirth or KaitunState.Enabled then
                task.wait(1.5)
            else
                task.wait(1.0)
                pcall(function()
                    local data = getPlayerData()
                    if not data then return end

                    local coins = getCoins()
                    local rebirthCount = getRebirthCount()
                    local currentWorld = Mod.WorldConfig and Mod.WorldConfig.Get and Mod.WorldConfig.Get(data)
                    local worldKey = currentWorld and currentWorld ~= Mod.WorldConfig.Main and currentWorld.Key or nil

                    local targetIndex = 1
                    if AutoFarmState.RebirthMode == "Best Affordable" then
                        for i = 1, 20 do
                            local amount = Mod.RebirthConfig.GetAmountFromIndex(i, worldKey)
                            local price = Mod.RebirthConfig.GetPrice(amount, rebirthCount, nil, worldKey)
                            if coins >= price then
                                targetIndex = i
                            else
                                break
                            end
                        end
                    else
                        local idx = string.match(AutoFarmState.RebirthMode, "Index (%d+)")
                        if idx then
                            targetIndex = tonumber(idx)
                        end
                    end

                    if targetIndex then
                        local amount = Mod.RebirthConfig.GetAmountFromIndex(targetIndex, worldKey)
                        local price = Mod.RebirthConfig.GetPrice(amount, rebirthCount, nil, worldKey)
                        if coins >= price then
                            if invalidateVelocityMeasurement then
                                invalidateVelocityMeasurement("Coin spend: Manual Rebirth", coins)
                            end
                            safeFire(Svc.RebirthService, "RE", "RebirthRequested", { Index = targetIndex })
                        end
                    end
                end)
            end
        end
    end)
end

return FarmWorkers
