-- Main.lua
-- Central Coordinator and UI Manager for Backrooms Farm

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Module loader helper
local function loadModule(name)
    local path = "BackroomsModules/" .. name .. ".lua"
    local content
    
    if isfile and isfile(path) then
        content = readfile(path)
    else
        local baseUrl = getgenv().BackroomsBaseUrl or "https://raw.githubusercontent.com/therlw/rlwscripts/refs/heads/main/BackroomsModules/"
        content = game:HttpGet(baseUrl .. name .. ".lua")
    end
    
    if content then
        local fn, err = loadstring(content, "@BackroomsModules/" .. name .. ".lua")
        if fn then
            return fn()
        else
            error("Error parsing module " .. name .. ": " .. tostring(err))
        end
    else
        error("Module not found: " .. name)
    end
end

-- Load all modules in sequence
loadModule("Config")
local Utils = loadModule("Utils")
loadModule("Bypasses")
loadModule("Webhooks")
loadModule("EggHatcher")
loadModule("BreakableFarmer")
loadModule("Solvers")
loadModule("ChestFarmer")
loadModule("BossHunter")
loadModule("Explorer")
loadModule("MainLogic")

-- ==========================
-- ⚙️ AUTO UPGRADE LOOP
-- ==========================
task.spawn(function()
    while task.wait(5) do
        local config = getgenv().Config
        if not config or not config.AutoUpgrades then continue end
        
        do
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
        end
    end
end)

-- ==========================
-- 📡 EGG ROOM DATA SYNC
-- ==========================
task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Network = ReplicatedStorage:WaitForChild("Network", 5)
    if not Network then return end
    local RequestEggRooms = Network:FindFirstChild("Backrooms: Request Egg Rooms")

    while task.wait(10) do
        if getgenv().Config.FindEggRooms and RequestEggRooms then
            local response = RequestEggRooms:InvokeServer()
            if type(response) == "table" then
                local Shared = getgenv().BackroomsShared
                Shared.TargetEggRooms = {}
                for _, eggData in ipairs(response) do
                    if eggData.UID then
                        Shared.TargetEggRooms[eggData.UID] = eggData
                    end
                end
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

local TabRadar = Window:CreateTab("🚀 Deep Radar")
local TabCombat = Window:CreateTab("⚔️ Combat")
local TabEggs = Window:CreateTab("🥚 Egg Hunter")
local TabUpgrades = Window:CreateTab("🆙 Upgrades")
local TabStats = Window:CreateTab("📊 Stats")
local TabScanner = Window:CreateTab("📡 Scanner")
local TabSettings = Window:CreateTab("⚙️ Settings")

-- 🚀 DEEP RADAR TAB (MAIN) --
TabRadar:CreateSection("Deep Backrooms Automation")

TabRadar:CreateToggle({
    Name = "Master Switch: Enable Deep Radar",
    CurrentValue = getgenv().Config.RadarTeleport,
    Flag = "Tgl_RadarTeleport",
    Callback = function(Value)
        getgenv().Config.RadarTeleport = Value
        if Value and getgenv().RLW_Window then
            getgenv().RLW_Window:Notify({Title = "⚠️ WARNING", Content = "Radar Teleport bypasses physics! It will teleport you instantly.", Duration = 5})
        end
    end
})

TabRadar:CreateToggle({
    Name = "🗺️ Explore All Rooms First (Max 400)",
    CurrentValue = false,
    Flag = "Tgl_ExploreFirst",
    Callback = function(Value) getgenv().Config.ExploreMapFirst = Value end
})

TabRadar:CreateToggle({
    Name = "⚔️ Auto Boss Hunt",
    CurrentValue = false,
    Flag = "Tgl_AutoBoss",
    Callback = function(Value) getgenv().Config.AutoBossHunt = Value end
})

TabRadar:CreateToggle({
    Name = "💰 Auto Farm Deep Chests",
    CurrentValue = false,
    Flag = "Tgl_AutoChests",
    Callback = function(Value) getgenv().Config.AutoFarmChests = Value end
})

TabRadar:CreateToggle({
    Name = "🪙 Auto Farm Deep Coins (Breakables)",
    CurrentValue = false,
    Flag = "Tgl_AutoCoins",
    Callback = function(Value) getgenv().Config.AutoFarmCoins = Value end
})

