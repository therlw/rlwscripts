-- src/Systems/PumpkinTycoon/PumpkinEconomy.lua
-- Handles:
--   - Auto Teleport to Best Pumpkin Egg / Area (Zones 1..8 incl. Part 2)
--   - Auto Buy Nearest Pumpkin Egg (with Intelligent Coin Saving)
--   - Auto Keep Pumpkins (Plot NET.SetAutoBreak)
--   - Auto Break Pumpkins (pets break all unkept island pumpkins without player movement)
--   - Auto Buy Merchant Pumpkins (Reworked: uses game Plot NET.SetAutoMerchant OR Selected Bands)
--   - Auto Plant Merchant Pumpkins (Plot NET.SetAutoPlace + NET.PlaceStock)
--   - Auto Buy Selected Hot Cocoa Boosts (Plot NET.CocoaBuyTime)
--   - Auto Use Selected Pumpkin Boosts (Consumables_Consume, Tier III first!)

local PumpkinEconomy = {}

function PumpkinEconomy.Init(ctx)
    local HttpService = ctx.Roblox.HttpService
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States
    local CONFIG = ctx.Config
    local Cooldowns = ctx.Runtime.Cooldowns

    local Econ = {
        _lastMerchantAutoAttemptAt = 0,
        _lastAutoPlaceAttemptAt = 0,
        _lastKeepAttemptAt = 0,
        _lastAutoBreakAt = 0,
    }

    local LADDER_INDEX_BY_NAME = {}
    do
        local ladder = Net.Mod.PT_Ladder and Net.Mod.PT_Ladder.LADDER
        if type(ladder) == "table" then
            for i, name in ipairs(ladder) do
                LADDER_INDEX_BY_NAME[name] = i
            end
        end
        LADDER_INDEX_BY_NAME["Off"] = 0
    end

    local COCOA_KEY_MAP = {
        Coins = "PumpkinTycoonCoins1",
        Damage = "PumpkinTycoonDamage1",
        IslandLuck = "PumpkinTycoonIslandLuck1",
    }

    local BOOST_CONSUMABLE_NAME = {
        Coins = "Patch Coin Boost",
        Damage = "Pumpkin Damage Boost",
        IslandLuck = "Island Luck Boost",
    }

    local function findOwnPlotEggById(eggId)
        local M = Net.Mod
        if not M.CustomEggsCmds or not M.CustomEggsCmds.All then return nil end

        local plotModel = Net.GetPlotModel()
        local plotPos = Utils.getInstancePos(plotModel)
        local best = nil
        local bestDist = math.huge

        for _, egg in pairs(M.CustomEggsCmds.All() or {}) do
            if egg._id == eggId and egg._position then
                local d = plotPos and Utils.dist3D(egg._position, plotPos) or 0
                if d < bestDist then
                    bestDist = d
                    best = egg
                end
            end
        end
        return best
    end

    function Econ.GetUnlockedEggs()
        local M = Net.Mod
        if not M.PT_Types then return {} end

        local buttonsState = Net.PlotSave(M.PT_Types.VAR.Buttons) or {}
        local part2 = Net.IsPart2Enabled()
        local zones = M.PT_Types.ZONES or {}
        local unlocked = {}

        for zoneIdx, z in ipairs(zones) do
            if (z.Part or 1) == 1 or part2 then
                local eggBtnKey = (zoneIdx == 1) and "CocoaCabin_Egg" or (tostring(z.Section) .. "_Egg")
                local isUnlocked = (zoneIdx == 1) or (buttonsState[eggBtnKey] ~= nil and buttonsState[eggBtnKey] ~= false)
                if isUnlocked then
                    local eggObj = findOwnPlotEggById(z.Egg)
                    if eggObj then
                        table.insert(unlocked, {
                            zoneIdx = zoneIdx,
                            zoneName = z.DisplayName,
                            eggName = z.Egg,
                            egg = eggObj,
                            pos = eggObj._position,
                        })
                    end
                end
            end
        end
        return unlocked
    end

    function Econ.GetBestUnlockedEgg()
        local unlocked = Econ.GetUnlockedEggs()
        if #unlocked == 0 then return nil end
        return unlocked[#unlocked]
    end

    function Econ.GetNearestUnlockedEgg()
        local unlocked = Econ.GetUnlockedEggs()
        if #unlocked == 0 then return nil end
        local _, hrp = Utils.getCharacterParts()
        if not hrp then return unlocked[#unlocked] end

        local nearest = nil
        local nearestDist = math.huge
        for _, entry in ipairs(unlocked) do
            if entry.pos then
                local d = Utils.dist3D(hrp.Position, entry.pos)
                if d < nearestDist then
                    nearestDist = d
                    nearest = entry
                end
            end
        end
        return nearest
    end

    --- Computes the closest spot INSIDE the nearest unlocked BreakableZone part to `targetEgg.pos`,
    --- staying within egg hatch range so pets continue breaking breakables continuously while hatching.
    local function resolveEggStandPosition(targetEgg)
        if not targetEgg or not targetEgg.pos then
            return nil, 12, false
        end
        local dir = targetEgg.egg and targetEgg.egg._dir or {}
        local rawRange = tonumber(dir.hatchRange or dir.HatchRange) or 30
        local maxHatch = math.min(27, math.max(12, rawRange - 3))
        local bzParts = Net.GetPumpkinBreakZoneParts()
        local standInZone, withinHatch = Utils.computeBreakableZoneStandPos(targetEgg.pos, bzParts, maxHatch, 3.0)
        if standInZone and withinHatch then
            return standInZone, maxHatch, true
        end
        return targetEgg.pos + Vector3.new(0, 0, 6), 12, false
    end

    local function isAtEggBreakableSpot(hrpPos, targetEgg, standPos, maxHatch, usesBreakZone)
        if not hrpPos or not targetEgg or not targetEgg.pos then
            return false
        end
        if Utils.flatDist(hrpPos, targetEgg.pos) > maxHatch then
            return false
        end
        if not usesBreakZone then
            return Utils.flatDist(hrpPos, standPos) <= 10
        end
        for _, part in ipairs(Net.GetPumpkinBreakZoneParts()) do
            if Utils.isPointInZonePart(part, hrpPos) then
                return true
            end
        end
        return Utils.flatDist(hrpPos, standPos) <= 5
    end

    function Econ.TryTeleportBestEgg()
        local PT = States.PumpkinTycoon
        if not PT.AutoTeleportBestEgg or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastTeleportBestAt < 2.0 then return false end
        if PT.AutoFightTurkey and Move.IsOnTurkeyIsland() then return false end

        local best = Econ.GetBestUnlockedEgg()
        if not best or not best.pos then return false end

        local standPos, maxHatch, usesZone = resolveEggStandPosition(best)
        local _, hrp = Utils.getCharacterParts()
        if hrp and isAtEggBreakableSpot(hrp.Position, best, standPos, maxHatch, usesZone) then
            return false
        end

        Cooldowns.LastTeleportBestAt = os.clock()
        if Move.IsOnTurkeyIsland() then
            Move.ReturnToOwnIsland()
        end
        local ok = Move.MoveTo(standPos, usesZone and 3.8 or 9, 3.0, function()
            return not States.PumpkinTycoon.AutoTeleportBestEgg
        end)
        if ok then
            ctx.Runtime.Status.Event = "At Best Egg (" .. (usesZone and "in BreakableZone" or "near pad") .. "): " .. best.eggName
        end
        return ok
    end

    function Econ.TryBuyNearestEgg()
        local PT = States.PumpkinTycoon
        if not PT.AutoBuyNearestEgg or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastEggHatchAt < CONFIG.EggHatchCooldown then return false end
        if PT.AutoFightTurkey and Move.IsOnTurkeyIsland() then return false end

        local M = Net.Mod
        if not M.CalcEggPricePlayer or not M.EggCmds then return false end

        local target = Econ.GetNearestUnlockedEgg()
        if not target or not target.egg or not target.egg._dir then return false end

        local egg = target.egg
        local dir = egg._dir
        if not dir.currency then return false end

        local allowCG = egg._allowChargedAndGolden == true
        local okP, singlePrice = pcall(M.CalcEggPricePlayer, dir, nil, not allowCG)
        if not okP or type(singlePrice) ~= "number" or singlePrice <= 0 then
            return false
        end

        local maxAllowed = egg._maxEggCount or (M.EggCmds.GetMaxHatch and M.EggCmds.GetMaxHatch(dir)) or 1
        local wanted = (PT.EggHatchAmount == "Max") and maxAllowed or math.min(maxAllowed, tonumber(PT.EggHatchAmount) or 1)
        local coins = Net.GetPumpkinCoins()

        -- Intelligent Coin Saving System
        local spendableCoins = coins
        if PT.SmartCoinSaving and ctx.TycoonProgression then
            local nextBtnPrice, nextBtnId = ctx.TycoonProgression.GetNextPriorityButtonPrice()
            if type(nextBtnPrice) == "number" and nextBtnPrice > 0 then
                local reserve = nextBtnPrice * (CONFIG.CoinReserveRatio or 1.0)
                local nearTarget = (nextBtnPrice <= coins * 8) or (singlePrice >= nextBtnPrice * 0.05)
                if nearTarget and (coins - singlePrice < reserve) then
                    ctx.Runtime.Telemetry.CoinSaveReason = string.format("Saving %s for %s", Utils.formatCompact(nextBtnPrice), tostring(nextBtnId))
                    return false
                end
                if coins >= reserve then
                    spendableCoins = math.max(0, coins - reserve)
                end
                ctx.Runtime.Telemetry.CoinSaveReason = nearTarget and ("Surplus OK (" .. tostring(nextBtnId) .. ")") or ("Farm OK (" .. tostring(nextBtnId) .. ")")
            else
                ctx.Runtime.Telemetry.CoinSaveReason = "Island Buttons Done"
            end
        else
            ctx.Runtime.Telemetry.CoinSaveReason = "Disabled"
        end

        local affordableCount = math.floor(spendableCoins / singlePrice)
        local count = math.clamp(math.min(wanted, affordableCount), 0, maxAllowed)
        if count <= 0 then return false end

        if Move.IsOnTurkeyIsland() then
            Move.ReturnToOwnIsland()
        end
        local standPos, maxHatch, usesZone = resolveEggStandPosition(target)
        local _, hrp = Utils.getCharacterParts()
        if not hrp or not isAtEggBreakableSpot(hrp.Position, target, standPos, maxHatch, usesZone) then
            local arrived = Move.MoveTo(standPos, usesZone and 3.8 or 10, 3.0, function()
                return not States.PumpkinTycoon.AutoBuyNearestEgg
            end)
            if not arrived then return false end
        end

        Cooldowns.LastEggHatchAt = os.clock()
        local ok, err = Net.NetworkInvoke("CustomEggs_Hatch", egg._uid, count)
        if ok then
            ctx.Runtime.Telemetry.EggsHatched = ctx.Runtime.Telemetry.EggsHatched + count
            ctx.Runtime.Status.Event = string.format("Hatched %dx %s", count, target.eggName)
            return true
        else
            Utils.debugLog("CustomEggs_Hatch", err)
        end
        return false
    end

    function Econ.TrySyncKeepRule()
        local PT = States.PumpkinTycoon
        if not PT.AutoKeepPumpkins or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Econ._lastKeepAttemptAt < 2.0 then return false end

        local M = Net.Mod
        if not M.AutoBreak or not M.PT_Types then return false end

        local desiredRaw = LADDER_INDEX_BY_NAME[PT.KeepRarityRule] or 0
        local maxAllowed = (M.AutoBreak.MaxBelow and M.AutoBreak.MaxBelow()) or desiredRaw
        local desired = math.clamp(desiredRaw, 0, maxAllowed)
        local current = (M.AutoBreak.Below and M.AutoBreak.Below()) or 0

        if current == desired then
            return false
        end

        Econ._lastKeepAttemptAt = os.clock()
        local ok = Net.PlotInvoke(M.PT_Types.NET.SetAutoBreak, desired)
        if ok then
            ctx.Runtime.Status.Event = "Set Pumpkin Keep Rule: " .. tostring(PT.KeepRarityRule)
        end
        return ok == true
    end

    function Econ.TryAutoBreakPumpkins()
        local PT = States.PumpkinTycoon
        if not PT.AutoBreakPumpkins or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Econ._lastAutoBreakAt < CONFIG.AutoBreakLoopInterval then return false end
        if Move.IsOnTurkeyIsland() then return false end

        local M = Net.Mod
        if not M.BreakableFrontend or not M.PlayerPet then return false end

        Econ._lastAutoBreakAt = os.clock()
        local below = (M.AutoBreak and M.AutoBreak.Below and M.AutoBreak.Below()) or 0
        local plotModel = Net.GetPlotModel()
        if not plotModel then return false end

        local okBox, plotCF, plotSize = pcall(plotModel.GetBoundingBox, plotModel)
        local candidates = {}

        local okBrk, chests = pcall(M.BreakableFrontend.AllByInstanceAndClass, "Chest")
        if okBrk and type(chests) == "table" then
            for _, brk in pairs(chests) do
                local model, ca, _, _, disabled = Utils.unpackBreakable(brk)
                if type(ca) == "table" and type(ca.PumpkinPedestal) == "number" and model and model.Parent then
                    local locked = M.AutoBreak and M.AutoBreak.Locked and M.AutoBreak.Locked(ca.PumpkinPedestal)
                    local keptByRule = PT.AutoKeepPumpkins and below > 0 and type(ca.PumpkinRung) == "number" and ca.PumpkinRung >= below
                    local manual = model:GetAttribute("ManualDamage") == true
                    local onOwnIsland = true
                    if okBox and M.PT_Types and M.PT_Types.OnIsland then
                        local okOn, resOn = pcall(M.PT_Types.OnIsland, plotCF, plotSize, model:GetPivot().Position)
                        if okOn then onOwnIsland = resOn == true end
                    end

                    if onOwnIsland and not locked and not keptByRule and not manual and not disabled then
                        table.insert(candidates, model)
                    end
                end
            end
        end

        if #candidates == 0 then return false end

        local pets = M.PlayerPet.GetByPlayer(LocalPlayer) or {}
        if not next(pets) then return false end

        local idx = 1
        local dispatched = 0
        for _, pet in pairs(pets) do
            if pet.AIHold == nil or pet.AIHold == "PumpkinAutoBreak" then
                local curTarget = pet.GetTarget and pet:GetTarget()
                local targetValid = false
                if typeof(curTarget) == "Instance" and curTarget.Parent then
                    for _, c in ipairs(candidates) do
                        if c == curTarget then
                            targetValid = true
                            break
                        end
                    end
                end
                if not targetValid then
                    local assignModel = candidates[idx]
                    idx = (idx % #candidates) + 1
                    pcall(function()
                        if pet.SetAnchored then pet:SetAnchored(false) end
                        if pet.SetTarget then pet:SetTarget(assignModel) end
                    end)
                    dispatched = dispatched + 1
                end
            end
        end
        return dispatched > 0
    end

    function Econ.TryMerchantAndPlant()
        local PT = States.PumpkinTycoon
        if not Net.IsInPumpkinTycoon() then return false end
        local M = Net.Mod
        if not M.PT_Types or not M.Merchant then return false end
        local NET = M.PT_Types.NET

        -- 1. Auto Buy Merchant Pumpkins (Reworked)
        if PT.AutoBuyMerchantPumpkins and M.Merchant.Unlocked and M.Merchant.Unlocked() then
            if PT.AutoBuyMerchantMode == "Game Auto Merchant" then
                if M.Merchant.AutoAllowed and M.Merchant.AutoAllowed() and M.Merchant.AutoOn and not M.Merchant.AutoOn() then
                    if os.clock() - Econ._lastMerchantAutoAttemptAt >= 3.0 then
                        Econ._lastMerchantAutoAttemptAt = os.clock()
                        local ok = Net.PlotInvoke(NET.SetAutoMerchant, true)
                        if ok then
                            ctx.Runtime.Status.Event = "Enabled Game Auto Merchant"
                        end
                    end
                end
            elseif PT.AutoBuyMerchantMode == "Selected Bands" then
                if os.clock() - Cooldowns.LastMerchantBuyAt >= CONFIG.MerchantPurchaseCooldown then
                    local merchData = M.PT_Merchant and M.PT_Merchant.Clean and M.PT_Merchant.Clean(Net.PlotSave(M.PT_Types.VAR.Merchant))
                    local stockData = M.PT_Merchant and M.PT_Merchant.CleanStock and M.PT_Merchant.CleanStock(Net.PlotSave(M.PT_Types.VAR.Stock))
                    local maxSlots = (M.Merchant.Slots and M.Merchant.Slots()) or 5

                    if merchData and type(merchData.Items) == "table" and stockData and #stockData < maxSlots then
                        local selectedSet = Utils.arrayToSet(PT.SelectedMerchantBands)
                        local parsed = nil
                        local rawCfg = Net.GetFFlag("PumpkinTycoon_MerchantBands", nil)
                        if type(rawCfg) == "string" then
                            pcall(function() parsed = HttpService:JSONDecode(rawCfg) end)
                        elseif type(rawCfg) == "table" then
                            parsed = rawCfg
                        end
                        local coins = Net.GetPumpkinCoins()
                        local buyBand = nil
                        for _, band in ipairs(M.PT_Merchant.BANDS or {}) do
                            if selectedSet[band] and (merchData.Items[band] or 0) > 0 then
                                local price = (parsed and parsed[band] and parsed[band].Price)
                                    or (M.PT_Merchant.DEFAULTS and M.PT_Merchant.DEFAULTS[band] and M.PT_Merchant.DEFAULTS[band].Price)
                                    or math.huge
                                if coins >= price then
                                    buyBand = band
                                    break
                                end
                            end
                        end

                        if buyBand then
                            -- Must be within PumpkinTycoon_MerchantRange (20 studs)
                            local range = Net.GetNumberFFlag("PumpkinTycoon_MerchantRange", CONFIG.DefaultMerchantRange)
                            local padPos = Move.FindMachinePad(M.PT_Merchant.MACHINE or "PumpkinMerchant")
                            if padPos then
                                Move.ReturnToOwnIsland()
                                if Move.MoveTo(padPos, math.max(5, range - 3), 3.0) then
                                    Cooldowns.LastMerchantBuyAt = os.clock()
                                    local ok = Net.PlotInvoke(NET.BuyBand, buyBand)
                                    if ok then
                                        ctx.Runtime.Status.Event = "Bought Merchant Pumpkin: " .. buyBand
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 2. Auto Plant Merchant Pumpkins (Plot NET.SetAutoPlace + NET.PlaceStock)
        if PT.AutoPlantMerchantPumpkins and M.Stock then
            if os.clock() - Econ._lastAutoPlaceAttemptAt >= 3.0 then
                local isAutoPlaceOn = M.Stock.AutoPlaceOn and M.Stock.AutoPlaceOn() == true
                if not isAutoPlaceOn then
                    Econ._lastAutoPlaceAttemptAt = os.clock()
                    Net.PlotInvoke(NET.SetAutoPlace, true)
                end
            end

            -- Also plant any leftover stock onto empty unlocked pedestals
            local stock = M.Stock.Stock and M.Stock.Stock() or {}
            local peds = M.Stock.Pedestals and M.Stock.Pedestals() or {}
            if #stock > 0 and #peds > 0 then
                for _, ped in ipairs(peds) do
                    if ped.empty then
                        local bestBand = stock[#stock]
                        Net.PlotInvoke(NET.PlaceStock, ped.index, bestBand)
                        break
                    end
                end
            end
        end
    end

    function Econ.TryBuyCocoaBoosts()
        local PT = States.PumpkinTycoon
        if not PT.AutoBuyCocoaBoosts or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastCocoaBuyAt < CONFIG.CocoaPurchaseCooldown then return false end

        local M = Net.Mod
        if not M.Cocoa or not M.Cocoa.Unlocked or not M.Cocoa.Unlocked() then return false end
        if not M.Util_Cocoa or not M.PT_Types then return false end

        local tankSec = M.Util_Cocoa.TankSeconds and M.Util_Cocoa.TankSeconds() or (720 * 60)
        local stepMin = M.Util_Cocoa.StepMinutes and M.Util_Cocoa.StepMinutes() or 10
        local minRoomMin = math.min(math.max(1, stepMin), math.max(1, math.floor(tankSec / 60)))
        local coins = Net.GetPumpkinCoins()

        -- Pick the selected axis with the LOWEST remaining tank time first so full tanks never starve empty ones,
        -- and quote using affordable minutes (Quote arg #3 is minutes, NOT coins) with at least stepMin missing.
        local best = nil
        for orderIdx, axis in ipairs(PT.SelectedCocoaBoosts or {}) do
            local key = COCOA_KEY_MAP[axis]
            local offer = key and M.Util_Cocoa.Offer and M.Util_Cocoa.Offer(key)
            if key and offer then
                local rem = (M.Cocoa.Remaining and M.Cocoa.Remaining(key)) or 0
                local roomMin = math.floor(math.max(0, tankSec - rem) / 60)
                if roomMin >= minRoomMin then
                    local costPerMin = (M.Util_Cocoa.CostPerMinute and M.Util_Cocoa.CostPerMinute(offer.Tier)) or 100000000
                    local affordableMin = (costPerMin > 0) and math.floor(coins / costPerMin) or 0
                    local wantMin = math.min(roomMin, affordableMin)
                    if wantMin >= 1 then
                        local okQ, quote = pcall(M.Util_Cocoa.Quote, offer, rem, wantMin)
                        local minutes = (okQ and type(quote) == "table" and quote.seconds and (quote.seconds // 60)) or 0
                        local cost = (okQ and type(quote) == "table" and quote.cost) or math.huge
                        if okQ and type(quote) == "table" and not quote.reason and minutes >= 1 and coins >= cost then
                            if not best or rem < best.rem or (rem == best.rem and orderIdx < best.orderIdx) then
                                best = {
                                    axis = axis,
                                    key = key,
                                    rem = rem,
                                    orderIdx = orderIdx,
                                    minutes = minutes,
                                }
                            end
                        end
                    end
                end
            end
        end

        if not best then return false end

        local range = Net.GetNumberFFlag("PumpkinTycoon_CocoaRange", CONFIG.DefaultCocoaRange)
        local padPos = Move.FindMachinePad(M.Util_Cocoa.MACHINE or "PumpkinTycoonCocoaStand")
        if padPos then
            Move.ReturnToOwnIsland()
            if Move.MoveTo(padPos, math.max(5, range - 3), 3.0) then
                Cooldowns.LastCocoaBuyAt = os.clock()
                local ok = Net.PlotInvoke(M.PT_Types.NET.CocoaBuyTime, best.key, best.minutes)
                if ok then
                    ctx.Runtime.Status.Event = string.format("Bought Cocoa Boost %s (+%dm)", best.axis, best.minutes)
                    return true
                end
            end
        end
        return false
    end

    function Econ.TryUsePumpkinBoosts()
        local PT = States.PumpkinTycoon
        if not PT.AutoUsePumpkinBoosts or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastBoostCheckAt < CONFIG.BoostCheckInterval then return false end

        local M = Net.Mod
        if not M.ConsumableItem or not M.ConsumableCmds or not M.BoostCmds or not M.Util_Boosts then
            return false
        end

        Cooldowns.LastBoostCheckAt = os.clock()

        for _, axis in ipairs(PT.SelectedPumpkinBoosts or {}) do
            local itemName = BOOST_CONSUMABLE_NAME[axis]
            if itemName then
                -- Check highest tier available in bag first: Tier III -> Tier II -> Tier I
                local bestItem = nil
                local bestTier = nil
                local hasHigherActive = false

                for tier = 3, 1, -1 do
                    local boostId = M.Util_Boosts.Id(axis, tier)
                    local timer = (M.BoostCmds.GetTimer and M.BoostCmds.GetTimer(boostId)) or 0
                    local paused = (M.BoostCmds.IsTierPaused and M.BoostCmds.IsTierPaused(boostId)) == true

                    if timer > 6 then
                        -- Any equal or higher tier currently active: stop before falling back to lower tiers
                        hasHigherActive = true
                        break
                    elseif not hasHigherActive and not paused then
                        local found = nil
                        pcall(function()
                            found = M.ConsumableItem(itemName):SetTier(tier):FindAny()
                        end)
                        if found and found[1] then
                            bestItem = found[1]
                            bestTier = tier
                            break
                        end
                    end
                end

                if bestItem and bestTier then
                    local ok, reason = pcall(M.ConsumableCmds.Consume, bestItem, 1)
                    if ok and reason ~= false then
                        ctx.Runtime.Status.Event = string.format("Used %s Tier %d", itemName, bestTier)
                        return true
                    end
                end
            end
        end
        return false
    end

    ctx.PumpkinEconomy = Econ
    ctx.API.getUnlockedEggs = Econ.GetUnlockedEggs
    ctx.API.getBestUnlockedEgg = Econ.GetBestUnlockedEgg
    return Econ
end

return PumpkinEconomy
