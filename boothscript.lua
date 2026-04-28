-- GAME SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local Booths = game:GetService("Workspace").__THINGS.Booths
local requestFunc = (syn and syn.request) or request or http_request or (http and http.request)

-- NETWORK & LIBRARY (PS99 Optimized)
local Library = require(game:GetService("ReplicatedStorage").Library)
local Network = require(game:GetService("ReplicatedStorage").Library.Client.Network)
local HttpService = game:GetService("HttpService")

if not requestFunc then
    warn("❌ Executor does not support HTTP requests! Webhooks and API features will not work.")
end

if not Network then
    warn("❌ Network module not found! Remote calls will fail.")
end

-- SETTINGS SYSTEM (getgenv priority)
local config = getgenv().RLW_Config or {}

local settings = {
    targetItemName = config.targetItemName or "Secret Key",

    -- ITEM TYPE
    itemType = config.itemType or "Misc", -- "Pet" or "MiscItems"
    
    -- GOLDEN (Only for Pets)
    searchGolden = config.searchGolden or false,
    maxCostGolden = config.maxCostGolden or 900000,

    -- RAINBOW (Only for Pets)
    searchRainbow = config.searchRainbow or false,
    maxCostRainbow = config.maxCostRainbow or 2000,

    -- MULTI TARGET
    multiTargetEnabled = config.multiTargetEnabled or false,
    targetItems = config.targetItems or {"Secret Key", "Secret Key Upper Half"},
    currentItemIndex = 1,

    -- WEBHOOK
    webhookEnabled = config.webhookEnabled or false,
    webhookUrl = config.webhookUrl or "",

    -- GENERAL
    maxCost = config.maxCost or 10000,
    delayBetweenPurchases = config.delayBetweenPurchases or 2,
    scanDelay = config.scanDelay or 4,
    running = config.running ~= false and true,

    -- WEBHOOK
    webhookEnabled = config.webhookEnabled or true,
    webhookURL = config.webhookURL or "",
    webhookAvatar = "https://i.imgur.com/sW9JcOk.png", -- RLW logo
    webhookUsername = "RLWSCRIPTS",

    -- SERVER
    serverHopDelay = config.serverHopDelay or 3,
    useTradingTerminal = config.useTradingTerminal ~= false,
    terminalSearchCooldown = 1,
    largeStockThreshold = 10000
}

-- Read from file and assign value later:
if isfile and not isfile("current_item.txt") then
    writefile("current_item.txt", "1")
end

if isfile and isfile("current_item.txt") then
    local content = readfile("current_item.txt")
    local num = tonumber(content)
    if num and num >= 1 and num <= #settings.targetItems then
        settings.currentItemIndex = num
    else
        settings.currentItemIndex = 1
    end
end

-- CALLER STRUCTURE
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

local function waitForGameLoad()
    local maxWaitTime = 10
    local startTime = os.time()
    
    while not game:IsLoaded() and os.time() - startTime < maxWaitTime do
        task.wait(1)
        print("Waiting for game to load...")
    end
    
    task.wait(3)
    
    if not game:IsLoaded() then
        warn("Game failed to load! Stopping script.")
        return false
    end
    
    print("Game loaded successfully!")
    return true
end

-- ITEM DATA FETCHING
local function getItemData(itemName)
    if not requestFunc then return false end
    
    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")
    local url = isMisc and "https://ps99.biggamesapi.io/api/collection/MiscItems" or "https://ps99.biggamesapi.io/api/collection/Pets"

    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET",
            Headers = { 
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/Executor"
            }
        })
    end)

    if success and response and (response.StatusCode == 200 or response.Status == 200) then
        local success2, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if success2 and data then
            local itemsList = data.data or data
            if type(itemsList) == "table" then
                for _, item in ipairs(itemsList) do
                    if item.configName == itemName then
                        settings.targetItemName = itemName
                        settings.targetImageId = item.configData.Icon or item.configData.thumbnail
                        if not isMisc then
                            settings.goldenImageId = item.configData.goldenThumbnail or nil
                            settings.rainbowImageId = item.configData.rainbowThumbnail or nil
                        end
                        print("✅ " .. (isMisc and "Misc" or "Pet") .. " found in API: " .. tostring(itemName))
                        return true
                    end
                end
            end
            warn("❌ " .. (isMisc and "Misc" or "Pet") .. " NOT FOUND in API: " .. tostring(itemName))
        else
            warn("❌ API data parsing error (JSON Decode failed)")
        end
    else
        local status = response and (response.StatusCode or response.Status) or "No Response"
        warn("❌ API connection error! Code: " .. tostring(status))
    end
    return false
