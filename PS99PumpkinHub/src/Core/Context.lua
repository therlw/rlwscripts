-- src/Core/Context.lua
-- Dependency Injection Container, Event/Farm CONFIG & All Feature State Tables

local Context = {}

function Context.New(opts)
    opts = opts or {}

    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local PathfindingService = game:GetService("PathfindingService")
    local Lighting = game:GetService("Lighting")

    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local CONFIG = {
        -- Rate-limit & server-safe timing floors (audited against PS99 FFlags)
        ButtonCooldown = 0.38,          -- Buttons.lua uses 0.35s
        RebirthCooldown = 5.4,          -- PumpkinTycoon_RebirthCooldown = 5s
        MerchantPurchaseCooldown = 0.35,-- MerchantPurchaseMinInterval = 0.15s / UI 0.3s
        CocoaPurchaseCooldown = 0.65,
        UpgradeCooldown = 0.45,
        ThrowCooldown = 3.15,           -- PumpkinTycoon_ThrowSeconds = 3s
        AutoHuntSyncGap = 2.25,         -- Hunt.SEND_GAP = 2.1s
        GiftOpenCooldown = 1.0,
        BoostCheckInterval = 2.5,
        EggHatchCooldown = 0.28,
        AutoBreakLoopInterval = 0.85,
        TurkeyScanInterval = 0.6,
        MainWorkerInterval = 0.35,

        -- Server reach defaults (live FFlags read at runtime when available)
        DefaultMerchantRange = 20,      -- PumpkinTycoon_MerchantRange
        DefaultCocoaRange = 20,         -- PumpkinTycoon_CocoaRange
        DefaultThrowReach = 150,        -- PumpkinTycoon_ThrowReach
        DefaultTurkeyReach = 150,       -- PumpkinTycoon_TurkeyReach
        DefaultAutoTapReach = 60,       -- PumpkinTycoon_AutoTapReach
        DefaultMaxClickDist = 150,      -- Auto Tapper AutoTapMaxDistance

        -- Intelligent Coin Saving parameters
        CoinReserveRatio = 1.0,         -- Reserve 100% of next progression button price

        Notifications = {
            Enabled = true,
            RareSpawns = true,
            RebirthAlerts = true,
        },

        Debug = {
            DebugMode = false,
        },

        Persistence = {
            AutoSave = true,
            AutoLoad = true,
            FileName = "PS99PumpkinHub/config.json",
        },

        Hotkeys = {
            ToggleUI = "RightShift",
            ToggleAutoTap = "None",
            ToggleAutoButtons = "None",
            ToggleAutoCatchRare = "None",
        },
    }

    local States = {
        Movement = {
            Mode = "Teleport", -- "Teleport" or "Legit Walk"
            WalkTimeout = 18,
        },

        Main = {
            AntiAFK = true,
            AutoClaimFreeGifts = false,
            AutoClaimRankRewards = false, -- Rank Rewards only (no Auto Rank Quests)
            AutoClaimForeverPack = false,
            AutoPopBalloons = false,
            AutoLeaveStairway = false,
            AutoTreehouseMerchant = false,
            AutoCrystalKeyCastle = false,
        },

        PumpkinTycoon = {
            -- Performance / Lag optimization
            OptimizePumpkinTycoon = false,

            -- Core Tycoon Progression & Rebirth
            AutoBuyButtons = false,
            ButtonPriorityMode = "Zone/Egg First", -- "Zone/Egg First" or "Cheapest First"
            AutoClaimIslandReward = true,
            AutoRebirth = false,
            MaxRebirths = "0", -- "0" = Unlimited, or target rebirth count ("1".."20")

            -- Eggs & Zones (Zones 1..8 incl. Part 2 Pine Woods / Maple Creek / Golden Ridge)
            AutoTeleportBestEgg = false,
            AutoBuyNearestEgg = false,
            SmartCoinSaving = true,
            CoinSavingLookaheadButtons = 2,
            EggHatchAmount = "Max", -- "Max" or "1", "3", "10", "50"

            -- Pumpkins Keep / Break
            AutoKeepPumpkins = false,
            KeepRarityRule = "Epic",
            AutoBreakPumpkins = false,

            -- Merchant & Planting Pumpkins
            AutoBuyMerchantPumpkins = false,
            AutoBuyMerchantMode = "Game Auto Merchant",
            SelectedMerchantBands = { "LegendaryPlus", "MythicalPlus", "ExoticPlus" },
            AutoPlantMerchantPumpkins = false,

            -- Upgrades & Cocoa & Boosts & Gifts
            AutoBuyUpgrades = false,
            SelectedUpgrades = {
                "SpawnLuck",
                "PumpkinCoins",
                "PumpkinDamage",
                "RespawnSpeed",
                "StockSlots",
                "ChaseOdds",
                "EggLuck",
                "MerchantLuck",
            },
            AutoBuyCocoaBoosts = false,
            SelectedCocoaBoosts = { "Coins", "Damage", "IslandLuck" },
            AutoUsePumpkinBoosts = false,
            SelectedPumpkinBoosts = { "Coins", "Damage", "IslandLuck" },
            AutoOpenFlannelGifts = false,
            GiftOpenBatch = 8,

            -- Wild Pets, Pet Nets, Turkey Boss & Rare Sightings
            AutoHuntWildPets = false,
            HuntMinTier = "Rare",
            HuntVariantsOnly = false,
            HuntUltraOnHuges = false,

            AutoCatchWildPets = false,
            CatchWildMinTier = "Epic",
            CatchWildVariantsOnly = false,
            CatchWildNetPreference = "Ultra Titanic/Garg",

            AutoBuyPetNets = false,
            BuyPetNetsMode = "Game Auto Nets + Shop",
            SelectedNetOffers = { "Pet Net", "Ultra Pet Net" },

            AutoFightTurkey = false,
            ReturnHomeAfterTurkey = true,
            AutoCatchRareSpawns = false,
            CatchRareTiers = { "Huge", "Titanic", "Gargantuan" },
            RareSpawnNetMode = "Ultra Titanic/Garg",
        },

        Farm = {
            AutoTap = false,
            TapTargetMode = "Best / Turkey Priority",
            TapRateScale = 1.0,
            InfinitePetSpeed = false,
            PetSpeedMult = 25,
            AutoEfficientFarm = false,
            AutoCollectOrbs = false,
            AutoUseUltimate = false,
            AutoTeleportBestArea = false,
            AutoBuyNextArea = false,
            AutoCompleteGateQuest = false,
            AutoAreaQuest = false,
            AutoRebirth = false,
            AutoTeleportBestWorld = false,
            AutoUseMiscItems = false,
            AutoUseSprinkler = false,
            AutoUseTNTCrate = false,
            AutoBuyPetEquipSlots = false,
            AutoBuyEggBundleSlots = false,
        },

        Egg = {
            AutoBuyEgg = false,
            TargetEggMode = "Best Unlocked", -- "Best Unlocked", "Nearest Unlocked", or explicit egg name
            SelectedEggName = "Best Unlocked",
            HatchAmount = "Max",
            GoldenHatch = false,
            ChargedHatch = false,
            StayInBreakableZone = true,
            DisableEggAnimation = false,
            AutoMakeGold = false,
            AutoMakeRainbow = false,
            AutoFusePets = false,
            FuseMinCount = 12,
            AutoCharmPets = false,
            PreferredCharms = { "Royalty", "Overload", "Glittering", "Strength", "Agility", "TNT", "Coins", "Criticals" },
        },

        Automatic = {
            AutoBuyBoosts = false,
            AutoBuyWingsUpgrades = false,
            AutoEatFruits = false,
            EatShinyFruits = true,
            AutoUseToys = false,
            AutoUsePotions = false,
            PotionMinTier = 1,
            AutoOpenGifts = false,
            AutoOpenLootboxes = false,
            AutoCombineKeys = false,
            AutoOpenChests = false,
            AutoSpinWheels = false,
            AutoUpgradeFruits = false,
            AutoUpgradePotions = false,
            AutoUpgradeEnchants = false,
        },

        FishingWorld = {
            AutoBuyNearestEgg = false,
            EggAmount = "Max",
            AutoEventFishing = false,
            FishingMode = "Game Autofish + Cast", -- "Game Autofish", "Auto Cast & Reel", "Game Autofish + Cast"
            AutoSellEventFish = false,
            AutoBuyNextRod = false,
            AutoUseScrolls = false,
            SelectedScrolls = { "Fishing Luck Scroll", "Fishing Speed Scroll", "Fishing XP Scroll" },
            AutoUseBucketOfChum = false,
        },

        FarmingWorld = {
            AutoBuyFarmEgg = false,
            AutoPlaceFarmEgg = false,
            AutoHarvestFarmEgg = false,
            AutoBuyFarmSupply = false,
            AutoFeedFarmPets = false,
            AutoSellFarmPets = false,
            AutoCraftItemsPets = false,
            AutoClaimFarmStorage = false,
            AutoClaimFarmingQuestRewards = false,
            AutoCompleteFarmingQuest = false,
            AutoBuyFarmPetSlot = false,
            AutoBuyFarmStorageSlot = false,
            AutoMailPixelRainbowItems = false,
            PixelMailUsername = "",
        },

        Mailbox = {
            AutoClaimMailbox = false,
            AutoMailPets = false,
            MailUsername = "",
            MailRarityFilter = "Exclusive / Huge+", -- "All Unlocked", "Mythical+", "Exclusive / Huge+", "Huge / Titanic+"
            MailMessage = "PS99 Hub Mail",
        },

        Optimization = {
            OptimizePumpkinTycoon = false,
            DisableBreakablesModel = false,
            DisablePetsRendering = false,
            DisableConfettiRendering = false,
            OptimizeGame = false,
            HideMachineGuis = true,
        },

        Webhook = {
            Url = "",
            NotifyTitanic = true,
            NotifyHuge = true,
            NotifyExclusive = false,
        },
    }

    local Runtime = {
        Generation = 0,
        Status = {
            Event = "Balkabağı adasına girilmesi bekleniyor...",
            Movement = "Beklemede",
            Farm = "Oto Tıklama beklemede",
            Main = "Genel özellikler beklemede",
            Egg = "Yumurta & Pet makineleri beklemede",
            Automatic = "Otomatik tüketim beklemede",
            Fishing = "Balıkçılık etkinliği beklemede",
            Farming = "Çiftlik Dünyası beklemede",
            Mailbox = "Posta kutusu beklemede",
            Webhook = "Webhook dinleyicisi aktif",
        },
        Cooldowns = {
            LastButtonAt = 0,
            LastRebirthAt = 0,
            LastMerchantBuyAt = 0,
            LastCocoaBuyAt = 0,
            LastUpgradeAt = 0,
            LastThrowAt = 0,
            LastHuntSyncAt = 0,
            LastGiftOpenAt = 0,
            LastBoostCheckAt = 0,
            LastEggHatchAt = 0,
            LastStoreBuyAt = 0,
            LastTeleportBestAt = 0,
        },
        Telemetry = {
            ButtonsBought = 0,
            Rebirths = 0,
            EggsHatched = 0,
            GiftsOpened = 0,
            WildCaught = 0,
            RareAttempts = 0,
            NetsThrown = 0,
            HugeNetsThrown = 0,
            HugeCaught = 0,
            HugeEscaped = 0,
            TitanicGargNetsThrown = 0,
            TitanicGargCaught = 0,
            TitanicGargEscaped = 0,
            TurkeyHits = 0,
            CoinSaveReason = "Yok",
            WebhooksSent = 0,
            PetsMailed = 0,
            FishCaught = 0,
        },
        ActiveButtonIds = {},
        RayfieldUnload = nil,
    }

    local ctx = {
        Version = opts.Version or "1.0",
        LoaderMeta = opts.LoaderMeta or {},
        Generation = 0,
        Roblox = {
            HttpService = HttpService,
            Players = Players,
            ReplicatedStorage = ReplicatedStorage,
            RunService = RunService,
            TweenService = TweenService,
            UserInputService = UserInputService,
            PathfindingService = PathfindingService,
            Lighting = Lighting,
            LocalPlayer = LocalPlayer,
            PlayerGui = PlayerGui,
        },
        Config = CONFIG,
        States = States,
        Runtime = Runtime,
        Connections = {},
        CleanupCallbacks = {},
        LoadedModules = {},
        API = {},
        UI = {},
        Net = nil,
        Lifecycle = nil,
        Utils = nil,
        ConfigManager = nil,
        Movement = nil,
        Optimizer = nil,
    }

    return ctx
end

return Context
