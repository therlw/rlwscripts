-- src/UI/Tabs/EggTab.lua
-- Egg Tab: World Egg Hatching (BreakableZone Edge Safe), Animation Toggle, Gold/Rainbow/Fuse/Charm

local EggTab = {}

function EggTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Egg = ctx.States.Egg
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown
    local createBoundSlider = UI.createBoundSlider

    local tab = Window:CreateTab({ name = "Egg", icon = 93364949241311 })
    UI.EggTab = tab

    tab:CreateSection({ name = "Egg Hatching" })

    UI.EggStatusText = tab:CreateText({
        name = "Egg & Pet Machines Status",
        text = "Egg & Pet machines idle",
    })

    createBoundToggle(tab, {
        name = "Auto Buy Egg",
        flag = "EggAutoBuy",
        value = Egg.AutoBuyEgg,
    }, function() return Egg.AutoBuyEgg end, function(v) Egg.AutoBuyEgg = v end)

    createBoundDropdown(tab, {
        name = "Egg Selection Mode",
        flag = "EggTargetMode",
        options = { "Best Unlocked", "Nearest Unlocked" },
        value = Egg.TargetEggMode,
    }, function() return Egg.TargetEggMode end, function(v) Egg.TargetEggMode = v end)

    createBoundDropdown(tab, {
        name = "Hatch Amount",
        flag = "EggHatchAmt",
        options = { "Max", "1", "3", "10", "50" },
        value = Egg.HatchAmount,
    }, function() return Egg.HatchAmount end, function(v) Egg.HatchAmount = v end)

    createBoundToggle(tab, {
        name = "Stay Inside BreakableZone Near Egg",
        flag = "EggStayBreakableZone",
        description = "Stands inside current zone's BreakableZone on the edge nearest the Egg",
        value = Egg.StayInBreakableZone,
    }, function() return Egg.StayInBreakableZone end, function(v) Egg.StayInBreakableZone = v end)

    createBoundToggle(tab, {
        name = "Golden Hatch",
        flag = "EggGoldenHatch",
        value = Egg.GoldenHatch,
    }, function() return Egg.GoldenHatch end, function(v) Egg.GoldenHatch = v end)

    createBoundToggle(tab, {
        name = "Charged Hatch",
        flag = "EggChargedHatch",
        value = Egg.ChargedHatch,
    }, function() return Egg.ChargedHatch end, function(v) Egg.ChargedHatch = v end)

    createBoundToggle(tab, {
        name = "Disable Egg Animation",
        flag = "EggDisableAnim",
        description = "Skips 3D egg opening animation while properly firing SM_Unmask",
        value = Egg.DisableEggAnimation,
    }, function() return Egg.DisableEggAnimation end, function(v)
        Egg.DisableEggAnimation = v
        if ctx.EggAndPetSystem and ctx.EggAndPetSystem.SetDisableEggAnimation then
            ctx.EggAndPetSystem.SetDisableEggAnimation(v)
        end
    end)

    tab:CreateSection({ name = "Pet Conversion & Charms" })

    createBoundToggle(tab, {
        name = "Auto Make Gold Pets",
        flag = "EggAutoGold",
        value = Egg.AutoMakeGold,
    }, function() return Egg.AutoMakeGold end, function(v) Egg.AutoMakeGold = v end)

    createBoundToggle(tab, {
        name = "Auto Make Rainbow Pets",
        flag = "EggAutoRainbow",
        value = Egg.AutoMakeRainbow,
    }, function() return Egg.AutoMakeRainbow end, function(v) Egg.AutoMakeRainbow = v end)

    createBoundToggle(tab, {
        name = "Auto Fuse Pets",
        flag = "EggAutoFuse",
        value = Egg.AutoFusePets,
    }, function() return Egg.AutoFusePets end, function(v) Egg.AutoFusePets = v end)

    createBoundSlider(tab, {
        name = "Min Pet Stack to Fuse",
        flag = "EggFuseMin",
        range = { 3, 100 },
        increment = 1,
        value = Egg.FuseMinCount,
        suffix = " pets",
    }, function() return Egg.FuseMinCount end, function(v)
        Egg.FuseMinCount = math.clamp(tonumber(v) or 12, 3, 100)
    end)

    createBoundToggle(tab, {
        name = "Auto Charm Pets",
        flag = "EggAutoCharm",
        value = Egg.AutoCharmPets,
    }, function() return Egg.AutoCharmPets end, function(v) Egg.AutoCharmPets = v end)

    createBoundDropdown(tab, {
        name = "Preferred Charms",
        flag = "EggPreferredCharms",
        multiSelect = true,
        options = { "Royalty", "Overload", "Glittering", "Strength", "Agility", "TNT", "Coins", "Criticals", "Diamonds", "Lightning", "XP" },
        value = Egg.PreferredCharms,
    }, function() return Egg.PreferredCharms end, function(v)
        if type(v) == "table" then Egg.PreferredCharms = v end
    end)

    return EggTab
end

return EggTab
