--ps99

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

getgenv().Config = {
    MetaFarmActive = false,
    TargetKeyCount = 5,
    FindKeepOutEgg = false,
    FindFreeEggRoom = false,
    TargetEggType = "Any",
    TargetEggMultiplier = 50,
    TargetKeepOutMultiplier = 50,
    AutoHatchNearest = false,
    AutoLoot = false,
    GodMode = false,
    TeleportDelay = 0.8,
    HopOnBossCooldown = false,
    DeepBackroomsMode = false,
    RadarTeleport = false,
    FarmDeepChests = false,
    FarmDeepEvents = false,
    AutoUpgrades = {
        BackroomsBossDamage = false,
        BackroomsExtraLootRoll = false,
        BackroomsTokenFind = false,
        BackroomsDeepBossDamage = false,
        BackroomsCoinMultiplier = false,
        BackroomsEggLuck = false,
        BackroomsKeyFind = false
    },
    WebhookEnabled = false,
    WebhookURL = "",
    AutoMailbox = false
}

local TargetEggRooms = {}

getgenv().LiveStats = {
    StartTime = os.time(),
    BossesKilled = 0,
    HighestMultiplier = 0,
    RoomsExplored = 0,
    _seenRooms = {},
    BossStatus = "Searching..."
}

-- ==========================
-- 🔗 WEBHOOK & INVENTORY SİSTEMİ
-- ==========================
local KnownUIDs      = {}
local StartHuges     = 0
local StartTitanics  = 0
local CurrentHuges   = 0
local CurrentTitanics= 0

local function GetPetDir()
    local petDir = {}
    pcall(function() petDir = require(ReplicatedStorage.Library.Directory.Pets) end)
    if not next(petDir) then
        pcall(function()
            local dir = require(ReplicatedStorage.Library.Directory)
            petDir = (dir and dir.Pet) or {}
        end)
    end
    return petDir
end

local function InitSessionStats()
    pcall(function()
        local save = require(ReplicatedStorage.Library.Client.Save).Get()
        if not save or not save.Inventory or not save.Inventory.Pet then return end
        local pets   = save.Inventory.Pet
        local petDir = GetPetDir()

        for uid, data in pairs(pets) do
            KnownUIDs[uid] = true
            local pId = tostring(data.id or "")
            local def = petDir[pId]
            local isH = (def and def.huge) or string.match(pId, "^Huge ")
            local isT = (def and def.titanic) or string.match(pId, "^Titanic ")
            
            if isH then StartHuges    = StartHuges    + 1 end
            if isT then StartTitanics = StartTitanics + 1 end
        end
    end)
end
InitSessionStats()

local function SendWebhook(title, desc, color, thumbId)
    if not getgenv().Config.WebhookEnabled then return end
    if not getgenv().Config.WebhookURL or getgenv().Config.WebhookURL == "" then return end
    local requestFn = (getgenv and getgenv().request) or (syn and syn.request) or request
    if not requestFn then return end

    local embed = {
        ["title"]       = title,
        ["description"] = desc,
        ["color"]       = color or 0x00ff00,
        ["timestamp"]   = DateTime.now():ToIsoDate(),
        ["footer"]      = { ["text"] = "powered by RLWSCRIPTS" }
    }
    
    if thumbId and tostring(thumbId) ~= "" then
        embed["thumbnail"] = { ["url"] = "https://ps99.biggamesapi.io/image/" .. tostring(thumbId) }
    end

    pcall(function()
        requestFn({
            Url     = getgenv().Config.WebhookURL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                ["username"] = "RLWSCRIPTS Notification",
                ["embeds"]   = { embed }
            })
        })
    end)
end

local function UpdateInventoryMonitor()
    local success, err = pcall(function()
        local save = require(ReplicatedStorage.Library.Client.Save).Get()
        if not save or not save.Inventory or not save.Inventory.Pet then return end
        local pets   = save.Inventory.Pet
        local petDir = GetPetDir()

        local currentH = 0
        local currentT = 0

        for uid, data in pairs(pets) do
            local pId = tostring(data.id or "")
            local def = petDir[pId]
            
            -- DIRECT STRING MATCHING: En garanti yol.
            local isH = (def and def.huge) or string.match(pId, "^Huge ")
            local isT = (def and def.titanic) or string.match(pId, "^Titanic ")

            if isH then currentH = currentH + 1 end
            if isT then currentT = currentT + 1 end

            -- Yeni pet tespiti
            if not KnownUIDs[uid] then
                KnownUIDs[uid] = true
                if isH or isT then
                    local pName = (def and def.DisplayName) or pId
                    
                    -- Shiny / Golden / Rainbow eklentileri
                    local prefixes = {}
                    if data.sh then table.insert(prefixes, "Shiny") end
                    if data.pt == 1 then table.insert(prefixes, "Golden")
                    elseif data.pt == 2 then table.insert(prefixes, "Rainbow") end
                    
                    if #prefixes > 0 then
                        pName = table.concat(prefixes, " ") .. " " .. pName
                    end

                    local col   = isH and 0x00ff00 or 0xffd700
                    local title = isH and "🎉 NEW HUGE CAUGHT! 🎉" or "🌟 NEW TITANIC CAUGHT! 🌟"
                    
                    local imageId = nil
                    if def then
                        local thumb = def.thumbnail
                        if data.pt == 1 and def.goldenThumbnail then
                            thumb = def.goldenThumbnail
                        elseif data.pt == 2 and def.rainbowThumbnail then
                            thumb = def.rainbowThumbnail
                        end
                        if thumb then
                            imageId = string.match(thumb, "%d+")
                        end
                    end
                    
                    local desc = string.format(
                        "🐾 **Pet:** `%s`\n" ..
                        "👤 **User:** `%s`\n" ..
                        "⏱️ **Time:** `%s`",
                        pName, LocalPlayer.Name, os.date("%X")
                    )
                    
                    SendWebhook(title, desc, col, imageId)
                end
            end
        end

        CurrentHuges    = currentH - StartHuges
        CurrentTitanics = currentT - StartTitanics
    end)
    
    if not success then
        warn("[Webhook Error] UpdateInventoryMonitor failed: " .. tostring(err))
    end
end

task.spawn(function()
    while task.wait(3) do
        UpdateInventoryMonitor()
    end
end)


-- ==========================
-- 🛡️ GELİŞMİŞ ANTİ-AFK SİSTEMİ
-- ==========================
pcall(function()
    local VirtualUser = game:GetService("VirtualUser")

    -- 1. Oyunun Kendi AFK Scriptlerini Kapat
    local coreScripts = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Scripts"):WaitForChild("Core")
    if coreScripts:FindFirstChild("Idle Tracking") then
        coreScripts["Idle Tracking"].Enabled = false
        -- print("[Anti-AFK] Oyunun dahili takip sistemi kapatıldı.")
    end

    -- 2. Sunucuya 'Dur' Sinyali Gönder
    task.spawn(function()
        while task.wait(30) do
            pcall(function()
                local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                if Network then
                    local remote = Network:FindFirstChild("Idle Tracking: Stop Timer")
                    if remote then
                        if remote:IsA("RemoteFunction") then
                            remote:InvokeServer()
                        else
                            remote:FireServer()
                        end
                    end
                end
            end)
        end
    end)

    -- 3. Genel Roblox AFK Kick Engelleyici (Idled Event)
    LocalPlayer.Idled:Connect(function() 
        VirtualUser:CaptureController() 
        VirtualUser:ClickButton2(Vector2.new()) 
        -- print("[Anti-AFK] Roblox AFK atması simüle edilerek engellendi.")
    end)
    -- print("[Anti-AFK] Sistem aktif!")
end)

-- ==========================
-- 🚫 EKRAN BİLDİRİMLERİNİ GİZLEME
-- ==========================
pcall(function()
    local Message = require(game:GetService("ReplicatedStorage").Library.Client.Message)
    Message.Error = function() end
    local oldNew = Message.New
    Message.New = function(msg, ...)
        if msg and type(msg) == "string" and msg:lower():find("mini%-boss") then
            return -- "Mini-boss defeated!" yazısını tamamen engelle
        end
        return oldNew(msg, ...)
    end
end)

