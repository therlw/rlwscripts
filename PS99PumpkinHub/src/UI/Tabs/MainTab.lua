-- src/UI/Tabs/MainTab.lua
-- Genel Özellikler & Günlük Ödüller Sekmesi

local MainTab = {}

function MainTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Main = ctx.States.Main

    local Tab = Window:CreateTab({
        name = "Genel",
        icon = 93364949241311,
    })
    UI.MainTab = Tab

    Tab:CreateSection({ name = "Durum & Koruma" })
    UI.MainStatusText = Tab:CreateText({
        name = "Genel Özellik Durumu",
        text = tostring(ctx.Runtime.Status.Main or "Genel özellikler beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "Anti-AFK Koruması",
        flag = "MainAntiAFK",
        value = Main.AntiAFK,
        description = "20 dakika hareketsizlikten oyundan atılmanı engeller",
    }, function()
        return Main.AntiAFK
    end, function(v)
        Main.AntiAFK = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Ücretsiz Ödüller & Harita Özellikleri" })

    UI.createBoundToggle(Tab, {
        name = "Ücretsiz Hediyeleri Topla (Free Gifts)",
        flag = "MainAutoFreeGifts",
        value = Main.AutoClaimFreeGifts,
        description = "Süresi dolan ücretsiz hediye kutularını otomatik alır",
    }, function()
        return Main.AutoClaimFreeGifts
    end, function(v)
        Main.AutoClaimFreeGifts = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Rütbe Ödüllerini Topla (Rank Rewards)",
        flag = "MainAutoRankRewards",
        value = Main.AutoClaimRankRewards,
        description = "Açılan rütbe ödüllerini otomatik toplar",
    }, function()
        return Main.AutoClaimRankRewards
    end, function(v)
        Main.AutoClaimRankRewards = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Sonsuz Paket Ödüllerini Al (Forever Pack)",
        flag = "MainAutoForeverPack",
        value = Main.AutoClaimForeverPack,
        description = "Forever Pack içindeki ücretsiz adımları otomatik alır",
    }, function()
        return Main.AutoClaimForeverPack
    end, function(v)
        Main.AutoClaimForeverPack = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Balon Patlat (Hediye Balonları)",
        flag = "MainAutoBalloons",
        value = Main.AutoPopBalloons,
        description = "Haritada uçan hediye balonlarını otomatik patlatıp toplar",
    }, function()
        return Main.AutoPopBalloons
    end, function(v)
        Main.AutoPopBalloons = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Cennet Merdiveninden Çık (Stairway)",
        flag = "MainAutoLeaveStairway",
        value = Main.AutoLeaveStairway,
        description = "Stairway to Heaven alanına girilirse otomatik çıkış yapar",
    }, function()
        return Main.AutoLeaveStairway
    end, function(v)
        Main.AutoLeaveStairway = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Ağaç Ev Tüccarı (Treehouse Merchant)",
        flag = "MainAutoTreehouseMerchant",
        value = Main.AutoTreehouseMerchant,
        description = "Secret Treehouse içindeki ürün tekliflerini otomatik alır",
    }, function()
        return Main.AutoTreehouseMerchant
    end, function(v)
        Main.AutoTreehouseMerchant = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Kristal Anahtar Kalesi (Crystal Key)",
        flag = "MainAutoCrystalKeyCastle",
        value = Main.AutoCrystalKeyCastle,
        description = "Anahtar biriktikçe Crystal Key sandığını otomatik açar",
    }, function()
        return Main.AutoCrystalKeyCastle
    end, function(v)
        Main.AutoCrystalKeyCastle = (v == true)
    end)

    return MainTab
end

return MainTab