end

-- WEBHOOK FUNCTION
local function sendWebhook(data)
    if not settings.webhookEnabled or settings.webhookUrl == "" or not requestFunc then return end
    
    local player = Players.LocalPlayer
    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")
    local itemTypeLabel = isMisc and "🔮 MISC" or (data.isGolden and "✨ GOLDEN" or (data.isRainbow and "🌈 RAINBOW" or "🐾 NORMAL"))

    local iconId = tostring(settings.targetImageId or ""):match("%d+")
    local thumbUrl = iconId and ("https://www.roblox.com/asset-thumbnail/image?assetId=" .. iconId .. "&width=420&height=420&format=png") or ""

    local embed = {
        ["title"] = "✅ Item Purchased!",
        ["color"] = 65280, -- Green
        ["thumbnail"] = {["url"] = thumbUrl},
        ["fields"] = {
            {["name"] = "Item", ["value"] = settings.targetItemName, ["inline"] = true},
            {["name"] = "Type", ["value"] = itemTypeLabel, ["inline"] = true},
            {["name"] = "Price", ["value"] = formatNumber(data.price) .. " 💎", ["inline"] = true},
            {["name"] = "Quantity", ["value"] = tostring(data.quantity), ["inline"] = true},
            {["name"] = "Total Spent", ["value"] = formatNumber(data.totalCost) .. " 💎", ["inline"] = true},
            {["name"] = "Seller", ["value"] = "||" .. data.seller .. "||", ["inline"] = true},
            {["name"] = "Remaining Diamonds", ["value"] = formatNumber(data.remainingBalance) .. " 💎", ["inline"] = false}
        },
        ["footer"] = {["text"] = "RLW Booth Sniper | " .. os.date("%X")},
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    pcall(function()
        requestFunc({
            Url = settings.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["embeds"] = {embed}})
        })
    end)
end

-- PRICE PARSE FUNCTION
local function parsePrice(priceText)
    local cleanText = priceText:gsub("[ ,%$]", ""):lower()
    if cleanText:find("e") then
        local base, exponent = cleanText:match("([%d%.]+)e([%d%.]+)")
        return (tonumber(base) or 0) * 10^(tonumber(exponent) or 0)
    end
    local number, suffix = cleanText:match("([%d%.]+)([mkb]?)")
    number = tonumber(number) or 0
    local multipliers = {b=1000000000, m=1000000, k=1000}
    return suffix and multipliers[suffix] and (number * multipliers[suffix]) or number
end

-- NUMBER FORMATTING
local function formatNumber(num)
    if num >= 1000000000 then
        local billionValue = num / 1000000000
        if billionValue == math.floor(billionValue) then
            return string.format("%.0fB", billionValue)
        else
            return string.format("%.1fB", billionValue)
        end
    elseif num >= 1000000 then
        local millionValue = num / 1000000
        if millionValue == math.floor(millionValue) then
            return string.format("%.0fM", millionValue)
        else
            return string.format("%.1fM", millionValue)
        end
    elseif num >= 1000 then
        return string.format("%.1fK", num/1000)
    end
    return tostring(math.floor(num))
end

