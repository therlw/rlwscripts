-- src/UI/Tabs/EggTab.lua
-- Tab 2: Eggs & Pets (Speed, Dynamic Egg Catalog, Auto Hatch & Animation Skips)

local EggTab = {}

function EggTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local ConfigManager = ctx.ConfigManager
    local HatchState = ctx.States.Hatch
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local buildDynamicEggList = ctx.API.buildDynamicEggList
    local rebuildSecretCatalog = ctx.API.rebuildSecretCatalog
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay
    local getPetStorageInfo = ctx.API.getPetStorageInfo
    local goToEgg = ctx.API.goToEgg
    local formatHatchSpeedTitle = UI.formatHatchSpeedTitle
    local updateHatchSpeedDisplay = UI.updateHatchSpeedDisplay
    local hatchCountToLabel = UI.hatchCountToLabel

    UI.EggTab = Window:CreateTab({ name = "Eggs & Pets", icon = 93364949241311 })
    local eggNames = buildDynamicEggList()

    UI.EggTab:CreateSection({ name = "Speed & Optimization" })
    UI.HatchSpeedText = nil

    createBoundToggle(UI.EggTab, {
        name = "Auto Adaptive Speed (Server Limit)",
        flag = "HatchAutoSpeed",
        description = "Automatically scales hatch cooldown down to the maximum server limit as you buy upgrades or use boosts",
        value = true,
    }, function() return HatchState.AutoSpeed end, function(v) HatchState.AutoSpeed = v end, function()
        if updateHatchSpeedDisplay then updateHatchSpeedDisplay() end
    end)

    local initDelay, initSpeed = getAutoHatchDelay()
    local initActiveDelay = HatchState.AutoSpeed and initDelay or (HatchState.HatchDelay or CONFIG.HatchCooldown)
    local initTitleStr = formatHatchSpeedTitle(initSpeed, initActiveDelay, HatchState.AutoSpeed)

    pcall(function()
        UI.HatchSpeedText = UI.EggTab:CreateText({
            name = initTitleStr,
            text = string.format("Server Delay: %.2fs | Multiplier: %.2fx", initActiveDelay, initSpeed)
        })
    end)

    pcall(function()
        local manualDelaySlider = UI.EggTab:CreateSlider({
            name = "Manual Hatch Cooldown",
            flag = "ManualHatchDelay",
            description = "Only used when Auto Adaptive Speed is turned OFF.",
            range = { 0.4, 3.5 },
            increment = 0.05,
            value = HatchState.HatchDelay,
            suffix = "s",
            callback = function(val)
                HatchState.HatchDelay = val
                if not HatchState.AutoSpeed and updateHatchSpeedDisplay then
                    updateHatchSpeedDisplay()
                end
                ConfigManager:MarkDirty()
            end
        })
        ConfigManager:Bind("ManualHatchDelay", manualDelaySlider, function() return HatchState.HatchDelay end, function(v) HatchState.HatchDelay = v end)
    end)

    UI.EggTab:CreateSection({ name = "Hatch Controls (Includes Medieval / Royal / Glitched)" })

    UI.EggDropdown = UI.EggTab:CreateDropdown({
        name = "Select Egg",
        flag = "SelectedEgg",
        description = "Choose which egg to farm (dynamically discovered from live game)",
        options = eggNames,
        value = HatchState.SelectedEgg,
        callback = function(selected)
            local egg = type(selected) == "table" and selected[1] or selected
            if egg then
                HatchState.SelectedEgg = egg
            end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("SelectedEgg", UI.EggDropdown, function() return HatchState.SelectedEgg end, function(v) HatchState.SelectedEgg = v end)

    UI.HatchAmountDropdown = UI.EggTab:CreateDropdown({
        name = "Hatch Amount",
        flag = "HatchAmount",
        options = { "Auto (8x / 3x / 1x)", "8x", "3x", "1x" },
        value = hatchCountToLabel(HatchState.HatchCount),
        callback = function(selected)
            local opt = type(selected) == "table" and selected[1] or selected
            if opt == "8x" then
                HatchState.HatchCount = 8
            elseif opt == "3x" then
                HatchState.HatchCount = 3
            elseif opt == "1x" then
                HatchState.HatchCount = 1
            else
                HatchState.HatchCount = "Auto"
            end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("HatchAmount", UI.HatchAmountDropdown, function() return hatchCountToLabel(HatchState.HatchCount) end, function(v)
        if v == "8x" then HatchState.HatchCount = 8
        elseif v == "3x" then HatchState.HatchCount = 3
        elseif v == "1x" then HatchState.HatchCount = 1
        else HatchState.HatchCount = "Auto" end
    end)

    UI.AutoHatchToggle = nil
    UI.AutoHatchToggle = UI.EggTab:CreateToggle({
        name = "Auto Hatch Egg",
        flag = "AutoHatch",
        description = "Automatically hatches the selected egg at the exact server speed",
        value = false,
        callback = function(val)
            if val then
                local neededSlots = (HatchState.HatchCount == 8) and 8 or ((HatchState.HatchCount == 3) and 3 or 1)
                local ownedCount, maxStorage, freeSlots = getPetStorageInfo()
                if freeSlots < neededSlots and (HatchState.HatchCount ~= "Auto" or freeSlots < 1) then
                    HatchState.AutoHatch = false
                    task.defer(function()
                        pcall(function()
                            if UI.AutoHatchToggle and UI.AutoHatchToggle.Set then
                                UI.AutoHatchToggle:Set(false)
                            end
                        end)
                    end)
                    safeNotify({
                        title = "Inventory Full!",
                        content = string.format("Storage is full (%d/%d). This hatch needs %d free slot(s) - please delete or craft pets to keep hatching!", ownedCount, maxStorage, neededSlots),
                        duration = 6
                    })
                    return
                end
            end
            HatchState.AutoHatch = val
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("AutoHatch", UI.AutoHatchToggle, function() return HatchState.AutoHatch end, function(v) HatchState.AutoHatch = v end)

    UI.EggTab:CreateButton({
        name = "Teleport to Selected Egg",
        callback = function()
            task.spawn(function()
                local ok, reason = goToEgg(HatchState.SelectedEgg)
                safeNotify({
                    title = "Egg Teleport",
                    content = ok and ("Moved to " .. tostring(HatchState.SelectedEgg) .. " Egg") or ("Failed: " .. tostring(reason))
                })
            end)
        end
    })

    UI.EggTab:CreateButton({
        name = "Refresh Live Eggs & Secret Catalog",
        callback = function()
            eggNames = buildDynamicEggList()
            rebuildSecretCatalog()
            pcall(function()
                if UI.EggDropdown and UI.EggDropdown.Refresh then
                    UI.EggDropdown:Refresh(eggNames)
                end
            end)
            safeNotify({ title = "Egg Discovery", content = string.format("Refreshed %d live eggs in Workspace!", #eggNames) })
        end
    })

    createBoundToggle(UI.EggTab, {
        name = "Fast Hatch / Skip Normal Animation",
        flag = "SkipAnimation",
        description = "Bypasses all normal/rare 3D egg opening cutscenes instantly",
        value = true,
    }, function() return HatchState.SkipAnimation end, function(v) HatchState.SkipAnimation = v end, function(val)
        if val and Mod.HatchRenderer then
            pcall(function()
                Mod.HatchRenderer:Cancel()
                Mod.HatchRenderer:FlushHudRestore()
            end)
        end
    end)

    createBoundToggle(UI.EggTab, {
        name = "Skip Secret Cutscenes",
        flag = "SkipSecretAnimation",
        description = "Skips Secret pet cutscene in ~0.3s while safely sending SecretAnimationCompleted & triggering Secret Webhook",
        value = true,
    }, function() return HatchState.SkipSecretAnimation end, function(v) HatchState.SkipSecretAnimation = v end, function(val)
        if val and Mod.SecretHatchRenderer then
            pcall(function()
                Mod.SecretHatchRenderer:Cancel()
            end)
        end
    end)

    return EggTab
end

return EggTab
