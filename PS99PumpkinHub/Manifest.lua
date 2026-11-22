-- Manifest.lua
-- Ordered Module Registry for PS99Hub GitHub RAW Modular Loader

return {
    Name = "PS99PumpkinHub",
    Version = "PS99-Complete-v2.0",
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
        { id = "Systems.Farm.AutoFarmSystem", path = "src/Systems/Farm/AutoFarmSystem.lua", phase = "systems", required = true },
        { id = "Systems.Eggs.EggAndPetSystem", path = "src/Systems/Eggs/EggAndPetSystem.lua", phase = "systems", required = true },
        { id = "Systems.Main.MainFeaturesSystem", path = "src/Systems/Main/MainFeaturesSystem.lua", phase = "systems", required = true },
        { id = "Systems.Automatic.AutomaticSystem", path = "src/Systems/Automatic/AutomaticSystem.lua", phase = "systems", required = true },
        { id = "Systems.Events.FishingWorldSystem", path = "src/Systems/Events/FishingWorldSystem.lua", phase = "systems", required = true },
        { id = "Systems.Events.FarmingWorldSystem", path = "src/Systems/Events/FarmingWorldSystem.lua", phase = "systems", required = true },
        { id = "Systems.Social.MailboxSystem", path = "src/Systems/Social/MailboxSystem.lua", phase = "systems", required = true },
        { id = "Systems.Social.WebhookSystem", path = "src/Systems/Social/WebhookSystem.lua", phase = "systems", required = true },

        { id = "UI.WindowManager", path = "src/UI/WindowManager.lua", phase = "ui", required = true },
        { id = "UI.Tabs.PumpkinTycoonTab", path = "src/UI/Tabs/PumpkinTycoonTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.MainTab", path = "src/UI/Tabs/MainTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.AutoFarmTab", path = "src/UI/Tabs/AutoFarmTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.EggTab", path = "src/UI/Tabs/EggTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.AutomaticTab", path = "src/UI/Tabs/AutomaticTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.FishingWorldTab", path = "src/UI/Tabs/FishingWorldTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.FarmingWorldTab", path = "src/UI/Tabs/FarmingWorldTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.MailboxTab", path = "src/UI/Tabs/MailboxTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.OptimizationTab", path = "src/UI/Tabs/OptimizationTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.WebhookTab", path = "src/UI/Tabs/WebhookTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.ConfigTab", path = "src/UI/Tabs/ConfigTab.lua", phase = "ui", required = true },
        { id = "UI.HubExports", path = "src/UI/HubExports.lua", phase = "ui", required = true },
    },
}