-- QUANTITY FETCH FUNCTION
local function getActualQuantity(itemSlot)
    local quantityLabels = {
        itemSlot:FindFirstChild("Quantity"),
        itemSlot:FindFirstChild("Amount"),
        itemSlot:FindFirstChild("Qty"),
        itemSlot:FindFirstChild("Count")
    }
    
    for _, label in ipairs(quantityLabels) do
        if label and label:IsA("TextLabel") then
            local text = label.Text:gsub("[,%s]", ""):gsub("x", ""):lower()
            local num = tonumber(text)
            if not num then
                num = tonumber(text:match("%d+")) or 0
                if text:find("k") then num = num * 1000
                elseif text:find("m") then num = num * 1000000 end
            end
            if num and num > 0 then return math.floor(num) end
        end
    end
    
    local petTag = itemSlot:FindFirstChild("PetTag")
    if petTag then return 1 end
    
    for _, child in ipairs(itemSlot:GetChildren()) do
        if child:IsA("TextLabel") and child.Text:match("[x%d%.kKmM]") then
            local text = child.Text:gsub("[^%d%.kKmM]", "")
            local num = tonumber(text:gsub("[kKmM]", ""))
            if text:find("[kK]") then num = num * 1000
            elseif text:find("[mM]") then num = num * 1000000 end
            if num and num > 0 then return math.floor(num) end
        end
    end
    
    return 1
end

-- ADVANCED WEBHOOK FUNCTION
local function sendWebhook(data)
    if not settings.webhookEnabled or not settings.webhookURL or settings.webhookURL == "https://discord.com/api/webhooks/..." then 
        print("⚠ Webhook disabled or URL not set")
        return 
    end
    
    local petImageUrl
    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")
    
    if not isMisc then
        if data.isGolden and settings.goldenImageId then
            local imageId = settings.goldenImageId:match("%d+$") or ""
            petImageUrl = "https://biggamesapi.io/image/"..imageId
        elseif data.isRainbow and settings.rainbowImageId then
            local imageId = settings.rainbowImageId:match("%d+$") or ""
            petImageUrl = "https://biggamesapi.io/image/"..imageId
        elseif settings.targetImageId then
            local imageId = settings.targetImageId:match("%d+$") or ""
            petImageUrl = "https://biggamesapi.io/image/"..imageId
        end
    end
    
    if not petImageUrl then
        petImageUrl = "https://tr.rbxcdn.com/180DAY-49a8a79075cc441a1c2624eabdd92291/420/420/Image/Png/noFilter"
    end
    
    local color
    if data.price < 10000 then
        color = 65280
    elseif data.price < 50000 then
        color = 16776960
    else
        color = 16711680
    end
    
    local itemTypeLabel = isMisc and "🔮 MISC" or (data.isGolden and "✨ GOLDEN" or (data.isRainbow and "🌈 RAINBOW" or "🐾 NORMAL"))
    
    local embed = {{
        title = "✅ SUCCESSFUL PURCHASE",
        description = string.format(
            "**Item Name:** %s\n**Item Type:** %s\n**Seller:** [%s](https://www.roblox.com/users/%d/profile)\n**Price:** %s\n**Quantity:** %s\n**Total:** %s\n**Remaining Gems:** %s",
            settings.targetItemName,
            itemTypeLabel,
            data.seller,
            data.userId,
            formatNumber(data.price),
            formatNumber(data.quantity),
            formatNumber(data.totalCost),
            formatNumber(data.remainingBalance)
        ),
        color = color,
        thumbnail = { url = petImageUrl },
        fields = {{
            name = "Time",
            value = os.date("%d/%m/%Y %H:%M:%S"),
            inline = true
        }},
        footer = {
            text = "RLWSCRIPTS • "..os.date("%H:%M:%S"),
            icon_url = settings.webhookAvatar
        },
        timestamp = DateTime.now():ToIsoDate()
    }}
    
    local content = data.quantity >= settings.largeStockThreshold and "@here LARGE STOCK FOUND!" or "@here New " .. string.lower(settings.itemType) .. " purchased!"
    
    local payload = {
        username = settings.webhookUsername,
        avatar_url = settings.webhookAvatar,
        embeds = embed,
        content = content
    }

    pcall(function()
        if not requestFunc then return end
        local response = requestFunc({
            Url = settings.webhookURL,
            Method = "POST",
            Headers = { 
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/Executor"
            },
            Body = HttpService:JSONEncode(payload)
        })
        if response and (response.StatusCode == 200 or response.StatusCode == 204 or response.Status == 200 or response.Status == 204) then
            print("✅ Webhook sent!")
        else
            warn("Webhook failed. Status:", response and (response.StatusCode or response.Status) or "No Response")
        end
    end)
