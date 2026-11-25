-- src/Core/Bridge.lua
-- Clean, fault-tolerant wrapper over Adopt Me's Fsys, ClientData, RouterClient, InteriorsM & new modules

local Bridge = {}

function Bridge.Init(ctx)
    local RS = ctx.Roblox.ReplicatedStorage
    local LocalPlayer = ctx.Roblox.LocalPlayer

    local function safeReq(inst)
        if not inst then return nil end
        local ok, mod = pcall(require, inst)
        return ok and mod or nil
    end

    local Fsys = safeReq(RS:FindFirstChild("Fsys"))
    local function fsysLoad(name)
        if not Fsys or type(Fsys.load) ~= "function" then return nil end
        local ok, mod = pcall(Fsys.load, name)
        return ok and mod or nil
    end

    local M = {
        Fsys = Fsys,
        ClientData = fsysLoad("ClientData"),
        RouterClient = fsysLoad("RouterClient"),
        InteriorsM = fsysLoad("InteriorsM"),
        InventoryDB = safeReq(RS:FindFirstChild("ClientDB") and RS.ClientDB:FindFirstChild("Inventory") and RS.ClientDB.Inventory:FindFirstChild("InventoryDB")),
        AilmentsDB = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Ailments") and RS.new.modules.Ailments:FindFirstChild("AilmentsDB")),
        AilmentsClient = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Ailments") and RS.new.modules.Ailments:FindFirstChild("AilmentsClient")),
        LuresNet = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Lures") and RS.new.modules.Lures:FindFirstChild("LuresNet")),
        LureActions = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Lures") and RS.new.modules.Lures:FindFirstChild("LureActions")),
        StorageNet = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Storage") and RS.new.modules.Storage:FindFirstChild("StorageNet")),
        UseItemHelper = safeReq(RS:FindFirstChild("new") and RS.new:FindFirstChild("modules") and RS.new.modules:FindFirstChild("Ailments") and RS.new.modules.Ailments:FindFirstChild("Helpers") and RS.new.modules.Ailments.Helpers:FindFirstChild("UseItemHelper")),
        LightningNet = safeReq(RS:FindFirstChild("SharedModules") and RS.SharedModules:FindFirstChild("ContentPacks") and RS.SharedModules.ContentPacks:FindFirstChild("LightningDimension2026") and RS.SharedModules.ContentPacks.LightningDimension2026:FindFirstChild("Game") and RS.SharedModules.ContentPacks.LightningDimension2026.Game:FindFirstChild("LightningDimensionNet")),
        MinigameClientManager = fsysLoad("MinigameClientManager"),
        UIManager = fsysLoad("UIManager"),
    }

    local B = { Mod = M }

    function B.GetMyData()
        if not M.ClientData or not M.ClientData.get_data then return nil end
        local ok, all = pcall(M.ClientData.get_data)
        return ok and type(all) == "table" and all[LocalPlayer.Name] or nil
    end

    function B.GetMoney()
        local d = B.GetMyData()
        return (d and tonumber(d.money)) or 0
    end

    function B.GetTeam()
        local d = B.GetMyData()
        return d and d.team or "Parents"
    end

    function B.GetInventory(category)
        local d = B.GetMyData()
        local inv = d and d.inventory or {}
        if category then
            return inv[category] or {}
        end
        return inv
    end

    function B.GetEquippedPets()
        local d = B.GetMyData()
        local wrappers = d and d.pet_char_wrappers
        if type(wrappers) == "table" and #wrappers > 0 then
            return wrappers
        end
        local eq = d and d.equip_manager and d.equip_manager.pets
        return type(eq) == "table" and eq or {}
    end

    function B.GetAilmentsManager()
        local d = B.GetMyData()
        return (d and d.ailments_manager) or {}
    end

    function B.GetCurrentLocation()
        if not M.InteriorsM or not M.InteriorsM.get_current_location then return nil end
        local ok, loc = pcall(M.InteriorsM.get_current_location)
        return ok and loc or nil
    end

    function B.GetRoute(routeName)
        local api = RS:FindFirstChild("API")
        if api then
            local direct = api:FindFirstChild(routeName)
            if direct then return direct end
        end
        if M.RouterClient and M.RouterClient.get then
            local ok, rem = pcall(M.RouterClient.get, routeName)
            if ok then return rem end
        end
        return nil
    end

    function B.RouteFire(routeName, ...)
        local rem = B.GetRoute(routeName)
        if not rem or not rem:IsA("RemoteEvent") then
            return false, "missing_remote"
        end
        local args = { ... }
        local ok, err = pcall(function()
            rem:FireServer(table.unpack(args))
        end)
        return ok, err
    end

    function B.RouteInvoke(routeName, ...)
        local rem = B.GetRoute(routeName)
        if not rem or not rem:IsA("RemoteFunction") then
            return false, "missing_remote"
        end
        local args = { ... }
        local ok, r1, r2, r3 = pcall(function()
            return rem:InvokeServer(table.unpack(args))
        end)
        if not ok then
            return false, tostring(r1)
        end
        return true, r1, r2, r3
    end

    function B.EnterInterior(destId, doorId, settings)
        if not M.InteriorsM then return false end
        local cur = B.GetCurrentLocation()
        if cur and cur.destination_id == destId then
            if destId ~= "housing" or (settings and cur.house_owner == settings.house_owner) then
                return true
            end
        end
        if M.InteriorsM.entering then
            return false
        end
        local fn = M.InteriorsM.enter_smooth or M.InteriorsM.enter
        if type(fn) ~= "function" then return false end
        local ok = pcall(fn, destId, doorId or "MainDoor", settings)
        task.wait(0.8)
        return ok
    end

    function B.EnterOwnHouse()
        local cur = B.GetCurrentLocation()
        if cur and cur.destination_id == "housing" and (cur.house_owner == nil or cur.house_owner == LocalPlayer) then
            return true
        end
        return B.EnterInterior("housing", "MainDoor", { house_owner = LocalPlayer })
    end

    -- Finds matching furniture inside LocalPlayer's house_interior and resolves its exact UseBlock name
    function B.FindOwnHouseFurniture(idPatterns)
        local d = B.GetMyData()
        local hi = d and d.house_interior
        local furnTbl = hi and hi.furniture
        if type(furnTbl) ~= "table" then return nil, nil end

        local matchedUid, matchedId = nil, nil
        for _, pat in ipairs(idPatterns) do
            local lpat = string.lower(pat)
            for uid, f in pairs(furnTbl) do
                if type(f) == "table" and f.id and string.find(string.lower(tostring(f.id)), lpat, 1, true) then
                    matchedUid = uid
                    matchedId = f.id
                    break
                end
            end
            if matchedUid then break end
        end

        if not matchedUid then return nil, nil end

        -- Inspect Workspace.HouseInteriors.furniture to resolve exact Seat1 vs UseBlock name
        local useName = "UseBlock"
        local hiWs = workspace:FindFirstChild("HouseInteriors")
        local fFolder = hiWs and hiWs:FindFirstChild("furniture")
        if fFolder then
            local suffix = "/" .. tostring(matchedUid)
            for _, ch in ipairs(fFolder:GetChildren()) do
                if string.sub(ch.Name, -#suffix) == suffix then
                    local ub = ch:FindFirstChild("UseBlocks", true)
                    if ub then
                        if ub:FindFirstChild("UseBlock") then
                            useName = "UseBlock"
                        elseif ub:FindFirstChild("Seat1") then
                            useName = "Seat1"
                        else
                            local firstPart = ub:FindFirstChildWhichIsA("BasePart")
                            if firstPart then useName = firstPart.Name end
                        end
                    end
                    break
                end
            end
        end

        return matchedUid, useName, matchedId
    end

    function B.TeleportStaticLocation(locName)
        local cur = B.GetCurrentLocation()
        if not cur or cur.destination_id ~= "MainMap" then
            B.EnterInterior("MainMap", "Neighborhood!MainDoor")
            task.wait(0.8)
        end
        local sm = workspace:FindFirstChild("StaticMap")
        if not sm then return false end

        -- Exact 2026 RateArea target coordinates for Golden ailments
        local directTargets = {
            bored = sm:FindFirstChild("Park") and (sm.Park:FindFirstChild("BoredAilmentTarget") or sm.Park:FindFirstChild("AilmentTarget")),
            camping = sm:FindFirstChild("Campsite") and sm.Campsite:FindFirstChild("CampsiteOrigin"),
            beach_party = sm:FindFirstChild("Beach") and (sm.Beach:FindFirstChild("BeachPartyNavTarget") or sm.Beach:FindFirstChild("BeachPartyAilmentTarget")),
        }
        local targetInst = directTargets[locName]
        if targetInst then
            local pos = ctx.Utils.getPos(targetInst)
            if pos then
                return ctx.Utils.moveToPosition(pos, 0.3)
            end
        end

        local tp = sm:FindFirstChild("TeleportLocations")
        if not tp then return false end
        for _, child in ipairs(tp:GetChildren()) do
            if child.Name == locName then
                local pos = ctx.Utils.getPos(child)
                if pos then
                    return ctx.Utils.moveToPosition(pos, 0.3)
                end
            end
        end
        return false
    end

    ctx.Bridge = B
    return B
end

return Bridge
