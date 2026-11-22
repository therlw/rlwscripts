-- src/Core/Utils.lua
-- Logging, Formatting, Geometry, Set Membership & Executor File System Helpers

local Utils = {}

function Utils.Init(ctx)
    local CONFIG = ctx.Config

    local function debugLog(...)
        if CONFIG.Debug and CONFIG.Debug.DebugMode then
            print("[PS99 Debug]", ...)
        end
    end

    local function debugWarn(context, err)
        if CONFIG.Debug and CONFIG.Debug.DebugMode then
            warn(string.format("[PS99 Error @ %s]: %s", tostring(context), tostring(err)))
        end
    end

    local function safeCall(context, fn, ...)
        local ok, res = pcall(fn, ...)
        if not ok then
            debugWarn(context, res)
        end
        return ok, res
    end

    local function formatCompact(n)
        if type(n) ~= "number" or n ~= n then
            return "0"
        end
        local absN = math.abs(n)
        if absN >= 1e18 then return string.format("%.2fQi", n / 1e18)
        elseif absN >= 1e15 then return string.format("%.2fQa", n / 1e15)
        elseif absN >= 1e12 then return string.format("%.2fT", n / 1e12)
        elseif absN >= 1e9 then return string.format("%.2fB", n / 1e9)
        elseif absN >= 1e6 then return string.format("%.2fM", n / 1e6)
        elseif absN >= 1e3 then return string.format("%.1fK", n / 1e3)
        end
        return tostring(math.floor(n + 0.5))
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
                if #dst[k] > 0 or #v > 0 then
                    dst[k] = deepCopyTable(v)
                else
                    applyMergedTable(dst[k], v)
                end
            elseif dst[k] == nil or type(dst[k]) == type(v) then
                dst[k] = v
            end
        end
    end

    local function arrayToSet(list)
        local set = {}
        if type(list) == "table" then
            for _, v in ipairs(list) do
                set[v] = true
            end
        end
        return set
    end

    local function getCharacterParts()
        local lp = ctx.Roblox.LocalPlayer
        local char = lp and lp.Character
        if not char then return nil, nil, nil end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hrp.Parent then return char, nil, hum end
        return char, hrp, hum
    end

    local function flatDist(a, b)
        if not a or not b then return math.huge end
        return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
    end

    local function dist3D(a, b)
        if not a or not b then return math.huge end
        return (a - b).Magnitude
    end

    local function getInstancePos(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then
            local ok, cf = pcall(function() return inst:GetPivot() end)
            if ok and cf then return cf.Position end
        end
        local bp = inst:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.Position or nil
    end

    local function fsEnsureFolder(folderPath)
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" then
                if not isfolder(folderPath) then
                    makefolder(folderPath)
                end
            end
        end)
    end

    Utils.debugLog = debugLog
    Utils.debugWarn = debugWarn
    Utils.safeCall = safeCall
    Utils.formatCompact = formatCompact
    Utils.deepCopyTable = deepCopyTable
    Utils.applyMergedTable = applyMergedTable
    Utils.arrayToSet = arrayToSet
    Utils.getCharacterParts = getCharacterParts
    Utils.flatDist = flatDist
    Utils.dist3D = dist3D
    Utils.getInstancePos = getInstancePos
    Utils.fsEnsureFolder = fsEnsureFolder

    ctx.Utils = Utils
    return Utils
end

return Utils
