-- src/Systems/Farm/DualFarmSystem.lua
-- Verified 2026 Dual Farm (Baby + Pet), Starter Egg & Beginner Friendly, Anti-Stuck Scheduler

local DualFarmSystem = {}

function DualFarmSystem.Init(ctx)
    local Bridge = ctx.Bridge
    local Utils = ctx.Utils
    local States = ctx.States
    local Cooldowns = ctx.Runtime.Cooldowns
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService

    local DF = {
        _attemptCooldowns = {},
        _busy = false,
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
        pizza_party = { dest = "PizzaShop", door = "MainDoor" },
        salon = { dest = "Salon", door = "MainDoor" },
        cat_cafe = { dest = "CatCafe", door = "MainDoor" },
    }

    local STATIC_AILMENTS = {
        bored = "bored",
        camping = "camping",
        beach_party = "beach_party",
        swim = "swim",
    }

    -- Instant tasks run with higher priority than 50s waiting tasks
    local TASK_PRIORITY = {
        mystery = 1,
        pet_me = 2,
        sick = 3,
        hungry = 4,
        thirsty = 5,
        sleepy = 6,
        dirty = 7,
        toilet = 8,
        play = 9,
        walk = 10,
        ride = 10,
        swim = 10,
        leaf_pile = 10,
        rain_puddle = 10,
        snowman = 10,
        school = 15,
        pizza_party = 15,
        salon = 15,
        cat_cafe = 15,
        bored = 15,
        camping = 15,
        beach_party = 15,
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

    local function isAilmentPresent(scopeKey, kind)
        local am = Bridge.GetAilmentsManager()
        if scopeKey == "baby" then
            return am.baby_ailments and am.baby_ailments[kind] ~= nil
        end
        return am.ailments and am.ailments[scopeKey] and am.ailments[scopeKey][kind] ~= nil
    end

    local function getAilmentEntry(scopeKey, kind)
        local am = Bridge.GetAilmentsManager()
        if scopeKey == "baby" then
            return am.baby_ailments and am.baby_ailments[kind] or nil
        end
        return am.ailments and am.ailments[scopeKey] and am.ailments[scopeKey][kind] or nil
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
                ctx.Runtime.Status.Farm = "Rol: Bebek (Babies) seçildi"
                task.wait(0.35)
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
                        -- Prefer starter_egg first for brand-new players
                        if pet.id == "starter_egg" then
                            return uid
                        end
                        bestUid = bestUid or uid
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
        if not F.DualFarm then return false end
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
                task.wait(0.4)
                return true
            end
        end
        return false
    end

    local function consumePlayerItem(itemUid, scopeKey, ailmentKind)
        if not itemUid then return false end
        Bridge.RouteFire("ToolAPI/UnequipAll")
        task.wait(0.15)
        Bridge.RouteInvoke("ToolAPI/Equip", itemUid, { use_sound_delay = false })
        task.wait(0.2)
        for _ = 1, 6 do
            if not isAilmentPresent(scopeKey, ailmentKind) then
                return true
            end
            Bridge.RouteInvoke("ToolAPI/ServerUseTool", itemUid, "START")
            local okEnd, used = Bridge.RouteInvoke("ToolAPI/ServerUseTool", itemUid, "END")
            task.wait(0.3)
            if not isAilmentPresent(scopeKey, ailmentKind) then
                return true
            end
            if not okEnd or used == false then
                break
            end
        end
        Bridge.RouteFire("ToolAPI/UnequipAll")
        return not isAilmentPresent(scopeKey, ailmentKind)
    end

    -- Feeds ANY pet OR unhatched Egg (like Starter Egg) directly via PetActions.feed_pet without FocusPetApp lockouts
    local function feedPetDirect(petCharWrapper, item, scopeKey, ailmentKind)
        if not petCharWrapper or not petCharWrapper.char or not item then
            return false
        end
        local ui = Bridge.Mod.UIManager
        local fpa = ui and ui.apps and ui.apps.FocusPetApp
        if fpa and fpa.release_focus and fpa.visible then
            pcall(function() fpa:release_focus() end)
            task.wait(0.2)
        end
        pcall(Bridge.RouteInvoke, "PetAPI/ExitFurnitureUseStates")
        Bridge.RouteFire("ToolAPI/UnequipAll")
        task.wait(0.15)

        local PA = Bridge.Mod.Fsys and pcall(Bridge.Mod.Fsys.load, "PetActions") and Bridge.Mod.Fsys.load("PetActions")
        local pChar = petCharWrapper.char
        local pRoot = pChar:FindFirstChild("HumanoidRootPart") or select(2, Utils.getCharacterParts())
        local spawnCF = pRoot and (pRoot.CFrame * CFrame.new(0, 1, -2)) or CFrame.new()

        local fedObj = nil
        local okFeed = false
        if PA and PA.feed_pet then
            local okCall, r1, r2 = pcall(function()
                return PA.feed_pet(petCharWrapper, {
                    item = item,
                    spawn_cframe = spawnCF,
                })
            end)
            okFeed = okCall and r1 == true
            fedObj = r2
        elseif Bridge.Mod.UseItemHelper and Bridge.Mod.UseItemHelper.use_item then
            okFeed = pcall(Bridge.Mod.UseItemHelper.use_item, petCharWrapper, item)
        end

        if not okFeed then
            return false
        end

        local deadline = os.clock() + 6.5
        while os.clock() < deadline and States.Farm.DualFarm do
            task.wait(0.45)
            if not isAilmentPresent(scopeKey, ailmentKind) then
                return true
            end
            if fedObj and typeof(fedObj) == "Instance" and fedObj.Parent and (os.clock() > deadline - 3.0) then
                Bridge.RouteFire("PetAPI/ConsumeFoodObject", fedObj, petCharWrapper.pet_unique)
            end
        end
        return not isAilmentPresent(scopeKey, ailmentKind)
    end

    local function activateHouseFurnitureAndWait(idPatterns, charTarget, scopeKey, ailmentKind, maxWaitSec)
        if not charTarget then return false end
        if not Bridge.EnterOwnHouse() then return false end
        task.wait(0.45)

        local furnUid, useBlockName = Bridge.FindOwnHouseFurniture(idPatterns)
        if not furnUid then return false end

        local _, hrp, hum = Utils.getCharacterParts()
        local cf = (hrp and hrp.CFrame) or CFrame.new()

        task.spawn(function()
            Bridge.RouteInvoke("HousingAPI/ActivateFurniture", LocalPlayer, furnUid, useBlockName or "UseBlock", { cframe = cf }, charTarget)
        end)

        local deadline = os.clock() + (maxWaitSec or 12)
        while os.clock() < deadline and States.Farm.DualFarm do
            task.wait(0.5)
            if not isAilmentPresent(scopeKey, ailmentKind) then
                pcall(function()
                    if hum and hum.Sit then
                        hum.Sit = false
                        hum.Jump = true
                    end
                    Bridge.RouteInvoke("PetAPI/ExitFurnitureUseStates")
                end)
                return true
            end
        end

        pcall(function()
            if hum and hum.Sit then
                hum.Sit = false
                hum.Jump = true
            end
            Bridge.RouteInvoke("PetAPI/ExitFurnitureUseStates")
        end)
        return not isAilmentPresent(scopeKey, ailmentKind)
    end

    local function completeAilment(kind, scopeKey, isPet, petUid, petCharWrapper)
        local invDB = Bridge.Mod.InventoryDB

        -- 1. Mystery Ailment (resolves real seeded slots via MysteryHelper/MysteryAilmentClient & picks fastest task)
        if kind == "mystery" and States.Farm.AutoMysteryAilment and isPet and petUid and petCharWrapper then
            pcall(function()
                local entry = getAilmentEntry(scopeKey, kind)
                local mysteryMod = Bridge.Mod.AilmentsDB and Bridge.Mod.AilmentsDB.mystery
                local act = mysteryMod and mysteryMod.create_action and entry and mysteryMod.create_action(entry)
                local slots = act and act._get_ailment_slots and act:_get_ailment_slots(petCharWrapper) or nil
                local key = (entry and entry.components and entry.components.mystery and entry.components.mystery.ailment_key) or "mystery"

                if type(slots) == "table" then
                    local bestIdx, bestKind, bestPrio = nil, nil, math.huge
                    for idx, sKind in pairs(slots) do
                        local p = TASK_PRIORITY[sKind] or 12
                        if p < bestPrio then
                            bestPrio = p
                            bestIdx = idx
                            bestKind = sKind
                        end
                    end
                    if bestIdx and bestKind then
                        Bridge.RouteFire("AilmentsAPI/ChooseMysteryAilment", petUid, key, bestIdx, bestKind)
                        ctx.Runtime.Status.Farm = "Gizemli görev seçildi: " .. tostring(bestKind)
                    end
                end
            end)
            task.wait(0.5)
            return not isAilmentPresent(scopeKey, kind)
        end

        -- 2. Pet Me (requires FocusPetApp:capture_focus(petCharWrapper) -> PetPetted + ProgressPetMeAilment)
        if kind == "pet_me" and isPet and petUid and petCharWrapper then
            ctx.Runtime.Status.Farm = "Pet okşanıyor (pet_me)..."
            local ui = Bridge.Mod.UIManager
            local fpa = ui and ui.apps and ui.apps.FocusPetApp
            if fpa and fpa.capture_focus then
                pcall(function() fpa:capture_focus(petCharWrapper) end)
                task.wait(0.35)
                Bridge.RouteFire("PetAPI/PetPetted", petUid, LocalPlayer)
                Bridge.RouteFire("AilmentsAPI/ProgressPetMeAilment", petUid)
                task.wait(0.85)
                if fpa.release_focus then
                    pcall(function() fpa:release_focus() end)
                end
            else
                Bridge.RouteFire("AdoptAPI/FocusPet", petCharWrapper.char)
                Bridge.RouteFire("PetAPI/PetPetted", petUid, LocalPlayer)
                Bridge.RouteFire("AilmentsAPI/ProgressPetMeAilment", petUid)
                task.wait(0.85)
                Bridge.RouteFire("AdoptAPI/UnfocusPet", petCharWrapper.char)
            end
            return not isAilmentPresent(scopeKey, kind)
        end

        -- 3. Sick -> FREE healing_apple cure (or Hospital fallback)
        if kind == "sick" then
            ctx.Runtime.Status.Farm = "Hastalık iyileştiriliyor (sick)..."
            local healItem = findInventoryItem("food", function(it)
                return (it.id or it.kind) == "healing_apple"
            end)
            if not healItem then
                Bridge.RouteInvoke("ShopAPI/BuyItem", "food", "healing_apple", {})
                task.wait(0.25)
                healItem = findInventoryItem("food", function(it)
                    return (it.id or it.kind) == "healing_apple"
                end)
            end
            if healItem then
                if not isPet then
                    if consumePlayerItem(healItem.unique, scopeKey, kind) then
                        return true
                    end
                elseif petCharWrapper then
                    if feedPetDirect(petCharWrapper, healItem, scopeKey, kind) then
                        return true
                    end
                end
            end
            Bridge.EnterInterior("Hospital", "MainDoor")
            return not isAilmentPresent(scopeKey, kind)
        end

        -- 4. Hungry
        if kind == "hungry" then
            ctx.Runtime.Status.Farm = isPet and "Pet besleniyor..." or "Bebek yemek yiyor..."

            local foodItem = findInventoryItem("food", function(it)
                local d = invDB and invDB.food and invDB.food[it.kind or it.id]
                return d and (d.ailment_to_boost == "hungry" or string.find(tostring(it.id), "sandwich", 1, true) or string.find(tostring(it.id), "apple", 1, true))
            end)
            if not foodItem and Bridge.GetMoney() >= 1 then
                Bridge.RouteInvoke("ShopAPI/BuyItem", "food", "apple", {})
                task.wait(0.25)
                foodItem = findInventoryItem("food", function(it) return (it.id or it.kind) == "apple" end)
            end
            if foodItem then
                if not isPet then
                    if consumePlayerItem(foodItem.unique, scopeKey, kind) then
                        return true
                    end
                elseif petCharWrapper then
                    if feedPetDirect(petCharWrapper, foodItem, scopeKey, kind) then
                        return true
                    end
                end
            end
            if isPet and petCharWrapper and petCharWrapper.char then
                if activateHouseFurnitureAndWait({ "pet_food_bowl", "food_bowl", "ailments_refresh_2024_cheap_food_bowl" }, petCharWrapper.char, scopeKey, kind, 8) then
                    return true
                end
            end
            return false
        end

        -- 5. Thirsty
        if kind == "thirsty" then
            ctx.Runtime.Status.Farm = isPet and "Pet su içiyor..." or "Bebek su içiyor..."

            local drinkItem = findInventoryItem("food", function(it)
                local d = invDB and invDB.food and invDB.food[it.kind or it.id]
                return d and d.ailment_to_boost == "thirsty"
            end)
            if not drinkItem and Bridge.GetMoney() >= 1 then
                Bridge.RouteInvoke("ShopAPI/BuyItem", "food", "water", {})
                task.wait(0.25)
                drinkItem = findInventoryItem("food", function(it) return (it.id or it.kind) == "water" end)
            end
            if drinkItem then
                if not isPet then
                    if consumePlayerItem(drinkItem.unique, scopeKey, kind) then
                        return true
                    end
                elseif petCharWrapper then
                    if feedPetDirect(petCharWrapper, drinkItem, scopeKey, kind) then
                        return true
                    end
                end
            end
            if isPet and petCharWrapper and petCharWrapper.char then
                if activateHouseFurnitureAndWait({ "pet_water_bowl", "water_bowl", "ailments_refresh_2024_cheap_water_bowl" }, petCharWrapper.char, scopeKey, kind, 8) then
                    return true
                end
            end
            return false
        end

        -- 6. Sleepy (House bed/crib -> wait until cleared!)
        if kind == "sleepy" then
            local targetChar = isPet and (petCharWrapper and petCharWrapper.char) or LocalPlayer.Character
            ctx.Runtime.Status.Farm = isPet and "Pet uyutuluyor (Ev Yatağı)..." or "Bebek uyutuluyor (Ev Yatağı)..."
            if activateHouseFurnitureAndWait({ "basicbed", "basiccrib", "crib", "bed" }, targetChar, scopeKey, kind, 14) then
                return true
            end
            Bridge.EnterInterior("Nursery", "MainDoor")
            return false
        end

        -- 7. Dirty (House shower/bathtub -> wait until cleared!)
        if kind == "dirty" then
            local targetChar = isPet and (petCharWrapper and petCharWrapper.char) or LocalPlayer.Character
            local patterns = isPet
                and { "cheap_pet_bathtub", "cheapbathtub", "pet_bathtub", "bathtub", "modernshower", "shower" }
                or { "modernshower", "shower", "bathtub", "cheapbathtub" }
            ctx.Runtime.Status.Farm = isPet and "Pet yıkanıyor (Küvet)..." or "Bebek duş alıyor..."
            if activateHouseFurnitureAndWait(patterns, targetChar, scopeKey, kind, 14) then
                return true
            end
            if isPet and petUid then
                Bridge.RouteFire("AilmentsAPI/ProgressDirtyAilment", petUid)
            end
            Bridge.EnterInterior("Salon", "MainDoor")
            return not isAilmentPresent(scopeKey, kind)
        end

        -- 8. Toilet (House toilet / litter box OR FireHydrantServer)
        if kind == "toilet" and isPet then
            if petCharWrapper and petCharWrapper.char then
                if activateHouseFurnitureAndWait({ "litter_box", "toilet" }, petCharWrapper.char, scopeKey, kind, 10) then
                    return true
                end
            end
            local hydrants = CollectionService:GetTagged("FireHydrantServer")
            if #hydrants > 0 then
                local pos = Utils.getPos(hydrants[1])
                if pos then
                    local cur = Bridge.GetCurrentLocation()
                    if not cur or cur.destination_id ~= "MainMap" then
                        Bridge.EnterInterior("MainMap", "Neighborhood!MainDoor")
                        task.wait(0.6)
                    end
                    Utils.moveToPosition(pos, 0.3)
                    ctx.Runtime.Status.Farm = "Tuvalet görevi (Yangın Musluğu)"
                    task.wait(2.5)
                    return not isAilmentPresent(scopeKey, kind)
                end
            end
            return false
        end

        -- 9. Play
        if kind == "play" and isPet and petCharWrapper then
            local toy = findInventoryItem("toys", function(it)
                local d = invDB and invDB.toys and invDB.toys[it.kind or it.id]
                return d and (d.tool == "ThrowToyTool" or d.tool == "ChewToyTool" or d.tool == "SqueakyToyTool")
            end)
            if toy then
                ctx.Runtime.Status.Farm = "Oyun görevi (" .. tostring(toy.id or toy.kind) .. ")"
                Bridge.RouteInvoke("ToolAPI/Equip", toy.unique, { use_sound_delay = false })
                task.wait(0.25)
                Bridge.RouteInvoke("PetObjectAPI/CreatePetObject", "__Enum_PetObjectCreatorType_1", {
                    reaction_name = "ThrowToyReaction",
                    unique_id = toy.unique,
                })
                task.wait(2.0)
                return not isAilmentPresent(scopeKey, kind)
            end
            return false
        end

        -- 10. Golden Interior RateArea (school, pizza_party, salon, cat_cafe)
        if INTERIOR_AILMENTS[kind] then
            local target = INTERIOR_AILMENTS[kind]
            local cur = Bridge.GetCurrentLocation()
            if not cur or cur.destination_id ~= target.dest then
                Bridge.EnterInterior(target.dest, target.door)
                task.wait(0.8)
            end
            ctx.Runtime.Status.Farm = string.format("Konumda bekleniyor: %s (%s)", kind, target.dest)
            return false -- RateArea stays open smoothly without spamming completion count
        end

        -- 11. Golden StaticMap RateArea (bored, camping, beach_party)
        if STATIC_AILMENTS[kind] then
            Bridge.TeleportStaticLocation(STATIC_AILMENTS[kind])
            ctx.Runtime.Status.Farm = "Harita alanında bekleniyor: " .. kind
            return false
        end

        -- 12. Movement / Ride / Weather (ride requires Stroller/Vehicle state; walk allows free movement)
        if kind == "walk" or kind == "ride" or kind == "leaf_pile" or kind == "rain_puddle" or kind == "snowman" then
            local curLoc = Bridge.GetCurrentLocation()
            if not curLoc or curLoc.destination_id ~= "MainMap" then
                Bridge.EnterInterior("MainMap", "Neighborhood!MainDoor")
                task.wait(0.8)
            end

            local usingStroller = false
            if kind == "ride" and isPet and petCharWrapper then
                local stItem = findInventoryItem("strollers", function() return true end)
                if stItem and Bridge.Mod.UseItemHelper and Bridge.Mod.UseItemHelper.use_item then
                    stItem.category = stItem.category or "strollers"
                    stItem.kind = stItem.kind or stItem.id
                    pcall(Bridge.Mod.UseItemHelper.use_item, petCharWrapper, stItem)
                    usingStroller = true
                    task.wait(1.0)
                end
            end

            local _, hrp, hum = Utils.getCharacterParts()
            if hrp and hum then
                if hum.Sit then hum.Sit = false; hum.Jump = true; task.wait(0.15) end
                local origin = hrp.Position
                local targets = {
                    origin + Vector3.new(45, 0, 0),
                    origin + Vector3.new(45, 0, 45),
                    origin + Vector3.new(-45, 0, 45),
                    origin + Vector3.new(-45, 0, 0),
                }
                local step = 0
                local deadline = os.clock() + 36
                while os.clock() < deadline and States.Farm.DualFarm and isAilmentPresent(scopeKey, kind) do
                    step = (step % #targets) + 1
                    hum:MoveTo(targets[step])
                    local subEnd = os.clock() + 2.4
                    while os.clock() < subEnd and States.Farm.DualFarm and isAilmentPresent(scopeKey, kind) do
                        local ent = getAilmentEntry(scopeKey, kind)
                        local pct = ent and math.floor((tonumber(ent.progress) or 0) * 100) or 0
                        ctx.Runtime.Status.Farm = string.format("%s (%s): %%%d", usingStroller and "Bebek Arabası Turu" or "Yürüyüş / Hareket", kind, pct)
                        task.wait(0.5)
                    end
                end
                pcall(function() hum:MoveTo(hrp.Position) end)
            end

            if usingStroller then
                Bridge.RouteFire("ToolAPI/UnequipAll")
            end
            return not isAilmentPresent(scopeKey, kind)
        end

        return false
    end

    function DF.TryStepAilments()
        local F = States.Farm
        if not (F.DualFarm and F.AutoAilments) then return false end
        if DF._busy then return false end
        if os.clock() - Cooldowns.LastAilmentStepAt < 1.5 then return false end

        DF._busy = true
        local okStep, didRun = pcall(function()
            ensureBabyTeam()

            local am = Bridge.GetAilmentsManager()
            local petUid, petCharWrapper = getActivePetUniqueAndWrapper()
            local now = os.clock()

            -- Build candidate task list across BOTH Baby and Active Pet, sorted by priority & cooldown
            local candidates = {}
            local activeRateName = nil

            if petUid and am.ailments and type(am.ailments[petUid]) == "table" then
                for k, a in pairs(am.ailments[petUid]) do
                    if type(a) == "table" then
                        local ak = a.kind or k
                        local cdKey = tostring(petUid) .. ":" .. tostring(ak)
                        local rate = tonumber(a.rate) or 0
                        if rate > 0 then
                            activeRateName = activeRateName or (tostring(ak) .. " (%" .. tostring(math.floor((tonumber(a.progress) or 0) * 100)) .. ")")
                        elseif (DF._attemptCooldowns[cdKey] or 0) <= now then
                            table.insert(candidates, {
                                kind = ak,
                                scopeKey = petUid,
                                isPet = true,
                                prio = TASK_PRIORITY[ak] or 12,
                                cdKey = cdKey,
                            })
                        end
                    end
                end
            end

            if type(am.baby_ailments) == "table" then
                for k, a in pairs(am.baby_ailments) do
                    if type(a) == "table" then
                        local ak = a.kind or k
                        local cdKey = "baby:" .. tostring(ak)
                        local rate = tonumber(a.rate) or 0
                        if rate > 0 then
                            activeRateName = activeRateName or (tostring(ak) .. " (%" .. tostring(math.floor((tonumber(a.progress) or 0) * 100)) .. ")")
                        elseif (DF._attemptCooldowns[cdKey] or 0) <= now then
                            table.insert(candidates, {
                                kind = ak,
                                scopeKey = "baby",
                                isPet = false,
                                prio = (TASK_PRIORITY[ak] or 12) + 0.1,
                                cdKey = cdKey,
                            })
                        end
                    end
                end
            end

            -- If a task is actively filling via RateArea/Furniture, only run instant in-place tasks (prio <= 5) so we don't teleport away mid-bar
            if activeRateName then
                local inPlaceOnly = {}
                for _, c in ipairs(candidates) do
                    if c.prio <= 5.2 and (c.isPet or c.kind == "sick" or c.kind == "hungry" or c.kind == "thirsty") then
                        if c.kind == "pet_me" or c.kind == "mystery" or not c.isPet then
                            table.insert(inPlaceOnly, c)
                        end
                    end
                end
                candidates = inPlaceOnly
            end

            if #candidates == 0 then
                ctx.Runtime.Status.Farm = activeRateName and ("Doluyor: " .. activeRateName) or "Yeni görev bekleniyor..."
                return false
            end

            table.sort(candidates, function(a, b)
                return a.prio < b.prio
            end)

            -- Never jump away from an active RateArea location for another long RateArea; allow quick local tasks only
            local cand = candidates[1]
            Cooldowns.LastAilmentStepAt = os.clock()
            -- Anti-stuck cooldown: if a task doesn't complete immediately, wait 12s (or 20s for RateArea) before retrying it
            DF._attemptCooldowns[cand.cdKey] = os.clock() + (cand.prio >= 15 and 18 or 8)

            local completed = completeAilment(cand.kind, cand.scopeKey, cand.isPet, petUid, petCharWrapper)
            if completed then
                ctx.Runtime.Telemetry.TasksCompleted = ctx.Runtime.Telemetry.TasksCompleted + 1
                DF._attemptCooldowns[cand.cdKey] = nil
                ctx.Runtime.Status.Farm = "Tamamlandı: " .. tostring(cand.kind)
                return true
            end
            return false
        end)

        DF._busy = false
        return okStep and didRun == true
    end

    function DF.TryAutoLure()
        local F = States.Farm
        if not F.AutoLure or os.clock() - Cooldowns.LastLureAt < 8 then return false end
        local LuresNet = Bridge.Mod.LuresNet
        local invDB = Bridge.Mod.InventoryDB
        if not LuresNet then return false end

        local data = Bridge.GetMyData()
        local lureMgr = data and data.lures_2023_lure_manager
        if not lureMgr then return false end

        Cooldowns.LastLureAt = os.clock()

        for slot, state in pairs(lureMgr.lures_by_type or {}) do
            if type(state) == "table" and state.reward_ready then
                pcall(function()
                    LuresNet.ClaimLure:invoke_server_async(slot)
                end)
                ctx.Runtime.Telemetry.LuresClaimed = ctx.Runtime.Telemetry.LuresClaimed + 1
                ctx.Runtime.Status.Farm = "Lure ödülü toplandı"
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
