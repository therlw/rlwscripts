-- src/UI/Tabs/ConfigTab.lua
-- Tab 9: Config, Hotkeys & Debug (Persistence, Retries, Action Keybinds & Self-Diagnostics)

local ConfigTab = {}

function ConfigTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local WebhookSender = ctx.WebhookSender
    local SecretDetector = ctx.SecretDetector
    local AutoFarmState = ctx.States.AutoFarm
    local HatchState = ctx.States.Hatch
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local bindHotkeyElement = UI.bindHotkeyElement

    UI.ConfigTab = Window:CreateTab({ name = "Config & Debug", icon = 93364949241311 })
    UI.ConfigTab:CreateSection({ name = "Config File (TapSimHub/config.json)" })

    UI.ConfigStatusText = UI.ConfigTab:CreateText({
        name = "Config Status",
        text = "Path: " .. tostring(CONFIG.Persistence.FileName)
    })

    createBoundToggle(UI.ConfigTab, {
        name = "Auto Save Config on Change",
        flag = "ConfigAutoSave",
        value = CONFIG.Persistence.AutoSave,
    }, function() return CONFIG.Persistence.AutoSave end, function(v) CONFIG.Persistence.AutoSave = v end)

    createBoundToggle(UI.ConfigTab, {
        name = "Auto Load Config on Startup",
        flag = "ConfigAutoLoad",
        value = CONFIG.Persistence.AutoLoad,
    }, function() return CONFIG.Persistence.AutoLoad end, function(v) CONFIG.Persistence.AutoLoad = v end)

    UI.ConfigTab:CreateButton({
        name = "Save Config Now",
        callback = function()
            local ok, msg = ConfigManager:Save()
            if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                pcall(function() UI.ConfigStatusText:Set(ok and ("Saved cleanly at " .. os.date("%X")) or ("Save error: " .. tostring(msg))) end)
            end
            safeNotify({ title = "Config Save", content = ok and ("Saved to " .. tostring(msg)) or ("Error: " .. tostring(msg)) })
        end
    })

    UI.ConfigTab:CreateButton({
        name = "Load Config from Disk",
        callback = function()
            local ok, msg = ConfigManager:Load()
            if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                pcall(function() UI.ConfigStatusText:Set(ok and ("Loaded at " .. os.date("%X")) or ("Load note: " .. tostring(msg))) end)
            end
            safeNotify({ title = "Config Load", content = ok and "Config loaded and synced to UI!" or ("Note: " .. tostring(msg)) })
        end
    })

    UI.ConfigTab:CreateButton({
        name = "Reset All Config to Defaults",
        callback = function()
            ConfigManager:Reset()
            ConfigManager:Save()
            safeNotify({ title = "Config Reset", content = "Restored defaults and updated config.json." })
        end
    })

    UI.ConfigTab:CreateSection({ name = "Delays, Retries, Notifications & Debug" })

    UI.TapDelaySlider = UI.ConfigTab:CreateSlider({
        name = "Auto Tap Interval",
        flag = "CfgTapLoopDelay",
        range = { 0.05, 0.50 },
        increment = 0.005,
        value = CONFIG.TapLoopDelay,
        suffix = "s",
        callback = function(val)
            CONFIG.TapLoopDelay = val
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("CfgTapLoopDelay", UI.TapDelaySlider, function() return CONFIG.TapLoopDelay end, function(v) CONFIG.TapLoopDelay = tonumber(v) or 0.075 end)

    UI.TrashIntSlider = UI.ConfigTab:CreateSlider({
        name = "Trash Clean Interval",
        flag = "CfgTrashInterval",
        range = { 5, 120 },
        increment = 1,
        value = CONFIG.TrashCleanInterval,
        suffix = "s",
        callback = function(val)
            CONFIG.TrashCleanInterval = val
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("CfgTrashInterval", UI.TrashIntSlider, function() return CONFIG.TrashCleanInterval end, function(v) CONFIG.TrashCleanInterval = tonumber(v) or 25 end)

    UI.RemoteRetrySlider = UI.ConfigTab:CreateSlider({
        name = "Remote Invoke Retries",
        flag = "CfgRemoteRetries",
        range = { 1, 5 },
        increment = 1,
        value = CONFIG.Retries.RemoteRetries,
        callback = function(val)
            CONFIG.Retries.RemoteRetries = math.floor(val)
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("CfgRemoteRetries", UI.RemoteRetrySlider, function() return CONFIG.Retries.RemoteRetries end, function(v) CONFIG.Retries.RemoteRetries = tonumber(v) or 2 end)

    createBoundToggle(UI.ConfigTab, {
        name = "Enable Hub Notifications",
        flag = "CfgNotificationsEnabled",
        value = CONFIG.Notifications.Enabled,
    }, function() return CONFIG.Notifications.Enabled end, function(v) CONFIG.Notifications.Enabled = v end)

    createBoundToggle(UI.ConfigTab, {
        name = "Enable Secret Popup Alerts",
        flag = "CfgSecretAlerts",
        value = CONFIG.Notifications.SecretAlerts,
    }, function() return CONFIG.Notifications.SecretAlerts end, function(v) CONFIG.Notifications.SecretAlerts = v end)

    createBoundToggle(UI.ConfigTab, {
        name = "Debug Mode (Print Diagnostic Logs)",
        flag = "CfgDebugMode",
        value = CONFIG.Debug.DebugMode,
    }, function() return CONFIG.Debug.DebugMode end, function(v)
        CONFIG.Debug.DebugMode = v
        ctx.Runtime.DebugMode = v == true
    end)

    UI.ConfigTab:CreateSection({ name = "Action Hotkeys (Press Backspace to Clear)" })

    bindHotkeyElement("Toggle Auto Tap Hotkey", "ToggleAutoTap", CONFIG.Hotkeys.ToggleAutoTap, function()
        AutoFarmState.AutoTap = not AutoFarmState.AutoTap
        if UI.AutoTapToggle and UI.AutoTapToggle.Set then pcall(function() UI.AutoTapToggle:Set(AutoFarmState.AutoTap, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Tap: " .. tostring(AutoFarmState.AutoTap) })
    end)

    bindHotkeyElement("Toggle Auto Hatch Hotkey", "ToggleAutoHatch", CONFIG.Hotkeys.ToggleAutoHatch, function()
        HatchState.AutoHatch = not HatchState.AutoHatch
        if UI.AutoHatchToggle and UI.AutoHatchToggle.Set then pcall(function() UI.AutoHatchToggle:Set(HatchState.AutoHatch, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Hatch: " .. tostring(HatchState.AutoHatch) })
    end)

    bindHotkeyElement("Toggle Auto Rebirth Hotkey", "ToggleAutoRebirth", CONFIG.Hotkeys.ToggleAutoRebirth, function()
        AutoFarmState.AutoRebirth = not AutoFarmState.AutoRebirth
        if UI.AutoRebirthToggle and UI.AutoRebirthToggle.Set then pcall(function() UI.AutoRebirthToggle:Set(AutoFarmState.AutoRebirth, true) end) end
        safeNotify({ title = "Hotkey", content = "Auto Rebirth: " .. tostring(AutoFarmState.AutoRebirth) })
    end)

    bindHotkeyElement("Teleport Best Island Hotkey", "BestTeleport", CONFIG.Hotkeys.BestTeleport, function()
        task.spawn(function()
            local best = ctx.API.getBestUnlockedIsland()
            ctx.API.travelToIsland(best)
        end)
    end)

    bindHotkeyElement("Emergency Restore World Hotkey", "EmergencyRestore", CONFIG.Hotkeys.EmergencyRestore, function()
        pcall(ctx.API.restoreAllCulledInstances)
        safeNotify({ title = "Hotkey", content = "Emergency restored all culled instances!" })
    end)

    UI.ConfigTab:CreateText({
        name = "Menu Toggle Key",
        text = "Press RightShift (Rayfield default) to hide or show the Hub window."
    })

    UI.ConfigTab:CreateSection({ name = "Self-Diagnostics" })

    UI.ConfigTab:CreateButton({
        name = "Run Live System Audit & Health Check",
        callback = function()
            local wsEggs = workspace:FindFirstChild("Eggs") and #workspace.Eggs:GetChildren() or 0
            local dynEggs = #ctx.API.buildDynamicEggList()
            local dynIsls = #ctx.API.buildDynamicIslandList()
            local hasHttp = WebhookSender:GetRequestFn() ~= nil
            local hasFs = (type(writefile) == "function" and type(readfile) == "function")
            safeNotify({
                title = "Hub Diagnostics",
                content = string.format("Eggs: %d/%d | Islands: %d | HTTP: %s | FS: %s | Secrets Seen: %d",
                    dynEggs, wsEggs, dynIsls, tostring(hasHttp), tostring(hasFs), SecretDetector.TotalDetected),
                duration = 6,
                force = true,
            })
        end
    })

    return ConfigTab
end

return ConfigTab
