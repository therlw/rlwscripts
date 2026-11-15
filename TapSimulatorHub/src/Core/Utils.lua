-- src/Core/Utils.lua
-- Defensive Logging, Retry Remotes, Instance Coordinates, Number Formatting & Table/FS Helpers

local Utils = {}

function Utils.Init(ctx)
    local CONFIG = ctx.Config

    local function debugLog(...)
        if CONFIG.Debug and CONFIG.Debug.DebugMode then
            print("[RLW Debug]", ...)
        end
    end

    local function debugWarn(context, err)
        if CONFIG.Debug and CONFIG.Debug.DebugMode then
            warn(string.format("[RLW Error @ %s]: %s", tostring(context), tostring(err)))
        end
    end

    local function safeCall(context, fn, ...)
        local ok, res = pcall(fn, ...)
        if not ok then
            debugWarn(context, res)
        end
        return ok, res
    end

    local function getInstancePosition(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Model") then
            local ok, cf = pcall(function() return inst:GetPivot() end)
            if ok and cf then return cf.Position end
            if inst.PrimaryPart then return inst.PrimaryPart.Position end
        end
        local bp = inst:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.Position or nil
    end

    local function getInstanceCFrame(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.CFrame
        elseif inst:IsA("Model") then
            local ok, cf = pcall(function() return inst:GetPivot() end)
            if ok and cf then return cf end
            if inst.PrimaryPart then return inst.PrimaryPart.CFrame end
        end
        local bp = inst:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.CFrame or nil
    end

    local function safeFire(service, remoteType, remoteName, ...)
        local args = { ... }
        local success, result = pcall(function()
            if not service then return false end
            local container = service:FindFirstChild(remoteType or "RE")
            if not container then return false end
            local remote = container:FindFirstChild(remoteName)
            if not remote then return false end
            remote:FireServer(unpack(args))
            return true
        end)
        if not success then
            debugWarn("safeFire:" .. tostring(remoteName), result)
        end
        return success and result == true
    end

    local function safeInvoke(service, remoteType, remoteName, ...)
        local args = { ... }
        local attempts = math.max(1, (CONFIG.Retries and CONFIG.Retries.RemoteRetries) or 1)
        local retryDelay = (CONFIG.Retries and CONFIG.Retries.RemoteRetryDelay) or 0.25
        local lastErr = nil
        for attempt = 1, attempts do
            local success, result = pcall(function()
                if not service then return nil end
                local container = service:FindFirstChild(remoteType or "RF")
                if not container then return nil end
                local remote = container:FindFirstChild(remoteName)
                if not remote then return nil end
                return remote:InvokeServer(unpack(args))
            end)
            if success then
                return result
            end
            lastErr = result
            if attempt < attempts then
                task.wait(retryDelay)
            end
        end
        debugWarn("safeInvoke:" .. tostring(remoteName), lastErr)
        return nil
    end

    local function formatCompact(n)
        if n ~= n then return "0" end
        if not n or type(n) ~= "number" then return tostring(n or 0) end
        if ctx.Modules.FormatNumber and ctx.Modules.FormatNumber.Abbreviate then
            local ok, s = pcall(function() return ctx.Modules.FormatNumber:Abbreviate(n, true) end)
            if ok and s then return s end
        end
        if n >= 1e18 then return string.format("%.2fQi", n / 1e18)
        elseif n >= 1e15 then return string.format("%.2fQa", n / 1e15)
        elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
        elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
        elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
        elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
        else return tostring(math.floor(n)) end
    end

    local function deepCopyTable(tbl)
        if type(tbl) ~= "table" then return tbl end
        local copy = {}
        for k, v in pairs(tbl) do
            copy[k] = (type(v) == "table") and deepCopyTable(v) or v
        end
        return copy
    end

    local function applyMergedTable(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return end
        for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" then
                applyMergedTable(dst[k], v)
            elseif dst[k] == nil or type(dst[k]) == type(v) then
                dst[k] = v
            end
        end
    end

    local function fsEnsureFolder(folderPath)
        local ok = pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" then
                if not isfolder(folderPath) then
                    makefolder(folderPath)
                end
            end
        end)
        return ok
    end

    local function fsWrite(filePath, content)
        local ok, err = pcall(function()
            local folder = string.match(filePath, "^(.*)/[^/]+$")
            if folder then fsEnsureFolder(folder) end
            if type(writefile) == "function" then
                writefile(filePath, content)
            else
                error("writefile API unavailable in this executor")
            end
        end)
        return ok, err
    end

    local function fsRead(filePath)
        local ok, data = pcall(function()
            if type(isfile) == "function" and not isfile(filePath) then
                return nil
            end
            if type(readfile) == "function" then
                return readfile(filePath)
            end
            return nil
        end)
        if not ok then return nil end
        return data
    end

    local U = ctx.Utils
    U.debugLog = debugLog
    U.debugWarn = debugWarn
    U.safeCall = safeCall
    U.getInstancePosition = getInstancePosition
    U.getInstanceCFrame = getInstanceCFrame
    U.safeFire = safeFire
    U.safeInvoke = safeInvoke
    U.formatCompact = formatCompact
    U.deepCopyTable = deepCopyTable
    U.applyMergedTable = applyMergedTable
    U.fsEnsureFolder = fsEnsureFolder
    U.fsWrite = fsWrite
    U.fsRead = fsRead

    ctx.Logger.Log = debugLog
    ctx.Logger.Warn = debugWarn

    return Utils
end

return Utils