-- ==========================
-- 👻 NOCLIP SİSTEMİ (BOSS UÇMASINI ENGELLER)
-- ==========================
task.spawn(function()
    game:GetService("RunService").Stepped:Connect(function()
        if getgenv().Config and getgenv().Config.MetaFarmActive then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end)

-- ==========================
-- 🔧 YARDIMCI FONKSİYONLAR
-- ==========================
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

-- Anti-Void platform
local antiVoid = workspace:FindFirstChild("AntiVoidPart_Antigravity")
if not antiVoid then
    antiVoid = Instance.new("Part")
    antiVoid.Name = "AntiVoidPart_Antigravity"
    antiVoid.Size = Vector3.new(500, 1, 500)
    antiVoid.Anchored = true
    antiVoid.Transparency = 1
    antiVoid.CanCollide = true
    antiVoid.Parent = workspace
end

-- ✅ TEK bir VisitedRooms tanımı
local VisitedRooms = {}
local visitedCount = 0

-- ✅ YENİ: Ölü yumurta odaları (VisitedRooms reset'ten etkilenmesin diye ayrı tutuyoruz)
local DeadEggRooms = {}        -- { [roomUID] = deadTimestamp }
local DEAD_EGG_COOLDOWN = 300  -- 5 dakika sonra tekrar dene (saniye)

local Toggle_MetaFarm = nil
local Toggle_KeepOutEgg = nil
local Toggle_FreeEgg = nil

-- ==========================
-- 🔑 ANAHTAR SAYISI OKUMA
-- ==========================
local function getDaydreamKeyCount()
    local success, result = pcall(function()
        local Save = require(game:GetService("ReplicatedStorage").Library.Client.Save)
        local saveFile = Save.Get()
        if not saveFile or not saveFile.Inventory then return 0 end

        local inventory = saveFile.Inventory
        local count = 0

        for categoryName, categoryData in pairs(inventory) do
            if type(categoryData) == "table" then
                for _, item in pairs(categoryData) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local idLower = string.lower(item.id)
                        local isDeepMode = getgenv().Config.DeepBackroomsMode
                        
                        if isDeepMode then
                            -- Sadece Deep anahtarlarını say
                            if idLower == "deep backrooms crayon key" or idLower == "deep daydream key" then
                                count = count + (item._am or 1)
                            end
                        else
                            -- Sadece Normal anahtarları say
                            if idLower == "backrooms crayon key" or idLower == "daydream key" or idLower == "backrooms key" then
                                count = count + (item._am or 1)
                            end
                        end
                    end
                end
            end
        end

        return count
    end)

    if not success then
        warn("[FARM HATA] Envanter okunamadı: " .. tostring(result))
    end

    return success and result or 0
end

-- ==========================
-- 🚀 IŞINLANMA
-- ==========================
local function safeTeleport(targetObj, fastMode)
    local root = getRootPart()
    if not root or not targetObj then return end

    local initialCFrame = typeof(targetObj) == "CFrame" and targetObj
        or (targetObj:IsA("Model") and targetObj:GetPivot() or targetObj.CFrame)
    local safePosition = initialCFrame.Position + Vector3.new(0, 6, 0)

    if typeof(targetObj) == "Instance" and targetObj:IsA("Model") then
        local boundingCFrame, size = targetObj:GetBoundingBox()
        safePosition = boundingCFrame.Position - Vector3.new(0, size.Y / 2, 0) + Vector3.new(0, 5, 0)
        -- BOSS UÇMA FİXİ: Boss ile tam ortada çarpışmamak için hafif çaprazına ışınlanalım
        safePosition = safePosition + Vector3.new(15, 0, 15)
    end

    root.Anchored = true
    root.CFrame = CFrame.new(safePosition)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
    if Network then
        local reqStream = Network:FindFirstChild("RequestStreaming")
        if reqStream then
            reqStream:FireServer(safePosition)
        end
    end

    local isRoom = typeof(targetObj) == "Instance" and targetObj:GetAttribute("RoomUID") ~= nil
    if isRoom and not fastMode then
        local timeout = 4
        local t = 0
        local loadedFloor = nil

        while t < timeout do
            local priorityNames = {"BREAK_ZONE", "Floor", "Base", "Ground", "Hitbox"}
            for _, name in ipairs(priorityNames) do
                local part = targetObj:FindFirstChild(name, true)
                if part and part:IsA("BasePart") then
                    loadedFloor = part
                    break
                end
            end

            if not loadedFloor then
                for _, part in ipairs(targetObj:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide
                        and part.Name ~= "AntiVoidPart_Antigravity"
                        and part.Size.X > 5 and part.Size.Z > 5 then
                        loadedFloor = part
                        break
                    end
                end
            end

            if loadedFloor then break end
            task.wait(0.2)
            t = t + 0.2
        end

        if loadedFloor then
            local exactPos = loadedFloor.Position + Vector3.new(0, (loadedFloor.Size.Y / 2) + 5, 0)
            safePosition = exactPos
            root.CFrame = CFrame.new(safePosition)
        end
    end

    if antiVoid then
        antiVoid.CFrame = CFrame.new(safePosition - Vector3.new(0, 4, 0))
    end

    task.wait(0.25)
    root.Anchored = false
end

-- ==========================
-- 🗡️ SMART FARM (AUTOTAP & PETS)
-- ==========================
getgenv().SmartFarmState = {
    PetAssignInterval= 0.5,
    AutoTapInterval  = 0.08,
    MaxTargetsPerTick= 8,
    FarmRange        = 150,
    BossRespawningUntil = 0,
    BossRoomUID = nil,
    EggRoomUID = nil,
}

local function GetPlayerPets()
    local pets = {}
    pcall(function()
        local PlayerPet = require(game:GetService("ReplicatedStorage").Library.Client.PlayerPet)
        for _, petData in pairs(PlayerPet.GetAll()) do
            if petData.owner == Players.LocalPlayer then table.insert(pets, petData) end
        end
    end)
    return pets
end

local _prevPetMapping = {}

local function DistributePets(breakables)
    if #breakables == 0 then return end
    local pets = GetPlayerPets()
    if #pets == 0 then return end
    local petsPerBreakable = math.floor(#pets / #breakables)
    local remainder = #pets % #breakables
    local mapping = {}
    local petIndex = 1
    for i, breakable in ipairs(breakables) do
        local count = petsPerBreakable + (i <= remainder and 1 or 0)
        for j = 1, count do
            if petIndex > #pets then break end
            mapping[pets[petIndex].euid] = breakable.Name
            petIndex = petIndex + 1
        end
    end
    if next(mapping) then
        local changed = false
        for k, v in pairs(mapping) do if _prevPetMapping[k] ~= v then changed=true break end end
        if not changed then for k in pairs(_prevPetMapping) do if not mapping[k] then changed=true break end end end
        if changed then
            _prevPetMapping = mapping
            local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
            if Network then Network:FindFirstChild("Breakables_JoinPetBulk"):FireServer(mapping) end
        end
    end
end

local function GetBackroomsTargets()
    local targets = {miniChests={}, bossChest={}, priority={}, normal={}}
    local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if not breakablesFolder then return targets end

    local char = getCharacter()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return targets end
    local pos = hrp.Position

    -- MiniBossRoom Özel Hedefleri
    local mbBossZone = nil
    local mbMiniPoints = {}
    pcall(function()
        local active = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
        local backrooms = active and active:FindFirstChild("Active") and active.Active:FindFirstChild("Backrooms")
        local genRooms = backrooms and backrooms:FindFirstChild("GeneratedBackrooms")
        local mbRoom = genRooms and genRooms:FindFirstChild("MiniBossRoom")
        if mbRoom then
            mbBossZone = mbRoom:FindFirstChild("BREAK_ZONE")
            local spawnPoints = mbRoom:FindFirstChild("MiniChestSpawnPoints")
            if spawnPoints then
                for _, child in ipairs(spawnPoints:GetChildren()) do
                    table.insert(mbMiniPoints, child)
                end
            end
        end
    end)

    for _, obj in ipairs(breakablesFolder:GetChildren()) do
        if obj:IsA("Model") and tonumber(obj.Name) then
            local pivot = obj.WorldPivot and obj.WorldPivot.Position
            if pivot and (pivot - pos).Magnitude < getgenv().SmartFarmState.FarmRange then
                local isBoss = false
                local isMini = false
                local isPriority = false
                
                if mbBossZone then
                    local ptPos = mbBossZone:IsA("BasePart") and mbBossZone.Position or mbBossZone:GetPivot().Position
                    if (pivot - ptPos).Magnitude < 15 then
                        isBoss = true
                    end
                end

                if not isBoss and #mbMiniPoints > 0 then
                    for _, point in ipairs(mbMiniPoints) do
                        local ptPos = point:IsA("BasePart") and point.Position or point:GetPivot().Position
                        if (pivot - ptPos).Magnitude < 15 then
                            isMini = true
                            break
                        end
                    end
                end

                if not isBoss and not isMini then
                    local bId = string.lower(tostring(obj:GetAttribute("BreakableID") or ""))
                    if bId:find("comet") or bId:find("jar") or bId:find("pinata") or bId:find("lucky") or bId:find("mini") or bId:find("boss") or bId:find("chest") then
                        isPriority = true
                    end
                end

                if isBoss then table.insert(targets.bossChest, obj)
                elseif isMini then table.insert(targets.miniChests, obj)
                elseif isPriority then table.insert(targets.priority, obj)
                else table.insert(targets.normal, obj) end
            end
        end
    end
    return targets
end

task.spawn(function()
    while task.wait(getgenv().SmartFarmState.PetAssignInterval) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        local targets = GetBackroomsTargets()
        local allTargets = {}
        
        if #targets.miniChests > 0 then
            for _, v in ipairs(targets.miniChests) do table.insert(allTargets, v) end
        elseif #targets.bossChest > 0 then
            for _, v in ipairs(targets.bossChest) do table.insert(allTargets, v) end
        else
            for _, v in ipairs(targets.priority) do table.insert(allTargets, v) end
            for _, v in ipairs(targets.normal) do table.insert(allTargets, v) end
        end
        
        pcall(function() DistributePets(allTargets) end)
    end
end)

task.spawn(function()
    while task.wait(getgenv().SmartFarmState.AutoTapInterval) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        local targets = GetBackroomsTargets()
        local hitCount = 0
        local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
        local dealDmg = Network and Network:FindFirstChild("Breakables_PlayerDealDamage")
        if dealDmg then
            local function hitGroup(group)
                for _, obj in ipairs(group) do
                    if hitCount >= getgenv().SmartFarmState.MaxTargetsPerTick then return true end
                    dealDmg:FireServer(obj.Name)
                    hitCount = hitCount + 1
                end
                return hitCount >= getgenv().SmartFarmState.MaxTargetsPerTick
            end
            
            if #targets.miniChests > 0 then
                hitGroup(targets.miniChests)
            elseif #targets.bossChest > 0 then
                hitGroup(targets.bossChest)
            else
                if not hitGroup(targets.priority) then
                    hitGroup(targets.normal)
                end
            end
        end
    end
end)

local function CollectOrbs()
    local orbs_container = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Orbs")
    if not orbs_container then return end
    local orbsToCollect = {}
    for _, orb in ipairs(orbs_container:GetChildren()) do
        local orbId = tonumber(orb.Name)
        if orbId then 
            table.insert(orbsToCollect, orbId) 
            orb:Destroy() 
        end
    end
    if #orbsToCollect > 0 then 
        local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
        local remote = Network and Network:FindFirstChild("Orbs: Collect")
        if remote then 
            remote:FireServer(orbsToCollect) 
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        pcall(CollectOrbs)
    end
end)

-- ==========================
-- 📡 EGG ROOM VERİLERİ
-- ==========================
task.spawn(function()
    local Network = ReplicatedStorage:WaitForChild("Network", 5)
    if not Network then return end
    local RequestEggRooms = Network:FindFirstChild("Backrooms: Request Egg Rooms")

    while task.wait(10) do
        if getgenv().Config.FindEggRooms and RequestEggRooms then
            local success, response = pcall(function()
                return RequestEggRooms:InvokeServer()
            end)
            if success and type(response) == "table" then
                TargetEggRooms = {}
                for _, eggData in ipairs(response) do
                    if eggData.UID then
                        TargetEggRooms[eggData.UID] = eggData
                    end
                end
            end
        end
    end
end)

-- ==========================
-- ⚙️ OTO UPGRADE SİSTEMİ
-- ==========================
task.spawn(function()
    while task.wait(5) do
        local config = getgenv().Config
        if not config or not config.AutoUpgrades then continue end
        
        pcall(function()
            local EventUpgradeCmds = require(game:GetService("ReplicatedStorage").Library.Client.EventUpgradeCmds)
            local EventUpgradesDir = require(game:GetService("ReplicatedStorage").Library.Directory.EventUpgrades)
            
            for upgradeId, isEnabled in pairs(config.AutoUpgrades) do
                if isEnabled then
                    local upgradeData = EventUpgradesDir[upgradeId]
                    if upgradeData then
                        local currentTier = EventUpgradeCmds.GetTier(upgradeData)
                        local maxTier = #upgradeData.TierPowers
                        if currentTier < maxTier then
                            EventUpgradeCmds.Purchase(upgradeData)
                            task.wait(0.5) -- İki satın alma arası ufak bekleme süresi
                        end
                    end
                end
            end
        end)
    end
end)

-- ==========================
-- 🔄 FARM ANA DÖNGÜSÜ
-- ==========================
local LastInstanceJoinAttempt = 0

local function IsInBackroomsInstance()
    local container = workspace:FindFirstChild("__THINGS")
    if container then
        local instanceContainer = container:FindFirstChild("__INSTANCE_CONTAINER")
        if instanceContainer and instanceContainer:FindFirstChild("Active") then
            return instanceContainer.Active:FindFirstChild("Backrooms") ~= nil
        end
    end
    return false
end

local function isEggAlive(room)
    -- 1. Süre kontrolü
    local expireTime = room:GetAttribute("EggExpireTimestamp")
    if type(expireTime) == "number" and workspace:GetServerTimeNow() > expireTime then
        return false
    end
    
    -- Streaming Check: Eğer oyuncu odaya çok uzaksa, Roblox modeli bellekten silmiş (unload) olabilir.
    -- Bu yüzden uzaktayken model yok diye yumurtayı "kırıldı" sanmamalıyız.
    local isNear = false
    pcall(function()
        local char = game.Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and (room:IsA("Model") or room:IsA("BasePart")) then
            local dist = (root.Position - room:GetPivot().Position).Magnitude
            if dist < 250 then
                isNear = true
            end
        end
    end)
    
    -- 2. Fiziksel model kontrolü (Workspace.__THINGS.CustomEggs)
    -- YALNIZCA yakındaysak fiziksel modele güvenebiliriz.
    if isNear then
        getgenv()._EggSpawnWaitTime = getgenv()._EggSpawnWaitTime or {}
        
        local eggUID = room:GetAttribute("EggUID")
        if type(eggUID) == "string" then
            local customEggs = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("CustomEggs")
            if customEggs then
                local eggModel = customEggs:FindFirstChild(eggUID)
                if not eggModel then
                    if not getgenv()._EggSpawnWaitTime[eggUID] then
                        getgenv()._EggSpawnWaitTime[eggUID] = os.clock()
                        return true
                    end
                    if os.clock() - getgenv()._EggSpawnWaitTime[eggUID] < 10 then
                        return true -- 10 saniye boyunca yüklenmesi için zaman tanı
                    end
                    return false -- Yakınız ama model 10 saniye boyunca yok = Kırılmış/Silinmiş!
                end
                
                getgenv()._EggSpawnWaitTime[eggUID] = nil -- Model var, sayacı sıfırla
                
                -- Odanın kabuğu (PriceFrame vs) kalmış ama yumurtanın kendisi (MeshPart) kırılıp silinmiş olabilir!
                local actualEgg = eggModel:FindFirstChild("Egg") or eggModel:FindFirstChild("EggLock")
                if not actualEgg then
                    -- Belki farklı bir isme sahiptir (TitanicEgg vs). İçinde herhangi bir part var mı diye bak.
                    local hasPart = false
                    for _, v in ipairs(eggModel:GetChildren()) do
                        if v:IsA("BasePart") then
                            hasPart = true
                            break
                        end
                    end
                    if not hasPart then
                        return false -- Yumurta kırılmış/alınmış!
                    end
                end
            end
        end
    end
    
    return true
end

local function getTargetRoomVector(roomTypeStr, altTypeStr, VisitedRooms, rooms_raw, DeadChestRooms)
    local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    if not invokeCustom then return nil end

    local success, descriptor = pcall(function()
        return invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", getgenv().Config.DeepBackroomsMode)
    end)

    if success and descriptor and type(descriptor) == "table" and descriptor.rooms then
        local t1 = roomTypeStr and string.lower(roomTypeStr)
        local t2 = altTypeStr and string.lower(altTypeStr)
        
        for _, roomInfo in ipairs(descriptor.rooms) do
            local c = string.lower(roomInfo.class or "")
            if (t1 and c:find(t1)) or (t2 and c:find(t2)) then
                local res = descriptor.res or 45
                local x0 = descriptor.x0 or 1
                local y0 = descriptor.y0 or 1
                local rootVec = descriptor.root or Vector3.new(0,0,0)
                
                local centerGridX = roomInfo.x + (roomInfo.w / 2)
                local centerGridY = roomInfo.y + (roomInfo.h / 2)
                
                local worldX = (centerGridX + (x0 - 1)) * res + rootVec.X
                local worldZ = (centerGridY + (y0 - 1)) * res + rootVec.Z
                local targetVec = Vector3.new(worldX, rootVec.Y + 15, worldZ)
                
                -- Kontrol: Bu koordinattaki fiziksel oda VisitedRooms'ta var mı?
                local isVisited = false
                if rooms_raw and VisitedRooms then
                    for _, r in ipairs(rooms_raw) do
                        local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
                        if (pos - targetVec).Magnitude < 300 then
                            local uid = r:GetAttribute("RoomUID")
                            if uid and VisitedRooms[uid] then
                                -- Eger Boss veya Vault odasiysa ve yeniden dogmadiysa visited say!
                                if not DeadChestRooms or not DeadChestRooms[uid] or DeadChestRooms[uid] > workspace:GetServerTimeNow() then
                                    isVisited = true
                                    break
                                end
                            end
                        end
                    end
                end

                if not isVisited then
                    return targetVec
                end
            end
        end
    end
    return nil
end

local function HandleInstanceEntry()
    if IsInBackroomsInstance() then return end
    if os.clock() - LastInstanceJoinAttempt < 60 then return end
    LastInstanceJoinAttempt = os.clock()
    
    getgenv().SmartFarmState.EggRoomUID = nil
    getgenv().SmartFarmState.BossRoomUID = nil
    getgenv().SmartFarmState.BossRespawningUntil = 0
    
    if getgenv().RLW_Window then
        getgenv().RLW_Window:Notify({Title = "🚀 Backrooms", Content = "Auto-joining Backrooms...", Duration = 5})
    end

    pcall(function()
        local InstancingCmds = require(game:GetService("ReplicatedStorage").Library.Client.InstancingCmds)
        if InstancingCmds and InstancingCmds.Enter then
            InstancingCmds.Enter("Backrooms")
        else
            local Network = game:GetService("ReplicatedStorage"):WaitForChild("Network")
            Network:WaitForChild("Instancing_PlayerEnterInstance"):InvokeServer("Backrooms")
        end
    end)
    task.wait(5)
end

task.spawn(function()
    while task.wait(0.2) do

        -- GodMode
        if getgenv().Config.GodMode then
            _G.BACKROOMS_GODMODE = true
            if getrenv then getrenv()._G.BACKROOMS_GODMODE = true end
        else
            _G.BACKROOMS_GODMODE = false
            if getrenv then getrenv()._G.BACKROOMS_GODMODE = false end
        end

        local root = getRootPart()
        if not root then continue end

        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom) then
            continue
        end

        HandleInstanceEntry()

        -- HİBRİT GERİ DÖNÜŞ KONTROLÜ
        local nowTime = workspace:GetServerTimeNow()
        local bossWaitTime = (getgenv().SmartFarmState.BossRespawningUntil or 0) - nowTime
        
        if bossWaitTime > 0 and bossWaitTime <= 8 then
            if getgenv().SmartFarmState.BossRoomUID then
                local rooms = CollectionService:GetTagged("Backrooms")
                local foundBossRoom = nil
                for _, r in ipairs(rooms) do
                    if r:GetAttribute("RoomUID") == getgenv().SmartFarmState.BossRoomUID then
                        foundBossRoom = r
                        break
                    end
                end
                
                if foundBossRoom then
                    if getgenv().RLW_Window then
                        getgenv().RLW_Window:Notify({Title = "⚡ Returning!", Content = "Boss is about to spawn, returning to battle!", Duration = 3})
                    end
                    safeTeleport(foundBossRoom, true)
                    task.wait(2)
                    getgenv().SmartFarmState.BossRespawningUntil = 0
                    getgenv().SmartFarmState.BossRoomUID = nil
                    continue
                else
                    getgenv().SmartFarmState.BossRespawningUntil = 0
                    getgenv().SmartFarmState.BossRoomUID = nil
                end
            end
        end

        -- STATE MACHINE
        local isKeyFarmPhase = false
        local isBossHuntPhase = false
        local isHybridEggPhase = false
        local currentKeys = getDaydreamKeyCount()

        if getgenv().Config.MetaFarmActive then
            if bossWaitTime > 15 and getgenv().Config.FindKeepOutEgg then
                isHybridEggPhase = true
            else
                if currentKeys < getgenv().Config.TargetKeyCount then
                    isKeyFarmPhase = true
                else
                    isBossHuntPhase = true
                end
            end
        else
            -- PARADOX FIX: Sadece Yumurta açık olsa bile, ilerlemek için en az 1 anahtara ihtiyacımız var!
            -- Yoksa kapalı kapılara kafa atıp kısır döngüye girer.
            if getgenv().Config.FindKeepOutEgg and currentKeys == 0 then
                isKeyFarmPhase = true
            end
        end

        local rooms_raw = CollectionService:GetTagged("Backrooms")
        
        -- Eğer oyuncu halihazırda "AÇIK" bir Boss Odasının içindeyse, boşuna anahtar aramaya gitmesin!
        local charPos = getRootPart() and getRootPart().Position or Vector3.zero
        for _, r in ipairs(rooms_raw) do
            local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
            if (pos - charPos).Magnitude < 500 then
                local roomID = string.lower(r:GetAttribute("RoomID") or "")
                local isBoss = roomID:find("bosschest") or roomID:find("minichest") or roomID:find("miniboss") or roomID:find("boss") or roomID:find("gamemaster") or r:GetAttribute("BossChestUID") or r:GetAttribute("ActiveMinichests")
                if isBoss and not r:FindFirstChild("LockedDoors") then
                    isKeyFarmPhase = false
                    isBossHuntPhase = true
                    break
                end
            end
        end
        if #rooms_raw == 0 then
            VisitedRooms = {}
            task.wait(1)
            continue
        end

        local root = getRootPart()
        local charPos = root and root.Position or Vector3.zero

        -- DEEP BACKROOMS GİRİŞ KONTROLÜ
        if getgenv().Config.DeepBackroomsMode then
            local inDeep = false
            pcall(function()
                inDeep = require(game:GetService("ReplicatedStorage").Library.Signal).Invoke("Backrooms_IsInDeep")
            end)
            
            if not inDeep then
                local curtain = CollectionService:GetTagged("DeepCurtainTarget")[1]
                if curtain then
                    local distToCurtain = (charPos - curtain.Position).Magnitude
                    if distToCurtain < 10000 then -- Eğer perdeye nispeten yakınsak (aynı boyuttaysak)
                    local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                    if invokeCustom then
                        pcall(function()
                            invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", 1, "UnlockDeep")
                            task.wait(1)
                            invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", true)
                        end)
                    end
                    
                    if getgenv().RLW_Window then
                        getgenv().RLW_Window:Notify({Title = "🌌 Deep Entry!", Content = "Entering Deep Backrooms...", Duration = 3})
                    end
                    
                    -- Perdeye ışınlanmadan önce ForceField ekle
                    local char = LocalPlayer.Character
                    if char then
                        local ff = Instance.new("ForceField")
                        ff.Visible = false
                        ff.Parent = char
                        task.delay(5, function() if ff then ff:Destroy() end end)
                    end
                    
                    safeTeleport(curtain, true)
                    task.wait(0.5)
                    
                    local currentRoot = getRootPart()
                    if currentRoot then
                        if firetouchinterest then
                            firetouchinterest(currentRoot, curtain, 0)
                            task.wait(0.1)
                            firetouchinterest(currentRoot, curtain, 1)
                        end
                        
                        -- Fırlatma ve içine sokma
                        pcall(function()
                            currentRoot.CFrame = curtain.CFrame * CFrame.new(0, 0, 5)
                            task.wait(0.2)
                            currentRoot.AssemblyLinearVelocity = curtain.CFrame.LookVector * -100
                        end)
                    end
                    
                    task.wait(3)
                    continue -- Yeni boyuta geçtik, döngüyü başa sar
                end
            end
            end -- Missing end for if not inDeep then
        end

        -- MESAFE FİLTRESİ: Deep ile Normal odaların birbirine karışmasını engeller
        -- Karakterden çok uzak olan odaları listeye almayız.
        local rooms = {}
        for _, r in ipairs(rooms_raw) do
            local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
            if (pos - charPos).Magnitude < 20000 then
                table.insert(rooms, r)
            end
        end

        if #rooms == 0 then
            task.wait(1)
            continue
        end

        -- Öncelikli hedef arama (Egg, Boss, Vault, Breakable)
        local bestRoom = nil
        local bestRoomType = 0

        -- RADAR TELEPORT (GOD MODE) ARAMASI
        if getgenv().Config.RadarTeleport then
            local radarTargets = {}
            if isBossHuntPhase then table.insert(radarTargets, {"boss", "gamemaster"}) end
            
            -- KULLANICI ARAYÜZDEN ÖZEL OLARAK AÇARSA KÜÇÜK SANDIKLARA UÇAR
            if isKeyFarmPhase or getgenv().Config.FarmDeepChests then 
                table.insert(radarTargets, {"vault", "chest"}) 
            end
            
            if isHybridEggPhase or getgenv().Config.FindKeepOutEgg then 
                table.insert(radarTargets, {"keepout", "egg"}) 
            end
            
            if getgenv().Config.FarmDeepEvents then
                table.insert(radarTargets, {"chalkboardkeypad", "code"})
                table.insert(radarTargets, {"simonfloor", "deeplaserpattern"})
                table.insert(radarTargets, {"buttons", "colorbutton"})
                table.insert(radarTargets, {"keyforge", "chestchoose"})
                table.insert(radarTargets, {"vending", "garden"})
            end
            
            local teleportedByRadar = false
            local radarFoundBoss = false
            for _, tData in ipairs(radarTargets) do
                local targetClass = tData[1]
                local altClass = tData[2]
                local targetVec = getTargetRoomVector(targetClass, altClass, VisitedRooms, rooms_raw, DeadChestRooms)
                
                if targetVec then
                    if targetClass == "boss" then
                        radarFoundBoss = true
                        getgenv().LiveStats.BossStatus = "Radar Locked 📡"
                    end
                    local currentRoot = getRootPart()
                    if currentRoot then
                        local dist = (currentRoot.Position - targetVec).Magnitude
                        -- Sadece hedeften 300 stud uzaktaysak ışınlan (Sonsuz döngüyü engeller)
                        if dist > 300 then
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "📡 Radar Locked!", Content = "Teleporting to " .. targetClass .. "!", Duration = 2})
                            end
                            currentRoot.CFrame = CFrame.new(targetVec)
                            task.wait(1)
                            teleportedByRadar = true
                            break -- Döngüden çık
                        end
                    end
                end
            end
            
            if teleportedByRadar then
                continue -- Ana loopu başa sar, fiziksel taramayı atla
            end
            
            if isBossHuntPhase and not radarFoundBoss then
                getgenv().LiveStats.BossStatus = "Dead / Waiting Respawn"
            end
        end

        -- 1. ADIM: KAYITLI YUMURTA ODASI KONTROLÜ
        local checkEggCache = isHybridEggPhase or (getgenv().Config.FindKeepOutEgg and not getgenv().Config.MetaFarmActive)
        if checkEggCache and getgenv().SmartFarmState.EggRoomUID then
            for _, room in ipairs(rooms) do
                if room:GetAttribute("RoomUID") == getgenv().SmartFarmState.EggRoomUID then
                    if isEggAlive(room) then
                        bestRoom = room
                        bestRoomType = 4
                    else
                        local deadUID = getgenv().SmartFarmState.EggRoomUID
                        getgenv().SmartFarmState.EggRoomUID = nil -- Yumurta yok olmuş, cache'i temizle
                        DeadEggRooms[deadUID] = os.clock()  -- ✅ cache'i temizlerken de kaydet
                    end
                    break
                end
            end
        end

        -- 2. ADIM: EĞER BULUNAMADIYSA NORMAL ARAMA YAP
        if not bestRoom then
            for _, room in ipairs(rooms) do
                local roomUID = room:GetAttribute("RoomUID")
                
                -- Live Stats: Track Unique Rooms and Highest Multiplier
                if getgenv().LiveStats and roomUID and not getgenv().LiveStats._seenRooms[roomUID] then
                    getgenv().LiveStats._seenRooms[roomUID] = true
                    getgenv().LiveStats.RoomsExplored = getgenv().LiveStats.RoomsExplored + 1
                    
                    local mult = room:GetAttribute("EggMultiplier")
                    local roomID = room:GetAttribute("RoomID") or ""
                    local isFreeEggStats = string.lower(roomID):find("freeegg")
                    
                    if not isFreeEggStats and mult and type(mult) == "number" and mult > getgenv().LiveStats.HighestMultiplier then
                        getgenv().LiveStats.HighestMultiplier = mult
                        
                        local eggName = "Egg"
                        local lowerID = string.lower(roomID)
                        if lowerID:find("keepout") then eggName = "Keep Out"
                        elseif lowerID:find("titanicegg") then eggName = "Titanic"
                        elseif lowerID:find("hugeegg") then eggName = "Huge"
                        else
                            local attr = room:GetAttribute("EggType") or room:GetAttribute("EggName") or room:GetAttribute("Egg")
                            if attr then eggName = tostring(attr) end
                        end
                        getgenv().LiveStats.HighestMultiplierName = eggName
                    end
                end
                
                local roomID = room:GetAttribute("RoomID") or ""
                local lowerID = string.lower(roomID)

                -- TITANIC, KEEPOUT VE DEEP LOCKED EGGLERİ KABUL EDER
                local isEgg = lowerID:find("titanicegg") or lowerID:find("deeplockedegg") or lowerID:find("keepout")
                
                -- ✅ DeadEggRooms kontrolü: cooldown süresi dolmadıysa bu odaya gitme
                if isEgg and DeadEggRooms[roomUID] and (os.clock() - DeadEggRooms[roomUID]) < DEAD_EGG_COOLDOWN then
                    isEgg = false
                end
                
                if isEgg and not isEggAlive(room) then
                    isEgg = false
                    DeadEggRooms[roomUID] = os.clock()  -- ✅ Canlı kontrol başarısız, dead olarak işaretle
                end
                
                -- ARKA PLANDA YUMURTA ODASI KAYDET (Kullanıcı sonradan açarsa diye)
                if isEgg and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end

                local isFreeEgg = lowerID:find("freeegg")
                if isFreeEgg and not isEggAlive(room) then isFreeEgg = false end
                
                -- Multiplier'ı hem FreeEgg hem de Normal (KeepOut vb.) yumurtalar için oku
                local multiplier = tonumber(room:GetAttribute("EggMultiplier")) or 0
                
                local matchSpecificEgg = true
                if getgenv().Config.TargetEggType ~= "Any" then
                    local targetStr = string.lower(string.gsub(getgenv().Config.TargetEggType, " ", ""))
                    local eggAttr = tostring(room:GetAttribute("EggType") or room:GetAttribute("EggName") or room:GetAttribute("Egg") or "")
                    local attrStr = string.lower(string.gsub(eggAttr, " ", ""))
                    if not lowerID:find(targetStr) and not attrStr:find(targetStr) then
                        matchSpecificEgg = false
                    end
                end
                
                local isBoss = lowerID:find("bosschest") or lowerID:find("minichest")
                    or lowerID:find("miniboss") or lowerID:find("boss") or lowerID:find("gamemaster")
                    or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
                local isVault = lowerID:find("vault") or lowerID:find("chest")
                local isBreakable = lowerID:find("breakable")
                
                local isEvent = getgenv().Config.FarmDeepEvents and (
                    lowerID:find("chalkboardkeypad") or lowerID:find("code") or lowerID:find("simonfloor")
                    or lowerID:find("deeplaserpattern") or lowerID:find("buttons") or lowerID:find("colorbutton")
                    or lowerID:find("keyforge") or lowerID:find("chestchoose") or lowerID:find("vending")
                    or lowerID:find("garden")
                )

                -- Event Odası Kontrolü (Type 6) - En yüksek öncelik!
                if isEvent and bestRoomType < 6 then
                    bestRoom = room
                    bestRoomType = 6
                    break
                end

                -- Free Egg Odası Kontrolü (Type 5)
                if getgenv().Config.FindFreeEggRoom and isFreeEgg and matchSpecificEgg and multiplier >= getgenv().Config.TargetEggMultiplier and bestRoomType < 5 then
                    bestRoom = room
                    bestRoomType = 5
                    break
                end

                -- Normal/KeepOut Yumurta Odası Kontrolü (Type 4)
                -- Artık filtreyi geçiyorsa Boss avını bile ezip geçer!
                local shouldFarmEgg = getgenv().Config.FindKeepOutEgg or isHybridEggPhase
                if isEgg then
                    if shouldFarmEgg and matchSpecificEgg and multiplier >= getgenv().Config.TargetEggMultiplier then
                        if bestRoomType < 4 then
                            bestRoom = room
                            bestRoomType = 4
                            break
                        end
                    else
                        -- Filtreyi (Çarpan veya Özel Yumurta Seçimini) geçemeyen bir yumurta odasıysa,
                        -- Chunk Loader'ın bu odaya takılıp sonsuz döngüye girmemesi için "Gezildi" işaretle!
                        VisitedRooms[roomUID] = true
                    end
                end

                if isBossHuntPhase and isBoss and bestRoomType < 3 then
                    bestRoom = room
                    bestRoomType = 3
                    getgenv().LiveStats.BossStatus = "Fighting Boss ⚔️"
                    break
                end

                if isKeyFarmPhase or getgenv().Config.FarmDeepChests then
                    if isVault and bestRoomType < 2 then
                        bestRoom = room
                        bestRoomType = 2
                    elseif isBreakable and bestRoomType < 1 then
                        bestRoom = room
                        bestRoomType = 1
                    end
                end
            end
        end

        -- Öncelikli oda bulundu → direkt işle
        if bestRoom and bestRoomType > 0 then
            local roomUID = bestRoom:GetAttribute("RoomUID")
            local roomID = bestRoom:GetAttribute("RoomID") or ""
            local lowerID = string.lower(roomID)

            local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
            local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")

            -- Kapı açma: Önce ışınlan, streaming yüklenmesini bekle, sonra karar ver
            if fireCustom then
                if bestRoomType == 5 or bestRoomType == 4 then
                    if bestRoom:FindFirstChild("LockedDoors") then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end
                -- Type 3 (Boss): teleport sonrası yükleme beklendiğinde kontrol edilecek
            end

            safeTeleport(bestRoom, false)

            if bestRoomType == 6 then
                local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
                
                if invokeCustom and fireCustom then
                    local roomName = string.lower(bestRoom:GetAttribute("RoomID") or "")
                    
                    if roomName:find("chalkboardkeypad") then
                        local problem = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetProblem")
                        if problem and type(problem) == "string" then
                            local num1, op, num2 = string.match(problem, "(%d+)%s*([%+%-%*%/])%s*(%d+)")
                            if num1 and op and num2 then
                                num1 = tonumber(num1)
                                num2 = tonumber(num2)
                                local ans = 0
                                if op == "+" then ans = num1 + num2
                                elseif op == "-" then ans = num1 - num2
                                elseif op == "*" then ans = num1 * num2
                                elseif op == "/" then ans = num1 / num2 end
                                invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "SubmitAnswer", tostring(ans))
                            end
                        end
                    elseif roomName:find("code") then
                        local code = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetCode")
                        if code then
                            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "Code", code)
                        end
                    elseif roomName:find("simonfloor") then
                        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetSequence")
                        if seq and type(seq) == "table" then
                            for _, step in ipairs(seq) do
                                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "StepTile", step)
                                task.wait(0.1)
                            end
                        end
                    elseif roomName:find("deeplaserpattern") then
                        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetSolutionOrder")
                        if seq and type(seq) == "table" then
                            for _, step in ipairs(seq) do
                                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", step)
                                task.wait(0.1)
                            end
                        end
                    elseif roomName:find("buttons") or roomName:find("colorbutton") then
                        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetCurrentOrder")
                        if seq and type(seq) == "table" then
                            for _, step in ipairs(seq) do
                                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", step)
                                task.wait(0.1)
                            end
                        end
                    elseif roomName:find("keyforge") then
                        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ForgeKey")
                    elseif roomName:find("chestchoose") then
                        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "RedeemChooseChest", 1)
                    elseif roomName:find("vending") then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UseVending")
                    elseif roomName:find("garden") then
                        -- For GardenRoom, just claiming rewards is enough
                    end
                    
                    -- Claim Random Reward if it spawned!
                    task.wait(0.5)
                    local rewards = {}
                    for _, v in ipairs(bestRoom:GetDescendants()) do
                        if v.Name == "RandomReward" and v:IsA("Model") then
                            table.insert(rewards, v)
                        end
                    end
                    for _, rw in ipairs(rewards) do
                        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ClaimRandomReward", rw)
                    end
                    
                    VisitedRooms[roomUID] = true
                    task.wait(1)
                end

            elseif bestRoomType == 5 then
                local mult = bestRoom:GetAttribute("EggMultiplier") or "Bilinmeyen"
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "🎁 Free Egg Room!", Content = mult .. "x Huge Chance room found! Hatching...", Duration = 10, Image = 4483362458})
                end

                -- Yumurta açılış animasyonunu kapat
                pcall(function()
                    local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                    if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
                end)
                
                local Network3 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                local CustomEggsCmds = nil
                pcall(function() CustomEggsCmds = require(game:GetService("ReplicatedStorage").Library.Client.CustomEggsCmds) end)
                
                local buyEggRemote = Network3 and (Network3:FindFirstChild("Eggs_RequestPurchase") or Network3:FindFirstChild("Eggs: RequestPurchase"))
                local customHatchRemote = Network3 and Network3:FindFirstChild("CustomEggs_Hatch")
                
                local maxHatch = 1
                pcall(function() maxHatch = require(game:GetService("ReplicatedStorage").Library.Client.EggCmds).GetMaxHatch() or 1 end)
                
                local BackroomsEggMap = {
                    ["nightmare"] = "Backrooms Nightmare Egg",
                    ["smile"] = "Backrooms Smile Egg",
                    ["flower"] = "Backrooms Flower Egg",
                    ["gooey"] = "Backrooms Gooey Egg",
                    ["scribble"] = "Backrooms Scribble Egg",
                    ["tentacle"] = "Backrooms Tentacles Egg",
                    ["keepout"] = "Backrooms Keep Out Egg",
                    ["nightterror"] = "Backrooms Night Terror Egg",
                    ["fear"] = "Backrooms Fear Egg",
                    ["swirl"] = "Backrooms Swirl Egg",
                    ["overgrown"] = "Backrooms Overgrown Egg",
                    ["ender"] = "Backrooms Ender Egg",
                    ["corrupt"] = "Backrooms Corrupt Egg",
                    ["titanic"] = "Titanic Backrooms Egg",
                    ["huge"] = "Huge Backrooms Egg"
                }

                local eggIdToBuy = "Backrooms Nightmare Egg" -- Default
                for key, eggName in pairs(BackroomsEggMap) do
                    if lowerID:find(key) then
                        eggIdToBuy = eggName
                        break
                    end
                end

                local hasTeleportedToEgg = false
                while getgenv().Config.FindFreeEggRoom do
                    local customUid = nil
                    local eggModel = nil
                    local closestDist = 99999
                    
                    if CustomEggsCmds and getRootPart() then
                        for uid, eggObj in pairs(CustomEggsCmds.All()) do
                            if eggObj._position then
                                local dist = (getRootPart().Position - eggObj._position).Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    customUid = uid
                                    eggModel = eggObj._model
                                end
                            end
                        end
                    end

                    if customUid and customHatchRemote then
                        if not hasTeleportedToEgg and eggModel then
                            getRootPart().CFrame = eggModel:GetPivot() + Vector3.new(0, 5, 0)
                            hasTeleportedToEgg = true
                            task.wait(0.2)
                        end

                        -- ASENKRON SATIN ALMA
                        task.spawn(function()
                            local pcallSuccess, res1, res2
                            if customHatchRemote:IsA("RemoteEvent") then
                                pcallSuccess, res1 = pcall(function() customHatchRemote:FireServer(customUid, maxHatch) end)
                            else
                                pcallSuccess, res1, res2 = pcall(function() return customHatchRemote:InvokeServer(customUid, maxHatch) end)
                            end
                            
                            if not pcallSuccess then
                                warn("[HATCH CRASH] Script çöktü! Hata: " .. tostring(res1))
                            end
                        end)
                    elseif buyEggRemote then
                        local success, err
                        if buyEggRemote:IsA("RemoteEvent") then
                            success, err = pcall(function() buyEggRemote:FireServer(eggIdToBuy, maxHatch) end)
                        else
                            success, err = pcall(function() return buyEggRemote:InvokeServer(eggIdToBuy, maxHatch) end)
                        end
                        if not success then
                            warn("[HATCH ERROR] Eski sistem satın alımı başarısız! Hata: " .. tostring(err))
                        end
                    else
                        warn("[HATCH ERROR] Ne customUid bulundu ne de buyEggRemote!")
                    end
                    task.wait(1.5)
                end

            elseif bestRoomType == 4 then
                if isHybridEggPhase and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end
                
                local Network3 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                if getgenv().RLW_Window then
                    if isHybridEggPhase then
                        getgenv().RLW_Window:Notify({Title = "🥚 Hybrid Egg Farm!", Content = "Hatching eggs until Boss spawns...", Duration = 4})
                    else
                        getgenv().RLW_Window:Notify({Title = "🥚 Secret Egg!", Content = roomID .. " found! Hatching...", Duration = 4})
                    end
                end
                
                -- Yumurta açılış animasyonunu kapat
                pcall(function()
                    local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                    if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
                end)
                
                local CustomEggsCmds = nil
                pcall(function() CustomEggsCmds = require(game:GetService("ReplicatedStorage").Library.Client.CustomEggsCmds) end)
                
                local buyEggRemote = Network3 and (Network3:FindFirstChild("Eggs_RequestPurchase") or Network3:FindFirstChild("Eggs: RequestPurchase"))
                local customHatchRemote = Network3 and Network3:FindFirstChild("CustomEggs_Hatch")
                
                local maxHatch = 1
                pcall(function() maxHatch = require(game:GetService("ReplicatedStorage").Library.Client.EggCmds).GetMaxHatch() or 1 end)
                
                local BackroomsEggMap = {
                    ["nightmare"] = "Backrooms Nightmare Egg",
                    ["smile"] = "Backrooms Smile Egg",
                    ["flower"] = "Backrooms Flower Egg",
                    ["gooey"] = "Backrooms Gooey Egg",
                    ["scribble"] = "Backrooms Scribble Egg",
                    ["tentacle"] = "Backrooms Tentacles Egg",
                    ["keepout"] = "Backrooms Keep Out Egg",
                    ["nightterror"] = "Backrooms Night Terror Egg",
                    ["fear"] = "Backrooms Fear Egg",
                    ["swirl"] = "Backrooms Swirl Egg",
                    ["overgrown"] = "Backrooms Overgrown Egg",
                    ["ender"] = "Backrooms Ender Egg",
                    ["corrupt"] = "Backrooms Corrupt Egg",
                    ["titanic"] = "Titanic Backrooms Egg",
                    ["huge"] = "Huge Backrooms Egg"
                }

                local eggIdToBuy = "Keep Out Egg"
                for key, eggName in pairs(BackroomsEggMap) do
                    if lowerID:find(key) then
                        eggIdToBuy = eggName
                        break
                    end
                end

                local hasTeleportedToEgg = false
                while getgenv().Config.FindKeepOutEgg do
                    local timeNow = workspace:GetServerTimeNow()
                    
                    if isHybridEggPhase then
                        local bossTimer = getgenv().SmartFarmState.BossRespawningUntil or 0
                        local remaining = bossTimer - timeNow
                        
                        -- Eğer bulduğumuz yumurta filtremize uyan nadir bir yumurtaysa, Boss dahi doğsa onu bırakma!
                        local mult = tonumber(bestRoom:GetAttribute("EggMultiplier")) or 0
                        local isPriorityEgg = mult >= getgenv().Config.TargetEggMultiplier
                        
                        if bossTimer > 0 and remaining <= 8 and not isPriorityEgg then
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "⚔️ Boss Time!", Content = "Leaving normal egg for Boss spawn!", Duration = 3})
                            end
                            break
                        end
                    end
                    
                    if not isEggAlive(bestRoom) then
                        getgenv().SmartFarmState.EggRoomUID = nil
                        VisitedRooms[roomUID] = true
                        if getgenv().RLW_Window then
                            getgenv().RLW_Window:Notify({Title = "👻 Egg Vanished!", Content = "The egg has hatched or expired. Finding a new room!", Duration = 3})
                        end
                        break
                    end
                    
                    local customUid = nil
                    local eggModel = nil
                    local closestDist = 99999
                    
                    if CustomEggsCmds and getRootPart() then
                        for uid, eggObj in pairs(CustomEggsCmds.All()) do
                            if eggObj._position then
                                local dist = (getRootPart().Position - eggObj._position).Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    customUid = uid
                                    eggModel = eggObj._model
                                end
                            end
                        end
                    end

                    if customUid and customHatchRemote then
                        if not hasTeleportedToEgg and eggModel then
                            getRootPart().CFrame = eggModel:GetPivot() + Vector3.new(0, 5, 0)
                            hasTeleportedToEgg = true
                            task.wait(0.2)
                        end

                        -- ASENKRON SATIN ALMA: Sunucunun 60 saniye bekletmesini engellemek için task.spawn eklendi!
                        task.spawn(function()
                            local pcallSuccess, res1, res2
                            if customHatchRemote:IsA("RemoteEvent") then
                                pcallSuccess, res1 = pcall(function() customHatchRemote:FireServer(customUid, maxHatch) end)
                            else
                                pcallSuccess, res1, res2 = pcall(function() return customHatchRemote:InvokeServer(customUid, maxHatch) end)
                            end
                            
                            if not pcallSuccess then
                                warn("[HATCH CRASH] Script çöktü! Hata: " .. tostring(res1))
                            elseif customHatchRemote:IsA("RemoteFunction") and res1 == false then
                                -- print("[HATCH REJECTED] Sunucu reddetti (Cooldown/Spam): " .. tostring(res2))
                            else
                                -- print("[HATCH SUCCESS] İstek başarıyla işlendi.")
                            end
                        end)
                    elseif buyEggRemote then
                        local success, err
                        if buyEggRemote:IsA("RemoteEvent") then
                            success, err = pcall(function() buyEggRemote:FireServer(eggIdToBuy, maxHatch) end)
                        else
                            success, err = pcall(function() return buyEggRemote:InvokeServer(eggIdToBuy, maxHatch) end)
                        end
                        if not success then
                            warn("[HATCH ERROR] Eski sistem satın alımı başarısız! Hata: " .. tostring(err))
                        end
                    else
                        warn("[HATCH ERROR] Ne customUid bulundu ne de buyEggRemote!")
                    end
                    task.wait(1.5)
                end

            elseif bestRoomType == 3 then
                -- ✅ Boss odasına ışınlandık. Şimdi streaming yüklenmesini bekleyip kapı durumunu kontrol ediyoruz.
                task.wait(2.5) -- Streaming yüklenmesi için yeterli süre

                local isAlreadyOpen = not bestRoom:FindFirstChild("LockedDoors")
                local hasBoss = bestRoom:GetAttribute("BossChestUID") or bestRoom:GetAttribute("ActiveMinichests")

                if isAlreadyOpen and hasBoss then
                    -- Door is already open! Camping without spending a key.
                    if getgenv().RLW_Window then
                        getgenv().RLW_Window:Notify({
                            Title = "🎯 Open Boss Room!",
                            Content = "Door is already open, no keys spent! Camping...",
                            Duration = 6
                        })
                    end
                elseif bestRoom:FindFirstChild("LockedDoors") then
                    -- Door closed, spend key.
                    local Network2 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                    local fireCustom2 = Network2 and Network2:FindFirstChild("Instancing_FireCustomFromClient")
                    if fireCustom2 then
                        fireCustom2:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                else
                    -- Kapı yok ama boss da yok, normal Boss Odası belki boş
                end

                -- Her iki durumda da odada kal ve kamp kur
                local isWaitingRespawn = false
                local notifiedRespawn = false
                while getgenv().Config.MetaFarmActive do
                    task.wait(1)
                    local respawnTs = nil
                    pcall(function() respawnTs = bestRoom:GetAttribute("RespawnTimestamp") end)
                    local now = workspace:GetServerTimeNow()
                    if respawnTs and respawnTs > now then
                        local remaining = math.ceil(respawnTs - now)
                        
                        -- HİBRİT KONTROL: Eğer doğmasına 15 saniyeden fazla varsa odadan ayrıl ve yumurta ara!
                        if remaining > 15 and getgenv().Config.FindKeepOutEgg then
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "🚀 Hybrid Mode Active!", Content = "Farming eggs while waiting for Boss...", Duration = 5})
                            end
                            getgenv().SmartFarmState.BossRespawningUntil = respawnTs
                            getgenv().SmartFarmState.BossRoomUID = roomUID
                            VisitedRooms[roomUID] = true -- Aramayı boss odasına kitlememesi için
                            break -- Döngüden çık, main döngü Egg bulacak!
                        end

                        -- HOP ON BOSS COOLDOWN KONTROL: Eğer boss ölü ise sunucu değiştir!
                        if getgenv().Config.HopOnBossCooldown then
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "🚀 Server Hopping!", Content = "Boss is on cooldown. Finding a new server...", Duration = 5})
                            end
                            local HttpService = game:GetService("HttpService")
                            local TeleportService = game:GetService("TeleportService")
                            local req = request or http_request or (syn and syn.request)
                            if req then
                                pcall(function()
                                    local servers = req({Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"}).Body
                                    local decoded = HttpService:JSONDecode(servers)
                                    if decoded and decoded.data then
                                        for _, v in pairs(decoded.data) do
                                            if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                                                TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, game.Players.LocalPlayer)
                                                break
                                            end
                                        end
                                    end
                                end)
                            end
                            task.wait(5) -- Hop atana kadar bekle
                            continue -- Alt işlemlere inmeden döngüyü yeniden başa sar (veya kır)
                        end

                        if not isWaitingRespawn then
                            isWaitingRespawn = true
                            notifiedRespawn = false
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "⏳ Boss Dead!", Content = "Respawning in " .. remaining .. " seconds. Waiting...", Duration = 5})
                            end
                            if getgenv().LiveStats then getgenv().LiveStats.BossesKilled = getgenv().LiveStats.BossesKilled + 1 end
                        end
                        local waitTime = math.max(respawnTs - workspace:GetServerTimeNow() - 1, 0)
                        if waitTime > 2 then task.wait(waitTime) end
                    else
                        if isWaitingRespawn and not notifiedRespawn then
                            notifiedRespawn = true
                            isWaitingRespawn = false
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({Title = "⚔️ Boss Respawned!", Content = "Attacking...", Duration = 3})
                            end
                        end
                    end
                end

            elseif bestRoomType == 1 or bestRoomType == 2 then
                local label = bestRoomType == 2 and "🏦 Vault/Chest Odası" or "⛏️ Breakable Oda"
                -- print("[SİSTEM] " .. label .. " bulundu: " .. roomID)
                local emptySeconds = 0
                local bigCheckTimer = 0
                
                while getgenv().Config.MetaFarmActive do
                    task.wait(1)
                    local currentKeys = getDaydreamKeyCount()
                    if currentKeys >= getgenv().Config.TargetKeyCount then
                        -- print("[SİSTEM] 🎯 Hedef anahtara ulaşıldı! Boss Avına geçiliyor.")
                        break
                    else
                        -- print("[FARM] ⏳ Anahtar: " .. currentKeys .. "/" .. getgenv().Config.TargetKeyCount)
                    end

                    local breakablesExist = false
                    local foundBig = false
                    local breakablesFolder = workspace:FindFirstChild("__THINGS")
                        and workspace.__THINGS:FindFirstChild("Breakables")
                        
                    if breakablesFolder then
                        local pos = getRootPart() and getRootPart().Position or Vector3.new(0,0,0)
                        for _, b in ipairs(breakablesFolder:GetChildren()) do
                            local part = b:FindFirstChild("Hitbox")
                                or (b:IsA("Model") and b.PrimaryPart)
                                or b:FindFirstChildWhichIsA("BasePart")
                                
                            if part and (part.Position - pos).Magnitude < 150 then
                                breakablesExist = true
                                
                                -- Büyüklük/Değer kontrolü (Sağlam/Büyük objeler)
                                local bName = string.lower(b.Name)
                                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                                local health = b:GetAttribute("MaxHealth") or b:GetAttribute("Health") or 0
                                
                                if health > 200 or bId:find("chest") or bId:find("vault") or bId:find("giant") or bId:find("huge") or bId:find("big") or bName:find("chest") then
                                    foundBig = true
                                end
                            end
                        end
                    end
                    
                    bigCheckTimer = bigCheckTimer + 1
                    if bigCheckTimer == 3 and not foundBig then
                        -- print("[FARM] ❌ Bu odada sadece KÜÇÜK eşyalar var! Büyük kasa/eşya olan başka odaya geçiliyor...")
                        VisitedRooms[roomUID] = true
                        break
                    end

                    if not breakablesExist then
                        emptySeconds = emptySeconds + 1
                        if emptySeconds >= 4 then
                            -- print("[FARM] ⚠️ Oda boşaldı! Yeni odaya geçiliyor...")
                            VisitedRooms[roomUID] = true
                            break
                        end
                    else
                        emptySeconds = 0
                    end
                end
            end

            continue -- Bir sonraki döngü turuna geç
        end

        -- Öncelikli oda bulunamadı → haritayı genişlet (en uzak odaya zıpla)
        local sortedRooms = {}
        local isEggSearchMode = isHybridEggPhase or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom
        for _, room in ipairs(rooms) do
            local uid = room:GetAttribute("RoomUID")
            if not VisitedRooms[uid] then
                -- ✅ Egg arama modundayken ölü egg odalarını sortedRooms'a ekleme (paradoks önleme)
                if isEggSearchMode and DeadEggRooms[uid] and (os.clock() - DeadEggRooms[uid]) < DEAD_EGG_COOLDOWN then
                    continue
                end
                local pos = room:IsA("Model") and room:GetPivot().Position or Vector3.new(0,0,0)
                local charPos = getRootPart() and getRootPart().Position or Vector3.zero
                table.insert(sortedRooms, {Room = room, Dist = (pos - charPos).Magnitude, UID = uid})
            end
        end

        table.sort(sortedRooms, function(a, b) return a.Dist > b.Dist end)

        if #sortedRooms == 0 then
            if visitedCount > 300 and getgenv().Config.HopOnBossCooldown then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "🚀 Dead Server!", Content = "Map fully explored. Hopping servers...", Duration = 5})
                end
                pcall(function()
                    local HttpService = game:GetService("HttpService")
                    local TeleportService = game:GetService("TeleportService")
                    local req = request or http_request or (syn and syn.request)
                    if req then
                        local servers = req({Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"}).Body
                        local decoded = HttpService:JSONDecode(servers)
                        if decoded and decoded.data then
                            for _, v in pairs(decoded.data) do
                                if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                                    TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, game.Players.LocalPlayer)
                                    break
                                end
                            end
                        end
                    end
                end)
                task.wait(5)
            end
            
            VisitedRooms = {}
            visitedCount = 0
            -- ✅ DeadEggRooms'u da temizle! Yeni oda gelmediyse, eski "ölü" odaları da tekrar dene.
            -- Aksi halde script 5 dakika boyunca boşta döngüye girer!
            if isHybridEggPhase or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom then
                DeadEggRooms = {}
                getgenv()._EggSpawnWaitTime = {}
                task.wait(3)
            else
                task.wait(1)
            end
            continue
        end

        local isSearchingOnly = isBossHuntPhase or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom

        -- Sadece EN UZAK odaya zıpla (1 oda per döngü)
        local roomData = sortedRooms[1]
        local room = roomData.Room
        local roomUID = roomData.UID
        -- PARADOX FİX 2: Odanın merkezine zıplamak, devasa odalarda sunucunun (server) yeni odaları yüklemesi için
        -- gereken yakınlık (proximity) şartını sağlamayabilir. Bu yüzden karakteri odanın tüm sınır hatlarına sürtüyoruz.
        local edgeParts = {}
        local namesToFind = {"door", "exit", "entrance", "portal", "hallway", "corridor"}
        for _, part in ipairs(room:GetDescendants()) do
            if part:IsA("BasePart") then
                local pName = string.lower(part.Name)
                for _, n in ipairs(namesToFind) do
                    if pName:find(n) then
                        table.insert(edgeParts, part)
                        break
                    end
                end
            end
        end
        
        if #edgeParts > 0 then
            -- Bulunan çıkış noktalarına mikro ışınlanma yap (Max 5 nokta)
            for i = 1, math.min(5, #edgeParts) do
                safeTeleport(edgeParts[i], true)
                task.wait(0.65)
            end
        elseif room:IsA("Model") then
            -- Eğer belirgin bir çıkış noktası yoksa odanın 4 köşesine (sınırlarına) zıpla
            local pivot = room:GetPivot()
            local size = room:GetExtentsSize()
            local halfX, halfZ = size.X / 2, size.Z / 2
            
            local offsets = {
                Vector3.new(halfX, 0, 0),
                Vector3.new(-halfX, 0, 0),
                Vector3.new(0, 0, halfZ),
                Vector3.new(0, 0, -halfZ)
            }
            
            for _, offset in ipairs(offsets) do
                local root = getRootPart()
                if root then
                    root.CFrame = pivot * CFrame.new(offset)
                    task.wait(0.15)
                end
            end
        end
        
        -- Oda taramasına devam etmek için merkeze geri dön
        safeTeleport(room, isSearchingOnly)

        local roomID = room:GetAttribute("RoomID") or ""
        local lowerID = string.lower(roomID)


        local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
        local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
        local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")

        if fireCustom then
            if room:FindFirstChild("LockedDoors") then
                local isUnlocked = false
                for _, door in ipairs(room.LockedDoors:GetChildren()) do
                    if door:GetAttribute("HasConnection") then
                        local lock = door:FindFirstChild("Lock")
                        if lock and lock.Transparency == 1 then
                            isUnlocked = true
                            break
                        end
                    end
                end

                if not isUnlocked then
                    local isBossRoom = lowerID:find("bosschest") or lowerID:find("minichest")
                        or lowerID:find("miniboss") or lowerID:find("boss")
                        or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
                    local isEggRoom = lowerID:find("titanicegg") or lowerID:find("hugeegg") or lowerID:find("egg") or lowerID:find("keepout")

                    local shouldUnlock = false

                    if isBossHuntPhase and isBossRoom then
                        shouldUnlock = true
                    elseif (getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom or isHybridEggPhase) and isEggRoom then
                        shouldUnlock = true
                    else
                        -- ANAHTAR TASARRUFU GÜNCELLEMESİ:
                        -- Gidilebilecek açık odalar varken boşuna anahtar harcama!
                        -- Sadece haritada başka gidilecek yer kalmadığında (darboğaz) yeni kapı aç.
                        if #sortedRooms <= 2 then
                            shouldUnlock = true
                        end
                    end

                    if shouldUnlock then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end
            end

            -- ChestChoose
            if lowerID:find("chestchoose") then
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "PickChest", 1)
            end

            -- Buttons
            local buttons = room:FindFirstChild("Buttons")
            if buttons then
                for _, btn in ipairs(buttons:GetChildren()) do
                    local num = tonumber(btn.Name) or tonumber(string.match(btn.Name, "%d+"))
                    if num then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", num)
                    end
                end
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed")
            end

            -- Levers
            local levers = room:FindFirstChild("Levers")
            if levers then
                for _, lever in ipairs(levers:GetChildren()) do
                    local num = tonumber(lever.Name) or tonumber(string.match(lever.Name, "%d+"))
                    if num then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "FlipLever", num)
                    end
                end
            end

            -- Faucets
            local faucets = room:FindFirstChild("Faucets")
            if faucets then
                for _, faucet in ipairs(faucets:GetChildren()) do
                    local num = tonumber(faucet.Name) or tonumber(string.match(faucet.Name, "%d+"))
                    if num then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "FaucetTurned", num)
                    end
                end
            end
        end

        -- AutoLoot
        if getgenv().Config.AutoLoot and invokeCustom then
            for _, obj in ipairs(room:GetChildren()) do
                if obj.Name:find("RandomReward") and obj:IsA("Model") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        safeTeleport(part, false)
                        task.wait(0.2)
                        pcall(function()
                            invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ClaimRandomReward", obj)
                        end)
                    end
                end
            end
        end

        -- ProximityPrompt tetikleme
        for _, prompt in ipairs(room:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local parentPart = prompt.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    safeTeleport(parentPart, false)
                    task.wait(0.1)
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.1)
                        prompt:InputHoldEnd()
                    end
                end
            end
        end

        if not VisitedRooms[roomUID] then
            VisitedRooms[roomUID] = true
            visitedCount = visitedCount + 1
        end

        if visitedCount > 500 then
            VisitedRooms = {}
            visitedCount = 0
        end

    end -- while döngüsü sonu
