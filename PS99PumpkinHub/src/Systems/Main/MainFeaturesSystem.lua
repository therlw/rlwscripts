-- src/Systems/Main/MainFeaturesSystem.lua
-- Main Tab Features:
--   - Auto Claim Free Gifts
--   - Auto Claim Rank Rewards (Rewards only — NO Auto Rank Quests)
--   - Auto Claim Default Forever Pack Free Gift
--   - Auto Pop Balloons
--   - Auto Leave Stairway To Heaven
--   - Auto Treehouse Merchant
--   - Auto Crystal Key Castle

local MainFeaturesSystem = {}

function MainFeaturesSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local Move = ctx.Movement
    local States = ctx.States

    local Sys = {
        _lastGiftAt = 0,
        _lastRankAt = 0,
        _lastPackAt = 0,
        _lastBalloonAt = 0,
        _lastTreeAt = 0,
        _lastCastleAt = 0,
    }

    function Sys.TryClaimFreeGifts()
        if not States.Main.AutoClaimFreeGifts then return false end
        if os.clock() - Sys._lastGiftAt < 3.0 then return false end
        local save = Net.GetSave()
        local dirGifts = Net.Mod.Directory and Net.Mod.Directory.FreeGifts
        if not save or type(dirGifts) ~= "table" then return false end

        local elapsed = (save.FreeGiftsTime or 0)
        local redeemed = save.FreeGiftsRedeemed or {}
        for idx, gift in pairs(dirGifts) do
            local slot = tonumber(idx) or gift.Number
            local waitReq = tonumber(gift.WaitTime) or math.huge
            if slot and not redeemed[slot] and not redeemed[tostring(slot)] and elapsed >= waitReq then
                Sys._lastGiftAt = os.clock()
                local ok = Net.NetworkInvoke("Redeem Free Gift", slot)
                if ok then
                    ctx.Runtime.Status.Main = "Claimed Free Gift #" .. tostring(slot)
                    return true
                end
            end
        end
        return false
    end

    function Sys.TryClaimRankRewards()
        if not States.Main.AutoClaimRankRewards then return false end
        if os.clock() - Sys._lastRankAt < 6.0 then return false end
        if Net.GetFFlag("RankRewards", true) ~= true or Net.GetFFlag("RankClaimAll", true) ~= true then
            return false
        end

        local save = Net.GetSave()
        if not save then return false end
        -- Only fire when RankCmds or save indicates claimable stars/rewards
        local rankStars = tonumber(save.RankStars) or 0
        if rankStars <= 0 then return false end

        Sys._lastRankAt = os.clock()
        local fired = Net.NetworkFire("Ranks_ClaimAll")
        if fired then
            ctx.Runtime.Status.Main = "Checked / Claimed Rank Rewards"
        end
        return fired
    end

    function Sys.TryClaimForeverPack()
        if not States.Main.AutoClaimForeverPack then return false end
        if os.clock() - Sys._lastPackAt < 15.0 then return false end

        Sys._lastPackAt = os.clock()
        local FP = Net.Mod.ForeverPackCmds
        if FP and FP.CanClaimFree then
            local okCan, canFree = pcall(FP.CanClaimFree, "Default")
            if okCan and not canFree then
                return false
            end
        end
        local ok = Net.NetworkInvoke("ForeverPacks: Claim Free", "Default")
        if ok then
            ctx.Runtime.Status.Main = "Claimed Default Forever Pack Free Gift!"
            return true
        end
        return false
    end

    function Sys.TryPopBalloons()
        if not States.Main.AutoPopBalloons then return false end
        if os.clock() - Sys._lastBalloonAt < 0.75 then return false end
        local Inst = Net.Mod.InstancingCmds
        if Inst and Inst.IsInInstance and Inst.IsInInstance() then return false end

        Sys._lastBalloonAt = os.clock()
        local ok, balloons = Net.NetworkInvoke("BalloonGifts_GetActiveBalloons")
        if not ok or type(balloons) ~= "table" then
            -- Fallback: scan BalloonModels in workspace.__THINGS.BalloonGifts
            local folder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("BalloonGifts")
            if folder then
                for _, ch in ipairs(folder:GetChildren()) do
                    local bid = ch:GetAttribute("BalloonId")
                    if bid then
                        Net.NetworkFire("BalloonGifts_BalloonHit", bid)
                        ctx.Runtime.Status.Main = "Popped Balloon " .. tostring(bid)
                        return true
                    end
                end
            end
            return false
        end

        for _, b in pairs(balloons) do
            if type(b) == "table" and b.Id then
                local pos = b.Position
                local _, hrp = Utils.getCharacterParts()
                if typeof(pos) == "Vector3" and (not hrp or Utils.flatDist(hrp.Position, pos) > 90) then
                    Move.MoveTo(pos, 45, 5)
                end
                Net.NetworkFire("BalloonGifts_BalloonHit", b.Id)
                ctx.Runtime.Status.Main = "Popped Balloon #" .. tostring(b.Id)
                return true
            end
        end
        return false
    end

    function Sys.TryLeaveStairway()
        if not States.Main.AutoLeaveStairway then return false end
        local Inst = Net.Mod.InstancingCmds
        if Inst and Inst.IsInInstance and Inst.IsInInstance("StairwayToHeaven") then
            pcall(function()
                if Inst.LeaveInstance then
                    Inst.LeaveInstance()
                else
                    Net.NetworkInvoke("Instancing_PlayerLeaveInstance", "StairwayToHeaven")
                end
            end)
            ctx.Runtime.Status.Main = "Left Stairway To Heaven"
            return true
        end
        return false
    end

    function Sys.TryTreehouseMerchant()
        if not States.Main.AutoTreehouseMerchant then return false end
        if os.clock() - Sys._lastTreeAt < 1.2 then return false end
        local Inst = Net.Mod.InstancingCmds
        if not Inst or not Inst.IsInInstance or not Inst.IsInInstance("TreehouseMerchant") then
            return false
        end

        Sys._lastTreeAt = os.clock()
        for slot = 1, 3 do
            local ok = Net.NetworkInvoke("TreehouseMerchant_Purchase", slot)
            if ok then
                ctx.Runtime.Status.Main = "Bought Treehouse Merchant slot #" .. tostring(slot)
                return true
            end
        end
        return false
    end

    function Sys.TryCrystalKeyCastle()
        if not States.Main.AutoCrystalKeyCastle then return false end
        if os.clock() - Sys._lastCastleAt < 1.4 then return false end
        if Net.GetMiscCount("Crystal Key") <= 0 then return false end
        local Inst = Net.Mod.InstancingCmds
        if not Inst or not Inst.IsInInstance or not Inst.IsInInstance("CrystalKeyCastle") then
            return false
        end

        Sys._lastCastleAt = os.clock()
        local ok = Net.NetworkInvoke("CrystalKey_Unlock", 1)
        if ok then
            ctx.Runtime.Status.Main = "Unlocked Crystal Key Castle Chest"
            return true
        end
        return false
    end

    function MainFeaturesSystem.Start()
        Lifecycle.SpawnLoop("MainFeaturesWorker", 0.7, function()
            Sys.TryLeaveStairway()
            Sys.TryClaimFreeGifts()
            Sys.TryClaimRankRewards()
            Sys.TryClaimForeverPack()
            Sys.TryPopBalloons()
            Sys.TryTreehouseMerchant()
            Sys.TryCrystalKeyCastle()
        end)
    end

    ctx.MainFeatures = Sys
    return Sys
end

return MainFeaturesSystem
