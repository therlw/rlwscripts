--[[
    ██████  ██       ██     ███████  ██████  ██████  ██ ██████  ████████ ███████ 
    ██   ██ ██       ██     ██      ██    ██ ██   ██ ██ ██   ██    ██    ██      
    ██████  ██       ██     █████   ██    ██ ██████  ██ ██████     ██    ███████ 
    ██   ██ ██       ██     ██      ██    ██ ██   ██ ██ ██   ██    ██         ██ 
    ██   ██ ███████  ██     ███████  ██████  ██   ██ ██ ██   ██    ██    ███████ 
    RLWSCRIPTS – PS99 BACKROOMS ULTIMATE FARM
]]--

-- ========================================================================
-- 1.  GLOBAL CONFIG & STATS
-- ========================================================================

getgenv().Config = {
    -- Core
    MetaFarmActive          = false,
    FastFarmBreakables      = false,
    TargetKeyCount          = 5,
    DeepBackroomsMode       = false,
    GodMode                 = false,
    HopOnBossCooldown       = false,
    RadarTeleport           = false,

    -- Eggs
    FindKeepOutEgg          = false,
    FindFreeEggRoom         = false,
    TargetEggType           = "Any",
    TargetEggMultiplier     = 50,
    TargetKeepOutMultiplier = 50,
    AutoHatchNearest        = false,

    -- Loot / Events
    AutoLoot                = false,
    FarmDeepChests          = false,
    FarmDeepEvents          = false,

    -- Upgrades
    AutoUpgrades = {
        BackroomsBossDamage      = false,
        BackroomsExtraLootRoll   = false,
        BackroomsTokenFind       = false,
        BackroomsDeepBossDamage  = false,
        BackroomsCoinMultiplier  = false,
        BackroomsEggLuck         = false,
        BackroomsKeyFind         = false,
    },

    -- Webhook & Mailbox
    WebhookEnabled          = false,
    WebhookURL              = "",
    AutoMailbox             = false,

    -- Teknik
    TeleportDelay           = 0.8,
}

getgenv().LiveStats = {
    StartTime          = os.time(),
    BossesKilled       = 0,
    HighestMultiplier  = 0,
    HighestMultiplierName = "None",
    RoomsExplored      = 0,
    _seenRooms         = {},
    BossStatus         = "Searching...",
    CurrentKeys        = 0,
}

-- Yardımcı global tablolar (başlangıçta boş)
getgenv()._EggSpawnWaitTime = getgenv()._EggSpawnWaitTime or {}
getgenv().DeadCoords       = getgenv().DeadCoords or {}
getgenv().NavGraph         = nil
getgenv().NavGraphDesc     = nil
getgenv().MapDescriptors   = getgenv().MapDescriptors or {}
getgenv().CurrentRadarTargetCoordKey = nil

-- ========================================================================
-- 2.  SERVICES & CONSTANTS
-- ========================================================================

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Network     = ReplicatedStorage:FindFirstChild("Network")

-- Constants
local DEAD_EGG_COOLDOWN   = 300   -- 5 dakika
local MAX_VISITED_ROOMS   = 500
local ROOM_LOAD_TIMEOUT   = 4
local EGG_LOAD_GRACE_TIME = 10

-- ========================================================================
-- 3.  UTILITY FUNCTIONS
-- ========================================================================

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPlayerPosition()
    local root = getRootPart()
    return root and root.Position or Vector3.zero
end

-- Güvenli ışınlanma (noclip + streaming desteği)
local function safeTeleport(target, fastMode)
    local root = getRootPart()
    if not root or not target then return end

    local initialCFrame = typeof(target) == "CFrame" and target
        or (target:IsA("Model") and target:GetPivot() or target.CFrame)
    local safePos = initialCFrame.Position + Vector3.new(0, 6, 0)

    if typeof(target) == "Instance" and target:IsA("Model") then
        local bbox, size = target:GetBoundingBox()
        safePos = bbox.Position - Vector3.new(0, size.Y / 2, 0) + Vector3.new(0, 5, 0)
        safePos = safePos + Vector3.new(15, 0, 15)   -- Boss ile tam çakışma engeli
    end

    root.Anchored = true
    root.CFrame = CFrame.new(safePos)
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    if Network and Network:FindFirstChild("RequestStreaming") then
        pcall(function() Network.RequestStreaming:FireServer(safePos) end)
    end

    -- Oda yüklenmesini bekle (fastMode false ise)
    local isRoom = typeof(target) == "Instance" and target:GetAttribute("RoomUID") ~= nil
    if isRoom and not fastMode then
        local loadedFloor = nil
        local t = 0
        while t < ROOM_LOAD_TIMEOUT do
            local priorityNames = {"BREAK_ZONE", "Floor", "Base", "Ground", "Hitbox"}
            for _, name in ipairs(priorityNames) do
                local part = target:FindFirstChild(name, true)
                if part and part:IsA("BasePart") then
                    loadedFloor = part
                    break
                end
            end
            if not loadedFloor then
                for _, part in ipairs(target:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide
                        and part.Name ~= "AntiVoidPart_Antigravity"
                        and part.Size.X > 5 and part.Size.Z > 5 then
                        loadedFloor = part
                        break
                    end
                end
            end
            if loadedFloor then break end
            task.wait(0.2); t = t + 0.2
        end
        if loadedFloor then
            local exactPos = loadedFloor.Position + Vector3.new(0, loadedFloor.Size.Y / 2 + 5, 0)
            root.CFrame = CFrame.new(exactPos)
        end
    end

    -- Anti-Void platform güncelle
    local antiVoid = workspace:FindFirstChild("AntiVoidPart_Antigravity")
    if antiVoid then
        antiVoid.CFrame = CFrame.new(safePos - Vector3.new(0, 4, 0))
    end

    task.wait(0.25)
    root.Anchored = false
end

-- Anti-Void platform oluştur (yoksa)
local function ensureAntiVoid()
    local av = workspace:FindFirstChild("AntiVoidPart_Antigravity")
    if not av then
        av = Instance.new("Part")
        av.Name = "AntiVoidPart_Antigravity"
        av.Size = Vector3.new(500, 1, 500)
        av.Anchored = true
        av.Transparency = 1
        av.CanCollide = true
        av.Parent = workspace
    end
    return av
end
ensureAntiVoid()

-- ========================================================================
-- 4.  WEBHOOK & INVENTORY MONITOR
-- ========================================================================

local KnownUIDs      = {}
local StartHuges     = 0
local StartTitanics  = 0
local CurrentHuges   = 0
local CurrentTitanics= 0

local function getPetDir()
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

local function initSessionStats()
    pcall(function()
        local save = require(ReplicatedStorage.Library.Client.Save).Get()
        if not save or not save.Inventory or not save.Inventory.Pet then return end
        local pets   = save.Inventory.Pet
        local petDir = getPetDir()

        for uid, data in pairs(pets) do
            KnownUIDs[uid] = true
            local pId = tostring(data.id or "")
            local def = petDir[pId]
            local isH = (def and def.huge) or string.match(pId, "^Huge ")
            local isT = (def and def.titanic) or string.match(pId, "^Titanic ")
            if isH then StartHuges = StartHuges + 1 end
            if isT then StartTitanics = StartTitanics + 1 end
        end
    end)
end
initSessionStats()

local function sendWebhook(title, desc, color, thumbId)
    if not getgenv().Config.WebhookEnabled or getgenv().Config.WebhookURL == "" then return end
    local requestFn = (getgenv and getgenv().request) or (syn and syn.request) or request
    if not requestFn then return end

    local embed = {
        title       = title,
        description = desc,
        color       = color or 0x00ff00,
        timestamp   = DateTime.now():ToIsoDate(),
        footer      = { text = "powered by RLWSCRIPTS" }
    }
    if thumbId and tostring(thumbId) ~= "" then
        embed.thumbnail = { url = "https://ps99.biggamesapi.io/image/" .. tostring(thumbId) }
    end

    pcall(function()
        requestFn({
            Url     = getgenv().Config.WebhookURL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                username = "RLWSCRIPTS Notification",
                embeds   = { embed }
            })
        })
    end)
end

