-- src/UI/Tabs/AutomaticTab.lua
-- Automatic Tab: Boosts, Wings, Fruits, Toys, Potions, Gifts, Lootboxes, Keys, Chests, Wheels, Upgrades

local AutomaticTab = {}

function AutomaticTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Auto = ctx.States.Automatic
    local createBoundToggle = UI.createBoundToggle
    local createBoundSlider = UI.createBoundSlider

    local tab = Window:CreateTab({ name = "Automatic", icon = 93364949241311 })
    UI.AutomaticTab = tab

    tab:CreateSection({ name = "Upgrades, Fruits, Toys & Potions" })

    UI.AutomaticStatusText = tab:CreateText({
        name = "Automatic Status",
        text = "Automatic systems idle",
    })

    createBoundToggle(tab, {
        name = "Auto Buy Boosts",
        flag = "AutoBuyBoosts",
        value = Auto.AutoBuyBoosts,
    }, function() return Auto.AutoBuyBoosts end, function(v) Auto.AutoBuyBoosts = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Wings Upgrades",
        flag = "AutoBuyWings",
        value = Auto.AutoBuyWingsUpgrades,
    }, function() return Auto.AutoBuyWingsUpgrades end, function(v) Auto.AutoBuyWingsUpgrades = v end)

    createBoundToggle(tab, {
        name = "Auto Eat Fruits (Normal / Shiny)",
        flag = "AutoEatFruits",
        value = Auto.AutoEatFruits,
    }, function() return Auto.AutoEatFruits end, function(v) Auto.AutoEatFruits = v end)

    createBoundToggle(tab, {
        name = "Include Shiny Fruits",
        flag = "AutoEatShinyFruits",
        value = Auto.EatShinyFruits,
    }, function() return Auto.EatShinyFruits end, function(v) Auto.EatShinyFruits = v end)

    createBoundToggle(tab, {
        name = "Auto Use Toys",
        flag = "AutoUseToys",
        value = Auto.AutoUseToys,
    }, function() return Auto.AutoUseToys end, function(v) Auto.AutoUseToys = v end)

    createBoundToggle(tab, {
        name = "Auto Use Potions",
        flag = "AutoUsePotions",
        value = Auto.AutoUsePotions,
    }, function() return Auto.AutoUsePotions end, function(v) Auto.AutoUsePotions = v end)

    createBoundSlider(tab, {
        name = "Min Potion Tier",
        flag = "AutoPotionMinTier",
        range = { 1, 10 },
        increment = 1,
        value = Auto.PotionMinTier,
    }, function() return Auto.PotionMinTier end, function(v)
        Auto.PotionMinTier = math.clamp(tonumber(v) or 1, 1, 10)
    end)

    tab:CreateSection({ name = "Gifts, Lootboxes, Keys, Chests & Wheels" })

    createBoundToggle(tab, {
        name = "Auto Open Gifts",
        flag = "AutoOpenGifts",
        value = Auto.AutoOpenGifts,
    }, function() return Auto.AutoOpenGifts end, function(v) Auto.AutoOpenGifts = v end)

    createBoundToggle(tab, {
        name = "Auto Open Lootboxes",
        flag = "AutoOpenLootboxes",
        value = Auto.AutoOpenLootboxes,
    }, function() return Auto.AutoOpenLootboxes end, function(v) Auto.AutoOpenLootboxes = v end)

    createBoundToggle(tab, {
        name = "Auto Combine Keys",
        flag = "AutoCombineKeys",
        value = Auto.AutoCombineKeys,
    }, function() return Auto.AutoCombineKeys end, function(v) Auto.AutoCombineKeys = v end)

    createBoundToggle(tab, {
        name = "Auto Open Chests",
        flag = "AutoOpenChests",
        value = Auto.AutoOpenChests,
    }, function() return Auto.AutoOpenChests end, function(v) Auto.AutoOpenChests = v end)

    createBoundToggle(tab, {
        name = "Auto Spin Wheels",
        flag = "AutoSpinWheels",
        value = Auto.AutoSpinWheels,
    }, function() return Auto.AutoSpinWheels end, function(v) Auto.AutoSpinWheels = v end)

    tab:CreateSection({ name = "Machine Upgraders" })

    createBoundToggle(tab, {
        name = "Auto Upgrade Fruits",
        flag = "AutoUpgradeFruits",
        value = Auto.AutoUpgradeFruits,
    }, function() return Auto.AutoUpgradeFruits end, function(v) Auto.AutoUpgradeFruits = v end)

    createBoundToggle(tab, {
        name = "Auto Upgrade Potions",
        flag = "AutoUpgradePotions",
        value = Auto.AutoUpgradePotions,
    }, function() return Auto.AutoUpgradePotions end, function(v) Auto.AutoUpgradePotions = v end)

    createBoundToggle(tab, {
        name = "Auto Upgrade Enchants",
        flag = "AutoUpgradeEnchants",
        value = Auto.AutoUpgradeEnchants,
    }, function() return Auto.AutoUpgradeEnchants end, function(v) Auto.AutoUpgradeEnchants = v end)

    return AutomaticTab
end

return AutomaticTab
