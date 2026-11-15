-- src/Systems/Pets/CastleMachines.lua
-- Castle Update Machines, Physical Upgrades, Quests, Glitched Tiers & Global Events

local CastleMachines = {}

function CastleMachines.Init(ctx)
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local MachineState = ctx.States.Machine
    local EventState = ctx.States.Event
    local getPlayerData = ctx.API.getPlayerData
    local safeInvoke = ctx.Utils.safeInvoke

    local function runPotionMachineCycle(allowBuy, allowCraft, allowClaim)
        local actions = 0
        if allowClaim and Svc.PotionMachineService then
            local res = safeInvoke(Svc.PotionMachineService, "RF", "ClaimAll")
            if type(res) == "table" and (res.Success or (res.Claimed and #res.Claimed > 0)) then
                actions = actions + 1
            end
        end
        if allowCraft and Svc.PotionMachineService then
            for _, outName in ipairs({ "Coins Potion II", "Luck Potion II", "Gems Potion II" }) do
                local res = safeInvoke(Svc.PotionMachineService, "RF", "Craft", outName)
                if type(res) == "table" and res.Success then
                    actions = actions + 1
                end
            end
        end
        if allowBuy and Svc.PotionMachineService then
            local amt = (MachineState and MachineState.PotionBuyAmount) or 1
            local res = safeInvoke(Svc.PotionMachineService, "RF", "Buy", amt)
            if type(res) == "table" and res.Success then
                actions = actions + 1
            end
        end
        return actions
    end

    local function runHoneyPotCycle(allowClaim, allowCraft, recipeKey)
        local actions = 0
        if allowClaim and Svc.HoneyPotService then
            local slotCount = (Mod.HoneyPotConfig and Mod.HoneyPotConfig.SlotCount) or 3
            for idx = 1, slotCount do
                local res = safeInvoke(Svc.HoneyPotService, "RF", "Claim", tostring(idx))
                if type(res) == "table" and res.Success then
                    actions = actions + 1
                end
            end
        end
        if allowCraft and Svc.HoneyPotService and recipeKey then
            local res = safeInvoke(Svc.HoneyPotService, "RF", "Craft", recipeKey, 1)
            if type(res) == "table" and res.Success then
                actions = actions + 1
            end
        end
        return actions
    end

    local function ackGlitchedEggTier()
        if not Svc.GlitchedEggService or not Mod.GlitchedEggTiers then return false end
        local data = getPlayerData()
        if not data then return false end
        local pendingTier = nil
        pcall(function()
            if Mod.GlitchedEggTiers.Read then
                local info = Mod.GlitchedEggTiers.Read(data)
                if type(info) == "table" and info.PendingUnlock then
                    pendingTier = info.PendingUnlock
                end
            end
        end)
        if pendingTier then
            local res = safeInvoke(Svc.GlitchedEggService, "RF", "AckTier", pendingTier)
            return type(res) == "table" and res.Success == true
        end
        return false
    end

    local function runGlitchedEvolutionOptIn()
        if not (MachineState and MachineState.AutoGlitchedEvolve and Svc.GlitchedEvolutionService and Mod.GlitchedEvolutionConfig) then
            return 0
        end
        local crafted = 0
        local consumeEq = MachineState.GlitchedEvolveConsumeEquipped == true
        for _, step in ipairs(Mod.GlitchedEvolutionConfig.Chain or {}) do
            for _, tierName in ipairs(Mod.GlitchedEvolutionConfig.Tiers or { "Normal", "Golden", "Diamond", "Shiny" }) do
                local res = safeInvoke(Svc.GlitchedEvolutionService, "RF", "Evolve", {
                    Stage = step.Index,
                    Tier = tierName,
                    ConsumeEquipped = consumeEq,
                })
                if type(res) == "table" and res.Success then
                    crafted = crafted + 1
                end
            end
        end
        return crafted
    end

    local function activateLuckyEggMachine()
        if not Svc.LuckyEggMachineService then return false end
        local res = safeInvoke(Svc.LuckyEggMachineService, "RF", "Activate")
        return type(res) == "table" and res.Success == true
    end

    local function collectReadyExpeditions()
        if not Svc.ExpeditionService then return false end
        local slot = (Mod.ExpeditionMapConfig and Mod.ExpeditionMapConfig.Regions and Mod.ExpeditionMapConfig.Regions.StarterIsles and Mod.ExpeditionMapConfig.Regions.StarterIsles.Slot) or "Regular"
        local res = safeInvoke(Svc.ExpeditionService, "RF", "Collect", slot)
        return type(res) == "table" and res.Success == true
    end

    local function purchasePhysicalUpgrades()
        if not (Svc.PhysicalUpgradeService and Mod.PhysicalUpgradeConfig and Mod.PhysicalUpgradeConfig.Lines) then return 0 end
        local data = getPlayerData()
        if not data then return 0 end
        local bought = 0
        local ownedMap = data.PhysicalUpgrades or {}
        local unlockedIslands = (data.Progression and data.Progression.UnlockedIslands) or {}
        local unlockedZones = (data.Progression and data.Progression.UnlockedZones) or {}

        for lineName, line in pairs(Mod.PhysicalUpgradeConfig.Lines) do
            if type(line) == "table" and type(line.Prices) == "table" then
                local currency = line.Currency or "Gems"
                local balance = (data.Currencies and data.Currencies[currency]) or 0
                local ownedLvl = tonumber(ownedMap[line.Key or lineName]) or 0
                local nextIdx = ownedLvl + 1
                local price = line.Prices[nextIdx]
                if type(price) == "number" and balance >= price then
                    local reqIsl = line.Islands and (line.Islands[nextIdx] or line.Islands[tostring(nextIdx)])
                    local islUnlocked = (not reqIsl) or (reqIsl == "Spawn") or (unlockedIslands[reqIsl] == true) or (unlockedZones[reqIsl] == true)
                    if islUnlocked then
                        local res = safeInvoke(Svc.PhysicalUpgradeService, "RF", "Purchase", {
                            Upgrade = lineName,
                            Index = nextIdx,
                        })
                        if type(res) == "table" and res.Success then
                            bought = bought + 1
                            task.wait(0.15)
                            data = getPlayerData() or data
                        end
                    end
                end
            end
        end
        return bought
    end

    local function claimAllReadyQuests()
        if not Svc.QuestService then return 0 end
        local data = getPlayerData()
        if not (data and data.Quests) then return 0 end
        local readyKeys = {}
        for k, v in pairs(data.Quests) do
            if type(v) == "table" and v.Completed and not v.Claimed then
                table.insert(readyKeys, k)
            end
        end
        if #readyKeys == 0 then return 0 end

        if Svc.QuestService:FindFirstChild("RF") and Svc.QuestService.RF:FindFirstChild("ClaimAllQuests") then
            local res = safeInvoke(Svc.QuestService, "RF", "ClaimAllQuests", { Quests = readyKeys })
            if type(res) == "table" and res.Success ~= false then
                return #readyKeys
            end
        end

        local claimed = 0
        for _, k in ipairs(readyKeys) do
            local res = safeInvoke(Svc.QuestService, "RF", "ClaimQuest", { Quest = k })
            if type(res) == "table" and res.Success ~= false then
                claimed = claimed + 1
            end
            task.wait(0.05)
        end
        return claimed
    end

    local function refreshGlobalEventsSummary()
        local parts = {}
        if Svc.GlobalEventService then
            local res = safeInvoke(Svc.GlobalEventService, "RF", "GetActiveStates")
            if type(res) == "table" then
                for _, ev in ipairs(res) do
                    if type(ev) == "table" and ev.Active then
                        local rem = ev.EndsAt and math.max(0, math.floor(ev.EndsAt - os.time())) or ev.Duration
                        table.insert(parts, string.format("%s x%s (%ss)", tostring(ev.EventType or "Event"), tostring(ev.Multiplier or 1), tostring(rem or "?")))
                    end
                end
            end
        end
        if Svc.BalloonPartyService and Svc.BalloonPartyService:FindFirstChild("RF") and Svc.BalloonPartyService.RF:FindFirstChild("GetActive") then
            local b = safeInvoke(Svc.BalloonPartyService, "RF", "GetActive")
            if type(b) == "table" and #b > 0 then
                table.insert(parts, string.format("BalloonParty (%d active)", #b))
            end
        end
        local summary = (#parts > 0) and table.concat(parts, " | ") or "No global timed events active right now"
        EventState.LastActiveSummary = summary
        return summary, parts
    end

    ctx.API.runPotionMachineCycle = runPotionMachineCycle
    ctx.API.runHoneyPotCycle = runHoneyPotCycle
    ctx.API.ackGlitchedEggTier = ackGlitchedEggTier
    ctx.API.runGlitchedEvolutionOptIn = runGlitchedEvolutionOptIn
    ctx.API.activateLuckyEggMachine = activateLuckyEggMachine
    ctx.API.collectReadyExpeditions = collectReadyExpeditions
    ctx.API.purchasePhysicalUpgrades = purchasePhysicalUpgrades
    ctx.API.claimAllReadyQuests = claimAllReadyQuests
    ctx.API.refreshGlobalEventsSummary = refreshGlobalEventsSummary

    CastleMachines.runPotionMachineCycle = runPotionMachineCycle
    CastleMachines.runHoneyPotCycle = runHoneyPotCycle
    CastleMachines.ackGlitchedEggTier = ackGlitchedEggTier
    CastleMachines.runGlitchedEvolutionOptIn = runGlitchedEvolutionOptIn
    CastleMachines.activateLuckyEggMachine = activateLuckyEggMachine
    CastleMachines.collectReadyExpeditions = collectReadyExpeditions
    CastleMachines.purchasePhysicalUpgrades = purchasePhysicalUpgrades
    CastleMachines.claimAllReadyQuests = claimAllReadyQuests
    CastleMachines.refreshGlobalEventsSummary = refreshGlobalEventsSummary
    return CastleMachines
end

function CastleMachines.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local MachineState = ctx.States.Machine
    local EventState = ctx.States.Event
    local UI = ctx.UI
    local getPlayerData = ctx.API.getPlayerData

    -- 7b. Castle Update Machines, Glitched Egg & Global Events Worker
    task.spawn(function()
        local lastEventPoll = 0
        while true do
            if not isCurrentGeneration() then break end
            local interval = math.max(3, tonumber(CONFIG.MachineCheckInterval) or 6)
            local now = os.clock()

            if EventState.MonitorGlobalEvents and (now - lastEventPoll >= (CONFIG.EventCheckInterval or 5)) then
                lastEventPoll = now
                pcall(function()
                    local summary = CastleMachines.refreshGlobalEventsSummary()
                    if UI.EventStatusText and UI.EventStatusText.Set then
                        UI.EventStatusText:Set(summary)
                    end
                end)
            end

            pcall(function()
                local data = getPlayerData()
                if UI.GlitchedStatusText and UI.GlitchedStatusText.Set and Mod.GlitchedEggTiers and Mod.GlitchedEggTiers.Read and data then
                    local okRead, info = pcall(Mod.GlitchedEggTiers.Read, data)
                    if okRead and type(info) == "table" then
                        UI.GlitchedStatusText:Set(string.format("Tier: %s | Pending Unlock: %s",
                            tostring(info.Tier or info.CurrentTier or 0), tostring(info.PendingUnlock or "None")))
                    end
                end
            end)

            if UI.refreshSecretAndWebhookLabels then
                pcall(UI.refreshSecretAndWebhookLabels)
            end

            if MachineState.AutoGlitchedAck then
                pcall(CastleMachines.ackGlitchedEggTier)
            end
            if MachineState.AutoGlitchedEvolve then
                pcall(CastleMachines.runGlitchedEvolutionOptIn)
            end
            if MachineState.AutoPotionBuy or MachineState.AutoPotionCraft or MachineState.AutoPotionClaim then
                pcall(CastleMachines.runPotionMachineCycle, MachineState.AutoPotionBuy, MachineState.AutoPotionCraft, MachineState.AutoPotionClaim)
            end
            if MachineState.AutoHoneyPotClaim or MachineState.AutoHoneyPotCraft then
                pcall(CastleMachines.runHoneyPotCycle, MachineState.AutoHoneyPotClaim, MachineState.AutoHoneyPotCraft, MachineState.HoneyPotRecipe)
            end
            if MachineState.AutoLuckyEggMachine then
                pcall(CastleMachines.activateLuckyEggMachine)
            end
            if MachineState.AutoExpeditionCollect then
                pcall(CastleMachines.collectReadyExpeditions)
            end

            task.wait(interval)
        end
    end)
end

return CastleMachines
