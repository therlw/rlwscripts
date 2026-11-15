-- src/UI/Tabs/UpgradeTab.lua
-- Tab 3: Upgrades & Progression (Gem Skill Tree, Physical Pads & Winter Retained Upgrades)

local UpgradeTab = {}

function UpgradeTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Mod = ctx.Modules
    local ConfigManager = ctx.ConfigManager
    local UpgradeState = ctx.States.Upgrade
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local getPlayerData = ctx.API.getPlayerData
    local getGems = ctx.API.getGems
    local getBuyableSkillUpgrades = ctx.API.getBuyableSkillUpgrades
    local purchaseSkillNode = ctx.API.purchaseSkillNode
    local purchasePhysicalUpgrades = ctx.API.purchasePhysicalUpgrades

    UI.UpgradeTab = Window:CreateTab({ name = "Upgrades", icon = 93364949241311 })
    UI.UpgradeTab:CreateSection({ name = "Gem Upgrades (Spawn Machine / Skill Tree)" })

    UI.GemUpgradeStatusText = nil
    pcall(function()
        UI.GemUpgradeStatusText = UI.UpgradeTab:CreateText({ name = "Status: Scanning Gem Upgrades..." })
    end)

    createBoundToggle(UI.UpgradeTab, {
        name = "Auto Buy Gem Upgrades",
        flag = "AutoSkillTree",
        description = "Automatically purchases affordable upgrades from the Gem Upgrades building (Criticals, Egg Luck, Hatch Speed, Auto Speed, Pet XP, etc.)",
        value = false,
    }, function() return UpgradeState.AutoSkillTree end, function(v) UpgradeState.AutoSkillTree = v end)

    UI.PriorityDropdown = UI.UpgradeTab:CreateDropdown({
        name = "Upgrade Priority",
        flag = "PrioritySkills",
        description = "Select which upgrade branch to prioritize",
        options = {
            "All (Cheapest First)",
            "Egg Upgrades First (Luck & Speed)",
            "Clicking & Speed First",
            "Pet Upgrades First"
        },
        value = UpgradeState.PrioritySkills,
        callback = function(selected)
            local opt = type(selected) == "table" and selected[1] or selected
            if opt then
                UpgradeState.PrioritySkills = opt
            end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("PrioritySkills", UI.PriorityDropdown, function() return UpgradeState.PrioritySkills end, function(v) UpgradeState.PrioritySkills = v end)

    UI.UpgradeTab:CreateButton({
        name = "Buy All Affordable Gem Upgrades Now",
        callback = function()
            local buyable, readyCount = getBuyableSkillUpgrades()
            if readyCount == 0 or #buyable == 0 then
                safeNotify({
                    title = "Gem Upgrades",
                    content = "No affordable gem upgrades right now! (Need more Gems)"
                })
                return
            end

            local boughtCount = 0
            for _, item in ipairs(buyable) do
                local ok = purchaseSkillNode(item.nodeToUnlock)
                if ok then
                    boughtCount = boughtCount + 1
                    task.wait(0.4)
                end
            end

            safeNotify({
                title = "Gem Upgrades",
                content = string.format("Successfully purchased %d upgrades!", boughtCount)
            })
        end
    })

    UI.UpgradeTab:CreateButton({
        name = "View Ready Gem Upgrades",
        callback = function()
            local buyable, readyCount = getBuyableSkillUpgrades()
            local gems = getGems()
            local text = string.format("Current Gems: %s\nReady Upgrades: %d\n", tostring(gems), readyCount)
            if #buyable == 0 then
                text = text .. "\nNone ready right now. Earn more Gems or unlock prerequisite nodes!"
            else
                for _, item in ipairs(buyable) do
                    text = text .. string.format("\n• %s: %s Gems [%s]", item.title, tostring(item.price), item.tag)
                end
            end
            safeNotify({
                title = "Available Gem Upgrades",
                content = string.format("%d upgrades ready! (Details printed to console)", readyCount)
            })
            print("\n--- AVAILABLE GEM UPGRADES ---")
            print(text)
            print("-----------------------------\n")
        end
    })

    UI.UpgradeTab:CreateSection({ name = "Physical Pad Upgrades (+1 Jump, Island Luck & Speed)" })

    createBoundToggle(UI.UpgradeTab, {
        name = "Auto Buy Physical Upgrades",
        flag = "AutoPhysicalUpgrades",
        description = "Automatically buys unlocked Double Jump and Island Luck/Speed pads using Gems or Rift Gems",
        value = false,
    }, function() return UpgradeState.AutoPhysicalUpgrades end, function(v) UpgradeState.AutoPhysicalUpgrades = v end)

    UI.UpgradeTab:CreateButton({
        name = "Buy Affordable Physical Upgrades Now",
        callback = function()
            task.spawn(function()
                local bought = purchasePhysicalUpgrades and purchasePhysicalUpgrades() or 0
                safeNotify({
                    title = "Physical Upgrades",
                    content = (bought > 0) and ("Purchased " .. tostring(bought) .. " physical upgrade(s)!") or "No unlocked affordable physical upgrades right now."
                })
            end)
        end
    })

    UI.UpgradeTab:CreateSection({ name = "Quick Buy Key Skills" })

    local quickSkills = {
        { id = "EggLuck", name = "Egg Luck", desc = "Boosts rare/mythic hatch odds" },
        { id = "HatchSpeed", name = "Hatch Speed", desc = "Cuts down egg hatch animation cooldown" },
        { id = "CriticalClicks", name = "Critical Clicks", desc = "Enables & increases critical tap chance" },
        { id = "ClickPower", name = "Click Power", desc = "Multiplies coins per tap" },
        { id = "AutoSpeed", name = "Auto Click Speed", desc = "Increases autoclicker speed" },
        { id = "PetXP", name = "Pet XP", desc = "Increases pet XP leveling speed" },
        { id = "PetPower", name = "Pet Power", desc = "Multiplies pet damage/rebirth bonus" },
    }

    for _, qs in ipairs(quickSkills) do
        UI.UpgradeTab:CreateButton({
            name = "Buy Next: " .. qs.name,
            callback = function()
                local data = getPlayerData()
                local board = Mod.SkillBoard and Mod.SkillBoard.Build and Mod.SkillBoard.Build(data)
                local stack = board and board.Stacks and board.Stacks[qs.id]
                if not stack then
                    safeNotify({ title = qs.name, content = "Skill data unavailable." })
                    return
                end

                if stack.Level >= stack.MaxLevel then
                    safeNotify({ title = qs.name, content = "Already at MAX level!" })
                    return
                end

                if not stack.CanBuy then
                    local reason = stack.LockReason or (getGems() < stack.Price and string.format("Need %d Gems!", stack.Price) or "Prerequisite locked!")
                    safeNotify({ title = qs.name, content = reason })
                    return
                end

                local ok, res = purchaseSkillNode(stack.NextNode)
                if ok then
                    safeNotify({
                        title = "Upgrade Unlocked!",
                        content = string.format("%s (Lvl %d) unlocked for %d Gems!", stack.Title or stack.Name, stack.Level + 1, stack.Price)
                    })
                else
                    safeNotify({ title = qs.name, content = "Purchase failed: " .. tostring(res) })
                end
            end
        })
    end

    UI.UpgradeTab:CreateSection({ name = "Winter Island Retained Upgrades" })

    createBoundToggle(UI.UpgradeTab, {
        name = "Auto Buy Winter Island Upgrades",
        flag = "AutoRetainedUpgrades",
        description = "Automatically purchases Winter Island retained upgrades when Winter Island is unlocked",
        value = false,
    }, function() return UpgradeState.AutoUpgrades end, function(v) UpgradeState.AutoUpgrades = v end)

    UI.UpgradeTab:CreateText({
        name = "Winter Retained Upgrades",
        text = "• Note: Retained Upgrades require Winter Island + Gems."
    })

    return UpgradeTab
end

return UpgradeTab
