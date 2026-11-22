-- src/Systems/Eggs/EggAndPetSystem.lua
-- Egg Tab Backend:
--   - Auto Buy Egg (Best / Nearest / Selected World Egg + BreakableZone edge positioning)
--   - Disable Egg Animation (pure client skip inside Egg Opening Frontend so game natively unmasks & completes)
--   - Auto Make Pets (Gold & Rainbow Machines)
--   - Auto Fuse Pets
--   - Auto Charm Pets

local EggAndPetSystem = {}

function EggAndPetSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States

    local EggSys = {
        _lastEggAt = 0,
        _lastMachineAt = 0,
        _lastCharmAt = 0,
        _animDisabled = false,
        _origAnimFns = nil,
        _disabledConns = {},
        _ourAnimConn = nil,
    }

    local function findNearestWorldEggInstance()
        local M = Net.Mod
        local things = workspace:FindFirstChild("__THINGS")
        local eggsFolder = things and things:FindFirstChild("Eggs")
        if not eggsFolder then return nil end

        local dirEggs = M.Directory and M.Directory.Eggs
        local save = Net.GetSave()
        local maxEggNum = (save and save.MaximumAvailableEgg) or 9999

        local bestScore = -1
        local nearestDist = math.huge
        local chosen = nil
        local _, hrp = Utils.getCharacterParts()
        local mode = States.Egg.TargetEggMode or "Best Unlocked"

        for _, eggFolder in ipairs(eggsFolder:GetChildren()) do
            for _, model in ipairs(eggFolder:GetChildren()) do
                local eggName = model.Name
                local dir = dirEggs and dirEggs[eggName]
                local eggNum = (dir and dir.eggNumber) or 0
                local pos = Utils.getInstancePos(model)
                if pos and eggNum <= maxEggNum then
                    if mode == "Selected" and eggName == States.Egg.SelectedEggName then
                        return { name = eggName, model = model, pos = pos, dir = dir, num = eggNum }
                    elseif mode == "Best Unlocked" and eggNum > bestScore then
                        bestScore = eggNum
                        chosen = { name = eggName, model = model, pos = pos, dir = dir, num = eggNum }
                    elseif mode == "Nearest Unlocked" and hrp then
                        local d = Utils.dist3D(hrp.Position, pos)
                        if d < nearestDist then
                            nearestDist = d
                            chosen = { name = eggName, model = model, pos = pos, dir = dir, num = eggNum }
                        end
                    end
                end
            end
        end
        return chosen
    end

    local function stepAutoBuyWorldEgg()
        if not States.Egg.AutoBuyEgg then return end
        if os.clock() - EggSys._lastEggAt < 0.35 then return end

        local M = Net.Mod
        if not M.EggCmds or not M.CalcEggPricePlayer then return end
        local inst = M.InstancingCmds and M.InstancingCmds.IsInInstance and M.InstancingCmds.IsInInstance()
        if inst then return end

        local target = findNearestWorldEggInstance()
        if not target or not target.pos then return end

        -- Golden / Charged sync
        local save = Net.GetSave()
        if save and save.HatchSettings then
            if States.Egg.GoldenHatch ~= (save.HatchSettings.Golden == true) then
                Net.NetworkInvoke("GoldenHatch_Toggle")
            end
            if States.Egg.ChargedHatch ~= (save.HatchSettings.Charged == true) then
                Net.NetworkInvoke("ChargedHatch_Toggle")
            end
        end

        -- Position INSIDE current zone's BreakableZone on the edge closest to the Egg when possible!
        local _, hrp = Utils.getCharacterParts()
        local standPos = target.pos + Vector3.new(0, 0, 5)
        local arrivalRadius = 10
        local maxRange = 28

        if States.Egg.StayInBreakableZone and M.MapCmds and M.ZonesUtil and M.ZonesUtil.GetBreakableZones then
            local zoneId = M.MapCmds.GetCurrentZone and M.MapCmds.GetCurrentZone()
            local bzFolder = zoneId and M.ZonesUtil.GetBreakableZones(zoneId)
            if bzFolder then
                local zoneParts = {}
                for _, ch in ipairs(bzFolder:GetChildren()) do
                    if ch:IsA("BasePart") then table.insert(zoneParts, ch) end
                end
                local inZoneEggPos, okRange = Utils.computeBreakableZoneStandPos(target.pos, zoneParts, maxRange, 3.0)
                if inZoneEggPos and okRange then
                    standPos = inZoneEggPos
                    arrivalRadius = 4.0
                end
            end
        end

        if not hrp or Utils.flatDist(hrp.Position, target.pos) > maxRange or Utils.flatDist(hrp.Position, standPos) > arrivalRadius + 2 then
            local okMove = Move.MoveTo(standPos, arrivalRadius, 3.0, function()
                return not States.Egg.AutoBuyEgg
            end)
            if not okMove then return end
        end

        local maxAllowed = (M.EggCmds.GetMaxHatch and M.EggCmds.GetMaxHatch(target.dir or {})) or 1
        local amt = (States.Egg.HatchAmount == "Max") and maxAllowed or math.min(maxAllowed, tonumber(States.Egg.HatchAmount) or 1)
        amt = math.max(1, math.floor(amt))

        EggSys._lastEggAt = os.clock()
        local ok = Net.NetworkInvoke("Eggs_RequestPurchase", target.name, amt)
        if ok then
            ctx.Runtime.Status.Egg = string.format("Hatched %dx %s", amt, target.name)
        end
    end

    local function findEggFrontendScript()
        local lp = ctx.Roblox.LocalPlayer
        local ps = lp and lp:FindFirstChild("PlayerScripts")
        if not ps then return nil end
        local scriptsFolder = ps:FindFirstChild("Scripts")
        local gameFolder = scriptsFolder and scriptsFolder:FindFirstChild("Game")
        return (gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend"))
            or ps:FindFirstChild("Egg Opening Frontend", true)
    end

    local function resolveEggFrontendEnv()
        local Network = Net.Mod.Network
        local sig = Network and Network.Fired and Network.Fired("Eggs_PlayOpenAnimation")
        local getConns = (type(getconnections) == "function") and getconnections or nil
        local getfenvFn = (type(getfenv) == "function") and getfenv or nil

        -- Primary: grab the exact fenv directly from Egg Opening Frontend's Eggs_PlayOpenAnimation handler
        if sig and getConns and getfenvFn then
            local okConns, list = pcall(getConns, sig)
            if okConns and type(list) == "table" then
                for _, conn in ipairs(list) do
                    local fn = conn and conn.Function
                    if type(fn) == "function" then
                        local okEnv, fenv = pcall(getfenvFn, fn)
                        if okEnv and type(fenv) == "table"
                            and (type(fenv.PlayNormalEggAnimation) == "function" or type(fenv.PlayEggAnimation) == "function") then
                            return fenv
                        end
                    end
                end
            end
        end

        -- Secondary: getsenv lookup on PlayerScripts
        local getsenvFn = (type(getsenv) == "function") and getsenv or nil
        local eggScript = getsenvFn and findEggFrontendScript()
        if eggScript and getsenvFn then
            local okEnv, fenv = pcall(getsenvFn, eggScript)
            if okEnv and type(fenv) == "table"
                and (type(fenv.PlayNormalEggAnimation) == "function" or type(fenv.PlayEggAnimation) == "function") then
                return fenv
            end
        end

        return nil
    end

    function EggSys.SetDisableEggAnimation(enable)
        local target = enable == true
        States.Egg.DisableEggAnimation = target
        if target == EggSys._animDisabled then return end
        EggSys._animDisabled = target

        local ui = ctx.Roblox.PlayerGui:FindFirstChild("EggOpenAnimation")
        if ui and ui:IsA("ScreenGui") then
            ui.Enabled = not target
        end

        if target then
            local scriptEnv = resolveEggFrontendEnv()

            -- Pure client-side skip: no-op visual renderers inside Egg Opening Frontend's own env
            -- so PS99's own script natively finishes hatching & unhiding without our script sending remotes.
            if scriptEnv then
                if not EggSys._origAnimFns then
                    EggSys._origAnimFns = {
                        env = scriptEnv,
                        normal = scriptEnv.PlayNormalEggAnimation,
                        egg = scriptEnv.PlayEggAnimation,
                        td = scriptEnv.PlayTowerDefenseAnimations,
                    }
                end
                local noOp = function() end
                if type(scriptEnv.PlayNormalEggAnimation) == "function" then
                    scriptEnv.PlayNormalEggAnimation = noOp
                end
                if type(scriptEnv.PlayEggAnimation) == "function" then
                    scriptEnv.PlayEggAnimation = noOp
                end
                if type(scriptEnv.PlayTowerDefenseAnimations) == "function" then
                    scriptEnv.PlayTowerDefenseAnimations = noOp
                end
                return
            end

            -- Fallback only if executor provides neither getfenv(conn) nor getsenv
            local Network = Net.Mod.Network
            local sig = Network and Network.Fired and Network.Fired("Eggs_PlayOpenAnimation")
            local getConns = (type(getconnections) == "function") and getconnections or nil
            if sig and getConns then
                for _, conn in ipairs(getConns(sig)) do
                    if conn ~= EggSys._ourAnimConn then
                        pcall(function() conn:Disable() end)
                        table.insert(EggSys._disabledConns, conn)
                    end
                end
            end
            if sig and not EggSys._ourAnimConn then
                local Library = ctx.Roblox.ReplicatedStorage:WaitForChild("Library")
                local okDecomp, Payload = pcall(require, Library.Util.EggAnimPayload)
                local PetItem = Net.Mod.PetItem
                local conn = sig:Connect(function(eggName, compressed)
                    if not States.Egg.DisableEggAnimation then return end
                    local uids = {}
                    if okDecomp and Payload and Payload.Decompress and type(compressed) == "table" and PetItem then
                        local okD, decoded = pcall(Payload.Decompress, compressed)
                        if okD and type(decoded) == "table" then
                            for k, v in pairs(decoded) do
                                table.insert(uids, k)
                                if ctx.Webhook and ctx.Webhook.OnPetHatched then
                                    pcall(function()
                                        local pItem = PetItem:From(v):SetUID(k):Freeze()
                                        ctx.Webhook.OnPetHatched(eggName, pItem)
                                    end)
                                end
                            end
                        end
                    end
                    if #uids > 0 then
                        Net.NetworkFire("Pets_ClearHidden", uids)
                    end
                    Net.SignalFire("CompletedHatching", eggName, uids)
                end)
                EggSys._ourAnimConn = Lifecycle.TrackConnection(conn)
            end
        else
            if EggSys._origAnimFns and type(EggSys._origAnimFns.env) == "table" then
                local orig = EggSys._origAnimFns
                if orig.normal then orig.env.PlayNormalEggAnimation = orig.normal end
                if orig.egg then orig.env.PlayEggAnimation = orig.egg end
                if orig.td then orig.env.PlayTowerDefenseAnimations = orig.td end
                EggSys._origAnimFns = nil
            end
            for _, conn in ipairs(EggSys._disabledConns) do
                pcall(function() conn:Enable() end)
            end
            table.clear(EggSys._disabledConns)
            if EggSys._ourAnimConn then
                pcall(function() EggSys._ourAnimConn:Disconnect() end)
                EggSys._ourAnimConn = nil
            end
        end
    end

    local function stepMachinesAndCharms()
        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container or not M.PetItem then return end

        local container = M.InventoryCmds.Container()
        if not container then return end

        -- Gold / Rainbow / Fuse Machines
        if os.clock() - EggSys._lastMachineAt >= 2.0 and (States.Egg.AutoMakeGold or States.Egg.AutoMakeRainbow or States.Egg.AutoFusePets) then
            EggSys._lastMachineAt = os.clock()

            if States.Egg.AutoMakeGold and Net.GetFFlag("GoldMachine", true) == true then
                for uid, item in pairs(container:All() or {}) do
                    if item.IsA and item:IsA("Pet") and item.CanBeGolden and item:CanBeGolden() and item.CanGoldMachine and item:CanGoldMachine() then
                        if not (item.IsLocked and item:IsLocked()) and not (item.IsHuge and item:IsHuge()) then
                            local amt = item:GetAmount()
                            local needed = 10
                            local craftCount = math.floor(amt / needed)
                            if craftCount >= 1 then
                                local ok = Net.NetworkInvoke("GoldMachine_Activate", uid, craftCount)
                                if ok then
                                    ctx.Runtime.Status.Egg = string.format("Crafted %dx Gold %s", craftCount, tostring(item:GetId()))
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if States.Egg.AutoMakeRainbow and Net.GetFFlag("RainbowMachine", true) == true then
                for uid, item in pairs(container:All() or {}) do
                    if item.IsA and item:IsA("Pet") and item.CanBeRainbow and item:CanBeRainbow() and item.CanRainbowMachine and item:CanRainbowMachine() then
                        if not (item.IsLocked and item:IsLocked()) and not (item.IsHuge and item:IsHuge()) then
                            local amt = item:GetAmount()
                            local craftCount = math.floor(amt / 10)
                            if craftCount >= 1 then
                                local ok = Net.NetworkInvoke("RainbowMachine_Activate", uid, craftCount)
                                if ok then
                                    ctx.Runtime.Status.Egg = string.format("Crafted %dx Rainbow %s", craftCount, tostring(item:GetId()))
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if States.Egg.AutoFusePets then
                local fuseReq = math.max(3, tonumber(States.Egg.FuseMinCount) or 12)
                for uid, item in pairs(container:All() or {}) do
                    if item.IsA and item:IsA("Pet") and not (item.IsLocked and item:IsLocked()) and not (item.IsHuge and item:IsHuge()) then
                        local amt = item:GetAmount()
                        if amt >= fuseReq then
                            local batch = math.min(amt, 100)
                            local ok = Net.NetworkInvoke("FuseMachine_Activate", { [uid] = batch })
                            if ok then
                                ctx.Runtime.Status.Egg = string.format("Fused %dx %s", batch, tostring(item:GetId()))
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Auto Charm Pets
        if States.Egg.AutoCharmPets and os.clock() - EggSys._lastCharmAt >= 3.0 and Net.GetFFlag("AttachCharms", true) == true then
            EggSys._lastCharmAt = os.clock()
            local charmlessPets = {}
            local charms = {}
            local prefSet = Utils.arrayToSet(States.Egg.PreferredCharms)

            for uid, item in pairs(container:All() or {}) do
                if item.IsA then
                    if item:IsA("Pet") and item.GetCharmSlots and item.GetCharms then
                        local slots = item:GetCharmSlots() or 0
                        local attached = item:GetCharms() or {}
                        if slots > 0 and #attached < slots then
                            table.insert(charmlessPets, uid)
                        end
                    elseif item:IsA("Charm") and (item:GetAmount() or 0) > 0 then
                        local id = item:GetId()
                        if prefSet[id] or next(prefSet) == nil then
                            table.insert(charms, { uid = uid, id = id })
                        end
                    end
                end
            end

            if #charmlessPets > 0 and #charms > 0 then
                local targetCharm = charms[1]
                local targetPet = charmlessPets[1]
                local ok = Net.NetworkInvoke("Charms_AttachToPet", targetCharm.uid, { targetPet })
                if ok then
                    ctx.Runtime.Status.Egg = "Attached " .. tostring(targetCharm.id) .. " Charm!"
                end
            end
        end
    end

    function EggAndPetSystem.Start()
        EggSys.SetDisableEggAnimation(States.Egg.DisableEggAnimation == true)

        Lifecycle.SpawnLoop("EggAndPetWorker", 0.35, function()
            stepAutoBuyWorldEgg()
            stepMachinesAndCharms()
        end)

        Lifecycle.RegisterCleanup(function()
            EggSys.SetDisableEggAnimation(false)
        end)
    end

    ctx.EggAndPetSystem = EggSys
    return EggSys
end

return EggAndPetSystem
