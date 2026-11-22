-- src/UI/Tabs/MainTab.lua
-- Main Tab: Free Gifts, Rank Rewards (Rewards Only), Forever Pack, Balloons, Stairway, Treehouse & Crystal Castle

local MainTab = {}

function MainTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Main = ctx.States.Main
    local createBoundToggle = UI.createBoundToggle

    local tab = Window:CreateTab({ name = "Main", icon = 93364949241311 })
    UI.MainTab = tab

    tab:CreateSection({ name = "Main World & Rewards" })

    UI.MainStatusText = tab:CreateText({
        name = "Main Status",
        text = "Main features idle",
    })

    createBoundToggle(tab, {
        name = "Anti-AFK (Idle Tracking + Engine)",
        flag = "MainAntiAFK",
        description = "Prevents Roblox 20m kick and PS99 15m/16.6m Move Server idle transfer",
        value = Main.AntiAFK,
    }, function() return Main.AntiAFK end, function(v) Main.AntiAFK = v end)

    createBoundToggle(tab, {
        name = "Auto Claim Free Gifts",
        flag = "MainAutoFreeGifts",
        value = Main.AutoClaimFreeGifts,
    }, function() return Main.AutoClaimFreeGifts end, function(v) Main.AutoClaimFreeGifts = v end)

    createBoundToggle(tab, {
        name = "Auto Claim Rank Rewards",
        flag = "MainAutoRankRewards",
        description = "Claims unlocked Rank Star Rewards only (Auto Rank Quests excluded)",
        value = Main.AutoClaimRankRewards,
    }, function() return Main.AutoClaimRankRewards end, function(v) Main.AutoClaimRankRewards = v end)

    createBoundToggle(tab, {
        name = "Auto Claim Default Forever Pack Free Gift",
        flag = "MainAutoForeverPack",
        value = Main.AutoClaimForeverPack,
    }, function() return Main.AutoClaimForeverPack end, function(v) Main.AutoClaimForeverPack = v end)

    tab:CreateSection({ name = "World Encounters & Instances" })

    createBoundToggle(tab, {
        name = "Auto Pop Balloons",
        flag = "MainAutoBalloons",
        value = Main.AutoPopBalloons,
    }, function() return Main.AutoPopBalloons end, function(v) Main.AutoPopBalloons = v end)

    createBoundToggle(tab, {
        name = "Auto Leave Stairway To Heaven",
        flag = "MainAutoLeaveStairway",
        value = Main.AutoLeaveStairway,
    }, function() return Main.AutoLeaveStairway end, function(v) Main.AutoLeaveStairway = v end)

    createBoundToggle(tab, {
        name = "Auto Treehouse Merchant",
        flag = "MainAutoTreehouseMerchant",
        value = Main.AutoTreehouseMerchant,
    }, function() return Main.AutoTreehouseMerchant end, function(v) Main.AutoTreehouseMerchant = v end)

    createBoundToggle(tab, {
        name = "Auto Crystal Key Castle",
        flag = "MainAutoCrystalKeyCastle",
        value = Main.AutoCrystalKeyCastle,
    }, function() return Main.AutoCrystalKeyCastle end, function(v) Main.AutoCrystalKeyCastle = v end)

    return MainTab
end

return MainTab
