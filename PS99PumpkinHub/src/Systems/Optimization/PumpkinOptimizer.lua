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

        if not target then
            Optimizer.RestoreAll()
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

    function PumpkinOptimizer.Start()
        Lifecycle.SpawnLoop("PumpkinOptimizerSweep", 2.0, function()
            if Optimizer.Enabled then
                cleanFlashContainers()
            end
        end)
        Lifecycle.RegisterCleanup(function()
            Optimizer.SetEnabled(false)
        end)
    end

    ctx.Optimizer = Optimizer
    ctx.API.setOptimizePumpkinTycoon = Optimizer.SetEnabled
    return Optimizer
end

return PumpkinOptimizer
