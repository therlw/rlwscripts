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
    TargetEggMultiplier = {50, 75, 100},
    TargetSpecificEgg = {"Any"},
    AutoBuyFreeEgg = false,
    AutoLoot = false,
    GodMode = false,
    TeleportDelay = 0.8,
    AutoUpgrades = {
        BackroomsBossDamage = false,
        BackroomsExtraLootRoll = false,
        BackroomsTokenFind = false
    },
    WebhookEnabled = false,
    WebhookURL = "",
    UnlockDeepBackrooms = false,
    AntiJumpscare = true,
    PotatoMode = false
}

local TargetEggRooms = {}
getgenv().DespawnedEggRooms = getgenv().DespawnedEggRooms or {}

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
                    
                    -- Rarity Prefixes (Gerçek isimleri almak için)
                    local prefix = ""
                    if data.sh then prefix = prefix .. "Shiny " end
                    if data.pt == 1 then prefix = prefix .. "Golden " end
                    if data.pt == 2 then prefix = prefix .. "Rainbow " end
                    
                    pName = prefix .. pName

                    local col   = isH and 0x00ff00 or 0xffd700
                    local title = isH and "🎉 NEW HUGE CAUGHT! 🎉" or "🌟 NEW TITANIC CAUGHT! 🌟"
                    
                    if data.sh then
                        title = isH and "✨ NEW SHINY HUGE CAUGHT! ✨" or "✨ NEW SHINY TITANIC CAUGHT! ✨"
                        col = 0x00ffff -- Shiny için Cyan renk
                    end
                    
                    local imageId = nil
                    if def then
                        local thumb = def.thumbnail
                        -- Golden ise altın resmi kullan, değilse normal (Rainbowlar da normal fotoyu kullanır oyun içi efekt basar)
                        if data.pt == 1 and def.goldenThumbnail then
                            thumb = def.goldenThumbnail
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
    local oldNew = Message.New
    Message.New = function(msg, ...)
        if msg and type(msg) == "string" and msg:lower():find("mini%-boss") then
            return -- "Mini-boss defeated!" yazısını tamamen engelle
        end
        return oldNew(msg, ...)
    end
end)