end)

-- ==========================
-- 🥚 AUTO HATCH NEAREST LOOP
-- ==========================
task.spawn(function()
    local CustomEggsCmds = nil
    pcall(function() CustomEggsCmds = require(game:GetService("ReplicatedStorage").Library.Client.CustomEggsCmds) end)
    
    local Network = game:GetService("ReplicatedStorage"):WaitForChild("Network")
    local customHatchRemote = Network:WaitForChild("CustomEggs_Hatch", 5)

    while task.wait(1) do
        if getgenv().Config.AutoHatchNearest and customHatchRemote and CustomEggsCmds then
            local root = getRootPart()
            if not root then continue end
            
            local customUid = nil
            local closestDist = 99999
            
            for uid, eggObj in pairs(CustomEggsCmds.All()) do
                if eggObj._position then
                    local dist = (root.Position - eggObj._position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        customUid = uid
                    end
                end
            end
            
            if customUid then
                -- Yumurta animasyonunu kapat
                pcall(function()
                    local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                    if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
                end)

                local maxHatch = 1
                pcall(function() maxHatch = require(game:GetService("ReplicatedStorage").Library.Client.EggCmds).GetMaxHatch() or 1 end)
                
                task.spawn(function()
                    if customHatchRemote:IsA("RemoteEvent") then
                        customHatchRemote:FireServer(customUid, maxHatch)
                    else
                        pcall(function() customHatchRemote:InvokeServer(customUid, maxHatch) end)
                    end
                end)
            end
        end
    end
end)

-- ==========================
-- 🎨 RLW UI
-- ==========================
local RLW_Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/therlw/rlwscripts/refs/heads/main/RLW_UILib.lua'))()

local Window = RLW_Library:CreateWindow({
    Title = "RLW",
    Subtitle = "</> SCRIPTS",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RLWSCRIPTS",
        FileName = "BackroomsConfig"
    }
})
getgenv().RLW_Window = Window

