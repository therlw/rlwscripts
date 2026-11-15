-- src/Core/Context.lua
-- Central Dependency Injection Container, CONFIG & Hoisted States
-- Mirrors TapSimulatorHub.lua Section [01], Section [04] bounds, and central state tables.

local Context = {}

function Context.New(opts)
    opts = opts or {}

    local HttpService = game:GetService("HttpService")
    local StarterPlayer = game:GetService("StarterPlayer")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CollectionService = game:GetService("CollectionService")

    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local VirtualUser = nil
    pcall(function()
        VirtualUser = game:GetService("VirtualUser")
    end)
    local VirtualInputManager = nil
    pcall(function()
        VirtualInputManager = game:GetService("VirtualInputManager")
    end)

    local DEFAULT_WALKSPEED = 16
    local DEFAULT_JUMPPOWER = 50
    pcall(function()
        if StarterPlayer and type(StarterPlayer.CharacterWalkSpeed) == "number" and StarterPlayer.CharacterWalkSpeed > 0 then
            DEFAULT_WALKSPEED = StarterPlayer.CharacterWalkSpeed
        end
        if StarterPlayer and type(StarterPlayer.CharacterJumpPower) == "number" and StarterPlayer.CharacterJumpPower > 0 then
            DEFAULT_JUMPPOWER = StarterPlayer.CharacterJumpPower
        end
    end)

    local CONFIG = {
        -- Auto Tap Engine
        TapRate = 13.33,
        TapLoopDelay = 0.075,
        OriginalTapCooldowns = { 0.11, 0.10 },

        -- Egg Hatching Timing
        HatchCooldown = 2.4,
        HatchJitterCushion = 0.04,
        HatchLoopDelay = 0.04,
        HatchBusyTimeout = 5.0,

        -- Evolution & Crafting
        CraftCooldown = 2.25,
        CraftTimeout = 3.5,
        MachinePadVerifyDelay = 0.5,
        GoldenCraftCount = 6,
        DiamondCraftCount = 5,

        -- Inventory & Pet Management
        TrashBatchSize = 40,

        -- Telemetry & Progression
        VelocitySampleWindow = 12.0,
        KaitunCycleInterval = 1.5,
        KaitunCycleIntervalCpuSaver = 2.5,
        KaitunDisplayInterval = 1.0,

        -- Stage-Aware Max Egg Save Durations (Seconds)
        MaxEggSaveTimes = {
            ["Early Game"] = 60,
            ["Mid Game"] = 120,
            ["Late Game"] = 180,
            ["Endgame"] = 300,
        },

        -- Progression Scoring Parameters
        Scoring = {
            CompoundingDiscount = 0.70,
            ExecutionOverhead = 0.11,
            MaxRebirthSaveSec = 25,
        },

        -- Stage Detection Thresholds
        StageThresholds = {
            EarlyRebirthLimit = 50,
            EarlyPowerLimit = 10000,
            MidPowerLimit = 5000000,
            EndgamePowerLimit = 100000,
        },

        -- Collectibles, Machines & Events Delays
        LuckyDuckySafeTime = 1.45,
        CollectiblesInterval = 4.0,
        StarCollectInterval = 10.0,
        SmartBoostInterval = 8.0,
        TrashCleanInterval = 25.0,
        QuestClaimInterval = 4.0,
        MachineCheckInterval = 6.0,
        EventCheckInterval = 5.0,

        -- Retries & Error Tolerance
        Retries = {
            RemoteRetries = 2,
            RemoteRetryDelay = 0.25,
            WebhookRetries = 3,
            WebhookRetryDelay = 1.5,
            WebhookTimeout = 10,
        },

        -- Notifications & Debug
        Notifications = {
            Enabled = true,
            SecretAlerts = true,
            MachineAlerts = true,
            UpgradeAlerts = true,
        },
        Debug = {
            DebugMode = false,
            VerboseEvents = false,
        },

        -- Secret Pet Webhook Configuration
        Webhook = {
            Enabled = false,
            Url = "",
            NotifySecrets = true,
            NotifyGodlies = false,
            NotifyGlitched = true,
            PingEveryone = false,
            CustomMention = "",
            IncludeStats = true,
            DedupeWindowSeconds = 20,
            SendSystemFallback = true,
        },

        -- Hotkeys
        Hotkeys = {
            ToggleUI = "RightShift",
            ToggleAutoTap = "None",
            ToggleAutoHatch = "None",
            ToggleAutoRebirth = "None",
            BestTeleport = "None",
            EmergencyRestore = "None",
        },

        -- Persistent Config Settings
        Persistence = {
            AutoSave = true,
            AutoLoad = true,
            Folder = "TapSimHub",
            FileName = "TapSimHub/config.json",
        },

        -- Anti-AFK
        AntiAfkHeartbeatInterval = 180,
    }

    local KaitunState = {
        Enabled = false,
        CurrentGoal = "Standby (Kaitun Disabled)",
        CurrentAction = "Idle",
        AccountStage = "Standby",
        ProgressionStage = "Standby",
        DynamicPriority = "Enable AI Kaitun to activate autonomous progression",
        PredictedVelocity = 0,
        MeasuredVelocity = nil,
        CoinVelocity = 0,
        MeasuredVelocityStr = "Measuring...",
        VelocityDiffPct = nil,
        LastEvaluatedIsland = nil,
        StrategyNote = "Standby: Turn on AI Kaitun to begin autonomous optimization",
        AllowHatch = true,
        AllowTripleHatch = true,
        AllowRebirth = true,
        AllowSkillTree = true,
        AllowIslandUnlock = true,
        AllowAutoCraft = true,
        SuppressMachineUI = true,
        AllowChestsAndStars = true,
        AllowTrashCleaning = true,
        AllowSmartBoosts = true,
        CollectShinyStars = true,
        AutoLuckyDucky = true,
        LastBestEquip = 0,
        LastHatchTime = 0,
        LastRebirthTime = 0,
        LastSkillTime = 0,
        LastCraftTime = 0,
        LastChestTime = 0,
        LastStarCheckTime = 0,
        LastBoostCheckTime = 0,
        LastTrashCheckTime = 0,
    }

    if type(getgenv) == "function" then
        pcall(function()
            getgenv().KaitunState = KaitunState
            getgenv().KaitunMasterToggle = nil
        end)
    end

    local ctx = {
        Version = opts.Version or "CastleUpdate-Audited",
        LoaderMeta = opts.LoaderMeta,
        Generation = 0,
        DefaultWalkSpeed = DEFAULT_WALKSPEED,
        DefaultJumpPower = DEFAULT_JUMPPOWER,

        Roblox = {
            HttpService = HttpService,
            StarterPlayer = StarterPlayer,
            Players = Players,
            ReplicatedStorage = ReplicatedStorage,
            RunService = RunService,
            UserInputService = UserInputService,
            TweenService = TweenService,
            CollectionService = CollectionService,
            LocalPlayer = LocalPlayer,
            PlayerGui = PlayerGui,
            VirtualUser = VirtualUser,
            VirtualInputManager = VirtualInputManager,
        },
        Player = LocalPlayer,

        Config = CONFIG,
        States = {
            Kaitun = KaitunState,
            AutoFarm = {
                AutoTap = false,
                AutoClicker = false,
                AutoRebirth = false,
                RebirthMode = "Best Affordable",
                AutoEquipBest = false,
                AutoCleanTrash = false,
            },
            Hatch = {
                SelectedEgg = "Basic",
                HatchCount = "Auto",
                AutoHatch = false,
                AutoSpeed = true,
                SkipAnimation = true,
                SkipSecretAnimation = true,
                HatchDelay = CONFIG.HatchCooldown,
                LiveSpeed = 1.0,
            },
            Upgrade = {
                AutoSkillTree = false,
                PrioritySkills = "All (Cheapest First)",
                AutoUpgrades = false,
                AutoPhysicalUpgrades = false,
            },
            Island = {
                SelectedIsland = "Spawn",
                AutoUnlockNext = false,
                AutoBestTeleport = false,
                AutoPushBridge = true,
                SuppressPrompt = true,
                AutoConfirmOnTouch = true,
            },
            Reward = {
                AutoChests = false,
                AutoStars = false,
                AutoQuests = false,
                AutoDailyRewards = false,
                AutoLuckyDucky = true,
            },
            Player = {
                WalkSpeed = DEFAULT_WALKSPEED,
                JumpPower = DEFAULT_JUMPPOWER,
                DefaultWalkSpeed = DEFAULT_WALKSPEED,
                DefaultJumpPower = DEFAULT_JUMPPOWER,
                CustomWalkSpeed = false,
                CustomJumpPower = false,
                InfiniteJump = false,
                Noclip = false,
            },
            Optimization = {
                CpuSaver = false,
            },
            Machine = {
                AutoPotionBuy = false,
                PotionBuyAmount = 1,
                AutoPotionCraft = false,
                AutoPotionClaim = false,
                AutoGlitchedAck = false,
                AutoGlitchedEvolve = false,
                GlitchedEvolveConsumeEquipped = false,
                AutoHoneyPotClaim = false,
                AutoHoneyPotCraft = false,
                HoneyPotRecipe = "BagOfTreats",
                AutoLuckyEggMachine = false,
                AutoExpeditionCollect = false,
            },
            Event = {
                MonitorGlobalEvents = true,
                AutoBalloonInflate = false,
                AutoCloudRain = false,
                LastActiveSummary = "Checking events...",
            },
        },

        W2_ISLAND_BOUNDS = {
            { name = "Medieval Island", center = Vector3.new(2544, 1940, 7050), radius = 780 },
            { name = "Ice Age", center = Vector3.new(1534, 1350, 7116), radius = 500 },
            { name = "Prehistoric Island", center = Vector3.new(957, 903, 7131), radius = 400 },
            { name = "World 2 Spawn", center = Vector3.new(46, 568, 7031), radius = 500 },
        },

        ISLAND_NAME_ALIASES = {
            ["Castle Island"] = "Medieval Island",
            ["Castle"] = "Medieval Island",
            ["World 2"] = "World 2 Spawn",
            ["World 2 (Time Rift)"] = "World 2 Spawn",
            ["TimeRift"] = "World 2 Spawn",
        },

        Runtime = {
            lastLuckyDuckySpawn = 0,
            lastHatchSent = 0,
            isHatchingBusy = false,
            tapControllerOptimized = false,
            customCodeText = "",
        },

        Connections = {},
        CleanupCallbacks = {},
        Services = {},
        Controllers = {},
        Modules = {},
        Catalogs = {
            EggSecretCatalog = {},
            SecretPetCatalog = {},
        },
        Utils = {},
        Logger = {},
        API = {},
        UI = {},
        Window = nil,
        Rayfield = nil,
        ConfigManager = nil,
        WebhookSender = nil,
        SecretDetector = nil,
        KaitunTelemetry = nil,
        Lifecycle = nil,
        LoadedModules = {},
    }

    return ctx
end

function Context.Init(ctx)
    return ctx
end

return Context
