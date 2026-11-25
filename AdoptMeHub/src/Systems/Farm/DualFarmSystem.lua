-- src/Systems/Farm/DualFarmSystem.lua
-- Handles Dual Farm (Baby + Pet), Ailment Solver, Auto-Age Queue, Auto-Hatch, Auto-Lure, Auto-Buy Eggs, Daily Claims

local DualFarmSystem = {}

function DualFarmSystem.Init(ctx)
    local Bridge = ctx.Bridge
    local Utils = ctx.Utils
    local States = ctx.States
    local Cooldowns = ctx.Runtime.Cooldowns
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService

    local DF = {
        _lastCompletedKeys = {},
    }

    local RARITY_RANK = {
        common = 1,
        uncommon = 2,
        rare = 3,
        ultra_rare = 4,
        legendary = 5,
    }

    local INTERIOR_AILMENTS = {
        school = { dest = "School", door = "MainDoor" },
        sick = { dest = "Hospital", door = "MainDoor" },
        salon = { dest = "Salon", door = "MainDoor" },
        pizza_party = { dest = "PizzaShop", door = "MainDoor" },
        cat_cafe = { dest = "CatCafe", door = "MainDoor" },
    }

    local STATIC_AILMENTS = {
        bored = "Park",
        camping = "exterior_camping",
        beach_party = "exterior_beach",
    }

    local function getPetInfo(kind)
        local invDB = Bridge.Mod.InventoryDB
        return invDB and invDB.pets and invDB.pets[kind] or nil
    end

    local function getActivePetUniqueAndWrapper()
        local data = Bridge.GetMyData()
        if not data then return nil, nil end
        local eqPets = data.equip_manager and data.equip_manager.pets
        local activeUid = type(eqPets) == "table" and eqPets[1] and eqPets[1].unique or nil
        if not activeUid and type(eqPets) == "table" then
            for _, v in pairs(eqPets) do
                if type(v) == "table" and v.unique then
                    activeUid = v.unique
                    break
                elseif type(v) == "string" then
                    activeUid = v
                    break
                end
            end
        end
        local charWrapper = nil
        for _, w in pairs(data.pet_char_wrappers or {}) do
            if not activeUid or w.pet_unique == activeUid then
                activeUid = activeUid or w.pet_unique
                charWrapper = w
                break
            end
        end
        return activeUid, charWrapper
    end

    local function findInventoryItem(category, predicate)
        local catTbl = Bridge.GetInventory(category)
        for uid, item in pairs(catTbl) do
            if type(item) == "table" then
                if not item.unique then item.unique = uid end
                if predicate(item) then
                    return item
                end
            end
        end
        return nil
    end

    local function ensureBabyTeam()
        local F = States.Farm
        if not (F.DualFarm and F.AutoBabyTeam) then return end
        if Bridge.GetTeam() ~= "Babies" then
            local ok = Bridge.RouteInvoke("TeamAPI/ChooseTeam", "Babies", {
                dont_send_back_home = true,
                source_for_logging = "adopt_me_hub",
            })
            if ok then
                ctx.Runtime.Status.Farm = "Rol: Baby seçildi (Dual Farm)"
                task.wait(0.4)
            end
        end
    end

    local function pickNextPetFromQueue(wantEggsOnly)
        local F = States.Farm
        local pets = Bridge.GetInventory("pets")
        local bestUid = nil
        local bestScore = -1
        local wantKind = string.lower(tostring(F.AgeQueuePetKind or ""))
        local wantRarity = string.lower(tostring(F.AgeQueueRarity or "All"))

        for uid, pet in pairs(pets) do
            if type(pet) == "table" and pet.id then
                local info = getPetInfo(pet.id)
                local isEgg = info and info.is_egg == true
                local age = (pet.properties and tonumber(pet.properties.age)) or 1

                if wantEggsOnly then
                    if isEgg then
                        bestUid = uid
                        break
                    end
                else
                    if not isEgg and age < 6 then
                        local rarity = string.lower(tostring((info and info.rarity) or "common"))
                        local kindMatch = (wantKind == "" or string.find(string.lower(pet.id), wantKind, 1, true) ~= nil)
                        local rarityMatch = (wantRarity == "all" or rarity == wantRarity)
                        if kindMatch and rarityMatch then
                            local score = (RARITY_RANK[rarity] or 0) * 10 + age
                            if score > bestScore then
                                bestScore = score
                                bestUid = uid
                            end
                        end
                    end
                end
            end
        end

        return bestUid
    end

    function DF.TryRotatePetOrEgg()
        local F = States.Farm
        if not (F.AutoHatchEggs or F.AutoAgeQueue or F.DualFarm) then return false end
        if os.clock() - Cooldowns.LastEquipAt < 3.0 then return false end

        local activeUid = getActivePetUniqueAndWrapper()
        local pets = Bridge.GetInventory("pets")
        local activePet = activeUid and pets[activeUid] or nil
        local activeInfo = activePet and getPetInfo(activePet.id) or nil
        local activeAge = (activePet and activePet.properties and tonumber(activePet.properties.age)) or 1
        local activeIsEgg = activeInfo and activeInfo.is_egg == true

        local needSwap = false
        local preferEgg = F.AutoHatchEggs

        if not activePet then
            needSwap = true
        elseif preferEgg and not activeIsEgg then
            -- Switch to egg if any egg exists in inventory
            if pickNextPetFromQueue(true) ~= nil then
                needSwap = true
            end
        elseif F.AutoAgeQueue and not activeIsEgg and activeAge >= 6 then
            needSwap = true
        end

        if not needSwap then return false end

        local nextUid = nil
        if preferEgg then
            nextUid = pickNextPetFromQueue(true)
        end
        if not nextUid and F.AutoAgeQueue then
            nextUid = pickNextPetFromQueue(false)
        end
        if not nextUid and not activePet then
            -- Pick any first pet if nothing is equipped
            for uid in pairs(pets) do
                nextUid = uid
                break
            end
        end

        if nextUid and nextUid ~= activeUid then
            Cooldowns.LastEquipAt = os.clock()
            local ok = Bridge.RouteInvoke("ToolAPI/Equip", nextUid, { use_sound_delay = false })
            if ok then
                local pName = (pets[nextUid] and pets[nextUid].id) or nextUid
                ctx.Runtime.Status.Farm = "Kuşanıldı: " .. tostring(pName)
                return true
            end
        end
        return false
    end

    local function completeUseItemAilment(kind, targetCharWrapper)
        local item = nil
        if kind == "hungry" then
            item = findInventoryItem("food", function(it)
                local d = Bridge.Mod.InventoryDB and Bridge.Mod.InventoryDB.food and Bridge.Mod.InventoryDB.food[it.kind or it.id]
                return d and (d.ailment_to_boost == "hungry" or string.find(tostring(it.id), "apple", 1, true) or string.find(tostring(it.id), "sandwich", 1, true))
            end)
            if not item then
                -- Buy cheap apple from ShopAPI
                Bridge.RouteInvoke("ShopAPI/BuyItem", "food", "apple", {})
                task.wait(0.25)
                item = findInventoryItem("food", function(it) return it.id == "apple" end)
            end
        elseif kind == "thirsty" then
            item = findInventoryItem("food", function(it)
                local d = Bridge.Mod.InventoryDB and Bridge.Mod.InventoryDB.food and Bridge.Mod.InventoryDB.food[it.kind or it.id]
                return d and (d.ailment_to_boost == "thirsty" or string.find(tostring(it.id), "water", 1, true) or string.find(tostring(it.id), "tea", 1, true))
            end)
            if not item then
                Bridge.RouteInvoke("ShopAPI/BuyItem", "food", "water", {})
                task.wait(0.25)
                item = findInventoryItem("food", function(it) return it.id == "water" end)
            end
        elseif kind == "play" then
            item = findInventoryItem("toys", function(it)
                local d = Bridge.Mod.InventoryDB and Bridge.Mod.InventoryDB.toys and Bridge.Mod.InventoryDB.toys[it.kind or it.id]
                return d and (d.tool == "ThrowToyTool" or d.tool == "ChewToyTool" or d.tool == "SqueakyToyTool")
            end)
        end

        if not item then return false end

        if Bridge.Mod.UseItemHelper and Bridge.Mod.UseItemHelper.use_item and targetCharWrapper then
            pcall(Bridge.Mod.UseItemHelper.use_item, targetCharWrapper, item)
            return true
        end
        Bridge.RouteInvoke("ToolAPI/Equip", item.unique, { use_sound_delay = false })
        task.wait(0.2)
        Bridge.RouteInvoke("ToolAPI/ServerUseTool", item.unique, "END")
        return true
    end

    local function completeAilment(kind, targetKey, isPet, petUid, petCharWrapper)
        if kind == "mystery" and States.Farm.AutoMysteryAilment and isPet and petUid then
            Bridge.RouteFire("AilmentsAPI/ChooseMysteryAilment", petUid, kind, 1, "hungry")
            ctx.Runtime.Status.Farm = "Mystery görev seçildi (hungry)"
            return true
        end

        if kind == "pet_me" and isPet and petUid then
            local pChar = petCharWrapper and petCharWrapper.char
            if pChar then
                Bridge.RouteFire("AdoptAPI/FocusPet", pChar)
                task.wait(0.15)
            end
            Bridge.RouteFire("PetAPI/PetPetted", petUid, LocalPlayer)
            Bridge.RouteFire("AilmentsAPI/ProgressPetMeAilment", petUid)
            if pChar then
                Bridge.RouteFire("AdoptAPI/UnfocusPet", pChar)
            end
            ctx.Runtime.Status.Farm = "Pet okşandı (pet_me)"
            return true
        end

        if kind == "dirty" and isPet and petUid then
            -- Use Nursery/Salon or dirty progress / house tub
            Bridge.RouteFire("AilmentsAPI/ProgressDirtyAilment", petUid)
            Bridge.EnterInterior("Salon", "MainDoor")
            ctx.Runtime.Status.Farm = "Temizleniyor (dirty)"
            return true
        elseif kind == "dirty" then
            Bridge.EnterInterior("Salon", "MainDoor")
            ctx.Runtime.Status.Farm = "Bebek temizleniyor (Salon)"
            return true
        end

        if kind == "sleepy" then
            -- Nursery & Hospital & School have free beds; enter Nursery for fast recovery
            Bridge.EnterInterior("Nursery", "MainDoor")
            ctx.Runtime.Status.Farm = "Uyku görevi (Nursery)"
            return true
        end

        if kind == "toilet" then
            local hydrants = CollectionService:GetTagged("FireHydrantServer")
            if #hydrants > 0 then
                local pos = Utils.getPos(hydrants[1])
                if pos then
                    local cur = Bridge.GetCurrentLocation()
                    if not cur or cur.destination_id ~= "MainMap" then
                        Bridge.EnterInterior("MainMap", "Neighborhood!MainDoor")
                        task.wait(0.4)
                    end
                    Utils.moveToPosition(pos, 0.25)
                    ctx.Runtime.Status.Farm = "Tuvalet görevi (Yangın Musluğu)"
                    return true
                end
            end
        end

        if INTERIOR_AILMENTS[kind] then
            local target = INTERIOR_AILMENTS[kind]
            Bridge.EnterInterior(target.dest, target.door)
            ctx.Runtime.Status.Farm = string.format("Konum görevi: %s (%s)", kind, target.dest)
            return true
        end

        if STATIC_AILMENTS[kind] then
            Bridge.TeleportStaticLocation(STATIC_AILMENTS[kind])
            ctx.Runtime.Status.Farm = "Harita görevi: " .. kind
            return true
        end

        if kind == "hungry" or kind == "thirsty" or kind == "play" then
            if completeUseItemAilment(kind, petCharWrapper) then
                ctx.Runtime.Status.Farm = "Eşya ile tamamlanıyor: " .. kind
                return true
            end
        end

        if kind == "walk" or kind == "ride" or kind == "swim" or kind == "leaf_pile" or kind == "rain_puddle" or kind == "snowman" then
            local _, hrp, hum = Utils.getCharacterParts()
            if hrp and hum then
                hum:Move(Vector3.new(0, 0, -1), true)
                task.wait(0.25)
                hum:Move(Vector3.zero, true)
                ctx.Runtime.Status.Farm = "Hareket görevi: " .. kind
                return true
            end
        end

        return false
    end

    function DF.TryStepAilments()
        local F = States.Farm
        if not (F.DualFarm or F.AutoAilments) then return false end
        if os.clock() - Cooldowns.LastAilmentStepAt < 3.5 then return false end

        ensureBabyTeam()

        local am = Bridge.GetAilmentsManager()
        local petUid, petCharWrapper = getActivePetUniqueAndWrapper()

        -- Prefer Pet ailments first, then Baby ailments (Dual Farm completes both!)
        local chosenKind, chosenIsPet = nil, false
        local petAilments = petUid and am.ailments and am.ailments[petUid] or nil
        if type(petAilments) == "table" then
            for kind, a in pairs(petAilments) do
                if type(a) == "table" then
                    chosenKind = a.kind or kind
                    chosenIsPet = true
                    break
                end
            end
        end

        if not chosenKind and F.DualFarm and type(am.baby_ailments) == "table" then
            for kind, a in pairs(am.baby_ailments) do
                if type(a) == "table" then
                    chosenKind = a.kind or kind
                    chosenIsPet = false
                    break
                end
            end
        end

        if not chosenKind then
            ctx.Runtime.Status.Farm = "Aktif görev bekleniyor..."
            return false
        end

        Cooldowns.LastAilmentStepAt = os.clock()
        if completeAilment(chosenKind, chosenIsPet and petUid or tostring(LocalPlayer.UserId), chosenIsPet, petUid, petCharWrapper) then
            ctx.Runtime.Telemetry.TasksCompleted = ctx.Runtime.Telemetry.TasksCompleted + 1
            return true
        end
        return false
    end

    function DF.TryAutoLure()
        local F = States.Farm
        if not F.AutoLure or os.clock() - Cooldowns.LastLureAt < 10 then return false end
        local LuresNet = Bridge.Mod.LuresNet
        if not LuresNet then return false end

        local d = Bridge.GetMyData()
        local lm = d and d.lures_2023_lure_manager
        if not lm then return false end
        Cooldowns.LastLureAt = os.clock()

        local luresMap = lm.lures_map or {}
        local lureSlots = { "BasicLure" }
        if lm.owns_premium_lure then
            table.insert(lureSlots, "PremiumLure")
        end

        local invDB = Bridge.Mod.InventoryDB
        for _, slot in ipairs(lureSlots) do
            local state = luresMap[slot]
            if state and state.finished then
                pcall(function()
                    LuresNet.ClaimLure:invoke_server_async(slot)
                end)
                ctx.Runtime.Telemetry.LuresClaimed = ctx.Runtime.Telemetry.LuresClaimed + 1
                ctx.Runtime.Status.Farm = "Lure ödülü toplandı: " .. slot
                return true
            elseif not state then
                local bait = findInventoryItem("food", function(it)
                    local meta = invDB and invDB.food and invDB.food[it.kind or it.id]
                    if not meta or not meta.is_lure_bait then return false end
                    if F.LureBaitMode == "Free Campfire Cookie Only" then
                        return string.find(tostring(it.id or it.kind), "campfire", 1, true) ~= nil
                    end
                    return true
                end)
                if bait then
                    pcall(function()
                        LuresNet.BaitLure:fire_server({ lure_type = slot, bait_unique = bait.unique })
                    end)
                    ctx.Runtime.Status.Farm = "Lure yemlendi: " .. tostring(bait.id or bait.kind)
                    return true
                end
            end
        end
        return false
    end

    function DF.TryAutoBuyEggs()
        local F = States.Farm
        if not F.AutoBuyEggs or os.clock() - Cooldowns.LastEggBuyAt < 6 then return false end
        local money = Bridge.GetMoney()
        local minKeep = tonumber(F.BuyEggMinBucks) or 750
        local eggId = tostring(F.SelectedEgg or "fairytale_egg_2026_fairytale_egg")
        local info = getPetInfo(eggId)
        local cost = (info and tonumber(info.cost)) or minKeep
        if money < math.max(minKeep, cost) then return false end

        Cooldowns.LastEggBuyAt = os.clock()
        local ok = Bridge.RouteInvoke("ShopAPI/BuyItem", "pets", eggId, {})
        if ok then
            ctx.Runtime.Status.Farm = "Yumurta satın alındı: " .. eggId
            return true
        end
        return false
    end

    function DF.TryClaimDailies()
        if not States.Farm.AutoClaimDailyAndPlaytime then return false end
        if os.clock() - Cooldowns.LastDailyAt < 30 then return false end
        Cooldowns.LastDailyAt = os.clock()
        pcall(function()
            Bridge.RouteFire("LootBoxAPI/ClaimLoginHandouts")
        end)
        return false
    end

    function DF.StepOnce()
        local money = Bridge.GetMoney()
        if ctx.Runtime.StartMoney == 0 and money > 0 then
            ctx.Runtime.StartMoney = money
        elseif ctx.Runtime.StartMoney > 0 and money > ctx.Runtime.StartMoney then
            ctx.Runtime.Telemetry.BucksEarned = money - ctx.Runtime.StartMoney
        end

        DF.TryClaimDailies()
        if DF.TryRotatePetOrEgg() then return end
        if DF.TryStepAilments() then return end
        if DF.TryAutoLure() then return end
        DF.TryAutoBuyEggs()
    end

    ctx.DualFarm = DF
    return DF
end

return DualFarmSystem
