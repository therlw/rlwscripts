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
    TargetEggMultiplier = 50,
    AutoLoot = false,
    GodMode = false,
    TeleportDelay = 0.8,
    AutoUpgrades = {
        BackroomsBossDamage = false,
        BackroomsExtraLootRoll = false,
        BackroomsTokenFind = false
    },
    WebhookEnabled = false,
    WebhookURL = ""
}

local TargetEggRooms = {}

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
            
            local isH = (def and def.huge) or string.match(pId, "^Huge ")
            local isT = (def and def.titanic) or string.match(pId, "^Titanic ")

            if isH then currentH = currentH + 1 end
            if isT then currentT = currentT + 1 end

            if not KnownUIDs[uid] then
                KnownUIDs[uid] = true
                if isH or isT then
                    local pName = (def and def.DisplayName) or pId
                    local col   = isH and 0x00ff00 or 0xffd700
                    local title = isH and "🎉 NEW HUGE CAUGHT! 🎉" or "🌟 NEW TITANIC CAUGHT! 🌟"
                    
                    local imageId = nil
                    if def and def.thumbnail then
                        imageId = string.match(def.thumbnail, "%d+")
                    end
                    
                    local desc = string.format(
                        "🐾 **Pet:** `%s`\n" ..
                        "👤 **User:** `%s`\n" ..
                        "⏱️ **Time:** `%s`\n\n" ..
                        "📊 **Session Stats:**\n" ..
                        "🟢 `%d` Huges  |  🟡 `%d` Titanics",
                        pName, LocalPlayer.Name, os.date("%X"),
                        currentH - StartHuges, currentT - StartTitanics
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

    local coreScripts = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Scripts"):WaitForChild("Core")
    if coreScripts:FindFirstChild("Idle Tracking") then
        coreScripts["Idle Tracking"].Enabled = false
    end

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

    LocalPlayer.Idled:Connect(function() 
        VirtualUser:CaptureController() 
        VirtualUser:ClickButton2(Vector2.new()) 
    end)
end)

