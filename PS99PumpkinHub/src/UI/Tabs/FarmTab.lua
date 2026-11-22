-- src/UI/Tabs/FarmTab.lua
-- Farm Tab: Upgraded Legit Auto Tap Behavior

local FarmTab = {}

function FarmTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Farm = ctx.States.Farm
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown
    local createBoundSlider = UI.createBoundSlider

    local tab = Window:CreateTab({ name = "Farm", icon = 93364949241311 })
    UI.FarmTab = tab

    tab:CreateSection({ name = "Auto Tap (Legit PS99 Behavior)" })

    UI.FarmStatusText = tab:CreateText({
        name = "Auto Tap Status",
        text = "Auto Tap off",
    })

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

    return FarmTab
end

return FarmTab
