

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local MachineCmds = require(Library.Client.MachineCmds)
local MapCmds = require(Library.Client.MapCmds)
local Functions = require(Library.Functions)

local function FireRemote(remoteName, ...)
    local remote = NetworkFolder:FindFirstChild(remoteName)
    if not remote then return end
    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    elseif remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    end
end


local function GetPlayerData()
    return Save.Get()
end


local function TeleportToMachine(machineName)
    local maxAttempts = 3
    for attempt = 1, maxAttempts do
        local machine = MachineCmds.GetClosestMachine(machineName)
        if machine and machine.Position then
            local zone = machine.ParentID
            if zone and MapCmds.GetCurrentZone() ~= zone then
                FireRemote("Teleports_RequestTeleport", zone)
                task.wait(2)
            end
            Functions.TeleportCharacterTo(machine.Position + Vector3.new(0, 2, 0))
            task.wait(1)
            FireRemote("Machines: Mark Approached", machineName)
            return true
        end
        task.wait(2)
    end
    return false
end


local function GetUpgradeCost(targetTier)
    local costs = {
        [2] = 5, [3] = 5, [4] = 7, [5] = 7,
        [6] = 7, [7] = 7, [8] = 10, [9] = 10, [10] = 10,
    }
    return costs[targetTier] or 5
end


local function GetEnchantBooks()
    local data = GetPlayerData()
    if not data or not data.Inventory or not data.Inventory.Enchant then
        return {}
    end
    local books = {}
    for uid, info in pairs(data.Inventory.Enchant) do
        if type(info) == "table" and info.id then
            local id = info.id
            local tier = info.tn or 1
            local amount = info._am or 1
            books[#books+1] = {
                uid = uid,
                id = id,
                tier = tier,
                amount = amount
            }
        end
    end
    return books
end


local function FindUIDsForBook(bookId, tier)
    local data = GetPlayerData()
    if not data or not data.Inventory.Enchant then return {} end
    local uids = {}
    for uid, info in pairs(data.Inventory.Enchant) do
        if info.id == bookId and (info.tn or 1) == tier then
            uids[#uids+1] = uid
        end
    end
    return uids
end


local function FindLargestStackBook(books)
    local groups = {} 
    for _, book in ipairs(books) do
        local key = book.id .. "_" .. book.tier
        if not groups[key] then
            groups[key] = {
                id = book.id,
                tier = book.tier,
                totalAmount = 0,
                uids = {}
            }
        end
        groups[key].totalAmount = groups[key].totalAmount + book.amount
        groups[key].uids[#groups[key].uids+1] = book.uid
    end

    local largest = nil
    for _, group in pairs(groups) do
        if not largest or group.totalAmount > largest.totalAmount then
            largest = group
        end
    end
    return largest
end


local function UpgradeAllEnchants()
    print("[AutoEnchant] Makineye gidiliyor...")
    if not TeleportToMachine("UpgradeEnchantsMachine") then
        print("[AutoEnchant] Makine bulunamadı, işlem iptal.")
        return
    end

    local totalUpgrades = 0
    local maxLoops = 1000 
    local loopCount = 0

    while loopCount < maxLoops do
        loopCount = loopCount + 1
        local books = GetEnchantBooks()
        if #books == 0 then
            print("[AutoEnchant] Envanterde büyü kitabı kalmadı.")
            break
        end

        
        local largest = FindLargestStackBook(books)
        if not largest then
            print("[AutoEnchant] Hiç kitap bulunamadı.")
            break
        end

        local currentTier = largest.tier
        local nextTier = currentTier + 1
        if nextTier > 10 then
            print(string.format("[AutoEnchant] %s zaten max seviyede (%d).", largest.id, currentTier))
            
            continue
        end

        local needed = GetUpgradeCost(nextTier)
        if not needed then
            print("[AutoEnchant] Bilinmeyen tier, atlanıyor.")
            continue
        end

        
        local possibleUpgrades = math.floor(largest.totalAmount / needed)
        if possibleUpgrades == 0 then
            
            continue
        end

        print(string.format("[AutoEnchant] %s (tier %d) -> %d (x%d) stack: %d, maliyet: %d",
            largest.id, currentTier, nextTier, possibleUpgrades, largest.totalAmount, needed))

        

        local crafted = 0
        for _, uid in ipairs(largest.uids) do
            if crafted >= possibleUpgrades then break end
            
            local data = GetPlayerData()
            local bookInfo = data and data.Inventory and data.Inventory.Enchant and data.Inventory.Enchant[uid]
            if not bookInfo then continue end
            local amt = bookInfo._am or 1
            local toCraft = math.min(math.floor(amt / needed), possibleUpgrades - crafted)
            if toCraft > 0 then
                FireRemote("UpgradeEnchantsMachine_Activate", uid, toCraft)
                crafted = crafted + toCraft
                totalUpgrades = totalUpgrades + toCraft
                task.wait(0.5) 
            end
        end

        if crafted == 0 then
            
            continue
        end

        
        task.wait(0.3)
    end

    print(string.format("[AutoEnchant] İşlem tamamlandı. Toplam %d upgrade yapıldı.", totalUpgrades))
end


UpgradeAllEnchants()