local function updateInventoryMonitor()
    pcall(function()
        local save = require(ReplicatedStorage.Library.Client.Save).Get()
        if not save or not save.Inventory or not save.Inventory.Pet then return end
        local pets   = save.Inventory.Pet
        local petDir = getPetDir()

        local currentH = 0
        local currentT = 0

        for uid, data in pairs(pets) do
            local pId = tostring(data.id or "")
            local def = petDir[pId]
            local isH = (def and def.huge) or string.match(pId, "^Huge ")
            local isT = (def and def.titanic) or string.match(pId, "^Titanic ")
            if isH then currentH = currentH + 1 end
            if isT then currentT = currentT + 1 end

            if not KnownUIDs[uid] and (isH or isT) then
                KnownUIDs[uid] = true
                local pName = (def and def.DisplayName) or pId
                local prefixes = {}
                if data.sh then table.insert(prefixes, "Shiny") end
                if data.pt == 1 then table.insert(prefixes, "Golden")
                elseif data.pt == 2 then table.insert(prefixes, "Rainbow") end
                if #prefixes > 0 then pName = table.concat(prefixes, " ") .. " " .. pName end

                local col   = isH and 0x00ff00 or 0xffd700
                local title = isH and "🎉 NEW HUGE CAUGHT!" or "🌟 NEW TITANIC CAUGHT!"
                local imageId = nil
                if def then
                    local thumb = def.thumbnail
                    if data.pt == 1 and def.goldenThumbnail then thumb = def.goldenThumbnail
                    elseif data.pt == 2 and def.rainbowThumbnail then thumb = def.rainbowThumbnail end
                    if thumb then imageId = string.match(thumb, "%d+") end
                end
                local desc = string.format(
                    "🐾 **Pet:** `%s`\n👤 **User:** `%s`\n⏱️ **Time:** `%s`",
                    pName, LocalPlayer.Name, os.date("%X")
                )
                sendWebhook(title, desc, col, imageId)
            end
        end

        CurrentHuges    = currentH - StartHuges
        CurrentTitanics = currentT - StartTitanics
    end)
end

task.spawn(function()
    while task.wait(3) do updateInventoryMonitor() end
end)

-- ========================================================================
-- 5.  ANTI-AFK
-- ========================================================================

