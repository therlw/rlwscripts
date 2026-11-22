-- src/UI/Tabs/FishingWorldTab.lua
-- Balıkçılık Dünyası (Fishing World / Event) Otomasyon Sekmesi

local FishingWorldTab = {}

function FishingWorldTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local FW = ctx.States.FishingWorld

    local Tab = Window:CreateTab({
        name = "Balıkçılık",
        icon = 93364949241311,
    })
    UI.FishingWorldTab = Tab

    Tab:CreateSection({ name = "Balıkçılık Yumurtaları" })
    UI.FishingStatusText = Tab:CreateText({
        name = "Balıkçılık Durumu",
        text = tostring(ctx.Runtime.Status.Fishing or "Balıkçılık etkinliği beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "En Yakın Yumurtayı Otomatik Aç",
        flag = "FishAutoEgg",
        value = FW.AutoBuyNearestEgg,
        description = "Balıkçılık adasındaki en iyi / en yakın yumurtayı açar",
    }, function()
        return FW.AutoBuyNearestEgg
    end, function(v)
        FW.AutoBuyNearestEgg = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Yumurta Açma Adedi",
        flag = "FishEggAmount",
        options = { "Max", "1", "3", "10", "50" },
        labels = {
            ["Max"] = "Maksimum",
        },
        value = FW.EggAmount,
    }, function()
        return FW.EggAmount
    end, function(v)
        FW.EggAmount = v
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Otomatik Balık Tutma, Satış & Parşömenler" })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Balık Tut",
        flag = "FishAutoFish",
        value = FW.AutoEventFishing,
        description = "Balıkçılık etkinliğinde otomatik olta atar ve yakalar",
    }, function()
        return FW.AutoEventFishing
    end, function(v)
        FW.AutoEventFishing = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Balık Tutma Modu",
        flag = "FishMode",
        options = { "Game Autofish + Cast", "Game Autofish", "Auto Cast & Reel" },
        labels = {
            ["Game Autofish + Cast"] = "Oyun Oto-Balık + Olta At",
            ["Game Autofish"] = "Oyun İçi Oto-Balık",
            ["Auto Cast & Reel"] = "Otomatik Olta At & Çek",
        },
        value = FW.FishingMode,
    }, function()
        return FW.FishingMode
    end, function(v)
        FW.FishingMode = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Tutulan Balıkları Otomatik Sat",
        flag = "FishAutoSell",
        value = FW.AutoSellEventFish,
        description = "Etkinlik balıklarını otomatik olarak balık tüccarına satar",
    }, function()
        return FW.AutoSellEventFish
    end, function(v)
        FW.AutoSellEventFish = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Sonraki Oltayı Otomatik Al (Rod)",
        flag = "FishAutoRod",
        value = FW.AutoBuyNextRod,
        description = "Paran yettiğinde bir üst seviye oltayı satın alır",
    }, function()
        return FW.AutoBuyNextRod
    end, function(v)
        FW.AutoBuyNextRod = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Balıkçılık Parşömenlerini Kullan (Scrolls)",
        flag = "FishAutoScrolls",
        value = FW.AutoUseScrolls,
        description = "Seçili Luck, Speed ve XP parşömenlerini otomatik tazeler",
    }, function()
        return FW.AutoUseScrolls
    end, function(v)
        FW.AutoUseScrolls = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Kullanılacak Parşömenler",
        flag = "FishSelectedScrolls",
        options = { "Fishing Luck Scroll", "Fishing Speed Scroll", "Fishing XP Scroll" },
        labels = {
            ["Fishing Luck Scroll"] = "Balık Şans Parşömeni (Luck)",
            ["Fishing Speed Scroll"] = "Balık Hız Parşömeni (Speed)",
            ["Fishing XP Scroll"] = "Balık XP Parşömeni",
        },
        value = FW.SelectedScrolls,
        multiSelect = true,
    }, function()
        return FW.SelectedScrolls
    end, function(v)
        FW.SelectedScrolls = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Yem Kovası Kullan (Bucket O' Chum)",
        flag = "FishAutoChum",
        value = FW.AutoUseBucketOfChum,
        description = "Nadir balık şansını artırmak için yem kovası kullanır",
    }, function()
        return FW.AutoUseBucketOfChum
    end, function(v)
        FW.AutoUseBucketOfChum = (v == true)
    end)

    return FishingWorldTab
end

return FishingWorldTab
