-- src/UI/Tabs/FarmingWorldTab.lua
-- Farming World Tab: Eggs, Supply, Place, Harvest, Feed, Sell, Craft, Storage, Quests, Slots & Pixel Mail

local FarmingWorldTab = {}

function FarmingWorldTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local FarmW = ctx.States.FarmingWorld
    local createBoundToggle = UI.createBoundToggle
    local createBoundInput = UI.createBoundInput

    local tab = Window:CreateTab({ name = "Farming World", icon = 93364949241311 })
    UI.FarmingWorldTab = tab

    tab:CreateSection({ name = "Eggs, Crops & Merchants" })

    UI.FarmingStatusText = tab:CreateText({
        name = "Farming World Status",
        text = "Farming World idle",
    })

    createBoundToggle(tab, {
        name = "Auto Buy Farm Egg",
        flag = "FarmWBuyEgg",
        value = FarmW.AutoBuyFarmEgg,
    }, function() return FarmW.AutoBuyFarmEgg end, function(v) FarmW.AutoBuyFarmEgg = v end)

    createBoundToggle(tab, {
        name = "Auto Place Farm Egg",
        flag = "FarmWPlaceEgg",
        value = FarmW.AutoPlaceFarmEgg,
    }, function() return FarmW.AutoPlaceFarmEgg end, function(v) FarmW.AutoPlaceFarmEgg = v end)

    createBoundToggle(tab, {
        name = "Auto Harvest Farm Egg",
        flag = "FarmWHarvestEgg",
        value = FarmW.AutoHarvestFarmEgg,
    }, function() return FarmW.AutoHarvestFarmEgg end, function(v) FarmW.AutoHarvestFarmEgg = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Farm Supply",
        flag = "FarmWBuySupply",
        value = FarmW.AutoBuyFarmSupply,
    }, function() return FarmW.AutoBuyFarmSupply end, function(v) FarmW.AutoBuyFarmSupply = v end)

    tab:CreateSection({ name = "Pets, Crafting & Storage" })

    createBoundToggle(tab, {
        name = "Auto Feed Farm Pets",
        flag = "FarmWFeedPets",
        value = FarmW.AutoFeedFarmPets,
    }, function() return FarmW.AutoFeedFarmPets end, function(v) FarmW.AutoFeedFarmPets = v end)

    createBoundToggle(tab, {
        name = "Auto Sell Farm Pets",
        flag = "FarmWSellPets",
        value = FarmW.AutoSellFarmPets,
    }, function() return FarmW.AutoSellFarmPets end, function(v) FarmW.AutoSellFarmPets = v end)

    createBoundToggle(tab, {
        name = "Auto Craft Items/Pets",
        flag = "FarmWCraft",
        value = FarmW.AutoCraftItemsPets,
    }, function() return FarmW.AutoCraftItemsPets end, function(v) FarmW.AutoCraftItemsPets = v end)

    createBoundToggle(tab, {
        name = "Auto Claim Farm Storage",
        flag = "FarmWClaimStorage",
        value = FarmW.AutoClaimFarmStorage,
    }, function() return FarmW.AutoClaimFarmStorage end, function(v) FarmW.AutoClaimFarmStorage = v end)

    tab:CreateSection({ name = "Quests, Slots & Pixel Rainbow Mail" })

    createBoundToggle(tab, {
        name = "Auto Claim Farming Quest Rewards",
        flag = "FarmWClaimQuests",
        value = FarmW.AutoClaimFarmingQuestRewards,
    }, function() return FarmW.AutoClaimFarmingQuestRewards end, function(v) FarmW.AutoClaimFarmingQuestRewards = v end)

    createBoundToggle(tab, {
        name = "Auto Complete Farming Quest",
        flag = "FarmWCompleteQuests",
        value = FarmW.AutoCompleteFarmingQuest,
    }, function() return FarmW.AutoCompleteFarmingQuest end, function(v) FarmW.AutoCompleteFarmingQuest = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Farm Pet Slot",
        flag = "FarmWBuyPetSlot",
        value = FarmW.AutoBuyFarmPetSlot,
    }, function() return FarmW.AutoBuyFarmPetSlot end, function(v) FarmW.AutoBuyFarmPetSlot = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Farm Storage Slot",
        flag = "FarmWBuyStorageSlot",
        value = FarmW.AutoBuyFarmStorageSlot,
    }, function() return FarmW.AutoBuyFarmStorageSlot end, function(v) FarmW.AutoBuyFarmStorageSlot = v end)

    createBoundToggle(tab, {
        name = "Auto Mail Pixel Rainbow Items",
        flag = "FarmWMailPixel",
        value = FarmW.AutoMailPixelRainbowItems,
    }, function() return FarmW.AutoMailPixelRainbowItems end, function(v) FarmW.AutoMailPixelRainbowItems = v end)

    createBoundInput(tab, {
        name = "Pixel Rainbow Mail Target Username",
        flag = "FarmWPixelUser",
        placeholder = "Target Roblox Username",
        value = FarmW.PixelMailUsername,
    }, function() return FarmW.PixelMailUsername end, function(v) FarmW.PixelMailUsername = v end)

    return FarmingWorldTab
end

return FarmingWorldTab