-- ==========================
-- 💡 ANTİ-JUMPSCARE / FULLBRIGHT
-- ==========================
task.spawn(function()
    while task.wait(1) do
        if getgenv().Config.AntiJumpscare then
            -- Oyunun ışıkları titreten 'flicker' sistemini kör ediyoruz.
            -- Işıklardan "BackroomsLight" etiketini silince oyun onları titreme listesine alamıyor!
            for _, light in ipairs(CollectionService:GetTagged("BackroomsLight")) do
                CollectionService:RemoveTag(light, "BackroomsLight")
                -- Işıkları sabit olarak açık bırak
                pcall(function()
                    if light:IsA("BasePart") then
                        light.Material = Enum.Material.Neon
                        light.Transparency = 0.5
                    end
                    local point = light:FindFirstChildOfClass("SurfaceLight") or light:FindFirstChildOfClass("PointLight")
                    if point then point.Enabled = true end
                end)
            end
        end
    end
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
                        if idLower:find("backroom") and idLower:find("crayon") and idLower:find("key") then
                            count = count + (item._am or 1)
                        elseif idLower == "daydream key" or idLower == "backrooms key" or idLower == "backrooms crayon key" then
                            count = count + (item._am or 1)
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
        if not getgenv().Config.MetaFarmActive then continue end
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
        if not getgenv().Config.MetaFarmActive then continue end
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
        if not getgenv().Config.MetaFarmActive then continue end
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

local function HandleInstanceEntry()
    if IsInBackroomsInstance() then return end
    if os.clock() - LastInstanceJoinAttempt < 60 then return end
    LastInstanceJoinAttempt = os.clock()
    
    getgenv().SmartFarmState.EggRoomUID = nil
    getgenv().SmartFarmState.BossRoomUID = nil
    getgenv().SmartFarmState.BossRespawningUntil = 0
    
    if Rayfield then
        Rayfield:Notify({Title = "🚀 Backrooms", Content = "Backrooms'a otomatik giriş yapılıyor...", Duration = 5})
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
                    if Rayfield then
                        Rayfield:Notify({Title = "⚡ Geri Dönüş!", Content = "Boss doğmak üzere, savaşa dönülüyor!", Duration = 3})
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

        local rooms = CollectionService:GetTagged("Backrooms")
        if #rooms == 0 then
            VisitedRooms = {}
            task.wait(1)
            continue
        end

        -- Öncelikli hedef arama (Egg, Boss, Vault, Breakable)
        local bestRoom = nil
        local bestRoomType = 0

        -- 1. ADIM: KAYITLI YUMURTA ODASI KONTROLÜ
        local checkEggCache = isHybridEggPhase or (getgenv().Config.FindKeepOutEgg and not getgenv().Config.MetaFarmActive)
        if checkEggCache and getgenv().SmartFarmState.EggRoomUID then
            for _, room in ipairs(rooms) do
                if room:GetAttribute("RoomUID") == getgenv().SmartFarmState.EggRoomUID then
                    bestRoom = room
                    bestRoomType = 4
                    break
                end
            end
        end

        -- 2. ADIM: EĞER BULUNAMADIYSA NORMAL ARAMA YAP
        if not bestRoom then
            for _, room in ipairs(rooms) do
                local roomUID = room:GetAttribute("RoomUID")
                local roomID = room:GetAttribute("RoomID") or ""
                local lowerID = string.lower(roomID)

                local isEgg = lowerID:find("keepout") or lowerID:find("hugeegg") or lowerID:find("titanicegg")
                
                -- ARKA PLANDA YUMURTA ODASI KAYDET (Kullanıcı sonradan açarsa diye)
                if isEgg and not getgenv().SmartFarmState.EggRoomUID and not getgenv().DespawnedEggRooms[roomUID] then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end

                local isFreeEgg = lowerID:find("freeegg")
                local multiplier = isFreeEgg and tonumber(room:GetAttribute("EggMultiplier")) or 0

                local isValidMultiplier = false
                if type(getgenv().Config.TargetEggMultiplier) == "table" then
                    if #getgenv().Config.TargetEggMultiplier == 0 then
                        isValidMultiplier = true -- Hiçbir şey seçilmediyse hepsini kabul et
                    else
                        for _, v in ipairs(getgenv().Config.TargetEggMultiplier) do
                            if multiplier == v then
                                isValidMultiplier = true
                                break
                            end
                        end
                    end
                else
                    isValidMultiplier = multiplier >= (getgenv().Config.TargetEggMultiplier or 50)
                end
                
                local isBoss = lowerID:find("bosschest") or lowerID:find("minichest")
                    or lowerID:find("miniboss") or lowerID:find("boss")
                    or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
                local isBreakable = lowerID:find("breakable")
                local hasDeepDoor = room:FindFirstChild("DeepDoor", true) ~= nil

                if getgenv().Config.UnlockDeepBackrooms and hasDeepDoor then
                    -- DeepDoor Boss'tan bile daha yüksek öncelikli (Type 6 yapalım)
                    if bestRoomType < 6 then
                        bestRoom = room
                        bestRoomType = 6
                    end
                end

                if getgenv().Config.FindFreeEggRoom and isFreeEgg and isValidMultiplier then
                    local targetType = getgenv().Config.AutoBuyFreeEgg and 4 or 5
                    if bestRoomType < targetType or (bestRoomType == targetType and roomUID < (bestRoom and bestRoom:GetAttribute("RoomUID") or 999999)) then
                        bestRoom = room
                        bestRoomType = targetType
                        bestMultiplier = multiplier
                    end
                end

                if isBossHuntPhase and isBoss then
                    if bestRoomType < 3 or (bestRoomType == 3 and roomUID < bestRoom:GetAttribute("RoomUID")) then
                        bestRoom = room
                        bestRoomType = 3
                    end
                end

                local shouldFarmEgg = (getgenv().Config.FindKeepOutEgg and not getgenv().Config.MetaFarmActive) or isHybridEggPhase
                if shouldFarmEgg and isEgg and not getgenv().DespawnedEggRooms[roomUID] then
                    if bestRoomType < 4 or (bestRoomType == 4 and roomUID < bestRoom:GetAttribute("RoomUID")) then
                        bestRoom = room
                        bestRoomType = 4
                    end
                end

                if isKeyFarmPhase and isBreakable then
                    if bestRoomType < 1 or (bestRoomType == 1 and roomUID < bestRoom:GetAttribute("RoomUID")) then
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
                if bestRoomType == 6 then
                    -- DeepDoor Kapısı İçin Kilit Açma
                    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                    if invokeCustom then
                        -- İçeri ışınlan, kapının tam önüne
                        safeTeleport(bestRoom, false)
                        task.wait(1) -- Yüklenmesi için bekle
                        
                        local success, err = pcall(function()
                            return invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "UnlockDeep")
                        end)
                        if success then
                            if Rayfield then
                                Rayfield:Notify({Title = "🌌 Deep Backrooms!", Content = "1.25M Daydream Coin ödendi ve kapı başarıyla açıldı!", Duration = 5})
                            end
                            -- Açıldıktan sonra artık taramaması için kapatıyoruz
                            getgenv().Config.UnlockDeepBackrooms = false
                            if Rayfield and Toggle_DeepBackrooms then Toggle_DeepBackrooms:Set(false) end
                            VisitedRooms[roomUID] = true
                        else
                            if Rayfield then
                                Rayfield:Notify({Title = "❌ Deep Door Hatası", Content = "Kapı açılamadı! Coin yetersiz olabilir. Özellik geçici olarak kapatıldı.", Duration = 5})
                            end
                            getgenv().Config.UnlockDeepBackrooms = false
                            if Rayfield and Toggle_DeepBackrooms then Toggle_DeepBackrooms:Set(false) end
                            VisitedRooms[roomUID] = true
                        end
                        return -- Main döngüden çık, yeniden başlasın
                    end
                elseif bestRoomType == 5 or bestRoomType == 4 then
                    if bestRoom:FindFirstChild("LockedDoors") then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end
                -- Type 3 (Boss): teleport sonrası yükleme beklendiğinde kontrol edilecek
            end

            safeTeleport(bestRoom, false)

            if bestRoomType == 6 then
                -- (Bu branch artık kullanılmıyor, streaming nedeniyle aşağıda handle ediliyor)

            elseif bestRoomType == 5 then
                local mult = bestRoom:GetAttribute("EggMultiplier") or "Bilinmeyen"
                getgenv().Config.FindFreeEggRoom = false
                getgenv().Config.MetaFarmActive = false
                if Rayfield and Toggle_FreeEgg then Toggle_FreeEgg:Set(false) end
                if Rayfield and Toggle_MetaFarm then Toggle_MetaFarm:Set(false) end
                if Rayfield then
                    local eggTitle = (type(getgenv().Config.TargetSpecificEgg) == "string" and getgenv().Config.TargetSpecificEgg) or "Egg"
                    Rayfield:Notify({Title = "🎁 İstenen Egg Bulundu!", Content = mult .. "x " .. eggTitle .. " Odası!", Duration = 10, Image = 4483362458})
                end

            elseif bestRoomType == 4 then
                if isHybridEggPhase and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end
                
                local Network3 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                if Rayfield then
                    if isHybridEggPhase then
                        Rayfield:Notify({Title = "🥚 Hibrit Egg Farm!", Content = "Boss doğana kadar yumurta açılıyor...", Duration = 4})
                    else
                        Rayfield:Notify({Title = "🥚 Gizli Yumurta!", Content = roomID .. " bulundu! Kırılıyor...", Duration = 4})
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
                
                local eggIdToBuy = "Keep Out Egg"
                if lowerID:find("titanicegg") then eggIdToBuy = "Titanic Backrooms Egg" end
                if lowerID:find("hugeegg") then eggIdToBuy = "Huge Backrooms Egg" end

                local hasTeleportedToEgg = false
                local missingEggCounter = 0
                while getgenv().Config.MetaFarmActive and (getgenv().Config.FindKeepOutEgg or getgenv().Config.AutoBuyFreeEgg or isHybridEggPhase) do
                    local timeNow = workspace:GetServerTimeNow()
                    
                    -- YUMURTA SÜRE KONTROLÜ (Oyunun Kendi Sayacı)
                    local expireTs = bestRoom:GetAttribute("EggExpireTimestamp")
                    if expireTs and type(expireTs) == "number" and timeNow > expireTs then
                        if Rayfield then
                            Rayfield:Notify({Title = "Yumurta Yok Oldu!", Content = "Süresi dolduğu için yumurta kayboldu, yeni odaya geçiliyor.", Duration = 3})
                        end
                        DespawnedEggRooms[roomUID] = true
                        getgenv().SmartFarmState.EggRoomUID = nil
                        getgenv().Config.MetaFarmActive = true
                        break
                    end
                    
                    if isHybridEggPhase then
                        local remaining = (getgenv().SmartFarmState.BossRespawningUntil or 0) - timeNow
                        if remaining > 0 and remaining <= 8 then
                            break -- Boss doğmak üzere, döngüden çık
                        end
                    end
                    
                    local customUid = nil
                    local eggModel = nil
                    local closestDist = 99999
                    local closestName = ""
                    
                    if CustomEggsCmds and getRootPart() then
                        for uid, eggObj in pairs(CustomEggsCmds.All()) do
                            if eggObj._position then
                                local dist = (getRootPart().Position - eggObj._position).Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    eggModel = eggObj._model
                                    customUid = uid
                                    closestName = tostring(eggObj._id or eggObj.id or (eggModel and eggModel.Name) or "")
                                end
                            end
                        end
                        
                        -- EGG DESPAWN CHECK: Yükleme (Streaming) gecikmesi olabileceği için 5 kez şans ver.
                        -- Uzaklığı 60'a düşürdük, çünkü yan odadaki bir yumurtayı görüp beklemesini istemiyoruz.
                        if closestDist > 60 then
                            missingEggCounter = missingEggCounter + 1
                            if missingEggCounter >= 5 then
                                if Rayfield then
                                    Rayfield:Notify({Title = "Egg Despawned!", Content = "Yumurta silinmiş veya yüklenemedi, yeni oda aranıyor...", Duration = 4})
                                end
                                getgenv().DespawnedEggRooms[roomUID] = true
                                getgenv().SmartFarmState.EggRoomUID = nil
                                break
                            end
                        else
                            missingEggCounter = 0 -- Bulduğu an sıfırlanır
                        end
                    end

                    if customUid then
                        -- TELEPORT: Yumurtanın YANINA ışınla (üstüne değil - zıplama olmasın)
                        if not hasTeleportedToEgg and eggModel then
                            local root = getRootPart()
                            if root then
                                root.Anchored = true
                                root.AssemblyLinearVelocity = Vector3.new(0,0,0)
                                root.AssemblyAngularVelocity = Vector3.new(0,0,0)
                                -- Üstüne değil, 4 stud YAN tarafına ışınla (zıplama yapmaz)
                                root.CFrame = eggModel:GetPivot() * CFrame.new(4, 3, 0)
                                task.wait(0.3)
                            end
                            hasTeleportedToEgg = true
                        end

                        -- HATCH: TestHatch.lua ile BİREBİR AYNI mantık
                        local hatchRemote = game:GetService("ReplicatedStorage"):WaitForChild("Network"):FindFirstChild("CustomEggs_Hatch")
                        if hatchRemote then
                            if hatchRemote:IsA("RemoteEvent") then
                                pcall(function() hatchRemote:FireServer(customUid, maxHatch) end)
                                print("[HATCH] FireServer yollandı, uid:", customUid, "amount:", maxHatch)
                            else
                                task.spawn(function()
                                    local success, res = pcall(function()
                                        return hatchRemote:InvokeServer(customUid, maxHatch)
                                    end)
                                    print("[HATCH] InvokeServer sonucu:", success, tostring(res))
                                    -- Sunucu reddederse (false döner) 1'li dene
                                    if not success or res == false then
                                        local s2, r2 = pcall(function()
                                            return hatchRemote:InvokeServer(customUid, 1)
                                        end)
                                        print("[HATCH] Fallback (1li) sonucu:", s2, tostring(r2))
                                    end
                                end)
                            end
                        else
                            warn("[HATCH] CustomEggs_Hatch bulunamadı!")
                        end
                    elseif buyEggRemote then
                        pcall(function()
                            if buyEggRemote:IsA("RemoteEvent") then
                                buyEggRemote:FireServer(eggIdToBuy, maxHatch)
                            else
                                buyEggRemote:InvokeServer(eggIdToBuy, maxHatch)
                            end
                        end)
                    end
                    task.wait(1.5)
                end

            elseif bestRoomType == 3 then
                -- ✅ Boss odasına ışınlandık. Şimdi streaming yüklenmesini bekleyip kapı durumunu kontrol ediyoruz.
                task.wait(2.5) -- Streaming yüklenmesi için yeterli süre

                local isAlreadyOpen = not bestRoom:FindFirstChild("LockedDoors")
                local hasBoss = bestRoom:GetAttribute("BossChestUID") or bestRoom:GetAttribute("ActiveMinichests")

                if isAlreadyOpen and hasBoss then
                    -- Kapı zaten açık! Anahtar harcamadan kamp kur.
                    if Rayfield then
                        Rayfield:Notify({
                            Title = "🎯 Açık Boss Odası!",
                            Content = "Kapı zaten açık, anahtar harcanmadı! Kamp kuruluyor...",
                            Duration = 6
                        })
                    end
                elseif bestRoom:FindFirstChild("LockedDoors") then
                    -- Kapı kapalı, anahtar harca.
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
                            if Rayfield then
                                Rayfield:Notify({Title = "🚀 Hibrit Mod Aktif!", Content = "Boss beklenirken yumurta farmına geçiliyor...", Duration = 5})
                            end
                            getgenv().SmartFarmState.BossRespawningUntil = respawnTs
                            getgenv().SmartFarmState.BossRoomUID = roomUID
                            VisitedRooms[roomUID] = true -- Aramayı boss odasına kitlememesi için
                            break -- Döngüden çık, main döngü Egg bulacak!
                        end

                        if not isWaitingRespawn then
                            isWaitingRespawn = true
                            notifiedRespawn = false
                            if Rayfield then
                                Rayfield:Notify({Title = "⏳ Boss Öldü!", Content = "Yeniden doğma: " .. remaining .. " saniye. Bekliyoruz...", Duration = 5})
                            end
                        end
                        local waitTime = math.max(respawnTs - workspace:GetServerTimeNow() - 1, 0)
                        if waitTime > 2 then task.wait(waitTime) end
                    else
                        if isWaitingRespawn and not notifiedRespawn then
                            notifiedRespawn = true
                            isWaitingRespawn = false
                            if Rayfield then
                                Rayfield:Notify({Title = "⚔️ Boss Geri Döndü!", Content = "Saldırı başlıyor...", Duration = 3})
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
        for _, room in ipairs(rooms) do
            local uid = room:GetAttribute("RoomUID")
            if not VisitedRooms[uid] then
                local pos = room:IsA("Model") and room:GetPivot().Position or Vector3.new(0,0,0)
                table.insert(sortedRooms, {Room = room, Dist = pos.Magnitude, UID = uid})
            end
        end

        table.sort(sortedRooms, function(a, b) return a.Dist > b.Dist end)

        if #sortedRooms == 0 then
            VisitedRooms = {}
            visitedCount = 0
            task.wait(1)
            continue
        end

        local isSearchingOnly = isBossHuntPhase or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom

        -- Sadece EN UZAK odaya zıpla (1 oda per döngü)
        local roomData = sortedRooms[1]
        local room = roomData.Room
        local roomUID = roomData.UID
        local roomID = room:GetAttribute("RoomID") or ""
        local lowerID = string.lower(roomID)

        -- print(string.format("[ARAMA] Harita Genişletiliyor -> Oda: %s | Mesafe: %d", roomID, math.floor(roomData.Dist)))

        safeTeleport(room, isSearchingOnly)
        task.wait(getgenv().Config.TeleportDelay)

        -- SPESİFİK YUMURTA KONTROLÜ (Tüm modlar için geçerli)
        local isFreeEggRoom = lowerID:find("freeegg")
        if isFreeEggRoom and type(getgenv().Config.TargetSpecificEgg) == "table" then
            local hasAny = false
            for _, v in ipairs(getgenv().Config.TargetSpecificEgg) do
                if v == "Any" then hasAny = true break end
            end

            if not hasAny and #getgenv().Config.TargetSpecificEgg > 0 then
                local CustomEggsCmds = nil
                pcall(function() CustomEggsCmds = require(game:GetService("ReplicatedStorage").Library.Client.CustomEggsCmds) end)
                local isCorrect = false
                if CustomEggsCmds and getRootPart() then
                    local closestDist = 99999
                    local closestName = ""
                    for uid, eggObj in pairs(CustomEggsCmds.All()) do
                        if eggObj._position then
                            local dist = (getRootPart().Position - eggObj._position).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestName = tostring(eggObj._id or eggObj.id or (eggObj._model and eggObj._model.Name) or "")
                            end
                        end
                    end
                    if closestName ~= "" and closestDist < 300 then
                        local lowerName = closestName:lower()
                        for _, target in ipairs(getgenv().Config.TargetSpecificEgg) do
                            if lowerName:find(target:lower()) then
                                isCorrect = true
                                break
                            end
                        end
                        if not isCorrect then
                            if Rayfield then
                                Rayfield:Notify({Title = "Yanlış Yumurta!", Content = "Bulunan: " .. closestName .. "\nİstenenlerden Değil! Atlanıyor...", Duration = 3})
                            end
                        end
                    end
                end

                if not isCorrect then
                    VisitedRooms[roomUID] = true
                    continue
                end
            end
        end

        -- PARADOX FİX 2: Odanın merkezine zıplamak, devasa odalarda sunucunun (server) yeni odaları yüklemesi için
        -- gereken yakınlık (proximity) şartını sağlamayabilir. Bu yüzden karakteri odanın tüm kapılarına (uç noktalara)
        -- sürtüyoruz ki oyun yeni odaları Stream etsin!
        if room:FindFirstChild("LockedDoors") then
            for _, door in ipairs(room.LockedDoors:GetChildren()) do
                if door:IsA("Model") or door:IsA("BasePart") then
                    safeTeleport(door, true)
                    task.wait(0.2) -- Odanın yüklenmesi için süreyi uzattık
                end
            end
        end

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

        -- AutoLoot (Random Rewards)
        if getgenv().Config.AutoLoot and invokeCustom then
            for _, obj in ipairs(room:GetChildren()) do
                if obj.Name == "RandomReward" and obj:IsA("Model") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        safeTeleport(part, false)
                        task.wait(0.1) -- Bekleme süresini optimize ettik
                        
                        local success = pcall(function()
                            invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ClaimRandomReward", obj)
                        end)
                        
                        -- Topladıktan sonra anında siliyoruz ki script aynı ödüle tekrar takılıp kalmasın!
                        if success then
                            pcall(function() obj:Destroy() end)
                        end
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
-- 🎨 RAYFIELD UI
-- ==========================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "RLWSCRIPTS Event Script (Backrooms!)",
    LoadingTitle = "RLWSCRIPTS Event Script (Backrooms!)",
    LoadingSubtitle = "by RLW",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RLWSCRIPTS",
        FileName = "BackroomsConfig"
    }
})

