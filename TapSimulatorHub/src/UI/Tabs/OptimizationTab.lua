-- src/UI/Tabs/OptimizationTab.lua
-- Tab: Optimization (CPU Saver & Emergency World Geometry Restore)

local OptimizationTab = {}

function OptimizationTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local ConfigManager = ctx.ConfigManager
    local safeNotify = UI.safeNotify

    UI.OptimizationTab = Window:CreateTab({ name = "Optimization", icon = 93364949241311 })
    UI.OptimizationTab:CreateSection({ name = "Resource & Performance Control" })

    UI.OptCpuSaverToggle = UI.OptimizationTab:CreateToggle({
        name = "CPU Saver",
        flag = "OptimizationCpuSaver",
        description = "Dramatically reduces CPU and GPU load by pausing decorative particles, cosmetic pet meshes, lighting shadows, and capping FPS to 15.",
        value = false,
        callback = function(val)
            if ctx.API.setCpuSaverState then ctx.API.setCpuSaverState(val) end
            ConfigManager:MarkDirty()
        end
    })

    UI.OptimizationTab:CreateButton({
        name = "Emergency Restore All Culled World Parts",
        callback = function()
            if ctx.API.restoreAllCulledInstances then
                pcall(ctx.API.restoreAllCulledInstances)
            end
            safeNotify({ title = "World Restored", content = "Restored all temporarily culled map geometry." })
        end
    })

    return OptimizationTab
end

return OptimizationTab
