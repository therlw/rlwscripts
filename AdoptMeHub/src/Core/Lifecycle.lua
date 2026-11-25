-- src/Core/Lifecycle.lua
-- Generation-based cleanup, connection/thread tracking, and safe loop orchestration

local Lifecycle = {}

function Lifecycle.Init(ctx)
    local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
    local genv = genFn()

    local L = {
        _connections = {},
        _threads = {},
        _cleanupHooks = {},
    }

    function L.BeginGeneration()
        local nextGen = (tonumber(genv._RLW_AdoptMeHubGeneration) or 0) + 1
        genv._RLW_AdoptMeHubGeneration = nextGen
        ctx.Generation = nextGen
        return nextGen
    end

    function L.IsCurrentGeneration(gen)
        return (genv._RLW_AdoptMeHubGeneration == (gen or ctx.Generation)) and ctx.Generation > 0
    end

    function L.TrackConnection(conn)
        if conn then
            table.insert(L._connections, conn)
        end
        return conn
    end

    function L.AddCleanup(fn)
        if type(fn) == "function" then
            table.insert(L._cleanupHooks, fn)
        end
    end

    L.RegisterCleanup = L.AddCleanup

    function L.SpawnLoop(name, intervalSec, callback)
        local myGen = ctx.Generation
        local thread = task.spawn(function()
            while L.IsCurrentGeneration(myGen) do
                local ok, err = pcall(callback)
                if not ok and ctx.Config.Debug.DebugMode then
                    warn(string.format("[AdoptMeHub:%s] %s", tostring(name), tostring(err)))
                end
                local waitLeft = intervalSec or 0.5
                while waitLeft > 0 and L.IsCurrentGeneration(myGen) do
                    local step = math.min(waitLeft, 0.25)
                    task.wait(step)
                    waitLeft = waitLeft - step
                end
            end
        end)
        table.insert(L._threads, thread)
        return thread
    end

    function L.Unload()
        genv._RLW_AdoptMeHubGeneration = (tonumber(genv._RLW_AdoptMeHubGeneration) or 0) + 1
        for _, conn in ipairs(L._connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(L._connections)

        for _, fn in ipairs(L._cleanupHooks) do
            pcall(fn)
        end
        table.clear(L._cleanupHooks)

        if ctx.Runtime.RayfieldUnload then
            pcall(ctx.Runtime.RayfieldUnload)
            ctx.Runtime.RayfieldUnload = nil
        end
    end

    ctx.Lifecycle = L
    return L
end

return Lifecycle