local TabMain = Window:CreateTab("🔥 Meta Farm", 4483362458)

TabMain:CreateSection("Phase 1: Smart Loop (Meta)")

Toggle_MetaFarm = TabMain:CreateToggle({
    Name = "Start Boss Farming",
    CurrentValue = false,
    Flag = "Tgl_MetaFarm",
    Callback = function(Value)
        getgenv().Config.MetaFarmActive = Value
        if Value then
            Rayfield:Notify({Title = "Boss Farming", Content = "Farming keys, then hunting Boss!", Duration = 5})
        end
    end
})

TabMain:CreateSlider({
    Name = "Target Key Count (For Boss)",
    Range = {1, 100}, Increment = 1, Suffix = " Keys", CurrentValue = 5,
    Flag = "Sld_TargetKeys",
    Callback = function(Value) getgenv().Config.TargetKeyCount = Value end
})

TabMain:CreateSection("Phase 1.5: Deep Backrooms")

Toggle_DeepBackrooms = TabMain:CreateToggle({
    Name = "🌌 Auto Unlock Deep Backrooms (1.25M Coins)",
    CurrentValue = false,
    Flag = "Tgl_DeepBackrooms",
    Callback = function(Value)
        getgenv().Config.UnlockDeepBackrooms = Value
        if Value and Rayfield then
            Rayfield:Notify({Title = "Deep Backrooms", Content = "Searching for the Deep Door...", Duration = 3})
        end
    end
})

