-- src/Systems/Events/FishingWorldSystem.lua
-- Fishing World Tab Backend ("FishingEvent"):
--   - Auto Buy Nearest Fishing Event Egg
--   - Auto Event Fishing (Game KM_Switch Autofish + water cast NV_Probe / WT_Resolve)
--   - Auto Sell Event Fish (EB_Redeem)
--   - Auto Buy Next Event Rod Merchant (EventRodMerchant_Purchase)
--   - Auto Use Event Fishing Scrolls (Luck / Speed / XP)
--   - Auto Use Bucket Of Chum

local FishingWorldSystem = {}

function FishingWorldSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States

    local Fish = {
        _lastEggAt = 0,
        _lastSellAt = 0,
        _lastRodAt = 0,
        _lastConsumeAt = 0,
        _lastAutofishSyncAt = 0,
        _lastCastAt = 0,
    }

    local function isInFishingEvent()
        local Inst = Net.Mod.InstancingCmds
        return Inst and Inst.IsInInstance and Inst.IsInInstance("FishingEvent")
    end

    local function stepConsumables()
        if os.clock() - Fish._lastConsumeAt < 3.0 then return end
        Fish._lastConsumeAt = os.clock()

        local M = Net.Mod
        if not M.ConsumableItem or not M.ConsumableCmds then return end
        local save = Net.GetSave()
        local effects = save and save.Effects or {}
        local buffs = save and save.Buffs or {}

        local function hasActiveBuff(name)
            return (effects[name] ~= nil) or (buffs[name] ~= nil)
        end

        if States.FishingWorld.AutoUseBucketOfChum and not hasActiveBuff("Bucket O' Chum") then
            local okF, found = pcall(function() return M.ConsumableItem("Bucket O' Chum"):FindAny() end)
            local item = okF and found and found[1]
            if item then
                pcall(M.ConsumableCmds.Consume, item, 1)
                ctx.Runtime.Status.Fishing = "Used Bucket O' Chum"
                return
            end
        end

        if States.FishingWorld.AutoUseScrolls then
            for _, scrollName in ipairs(States.FishingWorld.SelectedScrolls or {}) do
                if not hasActiveBuff(scrollName) then
                    local okF, found = pcall(function() return M.ConsumableItem(scrollName):FindAny() end)
                    local item = okF and found and found[1]
                    if item then
                        pcall(M.ConsumableCmds.Consume, item, 1)
                        ctx.Runtime.Status.Fishing = "Used " .. tostring(scrollName)
                        return
                    end
                end
            end
        end
    end

    local function stepSellFish()
        if not States.FishingWorld.AutoSellEventFish then return end
        if os.clock() - Fish._lastSellAt < 4.0 then return end
        Fish._lastSellAt = os.clock()

        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container then return end
        local container = M.InventoryCmds.Container()
        if not container then return end

        local sellPayload = {}
        local count = 0
        for uid, item in pairs(container:All() or {}) do
            if item.IsA and item:IsA("Catch") and not (item.IsLocked and item:IsLocked()) then
                local amt = (item.GetAmount and item:GetAmount()) or 1
                if amt > 0 then
                    sellPayload[uid] = amt
                    count = count + amt
                end
            end
        end

        if count > 0 then
            local ok = Net.NetworkInvoke("EB_Redeem", sellPayload)
            if ok then
                ctx.Runtime.Status.Fishing = string.format("Sold %d Event Fish!", count)
            end
        end
    end

    local function stepBuyNextRod()
        if not States.FishingWorld.AutoBuyNextRod then return end
        if os.clock() - Fish._lastRodAt < 5.0 then return end
        Fish._lastRodAt = os.clock()

        local M = Net.Mod
        local Util = M.EventFishingUtil
        local Cmds = M.EventFishingCmds
        if not Util or type(Util.EventRodMerchant) ~= "table" then return end

        local curLevel = (Cmds and Cmds.GetLevel and Cmds.GetLevel()) or 1
        for mIdx, merchant in pairs(Util.EventRodMerchant) do
            for slotIdx, offer in pairs(merchant) do
                if type(offer) == "table" and offer.Item and offer.Price then
                    local okHas, owned = pcall(offer.Item.HasAny, offer.Item)
                    if okHas and not owned then
                        local okDir, rDir = pcall(Util.GetRodDirectory, offer.Item)
                        local reqLv = (okDir and type(rDir) == "table" and rDir.Level) or 1
                        local okHave, haveCoins = pcall(offer.Price.CountAny, offer.Price)
                        local needCoins = offer.Price:GetAmount() or math.huge
                        if curLevel >= reqLv and okHave and type(haveCoins) == "number" and haveCoins >= needCoins then
                            local okBuy = Net.NetworkInvoke("EventRodMerchant_Purchase", mIdx, slotIdx)
                            if okBuy then
                                ctx.Runtime.Status.Fishing = "Bought Rod: " .. tostring(rDir and rDir.DisplayName or rDir and rDir._id)
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    local function stepNearestFishingEgg()
        if not States.FishingWorld.AutoBuyNearestEgg then return end
        if os.clock() - Fish._lastEggAt < 0.35 then return end

        local M = Net.Mod
        if not M.CustomEggsCmds or not M.EggCmds or not M.CalcEggPricePlayer then return end

        local _, hrp = Utils.getCharacterParts()
        if not hrp then return end

        local bestEgg = nil
        local bestDist = math.huge
        for _, egg in pairs(M.CustomEggsCmds.All() or {}) do
            if type(egg._id) == "string" and string.find(egg._id, "Fishing", 1, true) and egg._position then
                local d = Utils.dist3D(hrp.Position, egg._position)
                if d < bestDist then
                    bestDist = d
                    bestEgg = egg
                end
            end
        end
        if not bestEgg or not bestEgg._dir then return end

        local dir = bestEgg._dir
        local allowCG = bestEgg._allowChargedAndGolden == true
        local okP, unitPrice = pcall(M.CalcEggPricePlayer, dir, nil, not allowCG)
        if not okP or type(unitPrice) ~= "number" or unitPrice <= 0 then return end

        local bal = (M.CurrencyCmds and M.CurrencyCmds.Get and M.CurrencyCmds.Get(dir.currency or "FishingEvent")) or 0
        local maxAllowed = bestEgg._maxEggCount or (M.EggCmds.GetMaxHatch and M.EggCmds.GetMaxHatch(dir)) or 1
        local wanted = (States.FishingWorld.EggAmount == "Max") and maxAllowed or math.min(maxAllowed, tonumber(States.FishingWorld.EggAmount) or 1)
        local count = math.clamp(math.min(wanted, math.floor(bal / unitPrice)), 0, maxAllowed)
        if count <= 0 then return end

        if Utils.flatDist(hrp.Position, bestEgg._position) > 25 then
            Move.MoveTo(bestEgg._position + Vector3.new(0, 0, 5), 14, 3.0)
            return
        end

        Fish._lastEggAt = os.clock()
        local ok = Net.NetworkInvoke("CustomEggs_Hatch", bestEgg._uid, count)
        if ok then
            ctx.Runtime.Status.Fishing = string.format("Hatched %dx %s", count, bestEgg._id)
        end
    end

    local function findWaterSpotNearPlayer()
        local inst = Net.Mod.InstancingCmds and Net.Mod.InstancingCmds.GetModel and Net.Mod.InstancingCmds.GetModel()
        local _, hrp = Utils.getCharacterParts()
        if not hrp then return nil end

        local params = RaycastParams.new()
        params.IgnoreWater = false
        params.FilterType = Enum.RaycastFilterType.Include
        local filter = {}
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then table.insert(filter, terrain) end
        if inst then table.insert(filter, inst) end
        params.FilterDescendantsInstances = filter

        local dirs = {
            hrp.CFrame.LookVector * 26,
            hrp.CFrame.LookVector * 42,
            Vector3.new(28, 0, 0),
            Vector3.new(-28, 0, 0),
            Vector3.new(0, 0, 28),
            Vector3.new(0, 0, -28),
        }
        for _, offset in ipairs(dirs) do
            local origin = hrp.Position + offset + Vector3.new(0, 20, 0)
            local res = workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
            if res and res.Material == Enum.Material.Water then
                return res.Position
            end
        end
        return nil
    end

    local function stepAutoFishing()
        if not States.FishingWorld.AutoEventFishing then return end
        local Cmds = Net.Mod.EventFishingCmds
        local save = Net.GetSave()
        local mode = States.FishingWorld.FishingMode or "Game Autofish + Cast"

        if string.find(mode, "Game Autofish", 1, true) and save and save.FishingEventAutofish ~= true then
            if os.clock() - Fish._lastAutofishSyncAt >= 3.0 then
                Fish._lastAutofishSyncAt = os.clock()
                Net.NetworkFire("KM_Switch")
                ctx.Runtime.Status.Fishing = "Enabled Game Event Autofish"
            end
        end

        if string.find(mode, "Cast", 1, true) and Cmds and Cmds.IsLocalFishing and not Cmds.IsLocalFishing() then
            if os.clock() - Fish._lastCastAt >= 2.2 then
                local spot = findWaterSpotNearPlayer()
                if spot and Cmds.LocalCast then
                    Fish._lastCastAt = os.clock()
                    task.spawn(function()
                        pcall(Cmds.LocalCast, spot, true)
                    end)
                    ctx.Runtime.Telemetry.FishCaught = ctx.Runtime.Telemetry.FishCaught + 1
                    ctx.Runtime.Status.Fishing = "Cast rod at nearby water"
                end
            end
        end
    end

    function FishingWorldSystem.Start()
        Lifecycle.SpawnLoop("FishingWorldWorker", 0.45, function()
            if not isInFishingEvent() then
                if States.FishingWorld.AutoEventFishing or States.FishingWorld.AutoBuyNearestEgg then
                    ctx.Runtime.Status.Fishing = "Waiting: Enter Fishing Event instance"
                end
                return
            end
            stepConsumables()
            stepSellFish()
            stepBuyNextRod()
            stepNearestFishingEgg()
            stepAutoFishing()
        end)
    end

    ctx.FishingWorldSystem = Fish
    return Fish
end

return FishingWorldSystem