local TabAutoFarm = Window:CreateTab("⚔️ Auto Farm")
local TabEggs = Window:CreateTab("🥚 Egg Hunter")
local TabStats = Window:CreateTab("📊 Live Stats")
local TabScanner = Window:CreateTab("📡 Scanner")
local TabMailbox = Window:CreateTab("📬 Mailbox")
local TabUpgrades = Window:CreateTab("🆙 Upgrades")
local TabWebhook = Window:CreateTab("🔔 Webhook")
local TabSettings = Window:CreateTab("⚙️ Settings")

-- 📊 LIVE STATS TAB --
TabStats:CreateSection("Session Information")

local lblTime = TabStats:CreateLabel({Name = "⏱️ Session Time", CurrentValue = "00:00:00"})
local lblRooms = TabStats:CreateLabel({Name = "🚪 Rooms Explored", CurrentValue = "0", Color = Color3.fromRGB(150, 150, 255)})
local lblHighest = TabStats:CreateLabel({Name = "🚀 Highest Multiplier", CurrentValue = "0x", Color = Color3.fromRGB(255, 215, 0)})
local lblBosses = TabStats:CreateLabel({Name = "⚔️ Bosses Defeated", CurrentValue = "0", Color = Color3.fromRGB(255, 100, 100)})
local lblBossStatus = TabStats:CreateLabel({Name = "👁️ Boss Radar", CurrentValue = "Searching...", Color = Color3.fromRGB(200, 200, 200)})

