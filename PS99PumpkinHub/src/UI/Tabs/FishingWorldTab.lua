-- src/UI/Tabs/FishingWorldTab.lua
-- Fishing World Tab: Event Eggs, Event Fishing (Autofish/Cast), Sell Fish, Next Rod, Scrolls & Chum

local FishingWorldTab = {}

function FishingWorldTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local FW = ctx.States.FishingWorld
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown

    local tab = Window:CreateTab({ name = "Fishing World", icon = 93364949241311 })
    UI.FishingWorldTab = tab

    tab:CreateSection({ name = "Fishing Event Automation" })

    UI.FishingStatusText = tab:CreateText({
        name = "Fishing Event Status",
        text = "Fishing Event idle",
    })

    createBoundToggle(tab, {
        name = "Auto Buy Nearest Fishing Event Egg",
        flag = "FishAutoEgg",
        value = FW.AutoBuyNearestEgg,
    }, function() return FW.AutoBuyNearestEgg end, function(v) FW.AutoBuyNearestEgg = v end)

    createBoundDropdown(tab, {
        name = "Fishing Egg Hatch Amount",
        flag = "FishEggAmount",
        options = { "Max", "1", "3", "10", "50" },
        value = FW.EggAmount,
    }, function() return FW.EggAmount end, function(v) FW.EggAmount = v end)

    createBoundToggle(tab, {
        name = "Auto Event Fishing",
        flag = "FishAutoFish",
        value = FW.AutoEventFishing,
    }, function() return FW.AutoEventFishing end, function(v) FW.AutoEventFishing = v end)

    createBoundDropdown(tab, {
        name = "Event Fishing Mode",
        flag = "FishMode",
        options = { "Game Autofish + Cast", "Game Autofish", "Auto Cast & Reel" },
        value = FW.FishingMode,
    }, function() return FW.FishingMode end, function(v) FW.FishingMode = v end)

    createBoundToggle(tab, {
        name = "Auto Sell Event Fish",
        flag = "FishAutoSell",
        value = FW.AutoSellEventFish,
    }, function() return FW.AutoSellEventFish end, function(v) FW.AutoSellEventFish = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Next Event Rod Merchant",
        flag = "FishAutoRod",
        value = FW.AutoBuyNextRod,
    }, function() return FW.AutoBuyNextRod end, function(v) FW.AutoBuyNextRod = v end)

    tab:CreateSection({ name = "Boosters & Bait" })

    createBoundToggle(tab, {
        name = "Auto Use Event Fishing Scrolls",
        flag = "FishAutoScrolls",
        value = FW.AutoUseScrolls,
    }, function() return FW.AutoUseScrolls end, function(v) FW.AutoUseScrolls = v end)

    createBoundDropdown(tab, {
        name = "Selected Fishing Scrolls",
        flag = "FishSelectedScrolls",
        multiSelect = true,
        options = { "Fishing Luck Scroll", "Fishing Speed Scroll", "Fishing XP Scroll" },
        value = FW.SelectedScrolls,
    }, function() return FW.SelectedScrolls end, function(v)
        if type(v) == "table" then FW.SelectedScrolls = v end
    end)

    createBoundToggle(tab, {
        name = "Auto Use Bucket Of Chum",
        flag = "FishAutoChum",
        value = FW.AutoUseBucketOfChum,
    }, function() return FW.AutoUseBucketOfChum end, function(v) FW.AutoUseBucketOfChum = v end)

    return FishingWorldTab
end

return FishingWorldTab
