-- Manifest.lua
-- Ordered Module Registry for PS99PumpkinHub GitHub RAW Modular Loader

return {
    Name = "PS99PumpkinHub",
    Version = "PumpkinTycoon-Part2-v1.0",
    DefaultBranch = "main",

    Modules = {
        { id = "Core.Context", path = "src/Core/Context.lua", phase = "bootstrap", required = true },
        { id = "Core.Lifecycle", path = "src/Core/Lifecycle.lua", phase = "core", required = true },
        { id = "Core.Utils", path = "src/Core/Utils.lua", phase = "core", required = true },
        { id = "Core.NetworkBridge", path = "src/Core/NetworkBridge.lua", phase = "core", required = true },

        { id = "Services.ConfigManager", path = "src/Services/ConfigManager.lua", phase = "services", required = true },

        { id = "Systems.Movement.MovementController", path = "src/Systems/Movement/MovementController.lua", phase = "systems", required = true },
        { id = "Systems.Optimization.PumpkinOptimizer", path = "src/Systems/Optimization/PumpkinOptimizer.lua", phase = "systems", required = true },
        { id = "Systems.PumpkinTycoon.TycoonProgression", path = "src/Systems/PumpkinTycoon/TycoonProgression.lua", phase = "systems", required = true },
        { id = "Systems.PumpkinTycoon.PumpkinEconomy", path = "src/Systems/PumpkinTycoon/PumpkinEconomy.lua", phase = "systems", required = true },
        { id = "Systems.PumpkinTycoon.WildAndTurkey", path = "src/Systems/PumpkinTycoon/WildAndTurkey.lua", phase = "systems", required = true },
        { id = "Systems.PumpkinTycoon.EventCoordinator", path = "src/Systems/PumpkinTycoon/EventCoordinator.lua", phase = "systems", required = true },
        { id = "Systems.Farm.AutoTapEngine", path = "src/Systems/Farm/AutoTapEngine.lua", phase = "systems", required = true },

        { id = "UI.WindowManager", path = "src/UI/WindowManager.lua", phase = "ui", required = true },
        { id = "UI.Tabs.PumpkinTycoonTab", path = "src/UI/Tabs/PumpkinTycoonTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.FarmTab", path = "src/UI/Tabs/FarmTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.ConfigTab", path = "src/UI/Tabs/ConfigTab.lua", phase = "ui", required = true },
        { id = "UI.HubExports", path = "src/UI/HubExports.lua", phase = "ui", required = true },
    },
}
