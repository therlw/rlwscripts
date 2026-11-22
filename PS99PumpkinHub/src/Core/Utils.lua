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

    local function safeTableField(tbl, key)
        local v = rawget(tbl, key)
        if v ~= nil or getmetatable(tbl) == nil then
            return v
        end
        local ok, mv = pcall(function()
            return tbl[key]
        end)
        return ok and mv or nil
    end

    --- Safely unpacks a BreakableFrontend entry or raw Breakable Model without triggering Instance __index errors.
    local function unpackBreakable(brk)
        if brk == nil then
            return nil, nil, nil, nil, false
        end
        if typeof(brk) == "Instance" then
            local disabled = false
            pcall(function()
                disabled = brk:GetAttribute("DisableDamage") == true
            end)
            return brk, nil, nil, getInstancePos(brk), disabled
        end
        if type(brk) ~= "table" then
            return nil, nil, nil, nil, false
        end

        local rawModel = safeTableField(brk, "model")
        local model = (typeof(rawModel) == "Instance") and rawModel or nil

        local rawCA = safeTableField(brk, "clientAttributes")
        local ca = (type(rawCA) == "table") and rawCA or nil

        local rawDir = safeTableField(brk, "dir") or safeTableField(brk, "directory")
        local dir = (type(rawDir) == "table") and rawDir or nil

        local rawPos = safeTableField(brk, "position")
        local pos = (typeof(rawPos) == "Vector3") and rawPos or getInstancePos(model)

        local disabled = (safeTableField(brk, "disableDamage") == true)
        if not disabled and model then
            local okAttr, attrVal = pcall(model.GetAttribute, model, "DisableDamage")
            if okAttr and attrVal == true then
                disabled = true
            end
        end

        return model, ca, dir, pos, disabled
    end

    local function isPointInZonePart(part, pos)
        if not part or not part:IsA("BasePart") or not pos then return false end
        local localPos = part.CFrame:PointToObjectSpace(pos)
        local half = part.Size * 0.5
        return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z and math.abs(localPos.Y) <= half.Y + 100
    end

    --- Computes a stand position STRICTLY INSIDE the nearest BreakableZone part, on the edge closest to eggPos
    --- (so pets continue attacking zone breakables while the player remains within egg hatch range).
    local function computeBreakableZoneStandPos(eggPos, zoneParts, maxHatchRange, innerMargin)
        if not eggPos or type(zoneParts) ~= "table" or #zoneParts == 0 then
            return nil, false, nil
        end
        local margin = tonumber(innerMargin) or 3.0
        local maxRange = tonumber(maxHatchRange) or 28
        local bestPos = nil
        local bestDist = math.huge
        local bestPart = nil

        for _, part in ipairs(zoneParts) do
            if typeof(part) == "Instance" and part:IsA("BasePart") and part.Parent then
                local localEgg = part.CFrame:PointToObjectSpace(eggPos)
                local halfX = math.max(0, part.Size.X * 0.5 - margin)
                local halfZ = math.max(0, part.Size.Z * 0.5 - margin)
                local clampedLocal = Vector3.new(
                    math.clamp(localEgg.X, -halfX, halfX),
                    0,
                    math.clamp(localEgg.Z, -halfZ, halfZ)
                )
                local worldInside = part.CFrame:PointToWorldSpace(clampedLocal)
                local stand = Vector3.new(worldInside.X, eggPos.Y, worldInside.Z)
                local d = flatDist(stand, eggPos)
                if d < bestDist then
                    bestDist = d
                    bestPos = stand
                    bestPart = part
                end
            end
        end

        if bestPos and bestDist <= maxRange then
            return bestPos, true, bestPart
        end
        return bestPos, false, bestPart
    end

    local function postWebhook(url, payloadTbl)
        if type(url) ~= "string" or not string.match(url, "^https?://") then
            return false, "invalid url"
        end
        local reqFn = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (type(http) == "table" and type(http.request) == "function" and http.request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        if not reqFn then
            return false, "no http request fn"
        end
        local okEnc, body = pcall(function()
            return ctx.Roblox.HttpService:JSONEncode(payloadTbl)
        end)
        if not okEnc or type(body) ~= "string" then
            return false, "encode failed"
        end
        local okReq, resp = pcall(reqFn, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if not okReq then
            return false, tostring(resp)
        end
        local code = (type(resp) == "table" and tonumber(resp.StatusCode)) or 200
        return code >= 200 and code < 300, code
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
    Utils.unpackBreakable = unpackBreakable
    Utils.isPointInZonePart = isPointInZonePart
    Utils.computeBreakableZoneStandPos = computeBreakableZoneStandPos
    Utils.postWebhook = postWebhook
    Utils.fsEnsureFolder = fsEnsureFolder

    ctx.Utils = Utils
    return Utils
end

return Utils
