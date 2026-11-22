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
    }

    local function computeLegitTapInterval()
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
        return 1 / math.max(1, cps * scale)
    end

    local function isBreakableTapAllowed(brk, model, hrpPos, maxDist)
        if type(brk) ~= "table" or not model or not model.Parent then return false, math.huge end
        local dir = brk.dir or brk.directory or {}
        if dir.NoTapping or brk.disableDamage == true or model:GetAttribute("DisableDamage") == true then
            return false, math.huge
        end

        -- Respect TapTargetPolicy ManualDamage check unless AutoTapOverManual is explicitly set
        if model:GetAttribute("ManualDamage") == true and model:GetAttribute("AutoTapOverManual") ~= true then
            return false, math.huge
        end

        local ca = brk.clientAttributes
        local isTurkey = (type(ca) == "table" and ca.PumpkinTurkey == true)
        local isPumpkin = (type(ca) == "table" and type(ca.PumpkinPedestal) == "number")
        local mode = States.Farm.TapTargetMode

        if mode == "Pumpkin Only" and not isPumpkin and not isTurkey then
            return false, math.huge
        end

        local pos = brk.position or Utils.getInstancePos(model)
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
            local model = brk.model
            local okAllowed, dist = isBreakableTapAllowed(brk, model, hrp.Position, maxDist)
            if okAllowed then
                local ca = brk.clientAttributes
                if States.Farm.TapTargetMode == "Best / Turkey Priority" and type(ca) == "table" and ca.PumpkinTurkey == true then
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

        return priorityTurkey or priorityChest or nearestUid
    end

    function Engine.Step()
        if not States.Farm.AutoTap then
            ctx.Runtime.Status.Farm = "Auto Tap off"
            return
        end

        local M = Net.Mod
        -- Respect native flying restriction just like Auto Tapper.lua
        local isFlying = M.FlyingCmds and M.FlyingCmds.IsFlying and M.FlyingCmds.IsFlying(LocalPlayer)
        if isFlying then return end

        local interval = computeLegitTapInterval()
        if os.clock() - Engine._lastTapAt < interval then
            return
        end

        local uid = selectBestTarget()
        if not uid then
            ctx.Runtime.Status.Farm = "Auto Tap: scanning breakables in reach..."
            return
        end

        Engine._lastTapAt = os.clock()
        ctx.Runtime.Telemetry.TurkeyHits = ctx.Runtime.Telemetry.TurkeyHits + 1
        ctx.Runtime.Status.Farm = string.format("Tapping UID %s (%.1f cps)", tostring(uid), 1 / interval)

        -- Route through game's official AutoClicker_Nearby signal when wired, else Network UnreliableFire
        if not Net.SignalFire("AutoClicker_Nearby", uid) then
            Net.NetworkUnreliableFire("Breakables_PlayerDealDamage", uid)
        end
    end

    function AutoTapEngine.Start()
        Lifecycle.SpawnLoop("AutoTapEngine", 0.04, function()
            Engine.Step()
        end)
    end

    ctx.AutoTapEngine = Engine
    return Engine
end

return AutoTapEngine
