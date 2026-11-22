-- src/UI/Tabs/AutoFarmTab.lua
-- Savaş, Pet Farmı, Bölge İlerlemesi & Ekstra Slotlar Sekmesi

local AutoFarmTab = {}

function AutoFarmTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Farm = ctx.States.Farm

    local Tab = Window:CreateTab({
        name = "Oto Farm",
        icon = 93364949241311,
    })
    UI.FarmTab = Tab

    Tab:CreateSection({ name = "Savaş & Pet Farmı" })
    UI.FarmStatusText = Tab:CreateText({
        name = "Farm Durumu",
        text = tostring(ctx.Runtime.Status.Farm or "Oto Tıklama beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "Sınırsız Pet Hızı",
        flag = "FarmInfPetSpeed",
        value = Farm.InfinitePetSpeed,
        description = "Petlerin hedeflere gidiş hızını çarpanla yükseltir",
    }, function()
        return Farm.InfinitePetSpeed
    end, function(v)
        Farm.InfinitePetSpeed = (v == true)
    end)

    UI.createBoundSlider(Tab, {
        name = "Pet Hızı Çarpanı",
        flag = "FarmPetSpeedMult",
        range = { 2, 100 },
        increment = 1,
        suffix = "x",
        value = Farm.PetSpeedMult,
        description = "Sınırsız Pet Hızı açıkken uygulanacak hız kat sayısı",
    }, function()
        return Farm.PetSpeedMult
    end, function(v)
        Farm.PetSpeedMult = v
    end)

    UI.AutoTapToggle = UI.createBoundToggle(Tab, {
        name = "Otomatik Tıklama (Auto Tap)",
        flag = "FarmAutoTap",
        value = Farm.AutoTap,
        description = "Seçili önceliğe göre hedeflere ve balkabaklarına seri vurur",
    }, function()
        return Farm.AutoTap
    end, function(v)
        Farm.AutoTap = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Tıklama Hedef Önceliği",
        flag = "FarmTapTargetMode",
        options = { "Best / Turkey Priority", "Nearest Allowed", "Pumpkin Only" },
        labels = {
            ["Best / Turkey Priority"] = "En İyi Hedef / Hindi Öncelikli",
            ["Nearest Allowed"] = "En Yakın Hedef",
            ["Pumpkin Only"] = "Sadece Balkabağı",
        },
        value = Farm.TapTargetMode,
    }, function()
        return Farm.TapTargetMode
    end, function(v)
        Farm.TapTargetMode = v
    end)

    UI.createBoundSlider(Tab, {
        name = "Tıklama Hızı Ölçeği",
        flag = "FarmTapRateScale",
        range = { 0.4, 1.0 },
        increment = 0.05,
        suffix = "x",
        value = Farm.TapRateScale,
    }, function()
        return Farm.TapRateScale
    end, function(v)
        Farm.TapRateScale = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Akıllı Verimli Farm (FastFarm)",
        flag = "FarmAutoEfficient",
        value = Farm.AutoEfficientFarm,
        description = "Petleri hedef başına dağıtarak kırılabilirleri çok daha hızlı parçalar",
    }, function()
        return Farm.AutoEfficientFarm
    end, function(v)
        Farm.AutoEfficientFarm = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Küre & Ganimetleri Otomatik Topla",
        flag = "FarmAutoCollectOrbs",
        value = Farm.AutoCollectOrbs,
        description = "Yerdeki coin, elmas ve ganimet çantalarını otomatik çeker",
    }, function()
        return Farm.AutoCollectOrbs
    end, function(v)
        Farm.AutoCollectOrbs = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Ultimate Yeteneğini Otomatik Kullan",
        flag = "FarmAutoUseUltimate",
        value = Farm.AutoUseUltimate,
        description = "Doldukça aktif Ultimate yeteneğini otomatik tetikler",
    }, function()
        return Farm.AutoUseUltimate
    end, function(v)
        Farm.AutoUseUltimate = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Alanlar, Dünyalar, Görevler & Rebirth" })

    UI.createBoundToggle(Tab, {
        name = "En İyi Açık Alana Işınlan",
        flag = "FarmAutoBestArea",
        value = Farm.AutoTeleportBestArea,
        description = "Kilidi açılmış en son farm bölgesine otomatik ışınlanır",
    }, function()
        return Farm.AutoTeleportBestArea
    end, function(v)
        Farm.AutoTeleportBestArea = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Sonraki Alanı Otomatik Satın Al",
        flag = "FarmAutoBuyArea",
        value = Farm.AutoBuyNextArea,
        description = "Coin yettiğinde bir sonraki bölge kapısını otomatik açar",
    }, function()
        return Farm.AutoBuyNextArea
    end, function(v)
        Farm.AutoBuyNextArea = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Kapı Görevlerini Tamamla (Gate Quest)",
        flag = "FarmAutoGateQuest",
        value = Farm.AutoCompleteGateQuest,
        description = "Yeni dünya/alan kapısı için gereken görevleri yapar",
    }, function()
        return Farm.AutoCompleteGateQuest
    end, function(v)
        Farm.AutoCompleteGateQuest = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Alan Görevlerini Tamamla (Area Quest)",
        flag = "FarmAutoAreaQuest",
        value = Farm.AutoAreaQuest,
        description = "Bulunduğun alandaki görevleri otomatik ilerletir",
    }, function()
        return Farm.AutoAreaQuest
    end, function(v)
        Farm.AutoAreaQuest = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Rebirth (Ana Dünya)",
        flag = "FarmAutoRebirth",
        value = Farm.AutoRebirth,
        description = "Rebirth hazır olduğunda ana dünyada otomatik Rebirth atar",
    }, function()
        return Farm.AutoRebirth
    end, function(v)
        Farm.AutoRebirth = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "En Yüksek Dünyaya Geç",
        flag = "FarmAutoBestWorld",
        value = Farm.AutoTeleportBestWorld,
        description = "Yeni dünya açıldığında otomatik olarak oraya geçer",
    }, function()
        return Farm.AutoTeleportBestWorld
    end, function(v)
        Farm.AutoTeleportBestWorld = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Takviye Eşyaları & Slot Alımı" })

    UI.createBoundToggle(Tab, {
        name = "Bayrak & Çeşitli Eşyaları Kullan",
        flag = "FarmAutoMisc",
        value = Farm.AutoUseMiscItems,
        description = "Alan bayrakları ve destek eşyalarını otomatik bırakır",
    }, function()
        return Farm.AutoUseMiscItems
    end, function(v)
        Farm.AutoUseMiscItems = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Fıskiye Kullan (Sprinkler)",
        flag = "FarmAutoSprinkler",
        value = Farm.AutoUseSprinkler,
        description = "Alana otomatik Sprinkler yerleştirir",
    }, function()
        return Farm.AutoUseSprinkler
    end, function(v)
        Farm.AutoUseSprinkler = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik TNT Sandığı Kullan",
        flag = "FarmAutoTNTCrate",
        value = Farm.AutoUseTNTCrate,
        description = "Alana otomatik TNT Crate yerleştirir",
    }, function()
        return Farm.AutoUseTNTCrate
    end, function(v)
        Farm.AutoUseTNTCrate = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Pet Takma Slotu Satın Al",
        flag = "FarmAutoPetSlots",
        value = Farm.AutoBuyPetEquipSlots,
        description = "Elmas/Coin yettikçe ekstra pet taşıma slotu açar",
    }, function()
        return Farm.AutoBuyPetEquipSlots
    end, function(v)
        Farm.AutoBuyPetEquipSlots = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Yumurta Açma Slotu Satın Al",
        flag = "FarmAutoEggSlots",
        value = Farm.AutoBuyEggBundleSlots,
        description = "Tek seferde açılan yumurta kapasitesini artırır",
    }, function()
        return Farm.AutoBuyEggBundleSlots
    end, function(v)
        Farm.AutoBuyEggBundleSlots = (v == true)
    end)

    return AutoFarmTab
end

return AutoFarmTab
