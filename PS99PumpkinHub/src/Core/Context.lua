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

        PumpkinTycoon = {
            -- Performance / Lag optimization
            OptimizePumpkinTycoon = false,

            -- Core Tycoon Progression & Rebirth
            AutoBuyButtons = false,
            ButtonPriorityMode = "Zone/Egg First", -- "Zone/Egg First" or "Cheapest First"
            AutoClaimIslandReward = true,
            AutoRebirth = false,

            -- Eggs & Zones (Zones 1..8 incl. Part 2 Pine Woods / Maple Creek / Golden Ridge)
            AutoTeleportBestEgg = false,
            AutoBuyNearestEgg = false,
            SmartCoinSaving = true,
            CoinSavingLookaheadButtons = 2, -- Save coins when next N zone/cheap button is close
            EggHatchAmount = "Max", -- "Max" or "1", "3", "10", "50"

            -- Pumpkins Keep / Break
            AutoKeepPumpkins = false,
            KeepRarityRule = "Epic", -- "Off","Basic","Uncommon","Rare","Epic","Legendary","Mythical","Exotic","Secret"
            AutoBreakPumpkins = false,

            -- Merchant & Planting Pumpkins
            AutoBuyMerchantPumpkins = false, -- Uses game's HM_Sustain Auto Merchant
            AutoBuyMerchantMode = "Game Auto Merchant", -- "Game Auto Merchant" or "Selected Bands"
            SelectedMerchantBands = { "LegendaryPlus", "MythicalPlus", "ExoticPlus" },
            AutoPlantMerchantPumpkins = false, -- Uses game's JD_Prefer + manual XC_Allocate fallback

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
            HuntMinTier = "Rare", -- "Any", "Uncommon", "Rare", "Epic", "Huge"
            HuntVariantsOnly = false,
            HuntUltraOnHuges = true,

            AutoCatchWildPets = false,
            CatchWildMinTier = "Epic", -- "Any", "Uncommon", "Rare", "Epic", "Huge"
            CatchWildVariantsOnly = false,
            CatchWildNetPreference = "Best Available", -- "Best Available", "Pet Net Only", "Ultra For Huge+"

            AutoBuyPetNets = false, -- Game's GN_Restock Auto Buy Nets + optional store purchase
            BuyPetNetsMode = "Game Auto Nets + Shop", -- "Game Auto Nets", "Shop Selected Only", "Game Auto Nets + Shop"
            SelectedNetOffers = { "Pet Net", "Ultra Pet Net" },

            AutoFightTurkey = false,
            ReturnHomeAfterTurkey = true,
            AutoCatchRareSpawns = false, -- Throws best net at Huge/Titanic/Gargantuan after Turkey
            CatchRareTiers = { "Huge", "Titanic", "Gargantuan" },
        },

        Farm = {
            AutoTap = false,
            TapTargetMode = "Best / Turkey Priority", -- "Best / Turkey Priority", "Nearest Allowed", "Pumpkin Only"
            TapRateScale = 1.0, -- 0.5..1.0 of legit Swift Taps speed cap
        },
    }

    local Runtime = {
        Generation = 0,
        Status = {
            Event = "Waiting inside Pumpkin Patch Tycoon...",
            Movement = "Idle",
            Farm = "Auto Tap idle",
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
            TurkeyHits = 0,
            CoinSaveReason = "None",
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
