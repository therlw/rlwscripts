-- src/UI/Tabs/PumpkinTycoonTab.lua
-- Current Event Tab: "Pumpkin Tycoon" (Part 1 & Part 2 Complete Suite, Halloween Games omitted)

local PumpkinTycoonTab = {}

function PumpkinTycoonTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local PT = ctx.States.PumpkinTycoon
    local Move = ctx.States.Movement
    local Net = ctx.Net
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown
    local createBoundSlider = UI.createBoundSlider

    local tab = Window:CreateTab({ name = "Pumpkin Tycoon", icon = 93364949241311 })
    UI.PumpkinTycoonTab = tab

    tab:CreateSection({ name = "Live Event Status" })
    UI.PumpkinStatusText = tab:CreateText({
        name = "Pumpkin Patch Tycoon",
        text = "Initializing live telemetry...",
    })

    -- Movement & Performance
    tab:CreateSection({ name = "Movement & Optimization" })

    createBoundDropdown(tab, {
        name = "Select Movement Mode",
        flag = "PTMovementMode",
        description = "Choose Teleport or Legit Walk across all event actions & pads",
        options = { "Teleport", "Legit Walk" },
        value = Move.Mode,
    }, function() return Move.Mode end, function(v) Move.Mode = v end)

    UI.OptimizePTToggle = createBoundToggle(tab, {
        name = "Optimize Pumpkin Tycoon",
        flag = "PTOptimize",
        description = "Cleans Turkey island & removes Turkey + pumpkin flashes for less lag",
        value = PT.OptimizePumpkinTycoon,
    }, function() return PT.OptimizePumpkinTycoon end, function(v)
        PT.OptimizePumpkinTycoon = v
        if ctx.Optimizer and ctx.Optimizer.SetEnabled then
            ctx.Optimizer.SetEnabled(v == true)
        end
    end)

    -- Tycoon Building & Rebirth
    tab:CreateSection({ name = "Tycoon Progression & Rebirth" })

    UI.AutoButtonsToggle = createBoundToggle(tab, {
        name = "Auto Buy Pumpkin Tycoon Buttons",
        flag = "PTAutoButtons",
        description = "Builds Part 1 & Part 2 zones (1-8) and claims your island reward",
        value = PT.AutoBuyButtons,
    }, function() return PT.AutoBuyButtons end, function(v) PT.AutoBuyButtons = v end)

    createBoundDropdown(tab, {
        name = "Button Build Priority",
        flag = "PTButtonPriority",
        options = { "Zone/Egg First", "Cheapest First" },
        value = PT.ButtonPriorityMode,
    }, function() return PT.ButtonPriorityMode end, function(v) PT.ButtonPriorityMode = v end)

    createBoundToggle(tab, {
        name = "Auto Claim Island Completion Reward",
        flag = "PTAutoIslandReward",
        description = "Automatically claims Flannel Gifts at 100% completion (BT_Settle)",
        value = PT.AutoClaimIslandReward,
    }, function() return PT.AutoClaimIslandReward end, function(v) PT.AutoClaimIslandReward = v end)

    createBoundToggle(tab, {
        name = "Auto Rebirth Pumpkin Tycoon",
        flag = "PTAutoRebirth",
        description = "Rebirths at 100% Part 2 shrine respecting server 5s cooldown",
        value = PT.AutoRebirth,
    }, function() return PT.AutoRebirth end, function(v) PT.AutoRebirth = v end)

    -- Eggs & Intelligent Coin Saving
    tab:CreateSection({ name = "Eggs & Smart Coin Saving (Zones 1-8)" })

    createBoundToggle(tab, {
        name = "Auto Teleport to Best Pumpkin Egg/Area",
        flag = "PTAutoTPBestEgg",
        description = "Moves to highest unlocked Pumpkin Egg including Pine Woods, Maple Creek & Golden Ridge",
        value = PT.AutoTeleportBestEgg,
    }, function() return PT.AutoTeleportBestEgg end, function(v) PT.AutoTeleportBestEgg = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Nearest Pumpkin Egg",
        flag = "PTAutoBuyNearestEgg",
        description = "Hatches nearest unlocked Pumpkin Egg cleanly via CustomEggs_Hatch",
        value = PT.AutoBuyNearestEgg,
    }, function() return PT.AutoBuyNearestEgg end, function(v) PT.AutoBuyNearestEgg = v end)

    createBoundToggle(tab, {
        name = "Intelligent Coin Saving System",
        flag = "PTSmartCoinSave",
        description = "Pauses egg buying while saving Patch Coins for next priority button/zone",
        value = PT.SmartCoinSaving,
    }, function() return PT.SmartCoinSaving end, function(v) PT.SmartCoinSaving = v end)

    createBoundDropdown(tab, {
        name = "Egg Hatch Count",
        flag = "PTEggHatchCount",
        options = { "Max", "1", "3", "10", "50" },
        value = PT.EggHatchAmount,
    }, function() return PT.EggHatchAmount end, function(v) PT.EggHatchAmount = v end)

    -- Wild Pets, Pet Nets, Turkey & Rare Pet Spawns
    tab:CreateSection({ name = "Turkey Boss, Wild Pets & Rare Spawns" })

    createBoundToggle(tab, {
        name = "Auto Fight Turkey",
        flag = "PTAutoFightTurkey",
        description = "Launches cannon to Turkey island, sends pets & taps within TurkeyReach",
        value = PT.AutoFightTurkey,
    }, function() return PT.AutoFightTurkey end, function(v) PT.AutoFightTurkey = v end)

    createBoundToggle(tab, {
        name = "Return Home After Turkey",
        flag = "PTReturnAfterTurkey",
        value = PT.ReturnHomeAfterTurkey,
    }, function() return PT.ReturnHomeAfterTurkey end, function(v) PT.ReturnHomeAfterTurkey = v end)

    UI.AutoCatchRareToggle = createBoundToggle(tab, {
        name = "Auto Catch Rare Pet Spawns",
        flag = "PTAutoCatchRare",
        description = "Throws your best Pet Net at Huge, Titanic & Gargantuan spawns after each Turkey",
        value = PT.AutoCatchRareSpawns,
    }, function() return PT.AutoCatchRareSpawns end, function(v) PT.AutoCatchRareSpawns = v end)

    createBoundDropdown(tab, {
        name = "Rare Tiers to Catch",
        flag = "PTRareTiers",
        multiSelect = true,
        options = { "Huge", "Titanic", "Gargantuan" },
        value = PT.CatchRareTiers,
    }, function() return PT.CatchRareTiers end, function(v) PT.CatchRareTiers = v end)

    createBoundToggle(tab, {
        name = "Auto Hunt Wild Pets",
        flag = "PTAutoHuntWild",
        description = "Syncs game Auto Hunt rules safely (LF_Pursue)",
        value = PT.AutoHuntWildPets,
    }, function() return PT.AutoHuntWildPets end, function(v) PT.AutoHuntWildPets = v end)

    createBoundDropdown(tab, {
        name = "Auto Hunt Minimum Rarity",
        flag = "PTHuntMinTier",
        options = { "Any", "Uncommon", "Rare", "Epic", "Huge" },
        value = PT.HuntMinTier,
    }, function() return PT.HuntMinTier end, function(v) PT.HuntMinTier = v end)

    createBoundToggle(tab, {
        name = "Auto Hunt Variants Only",
        flag = "PTHuntVariants",
        value = PT.HuntVariantsOnly,
    }, function() return PT.HuntVariantsOnly end, function(v) PT.HuntVariantsOnly = v end)

    createBoundToggle(tab, {
        name = "Auto Hunt Ultra Net on Huges",
        flag = "PTHuntUltraHuge",
        value = PT.HuntUltraOnHuges,
    }, function() return PT.HuntUltraOnHuges end, function(v) PT.HuntUltraOnHuges = v end)

    createBoundToggle(tab, {
        name = "Auto Catch Wild Pets",
        flag = "PTAutoCatchWild",
        description = "Moves within 150 studs and throws nets directly at wild pets (RU_Ensnare)",
        value = PT.AutoCatchWildPets,
    }, function() return PT.AutoCatchWildPets end, function(v) PT.AutoCatchWildPets = v end)

    createBoundDropdown(tab, {
        name = "Auto Catch Min Rarity",
        flag = "PTCatchWildMinTier",
        options = { "Any", "Uncommon", "Rare", "Epic", "Huge" },
        value = PT.CatchWildMinTier,
    }, function() return PT.CatchWildMinTier end, function(v) PT.CatchWildMinTier = v end)

    createBoundDropdown(tab, {
        name = "Wild Pet Net Preference",
        flag = "PTCatchWildNetPref",
        options = { "Best Available", "Pet Net Only", "Ultra For Huge+" },
        value = PT.CatchWildNetPreference,
    }, function() return PT.CatchWildNetPreference end, function(v) PT.CatchWildNetPreference = v end)

    createBoundToggle(tab, {
        name = "Auto Catch Wild Variants Only",
        flag = "PTCatchWildVariants",
        value = PT.CatchWildVariantsOnly,
    }, function() return PT.CatchWildVariantsOnly end, function(v) PT.CatchWildVariantsOnly = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Pet Nets",
        flag = "PTAutoBuyNets",
        description = "Enables game Auto Buy Nets (GN_Restock) and buys selected nets in Pet Net Store",
        value = PT.AutoBuyPetNets,
    }, function() return PT.AutoBuyPetNets end, function(v) PT.AutoBuyPetNets = v end)

    createBoundDropdown(tab, {
        name = "Pet Net Purchase Mode",
        flag = "PTBuyNetsMode",
        options = { "Game Auto Nets + Shop", "Game Auto Nets", "Shop Selected Only" },
        value = PT.BuyPetNetsMode,
    }, function() return PT.BuyPetNetsMode end, function(v) PT.BuyPetNetsMode = v end)

    createBoundDropdown(tab, {
        name = "Selected Pet Nets (Shop)",
        flag = "PTSelectedNets",
        multiSelect = true,
        options = { "Pet Net", "Ultra Pet Net" },
        value = PT.SelectedNetOffers,
    }, function() return PT.SelectedNetOffers end, function(v) PT.SelectedNetOffers = v end)

    -- Pumpkins Keep, Break, Merchant & Planting
    tab:CreateSection({ name = "Pumpkins Keep, Break & Merchant" })

    createBoundToggle(tab, {
        name = "Auto Keep Pumpkins",
        flag = "PTAutoKeepPumpkins",
        description = "Keeps rare pumpkins below rule so pets leave high-earning pumpkins alive",
        value = PT.AutoKeepPumpkins,
    }, function() return PT.AutoKeepPumpkins end, function(v) PT.AutoKeepPumpkins = v end)

    local ladderOpts = { "Off", "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Exotic", "Secret" }
    createBoundDropdown(tab, {
        name = "Keep Pumpkins At or Above",
        flag = "PTKeepRarityRule",
        options = ladderOpts,
        value = PT.KeepRarityRule,
    }, function() return PT.KeepRarityRule end, function(v) PT.KeepRarityRule = v end)

    createBoundToggle(tab, {
        name = "Auto Break Pumpkins",
        flag = "PTAutoBreakPumpkins",
        description = "Dispatches pets to break unkept pumpkins across your island without moving",
        value = PT.AutoBreakPumpkins,
    }, function() return PT.AutoBreakPumpkins end, function(v) PT.AutoBreakPumpkins = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Merchant Pumpkins",
        flag = "PTAutoBuyMerchant",
        description = "Reworked: uses game Auto Merchant (HM_Sustain) or Selected Bands",
        value = PT.AutoBuyMerchantPumpkins,
    }, function() return PT.AutoBuyMerchantPumpkins end, function(v) PT.AutoBuyMerchantPumpkins = v end)

    createBoundDropdown(tab, {
        name = "Merchant Buy Mode",
        flag = "PTMerchantBuyMode",
        options = { "Game Auto Merchant", "Selected Bands" },
        value = PT.AutoBuyMerchantMode,
    }, function() return PT.AutoBuyMerchantMode end, function(v) PT.AutoBuyMerchantMode = v end)

    createBoundDropdown(tab, {
        name = "Selected Merchant Bands",
        flag = "PTSelectedMerchantBands",
        multiSelect = true,
        options = { "RarePlus", "EpicPlus", "LegendaryPlus", "MythicalPlus", "ExoticPlus" },
        value = PT.SelectedMerchantBands,
    }, function() return PT.SelectedMerchantBands end, function(v) PT.SelectedMerchantBands = v end)

    createBoundToggle(tab, {
        name = "Auto Plant Merchant Pumpkins",
        flag = "PTAutoPlant",
        description = "Enables auto planting (JD_Prefer) and plants leftover stock on free pedestals",
        value = PT.AutoPlantMerchantPumpkins,
    }, function() return PT.AutoPlantMerchantPumpkins end, function(v) PT.AutoPlantMerchantPumpkins = v end)

    -- Upgrades, Hot Cocoa, Boosts & Gifts
    tab:CreateSection({ name = "Upgrades, Hot Cocoa, Boosts & Gifts" })

    createBoundToggle(tab, {
        name = "Auto Buy Selected Pumpkin Upgrades",
        flag = "PTAutoBuyUpgrades",
        description = "Includes Part 2 upgrade tiers using Pumpkin Tokens (OQ_Advance)",
        value = PT.AutoBuyUpgrades,
    }, function() return PT.AutoBuyUpgrades end, function(v) PT.AutoBuyUpgrades = v end)

    local trackOptions = (Net.Mod.PT_Upgrades and Net.Mod.PT_Upgrades.TRACKS) or {
        "SpawnLuck", "PumpkinCoins", "PumpkinDamage", "RespawnSpeed",
        "StockSlots", "ChaseOdds", "EggLuck", "MerchantLuck",
    }
    createBoundDropdown(tab, {
        name = "Selected Pumpkin Upgrades",
        flag = "PTSelectedUpgrades",
        multiSelect = true,
        options = trackOptions,
        value = PT.SelectedUpgrades,
    }, function() return PT.SelectedUpgrades end, function(v) PT.SelectedUpgrades = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Selected Hot Cocoa Boosts",
        flag = "PTAutoBuyCocoa",
        description = "Buys time at Cocoa Stand within 20 studs (VB_Extend)",
        value = PT.AutoBuyCocoaBoosts,
    }, function() return PT.AutoBuyCocoaBoosts end, function(v) PT.AutoBuyCocoaBoosts = v end)

    createBoundDropdown(tab, {
        name = "Selected Hot Cocoa Boosts",
        flag = "PTSelectedCocoa",
        multiSelect = true,
        options = { "Coins", "Damage", "IslandLuck" },
        value = PT.SelectedCocoaBoosts,
    }, function() return PT.SelectedCocoaBoosts end, function(v) PT.SelectedCocoaBoosts = v end)

    createBoundToggle(tab, {
        name = "Auto Use Selected Pumpkin Boosts",
        flag = "PTAutoUseBoosts",
        description = "Uses Tier III boosts first from your Consumables (Tier III -> II -> I)",
        value = PT.AutoUsePumpkinBoosts,
    }, function() return PT.AutoUsePumpkinBoosts end, function(v) PT.AutoUsePumpkinBoosts = v end)

    createBoundDropdown(tab, {
        name = "Selected Pumpkin Boosts",
        flag = "PTSelectedBoosts",
        multiSelect = true,
        options = { "Coins", "Damage", "IslandLuck" },
        value = PT.SelectedPumpkinBoosts,
    }, function() return PT.SelectedPumpkinBoosts end, function(v) PT.SelectedPumpkinBoosts = v end)

    createBoundToggle(tab, {
        name = "Auto Open Flannel Gifts",
        flag = "PTAutoOpenGifts",
        description = "Opens Flannel Gifts in batches of up to 8 inside Pumpkin Tycoon",
        value = PT.AutoOpenFlannelGifts,
    }, function() return PT.AutoOpenFlannelGifts end, function(v) PT.AutoOpenFlannelGifts = v end)

    createBoundSlider(tab, {
        name = "Flannel Gift Batch Size",
        flag = "PTGiftBatch",
        range = { 1, 8 },
        increment = 1,
        value = PT.GiftOpenBatch,
        suffix = " gifts",
    }, function() return PT.GiftOpenBatch end, function(v) PT.GiftOpenBatch = math.clamp(math.floor(v), 1, 8) end)

    return PumpkinTycoonTab
end

return PumpkinTycoonTab
