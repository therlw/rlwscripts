-- src/Core/Services.lua
-- Game Service & Client Controller / Shared Config Discovery (Mirrors TapSimulatorHub.lua [03])

local Services = {}

function Services.Init(ctx)
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local RemoteServices = ReplicatedStorage:WaitForChild("RemoteServices", 10)

    local function findRemoteService(name)
        return RemoteServices and RemoteServices:FindFirstChild(name) or nil
    end

    local function requireSafe(instOrGetter)
        local ok, mod = pcall(function()
            local inst = (type(instOrGetter) == "function") and instOrGetter() or instOrGetter
            if inst then
                return require(inst)
            end
            return nil
        end)
        return ok and mod or nil
    end

    local Svc = ctx.Services
    Svc.TapService = findRemoteService("TapService")
    Svc.AutoClickService = findRemoteService("AutoClickService")
    Svc.RebirthService = findRemoteService("RebirthService")
    Svc.EggService = findRemoteService("EggService")
    Svc.UpgradeService = findRemoteService("UpgradeService")
    Svc.IslandService = findRemoteService("IslandService")
    Svc.WorldService = findRemoteService("WorldService")
    Svc.TimeRiftService = findRemoteService("TimeRiftService")
    Svc.TimeRiftIslandService = findRemoteService("TimeRiftIslandService")
    Svc.TapChestService = findRemoteService("TapChestService")
    Svc.ShinyStarService = findRemoteService("ShinyStarService")
    Svc.QuestService = findRemoteService("QuestService")
    Svc.OfflineRewardsService = findRemoteService("OfflineRewardsService")
    Svc.LuckyDuckyService = findRemoteService("LuckyDuckyService")
    Svc.PetIndexService = findRemoteService("PetIndexService")
    Svc.EventWheelService = findRemoteService("EventWheelService")
    Svc.CodeService = findRemoteService("CodeService")
    Svc.DoubleJumpService = findRemoteService("DoubleJumpService")
    Svc.PhysicalUpgradeService = findRemoteService("PhysicalUpgradeService")
    Svc.PetRemoteService = findRemoteService("PetService")
    Svc.SkillTreeService = findRemoteService("SkillTreeService")
    Svc.BridgeService = findRemoteService("BridgeService")
    Svc.MachineService = findRemoteService("MachineService")
    Svc.BoostService = findRemoteService("BoostService")

    -- Castle Update & Audited Extended Services
    Svc.GlitchedEggService = findRemoteService("GlitchedEggService")
    Svc.GlitchedEvolutionService = findRemoteService("GlitchedEvolutionService")
    Svc.PotionMachineService = findRemoteService("PotionMachineService")
    Svc.LuckyEggMachineService = findRemoteService("LuckyEggMachineService")
    Svc.HoneyPotService = findRemoteService("HoneyPotService")
    Svc.ExpeditionService = findRemoteService("ExpeditionService")
    Svc.GlobalEventService = findRemoteService("GlobalEventService")
    Svc.CloudRainService = findRemoteService("CloudRainService")
    Svc.BalloonPartyService = findRemoteService("BalloonPartyService")
    Svc.BalloonLuckService = findRemoteService("BalloonLuckService")
    Svc.PigsCouldFlyService = findRemoteService("PigsCouldFlyService")
    Svc.EggDropService = findRemoteService("EggDropService")
    Svc.MeteorShowerService = findRemoteService("MeteorShowerService")
    Svc.NeonCatChestService = findRemoteService("NeonCatChestService")
    Svc.TapFieldDropService = findRemoteService("TapFieldDropService")
    Svc.MessageService = findRemoteService("MessageService")
    Svc.FusionService = findRemoteService("FusionService")
    Svc.EnchantService = findRemoteService("EnchantService")
    Svc.MasteryService = findRemoteService("MasteryService")
    Svc.HallowBossService = findRemoteService("HallowBossService")
    Svc.HalloweenDailyService = findRemoteService("HalloweenDailyService")
    Svc.HalloweenShopService = findRemoteService("HalloweenShopService")
    Svc.RaffleService = findRemoteService("RaffleService")

    local Mod = ctx.Modules
    Mod.DataController = requireSafe(function() return ReplicatedStorage.Controllers.Core.DataController end)
    Mod.TapController = requireSafe(function() return ReplicatedStorage.Controllers.Game.TapController end)
    Mod.MessageController = requireSafe(function() return ReplicatedStorage.Controllers.UI.MessageController end)
    Mod.MenuController = requireSafe(function() return ReplicatedStorage.Controllers.UI.MenuController end)
    Mod.MachineController = requireSafe(function() return ReplicatedStorage.Controllers.Pets.MachineController end)
    Mod.LuckyDuckyController = requireSafe(function() return ReplicatedStorage.Controllers.Game.LuckyDuckyController end)
    Mod.NotificationController = requireSafe(function() return ReplicatedStorage.Controllers.UI.NotificationController end)

    Mod.RebirthConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.RebirthConfig end)
    Mod.RebirthButtonConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.RebirthButtonConfig end)
    Mod.WorldConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.WorldConfig end)
    Mod.IslandConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.IslandConfig end)
    Mod.RiftIslandConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.RiftIslandConfig end)
    Mod.CachedIslandRegions = requireSafe(function() return ReplicatedStorage.Shared.Progression.IslandRegions end)
    Mod.PhysicalUpgradeConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.PhysicalUpgradeConfig end)

    Mod.BridgeFightZone = requireSafe(function() return ReplicatedStorage.Shared.Progression.BridgeFightZone end)
    Mod.OnboardingBridgeConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.OnboardingBridgeConfig end)
    Mod.OnboardingConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.OnboardingConfig end)
    Mod.FormatNumber = requireSafe(function() return ReplicatedStorage.Modules.Client.Common.FormatNumber end)
    Mod.UpgradeConfig = requireSafe(function() return ReplicatedStorage.Shared.Progression.UpgradeConfig end)
    Mod.SkillBoard = requireSafe(function() return ReplicatedStorage.Shared.Progression.SkillBoard end)

    Mod.LaunchEggConfig = requireSafe(function() return ReplicatedStorage.Shared.Pets.LaunchEggConfig end)
    Mod.LaunchPetConfig = requireSafe(function() return ReplicatedStorage.Shared.Pets.LaunchPetConfig end)
    Mod.GlitchedEggTiers = requireSafe(function() return ReplicatedStorage.Shared.Pets.GlitchedEggTiers end)
    Mod.GlitchedEvolutionConfig = requireSafe(function() return ReplicatedStorage.Shared.Pets.GlitchedEvolutionConfig end)
    Mod.ShinyStarConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.ShinyStarConfig end)
    Mod.TapChestConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.TapChestConfig end)
    Mod.BoostConfig = requireSafe(function() return ReplicatedStorage.Shared.Items.BoostConfig end)
    Mod.BoostFormula = requireSafe(function() return ReplicatedStorage.Shared.Items.BoostFormula end)
    Mod.PotionMachineConfig = requireSafe(function() return ReplicatedStorage.Shared.Items.PotionMachineConfig end)
    Mod.PotionCraftConfig = requireSafe(function() return ReplicatedStorage.Shared.Items.PotionCraftConfig end)
    Mod.HoneyPotConfig = requireSafe(function() return ReplicatedStorage.Shared.Items.HoneyPotConfig end)
    Mod.ExpeditionMapConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.ExpeditionMapConfig end)
    Mod.LuckyEggMachineConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.LuckyEggMachineConfig end)
    Mod.GlobalEventConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.GlobalEventConfig end)
    Mod.UpdateLogConfig = requireSafe(function() return ReplicatedStorage.Shared.Game.UpdateLogConfig end)
    Mod.PetPowerModule = requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end)

    -- Pet Hatch Renderers & Cutscenes
    Mod.HatchRenderer = requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.HatchRenderer end)
    Mod.SecretHatchRenderer = requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.SecretHatchRenderer end)
    Mod.SecretHatchCutscenes = requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.SecretHatchCutscenes end)
    Mod.ProfileStats = requireSafe(function() return ReplicatedStorage.Modules.Client.Game.ProfileStats end)
    Mod.PetDeleteRequest = requireSafe(function() return ReplicatedStorage.Modules.Client.Pets.PetDeleteRequest end)

    ctx.Controllers = Mod
    ctx.Utils.findRemoteService = findRemoteService
    ctx.Utils.requireSafe = requireSafe
    Services.findRemoteService = findRemoteService
    Services.requireSafe = requireSafe
    return Services
end

return Services