TabRadar:CreateToggle({
    Name = "🧩 Auto Farm Deep Events",
    CurrentValue = false,
    Flag = "Tgl_AutoEvents",
    Callback = function(Value) getgenv().Config.AutoFarmEvents = Value end
})

TabRadar:CreateToggle({
    Name = "🥚 Auto Farm Eggs",
    CurrentValue = false,
    Flag = "Tgl_AutoEggs",
    Callback = function(Value) getgenv().Config.AutoFarmEggs = Value end
})

TabRadar:CreateSection("Deep Backrooms Entry")

TabRadar:CreateToggle({
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

-- ⚔️ COMBAT TAB --
TabCombat:CreateSection("Smart Farm & Breakables")

TabCombat:CreateToggle({
    Name = "⚡ Fast Farm Breakables",
    CurrentValue = false,
    Flag = "Tgl_FastFarm",
    Callback = function(Value)
        getgenv().Config.FastFarmBreakables = Value
    end
})

TabCombat:CreateSection("Deep Events & Loot")

TabCombat:CreateToggle({
    Name = "💰 Always Farm Chest/Vault Rooms",
    CurrentValue = false,
    Flag = "Tgl_FarmDeepChests",
    Callback = function(Value)
        getgenv().Config.FarmDeepChests = Value
    end
})

TabCombat:CreateToggle({
    Name = "🧩 Auto-Complete Deep Events",
    CurrentValue = false,
    Flag = "Tgl_FarmDeepEvents",
    Callback = function(Value)
        getgenv().Config.FarmDeepEvents = Value
    end
})

TabCombat:CreateToggle({
    Name = "Auto Loot Chests/Rewards",
    CurrentValue = false,
    Flag = "Tgl_AutoLoot",
    Callback = function(Value) getgenv().Config.AutoLoot = Value end
})

-- 🥚 EGG HUNTER TAB --
TabEggs:CreateSection("Auto Hatching")

TabEggs:CreateToggle({
    Name = "🥚 Auto Hatch Nearest Egg",
    CurrentValue = false,
    Flag = "Tgl_AutoHatchNearest",
    Callback = function(Value) getgenv().Config.AutoHatchNearest = Value end
})

TabEggs:CreateDropdown({
    Name = "Target Egg Type",
    Options = {"Any", "Danger", "Night Terror", "Corrupt", "Keep Out", "Eyes", "Tentacles", "Scribble", "Rain", "Ender", "Nightmare", "Smile", "Flower", "Gooey", "Fear", "Swirl", "Overgrown", "Heart", "Balloon"},
    CurrentOption = "Any",
    Flag = "Drp_TargetEggType",
    Callback = function(Option) 
        if type(Option) == "table" then
            getgenv().Config.TargetEggType = Option[1]
        else
            getgenv().Config.TargetEggType = Option
        end
    end
})

TabEggs:CreateSlider({
    Name = "Minimum Egg Multiplier",
    Range = {1, 250},
    CurrentValue = 50,
    Flag = "Sld_EggMultiplier",
    Callback = function(Value) getgenv().Config.TargetEggMultiplier = Value end
})

-- 🆙 UPGRADES TAB --
TabUpgrades:CreateSection("Auto Upgrade Machine")

local function makeUpgradeToggle(name, flag, confKey)
    TabUpgrades:CreateToggle({
        Name = name,
        CurrentValue = false,
        Flag = flag,
        Callback = function(Value)
            getgenv().Config.AutoUpgrades[confKey] = Value
        end
    })
end

makeUpgradeToggle("Boss Damage", "Tgl_Up_BossDmg", "BackroomsBossDamage")
makeUpgradeToggle("Extra Loot Roll", "Tgl_Up_ExtraLoot", "BackroomsExtraLootRoll")
makeUpgradeToggle("Token Find", "Tgl_Up_TokenFind", "BackroomsTokenFind")
makeUpgradeToggle("Deep Boss Damage", "Tgl_Up_DeepBossDmg", "BackroomsDeepBossDamage")
makeUpgradeToggle("Coin Multiplier", "Tgl_Up_CoinMult", "BackroomsCoinMultiplier")
makeUpgradeToggle("Egg Luck", "Tgl_Up_EggLuck", "BackroomsEggLuck")
makeUpgradeToggle("Key Find", "Tgl_Up_KeyFind", "BackroomsKeyFind")

-- 📊 STATS TAB --
TabStats:CreateSection("Session Information")
local lblTime = TabStats:CreateLabel({Name = "⏱️ Session Time", CurrentValue = "00:00:00"})
local lblRooms = TabStats:CreateLabel({Name = "🚪 Rooms Explored", CurrentValue = "0", Color = Color3.fromRGB(150, 150, 255)})
local lblHighest = TabStats:CreateLabel({Name = "🚀 Highest Multiplier", CurrentValue = "0x", Color = Color3.fromRGB(255, 215, 0)})
local lblBosses = TabStats:CreateLabel({Name = "⚔️ Bosses Defeated", CurrentValue = "0", Color = Color3.fromRGB(255, 100, 100)})
local lblBossStatus = TabStats:CreateLabel({Name = "👁️ Boss Radar", CurrentValue = "Searching...", Color = Color3.fromRGB(200, 200, 200)})

task.spawn(function()
    while task.wait(1) do
        if not getgenv().LiveStats then continue end
        local elapsed = os.time() - getgenv().LiveStats.StartTime
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)
        do
            if lblTime and lblTime.SetText then lblTime:SetText(timeStr) end
            if lblRooms and lblRooms.SetText then lblRooms:SetText(tostring(getgenv().LiveStats.RoomsExplored)) end
            if lblHighest and lblHighest.SetText then 
                local multStr = tostring(getgenv().LiveStats.HighestMultiplier) .. "x"
                if getgenv().LiveStats.HighestMultiplierName then multStr = multStr .. " (" .. getgenv().LiveStats.HighestMultiplierName .. ")" end
                lblHighest:SetText(multStr) 
            end
            if lblBosses and lblBosses.SetText then lblBosses:SetText(tostring(getgenv().LiveStats.BossesKilled)) end
            if lblBossStatus and lblBossStatus.SetText then lblBossStatus:SetText(getgenv().LiveStats.BossStatus) end
        end
    end
end)

-- 📡 SCANNER TAB --
TabScanner:CreateSection("Deep Backrooms Live Scanner")
local scannedRoomsList = {"[Scan to find rooms]"}
local scannedRoomsMap = {}
local selectedScannedRoom = nil
local ScannerDropdown = TabScanner:CreateDropdown({
    Name = "Found Rooms",
    Options = scannedRoomsList,
    CurrentOption = scannedRoomsList[1],
    Flag = "Drp_ScannedRooms",
    Callback = function(Option) 
        if type(Option) == "table" then
            selectedScannedRoom = Option[1]
        else
            selectedScannedRoom = Option
        end
    end
})

TabScanner:CreateButton({
    Name = "🚀 Teleport To Selected Room",
    Callback = function()
        if selectedScannedRoom then
            local uidMatch = selectedScannedRoom:match("UID: ([a-f0-9%-]+)")
            if uidMatch and scannedRoomsMap[uidMatch] then
                local room = scannedRoomsMap[uidMatch]
                local root = Utils.getRootPart()
                if root and room:GetPivot() then root.CFrame = room:GetPivot() + Vector3.new(0, 5, 0) end
            end
        end
    end
})

TabScanner:CreateButton({
    Name = "🔄 Scan All Rooms",
    Callback = function()
        local CollectionService = game:GetService("CollectionService")
        scannedRoomsList = {}
        scannedRoomsMap = {}
        local rooms_all = CollectionService:GetTagged("Backrooms")
        local rooms = {}
        for _, r in ipairs(rooms_all) do
            local isDeep = r:GetAttribute("DeepRoom") == true
            local targetDeep = getgenv().Config.DeepBackroomsMode == true
            if isDeep == targetDeep then
                table.insert(rooms, r)
            end
        end
        for _, room in ipairs(rooms) do
            local roomUID = room:GetAttribute("RoomUID")
            local roomID = room:GetAttribute("RoomID") or "Unknown"
            local lowerID = string.lower(roomID)
            if not roomUID then continue end
            local isEgg = lowerID:find("keepout") or lowerID:find("hugeegg") or lowerID:find("titanicegg") or lowerID:find("freeegg")
            local isBoss = lowerID:find("boss") or lowerID:find("minichest")
            if isEgg or isBoss then
                local label = roomID
                if isEgg then
                    if not Utils.isEggAlive(room) then label = "💀 [DEAD] " .. label else
                        local eggType = room:GetAttribute("EggType") or room:GetAttribute("EggName")
                        if eggType then label = label .. " (" .. tostring(eggType) .. ")" end
                        local multiplier = room:GetAttribute("EggMultiplier")
                        if multiplier then label = "[" .. tostring(multiplier) .. "x] " .. label end
                    end
                elseif isBoss then label = "⚔️ " .. label end
                label = label .. " (UID: " .. tostring(roomUID) .. ")"
                table.insert(scannedRoomsList, label)
                scannedRoomsMap[tostring(roomUID)] = room
            end
        end
        if #scannedRoomsList == 0 then table.insert(scannedRoomsList, "[No rooms found!]") end
        if ScannerDropdown and ScannerDropdown.RefreshOptions then
            ScannerDropdown:RefreshOptions(scannedRoomsList)
            if getgenv().RLW_Window then getgenv().RLW_Window:Notify({Title = "Scan Complete", Content = "Found " .. tostring(#scannedRoomsList) .. " interesting rooms!", Duration = 3}) end
        end
    end
})

-- ⚙️ SETTINGS TAB --
TabSettings:CreateSection("Mailbox & Webhook")

TabSettings:CreateToggle({
    Name = "Auto Claim Mailbox",
    CurrentValue = false,
    Flag = "Tgl_AutoMailbox",
    Callback = function(Value) getgenv().Config.AutoMailbox = Value end
})

task.spawn(function()
    while task.wait(30) do
        if not getgenv().Config.AutoMailbox then continue end
        do
            local NetworkFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
            local remote = NetworkFolder and NetworkFolder:FindFirstChild("Mailbox: Claim All")
            if remote then
                if remote:IsA("RemoteFunction") then remote:InvokeServer() else remote:FireServer() end
            end
        end
    end
end)

TabSettings:CreateToggle({
    Name = "Enable Webhook Logs",
    CurrentValue = false,
    Flag = "Tgl_Webhook",
    Callback = function(Value) getgenv().Config.WebhookEnabled = Value end
})

TabSettings:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) getgenv().Config.WebhookURL = Text end
})

TabSettings:CreateInput({
    Name = "Webhook Ping Discord ID / Value",
    PlaceholderText = "Discord User ID or @everyone",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) getgenv().Config.WebhookPingValue = Text end
})

