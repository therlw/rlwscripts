-- src/Systems/PumpkinTycoon/TycoonProgression.lua
-- Handles:
--   - Auto Buy Pumpkin Tycoon Buttons (Zones 1..8 incl. Part 2 Pine Woods / Maple Creek / Golden Ridge)
--   - Auto Claim Island Completion Reward (Plot NET.Complete)
--   - Auto Rebirth Pumpkin Tycoon (Plot NET.Rebirth)
--   - Auto Buy Selected Pumpkin Upgrades (Plot NET.UpgradeBuy, includes Part 2 upgrade tiers)
--   - Auto Open Flannel Gifts (PumpkinTycoonCmds.Gift.Open)

local TycoonProgression = {}

function TycoonProgression.Init(ctx)
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States
    local CONFIG = ctx.Config
    local Cooldowns = ctx.Runtime.Cooldowns

    local Prog = {}

    function Prog.IsFastRebirthActive()
        local PT = States.PumpkinTycoon
        if not PT.FastRebirth then
            return false
        end
        local maxTarget = tonumber(PT.MaxRebirths) or 0
        if maxTarget > 0 and Net.GetPumpkinRebirths() >= maxTarget then
            return false
        end
        return true
    end

    local function findButtonPosition(btnId)
        local padsFolder = workspace:FindFirstChild("PumpkinTycoonPads")
        if padsFolder then
            local padModel = padsFolder:FindFirstChild(btnId)
            local pos = Utils.getInstancePos(padModel)
            if pos then return pos end
        end

        local plotModel = Net.GetPlotModel()
        local btns = plotModel and plotModel:FindFirstChild("Buttons")
        if btns then
            local bInst = btns:FindFirstChild(btnId)
            local pos = Utils.getInstancePos(bInst)
            if pos then return pos end
        end

        -- Spot attribute lookup fallback
        local availPos = nil
        if plotModel and Net.Mod.Util_Buttons and Net.Mod.Util_Buttons.ResolvedSpot then
            local btnDef = Net.Mod.Util_Buttons.Get and Net.Mod.Util_Buttons.Get(btnId)
            if btnDef then
                local ok, spot = pcall(Net.Mod.Util_Buttons.ResolvedSpot, plotModel, btnDef)
                if ok and spot then
                    availPos = Utils.getInstancePos(spot)
                end
            end
        end
        return availPos
    end

    function Prog.GetAvailableButtons()
        if not Net.IsInPumpkinTycoon() then return {} end
        local M = Net.Mod
        if not M.Util_Buttons or not M.PT_Types then return {} end

        local state = Net.PlotSave(M.PT_Types.VAR.Buttons)
        if type(state) ~= "table" then state = {} end

        local part2 = Net.IsPart2Enabled()
        local zoneCount = part2 and #M.PT_Types.ZONES or M.PT_Types.PART1_ZONES
        local priceMult = (M.Buttons and M.Buttons.PriceMult and M.Buttons.PriceMult()) or 1

        local ok, avail = pcall(M.Util_Buttons.Available, state, zoneCount, part2, priceMult)
        if not ok or type(avail) ~= "table" then
            return {}
        end

        local fastRebirth = Prog.IsFastRebirthActive()
        local rows = {}
        for _, btn in ipairs(avail) do
            -- Fast Rebirth skips the 2 optional end buttons (Zone8_Cannon & Zone8_RebirthShrine, ~9.94T total)
            if not (fastRebirth and btn.Optional == true) then
                local price = 0
                local okP, p = pcall(M.Util_Buttons.Price, btn, priceMult)
                if okP and type(p) == "number" then price = p end
                table.insert(rows, {
                    def = btn,
                    id = btn.Id,
                    zone = btn.Zone or 1,
                    part = btn.Part or 1,
                    price = price,
                    isZoneOrEgg = (string.find(btn.Id, "_Zone$") ~= nil) or (string.find(btn.Id, "_Egg$") ~= nil),
                    isSpecial = btn.Id == "Zone8_Cannon" or btn.Id == "Zone8_RebirthShrine" or btn.Id == "PetNetStore" or btn.Id == "CocoaStand" or btn.Id == "UpgradeMachine" or btn.Id == "Merchant",
                })
            end
        end

        if States.PumpkinTycoon.ButtonPriorityMode == "Zone/Egg First" then
            table.sort(rows, function(a, b)
                if a.isZoneOrEgg ~= b.isZoneOrEgg then
                    return a.isZoneOrEgg
                end
                if a.isSpecial ~= b.isSpecial then
                    return a.isSpecial
                end
                if a.price ~= b.price then
                    return a.price < b.price
                end
                return a.id < b.id
            end)
        else
            table.sort(rows, function(a, b)
                if a.price ~= b.price then
                    return a.price < b.price
                end
                return a.id < b.id
            end)
        end

        return rows
    end

    -- Returns the minimum price of the next prioritized unbought button (used by Smart Coin Saving)
    function Prog.GetNextPriorityButtonPrice()
        local avail = Prog.GetAvailableButtons()
        if #avail == 0 then return nil, nil end
        return avail[1].price, avail[1].id
    end

    function Prog.TryStepButtonsAndReward()
        local PT = States.PumpkinTycoon
        if not Net.IsInPumpkinTycoon() then return false end
        local M = Net.Mod
        if not M.PT_Types or not M.Util_Buttons then return false end

        local NET = M.PT_Types.NET
        local buttonsState = Net.PlotSave(M.PT_Types.VAR.Buttons)
        if type(buttonsState) ~= "table" then buttonsState = {} end
        local fastRebirth = Prog.IsFastRebirthActive()

        -- 1. Check Auto Claim Island Reward (Plot NET.Complete) — skipped during Fast Rebirth to go straight to Rebirth
        if PT.AutoClaimIslandReward and not fastRebirth then
            local ownP2 = Net.OwnPlotPart2()
            local okComp, _, _, ratio = pcall(M.Util_Buttons.CompleteProgress, buttonsState, ownP2)
            local alreadyDone = M.Util_Buttons.Completed and M.Util_Buttons.Completed(buttonsState)
            if okComp and type(ratio) == "number" and ratio >= 1 and not alreadyDone then
                Move.ReturnToOwnIsland()
                local plotModel = Net.GetPlotModel()
                local interact = plotModel and plotModel:FindFirstChild("Interactable")
                local rewardPad = interact and interact:FindFirstChild("CompletionReward")
                local padPos = Utils.getInstancePos(rewardPad)
                if padPos then
                    Move.MoveTo(padPos, 5.5, 3.2)
                end
                local ok = Net.PlotInvoke(NET.Complete)
                if ok then
                    ctx.Runtime.Status.Event = "Claimed Pumpkin Island Completion Reward!"
                end
                return ok == true
            end
        end

        -- 2. Check Auto Buy Buttons (Plot NET.Buy)
        if not (PT.AutoBuyButtons or fastRebirth) then return false end
        if os.clock() - Cooldowns.LastButtonAt < CONFIG.ButtonCooldown then return false end

        local avail = Prog.GetAvailableButtons()
        if #avail == 0 then return false end

        local coins = Net.GetPumpkinCoins()
        local target = avail[1]
        if coins < target.price then
            return false
        end

        Move.ReturnToOwnIsland()
        local pos = findButtonPosition(target.id)
        if pos then
            local arrived = Move.MoveTo(pos, 4.3, 3.0, function()
                return not (States.PumpkinTycoon.AutoBuyButtons or Prog.IsFastRebirthActive())
            end)
            if not arrived then return false end
        end

        -- Re-verify cooldown and state after walk
        if os.clock() - Cooldowns.LastButtonAt < CONFIG.ButtonCooldown then return false end
        Cooldowns.LastButtonAt = os.clock()

        local ok = Net.PlotInvoke(NET.Buy, target.id)
        if ok then
            ctx.Runtime.Telemetry.ButtonsBought = ctx.Runtime.Telemetry.ButtonsBought + 1
            ctx.Runtime.Status.Event = string.format("Bought Button: %s ($%s)", target.id, Utils.formatCompact(target.price))
            return true
        end
        return false
    end

    function Prog.TryAutoRebirth()
        local PT = States.PumpkinTycoon
        local fastRebirth = Prog.IsFastRebirthActive()
        if not (PT.AutoRebirth or fastRebirth) or not Net.IsInPumpkinTycoon() then return false end
        if Net.GetFFlag("PumpkinTycoon_Rebirth", true) ~= true then return false end
        if not Net.OwnPlotPart2() then return false end

        local rebCooldown = math.max(CONFIG.RebirthCooldown, Net.GetNumberFFlag("PumpkinTycoon_RebirthCooldown", 5) + 0.4)
        if os.clock() - Cooldowns.LastRebirthAt < rebCooldown then return false end

        local M = Net.Mod
        local buttonsState = Net.PlotSave(M.PT_Types.VAR.Buttons)
        if type(buttonsState) ~= "table" or not M.Util_Buttons then return false end

        local okP, _, _, ratio = pcall(M.Util_Buttons.RebirthProgress, buttonsState)
        if not okP or type(ratio) ~= "number" or ratio < 1 then return false end

        local maxTarget = tonumber(PT.MaxRebirths) or 0
        if maxTarget > 0 then
            local currentRebirths = Net.GetPumpkinRebirths()
            if currentRebirths >= maxTarget then
                ctx.Runtime.Status.Event = string.format("Rebirth target reached (%d / %d)", currentRebirths, maxTarget)
                return false
            end
        end

        Move.ReturnToOwnIsland()
        local plotModel = Net.GetPlotModel()
        local interact = plotModel and plotModel:FindFirstChild("Interactable")
        -- When Fast Rebirth skips Zone8_RebirthShrine, use the permanent entrance Rebirth pad directly
        local rebirthPad = nil
        if interact then
            if fastRebirth then
                rebirthPad = interact:FindFirstChild("Rebirth") or interact:FindFirstChild("RebirthShrineTouch") or interact:FindFirstChild("TycoonRebirthShrine")
            else
                rebirthPad = interact:FindFirstChild("RebirthShrineTouch") or interact:FindFirstChild("Rebirth") or interact:FindFirstChild("TycoonRebirthShrine")
            end
        end
        local padPos = Utils.getInstancePos(rebirthPad)
        if padPos then
            local okWalk = Move.MoveTo(padPos, 6, 3.5, function()
                return not (States.PumpkinTycoon.AutoRebirth or Prog.IsFastRebirthActive())
            end)
            if not okWalk then return false end
        end

        Cooldowns.LastRebirthAt = os.clock()
        local ok, reason = Net.PlotInvoke(M.PT_Types.NET.Rebirth)
        if ok then
            ctx.Runtime.Telemetry.Rebirths = ctx.Runtime.Telemetry.Rebirths + 1
            ctx.Runtime.Status.Event = "Completed Pumpkin Tycoon Rebirth #" .. tostring(ctx.Runtime.Telemetry.Rebirths)
            if ctx.UI and ctx.UI.safeNotify and CONFIG.Notifications.RebirthAlerts then
                ctx.UI.safeNotify({ title = "Etkinlik Rebirth", content = "Rebirth başarıyla tamamlandı!", force = false })
            end
            return true
        else
            Utils.debugWarn("AutoRebirth", reason)
        end
        return false
    end

    function Prog.TryBuyUpgrades()
        local PT = States.PumpkinTycoon
        local fastRebirth = Prog.IsFastRebirthActive()
        if not (PT.AutoBuyUpgrades or fastRebirth) or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastUpgradeAt < CONFIG.UpgradeCooldown then return false end

        local M = Net.Mod
        if not M.Upgrades or not M.Upgrades.Unlocked or not M.Upgrades.Unlocked() then return false end
        if not M.PT_Upgrades or not M.Util_Upgrades then return false end

        local selectedSet = Utils.arrayToSet(PT.SelectedUpgrades)
        local tokens = Net.GetPumpkinTokens()
        if tokens <= 0 then return false end

        -- During Fast Rebirth, prioritize Patch Coin Payout (PumpkinCoins) then PumpkinDamage first
        local bestTrack = nil
        local bestCost = math.huge
        if fastRebirth then
            for _, priorityTrack in ipairs({ "PumpkinCoins", "PumpkinDamage" }) do
                local tier = M.Upgrades.Tier(priorityTrack) or 0
                local maxTier = M.Util_Upgrades.MaxTier(priorityTrack) or 0
                if tier < maxTier then
                    local cost = M.Upgrades.Cost(priorityTrack, tier + 1)
                    if type(cost) == "number" and tokens >= cost then
                        bestTrack = priorityTrack
                        bestCost = cost
                        break
                    end
                end
            end
        end

        -- Fallback to cheapest affordable selected upgrade not at MaxTier
        if not bestTrack then
            for _, track in ipairs(M.PT_Upgrades.TRACKS or {}) do
                if selectedSet[track] then
                    local tier = M.Upgrades.Tier(track) or 0
                    local maxTier = M.Util_Upgrades.MaxTier(track) or 0
                    if tier < maxTier then
                        local cost = M.Upgrades.Cost(track, tier + 1)
                        if type(cost) == "number" and tokens >= cost and cost < bestCost then
                            bestCost = cost
                            bestTrack = track
                        end
                    end
                end
            end
        end

        if not bestTrack then return false end

        if Move.GetMode() == "Legit Walk" then
            Move.ReturnToOwnIsland()
            local padPos = Move.FindMachinePad(M.PT_Upgrades.MACHINE or "PumpkinTycoonUpgradeMachine")
            if padPos then
                Move.MoveTo(padPos, 16, 3.2)
            end
        end

        Cooldowns.LastUpgradeAt = os.clock()
        local ok = Net.PlotInvoke(M.PT_Types.NET.UpgradeBuy, bestTrack)
        if ok then
            ctx.Runtime.Status.Event = string.format("Upgraded %s (%s Tokens)", bestTrack, Utils.formatCompact(bestCost))
            return true
        end
        return false
    end

    function Prog.TryOpenFlannelGifts()
        local PT = States.PumpkinTycoon
        if not PT.AutoOpenFlannelGifts or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastGiftOpenAt < CONFIG.GiftOpenCooldown then return false end
        if Net.GetFFlag("PumpkinTycoon_Gift", true) ~= true then return false end
        if workspace:GetAttribute("PumpkinTycoonGiftOpener") ~= true then return false end

        local M = Net.Mod
        if not M.LootboxItem or not M.Gift or not M.Util_Gift then return false end

        local giftId = M.Util_Gift.ID or "Flannel Gift"
        local found = nil
        pcall(function()
            found = M.LootboxItem(giftId):FindAny()
        end)
        local item = found and found[1]
        if not item then return false end

        local amt = (item.GetAmount and item:GetAmount()) or 1
        local count = math.clamp(math.floor(math.min(amt, PT.GiftOpenBatch or 8)), 1, 8)

        Cooldowns.LastGiftOpenAt = os.clock()
        local ok, reason = pcall(M.Gift.Open, item, count)
        if ok and reason == true then
            ctx.Runtime.Telemetry.GiftsOpened = ctx.Runtime.Telemetry.GiftsOpened + count
            ctx.Runtime.Status.Event = string.format("Opened %dx %s", count, giftId)
            return true
        end
        return false
    end

    ctx.TycoonProgression = Prog
    ctx.API.getAvailableButtons = Prog.GetAvailableButtons
    return Prog
end

return TycoonProgression
