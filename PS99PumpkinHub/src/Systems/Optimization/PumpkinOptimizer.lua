-- src/Systems/Optimization/PumpkinOptimizer.lua
-- Reversible Performance Optimizer ("Optimize Pumpkin Tycoon")
-- Removes Lighting flashes (PumpkinFxFlash/Dim), debris flashes (TurkeyFlash), confetti & heavy emitters
-- across both Home Island AND Turkey Island (PumpkinTycoonShared) without breaking interactables.

local PumpkinOptimizer = {}

function PumpkinOptimizer.Init(ctx)
    local Lighting = ctx.Roblox.Lighting
    local Net = ctx.Net
    local Lifecycle = ctx.Lifecycle

    local Optimizer = {
        Enabled = false,
        _savedProps = {},
        _connections = {},
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

    local function saveAndSet(inst, prop, val)
        local rec = Optimizer._savedProps[inst]
        if not rec then
            rec = {}
            Optimizer._savedProps[inst] = rec
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

    local function isProtectedInstance(inst)
        local cur = inst
        while cur and cur ~= workspace do
            local n = cur.Name
            if n == "Buttons" or n == "PumpkinTycoonPads" or n == "Interactable" or n == "Breakables" or n == "CustomEggs" or n == "Pets" then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function scrubInstance(inst)
        if not Optimizer.Enabled or not inst or not inst.Parent then return end

        if FLASH_NAMES[inst.Name] or (inst:IsA("ColorCorrectionEffect") and (inst.Name:find("Pumpkin") or inst.Name:find("Turkey"))) then
            if inst:IsA("PostEffect") or inst:IsA("BasePart") then
                if inst:IsA("PostEffect") then
                    saveAndSet(inst, "Enabled", false)
                else
                    saveAndSet(inst, "Transparency", 1)
                end
                pcall(function()
                    local pl = inst:FindFirstChildOfClass("PointLight")
                    if pl then saveAndSet(pl, "Enabled", false) end
                end)
                return
            end
        end

        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
            if not isProtectedInstance(inst) then
                saveAndSet(inst, "Enabled", false)
            end
        elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
            if not isProtectedInstance(inst) then
                saveAndSet(inst, "Enabled", false)
            end
        elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            if not isProtectedInstance(inst) then
                saveAndSet(inst, "Enabled", false)
            end
        end
    end

    local function cleanFlashContainers()
        if not Optimizer.Enabled then return end
        for _, child in ipairs(Lighting:GetChildren()) do
            if FLASH_NAMES[child.Name] or child.Name:find("PumpkinFx") then
                pcall(function() child:Destroy() end)
            end
        end

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, d in ipairs(debris:GetChildren()) do
                if d.Name == "TurkeyFlash" or d.Name:find("Pumpkin") or d.Name:find("Confetti") then
                    pcall(function() d:Destroy() end)
                elseif d:IsA("ParticleEmitter") then
                    saveAndSet(d, "Enabled", false)
                end
            end
        end

        pcall(function()
            if Net.Mod.PumpkinFx and Net.Mod.PumpkinFx.ClearAll then
                Net.Mod.PumpkinFx.ClearAll()
            end
        end)

        -- Clean Turkey Island (PumpkinTycoonShared) emitters/lights & clutter props safely
        local shared = Net.GetTurkeyIslandFolder()
        if shared then
            for _, d in ipairs(shared:GetDescendants()) do
                scrubInstance(d)
            end
            local sharedDecor = shared:FindFirstChild("Decor")
            if sharedDecor then
                for _, d in ipairs(sharedDecor:GetDescendants()) do
                    if d:IsA("BasePart") and d.Name ~= "Hitbox" and not d:IsDescendantOf(shared:FindFirstChild("Interactable") or sharedDecor) then
                        local pName = d.Parent and d.Parent.Name or ""
                        if pName:find("Tree") or pName:find("Bush") or pName:find("Cloud") or pName:find("Leaf") or pName:find("Prop") or d.Name:find("Light") or d.Name:find("Neon") then
                            saveAndSet(d, "LocalTransparencyModifier", 1)
                            saveAndSet(d, "CastShadow", false)
                        end
                    end
                end
            end
        end

        -- Clean own plot Props / Visual FX (without touching buttons, pedestals, eggs)
        local decor = Net.GetPlotDecor()
        if decor then
            local props = decor:FindFirstChild("Props")
            if props then
                for _, d in ipairs(props:GetDescendants()) do
                    scrubInstance(d)
                end
            end
            for _, d in ipairs(decor:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("Trail") or d:IsA("Beam") then
                    scrubInstance(d)
                end
            end
        end
    end

    local function clearWatchers()
        for _, conn in ipairs(Optimizer._connections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(Optimizer._connections)
    end

    function Optimizer.RestoreAll()
        clearWatchers()
        for inst, props in pairs(Optimizer._savedProps) do
            if inst and inst.Parent then
                for prop, oldVal in pairs(props) do
                    pcall(function() inst[prop] = oldVal end)
                end
            end
        end
        table.clear(Optimizer._savedProps)
    end

    function Optimizer.SetEnabled(enable)
        local target = enable == true
        if target == Optimizer.Enabled then return end
        Optimizer.Enabled = target
        ctx.States.PumpkinTycoon.OptimizePumpkinTycoon = target
        ctx.States.Optimization.OptimizePumpkinTycoon = target

        if not target then
            if not ctx.States.Optimization.OptimizeGame then
                Optimizer.RestoreAll()
            end
            return
        end

        cleanFlashContainers()

        table.insert(Optimizer._connections, Lifecycle.TrackConnection(Lighting.ChildAdded:Connect(function(child)
            if not Optimizer.Enabled then return end
            if FLASH_NAMES[child.Name] or child.Name:find("PumpkinFx") then
                task.defer(function()
                    if Optimizer.Enabled and child.Parent then
                        pcall(function() child:Destroy() end)
                    end
                end)
            end
        end)))

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            table.insert(Optimizer._connections, Lifecycle.TrackConnection(debris.ChildAdded:Connect(function(child)
                if not Optimizer.Enabled then return end
                if child.Name == "TurkeyFlash" or child.Name:find("Confetti") then
                    task.defer(function()
                        if Optimizer.Enabled and child.Parent then
                            pcall(function() child:Destroy() end)
                        end
                    end)
                else
                    task.defer(scrubInstance, child)
                end
            end)))
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
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                if not Optimizer._brkSaved[d] then Optimizer._brkSaved[d] = {} end
                if Optimizer._brkSaved[d].LocalTransparencyModifier == nil then
                    Optimizer._brkSaved[d].LocalTransparencyModifier = d.LocalTransparencyModifier
                end
                if Optimizer._brkSaved[d].CastShadow == nil then
                    Optimizer._brkSaved[d].CastShadow = d.CastShadow
                end
                d.LocalTransparencyModifier = 1
                d.CastShadow = false
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("PointLight") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                if not Optimizer._brkSaved[d] then Optimizer._brkSaved[d] = {} end
                if Optimizer._brkSaved[d].Enabled == nil then
                    Optimizer._brkSaved[d].Enabled = d.Enabled
                end
                pcall(function() d.Enabled = false end)
            elseif d:IsA("Decal") or d:IsA("Texture") then
                if not Optimizer._brkSaved[d] then Optimizer._brkSaved[d] = {} end
                if Optimizer._brkSaved[d].Transparency == nil then
                    Optimizer._brkSaved[d].Transparency = d.Transparency
                end
                d.Transparency = 1
            end
        end
    end

    function Optimizer.SetDisableBreakablesModel(enable)
        local target = enable == true
        ctx.States.Optimization.DisableBreakablesModel = target
        for _, c in ipairs(Optimizer._brkConns) do pcall(function() c:Disconnect() end) end
        table.clear(Optimizer._brkConns)

        local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
        if not target then
            for inst, props in pairs(Optimizer._brkSaved) do
                if inst and inst.Parent then
                    for p, v in pairs(props) do
                        pcall(function() inst[p] = v end)
                    end
                end
            end
            table.clear(Optimizer._brkSaved)
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
        for _, c in ipairs(Optimizer._petConns) do pcall(function() c:Disconnect() end) end
        table.clear(Optimizer._petConns)

        local PlayerPet = Net.Mod.PlayerPet
        local function applyPetVis(petObj, visible)
            pcall(function()
                if petObj and petObj.cpet and petObj.cpet.SetVisible then
                    petObj.cpet:SetVisible(visible)
                end
            end)
        end

        if PlayerPet and PlayerPet.GetByPlayer then
            for _, plr in ipairs(ctx.Roblox.Players:GetPlayers()) do
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
        for _, c in ipairs(Optimizer._gameConns) do pcall(function() c:Disconnect() end) end
        table.clear(Optimizer._gameConns)

        if not target then
            for inst, props in pairs(Optimizer._gameSaved) do
                if inst and inst.Parent then
                    for p, v in pairs(props) do
                        pcall(function() inst[p] = v end)
                    end
                end
            end
            table.clear(Optimizer._gameSaved)
            return
        end

        local function gSave(inst, prop, val)
            if not inst then return end
            local r = Optimizer._gameSaved[inst]
            if not r then
                r = {}
                Optimizer._gameSaved[inst] = r
            end
            if r[prop] == nil then
                local ok, old = pcall(function() return inst[prop] end)
                if ok then r[prop] = old else return end
            end
            pcall(function() inst[prop] = val end)
        end

        gSave(Lighting, "GlobalShadows", false)
        gSave(Lighting, "FogEnd", 1e9)
        for _, eff in ipairs(Lighting:GetChildren()) do
            if eff:IsA("PostEffect") or eff:IsA("Atmosphere") then
                gSave(eff, "Enabled", false)
            end
        end

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            gSave(terrain, "WaterWaveSize", 0)
            gSave(terrain, "WaterReflectance", 0)
            gSave(terrain, "WaterTransparency", 0)
            gSave(terrain, "Decoration", false)
        end

        local debris = workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, ch in ipairs(debris:GetChildren()) do
                if ch:IsA("ParticleEmitter") or ch:IsA("BasePart") then
                    pcall(function() ch:Destroy() end)
                end
            end
            table.insert(Optimizer._gameConns, Lifecycle.TrackConnection(debris.ChildAdded:Connect(function(ch)
                if ctx.States.Optimization.OptimizeGame then
                    task.defer(function()
                        if ch.Parent and (ch:IsA("ParticleEmitter") or ch.Name:find("Orb") == nil) then
                            if ch.Name:find("Flash") or ch.Name:find("Confetti") or ch:IsA("ParticleEmitter") then
                                pcall(function() ch:Destroy() end)
                            end
                        end
                    end)
                end
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
    end

    function PumpkinOptimizer.Start()
        Lifecycle.SpawnLoop("PumpkinOptimizerSweep", 2.0, function()
            if Optimizer.Enabled then
                cleanFlashContainers()
            end
        end)
        Lifecycle.RegisterCleanup(function()
            Optimizer.SetEnabled(false)
            Optimizer.SetDisableBreakablesModel(false)
            Optimizer.SetDisablePetsRendering(false)
            Optimizer.SetDisableConfettiRendering(false)
            Optimizer.SetOptimizeGame(false)
        end)
    end

    ctx.Optimizer = Optimizer
    ctx.API.setOptimizePumpkinTycoon = Optimizer.SetEnabled
    return Optimizer
end

return PumpkinOptimizer
