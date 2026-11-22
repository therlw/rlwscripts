-- src/Systems/Farm/AutoTapEngine.lua
-- Upgraded Legit Auto Tap (Farm Tab)
-- Mirrors PS99 Auto Tapper + TapTargetPolicy + BreakableFrontend CPS clamp & reach bounds.

local AutoTapEngine = {}

function AutoTapEngine.Init(ctx)
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local Net = ctx.Net
    local Utils = ctx.Utils
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle

    local Engine = {
        _lastTapAt = 0,
        _cachedInterval = 0.125,
        _cachedIntervalAt = 0,
        _cachedTargetUid = nil,
        _cachedTargetAt = 0,
        _cachedTargetIsTurkey = false,
    }

    local function computeLegitTapInterval()
        local now = os.clock()
        if now - Engine._cachedIntervalAt < 2.0 then
            return Engine._cachedInterval
        end
        Engine._cachedIntervalAt = now

        local M = Net.Mod
        local cps = 8
        if M.EnchantCmds and M.EnchantCmds.GetPower then
            local ok, p = pcall(M.EnchantCmds.GetPower, "Swift Taps")
            if ok and type(p) == "number" and p > 0 then
                cps = math.min(8 * (1 + p / 100), 16)
            end
        end

        if Net.GetFFlag("TapHeroes_FrenzyEnabled", false) == true and M.BoostCmds and M.BoostCmds.GetPower then
            local okB, fPower = pcall(M.BoostCmds.GetPower, "TapHeroesFrenzy")
            if okB and type(fPower) == "number" and fPower > 0 then
                local mult = Net.GetNumberFFlag("TapHeroes_FrenzySpeedMult", 2)
                if mult < 1 then mult = 1 end
                cps = math.min(cps * mult, mult * 16)
            end
        end

        local scale = math.clamp(tonumber(States.Farm.TapRateScale) or 1.0, 0.35, 1.0)
        Engine._cachedInterval = 1 / math.max(1, cps * scale)
        return Engine._cachedInterval
    end

    local function isBreakableTapAllowed(model, ca, dir, pos, disabled, hrpPos, maxDist)
        if not model or not model.Parent then return false, math.huge end
        if (type(dir) == "table" and dir.NoTapping) or disabled then
            return false, math.huge
        end

        -- Respect TapTargetPolicy ManualDamage check unless AutoTapOverManual is explicitly set
        if model:GetAttribute("ManualDamage") == true and model:GetAttribute("AutoTapOverManual") ~= true then
            return false, math.huge
        end

        local isTurkey = (type(ca) == "table" and ca.PumpkinTurkey == true)
        local isPumpkin = (type(ca) == "table" and type(ca.PumpkinPedestal) == "number")
        local mode = States.Farm.TapTargetMode

        if mode == "Pumpkin Only" and not isPumpkin and not isTurkey then
            return false, math.huge
        end

        if not pos then return false, math.huge end

        local flat = Utils.flatDist(hrpPos, pos)
        local dist = (hrpPos - pos).Magnitude
        local limit = maxDist

        if isTurkey then
            limit = math.min(maxDist, Net.GetNumberFFlag("PumpkinTycoon_TurkeyReach", 150))
            return flat <= limit, flat
        elseif isPumpkin then
            limit = Net.GetNumberFFlag("PumpkinTycoon_AutoTapReach", 60)
            return flat <= limit, flat
        end

        return dist <= limit, dist
    end

    local function selectBestTarget()
        local M = Net.Mod
        if not M.BreakableFrontend then return nil end

        local _, hrp = Utils.getCharacterParts()
        if not hrp then return nil end

        local inInst = M.InstancingCmds and M.InstancingCmds.IsInInstance and M.InstancingCmds.IsInInstance()
        local maxDist = ctx.Config.DefaultMaxClickDist or 150
        if M.InstancingCmds and M.InstancingCmds.GetInstanceConfig then
            local okCfg, cfg = pcall(M.InstancingCmds.GetInstanceConfig)
            if okCfg and type(cfg) == "table" then
                maxDist = cfg.AutoTapMaxDistance or cfg.MaxClickDistance or maxDist
            end
        end

        local myPlot = inInst and Net.GetPlotModel and Net.GetPlotModel() or nil
        local plotSuffix = myPlot and ("_" .. myPlot.Name) or nil
        local curBreakZoneId = (inInst and M.MapCmds and M.MapCmds.GetCurrentBreakZone and M.MapCmds.GetCurrentBreakZone()) or nil
        local turkeyPriorityMode = (States.Farm.TapTargetMode == "Best / Turkey Priority")

        local pool = {}
        if inInst then
            for _, cls in ipairs({ "Chest", "Normal" }) do
                local ok, t = pcall(M.BreakableFrontend.AllByInstanceAndClass, cls)
                if ok and type(t) == "table" then
                    for uid, b in pairs(t) do pool[uid] = b end
                end
            end
        else
            local zone = M.MapCmds and M.MapCmds.GetCurrentZone and M.MapCmds.GetCurrentZone()
            if zone then
                for _, cls in ipairs({ "Chest", "Normal" }) do
                    local ok, t = pcall(M.BreakableFrontend.AllByZoneAndClass, zone, cls)
                    if ok and type(t) == "table" then
                        for uid, b in pairs(t) do pool[uid] = b end
                    end
                end
            end
        end

        local priorityTurkey = nil
        local priorityChest = nil
        local nearestUid = nil
        local nearestDist = math.huge

        for uid, brk in pairs(pool) do
            -- Fast raw pre-filter: skip foreign players' breakables in O(1) without Instance calls
            if type(brk) == "table" then
                if rawget(brk, "disableDamage") == true then continue end
                local rawCA = rawget(brk, "clientAttributes")
                local isTurkeyRaw = (type(rawCA) == "table" and rawCA.PumpkinTurkey == true)
                local rawArea = rawget(brk, "areaID")
                if inInst and not isTurkeyRaw then
                    local isPedRaw = (type(rawCA) == "table" and type(rawCA.PumpkinPedestal) == "number")
                    if not isPedRaw and curBreakZoneId and rawArea and rawArea ~= curBreakZoneId then
                        continue
                    elseif plotSuffix and type(rawArea) == "string" and rawArea:match("_%d+$") and rawArea:sub(-#plotSuffix) ~= plotSuffix then
                        continue
                    end
                end
            end

            local model, ca, dir, pos, disabled = Utils.unpackBreakable(brk)
            local okAllowed, dist = isBreakableTapAllowed(model, ca, dir, pos, disabled, hrp.Position, maxDist)
            if okAllowed then
                if turkeyPriorityMode and type(ca) == "table" and ca.PumpkinTurkey == true then
                    priorityTurkey = uid
                    break
                end
                local autoTapRad = model:GetAttribute("AutoTapRadius")
                if type(autoTapRad) == "number" and dist <= autoTapRad then
                    priorityChest = uid
                end
                if dist < nearestDist then
                    nearestDist = dist
                    nearestUid = uid
                end
            end
        end

        local chosen = priorityTurkey or priorityChest or nearestUid
        Engine._cachedTargetIsTurkey = (priorityTurkey ~= nil)
        return chosen, maxDist
    end

    local function isCachedTargetValid(uid, maxDist)
        if not uid then return false end
        local M = Net.Mod
        if not M.BreakableFrontend or not M.BreakableFrontend.Get then return false end
        local okGet, brk = pcall(M.BreakableFrontend.Get, uid)
        if not okGet or not brk then return false end
        local _, hrp = Utils.getCharacterParts()
        if not hrp then return false end
        local model, ca, dir, pos, disabled = Utils.unpackBreakable(brk)
        local okAllowed = isBreakableTapAllowed(model, ca, dir, pos, disabled, hrp.Position, maxDist or (ctx.Config.DefaultMaxClickDist or 150))
        return okAllowed == true
    end

    function Engine.Step()
        if not States.Farm.AutoTap then
            ctx.Runtime.Status.Farm = "Auto Tap off"
            Engine._cachedTargetUid = nil
            return
        end

        local M = Net.Mod
        -- Respect native flying restriction just like Auto Tapper.lua
        local isFlying = M.FlyingCmds and M.FlyingCmds.IsFlying and M.FlyingCmds.IsFlying(LocalPlayer)
        if isFlying then return end

        local interval = computeLegitTapInterval()
        local now = os.clock()
        if now - Engine._lastTapAt < interval then
            return
        end

        local uid = Engine._cachedTargetUid
        if not uid or (now - Engine._cachedTargetAt) >= 0.25 or not isCachedTargetValid(uid) then
            local selected, maxDist = selectBestTarget()
            uid = selected
            Engine._cachedTargetUid = uid
            Engine._cachedTargetAt = now
            if uid and not isCachedTargetValid(uid, maxDist) then
                uid = nil
                Engine._cachedTargetUid = nil
            end
        end

        if not uid then
            ctx.Runtime.Status.Farm = "Auto Tap: scanning breakables in reach..."
            return
        end

        Engine._lastTapAt = now
        ctx.Runtime.Telemetry.TurkeyHits = ctx.Runtime.Telemetry.TurkeyHits + 1
        ctx.Runtime.Status.Farm = string.format("Tapping UID %s (%.1f cps)", tostring(uid), 1 / interval)

        -- Route through game's official AutoClicker_Nearby signal when wired, else Network UnreliableFire
        if not Net.SignalFire("AutoClicker_Nearby", uid) then
            Net.NetworkUnreliableFire("Breakables_PlayerDealDamage", uid)
        end
    end

    function AutoTapEngine.Start()
        local BF = Net.Mod.BreakableFrontend
        if BF and BF.Destroyed and BF.Destroyed.Connect then
            Lifecycle.TrackConnection(BF.Destroyed:Connect(function()
                Engine._cachedTargetUid = nil
                Engine._cachedTargetAt = 0
            end))
        end

        Lifecycle.SpawnLoop("AutoTapEngine", function()
            if not States.Farm.AutoTap then
                return 1.5
            end
            return math.max(0.075, (Engine._cachedInterval or 0.125) - 0.005)
        end, function()
            Engine.Step()
        end)
    end

    ctx.AutoTapEngine = Engine
    return Engine
end

return AutoTapEngine