end

-- TRADING TERMINAL SEARCH (FIXED)
local lastTerminalSearch = 0

local function terminalSearch(itemName)
    if not settings.useTradingTerminal then return nil end
    if os.time() - lastTerminalSearch < settings.terminalSearchCooldown then return nil end

    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")
    local queries = {}
    
    if isMisc then
        -- Misc item: try both plain name and JSON ID for maximum compatibility
        table.insert(queries, { query = itemName, type = "MISC" }) 
        table.insert(queries, { query = '{"id":"'..itemName..'"}', type = "MISC" })
    else
        -- Pets
        if settings.searchGolden and settings.goldenImageId then
            table.insert(queries, { query = '{"id":"'..itemName..'","pt":1}', type = "GOLDEN" })
        end
        if settings.searchRainbow then
            table.insert(queries, { query = '{"id":"'..itemName..'","pt":2}', type = "RAINBOW" })
        end
        if not settings.searchGolden and not settings.searchRainbow then
            table.insert(queries, { query = '{"id":"'..itemName..'"}', type = "NORMAL" })
        end
    end

    local VoiceChatService = game:GetService("VoiceChatService")
    local voiceEnabled = false
    pcall(function() voiceEnabled = VoiceChatService:IsVoiceEnabledForUserIdAsync(Players.LocalPlayer.UserId) end)

    for _, q in ipairs(queries) do
        -- For Misc items, we found JSON query to be the most reliable
        if not isMisc or q.query:find("{") then
            print("🔍 Terminal search: [Misc] " .. itemName)
            lastTerminalSearch = os.currentTime or os.time()
            
            local success, result = pcall(function()
                if not Network then return nil end
                return Network.Invoke("TradingTerminal_Search", isMisc and "Misc" or "Pet", q.query, nil, voiceEnabled)
            end)

            if success and result then
                local target = (type(result) == "table" and result[1]) or result
                if target and (target.job_id or target.JobID) then
                    print("✅ Found in terminal! Server: " .. tostring(target.job_id or target.JobID))
                    return target
                end
            end
        end
    end
    return nil
end

-- TELEPORT FUNCTION
local function teleportToTargetPet(searchResult)
    if not searchResult then return false end
    print("🚀 Teleporting to target server...")
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            searchResult.PlaceID or searchResult.place_id,
            searchResult.JobID or searchResult.job_id,
            Players.LocalPlayer
        )
    end)
    if not success then
        warn("⚠ Teleport error:", err)
        return false
    end
    return true
end

