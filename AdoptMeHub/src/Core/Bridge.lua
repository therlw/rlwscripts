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
            return true
        end
        if M.InteriorsM.entering then
            return false
        end
        local fn = M.InteriorsM.enter_smooth or M.InteriorsM.enter
        if type(fn) ~= "function" then return false end
        local ok = pcall(fn, destId, doorId or "MainDoor", settings)
        task.wait(0.6)
        return ok
    end

    function B.TeleportStaticLocation(locName)
        local cur = B.GetCurrentLocation()
        if not cur or cur.destination_id ~= "MainMap" then
            B.EnterInterior("MainMap", "Neighborhood!MainDoor")
            task.wait(0.6)
        end
        local sm = workspace:FindFirstChild("StaticMap")
        local tp = sm and sm:FindFirstChild("TeleportLocations")
        if not tp then return false end
        for _, child in ipairs(tp:GetChildren()) do
            if child.Name == locName then
                local pos = ctx.Utils.getPos(child)
                if pos then
                    return ctx.Utils.moveToPosition(pos, 0.25)
                end
            end
        end
        return false
    end

    ctx.Bridge = B
    return B
end

return Bridge
