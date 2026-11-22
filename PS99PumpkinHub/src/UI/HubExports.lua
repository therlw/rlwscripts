-- src/UI/HubExports.lua
-- Config Auto-Load, Global _RLW_PS99Hub API Export & Startup Toast

local HubExports = {}

function HubExports.Init(ctx)
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local UI = ctx.UI
    local States = ctx.States

    pcall(function()
        if CONFIG.Persistence and CONFIG.Persistence.AutoLoad and ConfigManager then
            local ok = ConfigManager:Load()
            if ok and UI.ConfigStatusText and UI.ConfigStatusText.Set then
                UI.ConfigStatusText:Set("Auto-loaded config.json at " .. os.date("%X"))
            end
        end
    end)

    pcall(function()
        local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
        genFn()._RLW_PS99Hub = {
            Version = ctx.Version,
            Generation = ctx.Generation,
            CONFIG = CONFIG,
            ConfigManager = ConfigManager,
            States = States,
            Runtime = ctx.Runtime,
            API = ctx.API,
            Unload = function()
                if ctx.Lifecycle and ctx.Lifecycle.CleanupAll then
                    ctx.Lifecycle.CleanupAll()
                end
            end,
        }
    end)

    return HubExports
end

function HubExports.Start(ctx)
    if ctx.UI and ctx.UI.safeNotify then
        ctx.UI.safeNotify({
            title = "PS99 Pumpkin Tycoon Hub",
            content = "Loaded Part 2 + Audited Turing/FFlag safe systems cleanly!",
        })
    end
end

return HubExports
