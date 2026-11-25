-- src/UI/WindowManager.lua
-- Rayfield Gen2 Window Isolation, Unload Cleanup, Safe Notify & Bound Control Builders

local WindowManager = {}

function WindowManager.Init(ctx)
    local CONFIG = ctx.Config
    local Players = ctx.Roblox.Players
    local CoreGui = game:GetService("CoreGui")
    local LP = Players.LocalPlayer
    local PlayerGui = LP and LP:FindFirstChildOfClass("PlayerGui")
    local ConfigManager = ctx.Services.ConfigManager
    local Lifecycle = ctx.Lifecycle
    local debugWarn = ctx.Utils.debugWarn

    ctx.ConfigManager = ConfigManager

    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    if genv._RLW_AdoptMe_Window then
        pcall(function()
            if genv._RLW_AdoptMe_Window.Unload then
                genv._RLW_AdoptMe_Window:Unload()
            end
        end)
        genv._RLW_AdoptMe_Window = nil
    end

    pcall(function()
        if PlayerGui then
            for _, child in ipairs(PlayerGui:GetChildren()) do
                if child:IsA("ScreenGui") and (child:FindFirstChild("Adopt Me! | RLW Hub") or (string.find(child.Name, "-") and #child.Name > 30)) then
                    child:Destroy()
                end
            end
        end
    end)

    local original_gethui = nil
    local function restoreGethui()
        if type(getgenv) == "function" then
            pcall(function()
                getgenv().gethui = original_gethui
            end)
        end
    end

    local Rayfield = nil
    local rfErr = nil
    local gen2Source = nil
    for attempt = 1, 2 do
        if type(getgenv) == "function" and PlayerGui then
            pcall(function()
                original_gethui = getgenv().gethui
                getgenv().gethui = function()
                    return PlayerGui
                end
            end)
        end
        local okLoad, res = pcall(function()
            gen2Source = gen2Source or game:HttpGet("https://sirius.menu/gen2")
            return loadstring(gen2Source)()
        end)
        restoreGethui()
        if okLoad and type(res) == "table" then
            Rayfield = res
            break
        end
        rfErr = res
        if attempt == 1 then
            task.wait(0.25)
        end
    end
    if not Rayfield then
        error(tostring(rfErr or "Rayfield Gen2 load failed"), 0)
    end

    local Window = Rayfield:CreateWindow({
        name = "Adopt Me! | RLW Hub",
        subtitle = "RLW · 2026 Türkçe Arayüz",
        sidebarLayout = true,
        configuration = {
            autoSave = false,
            autoLoad = false,
            fileName = "AdoptMeHubRF",
        },
    })

    pcall(function()
        local roots = { PlayerGui, CoreGui }
        for _, root in ipairs(roots) do
            if root then
                for _, child in ipairs(root:GetChildren()) do
                    if child:IsA("ScreenGui") and (string.find(child.Name, "-") and #child.Name > 30) then
                        child.AutoLocalize = false
                    end
                end
            end
        end
    end)

    genv._RLW_AdoptMe_Window = Window
    ctx.Rayfield = Rayfield
    ctx.Window = Window
    ctx.Runtime.RayfieldUnload = function()
        pcall(function()
            if Window and Window.Unload then
                Window:Unload()
            end
        end)
    end

    Lifecycle.AddCleanup(function()
        pcall(function()
            if Window and Window.Unload then
                Window:Unload()
            end
        end)
        if genv._RLW_AdoptMe_Window == Window then
            genv._RLW_AdoptMe_Window = nil
        end
    end)

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
        local el = tab:CreateToggle({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            value = opts.value == true,
            forgetState = true,
            callback = function(val)
                setter(val)
                if extraCb then extraCb(val) end
                if ConfigManager then ConfigManager:MarkDirty() end
            end,
        })
        if opts.flag and ConfigManager and ConfigManager.Bind then
            ConfigManager:Bind(opts.flag, el, getter, setter)
        end
        return el
    end

    local function createBoundDropdown(tab, opts, getter, setter, extraCb)
        local labels = opts.labels
        local revLabels = nil
        local dispOptions = opts.options or {}
        if type(labels) == "table" then
            revLabels = {}
            dispOptions = {}
            for _, rawOpt in ipairs(opts.options or {}) do
                local disp = labels[rawOpt] or rawOpt
                table.insert(dispOptions, disp)
                revLabels[disp] = rawOpt
            end
        end

        local function mapValue(val, mapTbl)
            if not mapTbl then return val end
            if type(val) == "table" then
                local out = {}
                for _, item in ipairs(val) do
                    table.insert(out, mapTbl[item] or item)
                end
                return out
            end
            return mapTbl[val] or val
        end

        local function toDisplay(val)
            return mapValue(val, labels)
        end

        local function toInternal(val)
            return mapValue(val, revLabels)
        end

        local el = tab:CreateDropdown({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            options = dispOptions,
            value = toDisplay(opts.value),
            multiSelect = opts.multiSelect == true,
            forgetState = true,
            callback = function(val)
                local internalVal = toInternal(val)
                setter(internalVal)
                if extraCb then extraCb(internalVal) end
                if ConfigManager then ConfigManager:MarkDirty() end
            end,
        })
        if opts.flag and ConfigManager and ConfigManager.Bind then
            local boundTarget = el
            if labels then
                boundTarget = {
                    Set = function(_, val, silent)
                        if el and el.Set then
                            el:Set(toDisplay(val), silent)
                        end
                    end,
                }
            end
            ConfigManager:Bind(opts.flag, boundTarget, getter, setter)
        end
        return el
    end

    local function createBoundSlider(tab, opts, getter, setter, extraCb)
        local el = tab:CreateSlider({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            range = opts.range or { 0, 100 },
            increment = opts.increment or 1,
            value = opts.value,
            suffix = opts.suffix or "",
            forgetState = true,
            callback = function(val, dragging)
                setter(val, dragging)
                if extraCb then extraCb(val, dragging) end
                if not dragging and ConfigManager then
                    ConfigManager:MarkDirty()
                end
            end,
        })
        if opts.flag and ConfigManager and ConfigManager.Bind then
            ConfigManager:Bind(opts.flag, el, getter, setter)
        end
        return el
    end

    local function createBoundInput(tab, opts, getter, setter, extraCb)
        local el = tab:CreateInput({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            placeholder = opts.placeholder or "Metin girin...",
            value = tostring(opts.value or ""),
            clearOnFocus = opts.clearOnFocus == true,
            forgetState = true,
            callback = function(val)
                setter(tostring(val or ""))
                if extraCb then extraCb(tostring(val or "")) end
                if ConfigManager then ConfigManager:MarkDirty() end
            end,
        })
        if opts.flag and ConfigManager and ConfigManager.Bind then
            ConfigManager:Bind(opts.flag, el, getter, setter)
        end
        return el
    end

    local function bindHotkeyElement(name, cfgKey, defaultKeyName, actionFn, targetTab)
        local tab = targetTab or ctx.UI.ConfigTab
        local initialKey = Enum.KeyCode.Unknown
        pcall(function()
            if defaultKeyName and defaultKeyName ~= "None" and Enum.KeyCode[defaultKeyName] then
                initialKey = Enum.KeyCode[defaultKeyName]
            end
        end)
        local kb = tab:CreateKeybind({
            name = name,
            flag = "Hotkey_" .. tostring(cfgKey),
            value = initialKey,
            forgetState = true,
            callback = function()
                if CONFIG.Hotkeys[cfgKey] ~= "None" and actionFn then
                    actionFn()
                end
            end,
            onChanged = function(newKey)
                local keyStr = (typeof(newKey) == "EnumItem") and newKey.Name or tostring(newKey or "None")
                if keyStr == "Unknown" then keyStr = "None" end
                CONFIG.Hotkeys[cfgKey] = keyStr
                if ConfigManager then ConfigManager:MarkDirty() end
            end,
        })
        if ConfigManager and ConfigManager.Bind then
            ConfigManager:Bind("Hotkey_" .. tostring(cfgKey), kb, function()
                local kn = CONFIG.Hotkeys[cfgKey]
                if kn and kn ~= "None" and Enum.KeyCode[kn] then
                    return Enum.KeyCode[kn]
                end
                return Enum.KeyCode.Unknown
            end, function(v)
                CONFIG.Hotkeys[cfgKey] = (typeof(v) == "EnumItem") and v.Name or tostring(v or "None")
            end)
        end
        return kb
    end

    ctx.UI.safeNotify = safeNotify
    ctx.UI.createBoundToggle = createBoundToggle
    ctx.UI.createBoundDropdown = createBoundDropdown
    ctx.UI.createBoundSlider = createBoundSlider
    ctx.UI.createBoundInput = createBoundInput
    ctx.UI.bindHotkeyElement = bindHotkeyElement

    return WindowManager
end

return WindowManager
