-- src/Systems/Trade/TradeSystem.lua
-- Live Trade Value Checker (W/F/L Estimator) & Trade Manager

local TradeSystem = {}

function TradeSystem.Init(ctx)
    local Bridge = ctx.Bridge
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle

    local T = {
        _lastSummary = "Aktif takas yok",
        _lastVerdict = "Bekleniyor",
    }

    -- Base market-tier weights (configurable / extendable; reflects 2026 rarity & MFR multipliers)
    local BASE_VALUES = {
        legendary = 3.0,
        ultra_rare = 1.2,
        rare = 0.5,
        uncommon = 0.25,
        common = 0.1,
    }

    -- Notable high-demand pets override table (Elve-style relative tiers)
    local SPECIAL_PETS = {
        shadow_dragon = 260,
        bat_dragon = 245,
        giraffe = 155,
        frost_dragon = 128,
        owl = 98,
        parrot = 80,
        evil_unicorn = 62,
        crow = 60,
        turtle = 16,
        cow = 14,
        kangaroo = 9,
        ssbd = 8.5,
        strawberry_shortcake_bat_dragon = 8.5,
    }

    local function scoreOffer(items)
        if type(items) ~= "table" then return 0, 0 end
        local invDB = Bridge.Mod.InventoryDB
        local total = 0
        local count = 0
        for _, item in ipairs(items) do
            count = count + 1
            local cat = item.category or "pets"
            local kind = item.kind or item.id or ""
            local props = item.properties or {}
            local info = invDB and invDB[cat] and invDB[cat][kind]
            local base = SPECIAL_PETS[kind] or (info and BASE_VALUES[info.rarity or "common"]) or 0.15
            if props.mega_neon then
                base = base * 12
            elseif props.neon then
                base = base * 3.8
            end
            if props.flyable then base = base + (base * 0.15 + 0.5) end
            if props.rideable then base = base + (base * 0.15 + 0.5) end
            total = total + base
        end
        return math.floor(total * 10 + 0.5) / 10, count
    end

    function T.GetActiveTradeInfo()
        local ui = Bridge.Mod.UIManager
        local ta = ui and ui.apps and ui.apps.TradeApp
        if not ta or not ta.visible then
            return nil
        end
        local state = nil
        pcall(function()
            if ta._get_local_trade_state then
                state = ta:_get_local_trade_state()
            end
        end)
        if type(state) ~= "table" then return nil end

        local myOffer = {}
        local partnerOffer = {}
        pcall(function()
            myOffer = ta._get_my_offer and ta:_get_my_offer().items or {}
            partnerOffer = ta._get_partner_offer and ta:_get_partner_offer().items or {}
        end)

        local myScore, myCount = scoreOffer(myOffer)
        local partnerScore, partnerCount = scoreOffer(partnerOffer)
        local diff = math.floor((partnerScore - myScore) * 10 + 0.5) / 10
        local margin = tonumber(States.Trade.MinWinMargin) or 0

        local verdict = "FAIR (Eşit)"
        if diff > math.max(0.5, margin) then
            verdict = "WIN (Kâr +" .. tostring(diff) .. ")"
        elseif diff < -0.5 then
            verdict = "LOSE (Zarar " .. tostring(diff) .. ")"
        end

        return {
            stage = state.current_stage,
            myScore = myScore,
            myCount = myCount,
            partnerScore = partnerScore,
            partnerCount = partnerCount,
            diff = diff,
            verdict = verdict,
            ta = ta,
        }
    end

    function T.GetStatusSummary()
        return T._lastSummary
    end

    Lifecycle.SpawnLoop("TradeManager", 0.8, function()
        -- Auto decline incoming trade popups if enabled
        if States.Trade.AutoDeclineTrades then
            pcall(function()
                local ui = Bridge.Mod.UIManager
                local dApp = ui and ui.apps and ui.apps.DialogApp
                if dApp and dApp.visible then
                    Bridge.RouteFire("TradeAPI/AcceptOrDeclineTradeRequest", nil, false)
                end
            end)
        end

        local info = T.GetActiveTradeInfo()
        if not info then
            T._lastSummary = "Aktif takas penceresi açık değil"
            T._lastVerdict = "Bekleniyor"
            ctx.Runtime.Status.Trade = "Hazır"
            return
        end

        T._lastSummary = string.format(
            "Sen: %.1f (%d eşya) | Karşı: %.1f (%d eşya) -> %s",
            info.myScore, info.myCount, info.partnerScore, info.partnerCount, info.verdict
        )
        T._lastVerdict = info.verdict
        ctx.Runtime.Status.Trade = info.verdict

        if States.Trade.ShowTradeValues then
            pcall(function()
                local ta = info.ta
                if ta and ta.negotiation_trade_icon and ta.negotiation_my_name_label then
                    ta.negotiation_my_name_label.Text = string.format("Sen (%.1f) | %s", info.myScore, info.verdict)
                end
            end)
        end

        if States.Trade.AutoAcceptWinFair and info.diff >= (tonumber(States.Trade.MinWinMargin) or 0) and info.partnerCount > 0 then
            if info.stage == "negotiation" then
                Bridge.RouteFire("TradeAPI/AcceptNegotiation")
            elseif info.stage == "confirmation" then
                Bridge.RouteFire("TradeAPI/ConfirmTrade")
            end
        end
    end)

    ctx.API.Trade = T
    return T
end

return TradeSystem
