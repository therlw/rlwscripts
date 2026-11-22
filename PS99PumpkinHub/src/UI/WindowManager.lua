-- src/UI/WindowManager.lua
-- Rayfield Gen2 Window Isolation, Previous Unload Cleanup, Safe Notify & Bound Element Builders

local WindowManager = {}

function WindowManager.Init(ctx)
    local CONFIG = ctx.Config
    local Players = ctx.Roblox.Players
    local PlayerGui = ctx.Roblox.PlayerGui
    local ConfigManager = ctx.ConfigManager
    local Lifecycle = ctx.Lifecycle
    local debugWarn = ctx.Utils.debugWarn

    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    -- Unload any prior Rayfield Gen2 window cleanly
    if genv._RLW_PS99_Window then
        pcall(function()
            if genv._RLW_PS99_Window.Unload then
                genv._RLW_PS99_Window:Unload()
            end
        end)
        genv._RLW_PS99_Window = nil
    end

    pcall(function()
        local lp = Players.LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        if pg then
            for _, child in ipairs(pg:GetChildren()) do
                if child:IsA("ScreenGui") and (child:FindFirstChild("PS99 | Pumpkin Tycoon Hub") or (string.find(child.Name, "-") and #child.Name > 30)) then
                    child:Destroy()
                end
            end
        end
    end)

    -- Route Rayfield into PlayerGui cleanly
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
        name = "PS99 | Pumpkin Tycoon Hub",
        subtitle = "by RLW",
        sidebarLayout = true,
        configuration = {
            autoSave = false,
            autoLoad = false,
            fileName = "PS99PumpkinHubRF",
        },
    })

    if type(getgenv) == "function" then
        pcall(function()
            getgenv().gethui = original_gethui
        end)
    end

    pcall(function()
        for _, child in ipairs(PlayerGui:GetChildren()) do
            if child:IsA("ScreenGui") and (string.find(child.Name, "-") and #child.Name > 30) then
                child.AutoLocalize = false
            end
        end
    end)

    genv._RLW_PS99_Window = Window
    ctx.Rayfield = Rayfield
    ctx.Window = Window

    Lifecycle.RegisterCleanup(function()
        pcall(function()
            if Window and Window.Unload then
                Window:Unload()
            end
        end)
        if genv._RLW_PS99_Window == Window then
            genv._RLW_PS99_Window = nil
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
                ConfigManager:MarkDirty()
            end,
        })
        if opts.flag then
            ConfigManager:Bind(opts.flag, el, getter, setter)
        end
        return el
    end

    local function createBoundDropdown(tab, opts, getter, setter, extraCb)
        local el = tab:CreateDropdown({
            name = opts.name,
            flag = opts.flag,
            description = opts.description,
            options = opts.options or {},
            value = opts.value,
            multiSelect = opts.multiSelect == true,
            forgetState = true,
            callback = function(val)
                setter(val)
                if extraCb then extraCb(val) end
                ConfigManager:MarkDirty()
            end,
        })
        if opts.flag then
            ConfigManager:Bind(opts.flag, el, getter, setter)
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
                if not dragging then
                    ConfigManager:MarkDirty()
                end
            end,
        })
        if opts.flag then
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
                ConfigManager:MarkDirty()
            end,
        })
        ConfigManager:Bind("Hotkey_" .. tostring(cfgKey), kb, function()
            local kn = CONFIG.Hotkeys[cfgKey]
            if kn and kn ~= "None" and Enum.KeyCode[kn] then
                return Enum.KeyCode[kn]
            end
            return Enum.KeyCode.Unknown
        end, function(v)
            CONFIG.Hotkeys[cfgKey] = (typeof(v) == "EnumItem") and v.Name or tostring(v or "None")
        end)
        return kb
    end

    ctx.UI.safeNotify = safeNotify
    ctx.UI.createBoundToggle = createBoundToggle
    ctx.UI.createBoundDropdown = createBoundDropdown
    ctx.UI.createBoundSlider = createBoundSlider
    ctx.UI.bindHotkeyElement = bindHotkeyElement

    return WindowManager
end

return WindowManager
