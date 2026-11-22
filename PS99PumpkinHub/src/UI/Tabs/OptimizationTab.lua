-- src/UI/Tabs/OptimizationTab.lua
-- Optimization Tab: Breakables Models, Pets Rendering, Confetti Rendering, Game & Pumpkin Tycoon Optimizer

local OptimizationTab = {}

function OptimizationTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Opt = ctx.States.Optimization
    local createBoundToggle = UI.createBoundToggle

    local tab = Window:CreateTab({ name = "Optimization", icon = 93364949241311 })
    UI.OptimizationTab = tab

    tab:CreateSection({ name = "Rendering & Performance" })

    createBoundToggle(tab, {
        name = "Disable Breakables Model",
        flag = "OptDisableBreakables",
        description = "Hides breakable visual parts/FX cleanly without breaking targeting",
        value = Opt.DisableBreakablesModel,
    }, function() return Opt.DisableBreakablesModel end, function(v)
        Opt.DisableBreakablesModel = v
        if ctx.Optimizer and ctx.Optimizer.SetDisableBreakablesModel then
            ctx.Optimizer.SetDisableBreakablesModel(v)
        end
    end)

    createBoundToggle(tab, {
        name = "Disable Pets Rendering",
        flag = "OptDisablePets",
        description = "Hides rendered pets via PlayerPet SetVisible without losing damage",
        value = Opt.DisablePetsRendering,
    }, function() return Opt.DisablePetsRendering end, function(v)
        Opt.DisablePetsRendering = v
        if ctx.Optimizer and ctx.Optimizer.SetDisablePetsRendering then
            ctx.Optimizer.SetDisablePetsRendering(v)
        end
    end)

    createBoundToggle(tab, {
        name = "Disable Confetti Rendering",
        flag = "OptDisableConfetti",
        description = "Disables GUIFX.Confetti playback cleanly & reversibly",
        value = Opt.DisableConfettiRendering,
    }, function() return Opt.DisableConfettiRendering end, function(v)
        Opt.DisableConfettiRendering = v
        if ctx.Optimizer and ctx.Optimizer.SetDisableConfettiRendering then
            ctx.Optimizer.SetDisableConfettiRendering(v)
        end
    end)

    createBoundToggle(tab, {
        name = "Optimize Game",
        flag = "OptOptimizeGame",
        description = "Disables global shadows, post-effects, terrain deco & heavy particles",
        value = Opt.OptimizeGame,
    }, function() return Opt.OptimizeGame end, function(v)
        Opt.OptimizeGame = v
        if ctx.Optimizer and ctx.Optimizer.SetOptimizeGame then
            ctx.Optimizer.SetOptimizeGame(v)
        end
    end)

    createBoundToggle(tab, {
        name = "Optimize Pumpkin Tycoon",
        flag = "OptOptimizePT",
        description = "Syncs with Current Event Pumpkin Tycoon + Turkey island flash cleanup",
        value = Opt.OptimizePumpkinTycoon,
    }, function() return Opt.OptimizePumpkinTycoon end, function(v)
        Opt.OptimizePumpkinTycoon = v
        if ctx.Optimizer and ctx.Optimizer.SetEnabled then
            ctx.Optimizer.SetEnabled(v)
        end
        if UI.OptimizePTToggle and UI.OptimizePTToggle.Set then
            pcall(function() UI.OptimizePTToggle:Set(v, true) end)
        end
    end)

    return OptimizationTab
end

return OptimizationTab
