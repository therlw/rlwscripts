-- src/UI/Tabs/KaitunTab.lua
-- Tab 0: AI Kaitun (Autonomous Master Engine)

local KaitunTab = {}

function KaitunTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local ConfigManager = ctx.ConfigManager
    local KaitunState = ctx.States.Kaitun
    local OptimizationState = ctx.States.Optimization
    local safeCall = ctx.Utils.safeCall
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle

    UI.KaitunTab = Window:CreateTab({ name = "AI Kaitun", icon = 93364949241311 })
    UI.KaitunTab:CreateSection({ name = "Autonomous Brain Control" })

    UI.KaitunGoalText = nil
    UI.KaitunActionText = nil
    UI.KaitunStageText = nil
    UI.KaitunStrategyText = nil
    UI.KaitunPriorityText = nil
    UI.KaitunVelocityText = nil

    UI.KaitunMasterToggle = UI.KaitunTab:CreateToggle({
        name = "Enable AI Kaitun",
        flag = "KaitunEnabled",
        description = "Autonomous AI manages account progression from zero to endgame. Does NOT affect manual toggles.",
        value = KaitunState.Enabled,
        callback = function(val)
            KaitunState.Enabled = val
            ConfigManager:MarkDirty()
            if val then
                KaitunState.CurrentGoal = "Evaluating Account State..."
                KaitunState.CurrentAction = "Activating Autonomous Engine..."
                KaitunState.StrategyNote = "Analyzing best progression path..."
                safeNotify({
                    title = "AI Kaitun Activated!",
                    content = "Autonomous progression is now active. Kaitun will evaluate state and optimize growth!"
                })
                task.spawn(function()
                    if ctx.API.runKaitunCycle then
                        safeCall("KaitunToggle:runKaitunCycle", ctx.API.runKaitunCycle)
                    end
                    if ctx.API.updateKaitunDisplays then
                        safeCall("KaitunToggle:updateKaitunDisplays", ctx.API.updateKaitunDisplays)
                    end
                end)
            else
                KaitunState.CurrentGoal = "Standby (Kaitun Disabled)"
                KaitunState.CurrentAction = "Idle"
                KaitunState.StrategyNote = "Turn on AI Kaitun to begin autonomous progression"
                safeNotify({
                    title = "AI Kaitun Deactivated",
                    content = "Autonomous engine stopped. Other manual features remain unaffected."
                })
            end
            if ctx.API.updateKaitunDisplays then
                safeCall("KaitunToggle:updateKaitunDisplays", ctx.API.updateKaitunDisplays)
            end
        end
    })
    ConfigManager:Bind("KaitunEnabled", UI.KaitunMasterToggle, function() return KaitunState.Enabled end, function(v) KaitunState.Enabled = v end)

    UI.KaitunTab:CreateSection({ name = "Live AI Telemetry & Strategy" })

    pcall(function()
        UI.KaitunGoalText = UI.KaitunTab:CreateText({ name = "Current Goal", text = "Standby (Kaitun Disabled)" })
    end)
    pcall(function()
        UI.KaitunActionText = UI.KaitunTab:CreateText({ name = "Live Action", text = "Idle" })
    end)
    pcall(function()
        UI.KaitunStageText = UI.KaitunTab:CreateText({ name = "Account Stage", text = "Analyzing..." })
    end)
    pcall(function()
        UI.KaitunStrategyText = UI.KaitunTab:CreateText({ name = "Strategic Reasoning", text = "Turn on AI Kaitun to begin autonomous progression" })
    end)
    pcall(function()
        UI.KaitunPriorityText = UI.KaitunTab:CreateText({ name = "Dynamic Priorities", text = "1. Evaluating account state..." })
    end)
    pcall(function()
        UI.KaitunVelocityText = UI.KaitunTab:CreateText({ name = "Coin Velocity Telemetry", text = "Predicted: Calculating... | Measured: Initializing..." })
    end)
    pcall(function()
        UI.KaitunTab:CreateButton({
            name = "Run Shadow Audit (Old vs New - Read Only)",
            description = "Safely runs Old vs Upgraded Kaitun math on your live account snapshot without triggering any in-game remotes",
            callback = function()
                if ctx.API.runShadowComparison then
                    local ok, report = pcall(ctx.API.runShadowComparison)
                    if ok and report then
                        if ctx.API.updateKaitunDisplays then
                            pcall(ctx.API.updateKaitunDisplays)
                        end
                        safeNotify({
                            title = "Shadow Audit Complete",
                            content = tostring(report.SummaryShort or "Evaluated cleanly"),
                            duration = 6,
                        })
                    end
                end
            end
        })
    end)

    UI.KaitunTab:CreateSection({ name = "Decision Modules & Rules" })

    createBoundToggle(UI.KaitunTab, {
        name = "Autonomous Rebirths (Best / Frontier Tier)",
        flag = "KaitunAllowRebirth",
        description = "AI always targets and buys the highest unlocked rebirth tier (+10M -> +50M -> +250M) to unlock new tiers without wasting coins on lower tiers",
        value = true,
    }, function() return KaitunState.AllowRebirth end, function(v) KaitunState.AllowRebirth = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Smart Egg Hatching",
        flag = "KaitunAllowHatch",
        description = "AI hatches the best affordable egg, auto-pausing when inventory is full",
        value = true,
    }, function() return KaitunState.AllowHatch end, function(v) KaitunState.AllowHatch = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Smart Triple Hatch (3x If Affordable)",
        flag = "KaitunAllowTripleHatch",
        description = "Automatically hatches 3x when coins >= 3x egg price and free slots >= 3, seamlessly falling back to 1x when tight on budget",
        value = true,
    }, function() return KaitunState.AllowTripleHatch end, function(v) KaitunState.AllowTripleHatch = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Gem Skill Tree",
        flag = "KaitunAllowSkillTree",
        description = "AI purchases high-value honeycomb nodes (Click Power, Hatch Speed, Pet Power)",
        value = true,
    }, function() return KaitunState.AllowSkillTree end, function(v) KaitunState.AllowSkillTree = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Island Progression",
        flag = "KaitunAllowIslandUnlock",
        description = "AI lowers drawbridges and unlocks portals as soon as affordable",
        value = true,
    }, function() return KaitunState.AllowIslandUnlock end, function(v) KaitunState.AllowIslandUnlock = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Collectibles & Rewards",
        flag = "KaitunAllowChests",
        description = "AI claims free in-game chests and daily rewards",
        value = true,
    }, function() return KaitunState.AllowChestsAndStars end, function(v) KaitunState.AllowChestsAndStars = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Auto Trash Cleaning (Smart Inventory)",
        flag = "KaitunAllowTrashCleaning",
        description = "Safely deletes obsolete trash pets when storage < 5 free slots to prevent farming stops",
        value = true,
    }, function() return KaitunState.AllowTrashCleaning end, function(v) KaitunState.AllowTrashCleaning = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Smart Potions & Boosts",
        flag = "KaitunAllowSmartBoosts",
        description = "Automatically uses Coins / Luck / Gems potions at the optimal progression stage without wasting",
        value = true,
    }, function() return KaitunState.AllowSmartBoosts end, function(v) KaitunState.AllowSmartBoosts = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Collect Shiny Stars (Permanent Buff)",
        flag = "KaitunCollectStars",
        description = "Physically approaches and collects Shiny Stars on unlocked islands to permanently double pet mutation chance",
        value = true,
    }, function() return KaitunState.CollectShinyStars end, function(v) KaitunState.CollectShinyStars = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Auto Pet Evolution (Golden & Diamond Machine)",
        flag = "KaitunAllowAutoCraft",
        description = "Automatically crafts 6x duplicate pets into Golden (3x power) and 5x into Diamond (7x power) at the machine",
        value = true,
    }, function() return KaitunState.AllowAutoCraft end, function(v) KaitunState.AllowAutoCraft = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Suppress Machine & Evolution UI",
        flag = "KaitunSuppressMachineUI",
        description = "Automatically hides and auto-dismisses the Golden & Diamond machine UI and 'Crafted! GOLDEN/DIAMOND' popups",
        value = true,
    }, function() return KaitunState.SuppressMachineUI end, function(v) KaitunState.SuppressMachineUI = v end)

    createBoundToggle(UI.KaitunTab, {
        name = "Auto Catch Lucky Ducky",
        flag = "KaitunAutoLuckyDucky",
        description = "Automatically clicks and catches the Lucky Ducky whenever it flies across your screen for massive free coin rewards",
        value = true,
    }, function() return KaitunState.AutoLuckyDucky end, function(v) KaitunState.AutoLuckyDucky = v end)

    UI.KaitunCpuSaverToggle = UI.KaitunTab:CreateToggle({
        name = "CPU Saver",
        flag = "KaitunCpuSaver",
        description = "Reduces CPU and GPU usage by freezing cosmetic pet meshes, decorative particles, and throttling frame rate to 15 FPS.",
        value = false,
        callback = function(val)
            if ctx.API.setCpuSaverState then ctx.API.setCpuSaverState(val) end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("KaitunCpuSaver", UI.KaitunCpuSaverToggle, function() return OptimizationState.CpuSaver end, function(v)
        if ctx.API.setCpuSaverState then ctx.API.setCpuSaverState(v) else OptimizationState.CpuSaver = v end
    end)

    return KaitunTab
end

return KaitunTab
