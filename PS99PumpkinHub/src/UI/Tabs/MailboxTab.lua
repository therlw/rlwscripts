-- src/UI/Tabs/MailboxTab.lua
-- Mailbox Tab: Open/Close Mailbox Gui, Auto Claim Mailbox & Auto Mail Pets

local MailboxTab = {}

function MailboxTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Mail = ctx.States.Mailbox
    local createBoundToggle = UI.createBoundToggle
    local createBoundDropdown = UI.createBoundDropdown
    local createBoundInput = UI.createBoundInput

    local tab = Window:CreateTab({ name = "Mailbox", icon = 93364949241311 })
    UI.MailboxTab = tab

    tab:CreateSection({ name = "Mailbox Controls" })

    UI.MailboxStatusText = tab:CreateText({
        name = "Mailbox Status",
        text = "Mailbox idle",
    })

    tab:CreateButton({
        name = "Open/Close Mailbox Gui",
        callback = function()
            if ctx.MailboxSystem and ctx.MailboxSystem.ToggleGui then
                ctx.MailboxSystem.ToggleGui()
            end
        end,
    })

    createBoundToggle(tab, {
        name = "Auto Claim Mailbox",
        flag = "MailAutoClaim",
        description = "Loads inbox and claims incoming gifts via RD_Ingest",
        value = Mail.AutoClaimMailbox,
    }, function() return Mail.AutoClaimMailbox end, function(v) Mail.AutoClaimMailbox = v end)

    tab:CreateSection({ name = "Auto Mail Pets" })

    createBoundToggle(tab, {
        name = "Auto Mail Pets",
        flag = "MailAutoSend",
        description = "Sends unlocked, unfavorited & unequipped pets matching filter via EF_Relay",
        value = Mail.AutoMailPets,
    }, function() return Mail.AutoMailPets end, function(v) Mail.AutoMailPets = v end)

    createBoundInput(tab, {
        name = "Mail Target Username",
        flag = "MailTargetUser",
        placeholder = "Exact Roblox Username",
        value = Mail.MailUsername,
    }, function() return Mail.MailUsername end, function(v) Mail.MailUsername = v end)

    createBoundDropdown(tab, {
        name = "Pet Rarity Filter",
        flag = "MailRarityFilter",
        options = { "Huge / Titanic+", "Exclusive / Huge+", "Mythical+", "All Unlocked" },
        value = Mail.MailRarityFilter,
    }, function() return Mail.MailRarityFilter end, function(v) Mail.MailRarityFilter = v end)

    createBoundInput(tab, {
        name = "Mail Message",
        flag = "MailMsgText",
        placeholder = "PS99 Hub Mail",
        value = Mail.MailMessage,
    }, function() return Mail.MailMessage end, function(v) Mail.MailMessage = v end)

    return MailboxTab
end

return MailboxTab