-- ==========================
-- 🚫 EKRAN BİLDİRİMLERİNİ GİZLEME
-- ==========================
pcall(function()
    local Message = require(game:GetService("ReplicatedStorage").Library.Client.Message)
    local oldNew = Message.New
    Message.New = function(msg, ...)
        if msg and type(msg) == "string" and msg:lower():find("mini%-boss") then
            return
        end
        return oldNew(msg, ...)
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
        if getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom then
            if RequestEggRooms then
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
                            task.wait(0.5)
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
local CustomEggsCmds = nil
local maxHatch = 1

pcall(function()
    CustomEggsCmds = require(game:GetService("ReplicatedStorage").Library.Client.CustomEggsCmds)
    maxHatch = require(game:GetService("ReplicatedStorage").Library.Client.EggCmds).GetMaxHatch() or 1
end)

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

        local bestRoom = nil
        local bestRoomType = 0

        -- 1. ADIM: KAYITLI YUMURTA ODASI KONTROLÜ (sadece Keep Out için)
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
                
                if isEgg and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end

                local isFreeEgg = lowerID:find("freeegg")
                -- multiplier odanın attribute'u olabilir, ama biz içerdeki egg'leri tarayacağız, şimdilik sadece isFreeEgg yeterli
                
                local isBoss = lowerID:find("bosschest") or lowerID:find("minichest")
                    or lowerID:find("miniboss") or lowerID:find("boss")
                    or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
                local isVault = lowerID:find("vault") or lowerID:find("chest")
                local isBreakable = lowerID:find("breakable")

                -- Free Egg öncelikli (en yüksek öncelik)
                if getgenv().Config.FindFreeEggRoom and isFreeEgg and bestRoomType < 5 then
                    bestRoom = room
                    bestRoomType = 5
                    break
                end

                if isBossHuntPhase and isBoss and bestRoomType < 3 then
                    bestRoom = room
                    bestRoomType = 3
                    break
                end

                local shouldFarmEgg = (getgenv().Config.FindKeepOutEgg and not getgenv().Config.MetaFarmActive) or isHybridEggPhase
                if shouldFarmEgg and isEgg and bestRoomType < 4 then
                    bestRoom = room
                    bestRoomType = 4
                    break
                end

                if isKeyFarmPhase then
                    if isBreakable and bestRoomType < 1 then
                        bestRoom = room
                        bestRoomType = 1
                    end
                end
            end
        end

        if bestRoom and bestRoomType > 0 then
            local roomUID = bestRoom:GetAttribute("RoomUID")
            local roomID = bestRoom:GetAttribute("RoomID") or ""
            local lowerID = string.lower(roomID)

            local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
            local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
            local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")

            if fireCustom then
                if bestRoomType == 5 or bestRoomType == 4 then
                    if bestRoom:FindFirstChild("LockedDoors") then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end
            end

            safeTeleport(bestRoom, false)

            if bestRoomType == 5 then
                -- ============================================================
                -- 🎯 FREE EGG ROOM – Akıllı Seçim ve Otomatik Açma
                -- ============================================================
                if Rayfield then
                    Rayfield:Notify({Title = "🎁 Free Egg Room!", Content = "Taranıyor ve en iyi yumurta seçiliyor...", Duration = 4})
                end

                -- Yumurta açma animasyonunu kapat (opsiyonel)
                pcall(function()
                    local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                    if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
                end)

                local NetworkFE = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                local customHatchRemoteFE = NetworkFE and NetworkFE:FindFirstChild("CustomEggs_Hatch")
                if not customHatchRemoteFE then
                    warn("[FREE EGG] CustomEggs_Hatch remote bulunamadı!")
                    if Rayfield then
                        Rayfield:Notify({Title = "Hata", Content = "CustomEggs_Hatch remote yok!", Duration = 5})
                    end
                    goto continue_loop
                end

                -- Hedef çarpan eşiği
                local targetMultiplier = getgenv().Config.TargetEggMultiplier or 50

                -- Bu odadaki uygun egg'leri tutacak liste
                local suitableEggs = {}

                -- Tüm custom egg'leri tara
                if CustomEggsCmds then
                    local allEggs = CustomEggsCmds.All()
                    local rootPos = getRootPart() and getRootPart().Position or Vector3.new(0,0,0)

                    for uid, eggObj in pairs(allEggs) do
                        -- Sadece bu odaya yakın olanları al (mesafe < 50)
                        if eggObj._position and (eggObj._position - rootPos).Magnitude < 50 then
                            local eggName = eggObj._dir and eggObj._dir.name or ""
                            -- Çarpanı parse et: "Backrooms Swirl Egg 3x" -> 3
                            local multiplier = tonumber(string.match(eggName, "(%d+)x"))
                            if multiplier and multiplier >= targetMultiplier then
                                table.insert(suitableEggs, {
                                    uid = uid,
                                    name = eggName,
                                    multiplier = multiplier,
                                    obj = eggObj
                                })
                            end
                        end
                    end
                end

                -- Eğer uygun egg yoksa, odayı terk et ve başka oda ara
                if #suitableEggs == 0 then
                    if Rayfield then
                        Rayfield:Notify({Title = "⚠️ Uygun Egg Yok", Content = "Bu odada " .. targetMultiplier .. "x üzeri egg bulunamadı, geçiliyor...", Duration = 4})
                    end
                    VisitedRooms[roomUID] = true
                    goto continue_loop
                end

                -- En yüksek çarpanlı olanı seç
                table.sort(suitableEggs, function(a, b) return a.multiplier > b.multiplier end)
                local bestEgg = suitableEggs[1]
                if Rayfield then
                    Rayfield:Notify({Title = "🥚 Seçilen Egg", Content = bestEgg.name .. " (" .. bestEgg.multiplier .. "x) açılıyor...", Duration = 5})
                end

                -- Seçilen egg'i sürekli aç
                local hatchCount = 0
                while getgenv().Config.FindFreeEggRoom do
                    -- Egg hala mevcut mu kontrol et
                    local currentEgg = CustomEggsCmds.Get(bestEgg.uid)
                    if not currentEgg or currentEgg._destroyed then
                        -- Mevcut egg bitti, listeden kaldır ve sıradakini seç
                        table.remove(suitableEggs, 1)
                        if #suitableEggs == 0 then
                            if Rayfield then
                                Rayfield:Notify({Title = "❌ Tüm Egg'ler Bitti", Content = "Bu odadaki tüm uygun egg'ler açıldı, yeni oda aranıyor...", Duration = 4})
                            end
                            VisitedRooms[roomUID] = true
                            break
                        end
                        bestEgg = suitableEggs[1]
                        if Rayfield then
                            Rayfield:Notify({Title = "🔄 Sıradaki Egg", Content = bestEgg.name .. " (" .. bestEgg.multiplier .. "x) açılıyor...", Duration = 4})
                        end
                        -- Yeni egg'e yaklaş
                        if bestEgg.obj and bestEgg.obj._model then
                            safeTeleport(bestEgg.obj._model, true)
                            task.wait(0.5)
                        end
                        -- Devam et
                    end

                    -- Egg'e ışınlan (eğer daha önce yapılmadıysa)
                    if bestEgg.obj and bestEgg.obj._model then
                        local rootPos = getRootPart()
                        if rootPos and (rootPos.Position - bestEgg.obj._position).Magnitude > 15 then
                            safeTeleport(bestEgg.obj._model, true)
                            task.wait(0.3)
                        end
                    end

                    -- Satın al / Hatch
                    task.spawn(function()
                        pcall(function()
                            if customHatchRemoteFE:IsA("RemoteEvent") then
                                customHatchRemoteFE:FireServer(bestEgg.uid, maxHatch or 1)
                            else
                                customHatchRemoteFE:InvokeServer(bestEgg.uid, maxHatch or 1)
                            end
                        end)
                    end)

                    hatchCount = hatchCount + 1
                    task.wait(1.5) -- bekleme süresi, sunucu spam koruması için
                end

            elseif bestRoomType == 4 then
                -- KEEP OUT EGG (mevcut kod, değişmedi)
                if isHybridEggPhase and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = roomUID
                end
                
                if Rayfield then
                    if isHybridEggPhase then
                        Rayfield:Notify({Title = "🥚 Hibrit Egg Farm!", Content = "Boss doğana kadar yumurta açılıyor...", Duration = 4})
                    else
                        Rayfield:Notify({Title = "🥚 Gizli Yumurta!", Content = roomID .. " bulundu! Kırılıyor...", Duration = 4})
                    end
                end
                
                pcall(function()
                    local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                    if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
                end)
                
                local Network4 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                local buyEggRemote4 = Network4 and (Network4:FindFirstChild("Eggs_RequestPurchase") or Network4:FindFirstChild("Eggs: RequestPurchase"))
                local customHatchRemote4 = Network4 and Network4:FindFirstChild("CustomEggs_Hatch")
                
                local eggIdToBuy4 = "Keep Out Egg"
                if lowerID:find("titanicegg") then eggIdToBuy4 = "Titanic Backrooms Egg" end
                if lowerID:find("hugeegg") then eggIdToBuy4 = "Huge Backrooms Egg" end

                local hasTeleportedToEgg4 = false

                while getgenv().Config.FindKeepOutEgg do
                    local timeNow = workspace:GetServerTimeNow()
                    
                    if isHybridEggPhase then
                        local remaining = (getgenv().SmartFarmState.BossRespawningUntil or 0) - timeNow
                        if remaining > 0 and remaining <= 8 then
                            break
                        end
                    end
                    
                    local customUid4 = nil
                    local eggModel4 = nil
                    local closestDist4 = 99999
                    
                    if CustomEggsCmds and getRootPart() then
                        for uid, eggObj in pairs(CustomEggsCmds.All()) do
                            if eggObj._position then
                                local dist = (getRootPart().Position - eggObj._position).Magnitude
                                if dist < closestDist4 then
                                    closestDist4 = dist
                                    customUid4 = uid
                                    eggModel4 = eggObj._model
                                end
                            end
                        end
                    end

                    if customUid4 and customHatchRemote4 then
                        if not hasTeleportedToEgg4 and eggModel4 then
                            getRootPart().CFrame = eggModel4:GetPivot() + Vector3.new(0, 5, 0)
                            hasTeleportedToEgg4 = true
                            task.wait(0.2)
                        end

                        task.spawn(function()
                            pcall(function()
                                if customHatchRemote4:IsA("RemoteEvent") then
                                    customHatchRemote4:FireServer(customUid4, maxHatch)
                                else
                                    customHatchRemote4:InvokeServer(customUid4, maxHatch)
                                end
                            end)
                        end)
                    elseif buyEggRemote4 then
                        task.spawn(function()
                            pcall(function()
                                if buyEggRemote4:IsA("RemoteEvent") then
                                    buyEggRemote4:FireServer(eggIdToBuy4, maxHatch)
                                else
                                    buyEggRemote4:InvokeServer(eggIdToBuy4, maxHatch)
                                end
                            end)
                        end)
                    else
                        warn("[KEEP OUT EGG] Ne custom ne normal egg remote bulunamadı!")
                    end
                    task.wait(1.5)
                end

            elseif bestRoomType == 3 then
                -- BOSS ROOM (mevcut kod, değişmedi)
                task.wait(2.5)

                local isAlreadyOpen = not bestRoom:FindFirstChild("LockedDoors")
                local hasBoss = bestRoom:GetAttribute("BossChestUID") or bestRoom:GetAttribute("ActiveMinichests")

                if isAlreadyOpen and hasBoss then
                    if Rayfield then
                        Rayfield:Notify({
                            Title = "🎯 Açık Boss Odası!",
                            Content = "Kapı zaten açık, anahtar harcanmadı! Kamp kuruluyor...",
                            Duration = 6
                        })
                    end
                elseif bestRoom:FindFirstChild("LockedDoors") then
                    local Network2 = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
                    local fireCustom2 = Network2 and Network2:FindFirstChild("Instancing_FireCustomFromClient")
                    if fireCustom2 then
                        fireCustom2:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end

                local isWaitingRespawn = false
                local notifiedRespawn = false
                while getgenv().Config.MetaFarmActive do
                    task.wait(1)
                    local respawnTs = nil
                    pcall(function() respawnTs = bestRoom:GetAttribute("RespawnTimestamp") end)
                    local now = workspace:GetServerTimeNow()
                    if respawnTs and respawnTs > now then
                        local remaining = math.ceil(respawnTs - now)
                        
                        if remaining > 15 and getgenv().Config.FindKeepOutEgg then
                            if Rayfield then
                                Rayfield:Notify({Title = "🚀 Hibrit Mod Aktif!", Content = "Boss beklenirken yumurta farmına geçiliyor...", Duration = 5})
                            end
                            getgenv().SmartFarmState.BossRespawningUntil = respawnTs
                            getgenv().SmartFarmState.BossRoomUID = roomUID
                            VisitedRooms[roomUID] = true
                            break
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
                -- BREAKABLE / VAULT (mevcut kod, değişmedi)
                local emptySeconds = 0
                local bigCheckTimer = 0
                
                while getgenv().Config.MetaFarmActive do
                    task.wait(1)
                    local currentKeys = getDaydreamKeyCount()
                    if currentKeys >= getgenv().Config.TargetKeyCount then
                        break
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
                        VisitedRooms[roomUID] = true
                        break
                    end

                    if not breakablesExist then
                        emptySeconds = emptySeconds + 1
                        if emptySeconds >= 4 then
                            VisitedRooms[roomUID] = true
                            break
                        end
                    else
                        emptySeconds = 0
                    end
                end
            end

            ::continue_loop::
            continue
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

        local roomData = sortedRooms[1]
        local room = roomData.Room
        local roomUID = roomData.UID
        local roomID = room:GetAttribute("RoomID") or ""
        local lowerID = string.lower(roomID)

        safeTeleport(room, false)
        task.wait(getgenv().Config.TeleportDelay)

        -- Harita genişletmek için kapılara yaklaş
        if room:FindFirstChild("LockedDoors") then
            for _, door in ipairs(room.LockedDoors:GetChildren()) do
                if door:IsA("Model") or door:IsA("BasePart") then
                    safeTeleport(door, true)
                    task.wait(0.2)
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
                    local isFreeEggRoom = lowerID:find("freeegg")

                    local shouldUnlock = false

                    if isBossHuntPhase and isBossRoom then
                        shouldUnlock = true
                    elseif (getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom or isHybridEggPhase) and (isEggRoom or isFreeEggRoom) then
                        shouldUnlock = true
                    else
                        shouldUnlock = true
                    end

                    if shouldUnlock then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UnlockDoors")
                    end
                end
            end

            if lowerID:find("chestchoose") then
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "PickChest", 1)
            end

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

            local levers = room:FindFirstChild("Levers")
            if levers then
                for _, lever in ipairs(levers:GetChildren()) do
                    local num = tonumber(lever.Name) or tonumber(string.match(lever.Name, "%d+"))
                    if num then
                        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "FlipLever", num)
                    end
                end
            end

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

    end
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
    Name = "🎁 Find & Open Free Egg Rooms",
    CurrentValue = false,
    Flag = "Tgl_FreeEgg",
    Callback = function(Value)
        getgenv().Config.FindFreeEggRoom = Value
    end
})

TabMain:CreateDropdown({
    Name = "🎯 Target Egg Multiplier (Free Egg)",
    Options = {"2x", "3x", "5x", "10x", "20x", "50x", "100x"},
    CurrentOption = {"50x"},
    MultipleOptions = false,
    Flag = "Drp_Multiplier",
    Callback = function(Option)
        local val = string.gsub(Option[1], "x", "")
        getgenv().Config.TargetEggMultiplier = tonumber(val) or 50
    end,
})

TabMain:CreateSection("Phase 3: Speed & Safety Settings")

TabMain:CreateToggle({
    Name = "Auto Loot Chests/Rewards",
    CurrentValue = false,
    Flag = "Tgl_AutoLoot",
    Callback = function(Value) getgenv().Config.AutoLoot = Value end
})

TabMain:CreateSlider({
    Name = "Teleport Delay (Speed)",
    Range = {0.1, 3}, Increment = 0.1, Suffix = "s", CurrentValue = 0.8,
    Flag = "Sld_Teleport",
    Callback = function(Value) getgenv().Config.TeleportDelay = Value end
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