pcall(function()
    -- Oyunun AFK script'ini kapat
    local coreScripts = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Scripts"):WaitForChild("Core")
    local idleTracking = coreScripts:FindFirstChild("Idle Tracking")
    if idleTracking then idleTracking.Enabled = false end

    -- Periyodik "Stop Timer" sinyali
    task.spawn(function()
        while task.wait(30) do
            pcall(function()
                local net = ReplicatedStorage:FindFirstChild("Network")
                if net then
                    local remote = net:FindFirstChild("Idle Tracking: Stop Timer")
                    if remote then
                        if remote:IsA("RemoteFunction") then remote:InvokeServer()
                        else remote:FireServer() end
                    end
                end
            end)
        end
    end)

    -- Roblox Idled event
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ========================================================================
-- 6.  HIDE GAME MESSAGES
-- ========================================================================

pcall(function()
    local Message = require(ReplicatedStorage.Library.Client.Message)
    local oldError = Message.Error
    Message.Error = function() end

    local oldNew = Message.New
    Message.New = function(msg, ...)
        if msg and type(msg) == "string" then
            local lower = msg:lower()
            if lower:find("mini%-boss") or lower:find("boss defeated") or lower:find("gamemaster") then
                return
            end
        end
        return oldNew(msg, ...)
    end
end)

-- ========================================================================
-- 7.  NOCLIP (BOSS UÇMASINI ENGELLER)
-- ========================================================================

RunService.Stepped:Connect(function()
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

-- ========================================================================
-- 8.  KEY COUNT HELPER
-- ========================================================================

local function getDaydreamKeyCount()
    local success, result = pcall(function()
        local Save = require(ReplicatedStorage.Library.Client.Save)
        local saveFile = Save.Get()
        if not saveFile or not saveFile.Inventory then return 0 end

        local count = 0
        local isDeep = getgenv().Config.DeepBackroomsMode

        for _, categoryData in pairs(saveFile.Inventory) do
            if type(categoryData) == "table" then
                for _, item in pairs(categoryData) do
                    if type(item) == "table" and type(item.id) == "string" then
                        local idLower = string.lower(item.id)
                        local amount = item._am or 1
                        if isDeep then
                            if idLower == "deep backrooms crayon key" or idLower == "deep daydream key" then
                                count = count + amount
                            end
                        else
                            if idLower == "backrooms crayon key" or idLower == "daydream key" or idLower == "backrooms key" then
                                count = count + amount
                            end
                        end
                    end
                end
            end
        end
        return count
    end)
    return success and result or 0
end

-- ========================================================================
-- 9.  EGG & ROOM UTILITIES
-- ========================================================================

local function isEggAlive(room)
    -- Süre kontrolü
    local expireTime = room:GetAttribute("EggExpireTimestamp")
    if type(expireTime) == "number" and workspace:GetServerTimeNow() > expireTime then
        return false
    end

    -- Yakınlık kontrolü
    local isNear = false
    pcall(function()
        local root = getRootPart()
        if root and (room:IsA("Model") or room:IsA("BasePart")) then
            local dist = (root.Position - room:GetPivot().Position).Magnitude
            if dist < 250 then isNear = true end
        end
    end)

    if isNear then
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
                    if os.clock() - getgenv()._EggSpawnWaitTime[eggUID] < EGG_LOAD_GRACE_TIME then
                        return true
                    end
                    return false
                end
                getgenv()._EggSpawnWaitTime[eggUID] = nil
                local actualEgg = eggModel:FindFirstChild("Egg") or eggModel:FindFirstChild("EggLock")
                if not actualEgg then
                    local hasPart = false
                    for _, v in ipairs(eggModel:GetChildren()) do
                        if v:IsA("BasePart") then hasPart = true; break end
                    end
                    if not hasPart then return false end
                end
            end
        end
    end
    return true
end

local function areRoomsAdjacent(a, b)
    local touchX = (a.x + a.w == b.x) or (b.x + b.w == a.x)
    local overlapY = (a.y < b.y + b.h) and (b.y < a.y + a.h)
    local touchY = (a.y + a.h == b.y) or (b.y + b.h == a.y)
    local overlapX = (a.x < b.x + b.w) and (b.x < a.x + a.w)
    return (touchX and overlapY) or (touchY and overlapX)
end

local function buildNavGraph(descriptor)
    if getgenv().NavGraph and getgenv().NavGraphDesc == descriptor then
        return getgenv().NavGraph
    end
    local graph = {}
    for i, roomA in ipairs(descriptor.rooms) do
        graph[i] = {}
        for j, roomB in ipairs(descriptor.rooms) do
            if i ~= j and areRoomsAdjacent(roomA, roomB) then
                table.insert(graph[i], j)
            end
        end
    end
    getgenv().NavGraph = graph
    getgenv().NavGraphDesc = descriptor
    return graph
end

local function getRoomIndexFromPosition(pos, descriptor)
    local res = descriptor.res or 45
    local x0 = descriptor.x0 or 1
    local y0 = descriptor.y0 or 1
    local rootVec = descriptor.root or Vector3.zero

    local relX = pos.X - rootVec.X
    local relZ = pos.Z - rootVec.Z
    local gridX = (relX / res) - (x0 - 1)
    local gridY = (relZ / res) - (y0 - 1)

    local bestIdx, bestDist = nil, math.huge
    for i, room in ipairs(descriptor.rooms) do
        if gridX >= room.x and gridX <= room.x + room.w and gridY >= room.y and gridY <= room.y + room.h then
            return i
        end
        local cx = room.x + (room.w / 2)
        local cy = room.y + (room.h / 2)
        local dist = math.sqrt((gridX - cx)^2 + (gridY - cy)^2)
        if dist < bestDist then
            bestDist = dist
            bestIdx = i
        end
    end
    return bestIdx
end

local function findPathAStar(startIdx, targetIdx, graph, descriptor)
    local openSet = {startIdx}
    local cameFrom = {}
    local gScore = {[startIdx] = 0}
    local fScore = {}

    local function heuristic(a, b)
        local rA = descriptor.rooms[a]
        local rB = descriptor.rooms[b]
        return math.abs(rA.x - rB.x) + math.abs(rA.y - rB.y)
    end
    fScore[startIdx] = heuristic(startIdx, targetIdx)

    while #openSet > 0 do
        local lowest = math.huge
        local current, currentIdx = nil, nil
        for i, node in ipairs(openSet) do
            local f = fScore[node] or math.huge
            if f < lowest then lowest = f; current = node; currentIdx = i end
        end
        if current == targetIdx then
            local path = {current}
            while cameFrom[current] do
                current = cameFrom[current]
                table.insert(path, 1, current)
            end
            return path
        end
        table.remove(openSet, currentIdx)
        for _, neighbor in ipairs(graph[current] or {}) do
            local tentative = (gScore[current] or math.huge) + 1
            if tentative < (gScore[neighbor] or math.huge) then
                cameFrom[neighbor] = current
                gScore[neighbor] = tentative
                fScore[neighbor] = tentative + heuristic(neighbor, targetIdx)
                local inOpen = false
                for _, node in ipairs(openSet) do
                    if node == neighbor then inOpen = true; break end
                end
                if not inOpen then table.insert(openSet, neighbor) end
            end
        end
    end
    return nil
end

-- ========================================================================
-- 10. SMART FARM – PET DISTRIBUTION & AUTO-TAP
-- ========================================================================

getgenv().SmartFarmState = {
    PetAssignInterval = 0.5,
    AutoTapInterval   = 0.08,
    MaxTargetsPerTick = 8,
    FarmRange         = 300,
    BossRespawningUntil = 0,
    BossRoomUID       = nil,
    EggRoomUID        = nil,
}

local function getPlayerPets()
    local pets = {}
    pcall(function()
        local PlayerPet = require(ReplicatedStorage.Library.Client.PlayerPet)
        for _, petData in pairs(PlayerPet.GetAll()) do
            if petData.owner == LocalPlayer then table.insert(pets, petData) end
        end
    end)
    return pets
end

local _prevPetMapping = {}

local function distributePets(breakables)
    if #breakables == 0 then return end
    local pets = getPlayerPets()
    if #pets == 0 then return end
    local per = math.floor(#pets / #breakables)
    local rem = #pets % #breakables
    local mapping = {}
    local idx = 1
    for i, b in ipairs(breakables) do
        local count = per + (i <= rem and 1 or 0)
        for _ = 1, count do
            if idx > #pets then break end
            mapping[pets[idx].euid] = b.Name
            idx = idx + 1
        end
    end
    if next(mapping) then
        local changed = false
        for k, v in pairs(mapping) do
            if _prevPetMapping[k] ~= v then changed = true; break end
        end
        if not changed then
            for k in pairs(_prevPetMapping) do
                if not mapping[k] then changed = true; break end
            end
        end
        if changed then
            _prevPetMapping = mapping
            local net = ReplicatedStorage:FindFirstChild("Network")
            if net then
                local remote = net:FindFirstChild("Breakables_JoinPetBulk")
                if remote then remote:FireServer(mapping) end
            end
        end
    end
end

local function getBackroomsTargets()
    local targets = { miniChests = {}, bossChest = {}, priority = {}, normal = {} }
    local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
    if not breakablesFolder then return targets end

    local root = getRootPart()
    if not root then return targets end
    local pos = root.Position

    local mbBossZone, mbMiniPoints = nil, {}
    pcall(function()
        local container = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
        local backrooms = container and container:FindFirstChild("Active") and container.Active:FindFirstChild("Backrooms")
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
                local isBoss, isMini, isPriority = false, false, false
                if mbBossZone then
                    local zonePos = mbBossZone:IsA("BasePart") and mbBossZone.Position or mbBossZone:GetPivot().Position
                    if (pivot - zonePos).Magnitude < 15 then isBoss = true end
                end
                if not isBoss and #mbMiniPoints > 0 then
                    for _, point in ipairs(mbMiniPoints) do
                        local ptPos = point:IsA("BasePart") and point.Position or point:GetPivot().Position
                        if (pivot - ptPos).Magnitude < 15 then isMini = true; break end
                    end
                end
                if not isBoss and not isMini then
                    local bId = string.lower(tostring(obj:GetAttribute("BreakableID") or ""))
                    if bId:find("gamemaster") or bId:find("grandmaster") then isBoss = true
                    elseif bId:find("comet") or bId:find("jar") or bId:find("pinata") or bId:find("lucky") or bId:find("mini") or bId:find("chest") then isPriority = true
                    elseif bId:find("boss") then isBoss = true end
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

-- Pet dağıtım döngüsü
task.spawn(function()
    while task.wait(getgenv().SmartFarmState.PetAssignInterval) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        local targets = getBackroomsTargets()
        local allTargets = {}
        local weakTargets = {}
        for _, v in ipairs(targets.miniChests) do table.insert(weakTargets, v) end
        for _, v in ipairs(targets.priority) do table.insert(weakTargets, v) end
        table.sort(weakTargets, function(a, b)
            local hA = a:GetAttribute("MaxHealth") or a:GetAttribute("Health") or math.huge
            local hB = b:GetAttribute("MaxHealth") or b:GetAttribute("Health") or math.huge
            return hA < hB
        end)
        for _, v in ipairs(weakTargets) do table.insert(allTargets, v) end
        if #allTargets == 0 and #targets.bossChest > 0 then
            for _, v in ipairs(targets.bossChest) do table.insert(allTargets, v) end
        end
        if #allTargets == 0 then
            for _, v in ipairs(targets.normal) do table.insert(allTargets, v) end
        end
        pcall(function() distributePets(allTargets) end)
    end
end)

-- Otomatik vuruş döngüsü
task.spawn(function()
    while task.wait(getgenv().SmartFarmState.AutoTapInterval) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        local targets = getBackroomsTargets()
        local dealDmg = Network and Network:FindFirstChild("Breakables_PlayerDealDamage")
        if not dealDmg then continue end

        local function hitGroup(group, limit)
            local count = 0
            for _, obj in ipairs(group) do
                if count >= limit then return true end
                dealDmg:FireServer(obj.Name)
                count = count + 1
            end
            return count >= limit
        end

        local weakTargets = {}
        for _, v in ipairs(targets.miniChests) do table.insert(weakTargets, v) end
        for _, v in ipairs(targets.priority) do table.insert(weakTargets, v) end
        table.sort(weakTargets, function(a, b)
            local hA = a:GetAttribute("MaxHealth") or a:GetAttribute("Health") or math.huge
            local hB = b:GetAttribute("MaxHealth") or b:GetAttribute("Health") or math.huge
            return hA < hB
        end)

        local max = getgenv().SmartFarmState.MaxTargetsPerTick
        if not hitGroup(weakTargets, max) and #targets.bossChest > 0 then
            hitGroup(targets.bossChest, max)
        end
        if not hitGroup(weakTargets, max) then
            hitGroup(targets.normal, max)
        end
    end
end)

-- Orb toplama
local function collectOrbs()
    local container = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Orbs")
    if not container then return end
    local orbs = {}
    for _, orb in ipairs(container:GetChildren()) do
        local id = tonumber(orb.Name)
        if id then table.insert(orbs, id); orb:Destroy() end
    end
    if #orbs > 0 then
        local remote = Network and Network:FindFirstChild("Orbs: Collect")
        if remote then remote:FireServer(orbs) end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if not (getgenv().Config.MetaFarmActive or getgenv().Config.FastFarmBreakables) then continue end
        pcall(collectOrbs)
    end
end)

-- ========================================================================
-- 11. AUTO UPGRADE
-- ========================================================================

task.spawn(function()
    while task.wait(5) do
        local cfg = getgenv().Config
        if not cfg or not cfg.AutoUpgrades then continue end
        pcall(function()
            local EventUpgradeCmds = require(ReplicatedStorage.Library.Client.EventUpgradeCmds)
            local EventUpgradesDir = require(ReplicatedStorage.Library.Directory.EventUpgrades)
            for upgradeId, enabled in pairs(cfg.AutoUpgrades) do
                if enabled then
                    local data = EventUpgradesDir[upgradeId]
                    if data then
                        local current = EventUpgradeCmds.GetTier(data)
                        local maxTier = #data.TierPowers
                        if current < maxTier then
                            EventUpgradeCmds.Purchase(data)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end)
    end
end)

-- ========================================================================
-- 12. INSTANCE ENTRY
-- ========================================================================

local LastInstanceJoinAttempt = 0

local function isInBackroomsInstance()
    local container = workspace:FindFirstChild("__THINGS")
    if container then
        local instContainer = container:FindFirstChild("__INSTANCE_CONTAINER")
        if instContainer and instContainer:FindFirstChild("Active") then
            return instContainer.Active:FindFirstChild("Backrooms") ~= nil
        end
    end
    return false
end

local function handleInstanceEntry()
    if isInBackroomsInstance() then return end
    if os.clock() - LastInstanceJoinAttempt < 60 then return end
    LastInstanceJoinAttempt = os.clock()

    getgenv().SmartFarmState.EggRoomUID = nil
    getgenv().SmartFarmState.BossRoomUID = nil
    getgenv().SmartFarmState.BossRespawningUntil = 0

    if getgenv().RLW_Window then
        getgenv().RLW_Window:Notify({ Title = "🚀 Backrooms", Content = "Auto-joining Backrooms...", Duration = 5 })
    end

    pcall(function()
        local InstancingCmds = require(ReplicatedStorage.Library.Client.InstancingCmds)
        if InstancingCmds and InstancingCmds.Enter then
            InstancingCmds.Enter("Backrooms")
        else
            local net = ReplicatedStorage:WaitForChild("Network")
            net:WaitForChild("Instancing_PlayerEnterInstance"):InvokeServer("Backrooms")
        end
    end)
    task.wait(5)
end

-- ========================================================================
-- 13. RADAR TELEPORT (A* PATHFINDING + GOD MODE)
-- ========================================================================

local function getTargetRoomVector(roomType, altType, visitedRooms, roomsRaw, deadChestRooms)
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    if not invokeCustom then return nil end

    local modeKey = getgenv().Config.DeepBackroomsMode and "Deep" or "Normal"
    local descriptor = getgenv().MapDescriptors[modeKey]
    if not descriptor then
        local s, desc = pcall(function()
            return invokeCustom:InvokeServer("Backrooms", "Backrooms_GetMapDescriptor", getgenv().Config.DeepBackroomsMode)
        end)
        if s and desc then
            descriptor = desc
            getgenv().MapDescriptors[modeKey] = desc
        else
            return nil
        end
    end

    if not descriptor or type(descriptor) ~= "table" or not descriptor.rooms then return nil end

    local t1 = roomType and string.lower(roomType) or ""
    local t2 = altType and string.lower(altType) or ""
    local bestDeadVec, lowestCooldown = nil, math.huge
    local rootVec = descriptor.root or Vector3.zero
    local res = descriptor.res or 45
    local x0 = descriptor.x0 or 1
    local y0 = descriptor.y0 or 1

    for _, roomInfo in ipairs(descriptor.rooms) do
        local cls = string.lower(roomInfo.class or "")
        if (t1 ~= "" and cls:find(t1)) or (t2 ~= "" and cls:find(t2)) then
            local isChoosing = cls:find("choose")
            local targetChoosing = (t1:find("choose")) or (t2:find("choose"))
            if isChoosing and not targetChoosing then continue end

            local cx = roomInfo.x + (roomInfo.w / 2)
            local cy = roomInfo.y + (roomInfo.h / 2)
            local worldX = (cx + (x0 - 1)) * res + rootVec.X
            local worldZ = (cy + (y0 - 1)) * res + rootVec.Z
            local targetY = rootVec.Y
            if targetY == 0 and roomsRaw and #roomsRaw > 0 then
                for _, r in ipairs(roomsRaw) do
                    local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position)
                    if pos then targetY = pos.Y; break end
                end
            end
            local targetVec = Vector3.new(worldX, targetY + 15, worldZ)

            local coordKey = string.format("%d_%d", math.floor(targetVec.X), math.floor(targetVec.Z))
            if getgenv().DeadCoords[coordKey] and getgenv().DeadCoords[coordKey] > workspace:GetServerTimeNow() then
                local timeLeft = getgenv().DeadCoords[coordKey] - workspace:GetServerTimeNow()
                if timeLeft < lowestCooldown and not (getgenv().Config.DeepBackroomsMode and timeLeft > 9999999) then
                    lowestCooldown = timeLeft
                    bestDeadVec = targetVec
                end
                continue
            end

            local isVisited = false
            local isPhysicallyLoaded = false
            if roomsRaw then
                for _, r in ipairs(roomsRaw) do
                    local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
                    if (pos - targetVec).Magnitude < 70 then
                        isPhysicallyLoaded = true
                        local uid = r:GetAttribute("RoomUID")
                        if uid and visitedRooms and visitedRooms[uid] then
                            if not deadChestRooms or not deadChestRooms[uid] or deadChestRooms[uid] > workspace:GetServerTimeNow() then
                                isVisited = true
                                break
                            end
                        end
                    end
                end
            end

            if not isVisited then
                getgenv().CurrentRadarTargetCoordKey = coordKey
                if getgenv().Config.DeepBackroomsMode and not isPhysicallyLoaded then
                    local bestEdgeVec, minDist = nil, math.huge
                    local currentRoot = getRootPart()
                    local currentPos = currentRoot and currentRoot.Position or Vector3.zero
                    local distCurrent = (currentPos - targetVec).Magnitude
                    for _, r in ipairs(roomsRaw) do
                        local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
                        local d = (pos - targetVec).Magnitude
                        if d < minDist and d < (distCurrent - 10) then
                            minDist = d
                            bestEdgeVec = pos
                        end
                    end
                    if bestEdgeVec then
                        return bestEdgeVec, nil, nil, true
                    end
                    return nil, nil, nil, false
                end
                return targetVec, nil, nil, false
            end
        end
    end

    if bestDeadVec then
        return nil, bestDeadVec, lowestCooldown, false
    end
    return nil, nil, nil, false
end

-- ========================================================================
-- 14. MAIN FARM STATE MACHINE
-- ========================================================================

local VisitedRooms = {}
local visitedCount = 0
local DeadEggRooms = {}
local DeadChestRooms = {}

local function isBackroomsRoom(room)
    return room:IsA("Model") and room:GetAttribute("RoomUID") ~= nil
end

local function isRoomVisited(uid)
    return VisitedRooms[uid] == true
end

local function markRoomVisited(room)
    local uid = room:GetAttribute("RoomUID")
    if uid and not VisitedRooms[uid] then
        VisitedRooms[uid] = true
        visitedCount = visitedCount + 1
        if visitedCount > MAX_VISITED_ROOMS then
            VisitedRooms = {}
            visitedCount = 0
        end
    end
end

local function getRoomsNearPlayer()
    local pos = getPlayerPosition()
    local raw = CollectionService:GetTagged("Backrooms")
    local filtered = {}
    for _, r in ipairs(raw) do
        local rPos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
        local yDiff = math.abs(rPos.Y - pos.Y)
        if yDiff < 500 and (rPos - pos).Magnitude < 20000 then
            table.insert(filtered, r)
        end
    end
    return filtered
end

local function getRoomsByPriority(rooms, targetType)
    local bestRoom, bestType = nil, 0
    for _, room in ipairs(rooms) do
        local uid = room:GetAttribute("RoomUID")
        if isRoomVisited(uid) then continue end
        local lowerID = string.lower(room:GetAttribute("RoomID") or "")
        local isEgg = lowerID:find("titanicegg") or lowerID:find("deeplockedegg") or lowerID:find("keepout")
        if isEgg and DeadEggRooms[uid] and (os.clock() - DeadEggRooms[uid]) < DEAD_EGG_COOLDOWN then
            isEgg = false
        end
        if isEgg and not isEggAlive(room) then
            isEgg = false
            DeadEggRooms[uid] = os.clock()
        end
        local isFreeEgg = lowerID:find("freeegg") and isEggAlive(room)
        local mult = tonumber(room:GetAttribute("EggMultiplier")) or 0
        local matchType = true
        if getgenv().Config.TargetEggType ~= "Any" then
            local targetStr = string.lower(string.gsub(getgenv().Config.TargetEggType, " ", ""))
            local eggAttr = tostring(room:GetAttribute("EggType") or room:GetAttribute("EggName") or room:GetAttribute("Egg") or "")
            local attrStr = string.lower(string.gsub(eggAttr, " ", ""))
            if not lowerID:find(targetStr) and not attrStr:find(targetStr) then
                matchType = false
            end
        end

        local isBoss = false
        if getgenv().Config.DeepBackroomsMode then
            isBoss = lowerID:find("gamemaster") or lowerID:find("deepportalroom")
        else
            isBoss = lowerID:find("bosschest") or lowerID:find("minichest") or lowerID:find("miniboss") or lowerID:find("boss")
                or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
        end

        local isVault, isBreakable, isEvent = false, false, false
        if getgenv().Config.DeepBackroomsMode then
            isVault = lowerID:find("deepchestroom") or lowerID:find("deepvault")
            isBreakable = lowerID:find("deepcoinroom")
        else
            isVault = lowerID:find("vault") or lowerID:find("chest")
            isBreakable = lowerID:find("breakable")
        end
        isEvent = getgenv().Config.FarmDeepEvents and (
            lowerID:find("chalkboardkeypad") or lowerID:find("code") or lowerID:find("simonfloor")
            or lowerID:find("deeplaserpattern") or lowerID:find("buttons") or lowerID:find("colorbutton")
            or lowerID:find("keyforge") or lowerID:find("chestchoose") or lowerID:find("vending") or lowerID:find("garden")
        )

        -- Öncelik sıralaması (6 en yüksek)
        local priority = 0
        if isEvent then priority = 6
        elseif getgenv().Config.FindFreeEggRoom and isFreeEgg and matchType and mult >= getgenv().Config.TargetEggMultiplier then priority = 5
        elseif isEgg and getgenv().Config.FindKeepOutEgg and matchType and mult >= getgenv().Config.TargetEggMultiplier then priority = 4
        elseif isBoss then priority = 3
        elseif isVault then priority = 2
        elseif isBreakable then priority = 1
        end

        if priority > bestType then
            bestType = priority
            bestRoom = room
        end
    end
    return bestRoom, bestType
end

-- ========================================================================
-- 15. EGG HATCHING HELPERS
-- ========================================================================

local function getCustomEggCmds()
    local success, cmds = pcall(function()
        return require(ReplicatedStorage.Library.Client.CustomEggsCmds)
    end)
    return success and cmds or nil
end

local function getMaxHatch()
    local success, val = pcall(function()
        return require(ReplicatedStorage.Library.Client.EggCmds).GetMaxHatch()
    end)
    return success and val or 1
end

local function hatchEgg(room, isFreeEgg)
    local customCmds = getCustomEggCmds()
    local maxHatch = getMaxHatch()

    pcall(function()
        local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
        if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
    end)

    local lowerID = string.lower(room:GetAttribute("RoomID") or "")
    local eggMap = {
        nightmare = "Backrooms Nightmare Egg", smile = "Backrooms Smile Egg",
        flower = "Backrooms Flower Egg", gooey = "Backrooms Gooey Egg",
        scribble = "Backrooms Scribble Egg", tentacle = "Backrooms Tentacles Egg",
        keepout = "Backrooms Keep Out Egg", nightterror = "Backrooms Night Terror Egg",
        fear = "Backrooms Fear Egg", swirl = "Backrooms Swirl Egg",
        overgrown = "Backrooms Overgrown Egg", ender = "Backrooms Ender Egg",
        corrupt = "Backrooms Corrupt Egg", titanic = "Titanic Backrooms Egg",
        huge = "Huge Backrooms Egg"
    }
    local eggId = "Backrooms Nightmare Egg"
    for key, name in pairs(eggMap) do
        if lowerID:find(key) then eggId = name; break end
    end

    local customHatchRemote = Network and Network:FindFirstChild("CustomEggs_Hatch")
    local buyRemote = Network and (Network:FindFirstChild("Eggs_RequestPurchase") or Network:FindFirstChild("Eggs: RequestPurchase"))

    local customUid, eggModel, closestDist = nil, nil, 99999
    if customCmds and getRootPart() then
        for uid, obj in pairs(customCmds.All()) do
            if obj._position then
                local d = (getRootPart().Position - obj._position).Magnitude
                if d < closestDist then
                    closestDist = d
                    customUid = uid
                    eggModel = obj._model
                end
            end
        end
    end

    if customUid and customHatchRemote then
        if eggModel and getRootPart() then
            getRootPart().CFrame = eggModel:GetPivot() + Vector3.new(0, 5, 0)
            task.wait(0.2)
        end
        task.spawn(function()
            if customHatchRemote:IsA("RemoteEvent") then
                customHatchRemote:FireServer(customUid, maxHatch)
            else
                pcall(function() customHatchRemote:InvokeServer(customUid, maxHatch) end)
            end
        end)
    elseif buyRemote then
        if buyRemote:IsA("RemoteEvent") then
            buyRemote:FireServer(eggId, maxHatch)
        else
            pcall(function() buyRemote:InvokeServer(eggId, maxHatch) end)
        end
    end
end

-- ========================================================================
-- 16. EVENT ROOM HANDLER
-- ========================================================================

local function handleEventRoom(room)
    local uid = room:GetAttribute("RoomUID")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
    if not invokeCustom or not fireCustom then return end

    local roomName = string.lower(room:GetAttribute("RoomID") or "")
    if roomName:find("chalkboardkeypad") then
        local problem = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "GetProblem")
        if problem and type(problem) == "string" then
            local num1, op, num2 = string.match(problem, "(%d+)%s*([%+%-%*%/])%s*(%d+)")
            if num1 and op and num2 then
                num1, num2 = tonumber(num1), tonumber(num2)
                local ans = 0
                if op == "+" then ans = num1 + num2
                elseif op == "-" then ans = num1 - num2
                elseif op == "*" then ans = num1 * num2
                elseif op == "/" then ans = num1 / num2 end
                invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "SubmitAnswer", tostring(ans))
            end
        end
    elseif roomName:find("code") then
        local code = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "GetCode")
        if code then fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "Code", code) end
    elseif roomName:find("simonfloor") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "GetSequence")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "StepTile", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("deeplaserpattern") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "GetSolutionOrder")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "ButtonPressed", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("buttons") or roomName:find("colorbutton") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "GetCurrentOrder")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "ButtonPressed", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("keyforge") then
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "ForgeKey")
    elseif roomName:find("chestchoose") then
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "RedeemChooseChest", 1)
    elseif roomName:find("vending") then
        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "UseVending")
    end

    task.wait(0.5)
    local rewards = {}
    for _, v in ipairs(room:GetDescendants()) do
        if v.Name == "RandomReward" and v:IsA("Model") then table.insert(rewards, v) end
    end
    for _, rw in ipairs(rewards) do
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "ClaimRandomReward", rw)
    end