-- SMART PURCHASE FUNCTION
local function smartPurchase(userId, itemId, sellerName, price, quantity, isGolden, isRainbow)
    local playerDiamonds = Players.LocalPlayer.leaderstats["💎 Diamonds"].Value
    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")
    
    local itemTypeLabel = isMisc and "🔮 MISC" or (isGolden and "✨ GOLDEN" or (isRainbow and "🌈 RAINBOW" or "🐾 NORMAL"))

    local realStock = quantity
    pcall(function()
        local stockData = Network.GetBoothStock:InvokeServer(userId)
        realStock = stockData and math.min(stockData[itemId] or quantity, quantity)
    end)

    if playerDiamonds < price then
        print(string.format("❌ INSUFFICIENT | %s %s | Need: %s | Have: %s",
            itemTypeLabel, settings.targetItemName, formatNumber(price), formatNumber(playerDiamonds)))
        return false
    end

    local purchaseQty = math.min(realStock, math.floor(playerDiamonds / price))
    local args = {
        userId,
        { [itemId] = purchaseQty },
        { ["Caller"] = getFakeCaller() }
    }

    local success, result = pcall(function()
        return Network.Booths_RequestPurchase:InvokeServer(unpack(args))
    end)

    if success and result == true then
        local totalSpent = price * purchaseQty
        local remainingBalance = playerDiamonds - totalSpent
        
        print(string.format("✅ PURCHASED | %s %s | Qty: %s | Total: %s | Remaining: %s",
            itemTypeLabel, settings.targetItemName, purchaseQty, formatNumber(totalSpent), formatNumber(remainingBalance)))
        
        sendWebhook({
            seller = sellerName,
            userId = userId,
            price = price,
            quantity = purchaseQty,
            totalCost = totalSpent,
            remainingBalance = remainingBalance,
            isGolden = isGolden,
            isRainbow = isRainbow
        })
        
        if purchaseQty < realStock and remainingBalance >= price then
            task.wait(settings.delayBetweenPurchases)
            return smartPurchase(userId, itemId, sellerName, price, realStock - purchaseQty, isGolden, isRainbow)
        end
        return true
    else
        warn("❌ PURCHASE ERROR:", tostring(result))
        return false
    end
end

-- MAIN SCAN FUNCTION
local function scanBooths(itemName)
    local foundValid = false
    local foundNoMoney = false
    local playersByDisplayName = {}
    local playerDiamonds = Players.LocalPlayer.leaderstats["💎 Diamonds"].Value
    local rawType = tostring(settings.itemType):lower()
    local isMisc = (rawType == "misc" or rawType == "miscitems")

    for _, player in ipairs(Players:GetPlayers()) do
        playersByDisplayName[player.DisplayName] = player
        playersByDisplayName[player.Name] = player
    end

    local mode = isMisc and "🔮 MISC" or (settings.searchRainbow and "🌈 RAINBOW" or (settings.searchGolden and "✨ GOLDEN" or "🐾 NORMAL"))
    local limit = isMisc and settings.maxCost or (settings.searchRainbow and settings.maxCostRainbow or (settings.searchGolden and settings.maxCostGolden or settings.maxCost))
    
    print(string.format("\n🔍 %s %s | Balance: %s | Limit: %s",
        mode, itemName, formatNumber(playerDiamonds), formatNumber(limit)))

    for _, booth in ipairs(Booths:GetChildren()) do
        if not settings.running then break end
        
        local info = booth:FindFirstChild("Info")
        local pets = booth:FindFirstChild("Pets")
        if not (info and pets) then continue end
        
        local usernameLabel = info.BoothBottom.Frame.Top
        if not usernameLabel then continue end
        
        local displayName = usernameLabel.Text:match("^(.-)'s Booth")
        local seller = displayName and playersByDisplayName[displayName]
        if not seller then continue end
        
        local petScroll = pets.BoothTop:FindFirstChild("PetScroll")
        if not petScroll then continue end
        
        for _, item in ipairs(petScroll:GetChildren()) do
            if not settings.running then break end
            
            local holder = item:FindFirstChild("Holder")
            if not holder then continue end
            
            local itemSlot = holder:FindFirstChild("ItemSlot")
            if not itemSlot then continue end
            
            local icon = itemSlot:FindFirstChild("Icon")
            if not icon then continue end
            
            -- Determine item properties
            local isRainbow = icon:FindFirstChild("RainbowIcon") ~= nil
            local isGolden = (not isMisc) and icon.Image == settings.goldenImageId
            local isTargetImage = icon.Image == settings.targetImageId
            
            local match = false
            if isMisc then
                match = isTargetImage
            else
                match = (settings.searchRainbow and isRainbow and isTargetImage) or
                        (settings.searchGolden and isGolden) or
                        (not settings.searchRainbow and not settings.searchGolden and not isRainbow and isTargetImage)
            end
            
            if match then
                local costLabel = item:FindFirstChild("Buy") and item.Buy:FindFirstChild("Cost")
                if costLabel then
                    local cost = parsePrice(costLabel.Text)
                    local quantity = getActualQuantity(itemSlot)
                    
                    if playerDiamonds < cost then
                        foundNoMoney = true
                        print(string.format("⚠ [NO MONEY] %s %s | Price: %s",
                            isMisc and "🔮" or (isGolden and "✨" or isRainbow and "🌈" or "🐾"),
                            itemName, formatNumber(cost)))
                    else
                        local maxAllowed = isMisc and settings.maxCost or
                                           (isGolden and settings.maxCostGolden or
                                            (isRainbow and settings.maxCostRainbow or settings.maxCost))
                        
                        if cost <= maxAllowed then
                            print(string.format("\n✅ [FOUND] %s %s | Price: %s | Stock: %s",
                                isMisc and "🔮" or (isGolden and "✨" or isRainbow and "🌈" or "🐾"),
                                itemName, formatNumber(cost), formatNumber(quantity)))
                            
                            smartPurchase(seller.UserId, item.Name, seller.Name, cost, quantity, isGolden, isRainbow)
                            task.wait(settings.delayBetweenPurchases)
                            return true
                        else
                            print(string.format("⚠ [HIGH PRICE] %s %s | %s > %s",
                                isMisc and "🔮" or (isGolden and "✨" or isRainbow and "🌈" or "🐾"),
                                itemName, formatNumber(cost), formatNumber(maxAllowed)))
                            return "high_price"
                        end
                    end
                end
            end
        end
    end
    
    print("\n📭 Result: " .. (foundValid and "No suitable price" or "Item not found"))
    return foundValid and true or false
