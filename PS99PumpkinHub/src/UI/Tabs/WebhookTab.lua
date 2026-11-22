-- src/UI/Tabs/WebhookTab.lua
-- Webhook Tab: Discord Alerts for Titanic/Gargantuan, Huge & Exclusive Pets

local WebhookTab = {}

function WebhookTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Hook = ctx.States.Webhook
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local createBoundInput = UI.createBoundInput

    local tab = Window:CreateTab({ name = "Webhook", icon = 93364949241311 })
    UI.WebhookTab = tab

    tab:CreateSection({ name = "Discord Webhook Configuration" })

    UI.WebhookStatusText = tab:CreateText({
        name = "Webhook Status",
        text = "Webhook listener active",
    })

    createBoundInput(tab, {
        name = "Discord Webhook URL",
        flag = "WebhookUrl",
        placeholder = "https://discord.com/api/webhooks/...",
        value = Hook.Url,
    }, function() return Hook.Url end, function(v) Hook.Url = v end)

    tab:CreateButton({
        name = "Send Test Webhook",
        callback = function()
            if ctx.Webhook and ctx.Webhook.SendTestWebhook then
                local ok, res = ctx.Webhook.SendTestWebhook()
                safeNotify({
                    title = "Webhook Test",
                    content = ok and "Test embed sent to Discord!" or ("Failed: " .. tostring(res)),
                })
            end
        end,
    })

    tab:CreateSection({ name = "Pet Notifications" })

    createBoundToggle(tab, {
        name = "New Titanic Pets Webhook",
        flag = "WebhookTitanic",
        value = Hook.NotifyTitanic,
    }, function() return Hook.NotifyTitanic end, function(v) Hook.NotifyTitanic = v end)

    createBoundToggle(tab, {
        name = "New Huge Pets Webhook",
        flag = "WebhookHuge",
        value = Hook.NotifyHuge,
    }, function() return Hook.NotifyHuge end, function(v) Hook.NotifyHuge = v end)

    createBoundToggle(tab, {
        name = "New Exclusive Pets Webhook",
        flag = "WebhookExclusive",
        value = Hook.NotifyExclusive,
    }, function() return Hook.NotifyExclusive end, function(v) Hook.NotifyExclusive = v end)

    return WebhookTab
end

return WebhookTab
