-- src/Systems/Progression/KaitunTelemetry.lua
-- Kaitun Displays, Calibrated Velocity Tracker, Exact Binomial Egg Combinatorics,
-- Stage-Aware Progression Scoring, & Read-Only Shadow Mode Benchmark Engine

local KaitunTelemetry = {}

--------------------------------------------------------------------------------
-- PURE MATHEMATICAL HELPERS (Zero Roblox Remote Side Effects)
--------------------------------------------------------------------------------

local function computeBinomialSurvArray(K, p, maxJ)
    local m = math.min(K, maxJ)
    local surv = {}
    if p <= 0 then
        for j = 1, m do surv[j] = 0 end
        return surv
    end
    if p >= 1 then
        for j = 1, m do surv[j] = 1 end
        return surv
    end

    local q = 1 - p
    local pmf = {}
    local comb = 1
    for r = 0, K do
        if r > 0 then
            comb = comb * (K - r + 1) / r
        end
        pmf[r] = comb * (p ^ r) * (q ^ (K - r))
    end

    local running = 0
    for r = K, 1, -1 do
        running = math.min(1, running + (pmf[r] or 0))
        if r <= m then
            surv[r] = running
        end
    end
    for j = 1, m do
        if surv[j] == nil then surv[j] = 0 end
    end
    return surv
end

