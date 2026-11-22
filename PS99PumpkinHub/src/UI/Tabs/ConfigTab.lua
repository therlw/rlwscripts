-- src/UI/Tabs/ConfigTab.lua
-- Yapılandırma Dosyası, Bildirimler & Klavye Kısayolları Sekmesi

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

    --------------------------------------------------------------------
    -- Yapılandırma Dosyası (config.json)
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Yapılandırma Dosyası (" .. tostring(CONFIG.Persistence.FileName) .. ")" })

    UI.ConfigStatusText = Tab:CreateText({
        name = "Ayar Durumu",
        text = "Kayıt yolu: " .. tostring(CONFIG.Persistence.FileName),
    })

    UI.createBoundToggle(Tab, {
        name = "Değişiklikleri Otomatik Kaydet (Auto Save)",
        flag = "CfgAutoSave",
        value = CONFIG.Persistence.AutoSave,
        description = "Bir ayar değiştirildiğinde 1-2 saniye içinde otomatik diske kaydeder",
    }, function()
        return CONFIG.Persistence.AutoSave
    end, function(v)
        CONFIG.Persistence.AutoSave = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Açılışta Otomatik Yükle (Auto Load)",
        flag = "CfgAutoLoad",
        value = CONFIG.Persistence.AutoLoad,
        description = "Script her başlatıldığında kayıtlı ayarları otomatik uygular",
    }, function()
        return CONFIG.Persistence.AutoLoad
    end, function(v)
        CONFIG.Persistence.AutoLoad = (v == true)
    end)

    Tab:CreateButton({
        name = "Ayarları Şimdi Kaydet",
        callback = function()
            local ok = ConfigManager:Save()
            pcall(function()
                if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                    UI.ConfigStatusText:Set(ok and ("Temiz kaydedildi: " .. os.date("%X")) or "Kaydetme başarısız!", nil)
                end
            end)
            UI.safeNotify({
                title = "Ayarlar",
                content = ok and "Tüm ayarlar config.json dosyasına kaydedildi." or "Ayar dosyası kaydedilemedi.",
                duration = 3,
                force = true,
            })
        end,
    })

    Tab:CreateButton({
        name = "Ayarları Dosyadan Yükle",
        callback = function()
            local ok = ConfigManager:Load()
            if ConfigManager.SyncUI then
                pcall(function() ConfigManager:SyncUI() end)
            end
            pcall(function()
                if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                    UI.ConfigStatusText:Set(ok and ("Yüklendi: " .. os.date("%X")) or "Kayıtlı config.json bulunamadı", nil)
                end
            end)
            UI.safeNotify({
                title = "Ayarlar",
                content = ok and "Kayıtlı ayarlar diskten yüklendi." or "Kayıtlı ayar dosyası bulunamadı.",
                duration = 3,
                force = true,
            })
        end,
    })

    Tab:CreateButton({
        name = "Tüm Ayarları Varsayılana Sıfırla",
        callback = function()
            ConfigManager:Reset()
            ConfigManager:Save()
            pcall(function()
                if UI.ConfigStatusText and UI.ConfigStatusText.Set then
                    UI.ConfigStatusText:Set("Varsayılanlara sıfırlandı: " .. os.date("%X"), nil)
                end
            end)
            UI.safeNotify({
                title = "Ayarlar Sıfırlandı",
                content = "Tüm ayarlar varsayılan değerlere döndürüldü.",
                duration = 4,
                force = true,
            })
        end,
    })

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- Bildirimler & Tanılama
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Bildirimler & Geliştirici" })

    UI.createBoundToggle(Tab, {
        name = "Bildirimleri Göster",
        flag = "CfgNotifications",
        value = CONFIG.Notifications.Enabled,
        description = "Rebirth, nadir spawn ve sistem bildirim baloncuklarını açar",
    }, function()
        return CONFIG.Notifications.Enabled
    end, function(v)
        CONFIG.Notifications.Enabled = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Geliştirici Modu (Konsol Logları)",
        flag = "CfgDebugMode",
        value = CONFIG.Debug.DebugMode,
        description = "Roblox konsoluna detaylı teknik hata ayıklama çıktıları yazar",
    }, function()
        return CONFIG.Debug.DebugMode
    end, function(v)
        CONFIG.Debug.DebugMode = (v == true)
    end)

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- Klavye Kısayolları
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Klavye Kısayolları (Hotkeys)" })

    UI.bindHotkeyElement("Oto Tıklama Aç / Kapat", "ToggleAutoTap", function()
        local nxt = not (States.Farm.AutoTap == true)
        States.Farm.AutoTap = nxt
        pcall(function()
            if UI.AutoTapToggle and UI.AutoTapToggle.Set then
                UI.AutoTapToggle:Set(nxt, true)
            end
        end)
        ConfigManager:MarkDirty()
    end)

    UI.bindHotkeyElement("Oto Buton Alımını Aç / Kapat", "ToggleAutoButtons", function()
        local nxt = not (States.PumpkinTycoon.AutoBuyButtons == true)
        States.PumpkinTycoon.AutoBuyButtons = nxt
        pcall(function()
            if UI.AutoButtonsToggle and UI.AutoButtonsToggle.Set then
                UI.AutoButtonsToggle:Set(nxt, true)
            end
        end)
        ConfigManager:MarkDirty()
    end)

    UI.bindHotkeyElement("Nadir Spawn Yakalamayı Aç / Kapat", "ToggleAutoCatchRare", function()
        local nxt = not (States.PumpkinTycoon.AutoCatchRareSpawns == true)
        States.PumpkinTycoon.AutoCatchRareSpawns = nxt
        pcall(function()
            if UI.AutoCatchRareToggle and UI.AutoCatchRareToggle.Set then
                UI.AutoCatchRareToggle:Set(nxt, true)
            end
        end)
        ConfigManager:MarkDirty()
    end)

    return ConfigTab
end

return ConfigTab
