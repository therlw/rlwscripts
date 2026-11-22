-- src/Systems/Optimization/PumpkinOptimizer.lua
-- Event-Aware Reversible & RAM-Freeing Optimizer ("Optimize Pumpkin Tycoon")
-- When inside Pumpkin Tycoon and enabled:
--   1. Frees RAM by purging other players' island decor (~12.8k/player), other plots' orchards/clutter,
--      other players' breakable meshes/FX, own-island decorative zone clutter (trees/fences/crates/lamps/
--      flowers/hay/buildings/leaderboard/props) while keeping walkable floors, pads & pedestals intact.
--   2. Cleans Turkey Island clutter (Trees/Props/HayBales/Ropes/Bushes) & Water wave layers.
--   3. Parks unused Spawn/Main-world map bloat (PSX Portal, Ornaments, Border, etc.) & restores on exit.
--   4. Purges __DEBRIS (ParticleHost_*, flashes, confetti), Lighting post-FX, and other players' avatars/pets.

local PumpkinOptimizer = {}

function PumpkinOptimizer.Init(ctx)
    local Lighting = ctx.Roblox.Lighting
    local CollectionService = game:GetService("CollectionService")
    local Players = ctx.Roblox.Players
    local LocalPlayer = Players.LocalPlayer
    local Net = ctx.Net
    local Lifecycle = ctx.Lifecycle

    local Optimizer = {
        Enabled = false,
        InEventZone = false,
        HideMachineGuis = false,
        _savedProps = {},
        _connections = {},
        _eventConns = {},
        _machGuiConns = {},
        _origOpenTab = nil,
        _parkedMainWorld = {},
        _cleanedPlots = setmetatable({}, { __mode = "k" }),
        _pendingForeignBrk = {},
        _foreignBrkScheduled = false,
        _lastDebrisSweepAt = 0,
        _cachedPlotModel = nil,
        _cachedPlotCF = nil,
        _cachedPlotSize = nil,
        _eventPurgeAt = 0,
        _destroyedCount = 0,
        LastStats = {
            destroyed = 0,
            parked = 0,
            workspaceDesc = 0,
            memoryMB = 0,
        },
    }

    local FLASH_NAMES = {
        PumpkinFxFlash = true,
        PumpkinFxDim = true,
        TurkeyFlash = true,
        TurkeyShockwave = true,
        TurkeyFeathers = true,
        WildSpawnDust = true,
        Confetti = true,
    }

    local MAIN_WORLD_PARK_TARGETS = {
        { parent = workspace, name = "Border" },
        { parent = workspace, name = "PSX Hall" },
        { parent = workspace, name = "FlyBorder" },
        { parent = workspace, name = "ALWAYS_RENDERING" },
    }

    local THINGS_PARK_NAMES = {
        "Ski Chairs",
        "VictoryScene",
    }

    local TURKEY_CLUTTER_FOLDERS = {
        Trees = true,
        Props = true,
        HayBales = true,
        Ropes = true,
        Bushes = true,
    }

    local WALKABLE_OR_FUNCTIONAL_PATTERNS = {
        "ground",
        "floor",
        "landpatch",
        "woodpath",
        "cabinpath",
        "path_",
        "walkway",
        "dock",
        "deck",
        "stair",
        "step",
        "breakzoneline",
        "pedestal",
        "cliff",
        "seabounds",
        "wildarea",
        "haypilespot",
    }

    local FX_STRIP_CLASSES = {
        ParticleEmitter = true,
        Trail = true,
        Beam = true,
        Fire = true,
        Smoke = true,
        Sparkles = true,
        PointLight = true,
        SpotLight = true,
        SurfaceLight = true,
        SurfaceAppearance = true,
        Decal = true,
        Texture = true,
    }

    local function trackDestroyed(n)
        Optimizer._destroyedCount = Optimizer._destroyedCount + (n or 1)
    end

    local function saveAndSet(bucket, inst, prop, val)
        if not inst then return end
        local rec = bucket[inst]
        if not rec then
            rec = {}
            bucket[inst] = rec
        end
        if rec[prop] == nil then
            local ok, oldVal = pcall(function() return inst[prop] end)
            if ok then
                rec[prop] = oldVal
            else
                return
            end
        end
        pcall(function() inst[prop] = val end)
    end

    local function restoreBucket(bucket)
        for inst, props in pairs(bucket) do
            if inst and inst.Parent then
                for prop, oldVal in pairs(props) do
                    pcall(function() inst[prop] = oldVal end)
                end
            end
        end
        table.clear(bucket)
    end

    local function parkInstance(inst)
        if not inst or not inst.Parent then return end
        if Optimizer._parkedMainWorld[inst] ~= nil then return end
        Optimizer._parkedMainWorld[inst] = inst.Parent
        pcall(function() inst.Parent = nil end)
    end

    local function unparkAll()
        for inst, origParent in pairs(Optimizer._parkedMainWorld) do
            if inst and origParent and origParent.Parent then
                pcall(function() inst.Parent = origParent end)
            end
        end
        table.clear(Optimizer._parkedMainWorld)
    end

    local function makeBudget()
        return { t = os.clock(), ops = 0 }
    end

    local function stepBudget(b)
        if not Optimizer.Enabled or not Lifecycle.IsCurrentGeneration() then
            return false
        end
        if not b then return true end
        b.ops = b.ops + 1
        if b.ops % 64 == 0 and (os.clock() - b.t) >= 0.005 then
            task.wait()
            b.t = os.clock()
            if not Optimizer.Enabled or not Optimizer.InEventZone or not Lifecycle.IsCurrentGeneration() then
                return false
            end
        end
        return true
    end

    local function clearChildrenSafe(container, budget)
        if not container or not container.Parent then return end
        for _, child in ipairs(container:GetChildren()) do
            if budget and not stepBudget(budget) then return end
            local cnt = #child:GetChildren() + 1
            local ok = pcall(function() child:Destroy() end)
            if ok then
                trackDestroyed(cnt)
            end
        end
    end

    local function isProtectedInstance(inst)
        local cur = inst
        while cur and cur ~= workspace do
            local n = cur.Name
            if n == "Buttons" or n == "PumpkinTycoonPads" or n == "Interactable"
                or n == "CustomEggs" or n == "Eggs" or n == "SAFETY_NET"
                or n == "Teleports" or n == "TurkeyArena" then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function isWalkableOrFunctional(inst)
        if not inst then return false end
        local lower = string.lower(inst.Name)
        if lower:find("rope", 1, true) then
            return false
        end
        if lower:find("bridge", 1, true) then
            return true
        end
        for _, pat in ipairs(WALKABLE_OR_FUNCTIONAL_PATTERNS) do
            if lower:find(pat, 1, true) then
                return true
            end
        end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("TouchTransmitter") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("LayerCollector") then
                return true
            end
        end
        return false
    end

    local function stripVisualsOnTree(root, destroyTextures)
        if not root or not root.Parent then return end
        if root:IsA("BasePart") then
            saveAndSet(Optimizer._savedProps, root, "CastShadow", false)
        end
        for _, d in ipairs(root:GetDescendants()) do
            if d.Parent then
                if d:IsA("BasePart") then
                    saveAndSet(Optimizer._savedProps, d, "CastShadow", false)
                elseif FX_STRIP_CLASSES[d.ClassName] then
                    if destroyTextures and not d:FindFirstAncestorWhichIsA("BillboardGui") and not d:FindFirstAncestorWhichIsA("SurfaceGui") then
                        if pcall(function() d:Destroy() end) then
                            trackDestroyed(1)
                        end
                    elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Light") then
                        saveAndSet(Optimizer._savedProps, d, "Enabled", false)
                    end
                elseif d:IsA("PostEffect") or d:IsA("Atmosphere") then
                    saveAndSet(Optimizer._savedProps, d, "Enabled", false)
                end
            end
        end
    end

    local function isDebrisCandidate(d)
        local name = d.Name
        if name == "TurkeyTag" or name == "TurkeyBreakRing" or name == "TurkeyBeacon" or name:find("Loot", 1, true)
            or name:find("Tag", 1, true) or name:find("Sign", 1, true) or name:find("Board", 1, true)
            or name:find("Aura", 1, true) or (name:find("Host", 1, true) and not name:find("ParticleHost", 1, true)) then
            return false
        end
        if FLASH_NAMES[name] or name:find("ParticleHost", 1, true) or name:find("Confetti", 1, true)
            or name:find("Flash", 1, true) or name:find("Shockwave", 1, true) or name:find("Feathers", 1, true) then
            return true
        end
        return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
    end

    local function scrubDebrisChild(d)
        if not Optimizer.Enabled or not d or not d.Parent then return end
        if d:IsA("LayerCollector") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ScreenGui") then
            return
        end
        local name = d.Name
        if name == "TurkeyTag" or name == "TurkeyBreakRing" or name == "TurkeyBeacon" or name:find("Loot", 1, true)
            or name:find("Tag", 1, true) or name:find("Sign", 1, true) or name:find("Board", 1, true)
            or name:find("Aura", 1, true) or (name:find("Host", 1, true) and not name:find("ParticleHost", 1, true)) then
            return
        end
        if FLASH_NAMES[name] or name:find("ParticleHost", 1, true) or name:find("Confetti", 1, true)
            or name:find("Flash", 1, true) or name:find("Shockwave", 1, true) or name:find("Feathers", 1, true) then
            if d:FindFirstChild("Aura", true) then return end
            local cnt = #d:GetDescendants() + 1
            if pcall(function() d:Destroy() end) then
                trackDestroyed(cnt)
            end
            return
        end
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("BasePart") then
            for _, sub in ipairs(d:GetDescendants()) do
                if sub:IsA("ParticleEmitter") or sub:IsA("Trail") or sub:IsA("Beam") then
                    pcall(function() sub.Enabled = false end)
                end
            end
        end
    end

    local function purgeDebrisAndLighting()
        if not Optimizer.Enabled then return end
        for _, child in ipairs(Lighting:GetChildren()) do
            if FLASH_NAMES[child.Name] or child.Name:find("PumpkinFx", 1, true) then
                pcall(function() child:Destroy() end)
                trackDestroyed(1)
            elseif child:IsA("PostEffect") or child:IsA("Atmosphere") then
                saveAndSet(Optimizer._savedProps, child, "Enabled", false)
            end
        end
        if Optimizer.InEventZone then
            saveAndSet(Optimizer._savedProps, Lighting, "GlobalShadows", false)
            saveAndSet(Optimizer._savedProps, Lighting, "FogStart", 45)
            saveAndSet(Optimizer._savedProps, Lighting, "FogEnd", 180)
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                saveAndSet(Optimizer._savedProps, terrain, "Decoration", false)
                saveAndSet(Optimizer._savedProps, terrain, "WaterWaveSize", 0)
                saveAndSet(Optimizer._savedProps, terrain, "WaterReflectance", 0)
                saveAndSet(Optimizer._savedProps, terrain, "WaterTransparency", 0)
                local clouds = terrain:FindFirstChildOfClass("Clouds")
                if clouds then
                    saveAndSet(Optimizer._savedProps, clouds, "Enabled", false)
                end
            end
        end

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, d in ipairs(debris:GetChildren()) do
                scrubDebrisChild(d)
            end
        end

        pcall(function()
            if Net.Mod.PumpkinFx and Net.Mod.PumpkinFx.ClearAll then
                Net.Mod.PumpkinFx.ClearAll()
            end
        end)
    end

    local function stripCharacterVisuals(plr, char)
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        if not plr or plr == LocalPlayer or not char or not char.Parent then return end
        -- Hide visuals reversibly without destroying Attachments/ParticleEmitters (e.g. Rebirth VFX Aura1.Aura)
        for _, d in ipairs(char:GetDescendants()) do
            if d.Parent then
                if d:IsA("BasePart") then
                    saveAndSet(Optimizer._savedProps, d, "LocalTransparencyModifier", 1)
                    saveAndSet(Optimizer._savedProps, d, "CastShadow", false)
                elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                    or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
                    or d:IsA("Light") or d:IsA("LayerCollector") then
                    saveAndSet(Optimizer._savedProps, d, "Enabled", false)
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    saveAndSet(Optimizer._savedProps, d, "Transparency", 1)
                elseif d:IsA("Sound") then
                    saveAndSet(Optimizer._savedProps, d, "Volume", 0)
                end
            end
        end
    end

    local function purgeOtherPlayersAndPets()
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                stripCharacterVisuals(plr, plr.Character)
            end
        end

        local PlayerPet = Net.Mod.PlayerPet
        if PlayerPet and PlayerPet.GetByPlayer then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    for _, pet in pairs(PlayerPet.GetByPlayer(plr) or {}) do
                        pcall(function()
                            if pet and pet.cpet and pet.cpet.SetVisible then
                                pet.cpet:SetVisible(false)
                            end
                        end)
                    end
                end
            end
        end
    end

    local function isTurkeyBreakableModel(model)
        if not model then return false end
        if model:GetAttribute("PumpkinTurkey") == true then return true end
        local areaId = model:GetAttribute("AreaID")
        local brkId = model:GetAttribute("BreakableID")
        if areaId == "TurkeyArena" then return true end
        if type(brkId) == "string" and brkId:find("Turkey", 1, true) ~= nil then return true end
        return false
    end

    local function getCachedPlotBox()
        local myPlot = Net.GetPlotModel()
        if not myPlot then return nil, nil, nil, nil end
        local suffix = "_" .. myPlot.Name
        if Optimizer._cachedPlotModel == myPlot and Optimizer._cachedPlotCF and Optimizer._cachedPlotSize then
            return myPlot, suffix, Optimizer._cachedPlotCF, Optimizer._cachedPlotSize
        end
        local okBox, myCF, mySize = pcall(myPlot.GetBoundingBox, myPlot)
        if okBox and myCF and mySize then
            Optimizer._cachedPlotModel = myPlot
            Optimizer._cachedPlotCF = myCF
            Optimizer._cachedPlotSize = mySize
            return myPlot, suffix, myCF, mySize
        end
        return myPlot, suffix, nil, nil
    end

    local function scrubForeignBreakableModel(model, myPlotCF, myPlotSize, myPlotSuffix)
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        if not model or not model.Parent or not model:IsA("Model") then return end
        if model:GetAttribute("ParentID") ~= "PumpkinTycoon" then return end
        if isTurkeyBreakableModel(model) then return end
        if model:GetAttribute("OwnerUsername") == LocalPlayer.Name then return end

        local areaId = model:GetAttribute("AreaID")
        if type(areaId) == "string" and myPlotSuffix and areaId:sub(-#myPlotSuffix) == myPlotSuffix then
            return
        end

        local PT_Types = Net.Mod.PT_Types
        if myPlotCF and myPlotSize and PT_Types and PT_Types.OnIsland then
            local okPos, pivot = pcall(model.GetPivot, model)
            if okPos and pivot then
                if pivot.Position.Magnitude < 10 then
                    return
                end
                local okOn, onMine = pcall(PT_Types.OnIsland, myPlotCF, myPlotSize, pivot.Position)
                if okOn and onMine == true then
                    return
                end
            else
                return
            end
        else
            return
        end

        -- Foreign player breakable: strip heavy meshes/FX reversibly or destroy non-primary visual children cleanly
        local primary = model.PrimaryPart
        for _, d in ipairs(model:GetChildren()) do
            if d ~= primary then
                local cnt = #d:GetDescendants() + 1
                if pcall(function() d:Destroy() end) then
                    trackDestroyed(cnt)
                end
            end
        end
        if primary and primary.Parent then
            for _, sub in ipairs(primary:GetChildren()) do
                if pcall(function() sub:Destroy() end) then
                    trackDestroyed(1)
                end
            end
            primary.Transparency = 1
            primary.CanCollide = false
            primary.CanQuery = false
            primary.CastShadow = false
        end
    end

    local function hasGameTag(inst)
        if not inst then return false end
        if #CollectionService:GetTags(inst) > 0 or inst:IsA("LayerCollector") then return true end
        for _, d in ipairs(inst:GetDescendants()) do
            if #CollectionService:GetTags(d) > 0 or d:IsA("LayerCollector") then return true end
        end
        return false
    end

    local function isSectionTrackedNodeFast(inst)
        if not inst then return false end
        if inst:GetAttribute("Button") ~= nil or inst:GetAttribute("TycoonSection") ~= nil then
            return true
        end
        if #CollectionService:GetTags(inst) > 0 then
            return true
        end
        if inst:IsA("LayerCollector") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") or inst:IsA("ScreenGui")
            or inst:IsA("TouchTransmitter") or inst:IsA("ClickDetector") or inst:IsA("ProximityPrompt") then
            return true
        end
        local n = inst.Name
        if n == "Buttons" or n == "PumpkinTycoonPads" or n == "Interactable"
            or n == "CustomEggs" or n == "Eggs" or n == "SAFETY_NET"
            or n == "Teleports" or n == "TurkeyArena" then
            return true
        end
        return false
    end

    --- O(N) chunked cleaner: keeps Model/Folder shells and Button/Section-tracked nodes intact
    --- while yielding cleanly on a 5ms frame budget so low-FPS / multi-instance clients never stall.
    local function purgeDecorContentsKeepShells(container, budget)
        if not container or not container.Parent then return end
        for _, child in ipairs(container:GetChildren()) do
            if budget and not stepBudget(budget) then return end
            if child.Parent then
                if child:IsA("Model") or child:IsA("Folder") then
                    purgeDecorContentsKeepShells(child, budget)
                elseif isSectionTrackedNodeFast(child) then
                    if child:IsA("BasePart") and not isWalkableOrFunctional(child) then
                        saveAndSet(Optimizer._savedProps, child, "Transparency", 1)
                        saveAndSet(Optimizer._savedProps, child, "CanCollide", false)
                        saveAndSet(Optimizer._savedProps, child, "CanQuery", false)
                        saveAndSet(Optimizer._savedProps, child, "CastShadow", false)
                    end
                    stripVisualsOnTree(child, true)
                elseif #child:GetChildren() > 0 then
                    purgeDecorContentsKeepShells(child, budget)
                else
                    if pcall(function() child:Destroy() end) then
                        trackDestroyed(1)
                    end
                end
            end
        end
    end

    local function hideLeaderboardVisuals(frontFolder)
        if not frontFolder then return end
        for _, lbName in ipairs({ "PumpkinLeaderboardCatches", "PumpkinLeaderboard" }) do
            local lb = frontFolder:FindFirstChild(lbName)
            local lbMain = lb and lb:FindFirstChild("Main")
            if lbMain then
                for _, d in ipairs(lbMain:GetDescendants()) do
                    if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
                        saveAndSet(Optimizer._savedProps, d, "Enabled", false)
                    end
                end
            end
        end
    end

    local function purgeOwnDecor(decor, budget)
        if not Optimizer.Enabled or not Optimizer.InEventZone or not decor or not decor.Parent then return end

        local props = decor:FindFirstChild("Props")
        if props then
            purgeDecorContentsKeepShells(props, budget)
        end

        local front = decor:FindFirstChild("Front")
        if front then
            hideLeaderboardVisuals(front)
            -- Only strip lights/particles/shadows on Front pads & _Look machines without destroying SurfaceGuis
            stripVisualsOnTree(front, false)
        end

        local ground = decor:FindFirstChild("Ground")
        if ground then
            stripVisualsOnTree(ground, true)
        end

        local function processZoneItem(item)
            if budget and not stepBudget(budget) then return end
            if isWalkableOrFunctional(item) or hasGameTag(item) then
                stripVisualsOnTree(item, false)
            elseif item:IsA("Model") or item:IsA("Folder") or isSectionTrackedNodeFast(item) or #item:GetChildren() > 0 then
                -- Keep tracked shells intact so Sections.reveal never fails on unlocked/rebirthed islands
                purgeDecorContentsKeepShells(item, budget)
            else
                if pcall(function() item:Destroy() end) then
                    trackDestroyed(1)
                end
            end
        end

        for _, child in ipairs(decor:GetChildren()) do
            if child.Name:match("^%d+ |") then
                for _, item in ipairs(child:GetChildren()) do
                    if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                    if item.Name == "Pieces" then
                        for _, subItem in ipairs(item:GetChildren()) do
                            processZoneItem(subItem)
                        end
                    else
                        processZoneItem(item)
                    end
                end
            end
        end
    end

    local function purgeTurkeyIsland(budget)
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        local shared = Net.GetTurkeyIslandFolder()
        if not shared then return end
        local sharedDecor = shared:FindFirstChild("Decor")
        if sharedDecor then
            for _, sub in ipairs(sharedDecor:GetChildren()) do
                if budget and not stepBudget(budget) then return end
                if TURKEY_CLUTTER_FOLDERS[sub.Name] then
                    clearChildrenSafe(sub, budget)
                else
                    stripVisualsOnTree(sub, false)
                end
            end
        end
    end

    local function purgeForeignIslandDecor(islandFolder, budget)
        if not Optimizer.Enabled or not Optimizer.InEventZone or not islandFolder or not islandFolder.Parent then return end
        -- Leave BillboardGui/SurfaceGui (PumpkinTimer_*, PumpkinSign_*, PumpkinIsland_*) intact so Signs/Billboard never warn,
        -- and keep tracked Model/Folder shells inside Props/Ground/ShoreFill/Zones so Sections never warns on foreign unlocks/rebirths.
        for _, sub in ipairs(islandFolder:GetChildren()) do
            if budget and not stepBudget(budget) then return end
            if sub:IsA("LayerCollector") or sub:IsA("BillboardGui") or sub:IsA("SurfaceGui") or sub:IsA("ScreenGui") then
                -- Keep UI intact
            elseif sub.Name == "Props" or sub.Name == "Ground" or sub.Name == "ShoreFill" then
                purgeDecorContentsKeepShells(sub, budget)
            elseif sub.Name:match("^%d+ |") then
                for _, item in ipairs(sub:GetChildren()) do
                    if budget and not stepBudget(budget) then return end
                    if item.Name == "Pieces" then
                        for _, subItem in ipairs(item:GetChildren()) do
                            if budget and not stepBudget(budget) then return end
                            if hasGameTag(subItem) then
                                stripVisualsOnTree(subItem, false)
                            elseif subItem:IsA("Model") or subItem:IsA("Folder") or isSectionTrackedNodeFast(subItem) or #subItem:GetChildren() > 0 then
                                purgeDecorContentsKeepShells(subItem, budget)
                            elseif pcall(function() subItem:Destroy() end) then
                                trackDestroyed(1)
                            end
                        end
                    elseif hasGameTag(item) then
                        stripVisualsOnTree(item, false)
                    elseif item:IsA("Model") or item:IsA("Folder") or isSectionTrackedNodeFast(item) or #item:GetChildren() > 0 then
                        purgeDecorContentsKeepShells(item, budget)
                    elseif pcall(function() item:Destroy() end) then
                        trackDestroyed(1)
                    end
                end
            elseif sub.Name == "Front" then
                hideLeaderboardVisuals(sub)
            end
        end
    end

    local function purgeIslandsAndPlots(budget)
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        local myUidStr = tostring(LocalPlayer.UserId)

        -- 1. workspace.PumpkinTycoonIslands
        local pti = workspace:FindFirstChild("PumpkinTycoonIslands")
        if pti then
            for _, islandFolder in ipairs(pti:GetChildren()) do
                if budget and not stepBudget(budget) then return end
                if islandFolder.Name == myUidStr then
                    purgeOwnDecor(islandFolder, budget)
                elseif islandFolder.Name ~= "Shared" then
                    purgeForeignIslandDecor(islandFolder, budget)
                end
            end
        end

        -- 2. workspace.__THINGS.Plots (Own Mini_Orchard + Other plots' decorative clutter only)
        local myPlot = Net.GetPlotModel()
        local things = workspace:FindFirstChild("__THINGS")
        local plots = things and things:FindFirstChild("Plots")
        if plots then
            for _, plotModel in ipairs(plots:GetChildren()) do
                if budget and not stepBudget(budget) then return end
                for _, child in ipairs(plotModel:GetChildren()) do
                    if child.Name:match("^Mini_Orchard%d*$") then
                        local cnt = #child:GetChildren() + 1
                        if pcall(function() child:Destroy() end) then
                            trackDestroyed(cnt)
                        end
                    end
                end
                if plotModel ~= myPlot then
                    for _, subName in ipairs({ "WildAreas", "HayPileSpots", "Sections" }) do
                        local sub = plotModel:FindFirstChild(subName)
                        if sub then clearChildrenSafe(sub, budget) end
                    end
                elseif not Optimizer._cleanedPlots[plotModel] then
                    Optimizer._cleanedPlots[plotModel] = true
                    for _, d in ipairs(plotModel:GetDescendants()) do
                        if budget and not stepBudget(budget) then return end
                        if d:IsA("BasePart") then
                            saveAndSet(Optimizer._savedProps, d, "CastShadow", false)
                        end
                    end
                end
            end
        end

        -- 3. Active PumpkinTycoon animated Water wave layers
        local ic = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local active = ic and ic:FindFirstChild("Active")
        local ptInst = active and active:FindFirstChild("PumpkinTycoon")
        local water = ptInst and ptInst:FindFirstChild("Water")
        if water then
            for _, child in ipairs(water:GetChildren()) do
                if child.Name ~= "SeaBounds" and child:IsA("BasePart") then
                    if pcall(function() child:Destroy() end) then
                        trackDestroyed(1)
                    end
                end
            end
        end

        -- 4. Foreign breakables inside __THINGS.Breakables
        local brkFolder = things and things:FindFirstChild("Breakables")
        if brkFolder and myPlot then
            local _, mySuffix, myCF, mySize = getCachedPlotBox()
            if myCF and mySize then
                for _, model in ipairs(brkFolder:GetChildren()) do
                    if budget and not stepBudget(budget) then return end
                    scrubForeignBreakableModel(model, myCF, mySize, mySuffix)
                end
            end
        end
    end

    local function parkMainWorldBloat()
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end
        for _, target in ipairs(MAIN_WORLD_PARK_TARGETS) do
            local inst = target.parent and target.parent:FindFirstChild(target.name)
            if inst then
                parkInstance(inst)
            end
        end
        local things = workspace:FindFirstChild("__THINGS")
        if things then
            for _, name in ipairs(THINGS_PARK_NAMES) do
                local inst = things:FindFirstChild(name)
                if inst then
                    parkInstance(inst)
                end
            end
        end
        -- Hide PSX Portal & Ornaments visuals in-place instead of reparenting so WaitForChild & Mini Leaderboards never warn/error
        for _, root in ipairs({ workspace:FindFirstChild("PSX Portal"), things and things:FindFirstChild("Ornaments") }) do
            if root then
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("BasePart") then
                        saveAndSet(Optimizer._savedProps, d, "LocalTransparencyModifier", 1)
                        saveAndSet(Optimizer._savedProps, d, "CastShadow", false)
                    elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
                        saveAndSet(Optimizer._savedProps, d, "Enabled", false)
                    end
                end
            end
        end
    end

    local function clearWatchers(list)
        for _, conn in ipairs(list) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(list)
    end

    local function bindEventWatchers()
        clearWatchers(Optimizer._eventConns)
        if not Optimizer.Enabled or not Optimizer.InEventZone then return end

        local myUidStr = tostring(LocalPlayer.UserId)

        local function cleanDecorBatchItem(item, budget)
            if not Optimizer.Enabled or not Optimizer.InEventZone or not item or not item.Parent then return end
            if item.Name == "Props" then
                purgeDecorContentsKeepShells(item, budget)
            elseif item.Name == "Ground" then
                stripVisualsOnTree(item, true)
            elseif item.Name == "Front" then
                hideLeaderboardVisuals(item)
                stripVisualsOnTree(item, false)
            elseif item.Name:match("^%d+ |") then
                for _, sub in ipairs(item:GetChildren()) do
                    if sub.Name == "Pieces" then
                        for _, subItem in ipairs(sub:GetChildren()) do
                            if budget and not stepBudget(budget) then return end
                            if isWalkableOrFunctional(subItem) or hasGameTag(subItem) then
                                stripVisualsOnTree(subItem, false)
                            elseif subItem:IsA("Model") or subItem:IsA("Folder") or isSectionTrackedNodeFast(subItem) or #subItem:GetChildren() > 0 then
                                purgeDecorContentsKeepShells(subItem, budget)
                            elseif pcall(function() subItem:Destroy() end) then
                                trackDestroyed(1)
                            end
                        end
                    else
                        if budget and not stepBudget(budget) then return end
                        if isWalkableOrFunctional(sub) or hasGameTag(sub) then
                            stripVisualsOnTree(sub, false)
                        elseif sub:IsA("Model") or sub:IsA("Folder") or isSectionTrackedNodeFast(sub) or #sub:GetChildren() > 0 then
                            purgeDecorContentsKeepShells(sub, budget)
                        elseif pcall(function() sub:Destroy() end) then
                            trackDestroyed(1)
                        end
                    end
                end
            elseif isWalkableOrFunctional(item) or hasGameTag(item) then
                stripVisualsOnTree(item, false)
            elseif item:IsA("Model") or item:IsA("Folder") or isSectionTrackedNodeFast(item) or #item:GetChildren() > 0 then
                purgeDecorContentsKeepShells(item, budget)
            elseif pcall(function() item:Destroy() end) then
                trackDestroyed(1)
            end
        end

        local pendingDecorQueue = {}
        local decorFlushScheduled = false
        local function enqueueDecorClean(inst)
            if not Optimizer.Enabled or not Optimizer.InEventZone or not inst then return end
            table.insert(pendingDecorQueue, inst)
            if decorFlushScheduled then return end
            decorFlushScheduled = true
            task.delay(1.5, function()
                decorFlushScheduled = false
                if not Optimizer.Enabled or not Optimizer.InEventZone then
                    table.clear(pendingDecorQueue)
                    return
                end
                local batch = pendingDecorQueue
                pendingDecorQueue = {}
                local budget = makeBudget()
                for _, node in ipairs(batch) do
                    if not stepBudget(budget) then break end
                    cleanDecorBatchItem(node, budget)
                end
            end)
        end

        local function watchZoneChildFolder(zoneFolder)
            if not zoneFolder then return end
            table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(zoneFolder.ChildAdded:Connect(function(c)
                if c.Name == "Pieces" then
                    watchZoneChildFolder(c)
                end
                enqueueDecorClean(c)
            end)))
            local pieces = zoneFolder:FindFirstChild("Pieces")
            if pieces then
                table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(pieces.ChildAdded:Connect(enqueueDecorClean)))
            end
        end

        local function watchOwnDecorIncremental(decor)
            if not decor then return end
            table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(decor.ChildAdded:Connect(function(ch)
                if ch.Name:match("^%d+ |") or ch.Name == "Props" then
                    watchZoneChildFolder(ch)
                end
                enqueueDecorClean(ch)
            end)))
            for _, ch in ipairs(decor:GetChildren()) do
                if ch.Name:match("^%d+ |") or ch.Name == "Props" then
                    watchZoneChildFolder(ch)
                end
            end
        end

        local function attachPTIWatcher(pti)
            if not pti then return end
            table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(pti.ChildAdded:Connect(function(child)
                if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                task.delay(0.5, function()
                    if not Optimizer.Enabled or not Optimizer.InEventZone or not child.Parent then return end
                    if child.Name == myUidStr then
                        purgeOwnDecor(child, makeBudget())
                        watchOwnDecorIncremental(child)
                    elseif child.Name ~= "Shared" then
                        purgeForeignIslandDecor(child, makeBudget())
                    end
                end)
            end)))
            local myDecor = pti:FindFirstChild(myUidStr)
            if myDecor then
                watchOwnDecorIncremental(myDecor)
            end
        end

        local pti = workspace:FindFirstChild("PumpkinTycoonIslands")
        attachPTIWatcher(pti)
        table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(workspace.ChildAdded:Connect(function(child)
            if Optimizer.Enabled and Optimizer.InEventZone and child.Name == "PumpkinTycoonIslands" then
                task.defer(attachPTIWatcher, child)
            end
        end)))

        local things = workspace:FindFirstChild("__THINGS")
        local brkFolder = things and things:FindFirstChild("Breakables")
        if brkFolder then
            table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(brkFolder.ChildAdded:Connect(function(model)
                if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                local _, suffix = getCachedPlotBox()
                local areaId = model:GetAttribute("AreaID")
                if suffix and type(areaId) == "string" and areaId:sub(-#suffix) == suffix then
                    return
                end
                if isTurkeyBreakableModel(model) or model:GetAttribute("OwnerUsername") == LocalPlayer.Name then
                    return
                end
                table.insert(Optimizer._pendingForeignBrk, model)
                if Optimizer._foreignBrkScheduled then return end
                Optimizer._foreignBrkScheduled = true
                task.delay(3.0, function()
                    Optimizer._foreignBrkScheduled = false
                    if not Optimizer.Enabled or not Optimizer.InEventZone then
                        table.clear(Optimizer._pendingForeignBrk)
                        return
                    end
                    local batch = Optimizer._pendingForeignBrk
                    Optimizer._pendingForeignBrk = {}
                    local _, curSuffix, myCF, mySize = getCachedPlotBox()
                    if not (myCF and mySize) then return end
                    local budget = makeBudget()
                    for _, m in ipairs(batch) do
                        if not stepBudget(budget) then break end
                        scrubForeignBreakableModel(m, myCF, mySize, curSuffix)
                    end
                end)
            end)))
        end

        table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(Players.PlayerAdded:Connect(function(plr)
            if plr ~= LocalPlayer then
                table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(plr.CharacterAdded:Connect(function(char)
                    if Optimizer.Enabled and Optimizer.InEventZone then
                        task.delay(0.25, stripCharacterVisuals, plr, char)
                    end
                end)))
            end
        end)))
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(Optimizer._eventConns, Lifecycle.TrackConnection(plr.CharacterAdded:Connect(function(char)
                    if Optimizer.Enabled and Optimizer.InEventZone then
                        task.delay(0.25, stripCharacterVisuals, plr, char)
                    end
                end)))
            end
        end
    end

    local function updateStats(includeWorkspaceCount)
        local memMB = 0
        pcall(function()
            memMB = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb() * 10 + 0.5) / 10
        end)
        local parkedCount = 0
        for _ in pairs(Optimizer._parkedMainWorld) do
            parkedCount = parkedCount + 1
        end
        Optimizer.LastStats = {
            destroyed = Optimizer._destroyedCount,
            parked = parkedCount,
            workspaceDesc = includeWorkspaceCount and #workspace:GetDescendants() or (Optimizer.LastStats.workspaceDesc or 0),
            memoryMB = memMB,
        }
    end

    local function runFullEventOptimization()
        if not Optimizer.Enabled or Optimizer._purgeRunning then return end
        Optimizer._purgeRunning = true
        task.spawn(function()
            local ok, err = pcall(function()
                if not Optimizer.Enabled then return end
                Optimizer._lastDebrisSweepAt = os.clock()
                purgeDebrisAndLighting()
                if Optimizer.InEventZone then
                    local budget = makeBudget()
                    parkMainWorldBloat()
                    task.wait()
                    if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                    purgeTurkeyIsland(budget)
                    task.wait()
                    if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                    purgeIslandsAndPlots(budget)
                    task.wait()
                    if not Optimizer.Enabled or not Optimizer.InEventZone then return end
                    purgeOtherPlayersAndPets()
                end
                updateStats(false)
            end)
            Optimizer._purgeRunning = false
            if not ok then
                pcall(ctx.Utils.debugWarn, "PumpkinOptimizer", err)
            end
        end)
    end

    local function syncEventZoneState(forceSweep)
        local nowInEvent = Optimizer.Enabled and Net.IsInPumpkinTycoon()
        local changed = (nowInEvent ~= Optimizer.InEventZone)
        Optimizer.InEventZone = nowInEvent

        if not Optimizer.Enabled then
            clearWatchers(Optimizer._eventConns)
            unparkAll()
            return
        end

        if changed then
            if nowInEvent then
                bindEventWatchers()
                task.delay(0.35, function()
                    if Optimizer.Enabled and Optimizer.InEventZone then
                        runFullEventOptimization()
                    end
                end)
            else
                clearWatchers(Optimizer._eventConns)
                unparkAll()
                restoreBucket(Optimizer._savedProps)
            end
        elseif nowInEvent and forceSweep then
            runFullEventOptimization()
        end
    end

    function Optimizer.RestoreAll()
        clearWatchers(Optimizer._connections)
        clearWatchers(Optimizer._eventConns)
        Optimizer.InEventZone = false
        unparkAll()
        restoreBucket(Optimizer._savedProps)
    end

    function Optimizer.SetEnabled(enable)
        local target = enable == true
        ctx.States.PumpkinTycoon.OptimizePumpkinTycoon = target
        ctx.States.Optimization.OptimizePumpkinTycoon = target
        if target == Optimizer.Enabled then
            if target then
                syncEventZoneState(true)
            end
            return
        end

        Optimizer.Enabled = target
        if not target then
            Optimizer.RestoreAll()
            updateStats()
            return
        end

        Optimizer.InEventZone = Net.IsInPumpkinTycoon()
        purgeDebrisAndLighting()

        table.insert(Optimizer._connections, Lifecycle.TrackConnection(Lighting.ChildAdded:Connect(function(child)
            if not Optimizer.Enabled then return end
            if FLASH_NAMES[child.Name] or child.Name:find("PumpkinFx", 1, true) then
                task.defer(function()
                    if Optimizer.Enabled and child.Parent then
                        pcall(function() child:Destroy() end)
                        trackDestroyed(1)
                    end
                end)
            elseif Optimizer.InEventZone and (child:IsA("PostEffect") or child:IsA("Atmosphere")) then
                task.defer(function()
                    if Optimizer.Enabled and Optimizer.InEventZone and child.Parent then
                        saveAndSet(Optimizer._savedProps, child, "Enabled", false)
                    end
                end)
            end
        end)))

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            table.insert(Optimizer._connections, Lifecycle.TrackConnection(debris.ChildAdded:Connect(function(child)
                if Optimizer.Enabled and isDebrisCandidate(child) then
                    task.defer(scrubDebrisChild, child)
                end
            end)))
        end

        if Optimizer.InEventZone then
            bindEventWatchers()
            task.defer(runFullEventOptimization)
        end
    end

    -- General Optimization Tab states & reversible handlers
    Optimizer._brkConns = {}
    Optimizer._brkSaved = {}
    Optimizer._petConns = {}
    Optimizer._origConfetti = nil
    Optimizer._gameConns = {}
    Optimizer._gameSaved = {}

    local function hideBreakableModel(model)
        if not ctx.States.Optimization.DisableBreakablesModel then return end
        if typeof(model) ~= "Instance" or not model.Parent then return end
        if isTurkeyBreakableModel(model) then return end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                saveAndSet(Optimizer._brkSaved, d, "LocalTransparencyModifier", 1)
                saveAndSet(Optimizer._brkSaved, d, "CastShadow", false)
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("PointLight") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                saveAndSet(Optimizer._brkSaved, d, "Enabled", false)
            elseif d:IsA("Decal") or d:IsA("Texture") then
                saveAndSet(Optimizer._brkSaved, d, "Transparency", 1)
            end
        end
    end

    function Optimizer.SetDisableBreakablesModel(enable)
        local target = enable == true
        ctx.States.Optimization.DisableBreakablesModel = target
        clearWatchers(Optimizer._brkConns)

        local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
        if not target then
            restoreBucket(Optimizer._brkSaved)
            return
        end

        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                hideBreakableModel(m)
            end
            table.insert(Optimizer._brkConns, Lifecycle.TrackConnection(folder.ChildAdded:Connect(function(m)
                task.defer(hideBreakableModel, m)
            end)))
        end
    end

    function Optimizer.SetDisablePetsRendering(enable)
        local target = enable == true
        ctx.States.Optimization.DisablePetsRendering = target
        clearWatchers(Optimizer._petConns)

        local PlayerPet = Net.Mod.PlayerPet
        local function applyPetVis(petObj, visible)
            pcall(function()
                if petObj and petObj.cpet and petObj.cpet.SetVisible then
                    petObj.cpet:SetVisible(visible)
                end
            end)
        end

        if PlayerPet and PlayerPet.GetByPlayer then
            for _, plr in ipairs(Players:GetPlayers()) do
                for _, pet in pairs(PlayerPet.GetByPlayer(plr) or {}) do
                    applyPetVis(pet, not target)
                end
            end
            if target and PlayerPet.Created then
                table.insert(Optimizer._petConns, Lifecycle.TrackConnection(PlayerPet.Created:Connect(function(petObj)
                    if ctx.States.Optimization.DisablePetsRendering then
                        task.defer(applyPetVis, petObj, false)
                    end
                end)))
            end
        end

        local petsFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Pets")
        if petsFolder then
            for _, d in ipairs(petsFolder:GetDescendants()) do
                if d:IsA("BasePart") then
                    pcall(function() d.LocalTransparencyModifier = target and 1 or 0 end)
                elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
                    pcall(function() d.Enabled = not target end)
                end
            end
        end
    end

    function Optimizer.SetDisableConfettiRendering(enable)
        local target = enable == true
        ctx.States.Optimization.DisableConfettiRendering = target
        local GUIFX = Net.Mod.GUIFX
        if type(GUIFX) == "table" and type(GUIFX.Confetti) == "table" then
            if target then
                if not Optimizer._origConfetti and type(GUIFX.Confetti.Play) == "function" then
                    Optimizer._origConfetti = GUIFX.Confetti.Play
                end
                GUIFX.Confetti.Play = function() end
            elseif Optimizer._origConfetti then
                GUIFX.Confetti.Play = Optimizer._origConfetti
                Optimizer._origConfetti = nil
            end
        end
    end

    function Optimizer.SetOptimizeGame(enable)
        local target = enable == true
        ctx.States.Optimization.OptimizeGame = target
        clearWatchers(Optimizer._gameConns)

        if not target then
            restoreBucket(Optimizer._gameSaved)
            return
        end

        saveAndSet(Optimizer._gameSaved, Lighting, "GlobalShadows", false)
        saveAndSet(Optimizer._gameSaved, Lighting, "FogEnd", 1e9)
        for _, eff in ipairs(Lighting:GetChildren()) do
            if eff:IsA("PostEffect") or eff:IsA("Atmosphere") then
                saveAndSet(Optimizer._gameSaved, eff, "Enabled", false)
            end
        end

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            saveAndSet(Optimizer._gameSaved, terrain, "WaterWaveSize", 0)
            saveAndSet(Optimizer._gameSaved, terrain, "WaterReflectance", 0)
            saveAndSet(Optimizer._gameSaved, terrain, "WaterTransparency", 0)
            saveAndSet(Optimizer._gameSaved, terrain, "Decoration", false)
        end

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, ch in ipairs(debris:GetChildren()) do
                if ch:IsA("ParticleEmitter") or ch:IsA("BasePart") then
                    pcall(function() ch:Destroy() end)
                end
            end
            table.insert(Optimizer._gameConns, Lifecycle.TrackConnection(debris.ChildAdded:Connect(function(ch)
                if ctx.States.Optimization.OptimizeGame and (ch:IsA("ParticleEmitter") or ch.Name:find("Flash", 1, true) or ch.Name:find("Confetti", 1, true)) then
                    task.defer(function()
                        if ch.Parent then
                            pcall(function() ch:Destroy() end)
                        end
                    end)
                end
            end)))
        end
    end

    local SUPPRESSED_MACHINE_SCREENS = {
        Merchant = true,
        PumpkinMerchant = true,
        PumpkinTycoonUpgradeMachine = true,
        PumpkinTycoonCocoaStand = true,
        GoldMachine = true,
        RainbowMachine = true,
        FuseMachine = true,
        TycoonTeleportMachine = true,
        UpgradePotionsMachine = true,
        UpgradeEnchantsMachine = true,
        UpgradeFruitsMachine = true,
        PetEquipMachine = true,
        EggSlotsMachine = true,
        TransferMachine = true,
    }

    local GUARDED_MACHINE_NAMES = {
        "PetNetStore",
        "PumpkinMerchant",
        "PumpkinTycoonUpgradeMachine",
        "PumpkinTycoonCocoaStand",
        "GoldMachine",
        "RainbowMachine",
        "FuseMachine",
        "TycoonTeleportMachine",
        "UpgradePotionsMachine",
        "UpgradeEnchantsMachine",
        "UpgradeFruitsMachine",
        "PetEquipMachine",
        "EggSlotsMachine",
        "TransferMachine",
    }

    local function suppressMachineScreenGui(gui)
        if not Optimizer.HideMachineGuis or not gui or not gui:IsA("ScreenGui") then return end
        if not SUPPRESSED_MACHINE_SCREENS[gui.Name] then return end
        if gui.Enabled then
            pcall(function() gui.Enabled = false end)
        end
        table.insert(Optimizer._machGuiConns, Lifecycle.TrackConnection(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if Optimizer.HideMachineGuis and gui.Enabled then
                pcall(function() gui.Enabled = false end)
                local TC = Net.Mod.TabController
                if TC and TC.Get and TC.CloseTab and SUPPRESSED_MACHINE_SCREENS[TC.Get()] then
                    pcall(TC.CloseTab)
                end
            end
        end)))
    end

    function Optimizer.SetHideMachineGuis(enable)
        local target = enable == true
        ctx.States.Optimization.HideMachineGuis = target
        Optimizer.HideMachineGuis = target
        clearWatchers(Optimizer._machGuiConns)

        local TC = Net.Mod.TabController
        local MC = Net.Mod.MachineCmds

        local function collectGuardedNames()
            local set = {}
            for _, n in ipairs(GUARDED_MACHINE_NAMES) do set[n] = true end
            local dirMerch = Net.Mod.Directory and Net.Mod.Directory.Merchants
            if type(dirMerch) == "table" then
                for _, row in pairs(dirMerch) do
                    if type(row) == "table" and type(row.MachineName) == "string" then
                        set[row.MachineName] = true
                    end
                end
            end
            return set
        end

        if not target then
            if TC and Optimizer._origOpenTab and TC.OpenTab ~= Optimizer._origOpenTab then
                TC.OpenTab = Optimizer._origOpenTab
                Optimizer._origOpenTab = nil
            end
            if MC then
                for name in pairs(collectGuardedNames()) do
                    if MC.AllowOpen then pcall(MC.AllowOpen, name) end
                    if MC.SetOpenGuard then pcall(MC.SetOpenGuard, name, nil) end
                end
            end
            return
        end

        -- 1. Block MachineCmds pad triggers cleanly
        if MC then
            local denyGuard = function()
                return not Optimizer.HideMachineGuis
            end
            for name in pairs(collectGuardedNames()) do
                if MC.PreventOpen then pcall(MC.PreventOpen, name) end
                if MC.SetOpenGuard then pcall(MC.SetOpenGuard, name, denyGuard) end
            end
        end

        -- 2. Wrap TabController.OpenTab so Merchant/PetNetStore & machines never blur/open screen
        if TC and type(TC.OpenTab) == "function" then
            if not Optimizer._origOpenTab then
                Optimizer._origOpenTab = TC.OpenTab
            end
            local origOpen = Optimizer._origOpenTab
            TC.OpenTab = function(tabId, ...)
                if Optimizer.HideMachineGuis and SUPPRESSED_MACHINE_SCREENS[tabId] then
                    return false
                end
                return origOpen(tabId, ...)
            end

            -- Close immediately if already open right now
            if TC.Get and TC.CloseTab then
                local cur = TC.Get()
                if cur and SUPPRESSED_MACHINE_SCREENS[cur] then
                    pcall(TC.CloseTab)
                end
            end

            if TC.Opened and TC.Opened.Connect then
                table.insert(Optimizer._machGuiConns, Lifecycle.TrackConnection(TC.Opened:Connect(function(tabId)
                    if Optimizer.HideMachineGuis and SUPPRESSED_MACHINE_SCREENS[tabId] then
                        task.defer(function()
                            if Optimizer.HideMachineGuis and TC.IsOpen and TC.IsOpen(tabId) then
                                pcall(TC.CloseTab)
                            end
                        end)
                    end
                end)))
            end
        end

        -- 3. Guard PlayerGui._MACHINES ScreenGuis as a final safety net
        local pg = ctx.Roblox.PlayerGui
        local machinesFolder = pg and pg:FindFirstChild("_MACHINES")
        if machinesFolder then
            for _, child in ipairs(machinesFolder:GetChildren()) do
                suppressMachineScreenGui(child)
            end
            table.insert(Optimizer._machGuiConns, Lifecycle.TrackConnection(machinesFolder.ChildAdded:Connect(function(child)
                suppressMachineScreenGui(child)
            end)))
        end
    end

    function Optimizer.ApplyAll()
        local Opt = ctx.States.Optimization
        Optimizer.SetEnabled(Opt.OptimizePumpkinTycoon or ctx.States.PumpkinTycoon.OptimizePumpkinTycoon)
        Optimizer.SetDisableBreakablesModel(Opt.DisableBreakablesModel)
        Optimizer.SetDisablePetsRendering(Opt.DisablePetsRendering)
        Optimizer.SetDisableConfettiRendering(Opt.DisableConfettiRendering)
        Optimizer.SetOptimizeGame(Opt.OptimizeGame)
        Optimizer.SetHideMachineGuis(Opt.HideMachineGuis ~= false)
    end

    function PumpkinOptimizer.Start()
        Optimizer.SetHideMachineGuis(ctx.States.Optimization.HideMachineGuis ~= false)

        -- Monitor event-zone entry/exit immediately via __INSTANCE_CONTAINER.Active
        local things = workspace:FindFirstChild("__THINGS")
        local ic = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local active = ic and ic:FindFirstChild("Active")
        if active then
            Lifecycle.TrackConnection(active.ChildAdded:Connect(function(child)
                if child.Name == "PumpkinTycoon" and Optimizer.Enabled then
                    syncEventZoneState(true)
                end
            end))
            Lifecycle.TrackConnection(active.ChildRemoved:Connect(function(child)
                if child.Name == "PumpkinTycoon" and Optimizer.Enabled then
                    task.defer(syncEventZoneState, false)
                end
            end))
        end

        Lifecycle.SpawnLoop("PumpkinOptimizerSweep", function()
            return Optimizer.Enabled and 10.0 or 3.0
        end, function()
            if not Optimizer.Enabled then return end
            syncEventZoneState(false)
            local now = os.clock()
            if now - Optimizer._lastDebrisSweepAt >= 60.0 then
                Optimizer._lastDebrisSweepAt = now
                purgeDebrisAndLighting()
            end
            if Optimizer.InEventZone and now - Optimizer._eventPurgeAt >= 120.0 then
                Optimizer._eventPurgeAt = now
                runFullEventOptimization()
            end
        end)

        Lifecycle.RegisterCleanup(function()
            Optimizer.SetEnabled(false)
            Optimizer.SetDisableBreakablesModel(false)
            Optimizer.SetDisablePetsRendering(false)
            Optimizer.SetDisableConfettiRendering(false)
            Optimizer.SetOptimizeGame(false)
            Optimizer.SetHideMachineGuis(false)
        end)
    end

    ctx.Optimizer = Optimizer
    ctx.API.setOptimizePumpkinTycoon = Optimizer.SetEnabled
    ctx.API.setHideMachineGuis = Optimizer.SetHideMachineGuis
    ctx.API.getOptimizerStats = function()
        updateStats(true)
        return Optimizer.LastStats
    end
    return Optimizer
end

return PumpkinOptimizer
