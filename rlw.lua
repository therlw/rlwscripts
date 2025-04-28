-- KULLANIM:
-- 1) _G.User ve _G.Pass değerlerini ayarlayın
-- 2) _G.WebhookURL değerini ayarlayın
-- 3) loadstring ile scripti çalıştırın

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local Booths = game:GetService("Workspace").__THINGS.Booths
local HttpService = game:GetService("HttpService")

-- KULLANICI DOĞRULAMA SİSTEMİ --
local USER_CREDENTIALS = {
    ["LynKox35"] = "WqisRHFet1NiKKsaGtPrmld7ML2nPi2n",
    ["rlwfarm1"] = "WqisRHFet1NiKKsaGtPrmld7ML2nPi2n",
    ["bjkgsfbinthehouse"] = "XmNFLZUQhrylqWAvptHADM9gNk8aXV2D"
}

-- Giriş kontrolü
if not _G.User or not _G.Pass or USER_CREDENTIALS[_G.User] ~= _G.Pass then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "GİRİŞ REDDEDİLDİ",
        Text = "Geçersiz kullanıcı adı/şifre",
        Duration = 10
    })
    error("⛔ Yetkisiz erişim! Lütfen doğru _G.User ve _G.Pass değerlerini ayarlayın")
    return
end

print("╔══════════════════════════════╗")
print("║  🔓 Giriş Başarılı           ║")
print("║  Kullanıcı: ".._G.User..string.rep(" ", 17-#_G.User).."║")
print("║  Webhook Bağlantısı Hazır    ║")
print("╚══════════════════════════════╝")

-- AYARLAR --
local settings = {
    targetImageId = _G.targetImageId or "rbxassetid://110695119653954",
    maxCost = _G.maxCost or 60000,
    delayBetweenPurchases = _G.delayBetweenPurchases or 0.3,
    running = _G.running ~= false and true,
    scanDelay = _G.scanDelay or 1,
    webhookEnabled = _G.webhookEnabled ~= false and true,
    webhookURL = _G.WebhookURL or ""
}

-- DISCORD WEBHOOK --
local function sendToDiscord(itemData)
    if not settings.webhookEnabled or settings.webhookURL == "" then return end
    
    local embed = {
        {
            ["title"] = "✅ YENİ SNIPE!",
            ["description"] = string.format(
                "**ItemID:** %s\n**Satıcı:** %s\n**Fiyat:** %s R$\n**Miktar:** x%d\n**Toplam:** %s R$",
                itemData.itemId, 
                itemData.sellerName, 
                itemData.price,
                itemData.quantity,
                itemData.price * itemData.quantity
            ),
            ["color"] = 65280,
            ["footer"] = {
                ["text"] = "PS99 Sniper • "..os.date("%d/%m/%Y %H:%M:%S")
            },
            ["thumbnail"] = {
                ["url"] = itemData.imageUrl
            }
        }
    }

    local success, response = pcall(function()
        return syn.request({
            Url = settings.webhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                ["embeds"] = embed,
                ["username"] = "PS99 Sniper Bot",
                ["avatar_url"] = "https://i.imgur.com/kp3UzPQ.png"
            })
        })
    end)

    if not success then
        warn("❌ Webhook hatası:", response)
    end
end

-- FAKE CALLER DETAYLARI (GÜNCELLENMİŞ) --
local function createFakeCaller()
    return {
        ["LineNumber"] = 527,
        ["ScriptClass"] = "ModuleScript",
        ["Variadic"] = false,
        ["Traceback"] = table.concat({
            "ReplicatedStorage.Library.Client.BoothCmds:527 function PromptPurchase2",
            "ReplicatedStorage.Library.Client.BoothCmds:654 function promptOtherPlayerBooth2",
            "ReplicatedStorage.Library.Client.BoothCmds:157"
        }, "\n"),
        ["ScriptPath"] = "ReplicatedStorage.Library.Client.BoothCmds",
        ["FunctionName"] = "PromptPurchase2",
        ["Handle"] = "function: 0xe90b5a337ba195fb",
        ["ScriptType"] = "Instance",
        ["ParameterCount"] = 2,
        ["SourceIdentifier"] = "ReplicatedStorage.Library.Client.BoothCmds",
        ["ScriptSignature"] = "0x7b226e616d65223a22426f6f7468436d6473222c226c696e65223a3532377d",
        ["CurrentLine"] = 527,
        ["ScriptOffset"] = 1250,
        ["DebuggerConnection"] = 3,
        ["ThreadId"] = 14523,
        ["EnvironmentTable"] = {
            ["__index"] = function() end
        }
    }
