-- src/UI/Tabs/WebhookTab.lua
-- Discord Webhook Bildirim Ayarları Sekmesi

local WebhookTab = {}

function WebhookTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Hook = ctx.States.Webhook

    local Tab = Window:CreateTab({
        name = "Webhook",
        icon = 93364949241311,
    })
    UI.WebhookTab = Tab

    Tab:CreateSection({ name = "Discord Webhook Bağlantısı" })
    UI.WebhookStatusText = Tab:CreateText({
        name = "Webhook Durumu",
        text = tostring(ctx.Runtime.Status.Webhook or "Webhook dinleyicisi aktif"),
    })

    UI.createBoundInput(Tab, {
        name = "Discord Webhook URL",
        flag = "WebhookUrl",
        placeholder = "https://discord.com/api/webhooks/...",
        value = Hook.Url,
    }, function()
        return Hook.Url
    end, function(v)
        Hook.Url = tostring(v or "")
    end)

    Tab:CreateButton({
        name = "Test Bildirimi Gönder",
        description = "Webhook adresinin doğru çalışıp çalışmadığını test eder",
        callback = function()
            if ctx.Webhook and ctx.Webhook.SendTestWebhook then
                task.spawn(function()
                    local ok, info = ctx.Webhook.SendTestWebhook()
                    if UI.safeNotify then
                        UI.safeNotify({
                            title = "Webhook Testi",
                            content = ok and "Test bildirimi Discord'a gönderildi!" or ("Gönderilemedi: " .. tostring(info)),
                            duration = 4,
                            force = true,
                        })
                    end
                end)
            end
        end,
    })

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Bildirim Gönderilecek Pet Katmanları" })

    UI.createBoundToggle(Tab, {
        name = "Titanic Pet Bildir",
        flag = "WebhookTitanic",
        value = Hook.NotifyTitanic,
        description = "Titanic veya Gargantuan pet çıktığında Discord'a mesaj atar",
    }, function()
        return Hook.NotifyTitanic
    end, function(v)
        Hook.NotifyTitanic = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Huge Pet Bildir",
        flag = "WebhookHuge",
        value = Hook.NotifyHuge,
        description = "Huge pet çıktığında Discord'a bildirim gönderir",
    }, function()
        return Hook.NotifyHuge
    end, function(v)
        Hook.NotifyHuge = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Exclusive Pet Bildir",
        flag = "WebhookExclusive",
        value = Hook.NotifyExclusive,
        description = "Exclusive pet çıktığında Discord'a bildirim gönderir",
    }, function()
        return Hook.NotifyExclusive
    end, function(v)
        Hook.NotifyExclusive = (v == true)
    end)

    return WebhookTab
end

return WebhookTab
