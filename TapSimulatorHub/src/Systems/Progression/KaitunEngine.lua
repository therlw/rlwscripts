-- src/Systems/Progression/KaitunEngine.lua
-- Autonomous Strategic Decision Engine & Kaitun Background Loop

local KaitunEngine = {}

function KaitunEngine.Init(ctx)
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService
    local KaitunState = ctx.States.Kaitun
    local OptimizationState = ctx.States.Optimization

    local getPlayerData = ctx.API.getPlayerData
    local getCoins = ctx.API.getCoins
    local getGems = ctx.API.getGems
    local getPetStorageInfo = ctx.API.getPetStorageInfo
    local getAutoHatchDelay = ctx.API.getAutoHatchDelay
    local equipBestPets = ctx.API.equipBestPets
    local formatCompact = ctx.Utils.formatCompact

    local pushBridge = ctx.API.pushBridge
    local unlockIsland = ctx.API.unlockIsland
    local travelToIsland = ctx.API.travelToIsland
    local goToEgg = ctx.API.goToEgg
    local cleanTrashPets = ctx.API.cleanTrashPets
    local getBuyableSkillUpgrades = ctx.API.getBuyableSkillUpgrades
    local purchaseSkillNode = ctx.API.purchaseSkillNode
    local collectIslandShinyStars = ctx.API.collectIslandShinyStars
    local manageSmartBoosts = ctx.API.manageSmartBoosts
    local autoCraftEvolutionPets = ctx.API.autoCraftEvolutionPets

    local T = ctx.KaitunTelemetry

    local function buildTelemetryAndPriorities(snap, plan, isShadowEnabled)
        local coins = snap.coins or 0
        local curWorld = snap.curWorld or "Main"
        local curIsland = snap.curIsland or "Spawn"
        local coinVelocity = plan.CoinVelocity or 1
        local nextIsl = snap.nextIsl
        local bestUpgradeEgg = plan.BestEgg
        local targetMilestoneRebirth = plan.TargetMilestoneRebirth
        local targetMacroRebirth = plan.TargetMacroRebirth
        local bestAffordableRebirth = plan.BestRebirth
        local activeGoldenChance = plan.ActiveGoldenChance or 0
        local isTeamSaturated = plan.IsTeamSaturated
        local isEndgameWorld = plan.IsEndgameWorld
        local timeToNextIsland = plan.TimeToNextIsland or math.huge
        local targetIslandCoins = plan.TargetIslandCoins or coins
        local isNearIslandSprint = plan.NearIslandSprint

        local evLabel = (activeGoldenChance > 0.0005)
            and string.format("Weighted Golden EV (%.1f%%)", activeGoldenChance * 100)
            or "Normal EV"

        if nextIsl then
            local pct = math.clamp(math.floor((targetIslandCoins / math.max(nextIsl.price, 1)) * 100), 0, 100)
            local secGoalStr = ""
            if bestUpgradeEgg then
                secGoalStr = string.format(" | Secondary: %s Egg (%s)", bestUpgradeEgg.Name, formatCompact(bestUpgradeEgg.Price))
            elseif targetMilestoneRebirth then
                secGoalStr = string.format(" | Secondary: +%s Rebirth (Saves %ds)", formatCompact(targetMilestoneRebirth.ActualAmount), math.floor(targetMilestoneRebirth.NetDeltaSeconds))
            elseif targetMacroRebirth then
                secGoalStr = string.format(" | Macro: +%s Rebirth (Delays by %ds)", formatCompact(targetMacroRebirth.ActualAmount), math.abs(math.floor(targetMacroRebirth.NetDeltaSeconds)))
            end
            KaitunState.CurrentGoal = string.format("Primary: Unlock %s [%s / %s (%d%%)]%s", nextIsl.name, formatCompact(targetIslandCoins), formatCompact(nextIsl.price), pct, secGoalStr)
        elseif isEndgameWorld and bestUpgradeEgg then
            local rebPct = targetMacroRebirth and math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100) or 0
            local unlockNote = (targetMacroRebirth and targetMacroRebirth.Index == 9) and " [Unlocks +2M!]" or ""
            local rebStr = targetMacroRebirth and string.format(" | Rebirth +%s [%s / %s (%d%%)]%s", formatCompact(targetMacroRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), rebPct, unlockNote) or ""
            KaitunState.CurrentGoal = string.format("Dual-Drive: Hatching %s Egg%s", bestUpgradeEgg.Name, rebStr)
        elseif bestUpgradeEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestUpgradeEgg.Price, 1)) * 100), 0, 100)
            local secGoalStr = ""
            if targetMilestoneRebirth then
                secGoalStr = string.format(" | Secondary: +%s Rebirth (Saves %ds)", formatCompact(targetMilestoneRebirth.ActualAmount), math.floor(targetMilestoneRebirth.NetDeltaSeconds))
            elseif targetMacroRebirth then
                secGoalStr = string.format(" | Macro: +%s Rebirth (Delays by %ds)", formatCompact(targetMacroRebirth.ActualAmount), math.abs(math.floor(targetMacroRebirth.NetDeltaSeconds)))
            end
            KaitunState.CurrentGoal = string.format("Primary: Save for %s Egg [%s / %s (%d%%)]%s", bestUpgradeEgg.Name, formatCompact(coins), formatCompact(bestUpgradeEgg.Price), pct, secGoalStr)
        elseif targetMilestoneRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMilestoneRebirth.Price, 1)) * 100), 0, 100)
            KaitunState.CurrentGoal = string.format("Milestone Rebirth: +%s [%s / %s (%d%%)]", formatCompact(targetMilestoneRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMilestoneRebirth.Price), pct)
        elseif targetMacroRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
            local unlockNote = (targetMacroRebirth.Index == 9) and " (Unlocks Final Slot 10: +2M!)" or ""
            local goalPrefix = (isEndgameWorld or (isTeamSaturated and not nextIsl)) and "Endgame Rebirth" or "Target Rebirth"
            KaitunState.CurrentGoal = string.format("%s: +%s [%s / %s (%d%%)]%s", goalPrefix, formatCompact(targetMacroRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct, unlockNote)
        else
            KaitunState.CurrentGoal = "Endgame Reached (All Worlds, Islands & Max Tiers Unlocked!)"
        end

        local worldLabel = (curWorld == "TimeRift") and "World 2" or "World 1"
        KaitunState.AccountStage = string.format("[%s] %s: %s | %s Rebirths | %s Coins",
            plan.Stage, worldLabel, curIsland, formatCompact(snap.rebirthCount or 0), formatCompact(coins))

        local priorities = {}
        if plan.DecisionType == "WaitForBagClean" and bestUpgradeEgg then
            table.insert(priorities, string.format("1. [BAG FULL] Cleaning/Evolving inventory to hatch %s Egg", bestUpgradeEgg.Name))
            table.insert(priorities, "2. Holding egg hatch until at least 1 inventory slot opens")
        elseif plan.DecisionType == "PreRebirthSurplusHatch" and bestUpgradeEgg and bestAffordableRebirth then
            table.insert(priorities, string.format("1. [SURPLUS PROTECT] Hatch %s x%d BEFORE Rebirth (uses excess above %s)",
                bestUpgradeEgg.Name, plan.HatchCount, formatCompact(bestAffordableRebirth.Price)))
            table.insert(priorities, string.format("2. Rebirth +%s right after (preserves surplus coin value)",
                formatCompact(bestAffordableRebirth.ActualAmount)))
            table.insert(priorities, string.format("3. Re-farm at +%s/s", formatCompact(bestAffordableRebirth.NewVelocity)))
        elseif isNearIslandSprint and nextIsl then
            local pct = math.clamp(math.floor((targetIslandCoins / math.max(nextIsl.price, 1)) * 100), 0, 100)
            local etaStr = (timeToNextIsland < math.huge) and string.format("%ds", math.floor(timeToNextIsland)) or "Paused (0/s)"
            table.insert(priorities, string.format("1. [SAVE MODE] Sprint to %s [%s / %s (%d%%)] (ETA: %s)",
                nextIsl.name, formatCompact(targetIslandCoins), formatCompact(nextIsl.price), pct, etaStr))
            table.insert(priorities, "2. Lock rebirths & egg spending to protect capital")
            if bestUpgradeEgg then
                table.insert(priorities, string.format("3. Modernize team with %s Egg on %s once unlocked", bestUpgradeEgg.Name, nextIsl.name))
            else
                table.insert(priorities, string.format("3. Farm on %s for higher zone multiplier", nextIsl.name))
            end
        elseif bestAffordableRebirth and (bestAffordableRebirth.NetDeltaSeconds > 0 or (isEndgameWorld and bestAffordableRebirth.Index >= plan.HighestUnlockedIdx)) then
            local savesStr = isEndgameWorld and "Endgame Step" or string.format("Saves %ds", math.floor(bestAffordableRebirth.NetDeltaSeconds))
            table.insert(priorities, string.format("1. Rebirth +%s tier (+%.1f%% vel, Rec: %ds, %s, Score: %.1f)",
                formatCompact(bestAffordableRebirth.ActualAmount), bestAffordableRebirth.MultGainPct, math.floor(bestAffordableRebirth.GrossRecoveryTime), savesStr, plan.BestRebirthScore or 0))
            table.insert(priorities, string.format("2. Re-farm coins at +%s/s with accelerated multiplier", formatCompact(bestAffordableRebirth.NewVelocity)))
            if bestUpgradeEgg then
                table.insert(priorities, string.format("3. Next Pet Target: %s Egg (%s)", bestUpgradeEgg.Name, formatCompact(bestUpgradeEgg.Price)))
            elseif nextIsl then
                table.insert(priorities, string.format("3. Push toward %s (%s)", nextIsl.name, formatCompact(nextIsl.price)))
            end
        elseif bestUpgradeEgg and coins >= bestUpgradeEgg.Price and plan.HatchCount > 0 then
            table.insert(priorities, string.format("1. Hatch %s Egg x%d (Weakest: %s Pwr -> Exact EV Gain: +%s [%s])",
                bestUpgradeEgg.Name, plan.HatchCount, formatCompact(snap.weakestPetPower or 0), formatCompact(plan.HatchGain or 0), evLabel))
            table.insert(priorities, "2. Auto-evolve craftable pets (skips CraftLocked Medieval/Royal)")
            if targetMacroRebirth then
                table.insert(priorities, string.format("3. Macro Target: +%s Rebirth (%s)", formatCompact(targetMacroRebirth.ActualAmount), formatCompact(targetMacroRebirth.Price)))
            end
        elseif bestUpgradeEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestUpgradeEgg.Price, 1)) * 100), 0, 100)
            local timeToEgg = (coinVelocity > 0) and (math.max(0, bestUpgradeEgg.Price - coins) / coinVelocity) or math.huge
            local etaStr = (timeToEgg < math.huge) and string.format("%ds", math.floor(timeToEgg)) or "Inf"
            local gainStr = formatCompact(bestUpgradeEgg.ExpectedEffectiveTeamGain or 0)
            table.insert(priorities, string.format("1. Save for %s Egg [%s / %s (%d%%)] (ETA: %s, Gain: +%s [%s])",
                bestUpgradeEgg.Name, formatCompact(coins), formatCompact(bestUpgradeEgg.Price), pct, etaStr, gainStr, evLabel))
            table.insert(priorities, "2. Rebirths locked to protect capital toward higher EV egg")
            if targetMacroRebirth then
                table.insert(priorities, string.format("3. Long-term Macro: +%s Rebirth (%s)",
                    formatCompact(targetMacroRebirth.ActualAmount), formatCompact(targetMacroRebirth.Price)))
            end
        elseif targetMilestoneRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMilestoneRebirth.Price, 1)) * 100), 0, 100)
            table.insert(priorities, string.format("1. Milestone Rebirth +%s [%s / %s (%d%%)] (Saves %ds)",
                formatCompact(targetMilestoneRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMilestoneRebirth.Price), pct, math.floor(targetMilestoneRebirth.NetDeltaSeconds)))
        elseif targetMacroRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
            table.insert(priorities, string.format("1. Long-term Macro Rebirth +%s [%s / %s (%d%%)]",
                formatCompact(targetMacroRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct))
        else
            table.insert(priorities, string.format("1. Farm coins on %s [Velocity: +%s/s]", curIsland, formatCompact(coinVelocity)))
        end

        KaitunState.DynamicPriority = table.concat(priorities, "\n")

        if isShadowEnabled and T.runShadowComparison then
            T.runShadowComparison(snap)
        end
    end

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

        local snap = T.buildLiveSnapshot and T.buildLiveSnapshot()
        if not snap then return end
        local data = snap.data
        local now = os.clock()

        local curWorld = snap.curWorld
        local curIsland = snap.curIsland
        local coins = snap.coins
        local bestUnlockedIsl = snap.bestUnlockedIsl
        local nextIsl = snap.nextIsl
        local freeSlots = snap.freeSlots

        if KaitunState.LastEvaluatedIsland ~= curIsland then
            local prevIsl = KaitunState.LastEvaluatedIsland
            KaitunState.LastEvaluatedIsland = curIsland
            if OptimizationState and OptimizationState.CpuSaver and ctx.API.updateRegionalCulling then
                task.defer(function() pcall(ctx.API.updateRegionalCulling) end)
            end
            if prevIsl ~= nil then
                safeNotify({
                    title = "New Island Checkpoint!",
                    content = string.format("Arrived at %s! Recalibrating entire progression strategy...", curIsland),
                    duration = 5
                })
            end
        end

        local coinVelocity, measuredVelocity, calibratedPredicted, velSource = T.updateVelocityMeasurement(
            coins, curWorld, curIsland, snap.rebirthCount, snap.effectiveTeamPower, snap.predictedVelocity, snap.boostFingerprint
        )
        snap.coinVelocityOverride = coinVelocity
        snap.measuredVelocity = measuredVelocity

        KaitunState.PredictedVelocity = calibratedPredicted
        KaitunState.MeasuredVelocity = measuredVelocity
        KaitunState.CoinVelocity = coinVelocity
        KaitunState.VelocitySource = velSource
        KaitunState.MeasuredVelocityStr = T.VelocityTracker.Status
        if measuredVelocity then
            KaitunState.VelocityDiffPct = (math.abs(calibratedPredicted - measuredVelocity) / math.max(1, measuredVelocity)) * 100
        else
            KaitunState.VelocityDiffPct = nil
        end

        local plan = T.evaluateKaitunStrategy(snap, KaitunState.LockedDecision)
        if not plan then return end

        KaitunState.ProgressionStage = plan.Stage
        KaitunState.LockedDecision = plan.DecisionLock
        buildTelemetryAndPriorities(snap, plan, true)

        -- 2. Periodic Equip Best Pets
        if (now - KaitunState.LastBestEquip >= 15.0) then
            KaitunState.LastBestEquip = now
            equipBestPets()
        end

        -- 3. ROI-Ranked Gem Skill Tree Upgrades
        if KaitunState.AllowSkillTree and (now - KaitunState.LastSkillTime >= 2.0) then
            local buyable, readyCount = getBuyableSkillUpgrades()
            if readyCount > 0 then
                local rankedSkills = (T.rankSkillUpgrades and T.rankSkillUpgrades(buyable, snap.gems, data)) or buyable
                for _, item in ipairs(rankedSkills) do
                    local ok = purchaseSkillNode(item.nodeToUnlock)
                    if ok then
                        KaitunState.LastSkillTime = now
                        KaitunState.CurrentAction = string.format("Purchased %s (%d Gems)", item.title, item.price)
                        safeNotify({
                            title = "Kaitun: Skill Unlocked!",
                            content = string.format("%s (Lvl %d) unlocked for %d Gems!", item.title, (item.level or 0) + 1, item.price)
                        })
                        task.wait(0.3)
                        break
                    end
                end
            end
        end

        -- 4a. Auto Pet Evolution Machine (CraftLock & PetTeams Safe)
        if KaitunState.AllowAutoCraft and (now - KaitunState.LastCraftTime >= 8.0) then
            KaitunState.LastCraftTime = now
            local gCount, dCount = autoCraftEvolutionPets(bestUnlockedIsl)
            if gCount > 0 or dCount > 0 then
                KaitunState.CurrentAction = string.format("Evolved %d Golden & %d Diamond pets!", gCount, dCount)
                task.wait(0.3)
                local _, _, updatedFree = getPetStorageInfo()
                freeSlots = updatedFree
            end
        end

        -- 4b. Smart Pet Storage & Trash Cleaning (Power-Shield + Per-Tier/Species Safe)
        if KaitunState.AllowTrashCleaning and (freeSlots < 35 or (now - KaitunState.LastTrashCheckTime >= 25.0)) then
            KaitunState.LastTrashCheckTime = now
            local cleaned = cleanTrashPets()
            if cleaned > 0 then
                KaitunState.CurrentAction = string.format("Cleaned %d trash pets", cleaned)
                safeNotify({
                    title = "Inventory Cleaned",
                    content = string.format("Auto-cleaned %d obsolete pets safely!", cleaned)
                })
                task.wait(0.3)
                local _, _, updatedFree = getPetStorageInfo()
                freeSlots = updatedFree
            end
        end

        -- 5. Physical Shiny Star Collection
        if KaitunState.CollectShinyStars and (now - KaitunState.LastStarCheckTime >= 8.0) then
            KaitunState.LastStarCheckTime = now
            if collectIslandShinyStars() then
                KaitunState.CurrentAction = "Collected Shiny Star!"
                task.wait(0.3)
            end
        end

        -- 6. Smart Potions & Boosts Management (Golden Potion decoupled from Luck Potion)
        local isActivelyHatching = (KaitunState.AllowHatch and freeSlots > 0 and plan.BestEgg ~= nil and not plan.IsSavingForIsland)
        if KaitunState.AllowSmartBoosts and (now - KaitunState.LastBoostCheckTime >= 8.0) then
            KaitunState.LastBoostCheckTime = now
            manageSmartBoosts(isActivelyHatching, plan.IsSavingForIsland)
        end

        -- 7. In-Game Collectibles (Chests, Quests, Offline Rewards)
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
        if snap.bridgeStatus and not snap.bridgeStatus.lowered then
            if snap.bridgeStatus.ready then
                KaitunState.CurrentGoal = "Drawbridge Ready - Lowering Drawbridge!"
                KaitunState.CurrentAction = "Pushing Drawbridge Down..."
                if pushBridge(6) then
                    KaitunState.CurrentAction = "Drawbridge Lowered!"
                    safeNotify({ title = "Kaitun: Drawbridge Lowered!", content = "Path to Sky Island is now open!" })
                    task.wait(1.0)
                end
                return
            else
                KaitunState.CurrentGoal = string.format("Powering Drawbridge (%s / %s Power)", formatCompact(snap.bridgeStatus.power), formatCompact(snap.bridgeStatus.req))
                KaitunState.StrategyNote = "Tapping to charge drawbridge power..."
            end
        end

        ----------------------------------------------------------------------------
        -- PROGRESSION DECISION EXECUTION
        ----------------------------------------------------------------------------
        if plan.DecisionType == "TravelWorld2" then
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

        if plan.DecisionType == "UnlockIsland" and nextIsl then
            T.invalidateVelocityMeasurement("Coin spend: Unlock Island", coins)
            local curCurrencyLabel = nextIsl.isRift and "Rift Coins" or "Coins"
            KaitunState.CurrentAction = string.format("Unlocking %s for %s %s!", nextIsl.name, formatCompact(nextIsl.price), curCurrencyLabel)
            KaitunState.StrategyNote = string.format("Milestone Achieved! Unlocking %s permanently for higher multiplier & egg tier!", nextIsl.name)
            if unlockIsland(nextIsl) then
                KaitunState.CurrentAction = string.format("Unlocked %s! Teleporting...", nextIsl.name)
                safeNotify({ title = "Kaitun: Island Unlocked!", content = string.format("Advanced to %s!", nextIsl.name) })
                task.wait(0.5)
                travelToIsland(nextIsl.name)
                task.wait(1.5)
                return
            end
        end

        if plan.DecisionType == "SaveIslandSprint" and nextIsl then
            local targetCoins = plan.TargetIslandCoins or coins
            local etaSec = (plan.TimeToNextIsland < math.huge) and math.floor(plan.TimeToNextIsland) or 0
            KaitunState.StrategyNote = string.format("Save Mode: Sprinting to %s [%s / %s (ETA: %ds)]. Rebirths & eggs locked.",
                nextIsl.name, formatCompact(targetCoins), formatCompact(nextIsl.price), etaSec)
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

        if (plan.DecisionType == "PreRebirthSurplusHatch" or plan.DecisionType == "HatchEgg")
            and KaitunState.AllowHatch and freeSlots > 0 and plan.BestEgg and plan.HatchCount > 0 then
            local egg = plan.BestEgg
            if now - KaitunState.LastHatchTime >= getAutoHatchDelay() then
                local atStand = goToEgg(egg.Name)
                if atStand then
                    local evLabel = (plan.ActiveGoldenChance > 0.0005)
                        and string.format("Golden %.1f%% EV", plan.ActiveGoldenChance * 100)
                        or "Normal EV"
                    local prefix = (plan.DecisionType == "PreRebirthSurplusHatch") and "[SURPLUS BEFORE REBIRTH] " or ""
                    KaitunState.CurrentAction = string.format("%sHatching %s Egg x%d (%s Coins)", prefix, egg.Name, plan.HatchCount, formatCompact(egg.Price * plan.HatchCount))
                    KaitunState.StrategyNote = string.format("%sHatching %s Egg x%d (Weakest: %s -> Exact Gain: +%s [%s])",
                        prefix, egg.Name, plan.HatchCount, formatCompact(snap.weakestPetPower or 0), formatCompact(plan.HatchGain or 0), evLabel)
                    KaitunState.LastHatchTime = now
                    T.invalidateVelocityMeasurement("Coin spend: Egg Hatch", coins)
                    Svc.EggService.RE.EggHatchRequested:FireServer({
                        Egg = egg.Name,
                        Count = plan.HatchCount,
                        Auto = false,
                        Roam = false,
                    })
                    return
                else
                    KaitunState.CurrentAction = string.format("Approaching %s Egg stand...", egg.Name)
                    return
                end
            end
        end

        if (plan.DecisionType == "Rebirth" or (plan.BestRebirth and plan.DecisionType == "PreRebirthSurplusHatch"))
            and KaitunState.AllowRebirth and plan.BestRebirth and (now - KaitunState.LastRebirthTime >= 2.0) and not plan.IsSavingForIsland then
            local reb = plan.BestRebirth
            local canStillRebirth = (coins >= reb.Price)
            if canStillRebirth and plan.DecisionType == "Rebirth"
                and Svc.RebirthService and Svc.RebirthService:FindFirstChild("RE") and Svc.RebirthService.RE:FindFirstChild("RebirthRequested") then
                KaitunState.CurrentAction = string.format("Rebirthing! (+%s Rebirths | Score: %.1f)",
                    formatCompact(reb.ActualAmount), plan.BestRebirthScore or 0)
                KaitunState.StrategyNote = plan.IsEndgameWorld
                    and string.format("Endgame Rebirth (+%s for %s Coins): +%.1f%% Velocity!", formatCompact(reb.ActualAmount), formatCompact(reb.Price), reb.MultGainPct)
                    or string.format("Stage-Aware Rebirth (+%s for %s Coins): +%.1f%% Velocity, Gross Rec %ds, Saves %ds!",
                        formatCompact(reb.ActualAmount), formatCompact(reb.Price), reb.MultGainPct, math.floor(reb.GrossRecoveryTime), math.floor(reb.NetDeltaSeconds))

                T.invalidateVelocityMeasurement("Coin spend: Rebirth", coins)
                Svc.RebirthService.RE.RebirthRequested:FireServer({ Index = reb.Index })
                KaitunState.LastRebirthTime = now
                safeNotify({
                    title = plan.IsEndgameWorld and "Endgame Rebirth Achieved!" or "Stage-Aware Rebirth Achieved!",
                    content = string.format("+%s Rebirths! (Score: %.1f) Velocity +%.1f%%!",
                        formatCompact(reb.ActualAmount), plan.BestRebirthScore or 0, reb.MultGainPct),
                    duration = 4
                })
                task.wait(0.35)
                if curIsland ~= "Spawn" then
                    travelToIsland(curIsland)
                end
                return
            end
        end

        -- OPTIMAL FARMING & SAVING FALLBACK
        if curIsland ~= bestUnlockedIsl and bestUnlockedIsl ~= "Spawn" and bestUnlockedIsl ~= "World 2 Spawn" and not nextIsl then
            travelToIsland(bestUnlockedIsl)
        end

        KaitunState.CurrentAction = string.format("Fast Tapping on %s [Velocity: +%s/s]", curIsland, formatCompact(coinVelocity))
        local bestEgg = plan.BestEgg
        local targetMacroRebirth = plan.TargetMacroRebirth
        if plan.IsEndgameWorld and bestEgg then
            local rebPct = targetMacroRebirth and math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100) or 0
            KaitunState.StrategyNote = string.format("Dual-Drive: Hunting %s Egg (%s) to replace %s Pwr pet & Accumulating for +%s Rebirth [%s / %s (%d%%)]",
                bestEgg.Name, formatCompact(bestEgg.Price), formatCompact(snap.weakestPetPower or 0),
                targetMacroRebirth and formatCompact(targetMacroRebirth.ActualAmount) or "400K",
                formatCompact(coins), targetMacroRebirth and formatCompact(targetMacroRebirth.Price) or "158QN", rebPct)
        elseif bestEgg then
            local pct = math.clamp(math.floor((coins / math.max(bestEgg.Price, 1)) * 100), 0, 100)
            local timeToEgg = (coinVelocity > 0) and (math.max(0, bestEgg.Price - coins) / coinVelocity) or math.huge
            local etaStr = (timeToEgg < math.huge) and string.format("%ds", math.floor(timeToEgg)) or "Inf"
            local evLabel = (plan.ActiveGoldenChance > 0.0005)
                and string.format("Weighted Golden EV (%.1f%%)", plan.ActiveGoldenChance * 100)
                or "Normal EV"
            KaitunState.StrategyNote = string.format("Saving for %s Egg [%s / %s (%d%%)] (ETA: %s, Exact Gain: +%s [%s]).",
                bestEgg.Name, formatCompact(coins), formatCompact(bestEgg.Price), pct, etaStr, formatCompact(bestEgg.ExpectedEffectiveTeamGain or 0), evLabel)
        elseif targetMacroRebirth then
            local pct = math.clamp(math.floor((coins / math.max(targetMacroRebirth.Price, 1)) * 100), 0, 100)
            KaitunState.StrategyNote = string.format("Saturated (%s Pwr). Accumulating for +%s Rebirth [%s / %s (%d%%)]",
                formatCompact(snap.effectiveTeamPower or 0), formatCompact(targetMacroRebirth.ActualAmount), formatCompact(coins), formatCompact(targetMacroRebirth.Price), pct)
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
