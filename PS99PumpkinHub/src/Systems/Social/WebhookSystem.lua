-- src/Systems/Social/WebhookSystem.lua
-- Webhook Tab Backend:
--   - New Titanic Pets Webhook
--   - New Huge Pets Webhook
--   - New Exclusive Pets Webhook

local WebhookSystem = {}

function WebhookSystem.Init(ctx)
    local Lifecycle = ctx.Lifecycle
    local Net = ctx.Net
    local Utils = ctx.Utils
    local States = ctx.States

    local HttpService = ctx.Roblox.HttpService

    local Hook = {
        _sentUids = {},
        _seenUids = {},
        _thumbCache = {},
        _snapshotReady = false,
    }

    local function formatCommas(n)
        local num = math.floor(tonumber(n) or 0)
        local s = tostring(num)
        local k
        while true do
            s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return s
    end

    local function getHttpRequestFn()
        if type(request) == "function" then return request end
        if type(http_request) == "function" then return http_request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        return nil
    end

    local function resolveThumbnailUrl(petId, isGolden)
        local M = Net.Mod
        local dir = M.Directory and M.Directory.Pets and M.Directory.Pets[petId]
        if type(dir) ~= "table" then return nil end

        local rawThumb = (isGolden and dir.goldenThumbnail) or dir.thumbnail
        if type(rawThumb) ~= "string" then return nil end

        local assetId = string.match(rawThumb, "%d+")
        if not assetId then return nil end

        if Hook._thumbCache[assetId] then
            return Hook._thumbCache[assetId]
        end

        local reqFn = getHttpRequestFn()
        if reqFn then
            local apiUrl = string.format(
                "https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=250x250&format=Png&isCircular=false",
                assetId
            )
            local okReq, resp = pcall(reqFn, { Url = apiUrl, Method = "GET" })
            if okReq and type(resp) == "table" and tonumber(resp.StatusCode) == 200 and type(resp.Body) == "string" then
                local okDec, data = pcall(HttpService.JSONDecode, HttpService, resp.Body)
                if okDec and type(data) == "table" and type(data.data) == "table" and data.data[1] and type(data.data[1].imageUrl) == "string" then
                    Hook._thumbCache[assetId] = data.data[1].imageUrl
                    return data.data[1].imageUrl
                end
            end
        end

        return string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%s&width=420&height=420&format=png", assetId)
    end

    local function getDiamondsCount()
        local RS = ctx.Roblox.ReplicatedStorage
        local okC, CurrencyCmds = pcall(require, RS.Library.Client.CurrencyCmds)
        if okC and CurrencyCmds and CurrencyCmds.Get then
            local okG, val = pcall(CurrencyCmds.Get, "Diamonds")
            if okG and type(val) == "number" then
                return val
            end
        end
        return 0
    end

    local function getPetRAP(petItem)
        local RS = ctx.Roblox.ReplicatedStorage
        local okR, RAPCmds = pcall(require, RS.Library.Client.RAPCmds)
        if okR and RAPCmds and RAPCmds.Get and petItem then
            local okG, val = pcall(RAPCmds.Get, petItem)
            if okG and type(val) == "number" and val > 0 then
                return val
            end
        end
        return nil
    end

    local function countSamePetInInventory(petItem)
        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.State or not petItem then return 1 end
        local inv = M.InventoryCmds.State()
        local byUID = inv and inv.container and inv.container._store and inv.container._store._byUID
        if type(byUID) ~= "table" then return 1 end

        local targetId = petItem.GetId and petItem:GetId()
        local targetGold = petItem.IsGolden and petItem:IsGolden() == true
        local targetRb = petItem.IsRainbow and petItem:IsRainbow() == true
        local targetShiny = petItem.IsShiny and petItem:IsShiny() == true

        local count = 0
        for _, item in pairs(byUID) do
            if type(item) == "table" and item.Class and item.Class.Name == "Pet" then
                if (item.GetId and item:GetId() == targetId)
                    and ((item.IsGolden and item:IsGolden() == true) == targetGold)
                    and ((item.IsRainbow and item:IsRainbow() == true) == targetRb)
                    and ((item.IsShiny and item:IsShiny() == true) == targetShiny) then
                    count = count + 1
                end
            end
        end
        return math.max(1, count)
    end

    local function buildFullPetName(petItem)
        local baseName = (petItem.GetName and petItem:GetName()) or (petItem.GetId and petItem:GetId()) or "Unknown Pet"
        local prefix = {}
        if petItem.IsShiny and petItem:IsShiny() then table.insert(prefix, "Shiny") end
        if petItem.IsRainbow and petItem:IsRainbow() then
            table.insert(prefix, "Rainbow")
        elseif petItem.IsGolden and petItem:IsGolden() then
            table.insert(prefix, "Golden")
        end
        if #prefix > 0 then
            return table.concat(prefix, " ") .. " " .. tostring(baseName)
        end
        return tostring(baseName)
    end

    local function classifyPet(petItem)
        if not petItem then return nil, nil end
        if petItem.IsGargantuan and petItem:IsGargantuan() then
            return "Gargantuan", 0xFF2E63
        end
        if petItem.IsTitanic and petItem:IsTitanic() then
            return "Titanic", 0xFF55FF
        end
        if petItem.IsHuge and petItem:IsHuge() then
            return "Huge", 0xFFAA00
        end
        if petItem.IsExclusive and petItem:IsExclusive() then
            return "Exclusive", 0xAA55FF
        end
        local rar = petItem.GetRarity and petItem:GetRarity()
        if rar and tostring(rar._id) == "Exclusive" then
            return "Exclusive", 0xAA55FF
        end
        return nil, nil
    end

    function Hook.OnPetHatched(sourceEggName, petItem)
        local url = tostring(States.Webhook.Url or "")
        if url == "" or not petItem then return end

        local uid = (petItem.GetUID and petItem:GetUID()) or tostring(petItem:GetId()) .. "_" .. tostring(os.time())
        if Hook._sentUids[uid] or Hook._seenUids[uid] then return end

        local tierLabel, color = classifyPet(petItem)
        if not tierLabel then return end

        local wanted = ((tierLabel == "Titanic" or tierLabel == "Gargantuan") and States.Webhook.NotifyTitanic)
            or (tierLabel == "Huge" and States.Webhook.NotifyHuge)
            or (tierLabel == "Exclusive" and States.Webhook.NotifyExclusive)
        if not wanted then return end

        Hook._sentUids[uid] = true
        Hook._seenUids[uid] = true

        task.spawn(function()
            local petId = (petItem.GetId and petItem:GetId()) or (petItem.GetName and petItem:GetName()) or "Unknown Pet"
            local displayName = buildFullPetName(petItem)
            local isGold = petItem.IsGolden and petItem:IsGolden() == true
            local rapVal = getPetRAP(petItem)
            local rapText = rapVal and formatCommas(rapVal) or "1"
            local diamondsText = formatCommas(getDiamondsCount())
            local invCount = countSamePetInInventory(petItem)
            local thumbUrl = resolveThumbnailUrl(petId, isGold)

            local descLines = {
                string.format("🐱 **Obtained %s Pet Info:**", tierLabel),
                string.format("> **Item:** `%s`", displayName),
                string.format("> **RAP:** `%s`", rapText),
                "",
                "🧑 **User Info:**",
                string.format("> **In Account:** `%s`", ctx.Roblox.LocalPlayer.Name),
                string.format("> **Diamonds Left:** `%s`", diamondsText),
                string.format("> **In Inventory:** `%s`", formatCommas(invCount)),
            }

            local embed = {
                title = string.format("🎉 You have obtained a new %s pet!", tierLabel),
                description = table.concat(descLines, "\n"),
                color = color,
                footer = { text = "RLW Pet Tracker • PS99 Pumpkin Hub" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
            if thumbUrl then
                embed.thumbnail = { url = thumbUrl }
            end

            local payload = {
                username = "RLW Pet Tracker",
                embeds = { embed },
            }

            local ok, code = Utils.postWebhook(url, payload)
            if ok then
                ctx.Runtime.Telemetry.WebhooksSent = ctx.Runtime.Telemetry.WebhooksSent + 1
                ctx.Runtime.Status.Webhook = "Sent " .. tierLabel .. ": " .. displayName
            else
                ctx.Runtime.Status.Webhook = "Webhook error: " .. tostring(code)
            end
        end)
    end

    function Hook.SendTestWebhook()
        local url = tostring(States.Webhook.Url or "")
        if url == "" then
            return false, "Webhook URL is empty!"
        end

        local diamondsText = formatCommas(getDiamondsCount())
        local testThumb = resolveThumbnailUrl("Huge Witch Fox", false)
        local descLines = {
            "🐱 **Obtained Huge Pet Info:**",
            "> **Item:** `RLW Webhook Test (Active)`",
            "> **RAP:** `Test`",
            "",
            "🧑 **User Info:**",
            string.format("> **In Account:** `%s`", ctx.Roblox.LocalPlayer.Name),
            string.format("> **Diamonds Left:** `%s`", diamondsText),
            "> **In Inventory:** `OK`",
        }
        local embed = {
            title = "🎉 RLW Pet Tracker — Webhook Connected!",
            description = table.concat(descLines, "\n"),
            color = 0xFFAA00,
            footer = { text = "RLW Pet Tracker • PS99 Pumpkin Hub" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        if testThumb then
            embed.thumbnail = { url = testThumb }
        end

        local payload = {
            username = "RLW Pet Tracker",
            embeds = { embed },
        }
        local ok, code = Utils.postWebhook(url, payload)
        if ok then
            ctx.Runtime.Status.Webhook = "Test webhook sent (" .. tostring(code) .. ")"
        else
            ctx.Runtime.Status.Webhook = "Test failed: " .. tostring(code)
        end
        return ok, code
    end

    local function snapshotExistingPets()
        local M = Net.Mod
        if not M.InventoryCmds or not M.InventoryCmds.State then return end
        local inv = M.InventoryCmds.State()
        local byUID = inv and inv.container and inv.container._store and inv.container._store._byUID
        if type(byUID) ~= "table" then return end
        for uid, item in pairs(byUID) do
            if type(item) == "table" and item.Class and item.Class.Name == "Pet" then
                Hook._seenUids[tostring(uid)] = true
            end
        end
        Hook._snapshotReady = true
    end

    function WebhookSystem.Start()
        local M = Net.Mod
        snapshotExistingPets()

        -- 1. Primary tracker: Inventory container Added (catches Eggs, Custom Eggs, Pet Nets, Turkey drops, Flannel Gifts, etc.)
        if M.InventoryCmds and M.InventoryCmds.State then
            local inv = M.InventoryCmds.State()
            local container = inv and inv.container
            if container and container.Added and container.Added.Connect then
                Lifecycle.TrackConnection(container.Added:Connect(function(addedItems)
                    if type(addedItems) ~= "table" then return end
                    for _, entry in ipairs(addedItems) do
                        local item = (type(entry) == "table" and entry.Class and entry)
                            or (type(entry) == "table" and type(entry.item) == "table" and entry.item)
                            or (type(entry) == "table" and type(entry[1]) == "table" and entry[1])
                        if type(item) == "table" and item.Class and item.Class.Name == "Pet" then
                            Hook.OnPetHatched("Inventory", item)
                        end
                    end
                end))
            end
        end

        -- 2. Secondary tracker: Standard Eggs open animation (deduplicated via _sentUids / _seenUids)
        if M.Network and M.Network.Fired then
            local sig = M.Network.Fired("Eggs_PlayOpenAnimation")
            if sig then
                local RS = ctx.Roblox.ReplicatedStorage
                local okP, Payload = pcall(require, RS.Library.Util.EggAnimPayload)
                Lifecycle.TrackConnection(sig:Connect(function(eggName, compressed)
                    if not M.PetItem or not okP or not Payload or not Payload.Decompress or type(compressed) ~= "table" then return end
                    local okD, decoded = pcall(Payload.Decompress, compressed)
                    if okD and type(decoded) == "table" then
                        for uid, data in pairs(decoded) do
                            pcall(function()
                                local pItem = M.PetItem:From(data):SetUID(uid):Freeze()
                                Hook.OnPetHatched(eggName, pItem)
                            end)
                        end
                    end
                end))
            end
        end
    end

    ctx.Webhook = Hook
    ctx.API.testWebhook = Hook.SendTestWebhook
    return Hook
end

return WebhookSystem
