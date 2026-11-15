-- src/UI/Tabs/WebhookTab.lua
-- Tab 8: Secrets & Discord Webhook (URL, Filters, Dedupe Window & Live Testing)

local WebhookTab = {}

function WebhookTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local CONFIG = ctx.Config
    local ConfigManager = ctx.ConfigManager
    local WebhookSender = ctx.WebhookSender
    local SecretDetector = ctx.SecretDetector
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle

    UI.WebhookTab = Window:CreateTab({ name = "Secrets & Webhook", icon = 93364949241311 })
    UI.WebhookTab:CreateSection({ name = "Discord Webhook Configuration" })

    UI.WebhookStatusText = UI.WebhookTab:CreateText({
        name = "Webhook Status",
        text = "Idle | Sent: 0 | Failed: 0"
    })

    createBoundToggle(UI.WebhookTab, {
        name = "Enable Secret Pet Webhook",
        flag = "WebhookEnabled",
        description = "Master toggle for Discord webhook notifications on verified Secret pet hatches",
        value = CONFIG.Webhook.Enabled,
    }, function() return CONFIG.Webhook.Enabled end, function(v) CONFIG.Webhook.Enabled = v end)

    UI.WebhookUrlInput = UI.WebhookTab:CreateInput({
        name = "Discord Webhook URL",
        flag = "WebhookUrl",
        placeholder = "https://discord.com/api/webhooks/...",
        value = CONFIG.Webhook.Url,
        callback = function(text)
            CONFIG.Webhook.Url = string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("WebhookUrl", UI.WebhookUrlInput, function() return CONFIG.Webhook.Url end, function(v) CONFIG.Webhook.Url = tostring(v or "") end)

    UI.WebhookTab:CreateSection({ name = "Secret Filters & Anti-False-Positive Rules" })

    createBoundToggle(UI.WebhookTab, {
        name = "Notify Secret Rarity Pets (^Secret)",
        flag = "WebhookNotifySecrets",
        description = "Triggers ONLY on true Secret rarity pets (ignores Common/Rare/Epic/Legendary/Mythical)",
        value = CONFIG.Webhook.NotifySecrets,
    }, function() return CONFIG.Webhook.NotifySecrets end, function(v) CONFIG.Webhook.NotifySecrets = v end)

    createBoundToggle(UI.WebhookTab, {
        name = "Notify Godly Pets",
        flag = "WebhookNotifyGodlies",
        value = CONFIG.Webhook.NotifyGodlies,
    }, function() return CONFIG.Webhook.NotifyGodlies end, function(v) CONFIG.Webhook.NotifyGodlies = v end)

    createBoundToggle(UI.WebhookTab, {
        name = "System Chat Fallback (Local Player Only)",
        flag = "WebhookSystemFallback",
        description = "Backup parser for MessageService chat announcements matching your username + catalog Secret pet",
        value = CONFIG.Webhook.SendSystemFallback,
    }, function() return CONFIG.Webhook.SendSystemFallback end, function(v) CONFIG.Webhook.SendSystemFallback = v end)

    createBoundToggle(UI.WebhookTab, {
        name = "Include Account Hatch Stats",
        flag = "WebhookIncludeStats",
        value = CONFIG.Webhook.IncludeStats,
    }, function() return CONFIG.Webhook.IncludeStats end, function(v) CONFIG.Webhook.IncludeStats = v end)

    createBoundToggle(UI.WebhookTab, {
        name = "Ping @everyone on Secret",
        flag = "WebhookPingEveryone",
        value = CONFIG.Webhook.PingEveryone,
    }, function() return CONFIG.Webhook.PingEveryone end, function(v) CONFIG.Webhook.PingEveryone = v end)

    UI.CustomMentionInput = UI.WebhookTab:CreateInput({
        name = "Custom Role/User Mention (Optional)",
        flag = "WebhookCustomMention",
        placeholder = "<@123456> or <@&roleId>",
        value = CONFIG.Webhook.CustomMention,
        callback = function(text)
            CONFIG.Webhook.CustomMention = tostring(text or "")
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("WebhookCustomMention", UI.CustomMentionInput, function() return CONFIG.Webhook.CustomMention end, function(v) CONFIG.Webhook.CustomMention = tostring(v or "") end)

    UI.DedupeSlider = UI.WebhookTab:CreateSlider({
        name = "Sourceless Dedupe Window (Seconds)",
        flag = "WebhookDedupeWindow",
        range = { 5, 120 },
        increment = 1,
        value = CONFIG.Webhook.DedupeWindowSeconds,
        suffix = "s",
        callback = function(val)
            CONFIG.Webhook.DedupeWindowSeconds = val
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("WebhookDedupeWindow", UI.DedupeSlider, function() return CONFIG.Webhook.DedupeWindowSeconds end, function(v) CONFIG.Webhook.DedupeWindowSeconds = tonumber(v) or 20 end)

    UI.WebhookTab:CreateSection({ name = "Webhook & Detection Testing" })

    UI.LastSecretText = UI.WebhookTab:CreateText({
        name = "Last Detected Secret",
        text = "None detected in this session yet."
    })

    UI.WebhookTab:CreateButton({
        name = "Send Test Webhook Now",
        callback = function()
            task.spawn(function()
                local valid, err = WebhookSender:IsValidUrl(CONFIG.Webhook.Url)
                if not valid then
                    safeNotify({ title = "Webhook Test", content = "Cannot send: " .. tostring(err), duration = 4 })
                    return
                end
                local ok, respOrErr = WebhookSender:SendSync(WebhookSender:BuildSecretPayload({
                    Name = "Crimson Rose Knight",
                    Rarity = "Secret",
                    Tier = "Normal",
                    Egg = "Royal",
                    World = "World 2 (Time Rift)",
                    Island = "Medieval Island",
                    OneIn = 3000000,
                    Source = "ManualWebhookTest",
                }, true))
                if UI.WebhookStatusText and UI.WebhookStatusText.Set then
                    pcall(function()
                        UI.WebhookStatusText:Set(string.format("%s | Sent: %d | Failed: %d",
                            WebhookSender.Stats.LastStatus, WebhookSender.Stats.SentCount, WebhookSender.Stats.FailedCount))
                    end)
                end
                safeNotify({
                    title = ok and "Webhook Test Sent!" or "Webhook Test Failed",
                    content = ok and "Embed delivered to your Discord channel!" or tostring(respOrErr),
                    duration = 5,
                })
            end)
        end
    })

    UI.WebhookTab:CreateButton({
        name = "Simulate Secret Detection (Safe Dry Run)",
        callback = function()
            local ok, meta = SecretDetector:Simulate("Operating System", "Glitched Egg")
            if UI.LastSecretText and UI.LastSecretText.Set and type(meta) == "table" then
                pcall(function()
                    UI.LastSecretText:Set(string.format("%s (%s) | Egg: %s | Source: %s",
                        meta.Name, meta.Rarity, meta.Egg, meta.Source))
                end)
            end
            safeNotify({
                title = "Secret Simulation",
                content = ok and "Pipeline verified: detected simulated Secret safely!" or ("Skipped: " .. tostring(meta)),
                duration = 4,
            })
        end
    })

    UI.WebhookTab:CreateButton({
        name = "Test Anti-False-Positive Filter (Legendary/Mythical)",
        callback = function()
            local _, legReason = SecretDetector:ProcessCandidate({ Id = "FP_1", Name = "Royal Guard", Rarity = "Legendary" }, "SelfTest", "Medieval", false)
            local _, mythReason = SecretDetector:ProcessCandidate({ Id = "FP_2", Name = "Crimson Dragon", Rarity = "Mythical" }, "SelfTest", "Medieval", false)
            local _, preReason = SecretDetector:ProcessCandidate({ Id = "FP_3", Name = "Prehistoric Monkey", Rarity = "Mythical" }, "SelfTest", "Glitched Egg", false)
            local allRejected = (legReason == "NotSecretRarity") and (mythReason == "NotSecretRarity") and (preReason == "NotSecretRarity")
            safeNotify({
                title = "False-Positive Check",
                content = allRejected and "PASS: Legendary/Mythical pets strictly ignored!" or string.format("FAIL: %s / %s / %s", tostring(legReason), tostring(mythReason), tostring(preReason)),
                duration = 5,
            })
        end
    })

    return WebhookTab
end

return WebhookTab
