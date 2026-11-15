-- src/UI/WindowManager.lua
-- Rayfield Gen2 Window Isolation (PlayerGui), Previous UI Cleanup, Notify & Shared Widget Builders

local WindowManager = {}

function WindowManager.Init(ctx)
    local CONFIG = ctx.Config
    local Players = ctx.Roblox.Players
    local PlayerGui = ctx.Roblox.PlayerGui
    local ConfigManager = ctx.ConfigManager
    local debugWarn = ctx.Utils.debugWarn

    -- Clean up any previous hub instances strictly
    pcall(function()
        local LP = Players.LocalPlayer
        local PG = LP and LP:FindFirstChild("PlayerGui")
        if PG then
            for _, child in ipairs(PG:GetChildren()) do
                if child:IsA("ScreenGui") and (child:FindFirstChild("Tap Simulator | Rebirth Hub") or (string.find(child.Name, "-") and #child.Name > 30)) then
                    child:Destroy()
                end
            end
        end
    end)

    -- Direct Rayfield to PlayerGui to permanently bypass Roblox CoreGui Plugin-capability sandboxing
    local original_gethui = nil
    if type(getgenv) == "function" then
        pcall(function()
            original_gethui = getgenv().gethui
            getgenv().gethui = function()
                return PlayerGui
            end
        end)
    end

    local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
    local Window = Rayfield:CreateWindow({
        name = "Tap Simulator | Rebirth Hub",
        subtitle = "by RLW",
        sidebarLayout = true,
        configuration = {
            autoSave = false,
            autoLoad = false,
            fileName = "TapSimConfig",
        }
    })

    if type(getgenv) == "function" then
        pcall(function()
            getgenv().gethui = original_gethui
        end)
    end

    ctx.Rayfield = Rayfield
    ctx.Window = Window

    local function safeNotify(options)
        if type(options) == "table" and not options.force then
            if CONFIG.Notifications and CONFIG.Notifications.Enabled == false then
                return
            end
        end
        local ok, err = pcall(function()
            if Window and Window.Notify then
                Window:Notify(options)
            end
        end)
        if not ok then
            debugWarn("safeNotify", err)
        end
    end

    local function createBoundToggle(tab, opts, getter, setter, extraCb)
        local t = tab:CreateToggle({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            value = opts.value,
            callback = function(val)
                setter(val)
                if extraCb then extraCb(val) end
                ConfigManager:MarkDirty()
            end,
        })
        if opts.flag then
            ConfigManager:Bind(opts.flag, t, getter, setter)
        end
        return t
    end

    local function bindHotkeyElement(name, cfgKey, defaultKeyName, actionFn, targetTab)
        local tab = targetTab or ctx.UI.ConfigTab
        local initialKey = nil
        pcall(function()
            if defaultKeyName and defaultKeyName ~= "None" and Enum.KeyCode[defaultKeyName] then
                initialKey = Enum.KeyCode[defaultKeyName]
            end
        end)
        local kb = tab:CreateKeybind({
            name = name,
            flag = "Hotkey_" .. cfgKey,
            value = initialKey,
            callback = function()
                pcall(actionFn)
            end,
            onChanged = function(newKey)
                CONFIG.Hotkeys[cfgKey] = (newKey and newKey.Name) or "None"
                ConfigManager:MarkDirty()
            end,
        })
        ConfigManager:Bind("Hotkey_" .. cfgKey, kb, function()
            local k = CONFIG.Hotkeys[cfgKey]
            return (k and k ~= "None" and Enum.KeyCode[k]) or nil
        end, function(v)
            if typeof(v) == "EnumItem" then
                CONFIG.Hotkeys[cfgKey] = v.Name
            elseif type(v) == "string" then
                CONFIG.Hotkeys[cfgKey] = v
            end
        end)
        return kb
    end

    local function refreshSecretAndWebhookLabels()
        pcall(function()
            local UI = ctx.UI
            if UI.LastSecretText and UI.LastSecretText.Set then
                local latest = ctx.SecretDetector and ctx.SecretDetector.History and ctx.SecretDetector.History[1]
                if latest then
                    UI.LastSecretText:Set(string.format("%s (%s) | Egg: %s | Source: %s",
                        tostring(latest.Name), tostring(latest.Rarity), tostring(latest.Egg), tostring(latest.Source)))
                end
            end
            if UI.WebhookStatusText and UI.WebhookStatusText.Set and ctx.WebhookSender then
                UI.WebhookStatusText:Set(string.format("%s | Sent: %d | Failed: %d",
                    tostring(ctx.WebhookSender.Stats.LastStatus), ctx.WebhookSender.Stats.SentCount, ctx.WebhookSender.Stats.FailedCount))
            end
        end)
    end

    ctx.UI.safeNotify = safeNotify
    ctx.UI.createBoundToggle = createBoundToggle
    ctx.UI.bindHotkeyElement = bindHotkeyElement
    ctx.UI.refreshSecretAndWebhookLabels = refreshSecretAndWebhookLabels

    WindowManager.Rayfield = Rayfield
    WindowManager.Window = Window
    return WindowManager
end

return WindowManager
