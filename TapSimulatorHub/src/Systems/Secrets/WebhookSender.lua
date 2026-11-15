-- src/Systems/Secrets/WebhookSender.lua
-- Resilient Async HTTP Discord Webhook Sender + Retries + Rich Embed Formatter

local WebhookSender = {}

function WebhookSender.Init(ctx)
    local CONFIG = ctx.Config
    local HttpService = ctx.Roblox.HttpService
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local formatCompact = ctx.Utils.formatCompact
    local debugWarn = ctx.Utils.debugWarn
    local getPlayerData = ctx.API.getPlayerData

    local sender = {
        Stats = {
            SentCount = 0,
            FailedCount = 0,
            LastStatus = "Idle",
            LastError = nil,
            LastSentAt = nil,
        },
    }

    function sender:GetRequestFn()
        local fn = nil
        pcall(function()
            if type(request) == "function" then fn = request end
            if not fn and type(http_request) == "function" then fn = http_request end
            if not fn and type(http) == "table" and type(http.request) == "function" then fn = http.request end
            if not fn and type(syn) == "table" and type(syn.request) == "function" then fn = syn.request end
        end)
        return fn
    end

    function sender:IsValidUrl(url)
        if type(url) ~= "string" then return false, "Empty URL" end
        local trimmed = string.gsub(url, "^%s*(.-)%s*$", "%1")
        if trimmed == "" then return false, "Empty URL" end
        if not string.match(trimmed, "^https?://[%w%.%-_]+") then
            return false, "Invalid URL scheme (must start with http:// or https://)"
        end
        return true, trimmed
    end

    function sender:BuildSecretPayload(info, isTest)
        local petName = tostring(info.Name or info.PetName or "Unknown Pet")
        local rarity = tostring(info.Rarity or "Secret")
        local tier = tostring(info.Tier or "Normal") .. (info.AutoDeleted and " [AutoDeleted]" or "")
        local shinyStr = info.Shiny and "Shiny " or ""
        local eggName = tostring(info.Egg or "Unknown Egg")
        local worldName = tostring(info.World or "Unknown World")
        local islandName = tostring(info.Island or "Unknown Island")
        local oneIn = tonumber(info.OneIn) or 0
        local oddsStr = (oneIn > 0) and ("1 in " .. formatCompact(oneIn))
            or (type(info.Odds) == "string" and info.Odds ~= "" and info.Odds)
            or "Secret / Unknown Odds"
        local playerName = LocalPlayer and string.format("%s (@%s)", tostring(LocalPlayer.DisplayName), tostring(LocalPlayer.Name)) or "Unknown"
        local prefix = isTest and "[TEST] " or ""
        local mention = ""
        if not isTest and CONFIG.Webhook.PingEveryone then
            mention = "@everyone"
        elseif not isTest and type(CONFIG.Webhook.CustomMention) == "string" and CONFIG.Webhook.CustomMention ~= "" then
            mention = CONFIG.Webhook.CustomMention
        end

        local fields = {
            { name = "Pet Name", value = string.format("**%s%s**", shinyStr, petName), inline = true },
            { name = "Rarity", value = rarity, inline = true },
            { name = "Variant / Tier", value = shinyStr .. tier, inline = true },
            { name = "Egg", value = eggName, inline = true },
            { name = "World / Island", value = string.format("%s — %s", worldName, islandName), inline = true },
            { name = "Hatch Odds", value = oddsStr, inline = true },
            { name = "Player", value = playerName, inline = true },
            { name = "Source", value = tostring(info.Source or "Unknown"), inline = true },
            { name = "Time", value = string.format("<t:%d:F>", os.time()), inline = true },
        }
        if CONFIG.Webhook.IncludeStats then
            local data = getPlayerData()
            local hatchTotal = data and data.Statistics and (data.Statistics.EggsHatched or data.Statistics.Eggs) or nil
            if hatchTotal then
                table.insert(fields, { name = "Account Eggs Hatched", value = formatCompact(hatchTotal), inline = true })
            end
        end

        local colorInt = isTest and 5793266 or 15844367
        return {
            username = "Tap Simulator Hub",
            content = (mention ~= "") and mention or nil,
            embeds = {
                {
                    title = prefix .. "SECRET PET DETECTED!",
                    description = string.format("**%s** just hatched/received a **%s%s**!", playerName, shinyStr, petName),
                    color = colorInt,
                    fields = fields,
                    footer = {
                        text = string.format("TapSimulatorHub | Place %s | Job %s", tostring(game.PlaceId), string.sub(tostring(game.JobId or ""), 1, 8)),
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
    end

    function sender:SendSync(payload, overrideUrl)
        local url = overrideUrl or (CONFIG.Webhook and CONFIG.Webhook.Url)
        local valid, cleanUrlOrReason = self:IsValidUrl(url)
        if not valid then
            self.Stats.FailedCount = self.Stats.FailedCount + 1
            self.Stats.LastStatus = "Skipped: " .. tostring(cleanUrlOrReason)
            self.Stats.LastError = cleanUrlOrReason
            return false, cleanUrlOrReason
        end

        local reqFn = self:GetRequestFn()
        if not reqFn then
            self.Stats.FailedCount = self.Stats.FailedCount + 1
            self.Stats.LastStatus = "Error: No HTTP request API"
            self.Stats.LastError = "No executor HTTP function found"
            return false, self.Stats.LastError
        end

        local okJson, body = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not okJson then
            self.Stats.FailedCount = self.Stats.FailedCount + 1
            self.Stats.LastError = "JSONEncode failed: " .. tostring(body)
            return false, self.Stats.LastError
        end

        local maxRetries = math.max(1, (CONFIG.Retries and CONFIG.Retries.WebhookRetries) or 2)
        local retryDelay = (CONFIG.Retries and CONFIG.Retries.WebhookRetryDelay) or 1.5
        local lastErr = "Request failed"

        for attempt = 1, maxRetries do
            local okReq, resp = pcall(reqFn, {
                Url = cleanUrlOrReason,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                },
                Body = body,
            })
            if okReq and type(resp) == "table" then
                local status = tonumber(resp.StatusCode) or 0
                if (status >= 200 and status < 300) or resp.Success == true then
                    self.Stats.SentCount = self.Stats.SentCount + 1
                    self.Stats.LastStatus = string.format("OK (HTTP %d)", status)
                    self.Stats.LastError = nil
                    self.Stats.LastSentAt = os.time()
                    return true, resp
                elseif status == 429 and attempt < maxRetries then
                    lastErr = "Rate limited (HTTP 429)"
                    task.wait(math.max(retryDelay, 2.0))
                else
                    lastErr = string.format("HTTP %d: %s", status, tostring(resp.StatusMessage or resp.Body or ""))
                    if attempt < maxRetries then task.wait(retryDelay) end
                end
            else
                lastErr = tostring(resp or "HTTP exception")
                if attempt < maxRetries then task.wait(retryDelay) end
            end
        end

        self.Stats.FailedCount = self.Stats.FailedCount + 1
        self.Stats.LastStatus = "Failed"
        self.Stats.LastError = lastErr
        debugWarn("WebhookSender", lastErr)
        return false, lastErr
    end

    function sender:SendAsync(payload, overrideUrl)
        task.spawn(function()
            pcall(function()
                self:SendSync(payload, overrideUrl)
            end)
        end)
    end

    function sender:SendSecretAlert(secretInfo, isTest)
        if not isTest and not (CONFIG.Webhook and CONFIG.Webhook.Enabled) then
            return false, "Webhook disabled in config"
        end
        local payload = self:BuildSecretPayload(secretInfo, isTest)
        self:SendAsync(payload)
        return true, "Queued"
    end

    ctx.WebhookSender = sender
    for k, v in pairs(sender) do
        WebhookSender[k] = v
    end
    return sender
end

return WebhookSender