end

-- SATIN ALMA FONKSİYONU (TAM SÜRÜM) --
local function purchaseItem(userId, itemId, sellerName, price, quantity)
    local args = {
        [1] = userId,
        [2] = { [itemId] = quantity },
        [3] = {
            ["Caller"] = createFakeCaller(),
            ["PurchasingFromBooth"] = true,
            ["BoothSlot"] = math.random(1, 8),
            ["PurchaseTime"] = os.time()
        }
    }

    local success, result = pcall(function()
        return Network.Booths_RequestPurchase:InvokeServer(unpack(args))
    end)

    if success and result then
        print(string.format("│ ✅ [%s] Satın alındı │ ItemID: %s x%d", os.date("%X"), itemId, quantity))
        sendToDiscord({
            itemId = itemId,
            sellerName = sellerName,
            price = price,
            quantity = quantity,
            imageUrl = settings.targetImageId
        })
    elseif not success then
        warn("❌ Satın alma hatası:", result)
    end
end

-- TARAMA FONKSİYONU --
local function scanAndPurchase()
    local startTime = os.clock()
    local stats = { scanned = 0, found = 0, purchased = 0 }
    
    for _, booth in ipairs(Booths:GetChildren()) do
        if not settings.running then break end
        stats.scanned = stats.scanned + 1
        
        local info = booth:FindFirstChild("Info")
        local pets = booth:FindFirstChild("Pets")
        
        if info and pets then
            local username = info:FindFirstChild("BoothBottom") and info.BoothBottom.Frame and info.BoothBottom.Frame.Top
            if username and username:IsA("TextLabel") then
                local displayName = username.Text:match("^(.-)'s Booth")
                if displayName then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if (player.DisplayName == displayName or player.Name == displayName) and settings.running then
                            local boothTop = pets:FindFirstChild("BoothTop")
                            local petScroll = boothTop and boothTop:FindFirstChild("PetScroll")
                            
                            if petScroll then
                                for _, item in ipairs(petScroll:GetChildren()) do
                                    if not settings.running then break end
                                    
                                    local icon = item:FindFirstChild("Holder") and item.Holder.ItemSlot and item.Holder.ItemSlot.Icon
                                    local costLabel = item:FindFirstChild("Buy") and item.Buy.Cost
                                    local quantityLabel = item.Holder and item.Holder.ItemSlot and item.Holder.ItemSlot.Quantity
                                    
                                    if icon and costLabel and quantityLabel and icon.Image == settings.targetImageId then
                                        local cost = tonumber(costLabel.Text:match("%d+")) or 0
                                        if costLabel.Text:match("k") then cost = cost * 1000 end
                                        local quantity = tonumber(quantityLabel.Text:match("%d+")) or 1
                                        
                                        if cost > 0 and cost <= settings.maxCost then
                                            stats.found = stats.found + 1
                                            purchaseItem(player.UserId, item.Name, player.Name, cost, quantity)
                                            task.wait(settings.delayBetweenPurchases)
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- İstatistikleri yazdır
    print(string.format("\n╔══════════════════════════════╗"))
    print(string.format("║  🔍 Tarama Tamamlandı       ║"))
    print(string.format("║  ⏱️ Süre: %.2f s           ║", os.clock()-startTime))
    print(string.format("║  📊 Standlar: %-13d ║", stats.scanned))
    print(string.format("║  🎯 Bulunan: %-14d ║", stats.found))
    print(string.format("╚══════════════════════════════╝"))
end

-- ANA DÖNGÜ --
while settings.running do
    scanAndPurchase()
    
    if settings.running then
        local waitStart = os.time()
        while os.time() - waitStart < settings.scanDelay and settings.running do
            task.wait(1)
            print(string.format("⏳ Bekleniyor... (%ds kaldı)", settings.scanDelay - (os.time() - waitStart)))
        end
    end
end

print("╔══════════════════════════════╗")
print("║  ⏹ Script Durduruldu        ║")
print("╚══════════════════════════════╝")
