-- src/UI/Tabs/ConfigTab.lua
-- Config Persistence, Notifications, Debug Logs & Action Hotkeys

local ConfigTab = {}

function ConfigTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local PT = ctx.States.PumpkinTycoon
    local Farm = ctx.States.Farm
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local bindHotkeyElement = UI.bindHotkeyElement

    local tab = Window:CreateTab({ name = "Config", icon = 93364949241311 })
    UI.ConfigTab = tab

    tab:CreateSection({ name = "Config File (PS99PumpkinHub/config.json)" })

    UI.ConfigStatusText = tab:CreateText({
        name = "Config Status",
        text = "Path: " .. tostring(CONFIG.Persistence.FileName),
    })

    createBoundToggle(tab, {
        name = "Auto Save Config on Change",
        flag = "CfgAutoSave",
        value = CONFIG.Persistence.AutoSave,
    }, function() return CONFIG.Persistence.AutoSave end, function(v) CONFIG.Persistence.AutoSave = v end)

    createBoundToggle(tab, {
        name = "Auto Load Config on Startup",
        flag = "CfgAutoLoad",
        value = CONFIG.Persistence.AutoLoad,
    }, function() return CONFIG.Persistence.AutoLoad end, function(v) CONFIG.Persistence.AutoLoad = v end)

    tab:CreateButton({
        name = "Save Config Now",
        callback = function()
            local ok, msg = ConfigManager:Save()
            if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                pcall(function() UI.ConfigStatusText:Set(ok and ("Saved cleanly at " .. os.date("%X")) or ("Save error: " .. tostring(msg))) end)
            end
            safeNotify({ title = "Config Save", content = ok and ("Saved to " .. tostring(msg)) or tostring(msg) })
        end,
    })

    tab:CreateButton({
        name = "Load Config from Disk",
        callback = function()
            local ok, msg = ConfigManager:Load()
            if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                pcall(function() UI.ConfigStatusText:Set(ok and ("Loaded at " .. os.date("%X")) or ("Note: " .. tostring(msg))) end)
            end
            safeNotify({ title = "Config Load", content = ok and "Config loaded and synced!" or tostring(msg) })
        end,
    })

    tab:CreateButton({
        name = "Reset All Config to Defaults",
        callback = function()
            ConfigManager:Reset()
            ConfigManager:Save()
            safeNotify({ title = "Config Reset", content = "Restored default settings." })
        end,
    })

    tab:CreateSection({ name = "Notifications & Diagnostics" })

    createBoundToggle(tab, {
        name = "Enable Notifications",
        flag = "CfgNotifications",
        value = CONFIG.Notifications.Enabled,
    }, function() return CONFIG.Notifications.Enabled end, function(v) CONFIG.Notifications.Enabled = v end)

    createBoundToggle(tab, {
        name = "Debug Mode (Console Logs)",
        flag = "CfgDebugMode",
        value = CONFIG.Debug.DebugMode,
    }, function() return CONFIG.Debug.DebugMode end, function(v) CONFIG.Debug.DebugMode = v end)

    tab:CreateSection({ name = "Hotkeys" })

    bindHotkeyElement("Toggle Auto Tap", "ToggleAutoTap", CONFIG.Hotkeys.ToggleAutoTap, function()
        Farm.AutoTap = not Farm.AutoTap
        if UI.AutoTapToggle and UI.AutoTapToggle.Set then pcall(function() UI.AutoTapToggle:Set(Farm.AutoTap, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Tap: " .. tostring(Farm.AutoTap) })
    end)

    bindHotkeyElement("Toggle Auto Buy Buttons", "ToggleAutoButtons", CONFIG.Hotkeys.ToggleAutoButtons, function()
        PT.AutoBuyButtons = not PT.AutoBuyButtons
        if UI.AutoButtonsToggle and UI.AutoButtonsToggle.Set then pcall(function() UI.AutoButtonsToggle:Set(PT.AutoBuyButtons, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Buy Buttons: " .. tostring(PT.AutoBuyButtons) })
    end)

    bindHotkeyElement("Toggle Auto Catch Rare Spawns", "ToggleAutoCatchRare", CONFIG.Hotkeys.ToggleAutoCatchRare, function()
        PT.AutoCatchRareSpawns = not PT.AutoCatchRareSpawns
        if UI.AutoCatchRareToggle and UI.AutoCatchRareToggle.Set then pcall(function() UI.AutoCatchRareToggle:Set(PT.AutoCatchRareSpawns, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Catch Rare Spawns: " .. tostring(PT.AutoCatchRareSpawns) })
    end)

    return ConfigTab
end

return ConfigTab
