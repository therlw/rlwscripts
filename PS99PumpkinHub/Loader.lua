-- Loader.lua
-- Single Entry Point for PS99PumpkinHub GitHub RAW Modular Architecture
-- Usage:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/therlw/rlwscripts/main/PS99PumpkinHub/Loader.lua"))()

local DEFAULT_GITHUB_OWNER = "therlw"
local DEFAULT_GITHUB_REPO = "rlwscripts"
local DEFAULT_BRANCH = "main"
local DEFAULT_SUBPATH = "PS99PumpkinHub/"

local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
local genv = genFn()
local userCfg = (type(genv._RLW_PS99LoaderConfig) == "table") and genv._RLW_PS99LoaderConfig or {}

local owner = userCfg.Owner or DEFAULT_GITHUB_OWNER
local repo = userCfg.Repo or DEFAULT_GITHUB_REPO
local branch = userCfg.Branch or DEFAULT_BRANCH
local subPath = userCfg.SubPath
if subPath == nil then
    subPath = (userCfg.Owner == nil and userCfg.Repo == nil) and DEFAULT_SUBPATH or ""
end
if subPath ~= "" and string.sub(subPath, -1) ~= "/" then
    subPath = subPath .. "/"
end
local baseUrl = userCfg.BaseUrl or string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", owner, repo, branch, subPath)
if string.sub(baseUrl, -1) ~= "/" then
    baseUrl = baseUrl .. "/"
end

local Loader = {
    BaseUrl = baseUrl,
    Owner = owner,
    Repo = repo,
    Branch = branch,
    Retries = math.max(1, tonumber(userCfg.Retries) or 3),
    RetryDelay = tonumber(userCfg.RetryDelay) or 0.4,
    CacheBust = userCfg.CacheBust == true,
    UseMemoryCache = userCfg.UseMemoryCache == true,
    LocalFolder = userCfg.LocalFolder,
    Manifest = nil,
    Context = nil,
    Cache = (userCfg.UseMemoryCache == true and type(genv._RLW_PS99LoaderCache) == "table") and genv._RLW_PS99LoaderCache or {
        Sources = {},
        Modules = {},
    },
    Diagnostics = {
        StartedAt = os.clock(),
        FinishedAt = nil,
        TotalDurationMs = 0,
        FetchedCount = 0,
        CacheHitCount = 0,
        TotalBytes = 0,
        ModuleTimings = {},
        Errors = {},
    },
}

local function reportFatal(stage, detail)
    local msg = string.format("[PS99PumpkinHub Loader FATAL @ %s]: %s", tostring(stage), tostring(detail))
    table.insert(Loader.Diagnostics.Errors, msg)
    warn(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "PS99PumpkinHub Loader Error",
            Text = string.sub(msg, 1, 180),
            Duration = 8,
        })
    end)
    error(msg, 0)
end

if type(loadstring) ~= "function" then
    reportFatal("Preflight", "Executor 'loadstring' function is unavailable.")
end

local function getRequestFn()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if type(http) == "table" and type(http.request) == "function" then return http.request end
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    return nil
end

local function fetchSource(relPath)
    if type(Loader.LocalFolder) == "string" and Loader.LocalFolder ~= "" and type(isfile) == "function" and type(readfile) == "function" then
        local localPath = Loader.LocalFolder .. "/" .. relPath
        local okEx, ex = pcall(isfile, localPath)
        if okEx and ex then
            local okRead, body = pcall(readfile, localPath)
            if okRead and type(body) == "string" and #body > 0 then
                return true, body
            end
        end
    end

    local fullUrl = baseUrl .. relPath
    local lastErr = "Unknown HTTP error"
    for attempt = 1, Loader.Retries do
        local fetchUrl = Loader.CacheBust and (fullUrl .. (string.find(fullUrl, "?", 1, true) and "&" or "?") .. "_cb=" .. tostring(math.floor(os.clock() * 1000))) or fullUrl

        local okGame, bodyOrErr = pcall(function()
            return game:HttpGet(fetchUrl, true)
        end)
        if okGame and type(bodyOrErr) == "string" and #bodyOrErr > 0 and not string.match(bodyOrErr, "^%s*404:") and not string.match(bodyOrErr, "^%s*<") then
            return true, bodyOrErr
        end

        local reqFn = getRequestFn()
        if reqFn then
            local okReq, resp = pcall(reqFn, { Url = fetchUrl, Method = "GET" })
            if okReq and type(resp) == "table" then
                local status = tonumber(resp.StatusCode) or 0
                if status >= 200 and status < 300 and type(resp.Body) == "string" and #resp.Body > 0 then
                    return true, resp.Body
                else
                    lastErr = string.format("HTTP %d fetching %s", status, fullUrl)
                end
            else
                lastErr = tostring(resp or bodyOrErr or "HTTP exception")
            end
        else
            lastErr = tostring(bodyOrErr or "game:HttpGet failed & no fallback request API")
        end

        if attempt < Loader.Retries then
            task.wait(Loader.RetryDelay * attempt)
        end
    end
    return false, lastErr
