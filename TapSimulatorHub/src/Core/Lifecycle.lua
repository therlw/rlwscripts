-- src/Core/Lifecycle.lua
-- Generation Token, Cleanup/Restore Registry, Connection Tracking & Anti-AFK System

local Lifecycle = {}

function Lifecycle.Init(ctx)
    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    local SCRIPT_GENERATION = (genv._RLW_ScriptGen or 0) + 1
    genv._RLW_ScriptGen = SCRIPT_GENERATION
    ctx.Generation = SCRIPT_GENERATION
    print(string.format("[RLW] TapSimulatorHub starting - Generation %d", SCRIPT_GENERATION))

    -- Clean up any prior CPU Saver state from previous script generations
    if genv._RLW_CpuSaverRestore then
        pcall(genv._RLW_CpuSaverRestore)
        genv._RLW_CpuSaverRestore = nil
    end

    -- Clean up any previous connections & hook cleanups from prior script generations
    if genv._RLW_Cleanup then
        pcall(genv._RLW_Cleanup)
        genv._RLW_Cleanup = nil
    end

    -- Disconnect any previous Anti-AFK connection from prior script executions
    if genv._RLW_AntiAFK_Conn then
        pcall(function()
            genv._RLW_AntiAFK_Conn:Disconnect()
        end)
        genv._RLW_AntiAFK_Conn = nil
    end

    local function triggerAntiAfkAction(_reason)
        local acted = false
        pcall(function()
            local vu = ctx.Roblox.VirtualUser or game:GetService("VirtualUser")
            if vu then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0, 0))
                acted = true
            end
        end)
        pcall(function()
            local vim = ctx.Roblox.VirtualInputManager or game:GetService("VirtualInputManager")
            if vim then
                vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
                acted = true
            end
        end)
        return acted
    end

    function Lifecycle.IsCurrentGeneration()
        return genv._RLW_ScriptGen == ctx.Generation
    end

    function Lifecycle.TrackConnection(conn)
        if conn then
            table.insert(ctx.Connections, conn)
        end
        return conn
    end

    function Lifecycle.RegisterCleanup(fn)
        if type(fn) == "function" then
            table.insert(ctx.CleanupCallbacks, fn)
        end
    end

    function Lifecycle.CleanupAll()
        for _, fn in ipairs(ctx.CleanupCallbacks) do
            pcall(fn)
        end
        table.clear(ctx.CleanupCallbacks)

        for _, conn in ipairs(ctx.Connections) do
            pcall(function()
                if type(conn) == "table" and conn.Disconnect then
                    conn:Disconnect()
                elseif typeof(conn) == "RBXScriptConnection" then
                    conn:Disconnect()
                end
            end)
        end
        table.clear(ctx.Connections)
    end

    genv._RLW_Cleanup = function()
        Lifecycle.CleanupAll()
    end

    -- 1. Reactive Anti-AFK: Hooks into Roblox engine's 20-minute Idled warning signal
    pcall(function()
        genv._RLW_AntiAFK_Conn = ctx.Roblox.LocalPlayer.Idled:Connect(function()
            triggerAntiAfkAction("Idled Event Detected")
            print(string.format("[RLW Anti-AFK] Prevented 20-minute idle disconnect at %s", os.date("%X")))
        end)
    end)

    Lifecycle.TriggerAntiAfkAction = triggerAntiAfkAction
    ctx.Lifecycle = Lifecycle
    return Lifecycle
end

function Lifecycle.Start(ctx)
    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    -- 2. Proactive Anti-AFK Heartbeat: Sends simulated input every 3 minutes (180s)
    task.spawn(function()
        print("[RLW Anti-AFK] Proactive background heartbeat active (Running for Kaitun & Normal modes).")
        while true do
            if genv._RLW_ScriptGen ~= ctx.Generation then break end
            task.wait(ctx.Config.AntiAfkHeartbeatInterval)
            pcall(function()
                Lifecycle.TriggerAntiAfkAction("Proactive Heartbeat")
            end)
        end
    end)
end

return Lifecycle