end

-- ========================================================================
-- 17. BOSS ROOM HANDLER
-- ========================================================================

local function handleBossRoom(room)
    local uid = room:GetAttribute("RoomUID")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")

    -- Kapı açma
    if room:FindFirstChild("LockedDoors") then
        if getgenv().Config.DeepBackroomsMode and invokeCustom then
            pcall(function() invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "UnlockDeep") end)
        elseif fireCustom then
            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "UnlockDoors")
        end
    end

    -- Boss döngüsü
    local isWaiting = false
    while getgenv().Config.MetaFarmActive do
        task.wait(1)
        local respawnTs = nil
        pcall(function() respawnTs = room:GetAttribute("RespawnTimestamp") end)
        local now = workspace:GetServerTimeNow()

        -- Boss sandığı var mı?
        local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
        local chestExists = false
        if breakablesFolder then
            local pos = getPlayerPosition()
            for _, b in ipairs(breakablesFolder:GetChildren()) do
                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                local bName = string.lower(b.Name)
                if bId:find("bosschest") or bName:find("bosschest") or bId:find("chest") or bName:find("chest") then
                    local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
                    if part and (part.Position - pos).Magnitude < 300 then
                        chestExists = true
                        break
                    end
                end
            end
        end
        if chestExists then
            task.wait(1)
            continue
        end

        if respawnTs and respawnTs > now then
            local remaining = math.ceil(respawnTs - now)
            -- Hybrid: eğer 15 saniyeden fazla kaldıysa yumurta ara
            if remaining > 15 and getgenv().Config.FindKeepOutEgg then
                getgenv().SmartFarmState.BossRespawningUntil = respawnTs
                getgenv().SmartFarmState.BossRoomUID = uid
                markRoomVisited(room)
                break
            end

            if getgenv().Config.HopOnBossCooldown then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({ Title = "🚀 Server Hopping!", Content = "Boss on cooldown. Finding new server...", Duration = 5 })
                end
                local req = request or http_request or (syn and syn.request)
                if req then
                    pcall(function()
                        local servers = req({
                            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                        }).Body
                        local decoded = HttpService:JSONDecode(servers)
                        if decoded and decoded.data then
                            for _, v in pairs(decoded.data) do
                                if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                                    TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
                                    break
                                end
                            end
                        end
                    end)
                end
                task.wait(5)
                break
            end

            if not isWaiting then
                isWaiting = true
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({ Title = "⏳ Boss Dead!", Content = "Respawning in " .. remaining .. "s", Duration = 5 })
                end
                if getgenv().LiveStats then getgenv().LiveStats.BossesKilled = getgenv().LiveStats.BossesKilled + 1 end
            end
            local waitTime = math.max(respawnTs - workspace:GetServerTimeNow() - 1, 0)
            if waitTime > 2 then task.wait(waitTime) end
        else
            isWaiting = false
        end
    end