TabMain:CreateSection("Phase 2: Hybrid Egg (Optional)")

Toggle_KeepOutEgg = TabMain:CreateToggle({
    Name = "🥚 Auto Keep Out Egg (Hybrid Mode)",
    CurrentValue = false,
    Flag = "Tgl_KeepOutEgg",
    Callback = function(Value)
        getgenv().Config.FindKeepOutEgg = Value
    end
})

Toggle_FreeEgg = TabMain:CreateToggle({
    Name = "🎁 Find Free Egg Room",
    CurrentValue = false,
    Flag = "Tgl_FreeEgg",
    Callback = function(Value)
        getgenv().Config.FindFreeEggRoom = Value
    end
})

TabMain:CreateDropdown({
    Name = "Target Egg Multiplier",
    Options = {"2x", "3x", "5x", "10x", "20x", "30x", "50x", "75x", "100x"},
    CurrentOption = {"50x", "75x", "100x"},
    MultipleOptions = true,
    Flag = "Drp_EggMultiplier",
    Callback = function(Option)
        local multiTable = {}
        for _, opt in ipairs(Option) do
            local val = string.gsub(opt, "x", "")
            table.insert(multiTable, tonumber(val) or 0)
        end
        getgenv().Config.TargetEggMultiplier = multiTable
    end,
})

