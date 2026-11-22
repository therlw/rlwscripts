-- src/UI/Tabs/AutoFarmTab.lua
-- Auto Farm Tab: Pet Speed, Auto Tap, Efficient Farm, Orbs, Ultimate, Areas/Rebirth/Gate Quests, Misc & Slots

local AutoFarmTab = {}

function AutoFarmTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Farm = ctx.States.Farm
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown
    local createBoundSlider = UI.createBoundSlider

    local tab = Window:CreateTab({ name = "Auto Farm", icon = 93364949241311 })
    UI.FarmTab = tab

    tab:CreateSection({ name = "Combat & Pet Farming" })

    UI.FarmStatusText = tab:CreateText({
        name = "Auto Farm Status",
        text = "Auto Tap idle",
    })

    createBoundToggle(tab, {
        name = "Infinite Pet Speed",
        flag = "FarmInfPetSpeed",
        description = "Boosts local PlayerPet movement speed toward breakables",
        value = Farm.InfinitePetSpeed,
    }, function() return Farm.InfinitePetSpeed end, function(v) Farm.InfinitePetSpeed = v end)

    createBoundSlider(tab, {
        name = "Pet Speed Multiplier",
        flag = "FarmPetSpeedMult",
        range = { 2, 100 },
        increment = 1,
        value = Farm.PetSpeedMult,
        suffix = "x",
    }, function() return Farm.PetSpeedMult end, function(v)
        Farm.PetSpeedMult = math.clamp(tonumber(v) or 25, 2, 100)
    end)

    UI.AutoTapToggle = createBoundToggle(tab, {
        name = "Auto Tap",
        flag = "FarmAutoTap",
        description = "Legit target selection (TapTargetPolicy, Swift Taps CPS clamp, reach checks)",
        value = Farm.AutoTap,
    }, function() return Farm.AutoTap end, function(v) Farm.AutoTap = v end)

    createBoundDropdown(tab, {
        name = "Tap Target Priority",
        flag = "FarmTapTargetMode",
        options = { "Best / Turkey Priority", "Nearest Allowed", "Pumpkin Only" },
        value = Farm.TapTargetMode,
    }, function() return Farm.TapTargetMode end, function(v) Farm.TapTargetMode = v end)

    createBoundSlider(tab, {
        name = "Tap Speed Scale (vs Legit Max CPS)",
        flag = "FarmTapRateScale",
        range = { 0.4, 1.0 },
        increment = 0.05,
        value = Farm.TapRateScale,
        suffix = "x",
    }, function() return Farm.TapRateScale end, function(v)
        Farm.TapRateScale = math.clamp(tonumber(v) or 1.0, 0.35, 1.0)
    end)

    createBoundToggle(tab, {
        name = "Auto Efficient Farm (Fast Farm)",
        flag = "FarmAutoEfficient",
        description = "Enables AutoFarm + spreads equipped pets across active breakables",
        value = Farm.AutoEfficientFarm,
    }, function() return Farm.AutoEfficientFarm end, function(v) Farm.AutoEfficientFarm = v end)

    createBoundToggle(tab, {
        name = "Auto Collect Orbs",
        flag = "FarmAutoCollectOrbs",
        value = Farm.AutoCollectOrbs,
    }, function() return Farm.AutoCollectOrbs end, function(v) Farm.AutoCollectOrbs = v end)

    createBoundToggle(tab, {
        name = "Auto Use Ultimate",
        flag = "FarmAutoUseUltimate",
        value = Farm.AutoUseUltimate,
    }, function() return Farm.AutoUseUltimate end, function(v) Farm.AutoUseUltimate = v end)

    tab:CreateSection({ name = "Areas, Worlds, Quests & Rebirth" })

    createBoundToggle(tab, {
        name = "Auto Teleport To Best Area",
        flag = "FarmAutoBestArea",
        value = Farm.AutoTeleportBestArea,
    }, function() return Farm.AutoTeleportBestArea end, function(v) Farm.AutoTeleportBestArea = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Next Area",
        flag = "FarmAutoBuyArea",
        value = Farm.AutoBuyNextArea,
    }, function() return Farm.AutoBuyNextArea end, function(v) Farm.AutoBuyNextArea = v end)

    createBoundToggle(tab, {
        name = "Auto Complete Gate Quest",
        flag = "FarmAutoGateQuest",
        value = Farm.AutoCompleteGateQuest,
    }, function() return Farm.AutoCompleteGateQuest end, function(v) Farm.AutoCompleteGateQuest = v end)

    createBoundToggle(tab, {
        name = "Auto Area Quest",
        flag = "FarmAutoAreaQuest",
        description = "Farms current unlocked zone quests (Auto Rank Quests intentionally excluded)",
        value = Farm.AutoAreaQuest,
    }, function() return Farm.AutoAreaQuest end, function(v) Farm.AutoAreaQuest = v end)

    createBoundToggle(tab, {
        name = "Auto Rebirth",
        flag = "FarmAutoRebirth",
        value = Farm.AutoRebirth,
    }, function() return Farm.AutoRebirth end, function(v) Farm.AutoRebirth = v end)

    createBoundToggle(tab, {
        name = "Auto Teleport to Best World",
        flag = "FarmAutoBestWorld",
        value = Farm.AutoTeleportBestWorld,
    }, function() return Farm.AutoTeleportBestWorld end, function(v) Farm.AutoTeleportBestWorld = v end)

    tab:CreateSection({ name = "Misc Boosters & Slots" })

    createBoundToggle(tab, {
        name = "Auto Use All Misc Items",
        flag = "FarmAutoMisc",
        description = "Uses Toy Ball/Bone/Squeaky Toy, Pinatas, Lucky Blocks & Swirls in zone",
        value = Farm.AutoUseMiscItems,
    }, function() return Farm.AutoUseMiscItems end, function(v) Farm.AutoUseMiscItems = v end)

    createBoundToggle(tab, {
        name = "Auto Use Breakable Sprinkler",
        flag = "FarmAutoSprinkler",
        value = Farm.AutoUseSprinkler,
    }, function() return Farm.AutoUseSprinkler end, function(v) Farm.AutoUseSprinkler = v end)

    createBoundToggle(tab, {
        name = "Auto Use TNT-TNT Crate",
        flag = "FarmAutoTNTCrate",
        value = Farm.AutoUseTNTCrate,
    }, function() return Farm.AutoUseTNTCrate end, function(v) Farm.AutoUseTNTCrate = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Pet Equip Slots",
        flag = "FarmAutoPetSlots",
        value = Farm.AutoBuyPetEquipSlots,
    }, function() return Farm.AutoBuyPetEquipSlots end, function(v) Farm.AutoBuyPetEquipSlots = v end)

    createBoundToggle(tab, {
        name = "Auto Buy Egg Bundle Slots",
        flag = "FarmAutoEggSlots",
        value = Farm.AutoBuyEggBundleSlots,
    }, function() return Farm.AutoBuyEggBundleSlots end, function(v) Farm.AutoBuyEggBundleSlots = v end)

    return AutoFarmTab
end

return AutoFarmTab