local function computeExactMultiHatchGain(outcomes, baselines, hatchCount)
    local K = math.max(1, math.floor(tonumber(hatchCount) or 1))
    local E = #baselines
    if E <= 0 or K <= 0 or not outcomes or #outcomes == 0 then
        return 0
    end

    -- Group duplicate powers into sorted distinct values x_1 < x_2 < ... < x_U
    local sorted = {}
    for _, o in ipairs(outcomes) do
        if o.prob and o.prob > 0 and o.power then
            table.insert(sorted, { power = o.power, prob = o.prob })
        end
    end
    if #sorted == 0 then return 0 end

    table.sort(sorted, function(a, b) return a.power < b.power end)

    local uniqPowers = {}
    local uniqProbs = {}
    for _, o in ipairs(sorted) do
        local n = #uniqPowers
        if n > 0 and math.abs(uniqPowers[n] - o.power) <= 1e-9 then
            uniqProbs[n] = uniqProbs[n] + o.prob
        else
            table.insert(uniqPowers, o.power)
            table.insert(uniqProbs, o.prob)
        end
    end

    local U = #uniqPowers
    local tailProbs = {}
    local cum = 0
    for i = U, 1, -1 do
        cum = math.min(1, cum + uniqProbs[i])
        tailProbs[i] = cum
    end

    local sortedBaselines = {}
    for _, b in ipairs(baselines) do
        table.insert(sortedBaselines, b or 0)
    end
    table.sort(sortedBaselines)

    local m = math.min(K, #sortedBaselines)
    local totalGain = 0
    for i = 1, U do
        local xi = uniqPowers[i]
        local xPrev = (i > 1) and uniqPowers[i - 1] or 0
        local surv = computeBinomialSurvArray(K, tailProbs[i], m)
        for j = 1, m do
            local bj = sortedBaselines[j]
            if xi > bj then
                local lower = math.max(xPrev, bj)
                if xi > lower then
                    totalGain = totalGain + (xi - lower) * surv[j]
                end
            end
        end
    end

    return totalGain
end

local function buildBaselines(teamPowers, equipLimit)
    local E = math.max(1, math.floor(tonumber(equipLimit) or 5))
    local tPowers = {}
    for _, pwr in ipairs(teamPowers or {}) do
        table.insert(tPowers, pwr or 0)
    end
    table.sort(tPowers)

    local baselines = {}
    local openSlots = math.max(0, E - #tPowers)
    for _ = 1, openSlots do
        table.insert(baselines, 0)
    end
    for i = 1, math.min(#tPowers, E - #baselines) do
        table.insert(baselines, tPowers[i])
    end
    table.sort(baselines)
    return baselines
end

local function evaluateEggTrueStatsPure(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, freeSlots, equipLimit, activeGoldenChance, opts)
    opts = opts or {}
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

    local goldMult = tonumber(opts.goldenMultiplier) or 3.0
    local diaMult = tonumber(opts.diamondMultiplier) or 7.0
    local shinyMult = tonumber(opts.shinyMultiplier) or 10.0

    local activePets = {}
    local totalChance = 0
    local rawTotalChance = 0
    if eggInfo and eggInfo.Pets then
        for pName, ch in pairs(eggInfo.Pets) do
            if type(ch) == "number" and ch > 0 then
                rawTotalChance = rawTotalChance + ch
                local vaulted = false
                if type(opts.isVaultedPetFn) == "function" then
                    vaulted = opts.isVaultedPetFn(pName) == true
                end
                if not vaulted then
                    activePets[pName] = ch
                    totalChance = totalChance + ch
                end
            end
        end
        if totalChance <= 0 and rawTotalChance > 0 then
            activePets = eggInfo.Pets
            totalChance = rawTotalChance
        end
    end

    local E = math.max(1, tonumber(equipLimit) or 5)
    local baselines = buildBaselines(teamPowers, E)
    local slotBaseline = baselines[1] or weakestPetPower or 0

    if totalChance > 0 and LaunchPetConfig then
        hasProbabilities = true
        for pName, ch in pairs(activePets) do
            local pCfg = LaunchPetConfig[pName]
            local pwr = pCfg and pCfg.Power or 0
            local weight = ch / totalChance

            if pwr > 0 then
                minPower = math.min(minPower, pwr)
                maxPower = math.max(maxPower, pwr)
                local gPwr = pwr * goldMult
                local dPwr = pwr * diaMult
                local sPwr = pwr * shinyMult

                evBasePower = evBasePower + (weight * pwr)
                evGoldenPower = evGoldenPower + (weight * gPwr)
                evDiamondPower = evDiamondPower + (weight * dPwr)

                evNormalTeamGain = evNormalTeamGain + (weight * math.max(0, pwr - slotBaseline))
                evGoldenTeamGain = evGoldenTeamGain + (weight * math.max(0, gPwr - slotBaseline))
                evDiamondTeamGain = evDiamondTeamGain + (weight * math.max(0, dPwr - slotBaseline))

                table.insert(petDetails, {
                    name = pName,
                    rarity = pCfg and pCfg.Rarity or "Common",
                    chance = ch,
                    weight = weight,
                    power = pwr,
                    goldenPower = gPwr,
                    diamondPower = dPwr,
                    shinyPower = sPwr,
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
    local dChance = math.clamp(opts.activeDiamondChance or 0, 0, 1)
    local sChance = math.clamp(opts.activeShinyChance or 0, 0, 1)
    local tierSum = gChance + dChance + sChance
    if tierSum > 1 then
        local scale = 1 / tierSum
        gChance = gChance * scale
        dChance = dChance * scale
        sChance = sChance * scale
    end
    local nChance = math.max(0, 1 - gChance - dChance - sChance)

    local evEffectivePetPower = (nChance * evBasePower) + (gChance * evGoldenPower) + (dChance * evDiamondPower) + (sChance * evBasePower * (shinyMult / 1.0))

    -- Exact order-statistic expected team power gains for K = 1, 3, 8
    local effOutcomes = {}
    local normOutcomes = {}
    local goldOutcomes = {}
    for _, pet in ipairs(petDetails) do
        table.insert(normOutcomes, { power = pet.power, prob = pet.weight })
        table.insert(goldOutcomes, { power = pet.goldenPower, prob = pet.weight })
        if nChance > 0 then table.insert(effOutcomes, { power = pet.power, prob = pet.weight * nChance }) end
        if gChance > 0 then table.insert(effOutcomes, { power = pet.goldenPower, prob = pet.weight * gChance }) end
        if dChance > 0 then table.insert(effOutcomes, { power = pet.diamondPower, prob = pet.weight * dChance }) end
        if sChance > 0 then table.insert(effOutcomes, { power = pet.shinyPower, prob = pet.weight * sChance }) end
    end

    local evEffectiveSingleTeamGain = (isVerified and #effOutcomes > 0)
        and computeExactMultiHatchGain(effOutcomes, baselines, 1)
        or ((nChance * evNormalTeamGain) + (gChance * evGoldenTeamGain) + (dChance * evDiamondTeamGain))

    local evTripleNormalGain = (isVerified and #normOutcomes > 0) and computeExactMultiHatchGain(normOutcomes, baselines, 3) or 0
    local evTripleGoldenGain = (isVerified and #goldOutcomes > 0) and computeExactMultiHatchGain(goldOutcomes, baselines, 3) or 0
    local evTripleEffectiveGain = (isVerified and #effOutcomes > 0) and computeExactMultiHatchGain(effOutcomes, baselines, 3) or (evEffectiveSingleTeamGain * 3)
    local evOctoEffectiveGain = (isVerified and #effOutcomes > 0) and computeExactMultiHatchGain(effOutcomes, baselines, 8) or (evEffectiveSingleTeamGain * 8)

    local isCraftLockedEgg = opts.isCraftLockedEgg == true
    local allowAutoCraft = (opts.allowAutoCraft ~= false)
    local bagCounts = opts.ownedBagCounts or {}
    local horizonHatches = math.max(1, tonumber(opts.horizonHatches) or 18)
    local craftAmortizedGain = 0
    local hasReachableUpgradePet = false
    local weakRef = weakestPetPower or 0

    for _, pet in ipairs(petDetails) do
        local bestDirectReachable = pet.power
        if gChance >= 0.01 then bestDirectReachable = math.max(bestDirectReachable, pet.goldenPower) end
        if dChance >= 0.005 then bestDirectReachable = math.max(bestDirectReachable, pet.diamondPower) end
        if pet.weight >= 0.01 and bestDirectReachable > weakRef * 1.05 then
            hasReachableUpgradePet = true
        end

        if allowAutoCraft and not isCraftLockedEgg and (freeSlots or 10) >= 2 and pet.weight > 0 then
            local bInfo = bagCounts[pet.name] or {}
            local ownedNormal = bInfo.Normal or 0
            local ownedGolden = bInfo.Golden or 0

            -- Normal -> Golden craft amortized value (requires 6 Normals total)
            if pet.goldenPower > slotBaseline then
                local needNorm = math.max(1, 6 - (ownedNormal % 6))
                local expInHorizon = pet.weight * nChance * horizonHatches
                local completionFactor = math.min(1, expInHorizon / needNorm)
                local gainPerCraft = math.max(0, pet.goldenPower - slotBaseline)
                local marginal = (pet.weight * nChance / 6) * gainPerCraft * completionFactor
                craftAmortizedGain = craftAmortizedGain + marginal
                if pet.weight >= 0.02 and (freeSlots or 10) >= 6 and pet.goldenPower > weakRef * 1.15 then
                    hasReachableUpgradePet = true
                end
            end
            -- Golden -> Diamond craft amortized value (requires 5 Goldens = 30 Normals)
            if pet.diamondPower > slotBaseline then
                local needGold = math.max(1, 5 - (ownedGolden % 5))
                local equivNormLeft = needGold * 6
                local expInHorizon = pet.weight * (nChance + gChance * 6) * horizonHatches
                local completionFactor = math.min(1, expInHorizon / equivNormLeft)
                local marginal = (pet.weight * nChance / 30) * math.max(0, pet.diamondPower - slotBaseline) * completionFactor
                craftAmortizedGain = craftAmortizedGain + marginal * 0.65
                if pet.weight >= 0.03 and (freeSlots or 10) >= 12 and pet.diamondPower > weakRef * 1.25 then
                    hasReachableUpgradePet = true
                end
            end
        end
    end

    local price = eggInfo and eggInfo.Price or 0
    local triplePrice = price * 3
    local octoPrice = price * 8
    local efficiency = (price > 0) and (evEffectiveSingleTeamGain / price) or 0
    local goldenEfficiency = (price > 0) and (evGoldenTeamGain / price) or 0
    local tripleEfficiency = (triplePrice > 0) and (evTripleEffectiveGain / triplePrice) or 0
    local octoEfficiency = (octoPrice > 0) and (evOctoEffectiveGain / octoPrice) or 0
    local tripleGoldenEfficiency = (triplePrice > 0) and (evTripleGoldenGain / triplePrice) or 0
    local evCraftAdjustedSingleGain = evEffectiveSingleTeamGain + craftAmortizedGain

    local minGainThreshold = math.max(0.01, weakRef * 0.03)
    local isUpgrade = false
    if #teamPowers < E then
        isUpgrade = (evEffectivePetPower > 0)
    else
        isUpgrade = (evEffectiveSingleTeamGain >= minGainThreshold)
            or (evTripleEffectiveGain >= minGainThreshold * 1.5)
            or (evCraftAdjustedSingleGain >= minGainThreshold)
            or hasReachableUpgradePet
    end

    return {
        Name = eggName,
        Price = price,
        TriplePrice = triplePrice,
        OctoPrice = octoPrice,
        Island = eggInfo and eggInfo.Island or "Spawn",
        World = eggInfo and eggInfo.World or "Main",
        MinPower = minPower,
        MaxPower = maxPower,
        GoldenMinPower = minPower * goldMult,
        GoldenMaxPower = maxPower * goldMult,
        DiamondMinPower = minPower * diaMult,
        DiamondMaxPower = maxPower * diaMult,
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
        ExpectedOctoEffectiveTeamGain = evOctoEffectiveGain,
        ExpectedCraftAdjustedTeamGain = evCraftAdjustedSingleGain,
        CraftAmortizedGain = craftAmortizedGain,
        Efficiency = efficiency,
        GoldenEfficiency = goldenEfficiency,
        TripleEfficiency = tripleEfficiency,
        OctoEfficiency = octoEfficiency,
        TripleGoldenEfficiency = tripleGoldenEfficiency,
        HasProbabilities = hasProbabilities,
        IsVerified = isVerified,
        IsCraftLockedEgg = isCraftLockedEgg,
        MissingPetCount = missingPetCount,
        MissingProbability = missingProbability,
        MissingProbabilityMass = missingProbabilityMass,
        TotalProbabilityCoverage = totalProbabilityCoverage,
        ActiveGoldenChance = gChance,
        ActiveDiamondChance = dChance,
        ActiveShinyChance = sChance,
        PetDetails = petDetails,
        IsUpgrade = isUpgrade,
    }
end

local function calculateProgressionScorePure(tier, coins, currentVelocity, rebirthMulti, milestoneTarget, stage, cfgScoring, opts)
    opts = opts or {}
    cfgScoring = cfgScoring or { CompoundingDiscount = 0.70, ExecutionOverhead = 0.11, MaxRebirthSaveSec = 25 }
    local rebirthCost = tier.Price or 0
    local rawAmount = tier.Amount or 1
    local actualGain = tonumber(opts.actualRebirthGain) or rawAmount
    local multGainPct = (actualGain / math.max(rebirthMulti, 1)) * 100
    local newRebirthMulti = rebirthMulti + actualGain

    if (currentVelocity or 0) <= 0 or rebirthMulti <= 0 or rebirthCost <= 0 then
        return -1000, -math.huge, math.huge, math.huge, 0, math.huge, math.huge, 0, math.huge
    end

    local newVelocity = currentVelocity * (newRebirthMulti / math.max(rebirthMulti, 1))
    if newVelocity <= 0 then
        return -1000, -math.huge, math.huge, math.huge, 0, math.huge, math.huge, 0, math.huge
    end

    local grossRecoveryTime = rebirthCost / newVelocity
    local deltaVelocity = newVelocity - currentVelocity
    local netBreakEvenTime = (deltaVelocity > 0) and (rebirthCost / deltaVelocity) or math.huge

    local M = math.max(milestoneTarget or 1, 1)
    local distA = math.max(0, M - coins)
    local etaA = distA / currentVelocity

    local timeToAffordRebirth = 0
    if coins < rebirthCost then
        timeToAffordRebirth = (rebirthCost - coins) / currentVelocity
    end

    local coinsAfter = 0
    local executionOverhead = cfgScoring.ExecutionOverhead or 0.11
    local sprintTimeB = M / newVelocity
    local etaB = timeToAffordRebirth + executionOverhead + sprintTimeB

    local netDeltaSeconds = etaA - etaB

    local sprintTimeA2 = M / currentVelocity
    local sprintTimeB2 = M / newVelocity
    local etaA2 = etaA + sprintTimeA2
    local etaB2 = etaB + sprintTimeB2
    local netDeltaCompounding = etaA2 - etaB2

    local isCompoundingAccelerator = (coins < M * (cfgScoring.CompoundingDiscount or 0.70))
        and (netDeltaCompounding > 0)
        and (grossRecoveryTime <= (cfgScoring.MaxRebirthSaveSec or 25))
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

    -- Penalize wasting large unspent excess coins ONLY if excess cannot be converted to eggs
    local surplusRatio = math.max(0, coins - rebirthCost) / math.max(rebirthCost, 1)
    local excessPenalty = (opts.surplusCanBeHatched) and 0 or math.min(15, surplusRatio * 3.0)

    local score = 0
    if stage == "Early Game" then
        score = (gainScore * 2.0) + (accelScore * 1.0) - (recoveryPenalty * 0.4) - (lostCoinPenalty * 0.3) - (excessPenalty * 0.3)
        if multGainPct < 5.0 then score = score - 10.0 end
    elseif stage == "Mid Game" then
        score = (gainScore * 1.2) + (accelScore * 1.5) - (recoveryPenalty * 1.0) - (lostCoinPenalty * 1.0) - (excessPenalty * 0.6)
        if multGainPct < 10.0 then score = score - 15.0 end
        if grossRecoveryTime > 60 then score = score - 20.0 end
    elseif stage == "Late Game" then
        score = (gainScore * 1.0) + (accelScore * 2.0) - (recoveryPenalty * 1.3) - (lostCoinPenalty * 1.8) - (excessPenalty * 0.8)
        if multGainPct < 12.0 then score = score - 25.0 end
        if grossRecoveryTime > 90 then score = score - 30.0 end
    else
        score = (gainScore * 2.5) + (accelScore * 2.5) - (recoveryPenalty * 0.8) - (lostCoinPenalty * 2.5) - (excessPenalty * 0.5)
        if multGainPct < 15.0 then score = score - 30.0 end
        if grossRecoveryTime > 120 then score = score - 40.0 end
    end

    return score, netDeltaSeconds, grossRecoveryTime, netBreakEvenTime, newVelocity, etaA, etaB, coinsAfter, timeToAffordRebirth
end

--------------------------------------------------------------------------------
-- INITIALIZATION & INSTANCE METHODS
--------------------------------------------------------------------------------

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
                local content = string.format("Predicted Coin Velocity: +%s/s (Calib: %.2fx)\nMeasured Coin Velocity: %s\nActive Decision Rate: +%s/s [Source: %s]",
                    formatCompact(KaitunState.PredictedVelocity or 0),
                    tonumber(KaitunState.CalibrationRatio) or 1.0,
                    tostring(KaitunState.MeasuredVelocityStr or "Measuring..."),
                    formatCompact(KaitunState.CoinVelocity or 0),
                    tostring(KaitunState.VelocitySource or "Predicted"))
                if KaitunState.ShadowReport and KaitunState.ShadowReport.SummaryShort then
                    content = content .. "\nShadow Audit: " .. KaitunState.ShadowReport.SummaryShort
                end
                if lastVelocityStr ~= content then
                    lastVelocityStr = content
                    UI.KaitunVelocityText:Set(content)
                end
            end
        end)
    end

    local function getFrontierRebirthInfo(overrideWorldKey, overrideData, overrideCoins, overrideRebirths)
        local data = overrideData or getPlayerData()
        if not (data and Mod.WorldConfig and Mod.RebirthButtonConfig and Mod.RebirthConfig) then
            return nil
        end

        local currentWorld = overrideWorldKey
            and (Mod.WorldConfig.GetByKey and Mod.WorldConfig.GetByKey(overrideWorldKey) or Mod.WorldConfig.Worlds and Mod.WorldConfig.Worlds[overrideWorldKey])
            or (Mod.WorldConfig.Get and Mod.WorldConfig.Get(data))
        local worldKey = overrideWorldKey or (currentWorld and currentWorld.Key) or "Main"
        local rebirthButtons = Mod.WorldConfig.GetRebirthButtons and Mod.WorldConfig.GetRebirthButtons(data, currentWorld) or 1
        local unlocked = Mod.RebirthButtonConfig.GetUnlockedCount and Mod.RebirthButtonConfig.GetUnlockedCount(rebirthButtons, worldKey) or 1
        local optionCount = Mod.RebirthButtonConfig.GetOptionCount and Mod.RebirthButtonConfig.GetOptionCount(unlocked, worldKey) or 1
        local maxOptions = Mod.RebirthButtonConfig.GetMaximumOptions and Mod.RebirthButtonConfig.GetMaximumOptions(worldKey) or ((worldKey == "TimeRift") and 10 or 18)

        local highestUnlockedIdx = optionCount
        if not overrideData then
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
        end

        highestUnlockedIdx = math.min(highestUnlockedIdx, maxOptions)
        local rebirthCount = overrideRebirths or getRebirthCount()
        local coins = overrideCoins or getCoins()
        local worldArg = (worldKey ~= "Main" and worldKey or nil)

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
            if rebirthCount < (CONFIG.StageThresholds.EarlyRebirthLimit or 50) and totalTeamPower < (CONFIG.StageThresholds.EarlyPowerLimit or 10000) then
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
        local endgameRebThresh = CONFIG.StageThresholds.EndgameRebirthLimit or CONFIG.StageThresholds.EndgamePowerLimit or 100000
        if totalTeamPower >= (CONFIG.StageThresholds.MidPowerLimit or 5000000) or rebirthCount >= endgameRebThresh then
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
        RawPredictedRate = 0,
        CalibrationRatio = 1.0,
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

    local function computePredictedVelocity(data, effectiveTeamPower, rebirthMulti, islandBonus, critChance, critPower)
        local tapRate = CONFIG.TapRate or 13.33
        local TapFormula = Mod.TapFormula or requireSafe(function() return ReplicatedStorage.Shared.Progression.TapFormula end)
        local ProfileStats = Mod.ProfileStats or requireSafe(function() return ReplicatedStorage.Modules.Client.Game.ProfileStats end)

        if TapFormula and type(TapFormula.GetAmounts) == "function" and data and data.Pets and type(data.Pets.PowerMultiplier) == "number" then
            local okAmounts, baseTap, critTap = pcall(TapFormula.GetAmounts, data, 1, 1, 1, 1, 1)
            if okAmounts and type(baseTap) == "number" and baseTap > 0 then
                local crUnlocked = true
                if ProfileStats and type(ProfileStats.CritsUnlocked) == "function" then
                    local okU, u = pcall(ProfileStats.CritsUnlocked, data)
                    if okU then crUnlocked = (u == true) end
                end
                local crC = crUnlocked and math.clamp(tonumber(critChance) or 0, 0, 1) or 0
                local crTap = tonumber(critTap) or (baseTap * math.max(1, tonumber(critPower) or 10))
                local expectedTap = (1 - crC) * baseTap + crC * crTap
                return math.max(1, expectedTap * tapRate), { mode = "TapFormula", baseTap = baseTap, critTap = crTap, expectedTap = expectedTap }
            end
        end

        local baseCoinPerTap = math.max(1, effectiveTeamPower or 1) * math.max(1, rebirthMulti or 1) * math.max(1, islandBonus or 1)
        local effCritC = math.clamp(tonumber(critChance) or 0, 0, 1)
        local effCritP = math.max(1, tonumber(critPower) or 10)
        local effectiveTap = baseCoinPerTap * (1 + effCritC * (effCritP - 1))
        return math.max(1, effectiveTap * tapRate), { mode = "FallbackFormula", baseTap = baseCoinPerTap, critTap = baseCoinPerTap * effCritP, expectedTap = effectiveTap }
    end

    local function updateVelocityMeasurement(currentCoins, curWorld, curIsland, rebirthCount, teamPower, predictedRate, boostFingerprint)
        local now = os.clock()
        VelocityTracker.RawPredictedRate = predictedRate
        local calibratedPredicted = math.max(1, predictedRate * (VelocityTracker.CalibrationRatio or 1.0))
        VelocityTracker.PredictedRate = calibratedPredicted

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
                if predictedRate > 0 and measuredRate > 0 then
                    local instantRatio = math.clamp(measuredRate / predictedRate, 0.20, 5.0)
                    VelocityTracker.CalibrationRatio = (0.65 * (VelocityTracker.CalibrationRatio or 1.0)) + (0.35 * instantRatio)
                    KaitunState.CalibrationRatio = VelocityTracker.CalibrationRatio
                end
                VelocityTracker.Difference = math.abs(calibratedPredicted - measuredRate)
            end
            VelocityTracker.SampleStartTick = now
            VelocityTracker.SampleStartCoins = currentCoins
        end

        local activeVelocity = calibratedPredicted
        if VelocityTracker.LastMeasuredRate ~= nil then
            activeVelocity = math.max(1, VelocityTracker.LastMeasuredRate)
            VelocityTracker.ActiveSource = "Measured"
            local ageSec = math.max(0, math.floor(now - VelocityTracker.LastMeasuredTick))
            local diffPct = (VelocityTracker.Difference / math.max(1, VelocityTracker.LastMeasuredRate)) * 100
            VelocityTracker.Status = string.format("+%s/s (Last completed, %ds ago | Diff: %.1f%%)",
                formatCompact(VelocityTracker.LastMeasuredRate), ageSec, diffPct)
        else
            activeVelocity = calibratedPredicted
            VelocityTracker.ActiveSource = (math.abs((VelocityTracker.CalibrationRatio or 1.0) - 1.0) > 0.02) and "Calibrated" or "Predicted"
            local rem = math.max(1, math.ceil(VelocityTracker.WindowDuration - (now - VelocityTracker.SampleStartTick)))
            VelocityTracker.Status = string.format("Measuring (%ds left)...", rem)
        end

        return activeVelocity, VelocityTracker.LastMeasuredRate, calibratedPredicted, VelocityTracker.ActiveSource
    end

    local function getActiveTierChances(data)
        local BoostFormula = Mod.BoostFormula or requireSafe(function() return ReplicatedStorage.Shared.Items.BoostFormula end)
        local SkillTreeFormula = Mod.SkillTreeFormula or requireSafe(function() return ReplicatedStorage.Shared.Progression.SkillTreeFormula end)
        local MasteryFormula = Mod.MasteryFormula or requireSafe(function() return ReplicatedStorage.Shared.Progression.MasteryFormula end)
        local ProfileStats = Mod.ProfileStats or requireSafe(function() return ReplicatedStorage.Modules.Client.Game.ProfileStats end)

        local rawBoostMult = 1.0
        if BoostFormula and type(BoostFormula.GetStatMultiplier) == "function" and data then
            local okB, val = pcall(BoostFormula.GetStatMultiplier, data, "GoldenHatch")
            if okB and type(val) == "number" then
                rawBoostMult = val
            end
        end

        -- BoostFormula returns 1.0 baseline when no Golden boost is active; subtract 1 before combining with SkillTree/Mastery
        local goldBoostExtra = math.max(0, rawBoostMult - 1)
        local goldSkill = 0
        local diaSkill = 0
        local shinySkill = 0
        if SkillTreeFormula and type(SkillTreeFormula.GetBonus) == "function" and data then
            local okG, vg = pcall(SkillTreeFormula.GetBonus, data, "GoldenChance")
            if okG and type(vg) == "number" then goldSkill = vg end
            local okD, vd = pcall(SkillTreeFormula.GetBonus, data, "DiamondChance")
            if okD and type(vd) == "number" then diaSkill = vd end
            local okS, vs = pcall(SkillTreeFormula.GetBonus, data, "RainbowChance")
            if okS and type(vs) == "number" then shinySkill = vs end
        end

        local goldMastery = 0
        if MasteryFormula and type(MasteryFormula.GetBonus) == "function" and data then
            local okM, vm = pcall(MasteryFormula.GetBonus, data, "EggGoldenChance")
            if okM and type(vm) == "number" then goldMastery = vm end
        end

        local goldLuck = 1.0
        local rainbowLuck = 1.0
        if ProfileStats and data then
            if type(ProfileStats.GoldLuck) == "function" then
                local okGL, vgl = pcall(ProfileStats.GoldLuck, data)
                if okGL and type(vgl) == "number" and vgl > 0 then goldLuck = vgl end
            end
            if type(ProfileStats.RainbowLuck) == "function" then
                local okRL, vrl = pcall(ProfileStats.RainbowLuck, data)
                if okRL and type(vrl) == "number" and vrl > 0 then rainbowLuck = vrl end
            end
        end

        local gChance = math.clamp((goldBoostExtra + goldSkill + goldMastery) * goldLuck, 0, 1)
        local dChance = math.clamp(diaSkill, 0, 1)
        local sChance = math.clamp(shinySkill * rainbowLuck, 0, 1)

        return gChance, dChance, sChance, rawBoostMult
    end

    local function evaluateEggTrueStats(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, freeSlots, equipLimit, activeGoldenChance, opts)
        local PetPowerModule = Mod.PetPowerModule or requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end)
        local CraftLockMod = Mod.CraftLock or requireSafe(function() return ReplicatedStorage.Shared.Pets.CraftLock end)
        local EggStockClientMod = Mod.EggStockClient or requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.EggStockClient end)

        local mergedOpts = {}
        if type(opts) == "table" then
            for k, v in pairs(opts) do mergedOpts[k] = v end
        end
        if mergedOpts.goldenMultiplier == nil then
            mergedOpts.goldenMultiplier = (PetPowerModule and PetPowerModule.GetTierMultiplier and PetPowerModule.GetTierMultiplier("Golden")) or 3.0
        end
        if mergedOpts.diamondMultiplier == nil then
            mergedOpts.diamondMultiplier = (PetPowerModule and PetPowerModule.GetTierMultiplier and PetPowerModule.GetTierMultiplier("Diamond")) or 7.0
        end
        if mergedOpts.shinyMultiplier == nil then
            local okSh, sM = pcall(function() return PetPowerModule and PetPowerModule.GetTierMultiplier and PetPowerModule.GetTierMultiplier("Shiny") end)
            mergedOpts.shinyMultiplier = (okSh and type(sM) == "number" and sM) or 10.0
        end
        if mergedOpts.isCraftLockedEgg == nil and CraftLockMod then
            if type(CraftLockMod.LocksEgg) == "function" then
                local okL, locked = pcall(CraftLockMod.LocksEgg, eggName)
                if okL then mergedOpts.isCraftLockedEgg = (locked == true) end
            elseif type(CraftLockMod.IsLocked) == "function" then
                local okL, locked = pcall(CraftLockMod.IsLocked, { Egg = eggName })
                if okL then mergedOpts.isCraftLockedEgg = (locked == true) end
            end
        end
        if mergedOpts.isVaultedPetFn == nil and EggStockClientMod and type(EggStockClientMod.Get) == "function" then
            mergedOpts.isVaultedPetFn = function(pName)
                local okSt, stock = pcall(EggStockClientMod.Get, pName)
                return okSt and type(stock) == "table" and stock.Left ~= nil and stock.Left <= 0
            end
        end

        return evaluateEggTrueStatsPure(eggName, eggInfo, LaunchPetConfig, teamPowers, weakestPetPower, freeSlots, equipLimit, activeGoldenChance, mergedOpts)
    end

    local function calculateProgressionScore(tier, coins, currentVelocity, rebirthMulti, milestoneTarget, stage, opts)
        return calculateProgressionScorePure(tier, coins, currentVelocity, rebirthMulti, milestoneTarget, stage, CONFIG.Scoring, opts)
    end

    local function rankSkillUpgrades(buyableList, coinsOrGems, data)
        if not buyableList or #buyableList == 0 then return {} end
        local ranked = {}
        local SkillTreeConfig = Mod.SkillTreeConfig

        local weightMap = {
            PetPower = 5.0,
            RebirthMultiplier = 4.5,
            TapPower = 4.0,
            GoldenChance = 3.5,
            EggLuck = 3.2,
            HatchSpeed = 2.8,
            CriticalTapChance = 2.6,
            CriticalTapDamage = 2.4,
            PetEquip = 5.5,
            DiamondChance = 3.0,
            RainbowChance = 3.0,
        }

        local function inferStatType(item)
            local n = item.nodeToUnlock
            if type(n) == "table" and n.Type then return n.Type, tonumber(n.Value) or 0.1 end
            local title = string.lower(tostring(item.title or ""))
            if title:find("equip") then return "PetEquip", 1 end
            if title:find("pet") and title:find("power") then return "PetPower", 0.15 end
            if title:find("rebirth") then return "RebirthMultiplier", 0.2 end
            if title:find("click") or title:find("tap") then return "TapPower", 0.1 end
            if title:find("gold") then return "GoldenChance", 0.01 end
            if title:find("luck") then return "EggLuck", 0.1 end
            if title:find("speed") or title:find("hatch") then return "HatchSpeed", 0.1 end
            if title:find("crit") then return "CriticalTapChance", 0.05 end
            return "Other", 0.05
        end

        for _, item in ipairs(buyableList) do
            local st, val = inferStatType(item)
            local w = weightMap[st] or 1.0
            local price = math.max(1, tonumber(item.price) or 1)
            local roi = (w * math.max(0.01, val)) / math.sqrt(price)
            table.insert(ranked, { item = item, roi = roi, statType = st })
        end

        table.sort(ranked, function(a, b)
            if math.abs(a.roi - b.roi) > 1e-9 then return a.roi > b.roi end
            return (a.item.price or 0) < (b.item.price or 0)
        end)

        local out = {}
        for _, entry in ipairs(ranked) do
            table.insert(out, entry.item)
        end
        return out
    end

    ----------------------------------------------------------------------------
    -- SHADOW MODE DECISION ENGINE (OLD vs NEW PURE EVALUATION)
    ----------------------------------------------------------------------------

    local function buildLiveSnapshot()
        local data = getPlayerData()
        if not data then return nil end

        local curWorld = (data.Progression and data.Progression.World) or "Main"
        local physicalIsland = getPhysicalCurrentIsland()
        local curIsland = physicalIsland or (data.Progression and data.Progression.Island) or "Spawn"
        local coins = getCoins()
        local mainCoins = (data.Currencies and data.Currencies.Coins) or coins or 0
        local riftCoins = (data.Currencies and data.Currencies.RiftCoins) or 0
        local gems = (ctx.API.getGems and ctx.API.getGems()) or 0
        local rebirthCount = getRebirthCount()
        local ownedCount, maxStorage, freeSlots = 0, 150, 150
        if ctx.API.getPetStorageInfo then
            ownedCount, maxStorage, freeSlots = ctx.API.getPetStorageInfo()
        end

        local bridgeStatus = (ctx.API.getBridgeStatus and ctx.API.getBridgeStatus()) or { lowered = true, ready = false, power = 0, req = 0 }
        local nextIsl = ctx.API.getNextLockedIsland and ctx.API.getNextLockedIsland(curWorld) or nil
        local mainNextIsl = ctx.API.getNextLockedIsland and ctx.API.getNextLockedIsland("Main") or nil
        local bestUnlockedIsl = ctx.API.getBestUnlockedIsland and ctx.API.getBestUnlockedIsland() or curIsland
        local w2Unlocked = (data.Progression and data.Progression.UnlockedWorlds and data.Progression.UnlockedWorlds.TimeRift == true)
            or (ctx.API.isWorld2Unlocked and ctx.API.isWorld2Unlocked()) or false

        local equippedIds = (data.Pets and data.Pets.Equipped) or {}
        local ownedPets = (data.Pets and data.Pets.Owned) or {}
        local equipLimit = math.max(1, tonumber(data.Pets and data.Pets.EquipLimit) or 5)
        local PetPowerModule = Mod.PetPowerModule or requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end)
        local effMap = {}
        if PetPowerModule and PetPowerModule.GetOwnedPowers and ownedPets then
            pcall(function() effMap = PetPowerModule.GetOwnedPowers(ownedPets) end)
        end

        local effectiveTeamPower = 0
        local teamPowers = {}
        local bagCounts = {}
        local equippedCount = 0
        for _, id in ipairs(equippedIds) do
            local p = ownedPets[id]
            if p then
                local pwr = effMap[id] or p.Power or 0
                effectiveTeamPower = effectiveTeamPower + pwr
                table.insert(teamPowers, pwr)
                equippedCount = equippedCount + 1
            end
        end
        for _, p in pairs(ownedPets) do
            if p and p.Name then
                local c = bagCounts[p.Name] or { Normal = 0, Golden = 0, Diamond = 0 }
                local t = p.Tier or "Normal"
                if t == "Golden" then c.Golden = c.Golden + 1
                elseif t == "Diamond" then c.Diamond = c.Diamond + 1
                else c.Normal = c.Normal + 1 end
                bagCounts[p.Name] = c
            end
        end
        table.sort(teamPowers)
        local weakestPetPower = teamPowers[1] or 0

        local ProfileStats = Mod.ProfileStats or requireSafe(function() return ReplicatedStorage.Modules.Client.Game.ProfileStats end)
        local rebirthMulti = rebirthCount + 1
        local islandBonus = 1.0
        local critChance = 0.05
        local critPower = 10
        local rebirthGainStat = 1.0
        local gemGainStat = 1.0
        if ProfileStats then
            pcall(function()
                rebirthMulti = ProfileStats.RebirthMulti(data) or (rebirthCount + 1)
                islandBonus = ProfileStats.IslandBonus(data) or 1.0
                critChance = ProfileStats.CritChance(data) or 0.05
                critPower = ProfileStats.CritPower(data) or 10
                if ProfileStats.RebirthGain then rebirthGainStat = ProfileStats.RebirthGain(data) or 1.0 end
                if ProfileStats.GemGain then gemGainStat = ProfileStats.GemGain(data) or 1.0 end
            end)
        end

        local activeGoldenChance, activeDiamondChance, activeShinyChance, rawBoostGoldMult = getActiveTierChances(data)
        local predictedVel, tapMeta = computePredictedVelocity(data, effectiveTeamPower, rebirthMulti, islandBonus, critChance, critPower)
        local boostFp = getBoostFingerprint(data)

        local liveEggsSet = {}
        local eggsFolder = workspace:FindFirstChild("Eggs")
        if eggsFolder then
            for _, c in ipairs(eggsFolder:GetChildren()) do
                liveEggsSet[c.Name] = true
            end
        end

        local eggsCatalog = {}
        for eggName, eggInfo in pairs(Mod.LaunchEggConfig or {}) do
            if type(eggInfo) == "table" then
                local wKey = eggInfo.World or "Main"
                if Mod.WorldConfig and type(Mod.WorldConfig.ForEgg) == "function" then
                    local okW, wc = pcall(Mod.WorldConfig.ForEgg, eggInfo)
                    if okW and type(wc) == "table" and wc.Key then wKey = wc.Key end
                end
                local copy = {}
                for k, v in pairs(eggInfo) do copy[k] = v end
                copy.World = wKey
                copy.InWorkspace = (eggsFolder == nil) or (liveEggsSet[eggName] == true)
                eggsCatalog[eggName] = copy
            end
        end

        local frontier = getFrontierRebirthInfo(curWorld, data, coins, rebirthCount)
        local highestUnlockedIdx = frontier and frontier.highestUnlockedIdx or 1
        local worldArg = (curWorld ~= "Main" and curWorld or nil)
        local rebirthTiers = {}
        if Mod.RebirthConfig then
            for i = 1, highestUnlockedIdx do
                local a = Mod.RebirthConfig.GetAmountFromIndex(i, worldArg)
                local p = Mod.RebirthConfig.GetPrice(a, rebirthCount, nil, worldArg)
                local actG = a * rebirthGainStat
                if Mod.RebirthRewardFormula and type(Mod.RebirthRewardFormula.Get) == "function" then
                    local okRG, rVal = pcall(Mod.RebirthRewardFormula.Get, data, a, 1)
                    if okRG and type(rVal) == "number" and rVal > 0 then actG = rVal end
                end
                table.insert(rebirthTiers, {
                    Index = i,
                    Amount = a,
                    ActualAmount = actG,
                    Price = p,
                })
            end
        end

        return {
            data = data,
            curWorld = curWorld,
            curIsland = curIsland,
            bestUnlockedIsl = bestUnlockedIsl,
            nextIsl = nextIsl,
            mainNextIsl = mainNextIsl,
            w2Unlocked = w2Unlocked,
            coins = coins,
            mainCoins = mainCoins,
            riftCoins = riftCoins,
            gems = gems,
            rebirthCount = rebirthCount,
            rebirthMulti = rebirthMulti,
            rebirthGainStat = rebirthGainStat,
            gemGainStat = gemGainStat,
            islandBonus = islandBonus,
            critChance = critChance,
            critPower = critPower,
            ownedCount = ownedCount,
            maxStorage = maxStorage,
            freeSlots = freeSlots,
            equipLimit = equipLimit,
            equippedCount = equippedCount,
            teamPowers = teamPowers,
            weakestPetPower = weakestPetPower,
            effectiveTeamPower = effectiveTeamPower,
            bagCounts = bagCounts,
            bridgeStatus = bridgeStatus,
            hasX8 = (ctx.API.hasX8Gamepass and ctx.API.hasX8Gamepass()) or false,
            hatchDelay = (ctx.API.getAutoHatchDelay and ctx.API.getAutoHatchDelay()) or 2.4,
            allowHatch = KaitunState.AllowHatch,
            allowTriple = (KaitunState.AllowTripleHatch ~= false),
            allowRebirth = KaitunState.AllowRebirth,
            allowIslandUnlock = KaitunState.AllowIslandUnlock,
            allowAutoCraft = KaitunState.AllowAutoCraft,
            activeGoldenChance = activeGoldenChance,
            activeDiamondChance = activeDiamondChance,
            activeShinyChance = activeShinyChance,
            rawBoostGoldMult = rawBoostGoldMult,
            boostFingerprint = boostFp,
            predictedVelocity = predictedVel,
            tapMeta = tapMeta,
            eggsCatalog = eggsCatalog,
            launchPetConfig = Mod.LaunchPetConfig,
            rebirthTiers = rebirthTiers,
            frontierInfo = frontier,
            unlockedIslands = (data.Progression and data.Progression.UnlockedIslands) or {},
            now = os.clock(),
        }
    end

    -- Legacy faithfully-reproduced Old Kaitun logic (read-only) for Shadow Comparison
    local function evaluateKaitunStrategyOld(snap)
        if not snap then return nil end
        local oldGolden = math.clamp(snap.rawBoostGoldMult or 0, 0, 1)
        local coins = snap.coins or 0
        local baseTapOld = math.max(1, snap.effectiveTeamPower or 1) * math.max(1, snap.rebirthMulti or 1) * math.max(1, snap.islandBonus or 1)
        local predVelOld = math.max(1, baseTapOld * (1 + (snap.critChance or 0.05) * ((snap.critPower or 10) - 1)) * 13.33)
        local coinVelOld = snap.coinVelocityOverride or snap.measuredVelocity or predVelOld

        -- Reproduce old EndgamePowerLimit bug in stage check
        local stageOld = "Mid Game"
        if snap.bridgeStatus and not snap.bridgeStatus.lowered then
            stageOld = "Early Game"
        elseif snap.curWorld == "Main" and (snap.bestUnlockedIsl == "Spawn" or snap.bestUnlockedIsl == "Sky Island" or snap.bestUnlockedIsl == "Autumn")
            and (snap.rebirthCount < 50 and snap.effectiveTeamPower < 10000) then
            stageOld = "Early Game"
        elseif not snap.nextIsl or (snap.curWorld == "TimeRift" and (snap.bestUnlockedIsl == "Medieval Island" or snap.bestUnlockedIsl == "Royal")) then
            stageOld = "Endgame"
        elseif snap.curWorld == "TimeRift" or (snap.curWorld == "Main" and (snap.bestUnlockedIsl == "Volcano" or snap.bestUnlockedIsl == "Heaven" or snap.bestUnlockedIsl == "Shadow Realm")) then
            stageOld = "Late Game"
        elseif snap.effectiveTeamPower >= 5000000 or snap.rebirthCount >= 100000 then
            stageOld = "Late Game"
        end

        local candidates = {}
        local unlocked = snap.unlockedIslands or {}
        for eggName, eggInfo in pairs(snap.eggsCatalog or {}) do
            if type(eggInfo) == "table" and (eggInfo.Price or 0) > 0 and eggInfo.InWorkspace ~= false
                and not eggInfo.ShowcaseOnly and not eggInfo.Limited and eggName ~= "Glitched Egg"
                and (eggInfo.World or "Main") == snap.curWorld then
                local reqIsl = eggInfo.Island or "Spawn"
                local islOk = (reqIsl == "Spawn") or (reqIsl == "World 2 Spawn") or unlocked[reqIsl] == true
                if islOk and snap.launchPetConfig then
                    -- Reproduce Jensen pre-averaging + hardcoded equipLimit=5
                    local totalCh, evBase, evGold, evSing, bestTriple = 0, 0, 0, 0, 0
                    local details = {}
                    local weak5 = (#(snap.teamPowers or {}) < 5) and 0 or (snap.weakestPetPower or 0)
                    for _, ch in pairs(eggInfo.Pets or {}) do totalCh = totalCh + ch end
                    if totalCh > 0 then
                        for pName, ch in pairs(eggInfo.Pets) do
                            local pc = snap.launchPetConfig[pName]
                            local pwr = pc and pc.Power or 0
                            if pwr > 0 then
                                local w = ch / totalCh
                                evBase = evBase + w * pwr
                                evGold = evGold + w * pwr * 3
                                evSing = evSing + w * (((1 - oldGolden) * math.max(0, pwr - weak5)) + (oldGolden * math.max(0, pwr * 3 - weak5)))
                                table.insert(details, { name = pName, weight = w, eff = (1 - oldGolden) * pwr + oldGolden * pwr * 3, pwr = pwr })
                            end
                        end
                    end
                    local bW = { snap.teamPowers[1] or 0, snap.teamPowers[2] or 0, snap.teamPowers[3] or 0 }
                    if #(snap.teamPowers or {}) < 5 then
                        local oSlots = 5 - #(snap.teamPowers or {})
                        if oSlots >= 3 then bW = { 0, 0, 0 }
                        elseif oSlots == 2 then bW = { 0, 0, snap.teamPowers[1] or 0 }
                        elseif oSlots == 1 then bW = { 0, snap.teamPowers[1] or 0, snap.teamPowers[2] or 0 } end
                    end
                    table.sort(bW)
                    for i = 1, #details do
                        for j = 1, #details do
                            for k = 1, #details do
                                local d = { details[i].eff, details[j].eff, details[k].eff }
                                table.sort(d) -- Bugged ascending vs ascending pairing
                                local g = math.max(0, d[1] - bW[1]) + math.max(0, d[2] - bW[2]) + math.max(0, d[3] - bW[3])
                                bestTriple = bestTriple + (details[i].weight * details[j].weight * details[k].weight * g)
                            end
                        end
                    end
                    local evDia = evBase * 7
                    local isUpg = (#(snap.teamPowers or {}) < 5) and (evBase > 0)
                        or (evSing >= math.max(0.01, weak5 * 0.05))
                        or (bestTriple >= math.max(0.01, weak5 * 0.05) * 1.5)
                        or ((eggName == "Royal" or eggName == "Medieval" or eggName == "Permafrost") and weak5 < evDia * 0.95)
                    local isEventBug = (eggName:find("30M") or eggName:find("Event") or eggName:find("Visit") or eggInfo.Price >= 50000000)
                    local isEarlyOrMidBug = (stageOld == "Early Game" or stageOld == "Mid Game" or coins < 50000000)
                    if isUpg and not (isEventBug and isEarlyOrMidBug) then
                        table.insert(candidates, { Name = eggName, Price = eggInfo.Price, TriplePrice = eggInfo.Price * 3, ExpectedEffectiveTeamGain = evSing, ExpectedTripleEffectiveTeamGain = bestTriple })
                    end
                end
            end
        end
        table.sort(candidates, function(a, b) return a.ExpectedEffectiveTeamGain > b.ExpectedEffectiveTeamGain end)
        local bestEgg = nil
        for _, c in ipairs(candidates) do
            if coins >= c.Price then bestEgg = c break end
        end
        if not bestEgg then bestEgg = candidates[1] end

        -- Reproduce Old Rebirth Selection (raw amt, zero-ETA on zero vel)
        local isEndgame = (snap.curWorld == "TimeRift" and not snap.nextIsl)
        local bestReb = nil
        local bestScore = -math.huge
        local frontierIdx = (snap.frontierInfo and snap.frontierInfo.highestUnlockedIdx) or #(snap.rebirthTiers or {})
        local M = (snap.nextIsl and snap.nextIsl.price) or (bestEgg and bestEgg.Price) or 1e9
        for _, t in ipairs(snap.rebirthTiers or {}) do
            if coins >= t.Price and t.Price > 0 then
                local newR = snap.rebirthMulti + t.Amount
                local newV = coinVelOld * (newR / math.max(snap.rebirthMulti, 1))
                local grossRec = (newV > 0) and (t.Price / newV) or 0 -- BUG: 0 when newV==0
                local etaA = (coinVelOld > 0) and (math.max(0, M - coins) / coinVelOld) or 0
                local etaB = 0.11 + ((newV > 0) and (M / newV) or 0)
                local netD = etaA - etaB
                local sc = ((t.Amount / math.max(snap.rebirthMulti, 1)) * 100 / 10 * 15) + ((etaA > 0) and (netD / math.max(etaA, 5) * 30) or (netD > 0 and 10 or -35))
                if isEndgame and t.Index >= frontierIdx then
                    bestReb = { Index = t.Index, Amount = t.Amount, Price = t.Price, Score = 1000 + t.Amount, NetDelta = netD, GrossRec = grossRec }
                elseif not isEndgame and netD > 0 and sc > bestScore then
                    bestScore = sc
                    bestReb = { Index = t.Index, Amount = t.Amount, Price = t.Price, Score = sc, NetDelta = netD, GrossRec = grossRec }
                end
            end
        end

        local nearSprint = false
        if snap.nextIsl then
            local tc = snap.nextIsl.isRift and (snap.riftCoins or 0) or coins
            local tIsl = math.max(0, snap.nextIsl.price - tc) / math.max(coinVelOld, 1)
            local recB = (bestReb and bestReb.GrossRec) or 30
            if tc >= snap.nextIsl.price * 0.50 or tIsl <= math.max(30, recB * 1.5) then
                nearSprint = true
            end
        end

        local actionType = "FarmSave"
        if snap.bridgeStatus and not snap.bridgeStatus.lowered then
            actionType = snap.bridgeStatus.ready and "PushBridge" or "ChargeBridge"
        elseif snap.w2Unlocked and snap.curWorld == "Main" then
            actionType = "TravelWorld2"
        elseif snap.nextIsl and ((snap.nextIsl.isRift and (snap.riftCoins or 0) or coins) >= snap.nextIsl.price) then
            actionType = "UnlockIsland"
        elseif nearSprint then
            actionType = "SaveIslandSprint"
        elseif snap.allowHatch and (snap.freeSlots or 0) > 0 and bestEgg and coins >= bestEgg.Price then
            actionType = "HatchEgg"
        elseif snap.allowRebirth and bestReb then
            actionType = "Rebirth"
        end

        return {
            Engine = "OLD",
            Stage = stageOld,
            DecisionType = actionType,
            BestEggName = bestEgg and bestEgg.Name or nil,
            BestEggGain = bestEgg and bestEgg.ExpectedEffectiveTeamGain or 0,
            BestRebirthIndex = bestReb and bestReb.Index or nil,
            BestRebirthAmount = bestReb and bestReb.Amount or 0,
            BestRebirthScore = bestReb and bestReb.Score or 0,
            ActiveGoldenChance = oldGolden,
            PredictedVelocity = predVelOld,
            CoinVelocity = coinVelOld,
            NearIslandSprint = nearSprint,
            CandidateEggCount = #candidates,
        }
    end

    local function evaluateKaitunStrategy(snap, lockedDecision)
        if not snap then return nil end

        local coins = snap.coins or 0
        local curWorld = snap.curWorld or "Main"
        local curIsland = snap.curIsland or "Spawn"
        local rebirthCount = snap.rebirthCount or 0
        local rebirthMulti = snap.rebirthMulti or 1
        local equipLimit = math.max(1, snap.equipLimit or 5)
        local freeSlots = snap.freeSlots or 0
        local activeGoldenChance = snap.activeGoldenChance or 0
        local activeDiamondChance = snap.activeDiamondChance or 0
        local activeShinyChance = snap.activeShinyChance or 0

        local predictedVelocity = math.max(0, snap.predictedVelocity or 0)
        local coinVelocity = snap.coinVelocityOverride or snap.measuredVelocity or predictedVelocity

        local stage = determineProgressionStage(curWorld, snap.bestUnlockedIsl or curIsland, rebirthCount, rebirthMulti, snap.effectiveTeamPower or 0, snap.nextIsl, snap.bridgeStatus)

        -- Evaluate Eligible Eggs (No fake ">= 50M == EventEgg" filter!)
        local candidateEggs = {}
        local function isEligibleEgg(eggName, eggInfo)
            if type(eggInfo) ~= "table" or not eggInfo.Price or eggInfo.Price <= 0 then return false end
            if eggInfo.ShowcaseOnly or eggInfo.Limited or eggInfo.Event or eggInfo.Hidden or eggInfo.Disabled then return false end
            if eggName == "Glitched Egg" or eggName == "Test" or eggName == "30M Visits" or eggName == "Ghost Ship Egg" then return false end
            if eggInfo.Currency and eggInfo.Currency ~= "Coins" and eggInfo.Currency ~= "RiftCoins" then return false end
            if eggInfo.InWorkspace == false then return false end
            return true
        end

        local function matchesWorldIsland(reqIsl, targetIsl)
            if reqIsl == targetIsl then return true end
            if curWorld == "TimeRift" and (targetIsl == "Spawn" or targetIsl == "World 2 Spawn") and (reqIsl == "Spawn" or reqIsl == "World 2 Spawn") then
                return true
            end
            return false
        end

        local eggOpts = {
            activeDiamondChance = activeDiamondChance,
            activeShinyChance = activeShinyChance,
            allowAutoCraft = (snap.allowAutoCraft ~= false),
            ownedBagCounts = snap.bagCounts,
            horizonHatches = 18,
        }

        for eggName, eggInfo in pairs(snap.eggsCatalog or {}) do
            if (eggInfo.World or "Main") == curWorld and matchesWorldIsland(eggInfo.Island or "Spawn", curIsland) and isEligibleEgg(eggName, eggInfo) then
                local eData = evaluateEggTrueStats(eggName, eggInfo, snap.launchPetConfig, snap.teamPowers, snap.weakestPetPower, freeSlots, equipLimit, activeGoldenChance, eggOpts)
                if eData.IsVerified then table.insert(candidateEggs, eData) end
            end
        end

        if #candidateEggs == 0 then
            local unlocked = snap.unlockedIslands or {}
            for eggName, eggInfo in pairs(snap.eggsCatalog or {}) do
                local reqIsl = eggInfo.Island or "Spawn"
                local isUnlocked = (reqIsl == "Spawn") or (reqIsl == "World 2 Spawn") or (unlocked[reqIsl] == true)
                    or (type(unlocked) == "table" and table.find(unlocked, reqIsl) ~= nil)
                if (eggInfo.World or "Main") == curWorld and isUnlocked and isEligibleEgg(eggName, eggInfo) then
                    local eData = evaluateEggTrueStats(eggName, eggInfo, snap.launchPetConfig, snap.teamPowers, snap.weakestPetPower, freeSlots, equipLimit, activeGoldenChance, eggOpts)
                    if eData.IsVerified then table.insert(candidateEggs, eData) end
                end
            end
        end

        local maxSaveTime = (CONFIG.MaxEggSaveTimes and CONFIG.MaxEggSaveTimes[stage]) or 120
        local affordableEggs, savingEggs, allUpgradeEggs = {}, {}, {}
        for _, egg in ipairs(candidateEggs) do
            if egg.IsUpgrade then
                table.insert(allUpgradeEggs, egg)
                if coins >= egg.Price then
                    table.insert(affordableEggs, egg)
                elseif coinVelocity > 0 then
                    local eta = (egg.Price - coins) / coinVelocity
                    if eta <= maxSaveTime then
                        table.insert(savingEggs, { egg = egg, eta = eta })
                    end
                end
            end
        end

        local bestUpgradeEgg = nil
        if #affordableEggs > 0 then
            table.sort(affordableEggs, function(a, b)
                local aGain = math.max(a.ExpectedEffectiveTeamGain or 0, a.ExpectedCraftAdjustedTeamGain or 0)
                local bGain = math.max(b.ExpectedEffectiveTeamGain or 0, b.ExpectedCraftAdjustedTeamGain or 0)
                if math.abs(aGain - bGain) > 1e-6 then return aGain > bGain end
                return a.Price > b.Price
            end)
            bestUpgradeEgg = affordableEggs[1]
        elseif #savingEggs > 0 then
            table.sort(savingEggs, function(a, b)
                local aGain = math.max(a.egg.ExpectedEffectiveTeamGain or 0, a.egg.ExpectedCraftAdjustedTeamGain or 0)
                local bGain = math.max(b.egg.ExpectedEffectiveTeamGain or 0, b.egg.ExpectedCraftAdjustedTeamGain or 0)
                local aRate = aGain / math.max(1, a.eta + (snap.hatchDelay or 2.4))
                local bRate = bGain / math.max(1, b.eta + (snap.hatchDelay or 2.4))
                if math.abs(aRate - bRate) > 1e-6 then return aRate > bRate end
                return a.egg.Price < b.egg.Price
            end)
            bestUpgradeEgg = savingEggs[1].egg
        elseif #allUpgradeEggs > 0 then
            table.sort(allUpgradeEggs, function(a, b) return a.Price < b.Price end)
            local cheapest = allUpgradeEggs[1]
            local eta = (coinVelocity > 0) and ((cheapest.Price - coins) / coinVelocity) or math.huge
            if eta <= maxSaveTime * 3 or cheapest.Price <= math.max(1000, coins * 10) then
                bestUpgradeEgg = cheapest
            end
        end

        if not bestUpgradeEgg and curWorld == "Main" and ((snap.ownedCount or 0) < equipLimit or rebirthCount < 5) and curIsland == "Spawn" and coins >= 100 and snap.eggsCatalog and snap.eggsCatalog.Basic then
            bestUpgradeEgg = evaluateEggTrueStats("Basic", snap.eggsCatalog.Basic, snap.launchPetConfig, snap.teamPowers, snap.weakestPetPower, freeSlots, equipLimit, activeGoldenChance, eggOpts)
        end

        local isTeamSaturated = (bestUpgradeEgg == nil and (snap.equippedCount or 0) >= equipLimit)

        -- Rebirth Analysis with Exact RebirthRewardFormula & Zero-Vel Guards
        local frontier = snap.frontierInfo
        local highestUnlockedIdx = (frontier and frontier.highestUnlockedIdx) or #(snap.rebirthTiers or {})
        local frontierPrice = (frontier and frontier.price) or 0
        local milestoneTarget = (snap.nextIsl and snap.nextIsl.price) or (bestUpgradeEgg and bestUpgradeEgg.Price) or (frontierPrice * 2)

        local viableRebirths = {}
        for _, tier in ipairs(snap.rebirthTiers or {}) do
            local isAffordable = (coins >= tier.Price and tier.Price > 0)
            local surplusCanHatch = (snap.allowHatch and freeSlots >= 1 and bestUpgradeEgg ~= nil and (coins - tier.Price) >= bestUpgradeEgg.Price)
            local actAmt = tier.ActualAmount or (tier.Amount * (snap.rebirthGainStat or 1))
            local score, netDelta, grossRec, netBreak, newVel, etaA, etaB, coinsAfter, timeToAff = calculateProgressionScore(
                tier, coins, coinVelocity, rebirthMulti, milestoneTarget, stage,
                { actualRebirthGain = actAmt, surplusCanBeHatched = surplusCanHatch }
            )
            table.insert(viableRebirths, {
                Index = tier.Index,
                Amount = tier.Amount,
                ActualAmount = actAmt,
                Price = tier.Price,
                MultGainPct = (actAmt / math.max(rebirthMulti, 1)) * 100,
                IsAffordable = isAffordable,
                CoinsBefore = coins,
                CoinsAfter = coinsAfter,
                TimeToAfford = timeToAff,
                CurrentVelocity = coinVelocity,
                NewVelocity = newVel,
                GrossRecoveryTime = grossRec,
                NetBreakEvenTime = netBreak,
                RecoveryTime = grossRec,
                ETABefore = etaA,
                ETAWith = etaB,
                NetDeltaSeconds = netDelta,
                ProgressionScore = score,
            })
        end

        local bestAffordableRebirth = nil
        local bestScore = -math.huge
        local targetMilestoneRebirth, targetMacroRebirth = nil, nil
        local bestMilestoneDelta, bestMacroGain = 0, 0
        local isEndgameWorld = (curWorld == "TimeRift" and not snap.nextIsl)

        if isEndgameWorld then
            targetMacroRebirth = viableRebirths[highestUnlockedIdx] or viableRebirths[#viableRebirths]
            for i = #viableRebirths, 1, -1 do
                local r = viableRebirths[i]
                if r.IsAffordable and r.Price > 0 and r.Index >= highestUnlockedIdx and coinVelocity > 0 then
                    bestAffordableRebirth = r
                    bestScore = 1000 + r.Amount
                    break
                end
            end
        else
            for _, r in ipairs(viableRebirths) do
                if r.IsAffordable and r.NetDeltaSeconds > 0 and r.ProgressionScore > bestScore then
                    bestScore = r.ProgressionScore
                    bestAffordableRebirth = r
                end
                if r.NetDeltaSeconds > bestMilestoneDelta and coinVelocity > 0 then
                    bestMilestoneDelta = r.NetDeltaSeconds
                    targetMilestoneRebirth = r
                end
                if r.MultGainPct > bestMacroGain and r.GrossRecoveryTime <= 300 and coinVelocity > 0 then
                    bestMacroGain = r.MultGainPct
                    targetMacroRebirth = r
                end
            end
            if bestScore <= 0 then bestAffordableRebirth = nil end
        end

        -- Near-Island Capital Sprint (Scoped strictly to current world currency)
        local timeToNextIsland = math.huge
        local dynamicSaveThreshold = 0.50
        if stage == "Early Game" then dynamicSaveThreshold = 0.75
        elseif stage == "Mid Game" then dynamicSaveThreshold = 0.60
        elseif stage == "Late Game" then dynamicSaveThreshold = 0.50
        else dynamicSaveThreshold = 0.40 end

        local isNearIslandSprint = false
        local targetIslandCoins = coins
        if snap.nextIsl then
            targetIslandCoins = snap.nextIsl.isRift and (snap.riftCoins or coins) or (snap.mainCoins or coins)
            local dist = math.max(0, snap.nextIsl.price - targetIslandCoins)
            timeToNextIsland = (coinVelocity > 0) and (dist / coinVelocity) or math.huge
            local recoveryBaseline = (bestAffordableRebirth and bestAffordableRebirth.RecoveryTime ~= math.huge and bestAffordableRebirth.RecoveryTime) or 30
            if targetIslandCoins >= snap.nextIsl.price * dynamicSaveThreshold
                or (coinVelocity > 0 and timeToNextIsland <= math.max(30, recoveryBaseline * 1.5)) then
                isNearIslandSprint = true
            end
        end

        -- Choose optimal batch size K (8 / 3 / 1) using exact Binomial gains
        local function chooseOptimalHatchBatch(budgetCoins)
            if not bestUpgradeEgg or freeSlots < 1 or budgetCoins < bestUpgradeEgg.Price then
                return 0, 0
            end
            local g1 = bestUpgradeEgg.ExpectedEffectiveTeamGain or 0
            local g3 = bestUpgradeEgg.ExpectedTripleEffectiveTeamGain or (g1 * 3)
            local g8 = bestUpgradeEgg.ExpectedOctoEffectiveTeamGain or (g3 * 2.5)
            local p = bestUpgradeEgg.Price
            if snap.hasX8 and freeSlots >= 8 and budgetCoins >= (p * 8) and (g8 > g3 * 1.25 or isEndgameWorld) then
                return 8, g8
            elseif snap.allowTriple and freeSlots >= 3 and budgetCoins >= bestUpgradeEgg.TriplePrice and (g3 > g1 * 1.25 or isEndgameWorld) then
                return 3, g3
            end
            return 1, g1
        end

        local isActivelyHatching = (snap.allowHatch ~= false) and (freeSlots > 0) and (bestUpgradeEgg ~= nil) and not isNearIslandSprint
        local allowEndgameRebirth = (isEndgameWorld and bestAffordableRebirth ~= nil and bestAffordableRebirth.Index >= highestUnlockedIdx)
        local shouldRebirth = (snap.allowRebirth ~= false) and bestAffordableRebirth ~= nil and (allowEndgameRebirth or (bestAffordableRebirth.NetDeltaSeconds > 0 and bestAffordableRebirth.ProgressionScore > 0)) and not isNearIslandSprint

        -- Pre-Rebirth Surplus Hatching: spend excess coins above Rebirth price on beneficial eggs before Rebirth wipes Coins to 0!
        local preRebirthSurplus = shouldRebirth and math.max(0, coins - bestAffordableRebirth.Price) or 0
        local surplusBatchCount, surplusBatchGain = 0, 0
        if shouldRebirth and snap.allowHatch ~= false and freeSlots >= 1 and bestUpgradeEgg and preRebirthSurplus >= bestUpgradeEgg.Price then
            surplusBatchCount, surplusBatchGain = chooseOptimalHatchBatch(preRebirthSurplus)
        end

        -- Primary Action Plan Arbitration
        local decisionType = "FarmSave"
        local chosenHatchCount, chosenHatchGain = 0, 0
        if snap.bridgeStatus and not snap.bridgeStatus.lowered then
            decisionType = snap.bridgeStatus.ready and "PushBridge" or "ChargeBridge"
        elseif snap.w2Unlocked and curWorld == "Main" then
            decisionType = "TravelWorld2"
        elseif (snap.allowIslandUnlock ~= false) and snap.nextIsl and targetIslandCoins >= snap.nextIsl.price and (not snap.bridgeStatus or snap.bridgeStatus.lowered) then
            decisionType = "UnlockIsland"
        elseif isNearIslandSprint and snap.nextIsl then
            decisionType = "SaveIslandSprint"
        elseif shouldRebirth and surplusBatchCount > 0 then
            decisionType = "PreRebirthSurplusHatch"
            chosenHatchCount = surplusBatchCount
            chosenHatchGain = surplusBatchGain
        elseif shouldRebirth then
            decisionType = "Rebirth"
        elseif snap.allowHatch ~= false and freeSlots > 0 and bestUpgradeEgg and coins >= bestUpgradeEgg.Price then
            chosenHatchCount, chosenHatchGain = chooseOptimalHatchBatch(coins)
            if chosenHatchCount > 0 then
                decisionType = "HatchEgg"
            end
        elseif snap.allowHatch ~= false and freeSlots <= 0 and bestUpgradeEgg and coins >= bestUpgradeEgg.Price then
            decisionType = "WaitForBagClean"
        elseif snap.allowHatch ~= false and bestUpgradeEgg and isTeamSaturated == false and (coinVelocity <= 0 or ((bestUpgradeEgg.Price - coins) / math.max(coinVelocity, 1)) <= maxSaveTime) then
            decisionType = "SaveForEgg"
        elseif targetMilestoneRebirth or targetMacroRebirth then
            decisionType = "SaveForRebirth"
        elseif snap.nextIsl then
            decisionType = "SaveForIsland"
        end

        -- Apply Anti-Oscillation Hysteresis Lock for Save decisions
        local nowT = snap.now or os.clock()
        if (decisionType == "SaveForEgg" or decisionType == "SaveForRebirth" or decisionType == "SaveForIsland")
            and lockedDecision and lockedDecision.world == curWorld and nowT < (lockedDecision.lockUntil or 0) then
            local keepLocked = false
            if lockedDecision.decisionType == "SaveForEgg" and bestUpgradeEgg and bestUpgradeEgg.Name == lockedDecision.targetKey and coins < bestUpgradeEgg.Price then
                keepLocked = true
            elseif lockedDecision.decisionType == "SaveForRebirth" and (targetMilestoneRebirth or targetMacroRebirth) then
                local r = targetMilestoneRebirth or targetMacroRebirth
                if r.Index == lockedDecision.targetKey and coins < r.Price then
                    keepLocked = true
                end
            elseif lockedDecision.decisionType == "SaveForIsland" and snap.nextIsl and snap.nextIsl.name == lockedDecision.targetKey then
                keepLocked = true
            end
            if keepLocked and decisionType ~= lockedDecision.decisionType then
                decisionType = lockedDecision.decisionType
            end
        end

        local newLock = lockedDecision
        if decisionType == "SaveForEgg" and bestUpgradeEgg then
            if not lockedDecision or lockedDecision.decisionType ~= decisionType or lockedDecision.targetKey ~= bestUpgradeEgg.Name or nowT >= (lockedDecision.lockUntil or 0) then
                newLock = { decisionType = decisionType, targetKey = bestUpgradeEgg.Name, world = curWorld, lockUntil = nowT + ((CONFIG.Scoring and CONFIG.Scoring.DecisionLockSeconds) or 10) }
            end
        elseif decisionType == "SaveForRebirth" and (targetMilestoneRebirth or targetMacroRebirth) then
            local r = targetMilestoneRebirth or targetMacroRebirth
            if not lockedDecision or lockedDecision.decisionType ~= decisionType or lockedDecision.targetKey ~= r.Index or nowT >= (lockedDecision.lockUntil or 0) then
                newLock = { decisionType = decisionType, targetKey = r.Index, world = curWorld, lockUntil = nowT + ((CONFIG.Scoring and CONFIG.Scoring.DecisionLockSeconds) or 10) }
            end
        elseif decisionType == "SaveForIsland" and snap.nextIsl then
            if not lockedDecision or lockedDecision.decisionType ~= decisionType or lockedDecision.targetKey ~= snap.nextIsl.name or nowT >= (lockedDecision.lockUntil or 0) then
                newLock = { decisionType = decisionType, targetKey = snap.nextIsl.name, world = curWorld, lockUntil = nowT + ((CONFIG.Scoring and CONFIG.Scoring.DecisionLockSeconds) or 10) }
            end
        else
            newLock = nil
        end

        return {
            Engine = "NEW",
            Stage = stage,
            World = curWorld,
            Island = curIsland,
            DecisionType = decisionType,
            BestEggName = bestUpgradeEgg and bestUpgradeEgg.Name or nil,
            BestEgg = bestUpgradeEgg,
            BestEggGain = bestUpgradeEgg and bestUpgradeEgg.ExpectedEffectiveTeamGain or 0,
            HatchCount = chosenHatchCount,
            HatchGain = chosenHatchGain,
            BestRebirthIndex = bestAffordableRebirth and bestAffordableRebirth.Index or nil,
            BestRebirthAmount = bestAffordableRebirth and bestAffordableRebirth.ActualAmount or 0,
            BestRebirth = bestAffordableRebirth,
            BestRebirthScore = bestScore > -math.huge and bestScore or 0,
            TargetMilestoneRebirth = targetMilestoneRebirth,
            TargetMacroRebirth = targetMacroRebirth,
            ViableRebirths = viableRebirths,
            HighestUnlockedIdx = highestUnlockedIdx,
            ActiveGoldenChance = activeGoldenChance,
            ActiveDiamondChance = activeDiamondChance,
            ActiveShinyChance = activeShinyChance,
            PredictedVelocity = predictedVelocity,
            CoinVelocity = coinVelocity,
            NearIslandSprint = isNearIslandSprint,
            IsSavingForIsland = isNearIslandSprint,
            IsActivelyHatching = isActivelyHatching,
            IsTeamSaturated = isTeamSaturated,
            IsEndgameWorld = isEndgameWorld,
            TimeToNextIsland = timeToNextIsland,
            TargetIslandCoins = targetIslandCoins,
            CandidateEggs = candidateEggs,
            CandidateEggCount = #allUpgradeEggs,
            DecisionLock = newLock,
        }
    end

    local function runShadowComparison(snapshotOrLive)
        local snap = snapshotOrLive or buildLiveSnapshot()
        if not snap then return nil end

        local oldRes = evaluateKaitunStrategyOld(snap)
        local newRes = evaluateKaitunStrategy(snap, KaitunState.LockedDecision)

        local diffs = {}
        if math.abs((oldRes.ActiveGoldenChance or 0) - (newRes.ActiveGoldenChance or 0)) > 0.05 then
            table.insert(diffs, string.format("Golden%%: %.0f%% -> %.1f%%", (oldRes.ActiveGoldenChance or 0) * 100, (newRes.ActiveGoldenChance or 0) * 100))
        end
        if oldRes.CandidateEggCount ~= newRes.CandidateEggCount then
            table.insert(diffs, string.format("EligibleEggs: %d -> %d", oldRes.CandidateEggCount, newRes.CandidateEggCount))
        end
        if oldRes.DecisionType ~= newRes.DecisionType then
            table.insert(diffs, string.format("Action: %s -> %s", tostring(oldRes.DecisionType), tostring(newRes.DecisionType)))
        end
        if oldRes.BestEggName ~= newRes.BestEggName then
            table.insert(diffs, string.format("Egg: %s -> %s", tostring(oldRes.BestEggName), tostring(newRes.BestEggName)))
        end
        if (newRes.PredictedVelocity or 0) > 0 and math.abs((oldRes.PredictedVelocity or 0) - (newRes.PredictedVelocity or 0)) / math.max(1, newRes.PredictedVelocity) > 0.15 then
            table.insert(diffs, string.format("PredVel: %s -> %s/s", formatCompact(oldRes.PredictedVelocity), formatCompact(newRes.PredictedVelocity)))
        end

        local summaryShort = (#diffs > 0) and table.concat(diffs, " | ") or string.format("Aligned (%s | Egg=%s)", newRes.DecisionType, tostring(newRes.BestEggName or "None"))
        local report = {
            Old = oldRes,
            New = newRes,
            Changed = (oldRes.DecisionType ~= newRes.DecisionType) or (oldRes.BestEggName ~= newRes.BestEggName) or (#diffs > 0),
            Deltas = diffs,
            SummaryShort = summaryShort,
        }
        if snapshotOrLive == nil then
            KaitunState.ShadowReport = report
        end
        return report
    end

    ctx.API.updateKaitunDisplays = updateKaitunDisplays
    ctx.API.getFrontierRebirthInfo = getFrontierRebirthInfo
    ctx.API.determineProgressionStage = determineProgressionStage
    ctx.API.getBoostFingerprint = getBoostFingerprint
    ctx.API.getPhysicalCurrentIsland = getPhysicalCurrentIsland
    ctx.API.invalidateVelocityMeasurement = invalidateVelocityMeasurement
    ctx.API.computePredictedVelocity = computePredictedVelocity
    ctx.API.updateVelocityMeasurement = updateVelocityMeasurement
    ctx.API.getActiveTierChances = getActiveTierChances
    ctx.API.computeExactMultiHatchGain = computeExactMultiHatchGain
    ctx.API.evaluateEggTrueStats = evaluateEggTrueStats
    ctx.API.calculateProgressionScore = calculateProgressionScore
    ctx.API.rankSkillUpgrades = rankSkillUpgrades
    ctx.API.buildLiveSnapshot = buildLiveSnapshot
    ctx.API.evaluateKaitunStrategyOld = evaluateKaitunStrategyOld
    ctx.API.evaluateKaitunStrategy = evaluateKaitunStrategy
    ctx.API.runShadowComparison = runShadowComparison

    KaitunTelemetry.VelocityTracker = VelocityTracker
    KaitunTelemetry.updateKaitunDisplays = updateKaitunDisplays
    KaitunTelemetry.getFrontierRebirthInfo = getFrontierRebirthInfo
    KaitunTelemetry.determineProgressionStage = determineProgressionStage
    KaitunTelemetry.getBoostFingerprint = getBoostFingerprint
    KaitunTelemetry.getPhysicalCurrentIsland = getPhysicalCurrentIsland
    KaitunTelemetry.invalidateVelocityMeasurement = invalidateVelocityMeasurement
    KaitunTelemetry.computePredictedVelocity = computePredictedVelocity
    KaitunTelemetry.updateVelocityMeasurement = updateVelocityMeasurement
    KaitunTelemetry.getActiveTierChances = getActiveTierChances
    KaitunTelemetry.computeExactMultiHatchGain = computeExactMultiHatchGain
    KaitunTelemetry.evaluateEggTrueStats = evaluateEggTrueStats
    KaitunTelemetry.calculateProgressionScore = calculateProgressionScore
    KaitunTelemetry.rankSkillUpgrades = rankSkillUpgrades
    KaitunTelemetry.buildLiveSnapshot = buildLiveSnapshot
    KaitunTelemetry.evaluateKaitunStrategyOld = evaluateKaitunStrategyOld
    KaitunTelemetry.evaluateKaitunStrategy = evaluateKaitunStrategy
    KaitunTelemetry.runShadowComparison = runShadowComparison
    ctx.KaitunTelemetry = KaitunTelemetry
    return KaitunTelemetry
end

return KaitunTelemetry