end

-- Step 1: Fetch & Compile Manifest.lua
local manifestPath = userCfg.ManifestPath or "Manifest.lua"
local okMan, manifestSrcOrErr = fetchSource(manifestPath)
if not okMan then
    reportFatal("FetchManifest", string.format("Failed to fetch %s (%s)", manifestPath, tostring(manifestSrcOrErr)))
end

local manChunk, manCompileErr = loadstring(manifestSrcOrErr, "@" .. manifestPath)
if not manChunk then
    reportFatal("CompileManifest", tostring(manCompileErr))
end

local okExecMan, manifest = pcall(manChunk)
if not okExecMan or type(manifest) ~= "table" or type(manifest.Modules) ~= "table" or #manifest.Modules == 0 then
    reportFatal("ExecuteManifest", "Manifest.lua did not return a valid { Modules = {...} } table: " .. tostring(manifest))
end
Loader.Manifest = manifest

-- Step 2: Atomic Fetch + Compile + Factory Evaluation BEFORE terminating any prior Hub generation
local compiledFactories = {}
local seenIds = {}

for _, entry in ipairs(manifest.Modules) do
    local t0 = os.clock()
    if type(entry) ~= "table" or type(entry.id) ~= "string" or type(entry.path) ~= "string" then
        reportFatal("ManifestSchema", "Invalid module entry in Manifest.lua")
    end
    if seenIds[entry.id] then
        reportFatal("ManifestSchema", "Duplicate module id: " .. entry.id)
    end
    seenIds[entry.id] = true

    local src = Loader.UseMemoryCache and Loader.Cache.Sources[entry.path] or nil
    if type(src) == "string" then
        Loader.Diagnostics.CacheHitCount = Loader.Diagnostics.CacheHitCount + 1
    else
        local okFetch, bodyOrErr = fetchSource(entry.path)
        if not okFetch then
            if entry.required ~= false then
                reportFatal("Fetch:" .. entry.id, tostring(bodyOrErr))
            else
                table.insert(Loader.Diagnostics.Errors, "Optional fetch failed (" .. entry.id .. "): " .. tostring(bodyOrErr))
                continue
            end
        end
        src = bodyOrErr
        Loader.Cache.Sources[entry.path] = src
        Loader.Diagnostics.FetchedCount = Loader.Diagnostics.FetchedCount + 1
        Loader.Diagnostics.TotalBytes = Loader.Diagnostics.TotalBytes + #src
    end

    local chunkFn, syntaxErr = loadstring(src, "@" .. entry.path)
    if not chunkFn then
        if entry.required ~= false then
            reportFatal("Syntax:" .. entry.id, tostring(syntaxErr))
        else
            table.insert(Loader.Diagnostics.Errors, "Optional compile failed (" .. entry.id .. "): " .. tostring(syntaxErr))
            continue
        end
    end

    local okMod, modTable = pcall(chunkFn)
    if not okMod or type(modTable) ~= "table" then
        if entry.required ~= false then
            reportFatal("Evaluate:" .. entry.id, tostring(modTable or "Module did not return a table"))
        else
            table.insert(Loader.Diagnostics.Errors, "Optional eval failed (" .. entry.id .. "): " .. tostring(modTable))
            continue
        end
    end

    if entry.id == "Core.Context" then
        if type(modTable.New) ~= "function" then
            reportFatal("Contract:Core.Context", "Core.Context must expose New(opts)")
        end
    elseif type(modTable.Init) ~= "function" then
        if entry.required ~= false then
            reportFatal("Contract:" .. entry.id, "Required module missing Init(ctx) function")
        end
    end

    Loader.Cache.Modules[entry.id] = modTable
    table.insert(compiledFactories, {
        entry = entry,
        module = modTable,
        fetchCompileMs = (os.clock() - t0) * 1000,
    })
