-- src/Systems/Worlds/UpgradeManager.lua
-- Retained Upgrades, Gem Skill Tree Unlock & Auto Upgrade Worker

local UpgradeManager = {}

local UPGRADE_LIST = {
    { id = "ClickMultiplier", name = "Click Multiplier", req = "Winter" },
    { id = "HatchSpeed", name = "Hatch Speed", req = "Winter" },
    { id = "FreeAutoClicker", name = "Free Auto Clicker", req = "Forest" },
    { id = "AutoClickerSpeed", name = "Auto Clicker Speed", req = "Winter" },
    { id = "CriticalChance", name = "Critical Chance", req = "Winter" },
    { id = "Teleport", name = "Teleport Upgrade", req = "None" },
}

function UpgradeManager.Init(ctx)
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local getPlayerData = ctx.API.getPlayerData
    local getGems = ctx.API.getGems

    local function tryPurchaseUpgrade(upgradeId)
        local data = getPlayerData()
        if not data or not Mod.UpgradeConfig then return false, "NoData" end

        local def = Mod.UpgradeConfig.Get and Mod.UpgradeConfig.Get(upgradeId)
        if not def then return false, "UnknownDef" end

        local curLvl = data.Upgrades and data.Upgrades[upgradeId] or 0
        local maxLvl = def.LaunchTotal or 1
        if curLvl >= maxLvl then
            return false, "MaxLevel"
        end

        local price = Mod.UpgradeConfig.GetPrice and Mod.UpgradeConfig.GetPrice(upgradeId, curLvl + 1) or 0
        local gems = getGems()
        if gems < price then
            return false, "InsufficientGems", price - gems
        end

        local reqZone = Mod.UpgradeConfig.GetRetainedRequirement and Mod.UpgradeConfig.GetRetainedRequirement(upgradeId, curLvl)
        if reqZone and reqZone ~= "None" then
            local unlockedZones = data.Progression and data.Progression.UnlockedZones
            if not (unlockedZones and unlockedZones[reqZone] == true) then
                return false, "ZoneLocked", reqZone
            end
        end

        if Svc.UpgradeService and Svc.UpgradeService:FindFirstChild("RF") and Svc.UpgradeService.RF:FindFirstChild("Purchase") then
            local ok, res = pcall(function()
                return Svc.UpgradeService.RF.Purchase:InvokeServer({ Name = upgradeId })
            end)
            if ok and type(res) == "table" and res.Success == true then
                return true, "Success", res.Current
            elseif ok and type(res) == "table" then
                return false, res.Reason or "Failed", res.RequiredZone or res.Missing
            else
                return false, "CommError"
            end
        end

        return false, "NoService"
    end

    local function getBuyableSkillUpgrades()
        local data = getPlayerData()
        if not data or not Mod.SkillBoard then return {}, 0 end
        local board = Mod.SkillBoard.Build(data)
        if not board or not board.Stacks then return {}, 0 end

        local buyable = {}
        for id, stack in pairs(board.Stacks) do
            if stack.CanBuy and stack.NextNode then
                table.insert(buyable, {
                    id = id,
                    title = stack.Title or stack.Name,
                    name = stack.Name,
                    tag = stack.Tag or "Upgrade",
                    level = stack.Level or 0,
                    maxLevel = stack.MaxLevel or 1,
                    nodeToUnlock = stack.NextNode,
                    price = stack.Price or 0
                })
            end
        end
        table.sort(buyable, function(a, b) return a.price < b.price end)
        return buyable, board.Ready or #buyable
    end

    local function purchaseSkillNode(nodeName)
        if Svc.SkillTreeService and Svc.SkillTreeService:FindFirstChild("RF") and Svc.SkillTreeService.RF:FindFirstChild("Unlock") then
            local ok, res = pcall(function()
                return Svc.SkillTreeService.RF.Unlock:InvokeServer({ Name = nodeName })
            end)
            if ok and type(res) == "table" and res.Success == true then
                return true, res
            elseif ok and type(res) == "table" then
                return false, res.Reason or "Failed"
            else
                return false, "CommError"
            end
        end
        return false, "NoService"
    end

    ctx.Catalogs.UpgradeList = UPGRADE_LIST
    ctx.API.tryPurchaseUpgrade = tryPurchaseUpgrade
    ctx.API.getBuyableSkillUpgrades = getBuyableSkillUpgrades
    ctx.API.purchaseSkillNode = purchaseSkillNode

    UpgradeManager.UpgradeList = UPGRADE_LIST
    UpgradeManager.tryPurchaseUpgrade = tryPurchaseUpgrade
    UpgradeManager.getBuyableSkillUpgrades = getBuyableSkillUpgrades
    UpgradeManager.purchaseSkillNode = purchaseSkillNode
    return UpgradeManager
