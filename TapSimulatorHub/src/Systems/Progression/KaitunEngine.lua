-- src/Systems/Progression/KaitunEngine.lua
-- Autonomous Strategic Decision Engine & Kaitun Background Loop

local KaitunEngine = {}

function KaitunEngine.Init(ctx)
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local KaitunState = ctx.States.Kaitun
    local OptimizationState = ctx.States.Optimization

    local getPlayerData = ctx.API.getPlayerData
    local getCoins = ctx.API.getCoins
    local getGems = ctx.API.getGems
    local getRebirthCount = ctx.API.getRebirthCount
    local getPetStorageInfo = ctx.API.getPetStorageInfo
    local hasX8Gamepass = ctx.API.hasX8Gamepass
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay
    local equipBestPets = ctx.API.equipBestPets
    local formatCompact = ctx.Utils.formatCompact
    local requireSafe = ctx.Utils.requireSafe

    local getBridgeStatus = ctx.API.getBridgeStatus
    local pushBridge = ctx.API.pushBridge
    local isWorld2Unlocked = ctx.API.isWorld2Unlocked
    local getNextLockedIsland = ctx.API.getNextLockedIsland
    local unlockIsland = ctx.API.unlockIsland
    local getBestUnlockedIsland = ctx.API.getBestUnlockedIsland
    local travelToIsland = ctx.API.travelToIsland
    local goToEgg = ctx.API.goToEgg
    local cleanTrashPets = ctx.API.cleanTrashPets
    local getBuyableSkillUpgrades = ctx.API.getBuyableSkillUpgrades
    local purchaseSkillNode = ctx.API.purchaseSkillNode
    local collectIslandShinyStars = ctx.API.collectIslandShinyStars
    local manageSmartBoosts = ctx.API.manageSmartBoosts
    local autoCraftEvolutionPets = ctx.API.autoCraftEvolutionPets

    local T = ctx.KaitunTelemetry

    local function runKaitunCycle()
        if not KaitunState.Enabled then return end

        local safeNotify = function(opts)
            if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
        end

        if KaitunState.StrategyNote == "Turn on AI Kaitun to begin autonomous progression" then
            KaitunState.StrategyNote = "Evaluating best progression path..."
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (char and hrp and hum and hum.Health > 0) then
            KaitunState.CurrentAction = "Waiting for Respawn / Character..."
            return
        end

        local data = getPlayerData()
        if not data then return end

        local coins = getCoins()
        local _gems = getGems()
        local rebirthCount = getRebirthCount()
        local ownedCount, _maxStorage, freeSlots = getPetStorageInfo()
        local bridgeStatus = getBridgeStatus()
        local nextIsl = getNextLockedIsland()
        local bestUnlockedIsl = getBestUnlockedIsland()
        local physicalIsland = T.getPhysicalCurrentIsland()
        local curWorld = data.Progression and data.Progression.World or "Main"
        local curIsland = physicalIsland or (data.Progression and data.Progression.Island) or "Spawn"
        local now = os.clock()

        if KaitunState.LastEvaluatedIsland ~= curIsland then
            local prevIsl = KaitunState.LastEvaluatedIsland
            KaitunState.LastEvaluatedIsland = curIsland
            if OptimizationState and OptimizationState.CpuSaver and ctx.API.updateRegionalCulling then
                task.defer(function()
                    pcall(ctx.API.updateRegionalCulling)
                end)
            end
            if prevIsl ~= nil then
                safeNotify({
                    title = "New Island Checkpoint!",
                    content = string.format("Arrived at %s! Recalibrating entire progression strategy...", curIsland),
                    duration = 5
                })
            end
        end

        ----------------------------------------------------------------------------
        -- 1. EQUIPPED PET TEAM & POWER ANALYSIS
        ----------------------------------------------------------------------------
        local equippedIds = data.Pets and data.Pets.Equipped or {}
        local ownedPets = data.Pets and data.Pets.Owned or {}
        local teamPower = 0
        local equippedCount = 0
        for _, id in ipairs(equippedIds) do
            local p = ownedPets[id]
            if p and p.Power then
                teamPower = teamPower + p.Power
                equippedCount = equippedCount + 1
            end
        end

        local PetPowerModule = Mod.PetPowerModule or requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end)
        local effMap = {}
        local effectiveTeamPower = 0
        if PetPowerModule and PetPowerModule.GetOwnedPowers and ownedPets then
            pcall(function() effMap = PetPowerModule.GetOwnedPowers(ownedPets) end)
            for _, id in ipairs(equippedIds) do
                effectiveTeamPower = effectiveTeamPower + (effMap[id] or (ownedPets[id] and ownedPets[id].Power) or 0)
            end
        else
            effectiveTeamPower = teamPower
        end

        local teamPowers = {}
        for _, id in ipairs(equippedIds) do
            local p = ownedPets[id]
            if p then
                local pwr = effMap[id] or p.Power or 0
                table.insert(teamPowers, pwr)
            end
        end
        table.sort(teamPowers)
        local weakestPetPower = teamPowers[1] or 0

        ----------------------------------------------------------------------------
        -- 2. LIVE COIN PRODUCTION VELOCITY & BOOST FINGERPRINT TELEMETRY
        ----------------------------------------------------------------------------
        local ProfileStats = Mod.ProfileStats or requireSafe(function() return ReplicatedStorage.Modules.Client.Game.ProfileStats end)
        local rebirthMulti = 1
        local islandBonus = 1.0
        local critChance = 0.05
        local critPower = 10
        if ProfileStats and data then
            pcall(function()
                rebirthMulti = ProfileStats.RebirthMulti(data) or (rebirthCount + 1)
                islandBonus = ProfileStats.IslandBonus(data) or 1.0
                critChance = ProfileStats.CritChance(data) or 0.05
                critPower = ProfileStats.CritPower(data) or 10
            end)
        else
            rebirthMulti = rebirthCount + 1
        end

        local boostFingerprint = T.getBoostFingerprint(data)
        local BoostFormula = Mod.BoostFormula or requireSafe(function() return ReplicatedStorage.Shared.Items.BoostFormula end)
        local activeGoldenChance = 0
        if BoostFormula and BoostFormula.GetStatMultiplier and data then
            pcall(function()
                activeGoldenChance = math.clamp(BoostFormula.GetStatMultiplier(data, "GoldenHatch") or 0, 0, 1)
            end)
        end

        local baseCoinPerTap = math.max(1, effectiveTeamPower) * rebirthMulti * islandBonus
        local effectiveTap = baseCoinPerTap * (1 + critChance * (critPower - 1))
        local predictedVelocity = math.max(1, effectiveTap * 13.33)

        local coinVelocity, measuredVelocity, _, velSource = T.updateVelocityMeasurement(coins, curWorld, curIsland, rebirthCount, effectiveTeamPower, predictedVelocity, boostFingerprint)

        KaitunState.PredictedVelocity = predictedVelocity
        KaitunState.MeasuredVelocity = measuredVelocity
        KaitunState.CoinVelocity = coinVelocity
        KaitunState.VelocitySource = velSource
        KaitunState.MeasuredVelocityStr = T.VelocityTracker.Status
        if measuredVelocity then
            local diff = math.abs(predictedVelocity - measuredVelocity)
            KaitunState.VelocityDiffPct = (diff / math.max(1, measuredVelocity)) * 100
        else
            KaitunState.VelocityDiffPct = nil
        end

        local progressionStage = T.determineProgressionStage(curWorld, curIsland, rebirthCount, rebirthMulti, effectiveTeamPower, nextIsl, bridgeStatus)
        KaitunState.ProgressionStage = progressionStage

        ----------------------------------------------------------------------------
        -- 3. CANDIDATE EGGS & PET UPGRADE EVALUATION
        ----------------------------------------------------------------------------
        local candidateEggs = {}
        local LaunchPetConfig = Mod.LaunchPetConfig or requireSafe(function() return ReplicatedStorage.Shared.Pets.LaunchPetConfig end)
        local liveEggsFolder = workspace:FindFirstChild("Eggs")

        local function isEligibleFarmEgg(eggName, eggInfo)
            if type(eggInfo) ~= "table" or not eggInfo.Price or eggInfo.Price <= 0 then return false end
            if eggInfo.ShowcaseOnly or eggInfo.Limited or eggName == "Glitched Egg" then return false end
            if eggInfo.Currency and eggInfo.Currency ~= "Coins" and eggInfo.Currency ~= "RiftCoins" then return false end
            if liveEggsFolder and not liveEggsFolder:FindFirstChild(eggName) then return false end
            return true
        end

        local function eggMatchesIsland(reqIsland, targetIsland)
            if reqIsland == targetIsland then return true end
            if curWorld == "TimeRift" and (targetIsland == "Spawn" or targetIsland == "World 2 Spawn") and (reqIsland == "Spawn" or reqIsland == "World 2 Spawn") then
                return true
            end
            return false
        end

        for eggName, eggInfo in pairs(Mod.LaunchEggConfig or {}) do
            local eggWorld = eggInfo.World or "Main"
            local reqIsland = eggInfo.Island or "Spawn"
            if eggWorld == curWorld and eggMatchesIsland(reqIsland, curIsland) and isEligibleFarmEgg(eggName, eggInfo) then
                local eggData = T.evaluateEggTrueStats(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, freeSlots, 5, activeGoldenChance)
                if eggData.IsVerified then
                    table.insert(candidateEggs, eggData)
                end
            end
        end

        if #candidateEggs == 0 then
            local unlockedIslands = data.Progression and data.Progression.UnlockedIslands or {}
            for eggName, eggInfo in pairs(Mod.LaunchEggConfig or {}) do
                local eggWorld = eggInfo.World or "Main"
                local reqIsland = eggInfo.Island or "Spawn"
                local isIslUnlocked = (reqIsland == "Spawn") or (reqIsland == "World 2 Spawn") or (unlockedIslands[reqIsland] == true) or (type(unlockedIslands) == "table" and table.find(unlockedIslands, reqIsland) ~= nil)
                if eggWorld == curWorld and isIslUnlocked and isEligibleFarmEgg(eggName, eggInfo) then
                    local eggData = T.evaluateEggTrueStats(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, freeSlots, 5, activeGoldenChance)
                    if eggData.IsVerified then
                        table.insert(candidateEggs, eggData)
                    end
                end
            end
        end

        local maxSaveTime = CONFIG.MaxEggSaveTimes[progressionStage] or 60
        local affordableUpgradeEggs = {}
        local reachableSavingEggs = {}
        local allUpgradeEggs = {}

        for _, egg in ipairs(candidateEggs) do
            local isEventEgg = (egg.Name:find("30M") or egg.Name:find("Event") or egg.Name:find("Visit") or egg.Price >= 50000000)
            local isEarlyOrMid = (progressionStage == "Early Game" or progressionStage == "Mid Game" or coins < 50000000)
            local skipEvent = isEventEgg and isEarlyOrMid

            if not skipEvent and egg.IsUpgrade then
                table.insert(allUpgradeEggs, egg)
                if coins >= egg.Price then
                    table.insert(affordableUpgradeEggs, egg)
                else
                    local eta = (egg.Price - coins) / math.max(1, coinVelocity)
                    if eta <= maxSaveTime then
                        table.insert(reachableSavingEggs, { egg = egg, eta = eta })
                    end
                end
            end
        end

        local bestUpgradeEgg = nil
        if #affordableUpgradeEggs > 0 then
            table.sort(affordableUpgradeEggs, function(a, b)
                local aGain = math.max(a.ExpectedEffectiveTeamGain or 0, a.ExpectedGoldenTeamGain or 0, a.ExpectedDiamondTeamGain or 0)
                local bGain = math.max(b.ExpectedEffectiveTeamGain or 0, b.ExpectedGoldenTeamGain or 0, b.ExpectedDiamondTeamGain or 0)
                if math.abs(aGain - bGain) > 1e-4 then
                    return aGain > bGain
                end
                return a.Price > b.Price
            end)
            bestUpgradeEgg = affordableUpgradeEggs[1]
        elseif #reachableSavingEggs > 0 then
            table.sort(reachableSavingEggs, function(a, b)
                local aGain = math.max(a.egg.ExpectedEffectiveTeamGain or 0, a.egg.ExpectedGoldenTeamGain or 0, a.egg.ExpectedDiamondTeamGain or 0)
                local bGain = math.max(b.egg.ExpectedEffectiveTeamGain or 0, b.egg.ExpectedGoldenTeamGain or 0, b.egg.ExpectedDiamondTeamGain or 0)
                local aScore = aGain / math.max(1, a.eta)
                local bScore = bGain / math.max(1, b.eta)
                if math.abs(aScore - bScore) > 1e-4 then
                    return aScore > bScore
                end
                return a.egg.Price < b.egg.Price
            end)
            bestUpgradeEgg = reachableSavingEggs[1].egg
        elseif #allUpgradeEggs > 0 then
            table.sort(allUpgradeEggs, function(a, b)
                return a.Price < b.Price
            end)
            local cheapest = allUpgradeEggs[1]
            local cheapEta = (cheapest.Price - coins) / math.max(1, coinVelocity)
            if cheapEta <= maxSaveTime * 3 or cheapest.Price <= math.max(1000, coins * 10) then
                bestUpgradeEgg = cheapest
            else
                bestUpgradeEgg = nil
            end
        end

        if not bestUpgradeEgg and curWorld == "Main" and (ownedCount < 5 or rebirthCount < 5) and curIsland == "Spawn" then
            if coins >= 100 then
                bestUpgradeEgg = {
                    Name = "Basic",
                    Price = 100,
                    TriplePrice = 300,
                    Island = "Spawn",
                    MinPower = 1,
                    MaxPower = 10,
                    ExpectedPetPower = 3,
                    ExpectedGoldenPower = 9,
                    ExpectedDiamondPower = 21,
                    ExpectedEffectivePetPower = 3,
                    ExpectedTeamGain = 3,
                    ExpectedGoldenTeamGain = 9,
                    ExpectedEffectiveTeamGain = 3,
                    ExpectedTripleTeamGain = 9,
                    ExpectedTripleEffectiveTeamGain = 9,
                    Efficiency = 3 / 100,
                    TripleEfficiency = 9 / 300,
                    HasProbabilities = false,
                    IsVerified = true,
                    IsUpgrade = true
                }
            end
        end

        local isTeamSaturated = (bestUpgradeEgg == nil and equippedCount >= 5)

        ----------------------------------------------------------------------------
        -- 4. REBIRTH OPPORTUNITY & PROGRESSION SCORE ANALYSIS
        ----------------------------------------------------------------------------
        local worldArg = (curWorld ~= "Main" and curWorld or nil)
        local frontier = T.getFrontierRebirthInfo()
        local highestUnlockedIdx = frontier and frontier.highestUnlockedIdx or 1
        local frontierPrice = frontier and frontier.price or 0

        local milestoneTarget = (nextIsl and nextIsl.price) or (bestUpgradeEgg and bestUpgradeEgg.Price) or (frontierPrice * 2)

        local viableRebirths = {}
        for i = 1, highestUnlockedIdx do
            local a = Mod.RebirthConfig.GetAmountFromIndex(i, worldArg)
            local p = Mod.RebirthConfig.GetPrice(a, rebirthCount, nil, worldArg)
            local isAffordable = (coins >= p and p > 0)
            local tempTier = { Amount = a, Price = p, Index = i }
            local score, netDelta, grossRecTime, netBreakEven, newVel, etaA, etaB, coinsAfter, timeToAfford = T.calculateProgressionScore(tempTier, coins, coinVelocity, rebirthMulti, milestoneTarget, progressionStage)

            table.insert(viableRebirths, {
                Index = i,
                Amount = a,
                Price = p,
                MultGainPct = (a / math.max(rebirthMulti, 1)) * 100,
                IsAffordable = isAffordable,
                CoinsBefore = coins,
                CoinsAfter = coinsAfter,
                TimeToAfford = timeToAfford,
                CurrentVelocity = coinVelocity,
                NewVelocity = newVel,
                GrossRecoveryTime = grossRecTime,
                NetBreakEvenTime = netBreakEven,
                RecoveryTime = grossRecTime,
                ETABefore = etaA,
                ETAWithout = etaA,
                ETAWith = etaB,
                NetDeltaSeconds = netDelta,
                ProgressionScore = score
            })
        end

        local bestAffordableRebirth = nil
        local bestScore = -math.huge
        local targetMilestoneRebirth = nil
        local targetMacroRebirth = nil
        local bestMilestoneDelta = 0
        local bestMacroGain = 0

        local isEndgameWorld = (curWorld == "TimeRift" and not nextIsl)
        if isEndgameWorld then
            local frontierIdx = highestUnlockedIdx
            targetMacroRebirth = viableRebirths[frontierIdx] or viableRebirths[#viableRebirths]

            for i = #viableRebirths, 1, -1 do
                local r = viableRebirths[i]
                if r.IsAffordable and r.Price > 0 and r.Index >= frontierIdx then
                    bestAffordableRebirth = r
                    bestScore = 1000 + r.Amount
                    break
                end
            end
        else
            for i = 1, #viableRebirths do
                local r = viableRebirths[i]
                if r.IsAffordable and r.NetDeltaSeconds > 0 and r.ProgressionScore > bestScore then
                    bestScore = r.ProgressionScore
                    bestAffordableRebirth = r
                end
            end
            if bestScore <= 0 then
                bestAffordableRebirth = nil
            end

            for _, r in ipairs(viableRebirths) do
                if r.NetDeltaSeconds > bestMilestoneDelta then
                    bestMilestoneDelta = r.NetDeltaSeconds
                    targetMilestoneRebirth = r
                end
                if r.MultGainPct > bestMacroGain and r.GrossRecoveryTime <= 300 then
                    bestMacroGain = r.MultGainPct
                    targetMacroRebirth = r
                end
            end
        end

        ----------------------------------------------------------------------------
        -- 5. MILESTONE FORMULATION & DYNAMIC CAPITAL PROTECTION
        ----------------------------------------------------------------------------
        local timeToNextIsland = math.huge
        local dynamicSaveThreshold = 0.50
        if progressionStage == "Early Game" then
            dynamicSaveThreshold = 0.75
        elseif progressionStage == "Mid Game" then
            dynamicSaveThreshold = 0.60
        elseif progressionStage == "Late Game" then
            dynamicSaveThreshold = 0.50
        else
            dynamicSaveThreshold = 0.40
        end

        local isNearIslandSprint = false
        local targetIslandCoins = coins
        if nextIsl then
            if nextIsl.isRift then
                targetIslandCoins = (data.Currencies and data.Currencies.RiftCoins) or 0
            else
                targetIslandCoins = (data.Currencies and data.Currencies.Coins) or coins
            end
            local dist = math.max(0, nextIsl.price - targetIslandCoins)
            timeToNextIsland = dist / math.max(coinVelocity, 1)
            local recoveryBaseline = (bestAffordableRebirth and bestAffordableRebirth.RecoveryTime) or 30
            if targetIslandCoins >= nextIsl.price * dynamicSaveThreshold or timeToNextIsland <= math.max(30, recoveryBaseline * 1.5) then
                isNearIslandSprint = true
            end
        end

        local isSavingForIsland = isNearIslandSprint
        local isActivelyHatching = KaitunState.AllowHatch and (freeSlots > 0) and bestUpgradeEgg ~= nil and not isNearIslandSprint

        if nextIsl then
            local pct = math.clamp(math.floor((targetIslandCoins / math.max(nextIsl.price, 1)) * 100), 0, 100)
            local secGoalStr = ""
            if bestUpgradeEgg then
                secGoalStr = string.format(" | Secondary: %s Egg (%s)", bestUpgradeEgg.Name, formatCompact(bestUpgradeEgg.Price))
            elseif targetMilestoneRebirth then
                secGoalStr = string.format(" | Secondary: +%s Rebirth (Saves %ds)", formatCompact(targetMilestoneRebirth.Amount), math.floor(targetMilestoneRebirth.NetDeltaSeconds))
            elseif targetMacroRebirth then
                secGoalStr = string.format(" | Macro: +%s Rebirth (Delays by %ds)", formatCompact(targetMacroRebirth.Amount), math.abs(math.floor(targetMacroRebirth.NetDeltaSeconds)))
            end
            KaitunState.CurrentGoal = string.format("Primary: Unlock %s [%s / %s (%d%%)]%s", nextIsl.name, formatCompact(targetIslandCoins), formatCompact(nextIsl.price), pct, secGoalStr)
        elseif isEndgameWorld and bestUpgradeEgg then
            local rebPct = targetMacroRebirth and math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100) or 0
            local unlockNote = (targetMacroRebirth and targetMacroRebirth.Index == 9) and " [Unlocks +2M!]" or ""
            local rebStr = targetMacroRebirth and string.format(" | Rebirth +%s [%s / %s (%d%%)]%s", formatCompact(targetMacroRebirth.Amount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), rebPct, unlockNote) or ""
            KaitunState.CurrentGoal = string.format("Dual-Drive: Hatching %s Mythics%s", bestUpgradeEgg.Name, rebStr)
        elseif bestUpgradeEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestUpgradeEgg.Price, 1)) * 100), 0, 100)
            local secGoalStr = ""
            if targetMilestoneRebirth then
                secGoalStr = string.format(" | Secondary: +%s Rebirth (Saves %ds)", formatCompact(targetMilestoneRebirth.Amount), math.floor(targetMilestoneRebirth.NetDeltaSeconds))
            elseif targetMacroRebirth then
                secGoalStr = string.format(" | Macro: +%s Rebirth (Delays by %ds)", formatCompact(targetMacroRebirth.Amount), math.abs(math.floor(targetMacroRebirth.NetDeltaSeconds)))
            end
            KaitunState.CurrentGoal = string.format("Primary: Save for %s Egg [%s / %s (%d%%)]%s", bestUpgradeEgg.Name, formatCompact(coins), formatCompact(bestUpgradeEgg.Price), pct, secGoalStr)
        elseif targetMilestoneRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMilestoneRebirth.Price, 1)) * 100), 0, 100)
            KaitunState.CurrentGoal = string.format("Milestone Rebirth: +%s [%s / %s (%d%%)]", formatCompact(targetMilestoneRebirth.Amount), formatCompact(coins), formatCompact(targetMilestoneRebirth.Price), pct)
        elseif targetMacroRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
            local unlockNote = (targetMacroRebirth.Index == 9) and " (Unlocks Final Slot 10: +2M!)" or ""
            local goalPrefix = (isEndgameWorld or (isTeamSaturated and not nextIsl)) and "Endgame Rebirth" or "Target Rebirth"
            KaitunState.CurrentGoal = string.format("%s: +%s [%s / %s (%d%%)]%s", goalPrefix, formatCompact(targetMacroRebirth.Amount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct, unlockNote)
        else
            KaitunState.CurrentGoal = "Endgame Reached (All Worlds, Islands & Max Tiers Unlocked!)"
        end

        local worldLabel = (curWorld == "TimeRift") and "World 2" or "World 1"
        KaitunState.AccountStage = string.format("[%s] %s: %s | %d Rebirths | %s Coins", progressionStage, worldLabel, curIsland, rebirthCount, formatCompact(coins))

        ----------------------------------------------------------------------------
        -- 5b. DYNAMIC MULTI-TIER PRIORITY GENERATION
        ----------------------------------------------------------------------------
        local priorities = {}
        if isNearIslandSprint and nextIsl then
            local pct = math.clamp(math.floor((targetIslandCoins / math.max(nextIsl.price, 1)) * 100), 0, 100)
            table.insert(priorities, string.format("1. [SAVE MODE] Sprint to %s [%s / %s (%d%%)] (ETA: %ds)",
                nextIsl.name, formatCompact(targetIslandCoins), formatCompact(nextIsl.price), pct, math.floor(timeToNextIsland)))
            table.insert(priorities, "2. Lock rebirths & egg spending to protect capital")
            if bestUpgradeEgg then
                table.insert(priorities, string.format("3. Modernize team with %s Egg on %s once unlocked", bestUpgradeEgg.Name, nextIsl.name))
            else
                table.insert(priorities, string.format("3. Farm on %s for higher zone multiplier", nextIsl.name))
            end
        elseif bestAffordableRebirth and (bestAffordableRebirth.NetDeltaSeconds > 0 or (isTeamSaturated and not nextIsl)) and bestScore > 0 then
            local savesStr = (isTeamSaturated and not nextIsl) and "Endgame Step" or string.format("Saves %ds", math.floor(bestAffordableRebirth.NetDeltaSeconds))
            table.insert(priorities, string.format("1. Rebirth with +%s tier (+%.1f%% velocity, Gross Rec: %ds, %s, Score: %.1f)",
                formatCompact(bestAffordableRebirth.Amount), bestAffordableRebirth.MultGainPct, math.floor(bestAffordableRebirth.GrossRecoveryTime), savesStr, bestScore))
            table.insert(priorities, string.format("2. Re-farm coins at +%s/s with accelerated multiplier", formatCompact(bestAffordableRebirth.NewVelocity)))
            if isTeamSaturated and not nextIsl and targetMacroRebirth then
                local unlockNote = (targetMacroRebirth.Index == 9) and " (Unlocks Final Slot 10: +2M!)" or ""
                table.insert(priorities, string.format("3. Next Ladder Step: +%s Rebirth (%s)%s", formatCompact(targetMacroRebirth.Amount), formatCompact(targetMacroRebirth.Price), unlockNote))
            elseif bestUpgradeEgg then
                table.insert(priorities, string.format("3. Accumulate for %s Egg (%s)", bestUpgradeEgg.Name, formatCompact(bestUpgradeEgg.Price)))
            elseif nextIsl then
                table.insert(priorities, string.format("3. Push toward %s (%s)", nextIsl.name, formatCompact(nextIsl.price)))
            end
        elseif bestUpgradeEgg and coins >= bestUpgradeEgg.Price then
            local evLabel = (activeGoldenChance > 0) and string.format("Weighted Golden EV (%.0f%%)", activeGoldenChance * 100) or "Normal EV"
            local singleGain = bestUpgradeEgg.ExpectedEffectiveTeamGain or 0
            local tripleGain = bestUpgradeEgg.ExpectedTripleEffectiveTeamGain or 0
            local chosenCount = 1
            if hasX8Gamepass() and freeSlots >= 8 and coins >= (bestUpgradeEgg.Price * 8) then
                chosenCount = 8
            elseif KaitunState.AllowTripleHatch ~= false and freeSlots >= 3 and coins >= bestUpgradeEgg.TriplePrice and (tripleGain > singleGain * 1.3 or isEndgameWorld) then
                chosenCount = 3
            end
            local chosenGain = (chosenCount == 8) and (tripleGain * 2.6) or ((chosenCount == 3) and tripleGain or singleGain)
            table.insert(priorities, string.format("1. Hatch %s Egg x%d (Weakest: %s Pwr -> Gain: +%s [%s])",
                bestUpgradeEgg.Name, chosenCount, formatCompact(weakestPetPower), formatCompact(chosenGain), evLabel))
            table.insert(priorities, "2. Auto-evolve newly hatched pets to Golden / Diamond in Machine")
            if targetMacroRebirth then
                table.insert(priorities, string.format("3. Long-term Macro: +%s Rebirth once team is upgraded", formatCompact(targetMacroRebirth.Amount)))
            end
        elseif bestUpgradeEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestUpgradeEgg.Price, 1)) * 100), 0, 100)
            local timeToEgg = math.max(0, bestUpgradeEgg.Price - coins) / coinVelocity
            local evLabel = (activeGoldenChance > 0) and string.format("Weighted Golden EV (%.0f%%)", activeGoldenChance * 100) or "Normal EV"
            local gainStr = formatCompact(bestUpgradeEgg.ExpectedEffectiveTeamGain or 0)
            table.insert(priorities, string.format("1. Save for %s Egg [%s / %s (%d%%)] (ETA: %ds, Gain: +%s [%s])",
                bestUpgradeEgg.Name, formatCompact(coins), formatCompact(bestUpgradeEgg.Price), pct, math.floor(timeToEgg), gainStr, evLabel))
            table.insert(priorities, "2. Rebirths locked to protect capital (any rebirth delays egg)")
            if targetMacroRebirth then
                table.insert(priorities, string.format("3. Long-term Macro: +%s Rebirth (%s) [Delays Egg by %ds]",
                    formatCompact(targetMacroRebirth.Amount), formatCompact(targetMacroRebirth.Price), math.abs(math.floor(targetMacroRebirth.NetDeltaSeconds))))
            end
        elseif targetMilestoneRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMilestoneRebirth.Price, 1)) * 100), 0, 100)
            table.insert(priorities, string.format("1. Milestone Rebirth +%s [%s / %s (%d%%)] (Saves %ds)",
                formatCompact(targetMilestoneRebirth.Amount), formatCompact(coins), formatCompact(targetMilestoneRebirth.Price), pct, math.floor(targetMilestoneRebirth.NetDeltaSeconds)))
        elseif targetMacroRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
            table.insert(priorities, string.format("1. Long-term Macro Rebirth +%s [%s / %s (%d%%)]",
                formatCompact(targetMacroRebirth.Amount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct))
        else
            table.insert(priorities, string.format("1. Farm coins on %s [Velocity: +%s/s]", curIsland, formatCompact(coinVelocity)))
        end

        KaitunState.DynamicPriority = table.concat(priorities, "\n")

        -- 2. Periodic Equip Best Pets
        if (now - KaitunState.LastBestEquip >= 15.0) then
            KaitunState.LastBestEquip = now
            equipBestPets()
        end

        -- 3. Gem Upgrades
        if KaitunState.AllowSkillTree and (now - KaitunState.LastSkillTime >= 2.0) then
            local buyable, readyCount = getBuyableSkillUpgrades()
            if readyCount > 0 then
                for _, item in ipairs(buyable) do
                    local ok = purchaseSkillNode(item.nodeToUnlock)
                    if ok then
                        KaitunState.LastSkillTime = now
                        KaitunState.CurrentAction = string.format("Purchased %s (%d Gems)", item.title, item.price)
                        safeNotify({
                            title = "Kaitun: Skill Unlocked!",
                            content = string.format("%s (Lvl %d) unlocked for %d Gems!", item.title, item.level + 1, item.price)
                        })
                        task.wait(0.3)
                        break
                    end
                end
            end
        end

        -- 4a. Auto Pet Evolution Machine
        if KaitunState.AllowAutoCraft and (now - KaitunState.LastCraftTime >= 8.0) then
            KaitunState.LastCraftTime = now
            local gCount, dCount = autoCraftEvolutionPets(bestUnlockedIsl)
            if gCount > 0 or dCount > 0 then
                KaitunState.CurrentAction = string.format("Evolved %d Golden & %d Diamond pets!", gCount, dCount)
                task.wait(0.3)
                ownedCount, _maxStorage, freeSlots = getPetStorageInfo()
            end
        end

        -- 4. Smart Pet Storage & Trash Cleaning
        if KaitunState.AllowTrashCleaning and (freeSlots < 35 or (now - KaitunState.LastTrashCheckTime >= 25.0)) then
            KaitunState.LastTrashCheckTime = now
            local cleaned = cleanTrashPets()
            if cleaned > 0 then
                KaitunState.CurrentAction = string.format("Cleaned %d trash pets", cleaned)
                safeNotify({
                    title = "Inventory Cleaned",
                    content = string.format("Auto-cleaned %d obsolete pets to maintain open slots!", cleaned)
                })
                task.wait(0.3)
                ownedCount, _maxStorage, freeSlots = getPetStorageInfo()
                isActivelyHatching = KaitunState.AllowHatch and (freeSlots > 0) and not isSavingForIsland
            end
        end

        -- 5. Physical Shiny Star Collection
        if KaitunState.CollectShinyStars and (now - KaitunState.LastStarCheckTime >= 8.0) then
            KaitunState.LastStarCheckTime = now
            local collected = collectIslandShinyStars()
            if collected then
                KaitunState.CurrentAction = "Collected Shiny Star!"
                task.wait(0.3)
            end
        end

        -- 6. Smart Potions & Boosts Management
        if KaitunState.AllowSmartBoosts and (now - KaitunState.LastBoostCheckTime >= 8.0) then
            KaitunState.LastBoostCheckTime = now
            manageSmartBoosts(isActivelyHatching, isSavingForIsland)
        end

        -- 7. In-Game Collectibles
        if KaitunState.AllowChestsAndStars and (now - KaitunState.LastChestTime >= 4.0) then
            KaitunState.LastChestTime = now
            pcall(function()
                if Mod.TapChestConfig and Svc.TapChestService and Svc.TapChestService:FindFirstChild("RF") and Svc.TapChestService.RF:FindFirstChild("Claim") then
                    for _, chest in ipairs(CollectionService:GetTagged(Mod.TapChestConfig.Tag or "TapChest")) do
                        local chestId = chest:GetAttribute("TapChestId") or chest:GetAttribute("Id") or chest.Name
                        if chestId then
                            Svc.TapChestService.RF.Claim:InvokeServer(chestId)
                            task.wait(0.05)
                        end
                    end
                end
                if Svc.QuestService and Svc.QuestService:FindFirstChild("RF") and Svc.QuestService.RF:FindFirstChild("ClaimQuest") and data.Quests then
                    for k, v in pairs(data.Quests) do
                        if v.Completed and not v.Claimed then
                            Svc.QuestService.RF.ClaimQuest:InvokeServer({ Quest = k })
                            task.wait(0.05)
                        end
                    end
                end
                if Svc.OfflineRewardsService and Svc.OfflineRewardsService:FindFirstChild("RF") and Svc.OfflineRewardsService.RF:FindFirstChild("Claim") then
                    Svc.OfflineRewardsService.RF.Claim:InvokeServer()
                end
            end)
        end

        -- 8. Drawbridge Lowering Check
        if not bridgeStatus.lowered then
            if bridgeStatus.ready then
                KaitunState.CurrentGoal = "Drawbridge Ready - Lowering Drawbridge!"
                KaitunState.CurrentAction = "Pushing Drawbridge Down..."
                local ok = pushBridge(6)
                if ok then
                    KaitunState.CurrentAction = "Drawbridge Lowered!"
                    safeNotify({ title = "Kaitun: Drawbridge Lowered!", content = "Path to Sky Island is now open!" })
                    task.wait(1.0)
                end
                return
            else
                KaitunState.CurrentGoal = string.format("Powering Drawbridge (%s / %s Power)", formatCompact(bridgeStatus.power), formatCompact(bridgeStatus.req))
                KaitunState.StrategyNote = "Tapping to charge drawbridge power..."
            end
        end

        ----------------------------------------------------------------------------
        -- 7. PROGRESSION DECISION EXECUTION
        ----------------------------------------------------------------------------
        local w2Unlocked = (data.Progression.UnlockedWorlds and data.Progression.UnlockedWorlds.TimeRift == true) or (isWorld2Unlocked and isWorld2Unlocked())
        if (w2Unlocked or (nextIsl and nextIsl.isRift)) and curWorld == "Main" then
            KaitunState.CurrentAction = "Advancing to World 2 (Time Rift)..."
            KaitunState.StrategyNote = "World 2 is unlocked! Teleporting to World 2 frontier to earn Rift Coins..."
            local targetIsl = bestUnlockedIsl
            if targetIsl == "Spawn" or targetIsl == "Heaven" or not targetIsl then
                targetIsl = "World 2 Spawn"
            end
            travelToIsland(targetIsl)
            task.wait(1.5)
            return
        end

        -- DECISION 1: UNLOCK NEXT ISLAND
        local islandCostMet = false
        if nextIsl then
            local curIslandCurrency = (nextIsl.isRift and data.Currencies and data.Currencies.RiftCoins) or coins
            islandCostMet = (curIslandCurrency >= nextIsl.price)
        end
        if KaitunState.AllowIslandUnlock and nextIsl and islandCostMet and bridgeStatus.lowered then
            T.invalidateVelocityMeasurement("Coin spend: Unlock Island", coins)
            local curCurrencyLabel = nextIsl.isRift and "Rift Coins" or "Coins"
            KaitunState.CurrentAction = string.format("Unlocking %s for %s %s!", nextIsl.name, formatCompact(nextIsl.price), curCurrencyLabel)
            KaitunState.StrategyNote = string.format("Milestone Achieved! Unlocking %s to access higher multiplier & new egg tier!", nextIsl.name)
            local ok = unlockIsland(nextIsl)
            if ok then
                KaitunState.CurrentAction = string.format("Unlocked %s! Teleporting...", nextIsl.name)
                safeNotify({ title = "Kaitun: Island Unlocked!", content = string.format("Advanced to %s!", nextIsl.name) })
                task.wait(0.5)
                travelToIsland(nextIsl.name)
                task.wait(1.5)
                return
            end
        end

        -- DECISION 2: CAPITAL PROTECTION SPRINT
        if isNearIslandSprint and nextIsl then
            local targetCoins = (nextIsl.isRift and data.Currencies and data.Currencies.RiftCoins) or coins
            KaitunState.StrategyNote = string.format("Save Mode: Sprinting to %s [%s / %s (ETA: %ds)]. Rebirths and Egg hatches paused.",
                nextIsl.name, formatCompact(targetCoins), formatCompact(nextIsl.price), math.floor(timeToNextIsland))

            local targetFarmIsland = bestUnlockedIsl
            if targetFarmIsland == "World 2 Spawn" and curWorld == "TimeRift" then
                targetFarmIsland = "Spawn"
            end
            if curIsland ~= targetFarmIsland and targetFarmIsland ~= "Spawn" and curIsland ~= "World 2 Spawn" then
                travelToIsland(targetFarmIsland)
            end
            KaitunState.CurrentAction = string.format("Fast Tapping on %s [Velocity: +%s/s]", curIsland, formatCompact(coinVelocity))
            return
        end

        -- DECISION 3: PET MODERNIZATION
        local canHatchEgg = KaitunState.AllowHatch and (freeSlots > 0) and bestUpgradeEgg and not isNearIslandSprint
        if canHatchEgg and (now - KaitunState.LastHatchTime >= getAutoHatchDelay()) then
            if coins >= bestUpgradeEgg.Price then
                local atStand = goToEgg(bestUpgradeEgg.Name)
                if atStand then
                    local hatchCount = 1
                    local singleGain = bestUpgradeEgg.ExpectedEffectiveTeamGain or 0
                    local tripleGain = bestUpgradeEgg.ExpectedTripleEffectiveTeamGain or 0
                    if hasX8Gamepass() and freeSlots >= 8 and coins >= (bestUpgradeEgg.Price * 8) then
                        hatchCount = 8
                    elseif KaitunState.AllowTripleHatch ~= false and freeSlots >= 3 and coins >= bestUpgradeEgg.TriplePrice and (tripleGain > singleGain * 1.3 or isEndgameWorld) then
                        hatchCount = 3
                    end
                    local evLabel = (activeGoldenChance > 0) and string.format("Weighted Golden EV (%.0f%%)", activeGoldenChance * 100) or "Normal EV"
                    local chosenGain = (hatchCount == 8) and (tripleGain * 2.6) or ((hatchCount == 3) and tripleGain or singleGain)

                    KaitunState.CurrentAction = string.format("Hatching %s Egg x%d (%s Coins)", bestUpgradeEgg.Name, hatchCount, formatCompact(bestUpgradeEgg.Price * hatchCount))
                    KaitunState.StrategyNote = string.format("Dual-Drive: Hatching %s Egg x%d (Weakest: %s Pwr -> Gain: +%s [%s])",
                        bestUpgradeEgg.Name, hatchCount, formatCompact(weakestPetPower), formatCompact(chosenGain), evLabel)
                    KaitunState.LastHatchTime = now
                    T.invalidateVelocityMeasurement("Coin spend: Egg Hatch", coins)
                    Svc.EggService.RE.EggHatchRequested:FireServer({
                        Egg = bestUpgradeEgg.Name,
                        Count = hatchCount,
                        Auto = false,
                        Roam = false
                    })
                    return
                else
                    KaitunState.CurrentAction = string.format("Approaching %s Egg stand...", bestUpgradeEgg.Name)
                    return
                end
            end
        end

        -- DECISION 4: HIGH-ROI STAGE-AWARE REBIRTH
        local allowEndgameRebirth = (isEndgameWorld and bestAffordableRebirth ~= nil and bestAffordableRebirth.Index >= highestUnlockedIdx)
        if KaitunState.AllowRebirth and bestAffordableRebirth and (allowEndgameRebirth or (bestAffordableRebirth.NetDeltaSeconds > 0 and bestAffordableRebirth.ProgressionScore > 0)) and (now - KaitunState.LastRebirthTime >= 2.0) and not isNearIslandSprint then
            if Svc.RebirthService and Svc.RebirthService:FindFirstChild("RE") and Svc.RebirthService.RE:FindFirstChild("RebirthRequested") then
                KaitunState.CurrentAction = string.format("Rebirthing! (+%s Rebirths | Score: %.1f)",
                    formatCompact(bestAffordableRebirth.Amount), bestAffordableRebirth.ProgressionScore)
                local noteReason = allowEndgameRebirth and string.format("Endgame Rebirth (+%s for %s Coins): +%.1f%% Velocity!", formatCompact(bestAffordableRebirth.Amount), formatCompact(bestAffordableRebirth.Price), bestAffordableRebirth.MultGainPct) or string.format("Stage-Aware Rebirth (+%s for %s Coins): +%.1f%% Velocity, Gross Rec %ds, Saves %ds!", formatCompact(bestAffordableRebirth.Amount), formatCompact(bestAffordableRebirth.Price), bestAffordableRebirth.MultGainPct, math.floor(bestAffordableRebirth.GrossRecoveryTime), math.floor(bestAffordableRebirth.NetDeltaSeconds))
                KaitunState.StrategyNote = noteReason

                T.invalidateVelocityMeasurement("Coin spend: Rebirth", coins)
                Svc.RebirthService.RE.RebirthRequested:FireServer({ Index = bestAffordableRebirth.Index })
                KaitunState.LastRebirthTime = now
                safeNotify({
                    title = allowEndgameRebirth and "Endgame Rebirth Achieved!" or "Stage-Aware Rebirth Achieved!",
                    content = string.format("+%s Rebirths! (Score: %.1f) Velocity +%.1f%%!",
                        formatCompact(bestAffordableRebirth.Amount), bestAffordableRebirth.ProgressionScore, bestAffordableRebirth.MultGainPct),
                    duration = 4
                })
                task.wait(0.35)
                if curIsland ~= "Spawn" then
                    travelToIsland(curIsland)
                end
                return
            end
        end

        -- DECISION 5: OPTIMAL FARMING & SAVING
        if curIsland ~= bestUnlockedIsl and bestUnlockedIsl ~= "Spawn" and not nextIsl then
            travelToIsland(bestUnlockedIsl)
        end

        KaitunState.CurrentAction = string.format("Fast Tapping on %s [Velocity: +%s/s]", curIsland, formatCompact(coinVelocity))

        if isEndgameWorld and bestUpgradeEgg then
            local rebPct = targetMacroRebirth and math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100) or 0
            local unlockNote = (targetMacroRebirth and targetMacroRebirth.Index == 9) and " (Unlocks Final Slot 10: +2M!)" or ""
            KaitunState.StrategyNote = string.format("Dual-Drive: Hunting %s Mythics (%s) to replace %s Pwr pet & Accumulating for +%s Rebirth [%s / %s (%d%%)]%s",
                bestUpgradeEgg.Name, formatCompact(bestUpgradeEgg.Price), formatCompact(weakestPetPower), targetMacroRebirth and formatCompact(targetMacroRebirth.Amount) or "400K", formatCompact(coins), targetMacroRebirth and formatCompact(targetMacroRebirth.Price) or "158QN", rebPct, unlockNote)
        elseif isEndgameWorld or (isTeamSaturated and not nextIsl) then
            if targetMacroRebirth then
                local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
                local unlockNote = (targetMacroRebirth.Index == 9) and " (Unlocks Final Slot 10: +2M!)" or ""
                KaitunState.StrategyNote = string.format("Endgame Saturated (%s Pwr). Pushing Rebirth Ladder -> +%s Rebirth [%s / %s (%d%%)]%s",
                    formatCompact(effectiveTeamPower), formatCompact(targetMacroRebirth.Amount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct, unlockNote)
            else
                KaitunState.StrategyNote = string.format("Endgame Farming: Team Power %s, %s Rebirths, Velocity +%s/s",
                    formatCompact(effectiveTeamPower), formatCompact(rebirthCount), formatCompact(coinVelocity))
            end
        elseif isTeamSaturated then
            if targetMacroRebirth then
                local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
                KaitunState.StrategyNote = string.format("Team Saturated (%s Pwr). Accumulating capital for +%s Rebirth [%s / %s (%d%%)] or %s",
                    formatCompact(effectiveTeamPower), formatCompact(targetMacroRebirth.Amount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct, nextIsl and nextIsl.name or "Endgame")
            elseif nextIsl then
                KaitunState.StrategyNote = string.format("Team Saturated (%s Pwr). Tapping toward %s [%s / %s]",
                    formatCompact(effectiveTeamPower), nextIsl.name, formatCompact(coins), formatCompact(nextIsl.price))
            else
                KaitunState.StrategyNote = string.format("Endgame Farming: Team Power %s, %s Rebirths, Velocity +%s/s",
                    formatCompact(effectiveTeamPower), formatCompact(rebirthCount), formatCompact(coinVelocity))
            end
        elseif bestUpgradeEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestUpgradeEgg.Price, 1)) * 100), 0, 100)
            local timeToEgg = math.max(0, bestUpgradeEgg.Price - coins) / coinVelocity
            local evLabel = (activeGoldenChance > 0) and string.format("Weighted Golden EV (%.0f%%)", activeGoldenChance * 100) or "Normal EV"
            local gainStr = formatCompact(bestUpgradeEgg.ExpectedEffectiveTeamGain or 0)
            KaitunState.StrategyNote = string.format("Saving for %s Egg [%s / %s (%d%%)] (ETA: %ds, Gain: +%s [%s]). Rebirths locked.",
                bestUpgradeEgg.Name, formatCompact(coins), formatCompact(bestUpgradeEgg.Price), pct, math.floor(timeToEgg), gainStr, evLabel)
        else
            KaitunState.StrategyNote = string.format("Optimizing account velocity on %s (+%s/s)", curIsland, formatCompact(coinVelocity))
        end
    end

    ctx.API.runKaitunCycle = runKaitunCycle
    KaitunEngine.runKaitunCycle = runKaitunCycle
    return KaitunEngine
end

function KaitunEngine.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local OptimizationState = ctx.States.Optimization
    local KaitunState = ctx.States.Kaitun
    local safeCall = ctx.Utils.safeCall
    local updateKaitunDisplays = ctx.API.updateKaitunDisplays

    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            local waitCadence = (OptimizationState and OptimizationState.CpuSaver) and (CONFIG.KaitunCycleIntervalCpuSaver or 2.5) or CONFIG.KaitunCycleInterval
            task.wait(waitCadence)
            if KaitunState.Enabled then
                safeCall("runKaitunCycle", KaitunEngine.runKaitunCycle)
                safeCall("updateKaitunDisplays", updateKaitunDisplays)
            end
        end
    end)
end

return KaitunEngine
