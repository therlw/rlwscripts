-- src/UI/HubExports.lua
-- Config Auto-Load Synchronization, Global _RLW_AdoptMeHub Export & Startup Toast

local HubExports = {}

function HubExports.Init(ctx)
    local CONFIG = ctx.Config
    local ConfigManager = ctx.Services.ConfigManager
    local UI = ctx.UI
    local States = ctx.States

    pcall(function()
        if CONFIG.Persistence and CONFIG.Persistence.AutoLoad and ConfigManager then
            local ok = ConfigManager:Load()
            if ok and UI.ConfigStatusText and UI.ConfigStatusText.Set then
                UI.ConfigStatusText:Set("config.json otomatik yüklendi: " .. os.date("%X"))
            end
        end
    end)

    pcall(function()
        local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
        genFn()._RLW_AdoptMeHub = {
            Version = ctx.Version,
            Generation = ctx.Generation,
            CONFIG = CONFIG,
            ConfigManager = ConfigManager,
            States = States,
            Runtime = ctx.Runtime,
            API = ctx.API,
            DualFarm = ctx.DualFarm,
            Unload = function()
                if ctx.Lifecycle and ctx.Lifecycle.Unload then
                    ctx.Lifecycle.Unload()
                end
            end,
        }
    end)

    return HubExports
end

function HubExports.Start(ctx)
    if ctx.UI and ctx.UI.safeNotify then
        ctx.UI.safeNotify({
            title = "AdoptMeHub (2026)",
            content = "Oto Farm, Harita & Etkinlik, Pet & Envanter, Ev & Takas, ESP & Performans modülleri yüklendi!",
            duration = 5,
            force = true,
        })
    end
end

return HubExports
