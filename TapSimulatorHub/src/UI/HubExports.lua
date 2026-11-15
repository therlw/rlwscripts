-- src/UI/HubExports.lua
-- Config Auto-Load, Global Event Summary Refresh, _RLW_Hub API Export & Loaded Toast

local HubExports = {}

function HubExports.Init(ctx)
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local UI = ctx.UI
    local A = ctx.API
    local States = ctx.States

    pcall(function()
        if CONFIG.Persistence and CONFIG.Persistence.AutoLoad and ConfigManager then
            local ok = ConfigManager:Load()
            if ok and UI.ConfigStatusText and UI.ConfigStatusText.Set then
                UI.ConfigStatusText:Set("Auto-loaded saved config.json at " .. os.date("%X"))
            end
        end
    end)

    pcall(function()
        if A.refreshGlobalEventsSummary then
            A.refreshGlobalEventsSummary()
        end
        if UI.EventStatusText and UI.EventStatusText.Set and States.Event then
            UI.EventStatusText:Set(States.Event.LastActiveSummary)
        end
    end)

    pcall(function()
        local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
        genFn()._RLW_Hub = {
            Version = ctx.Version,
            Generation = ctx.Generation,
            CONFIG = CONFIG,
            ConfigManager = ConfigManager,
            SecretDetector = ctx.SecretDetector,
            WebhookSender = ctx.WebhookSender,
            KaitunTelemetry = ctx.KaitunTelemetry,
            States = {
                Kaitun = States.Kaitun,
                AutoFarm = States.AutoFarm,
                Hatch = States.Hatch,
                Upgrade = States.Upgrade,
                Island = States.Island,
                Reward = States.Reward,
                Player = States.Player,
                Optimization = States.Optimization,
                Machine = States.Machine,
                Event = States.Event,
            },
            API = {
                getPlayerData = A.getPlayerData,
                getCoins = A.getCoins,
                getGems = A.getGems,
                getPetStorageInfo = A.getPetStorageInfo,
                buildDynamicEggList = A.buildDynamicEggList,
                buildDynamicIslandList = A.buildDynamicIslandList,
                getBestUnlockedIsland = A.getBestUnlockedIsland,
                getNextLockedIsland = A.getNextLockedIsland,
                travelToIsland = A.travelToIsland,
                getEggStandCFrame = A.getEggStandCFrame,
                goToEgg = A.goToEgg,
                cleanTrashPets = A.cleanTrashPets,
                evaluateTrashPetsDryRun = A.evaluateTrashPetsDryRun,
                isPetProtectedFromDelete = A.isPetProtectedFromDelete,
                equipBestPets = A.equipBestPets,
                buildLiveSnapshot = A.buildLiveSnapshot,
                evaluateKaitunStrategy = A.evaluateKaitunStrategy,
                evaluateKaitunStrategyOld = A.evaluateKaitunStrategyOld,
                runShadowComparison = A.runShadowComparison,
                runKaitunCycle = A.runKaitunCycle,
                updateKaitunDisplays = A.updateKaitunDisplays,
                evaluateEggTrueStats = A.evaluateEggTrueStats,
                calculateProgressionScore = A.calculateProgressionScore,
                computeExactMultiHatchGain = A.computeExactMultiHatchGain,
                collectIslandShinyStars = A.collectIslandShinyStars,
                autoCraftEvolutionPets = A.autoCraftEvolutionPets,
                refreshGlobalEventsSummary = A.refreshGlobalEventsSummary,
                runPotionMachineCycle = A.runPotionMachineCycle,
                runHoneyPotCycle = A.runHoneyPotCycle,
                ackGlitchedEggTier = A.ackGlitchedEggTier,
                activateLuckyEggMachine = A.activateLuckyEggMachine,
                collectReadyExpeditions = A.collectReadyExpeditions,
                purchasePhysicalUpgrades = A.purchasePhysicalUpgrades,
                claimAllReadyQuests = A.claimAllReadyQuests,
                setCpuSaverState = A.setCpuSaverState,
                restoreAllCulled = A.restoreAllCulledInstances,
                restoreAllCulledInstances = A.restoreAllCulledInstances,
                applyPlayerHumanoidStats = A.applyPlayerHumanoidStats,
            },
        }
    end)

    return HubExports
end

function HubExports.Start(ctx)
    if ctx.UI.safeNotify then
        ctx.UI.safeNotify({
            title = "Tap Simulator Hub",
            content = "Loaded successfully! Castle Update ready (Webhook + Config + All Systems synced).",
        })
    end
end

return HubExports
