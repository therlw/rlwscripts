-- Manifest.lua
-- Ordered Module Registry for TapSimulatorHub GitHub RAW Modular Loader

return {
    Name = "TapSimulatorHub",
    Version = "CastleUpdate-Audited",
    DefaultBranch = "main",

    -- Ordered strictly by Dependency Injection & Runtime Boot sequence:
    -- Phase "bootstrap": constructs DI container (Context.New)
    -- Phase "core": generation lifecycle, Roblox services, remote wrappers & utils
    -- Phase "services": player data, persistent JSON config, dynamic catalogs
    -- Phase "systems": optimization, secrets, webhook, worlds, pets, automation, kaitun
    -- Phase "integrations": client controller hooks & popup/cutscene suppression
    -- Phase "ui": Rayfield Gen2 window + 11 modular tabs + _RLW_Hub finalizer
    Modules = {
        { id = "Core.Context", path = "src/Core/Context.lua", phase = "bootstrap", required = true },
        { id = "Core.Lifecycle", path = "src/Core/Lifecycle.lua", phase = "core", required = true },
        { id = "Core.Services", path = "src/Core/Services.lua", phase = "core", required = true },
        { id = "Core.Utils", path = "src/Core/Utils.lua", phase = "core", required = true },

        { id = "Services.PlayerData", path = "src/Services/PlayerData.lua", phase = "services", required = true },
        { id = "Services.ConfigManager", path = "src/Services/ConfigManager.lua", phase = "services", required = true },
        { id = "Data.Catalogs", path = "src/Data/Catalogs.lua", phase = "services", required = true },

        { id = "Systems.Optimization.CpuSaver", path = "src/Systems/Optimization/CpuSaver.lua", phase = "systems", required = true },
        { id = "Systems.Secrets.WebhookSender", path = "src/Systems/Secrets/WebhookSender.lua", phase = "systems", required = true },
        { id = "Systems.Secrets.SecretDetector", path = "src/Systems/Secrets/SecretDetector.lua", phase = "systems", required = true },

        { id = "Systems.Worlds.IslandManager", path = "src/Systems/Worlds/IslandManager.lua", phase = "systems", required = true },
        { id = "Systems.Worlds.UpgradeManager", path = "src/Systems/Worlds/UpgradeManager.lua", phase = "systems", required = true },

        { id = "Systems.Pets.PetInventory", path = "src/Systems/Pets/PetInventory.lua", phase = "systems", required = true },
        { id = "Systems.Pets.EggController", path = "src/Systems/Pets/EggController.lua", phase = "systems", required = true },
        { id = "Systems.Pets.MachineEvolution", path = "src/Systems/Pets/MachineEvolution.lua", phase = "systems", required = true },
        { id = "Systems.Pets.CastleMachines", path = "src/Systems/Pets/CastleMachines.lua", phase = "systems", required = true },

        { id = "Systems.Automation.RewardsManager", path = "src/Systems/Automation/RewardsManager.lua", phase = "systems", required = true },
        { id = "Systems.Automation.LuckyDucky", path = "src/Systems/Automation/LuckyDucky.lua", phase = "systems", required = true },
        { id = "Systems.Automation.PlayerMovement", path = "src/Systems/Automation/PlayerMovement.lua", phase = "systems", required = true },

        { id = "Systems.Progression.KaitunTelemetry", path = "src/Systems/Progression/KaitunTelemetry.lua", phase = "systems", required = true },
        { id = "Systems.Progression.KaitunEngine", path = "src/Systems/Progression/KaitunEngine.lua", phase = "systems", required = true },
        { id = "Systems.Automation.FarmWorkers", path = "src/Systems/Automation/FarmWorkers.lua", phase = "systems", required = true },

        { id = "Integrations.ClientHooks", path = "src/Integrations/ClientHooks.lua", phase = "integrations", required = true },

        { id = "UI.WindowManager", path = "src/UI/WindowManager.lua", phase = "ui", required = true },
        { id = "UI.Tabs.KaitunTab", path = "src/UI/Tabs/KaitunTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.OptimizationTab", path = "src/UI/Tabs/OptimizationTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.FarmTab", path = "src/UI/Tabs/FarmTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.EggTab", path = "src/UI/Tabs/EggTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.UpgradeTab", path = "src/UI/Tabs/UpgradeTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.IslandTab", path = "src/UI/Tabs/IslandTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.RewardTab", path = "src/UI/Tabs/RewardTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.PlayerTab", path = "src/UI/Tabs/PlayerTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.EventsTab", path = "src/UI/Tabs/EventsTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.WebhookTab", path = "src/UI/Tabs/WebhookTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.ConfigTab", path = "src/UI/Tabs/ConfigTab.lua", phase = "ui", required = true },
        { id = "UI.HubExports", path = "src/UI/HubExports.lua", phase = "ui", required = true },
    }
}
