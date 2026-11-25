-- src/Systems/Events/EventsAndWorldSystem.lua
-- 2026 Events, Lightning Dimension, Auto-Minigames, Teleport Nodes & Special Treats

local EventsAndWorldSystem = {}

function EventsAndWorldSystem.Init(ctx)
    local Bridge = ctx.Bridge
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle
    local Utils = ctx.Utils
    local RS = ctx.Roblox.ReplicatedStorage
    local Players = ctx.Roblox.Players

    local S = {}

    -- Verified 2026 Adopt Me Teleport & Interior Nodes
    S.TeleportNodes = {
        { id = "MainMap", label = "Ana Harita (Town)", type = "interior", dest = "MainMap", door = "Neighborhood!MainDoor" },
        { id = "Housing", label = "Kendi Evim (Home)", type = "interior", dest = "housing", door = "MainDoor" },
        { id = "Nursery", label = "Kreş (Nursery)", type = "interior", dest = "Nursery", door = "MainDoor" },
        { id = "Hospital", label = "Hayvan Hastanesi (Hospital)", type = "interior", dest = "Hospital", door = "MainDoor" },
        { id = "School", label = "Okul (School)", type = "interior", dest = "School", door = "MainDoor" },
        { id = "Salon", label = "Bakım Salonu (Salon)", type = "interior", dest = "Salon", door = "MainDoor" },
        { id = "CatCafe", label = "Cat Cafe (2026)", type = "interior", dest = "CatCafe", door = "MainDoor" },
        { id = "NeonCave", label = "Neon Mağarası (Neon Cave)", type = "interior", dest = "Cave", door = "MainDoor" },
        { id = "VIP", label = "VIP Odası", type = "interior", dest = "VIP", door = "MainDoor" },
        { id = "TradeHub", label = "Takas Merkezi (Trade Hub)", type = "interior", dest = "TradeHub", door = "MainDoor" },
        { id = "LightningDimension", label = "Lightning Dimension (2026)", type = "interior", dest = "LightningDimension", door = "MainDoor" },
        { id = "PetShop", label = "Pet Shop", type = "interior", dest = "PetShop", door = "MainDoor" },
        { id = "Supermarket", label = "Süpermarket", type = "interior", dest = "Supermarket", door = "MainDoor" },
        { id = "CoffeeShop", label = "Kahve Dükkanı", type = "interior", dest = "CoffeeShop", door = "MainDoor" },
        { id = "PizzaShop", label = "Pizza Dükkanı", type = "interior", dest = "IceCream", door = "MainDoor" },
        { id = "ToyShop", label = "Oyuncakçı (Toy Shop)", type = "interior", dest = "ToyShop", door = "MainDoor" },
        { id = "SkyCastle", label = "Gökyüzü Kalesi (Sky Castle)", type = "interior", dest = "SkyCastle", door = "MainDoor" },
        { id = "Playground", label = "Oyun Parkı (Playground)", type = "static", loc = "exterior_park" },
        { id = "Camping", label = "Kamp Alanı (Camping)", type = "static", loc = "exterior_camping" },
        { id = "Beach", label = "Sahil (Beach Party)", type = "static", loc = "exterior_beach" },
        { id = "AFKZone", label = "AFK Bölgesi", type = "interior", dest = "AFKZone", door = "MainDoor" },
    }

    local nodeMap = {}
    for _, node in ipairs(S.TeleportNodes) do
        nodeMap[node.id] = node
        nodeMap[node.label] = node
    end

    function S.GetTeleportLabels()
        local list = {}
        for _, node in ipairs(S.TeleportNodes) do
            table.insert(list, node.label)
        end
        return list
    end

    function S.TeleportTo(keyOrLabel)
        local node = nodeMap[keyOrLabel]
        if not node then return false end
        if node.type == "interior" then
            if node.dest == "housing" then
                local lp = Players.LocalPlayer
                local ok = Bridge.EnterInterior("housing", "MainDoor", { house_owner = lp })
                ctx.Runtime.Status.Events = ok and "Eve ışınlanıldı" or "Ev girişi bekliyor"
                return ok
            end
            local ok = Bridge.EnterInterior(node.dest, node.door or "MainDoor")
            ctx.Runtime.Status.Events = ok and ("Gidildi: " .. node.label) or ("Gidilemedi: " .. node.dest)
            return ok
        elseif node.type == "static" then
            local ok = Bridge.TeleportStaticLocation(node.loc)
            ctx.Runtime.Status.Events = ok and ("Gidildi: " .. node.label) or ("Konum bulunamadı: " .. node.loc)
            return ok
        end
        return false
    end

    -- Helper to collect nearby Lightning Dimension objects/bottles
    local function stepLightningDimension()
        if (os.clock() - ctx.Runtime.Cooldowns.LastEventAt) < 1.5 then
            return
        end
        ctx.Runtime.Cooldowns.LastEventAt = os.clock()

        local cur = Bridge.GetCurrentLocation()
        if not cur or cur.destination_id ~= "LightningDimension" then
            Bridge.EnterInterior("LightningDimension", "MainDoor")
            ctx.Runtime.Status.Events = "Lightning Dimension'a giriliyor"
            return
        end

        local ldNet = Bridge.Mod.LightningNet
        if ldNet then
            pcall(function()
                if ldNet.TakeBottle and ldNet.TakeBottle.invoke_server_async then
                    ldNet.TakeBottle:invoke_server_async()
                end
            end)
            pcall(function()
                if ldNet.CloseCap and ldNet.CloseCap.fire_server then
                    ldNet.CloseCap:fire_server()
                end
            end)
        end

        -- Move to nearby collectible bottle / lightning orb in workspace Interiors
        local interiors = workspace:FindFirstChild("Interiors")
        local ldFolder = interiors and interiors:FindFirstChild("LightningDimension")
        if ldFolder then
            local _, hrp = Utils.getCharacterParts()
            local bestPos = nil
            local bestDist = math.huge
            for _, desc in ipairs(ldFolder:GetDescendants()) do
                if desc:IsA("BasePart") or desc:IsA("Model") then
                    local lname = string.lower(desc.Name)
                    if string.find(lname, "bottle", 1, true) or string.find(lname, "lightning", 1, true) or string.find(lname, "orb", 1, true) or string.find(lname, "coin", 1, true) then
                        local pos = Utils.getPos(desc)
                        if pos and hrp then
                            local d = (pos - hrp.Position).Magnitude
                            if d > 4 and d < 350 and d < bestDist then
                                bestDist = d
                                bestPos = pos
                            end
                        end
                    end
                end
            end
            if bestPos then
                Utils.moveToPosition(bestPos, 0.25)
                ctx.Runtime.Status.Events = "Lightning nesnesi toplanıyor"
                return
            end
        end
        ctx.Runtime.Status.Events = "Lightning Dimension taranıyor"
    end

    -- Auto Minigames: inspect MinigameClientManager & AttemptJoin / LobbyStart
    local function stepMinigames()
        if (os.clock() - ctx.Runtime.Cooldowns.LastMinigameAt) < 3.0 then
            return
        end
        ctx.Runtime.Cooldowns.LastMinigameAt = os.clock()

        local mcm = Bridge.Mod.MinigameClientManager
        local allMgs = mcm and mcm.get_all and mcm.get_all() or {}
        local joinedAny = false

        for id, mg in pairs(allMgs) do
            pcall(function()
                local isActive = (mg.is_participating and mg:is_participating()) or (mg.ingame == true)
                if isActive then
                    joinedAny = true
                    ctx.Runtime.Status.Events = "Mini oyun aktif: " .. tostring(id)
                    if type(mg.collect_nearby) == "function" then
                        mg:collect_nearby()
                    end
                elseif mg.join_zone_position or mg.can_join then
                    Bridge.RouteInvoke("MinigameAPI/AttemptJoin", id)
                    Bridge.RouteFire("MinigameAPI/LobbyStart", id)
                end
            end)
        end

        if not joinedAny then
            -- Also check if join popup prompt is open
            pcall(function()
                local ui = Bridge.Mod.UIManager
                if ui and ui.apps and ui.apps.MinigameJoinApp then
                    local app = ui.apps.MinigameJoinApp
                    if app.visible and app.join_button_pressed then
                        app:join_button_pressed()
                    end
                end
            end)
        end
    end

    -- Use special food treats: Kitty Biscuit (Cat Cafe) & Age-Up Potions
    function S.UseSpecialItemByKinds(kinds)
        local invFood = Bridge.GetInventory("food")
        local pets = Bridge.GetEquippedPets()
        local targetPet = pets[1]
        if not targetPet then
            return false, "Kuşanılmış pet yok"
        end
        local kindSet = {}
        for _, k in ipairs(kinds) do
            kindSet[k] = true
        end
        for _, item in pairs(invFood) do
            if kindSet[item.kind or item.id] then
                if Bridge.Mod.UseItemHelper and Bridge.Mod.UseItemHelper.use_item then
                    pcall(Bridge.Mod.UseItemHelper.use_item, targetPet, item)
                else
                    Bridge.RouteInvoke("ToolAPI/Equip", item.unique, { use_sound_delay = false })
                end
                return true, tostring(item.kind or item.id)
            end
        end
        return false, "Envanterde bulunamadı"
    end

    Lifecycle.SpawnLoop("EventsAndWorld", 1.0, function()
        if States.Events.AutoLightningDimension then
            stepLightningDimension()
        end
        if States.Events.AutoMinigames then
            stepMinigames()
        end
        if States.Events.AutoUseKittyBiscuit then
            local pets = Bridge.GetEquippedPets()
            if #pets > 0 then
                S.UseSpecialItemByKinds({ "cat_cafe_2026_kitty_biscuit" })
            end
        end
        if States.Events.AutoUseAgePotions then
            local pets = Bridge.GetEquippedPets()
            local first = pets[1]
            local age = first and first.properties and tonumber(first.properties.age) or 6
            if first and age < 6 then
                S.UseSpecialItemByKinds({ "super_age_potion", "pet_age_potion", "tiny_pet_age_potion" })
            end
        end
    end)

    ctx.API.Events = S
    return S
end

return EventsAndWorldSystem
