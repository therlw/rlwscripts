-- src/Systems/Optimization/CpuSaver.lua
-- Destroy-Based Regional Map Culling, Potato Visual Stripping & Lossless Restoration

local CpuSaver = {}

function CpuSaver.Init(ctx)
    local Players = ctx.Roblox.Players
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local OptimizationState = ctx.States.Optimization
    local KaitunState = ctx.States.Kaitun
    local UI = ctx.UI
    local getPlayerData = ctx.API.getPlayerData
    local debugLog = ctx.Utils.debugLog

    local savedVisualProps = {}
    local savedGlobalShadows = nil
    local savedFpsCap = nil
    local cpuSaverConnections = {}
    local isUpdatingCpuSaverToggle = false
    local culledRegistry = {} -- List of { instance = Instance, originalParent = Instance, name = string, area = string }
    local lastActiveArea = nil
    local lastTargetArea = nil

    local function getCurrentAreaName()
        if ctx.API.getPhysicalCurrentIsland then
            local ok, p = pcall(ctx.API.getPhysicalCurrentIsland)
            if ok and p and p ~= "" then return p end
        end
        if KaitunState and KaitunState.CurrentIsland and KaitunState.CurrentIsland ~= "" then
            return KaitunState.CurrentIsland
        end
        local data = getPlayerData()
        if data and data.Progression and data.Progression.Island then
            return data.Progression.Island
        end
        return "Spawn"
    end

    local function getTargetAreaName()
        if ctx.API.getNextLockedIsland then
            local ok, n = pcall(ctx.API.getNextLockedIsland)
            if ok and n and n.name then return n.name end
        end
        return nil
    end

    -- Strict Gameplay Whitelist & Hierarchy Protection (User Rules 3, 4, 7, 9, 10)
    local function isGameplayCriticalInstance(obj)
        if not obj then return true end

        local name = obj.Name
        if name == "Portal Decor" or name == "HoneyPotArea" or name == "Borders"
            or name == "RiftGate" or name == "BalloonLuck" or name == "Greg"
            or name == "Paving" or name == "SkyRift" or name == "AmbientClouds"
            or name == "AltitudeAmbience" or name == "TS2Tumbleweeds" or name == "Decor"
            or name == "Clouds" or name:find("Daisy") or name:find("Flower")
            or name:find("Bush") or name:find("Lawn") or name:find("Planter")
            or name:find("Crate") or (name:find("Border") and not name:find("Island"))
            or name == "Water" or name == "Watervfx" or name == "Foliage" or name == "Trees"
            or name == "Rocks" or name == "Log" or name:find("DirtPatch")
            or (obj.Parent and obj.Parent.Name == "Map1" and name == "Terrain")
            or name == "Fishing" or name == "FishingLocal" or name == "WaveDefence Island"
            or name:find("TradePlaza") or name == "IslandBreakableSigns" or name == "FloatingSigns"
            or name == "Onboarding" or name == "WorldEventFx" or name == "BreakableFx"
            or name == "ShinyStarFx" or name == "GoldPets" or name == "RainbowPets"
            or name == "_PetShadows" or name == "DiamondPets" or name == "SelectedPets"
            or name == "HighlightedPets" or name == "MemoryMatch" or name == "LuckyMachine"
            or name == "HalloweenIsland" or name == "Fence" or name == "grassBlock"
            or name == "BallTrials" or name == "FireworkShows" or name == "AssetPack" then
            return false
        end

        local cur = obj
        while cur and cur ~= workspace and cur ~= game do
            local curName = cur.Name

            if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then
                return true
            end

            if cur:IsA("LuaSourceContainer") or cur:IsA("RemoteEvent") or cur:IsA("RemoteFunction")
                or cur:IsA("BindableEvent") or cur:IsA("BindableFunction") then
                return true
            end

            if cur == workspace:FindFirstChildOfClass("Terrain")
                or curName == "World2" or curName == "Ts2Islands" or curName == "Map1"
                or curName:find("Floor") or curName:find("Ground") or curName:find("Base")
                or curName:find("Island") or curName:find("Path") or curName:find("Platform") or curName:find("Bridge")
                or curName:find("Stair") or curName:find("Step") or curName:find("CloudStep") or curName:find("CloudGeneration")
                or curName:find("SpawnLocation") or curName:find("Road") or curName == "Arrival" or curName == "ReturnPortal" then
                return true
            end

            if curName:find("Egg") or curName:find("Stand") or curName:find("Portal") or curName:find("NextPortals")
                or curName:find("Machine") or curName:find("Golden") or curName:find("Rainbow") or curName:find("Diamond")
                or curName:find("Double") or curName:find("Craft") or curName:find("Fuse")
                or curName:find("Rebirth") or curName:find("Shop") or curName:find("Upgrade") or curName:find("Merchant")
                or curName:find("Chest") or curName:find("Reward") or curName:find("Gift") or curName:find("Drop")
                or curName:find("Star") or curName:find("ShinyStar") or curName:find("Ducky") or curName:find("Coin") or curName:find("Token")
                or curName:find("Pad") or curName:find("Zone") or curName:find("Gate") or curName:find("Button") or curName:find("Hitbox")
                or curName:find("Prompt") or curName:find("Door") or curName:find("Interact") or curName:find("TapField")
                or curName:find("Npc") or curName:find("Quest") or curName:find("Dialogue") or curName:find("Leaderboard")
                or curName:find("Lbs") or curName:find("Board") then
                return true
            end

            cur = cur.Parent
        end

        for _, desc in ipairs(obj:GetDescendants()) do
            if desc:IsA("LuaSourceContainer") or desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")
                or desc:IsA("BindableEvent") or desc:IsA("BindableFunction")
                or desc:IsA("ProximityPrompt") or desc:IsA("ClickDetector") or desc:IsA("TouchTransmitter") then
                return true
            end
        end

        return false
    end

    local function isPartUnderOrNearPlayer(obj)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return true end

        local hrpPos = hrp.Position

        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local hit = workspace:Raycast(hrpPos, Vector3.new(0, -35, 0), params)
        if hit and hit.Instance then
            if hit.Instance == obj or hit.Instance:IsDescendantOf(obj) or obj:IsDescendantOf(hit.Instance) then
                return true
            end
        end

        if obj:IsA("BasePart") then
            if (obj.Position - hrpPos).Magnitude <= 55 then
                return true
            end
        elseif obj:IsA("Model") or obj:IsA("Folder") then
            for _, p in ipairs(obj:GetChildren()) do
                if p:IsA("BasePart") and (p.Position - hrpPos).Magnitude <= 55 then
                    return true
                end
            end
        end

        return false
    end

    local function safeCullInstance(obj, areaTag)
        if not obj or not obj.Parent then return false end
        if isGameplayCriticalInstance(obj) then return false end
        if isPartUnderOrNearPlayer(obj) then return false end

        local origParent = obj.Parent
        local origName = obj.Name
        table.insert(culledRegistry, {
            instance = obj,
            originalParent = origParent,
            name = origName,
            area = areaTag or "Global"
        })

        pcall(function()
            obj.Parent = nil
        end)
        return true
    end

    local function restoreAllCulledInstances()
        if #culledRegistry == 0 then return end
        for i = #culledRegistry, 1, -1 do
            local entry = culledRegistry[i]
            pcall(function()
                if entry.instance and entry.instance.Parent == nil then
                    if entry.originalParent and entry.originalParent.Parent ~= nil then
                        entry.instance.Parent = entry.originalParent
                    else
                        entry.instance.Parent = workspace
                    end
                end
            end)
        end
        culledRegistry = {}
    end

    local function restoreCulledArea(areaTag)
        if not areaTag or #culledRegistry == 0 then return end
        local w2Regions = {
            ["World2"] = true, ["World2Decor"] = true, ["World 2 Spawn"] = true,
            ["Prehistoric Island"] = true, ["Ice Age"] = true, ["Medieval Island"] = true,
            ["TimeRift"] = true,
        }
        local remaining = {}
        for _, entry in ipairs(culledRegistry) do
            local match = (entry.area == areaTag)
            if not match and w2Regions[areaTag] and w2Regions[entry.area] then
                match = true
            end
            if not match and (areaTag == "World1" or areaTag == "Main" or areaTag == "Spawn") then
                if entry.area == "Map1" or entry.area == "Spawn" or entry.area == "Ts2Islands" then
                    match = true
                end
            end
            if match then
                pcall(function()
                    if entry.instance and entry.instance.Parent == nil then
                        if entry.originalParent and entry.originalParent.Parent ~= nil then
                            entry.instance.Parent = entry.originalParent
                        else
                            entry.instance.Parent = workspace
                        end
                    end
                end)
            else
                table.insert(remaining, entry)
            end
        end
        culledRegistry = remaining
    end

    local function updateRegionalCulling()
        if not OptimizationState.CpuSaver then return end

        local curArea = getCurrentAreaName()
        local tgtArea = getTargetAreaName()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local isPhysicallyInWorld2 = hrp and (hrp.Position.Z > 3000)

        if curArea ~= lastActiveArea or isPhysicallyInWorld2 then
            if isPhysicallyInWorld2 or curArea == "World 2 Spawn" or curArea == "Ice Age" or curArea == "Prehistoric Island" or curArea == "Medieval Island" then
                restoreCulledArea("World2")
                restoreCulledArea("World2Decor")
            else
                restoreCulledArea(curArea)
            end
            lastActiveArea = curArea
        end
        if tgtArea ~= lastTargetArea then
            if tgtArea then
                restoreCulledArea(tgtArea)
            end
            lastTargetArea = tgtArea
        end

        local ts2 = workspace:FindFirstChild("Ts2Islands")
        if ts2 then
            for _, isl in ipairs(ts2:GetChildren()) do
                if isl.Name ~= curArea and isl.Name ~= tgtArea then
                    local decor = isl:FindFirstChild("Decor")
                    if decor then
                        safeCullInstance(decor, isl.Name)
                    end
                end
            end
        end

        local map1 = workspace:FindFirstChild("Map1")
        if map1 and curArea ~= "Spawn" and tgtArea ~= "Spawn" then
            for _, n in ipairs({"Trees", "Rocks", "Foliage", "Watervfx"}) do
                local folder = map1:FindFirstChild(n)
                if folder then
                    safeCullInstance(folder, "Map1")
                end
            end
        end
    end

    local function applyCpuSaver(enable)
        if enable then
            pcall(function()
                local lighting = game:GetService("Lighting")
                if savedGlobalShadows == nil then
                    savedGlobalShadows = lighting.GlobalShadows
                end
                lighting.GlobalShadows = false
                lighting.FogEnd = 9e9

                for _, obj in ipairs(lighting:GetChildren()) do
                    if obj:IsA("PostEffect") then
                        if savedVisualProps[obj] == nil then
                            savedVisualProps[obj] = { Enabled = obj.Enabled }
                        end
                        obj.Enabled = false
                    end
                end
            end)

            pcall(function()
                local nonEssentialNames = {
                    "Fishing", "FishingLocal", "TradePlaza", "TradePlazaV2", "WaveDefence Island",
                    "IslandBreakableSigns", "FloatingSigns", "Onboarding", "WorldEventFx", "BreakableFx",
                    "ShinyStarFx", "GoldPets", "RainbowPets", "_PetShadows", "DiamondPets", "SelectedPets",
                    "HighlightedPets", "Arctic", "Volcano", "Sky Island", "MemoryMatch", "LuckyMachine",
                    "SkyRift", "AmbientClouds", "AltitudeAmbience", "TS2Tumbleweeds",
                    "CloudRoute", "CloudRain", "Clouds", "RiftGate", "BalloonLuck", "Greg", "Paving",
                    "HalloweenIsland", "BallTrials", "FireworkShows", "AssetPack", "Fence", "grassBlock",
                    "Effects", "Vfx", "Tip1", "PetInstances"
                }
                for _, name in ipairs(nonEssentialNames) do
                    local obj = workspace:FindFirstChild(name)
                    if obj then safeCullInstance(obj, "NonEssential") end
                end

                for _, c in ipairs(workspace:GetChildren()) do
                    if c:IsA("Model") and (c.Name == "Model" or c.Name == "Fence" or c.Name == "grassBlock" or c.Name == "Tip1") then
                        if not isGameplayCriticalInstance(c) and not isPartUnderOrNearPlayer(c) then
                            safeCullInstance(c, "DecorativeModels")
                        end
                    end
                end

                local w2 = workspace:FindFirstChild("World2")
                if w2 then
                    for _, n in ipairs({"Sea", "Clouds", "SeasonPets"}) do
                        local obj = w2:FindFirstChild(n)
                        if obj then safeCullInstance(obj, "World2Decor") end
                    end
                    local w2s = w2:FindFirstChild("World 2 Spawn")
                    if w2s then
                        for _, n in ipairs({"RiftRing", "Sharks"}) do
                            local obj = w2s:FindFirstChild(n)
                            if obj then safeCullInstance(obj, "World2Decor") end
                        end
                    end
                end

                local port = workspace:FindFirstChild("Portals")
                if port and port:FindFirstChild("Portal Decor") then
                    safeCullInstance(port["Portal Decor"], "Portals")
                end

                for _, c in ipairs(workspace:GetChildren()) do
                    local n = c.Name
                    if n:find("Daisy") or n:find("Flower") or n:find("Bush") or n:find("Lawn")
                        or n:find("Planter") or n:find("Crate") or (n:find("Border") and not n:find("Island"))
                        or n == "Water" or n:find("Rock") or n:find("DirtPatch") then
                        safeCullInstance(c, "RootClutter")
                    end
                end

                local map1 = workspace:FindFirstChild("Map1")
                if map1 then
                    for _, n in ipairs({"Borders", "HoneyPotArea", "Foliage", "Trees", "Rocks", "Watervfx", "Log"}) do
                        local obj = map1:FindFirstChild(n)
                        if obj then safeCullInstance(obj, "Map1") end
                    end
                    for _, c in ipairs(map1:GetChildren()) do
                        if c.Name == "Water" then
                            safeCullInstance(c, "Map1")
                        end
                    end
                    local mTerr = map1:FindFirstChild("Terrain")
                    if mTerr then
                        safeCullInstance(mTerr, "Map1")
                    end
                end
            end)

            pcall(function()
                updateRegionalCulling()
            end)

            pcall(function()
                local char = LocalPlayer.Character
                for _, desc in ipairs(workspace:GetDescendants()) do
                    if not (char and desc:IsDescendantOf(char)) then
                        if desc:IsA("BasePart") then
                            if savedVisualProps[desc] == nil then
                                savedVisualProps[desc] = {
                                    Material = desc.Material,
                                    Color = desc.Color
                                }
                                if desc:IsA("MeshPart") then
                                    savedVisualProps[desc].TextureID = desc.TextureID
                                end
                            end
                            desc.Material = Enum.Material.SmoothPlastic
                            desc.Color = Color3.fromRGB(240, 240, 240)
                            if desc:IsA("MeshPart") and desc.TextureID ~= "" then
                                desc.TextureID = ""
                            end
                        elseif desc:IsA("Decal") or desc:IsA("Texture") then
                            local isGui = desc:FindFirstAncestorOfClass("BillboardGui") or desc:FindFirstAncestorOfClass("SurfaceGui")
                            if not isGui then
                                if savedVisualProps[desc] == nil then
                                    savedVisualProps[desc] = { Transparency = desc.Transparency }
                                end
                                desc.Transparency = 1
                            end
                        elseif desc:IsA("SpecialMesh") then
                            if desc.TextureId ~= "" then
                                if savedVisualProps[desc] == nil then
                                    savedVisualProps[desc] = { TextureId = desc.TextureId }
                                end
                                desc.TextureId = ""
                            end
                        elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail")
                            or desc:IsA("Highlight") or desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
                            if not isGameplayCriticalInstance(desc) and not isPartUnderOrNearPlayer(desc) then
                                if savedVisualProps[desc] == nil then
                                    savedVisualProps[desc] = { Enabled = desc.Enabled }
                                end
                                desc.Enabled = false
                            end
                        end
                    end
                end

                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    if savedVisualProps[terrain] == nil then
                        savedVisualProps[terrain] = {
                            WaterWaveSize = terrain.WaterWaveSize,
                            WaterWaveSpeed = terrain.WaterWaveSpeed
                        }
                    end
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                end
            end)

            pcall(function()
                if type(getfpscap) == "function" and type(setfpscap) == "function" then
                    local curCap = getfpscap()
                    if savedFpsCap == nil then
                        savedFpsCap = curCap
                    end
                    if curCap == 0 or curCap > 15 then
                        setfpscap(15)
                    end
                end
            end)

            pcall(function()
                local connChar = LocalPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if OptimizationState.CpuSaver then
                        updateRegionalCulling()
                    end
                end)
                table.insert(cpuSaverConnections, connChar)
            end)

            debugLog("CPU Saver ENABLED: Destroy culling + Full White Potato mode active, FPS capped to 15.")
        else
            pcall(function()
                restoreAllCulledInstances()
            end)

            pcall(function()
                local lighting = game:GetService("Lighting")
                if savedGlobalShadows ~= nil then
                    lighting.GlobalShadows = savedGlobalShadows
                    savedGlobalShadows = nil
                end
            end)

            for instance, props in pairs(savedVisualProps) do
                if instance and instance.Parent then
                    pcall(function()
                        for propName, origVal in pairs(props) do
                            instance[propName] = origVal
                        end
                    end)
                end
            end
            savedVisualProps = {}

            for _, conn in ipairs(cpuSaverConnections) do
                pcall(function() conn:Disconnect() end)
            end
            cpuSaverConnections = {}

            pcall(function()
                if savedFpsCap ~= nil and type(setfpscap) == "function" then
                    setfpscap(savedFpsCap)
                    savedFpsCap = nil
                end
            end)

            lastActiveArea = nil
            lastTargetArea = nil

            debugLog("CPU Saver DISABLED: All culled map geometry restored, textures, visuals, lighting, and FPS returned to original.")
        end
    end

    local cpuSaverApplied = false

    local function setCpuSaverState(val)
        val = val == true
        if OptimizationState.CpuSaver == val and cpuSaverApplied == val then return end
        OptimizationState.CpuSaver = val
        cpuSaverApplied = val
        applyCpuSaver(val)

        if not isUpdatingCpuSaverToggle then
            isUpdatingCpuSaverToggle = true
            pcall(function()
                if UI.KaitunCpuSaverToggle and UI.KaitunCpuSaverToggle.Set then
                    UI.KaitunCpuSaverToggle:Set(val)
                end
                if UI.OptCpuSaverToggle and UI.OptCpuSaverToggle.Set then
                    UI.OptCpuSaverToggle:Set(val)
                end
            end)
            isUpdatingCpuSaverToggle = false
        end
    end

    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()
    genv._RLW_CpuSaverRestore = function()
        applyCpuSaver(false)
    end
    pcall(function()
        genv.OptimizationState = OptimizationState
        genv._RLW_SetCpuSaver = setCpuSaverState
        genv._RLW_UpdateRegionalCulling = updateRegionalCulling
    end)

    local A = ctx.API
    A.restoreAllCulledInstances = restoreAllCulledInstances
    A.restoreAllCulled = restoreAllCulledInstances
    A.restoreCulledArea = restoreCulledArea
    A.updateRegionalCulling = updateRegionalCulling
    A.applyCpuSaver = applyCpuSaver
    A.setCpuSaverState = setCpuSaverState

    CpuSaver.SetEnabled = setCpuSaverState
    CpuSaver.RestoreAll = restoreAllCulledInstances
    CpuSaver.RestoreArea = restoreCulledArea
    CpuSaver.UpdateRegionalCulling = updateRegionalCulling
    CpuSaver.Apply = applyCpuSaver

    return CpuSaver
end

return CpuSaver
