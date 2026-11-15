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

    local function isPetProtectedFromDelete(id, p, equippedSet, minEquippedPower, maxPower)
        if not p then return true end
        if equippedSet[id] or p.Equip or p.Locked then
            return true
        end
        if p.Frozen then
            return true
        end
        local okAttr, heldId = pcall(function() return LocalPlayer:GetAttribute("EnchantHeldPet") end)
        if okAttr and heldId == id then
            return true
        end
        local rarityStr = tostring(p.Rarity or "")
        if string.match(rarityStr, "^Secret") or rarityStr == "Mythical" or rarityStr == "Godly" or rarityStr == "Limited" then
            return true
        end
        if p.Glitched == true or p.Tier == "Glitched" or p.Tier == "Rainbow" then
            return true
        end
        local pwr = p.Power or 0
        if p.Tier == "Diamond" and pwr >= (minEquippedPower * 0.8) then
            return true
        end
        if p.Tier == "Shiny" and (pwr >= 50000000 or maxPower <= 50000) then
            return true
        end
        if p.Enchant and p.Enchant ~= "" then
            return true
        end
        return false
    end

    local function buildDynamicFrontierSpecies(curWorld, curIsland, bestIsl)
        local frontierSpecies = {}
        if Mod.LaunchEggConfig then
            local bestPrice = -1
            local bestEggs = {}
            for eggName, cfg in pairs(Mod.LaunchEggConfig) do
                if type(cfg) == "table" and (cfg.World or "Main") == curWorld and not cfg.ShowcaseOnly and not cfg.Limited then
                    if type(cfg.Price) == "number" and cfg.Price > 0 then
                        if cfg.Island == curIsland or cfg.Island == bestIsl or eggName == "Royal" or eggName == "Medieval" or eggName == "Permafrost" then
                            table.insert(bestEggs, cfg)
                        elseif cfg.Price > bestPrice then
                            bestPrice = cfg.Price
                        end
                    end
                end
            end
            for _, cfg in ipairs(bestEggs) do
                if type(cfg.Pets) == "table" then
                    for petName, _ in pairs(cfg.Pets) do
                        frontierSpecies[petName] = true
                    end
                end
            end
        end
        for _, fallbackName in ipairs({
            "Arctic Moose", "Ice Age Polar Bear", "Frost Elk", "Woolly Mammoth", "Frostbite Mammoth",
            "Soulflake", "Monarch Butterfly", "Ice Age Specter", "Frigidus", "Frost Behemoth",
            "Royal Guard", "Golden Knight", "Crown Prince", "Crimson Dragon", "Castle Griffin",
        }) do
            frontierSpecies[fallbackName] = true
        end
        return frontierSpecies
    end

    local function cleanTrashPets()
        local data = getPlayerData()
        if not (data and data.Pets and data.Pets.Owned) then return 0 end

        local owned = data.Pets.Owned
        local equipped = data.Pets.Equipped or {}
        local equippedSet = {}
        for _, id in ipairs(equipped) do equippedSet[id] = true end

        local maxPower = 0
        local minEquippedPower = math.huge
        for id, p in pairs(owned) do
            if equippedSet[id] then
                local pwr = p.Power or 0
                if pwr > maxPower then maxPower = pwr end
                if pwr < minEquippedPower then minEquippedPower = pwr end
            end
        end
        if minEquippedPower == math.huge then minEquippedPower = 0 end

        local curWorld = (data.Progression and data.Progression.World) or "Main"
        local curIsland = (data.Progression and data.Progression.Island) or "Spawn"
        local isWorld2 = (curWorld == "TimeRift")
        local bestIsl = (ctx.API.getBestUnlockedIsland and ctx.API.getBestUnlockedIsland()) or curIsland
        local frontierSpecies = buildDynamicFrontierSpecies(curWorld, curIsland, bestIsl)

        local keptSpecies = {}
        local trashIds = {}

        for id, p in pairs(owned) do
            local isProtected = isPetProtectedFromDelete(id, p, equippedSet, minEquippedPower, maxPower)
            local pwr = p.Power or 0

            if not isProtected then
                if isWorld2 and (curIsland == "Medieval Island" or curIsland == "Ice Age" or curIsland == "Prehistoric Island") then
                    if frontierSpecies[p.Name] then
                        local count = keptSpecies[p.Name] or 0
                        if count < CONFIG.GoldenCraftCount then
                            keptSpecies[p.Name] = count + 1
                        else
                            table.insert(trashIds, { id = id, power = pwr })
                        end
                    else
                        table.insert(trashIds, { id = id, power = pwr })
                    end
                else
                    local count = keptSpecies[p.Name] or 0
                    if count < CONFIG.GoldenCraftCount and maxPower > 0 and pwr >= (maxPower * 0.15) then
                        keptSpecies[p.Name] = count + 1
                    else
                        table.insert(trashIds, { id = id, power = pwr })
                    end
                end
            end
        end

        if #trashIds == 0 then return 0 end

        table.sort(trashIds, function(a, b) return a.power < b.power end)

        local batch = {}
        for i = 1, math.min(#trashIds, CONFIG.TrashBatchSize) do
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

    ctx.API.isPetProtectedFromDelete = isPetProtectedFromDelete
    ctx.API.buildDynamicFrontierSpecies = buildDynamicFrontierSpecies
    ctx.API.cleanTrashPets = cleanTrashPets

    PetInventory.isPetProtectedFromDelete = isPetProtectedFromDelete
    PetInventory.buildDynamicFrontierSpecies = buildDynamicFrontierSpecies
    PetInventory.cleanTrashPets = cleanTrashPets
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
