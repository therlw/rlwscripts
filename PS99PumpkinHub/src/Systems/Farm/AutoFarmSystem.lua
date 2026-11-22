-- src/Systems/Farm/AutoFarmSystem.lua
-- Auto Farm Tab Backend:
--   - Infinite Pet Speed (cpet PetSpeedMult broadcast + clean restore)
--   - Auto Efficient Farm (Fast Farm: native AutoFarmCmds + smart 1-pet-per-breakable distribution)
--   - Auto Collect Orbs (Orbs: Collect on live __THINGS.Orbs & Lootbags)
--   - Auto Use Ultimate (Ultimates: Activate when charged)
--   - Auto Teleport To Best Area & Auto Buy Next Area
--   - Auto Complete Gate Quest & Auto Area Quest (No Auto Rank Quests)
--   - Auto Rebirth & Auto Teleport to Best World
--   - Auto Use All Misc Items / Breakable Sprinkler / TNT-TNT Crate
--   - Auto Buy Pet Equip Slots & Auto Buy Egg Bundle Slots

local AutoFarmSystem = {}

function AutoFarmSystem.Init(ctx)
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States

    local FarmSys = {
        _lastSpeedSyncAt = 0,
        _wasSpeedModified = false,
        _lastFastFarmAt = 0,
        _lastAfResetAt = 0,
        _lastZoneSig = nil,
        _lastOrbAt = 0,
        _lastUltAt = 0,
        _lastAreaAt = 0,
        _lastWorldAt = 0,
        _lastRebirthAt = 0,
        _lastMiscAt = 0,
        _lastSlotBuyAt = 0,
    }

    local function syncPetSpeed()
        local PlayerPet = Net.Mod.PlayerPet
        if not PlayerPet or not PlayerPet.GetByPlayer then return end
        local enabled = States.Farm.InfinitePetSpeed == true
        local mult = math.clamp(tonumber(States.Farm.PetSpeedMult) or 25, 2, 100)

        if not enabled then
            if FarmSys._wasSpeedModified then
                FarmSys._wasSpeedModified = false
                for _, pet in pairs(PlayerPet.GetByPlayer(LocalPlayer) or {}) do
                    pcall(function()
                        local native = pet.CalculateSpeedMultiplier and pet:CalculateSpeedMultiplier() or 1
                        pet.speedMult = native
                        if pet.cpet and pet.cpet.Broadcast then
                            pet.cpet:Broadcast("petSpeedMult", native)
                        end
                    end)
                end
            end
            return
        end

        FarmSys._wasSpeedModified = true
        for _, pet in pairs(PlayerPet.GetByPlayer(LocalPlayer) or {}) do
            pcall(function()
                if pet.speedMult ~= mult then
                    pet.speedMult = mult
                    if pet.cpet and pet.cpet.Broadcast then
                        pet.cpet:Broadcast("petSpeedMult", mult)
                    end
                end
            end)
        end
    end

    local function isPointNearZonePart(part, pos, margin)
        if not part or not part:IsA("BasePart") or not pos then return false end
        local okRel, rel = pcall(function() return part.CFrame:PointToObjectSpace(pos) end)
        if not okRel or not rel then return false end
        local m = margin or 0
        return math.abs(rel.X) <= (part.Size.X * 0.5) + m
            and math.abs(rel.Z) <= (part.Size.Z * 0.5) + m
            and math.abs(rel.Y) <= math.max(28, (part.Size.Y * 0.5) + 18)
    end

    local function getActiveBreakZonePart(inInst, parentId, hrpPos)
        local M = Net.Mod
        if inInst then
            local parts = Net.GetPumpkinBreakZoneParts and Net.GetPumpkinBreakZoneParts() or {}
            local nearest, nearestDist = nil, math.huge
            for _, zp in ipairs(parts) do
                if hrpPos and ((M.AutoFarmReach and M.AutoFarmReach.OnZone and M.AutoFarmReach.OnZone(zp, hrpPos))
                    or Utils.isPointInZonePart(zp, hrpPos)) then
                    return zp
                end
                if hrpPos then
                    local d = Utils.flatDist(hrpPos, zp.Position)
                    if d < nearestDist then
                        nearestDist = d
                        nearest = zp
                    end
                end
            end
            if nearest and nearestDist <= 115 then
                return nearest
            end
            return nil
        end

        if parentId and M.ZonesUtil and M.ZonesUtil.GetBreakableZones then
            local okBz, bzFolder = pcall(M.ZonesUtil.GetBreakableZones, parentId)
            if okBz and bzFolder then
                local fallback = nil
                for _, zp in ipairs(bzFolder:GetChildren()) do
                    if zp:IsA("BasePart") then
                        fallback = fallback or zp
                        if hrpPos and Utils.isPointInZonePart(zp, hrpPos) then
                            return zp
                        end
                    end
                end
                return fallback
            end
        end
        return nil
    end

    local function stepEfficientFarm()
        if not States.Farm.AutoEfficientFarm then return end
        if os.clock() - FarmSys._lastFastFarmAt < 0.35 then return end
        FarmSys._lastFastFarmAt = os.clock()

        local M = Net.Mod
        if not M.BreakableFrontend or not M.PlayerPet then return end

        local _, hrp = Utils.getCharacterParts()
        local hrpPos = hrp and hrp.Position
        local inInst = M.InstancingCmds and M.InstancingCmds.IsInInstance and M.InstancingCmds.IsInInstance()
        local parentId = inInst and M.InstancingCmds.GetInstanceID() or (M.MapCmds and M.MapCmds.GetCurrentZone())
        local inDotted = M.MapCmds and M.MapCmds.IsInDottedBox and M.MapCmds.IsInDottedBox() == true
        local activeZonePart = getActiveBreakZonePart(inInst, parentId, hrpPos)

        -- Refresh native AutoFarmCmds whenever player switches zone/world/instance/section
        if M.AutoFarmCmds and M.AutoFarmCmds.Enable and M.AutoFarmCmds.IsEnabled then
            pcall(function()
                local afEnabled = M.AutoFarmCmds.IsEnabled()
                local insideZone = inDotted or (activeZonePart ~= nil and hrpPos ~= nil and isPointNearZonePart(activeZonePart, hrpPos, 2))
                if afEnabled then
                    local afParent = M.AutoFarmCmds.GetTargetParentId and M.AutoFarmCmds.GetTargetParentId()
                    local afZone = M.AutoFarmCmds.GetWholeFarmZone and M.AutoFarmCmds.GetWholeFarmZone()
                    local afStart = M.AutoFarmCmds.GetStartingPosition and M.AutoFarmCmds.GetStartingPosition()

                    local parentMismatch = (parentId ~= nil and afParent ~= nil and afParent ~= parentId)
                    local zoneMismatch = (activeZonePart ~= nil and afZone ~= nil and afZone ~= activeZonePart)
                    local distMismatch = (hrpPos ~= nil and afStart ~= nil and insideZone and Utils.flatDist(hrpPos, afStart) > 95)

                    if (parentMismatch or zoneMismatch or distMismatch) and os.clock() - FarmSys._lastAfResetAt >= 1.2 then
                        FarmSys._lastAfResetAt = os.clock()
                        if M.AutoFarmCmds.Disable then
                            M.AutoFarmCmds.Disable()
                        end
                        if (M.MapCmds and M.MapCmds.IsInDottedBox and M.MapCmds.IsInDottedBox()) or insideZone then
                            M.AutoFarmCmds.Enable()
                        end
                    end
                elseif insideZone and os.clock() - FarmSys._lastAfResetAt >= 0.8 then
                    FarmSys._lastAfResetAt = os.clock()
                    M.AutoFarmCmds.Enable()
                end
            end)
        end

        local zoneSig = tostring(parentId) .. "|" .. (activeZonePart and activeZonePart:GetFullName() or "none")
        local zoneChanged = (FarmSys._lastZoneSig ~= nil and FarmSys._lastZoneSig ~= zoneSig)
        FarmSys._lastZoneSig = zoneSig

        local plotCF, plotSize = nil, nil
        if inInst then
            local plotModel = Net.GetPlotModel and Net.GetPlotModel()
            if plotModel then
                local okBox, cf, sz = pcall(plotModel.GetBoundingBox, plotModel)
                if okBox then
                    plotCF, plotSize = cf, sz
                end
            end
        end

        local candidates = {}
        local candidateSet = {}
        local getter = inInst and M.BreakableFrontend.AllByInstanceAndClass or M.BreakableFrontend.AllByZoneAndClass
        if getter then
            for _, cls in ipairs({ "Chest", "Normal" }) do
                local ok, pool = (inInst and pcall(getter, cls) or pcall(getter, parentId, cls))
                if ok and type(pool) == "table" then
                    for _, brk in pairs(pool) do
                        local model, ca, _, bPos, disabled = Utils.unpackBreakable(brk)
                        if model and model.Parent and not disabled then
                            local manual = model:GetAttribute("ManualDamage") == true
                            local bParentId = model:GetAttribute("ParentID")
                            local parentOk = (not parentId) or (bParentId == nil) or (bParentId == parentId)

                            -- Scope breakables to active section/zone and own island
                            local inActiveArea = true
                            local checkPos = bPos or Utils.getInstancePos(model)
                            if activeZonePart and checkPos then
                                inActiveArea = isPointNearZonePart(activeZonePart, checkPos, 10)
                            elseif inInst and plotCF and plotSize and checkPos and M.PT_Types and M.PT_Types.OnIsland then
                                local okOn, resOn = pcall(M.PT_Types.OnIsland, plotCF, plotSize, checkPos)
                                if okOn then inActiveArea = resOn == true end
                            end

                            -- Skip kept pumpkins inside PumpkinTycoon
                            local keptPumpkin = false
                            if inInst and type(ca) == "table" and type(ca.PumpkinPedestal) == "number" and States.PumpkinTycoon.AutoKeepPumpkins then
                                local below = M.AutoBreak and M.AutoBreak.Below and M.AutoBreak.Below() or 0
                                if below > 0 and type(ca.PumpkinRung) == "number" and ca.PumpkinRung >= below then
                                    keptPumpkin = true
                                end
                            end

                            if parentOk and inActiveArea and not manual and not keptPumpkin then
                                table.insert(candidates, model)
                                candidateSet[model] = true
                            end
                        end
                    end
                end
            end
        end

        local pets = M.PlayerPet.GetByPlayer(LocalPlayer) or {}
        if not next(pets) then return end

        -- If no valid breakables found yet after zone transition, release stale old-zone pet targets
        if #candidates == 0 then
            if zoneChanged then
                for _, pet in pairs(pets) do
                    if pet.AIHold == nil or pet.AIHold == "FastFarm" then
                        local curT = pet.GetTarget and pet:GetTarget()
                        if typeof(curT) == "Instance" and curT ~= LocalPlayer.Character then
                            pcall(function()
                                if pet.SetAnchored then pet:SetAnchored(false) end
                                if pet.SetTarget and LocalPlayer.Character then pet:SetTarget(LocalPlayer.Character) end
                            end)
                        end
                    end
                end
            end
            return
        end

        -- Spread unassigned/retreating/stale-zone pets round-robin across current zone breakables
        local takenModels = {}
        local freePets = {}
        for _, pet in pairs(pets) do
            if pet.AIHold == nil or pet.AIHold == "FastFarm" then
                local curT = pet.GetTarget and pet:GetTarget()
                if typeof(curT) == "Instance" and curT.Parent and curT:GetAttribute("DisableDamage") ~= true and candidateSet[curT] then
                    takenModels[curT] = (takenModels[curT] or 0) + 1
                else
                    table.insert(freePets, pet)
                end
            end
        end

        if #freePets > 0 then
            table.sort(candidates, function(a, b)
                return (takenModels[a] or 0) < (takenModels[b] or 0)
            end)
            local idx = 1
            for _, pet in ipairs(freePets) do
                local mdl = candidates[idx]
                idx = (idx % #candidates) + 1
                pcall(function()
                    if pet.SetAnchored then pet:SetAnchored(false) end
                    if pet.SetTarget then pet:SetTarget(mdl) end
                end)
            end
        end
    end

    local function stepCollectOrbs()
        if not States.Farm.AutoCollectOrbs then return end
        if os.clock() - FarmSys._lastOrbAt < 0.35 then return end
        FarmSys._lastOrbAt = os.clock()

        local things = workspace:FindFirstChild("__THINGS")
        local orbsFolder = things and things:FindFirstChild("Orbs")
        if orbsFolder then
            local ids = {}
            for _, ch in ipairs(orbsFolder:GetChildren()) do
                local idNum = tonumber(ch.Name)
                if idNum then
                    table.insert(ids, idNum)
                    if #ids >= 100 then break end
                end
            end
            if #ids > 0 then
                Net.NetworkFire("Orbs: Collect", ids)
            end
        end

        local lootFolder = things and things:FindFirstChild("Lootbags")
        local _, hrp = Utils.getCharacterParts()
        if lootFolder and hrp then
            for _, lb in ipairs(lootFolder:GetChildren()) do
                local p = Utils.getInstancePos(lb)
                if p and (p - hrp.Position).Magnitude > 6 then
                    pcall(function()
                        if lb:IsA("Model") then
                            lb:PivotTo(hrp.CFrame)
                        elseif lb:IsA("BasePart") then
                            lb.CFrame = hrp.CFrame
                        end
                    end)
                end
            end
        end
    end

    local function stepUseUltimate()
        if not States.Farm.AutoUseUltimate then return end
        if os.clock() - FarmSys._lastUltAt < 1.5 then return end
        FarmSys._lastUltAt = os.clock()

        local Ult = Net.Mod.UltimateCmds
        local save = Net.GetSave()
        if not save then return end
        local ultId = (Ult and Ult.GetEquipped and Ult.GetEquipped()) or save.EquippedUltimateId or save.EquippedUltimate
        if type(ultId) ~= "string" or ultId == "" then return end

        local ready = true
        if Ult and Ult.IsReady then
            local okR, resR = pcall(Ult.IsReady, ultId)
            if okR then ready = resR == true end
        elseif Ult and Ult.GetCharge then
            local okC, chg = pcall(Ult.GetCharge, ultId)
            if okC and type(chg) == "number" then ready = chg >= 1 end
        end

        if ready then
            local ok = Net.NetworkInvoke("Ultimates: Activate", ultId)
            if ok then
                ctx.Runtime.Status.Farm = "Activated Ultimate: " .. ultId
            end
        end
    end

    local function getZonesSortedByNumber()
        local Dir = Net.Mod.Directory and Net.Mod.Directory.Zones
        local ZoneCmds = Net.Mod.ZoneCmds
        if type(Dir) ~= "table" then return {} end
        local list = {}
        for zId, zDir in pairs(Dir) do
            if type(zDir) == "table" and type(zDir.ZoneNumber) == "number" then
                local owns = ZoneCmds and ZoneCmds.Owns and ZoneCmds.Owns(zId)
                table.insert(list, { id = zId, dir = zDir, num = zDir.ZoneNumber, world = zDir.WorldNumber or 1, owns = owns == true })
            end
        end
        table.sort(list, function(a, b) return a.num < b.num end)
        return list
    end

    local function stepAreasAndWorlds()
        if os.clock() - FarmSys._lastAreaAt < 2.2 then return end
        FarmSys._lastAreaAt = os.clock()

        local M = Net.Mod
        local Inst = M.InstancingCmds
        if Inst and Inst.IsInInstance and Inst.IsInInstance() then return end

        local zones = getZonesSortedByNumber()
        if #zones == 0 then return end

        local bestOwned = nil
        local nextUnowned = nil
        for _, z in ipairs(zones) do
            if z.owns then
                bestOwned = z
            elseif not nextUnowned then
                nextUnowned = z
                break
            end
        end

        -- 1. Auto Rebirth
        if States.Farm.AutoRebirth and M.RebirthCmds and M.RebirthCmds.GetNextRebirth and os.clock() - FarmSys._lastRebirthAt > 5.0 then
            local nextReb = M.RebirthCmds.GetNextRebirth()
            if nextReb and bestOwned and bestOwned.num >= (nextReb.ZoneNumberRequired or 9999) then
                FarmSys._lastRebirthAt = os.clock()
                local ok = Net.NetworkInvoke("Rebirth_Request", nextReb._id)
                if ok then
                    ctx.Runtime.Status.Farm = "Completed Rebirth #" .. tostring(nextReb.RebirthNumber)
                    return
                end
            end
        end

        -- 2. Auto Buy Next Area
        if States.Farm.AutoBuyNextArea and nextUnowned then
            local questsDone = (not M.ZoneCmds or not M.ZoneCmds.HasCompletedNextZoneQuests or M.ZoneCmds.HasCompletedNextZoneQuests())
            local canAfford = true
            if M.CurrencyCmds and M.CurrencyCmds.CanAfford and M.Balancing and M.Balancing.CalcGatePrice then
                local okPrice, price = pcall(M.Balancing.CalcGatePrice, nextUnowned.dir)
                if okPrice and type(price) == "number" then
                    canAfford = M.CurrencyCmds.CanAfford(nextUnowned.dir.Currency or "Coins", price) == true
                end
            end
            if questsDone and canAfford then
                local ok = Net.NetworkInvoke("Zones_RequestPurchase", nextUnowned.id)
                if ok then
                    FarmSys._lastAfResetAt = 0
                    ctx.Runtime.Status.Farm = "Bought Area: " .. nextUnowned.id
                    return
                end
            end
        end

        -- 3. Auto Teleport Best World
        if States.Farm.AutoTeleportBestWorld and bestOwned and M.WorldsUtil and os.clock() - FarmSys._lastWorldAt > 5.0 then
            local curWorld = M.MapCmds and M.MapCmds.GetCurrentWorld and M.MapCmds.GetCurrentWorld()
            local curNum = (type(curWorld) == "table" and curWorld.WorldNumber) or tonumber(curWorld) or 1
            if bestOwned.world > curNum then
                FarmSys._lastWorldAt = os.clock()
                FarmSys._lastAfResetAt = 0
                local worldRemote = "World" .. tostring(bestOwned.world) .. "Teleport"
                Net.NetworkInvoke(worldRemote)
                ctx.Runtime.Status.Farm = "Teleporting to World " .. tostring(bestOwned.world)
                return
            end
        end

        -- 4. Auto Teleport Best Area
        if (States.Farm.AutoTeleportBestArea or States.Farm.AutoCompleteGateQuest or States.Farm.AutoAreaQuest) and bestOwned then
            local curZone = M.MapCmds and M.MapCmds.GetCurrentZone and M.MapCmds.GetCurrentZone()
            if curZone ~= bestOwned.id then
                local tpOk = false
                if M.TeleportMapCmds and M.TeleportMapCmds.Teleport then
                    tpOk = pcall(M.TeleportMapCmds.Teleport, bestOwned.id)
                end
                if not tpOk then
                    Net.NetworkInvoke("Teleports_RequestTeleport", bestOwned.id)
                end
                FarmSys._lastAfResetAt = 0
                ctx.Runtime.Status.Farm = "Moved to Best Area: " .. bestOwned.id
            else
                -- Step inside best area's BreakableZone when quest-farming or transitioning via AutoTeleportBestArea + AutoEfficientFarm
                local shouldEnterZone = States.Farm.AutoCompleteGateQuest
                    or States.Farm.AutoAreaQuest
                    or (States.Farm.AutoEfficientFarm and States.Farm.AutoTeleportBestArea)
                if shouldEnterZone and not Move._walking and M.ZonesUtil and M.ZonesUtil.GetBreakableZones then
                    local okBz, bzFolder = pcall(M.ZonesUtil.GetBreakableZones, bestOwned.id)
                    local _, hrp = Utils.getCharacterParts()
                    if okBz and bzFolder and hrp then
                        local bzParts = {}
                        local alreadyInside = false
                        for _, zp in ipairs(bzFolder:GetChildren()) do
                            if zp:IsA("BasePart") then
                                table.insert(bzParts, zp)
                                if Utils.isPointInZonePart(zp, hrp.Position) then
                                    alreadyInside = true
                                    break
                                end
                            end
                        end
                        if not alreadyInside and #bzParts > 0 then
                            local dest = Utils.computeBreakableZoneStandPos(hrp.Position, bzParts, 9999, 4.0) or bzParts[1].Position
                            Move.MoveTo(dest, 6, 3.2)
                        end
                    end
                end
            end
        end
    end

    local function stepMiscAndSlots()
        local M = Net.Mod
        if os.clock() - FarmSys._lastSlotBuyAt >= 4.0 then
            FarmSys._lastSlotBuyAt = os.clock()
            local save = Net.GetSave()
            if save then
                if States.Farm.AutoBuyPetEquipSlots then
                    local nextSlot = (save.PetSlotsPurchased or 0) + 1
                    Net.NetworkInvoke("EquipSlotsMachine_RequestPurchase", nextSlot)
                end
                if States.Farm.AutoBuyEggBundleSlots then
                    local nextEggSlot = (save.EggSlotsPurchased or 0) + 1
                    Net.NetworkInvoke("EggHatchSlotsMachine_RequestPurchase", nextEggSlot)
                end
            end
        end

        if os.clock() - FarmSys._lastMiscAt < 2.2 then return end
        FarmSys._lastMiscAt = os.clock()

        local inDotted = M.MapCmds and M.MapCmds.IsInDottedBox and M.MapCmds.IsInDottedBox()
        local inInst = M.InstancingCmds and M.InstancingCmds.IsInInstance and M.InstancingCmds.IsInInstance()
        if not inDotted or inInst then return end

        if States.Farm.AutoUseSprinkler and M.SprinklerCmds and M.MiscItem then
            local okFind, list = pcall(function() return M.MiscItem("Breakable Sprinkler"):FindAny() end)
            local item = okFind and list and list[1]
            if item then
                pcall(M.SprinklerCmds.Consume, "Breakable Sprinkler", item:GetUID(), 1)
            end
        end

        if States.Farm.AutoUseTNTCrate then
            if Net.GetMiscCount("TNT Crate") > 0 then
                Net.NetworkInvoke("TNT_Crate_Consume")
            elseif Net.GetMiscCount("TNT") > 0 then
                Net.NetworkInvoke("TNT_Consume")
            end
        end

        if States.Farm.AutoUseMiscItems then
            if Net.GetMiscCount("Toy Ball") > 0 then Net.NetworkInvoke("ToyBall_Consume", 1) end
            if Net.GetMiscCount("Toy Bone") > 0 then Net.NetworkInvoke("ToyBone_Consume", 1) end
            if Net.GetMiscCount("Squeaky Toy") > 0 then Net.NetworkInvoke("SqueakyToy_Consume", 1) end
            if Net.GetMiscCount("Rainbow Swirl") > 0 then Net.NetworkInvoke("RainbowSwirl_Use") end
            if Net.GetMiscCount("Mini Pinata") > 0 then Net.NetworkInvoke("MiniPinata_Consume") end
            if Net.GetMiscCount("Mini Lucky Block") > 0 then Net.NetworkInvoke("MiniLuckyBlock_Consume") end
            if Net.GetMiscCount("Party Box") > 0 then Net.NetworkInvoke("PartyBox_Consume") end
        end
    end

    function AutoFarmSystem.Start()
        Lifecycle.SpawnLoop("AutoFarmWorker", 0.35, function()
            syncPetSpeed()
            stepEfficientFarm()
            stepCollectOrbs()
            stepUseUltimate()
            stepAreasAndWorlds()
            stepMiscAndSlots()
        end)

        Lifecycle.RegisterCleanup(function()
            States.Farm.InfinitePetSpeed = false
            syncPetSpeed()
        end)
    end

    ctx.AutoFarmSystem = FarmSys
    return FarmSys
end

return AutoFarmSystem
