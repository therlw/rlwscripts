-- src/UI/Tabs/AutomaticTab.lua
-- Meyve, İksir, Sandık, Çark & Yükseltme Otomasyonları Sekmesi

local AutomaticTab = {}

function AutomaticTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Auto = ctx.States.Automatic

    local Tab = Window:CreateTab({
        name = "Otomatik İşler",
        icon = 93364949241311,
    })
    UI.AutomaticTab = Tab

    Tab:CreateSection({ name = "Boostlar, Meyveler & İksirler" })
    UI.AutomaticStatusText = Tab:CreateText({
        name = "Tüketim & Açma Durumu",
        text = tostring(ctx.Runtime.Status.Automatic or "Otomatik tüketim beklemede"),
    })

    UI.createBoundToggle(Tab, {
        name = "Boostları Otomatik Kullan / Yenile",
        flag = "AutoBuyBoosts",
        value = Auto.AutoBuyBoosts,
        description = "Envanterdeki Boost eşyalarını süresi bittikçe aktif eder",
    }, function()
        return Auto.AutoBuyBoosts
    end, function(v)
        Auto.AutoBuyBoosts = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Kanat Yükseltmelerini Al (Wings)",
        flag = "AutoBuyWings",
        value = Auto.AutoBuyWingsUpgrades,
        description = "Mevcut Wing / Hoverboard yükseltmelerini otomatik satın alır",
    }, function()
        return Auto.AutoBuyWingsUpgrades
    end, function(v)
        Auto.AutoBuyWingsUpgrades = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Meyve Ye (Fruits)",
        flag = "AutoEatFruits",
        value = Auto.AutoEatFruits,
        description = "Elma, Muz, Ananas ve Karpuz takviyelerini otomatik tazeler",
    }, function()
        return Auto.AutoEatFruits
    end, function(v)
        Auto.AutoEatFruits = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Shiny Meyveleri Önce Ye",
        flag = "AutoEatShinyFruits",
        value = Auto.EatShinyFruits,
        description = "Mümkünse daha yüksek bonus veren Shiny meyveleri tüketir",
    }, function()
        return Auto.EatShinyFruits
    end, function(v)
        Auto.EatShinyFruits = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Oyuncakları Otomatik Kullan (Toys)",
        flag = "AutoUseToys",
        value = Auto.AutoUseToys,
        description = "Toy Ball, Toy Bone vb. oyuncakları otomatik aktif tutar",
    }, function()
        return Auto.AutoUseToys
    end, function(v)
        Auto.AutoUseToys = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "İksirleri Otomatik İç (Potions)",
        flag = "AutoUsePotions",
        value = Auto.AutoUsePotions,
        description = "Belirlenen seviye ve üzerindeki iksirleri otomatik kullanır",
    }, function()
        return Auto.AutoUsePotions
    end, function(v)
        Auto.AutoUsePotions = (v == true)
    end)

    UI.createBoundSlider(Tab, {
        name = "Minimum İksir Seviyesi (Tier)",
        flag = "AutoPotionMinTier",
        range = { 1, 10 },
        increment = 1,
        suffix = ". sv",
        value = Auto.PotionMinTier,
    }, function()
        return Auto.PotionMinTier
    end, function(v)
        Auto.PotionMinTier = v
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Hediye, Kutu, Anahtar & Çarklar" })

    UI.createBoundToggle(Tab, {
        name = "Hediye Paketlerini Otomatik Aç",
        flag = "AutoOpenGifts",
        value = Auto.AutoOpenGifts,
        description = "Gift Bag ve Bundle paketlerini otomatik açar",
    }, function()
        return Auto.AutoOpenGifts
    end, function(v)
        Auto.AutoOpenGifts = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Ganimet Kutularını Aç (Lootboxes)",
        flag = "AutoOpenLootboxes",
        value = Auto.AutoOpenLootboxes,
        description = "Envanterdeki Lootbox kasalarını otomatik açar",
    }, function()
        return Auto.AutoOpenLootboxes
    end, function(v)
        Auto.AutoOpenLootboxes = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Anahtarları Birleştir (Combine Keys)",
        flag = "AutoCombineKeys",
        value = Auto.AutoCombineKeys,
        description = "Crystal, Secret, Tech ve Void anahtar parçalarını birleştirir",
    }, function()
        return Auto.AutoCombineKeys
    end, function(v)
        Auto.AutoCombineKeys = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Sandıkları Otomatik Aç (Chests)",
        flag = "AutoOpenChests",
        value = Auto.AutoOpenChests,
        description = "Anahtarlı dünya sandıklarını otomatik açar",
    }, function()
        return Auto.AutoOpenChests
    end, function(v)
        Auto.AutoOpenChests = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Şans Çarklarını Çevir (Spin Wheels)",
        flag = "AutoSpinWheels",
        value = Auto.AutoSpinWheels,
        description = "Spinny Wheel biletlerin varsa otomatik çevirir",
    }, function()
        return Auto.AutoSpinWheels
    end, function(v)
        Auto.AutoSpinWheels = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Otomatik Eşya Yükseltme (Upgrade)" })

    UI.createBoundToggle(Tab, {
        name = "Meyveleri Yükselt (Rainbow Fruits)",
        flag = "AutoUpgradeFruits",
        value = Auto.AutoUpgradeFruits,
        description = "Meyveleri birleştirip Rainbow Fruit üretir",
    }, function()
        return Auto.AutoUpgradeFruits
    end, function(v)
        Auto.AutoUpgradeFruits = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "İksirleri Üst Seviyeye Çıkar",
        flag = "AutoUpgradePotions",
        value = Auto.AutoUpgradePotions,
        description = "Aynı seviye iksirleri makinede birleştirip güçlendirir",
    }, function()
        return Auto.AutoUpgradePotions
    end, function(v)
        Auto.AutoUpgradePotions = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Büyüleri Yükselt (Upgrade Enchants)",
        flag = "AutoUpgradeEnchants",
        value = Auto.AutoUpgradeEnchants,
        description = "Düşük seviye Enchant kitaplarını üst seviyeye birleştirir",
    }, function()
        return Auto.AutoUpgradeEnchants
    end, function(v)
        Auto.AutoUpgradeEnchants = (v == true)
    end)

    return AutomaticTab
end

return AutomaticTab
