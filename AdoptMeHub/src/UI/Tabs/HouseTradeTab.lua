-- src/UI/Tabs/HouseTradeTab.lua
-- Ev Kopyalayıcı (House Cloner), Auto-Pay Kasa/Stant & Canlı Takas Değer Analizcisi

local HouseTradeTab = {}

function HouseTradeTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local States = ctx.States
    local House = ctx.API.House
    local Trade = ctx.API.Trade
    local Lifecycle = ctx.Lifecycle

    local Tab = Window:CreateTab({
        name = "Ev & Takas",
        icon = 93364949241311,
    })
    UI.HouseTradeTab = Tab

    Tab:CreateSection({ name = "Ev Kopyalayıcı (JSON House Cloner)" })

    UI.createBoundInput(Tab, {
        name = "Ev Dosya Adı",
        flag = "SelectedHouseFile",
        placeholder = "saved_house",
        value = States.House.SelectedHouseFile,
    }, function() return States.House.SelectedHouseFile end, function(v)
        States.House.SelectedHouseFile = (v ~= "" and v or "saved_house")
    end)

    Tab:CreateButton({
        name = "İçinde Bulunduğun Evi Dışa Aktar (JSON Kaydet)",
        callback = function()
            local ok, msg = House.ExportCurrentHouse(States.House.SelectedHouseFile)
            UI.safeNotify({
                title = "House Cloner",
                content = tostring(msg),
                duration = 3.5,
            })
        end,
    })

    Tab:CreateButton({
        name = "Kayıtlı Evi Kendi Evine İnşa Et (Bucks İle Alır)",
        callback = function()
            local ok, msg = House.ImportHouse(States.House.SelectedHouseFile)
            UI.safeNotify({
                title = "House Cloner İnşa",
                content = tostring(msg),
                duration = 3.5,
            })
        end,
    })

    Tab:CreateSection({ name = "Auto-Pay / Yazar Kasa & Stant Para Transferi" })

    UI.createBoundInput(Tab, {
        name = "Hedef Oyuncu Kullanıcı Adı (Stant/Kasa Sahibi)",
        flag = "PayTargetPlayer",
        placeholder = "AnaHesapAdi (opsiyonel)",
        value = States.House.PayTargetPlayer,
    }, function() return States.House.PayTargetPlayer end, function(v)
        States.House.PayTargetPlayer = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Para Gönder (Auto-Pay)",
        flag = "AutoPay",
        value = States.House.AutoPay,
        description = "Kasa veya Limonata/Hotdog standı üzerinden otomatik ödeme yapar",
    }, function() return States.House.AutoPay end, function(v)
        States.House.AutoPay = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Yazar Kasadan Otomatik Topla",
        flag = "AutoCollectRegister",
        value = States.House.AutoCollectRegister,
    }, function() return States.House.AutoCollectRegister end, function(v)
        States.House.AutoCollectRegister = (v == true)
    end)

    Tab:CreateSection({ name = "Ticaret (Trading) & Canlı Değer Hesaplayıcı" })

    local tradeStatusText = Tab:CreateText({
        name = "Canlı Takas Analizi",
        text = "Aktif takas penceresi açık değil",
    })

    Lifecycle.SpawnLoop("TradeTabStatus", 0.9, function()
        if tradeStatusText and tradeStatusText.Set then
            pcall(function()
                tradeStatusText:Set(Trade.GetStatusSummary())
            end)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Takas Penceresinde Canlı Değer Göster (W/F/L)",
        flag = "ShowTradeValues",
        value = States.Trade.ShowTradeValues,
        description = "Rarity, Neon/Mega ve FR ağırlıklarına göre anlık WIN/FAIR/LOSE hesabı yapar",
    }, function() return States.Trade.ShowTradeValues end, function(v)
        States.Trade.ShowTradeValues = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Spam Takas İsteklerini Otomatik Reddet",
        flag = "AutoDeclineTrades",
        value = States.Trade.AutoDeclineTrades,
    }, function() return States.Trade.AutoDeclineTrades end, function(v)
        States.Trade.AutoDeclineTrades = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Kârlı / Eşit Takası Otomatik Onayla (Dikkatli Kullan)",
        flag = "AutoAcceptWinFair",
        value = States.Trade.AutoAcceptWinFair,
        description = "Karşı teklif senin teklifinden belirlenen fark kadar yüksekse otomatik kabul & onaylar",
    }, function() return States.Trade.AutoAcceptWinFair end, function(v)
        States.Trade.AutoAcceptWinFair = (v == true)
    end)

    UI.createBoundSlider(Tab, {
        name = "Oto-Onay Minimum Kâr Farkı",
        flag = "MinWinMargin",
        range = { 0, 100 },
        increment = 1,
        value = States.Trade.MinWinMargin,
        suffix = " Puan",
    }, function() return States.Trade.MinWinMargin end, function(v)
        States.Trade.MinWinMargin = v
    end)

    return HouseTradeTab
end

return HouseTradeTab
