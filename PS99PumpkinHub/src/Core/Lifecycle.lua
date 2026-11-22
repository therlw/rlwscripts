-- src/Core/Lifecycle.lua
-- Script Generation Token, Safe Resource Cleanup & Background Worker Scheduler
-- Intentionally performs NO input spoofing or metamethod hooking.

local Lifecycle = {}

function Lifecycle.Init(ctx)
    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    local SCRIPT_GENERATION = (genv._RLW_PS99_ScriptGen or 0) + 1
    genv._RLW_PS99_ScriptGen = SCRIPT_GENERATION
    ctx.Generation = SCRIPT_GENERATION
    ctx.Runtime.Generation = SCRIPT_GENERATION
    print(string.format("[PS99PumpkinHub] Starting Generation %d", SCRIPT_GENERATION))

    -- Run cleanup from any previous generation cleanly before registering new resources
    if genv._RLW_PS99_Cleanup then
        pcall(genv._RLW_PS99_Cleanup)
        genv._RLW_PS99_Cleanup = nil
    end

    function Lifecycle.IsCurrentGeneration()
        return genv._RLW_PS99_ScriptGen == ctx.Generation
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

    function Lifecycle.SpawnLoop(name, intervalFnOrNum, fn)
        task.spawn(function()
            while Lifecycle.IsCurrentGeneration() do
                local ok, err = pcall(fn)
                if not ok and ctx.Utils and ctx.Utils.debugWarn then
                    ctx.Utils.debugWarn("Loop:" .. tostring(name), err)
                end
                local waitTime = (type(intervalFnOrNum) == "function") and intervalFnOrNum() or tonumber(intervalFnOrNum) or 0.5
                task.wait(math.max(0.03, waitTime))
            end
        end)
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

    genv._RLW_PS99_Cleanup = function()
        Lifecycle.CleanupAll()
    end

    ctx.Lifecycle = Lifecycle
    return Lifecycle
end

return Lifecycle