end

-- ========================================================================
-- 18. MAIN LOOP
-- ========================================================================

task.spawn(function()
    while task.wait(0.2) do
        -- GodMode
        _G.BACKROOMS_GODMODE = getgenv().Config.GodMode
        if getrenv then getrenv()._G.BACKROOMS_GODMODE = _G.BACKROOMS_GODMODE end

        local root = getRootPart()
        if not root then continue end

        local active = getgenv().Config.MetaFarmActive
            or getgenv().Config.FindKeepOutEgg
            or getgenv().Config.FindFreeEggRoom
        if not active then continue end

        handleInstanceEntry()

        -- Boss respawn geri dönüş kontrolü
        local now = workspace:GetServerTimeNow()
        local bossWait = (getgenv().SmartFarmState.BossRespawningUntil or 0) - now
        if bossWait > 0 and bossWait <= 8 and getgenv().SmartFarmState.BossRoomUID then
            local rooms = CollectionService:GetTagged("Backrooms")
            for _, r in ipairs(rooms) do
                if r:GetAttribute("RoomUID") == getgenv().SmartFarmState.BossRoomUID then
                    safeTeleport(r, true)
                    task.wait(2)
                    getgenv().SmartFarmState.BossRespawningUntil = 0
                    getgenv().SmartFarmState.BossRoomUID = nil
                    break
                end
            end
            continue
        end

        -- State belirle
        local currentKeys = getDaydreamKeyCount()
        getgenv().LiveStats.CurrentKeys = currentKeys
        local shouldFarmKeys = currentKeys < getgenv().Config.TargetKeyCount
        local shouldHuntBoss = not shouldFarmKeys
        local isHybrid = false

        if getgenv().Config.MetaFarmActive then
            local bossWaitTime = (getgenv().SmartFarmState.BossRespawningUntil or 0) - now
            if bossWaitTime > 15 and getgenv().Config.FindKeepOutEgg then
                isHybrid = true
            else
                if shouldFarmKeys then
                    -- Key farm modu
                else
                    shouldHuntBoss = true
                end
            end
        elseif getgenv().Config.FindKeepOutEgg and currentKeys == 0 then
            shouldFarmKeys = true
        end

        local rooms = getRoomsNearPlayer()
        if #rooms == 0 then
            task.wait(1)
            continue
        end

        -- Eğer zaten boss odasındaysak, doğrudan boss handler'a geç
        local inBossRoom = false
        for _, r in ipairs(rooms) do
            local lowerID = string.lower(r:GetAttribute("RoomID") or "")
            local isBoss = false
            if getgenv().Config.DeepBackroomsMode then
                isBoss = lowerID:find("gamemaster")
            else
                isBoss = lowerID:find("bosschest") or lowerID:find("minichest") or lowerID:find("miniboss")
                    or lowerID:find("boss") or r:GetAttribute("BossChestUID") or r:GetAttribute("ActiveMinichests")
            end
            if isBoss and not r:FindFirstChild("LockedDoors") then
                local pos = r:IsA("Model") and r:GetPivot().Position or (r:IsA("BasePart") and r.Position or Vector3.zero)
                if (pos - getPlayerPosition()).Magnitude < 500 then
                    inBossRoom = true
                    break
                end
            end
        end
        if inBossRoom and shouldHuntBoss then
            -- Boss odasındayız, handler'a git
            local bossRoom = nil
            for _, r in ipairs(rooms) do
                local lowerID = string.lower(r:GetAttribute("RoomID") or "")
                local isBoss = false
                if getgenv().Config.DeepBackroomsMode then
                    isBoss = lowerID:find("gamemaster")
                else
                    isBoss = lowerID:find("bosschest") or lowerID:find("minichest") or lowerID:find("miniboss")
                        or lowerID:find("boss") or r:GetAttribute("BossChestUID") or r:GetAttribute("ActiveMinichests")
                end
                if isBoss and not r:FindFirstChild("LockedDoors") then
                    bossRoom = r
                    break
                end
            end
            if bossRoom then
                handleBossRoom(bossRoom)
                continue
            end
        end

        -- Radar Teleport (A*)
        if getgenv().Config.RadarTeleport then
            local radarTargets = {}
            if shouldHuntBoss then
                if getgenv().Config.DeepBackroomsMode then
                    table.insert(radarTargets, {"gamemaster", "deepportalroom"})
                else
                    table.insert(radarTargets, {"boss", "miniboss"})
                end
            end
            if shouldFarmKeys or getgenv().Config.FarmDeepChests then
                if getgenv().Config.DeepBackroomsMode then
                    table.insert(radarTargets, {"deepchestroom3", "deepcoinroom3"})
                    table.insert(radarTargets, {"deepchestroom2", "deepchestroom2"})
                    table.insert(radarTargets, {"deepchestroom", "deepchestroom"})
                else
                    table.insert(radarTargets, {"vault", "chest"})
                end
            end
            if isHybrid or getgenv().Config.FindKeepOutEgg then
                table.insert(radarTargets, {"keepout", "egg"})
            end
            if getgenv().Config.FarmDeepEvents then
                table.insert(radarTargets, {"chalkboardkeypad", "code"})
                table.insert(radarTargets, {"simonfloor", "deeplaserpattern"})
                table.insert(radarTargets, {"buttons", "colorbutton"})
                table.insert(radarTargets, {"keyforge", "chestchoose"})
                table.insert(radarTargets, {"vending", "garden"})
            end

            local teleported = false
            for _, tData in ipairs(radarTargets) do
                local targetVec, deadVec, deadCooldown, isPathNode = getTargetRoomVector(
                    tData[1], tData[2], VisitedRooms, rooms, DeadChestRooms
                )
                if targetVec then
                    if tData[1] == "boss" then getgenv().LiveStats.BossStatus = "Radar Locked 📡" end
                    local dist = (getPlayerPosition() - targetVec).Magnitude
                    local minDist = isPathNode and 50 or 300
                    if dist > minDist then
                        local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
                        if isPathNode and invokeCustom and rooms then
                            for _, r in ipairs(rooms) do
                                local rPos = r:GetPivot().Position
                                if (rPos - getPlayerPosition()).Magnitude < 150 then
                                    local uid = r:GetAttribute("RoomUID")
                                    if uid then
                                        pcall(function() invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "UnlockDeep") end)
                                    end
                                end
                            end
                        end
                        root.Anchored = true
                        root.CFrame = CFrame.new(targetVec + Vector3.new(0, 5, 0))
                        if Network and Network:FindFirstChild("RequestStreaming") then
                            pcall(function() Network.RequestStreaming:FireServer(targetVec) end)
                        end
                        local p = Instance.new("Part")
                        p.Name = "AntiVoidPart_Antigravity"
                        p.Size = Vector3.new(30, 2, 30)
                        p.Anchored = true
                        p.CFrame = CFrame.new(targetVec - Vector3.new(0, 1, 0))
                        p.Transparency = 1
                        p.Parent = workspace
                        Debris:AddItem(p, 10)
                        task.wait(1.2)
                        root.Anchored = false
                        teleported = true
                        break
                    end
                elseif deadVec and deadCooldown then
                    -- Bekleme durumu
                end
            end
            if teleported then continue end
        end

        -- Öncelikli oda seç
        local bestRoom, bestType = getRoomsByPriority(rooms, "all")

        if bestRoom and bestType > 0 then
            local uid = bestRoom:GetAttribute("RoomUID")
            local lowerID = string.lower(bestRoom:GetAttribute("RoomID") or "")

            safeTeleport(bestRoom, false)

            if bestType == 6 then
                handleEventRoom(bestRoom)
                markRoomVisited(bestRoom)
                task.wait(1)
            elseif bestType == 5 then
                -- Free Egg
                if getgenv().RLW_Window then
                    local mult = bestRoom:GetAttribute("EggMultiplier") or "?"
                    getgenv().RLW_Window:Notify({ Title = "🎁 Free Egg Room!", Content = mult .. "x Huge Chance!", Duration = 10, Image = 4483362458 })
                end
                while getgenv().Config.FindFreeEggRoom do
                    if not isEggAlive(bestRoom) then break end
                    hatchEgg(bestRoom, true)
                    task.wait(1.5)
                end
            elseif bestType == 4 then
                -- Normal/KeeOut Egg
                if isHybrid and not getgenv().SmartFarmState.EggRoomUID then
                    getgenv().SmartFarmState.EggRoomUID = uid
                end
                while getgenv().Config.FindKeepOutEgg do
                    if isHybrid then
                        local bossTimer = getgenv().SmartFarmState.BossRespawningUntil or 0
                        local remaining = bossTimer - workspace:GetServerTimeNow()
                        local mult = tonumber(bestRoom:GetAttribute("EggMultiplier")) or 0
                        local isPriority = mult >= getgenv().Config.TargetEggMultiplier
                        if bossTimer > 0 and remaining <= 8 and not isPriority then
                            if getgenv().RLW_Window then
                                getgenv().RLW_Window:Notify({ Title = "⚔️ Boss Time!", Content = "Leaving egg for Boss spawn!", Duration = 3 })
                            end
                            break
                        end
                    end
                    if not isEggAlive(bestRoom) then
                        getgenv().SmartFarmState.EggRoomUID = nil
                        markRoomVisited(bestRoom)
                        break
                    end
                    hatchEgg(bestRoom, false)
                    task.wait(1.5)
                end
            elseif bestType == 3 then
                handleBossRoom(bestRoom)
            elseif bestType == 2 or bestType == 1 then
                -- Vault / Breakable
                local emptyCount = 0
                while getgenv().Config.MetaFarmActive do
                    task.wait(1)
                    local currentK = getDaydreamKeyCount()
                    getgenv().LiveStats.CurrentKeys = currentK
                    if currentK >= getgenv().Config.TargetKeyCount then break end

                    local breakablesFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Breakables")
                    local hasBreakable = false
                    local foundBig = false
                    if breakablesFolder then
                        local pos = getPlayerPosition()
                        for _, b in ipairs(breakablesFolder:GetChildren()) do
                            local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
                            if part and (part.Position - pos).Magnitude < 150 then
                                hasBreakable = true
                                local health = b:GetAttribute("MaxHealth") or b:GetAttribute("Health") or 0
                                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                                if health > 200 or bId:find("chest") or bId:find("vault") then foundBig = true end
                            end
                        end
                    end
                    if not hasBreakable then
                        emptyCount = emptyCount + 1
                        if emptyCount >= 4 then
                            markRoomVisited(bestRoom)
                            local respawnTs = nil
                            pcall(function() respawnTs = bestRoom:GetAttribute("RespawnTimestamp") end)
                            if getgenv().Config.DeepBackroomsMode then respawnTs = math.huge end
                            if respawnTs and respawnTs > workspace:GetServerTimeNow() then
                                if getgenv().CurrentRadarTargetCoordKey then
                                    getgenv().DeadCoords[getgenv().CurrentRadarTargetCoordKey] = respawnTs
                                end
                                DeadChestRooms[uid] = respawnTs
                            end
                            break
                        end
                    else
                        emptyCount = 0
                    end
                end
            end
            continue
        end

        -- Hiç öncelikli oda yoksa – haritayı keşfet (en uzak odaya zıpla)
        local sortedRooms = {}
        local isEggSearch = isHybrid or getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom
        for _, room in ipairs(rooms) do
            local uid = room:GetAttribute("RoomUID")
            if not VisitedRooms[uid] then
                if isEggSearch and DeadEggRooms[uid] and (os.clock() - DeadEggRooms[uid]) < DEAD_EGG_COOLDOWN then
                    continue
                end
                local pos = room:IsA("Model") and room:GetPivot().Position or Vector3.zero
                local charPos = getPlayerPosition()
                table.insert(sortedRooms, { Room = room, Dist = (pos - charPos).Magnitude, UID = uid })
            end
        end

        table.sort(sortedRooms, function(a, b) return a.Dist > b.Dist end)

        if #sortedRooms == 0 then
            if visitedCount > 300 and getgenv().Config.HopOnBossCooldown then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({ Title = "🚀 Dead Server!", Content = "Map fully explored. Hopping...", Duration = 5 })
                end
                local req = request or http_request or (syn and syn.request)
                if req then
                    pcall(function()
                        local servers = req({
                            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                        }).Body
                        local decoded = HttpService:JSONDecode(servers)
                        if decoded and decoded.data then
                            for _, v in pairs(decoded.data) do
                                if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                                    TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
                                    break
                                end
                            end
                        end
                    end)
                end
                task.wait(5)
            end
            VisitedRooms = {}
            visitedCount = 0
            if isEggSearch then
                DeadEggRooms = {}
                getgenv()._EggSpawnWaitTime = {}
                task.wait(3)
            else
                task.wait(1)
            end
            continue
        end

        local roomData = sortedRooms[1]
        local room = roomData.Room
        -- Odanın kenarlarına zıplayarak yüklenmesini tetikle
        local edgeParts = {}
        local edgeNames = {"door", "exit", "entrance", "portal", "hallway", "corridor"}
        for _, part in ipairs(room:GetDescendants()) do
            if part:IsA("BasePart") then
                local pName = string.lower(part.Name)
                for _, n in ipairs(edgeNames) do
                    if pName:find(n) then table.insert(edgeParts, part); break end
                end
            end
        end
        if #edgeParts > 0 then
            for i = 1, math.min(5, #edgeParts) do
                safeTeleport(edgeParts[i], true)
                task.wait(0.65)
            end
        elseif room:IsA("Model") then
            local pivot = room:GetPivot()
            local size = room:GetExtentsSize()
            local halfX, halfZ = size.X / 2, size.Z / 2
            local offsets = {
                Vector3.new(halfX, 0, 0), Vector3.new(-halfX, 0, 0),
                Vector3.new(0, 0, halfZ), Vector3.new(0, 0, -halfZ)
            }
            for _, off in ipairs(offsets) do
                local rootPart = getRootPart()
                if rootPart then
                    rootPart.CFrame = pivot * CFrame.new(off)
                    task.wait(0.15)
                end
            end
        end

        safeTeleport(room, false)

        -- Kapı açma / buton vs.
        local uid = room:GetAttribute("RoomUID")
        local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
        local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")

        if fireCustom then
            if room:FindFirstChild("LockedDoors") then
                local locked = true
                for _, door in ipairs(room.LockedDoors:GetChildren()) do
                    if door:GetAttribute("HasConnection") then
                        local lock = door:FindFirstChild("Lock")
                        if lock and lock.Transparency == 1 then locked = false; break end
                    end
                end
                if locked then
                    local lowerID = string.lower(room:GetAttribute("RoomID") or "")
                    local isBoss = lowerID:find("bosschest") or lowerID:find("minichest") or lowerID:find("miniboss")
                        or lowerID:find("boss") or room:GetAttribute("BossChestUID") or room:GetAttribute("ActiveMinichests")
                    local isEgg = lowerID:find("titanicegg") or lowerID:find("hugeegg") or lowerID:find("egg") or lowerID:find("keepout")
                    local shouldUnlock = false
                    if shouldHuntBoss and isBoss then shouldUnlock = true
                    elseif (getgenv().Config.FindKeepOutEgg or getgenv().Config.FindFreeEggRoom or isHybrid) and isEgg then shouldUnlock = true
                    elseif #sortedRooms <= 2 then shouldUnlock = true
                    end
                    if shouldUnlock then
                        if getgenv().Config.DeepBackroomsMode and invokeCustom then
                            pcall(function() invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "UnlockDeep") end)
                        else
                            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "UnlockDoors")
                        end
                    end
                end
            end

            local lowerID = string.lower(room:GetAttribute("RoomID") or "")
            if lowerID:find("chestchoose") then
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "PickChest", 1)
            end

            for _, child in ipairs(room:GetChildren()) do
                if child.Name == "Buttons" then
                    for _, btn in ipairs(child:GetChildren()) do
                        local num = tonumber(btn.Name) or tonumber(string.match(btn.Name, "%d+"))
                        if num then fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "ButtonPressed", num) end
                    end
                    fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "ButtonPressed")
                elseif child.Name == "Levers" then
                    for _, lever in ipairs(child:GetChildren()) do
                        local num = tonumber(lever.Name) or tonumber(string.match(lever.Name, "%d+"))
                        if num then fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "FlipLever", num) end
                    end
                elseif child.Name == "Faucets" then
                    for _, faucet in ipairs(child:GetChildren()) do
                        local num = tonumber(faucet.Name) or tonumber(string.match(faucet.Name, "%d+"))
                        if num then fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", uid, "FaucetTurned", num) end
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
                            invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", uid, "ClaimRandomReward", obj)
                        end)
                    end
                end
            end
        end

        -- ProximityPrompt
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

        markRoomVisited(room)
    end
