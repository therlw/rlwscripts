-- src/UI/Tabs/VisualsPerfTab.lua
-- Object/Egg/Player ESP, Ultra FPS Boost, 3D Render Kapatma + AFK Overlay, Anti-AFK & Auto-Reconnect

local VisualsPerfTab = {}

function VisualsPerfTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local States = ctx.States
    local Visuals = ctx.API.Visuals

    local Tab = Window:CreateTab({
        name = "ESP & Performans",
        icon = 93364949241311,
    })
    UI.VisualsPerfTab = Tab

    Tab:CreateSection({ name = "Görsel Algılama (ESP)" })

    UI.createBoundToggle(Tab, {
        name = "Etkinlik Nesneleri & Yumurta/Lure ESP",
        flag = "EventObjectESP",
        value = States.Visuals.EventObjectESP,
        description = "Haritadaki etkinlik şişeleri, yumurtalar ve tuzak kutularını duvar arkasından gösterir",
    }, function() return States.Visuals.EventObjectESP end, function(v)
        States.Visuals.EventObjectESP = (v == true)
        Visuals.RefreshESP()
    end)

    UI.createBoundToggle(Tab, {
        name = "Diğer Oyuncu ESP",
        flag = "PlayerPetESP",
        value = States.Visuals.PlayerPetESP,
    }, function() return States.Visuals.PlayerPetESP end, function(v)
        States.Visuals.PlayerPetESP = (v == true)
        Visuals.RefreshESP()
    end)

    Tab:CreateSection({ name = "Ultra Performans & Arka Plan Tasarrufu" })

    UI.createBoundToggle(Tab, {
        name = "Ultra FPS Booster (Gölgeler & Efektler Kapalı)",
        flag = "UltraFPSBoost",
        value = States.Visuals.UltraFPSBoost,
    }, function() return States.Visuals.UltraFPSBoost end, function(v)
        States.Visuals.UltraFPSBoost = (v == true)
        if States.Visuals.UltraFPSBoost then
            Visuals.ApplyUltraFPSBoost(true)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "3D Render Kapat (GPU Kullanımını Sıfırla)",
        flag = "Disable3DRender",
        value = States.Visuals.Disable3DRender,
        description = "Uzun AFK farm sırasında ekran kartı yükünü düşürür (farm arka planda devam eder)",
    }, function() return States.Visuals.Disable3DRender end, function(v)
        States.Visuals.Disable3DRender = (v == true)
        Visuals.Set3DRenderDisabled(States.Visuals.Disable3DRender)
    end)

    UI.createBoundToggle(Tab, {
        name = "Siyah AFK İstatistik Ekranını Göster",
        flag = "ShowAFKOverlay",
        value = States.Visuals.ShowAFKOverlay,
    }, function() return States.Visuals.ShowAFKOverlay end, function(v)
        States.Visuals.ShowAFKOverlay = (v == true)
        Visuals.UpdateAFKOverlay(States.Visuals.ShowAFKOverlay)
    end)

    Tab:CreateSection({ name = "Bağlantı Güvenliği (Anti-AFK & Reconnect)" })

    UI.createBoundToggle(Tab, {
        name = "Gelişmiş Anti-AFK (20 Dakika Koruma)",
        flag = "AntiAFK",
        value = States.Visuals.AntiAFK,
    }, function() return States.Visuals.AntiAFK end, function(v)
        States.Visuals.AntiAFK = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yeniden Bağlan (Auto-Reconnect)",
        flag = "AutoReconnect",
        value = States.Visuals.AutoReconnect,
        description = "Bağlantı kesilirse veya sunucu kapanırsa oyuna otomatik tekrar bağlanır",
    }, function() return States.Visuals.AutoReconnect end, function(v)
        States.Visuals.AutoReconnect = (v == true)
    end)

    return VisualsPerfTab
end

return VisualsPerfTab
