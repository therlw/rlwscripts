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

    local Hook = {
        _sentUids = {},
    }

    local function classifyPet(petItem)
        if not petItem then return nil, 0x7289DA end
        if (petItem.IsGargantuan and petItem:IsGargantuan()) or (petItem.IsTitanic and petItem:IsTitanic()) then
            return "Titanic / Gargantuan", 0xFF55FF
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
        if Hook._sentUids[uid] then return end

        local tierLabel, color = classifyPet(petItem)
        if not tierLabel then return end

        local wanted = (tierLabel == "Titanic / Gargantuan" and States.Webhook.NotifyTitanic)
            or (tierLabel == "Huge" and States.Webhook.NotifyHuge)
            or (tierLabel == "Exclusive" and States.Webhook.NotifyExclusive)
        if not wanted then return end

        Hook._sentUids[uid] = true
        local name = (petItem.GetName and petItem:GetName()) or (petItem.GetId and petItem:GetId()) or "Unknown Pet"
        local variants = {}
        if petItem.IsGolden and petItem:IsGolden() then table.insert(variants, "Golden") end
        if petItem.IsRainbow and petItem:IsRainbow() then table.insert(variants, "Rainbow") end
        if petItem.IsShiny and petItem:IsShiny() then table.insert(variants, "Shiny") end
        local variantText = #variants > 0 and table.concat(variants, " ") or "Normal"

        local payload = {
            username = "PS99 Hub Alerts",
            embeds = {
                {
                    title = string.format("New %s Pet Hatched!", tierLabel),
                    description = string.format("**%s** (%s)", tostring(name), variantText),
                    color = color,
                    fields = {
                        { name = "Player", value = ctx.Roblox.LocalPlayer.Name, inline = true },
                        { name = "Egg", value = tostring(sourceEggName or "Unknown"), inline = true },
                    },
                    footer = { text = "PS99 Pumpkin Tycoon Hub • Webhook" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                },
            },
        }

        task.spawn(function()
            local ok = Utils.postWebhook(url, payload)
            if ok then
                ctx.Runtime.Telemetry.WebhooksSent = ctx.Runtime.Telemetry.WebhooksSent + 1
                ctx.Runtime.Status.Webhook = "Sent " .. tierLabel .. ": " .. tostring(name)
            end
        end)
    end

    function Hook.SendTestWebhook()
        local url = tostring(States.Webhook.Url or "")
        if url == "" then
            return false, "Webhook URL is empty!"
        end
        local payload = {
            username = "PS99 Hub Alerts",
            embeds = {
                {
                    title = "Webhook Connection Verified!",
                    description = "Discord webhook integration is active for " .. ctx.Roblox.LocalPlayer.Name,
                    color = 0x00FF99,
                },
            },
        }
        return Utils.postWebhook(url, payload)
    end

    function WebhookSystem.Start()
        local M = Net.Mod
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