TabSettings:CreateSection("Server Management")

TabSettings:CreateToggle({
    Name = "🛡️ God Mode (Invincible)",
    CurrentValue = getgenv().Config.GodMode,
    Flag = "Tgl_GodMode",
    Callback = function(Value) getgenv().Config.GodMode = Value end
})

TabSettings:CreateToggle({
    Name = "🚀 Hop on Boss Cooldown",
    CurrentValue = false,
    Flag = "Tgl_HopOnBossCooldown",
    Callback = function(Value) getgenv().Config.HopOnBossCooldown = Value end
})

TabSettings:CreateButton({
    Name = "🔄 Rejoin Server",
    Callback = function()
        local ts = game:GetService("TeleportService")
        local p = game:GetService("Players").LocalPlayer
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
    end
})

TabSettings:CreateButton({
    Name = "🚀 Server Hop",
    Callback = function()
        local Utils = getgenv().BackroomsUtils
        if Utils and Utils.serverHop then
            Utils.serverHop()
        else
            local HttpService = game:GetService("HttpService")
            local TeleportService = game:GetService("TeleportService")
            local req = request or http_request or (syn and syn.request)
            if req then
                local servers = req({Url = "https://games.roproxy.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"}).Body
                local decoded = HttpService:JSONDecode(servers)
                if decoded and decoded.data then
                    for _, v in ipairs(decoded.data) do
                        if type(v) == "table" and v.playing and v.playing < v.maxPlayers and v.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, game:GetService("Players").LocalPlayer)
                            break
                        end
                    end
                end
            end
        end
    end
})

Window:LoadConfiguration()

Window:Notify({Title = "Success", Content = "Modular Backrooms Script Loaded Successfully!", Duration = 5})
