-- src/Systems/PumpkinTycoon/EventCoordinator.lua
-- Unified Priority Coordinator for All Pumpkin Tycoon Subsystems

local EventCoordinator = {}

function EventCoordinator.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local States = ctx.States

    local Coordinator = {}

    function Coordinator.StepOnce()
        if not Net.IsInPumpkinTycoon() then
            ctx.Runtime.Status.Event = "Waiting: Enter Pumpkin Patch Tycoon instance"
            return
        end
        if Net.GetFFlag("PumpkinTycoon_Enabled", true) ~= true then
            ctx.Runtime.Status.Event = "Pumpkin Tycoon is currently disabled by server FFlag"
            return
        end

        local WT = ctx.WildAndTurkey
        local Prog = ctx.TycoonProgression
        local Econ = ctx.PumpkinEconomy

        -- 1. Highest priority: Rare Huge/Titanic/Gargantuan spawn & active Turkey fight
        if WT and WT.TryCatchRareSpawn() then return end
        if WT and WT.TryFightTurkey() then
            -- While fighting Turkey, also keep boosts/hunt/nets/auto-merchant synced passively
            if Prog then Prog.TryOpenFlannelGifts() end
            if Econ then Econ.TryUsePumpkinBoosts() end
            return
        end

        -- 2. Core Tycoon Progression (Rebirth -> Island Reward -> Buttons)
        if Prog then
            if Prog.TryAutoRebirth() then return end
            if Prog.TryStepButtonsAndReward() then return end
        end

        -- 3. Wild Pets + Pet Net Store + Auto Hunt
        if WT then
            WT.TrySyncAutoHunt()
            if WT.TryBuyPetNets() then return end
            if WT.TryCatchWildPets() then return end
        end

        -- 4. Upgrades, Cocoa Boosts, Consumable Boosts, Flannel Gifts
        if Prog and Prog.TryBuyUpgrades() then return end
        if Econ then
            if Econ.TryBuyCocoaBoosts() then return end
            Econ.TryUsePumpkinBoosts()
        end
        if Prog and Prog.TryOpenFlannelGifts() then return end

        -- 5. Merchant, Planting, Keep Rule, Island AutoBreak, Eggs
        if Econ then
            Econ.TryMerchantAndPlant()
            Econ.TrySyncKeepRule()
            Econ.TryAutoBreakPumpkins()
            if Econ.TryTeleportBestEgg() then return end
            Econ.TryBuyNearestEgg()
        end
    end

    function Coordinator.FormatStatusSummary()
        local coins = Net.GetPumpkinCoins()
        local tokens = Net.GetPumpkinTokens()
        local pNets = Net.GetMiscCount("Pet Net")
        local uNets = Net.GetMiscCount("Ultra Pet Net")
        local te = ctx.Runtime.Telemetry
        local part2Txt = Net.OwnPlotPart2() and "P2 Built" or "P1"

        return string.format(
            "%s | Coins: %s | Tokens: %s | Nets: %d / Ultra: %d\nAction: %s\nCoinSave: %s | Buttons: %d | Eggs: %d | Rare: %d",
            part2Txt,
            Utils.formatCompact(coins),
            Utils.formatCompact(tokens),
            pNets,
            uNets,
            tostring(ctx.Runtime.Status.Event),
            tostring(te.CoinSaveReason),
            te.ButtonsBought,
            te.EggsHatched,
            te.RareAttempts
        )
    end

    function EventCoordinator.Start()
        Lifecycle.SpawnLoop("PumpkinEventCoordinator", function()
            return ctx.Config.MainWorkerInterval or 0.35
        end, function()
            Coordinator.StepOnce()
        end)

        Lifecycle.SpawnLoop("PumpkinStatusUpdater", 0.75, function()
            local UI = ctx.UI
            if UI and UI.PumpkinStatusText and UI.PumpkinStatusText.Set then
                pcall(function()
                    UI.PumpkinStatusText:Set(Coordinator.FormatStatusSummary())
                end)
            end
            if UI and UI.FarmStatusText and UI.FarmStatusText.Set then
                pcall(function()
                    UI.FarmStatusText:Set(string.format("%s | Taps: %d", tostring(ctx.Runtime.Status.Farm), ctx.Runtime.Telemetry.TurkeyHits))
                end)
            end
        end)
    end

    ctx.EventCoordinator = Coordinator
    ctx.API.stepPumpkinCoordinator = Coordinator.StepOnce
    return Coordinator
end

return EventCoordinator
