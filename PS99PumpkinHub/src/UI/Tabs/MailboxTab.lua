-- src/UI/Tabs/MailboxTab.lua
-- Posta Kutusu (Otomatik Toplama & Pet Gönderme) Sekmesi

local MailboxTab = {}

function MailboxTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Mail = ctx.States.Mailbox

    local Tab = Window:CreateTab({
        name = "Posta Kutusu",
        icon = 93364949241311,
    })
    UI.MailboxTab = Tab

    Tab:CreateSection({ name = "Posta Kutusu Yönetimi" })
    UI.MailboxStatusText = Tab:CreateText({
        name = "Posta Durumu",
        text = tostring(ctx.Runtime.Status.Mailbox or "Posta kutusu beklemede"),
    })

    Tab:CreateButton({
        name = "Oyun İçi Posta Kutusunu Aç / Kapat",
        description = "Nerede olursan ol Mailbox arayüzünü uzaktan açar",
        callback = function()
            if ctx.MailboxSystem and ctx.MailboxSystem.ToggleGui then
                ctx.MailboxSystem.ToggleGui()
            end
        end,
    })

    UI.createBoundToggle(Tab, {
        name = "Gelen Postaları Otomatik Topla (Auto Claim)",
        flag = "MailAutoClaim",
        value = Mail.AutoClaimMailbox,
        description = "Posta kutuna gelen tüm eşyaları ve hediyeleri otomatik alır",
    }, function()
        return Mail.AutoClaimMailbox
    end, function(v)
        Mail.AutoClaimMailbox = (v == true)
    end)

    Tab:CreateDivider()
    Tab:CreateSection({ name = "Otomatik Pet Gönderme (Auto Mail)" })

    UI.createBoundToggle(Tab, {
        name = "Petleri Otomatik Postala (Auto Send)",
        flag = "MailAutoSend",
        value = Mail.AutoMailPets,
        description = "Seçilen nadirlikteki petleri hedef hesaba otomatik gönderir",
    }, function()
        return Mail.AutoMailPets
    end, function(v)
        Mail.AutoMailPets = (v == true)
    end)

    UI.createBoundInput(Tab, {
        name = "Alıcı Kullanıcı Adı (Username)",
        flag = "MailTargetUser",
        placeholder = "Alıcı Roblox kullanıcı adı...",
        value = Mail.MailUsername,
    }, function()
        return Mail.MailUsername
    end, function(v)
        Mail.MailUsername = tostring(v or "")
    end)

    UI.createBoundDropdown(Tab, {
        name = "Gönderilecek Pet Nadirlik Filtresi",
        flag = "MailRarityFilter",
        options = { "Huge / Titanic+", "Exclusive / Huge+", "Mythical+", "All Unlocked" },
        labels = {
            ["Huge / Titanic+"] = "Sadece Huge / Titanic+",
            ["Exclusive / Huge+"] = "Exclusive / Huge+",
            ["Mythical+"] = "Mythical ve Üstü",
            ["All Unlocked"] = "Kilitsiz Tüm Petler",
        },
        value = Mail.MailRarityFilter,
    }, function()
        return Mail.MailRarityFilter
    end, function(v)
        Mail.MailRarityFilter = v
    end)

    UI.createBoundInput(Tab, {
        name = "Posta Mesajı",
        flag = "MailMsgText",
        placeholder = "Örn: Ana hesap transferi",
        value = Mail.MailMessage,
    }, function()
        return Mail.MailMessage
    end, function(v)
        Mail.MailMessage = tostring(v or "")
    end)

    return MailboxTab
end

return MailboxTab
