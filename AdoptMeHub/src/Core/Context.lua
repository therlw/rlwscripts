-- src/Core/Context.lua
-- Shared Configuration, Mutable State, Runtime Telemetry, and Service Registry for AdoptMeHub

local Context = {}

function Context.Create(opts)
    opts = opts or {}

    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    local VirtualUser = game:GetService("VirtualUser")
    local CollectionService = game:GetService("CollectionService")

    local LocalPlayer = Players.LocalPlayer
    while not LocalPlayer do
        Players.PlayerAdded:Wait()
        LocalPlayer = Players.LocalPlayer
    end

    local CONFIG = {
        Notifications = {
            Enabled = true,
            Ailments = false,
            TradeAlerts = true,
        },
        Persistence = {
            AutoLoad = true,
            AutoSave = true,
            FileName = "AdoptMeHub/config.json",
            HouseFolder = "AdoptMeHub/houses",
        },
        Hotkeys = {
            ToggleUI = "RightShift",
            ToggleDualFarm = "None",
        },
        Debug = {
            DebugMode = false,
        },
    }

    local States = {
        Farm = {
            DualFarm = false,         -- Baby + Pet simultaneous farm
            AutoBabyTeam = true,      -- Automatically choose Babies team
            AutoAilments = true,      -- Complete Baby & Pet tasks
            AutoAgeQueue = false,     -- Rotate to next pet once Full Grown
            AgeQueueRarity = "All",   -- "All", "legendary", "ultra_rare", "rare", "uncommon", "common"
            AgeQueuePetKind = "",     -- Optional specific pet kind filter
            AutoHatchEggs = false,    -- Equip & hatch eggs sequentially
            AutoLure = false,         -- Claim & re-bait home Lure Box
            LureBaitMode = "Free / Any Bait",
            AutoBuyEggs = false,      -- Buy eggs when Bucks > reserve
            SelectedEgg = "fairytale_egg_2026_fairytale_egg",
            BuyEggMinBucks = 750,
            AutoMysteryAilment = true,
            AutoClaimDailyAndPlaytime = true,
        },
        Events = {
            AutoLightningDimension = false,
            AutoMinigames = false,
            AutoUseKittyBiscuit = false,
            AutoUseAgePotions = false,
        },
        Pets = {
            AutoNeon = false,
            AutoMegaNeon = false,
            AutoEquipBest = false,
            SelectedEquipMode = "Highest Rarity",
            VisualPetKind = "frost_dragon",
            VisualPetNeon = "Mega Neon", -- "Normal", "Neon", "Mega Neon"
            VisualPetRide = true,
            VisualPetFly = true,
            AutoStoreDuplicates = false,
            KeepEquippedCount = 4,
        },
        House = {
            AutoPay = false,
            PayTargetPlayer = "",
            AutoCollectRegister = false,
            SelectedHouseFile = "saved_house",
        },
        Trade = {
            ShowTradeValues = true,
            AutoDeclineTrades = false,
            AutoAcceptWinFair = false,
            MinWinMargin = 0,
        },
        Visuals = {
            EventObjectESP = false,
            PlayerPetESP = false,
            UltraFPSBoost = false,
            Disable3DRender = false,
            ShowAFKOverlay = false,
            AntiAFK = true,
            AutoReconnect = true,
        },
    }

    local Runtime = {
        StartedAt = os.clock(),
        StartMoney = 0,
        Status = {
            Farm = "Beklemede",
            Events = "Beklemede",
            Pets = "Beklemede",
            Trade = "Hazır",
        },
        Cooldowns = {
            LastAilmentStepAt = 0,
            LastLocationSwitchAt = 0,
            LastEquipAt = 0,
            LastLureAt = 0,
            LastEggBuyAt = 0,
            LastNeonAt = 0,
            LastEventAt = 0,
            LastMinigameAt = 0,
            LastPayAt = 0,
            LastDailyAt = 0,
        },
        Telemetry = {
            TasksCompleted = 0,
            BucksEarned = 0,
            EggsHatched = 0,
            NeonsFused = 0,
            LuresClaimed = 0,
            PaymentsSent = 0,
        },
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
            TeleportService = TeleportService,
            GuiService = GuiService,
            VirtualUser = VirtualUser,
            CollectionService = CollectionService,
            LocalPlayer = LocalPlayer,
        },
        Config = CONFIG,
        States = States,
        Runtime = Runtime,
        Lifecycle = nil,
        Utils = nil,
        Bridge = nil,
        Services = {},
        UI = {},
        Window = nil,
        API = {},
    }

    return ctx
end

return Context
