-- src/Systems/PumpkinTycoon/EventCoordinator.lua
-- Unified Priority Coordinator for All Pumpkin Tycoon Subsystems

local EventCoordinator = {}

function EventCoordinator.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local States = ctx.States

    local Coordinator = {}

    function Coordinator.StepOnce()
        if not Net.IsInPumpkinTycoon() then
            ctx.Runtime.Status.Event = "Waiting: Enter Pumpkin Patch Tycoon instance"
            return
        end
        if Net.GetFFlag("PumpkinTycoon_Enabled", true) ~= true then
            ctx.Runtime.Status.Event = "Pumpkin Tycoon is currently disabled by server FFlag"
            return
        end

        local WT = ctx.WildAndTurkey
        local Prog = ctx.TycoonProgression
        local Econ = ctx.PumpkinEconomy

        -- 1. Highest priority: Rare Huge/Titanic/Gargantuan spawn & active Turkey fight
        if WT and WT.TryCatchRareSpawn() then return end
        if WT and WT.TryFightTurkey() then
            -- While fighting Turkey, also keep boosts/hunt/nets/auto-merchant synced passively
            if Prog then Prog.TryOpenFlannelGifts() end
            if Econ then Econ.TryUsePumpkinBoosts() end
            return
        end

        -- 2. Core Tycoon Progression (Rebirth -> Island Reward -> Buttons)
        if Prog then
            if Prog.TryAutoRebirth() then return end
            if Prog.TryStepButtonsAndReward() then return end
        end

        -- 3. Wild Pets + Pet Net Store + Auto Hunt
        if WT then
            WT.TrySyncAutoHunt()
            if WT.TryBuyPetNets() then return end
            if WT.TryCatchWildPets() then return end
        end

        -- 4. Upgrades, Cocoa Boosts, Consumable Boosts, Flannel Gifts
        if Prog and Prog.TryBuyUpgrades() then return end
        if Econ then
            if Econ.TryBuyCocoaBoosts() then return end
            Econ.TryUsePumpkinBoosts()
        end
        if Prog and Prog.TryOpenFlannelGifts() then return end

        -- 5. Merchant, Planting, Keep Rule, Island AutoBreak, Eggs
        if Econ then
            Econ.TryMerchantAndPlant()
            Econ.TrySyncKeepRule()
            Econ.TryAutoBreakPumpkins()
            Econ.TryTeleportBestEgg()
            Econ.TryBuyNearestEgg()
        end
    end

    local STATUS_EXACT = {
        ["None"] = "Yok",
        ["Disabled"] = "Kapalı",
        ["Island Buttons Done"] = "Ada Butonları Tamamlandı",
        ["Waiting inside Pumpkin Patch Tycoon..."] = "Balkabağı adasına girilmesi bekleniyor...",
        ["Waiting: Enter Pumpkin Patch Tycoon instance"] = "Balkabağı Etkinliği alanına girmen bekleniyor",
        ["Pumpkin Tycoon is currently disabled by server FFlag"] = "Balkabağı Etkinliği sunucu tarafından kapalı",
        ["Waiting to unlock Zone 8 Cannon before Turkey"] = "Hindi için Bölge 8 Topunun açılması bekleniyor",
        ["Turkey defeated — returned home"] = "Hindi kesildi — adaya dönüldü",
        ["Claimed Pumpkin Island Completion Reward!"] = "Ada tamamlama ödülü alındı!",
        ["Enabled Game Auto Merchant"] = "Oyun İçi Oto Tüccar aktif",
        ["Auto Tap off"] = "Oto Tıklama kapalı",
        ["Auto Tap idle"] = "Oto Tıklama beklemede",
        ["Auto Tap: scanning breakables in reach..."] = "Oto Tıklama: menzilde hedef aranıyor...",
        ["Main features idle"] = "Genel özellikler beklemede",
        ["Egg & Pet machines idle"] = "Yumurta & Pet makineleri beklemede",
        ["Automatic consumables idle"] = "Otomatik tüketim beklemede",
        ["Fishing Event idle"] = "Balıkçılık etkinliği beklemede",
        ["Waiting: Enter Fishing Event instance"] = "Balıkçılık Etkinliği alanına girmen bekleniyor",
        ["Enabled Game Event Autofish"] = "Oyun İçi Oto-Balık aktif",
        ["Cast rod at nearby water"] = "Yakındaki suya olta atıldı",
        ["Used Bucket O' Chum"] = "Yem Kovası (Bucket O' Chum) kullanıldı",
        ["Farming World idle"] = "Çiftlik Dünyası beklemede",
        ["Claimed Farm Storage!"] = "Çiftlik deposu toplandı!",
        ["Redeemed Farming Quests Reward!"] = "Çiftlik görev ödülleri alındı!",
        ["Mailbox idle"] = "Posta kutusu beklemede",
        ["Webhook listener active"] = "Webhook dinleyicisi aktif",
        ["Checked / Claimed Rank Rewards"] = "Rütbe ödülleri kontrol edildi / alındı",
        ["Claimed Default Forever Pack Free Gift!"] = "Forever Pack ücretsiz hediyesi alındı!",
        ["Left Stairway To Heaven"] = "Stairway To Heaven alanından çıkıldı",
        ["Unlocked Crystal Key Castle Chest"] = "Crystal Key Kalesi sandığı açıldı",
        ["Bulk Upgraded Potions!"] = "İksirler topluca yükseltildi!",
        ["Bulk Upgraded Enchants!"] = "Büyüler topluca yükseltildi!",
    }

    local function translateStatus(raw)
        local s = tostring(raw or "")
        if STATUS_EXACT[s] then
            return STATUS_EXACT[s]
        end

        local amt, target = s:match("^Saving (.+) for (.+)$")
        if amt then return string.format("%s için %s biriktiriliyor", target, amt) end
        local okId = s:match("^Surplus OK %((.+)%)$")
        if okId then return string.format("Fazla Coin Hazır (%s)", okId) end
        local farmId = s:match("^Farm OK %((.+)%)$")
        if farmId then return string.format("Farm Uygun (%s)", farmId) end

        local bId, bPrice = s:match("^Bought Button: (.+) %(%$(.+)%)$")
        if bId then return string.format("Buton Alındı: %s (%s)", bId, bPrice) end
        local fUid, fCps = s:match("^Tapping UID (.+) %((.+) cps%)$")
        if fUid then return string.format("Hedef %s vuruluyor (%s/sn)", fUid, fCps) end
        local tUid = s:match("^Fighting Turkey %(UID: (.+)%)$")
        if tUid then return string.format("Hindi Boss kesiliyor (UID: %s)", tUid) end
        local trk, cost = s:match("^Upgraded (.+) %((.+) Tokens%)$")
        if trk then return string.format("%s yükseltildi (%s Token)", trk, cost) end
        local coco = s:match("^Cocoa Refilled: (.+)$")
        if coco then return "Kakao Yenilendi: " .. coco end
        local bName, bTier = s:match("^Used (.+) Tier (%d+)$")
        if bName then return string.format("Kullanıldı: %s (Sv. %s)", bName, bTier) end
        local keepR = s:match("^Set Pumpkin Keep Rule: (.+)$")
        if keepR then return "Koruma Kuralı Ayarlandı: " .. keepR end
        local merchB = s:match("^Bought Merchant Pumpkin: (.+)$")
        if merchB then return "Tüccardan Alındı: " .. merchB end
        local hCnt, hName = s:match("^Hatched (.+)x (.+)$")
        if hCnt then return string.format("Yumurta Açıldı: %sx %s", hCnt, hName) end
        local oCnt, oId = s:match("^Opened (.+)x (.+)$")
        if oCnt then return string.format("Açıldı: %sx %s", oCnt, oId) end
        local rebN = s:match("^Completed Pumpkin Tycoon Rebirth #(.+)$")
        if rebN then return "Etkinlik Rebirth #" .. rebN .. " tamamlandı!" end
        local rCur, rMax = s:match("^Rebirth target reached %((%d+) / (%d+)%)$")
        if rCur then return string.format("Hedef Rebirth'e ulaşıldı (%s/%s)", rCur, rMax) end
        local thNet, thPet, thOut = s:match("^Threw (.+) at (.+) %((.+)%)$")
        if thNet then return string.format("%s hedefine %s atıldı (%s)", thPet, thNet, thOut) end
        local thNet2, thPet2 = s:match("^Threw (.+) at (.+)!$")
        if thNet2 then return string.format("%s hedefine %s atıldı!", thPet2, thNet2) end
        local huntT = s:match("^Synced Auto Hunt %((.+)%)$")
        if huntT then return "Oto Av senkronize (" .. huntT .. ")" end
        local netItem = s:match("^Bought (.+) from Pet Net Store$")
        if netItem then return "Mağazadan alındı: " .. netItem end
        local fishSold = s:match("^Sold (%d+) Event Fish!$")
        if fishSold then return fishSold .. " etkinlik balığı satıldı!" end
        local mSent = s:match("^Claimed (%d+) Mailbox items!$")
        if mSent then return mSent .. " posta eşyası alındı!" end

        if s:find("^At Best Egg %(in BreakableZone%): ") then
            return s:gsub("^At Best Egg %(in BreakableZone%): ", "En İyi Yumurtada (Kırılabilir Alan): ")
        elseif s:find("^At Best Egg %(near pad%): ") then
            return s:gsub("^At Best Egg %(near pad%): ", "En İyi Yumurtada (Yakın): ")
        end

        return s
    end

    local function translateSummaryBlock(summary)
        local out = summary:gsub("(İşlem: )([^|\n]+)", function(pfx, val)
            local trimmed = val:gsub("^%s+", ""):gsub("%s+$", "")
            local trail = val:match("%s+$") or ""
            return pfx .. translateStatus(trimmed) .. trail
        end)
        out = out:gsub("(Coin Tasarrufu: )([^|\n]+)", function(pfx, val)
            local trimmed = val:gsub("^%s+", ""):gsub("%s+$", "")
            local trail = val:match("%s+$") or ""
            return pfx .. translateStatus(trimmed) .. trail
        end)
        return out
    end

    local uiTextCache = {}
    local uiStatCache = {}

    local function safeStat(key, statEl, value)
        local num = tonumber(value) or 0
        if uiStatCache[key] == num then return end
        if statEl and statEl.Set then
            uiStatCache[key] = num
            pcall(function() statEl:Set(num) end)
        end
    end

    local function getRebirthProgressMetrics()
        local M = Net.Mod
        if not Net.IsInPumpkinTycoon() or not M.Util_Buttons or not M.PT_Types or not M.Util_Buttons.RebirthProgress then
            return 0, 0, 0, 0
        end
        local buttonsState = Net.PlotSave(M.PT_Types.VAR.Buttons)
        if type(buttonsState) ~= "table" then
            return 0, 0, 0, 0
        end
        local ok, bought, total, ratio = pcall(M.Util_Buttons.RebirthProgress, buttonsState)
        if not ok or type(total) ~= "number" or total <= 0 then
            return 0, 0, 0, 0
        end
        local b = tonumber(bought) or 0
        local t = tonumber(total) or 0
        local r = math.clamp(tonumber(ratio) or 0, 0, 1)
        return b, t, r, math.max(0, t - b)
    end

    function Coordinator.FormatStatusSummary()
        local coins = Net.GetPumpkinCoins()
        local tokens = Net.GetPumpkinTokens()
        local rebs = Net.GetPumpkinRebirths()
        local maxReb = tonumber(ctx.States.PumpkinTycoon.MaxRebirths) or 0
        local rebTxt = (maxReb > 0) and string.format("%d/%d", rebs, maxReb) or tostring(rebs)
        local pNets = Net.GetMiscCount("Pet Net")
        local uNets = Net.GetMiscCount("Ultra Pet Net")
        local te = ctx.Runtime.Telemetry
        local part2Txt = Net.OwnPlotPart2() and "Bölüm 2 Açık" or "Bölüm 1"
        local bought, total, ratio, remaining = getRebirthProgressMetrics()
        local pctTxt = total > 0 and string.format("%%%.1f (%d/%d · Kalan: %d)", ratio * 100, bought, total, remaining) or "-"

        return string.format(
            "%s | Rebirth: %s | İlerleme: %s\nCoin: %s | Token: %s | Ağ: %d (Ultra: %d) | Atılan Ağ: %d\nHuge Ağ: %d (Yakalanan: %d · Kaçan: %d) | Titanic/Garg Ağ: %d (Yakalanan: %d · Kaçan: %d)\nİşlem: %s | Coin Tasarrufu: %s",
            part2Txt,
            rebTxt,
            pctTxt,
            Utils.formatCompact(coins),
            Utils.formatCompact(tokens),
            pNets,
            uNets,
            te.NetsThrown or 0,
            te.HugeNetsThrown or 0,
            te.HugeCaught or 0,
            te.HugeEscaped or 0,
            te.TitanicGargNetsThrown or 0,
            te.TitanicGargCaught or 0,
            te.TitanicGargEscaped or 0,
            tostring(ctx.Runtime.Status.Event),
            tostring(te.CoinSaveReason)
        )
    end

    function EventCoordinator.Start()
        Lifecycle.SpawnLoop("PumpkinEventCoordinator", function()
            return ctx.Config.MainWorkerInterval or 0.40
        end, function()
            Coordinator.StepOnce()
        end)

        Lifecycle.SpawnLoop("PumpkinStatusUpdater", 1.25, function()
            local UI = ctx.UI
            if not UI then return end
            local st = ctx.Runtime.Status
            local te = ctx.Runtime.Telemetry
            local function safeSet(key, el, txt)
                if uiTextCache[key] == txt then return end
                if el and el.Set then
                    uiTextCache[key] = txt
                    pcall(function() el:Set(txt) end)
                end
            end
            local _, _, ratio, remaining = getRebirthProgressMetrics()
            local pctRounded = math.clamp(math.floor(ratio * 100 + 0.5), 0, 100)
            local totalNets = Net.GetMiscCount("Pet Net") + Net.GetMiscCount("Ultra Pet Net")
            safeSet("pt", UI.PumpkinStatusText, translateSummaryBlock(Coordinator.FormatStatusSummary()))
            safeStat("rebpct", UI.PTStatRebirthPct, pctRounded)
            safeStat("rem", UI.PTStatRemaining, remaining)
            safeStat("net", UI.PTStatNets, totalNets)
            safeSet("farm", UI.FarmStatusText, string.format("%s | Vuruş: %d", translateStatus(st.Farm), te.TurkeyHits))
            safeSet("main", UI.MainStatusText, translateStatus(st.Main))
            safeSet("egg", UI.EggStatusText, translateStatus(st.Egg))
            safeSet("auto", UI.AutomaticStatusText, translateStatus(st.Automatic))
            safeSet("fish", UI.FishingStatusText, string.format("%s | Tutulan: %d", translateStatus(st.Fishing), te.FishCaught))
            safeSet("farming", UI.FarmingStatusText, translateStatus(st.Farming))
            safeSet("mail", UI.MailboxStatusText, string.format("%s | Gönderilen: %d", translateStatus(st.Mailbox), te.PetsMailed))
            safeSet("wh", UI.WebhookStatusText, string.format("%s | Gönderilen: %d", translateStatus(st.Webhook), te.WebhooksSent))
        end)
    end

    ctx.EventCoordinator = Coordinator
    ctx.API.stepPumpkinCoordinator = Coordinator.StepOnce
    return Coordinator
end

return EventCoordinator