-- Sayaç Loop
task.spawn(function()
    while task.wait(1) do
        if not getgenv().LiveStats then continue end
        local elapsed = os.time() - getgenv().LiveStats.StartTime
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)
        
        pcall(function()
            if lblTime and lblTime.SetText then lblTime:SetText(timeStr) end
            if lblRooms and lblRooms.SetText then lblRooms:SetText(tostring(getgenv().LiveStats.RoomsExplored)) end
            if lblHighest and lblHighest.SetText then 
                local multStr = tostring(getgenv().LiveStats.HighestMultiplier) .. "x"
                if getgenv().LiveStats.HighestMultiplierName then
                    multStr = multStr .. " (" .. getgenv().LiveStats.HighestMultiplierName .. ")"
                end
                lblHighest:SetText(multStr) 
            end
            if lblBosses and lblBosses.SetText then lblBosses:SetText(tostring(getgenv().LiveStats.BossesKilled)) end
            if lblBossStatus and lblBossStatus.SetText then lblBossStatus:SetText(getgenv().LiveStats.BossStatus) end
        end)
    end
end)

-- ⚔️ AUTO FARM TAB --
TabAutoFarm:CreateSection("Standalone Farm")

TabAutoFarm:CreateToggle({
    Name = "🌌 Deep Backrooms Mode",
    CurrentValue = getgenv().Config.DeepBackroomsMode,
    Flag = "Tgl_DeepBackroomsMode",
    Callback = function(Value)
        getgenv().Config.DeepBackroomsMode = Value
        if Value and getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "🌌 Deep Mode", Content = "Script will auto-pay 1.25M to enter Deep Backrooms!", Duration = 5})
        end
    end
})

