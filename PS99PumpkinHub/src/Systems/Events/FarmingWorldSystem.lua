-- src/Systems/Events/FarmingWorldSystem.lua
-- Farming World Tab Backend ("FarmingWorld"):
--   - Auto Buy Farm Egg & Farm Supply
--   - Auto Place Farm Egg & Auto Harvest Farm Egg
--   - Auto Feed Farm Pets & Auto Sell Farm Pets
--   - Auto Craft Items/Pets (PetCraftingMachines / PetCraftingMachine_Craft)
--   - Auto Claim Farm Storage (Farming_ClaimStorage)
--   - Auto Claim & Auto Complete Farming Quest Rewards
--   - Auto Buy Farm Pet Slot & Farm Storage Slot
--   - Auto Mail Pixel Rainbow Items (Mailbox: Send)

local FarmingWorldSystem = {}

function FarmingWorldSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local States = ctx.States

    local FarmW = {
        _lastMerchantAt = 0,
        _lastPlotActAt = 0,
        _lastStorageAt = 0,
        _lastQuestAt = 0,
        _lastCraftAt = 0,
        _lastSlotAt = 0,
        _lastMailAt = 0,
    }

    local function getFarmingPlot()
        return Net.GetClientPlot("FarmingWorld")
    end

    local function findFreePlantSpot(plot)
        local model = plot and plot.GetModel and plot:GetModel()
        if not model then return nil end
        local area = model:FindFirstChild("FarmArea", true) or model:FindFirstChild("PlotArea", true) or model:FindFirstChild("Dirt", true) or model:FindFirstChild("Ground", true)
        local cf, size
        if area and area:IsA("BasePart") then
            cf, size = area.CFrame, area.Size
        else
            local okB, bCF, bSz = pcall(model.GetBoundingBox, model)
            if okB then cf, size = bCF, bSz end
        end
        if not cf or not size then return nil end

        local rx = (math.random() - 0.5) * math.min(40, size.X * 0.5)
        local rz = (math.random() - 0.5) * math.min(40, size.Z * 0.5)
        return (cf * CFrame.new(rx, 2, rz)).Position
    end

    local function stepMerchantsAndSell(plot)
        if not plot or not plot.Save or not plot.Invoke then return end
        if os.clock() - FarmW._lastMerchantAt < 1.5 then return end
        FarmW._lastMerchantAt = os.clock()

        local fTypes = Net.Mod.FarmingTypes
        local pKeys = fTypes and fTypes.PlotKeys or {}

        if States.FarmingWorld.AutoBuyFarmEgg then
            local okS, merch = pcall(plot.Save, plot, pKeys.EggMerchant or "EggMerchant")
            if okS and type(merch) == "table" and type(merch.Items) == "table" then
                for eggId, stock in pairs(merch.Items) do
                    if type(stock) == "number" and stock > 0 then
                        local ok = pcall(plot.Invoke, plot, "BuyEgg", eggId)
                        if ok then
                            ctx.Runtime.Status.Farming = "Bought Farm Egg: " .. tostring(eggId)
                            return
                        end
                    end
                end
            end
        end

        if States.FarmingWorld.AutoBuyFarmSupply then
            local okS, sup = pcall(plot.Save, plot, pKeys.SupplyMerchant or "SupplyMerchant")
            if okS and type(sup) == "table" and type(sup.Items) == "table" then
                for itemId, stock in pairs(sup.Items) do
                    if type(stock) == "number" and stock > 0 then
                        local ok = pcall(plot.Invoke, plot, "BuySupply", itemId)
                        if ok then
                            ctx.Runtime.Status.Farming = "Bought Farm Supply: " .. tostring(itemId)
                            return
                        end
                    end
                end
            end
        end

        if States.FarmingWorld.AutoSellFarmPets and Net.Mod.InventoryCmds and Net.Mod.InventoryCmds.Container then
            local container = Net.Mod.InventoryCmds.Container()
            local save = Net.GetSave()
            local activePets = (save and save.FarmingWorldPets) or {}
            if container then
                local toSell = {}
                local n = 0
                for uid, item in pairs(container:All() or {}) do
                    if item.IsA and item:IsA("Worker") and not activePets[uid] and not (item.IsLocked and item:IsLocked()) then
                        toSell[uid] = item:GetAmount() or 1
                        n = n + 1
                    end
                end
                if n > 0 then
                    local ok = pcall(plot.Invoke, plot, "SellPets", toSell)
                    if ok then
                        ctx.Runtime.Status.Farming = string.format("Sold %d unplaced Farm Pets", n)
                    end
                end
            end
        end
    end

    local function stepHarvestPlantFeed(plot)
        if os.clock() - FarmW._lastPlotActAt < 0.7 then return end
        FarmW._lastPlotActAt = os.clock()

        local M = Net.Mod
        local save = Net.GetSave()
        if not save then return end

        -- Auto Harvest ready eggs
        if States.FarmingWorld.AutoHarvestFarmEgg or States.FarmingWorld.AutoCompleteFarmingQuest then
            for uid, data in pairs(save.FarmingWorldEggs or {}) do
                if type(data) == "table" then
                    local hatchAt = tonumber(data.HatchTime)
                    if not hatchAt or workspace:GetServerTimeNow() >= hatchAt then
                        local ok = Net.NetworkInvoke("Farming_Harvest", uid)
                        if ok then
                            ctx.Runtime.Status.Farming = "Harvested Farm Egg " .. tostring(data.Id or uid)
                            return
                        end
                    end
                end
            end
        end

        local container = M.InventoryCmds and M.InventoryCmds.Container and M.InventoryCmds.Container()
        if not container then return end

        -- Auto Place Farm Egg
        if (States.FarmingWorld.AutoPlaceFarmEgg or States.FarmingWorld.AutoCompleteFarmingQuest) and plot then
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("EggFarm") then
                    local spot = findFreePlantSpot(plot)
                    if spot then
                        local ok = Net.NetworkInvoke("Farming_Plant", spot, uid)
                        if ok then
                            ctx.Runtime.Status.Farming = "Planted Farm Egg: " .. tostring(item:GetId())
                            return
                        end
                    end
                end
            end
        end

        -- Auto Feed Farm Pets
        if States.FarmingWorld.AutoFeedFarmPets then
            local foods = {}
            for _, item in pairs(container:All() or {}) do
                if item.HasInventoryTag and item:HasInventoryTag("FarmFood") and (item:GetAmount() or 0) > 0 then
                    table.insert(foods, { id = item:GetId(), amt = item:GetAmount() })
                end
            end
            if #foods > 0 then
                for petUid, petData in pairs(save.FarmingWorldPets or {}) do
                    if type(petData) == "table" and (tonumber(petData.Feed) or 0) < 90 then
                        local food = foods[1]
                        local ok = Net.NetworkInvoke("Farming_Feed", petUid, food.id, 1)
                        if ok then
                            ctx.Runtime.Status.Farming = "Fed Farm Pet with " .. tostring(food.id)
                            return
                        end
                    end
                end
            end
        end
    end

    local function stepCraftStorageQuestsSlotsMail()
        local M = Net.Mod
        local save = Net.GetSave()
        if not save then return end

        if States.FarmingWorld.AutoClaimFarmStorage and os.clock() - FarmW._lastStorageAt >= 3.5 then
            FarmW._lastStorageAt = os.clock()
            local ok = Net.NetworkInvoke("Farming_ClaimStorage")
            if ok then
                ctx.Runtime.Status.Farming = "Claimed Farm Storage!"
            end
        end

        if States.FarmingWorld.AutoClaimFarmingQuestRewards and os.clock() - FarmW._lastQuestAt >= 3.0 then
            FarmW._lastQuestAt = os.clock()
            local fq = save.NPCQuests and save.NPCQuests.FarmingQuests
            if fq and type(fq.Quests) == "table" then
                local allDone = true
                for i = 1, 3 do
                    local q = fq.Quests[i]
                    if not q or (q.Progress or 0) < (q.Amount or 1) then
                        allDone = false
                        break
                    end
                end
                if allDone then
                    local ok = Net.NetworkInvoke("NPC Quests: Redeem", "FarmingQuests")
                    if ok then
                        ctx.Runtime.Status.Farming = "Redeemed Farming Quests Reward!"
                    end
                end
            end
        end

        if os.clock() - FarmW._lastSlotAt >= 5.0 then
            FarmW._lastSlotAt = os.clock()
            if States.FarmingWorld.AutoBuyFarmPetSlot then
                Net.NetworkInvoke("FarmSlotsMachine_RequestPurchase")
            end
            if States.FarmingWorld.AutoBuyFarmStorageSlot then
                Net.NetworkInvoke("FarmSlotsStorageMachine_RequestPurchase")
            end
        end

        if States.FarmingWorld.AutoCraftItemsPets and os.clock() - FarmW._lastCraftAt >= 4.0 then
            FarmW._lastCraftAt = os.clock()
            local craftDir = M.Directory and M.Directory.PetCraftingMachines
            if type(craftDir) == "table" then
                for mId, mDir in pairs(craftDir) do
                    if type(mDir) == "table" and type(mDir.Recipes) == "table" and (tostring(mId):find("Farm") or tostring(mId):find("Pixel")) then
                        for rIdx, _ in ipairs(mDir.Recipes) do
                            local ok = Net.NetworkInvoke("PetCraftingMachine_Craft", mId, rIdx, 1, { pt = 0, shiny = false })
                            if ok then
                                ctx.Runtime.Status.Farming = "Crafted recipe #" .. tostring(rIdx)
                                return
                            end
                        end
                    end
                end
            end
        end

        if States.FarmingWorld.AutoMailPixelRainbowItems and os.clock() - FarmW._lastMailAt >= 8.0 then
            local target = tostring(States.FarmingWorld.PixelMailUsername or "")
            if target ~= "" and M.InventoryCmds and M.InventoryCmds.Container then
                FarmW._lastMailAt = os.clock()
                local container = M.InventoryCmds.Container()
                if container then
                    for uid, item in pairs(container:All() or {}) do
                        local id = item.GetId and tostring(item:GetId()) or ""
                        if id:find("Pixel Rainbow", 1, true) and not (item.IsLocked and item:IsLocked()) then
                            local cls = item.Class and item.Class.Name or "Misc"
                            local amt = (item.GetAmount and item:GetAmount()) or 1
                            local ok = Net.NetworkInvoke("Mailbox: Send", target, "Pixel Rainbow Item", cls, uid, amt)
                            if ok then
                                ctx.Runtime.Status.Farming = "Mailed " .. id .. " to " .. target
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    function FarmingWorldSystem.Start()
        Lifecycle.SpawnLoop("FarmingWorldWorker", function()
            local Inst = Net.Mod.InstancingCmds
            if Inst and Inst.IsInInstance and Inst.IsInInstance("FarmingWorld") then
                return 0.55
            end
            return 2.5
        end, function()
            local Inst = Net.Mod.InstancingCmds
            local inFarm = Inst and Inst.IsInInstance and Inst.IsInInstance("FarmingWorld")
            if not inFarm then
                return
            end
            local plot = getFarmingPlot()
            stepMerchantsAndSell(plot)
            stepHarvestPlantFeed(plot)
            stepCraftStorageQuestsSlotsMail()
        end)
    end

    ctx.FarmingWorldSystem = FarmW
    return FarmW
end

return FarmingWorldSystem
