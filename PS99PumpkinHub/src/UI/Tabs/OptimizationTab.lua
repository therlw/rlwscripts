-- src/UI/Tabs/OptimizationTab.lua
-- Performans, FPS ve Bellek (RAM) Optimizasyonu Sekmesi

local OptimizationTab = {}

function OptimizationTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Opt = ctx.States.Optimization
    local PT = ctx.States.PumpkinTycoon

    local Tab = Window:CreateTab({
        name = "Optimizasyon",
        icon = 93364949241311,
    })
    UI.OptimizationTab = Tab

    Tab:CreateSection({ name = "Performans & Bellek Tasarrufu" })

    UI.OptOptimizePTToggle = UI.createBoundToggle(Tab, {
        name = "Pumpkin Tycoon Alanını Optimize Et",
        flag = "OptOptimizePT",
        value = Opt.OptimizePumpkinTycoon or PT.OptimizePumpkinTycoon,
        description = "Etkinlikteki ağaç, süs, diğer oyuncuların adaları ve fazla efektleri temizler",
    }, function()
        return Opt.OptimizePumpkinTycoon or PT.OptimizePumpkinTycoon
    end, function(v)
        local enabled = (v == true)
        Opt.OptimizePumpkinTycoon = enabled
        PT.OptimizePumpkinTycoon = enabled
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetEnabled then
            ctx.Optimizer.SetEnabled(v == true)
        end
        if UI.OptimizePTToggle and UI.OptimizePTToggle.Set then
            pcall(function()
                UI.OptimizePTToggle:Set(v == true, true)
            end)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Kırılabilir Modelleri Gizle (Breakables)",
        flag = "OptDisableBreakables",
        value = Opt.DisableBreakablesModel,
        description = "Yerdeki paraların/sandıkların 3D modellerini gizler (farm çalışmaya devam eder)",
    }, function()
        return Opt.DisableBreakablesModel
    end, function(v)
        Opt.DisableBreakablesModel = (v == true)
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetDisableBreakablesModel then
            ctx.Optimizer.SetDisableBreakablesModel(v == true)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Pet Modellerini Gizle (Pets)",
        flag = "OptDisablePets",
        value = Opt.DisablePetsRendering,
        description = "Sadece görsel petleri gizleyerek CPU ve GPU yükünü azaltır",
    }, function()
        return Opt.DisablePetsRendering
    end, function(v)
        Opt.DisablePetsRendering = (v == true)
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetDisablePetsRendering then
            ctx.Optimizer.SetDisablePetsRendering(v == true)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Konfeti & Partikül Efektlerini Kapat",
        flag = "OptDisableConfetti",
        value = Opt.DisableConfettiRendering,
        description = "Kutu açılışı ve patlamalardaki konfeti/partikül efektlerini engeller",
    }, function()
        return Opt.DisableConfettiRendering
    end, function(v)
        Opt.DisableConfettiRendering = (v == true)
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetDisableConfettiRendering then
            ctx.Optimizer.SetDisableConfettiRendering(v == true)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Genel Oyun Optimizasyonu (Potato Modu)",
        flag = "OptOptimizeGame",
        value = Opt.OptimizeGame,
        description = "Gölge, su yansıması ve PostEffect grafiklerini kapatıp maksimum FPS sağlar",
    }, function()
        return Opt.OptimizeGame
    end, function(v)
        Opt.OptimizeGame = (v == true)
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetOptimizeGame then
            ctx.Optimizer.SetOptimizeGame(v == true)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Makine & Tüccar GUI'lerini Gizle",
        flag = "OptHideMachineGuis",
        value = Opt.HideMachineGuis ~= false,
        description = "Gidilen makine, tüccar, kakao ve yükseltme pencerelerinin ekranda açılmasını engeller",
    }, function()
        return Opt.HideMachineGuis ~= false
    end, function(v)
        Opt.HideMachineGuis = (v == true)
    end, function(v)
        if ctx.Optimizer and ctx.Optimizer.SetHideMachineGuis then
            ctx.Optimizer.SetHideMachineGuis(v == true)
        end
    end)

    return OptimizationTab
end

return OptimizationTab