end)

-- ========================================================================
-- 19. AUTO HATCH NEAREST
-- ========================================================================

task.spawn(function()
    local customCmds = getCustomEggCmds()
    local hatchRemote = Network and Network:FindFirstChild("CustomEggs_Hatch")
    while task.wait(1) do
        if not getgenv().Config.AutoHatchNearest or not hatchRemote or not customCmds then continue end
        local root = getRootPart()
        if not root then continue end
        local bestUid, bestDist = nil, 99999
        for uid, obj in pairs(customCmds.All()) do
            if obj._position then
                local d = (root.Position - obj._position).Magnitude
                if d < bestDist then bestDist = d; bestUid = uid end
            end
        end
        if bestUid then
            pcall(function()
                local fe = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
                if fe and fe.PlayEggAnimation then fe.PlayEggAnimation = function() end end
            end)
            local maxHatch = getMaxHatch()
            task.spawn(function()
                if hatchRemote:IsA("RemoteEvent") then
                    hatchRemote:FireServer(bestUid, maxHatch)
                else
                    pcall(function() hatchRemote:InvokeServer(bestUid, maxHatch) end)
                end
            end)
        end
    end
end)

-- ========================================================================
-- 20. AUTO MAILBOX
-- ========================================================================

task.spawn(function()
    while task.wait(30) do
        if not getgenv().Config.AutoMailbox then continue end
        pcall(function()
            local remote = Network and Network:FindFirstChild("Mailbox: Claim All")
            if remote then
                if remote:IsA("RemoteFunction") then remote:InvokeServer() else remote:FireServer() end
            end
        end)
    end
end)