TabAutoFarm:CreateToggle({
    Name = "🚀 BETA: Map Radar Teleport (God Mode)",
    CurrentValue = getgenv().Config.RadarTeleport,
    Flag = "Tgl_RadarTeleport",
    Callback = function(Value)
        getgenv().Config.RadarTeleport = Value
        if Value and getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "⚠️ WARNING", Content = "Radar Teleport bypasses physics! It will teleport you instantly.", Duration = 5})
        end
    end
})

TabAutoFarm:CreateToggle({
    Name = "⚡ Fast Farm Breakables",
    CurrentValue = false,
    Flag = "Tgl_FastFarm",
    Callback = function(Value)
        getgenv().Config.FastFarmBreakables = Value
    end
})

TabAutoFarm:CreateSection("Phase 1: Smart Loop (Meta)")

TabAutoFarm:CreateToggle({
    Name = "Start Boss Farming",
    CurrentValue = false,
    Flag = "Tgl_MetaFarm",
    Callback = function(Value)
        getgenv().Config.MetaFarmActive = Value
        if Value and getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "Boss Farming", Content = "Farming keys, then hunting Boss!", Duration = 5})
        end
    end
})

TabAutoFarm:CreateToggle({
    Name = "✅ Always Farm Chest/Vault Rooms",
    CurrentValue = false,
    Flag = "Tgl_FarmDeepChests",
    Callback = function(Value)
        getgenv().Config.FarmDeepChests = Value
    end
})

