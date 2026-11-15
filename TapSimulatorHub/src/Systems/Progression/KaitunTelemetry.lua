-- src/Systems/Progression/KaitunTelemetry.lua
-- Kaitun Displays, Velocity Tracker, Egg Combinatorics Evaluator & Stage-Aware Progression Scoring

local KaitunTelemetry = {}

function KaitunTelemetry.Init(ctx)
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local KaitunState = ctx.States.Kaitun
    local UI = ctx.UI
    local W2_ISLAND_BOUNDS = ctx.W2_ISLAND_BOUNDS

    local getPlayerData = ctx.API.getPlayerData
    local getCoins = ctx.API.getCoins
    local getRebirthCount = ctx.API.getRebirthCount
    local formatCompact = ctx.Utils.formatCompact
    local requireSafe = ctx.Utils.requireSafe

    local lastGoalStr, lastActionStr, lastStageStr, lastStrategyStr, lastPriorityStr, lastVelocityStr = nil, nil, nil, nil, nil, nil

    local function updateKaitunDisplays()
        pcall(function()
            if UI.KaitunGoalText and UI.KaitunGoalText.Set and lastGoalStr ~= KaitunState.CurrentGoal then
                lastGoalStr = KaitunState.CurrentGoal
                UI.KaitunGoalText:Set(lastGoalStr)
            end
            if UI.KaitunActionText and UI.KaitunActionText.Set and lastActionStr ~= KaitunState.CurrentAction then
                lastActionStr = KaitunState.CurrentAction
                UI.KaitunActionText:Set(lastActionStr)
            end
            if UI.KaitunStageText and UI.KaitunStageText.Set and lastStageStr ~= KaitunState.AccountStage then
                lastStageStr = KaitunState.AccountStage
                UI.KaitunStageText:Set(lastStageStr)
            end
            if UI.KaitunStrategyText and UI.KaitunStrategyText.Set and lastStrategyStr ~= KaitunState.StrategyNote then
                lastStrategyStr = KaitunState.StrategyNote
                UI.KaitunStrategyText:Set(lastStrategyStr)
            end
            local curPri = KaitunState.DynamicPriority or "1. Evaluating..."
            if UI.KaitunPriorityText and UI.KaitunPriorityText.Set and lastPriorityStr ~= curPri then
                lastPriorityStr = curPri
                UI.KaitunPriorityText:Set(lastPriorityStr)
            end
            if UI.KaitunVelocityText and UI.KaitunVelocityText.Set then
                local content = string.format("Predicted Coin Velocity: +%s/s\nMeasured Coin Velocity: %s\nActive Decision Rate: +%s/s [Source: %s]",
                    formatCompact(KaitunState.PredictedVelocity or 0),
                    tostring(KaitunState.MeasuredVelocityStr or "Measuring..."),
                    formatCompact(KaitunState.CoinVelocity or 0),
                    tostring(KaitunState.VelocitySource or "Predicted"))
                if lastVelocityStr ~= content then
                    lastVelocityStr = content
                    UI.KaitunVelocityText:Set(content)
                end
            end
        end)
    end

    local function getFrontierRebirthInfo()
        local data = getPlayerData()
        if not (data and Mod.WorldConfig and Mod.RebirthButtonConfig and Mod.RebirthConfig) then
            return nil
        end

        local currentWorld = Mod.WorldConfig.Get and Mod.WorldConfig.Get(data)
        local worldKey = currentWorld and currentWorld.Key or "Main"
        local rebirthButtons = Mod.WorldConfig.GetRebirthButtons and Mod.WorldConfig.GetRebirthButtons(data, currentWorld) or 1
        local unlocked = Mod.RebirthButtonConfig.GetUnlockedCount and Mod.RebirthButtonConfig.GetUnlockedCount(rebirthButtons, worldKey) or 1
        local optionCount = Mod.RebirthButtonConfig.GetOptionCount and Mod.RebirthButtonConfig.GetOptionCount(unlocked, worldKey) or 1
        local maxOptions = Mod.RebirthButtonConfig.GetMaximumOptions and Mod.RebirthButtonConfig.GetMaximumOptions(worldKey) or 18

        local highestUnlockedIdx = optionCount
        pcall(function()
            local options = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("RightHud")
                and LocalPlayer.PlayerGui.RightHud:FindFirstChild("Main")
                and LocalPlayer.PlayerGui.RightHud.Main:FindFirstChild("RightUI")
                and LocalPlayer.PlayerGui.RightHud.Main.RightUI:FindFirstChild("Rebirths")
                and LocalPlayer.PlayerGui.RightHud.Main.RightUI.Rebirths:FindFirstChild("List")
                and LocalPlayer.PlayerGui.RightHud.Main.RightUI.Rebirths.List:FindFirstChild("Options")
            if options then
                for _, ch in ipairs(options:GetChildren()) do
                    local n = tonumber(ch.Name)
                    if n and ch:IsA("GuiObject") then
                        local locked = ch:FindFirstChild("LockedFrame", true)
                        local isUnlocked = not locked or not locked.Visible
                        if isUnlocked and n > highestUnlockedIdx then
                            highestUnlockedIdx = n
                        end
                    end
                end
            end
        end)

        highestUnlockedIdx = math.min(highestUnlockedIdx, maxOptions)
        local rebirthCount = getRebirthCount()
        local coins = getCoins()
        local worldArg = (currentWorld ~= Mod.WorldConfig.Main and worldKey or nil)

        local highestAffordableIdx = 0
        for i = 1, highestUnlockedIdx do
            local a = Mod.RebirthConfig.GetAmountFromIndex(i, worldArg)
            local p = Mod.RebirthConfig.GetPrice(a, rebirthCount, nil, worldArg)
            if coins >= p and p > 0 then
                highestAffordableIdx = i
            end
        end

        local targetIndex = highestAffordableIdx > 0 and highestAffordableIdx or 1
        local targetAmt = Mod.RebirthConfig.GetAmountFromIndex(targetIndex, worldArg)
        local targetPrice = Mod.RebirthConfig.GetPrice(targetAmt, rebirthCount, nil, worldArg)

        return {
            index = targetIndex,
            amount = targetAmt,
            price = targetPrice,
            highestAffordable = highestAffordableIdx,
            unlockedCount = unlocked,
            highestUnlockedIdx = highestUnlockedIdx,
            maxOptions = maxOptions
        }
    end

    local function determineProgressionStage(curWorld, bestUnlockedIsl, rebirthCount, _rebirthMulti, totalTeamPower, nextIsl, bridgeStatus)
        if bridgeStatus and not bridgeStatus.lowered then
            return "Early Game"
        end
        if curWorld == "Main" and (bestUnlockedIsl == "Spawn" or bestUnlockedIsl == "Sky Island" or bestUnlockedIsl == "Autumn") then
            if rebirthCount < CONFIG.StageThresholds.EarlyRebirthLimit and totalTeamPower < CONFIG.StageThresholds.EarlyPowerLimit then
                return "Early Game"
            end
        end

        if not nextIsl then
            return "Endgame"
        end
        if curWorld == "TimeRift" and (bestUnlockedIsl == "Medieval Island" or bestUnlockedIsl == "Royal" or not nextIsl) then
            return "Endgame"
        end

        if curWorld == "TimeRift" then
            return "Late Game"
        end
        if curWorld == "Main" and (bestUnlockedIsl == "Volcano" or bestUnlockedIsl == "Heaven" or bestUnlockedIsl == "Shadow Realm") then
            return "Late Game"
        end
        if totalTeamPower >= CONFIG.StageThresholds.MidPowerLimit or rebirthCount >= CONFIG.StageThresholds.EndgamePowerLimit then
            return "Late Game"
        end

        return "Mid Game"
    end

    local function getBoostFingerprint(data)
        if not (data and data.ActiveBoosts and type(data.ActiveBoosts) == "table") then
            return "none"
        end
        local parts = {}
        for k, v in pairs(data.ActiveBoosts) do
            if type(v) == "table" then
                table.insert(parts, string.format("%s:%s:%s", tostring(k), tostring(v.Type or v.Name or ""), tostring(v.Multi or v.Multiplier or "")))
            else
                table.insert(parts, string.format("%s:%s", tostring(k), tostring(v)))
            end
        end
        table.sort(parts)
        return #parts > 0 and table.concat(parts, "|") or "none"
    end

    local function getPhysicalCurrentIsland()
        local data = getPlayerData()
        local curWorld = data and data.Progression and data.Progression.World or "Main"
        local progIsland = data and data.Progression and data.Progression.Island

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return progIsland or "Spawn" end
        local pos = hrp.Position

        if curWorld == "TimeRift" then
            for _, b in ipairs(W2_ISLAND_BOUNDS) do
                if (pos - b.center).Magnitude <= b.radius then
                    return b.name
                end
            end
            return "World 2 Spawn"
        end

        if pos.Y < -400 then
            return "Spawn"
        end

        if Mod.CachedIslandRegions and Mod.CachedIslandRegions.Resolve then
            local ok, resolved = pcall(Mod.CachedIslandRegions.Resolve, pos)
            if ok and resolved and resolved ~= "Spawn" then return resolved end
        end

        return progIsland or "Spawn"
    end

    local VelocityTracker = {
        SampleStartTick = 0,
        SampleStartCoins = 0,
        LastTickCoins = 0,
        WindowDuration = 12.0,
        LastMeasuredRate = nil,
        LastMeasuredTick = 0,
        LastKnownRebirths = nil,
        LastKnownIsland = nil,
        LastKnownWorld = nil,
        LastKnownTeamPower = 0,
        LastBoostFingerprint = "",
        PredictedRate = 0,
        Difference = 0,
        Status = "Calibrating (12s left)...",
        ActiveSource = "Predicted"
    }

    local function invalidateVelocityMeasurement(_reason, currentCoins)
        local now = os.clock()
        VelocityTracker.LastMeasuredRate = nil
        VelocityTracker.SampleStartTick = now
        VelocityTracker.SampleStartCoins = currentCoins or (getCoins and getCoins()) or 0
        VelocityTracker.LastTickCoins = VelocityTracker.SampleStartCoins
        VelocityTracker.Status = string.format("Measuring (%ds left)...", math.floor(VelocityTracker.WindowDuration))
        VelocityTracker.ActiveSource = "Predicted"
    end

    local function updateVelocityMeasurement(currentCoins, curWorld, curIsland, rebirthCount, teamPower, predictedRate, boostFingerprint)
        local now = os.clock()
        VelocityTracker.PredictedRate = predictedRate

        if VelocityTracker.LastKnownWorld ~= nil and VelocityTracker.LastKnownWorld ~= curWorld then
            invalidateVelocityMeasurement("World changed", currentCoins)
        elseif VelocityTracker.LastKnownRebirths ~= nil and VelocityTracker.LastKnownRebirths ~= rebirthCount then
            invalidateVelocityMeasurement("Rebirth occurred", currentCoins)
        elseif VelocityTracker.LastKnownIsland ~= nil and VelocityTracker.LastKnownIsland ~= curIsland then
            invalidateVelocityMeasurement("Island changed", currentCoins)
        elseif VelocityTracker.LastKnownTeamPower ~= nil and VelocityTracker.LastKnownTeamPower > 0 and math.abs(VelocityTracker.LastKnownTeamPower - teamPower) > math.max(1000000, VelocityTracker.LastKnownTeamPower * 0.05) then
            invalidateVelocityMeasurement("Team power changed", currentCoins)
        elseif VelocityTracker.LastBoostFingerprint ~= "" and VelocityTracker.LastBoostFingerprint ~= boostFingerprint then
            invalidateVelocityMeasurement("Boost fingerprint changed", currentCoins)
        elseif VelocityTracker.LastTickCoins > 0 and currentCoins < VelocityTracker.LastTickCoins then
            invalidateVelocityMeasurement("Coin spend detected", currentCoins)
        end

        VelocityTracker.LastKnownRebirths = rebirthCount
        VelocityTracker.LastKnownIsland = curIsland
        VelocityTracker.LastKnownWorld = curWorld
        VelocityTracker.LastKnownTeamPower = teamPower
        VelocityTracker.LastBoostFingerprint = boostFingerprint
        VelocityTracker.LastTickCoins = currentCoins

        if VelocityTracker.SampleStartTick == 0 then
            VelocityTracker.SampleStartTick = now
            VelocityTracker.SampleStartCoins = currentCoins
        end

        local elapsed = now - VelocityTracker.SampleStartTick
        if elapsed >= VelocityTracker.WindowDuration then
            local delta = currentCoins - VelocityTracker.SampleStartCoins
            if delta >= 0 and elapsed > 0 then
                local measuredRate = delta / elapsed
                VelocityTracker.LastMeasuredRate = measuredRate
                VelocityTracker.LastMeasuredTick = now
                VelocityTracker.Difference = math.abs(predictedRate - measuredRate)
            end
            VelocityTracker.SampleStartTick = now
            VelocityTracker.SampleStartCoins = currentCoins
        end

        local activeVelocity = predictedRate
        if VelocityTracker.LastMeasuredRate ~= nil then
            activeVelocity = VelocityTracker.LastMeasuredRate
            VelocityTracker.ActiveSource = "Measured"
            local ageSec = math.max(0, math.floor(now - VelocityTracker.LastMeasuredTick))
            local diffPct = (VelocityTracker.Difference / math.max(1, VelocityTracker.LastMeasuredRate)) * 100
            VelocityTracker.Status = string.format("+%s/s (Last completed, %ds ago | Diff: %.1f%%)",
                formatCompact(VelocityTracker.LastMeasuredRate), ageSec, diffPct)
        else
            activeVelocity = predictedRate
            VelocityTracker.ActiveSource = "Predicted"
            local rem = math.max(1, math.ceil(VelocityTracker.WindowDuration - (now - VelocityTracker.SampleStartTick)))
            VelocityTracker.Status = string.format("Measuring (%ds left)...", rem)
        end

        return activeVelocity, VelocityTracker.LastMeasuredRate, predictedRate, VelocityTracker.ActiveSource
    end

    local function evaluateEggTrueStats(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, _freeSlots, equipLimit, activeGoldenChance)
        local minPower = math.huge
        local maxPower = 0
        local evBasePower = 0
        local evGoldenPower = 0
        local evDiamondPower = 0
        local evNormalTeamGain = 0
        local evGoldenTeamGain = 0
        local evDiamondTeamGain = 0
        local hasProbabilities = false
        local missingProbability = 0
        local missingPetCount = 0
        local isVerified = true
        local petDetails = {}

        local totalChance = 0
        if eggInfo and eggInfo.Pets then
            for _, ch in pairs(eggInfo.Pets) do
                totalChance = totalChance + ch
            end
        end

        local PetPowerModule = Mod.PetPowerModule or requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end)
        local goldenMultiplier = (PetPowerModule and PetPowerModule.GetTierMultiplier and PetPowerModule.GetTierMultiplier("Golden")) or 3.0
        local diamondMultiplier = (PetPowerModule and PetPowerModule.GetTierMultiplier and PetPowerModule.GetTierMultiplier("Diamond")) or 7.0

        if totalChance > 0 and LaunchPetConfig then
            hasProbabilities = true
            for pName, ch in pairs(eggInfo.Pets) do
                local pCfg = LaunchPetConfig[pName]
                local pwr = pCfg and pCfg.Power or 0
                local weight = ch / totalChance

                if pwr > 0 then
                    minPower = math.min(minPower, pwr)
                    maxPower = math.max(maxPower, pwr)
                    local gPwr = pwr * goldenMultiplier
                    local dPwr = pwr * diamondMultiplier

                    evBasePower = evBasePower + (weight * pwr)
                    evGoldenPower = evGoldenPower + (weight * gPwr)
                    evDiamondPower = evDiamondPower + (weight * dPwr)

                    local slotBaseline = (#teamPowers < (equipLimit or 5)) and 0 or (weakestPetPower or 0)
                    evNormalTeamGain = evNormalTeamGain + (weight * math.max(0, pwr - slotBaseline))
                    evGoldenTeamGain = evGoldenTeamGain + (weight * math.max(0, gPwr - slotBaseline))
                    evDiamondTeamGain = evDiamondTeamGain + (weight * math.max(0, dPwr - slotBaseline))

                    table.insert(petDetails, {
                        name = pName,
                        chance = ch,
                        weight = weight,
                        power = pwr,
                        goldenPower = gPwr,
                        diamondPower = dPwr
                    })
                else
                    isVerified = false
                    missingPetCount = missingPetCount + 1
                    missingProbability = missingProbability + ch
                end
            end
        else
            isVerified = false
        end

        if minPower == math.huge then minPower = 0 end
        local missingProbabilityMass = (totalChance > 0) and ((missingProbability / totalChance) * 100) or 100
        local totalProbabilityCoverage = 100 - missingProbabilityMass

        local gChance = math.clamp(activeGoldenChance or 0, 0, 1)
        local evEffectivePetPower = (1 - gChance) * evBasePower + gChance * evGoldenPower
        local evEffectiveSingleTeamGain = (1 - gChance) * evNormalTeamGain + gChance * evGoldenTeamGain

        local price = eggInfo and eggInfo.Price or 0
        local efficiency = (price > 0) and (evEffectiveSingleTeamGain / price) or 0
        local goldenEfficiency = (price > 0) and (evGoldenTeamGain / price) or 0

        local evTripleNormalGain = 0
        local evTripleGoldenGain = 0
        local evTripleEffectiveGain = 0

        if isVerified and #petDetails > 0 then
            local maxEquip = equipLimit or 5
            local openEquipSlots = math.max(0, maxEquip - #teamPowers)
            local baseWeak = {}
            if openEquipSlots >= 3 then
                baseWeak = { 0, 0, 0 }
            elseif openEquipSlots == 2 then
                baseWeak = { 0, 0, teamPowers[1] or 0 }
            elseif openEquipSlots == 1 then
                baseWeak = { 0, teamPowers[1] or 0, teamPowers[2] or 0 }
            else
                baseWeak = { teamPowers[1] or 0, teamPowers[2] or 0, teamPowers[3] or 0 }
            end
            table.sort(baseWeak)

            local N = #petDetails
            for i = 1, N do
                local p1 = petDetails[i]
                for j = 1, N do
                    local p2 = petDetails[j]
                    local w12 = p1.weight * p2.weight
                    for k = 1, N do
                        local p3 = petDetails[k]
                        local jointW = w12 * p3.weight

                        local dNorm = { p1.power, p2.power, p3.power }
                        table.sort(dNorm)
                        local comboNorm = math.max(0, dNorm[1] - baseWeak[1]) + math.max(0, dNorm[2] - baseWeak[2]) + math.max(0, dNorm[3] - baseWeak[3])
                        evTripleNormalGain = evTripleNormalGain + (jointW * comboNorm)

                        local dGold = { p1.goldenPower, p2.goldenPower, p3.goldenPower }
                        table.sort(dGold)
                        local comboGold = math.max(0, dGold[1] - baseWeak[1]) + math.max(0, dGold[2] - baseWeak[2]) + math.max(0, dGold[3] - baseWeak[3])
                        evTripleGoldenGain = evTripleGoldenGain + (jointW * comboGold)

                        local eff1 = (1 - gChance) * p1.power + gChance * p1.goldenPower
                        local eff2 = (1 - gChance) * p2.power + gChance * p2.goldenPower
                        local eff3 = (1 - gChance) * p3.power + gChance * p3.goldenPower
                        local dEff = { eff1, eff2, eff3 }
                        table.sort(dEff)
                        local comboEff = math.max(0, dEff[1] - baseWeak[1]) + math.max(0, dEff[2] - baseWeak[2]) + math.max(0, dEff[3] - baseWeak[3])
                        evTripleEffectiveGain = evTripleEffectiveGain + (jointW * comboEff)
                    end
                end
            end
        end

        local triplePrice = price * 3
        local tripleEfficiency = (triplePrice > 0) and (evTripleEffectiveGain / triplePrice) or 0
        local tripleGoldenEfficiency = (triplePrice > 0) and (evTripleGoldenGain / triplePrice) or 0

        return {
            Name = eggName,
            Price = price,
            TriplePrice = triplePrice,
            Island = eggInfo and eggInfo.Island or "Spawn",
            World = eggInfo and eggInfo.World or "Main",
            MinPower = minPower,
            MaxPower = maxPower,
            GoldenMinPower = minPower * goldenMultiplier,
            GoldenMaxPower = maxPower * goldenMultiplier,
            DiamondMinPower = minPower * diamondMultiplier,
            DiamondMaxPower = maxPower * diamondMultiplier,
            ExpectedPetPower = evBasePower,
            ExpectedGoldenPower = evGoldenPower,
            ExpectedDiamondPower = evDiamondPower,
            ExpectedEffectivePetPower = evEffectivePetPower,
            ExpectedTeamGain = evNormalTeamGain,
            ExpectedGoldenTeamGain = evGoldenTeamGain,
            ExpectedDiamondTeamGain = evDiamondTeamGain,
            ExpectedEffectiveTeamGain = evEffectiveSingleTeamGain,
            ExpectedTripleTeamGain = evTripleNormalGain,
            ExpectedTripleGoldenGain = evTripleGoldenGain,
            ExpectedTripleEffectiveTeamGain = evTripleEffectiveGain,
            Efficiency = efficiency,
            GoldenEfficiency = goldenEfficiency,
            TripleEfficiency = tripleEfficiency,
            TripleGoldenEfficiency = tripleGoldenEfficiency,
            HasProbabilities = hasProbabilities,
            IsVerified = isVerified,
            MissingPetCount = missingPetCount,
            MissingProbability = missingProbability,
            MissingProbabilityMass = missingProbabilityMass,
            TotalProbabilityCoverage = totalProbabilityCoverage,
            ActiveGoldenChance = gChance,
            PetDetails = petDetails,
            IsUpgrade = (function()
                local minGainThreshold = math.max(0.01, (weakestPetPower or 0) * 0.05)
                if #teamPowers < (equipLimit or 5) then
                    return (evEffectivePetPower > 0)
                else
                    local isApexFrontierEgg = (eggName == "Royal" or eggName == "Medieval" or eggName == "Permafrost") or (evDiamondPower > (weakestPetPower or 0) * 1.5)
                    local hasWeakerEquipped = (weakestPetPower or 0) < evDiamondPower * 0.95
                    if isApexFrontierEgg and hasWeakerEquipped then
                        return true
                    end
                    return (evEffectiveSingleTeamGain >= minGainThreshold) or (evTripleEffectiveGain >= minGainThreshold * 1.5) or (evDiamondPower > (weakestPetPower or 0) * 1.3 and evGoldenPower > (weakestPetPower or 0) * 0.70)
                end
            end)()
        }
    end

    local function calculateProgressionScore(tier, coins, currentVelocity, rebirthMulti, milestoneTarget, stage)
        local rebirthCost = tier.Price or 0
        local a = tier.Amount or 1
        local multGainPct = (a / math.max(rebirthMulti, 1)) * 100
        local newRebirthMulti = rebirthMulti + a
        local newVelocity = currentVelocity * (newRebirthMulti / math.max(rebirthMulti, 1))

        local grossRecoveryTime = (newVelocity > 0) and (rebirthCost / newVelocity) or 0
        local deltaVelocity = newVelocity - currentVelocity
        local netBreakEvenTime = (deltaVelocity > 0) and (rebirthCost / deltaVelocity) or math.huge

        local M = math.max(milestoneTarget or 1, 1)
        local distA = math.max(0, M - coins)
        local etaA = (currentVelocity > 0) and (distA / currentVelocity) or 0

        local timeToAffordRebirth = 0
        if coins < rebirthCost then
            timeToAffordRebirth = (currentVelocity > 0) and ((rebirthCost - coins) / currentVelocity) or 0
        end

        local coinsAfter = 0
        local executionOverhead = CONFIG.Scoring.ExecutionOverhead
        local distB = M
        local sprintTimeB = (newVelocity > 0) and (distB / newVelocity) or 0
        local etaB = timeToAffordRebirth + executionOverhead + sprintTimeB

        local netDeltaSeconds = etaA - etaB

        local sprintTimeA2 = (currentVelocity > 0) and (M / currentVelocity) or 0
        local sprintTimeB2 = (newVelocity > 0) and (M / newVelocity) or 0
        local etaA2 = etaA + sprintTimeA2
        local etaB2 = etaB + sprintTimeB2
        local netDeltaCompounding = etaA2 - etaB2

        local isCompoundingAccelerator = (coins < M * CONFIG.Scoring.CompoundingDiscount)
            and (netDeltaCompounding > 0)
            and (grossRecoveryTime <= CONFIG.Scoring.MaxRebirthSaveSec)
            and (multGainPct >= 5)

        if isCompoundingAccelerator then
            netDeltaSeconds = math.max(netDeltaSeconds, math.min(10.0, netDeltaCompounding * 0.5))
        end

        local gainScore = (multGainPct / 10.0) * 15.0
        local accelScore = 0
        if etaA > 0 then
            accelScore = (netDeltaSeconds / math.max(etaA, 5.0)) * 30.0
        else
            accelScore = (netDeltaSeconds > 0) and 10.0 or -35.0
        end

        if netDeltaSeconds < 0 then
            accelScore = accelScore - 25.0
        end

        local recoveryPenalty = (grossRecoveryTime / 30.0) * 10.0
        local lostCoinRatio = math.clamp(coins / M, 0, 1)
        local lostCoinPenalty = (lostCoinRatio ^ 1.5) * 20.0

        local score = 0
        if stage == "Early Game" then
            score = (gainScore * 2.0) + (accelScore * 1.0) - (recoveryPenalty * 0.4) - (lostCoinPenalty * 0.3)
            if multGainPct < 5.0 then score = score - 10.0 end
        elseif stage == "Mid Game" then
            score = (gainScore * 1.2) + (accelScore * 1.5) - (recoveryPenalty * 1.0) - (lostCoinPenalty * 1.0)
            if multGainPct < 10.0 then score = score - 15.0 end
            if grossRecoveryTime > 60 then score = score - 20.0 end
        elseif stage == "Late Game" then
            score = (gainScore * 1.0) + (accelScore * 2.0) - (recoveryPenalty * 1.3) - (lostCoinPenalty * 1.8)
            if multGainPct < 12.0 then score = score - 25.0 end
            if grossRecoveryTime > 90 then score = score - 30.0 end
        else
            score = (gainScore * 2.5) + (accelScore * 2.5) - (recoveryPenalty * 0.8) - (lostCoinPenalty * 2.5)
            if multGainPct < 15.0 then score = score - 30.0 end
            if grossRecoveryTime > 120 then score = score - 40.0 end
        end

        return score, netDeltaSeconds, grossRecoveryTime, netBreakEvenTime, newVelocity, etaA, etaB, coinsAfter, timeToAffordRebirth
    end

    ctx.API.updateKaitunDisplays = updateKaitunDisplays
    ctx.API.getFrontierRebirthInfo = getFrontierRebirthInfo
    ctx.API.determineProgressionStage = determineProgressionStage
    ctx.API.getBoostFingerprint = getBoostFingerprint
    ctx.API.getPhysicalCurrentIsland = getPhysicalCurrentIsland
    ctx.API.invalidateVelocityMeasurement = invalidateVelocityMeasurement
    ctx.API.updateVelocityMeasurement = updateVelocityMeasurement
    ctx.API.evaluateEggTrueStats = evaluateEggTrueStats
    ctx.API.calculateProgressionScore = calculateProgressionScore

    KaitunTelemetry.VelocityTracker = VelocityTracker
    KaitunTelemetry.updateKaitunDisplays = updateKaitunDisplays
    KaitunTelemetry.getFrontierRebirthInfo = getFrontierRebirthInfo
    KaitunTelemetry.determineProgressionStage = determineProgressionStage
    KaitunTelemetry.getBoostFingerprint = getBoostFingerprint
    KaitunTelemetry.getPhysicalCurrentIsland = getPhysicalCurrentIsland
    KaitunTelemetry.invalidateVelocityMeasurement = invalidateVelocityMeasurement
    KaitunTelemetry.updateVelocityMeasurement = updateVelocityMeasurement
    KaitunTelemetry.evaluateEggTrueStats = evaluateEggTrueStats
    KaitunTelemetry.calculateProgressionScore = calculateProgressionScore
    ctx.KaitunTelemetry = KaitunTelemetry
    return KaitunTelemetry
end

return KaitunTelemetry
