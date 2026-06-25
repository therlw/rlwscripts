-- Config.lua
-- Configuration & State Initialization

if not getgenv().Config then
    getgenv().Config = {
        MetaFarmActive = false,
        TargetKeyCount = 5,
        AutoFarmCoins = false,
        AutoFarmEggs = false,
        TargetEggType = "Any",
        TargetEggMultiplier = 50,
        TargetKeepOutMultiplier = 50,
        AutoHatchNearest = false,
        AutoLoot = false,
        GodMode = false,
        TeleportDelay = 0.8,
        HopOnBossCooldown = false,
        DeepBackroomsMode = false,
        RadarTeleport = false,
        FarmDeepChests = false,
        FarmDeepEvents = false,
        AutoUpgrades = {
            BackroomsBossDamage = false,
            BackroomsExtraLootRoll = false,
            BackroomsTokenFind = false,
            BackroomsDeepBossDamage = false,
            BackroomsCoinMultiplier = false,
            BackroomsEggLuck = false,
            BackroomsKeyFind = false
        },
        WebhookEnabled = false,
        WebhookURL = "",
        AutoMailbox = false,
    }
end

if not getgenv().SmartFarmState then
    getgenv().SmartFarmState = {
        Running          = true,
        PetAssignInterval= 0.15,
        AutoTapInterval  = 0.08,
        MaxTargetsPerTick= 8,
        FarmRange        = 250,
        ClickAuraRange   = 250,
        Mode             = "Combined",
        EggRoomUID       = nil,
        BossRoomUID      = nil,
        BossRespawningUntil = 0
    }
end

if not getgenv().LiveStats then
    getgenv().LiveStats = {
        StartTime = os.time(),
        BossesKilled = 0,
        HighestMultiplier = 0,
        RoomsExplored = 0,
        _seenRooms = {},
        BossStatus = "Searching...",
        CurrentKeys = 0,
        HighestMultiplierName = nil
    }
end

if not getgenv().BackroomsShared then
    getgenv().BackroomsShared = {
        VisitedRooms = {},
        visitedCount = 0,
        DeadEggRooms = {},
        DEAD_EGG_COOLDOWN = 300,
        DeadChestRooms = {},
        TargetEggRooms = {},
        LastInstanceJoinAttempt = 0,
        LastTeleportTime = 0,
        CurrentTeleportTarget = nil,
        RadarAntiCheatBlacklist = {},
        CurrentRadarTargetCoordKey = nil,
        NotifiedBossChest = false,
        _EggSpawnWaitTime = {},
        DeadCoords = {}
    }
end

return getgenv().Config
