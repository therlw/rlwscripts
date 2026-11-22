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
                UI.ConfigStatusText:Set("config.json otomatik yüklendi: " .. os.date("%X"))
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
    if ctx.Optimizer and ctx.Optimizer.ApplyAll then
        pcall(ctx.Optimizer.ApplyAll)
    end
    if ctx.UI and ctx.UI.safeNotify then
        ctx.UI.safeNotify({
            title = "PS99 Hub (Güncel Etkinlik + Dünyalar)",
            content = "Güncel Etkinlik, Genel, Oto Farm, Yumurta, Otomatik İşler, Balıkçılık, Çiftlik, Posta, Optimizasyon ve Webhook yüklendi!",
        })
    end
end

return HubExports
