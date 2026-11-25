-- src/UI/Tabs/EventsTab.lua
-- 2026 Harita Işınlayıcıları, Lightning Dimension, Mini Oyunlar & Özel İksir/Bisküviler

local EventsTab = {}

function EventsTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local States = ctx.States
    local Events = ctx.API.Events
    local Lifecycle = ctx.Lifecycle

    local Tab = Window:CreateTab({
        name = "Harita & Etkinlik",
        icon = 93364949241311,
    })
    UI.EventsTab = Tab

    Tab:CreateSection({ name = "2026 Güncel Konum Işınlayıcıları" })

    local eventStatus = Tab:CreateText({
        name = "Etkinlik & Konum Durumu",
        text = "Durum: Beklemede",
    })

    Lifecycle.SpawnLoop("EventsTabStatus", 1.5, function()
        if eventStatus and eventStatus.Set then
            pcall(function()
                eventStatus:Set("Durum: " .. tostring(ctx.Runtime.Status.Events))
            end)
        end
    end)

    local labels = Events.GetTeleportLabels()
    local selectedNode = labels[1] or "Ana Harita (Town)"

    Tab:CreateDropdown({
        name = "Hedef Bölge Seç",
        options = labels,
        value = selectedNode,
        forgetState = true,
        callback = function(val)
            selectedNode = val
        end,
    })

    Tab:CreateButton({
        name = "Seçilen Bölgeye Git (Işınlan)",
        callback = function()
            local ok = Events.TeleportTo(selectedNode)
            UI.safeNotify({
                title = "Işınlanma",
                content = ok and ("Gidildi: " .. tostring(selectedNode)) or ("Geçiş başarısız: " .. tostring(selectedNode)),
                duration = 2.5,
            })
        end,
    })

    -- Quick one-click popular 2026 shortcuts
    for _, quick in ipairs({
        { label = "Lightning Dimension'a Git", key = "LightningDimension" },
        { label = "Cat Cafe'ye Git (2026)", key = "CatCafe" },
        { label = "Nursery (Kreş)", key = "Nursery" },
        { label = "Neon Mağarası (Neon Cave)", key = "NeonCave" },
        { label = "Kendi Evime Dön", key = "Housing" },
    }) do
        Tab:CreateButton({
            name = quick.label,
            callback = function()
                Events.TeleportTo(quick.key)
            end,
        })
    end

    Tab:CreateSection({ name = "2026 Etkinlik & Mini Oyun Otomasyonu" })

    UI.createBoundToggle(Tab, {
        name = "Lightning Dimension Otomatik Farm",
        flag = "AutoLightningDimension",
        value = States.Events.AutoLightningDimension,
        description = "Lightning Dimension bölgesine geçer, şişe/yıldırım görevlerini ve nesneleri toplar",
    }, function() return States.Events.AutoLightningDimension end, function(v)
        States.Events.AutoLightningDimension = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Auto-Minigames & Otomatik Katılım",
        flag = "AutoMinigames",
        value = States.Events.AutoMinigames,
        description = "Aktif veya davet gelen mini oyunlara otomatik katılır",
    }, function() return States.Events.AutoMinigames end, function(v)
        States.Events.AutoMinigames = (v == true)
    end)

    Tab:CreateSection({ name = "Özel Yemler & Yaş İksirleri (Kitty Biscuit / Age Potion)" })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Kitty Biscuit Kullan (Cat Cafe)",
        flag = "AutoUseKittyBiscuit",
        value = States.Events.AutoUseKittyBiscuit,
    }, function() return States.Events.AutoUseKittyBiscuit end, function(v)
        States.Events.AutoUseKittyBiscuit = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Age-Up Potion Kullan",
        flag = "AutoUseAgePotions",
        value = States.Events.AutoUseAgePotions,
        description = "Kuşanılmış pet Full Grown değilse otomatik Yaş İksiri içirir",
    }, function() return States.Events.AutoUseAgePotions end, function(v)
        States.Events.AutoUseAgePotions = (v == true)
    end)

    Tab:CreateButton({
        name = "Şimdi 1x Kitty Biscuit / Age Potion Kullan",
        callback = function()
            local ok, detail = Events.UseSpecialItemByKinds({
                "cat_cafe_2026_kitty_biscuit",
                "super_age_potion",
                "pet_age_potion",
                "tiny_pet_age_potion",
            })
            UI.safeNotify({
                title = "Özel Eşya",
                content = ok and ("Kullanıldı: " .. tostring(detail)) or tostring(detail),
                duration = 2.5,
            })
        end,
    })

    return EventsTab
end

return EventsTab
