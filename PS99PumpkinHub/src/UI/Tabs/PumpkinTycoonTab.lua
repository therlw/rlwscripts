-- src/UI/Tabs/PumpkinTycoonTab.lua
-- Güncel Etkinlik (Pumpkin Patch Tycoon) - Sadeleştirilmiş ve Türkçe Kontrol Sekmesi

local PumpkinTycoonTab = {}

function PumpkinTycoonTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local PT = ctx.States.PumpkinTycoon
    local Opt = ctx.States.Optimization
    local Move = ctx.States.Movement

    local Tab = Window:CreateTab({
        name = "Güncel Etkinlik",
        icon = 93364949241311,
    })
    UI.PumpkinTycoonTab = Tab

    --------------------------------------------------------------------
    -- 1. Canlı Özet & Hızlı Ayarlar
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Canlı Özet & Hızlı Ayarlar" })

    local statsRow = Tab:CreateGroup({ direction = "row" })
    UI.PTStatRebirthPct = statsRow:CreateStat({
        name = "Ada",
        value = 0,
        suffix = "%",
        numberEasing = false,
    })
    UI.PTStatRemaining = statsRow:CreateStat({
        name = "Kalan",
        value = 0,
        numberEasing = false,
    })
    UI.PTStatNets = statsRow:CreateStat({
        name = "Pet Ağı",
        value = 0,
        numberEasing = false,
    })

    UI.PumpkinStatusText = Tab:CreateText({
        name = "Etkinlik Durumu",
        text = tostring(ctx.Runtime.Status.Event or "Balkabağı adası bekleniyor..."),
    })

    UI.OptimizePTToggle = UI.createBoundToggle(Tab, {
        name = "Alanı Optimize Et (RAM / FPS)",
        flag = "PTOptimize",
        value = PT.OptimizePumpkinTycoon,
        description = "Gereksiz dekorasyonları, ağaçları ve diğer adaları gizleyip RAM kullanımını düşürür",
    }, function()
        return PT.OptimizePumpkinTycoon
    end, function(v)
        local enabled = (v == true)
        PT.OptimizePumpkinTycoon = enabled
        if Opt then
            Opt.OptimizePumpkinTycoon = enabled
        end
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetEnabled then
            ctx.Optimizer.SetEnabled(v == true)
        end
        if UI.OptOptimizePTToggle and UI.OptOptimizePTToggle.Set then
            pcall(function()
                UI.OptOptimizePTToggle:Set(v == true, true)
            end)
        end
    end)

    UI.createBoundDropdown(Tab, {
        name = "Hareket Modu",
        flag = "PTMovementMode",
        options = { "Teleport", "Legit Walk" },
        labels = {
            ["Teleport"] = "Işınlanma (Hızlı)",
            ["Legit Walk"] = "Yürüyerek (Normal)",
        },
        value = Move.Mode,
        description = "Buton, yumurta ve vahşi petlere gidiş şeklini seçer",
    }, function()
        return Move.Mode
    end, function(v)
        Move.Mode = v
    end)

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- 2. Temel Otomasyon (Ana Sistem)
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Temel Otomasyon (Ana Sistem)" })

    UI.AutoButtonsToggle = UI.createBoundToggle(Tab, {
        name = "Otomatik Buton Satın Al",
        flag = "PTAutoButtons",
        value = PT.AutoBuyButtons,
        description = "Adandaki tüm Tycoon platformlarını sırayla satın alır",
    }, function()
        return PT.AutoBuyButtons
    end, function(v)
        PT.AutoBuyButtons = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Ada Ödülü Topla",
        flag = "PTAutoIslandReward",
        value = PT.AutoClaimIslandReward,
        description = "Tamamlanan ada ödüllerini otomatik olarak alır",
    }, function()
        return PT.AutoClaimIslandReward
    end, function(v)
        PT.AutoClaimIslandReward = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Rebirth",
        flag = "PTAutoRebirth",
        value = PT.AutoRebirth,
        description = "Ada tamamlandığında otomatik Rebirth atar",
    }, function()
        return PT.AutoRebirth
    end, function(v)
        PT.AutoRebirth = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Rebirth Limiti",
        flag = "PTMaxRebirths",
        options = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "15", "20" },
        labels = {
            ["0"] = "Sınırsız (Durma)",
            ["1"] = "Rebirth 1'de Kal",
            ["2"] = "Rebirth 2'de Kal",
            ["3"] = "Rebirth 3 (Şans Max)",
            ["4"] = "Rebirth 4'te Kal",
            ["5"] = "Rebirth 5'te Kal",
            ["6"] = "Rebirth 6'da Kal",
            ["7"] = "Rebirth 7'de Kal",
            ["8"] = "Rebirth 8'de Kal",
            ["9"] = "Rebirth 9'da Kal",
            ["10"] = "Rebirth 10'da Kal",
            ["15"] = "Rebirth 15'te Kal",
            ["20"] = "Rebirth 20 (Bonus Max)",
        },
        value = tostring(PT.MaxRebirths or "0"),
        description = "Seçilen Rebirth sayısına ulaşınca Oto Rebirth durur (3: Şans Max, 20: Bonus Max)",
    }, function()
        return tostring(PT.MaxRebirths or "0")
    end, function(v)
        PT.MaxRebirths = tostring(v or "0")
    end)

    UI.createBoundToggle(Tab, {
        name = "En İyi Yumurtaya Işınlan",
        flag = "PTAutoTPBestEgg",
        value = PT.AutoTeleportBestEgg,
        description = "Kilidi açılmış en yüksek bölge yumurtasına otomatik geçer",
    }, function()
        return PT.AutoTeleportBestEgg
    end, function(v)
        PT.AutoTeleportBestEgg = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yumurta Aç (En Yakın)",
        flag = "PTAutoBuyNearestEgg",
        value = PT.AutoBuyNearestEgg,
        description = "Bulunduğun veya en yakın yumurtayı sürekli açar",
    }, function()
        return PT.AutoBuyNearestEgg
    end, function(v)
        PT.AutoBuyNearestEgg = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Akıllı Coin Biriktirme",
        flag = "PTSmartCoinSave",
        value = PT.SmartCoinSaving,
        description = "Sonraki kritik buton veya geçit için Coin birikene kadar yumurtayı duraklatır",
    }, function()
        return PT.SmartCoinSaving
    end, function(v)
        PT.SmartCoinSaving = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Hindi Boss'a Otomatik Saldır (Turkey)",
        flag = "PTAutoFightTurkey",
        value = PT.AutoFightTurkey,
        description = "Hindi Boss doğduğunda otomatik olarak gider ve keser",
    }, function()
        return PT.AutoFightTurkey
    end, function(v)
        PT.AutoFightTurkey = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Hindi Kesilince Adaya Dön",
        flag = "PTReturnAfterTurkey",
        value = PT.ReturnHomeAfterTurkey,
        description = "Hindi Boss bittikten sonra otomatik olarak kendi adana geri döner",
    }, function()
        return PT.ReturnHomeAfterTurkey
    end, function(v)
        PT.ReturnHomeAfterTurkey = (v == true)
    end)

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- 3. Balkabağı, Yükseltme, Boost & Tüccar
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Balkabağı, Boost & Tüccar" })

    UI.createBoundToggle(Tab, {
        name = "Otomatik Balkabağı Kır (Tarla)",
        flag = "PTAutoBreakPumpkins",
        value = PT.AutoBreakPumpkins,
        description = "Adanda çıkan tüm balkabaklarına pet gönderip kırar",
    }, function()
        return PT.AutoBreakPumpkins
    end, function(v)
        PT.AutoBreakPumpkins = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Nadir Balkabaklarını Koru (Sakla)",
        flag = "PTAutoKeepPumpkins",
        value = PT.AutoKeepPumpkins,
        description = "Seçilen nadirlik ve üstündeki balkabaklarını kırmadan tutar",
    }, function()
        return PT.AutoKeepPumpkins
    end, function(v)
        PT.AutoKeepPumpkins = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Yükseltme Al (Upgrades)",
        flag = "PTAutoBuyUpgrades",
        value = PT.AutoBuyUpgrades,
        description = "Seçili Tycoon yükseltmelerini otomatik olarak satın alır",
    }, function()
        return PT.AutoBuyUpgrades
    end, function(v)
        PT.AutoBuyUpgrades = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Kakao Boost Satın Al",
        flag = "PTAutoBuyCocoa",
        value = PT.AutoBuyCocoaBoosts,
        description = "Sıcak Kakao standından seçili boostları otomatik satın alır",
    }, function()
        return PT.AutoBuyCocoaBoosts
    end, function(v)
        PT.AutoBuyCocoaBoosts = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Balkabağı Boostlarını Kullan",
        flag = "PTAutoUseBoosts",
        value = PT.AutoUsePumpkinBoosts,
        description = "Süresi biten seçili balkabağı boostlarını otomatik yeniler",
    }, function()
        return PT.AutoUsePumpkinBoosts
    end, function(v)
        PT.AutoUsePumpkinBoosts = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Tüccardan Otomatik Balkabağı Al",
        flag = "PTAutoBuyMerchant",
        value = PT.AutoBuyMerchantPumpkins,
        description = "Etkinlik tüccarından seçili nadirliklerdeki balkabaklarını alır",
    }, function()
        return PT.AutoBuyMerchantPumpkins
    end, function(v)
        PT.AutoBuyMerchantPumpkins = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Tüccar Balkabaklarını Otomatik Ek",
        flag = "PTAutoPlant",
        value = PT.AutoPlantMerchantPumpkins,
        description = "Alınan balkabaklarını boş alanlara otomatik olarak eker",
    }, function()
        return PT.AutoPlantMerchantPumpkins
    end, function(v)
        PT.AutoPlantMerchantPumpkins = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Flannel Hediye Aç",
        flag = "PTAutoOpenGifts",
        value = PT.AutoOpenFlannelGifts,
        description = "Envanterdeki Flannel Gift paketlerini toplu olarak açar",
    }, function()
        return PT.AutoOpenFlannelGifts
    end, function(v)
        PT.AutoOpenFlannelGifts = (v == true)
    end)

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- 4. Vahşi Petler & Nadir Yakalama
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "Vahşi Petler & Nadir Yakalama" })

    UI.AutoCatchRareToggle = UI.createBoundToggle(Tab, {
        name = "Nadir Spawn Yakala (Huge / Titanic+)",
        flag = "PTAutoCatchRare",
        value = PT.AutoCatchRareSpawns,
        description = "Hindi veya nadir spawn çıktığında (Huge / Titanic / Gargantuan) otomatik yakalamaya gider",
    }, function()
        return PT.AutoCatchRareSpawns
    end, function(v)
        PT.AutoCatchRareSpawns = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Nadir Spawn Ağı",
        flag = "PTRareNetMode",
        options = { "Ultra Titanic/Garg", "Ultra All Rares", "Pet Net Only" },
        labels = {
            ["Ultra Titanic/Garg"] = "Titanic/Garg Ultra (Huge Normal)",
            ["Ultra All Rares"] = "Hepsine Ultra (Yoksa Normal)",
            ["Pet Net Only"] = "Sadece Normal Pet Net",
        },
        value = PT.RareSpawnNetMode or "Ultra Titanic/Garg",
        description = "Huge için Normal Net atar, Ultra Neti Titanic/Gargantuan'a saklar (Ultra biterse Normal atar)",
    }, function()
        return PT.RareSpawnNetMode
    end, function(v)
        PT.RareSpawnNetMode = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Vahşi Pet Yakala (Otomatik Ağ At)",
        flag = "PTAutoCatchWild",
        value = PT.AutoCatchWildPets,
        description = "Etkinlikteki vahşi petlere yaklaşıp ağ fırlatır",
    }, function()
        return PT.AutoCatchWildPets
    end, function(v)
        PT.AutoCatchWildPets = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Vahşi Pet Ağı",
        flag = "PTCatchWildNetPref",
        options = { "Ultra Titanic/Garg", "Pet Net Only", "Ultra For Huge+", "Best Available" },
        labels = {
            ["Ultra Titanic/Garg"] = "Titanic/Garg Ultra (Sakla)",
            ["Pet Net Only"] = "Sadece Normal Pet Net",
            ["Ultra For Huge+"] = "Huge ve Üstüne Ultra",
            ["Best Available"] = "Eldeki En İyi Ağ",
        },
        value = PT.CatchWildNetPreference or "Ultra Titanic/Garg",
        description = "Haritadaki vahşi petlerde atılacak ağ kuralı (Ultraları Titanic/Garg için saklayabilir)",
    }, function()
        return PT.CatchWildNetPreference
    end, function(v)
        PT.CatchWildNetPreference = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Vahşi Pet Avla (Auto Hunt)",
        flag = "PTAutoHuntWild",
        value = PT.AutoHuntWildPets,
        description = "Seçili seviyedeki vahşi petleri takip edip otomatik yakalar",
    }, function()
        return PT.AutoHuntWildPets
    end, function(v)
        PT.AutoHuntWildPets = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Pet Ağı Satın Al",
        flag = "PTAutoBuyNets",
        value = PT.AutoBuyPetNets,
        description = "Mağazadan veya oyun içi sistemden Pet Net / Ultra Pet Net alır",
    }, function()
        return PT.AutoBuyPetNets
    end, function(v)
        PT.AutoBuyPetNets = (v == true)
    end)

    Tab:CreateDivider()

    --------------------------------------------------------------------
    -- 5. İnce Ayarlar & Filtreler (Gelişmiş)
    --------------------------------------------------------------------
    Tab:CreateSection({ name = "İnce Ayarlar & Filtreler (Gelişmiş)" })

    UI.createBoundDropdown(Tab, {
        name = "Buton Alım Önceliği",
        flag = "PTButtonPriority",
        options = { "Zone/Egg First", "Cheapest First" },
        labels = {
            ["Zone/Egg First"] = "Önce Bölge & Yumurta",
            ["Cheapest First"] = "Önce En Ucuz Buton",
        },
        value = PT.ButtonPriorityMode,
        description = "Yeni alan ve yumurta açmaya mı yoksa en ucuz butona mı öncelik verilsin",
    }, function()
        return PT.ButtonPriorityMode
    end, function(v)
        PT.ButtonPriorityMode = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Yumurta Açma Adedi",
        flag = "PTEggHatchCount",
        options = { "Max", "1", "3", "10", "50" },
        labels = {
            ["Max"] = "Maksimum",
        },
        value = PT.EggHatchAmount,
        description = "Her işlemde açılacak yumurta sayısı",
    }, function()
        return PT.EggHatchAmount
    end, function(v)
        PT.EggHatchAmount = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Korunacak Balkabağı Nadirliği",
        flag = "PTKeepRarityRule",
        options = { "Off", "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Exotic", "Secret" },
        labels = {
            ["Off"] = "Kapalı",
            ["Basic"] = "Temel (Basic)",
            ["Uncommon"] = "Sıradışı (Uncommon)",
            ["Rare"] = "Nadir (Rare)",
            ["Epic"] = "Epik (Epic)",
            ["Legendary"] = "Efsanevi (Legendary)",
            ["Mythical"] = "Mitik (Mythical)",
            ["Exotic"] = "Egzotik (Exotic)",
            ["Secret"] = "Gizli (Secret)",
        },
        value = PT.KeepRarityRule,
        description = "Bu seviye ve üstündeki balkabakları kırılmaz",
    }, function()
        return PT.KeepRarityRule
    end, function(v)
        PT.KeepRarityRule = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Tüccar Alım Modu",
        flag = "PTMerchantBuyMode",
        options = { "Game Auto Merchant", "Selected Bands" },
        labels = {
            ["Game Auto Merchant"] = "Oyun İçi Oto Tüccar",
            ["Selected Bands"] = "Sadece Seçili Nadirlikler",
        },
        value = PT.AutoBuyMerchantMode,
    }, function()
        return PT.AutoBuyMerchantMode
    end, function(v)
        PT.AutoBuyMerchantMode = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Tüccar Balkabağı Nadirlikleri",
        flag = "PTSelectedMerchantBands",
        options = { "RarePlus", "EpicPlus", "LegendaryPlus", "MythicalPlus", "ExoticPlus" },
        labels = {
            RarePlus = "Rare+",
            EpicPlus = "Epic+",
            LegendaryPlus = "Legendary+",
            MythicalPlus = "Mythical+",
            ExoticPlus = "Exotic+",
        },
        value = PT.SelectedMerchantBands,
        multiSelect = true,
    }, function()
        return PT.SelectedMerchantBands
    end, function(v)
        PT.SelectedMerchantBands = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Alınacak Yükseltmeler",
        flag = "PTSelectedUpgrades",
        options = { "SpawnLuck", "PumpkinCoins", "PumpkinDamage", "RespawnSpeed", "StockSlots", "ChaseOdds", "EggLuck", "MerchantLuck" },
        labels = {
            SpawnLuck = "Doğma Şansı (Spawn Luck)",
            PumpkinCoins = "Balkabağı Coin Artışı",
            PumpkinDamage = "Balkabağı Hasarı",
            RespawnSpeed = "Yeniden Çıkma Hızı",
            StockSlots = "Tüccar Stok Slotu",
            ChaseOdds = "Nadir Yakalama Şansı",
            EggLuck = "Yumurta Şansı",
            MerchantLuck = "Tüccar Şansı",
        },
        value = PT.SelectedUpgrades,
        multiSelect = true,
    }, function()
        return PT.SelectedUpgrades
    end, function(v)
        PT.SelectedUpgrades = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Alınacak Kakao Boostları",
        flag = "PTSelectedCocoa",
        options = { "Coins", "Damage", "IslandLuck" },
        labels = {
            Coins = "Coin Boost",
            Damage = "Hasar Boost",
            IslandLuck = "Ada Şansı Boost",
        },
        value = PT.SelectedCocoaBoosts,
        multiSelect = true,
    }, function()
        return PT.SelectedCocoaBoosts
    end, function(v)
        PT.SelectedCocoaBoosts = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Kullanılacak Balkabağı Boostları",
        flag = "PTSelectedBoosts",
        options = { "Coins", "Damage", "IslandLuck" },
        labels = {
            Coins = "Coin Boost",
            Damage = "Hasar Boost",
            IslandLuck = "Ada Şansı Boost",
        },
        value = PT.SelectedPumpkinBoosts,
        multiSelect = true,
    }, function()
        return PT.SelectedPumpkinBoosts
    end, function(v)
        PT.SelectedPumpkinBoosts = v
    end)

    UI.createBoundSlider(Tab, {
        name = "Tek Seferde Açılacak Hediye",
        flag = "PTGiftBatch",
        range = { 1, 8 },
        increment = 1,
        suffix = " adet",
        value = PT.GiftOpenBatch,
    }, function()
        return PT.GiftOpenBatch
    end, function(v)
        PT.GiftOpenBatch = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Nadir Spawn Katmanları",
        flag = "PTRareTiers",
        options = { "Huge", "Titanic", "Gargantuan" },
        value = PT.CatchRareTiers,
        multiSelect = true,
    }, function()
        return PT.CatchRareTiers
    end, function(v)
        PT.CatchRareTiers = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Avlama Min Seviye",
        flag = "PTHuntMinTier",
        options = { "Any", "Uncommon", "Rare", "Epic", "Huge" },
        labels = {
            Any = "Tümü",
            Uncommon = "Uncommon+",
            Rare = "Rare+",
            Epic = "Epic+",
            Huge = "Sadece Huge+",
        },
        value = PT.HuntMinTier,
    }, function()
        return PT.HuntMinTier
    end, function(v)
        PT.HuntMinTier = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Avlamada Sadece Varyantlı Petler",
        flag = "PTHuntVariants",
        value = PT.HuntVariantsOnly,
        description = "Avlanırken yalnızca Golden / Rainbow / Shiny petleri hedefler",
    }, function()
        return PT.HuntVariantsOnly
    end, function(v)
        PT.HuntVariantsOnly = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Oto Av: Huge'de Ultra Ağ Kullan",
        flag = "PTHuntUltraHuge",
        value = PT.HuntUltraOnHuges,
        description = "Oyun içi Oto Av Huge bulduğunda Ultra Pet Net harcasın mı (Kapalı önerilir)",
    }, function()
        return PT.HuntUltraOnHuges
    end, function(v)
        PT.HuntUltraOnHuges = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Yakalama Min Seviye",
        flag = "PTCatchWildMinTier",
        options = { "Any", "Uncommon", "Rare", "Epic", "Huge" },
        labels = {
            Any = "Tümü",
            Uncommon = "Uncommon+",
            Rare = "Rare+",
            Epic = "Epic+",
            Huge = "Huge+",
        },
        value = PT.CatchWildMinTier,
    }, function()
        return PT.CatchWildMinTier
    end, function(v)
        PT.CatchWildMinTier = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Yakalamada Sadece Varyantlılar",
        flag = "PTCatchWildVariants",
        value = PT.CatchWildVariantsOnly,
        description = "Sadece Golden / Rainbow / Shiny vahşi petlere ağ atar",
    }, function()
        return PT.CatchWildVariantsOnly
    end, function(v)
        PT.CatchWildVariantsOnly = (v == true)
    end)

    UI.createBoundDropdown(Tab, {
        name = "Ağ Satın Alma Modu",
        flag = "PTBuyNetsMode",
        options = { "Game Auto Nets + Shop", "Game Auto Nets", "Shop Selected Only" },
        labels = {
            ["Game Auto Nets + Shop"] = "Oto Ağ + Mağaza",
            ["Game Auto Nets"] = "Sadece Oyun İçi Oto Ağ",
            ["Shop Selected Only"] = "Sadece Mağazadan Seçililer",
        },
        value = PT.BuyPetNetsMode,
    }, function()
        return PT.BuyPetNetsMode
    end, function(v)
        PT.BuyPetNetsMode = v
    end)

    UI.createBoundDropdown(Tab, {
        name = "Mağazadan Alınacak Ağlar",
        flag = "PTSelectedNets",
        options = { "Pet Net", "Ultra Pet Net" },
        labels = {
            ["Pet Net"] = "Normal Pet Net",
            ["Ultra Pet Net"] = "Ultra Pet Net",
        },
        value = PT.SelectedNetOffers,
        multiSelect = true,
    }, function()
        return PT.SelectedNetOffers
    end, function(v)
        PT.SelectedNetOffers = v
    end)

    return PumpkinTycoonTab
end

return PumpkinTycoonTab