-- ========================================================================
-- 21. UI
-- ========================================================================

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

local TabRadar   = Window:CreateTab("🚀 Deep Radar")
local TabCombat  = Window:CreateTab("⚔️ Combat")
local TabEggs    = Window:CreateTab("🥚 Egg Hunter")
local TabUpgrades= Window:CreateTab("🆙 Upgrades")
local TabStats   = Window:CreateTab("📊 Stats")
local TabScanner = Window:CreateTab("📡 Scanner")
local TabSettings= Window:CreateTab("⚙️ Settings")

-- 🚀 Deep Radar
TabRadar:CreateSection("Radar Teleport (God Mode)")
TabRadar:CreateToggle({
    Name = "A* Pathfinding Radar",
    CurrentValue = getgenv().Config.RadarTeleport,
    Flag = "Tgl_RadarTeleport",
    Callback = function(v) getgenv().Config.RadarTeleport = v end
})
TabRadar:CreateSlider({
    Name = "Target Key Count (Start Radar)",
    Range = {0, 100},
    CurrentValue = getgenv().Config.TargetKeyCount,
    Flag = "Sld_TargetKeys",
    Callback = function(v) getgenv().Config.TargetKeyCount = v end
})
TabRadar:CreateSection("Deep Backrooms Entry")
TabRadar:CreateToggle({
    Name = "🌌 Deep Backrooms Mode",
    CurrentValue = getgenv().Config.DeepBackroomsMode,
    Flag = "Tgl_DeepBackroomsMode",
    Callback = function(v) getgenv().Config.DeepBackroomsMode = v end
})

-- ⚔️ Combat
TabCombat:CreateSection("Smart Farm & Breakables")
TabCombat:CreateToggle({
    Name = "Start Boss Farming (Meta)",
    CurrentValue = getgenv().Config.MetaFarmActive,
    Flag = "Tgl_MetaFarm",
    Callback = function(v) getgenv().Config.MetaFarmActive = v end
})
TabCombat:CreateToggle({
    Name = "⚡ Fast Farm Breakables",
    CurrentValue = getgenv().Config.FastFarmBreakables,
    Flag = "Tgl_FastFarm",
    Callback = function(v) getgenv().Config.FastFarmBreakables = v end
})
TabCombat:CreateSection("Deep Events & Loot")
TabCombat:CreateToggle({
    Name = "💰 Always Farm Chest/Vault Rooms",
    CurrentValue = getgenv().Config.FarmDeepChests,
    Flag = "Tgl_FarmDeepChests",
    Callback = function(v) getgenv().Config.FarmDeepChests = v end
})
TabCombat:CreateToggle({
    Name = "🧩 Auto-Complete Deep Events",
    CurrentValue = getgenv().Config.FarmDeepEvents,
    Flag = "Tgl_FarmDeepEvents",
    Callback = function(v) getgenv().Config.FarmDeepEvents = v end
})
TabCombat:CreateToggle({
    Name = "Auto Loot Chests/Rewards",
    CurrentValue = getgenv().Config.AutoLoot,
    Flag = "Tgl_AutoLoot",
    Callback = function(v) getgenv().Config.AutoLoot = v end
})

