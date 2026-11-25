-- src/UI/Tabs/FarmTab.lua
-- Ana Otomasyon ve Farm: Dual Farm (Baby + Pet), Auto-Age Kuyruğu, Auto-Lure, Auto-Hatch & Yumurta Alımı

local FarmTab = {}

function FarmTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle
    local Bridge = ctx.Bridge
    local Utils = ctx.Utils

    local Tab = Window:CreateTab({
        name = "Oto Farm",
        icon = 93364949241311,
    })
    UI.FarmTab = Tab

    Tab:CreateSection({ name = "Canlı Durum ve İstatistik" })

    local statusText = Tab:CreateText({
        name = "Farm Durumu",
        text = "Durum: Beklemede",
    })

    Lifecycle.SpawnLoop("FarmTabStatus", 1.2, function()
        if statusText and statusText.Set then
            local bucks = Bridge.GetMoney()
            local eq = Bridge.GetEquippedPets()
            local rawId = eq[1] and (eq[1].pet_id or eq[1].kind or eq[1].id)
            local invPets = Bridge.Mod.InventoryDB and Bridge.Mod.InventoryDB.pets
            local pName = (rawId and invPets and invPets[rawId] and invPets[rawId].name) or rawId or "Yok"

            local am = Bridge.GetAilmentsManager()
            local petUid = eq[1] and (eq[1].pet_unique or eq[1].unique)
            local bCount, pCount = 0, 0
            for _ in pairs(am.baby_ailments or {}) do bCount = bCount + 1 end
            if petUid and am.ailments and type(am.ailments[petUid]) == "table" then
                for _ in pairs(am.ailments[petUid]) do pCount = pCount + 1 end
            end

            pcall(function()
                statusText:Set(string.format(
                    "%s | Bucks: %s (+%s) | Biten: %d | Aktif: Bebek %d / Pet %d | Pet: %s",
                    tostring(ctx.Runtime.Status.Farm),
                    Utils.formatNumber(bucks),
                    Utils.formatNumber(ctx.Runtime.Telemetry.BucksEarned),
                    ctx.Runtime.Telemetry.TasksCompleted,
                    bCount,
                    pCount,
                    tostring(pName)
                ))
            end)
        end
    end)

    Tab:CreateSection({ name = "Dual Farm (Bebek + Evcil Hayvan)" })

    UI.createBoundToggle(Tab, {
        name = "Dual Farm Başlat (Baby + Pet Method)",
        flag = "DualFarm",
        value = States.Farm.DualFarm,
        description = "Bebek rolüne geçer, hem karakterin hem evcil hayvanın tüm ihtiyaçlarını otomatik tamamlar",
    }, function() return States.Farm.DualFarm end, function(v)
        States.Farm.DualFarm = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Bebek (Babies) Rolüne Geç",
        flag = "AutoBabyTeam",
        value = States.Farm.AutoBabyTeam,
        description = "Kazancı ikiye katlamak için oyuncuyu otomatik Babies takımına alır",
    }, function() return States.Farm.AutoBabyTeam end, function(v)
        States.Farm.AutoBabyTeam = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "İhtiyaç Görevlerini Otomatik Tamamla (Ailments)",
        flag = "AutoAilments",
        value = States.Farm.AutoAilments,
        description = "Yemek, Su, Uyku, Duş, Okul, Hastane, Oyun Parkı, Kamp, Sahil ve Pizza/Salon görevlerini yapar",
    }, function() return States.Farm.AutoAilments end, function(v)
        States.Farm.AutoAilments = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Gizemli Görevleri Otomatik Seç (Mystery Ailment)",
        flag = "AutoMysteryAilment",
        value = States.Farm.AutoMysteryAilment,
    }, function() return States.Farm.AutoMysteryAilment end, function(v)
        States.Farm.AutoMysteryAilment = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Günlük Giriş & Oynama Ödüllerini Al",
        flag = "AutoClaimDailyAndPlaytime",
        value = States.Farm.AutoClaimDailyAndPlaytime,
    }, function() return States.Farm.AutoClaimDailyAndPlaytime end, function(v)
        States.Farm.AutoClaimDailyAndPlaytime = (v == true)
    end)

    Tab:CreateSection({ name = "Auto-Age Kuyruğu & Yumurta Çatlatma" })

    UI.createBoundToggle(Tab, {
        name = "Auto-Age / Auto-Grow Kuyruğu",
        flag = "AutoAgeQueue",
        value = States.Farm.AutoAgeQueue,
        description = "Full Grown olmayan petleri sırayla kuşanır, yaş 6 olunca bir sonrakine geçer",
    }, function() return States.Farm.AutoAgeQueue end, function(v)
        States.Farm.AutoAgeQueue = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Kuyruk Nadirlik Filtresi",
        flag = "AgeQueueRarity",
        options = { "All", "legendary", "ultra_rare", "rare", "uncommon", "common" },
        labels = {
            All = "Tümü (Hepsi)",
            legendary = "Legendary",
            ultra_rare = "Ultra-Rare",
            rare = "Rare",
            uncommon = "Uncommon",
            common = "Common",
        },
        value = States.Farm.AgeQueueRarity,
    }, function() return States.Farm.AgeQueueRarity end, function(v)
        States.Farm.AgeQueueRarity = v
    end)

    UI.createBoundInput(Tab, {
        name = "Özel Pet Kind Filtresi (Opsiyonel)",
        flag = "AgeQueuePetKind",
        placeholder = "Örn: frost_dragon veya boş bırak",
        value = States.Farm.AgeQueuePetKind,
    }, function() return States.Farm.AgeQueuePetKind end, function(v)
        States.Farm.AgeQueuePetKind = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yumurta Çatlat (Auto-Hatch Eggs)",
        flag = "AutoHatchEggs",
        value = States.Farm.AutoHatchEggs,
        description = "Envanterdeki yumurtaları sırayla kuşanır ve görevlerini tamamlar",
    }, function() return States.Farm.AutoHatchEggs end, function(v)
        States.Farm.AutoHatchEggs = (v == true)
    end)

    Tab:CreateSection({ name = "Auto-Lure (Tuzak) & Otomatik Yumurta Alımı" })

    UI.createBoundToggle(Tab, {
        name = "Auto-Lure (Ev Tuzak Kutusu)",
        flag = "AutoLure",
        value = States.Farm.AutoLure,
        description = "Lure Box dolunca ödülü toplar ve ücretsiz/seçili yemi tekrar koyar",
    }, function() return States.Farm.AutoLure end, function(v)
        States.Farm.AutoLure = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Lure Yem Tercihi",
        flag = "LureBaitMode",
        options = { "Free / Any Bait", "Free Campfire Cookie Only" },
        labels = {
            ["Free / Any Bait"] = "Ücretsiz / Herhangi Bir Yem",
            ["Free Campfire Cookie Only"] = "Sadece Campfire Cookie (Ücretsiz)",
        },
        value = States.Farm.LureBaitMode,
    }, function() return States.Farm.LureBaitMode end, function(v)
        States.Farm.LureBaitMode = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yumurta Satın Al (Auto-Buy Eggs)",
        flag = "AutoBuyEggs",
        value = States.Farm.AutoBuyEggs,
        description = "Bucks limiti aşıldığında seçilen yumurtayı otomatik satın alır",
    }, function() return States.Farm.AutoBuyEggs end, function(v)
        States.Farm.AutoBuyEggs = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Satın Alınacak Yumurta",
        flag = "SelectedEgg",
        options = {
            "fairytale_egg_2026_fairytale_egg",
            "endangered_2026_endangered_egg",
            "royal_egg",
            "retired_egg",
            "regular_pet_egg",
            "cracked_egg",
        },
        labels = {
            fairytale_egg_2026_fairytale_egg = "Fairytale Egg (750 Bucks)",
            endangered_2026_endangered_egg = "Endangered Egg (750 Bucks)",
            royal_egg = "Royal Egg (1450 Bucks)",
            retired_egg = "Retired Egg (600 Bucks)",
            regular_pet_egg = "Pet Egg (600 Bucks)",
            cracked_egg = "Cracked Egg (350 Bucks)",
        },
        value = States.Farm.SelectedEgg,
    }, function() return States.Farm.SelectedEgg end, function(v)
        States.Farm.SelectedEgg = v
    end)

    UI.createBoundSlider(Tab, {
        name = "Minimum Bucks Limiti",
        flag = "BuyEggMinBucks",
        range = { 350, 5000 },
        increment = 50,
        value = States.Farm.BuyEggMinBucks,
        suffix = " Bucks",
    }, function() return States.Farm.BuyEggMinBucks end, function(v)
        States.Farm.BuyEggMinBucks = v
    end)

    return FarmTab
end

return FarmTab
