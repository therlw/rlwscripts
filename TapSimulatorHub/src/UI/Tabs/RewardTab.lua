-- src/UI/Tabs/RewardTab.lua
-- Tab 5: Rewards & Collectibles (Chests, Shiny Stars, Quests, Daily/Wheel & Promo Codes)

local RewardTab = {}

function RewardTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Svc = ctx.Services
    local Runtime = ctx.Runtime
    local RewardState = ctx.States.Reward
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local safeInvoke = ctx.Utils.safeInvoke

    UI.RewardTab = Window:CreateTab({ name = "Rewards", icon = 93364949241311 })
    UI.RewardTab:CreateSection({ name = "Chests & Stars" })

    createBoundToggle(UI.RewardTab, {
        name = "Auto Collect Tap Chests",
        flag = "AutoChests",
        description = "Claims all spawned and ready tap chests across the world",
        value = false,
    }, function() return RewardState.AutoChests end, function(v) RewardState.AutoChests = v end)

    createBoundToggle(UI.RewardTab, {
        name = "Auto Collect Shiny Stars",
        flag = "AutoStars",
        description = "Claims hidden Shiny Stars (24 across World 1 & World 2 incl. Medieval Island) for free mutation boosts",
        value = false,
    }, function() return RewardState.AutoStars end, function(v) RewardState.AutoStars = v end)

    UI.RewardTab:CreateSection({ name = "Quests & Daily Gifts" })

    createBoundToggle(UI.RewardTab, {
        name = "Auto Claim Quests",
        flag = "AutoQuests",
        description = "Instantly claims all finished quests using ClaimAllQuests & ClaimQuest",
        value = false,
    }, function() return RewardState.AutoQuests end, function(v) RewardState.AutoQuests = v end)

    createBoundToggle(UI.RewardTab, {
        name = "Auto Claim Gifts & Wheel",
        flag = "AutoDailyRewards",
        description = "Claims offline rewards, lucky ducky, pet index, and wheel spins",
        value = false,
    }, function() return RewardState.AutoDailyRewards end, function(v) RewardState.AutoDailyRewards = v end)

    createBoundToggle(UI.RewardTab, {
        name = "Auto Catch Lucky Ducky",
        flag = "RewardAutoLuckyDucky",
        description = "Automatically catches the flying Lucky Ducky at the optimal safe flight timing (+1.45s)",
        value = true,
    }, function() return RewardState.AutoLuckyDucky end, function(v) RewardState.AutoLuckyDucky = v end)

    UI.RewardTab:CreateSection({ name = "Promo Codes" })

    local promoCodes = {
        "CASTLE", "WORLD2", "CLANS", "30MVISITS", "HEAVEN", "SPOOKY", "BOO!", "UPDATE", "RELEASE", "TAP", "REBIRTH"
    }

    UI.RewardTab:CreateInput({
        name = "Custom Promo Code",
        placeholder = "e.g. CASTLE",
        value = "",
        callback = function(text)
            Runtime.customCodeText = tostring(text or "")
        end
    })

    UI.RewardTab:CreateButton({
        name = "Redeem Custom Code",
        callback = function()
            local clean = string.gsub(Runtime.customCodeText or "", "^%s*(.-)%s*$", "%1")
            if clean == "" then
                safeNotify({ title = "Promo Code", content = "Please enter a promo code first!" })
                return
            end
            local res = safeInvoke(Svc.CodeService, "RF", "Redeem", clean)
            safeNotify({
                title = "Promo Code: " .. clean,
                content = (type(res) == "table" and (res.Success and "Redeemed successfully!" or tostring(res.Reason or res.Error or "Could not redeem"))) or "Sent redeem request!"
            })
        end
    })

    UI.RewardTab:CreateButton({
        name = "Redeem All Known Promo Codes (Incl. CASTLE)",
        description = "Redeems all known active codes for free totems, potions & boosts",
        callback = function()
            if Svc.CodeService and Svc.CodeService:FindFirstChild("RF") and Svc.CodeService.RF:FindFirstChild("Redeem") then
                local count = 0
                for _, code in ipairs(promoCodes) do
                    local ok = pcall(function()
                        Svc.CodeService.RF.Redeem:InvokeServer(code)
                    end)
                    if ok then count = count + 1 end
                    task.wait(0.2)
                end
                safeNotify({ title = "Codes", content = "Processed " .. tostring(count) .. " promo codes!" })
            end
        end
    })

    return RewardTab
end

return RewardTab