TabMain:CreateDropdown({
    Name = "🎯 Target Specific Free Egg",
    Options = {"Any", "Smile", "Flower", "Scribble", "Swirl", "Keep Out", "Nightmare", "Overgrown", "Gooey", "Night Terror", "Fear", "Corrupt"},
    CurrentOption = {"Any"},
    MultipleOptions = true,
    Flag = "Drp_SpecificEgg",
    Callback = function(Option)
        getgenv().Config.TargetSpecificEgg = Option
    end,
})

TabMain:CreateToggle({
    Name = "Auto Buy Targeted Free Egg",
    CurrentValue = false,
    Flag = "Tgl_AutoBuyFreeEgg",
    Callback = function(Value)
        getgenv().Config.AutoBuyFreeEgg = Value
    end,
})

TabMain:CreateSection("Phase 3: Speed & Safety Settings")

TabMain:CreateToggle({
    Name = "Auto Loot Chests/Rewards",
    CurrentValue = false,
    Flag = "Tgl_AutoLoot",
    Callback = function(Value) getgenv().Config.AutoLoot = Value end
})

TabMain:CreateToggle({
    Name = "💡 Anti-Jumpscare (Fullbright)",
    CurrentValue = true,
    Flag = "Tgl_AntiJumpscare",
    Callback = function(Value) getgenv().Config.AntiJumpscare = Value end
})

