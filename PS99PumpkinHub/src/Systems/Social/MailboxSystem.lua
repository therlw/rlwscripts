-- src/Systems/Social/MailboxSystem.lua
-- Mailbox Tab Backend:
--   - Open/Close Mailbox Gui (TabController "MailboxMachine" + Signal "Mailbox: Show")
--   - Auto Claim Mailbox ("Mailbox: Request" -> "Mailbox: Claim All")
--   - Auto Mail Pets ("Mailbox: Send" with rarity/lock/favorite filters & rate limiting)

local MailboxSystem = {}

function MailboxSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local States = ctx.States

    local Mail = {
        _lastClaimAt = 0,
        _lastSendAt = 0,
        _cooldownUntil = 0,
    }

    function Mail.ToggleGui()
        local TC = Net.Mod.TabController
        if TC and TC.IsOpen and TC.CloseTab and TC.OpenTab then
            local okOpenCheck, isOpen = pcall(TC.IsOpen, "MailboxMachine")
            if okOpenCheck and isOpen then
                pcall(TC.CloseTab, "MailboxMachine")
                return false
            end
            local okOpen = pcall(TC.OpenTab, "MailboxMachine")
            if okOpen then
                pcall(Net.SignalFire, "Mailbox: Show", "Gifts")
                return true
            end
        end
        return false
    end

    local function stepAutoClaimMailbox()
        if not States.Mailbox.AutoClaimMailbox then return end
        if os.clock() - Mail._lastClaimAt < 6.0 then return end
        Mail._lastClaimAt = os.clock()

        local okLoad, inboxData = Net.NetworkInvoke("Mailbox: Request")
        if okLoad and type(inboxData) == "table" and type(inboxData.Inbox) == "table" and #inboxData.Inbox > 0 then
            local count = #inboxData.Inbox
            local ok = Net.NetworkInvoke("Mailbox: Claim All")
            if ok then
                ctx.Runtime.Status.Mailbox = string.format("Claimed %d Mailbox items!", count)
            end
        end
    end

    local function matchesFilter(item, filterMode)
        if filterMode == "Huge / Titanic+" then
            return (item.IsHuge and item:IsHuge()) or (item.IsTitanic and item:IsTitanic()) or (item.IsGargantuan and item:IsGargantuan())
        elseif filterMode == "Exclusive / Huge+" then
            return (item.IsExclusive and item:IsExclusive()) or (item.IsHuge and item:IsHuge()) or (item.IsTitanic and item:IsTitanic()) or (item.IsGargantuan and item:IsGargantuan())
        elseif filterMode == "Mythical+" then
            local r = item.GetRarity and item:GetRarity()
            return (r and (r.RarityNumber or 0) >= 6) or (item.IsExclusive and item:IsExclusive()) or (item.IsHuge and item:IsHuge())
        end
        return true
    end

    local function stepAutoMailPets()
        if not States.Mailbox.AutoMailPets then return end
        if os.clock() - Mail._lastSendAt < 3.5 or os.clock() < Mail._cooldownUntil then return end

        local target = tostring(States.Mailbox.MailUsername or "")
        if target == "" or target == ctx.Roblox.LocalPlayer.Name then return end

        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.Container then return end
        local container = M.InventoryCmds.Container()
        if not container then return end

        local eqIds = {}
        if M.PetEquipCmds and M.PetEquipCmds.GetEquipped then
            for _, eq in pairs(M.PetEquipCmds.GetEquipped() or {}) do
                if eq and eq.uid then eqIds[eq.uid] = true end
            end
        end

        local filterMode = States.Mailbox.MailRarityFilter or "Exclusive / Huge+"
        local msg = tostring(States.Mailbox.MailMessage or "")

        for uid, item in pairs(container:All() or {}) do
            if item.IsA and item:IsA("Pet") and not eqIds[uid] then
                local locked = item.IsLocked and item:IsLocked()
                local fav = item.IsFavorite and item:IsFavorite()
                if not locked and not fav and matchesFilter(item, filterMode) then
                    Mail._lastSendAt = os.clock()
                    local amt = (item.GetAmount and item:GetAmount()) or 1
                    local ok, reason = Net.NetworkInvoke("Mailbox: Send", target, msg, "Pet", uid, amt)
                    if ok then
                        ctx.Runtime.Telemetry.PetsMailed = ctx.Runtime.Telemetry.PetsMailed + amt
                        ctx.Runtime.Status.Mailbox = string.format("Mailed %dx %s to %s", amt, tostring(item:GetId()), target)
                    else
                        local waitSec = type(reason) == "string" and tonumber(string.match(reason, "Please wait (%d+) seconds"))
                        if waitSec then
                            Mail._cooldownUntil = os.clock() + waitSec + 1
                        end
                    end
                    return
                end
            end
        end
    end

    function MailboxSystem.Start()
        Lifecycle.SpawnLoop("MailboxWorker", 1.25, function()
            stepAutoClaimMailbox()
            stepAutoMailPets()
        end)
    end

    ctx.MailboxSystem = Mail
    ctx.API.toggleMailboxGui = Mail.ToggleGui
    return Mail
end

return MailboxSystem
