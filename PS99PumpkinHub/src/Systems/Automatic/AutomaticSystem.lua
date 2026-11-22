-- src/Systems/Automatic/AutomaticSystem.lua
-- Automatic Tab Backend:
--   - Auto Buy Boosts & Auto Buy Wings Upgrades
--   - Auto Eat Fruits (Normal / Shiny)
--   - Auto Use Toys & Auto Use Potions
--   - Auto Open Gifts & Auto Open Lootboxes
--   - Auto Combine Keys & Auto Open Chests
--   - Auto Spin Wheels
--   - Auto Upgrade Fruits / Potions / Enchants

local AutomaticSystem = {}

function AutomaticSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local States = ctx.States

    local Auto = {
        _lastUpgradeBuyAt = 0,
        _lastConsumableAt = 0,
        _lastOpenAt = 0,
        _lastKeyChestAt = 0,
        _lastWheelAt = 0,
        _lastCraftUpAt = 0,
    }

    local WING_UPGRADE_IDS = {
        "WingsBetterEfficiency",
        "WingsQuickerRechargeTime",
        "WingsFasterHorizontalSpeed",
        "WingsFasterVerticalSpeed",
    }

    local KEY_COMBINE_MAP = {
        { lower = "Crystal Key Lower Half", upper = "Crystal Key Upper Half", remote = "CrystalKey_Combine" },
        { lower = "Secret Key Lower Half", upper = "Secret Key Upper Half", remote = "SecretKey_Combine" },
        { lower = "Tech Key Lower Half", upper = "Tech Key Upper Half", remote = "TechKey_Combine" },
        { lower = "Void Key Lower Half", upper = "Void Key Upper Half", remote = "VoidKey_Combine" },
        { lower = "Fantasy Key Lower Half", upper = "Fantasy Key Upper Half", remote = "FantasyKey_Combine" },
        { lower = "MVP Key Lower Half", upper = "MVP Key Upper Half", remote = "MVPKey_Combine" },
    }

    local GIFT_IDS = {
        ["Gift Bag"] = true,
        ["Large Gift Bag"] = true,
        ["Diamond Gift Bag"] = true,
        ["Global Event Gift"] = true,
    }

    local function stepUpgradesAndWings()
        if os.clock() - Auto._lastUpgradeBuyAt < 3.5 then return end
        Auto._lastUpgradeBuyAt = os.clock()
        local M = Net.Mod

        if States.Automatic.AutoBuyBoosts then
            -- 1. Zone upgrades (Coins, Luck, Pet Damage, etc.) via UpgradeCmds
            if M.UpgradeCmds and M.UpgradeCmds.All and M.UpgradeCmds.CanInteractWith and M.UpgradeCmds.Purchase then
                for _, upg in pairs(M.UpgradeCmds.All() or {}) do
                    if type(upg) == "table" and upg.UpgradeID and upg.Zone then
                        local okCan, can = pcall(M.UpgradeCmds.CanInteractWith, upg.UpgradeID, upg.Zone)
                        if okCan and can then
                            local ok = pcall(M.UpgradeCmds.Purchase, upg.UpgradeID, upg.Zone)
                            if ok then
                                ctx.Runtime.Status.Automatic = "Bought Upgrade: " .. tostring(upg.UpgradeID)
                                break
                            end
                        end
                    end
                end
            end
            -- 2. Boost Exchange if BoostExchangeCmds & items available
            if M.BoostExchangeCmds and M.BoostExchangeCmds.AddBoost then
                if Net.GetMiscCount("Millionaire Bucks") > 0 then
                    pcall(M.BoostExchangeCmds.AddBoost, "Luck", 1)
                end
            end
        end

        if States.Automatic.AutoBuyWingsUpgrades and M.EventUpgradeCmds and M.EventUpgradeCmds.Purchase then
            for _, wId in ipairs(WING_UPGRADE_IDS) do
                local ok = pcall(M.EventUpgradeCmds.Purchase, wId)
                if ok then
                    ctx.Runtime.Status.Automatic = "Checked Wings Upgrade: " .. wId
                end
            end
        end
    end

    local function stepConsumablesFruitsToysPotions()
        if os.clock() - Auto._lastConsumableAt < 2.0 then return end
        Auto._lastConsumableAt = os.clock()
        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container then return end
        local container = M.InventoryCmds.Container()
        if not container then return end

        -- Auto Eat Fruits (Normal / Shiny)
        if States.Automatic.AutoEatFruits and M.FruitCmds and M.FruitCmds.Consume and M.FruitCmds.GetMaxConsume then
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("Fruit") then
                    local isShiny = (item.IsShiny and item:IsShiny() == true)
                    if not isShiny or States.Automatic.EatShinyFruits then
                        local okMax, maxAmt = pcall(M.FruitCmds.GetMaxConsume, uid)
                        if okMax and type(maxAmt) == "number" and maxAmt > 0 then
                            pcall(M.FruitCmds.Consume, uid, math.min(maxAmt, 5))
                            ctx.Runtime.Status.Automatic = "Ate Fruit: " .. tostring(item:GetId())
                            break
                        end
                    end
                end
            end
        end

        -- Auto Use Toys
        if States.Automatic.AutoUseToys then
            if Net.GetMiscCount("Toy Ball") > 0 then Net.NetworkInvoke("ToyBall_Consume", 1) end
            if Net.GetMiscCount("Toy Bone") > 0 then Net.NetworkInvoke("ToyBone_Consume", 1) end
            if Net.GetMiscCount("Squeaky Toy") > 0 then Net.NetworkInvoke("SqueakyToy_Consume", 1) end
        end

        -- Auto Use Potions
        if States.Automatic.AutoUsePotions and M.PotionCmds and M.PotionCmds.Consume and M.PotionCmds.Has then
            local minTier = tonumber(States.Automatic.PotionMinTier) or 1
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("Potion") and (item.GetTier and item:GetTier() or 1) >= minTier then
                    local pid = item:GetId()
                    local has, activeTier = pcall(M.PotionCmds.Has, pid)
                    if not has or not activeTier or (item:GetTier() > activeTier) then
                        pcall(M.PotionCmds.Consume, uid, 1)
                        ctx.Runtime.Status.Automatic = string.format("Used Potion: %s T%d", tostring(pid), item:GetTier() or 1)
                        break
                    end
                end
            end
        end
    end

    local function stepOpenGiftsAndLootboxes()
        if os.clock() - Auto._lastOpenAt < 1.2 then return end
        if not States.Automatic.AutoOpenGifts and not States.Automatic.AutoOpenLootboxes then return end
        Auto._lastOpenAt = os.clock()

        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container or not M.LootboxCmds then return end
        local container = M.InventoryCmds.Container()
        if not container then return end

        local completionId = (M.PT_Buttons and M.PT_Buttons.COMPLETION_GIFT) or "Flannel Gift"
        for _, item in pairs(container:All() or {}) do
            if item.IsA and item:IsA("Lootbox") and item:GetId() ~= completionId then
                local id = tostring(item:GetId())
                local isGift = GIFT_IDS[id] or id:find("Gift", 1, true) ~= nil or id:find("Present", 1, true) ~= nil
                local wanted = (isGift and States.Automatic.AutoOpenGifts) or ((not isGift) and States.Automatic.AutoOpenLootboxes)
                if wanted then
                    local amt = math.min(item:GetAmount() or 1, 8)
                    local ok = pcall(M.LootboxCmds.Open, item, amt)
                    if ok then
                        ctx.Runtime.Status.Automatic = string.format("Opened %dx %s", amt, id)
                        break
                    end
                end
            end
        end
    end

    local function stepKeysChestsWheels()
        if os.clock() - Auto._lastKeyChestAt >= 2.5 then
            Auto._lastKeyChestAt = os.clock()
            if States.Automatic.AutoCombineKeys then
                for _, def in ipairs(KEY_COMBINE_MAP) do
                    local cLow = Net.GetMiscCount(def.lower)
                    local cUp = Net.GetMiscCount(def.upper)
                    local count = math.min(cLow, cUp)
                    if count > 0 then
                        local ok = Net.NetworkInvoke(def.remote, count)
                        if ok then
                            ctx.Runtime.Status.Automatic = "Combined " .. tostring(count) .. "x Keys (" .. def.remote .. ")"
                            break
                        end
                    end
                end
            end

            if States.Automatic.AutoOpenChests then
                local Inst = Net.Mod.InstancingCmds
                local curInst = Inst and Inst.GetInstanceID and Inst.GetInstanceID()
                if curInst == "CrystalKeyCastle" and Net.GetMiscCount("Crystal Key") > 0 then
                    Net.NetworkInvoke("CrystalKey_Unlock", 1)
                elseif Net.GetMiscCount("Tech Key") > 0 and curInst == "TechChest" then
                    Net.NetworkInvoke("TechKey_Unlock", 1)
                elseif Net.GetMiscCount("Void Key") > 0 and curInst == "VoidChest" then
                    Net.NetworkInvoke("VoidKey_Unlock", 1)
                elseif Net.GetMiscCount("Fantasy Key") > 0 and curInst == "FantasyChest" then
                    Net.NetworkInvoke("FantasyKey_Unlock", 1)
                end
            end
        end

        if States.Automatic.AutoSpinWheels and os.clock() - Auto._lastWheelAt >= 2.0 then
            Auto._lastWheelAt = os.clock()
            local wheels = Net.Mod.Directory and Net.Mod.Directory.SpinnyWheels
            if type(wheels) == "table" then
                for wId, wDir in pairs(wheels) do
                    if type(wDir) == "table" and wDir.RequiredItem and wDir.RequiredItem.CountExact then
                        local okC, cnt = pcall(wDir.RequiredItem.CountExact, wDir.RequiredItem)
                        if okC and type(cnt) == "number" and cnt > 0 then
                            local ok = Net.NetworkInvoke("Spinny Wheel: Request Spin", wId)
                            if ok then
                                ctx.Runtime.Status.Automatic = "Spun Wheel: " .. tostring(wId)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    local function stepUpgradersBulk()
        if os.clock() - Auto._lastCraftUpAt < 3.0 then return end
        if not States.Automatic.AutoUpgradeFruits and not States.Automatic.AutoUpgradePotions and not States.Automatic.AutoUpgradeEnchants then
            return
        end
        Auto._lastCraftUpAt = os.clock()

        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container or not M.Balancing then return end
        local container = M.InventoryCmds.Container()
        if not container then return end

        if States.Automatic.AutoUpgradeFruits then
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("Fruit") and item:GetId() ~= "Rainbow" then
                    local req = 10
                    if (item:GetAmount() or 0) >= req then
                        local isShiny = (item.IsShiny and item:IsShiny() == true)
                        local remote = isShiny and "UpgradeShinyFruitsMachine_Activate" or "UpgradeFruitsMachine_Activate"
                        local ok = Net.NetworkInvoke(remote, { [uid] = req })
                        if ok then
                            ctx.Runtime.Status.Automatic = "Upgraded Fruit: " .. tostring(item:GetId())
                            break
                        end
                    end
                end
            end
        end

        if States.Automatic.AutoUpgradePotions and M.Balancing.CalcPotionsPerTierRequired then
            local batch = {}
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("Potion") then
                    local tier = (item.GetTier and item:GetTier()) or 1
                    local maxT = (item:Directory() and item:Directory().MaxTier) or 10
                    if tier < maxT then
                        local okReq, req = pcall(M.Balancing.CalcPotionsPerTierRequired, tier)
                        if okReq and type(req) == "number" and req > 0 then
                            local times = math.floor((item:GetAmount() or 0) / req)
                            if times > 0 then
                                batch[uid] = times
                            end
                        end
                    end
                end
            end
            if next(batch) then
                local ok = Net.NetworkInvoke("UpgradePotionsMachine_ActivateBulk", batch)
                if ok then
                    ctx.Runtime.Status.Automatic = "Bulk Upgraded Potions!"
                end
            end
        end

        if States.Automatic.AutoUpgradeEnchants and M.Balancing.CalcEnchantsPerTierRequired then
            local batch = {}
            for uid, item in pairs(container:All() or {}) do
                if item.IsA and item:IsA("Enchant") then
                    local tier = (item.GetTier and item:GetTier()) or 1
                    local maxT = (item:Directory() and item:Directory().MaxTier) or 10
                    if tier < maxT and not (item.IsLocked and item:IsLocked()) then
                        local okReq, req = pcall(M.Balancing.CalcEnchantsPerTierRequired, tier)
                        if okReq and type(req) == "number" and req > 0 then
                            local times = math.floor((item:GetAmount() or 0) / req)
                            if times > 0 then
                                batch[uid] = times
                            end
                        end
                    end
                end
            end
            if next(batch) then
                local ok = Net.NetworkInvoke("UpgradeEnchantsMachine_ActivateBulk", batch)
                if ok then
                    ctx.Runtime.Status.Automatic = "Bulk Upgraded Enchants!"
                end
            end
        end
    end

    function AutomaticSystem.Start()
        Lifecycle.SpawnLoop("AutomaticWorker", 0.85, function()
            stepUpgradesAndWings()
            stepConsumablesFruitsToysPotions()
            stepOpenGiftsAndLootboxes()
            stepKeysChestsWheels()
            stepUpgradersBulk()
        end)
    end

    ctx.AutomaticSystem = Auto
    return Auto
end

return AutomaticSystem