TabMain:CreateSlider({
    Name = "Teleport Delay (Speed)",
    Range = {0.1, 3}, Increment = 0.1, Suffix = "s", CurrentValue = 0.8,
    Flag = "Sld_Teleport",
    Callback = function(Value) getgenv().Config.TeleportDelay = Value end
})

TabMain:CreateToggle({
    Name = "🥔 Potato Mode (Max FPS)",
    CurrentValue = false,
    Flag = "Tgl_PotatoMode",
    Callback = function(Value)
        getgenv().Config.PotatoMode = Value
        if Value then
            task.spawn(function()
                pcall(function()
                    game.Lighting.GlobalShadows = false
                    game.Lighting.FogEnd = 9e9
                    game.Lighting.ShadowSoftness = 0
                    for _, v in ipairs(game.Lighting:GetDescendants()) do
                        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("Atmosphere") then
                            v.Enabled = false
                        end
                    end
                    for _, v in ipairs(workspace:GetDescendants()) do
                        if v:IsA("Texture") or v:IsA("Decal") then
                            v.Transparency = 1
                        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                            v.Enabled = false
                        elseif v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                            v.Material = Enum.Material.SmoothPlastic
                        end
                    end
                end)
                
                if not getgenv().PotatoConnection then
                    getgenv().PotatoConnection = workspace.DescendantAdded:Connect(function(v)
                        if getgenv().Config.PotatoMode then
                            pcall(function()
                                if v:IsA("Texture") or v:IsA("Decal") then
                                    v.Transparency = 1
                                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                                    v.Enabled = false
                                elseif v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                                    v.Material = Enum.Material.SmoothPlastic
                                end
                            end)
                        end
                    end)
                end
            end)
        end
    end
})

TabMain:CreateToggle({
    Name = "God Mode (Invincibility)",
    CurrentValue = false,
    Flag = "Tgl_GodMode",
    Callback = function(Value) getgenv().Config.GodMode = Value end
})

TabMain:CreateButton({
    Name = "Close Interface",
    Callback = function() Rayfield:Destroy() end
})

local TabUpgrades = Window:CreateTab("⚙️ Auto Upgrades", 4483362458)

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
local TabWebhook = Window:CreateTab("🔔 Webhook", 4483362458)

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
            Rayfield:Notify({Title = "Error", Content = "Please enable the Webhook toggle first!", Duration = 3})
            return
        end
        if getgenv().Config.WebhookURL == "" then
            Rayfield:Notify({Title = "Error", Content = "Please enter a valid Webhook URL!", Duration = 3})
            return
        end
        SendWebhook("✅ Webhook Test Successful!", "Your Webhook is working perfectly.\nYou will receive Huge and Titanic notifications here.", 0x00ff00)
        Rayfield:Notify({Title = "Success", Content = "Test message sent to your Discord!", Duration = 3})
    end
})

Rayfield:LoadConfiguration()
