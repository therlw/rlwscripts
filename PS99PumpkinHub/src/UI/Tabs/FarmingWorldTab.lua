-- src/UI/Tabs/FarmingWorldTab.lua
-- Çiftlik Dünyası (Farming World) Otomasyon Sekmesi

local FarmingWorldTab = {}

function FarmingWorldTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local FMW = ctx.States.FarmingWorld

    local Tab = Window:CreateTab({
        name = "Çiftlik Dünyası",
        icon = 93364949241311,
    })
    UI.FarmingWorldTab = Tab

    Tab:CreateSection({ name = "Çiftlik Yumurtaları & Besleme" })
    UI.FarmingStatusText = Tab:CreateText({
        name = "Çiftlik Durumu",
        text = tostring(ctx.Runtime.Status.Farming or "Çiftlik Dünyası beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Çiftlik Yumurtası Al",
        flag = "FarmWBuyEgg",
        value = FMW.AutoBuyFarmEgg,
        description = "Çiftlik mağazasından stoktaki yumurtaları alır",
    }, function()
        return FMW.AutoBuyFarmEgg
    end, function(v)
        FMW.AutoBuyFarmEgg = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Yumurtalarını Ek (Place)",
        flag = "FarmWPlaceEgg",
        value = FMW.AutoPlaceFarmEgg,
        description = "Envanterdeki çiftlik yumurtalarını boş yuvalara koyar",
    }, function()
        return FMW.AutoPlaceFarmEgg
    end, function(v)
        FMW.AutoPlaceFarmEgg = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Büyüyen Yumurtaları Hasat Et (Harvest)",
        flag = "FarmWHarvestEgg",
        value = FMW.AutoHarvestFarmEgg,
        description = "Süresi dolan hazır çiftlik yumurtalarını toplar",
    }, function()
        return FMW.AutoHarvestFarmEgg
    end, function(v)
        FMW.AutoHarvestFarmEgg = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Malzemeleri Satın Al (Supply)",
        flag = "FarmWBuySupply",
        value = FMW.AutoBuyFarmSupply,
        description = "Mama, hızlandırıcı ve çiftlik malzemelerini alır",
    }, function()
        return FMW.AutoBuyFarmSupply
    end, function(v)
        FMW.AutoBuyFarmSupply = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Petlerini Besle (Feed)",
        flag = "FarmWFeedPets",
        value = FMW.AutoFeedFarmPets,
        description = "Çiftlik petlerine otomatik mama verir",
    }, function()
        return FMW.AutoFeedFarmPets
    end, function(v)
        FMW.AutoFeedFarmPets = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Fazla Çiftlik Petlerini Sat",
        flag = "FarmWSellPets",
        value = FMW.AutoSellFarmPets,
        description = "Dışarıda kalan fazla çiftlik petlerini satıp coin çevirir",
    }, function()
        return FMW.AutoSellFarmPets
    end, function(v)
        FMW.AutoSellFarmPets = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Üretim (Craft), Depo & Görevler" })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Üretim Yap (Craft)",
        flag = "FarmWCraft",
        value = FMW.AutoCraftItemsPets,
        description = "Çiftlik tezgahında mevcut tarifleri üretir",
    }, function()
        return FMW.AutoCraftItemsPets
    end, function(v)
        FMW.AutoCraftItemsPets = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Deposunu Topla (Claim Storage)",
        flag = "FarmWClaimStorage",
        value = FMW.AutoClaimFarmStorage,
        description = "Petlerin depoda biriktirdiği ürünleri alır",
    }, function()
        return FMW.AutoClaimFarmStorage
    end, function(v)
        FMW.AutoClaimFarmStorage = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Görev Ödüllerini Al",
        flag = "FarmWClaimQuests",
        value = FMW.AutoClaimFarmingQuestRewards,
        description = "Tamamlanan çiftlik görevlerinin ödüllerini toplar",
    }, function()
        return FMW.AutoClaimFarmingQuestRewards
    end, function(v)
        FMW.AutoClaimFarmingQuestRewards = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Görevlerini Otomatik Yap",
        flag = "FarmWCompleteQuests",
        value = FMW.AutoCompleteFarmingQuest,
        description = "Aktif çiftlik görevlerini otomatik olarak tamamlar",
    }, function()
        return FMW.AutoCompleteFarmingQuest
    end, function(v)
        FMW.AutoCompleteFarmingQuest = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Slotlar & Pixel Posta Gönderimi" })

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Pet Slotu Satın Al",
        flag = "FarmWBuyPetSlot",
        value = FMW.AutoBuyFarmPetSlot,
        description = "Yeni çiftlik pet yerleştirme slotları açar",
    }, function()
        return FMW.AutoBuyFarmPetSlot
    end, function(v)
        FMW.AutoBuyFarmPetSlot = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Çiftlik Depo Slotu Satın Al",
        flag = "FarmWBuyStorageSlot",
        value = FMW.AutoBuyFarmStorageSlot,
        description = "Depo kapasitesini otomatik olarak genişletir",
    }, function()
        return FMW.AutoBuyFarmStorageSlot
    end, function(v)
        FMW.AutoBuyFarmStorageSlot = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Pixel Rainbow Eşyalarını Mail At",
        flag = "FarmWMailPixel",
        value = FMW.AutoMailPixelRainbowItems,
        description = "Pixel Rainbow eşyalarını aşağıdaki kullanıcıya otomatik yollar",
    }, function()
        return FMW.AutoMailPixelRainbowItems
    end, function(v)
        FMW.AutoMailPixelRainbowItems = (v == true)
    end)

    UI.createBoundInput(Tab, {
        name = "Pixel Mail Alıcı Kullanıcı Adı",
        flag = "FarmWPixelUser",
        placeholder = "Roblox kullanıcı adı...",
        value = FMW.PixelMailUsername,
    }, function()
        return FMW.PixelMailUsername
    end, function(v)
        FMW.PixelMailUsername = tostring(v or "")
    end)

    return FarmingWorldTab
end

return FarmingWorldTab