TabAutoFarm:CreateToggle({
    Name = "🧩 Auto-Complete Deep Events",
    CurrentValue = false,
    Flag = "Tgl_FarmDeepEvents",
    Callback = function(Value)
        getgenv().Config.FarmDeepEvents = Value
    end
})

TabAutoFarm:CreateToggle({
    Name = "🚀 Hop on Boss Cooldown",
    CurrentValue = false,
    Flag = "Tgl_HopOnBossCooldown",
    Callback = function(Value)
        getgenv().Config.HopOnBossCooldown = Value
    end
})

TabAutoFarm:CreateSlider({
    Name = "Target Key Count (For Boss)",
    Range = {1, 100}, 
    CurrentValue = 5,
    Flag = "Sld_TargetKeys",
    Callback = function(Value) getgenv().Config.TargetKeyCount = Value end
})

TabAutoFarm:CreateToggle({
    Name = "💰 Always Farm Chest/Vault Rooms",
    CurrentValue = false,
    Flag = "Tgl_FarmDeepChests",
    Callback = function(Value)
        getgenv().Config.FarmDeepChests = Value
    end
})

TabAutoFarm:CreateToggle({
    Name = "Auto Loot Chests/Rewards",
    CurrentValue = false,
    Flag = "Tgl_AutoLoot",
    Callback = function(Value) getgenv().Config.AutoLoot = Value end
})