end

if Loader.UseMemoryCache then
    genv._RLW_PS99LoaderCache = Loader.Cache
end

-- Step 3: Build DI Container & Run Lifecycle Init
local bootstrapItem = compiledFactories[1]
if not bootstrapItem or bootstrapItem.entry.id ~= "Core.Context" then
    reportFatal("Bootstrap", "First module in Manifest.lua must be Core.Context")
end

local okCtx, ctx = pcall(bootstrapItem.module.New, {
    Version = manifest.Version,
    LoaderMeta = {
        BaseUrl = baseUrl,
        Owner = owner,
        Repo = repo,
        Branch = branch,
    },
})
if not okCtx or type(ctx) ~= "table" then
    reportFatal("BootstrapContext", tostring(ctx))
end

ctx.Loader = Loader
Loader.Context = ctx
ctx.LoadedModules[bootstrapItem.entry.id] = bootstrapItem.module

function Loader:ClearCache()
    table.clear(self.Cache.Sources)
    table.clear(self.Cache.Modules)
    genv._RLW_PS99LoaderCache = nil
end

function Loader:Require(id)
    return ctx.LoadedModules[id] or self.Cache.Modules[id]
end

-- Step 4: Initialize Modules in Order
for idx = 2, #compiledFactories do
    local item = compiledFactories[idx]
    local entry = item.entry
    local mod = item.module
    local tInit = os.clock()

    local okInit, resOrErr = pcall(mod.Init, ctx)
    local initMs = (os.clock() - tInit) * 1000

    Loader.Diagnostics.ModuleTimings[entry.id] = {
        fetchCompileMs = math.floor(item.fetchCompileMs * 100) / 100,
        initMs = math.floor(initMs * 100) / 100,
        startMs = 0,
    }

    if not okInit then
        if entry.required ~= false then
            reportFatal("Init:" .. entry.id, tostring(resOrErr))
        else
            table.insert(Loader.Diagnostics.Errors, "Optional Init failed (" .. entry.id .. "): " .. tostring(resOrErr))
        end
    else
        ctx.LoadedModules[entry.id] = (type(resOrErr) == "table") and resOrErr or mod
        if entry.id == "Core.Lifecycle" then
            ctx.Lifecycle = ctx.LoadedModules[entry.id]
        end
    end
end

-- Step 5: Start Runtime Workers & Event Listeners in Order
for idx = 2, #compiledFactories do
    local item = compiledFactories[idx]
    local entry = item.entry
    local mod = item.module
    if type(mod.Start) == "function" then
        local tStart = os.clock()
        local okStart, errStart = pcall(mod.Start, ctx)
        local startMs = (os.clock() - tStart) * 1000

        if Loader.Diagnostics.ModuleTimings[entry.id] then
            Loader.Diagnostics.ModuleTimings[entry.id].startMs = math.floor(startMs * 100) / 100
        end

        if not okStart then
            if entry.required ~= false then
                reportFatal("Start:" .. entry.id, tostring(errStart))
            else
                table.insert(Loader.Diagnostics.Errors, "Optional Start failed (" .. entry.id .. "): " .. tostring(errStart))
            end
        end
    end
end

Loader.Diagnostics.FinishedAt = os.clock()
Loader.Diagnostics.TotalDurationMs = math.floor((Loader.Diagnostics.FinishedAt - Loader.Diagnostics.StartedAt) * 1000 * 100) / 100

genv._RLW_PS99Loader = Loader
print(string.format("[PS99PumpkinHub] Booted %s (%s) — %d modules (%d fetched, %d cached, %.1f KB) in %.1f ms",
    tostring(manifest.Name),
    tostring(manifest.Version),
    #compiledFactories,
    Loader.Diagnostics.FetchedCount,
    Loader.Diagnostics.CacheHitCount,
    Loader.Diagnostics.TotalBytes / 1024,
    Loader.Diagnostics.TotalDurationMs
))

return Loader
