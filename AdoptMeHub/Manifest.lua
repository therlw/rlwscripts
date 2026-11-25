-- Manifest.lua
-- Ordered Module Registry for AdoptMeHub GitHub RAW Modular Loader

return {
    Name = "AdoptMeHub",
    Version = "AdoptMe-v1.0",
    DefaultBranch = "main",

    Modules = {
        { id = "Core.Context", path = "src/Core/Context.lua", phase = "bootstrap", required = true },
        { id = "Core.Lifecycle", path = "src/Core/Lifecycle.lua", phase = "core", required = true },
        { id = "Core.Utils", path = "src/Core/Utils.lua", phase = "core", required = true },
        { id = "Core.Bridge", path = "src/Core/Bridge.lua", phase = "core", required = true },

        { id = "Services.ConfigManager", path = "src/Services/ConfigManager.lua", phase = "services", required = true },

        { id = "Systems.Farm.DualFarmSystem", path = "src/Systems/Farm/DualFarmSystem.lua", phase = "systems", required = true },
        { id = "Systems.Events.EventsAndWorldSystem", path = "src/Systems/Events/EventsAndWorldSystem.lua", phase = "systems", required = true },
        { id = "Systems.Pets.PetManagerSystem", path = "src/Systems/Pets/PetManagerSystem.lua", phase = "systems", required = true },
        { id = "Systems.House.HouseAndEconomySystem", path = "src/Systems/House/HouseAndEconomySystem.lua", phase = "systems", required = true },
        { id = "Systems.Trade.TradeSystem", path = "src/Systems/Trade/TradeSystem.lua", phase = "systems", required = true },
        { id = "Systems.Visuals.VisualsAndSafetySystem", path = "src/Systems/Visuals/VisualsAndSafetySystem.lua", phase = "systems", required = true },

        { id = "UI.WindowManager", path = "src/UI/WindowManager.lua", phase = "ui", required = true },
        { id = "UI.Tabs.FarmTab", path = "src/UI/Tabs/FarmTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.EventsTab", path = "src/UI/Tabs/EventsTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.PetsTab", path = "src/UI/Tabs/PetsTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.HouseTradeTab", path = "src/UI/Tabs/HouseTradeTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.VisualsPerfTab", path = "src/UI/Tabs/VisualsPerfTab.lua", phase = "ui", required = true },
        { id = "UI.Tabs.ConfigTab", path = "src/UI/Tabs/ConfigTab.lua", phase = "ui", required = true },
        { id = "UI.HubExports", path = "src/UI/HubExports.lua", phase = "ui", required = true },
    },
}