-- 🥚 EGG HUNTER TAB --
TabEggs:CreateSection("Auto Hatch (No Teleport)")

TabEggs:CreateToggle({
    Name = "🥚 Auto Hatch Nearest Egg",
    CurrentValue = false,
    Flag = "Tgl_AutoHatchNearest",
    Callback = function(Value)
        getgenv().Config.AutoHatchNearest = Value
    end
})

TabEggs:CreateSection("Phase 2: Hybrid Egg (Optional)")

TabEggs:CreateToggle({
    Name = "🥚 Auto Titanic Egg (Keep Out)",
    CurrentValue = false,
    Flag = "Tgl_KeepOutEgg",
    Callback = function(Value)
        getgenv().Config.FindKeepOutEgg = Value
    end
})

TabEggs:CreateToggle({
    Name = "🎁 Find Free Egg Room",
    CurrentValue = false,
    Flag = "Tgl_FreeEgg",
    Callback = function(Value)
        getgenv().Config.FindFreeEggRoom = Value
    end
})

TabEggs:CreateDropdown({
    Name = "🥚 Target Specific Egg",
    Options = {"Any", "Nightmare", "Smile", "Flower", "Gooey", "Scribble", "Tentacles", "Keep Out", "Night Terror", "Fear", "Swirl", "Overgrown", "Ender", "Corrupt", "Titanic", "Huge", "Heart", "Balloon", "Rain", "Eyes", "Danger"},
    CurrentOption = {"Any"},
    Flag = "Drp_SpecificEgg",
    Callback = function(Option)
        getgenv().Config.TargetEggType = Option[1]
    end,
})

TabEggs:CreateDropdown({
    Name = "🎯 Target Egg Multiplier",
    Options = {"2x", "3x", "5x", "10x", "15x", "20x", "25x", "30x", "35x", "40x", "45x", "50x", "75x", "100x", "250x"},
    CurrentOption = {"50x"},
    Flag = "Drp_Multiplier",
    Callback = function(Option)
        local val = string.gsub(Option[1], "x", "")
        getgenv().Config.TargetEggMultiplier = tonumber(val) or 50
    end,
})

-- ⚙️ SETTINGS TAB --
TabSettings:CreateSection("Speed & Safety Settings")

TabSettings:CreateSlider({
    Name = "Teleport Delay (Speed)",
    Range = {0, 3},
    CurrentValue = 0,
    Flag = "Sld_Teleport",
    Callback = function(Value) getgenv().Config.TeleportDelay = Value end
})

TabSettings:CreateToggle({
    Name = "God Mode (Invincibility)",
    CurrentValue = false,
    Flag = "Tgl_GodMode",
    Callback = function(Value) getgenv().Config.GodMode = Value end
})

-- 🆙 UPGRADES TAB --
TabUpgrades:CreateSection("Backrooms Upgrades (Tokens)")

TabUpgrades:CreateToggle({
    Name = "Auto Boss Damage",
    CurrentValue = false,
    Flag = "Tgl_UpgBossDamage",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsBossDamage = Value
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Extra Loot Roll",
    CurrentValue = false,
    Flag = "Tgl_UpgExtraLoot",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsExtraLootRoll = Value
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Token Find",
    CurrentValue = false,
    Flag = "Tgl_UpgTokenFind",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsTokenFind = Value
    end
})

-- 🔔 WEBHOOK TAB --

TabUpgrades:CreateSection("Deep Chest Upgrades")

TabUpgrades:CreateToggle({
    Name = "Auto Deep Boss Damage",
    CurrentValue = false,
    Flag = "Tgl_UpgDeepBossDmg",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsDeepBossDamage = Value
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Coin Multiplier",
    CurrentValue = false,
    Flag = "Tgl_UpgDeepCoinMult",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsCoinMultiplier = Value
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Egg Luck",
    CurrentValue = false,
    Flag = "Tgl_UpgDeepEggLuck",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsEggLuck = Value
    end
})

TabUpgrades:CreateToggle({
    Name = "Auto Key Find",
    CurrentValue = false,
    Flag = "Tgl_UpgDeepKeyFind",
    Callback = function(Value)
        getgenv().Config.AutoUpgrades.BackroomsKeyFind = Value
    end
})
TabWebhook:CreateSection("Discord Notifications (Huge/Titanic)")

TabWebhook:CreateToggle({
    Name = "Enable Discord Webhook",
    CurrentValue = false,
    Flag = "Tgl_Webhook",
    Callback = function(Value)
        getgenv().Config.WebhookEnabled = Value
    end
})

TabWebhook:CreateInput({
    Name = "Discord Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Flag = "Inp_WebhookURL",
    Callback = function(Text)
        getgenv().Config.WebhookURL = Text
    end,
})

TabWebhook:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if not getgenv().Config.WebhookEnabled then
            if getgenv().RLW_Window then
                getgenv().RLW_Window:Notify({Title = "Error", Content = "Please enable the Webhook toggle first!", Duration = 3})
            end
            return
        end
        if getgenv().Config.WebhookURL == "" then
            if getgenv().RLW_Window then
                getgenv().RLW_Window:Notify({Title = "Error", Content = "Please enter a valid Webhook URL!", Duration = 3})
            end
            return
        end
        SendWebhook("✅ Webhook Test Successful!", "Your Webhook is working perfectly.\nYou will receive Huge and Titanic notifications here.", 0x00ff00)
        if getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "Success", Content = "Test message sent to your Discord!", Duration = 3})
        end
    end
})

-- 📡 SCANNER TAB --
TabScanner:CreateSection("Room Radar")

local scannedRoomsList = {}
local scannedRoomsMap = {}

local ScannerDropdown = TabScanner:CreateDropdown({
    Name = "Scanned Rooms (Click to TP)",
    Options = {"[Waiting for scan...]"},
    CurrentOption = {"[Waiting for scan...]"},
    Flag = "Drp_ScannerList",
    Callback = function(Option)
        local optStr = Option[1]
        if optStr == "[Waiting for scan...]" or optStr == "[No rooms found!]" then return end
        
        -- Extract UID
        local uid = string.match(optStr, "UID: ([%w%-]+)")
        if uid and scannedRoomsMap[uid] then
            local targetRoom = scannedRoomsMap[uid]
            if targetRoom and targetRoom.Parent then
                safeTeleport(targetRoom, true)
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "Teleported", Content = "Teleported to the selected room!", Duration = 3})
                end
            else
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "Error", Content = "Room no longer exists (despawned)!", Duration = 3})
                end
            end
        end
    end,
})

TabScanner:CreateButton({
    Name = "🔍 Scan All Rooms",
    Callback = function()
        scannedRoomsList = {}
        scannedRoomsMap = {}
        
        local rooms = CollectionService:GetTagged("Backrooms")
        for _, room in ipairs(rooms) do
            local roomUID = room:GetAttribute("RoomUID")
            local roomID = room:GetAttribute("RoomID") or "Unknown"
            local lowerID = string.lower(roomID)
            
            if not roomUID then continue end
            
            -- Sadece Boss ve Yumurta odalarını göster (Breakable ve Vault'lar çok kalabalık yapar)
            local isEgg = lowerID:find("keepout") or lowerID:find("hugeegg") or lowerID:find("titanicegg") or lowerID:find("freeegg")
            local isBoss = lowerID:find("boss") or lowerID:find("minichest")
            
            if isEgg or isBoss then
                local label = roomID
                
                if isEgg then
                    if not isEggAlive(room) then
                        label = "💀 [DEAD] " .. label
                    else
                        local eggType = room:GetAttribute("EggType") or room:GetAttribute("EggName")
                        if eggType then label = label .. " (" .. tostring(eggType) .. ")" end
                        
                        local multiplier = room:GetAttribute("EggMultiplier")
                        if multiplier then label = "[" .. tostring(multiplier) .. "x] " .. label end
                    end
                elseif isBoss then
                    label = "👹 " .. label
                end
                
                label = label .. " (UID: " .. tostring(roomUID) .. ")"
                table.insert(scannedRoomsList, label)
                scannedRoomsMap[tostring(roomUID)] = room
            end
        end
        
        if #scannedRoomsList == 0 then
            table.insert(scannedRoomsList, "[No rooms found!]")
        end
        
        if ScannerDropdown and ScannerDropdown.RefreshOptions then
            ScannerDropdown:RefreshOptions(scannedRoomsList)
            if getgenv().RLW_Window then
                getgenv().RLW_Window:Notify({Title = "Scan Complete", Content = "Found " .. tostring(#scannedRoomsList) .. " interesting rooms!", Duration = 3})
            end
        end
    end
})

-- 📬 MAILBOX TAB --
TabMailbox:CreateSection("Mailbox Automation")
TabMailbox:CreateToggle({
    Name = "Auto Claim Mailbox",
    CurrentValue = false,
    Flag = "Tgl_AutoMailbox",
    Callback = function(Value)
        getgenv().Config.AutoMailbox = Value
    end
})

task.spawn(function()
    while task.wait(30) do
        if not getgenv().Config.AutoMailbox then continue end
        pcall(function()
            local NetworkFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
            local remote = NetworkFolder and NetworkFolder:FindFirstChild("Mailbox: Claim All")
            if remote then
                if remote:IsA("RemoteFunction") then remote:InvokeServer()
                else remote:FireServer() end
            end
        end)
    end
end)

Window:LoadConfiguration()

-- ⚙️ SETTINGS TAB --
TabSettings:CreateSection("Server Management")

TabSettings:CreateButton({
    Name = "🔄 Rejoin Server",
    Callback = function()
        if getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "Rejoining...", Content = "Please wait...", Duration = 3})
        end
        local ts = game:GetService("TeleportService")
        local p = game:GetService("Players").LocalPlayer
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
    end
})

TabSettings:CreateButton({
    Name = "🚀 Server Hop",
    Callback = function()
        if getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "Server Hopping...", Content = "Finding a new server...", Duration = 3})
        end
        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local req = request or http_request or (syn and syn.request)
        if req then
            pcall(function()
                local servers = req({Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"}).Body
                local decoded = HttpService:JSONDecode(servers)
                if decoded and decoded.data then
                    for _, v in pairs(decoded.data) do
                        if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, game.Players.LocalPlayer)
                            break
                        end
                    end
                end
            end)
        end
    end
})
