-- Webhooks.lua
-- Discord Webhook Logging and Inventory Monitoring

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Shared = getgenv().BackroomsShared

local KnownUIDs      = {}
local StartHuges     = 0
local StartTitanics  = 0
local CurrentHuges   = 0
local CurrentTitanics= 0

local function GetPetDir()
    local petDir = require(ReplicatedStorage.Library.Directory.Pets)
    return petDir
end

local function InitSessionStats()
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

    local payload = {
        ["username"] = "RLWSCRIPTS Notification",
        ["embeds"]   = { embed }
    }
    
    local ping = getgenv().Config.WebhookPingValue
    if ping and tostring(ping) ~= "" then
        local pingStr = tostring(ping)
        if pingStr:match("^%d+$") then
            payload["content"] = "<@" .. pingStr .. ">"
        else
            payload["content"] = pingStr
        end
    end

    requestFn({
        Url     = getgenv().Config.WebhookURL,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = HttpService:JSONEncode(payload)
    })
end

local function UpdateInventoryMonitor()
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
end

task.spawn(function()
    while task.wait(3) do
        UpdateInventoryMonitor()
    end
end)

return {
    SendWebhook = SendWebhook,
    UpdateInventoryMonitor = UpdateInventoryMonitor
}