-- 🥚 Egg Hunter
TabEggs:CreateSection("Auto Hatching")
TabEggs:CreateToggle({
    Name = "🥚 Auto Hatch Nearest Egg",
    CurrentValue = getgenv().Config.AutoHatchNearest,
    Flag = "Tgl_AutoHatchNearest",
    Callback = function(v) getgenv().Config.AutoHatchNearest = v end
})
TabEggs:CreateDropdown({
    Name = "Target Egg Type",
    Options = {"Any", "KeepOut", "Huge", "Titanic", "Free"},
    CurrentOption = getgenv().Config.TargetEggType,
    Flag = "Drp_TargetEggType",
    Callback = function(opt)
        if type(opt) == "table" then getgenv().Config.TargetEggType = opt[1]
        else getgenv().Config.TargetEggType = opt end
    end
})
TabEggs:CreateSlider({
    Name = "Minimum Egg Multiplier",
    Range = {1, 100},
    CurrentValue = getgenv().Config.TargetEggMultiplier,
    Flag = "Sld_EggMultiplier",
    Callback = function(v) getgenv().Config.TargetEggMultiplier = v end
})
TabEggs:CreateToggle({
    Name = "Target Free Egg Rooms",
    CurrentValue = getgenv().Config.FindFreeEggRoom,
    Flag = "Tgl_FindFreeEgg",
    Callback = function(v) getgenv().Config.FindFreeEggRoom = v end
})

-- 🆙 Upgrades
TabUpgrades:CreateSection("Auto Upgrade Machine")
local function makeUpgradeToggle(name, flag, key)
    TabUpgrades:CreateToggle({
        Name = name,
        CurrentValue = false,
        Flag = flag,
        Callback = function(v) getgenv().Config.AutoUpgrades[key] = v end
    })
end
makeUpgradeToggle("Boss Damage", "Tgl_Up_BossDmg", "BackroomsBossDamage")
makeUpgradeToggle("Extra Loot Roll", "Tgl_Up_ExtraLoot", "BackroomsExtraLootRoll")
makeUpgradeToggle("Token Find", "Tgl_Up_TokenFind", "BackroomsTokenFind")
makeUpgradeToggle("Deep Boss Damage", "Tgl_Up_DeepBossDmg", "BackroomsDeepBossDamage")
makeUpgradeToggle("Coin Multiplier", "Tgl_Up_CoinMult", "BackroomsCoinMultiplier")
makeUpgradeToggle("Egg Luck", "Tgl_Up_EggLuck", "BackroomsEggLuck")
makeUpgradeToggle("Key Find", "Tgl_Up_KeyFind", "BackroomsKeyFind")

-- 📊 Stats
TabStats:CreateSection("Session Information")
local lblTime = TabStats:CreateLabel({ Name = "⏱️ Session Time", CurrentValue = "00:00:00" })
local lblRooms = TabStats:CreateLabel({ Name = "🚪 Rooms Explored", CurrentValue = "0", Color = Color3.fromRGB(150,150,255) })
local lblKeys = TabStats:CreateLabel({ Name = "🔑 Target Keys", CurrentValue = "0 / 0", Color = Color3.fromRGB(200,255,100) })
local lblHighest = TabStats:CreateLabel({ Name = "🚀 Highest Multiplier", CurrentValue = "0x", Color = Color3.fromRGB(255,215,0) })
local lblBosses = TabStats:CreateLabel({ Name = "⚔️ Bosses Defeated", CurrentValue = "0", Color = Color3.fromRGB(255,100,100) })
local lblBossStatus = TabStats:CreateLabel({ Name = "👁️ Boss Radar", CurrentValue = "Searching...", Color = Color3.fromRGB(200,200,200) })

task.spawn(function()
    while task.wait(1) do
        local stats = getgenv().LiveStats
        if not stats then continue end
        local elapsed = os.time() - stats.StartTime
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        local timeStr = string.format("%02d:%02d:%02d", h, m, s)
        pcall(function()
            lblTime:SetText(timeStr)
            lblRooms:SetText(tostring(stats.RoomsExplored))
            lblKeys:SetText(tostring(stats.CurrentKeys) .. " / " .. tostring(getgenv().Config.TargetKeyCount))
            local multStr = tostring(stats.HighestMultiplier) .. "x"
            if stats.HighestMultiplierName then multStr = multStr .. " (" .. stats.HighestMultiplierName .. ")" end
            lblHighest:SetText(multStr)
            lblBosses:SetText(tostring(stats.BossesKilled))
            lblBossStatus:SetText(stats.BossStatus)
        end)
    end
end)

-- 📡 Scanner
TabScanner:CreateSection("Deep Backrooms Live Scanner")
local scannedRoomsList = {"[Scan to find rooms]"}
local scannedRoomsMap = {}
local selectedScannedRoom = nil
local ScannerDropdown = TabScanner:CreateDropdown({
    Name = "Found Rooms",
    Options = scannedRoomsList,
    CurrentOption = scannedRoomsList[1],
    Flag = "Drp_ScannedRooms",
    Callback = function(opt)
        if type(opt) == "table" then selectedScannedRoom = opt[1]
        else selectedScannedRoom = opt end
    end
})
TabScanner:CreateButton({
    Name = "🚀 Teleport To Selected Room",
    Callback = function()
        if not selectedScannedRoom then return end
        local uidMatch = selectedScannedRoom:match("UID: ([a-f0-9%-]+)")
        if uidMatch and scannedRoomsMap[uidMatch] then
            local room = scannedRoomsMap[uidMatch]
            local root = getRootPart()
            if root and room:GetPivot() then
                root.CFrame = room:GetPivot() + Vector3.new(0, 5, 0)
            end
        end
    end
})
TabScanner:CreateButton({
    Name = "🔄 Scan All Rooms",
    Callback = function()
        scannedRoomsList = {}
        scannedRoomsMap = {}
        local rooms = CollectionService:GetTagged("Backrooms")
        for _, room in ipairs(rooms) do
            local uid = room:GetAttribute("RoomUID")
            if not uid then continue end
            local id = room:GetAttribute("RoomID") or "Unknown"
            local lower = string.lower(id)
            local isEgg = lower:find("keepout") or lower:find("hugeegg") or lower:find("titanicegg") or lower:find("freeegg")
            local isBoss = lower:find("boss") or lower:find("minichest")
            if isEgg or isBoss then
                local label = id
                if isEgg then
                    if not isEggAlive(room) then label = "💀 [DEAD] " .. label
                    else
                        local eggType = room:GetAttribute("EggType") or room:GetAttribute("EggName")
                        if eggType then label = label .. " (" .. tostring(eggType) .. ")" end
                        local mult = room:GetAttribute("EggMultiplier")
                        if mult then label = "[" .. tostring(mult) .. "x] " .. label end
                    end
                elseif isBoss then
                    label = "⚔️ " .. label
                end
                label = label .. " (UID: " .. tostring(uid) .. ")"
                table.insert(scannedRoomsList, label)
                scannedRoomsMap[tostring(uid)] = room
            end
        end
        if #scannedRoomsList == 0 then table.insert(scannedRoomsList, "[No rooms found!]") end
        ScannerDropdown:RefreshOptions(scannedRoomsList)
    end
})

-- ⚙️ Settings
TabSettings:CreateSection("Mailbox & Webhook")
TabSettings:CreateToggle({
    Name = "Auto Claim Mailbox",
    CurrentValue = getgenv().Config.AutoMailbox,
    Flag = "Tgl_AutoMailbox",
    Callback = function(v) getgenv().Config.AutoMailbox = v end
})
TabSettings:CreateToggle({
    Name = "Enable Webhook Logs",
    CurrentValue = getgenv().Config.WebhookEnabled,
    Flag = "Tgl_Webhook",
    Callback = function(v) getgenv().Config.WebhookEnabled = v end
})
TabSettings:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) getgenv().Config.WebhookURL = t end
})
TabSettings:CreateSection("Server Management")
TabSettings:CreateToggle({
    Name = "🛡️ God Mode (Invincible)",
    CurrentValue = getgenv().Config.GodMode,
    Flag = "Tgl_GodMode",
    Callback = function(v) getgenv().Config.GodMode = v end
})
TabSettings:CreateToggle({
    Name = "🚀 Hop on Boss Cooldown",
    CurrentValue = getgenv().Config.HopOnBossCooldown,
    Flag = "Tgl_HopOnBossCooldown",
    Callback = function(v) getgenv().Config.HopOnBossCooldown = v end
})
TabSettings:CreateButton({
    Name = "🔄 Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})
TabSettings:CreateButton({
    Name = "🚀 Server Hop",
    Callback = function()
        local req = request or http_request or (syn and syn.request)
        if req then
            pcall(function()
                local servers = req({
                    Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                }).Body
                local decoded = HttpService:JSONDecode(servers)
                if decoded and decoded.data then
                    for _, v in pairs(decoded.data) do
                        if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
                            break
                        end
                    end
                end
            end)
        end
    end
})

Window:LoadConfiguration()
