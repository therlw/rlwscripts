-- src/Systems/Pets/MachineEvolution.lua
-- Auto Pet Evolution (Golden & Diamond Machines) + Popup Dismissal

local MachineEvolution = {}

function MachineEvolution.Init(ctx)
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local PlayerGui = ctx.Roblox.PlayerGui
    local KaitunState = ctx.States.Kaitun

    local getPlayerData = ctx.API.getPlayerData
    local discoverMachinePads = ctx.API.discoverMachinePads
    local equipBestPets = ctx.API.equipBestPets

    local function dismissMachinePopups()
        if not (KaitunState and KaitunState.SuppressMachineUI) then return end
        pcall(function()
            if Mod.MachineController and type(Mod.MachineController.ContinueRoll) == "function" then
                Mod.MachineController:ContinueRoll()
            end
        end)
        pcall(function()
            if Mod.MenuController and type(Mod.MenuController.Close) == "function" then
                Mod.MenuController:Close("CraftingRoll")
                Mod.MenuController:Close("Golden")
                Mod.MenuController:Close("Diamond")
                Mod.MenuController:Close("Shiny")
                Mod.MenuController:Close("RainbowFuse")
            end
        end)
        pcall(function()
            local tabs = PlayerGui:FindFirstChild("Tabs")
            if tabs then
                for _, name in ipairs({ "CraftingRoll", "Golden", "Diamond", "Shiny", "RainbowFuse" }) do
                    local g = tabs:FindFirstChild(name)
                    if g and g:IsA("ScreenGui") and g.Enabled then
                        g.Enabled = false
                        local cont = g:FindFirstChild("Menu") and g.Menu:FindFirstChild("Continue")
                        local btn = cont and cont:FindFirstChildWhichIsA("TextButton", true)
                        if btn then
                            for _, c in ipairs(getconnections(btn.Activated or btn.MouseButton1Click)) do
                                c:Fire()
                            end
                        end
                    end
                end
            end
        end)
    end

    local function teleportAndVerifyAtPad(targetPos)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        for _ = 1, 3 do
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.4)
            dismissMachinePopups()
            if (hrp.Position - targetPos).Magnitude <= 10 then
                task.wait(0.95)
                dismissMachinePopups()
                if (hrp.Position - targetPos).Magnitude <= 10 then
                    return true
                end
            end
        end
        return false
    end

    local function performConfirmedCraft(machineType, petBatch)
        if not (Svc.MachineService and Svc.MachineService:FindFirstChild("RE") and Svc.MachineService.RE:FindFirstChild("MachineCraftRequested")) then
            return false
        end

        local craftDone = false
        local craftSuccess = false
        local conn = nil

        if Svc.MachineService.RE:FindFirstChild("MachineCraftResult") then
            conn = Svc.MachineService.RE.MachineCraftResult.OnClientEvent:Connect(function(res)
                if type(res) == "table" and res.Machine == machineType then
                    craftDone = true
                    craftSuccess = (res.Success == true)
                end
            end)
        end

        Svc.MachineService.RE.MachineCraftRequested:FireServer({
            Action = "Craft",
            Machine = machineType,
            PetIds = petBatch
        })

        local start = os.clock()
        while not craftDone and (os.clock() - start < CONFIG.CraftTimeout) do
            task.wait(0.05)
        end

        if conn then conn:Disconnect() end
        dismissMachinePopups()
        task.wait(CONFIG.CraftCooldown)
        dismissMachinePopups()

        return craftSuccess
    end

    local function autoCraftEvolutionPets(targetBestIsl)
        local data = getPlayerData()
        if not (data and data.Pets and data.Pets.Owned) then return 0, 0 end
        if not Svc.MachineService or not Svc.MachineService:FindFirstChild("RE") or not Svc.MachineService.RE:FindFirstChild("MachineCraftRequested") then
            return 0, 0
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return 0, 0 end

        local getBestUnlockedIsland = ctx.API.getBestUnlockedIsland
        local travelToIsland = ctx.API.travelToIsland
        local safeNotify = ctx.UI.safeNotify

        local curWorld = data.Progression and data.Progression.World or "Main"
        local curIsland = data.Progression and data.Progression.Island or "Spawn"
        local bestUnlockedIsl = targetBestIsl or (getBestUnlockedIsland and getBestUnlockedIsland()) or curIsland
        local isWorld2 = (curWorld == "TimeRift")

        if not isWorld2 then
            local unlockedIslands = data.Progression and data.Progression.UnlockedIslands or {}
            if not (unlockedIslands["Crystal Cave"] == true or curIsland == "Crystal Cave") then
                return 0, 0
            end
        end

        local CraftLockMod = Mod.CraftLock or (ctx.Utils.requireSafe and ctx.Utils.requireSafe(function() return ctx.Roblox.ReplicatedStorage.Shared.Pets.CraftLock end))
        local CraftAllPlanMod = Mod.CraftAllPlan or (ctx.Utils.requireSafe and ctx.Utils.requireSafe(function() return ctx.Roblox.ReplicatedStorage.Shared.Pets.CraftAllPlan end))

        local owned = data.Pets.Owned or {}
        local equipped = data.Pets.Equipped or {}
        local keptSet = {}
        for _, id in ipairs(equipped) do keptSet[id] = true end
        if CraftAllPlanMod and type(CraftAllPlanMod.Kept) == "function" then
            local okKept, kept = pcall(CraftAllPlanMod.Kept, data)
            if okKept and type(kept) == "table" then
                for id, isKept in pairs(kept) do
                    if isKept then keptSet[id] = true end
                end
            end
        end
        if type(data.PetTeams) == "table" then
            for _, team in pairs(data.PetTeams) do
                if type(team) == "table" then
                    local members = team.Pets or team.Ids or team
                    if type(members) == "table" then
                        for _, id in pairs(members) do
                            if type(id) == "string" then keptSet[id] = true end
                        end
                    end
                end
            end
        end
        local okAttr, heldId = pcall(function() return LocalPlayer:GetAttribute("EnchantHeldPet") end)
        if okAttr and heldId then keptSet[heldId] = true end

        local function isCraftCandidate(id, p, targetTier)
            if not p or p.Locked or p.Frozen or keptSet[id] then return false end
            if p.Equip or p.Signature or p.LeaderboardSerial then return false end
            if (p.Enchant and p.Enchant ~= "") or (p.Enchant2 and p.Enchant2 ~= "") then return false end
            if p.Mutation and p.Mutation ~= "" then return false end
            if p.Glitched == true or p.Tier == "Glitched" or p.Tier == "Rainbow" or p.Tier == "Shiny" then return false end
            local rarityStr = tostring(p.Rarity or "")
            if string.match(rarityStr, "^Secret") or rarityStr == "Limited" then return false end
            if CraftLockMod and type(CraftLockMod.IsLocked) == "function" then
                local okLock, locked = pcall(CraftLockMod.IsLocked, p)
                if okLock and locked then return false end
            end
            if targetTier == "Normal" then
                return (p.Tier == "Normal" or not p.Tier)
            end
            return p.Tier == targetTier
        end

        local normalSpecies = {}
        for id, p in pairs(owned) do
            if isCraftCandidate(id, p, "Normal") then
                normalSpecies[p.Name] = normalSpecies[p.Name] or {}
                table.insert(normalSpecies[p.Name], id)
            end
        end

        local goldenPlans = {}
        for name, ids in pairs(normalSpecies) do
            if #ids >= CONFIG.GoldenCraftCount then
                table.insert(goldenPlans, { name = name, batches = math.floor(#ids / CONFIG.GoldenCraftCount), ids = ids })
            end
        end

        local goldenSpecies = {}
        for id, p in pairs(owned) do
            if isCraftCandidate(id, p, "Golden") then
                goldenSpecies[p.Name] = goldenSpecies[p.Name] or {}
                table.insert(goldenSpecies[p.Name], id)
            end
        end

        local diamondPlans = {}
        for name, ids in pairs(goldenSpecies) do
            if #ids >= CONFIG.DiamondCraftCount then
                table.insert(diamondPlans, { name = name, batches = math.floor(#ids / CONFIG.DiamondCraftCount), ids = ids })
            end
        end

        if #goldenPlans == 0 and #diamondPlans == 0 then
            return 0, 0
        end

        local oldCF = hrp.CFrame
        local goldenCraftedCount = 0
        local diamondCraftedCount = 0

        -- Craft Golden pets
        if #goldenPlans > 0 then
            local padPos = nil
            local dynGolden = discoverMachinePads("GoldenMachine", isWorld2)
            if isWorld2 then
                local bestDyn, bestDist = nil, math.huge
                for _, entry in ipairs(dynGolden) do
                    if entry.inWorld2 then
                        local d = (entry.pos - hrp.Position).Magnitude
                        if curIsland == "Medieval Island" and entry.pos.X > 2000 then
                            bestDyn = entry.pos
                            break
                        elseif d < bestDist then
                            bestDist = d
                            bestDyn = entry.pos
                        end
                    end
                end
                if bestDyn then
                    padPos = bestDyn
                elseif curIsland == "Ice Age" or bestUnlockedIsl == "Ice Age" or curIsland == "Medieval Island" or bestUnlockedIsl == "Medieval Island" then
                    padPos = Vector3.new(1478.8, 1355.6, 6995.4)
                elseif curIsland == "Prehistoric Island" or bestUnlockedIsl == "Prehistoric Island" then
                    padPos = Vector3.new(1071.5, 887.2, 7000.2)
                else
                    padPos = Vector3.new(74.9, 497.0, 7087.8)
                end
            else
                padPos = (dynGolden[1] and not dynGolden[1].inWorld2 and dynGolden[1].pos) or Vector3.new(-146.5, 5446.5, -2044.9)
                if curIsland ~= "Crystal Cave" and travelToIsland then
                    travelToIsland("Crystal Cave")
                    task.wait(0.6)
                end
            end
            local arrived = teleportAndVerifyAtPad(padPos)
            if arrived then
                for _, plan in ipairs(goldenPlans) do
                    for b = 1, plan.batches do
                        local batch = {}
                        for i = (b - 1) * CONFIG.GoldenCraftCount + 1, b * CONFIG.GoldenCraftCount do
                            table.insert(batch, plan.ids[i])
                        end
                        local ok = performConfirmedCraft("Golden", batch)
                        if ok then
                            goldenCraftedCount = goldenCraftedCount + 1
                        end
                    end
                end
            end
        end

        -- Re-scan Golden pets after crafting
        data = getPlayerData()
        owned = data and data.Pets and data.Pets.Owned or {}
        goldenSpecies = {}
        for id, p in pairs(owned) do
            if isCraftCandidate(id, p, "Golden") then
                goldenSpecies[p.Name] = goldenSpecies[p.Name] or {}
                table.insert(goldenSpecies[p.Name], id)
            end
        end

        diamondPlans = {}
        for name, ids in pairs(goldenSpecies) do
            if #ids >= CONFIG.DiamondCraftCount then
                table.insert(diamondPlans, { name = name, batches = math.floor(#ids / CONFIG.DiamondCraftCount), ids = ids })
            end
        end

        -- Craft Diamond pets
        if #diamondPlans > 0 then
            local padPos = nil
            local dynDiamond = discoverMachinePads("DiamondMachine", isWorld2)
            if isWorld2 then
                local useMedieval = (curIsland == "Medieval Island" or bestUnlockedIsl == "Medieval Island")
                local bestDyn, bestDist = nil, math.huge
                for _, entry in ipairs(dynDiamond) do
                    if entry.inWorld2 then
                        if useMedieval and entry.pos.X > 2000 then
                            bestDyn = entry.pos
                            break
                        elseif (entry.pos - hrp.Position).Magnitude < bestDist then
                            bestDist = (entry.pos - hrp.Position).Magnitude
                            bestDyn = entry.pos
                        end
                    end
                end
                if bestDyn then
                    padPos = bestDyn
                elseif useMedieval then
                    padPos = Vector3.new(2603.5, 1939.7, 7056.9)
                else
                    padPos = Vector3.new(1487.9, 1375.4, 6773.0)
                    if curIsland ~= "Ice Age" and (bestUnlockedIsl == "Ice Age" or curIsland ~= "Spawn") and travelToIsland then
                        travelToIsland("Ice Age")
                        task.wait(0.6)
                    end
                end
            else
                padPos = (dynDiamond[1] and not dynDiamond[1].inWorld2 and dynDiamond[1].pos) or Vector3.new(-186.6, 5446.5, -2002.3)
                if curIsland ~= "Crystal Cave" and travelToIsland then
                    travelToIsland("Crystal Cave")
                    task.wait(0.6)
                end
            end
            local arrived = teleportAndVerifyAtPad(padPos)
            if arrived then
                for _, plan in ipairs(diamondPlans) do
                    for b = 1, plan.batches do
                        local batch = {}
                        for i = (b - 1) * CONFIG.DiamondCraftCount + 1, b * CONFIG.DiamondCraftCount do
                            table.insert(batch, plan.ids[i])
                        end
                        local ok = performConfirmedCraft("Diamond", batch)
                        if ok then
                            diamondCraftedCount = diamondCraftedCount + 1
                        end
                    end
                end
            end
        end

        if not isWorld2 and curIsland ~= "Crystal Cave" and travelToIsland then
            travelToIsland(curIsland)
            task.wait(0.5)
        end
        hrp.CFrame = oldCF
        task.wait(0.2)
        dismissMachinePopups()

        equipBestPets()

        if (goldenCraftedCount > 0 or diamondCraftedCount > 0) and safeNotify then
            safeNotify({
                title = "Pet Evolution Complete!",
                content = string.format("Crafted %d Golden (3x Power) & %d Diamond (7x Power) pets!", goldenCraftedCount, diamondCraftedCount),
                duration = 5
            })
        end

        return goldenCraftedCount, diamondCraftedCount
    end

    ctx.API.dismissMachinePopups = dismissMachinePopups
    ctx.API.teleportAndVerifyAtPad = teleportAndVerifyAtPad
    ctx.API.performConfirmedCraft = performConfirmedCraft
    ctx.API.autoCraftEvolutionPets = autoCraftEvolutionPets

    MachineEvolution.dismissMachinePopups = dismissMachinePopups
    MachineEvolution.teleportAndVerifyAtPad = teleportAndVerifyAtPad
    MachineEvolution.performConfirmedCraft = performConfirmedCraft
    MachineEvolution.autoCraftEvolutionPets = autoCraftEvolutionPets
    return MachineEvolution
end

return MachineEvolution
