-- src/Systems/Pets/PetInventory.lua
-- Pet Protection Filter, Frontier Species Detection, Safe Trash Cleaner & Best Equip Workers

local PetInventory = {}

function PetInventory.Init(ctx)
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local getPlayerData = ctx.API.getPlayerData
    local safeFire = ctx.Utils.safeFire

    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local requireSafe = ctx.Utils.requireSafe

    local function buildKeptPetTeamSet(data, equippedSet)
        local kept = {}
        for id, v in pairs(equippedSet or {}) do
            if v then kept[id] = true end
        end
        local CraftAllPlanMod = Mod.CraftAllPlan or (requireSafe and requireSafe(function() return ReplicatedStorage.Shared.Pets.CraftAllPlan end))
        if CraftAllPlanMod and type(CraftAllPlanMod.Kept) == "function" and data then
            local okKept, res = pcall(CraftAllPlanMod.Kept, data)
            if okKept and type(res) == "table" then
                for id, isKept in pairs(res) do
                    if isKept then kept[id] = true end
                end
            end
        end
        if data and type(data.PetTeams) == "table" then
            for _, team in pairs(data.PetTeams) do
                if type(team) == "table" then
                    local members = team.Pets or team.Ids or team
                    if type(members) == "table" then
                        for _, id in pairs(members) do
                            if type(id) == "string" then kept[id] = true end
                        end
                    end
                end
            end
        end
        return kept
    end

    local function isCraftLockedPet(p)
        local CraftLockMod = Mod.CraftLock or (requireSafe and requireSafe(function() return ReplicatedStorage.Shared.Pets.CraftLock end))
        if CraftLockMod and type(CraftLockMod.IsLocked) == "function" then
            local ok, locked = pcall(CraftLockMod.IsLocked, p)
            if ok and locked then return true end
        end
        return false
    end

    local function isPetProtectedFromDelete(id, p, equippedSet, minEquippedPower, maxPower, effPowerOverride, contextSets)
        if not p then return true end
        if (equippedSet and equippedSet[id]) or p.Equip or p.Locked or p.Frozen then
            return true
        end
        if contextSets and ((contextSets.petTeamsSet and contextSets.petTeamsSet[id]) or (contextSets.topShieldSet and contextSets.topShieldSet[id])) then
            return true
        end
        local okAttr, heldId = pcall(function() return LocalPlayer and LocalPlayer:GetAttribute("EnchantHeldPet") end)
        if okAttr and heldId == id then
            return true
        end
        local rarityStr = tostring(p.Rarity or "")
        if string.match(rarityStr, "^Secret") or rarityStr == "Mythical" or rarityStr == "Godly" or rarityStr == "Limited" or rarityStr == "Event" or rarityStr == "Exclusive" then
            return true
        end
        if p.Glitched == true or p.Tier == "Glitched" or p.Tier == "Rainbow" or p.Tier == "Shiny" then
            return true
        end
        if p.Mutation and p.Mutation ~= "" then
            return true
        end
        if p.Signature or p.LeaderboardSerial then
            return true
        end
        if (p.Enchant and p.Enchant ~= "") or (p.Enchant2 and p.Enchant2 ~= "") then
            return true
        end

        local pwr = effPowerOverride or p.Power or 0
        local minEq = minEquippedPower or 0
        local maxPwr = maxPower or 0

        -- Never delete pets that rival or beat current active lineup slots
        if minEq > 0 and pwr >= (minEq * 0.75) then
            return true
        end
        if p.Tier == "Diamond" and (pwr >= (minEq * 0.35) or (maxPwr <= 500000 and pwr >= 50000)) then
            return true
        end
        if p.Tier == "Golden" and minEq > 0 and pwr >= (minEq * 0.50) then
            return true
        end
        return false
    end

    local function buildDynamicFrontierSpecies(curWorld, curIsland, bestIsl)
        local frontierSpecies = {}
        if Mod.LaunchEggConfig then
            local worldEggs = {}
            for eggName, cfg in pairs(Mod.LaunchEggConfig) do
                if type(cfg) == "table" and (cfg.World or "Main") == curWorld and not cfg.ShowcaseOnly and not cfg.Limited and not cfg.Event then
                    if type(cfg.Price) == "number" and cfg.Price > 0 then
                        table.insert(worldEggs, { name = eggName, cfg = cfg, price = cfg.Price })
                    end
                end
            end
            table.sort(worldEggs, function(a, b) return a.price > b.price end)

            for idx, entry in ipairs(worldEggs) do
                local cfg = entry.cfg
                local matchIsland = (cfg.Island == curIsland or cfg.Island == bestIsl or idx <= 2)
                if matchIsland and type(cfg.Pets) == "table" then
                    for petName, _ in pairs(cfg.Pets) do
                        frontierSpecies[petName] = true
                    end
                end
            end
        end
        for _, fallbackName in ipairs({
            "Arctic Moose", "Ice Age Polar Bear", "Frost Elk", "Woolly Mammoth", "Frostbite Mammoth",
            "Soulflake", "Monarch Butterfly", "Ice Age Specter", "Frigidus", "Frost Behemoth",
            "Squire Pup", "Blacksmith Bear", "Archer Kitty", "Friendly Wizard", "Mimmic Chest",
            "Castle Golem", "Griffin", "Jester", "Crimson Dragon", "Royal Crown",
            "Crimson Rose Knight", "Prestige", "Blue Briar Palidin",
            "Royal Guard", "Golden Knight", "Crown Prince", "Castle Griffin",
        }) do
            frontierSpecies[fallbackName] = true
        end
        return frontierSpecies
    end

    local function evaluateTrashPlan(overrideData)
        local data = overrideData or getPlayerData()
        if not (data and data.Pets and data.Pets.Owned) then
            return {}, {}, { protectedCount = 0, deleteCount = 0 }
        end

        local owned = data.Pets.Owned
        local equipped = data.Pets.Equipped or {}
        local equippedSet = {}
        for _, id in ipairs(equipped) do equippedSet[id] = true end
        local petTeamsSet = buildKeptPetTeamSet(data, equippedSet)

        local PetPowerMod = Mod.PetPowerModule or (requireSafe and requireSafe(function() return ReplicatedStorage.Shared.Pets.PetPower end))
        local effMap = {}
        if PetPowerMod and type(PetPowerMod.GetOwnedPowers) == "function" then
            local okPow, mapped = pcall(PetPowerMod.GetOwnedPowers, owned)
            if okPow and type(mapped) == "table" then
                effMap = mapped
            end
        end

        local rankedPets = {}
        local maxPower = 0
        local minEquippedPower = math.huge
        for id, p in pairs(owned) do
            local pwr = effMap[id] or p.Power or 0
            table.insert(rankedPets, { id = id, pet = p, power = pwr })
            if equippedSet[id] then
                if pwr > maxPower then maxPower = pwr end
                if pwr < minEquippedPower then minEquippedPower = pwr end
            end
        end
        if minEquippedPower == math.huge then minEquippedPower = 0 end

        table.sort(rankedPets, function(a, b)
            if a.power ~= b.power then return a.power > b.power end
            return tostring(a.id) < tostring(b.id)
        end)

        local equipLimit = math.max(tonumber(data.Pets.EquipLimit) or 5, #equipped, 5)
        local shieldSlots = (maxPower == 0) and (equipLimit * 2) or (equipLimit + 4)
        local topShieldSet = {}
        for idx = 1, math.min(#rankedPets, shieldSlots) do
            topShieldSet[rankedPets[idx].id] = true
            if rankedPets[idx].power > maxPower then
                maxPower = rankedPets[idx].power
            end
        end

        local curWorld = (data.Progression and data.Progression.World) or "Main"
        local curIsland = (data.Progression and data.Progression.Island) or "Spawn"
        local bestIsl = (ctx.API.getBestUnlockedIsland and not overrideData and ctx.API.getBestUnlockedIsland()) or curIsland
        local frontierSpecies = buildDynamicFrontierSpecies(curWorld, curIsland, bestIsl)
        local contextSets = { petTeamsSet = petTeamsSet, topShieldSet = topShieldSet }

        local goldenCraftKeep = tonumber(CONFIG.GoldenCraftCount) or 6
        local diamondCraftKeep = tonumber(CONFIG.DiamondCraftCount) or 5
        local keptByTierSpecies = {}
        local trashIds = {}
        local protectedList = {}

        -- Process strongest pets first so craft-buffer quotas always keep the strongest copies of a species+tier
        for _, entry in ipairs(rankedPets) do
            local id = entry.id
            local p = entry.pet
            local pwr = entry.power
            local tier = p.Tier or "Normal"
            local isProtected = isPetProtectedFromDelete(id, p, equippedSet, minEquippedPower, maxPower, pwr, contextSets)

            if isProtected then
                table.insert(protectedList, { id = id, name = p.Name, tier = tier, power = pwr, reason = "ProtectedShield" })
            else
                local keepForCraft = false
                local craftLocked = isCraftLockedPet(p)
                local speciesTierKey = tostring(p.Name or "Unknown") .. "::" .. tostring(tier)
                local count = keptByTierSpecies[speciesTierKey] or 0

                if not craftLocked then
                    if tier == "Golden" and count < diamondCraftKeep then
                        local diamondPotential = pwr * (7 / 3)
                        if frontierSpecies[p.Name] or (minEquippedPower > 0 and diamondPotential >= minEquippedPower * 0.55) or (maxPower > 0 and pwr >= maxPower * 0.08) then
                            keepForCraft = true
                        end
                    elseif tier == "Normal" and count < goldenCraftKeep then
                        local diamondPotential = pwr * 7
                        if frontierSpecies[p.Name] or (minEquippedPower > 0 and diamondPotential >= minEquippedPower * 0.55) or (maxPower > 0 and pwr >= maxPower * 0.08) or (maxPower == 0) then
                            keepForCraft = true
                        end
                    end
                end

                if keepForCraft then
                    keptByTierSpecies[speciesTierKey] = count + 1
                    table.insert(protectedList, { id = id, name = p.Name, tier = tier, power = pwr, reason = "EvolutionBuffer" })
                else
                    table.insert(trashIds, { id = id, name = p.Name, tier = tier, power = pwr })
                end
            end
        end

        table.sort(trashIds, function(a, b) return a.power < b.power end)
        return trashIds, protectedList, {
            protectedCount = #protectedList,
            deleteCount = #trashIds,
            minEquippedPower = minEquippedPower,
            maxPower = maxPower,
            equipLimit = equipLimit,
        }
    end

    local function cleanTrashPets(dryRun, overrideData)
        local trashIds, protectedList, meta = evaluateTrashPlan(overrideData)
        local batchLimit = math.max(1, tonumber(CONFIG.TrashBatchSize) or 40)

        if dryRun == true or overrideData ~= nil then
            local preview = {}
            for i = 1, math.min(#trashIds, batchLimit) do
                table.insert(preview, trashIds[i])
            end
            return #preview, {
                wouldDelete = preview,
                totalTrashCandidates = #trashIds,
                protectedSample = protectedList,
                meta = meta,
            }
        end

        if #trashIds == 0 then return 0 end

        local batch = {}
        for i = 1, math.min(#trashIds, batchLimit) do
            table.insert(batch, trashIds[i].id)
        end

        if #batch > 0 then
            if Mod.PetDeleteRequest and type(Mod.PetDeleteRequest.Send) == "function" then
                local okSend = pcall(Mod.PetDeleteRequest.Send, batch, true, true)
                if okSend then return #batch end
            end
            local numericBatch = math.floor(os.clock() * 1000)
            safeFire(Svc.PetRemoteService, "RE", "PetActionRequested", {
                Action = "Delete",
                PetIds = batch,
                Batch = numericBatch,
            })
            return #batch
        end

        return 0
    end

    local function evaluateTrashPetsDryRun(overrideData)
        return cleanTrashPets(true, overrideData)
    end

    ctx.API.isPetProtectedFromDelete = isPetProtectedFromDelete
    ctx.API.buildDynamicFrontierSpecies = buildDynamicFrontierSpecies
    ctx.API.cleanTrashPets = cleanTrashPets
    ctx.API.evaluateTrashPetsDryRun = evaluateTrashPetsDryRun

    PetInventory.isPetProtectedFromDelete = isPetProtectedFromDelete
    PetInventory.buildDynamicFrontierSpecies = buildDynamicFrontierSpecies
    PetInventory.cleanTrashPets = cleanTrashPets
    PetInventory.evaluateTrashPetsDryRun = evaluateTrashPetsDryRun
    return PetInventory
end

function PetInventory.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local AutoFarmState = ctx.States.AutoFarm
    local KaitunState = ctx.States.Kaitun
    local equipBestPets = ctx.API.equipBestPets

    -- 3. Auto Equip Best Pets Worker
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            if not AutoFarmState.AutoEquipBest then
                task.wait(2.5)
            else
                task.wait(5.0)
                equipBestPets()
            end
        end
    end)

    -- 3b. Manual Auto Clean Trash Pets Worker
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            local interval = math.max(5, tonumber(CONFIG.TrashCleanInterval) or 25)
            if not AutoFarmState.AutoCleanTrash or KaitunState.Enabled then
                task.wait(2.5)
            else
                pcall(PetInventory.cleanTrashPets)
                task.wait(interval)
            end
        end
    end)
end

return PetInventory