end

function UpgradeManager.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local UpgradeState = ctx.States.Upgrade
    local UI = ctx.UI
    local getGems = ctx.API.getGems
    local safeNotify = function(opts)
        if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
    end

    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            task.wait(2.0)
            pcall(function()
                local buyable, readyCount = UpgradeManager.getBuyableSkillUpgrades()
                local gems = getGems()
                if UI.GemUpgradeStatusText and UI.GemUpgradeStatusText.SetTitle then
                    if readyCount > 0 then
                        local cheapest = buyable[1]
                        UI.GemUpgradeStatusText:SetTitle(string.format("Status: %d Ready to Buy! (Next: %s - %d Gems)", readyCount, cheapest.title, cheapest.price))
                    else
                        UI.GemUpgradeStatusText:SetTitle(string.format("Status: Waiting for Gems (Current: %s)", tostring(gems)))
                    end
                end
            end)

            if UpgradeState.AutoSkillTree then
                local buyable = UpgradeManager.getBuyableSkillUpgrades()
                for _, item in ipairs(buyable) do
                    local shouldBuy = true
                    if UpgradeState.PrioritySkills == "Egg Upgrades First (Luck & Speed)" then
                        shouldBuy = (item.tag == "Egg Upgrade")
                    elseif UpgradeState.PrioritySkills == "Clicking & Speed First" then
                        shouldBuy = (item.tag == "Clicking Upgrade")
                    elseif UpgradeState.PrioritySkills == "Pet Upgrades First" then
                        shouldBuy = (item.tag == "Pet Upgrade")
                    end

                    if shouldBuy then
                        local ok = UpgradeManager.purchaseSkillNode(item.nodeToUnlock)
                        if ok then
                            pcall(function()
                                safeNotify({
                                    title = "Gem Upgrade Unlocked!",
                                    content = string.format("%s (Lvl %d) unlocked for %d Gems!", item.title, item.level + 1, item.price)
                                })
                            end)
                            task.wait(0.5)
                        end
                    end
                end
            end

            if UpgradeState.AutoUpgrades then
                for _, upg in ipairs(UPGRADE_LIST) do
                    local ok, _, extra = UpgradeManager.tryPurchaseUpgrade(upg.id)
                    if ok then
                        pcall(function()
                            safeNotify({
                                title = "Auto Upgrade",
                                content = string.format("%s upgraded to Level %s!", upg.name, tostring(extra))
                            })
                        end)
                        task.wait(0.5)
                    end
                end
            end

            if UpgradeState.AutoPhysicalUpgrades and ctx.API.purchasePhysicalUpgrades then
                local boughtPhys = ctx.API.purchasePhysicalUpgrades()
                if boughtPhys > 0 and CONFIG.Notifications.UpgradeAlerts then
                    safeNotify({
                        title = "Physical Upgrades",
                        content = string.format("Purchased %d physical upgrade(s)!", boughtPhys)
                    })
                end
            end
        end
    end)
end

return UpgradeManager