end

-- ITEM CHECK FUNCTION
local function checkItem(itemName)
    if not getItemData(itemName) then
        warn("❌ Failed to fetch item data: "..itemName)
        return false, nil
    end
    
    local found = scanBooths(itemName)
    if found == true then
        print("✅ Item purchased from booth: "..itemName)
        return true, nil
    elseif found == "high_price" or found == false then
        if settings.useTradingTerminal then
            local terminalResult = terminalSearch(itemName)
            if terminalResult then
                print("📡 Item found in terminal, teleporting...")
                if teleportToTargetPet(terminalResult) then
                    return true, terminalResult
                else
                    warn("⚠ Teleport failed")
                    return false, nil
                end
            else
                print("❌ Item not found in terminal: "..itemName)
                return false, nil
            end
        else
            return false, nil
        end
    else
        return false, nil
    end
end

-- GET CURRENT TARGET NAME
local function getCurrentTargetName()
    if settings.multiTargetEnabled then
        return settings.targetItems[settings.currentItemIndex]
    else
        return settings.targetItemName
    end
end

-- ============ MAIN LOOP ============
if not waitForGameLoad() then return end

local firstItem = getCurrentTargetName()
if not getItemData(firstItem) then
    warn("❌ Failed to get " .. string.lower(settings.itemType) .. " data, stopping!")
    return
end

while settings.running do
    local anyBought = false
    local totalItems = settings.multiTargetEnabled and #settings.targetItems or 1
    
    for i = settings.currentItemIndex, totalItems do
        if not settings.running then break end
        
        settings.currentItemIndex = i
        if writefile then writefile("current_item.txt", tostring(i)) end
        
        local itemName = getCurrentTargetName()
        local success = checkItem(itemName)
        
        if success then
            if writefile then writefile("current_item.txt", "1") end
            anyBought = true
            break
        else
            task.wait(settings.scanDelay)
        end
    end
    
    if not anyBought then
        settings.currentItemIndex = 1
        if writefile then writefile("current_item.txt", "1") end
        print("⚠ No stock found, waiting 5 seconds...")
        task.wait(5)
    end
end

print("⏹ Bot stopped")
