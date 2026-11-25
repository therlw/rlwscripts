-- src/Systems/Pets/PetManagerSystem.lua
-- Auto-Neon & Mega Neon, Auto-Equip Best, Pet Storage Helper & Strictly Client-Side Visual Pet Spawner

local PetManagerSystem = {}

function PetManagerSystem.Init(ctx)
    local Bridge = ctx.Bridge
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle
    local Utils = ctx.Utils
    local RS = ctx.Roblox.ReplicatedStorage
    local RunService = ctx.Roblox.RunService

    local P = {
        _visualModels = {},
        _visualConn = nil,
    }

    local RARITY_RANK = {
        common = 1,
        uncommon = 2,
        rare = 3,
        ultra_rare = 4,
        legendary = 5,
    }

    local function getPetInfo(kind)
        local invDB = Bridge.Mod.InventoryDB
        return invDB and invDB.pets and invDB.pets[kind] or nil
    end

    -- Auto Neon & Mega Neon Fusion
    function P.RunNeonFusion(doMega)
        local invPets = Bridge.GetInventory("pets")
        local normalBuckets = {}
        local neonBuckets = {}

        for _, pet in pairs(invPets) do
            local props = pet.properties or {}
            local age = tonumber(props.age) or 1
            local info = getPetInfo(pet.kind or pet.id)
            local isEgg = info and info.is_egg
            if not isEgg and age >= 6 and not props.mega_neon then
                if props.neon then
                    neonBuckets[pet.kind] = neonBuckets[pet.kind] or {}
                    table.insert(neonBuckets[pet.kind], pet.unique)
                else
                    normalBuckets[pet.kind] = normalBuckets[pet.kind] or {}
                    table.insert(normalBuckets[pet.kind], pet.unique)
                end
            end
        end

        local fused = 0
        for kind, uniques in pairs(normalBuckets) do
            while #uniques >= 4 do
                local batch = {
                    table.remove(uniques),
                    table.remove(uniques),
                    table.remove(uniques),
                    table.remove(uniques),
                }
                local ok = Bridge.RouteInvoke("PetAPI/DoNeonFusion", batch)
                Bridge.RouteFire("PetAPI/SkipNeonFusion")
                if ok then
                    fused = fused + 1
                    ctx.Runtime.Telemetry.NeonsFused = ctx.Runtime.Telemetry.NeonsFused + 1
                    ctx.Runtime.Status.Pets = "Neon birleştirildi: " .. tostring(kind)
                end
                task.wait(0.35)
            end
        end

        if doMega then
            for kind, uniques in pairs(neonBuckets) do
                while #uniques >= 4 do
                    local batch = {
                        table.remove(uniques),
                        table.remove(uniques),
                        table.remove(uniques),
                        table.remove(uniques),
                    }
                    local ok = Bridge.RouteInvoke("PetAPI/DoNeonFusion", batch)
                    Bridge.RouteFire("PetAPI/SkipNeonFusion")
                    if ok then
                        fused = fused + 1
                        ctx.Runtime.Telemetry.NeonsFused = ctx.Runtime.Telemetry.NeonsFused + 1
                        ctx.Runtime.Status.Pets = "Mega Neon birleştirildi: " .. tostring(kind)
                    end
                    task.wait(0.35)
                end
            end
        end

        return fused
    end

    -- Equip Best Pet (highest rarity + Mega/Neon/FR bonus)
    function P.EquipBestPet()
        local invPets = Bridge.GetInventory("pets")
        local bestPet = nil
        local bestScore = -1

        for _, pet in pairs(invPets) do
            local info = getPetInfo(pet.kind or pet.id)
            if info and not info.is_egg then
                local props = pet.properties or {}
                local score = (RARITY_RANK[info.rarity or "common"] or 1) * 100
                if props.mega_neon then score = score + 40
                elseif props.neon then score = score + 20 end
                if props.flyable then score = score + 5 end
                if props.rideable then score = score + 5 end
                score = score + (tonumber(props.age) or 1)
                if score > bestScore then
                    bestScore = score
                    bestPet = pet
                end
            end
        end

        if bestPet and bestPet.unique then
            local ok = Bridge.RouteInvoke("ToolAPI/Equip", bestPet.unique, { use_sound_delay = false })
            if ok then
                ctx.Runtime.Status.Pets = "En iyi pet kuşanıldı: " .. tostring(bestPet.kind)
            end
            return ok, bestPet
        end
        return false, nil
    end

    -- Transfer excess duplicate pets into storage tab if StorageNet is available
    function P.TransferExcessToStorage(keepCount)
        local storageNet = Bridge.Mod.StorageNet
        if not storageNet or not storageNet.TransferItems then
            return 0, "StorageNet bulunamadı"
        end
        local data = Bridge.GetMyData()
        local sm = data and data.storage_manager
        local tabs = sm and sm.tabs
        local targetTabId = nil
        if type(tabs) == "table" then
            for id, _ in pairs(tabs) do
                targetTabId = id
                break
            end
        end
        if not targetTabId then
            return 0, "Kayıtlı depolama sekmesi yok"
        end

        local invPets = Bridge.GetInventory("pets")
        local byKind = {}
        for _, pet in pairs(invPets) do
            byKind[pet.kind] = byKind[pet.kind] or {}
            table.insert(byKind[pet.kind], pet)
        end

        local fastIds = {}
        local limit = tonumber(keepCount) or 4
        for _, list in pairs(byKind) do
            if #list > limit then
                for i = limit + 1, #list do
                    local fid = list[i].fast_id or list[i].unique
                    if tonumber(fid) then
                        table.insert(fastIds, tonumber(fid))
                    end
                end
            end
        end
        if #fastIds == 0 then
            return 0, "Aktarılacak fazlalık pet yok"
        end

        local ok = pcall(function()
            local buf = buffer.create(#fastIds * 4)
            for i, idVal in ipairs(fastIds) do
                buffer.writeu32(buf, (i - 1) * 4, idVal)
            end
            storageNet.TransferItems:fire_server({
                to_id = targetTabId,
                fast_ids = buf,
                buffer_write_size = 4,
            })
        end)
        return ok and #fastIds or 0, ok and "Aktarıldı" or "Aktarım başarısız"
    end

    -- Strictly Client-Side Visual Pet Spawner (renders neon/mega/aura & follows local player; non-tradable)
    function P.ClearVisualPets()
        if P._visualConn then
            P._visualConn:Disconnect()
            P._visualConn = nil
        end
        for _, mdl in ipairs(P._visualModels) do
            pcall(function() mdl:Destroy() end)
        end
        table.clear(P._visualModels)
        ctx.Runtime.Status.Pets = "Görsel petler temizlendi"
    end

    function P.SpawnVisualPet(petKind, neonMode, ride, fly)
        local kind = tostring(petKind or States.Pets.VisualPetKind or "frost_dragon")
        local info = getPetInfo(kind)
        local displayName = (info and info.name) or kind
        local modelName = (info and info.model) or kind

        local char, hrp = Utils.getCharacterParts()
        if not char or not hrp then
            return false, "Karakter hazır değil"
        end

        local cloned = nil
        pcall(function()
            local dl = Bridge.Fsys and Bridge.Fsys.load("DownloadClient")
            if dl then
                if dl.promise_download_copy_by_kind then
                    local okP, mdl = dl.promise_download_copy_by_kind("pets", kind):await()
                    if okP and mdl then cloned = mdl end
                elseif dl.download then
                    local mdl = dl.download("Pets", modelName)
                    if mdl then cloned = mdl:Clone() end
                end
            end
        end)

        if not cloned then
            -- Fallback stylized glowing companion model so visual preview always works even without asset cache
            local mdl = Instance.new("Model")
            mdl.Name = "RLW_VisualPet_" .. kind

            local body = Instance.new("Part")
            body.Name = "Torso"
            body.Size = Vector3.new(2.2, 1.5, 2.8)
            body.Shape = Enum.PartType.Block
            body.Material = Enum.Material.SmoothPlastic
            body.Color = Color3.fromRGB(70, 175, 255)
            body.CanCollide = false
            body.Anchored = true
            body.Parent = mdl

            local head = Instance.new("Part")
            head.Name = "Head"
            head.Size = Vector3.new(1.5, 1.3, 1.5)
            head.Shape = Enum.PartType.Ball
            head.Material = Enum.Material.Neon
            head.Color = Color3.fromRGB(160, 230, 255)
            head.CanCollide = false
            head.Anchored = true
            head.Parent = mdl

            mdl.PrimaryPart = body
            cloned = mdl
        end

        cloned.Name = "RLW_VisualPet_" .. kind
        for _, d in ipairs(cloned:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CanCollide = false
                d.Anchored = true
                if neonMode == "Neon" or neonMode == "Mega Neon" then
                    if d.Name == "Head" or d.Material == Enum.Material.Neon or string.find(string.lower(d.Name), "neon") or string.find(string.lower(d.Name), "wing") then
                        d.Material = Enum.Material.Neon
                    end
                end
            end
        end

        -- Overhead badge clearly showing Visual / MFR tags
        local rootPart = cloned.PrimaryPart or cloned:FindFirstChildWhichIsA("BasePart")
        if rootPart then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 170, 0, 44)
            bb.StudsOffset = Vector3.new(0, 2.8, 0)
            bb.AlwaysOnTop = true
            bb.Parent = rootPart

            local tags = {}
            if neonMode == "Mega Neon" then table.insert(tags, "[M]")
            elseif neonMode == "Neon" then table.insert(tags, "[N]") end
            if fly then table.insert(tags, "[F]") end
            if ride then table.insert(tags, "[R]") end

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextScaled = true
            lbl.TextColor3 = Color3.fromRGB(255, 235, 110)
            lbl.TextStrokeTransparency = 0.25
            lbl.Text = string.format("%s %s\n(Görsel / Client)", table.concat(tags, ""), displayName)
            lbl.Parent = bb
        end

        cloned.Parent = workspace
        table.insert(P._visualModels, cloned)

        if not P._visualConn then
            P._visualConn = Lifecycle.TrackConnection(RunService.RenderStepped:Connect(function()
                local _, curHrp = Utils.getCharacterParts()
                if not curHrp then return end
                local t = os.clock()
                local rainbow = Color3.fromHSV((t * 0.35) % 1, 0.85, 1)

                for idx, mdl in ipairs(P._visualModels) do
                    if mdl and mdl.Parent then
                        local angle = (idx - 1) * 1.15
                        local offset = CFrame.new(math.cos(angle) * 4.2, (fly and 2.5 or 0.6) + math.sin(t * 2.5 + idx) * 0.45, 3.8 + math.sin(angle) * 1.5)
                        local targetCF = curHrp.CFrame * offset
                        mdl:PivotTo(targetCF)
                        if neonMode == "Mega Neon" then
                            for _, p in ipairs(mdl:GetDescendants()) do
                                if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
                                    p.Color = rainbow
                                end
                            end
                        end
                    end
                end
            end))
        end

        ctx.Runtime.Status.Pets = "Görsel pet eklendi: " .. displayName
        return true, displayName
    end

    function P.GetSamplePetKinds()
        return {
            "frost_dragon",
            "shadow_dragon",
            "bat_dragon",
            "giraffe",
            "owl",
            "parrot",
            "crow",
            "evil_unicorn",
            "unicorn",
            "practice_dog",
        }
    end

    Lifecycle.AddCleanup(function()
        P.ClearVisualPets()
    end)

    Lifecycle.SpawnLoop("PetManager", 2.0, function()
        if States.Pets.AutoNeon or States.Pets.AutoMegaNeon then
            if (os.clock() - ctx.Runtime.Cooldowns.LastNeonAt) >= 4.0 then
                ctx.Runtime.Cooldowns.LastNeonAt = os.clock()
                P.RunNeonFusion(States.Pets.AutoMegaNeon)
            end
        end
        if States.Pets.AutoEquipBest then
            if (os.clock() - ctx.Runtime.Cooldowns.LastEquipAt) >= 8.0 then
                ctx.Runtime.Cooldowns.LastEquipAt = os.clock()
                local eq = Bridge.GetEquippedPets()
                if #eq == 0 then
                    P.EquipBestPet()
                end
            end
        end
    end)

    ctx.API.Pets = P
    return P
end

return PetManagerSystem
