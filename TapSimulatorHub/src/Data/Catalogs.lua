-- src/Data/Catalogs.lua
-- Dynamic World, Island, Egg, Secret Catalog & Machine Pad Discovery

local Catalogs = {}

function Catalogs.Init(ctx)
    local Mod = ctx.Modules
    local getInstancePosition = ctx.Utils.getInstancePosition
    local ISLAND_NAME_ALIASES = ctx.ISLAND_NAME_ALIASES
    local EggSecretCatalog = ctx.Catalogs.EggSecretCatalog
    local SecretPetCatalog = ctx.Catalogs.SecretPetCatalog

    local function normalizeIslandName(name)
        if type(name) ~= "string" then return name end
        return ISLAND_NAME_ALIASES[name] or name
    end

    local function rebuildSecretCatalog()
        table.clear(EggSecretCatalog)
        table.clear(SecretPetCatalog)
        if Mod.LaunchEggConfig then
            for eggName, cfg in pairs(Mod.LaunchEggConfig) do
                if type(cfg) == "table" and type(cfg.Secrets) == "table" then
                    EggSecretCatalog[eggName] = {}
                    for petName, oneIn in pairs(cfg.Secrets) do
                        local meta = {
                            Name = petName,
                            Egg = eggName,
                            Island = cfg.Island or (cfg.World == "TimeRift" and "World 2 Spawn" or "Spawn"),
                            World = cfg.World or "Main",
                            OneIn = tonumber(oneIn) or 0,
                            Rarity = "Secret",
                        }
                        EggSecretCatalog[eggName][petName] = meta
                        SecretPetCatalog[string.lower(petName)] = meta
                    end
                end
            end
        end
        if Mod.GlitchedEvolutionConfig and type(Mod.GlitchedEvolutionConfig.Chain) == "table" then
            for _, step in ipairs(Mod.GlitchedEvolutionConfig.Chain) do
                if type(step) == "table" and step.To then
                    SecretPetCatalog[string.lower(step.To)] = {
                        Name = step.To,
                        Egg = Mod.GlitchedEggTiers and Mod.GlitchedEggTiers.EggName or "Glitched Egg",
                        Island = "Medieval Island",
                        World = "TimeRift",
                        OneIn = 0,
                        Rarity = "Secret",
                    }
                end
            end
        end
    end

    local function buildDynamicIslandList()
        local list = { "Spawn" }
        local seen = { ["Spawn"] = true }
        if Mod.IslandConfig and Mod.IslandConfig.Islands then
            local w1 = {}
            for name, info in pairs(Mod.IslandConfig.Islands) do
                table.insert(w1, { name = name, order = info.Order or 0 })
            end
            table.sort(w1, function(a, b) return a.order < b.order end)
            for _, item in ipairs(w1) do
                if not seen[item.name] then
                    seen[item.name] = true
                    table.insert(list, item.name)
                end
            end
        else
            for _, n in ipairs({ "Sky Island", "Autumn", "Mushroom", "Desert", "Crystal Cave", "Shadow Realm", "Volcano", "Heaven" }) do
                if not seen[n] then seen[n] = true; table.insert(list, n) end
            end
        end

        if not seen["World 2 Spawn"] then
            seen["World 2 Spawn"] = true
            table.insert(list, "World 2 Spawn")
        end

        if Mod.RiftIslandConfig and Mod.RiftIslandConfig.Islands then
            local w2 = {}
            for name, info in pairs(Mod.RiftIslandConfig.Islands) do
                table.insert(w2, { name = name, order = info.Order or 0 })
            end
            table.sort(w2, function(a, b) return a.order < b.order end)
            for _, item in ipairs(w2) do
                if not seen[item.name] then
                    seen[item.name] = true
                    table.insert(list, item.name)
                end
            end
        else
            for _, n in ipairs({ "Prehistoric Island", "Ice Age", "Medieval Island" }) do
                if not seen[n] then seen[n] = true; table.insert(list, n) end
            end
        end
        return list
    end

    local function buildDynamicEggList()
        local eggsFolder = workspace:FindFirstChild("Eggs")
        local list = {}
        if Mod.LaunchEggConfig then
            local items = {}
            for eggName, cfg in pairs(Mod.LaunchEggConfig) do
                if type(cfg) == "table" and type(cfg.Price) == "number" and cfg.Price > 0 then
                    local inWorkspace = (not eggsFolder) or (eggsFolder:FindFirstChild(eggName) ~= nil)
                    if inWorkspace then
                        table.insert(items, {
                            name = eggName,
                            price = cfg.Price,
                            world = (cfg.World == "TimeRift") and 2 or 1,
                        })
                    end
                end
            end
            table.sort(items, function(a, b)
                if a.world ~= b.world then return a.world < b.world end
                if a.price ~= b.price then return a.price < b.price end
                return a.name < b.name
            end)
            for _, item in ipairs(items) do
                table.insert(list, item.name)
            end
        end
        if #list == 0 then
            list = {
                "Basic", "Spotted", "Spiked", "Nimbus", "Sky", "Pumpkin",
                "Mushroom", "Mycelium", "Cactus", "Geode", "Crystal", "Void",
                "Volcanic", "Draconic", "Heaven", "Grove", "Rift", "Jurassic",
                "Glacier", "Permafrost", "Medieval", "Glitched Egg", "Royal"
            }
        end
        return list
    end

    local function discoverMachinePads(machineName, preferWorld2)
        local found = {}
        local function scanRoot(root)
            if not root then return end
            for _, inst in ipairs(root:GetDescendants()) do
                if inst.Name == machineName or string.find(inst.Name, machineName, 1, true) then
                    local pos = getInstancePosition(inst)
                    if pos then
                        table.insert(found, {
                            instance = inst,
                            pos = pos,
                            inWorld2 = (pos.Z > 3000) or inst:IsDescendantOf(workspace:FindFirstChild("World2") or workspace),
                        })
                    end
                end
            end
        end
        local w2 = workspace:FindFirstChild("World2")
        if preferWorld2 and w2 then
            scanRoot(w2)
        else
            scanRoot(workspace:FindFirstChild("Ts2Islands"))
            scanRoot(workspace:FindFirstChild("Map1"))
            scanRoot(w2)
        end
        return found
    end

    rebuildSecretCatalog()

    local A = ctx.API
    A.normalizeIslandName = normalizeIslandName
    A.rebuildSecretCatalog = rebuildSecretCatalog
    A.buildDynamicIslandList = buildDynamicIslandList
    A.buildDynamicEggList = buildDynamicEggList
    A.discoverMachinePads = discoverMachinePads

    Catalogs.NormalizeIslandName = normalizeIslandName
    Catalogs.RebuildSecretCatalog = rebuildSecretCatalog
    Catalogs.BuildDynamicIslandList = buildDynamicIslandList
    Catalogs.BuildDynamicEggList = buildDynamicEggList
    Catalogs.DiscoverMachinePads = discoverMachinePads

    return Catalogs
end

return Catalogs
