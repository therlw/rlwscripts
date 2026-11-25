-- src/UI/Tabs/ConfigTab.lua
-- Yapılandırma Dosyası, Bildirimler, Klavye Kısayolları & Güvenli Kapatma Sekmesi

local ConfigTab = {}

function ConfigTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local States = ctx.States

    local Tab = Window:CreateTab({
        name = "Ayarlar",
        icon = 93364949241311,
    })
    UI.ConfigTab = Tab

    Tab:CreateSection({ name = "Yapılandırma Dosyası (" .. tostring(CONFIG.Persistence.FileName) .. ")" })

    UI.ConfigStatusText = Tab:CreateText({
        name = "Ayar Durumu",
        text = "Kayıt yolu: " .. tostring(CONFIG.Persistence.FileName),
    })

    UI.createBoundToggle(Tab, {
        name = "Değişiklikleri Otomatik Kaydet (Auto Save)",
        flag = "CfgAutoSave",
        value = CONFIG.Persistence.AutoSave,
    }, function() return CONFIG.Persistence.AutoSave end, function(v)
        CONFIG.Persistence.AutoSave = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Açılışta Otomatik Yükle (Auto Load)",
        flag = "CfgAutoLoad",
        value = CONFIG.Persistence.AutoLoad,
    }, function() return CONFIG.Persistence.AutoLoad end, function(v)
        CONFIG.Persistence.AutoLoad = (v == true)
    end)

    Tab:CreateButton({
        name = "Ayarları Şimdi Kaydet",
        callback = function()
            local ok = ConfigManager and ConfigManager:Save()
            pcall(function()
                if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                    UI.ConfigStatusText:Set(ok and ("Temiz kaydedildi: " .. os.date("%X")) or "Kaydetme başarısız!")
                end
            end)
            UI.safeNotify({
                title = "Ayarlar",
                content = ok and "Tüm ayarlar kaydedildi." or "Kaydetme başarısız.",
                duration = 3,
                force = true,
            })
        end,
    })

    Tab:CreateButton({
        name = "Ayarları Dosyadan Yükle",
        callback = function()
            local ok = ConfigManager and ConfigManager:Load()
            pcall(function()
                if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                    UI.ConfigStatusText:Set(ok and ("Yüklendi: " .. os.date("%X")) or "Kayıtlı ayar dosyası yok")
                end
            end)
            UI.safeNotify({
                title = "Ayarlar",
                content = ok and "Ayarlar diskten yüklendi." or "Kayıtlı config bulunamadı.",
                duration = 3,
                force = true,
            })
        end,
    })

    Tab:CreateSection({ name = "Bildirim & Hata Ayıklama" })

    UI.createBoundToggle(Tab, {
        name = "Bildirimleri Göster",
        flag = "CfgNotifEnabled",
        value = CONFIG.Notifications.Enabled,
    }, function() return CONFIG.Notifications.Enabled end, function(v)
        CONFIG.Notifications.Enabled = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Hata Ayıklama Günlükleri (Debug Mode)",
        flag = "CfgDebugMode",
        value = CONFIG.Debug.DebugMode,
    }, function() return CONFIG.Debug.DebugMode end, function(v)
        CONFIG.Debug.DebugMode = (v == true)
    end)

    Tab:CreateSection({ name = "Klavye Kısayolları" })

    UI.bindHotkeyElement("Dual Farm Aç/Kapat", "ToggleDualFarm", CONFIG.Hotkeys.ToggleDualFarm, function()
        States.Farm.DualFarm = not States.Farm.DualFarm
        if ConfigManager and ConfigManager.SyncAllUI then
            ConfigManager:SyncAllUI()
        end
        UI.safeNotify({
            title = "Kısayol",
            content = "Dual Farm: " .. (States.Farm.DualFarm and "AÇIK" or "KAPALI"),
            duration = 2,
        })
    end, Tab)

    Tab:CreateSection({ name = "Hub Kontrolü" })

    Tab:CreateButton({
        name = "AdoptMeHub'ı Tamamen Kapat (Unload)",
        callback = function()
            if ctx.Lifecycle and ctx.Lifecycle.Unload then
                ctx.Lifecycle.Unload()
            end
        end,
    })

    return ConfigTab
end

return ConfigTab
