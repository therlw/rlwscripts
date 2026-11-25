-- src/Systems/House/HouseAndEconomySystem.lua
-- JSON House Cloner (Export/Build) & Auto-Pay / Cash Register Economy Helper

local HouseAndEconomySystem = {}

function HouseAndEconomySystem.Init(ctx)
    local Bridge = ctx.Bridge
    local States = ctx.States
    local CONFIG = ctx.Config
    local Lifecycle = ctx.Lifecycle
    local HttpService = ctx.Roblox.HttpService
    local Players = ctx.Roblox.Players

    local H = {}

    local function ensureHouseFolder()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("AdoptMeHub") then pcall(makefolder, "AdoptMeHub") end
            if not isfolder(CONFIG.Persistence.HouseFolder) then pcall(makefolder, CONFIG.Persistence.HouseFolder) end
        end
    end

    local function serializeCFrame(cf)
        return { cf:GetComponents() }
    end

    local function deserializeCFrame(arr)
        if type(arr) ~= "table" or #arr < 12 then return CFrame.new() end
        return CFrame.new(table.unpack(arr, 1, 12))
    end

    local function serializeColors(cols)
        local out = {}
        if type(cols) == "table" then
            for k, v in pairs(cols) do
                if typeof(v) == "Color3" then
                    out[tostring(k)] = { v.R, v.G, v.B }
                end
            end
        end
        return out
    end

    local function deserializeColors(tbl)
        local out = {}
        if type(tbl) == "table" then
            for k, rgb in pairs(tbl) do
                if type(rgb) == "table" and #rgb >= 3 then
                    out[tonumber(k) or k] = Color3.new(rgb[1], rgb[2], rgb[3])
                end
            end
        end
        return out
    end

    -- Export current house furniture (your house or any house you are currently inside!)
    function H.ExportCurrentHouse(fileName)
        if type(writefile) ~= "function" then
            return false, "writefile desteklenmiyor"
        end
        local data = Bridge.GetMyData()
        local hi = data and data.house_interior
        if type(hi) ~= "table" or type(hi.furniture) ~= "table" then
            return false, "Ev verisi bulunamadı (bir evin içine girin)"
        end

        local items = {}
        for _, f in pairs(hi.furniture) do
            if type(f) == "table" and f.id and f.cframe then
                table.insert(items, {
                    id = f.id,
                    cframe = serializeCFrame(f.cframe),
                    colors = serializeColors(f.colors),
                    scale = f.scale,
                })
            end
        end

        if #items == 0 then
            return false, "Evde dışa aktarılacak mobilya yok"
        end

        ensureHouseFolder()
        local cleanName = tostring(fileName or States.House.SelectedHouseFile or "saved_house"):gsub("[^%w_%-]", "_")
        local fullPath = string.format("%s/%s.json", CONFIG.Persistence.HouseFolder, cleanName)
        local payload = {
            interior = tostring(hi.interior_name or "housing"),
            exportedAt = os.time(),
            count = #items,
            furniture = items,
        }
        local ok = pcall(writefile, fullPath, HttpService:JSONEncode(payload))
        return ok, string.format("%d mobilya kaydedildi (%s)", #items, cleanName .. ".json")
    end

    -- Import / Build saved JSON furniture into player's own house via HousingAPI/BuyFurnitures
    function H.ImportHouse(fileName)
        if type(isfile) ~= "function" or type(readfile) ~= "function" then
            return false, "readfile desteklenmiyor"
        end
        local cleanName = tostring(fileName or States.House.SelectedHouseFile or "saved_house"):gsub("[^%w_%-]", "_")
        local fullPath = string.format("%s/%s.json", CONFIG.Persistence.HouseFolder, cleanName)
        if not isfile(fullPath) then
            return false, "Dosya bulunamadı: " .. fullPath
        end
        local raw = readfile(fullPath)
        local okDec, payload = pcall(HttpService.JSONDecode, HttpService, raw)
        if not okDec or type(payload) ~= "table" or type(payload.furniture) ~= "table" then
            return false, "JSON okunamadı"
        end

        -- Ensure player is in own house
        Bridge.EnterInterior("housing", "MainDoor", { house_owner = Players.LocalPlayer })
        task.wait(0.8)

        -- Batch buy furniture in chunks of 10
        local batch = {}
        local built = 0
        for _, entry in ipairs(payload.furniture) do
            table.insert(batch, {
                kind = entry.id,
                properties = {
                    cframe = deserializeCFrame(entry.cframe),
                    colors = deserializeColors(entry.colors),
                    scale = entry.scale,
                },
            })
            if #batch >= 10 then
                local okBuy = Bridge.RouteInvoke("HousingAPI/BuyFurnitures", batch)
                if okBuy then built = built + #batch end
                batch = {}
                task.wait(0.3)
            end
        end
        if #batch > 0 then
            local okBuy = Bridge.RouteInvoke("HousingAPI/BuyFurnitures", batch)
            if okBuy then built = built + #batch end
        end

        return built > 0, string.format("%d/%d mobilya inşa edildi", built, #payload.furniture)
    end

    -- Find a cash register / lemonade / hotdog stand near or owned by target
    function H.FindPayStation(targetPlayerName)
        local houseInteriors = workspace:FindFirstChild("HouseInteriors")
        local hiFolder = houseInteriors and houseInteriors:FindFirstChild("furniture")
        if hiFolder then
            for _, model in ipairs(hiFolder:GetDescendants()) do
                if model:IsA("Model") then
                    local lname = string.lower(model.Name)
                    if string.find(lname, "cashregister", 1, true) or string.find(lname, "register", 1, true) then
                        return "register", model
                    end
                end
            end
        end
        -- Check placeable refreshment stands in Workspace
        for _, obj in ipairs(workspace:GetChildren()) do
            local lname = string.lower(obj.Name)
            if string.find(lname, "lemonade", 1, true) or string.find(lname, "hotdog", 1, true) or string.find(lname, "stand", 1, true) then
                if targetPlayerName == "" or string.find(lname, string.lower(targetPlayerName), 1, true) then
                    return "stand", obj
                end
            end
        end
        return nil, nil
    end

    Lifecycle.SpawnLoop("HouseAndEconomy", 2.0, function()
        if States.House.AutoCollectRegister then
            Bridge.RouteFire("PayAPI/Collect")
        end

        if States.House.AutoPay and (os.clock() - ctx.Runtime.Cooldowns.LastPayAt) >= 4.0 then
            ctx.Runtime.Cooldowns.LastPayAt = os.clock()
            local kind, inst = H.FindPayStation(States.House.PayTargetPlayer or "")
            if kind == "stand" and inst then
                local ownerName = States.House.PayTargetPlayer
                local targetPlr = (ownerName and ownerName ~= "") and Players:FindFirstChild(ownerName) or nil
                if targetPlr then
                    Bridge.RouteInvoke("PlaceableToolAPI/BuyRefreshment", inst, targetPlr)
                    ctx.Runtime.Telemetry.PaymentsSent = ctx.Runtime.Telemetry.PaymentsSent + 1
                end
            elseif kind == "register" and inst then
                local fUnique = inst.Name
                Bridge.RouteInvoke("HousingAPI/ActivateFurniture", Players.LocalPlayer, fUnique, "UseBlock", nil, Players.LocalPlayer.Character)
                ctx.Runtime.Telemetry.PaymentsSent = ctx.Runtime.Telemetry.PaymentsSent + 1
            end
        end
    end)

    ctx.API.House = H
    return H
end

return HouseAndEconomySystem
