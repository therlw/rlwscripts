-- src/UI/Tabs/EventsTab.lua
-- Tab 7: Events & Machines (Castle Update Systems: Global Events, Glitched Egg, Potion, HoneyPot, Lucky Egg, Expeditions)

local EventsTab = {}

function EventsTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local ConfigManager = ctx.ConfigManager
    local MachineState = ctx.States.Machine
    local EventState = ctx.States.Event
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle

    local refreshGlobalEventsSummary = ctx.API.refreshGlobalEventsSummary
    local runPotionMachineCycle = ctx.API.runPotionMachineCycle
    local runHoneyPotCycle = ctx.API.runHoneyPotCycle
    local collectReadyExpeditions = ctx.API.collectReadyExpeditions
    local ackGlitchedEggTier = ctx.API.ackGlitchedEggTier

    UI.EventsTab = Window:CreateTab({ name = "Events & Machines", icon = 93364949241311 })
    UI.EventsTab:CreateSection({ name = "Global & Timed World Events" })

    UI.EventStatusText = UI.EventsTab:CreateText({
        name = "Active World Events",
        text = EventState.LastActiveSummary
    })

    createBoundToggle(UI.EventsTab, {
        name = "Monitor Global Events",
        flag = "MonitorGlobalEvents",
        description = "Polls GlobalEventService & BalloonPartyService live states",
        value = true,
    }, function() return EventState.MonitorGlobalEvents end, function(v) EventState.MonitorGlobalEvents = v end)

    UI.EventsTab:CreateButton({
        name = "Refresh Active Events Now",
        callback = function()
            task.spawn(function()
                local summary = refreshGlobalEventsSummary()
                if UI.EventStatusText and UI.EventStatusText.Set then
                    pcall(function() UI.EventStatusText:Set(summary) end)
                end
                safeNotify({ title = "Global Events", content = summary })
            end)
        end
    })

    UI.EventsTab:CreateSection({ name = "Glitched Egg & Evolution (Castle Island)" })

    UI.GlitchedStatusText = UI.EventsTab:CreateText({
        name = "Glitched Egg Progress",
        text = "Reading tier info..."
    })

    createBoundToggle(UI.EventsTab, {
        name = "Auto Acknowledge Glitched Tiers",
        flag = "AutoGlitchedAck",
        description = "Automatically acknowledges newly unlocked Glitched Egg luck tiers via GlitchedEggService",
        value = false,
    }, function() return MachineState.AutoGlitchedAck end, function(v) MachineState.AutoGlitchedAck = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Evolve Glitched Secrets (Opt-In)",
        flag = "AutoGlitchedEvolve",
        description = "CAUTION: Opt-in only! Automatically evolves 3x Glitched Secret copies when unlocked at Castle Island",
        value = false,
    }, function() return MachineState.AutoGlitchedEvolve end, function(v) MachineState.AutoGlitchedEvolve = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Glitched Evo: Consume Equipped Copies",
        flag = "GlitchedConsumeEquipped",
        description = "Allow Glitched Evolution to consume currently equipped secret copies",
        value = false,
    }, function() return MachineState.GlitchedEvolveConsumeEquipped end, function(v) MachineState.GlitchedEvolveConsumeEquipped = v end)

    UI.EventsTab:CreateSection({ name = "Potion Machine (Buy / Craft II / Claim)" })

    createBoundToggle(UI.EventsTab, {
        name = "Auto Claim Finished Potions",
        flag = "AutoPotionClaim",
        value = false,
    }, function() return MachineState.AutoPotionClaim end, function(v) MachineState.AutoPotionClaim = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Craft Potion II (Coins/Luck/Gems)",
        flag = "AutoPotionCraft",
        value = false,
    }, function() return MachineState.AutoPotionCraft end, function(v) MachineState.AutoPotionCraft = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Buy Potions",
        flag = "AutoPotionBuy",
        value = false,
    }, function() return MachineState.AutoPotionBuy end, function(v) MachineState.AutoPotionBuy = v end)

    UI.PotionAmtDropdown = UI.EventsTab:CreateDropdown({
        name = "Potion Buy Batch Size",
        flag = "PotionBuyAmount",
        options = { "1", "3", "10" },
        value = tostring(MachineState.PotionBuyAmount or 1),
        callback = function(selected)
            local opt = type(selected) == "table" and selected[1] or selected
            MachineState.PotionBuyAmount = tonumber(opt) or 1
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("PotionBuyAmount", UI.PotionAmtDropdown, function() return tostring(MachineState.PotionBuyAmount or 1) end, function(v)
        MachineState.PotionBuyAmount = tonumber(v) or 1
    end)

    UI.EventsTab:CreateSection({ name = "HoneyPot, Lucky Egg Machine & Expeditions" })

    UI.HoneyPotDropdown = UI.EventsTab:CreateDropdown({
        name = "HoneyPot Recipe",
        flag = "HoneyPotRecipe",
        options = { "BagOfTreats", "GoldenApple", "DragonFruit", "RainbowStrawberry", "SecretFruit", "PetXP3x", "PetClicks2x", "PetLevels10" },
        value = MachineState.HoneyPotRecipe,
        callback = function(selected)
            local opt = type(selected) == "table" and selected[1] or selected
            if opt then MachineState.HoneyPotRecipe = opt end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("HoneyPotRecipe", UI.HoneyPotDropdown, function() return MachineState.HoneyPotRecipe end, function(v) MachineState.HoneyPotRecipe = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Claim HoneyPot Slots",
        flag = "AutoHoneyPotClaim",
        value = false,
    }, function() return MachineState.AutoHoneyPotClaim end, function(v) MachineState.AutoHoneyPotClaim = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Craft HoneyPot Recipe",
        flag = "AutoHoneyPotCraft",
        value = false,
    }, function() return MachineState.AutoHoneyPotCraft end, function(v) MachineState.AutoHoneyPotCraft = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Activate Lucky Egg Machine (Heaven)",
        flag = "AutoLuckyEggMachine",
        value = false,
    }, function() return MachineState.AutoLuckyEggMachine end, function(v) MachineState.AutoLuckyEggMachine = v end)

    createBoundToggle(UI.EventsTab, {
        name = "Auto Collect Ready Expeditions",
        flag = "AutoExpeditionCollect",
        value = false,
    }, function() return MachineState.AutoExpeditionCollect end, function(v) MachineState.AutoExpeditionCollect = v end)

    UI.EventsTab:CreateButton({
        name = "Run Claim & Collect Machines Now",
        callback = function()
            task.spawn(function()
                local pAct = runPotionMachineCycle(false, false, true)
                local hAct = runHoneyPotCycle(true, false, MachineState.HoneyPotRecipe)
                local expOk = collectReadyExpeditions()
                ackGlitchedEggTier()
                safeNotify({
                    title = "Machines & Expeditions",
                    content = string.format("Potions=%d | HoneyPot=%d | Expedition=%s", pAct, hAct, tostring(expOk))
                })
            end)
        end
    })

    return EventsTab
end

return EventsTab
