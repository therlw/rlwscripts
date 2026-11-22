-- src/Systems/PumpkinTycoon/WildAndTurkey.lua
-- Handles:
--   - Auto Hunt Wild Pets (LF_Pursue)
--   - Auto Catch Wild Pets (RU_Ensnare within ThrowReach + ThrowSeconds)
--   - Auto Buy Pet Nets (GN_Restock + Merchant_RequestPurchase PetNetStore)
--   - Auto Fight Turkey (Cannon / Cross + TurkeyArena reach + Pets + AutoTap coordinate)
--   - Auto Catch Rare Pet Spawns (PV_Glimpse with best net on Huge/Titanic/Gargantuan sighting)

local WildAndTurkey = {}

function WildAndTurkey.Init(ctx)
    local HttpService = ctx.Roblox.HttpService
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States
    local CONFIG = ctx.Config
    local Cooldowns = ctx.Runtime.Cooldowns

    local WT = {
        _wasFightingTurkey = false,
        _lastAutoNetsAttemptAt = 0,
    }

    local TIER_BY_NAME = {
        Any = 0,
        Uncommon = 1,
        Rare = 2,
        Epic = 3,
        Huge = 4,
    }

    local function isVariantEntry(entry)
        return type(entry) == "table" and (entry.G == true or entry.R == true or entry.S == true)
    end

    local function inferEntryTier(entry)
        if type(entry) ~= "table" then return 0 end
        local petId = tostring(entry.P or "")
        if string.find(petId, "^Huge ") or string.find(petId, "^Titanic ") or string.find(petId, "^Gargantuan ") then
            return 4
        end
        local Directory = Net.Mod.Directory
        if Directory and Directory.RoamingPets then
            for _, row in pairs(Directory.RoamingPets) do
                if row.Table == "PumpkinTycoon" and row.PetId == petId then
                    if row.Huge then return 4 end
                    return tonumber(row.Tier) or 0
                end
            end
        end
        return 0
    end

    local function classifyRareTier(petName)
        local n = tostring(petName or "")
        if string.find(n, "^Gargantuan ") or string.find(n, "Gargantuan") then return "Gargantuan" end
        if string.find(n, "^Titanic ") or string.find(n, "Titanic") then return "Titanic" end
        if string.find(n, "^Huge ") or string.find(n, "Huge") then return "Huge" end
        return nil
    end

    function WT.GetActiveRareSighting()
        local M = Net.Mod
        if not M.Turkey or not M.Turkey.TestState then return nil end

        local ok, raw = pcall(M.Turkey.TestState)
        if not ok or type(raw) ~= "string" then return nil end

        local okDec, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if not okDec or type(decoded) ~= "table" then return nil end

        local shown = decoded.shown
        if type(shown) ~= "table" or shown.thrown == true or shown.soldOut == true then
            return nil
        end

        local posTbl = decoded.pos
        local pos = (type(posTbl) == "table" and #posTbl >= 3) and Vector3.new(posTbl[1], posTbl[2], posTbl[3]) or nil
        return {
            id = shown.id,
            slot = shown.slot,
            pet = shown.pet,
            tierName = classifyRareTier(shown.pet) or "Huge",
            pos = pos,
            chance = decoded.chance,
        }
    end

    function WT.TryCatchRareSpawn()
        local PT = States.PumpkinTycoon
        if not PT.AutoCatchRareSpawns or not Net.IsInPumpkinTycoon() then return false end
        if not Net.OwnPlotPart2() or Net.GetFFlag("PumpkinTycoon_Sighting", true) ~= true then return false end

        local sighting = WT.GetActiveRareSighting()
        if not sighting or not sighting.id then return false end

        local allowedTiers = Utils.arrayToSet(PT.CatchRareTiers)
        if next(allowedTiers) ~= nil and not allowedTiers[sighting.tierName] then
            return false
        end

        -- Throws YOUR BEST NET (Ultra Pet Net first, fallback Pet Net)
        local bestNet = Net.GetBestNetName()
        if not bestNet then return false end

        local M = Net.Mod
        local throwCd = (M.Util_Wild and M.Util_Wild.ThrowSeconds and M.Util_Wild.ThrowSeconds()) or CONFIG.ThrowCooldown
        if os.clock() - Cooldowns.LastThrowAt < throwCd + 0.1 then
            return false
        end

        local throwReach = Net.GetNumberFFlag("PumpkinTycoon_ThrowReach", CONFIG.DefaultThrowReach)
        if sighting.pos then
            local sharedPos = Utils.getInstancePos(Net.GetTurkeyIslandFolder())
            local onTurkey = sharedPos ~= nil and Utils.flatDist(sighting.pos, sharedPos) < 420
            if onTurkey and not Move.IsOnTurkeyIsland() then
                Move.CrossToTurkeyIsland()
            elseif not onTurkey and Move.IsOnTurkeyIsland() then
                Move.ReturnToOwnIsland()
            end
            local arrived = Move.MoveTo(sighting.pos, math.max(20, throwReach - 25), 3.0)
            if not arrived then return false end
        end

        Cooldowns.LastThrowAt = os.clock()
        local ok, reason = Net.PlotInvoke(M.PT_Types.NET.CatchSighting, sighting.id, bestNet)
        if ok then
            ctx.Runtime.Telemetry.RareAttempts = ctx.Runtime.Telemetry.RareAttempts + 1
            ctx.Runtime.Status.Event = string.format("Threw %s at %s!", bestNet, tostring(sighting.pet))
            if ctx.UI and ctx.UI.safeNotify and CONFIG.Notifications.RareSpawns then
                ctx.UI.safeNotify({ title = "Rare Pet Sighting", content = string.format("Threw %s at %s", bestNet, tostring(sighting.pet)) })
            end
            return true
        else
            Utils.debugLog("CatchSighting", reason)
        end
        return false
    end

    function WT.GetActiveTurkeyBreakable()
        local M = Net.Mod
        if not M.BreakableFrontend or not M.BreakableFrontend.AllByInstanceAndClass then return nil, nil end
        for _, cls in ipairs({ "Chest", "Normal" }) do
            local ok, tbl = pcall(M.BreakableFrontend.AllByInstanceAndClass, cls)
            if ok and type(tbl) == "table" then
                for uid, brk in pairs(tbl) do
                    local model, ca, _, _, disabled = Utils.unpackBreakable(brk)
                    if type(ca) == "table" and ca.PumpkinTurkey == true and model and model.Parent and not disabled then
                        return uid, model
                    end
                end
            end
        end
        return nil, nil
    end

    function WT.TryFightTurkey()
        local PT = States.PumpkinTycoon
        if not PT.AutoFightTurkey or not Net.IsInPumpkinTycoon() then
            WT._wasFightingTurkey = false
            return false
        end
        if not Net.OwnPlotPart2() or Net.GetFFlag("PumpkinTycoon_Turkey", true) ~= true then return false end

        local uid, turkeyModel = WT.GetActiveTurkeyBreakable()
        if not turkeyModel then
            -- Fallback: if no breakable seen yet while on Turkey island, leave after sightseeing check
            if WT._wasFightingTurkey then
                WT._wasFightingTurkey = false
                if PT.ReturnHomeAfterTurkey and Move.IsOnTurkeyIsland() and not WT.GetActiveRareSighting() then
                    Move.ReturnToOwnIsland()
                    ctx.Runtime.Status.Event = "Turkey defeated — returned home"
                end
            end
            return false
        end

        WT._wasFightingTurkey = true
        if not Move.IsOnTurkeyIsland() then
            if not Move.CrossToTurkeyIsland() then
                return false
            end
        end

        local turkeyPos = Utils.getInstancePos(turkeyModel)
        local turkeyReach = Net.GetNumberFFlag("PumpkinTycoon_TurkeyReach", CONFIG.DefaultTurkeyReach)
        local autoTapReach = Net.GetNumberFFlag("PumpkinTycoon_AutoTapReach", CONFIG.DefaultAutoTapReach)
        local standDist = math.min(math.max(15, turkeyReach - 25), math.max(15, autoTapReach - 8))

        if turkeyPos then
            local _, hrp = Utils.getCharacterParts()
            if not hrp or Utils.flatDist(hrp.Position, turkeyPos) > standDist then
                Move.MoveTo(turkeyPos + Vector3.new(0, 0, 12), standDist, 3.0, function()
                    return not States.PumpkinTycoon.AutoFightTurkey or not turkeyModel.Parent
                end)
            end
        end

        -- Dispatch all available pets onto Turkey
        local M = Net.Mod
        if M.PlayerPet and M.PlayerPet.GetByPlayer then
            for _, pet in ipairs(M.PlayerPet.GetByPlayer(LocalPlayer) or {}) do
                local cur = pet.GetTarget and pet:GetTarget()
                if cur ~= turkeyModel then
                    pcall(function()
                        if pet.SetAnchored then pet:SetAnchored(false) end
                        if pet.SetTarget then pet:SetTarget(turkeyModel) end
                    end)
                end
            end
        end

        ctx.Runtime.Status.Event = string.format("Fighting Turkey (UID: %s)", tostring(uid))
        return true
    end

    function WT.TrySyncAutoHunt()
        local PT = States.PumpkinTycoon
        if not PT.AutoHuntWildPets or not Net.IsInPumpkinTycoon() then return false end
        if os.clock() - Cooldowns.LastHuntSyncAt < CONFIG.AutoHuntSyncGap then return false end
        if Net.GetFFlag("PumpkinTycoon_AutoHunt", true) ~= true or not Net.OwnPlotPart2() then return false end

        local M = Net.Mod
        if not M.Hunt or not M.Hunt.Rules then return false end

        local minTier = TIER_BY_NAME[PT.HuntMinTier] or 0
        local current = M.Hunt.Rules() or {}
        if current.On == true
            and current.Min == minTier
            and (current.Variant == true) == (PT.HuntVariantsOnly == true)
            and (current.UltraOnHuge == true) == (PT.HuntUltraOnHuges == true) then
            return false
        end

        Cooldowns.LastHuntSyncAt = os.clock()
        local ok = Net.PlotInvoke(M.PT_Types.NET.SetHunt, {
            On = true,
            Min = minTier,
            Variant = PT.HuntVariantsOnly == true,
            UltraOnHuge = PT.HuntUltraOnHuges == true,
        })
        if ok then
            ctx.Runtime.Status.Event = "Synced Auto Hunt (" .. tostring(PT.HuntMinTier) .. "+)"
        end
        return ok == true
    end

    function WT.TryBuyPetNets()
        local PT = States.PumpkinTycoon
        if not PT.AutoBuyPetNets or not Net.IsInPumpkinTycoon() then return false end
        if not Net.OwnPlotPart2() or Net.GetFFlag("PumpkinTycoon_NetStore", true) ~= true then return false end

        local M = Net.Mod
        if not M.Store or not M.Store.TabOpen or not M.Store.TabOpen() then return false end

        local mode = PT.BuyPetNetsMode or "Game Auto Nets + Shop"

        -- 1. Toggle game's own Auto Buy Nets (GN_Restock)
        if string.find(mode, "Game Auto Nets", 1, true) then
            if M.Store.AutoOn and not M.Store.AutoOn() and os.clock() - WT._lastAutoNetsAttemptAt >= 3.0 then
                WT._lastAutoNetsAttemptAt = os.clock()
                Net.PlotInvoke(M.PT_Types.NET.SetAutoNets, true)
            end
        end

        -- 2. Buy selected net offers from PetNetStore (Merchant_RequestPurchase)
        if string.find(mode, "Shop", 1, true) then
            if os.clock() - Cooldowns.LastStoreBuyAt < CONFIG.MerchantPurchaseCooldown then return false end
            local shelf = M.Store.Shelf and M.Store.Shelf()
            if type(shelf) ~= "table" or type(shelf.offers) ~= "table" or not shelf.seed then
                return false
            end

            local wantedSet = Utils.arrayToSet(PT.SelectedNetOffers)
            local coins = Net.GetPumpkinCoins()
            for _, offer in ipairs(shelf.offers) do
                if (offer.left or 0) > 0 and wantedSet[offer.item] and coins >= (offer.price or math.huge) then
                    local padPos = Move.FindMachinePad("PetNetStore")
                    if padPos then
                        Move.ReturnToOwnIsland()
                        Move.MoveTo(padPos, 17, 3.0)
                    end
                    Cooldowns.LastStoreBuyAt = os.clock()
                    local ok = Net.NetworkInvoke("Merchant_RequestPurchase", "PetNetStore", offer.slot, false, shelf.seed)
                    if ok then
                        ctx.Runtime.Status.Event = "Bought " .. tostring(offer.item) .. " from Pet Net Store"
                        return true
                    end
                    break
                end
            end
        end
        return false
    end

    function WT.TryCatchWildPets()
        local PT = States.PumpkinTycoon
        if not PT.AutoCatchWildPets or not Net.IsInPumpkinTycoon() then return false end
        if not Net.OwnPlotPart2() or Net.GetFFlag("PumpkinTycoon_Wild", true) ~= true then return false end
        if PT.AutoFightTurkey and Move.IsOnTurkeyIsland() then return false end

        local M = Net.Mod
        if not M.Wild or not M.Wild.All then return false end

        local throwCd = (M.Util_Wild and M.Util_Wild.ThrowSeconds and M.Util_Wild.ThrowSeconds()) or CONFIG.ThrowCooldown
        if os.clock() - Cooldowns.LastThrowAt < throwCd + 0.1 then return false end

        local minTier = TIER_BY_NAME[PT.CatchWildMinTier] or 0
        local bestSlot = nil
        local bestScore = -1
        local bestEntry = nil
        local bestPos = nil

        for slot, obj in pairs(M.Wild.All() or {}) do
            local primary = obj.CustomPet and obj.CustomPet.primaryPart
            if primary and primary.Parent and not obj.Catching and not obj.AttemptingCatch then
                local soldOut = M.Wild.SoldOut and M.Wild.SoldOut(slot)
                if not soldOut then
                    local entry = obj.Entry
                    local tier = inferEntryTier(entry)
                    local variantOk = (not PT.CatchWildVariantsOnly) or isVariantEntry(entry)
                    if tier >= minTier and variantOk then
                        local score = tier * 100 + (isVariantEntry(entry) and 20 or 0)
                        if score > bestScore then
                            bestScore = score
                            bestSlot = slot
                            bestEntry = entry
                            bestPos = primary.Position
                        end
                    end
                end
            end
        end

        if not bestSlot or not bestPos then return false end

        local tier = inferEntryTier(bestEntry)
        local chosenNet = nil
        if PT.CatchWildNetPreference == "Pet Net Only" then
            if Net.GetMiscCount("Pet Net") > 0 then chosenNet = "Pet Net" end
        elseif PT.CatchWildNetPreference == "Ultra For Huge+" then
            if tier >= 4 and Net.GetMiscCount("Ultra Pet Net") > 0 then
                chosenNet = "Ultra Pet Net"
            elseif Net.GetMiscCount("Pet Net") > 0 then
                chosenNet = "Pet Net"
            end
        else
            chosenNet = Net.GetBestNetName()
        end
        if not chosenNet then return false end

        local throwReach = Net.GetNumberFFlag("PumpkinTycoon_ThrowReach", CONFIG.DefaultThrowReach)
        Move.ReturnToOwnIsland()
        local arrived = Move.MoveTo(bestPos, math.max(20, throwReach - 30), 3.0, function()
            return not States.PumpkinTycoon.AutoCatchWildPets
        end)
        if not arrived then return false end

        Cooldowns.LastThrowAt = os.clock()
        local ok, outcome = Net.PlotInvoke(M.PT_Types.NET.CatchWild, bestSlot, chosenNet)
        if ok then
            ctx.Runtime.Telemetry.WildCaught = ctx.Runtime.Telemetry.WildCaught + 1
            ctx.Runtime.Status.Event = string.format("Threw %s at %s (%s)", chosenNet, tostring(bestEntry and bestEntry.P), tostring(outcome))
            return true
        end
        return false
    end

    ctx.WildAndTurkey = WT
    ctx.API.getActiveTurkeyBreakable = WT.GetActiveTurkeyBreakable
    ctx.API.getActiveRareSighting = WT.GetActiveRareSighting
    return WT
end

return WildAndTurkey
