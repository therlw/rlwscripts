-- src/UI/Tabs/EggTab.lua
-- Yumurta Açma, Altın/Gökkuşağı Çevirme & Tılsım (Charm) Sekmesi

local EggTab = {}

function EggTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Egg = ctx.States.Egg

    local Tab = Window:CreateTab({
        name = "Yumurta & Pet",
        icon = 93364949241311,
    })
    UI.EggTab = Tab

    Tab:CreateSection({ name = "Yumurta Açma (Auto Hatch)" })
    UI.EggStatusText = Tab:CreateText({
        name = "Yumurta & Makine Durumu",
        text = tostring(ctx.Runtime.Status.Egg or "Yumurta & Pet makineleri beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yumurta Aç",
        flag = "EggAutoBuy",
        value = Egg.AutoBuyEgg,
        description = "Seçilen yumurtayı belirlenen adette sürekli açar",
    }, function()
        return Egg.AutoBuyEgg
    end, function(v)
        Egg.AutoBuyEgg = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Hedef Yumurta Seçimi",
        flag = "EggTargetMode",
        options = { "Best Unlocked", "Nearest Unlocked" },
        labels = {
            ["Best Unlocked"] = "Kilitsiz En İyi Yumurta",
            ["Nearest Unlocked"] = "En Yakın Yumurta",
        },
        value = Egg.TargetEggMode,
    }, function()
        return Egg.TargetEggMode
    end, function(v)
        Egg.TargetEggMode = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Açılacak Yumurta Adedi",
        flag = "EggHatchAmt",
        options = { "Max", "1", "3", "10", "50" },
        labels = {
            ["Max"] = "Maksimum",
        },
        value = Egg.HatchAmount,
    }, function()
        return Egg.HatchAmount
    end, function(v)
        Egg.HatchAmount = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Farm Bölgesinden Ayrılma",
        flag = "EggStayBreakableZone",
        value = Egg.StayInBreakableZone,
        description = "Yumurtaya gitmeden uzaktan açarak petlerin farma devam etmesini sağlar",
    }, function()
        return Egg.StayInBreakableZone
    end, function(v)
        Egg.StayInBreakableZone = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Altın Yumurta Modu (Golden)",
        flag = "EggGoldenHatch",
        value = Egg.GoldenHatch,
        description = "Açıksa yumurtaları Golden şansıyla açar",
    }, function()
        return Egg.GoldenHatch
    end, function(v)
        Egg.GoldenHatch = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Şarjlı Yumurta Modu (Charged)",
        flag = "EggChargedHatch",
        value = Egg.ChargedHatch,
        description = "Açıksa Charged Eggs özelliğiyle yumurta açar",
    }, function()
        return Egg.ChargedHatch
    end, function(v)
        Egg.ChargedHatch = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Yumurta Açılma Animasyonunu Kapat",
        flag = "EggDisableAnim",
        value = Egg.DisableEggAnimation,
        description = "Kutu açılma animasyonunu atlayarak çok hızlı açılış ve düşük gecikme sağlar",
    }, function()
        return Egg.DisableEggAnimation
    end, function(v)
        Egg.DisableEggAnimation = (v == true)
    end, function(v)
        if ctx.EggAndPetSystem and ctx.EggAndPetSystem.SetDisableEggAnimation then
            ctx.EggAndPetSystem.SetDisableEggAnimation(v == true)
        end
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Pet Dönüştürme & Tılsımlar (Charms)" })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Altına Çevir (Auto Gold)",
        flag = "EggAutoGold",
        value = Egg.AutoMakeGold,
        description = "Yeterli normal pet biriktiğinde otomatik Golden yapar",
    }, function()
        return Egg.AutoMakeGold
    end, function(v)
        Egg.AutoMakeGold = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Gökkuşağı Yap (Auto Rainbow)",
        flag = "EggAutoRainbow",
        value = Egg.AutoMakeRainbow,
        description = "Yeterli Golden pet biriktiğinde otomatik Rainbow yapar",
    }, function()
        return Egg.AutoMakeRainbow
    end, function(v)
        Egg.AutoMakeRainbow = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Birleştir (Auto Fuse)",
        flag = "EggAutoFuse",
        value = Egg.AutoFusePets,
        description = "Fazla petleri otomatik olarak Fuse makinesinde birleştirir",
    }, function()
        return Egg.AutoFusePets
    end, function(v)
        Egg.AutoFusePets = (v == true)
    end)

    UI.createBoundSlider(Tab, {
        name = "Fuse Minimum Pet Sayısı",
        flag = "EggFuseMin",
        range = { 3, 100 },
        increment = 1,
        suffix = " pet",
        value = Egg.FuseMinCount,
    }, function()
        return Egg.FuseMinCount
    end, function(v)
        Egg.FuseMinCount = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Tılsım Tak (Auto Charm)",
        flag = "EggAutoCharm",
        value = Egg.AutoCharmPets,
        description = "Boş tılsım slotu olan petlere tercih edilen tılsımları takar",
    }, function()
        return Egg.AutoCharmPets
    end, function(v)
        Egg.AutoCharmPets = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Tercih Edilen Tılsımlar",
        flag = "EggPreferredCharms",
        options = { "Royalty", "Overload", "Glittering", "Strength", "Agility", "TNT", "Coins", "Criticals", "Diamonds", "Lightning", "XP" },
        labels = {
            Royalty = "Royalty (Kraliyet)",
            Overload = "Overload (Çift Slot)",
            Glittering = "Glittering (Elmas Üretimi)",
            Strength = "Strength (Güç)",
            Agility = "Agility (Hız)",
            TNT = "TNT",
            Coins = "Coins (Altın)",
            Criticals = "Criticals (Kritik)",
            Diamonds = "Diamonds (Elmas)",
            Lightning = "Lightning (Yıldırım)",
            XP = "XP",
        },
        value = Egg.PreferredCharms,
        multiSelect = true,
    }, function()
        return Egg.PreferredCharms
    end, function(v)
        Egg.PreferredCharms = v
    end)

    return EggTab
end

return EggTab
