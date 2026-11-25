-- Loader.lua
-- Single Entry Point for AdoptMeHub GitHub RAW Modular Architecture
-- Usage:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/therlw/rlwscripts/main/AdoptMeHub/Loader.lua"))()

local DEFAULT_GITHUB_OWNER = "therlw"
local DEFAULT_GITHUB_REPO = "rlwscripts"
local DEFAULT_BRANCH = "main"
local DEFAULT_SUBPATH = "AdoptMeHub/"

local genFn = (type(getgenv) == "function") and getgenv or function() return _G end
local genv = genFn()
local userCfg = (type(genv._RLW_AdoptMeLoaderConfig) == "table") and genv._RLW_AdoptMeLoaderConfig or {}

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
    CacheBust = userCfg.CacheBust ~= false,
    UseMemoryCache = userCfg.UseMemoryCache == true,
    LocalFolder = userCfg.LocalFolder,
    Manifest = nil,
    Context = nil,
    Cache = (userCfg.UseMemoryCache == true and type(genv._RLW_AdoptMeLoaderCache) == "table") and genv._RLW_AdoptMeLoaderCache or {
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
    local msg = string.format("[AdoptMeHub Loader FATAL @ %s]: %s", tostring(stage), tostring(detail))
    table.insert(Loader.Diagnostics.Errors, msg)
    warn(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "AdoptMeHub Loader Error",
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
            lastErr = tostring(bodyOrErr or "game:HttpGet failed")
        end

        if attempt < Loader.Retries then
            task.wait(Loader.RetryDelay * attempt)
        end
    end

    return false, lastErr
end

local function compileModule(relPath, source)
    local fn, syntaxErr = loadstring(source, "@" .. relPath)
    if not fn then
        return false, string.format("Syntax error in %s: %s", relPath, tostring(syntaxErr))
    end
    local okExec, result = pcall(fn)
    if not okExec then
        return false, string.format("Runtime error loading %s: %s", relPath, tostring(result))
    end
    return true, result
end

local function loadEntry(entry)
    local t0 = os.clock()
    local source = Loader.UseMemoryCache and Loader.Cache.Sources[entry.path] or nil
    if type(source) == "string" and #source > 0 then
        Loader.Diagnostics.CacheHitCount = Loader.Diagnostics.CacheHitCount + 1
    else
        local okFetch, srcOrErr = fetchSource(entry.path)
        if not okFetch then
            return false, string.format("Fetch failed (%s): %s", entry.id, tostring(srcOrErr))
        end
        source = srcOrErr
        Loader.Diagnostics.FetchedCount = Loader.Diagnostics.FetchedCount + 1
        Loader.Diagnostics.TotalBytes = Loader.Diagnostics.TotalBytes + #source
        if Loader.UseMemoryCache then
            Loader.Cache.Sources[entry.path] = source
        end
    end

    local okCompile, modOrErr = compileModule(entry.path, source)
    if not okCompile then
        return false, modOrErr
    end

    Loader.Cache.Modules[entry.id] = modOrErr
    Loader.Diagnostics.ModuleTimings[entry.id] = math.floor((os.clock() - t0) * 10000) / 10
    return true, modOrErr
end

function Loader.LoadManifest()
    local ok, srcOrErr = fetchSource("Manifest.lua")
    if not ok then
        reportFatal("ManifestFetch", srcOrErr)
    end
    local okComp, manifest = compileModule("Manifest.lua", srcOrErr)
    if not okComp or type(manifest) ~= "table" or type(manifest.Modules) ~= "table" then
        reportFatal("ManifestCompile", tostring(manifest))
    end
    Loader.Manifest = manifest
    return manifest
end

function Loader.UnloadPrevious()
    local prev = genv._RLW_AdoptMeHub
    if type(prev) == "table" and type(prev.Unload) == "function" then
        pcall(prev.Unload)
        task.wait(0.15)
    end
end

function Loader.Boot()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    Loader.UnloadPrevious()

    local manifest = Loader.LoadManifest()
    local ctxModule = nil
    local remaining = {}

    for _, entry in ipairs(manifest.Modules) do
        if entry.phase == "bootstrap" and entry.id == "Core.Context" then
            local ok, modOrErr = loadEntry(entry)
            if not ok then
                reportFatal("Bootstrap", modOrErr)
            end
            ctxModule = modOrErr
        else
            table.insert(remaining, entry)
        end
    end

    if type(ctxModule) ~= "table" or type(ctxModule.Create) ~= "function" then
        reportFatal("Bootstrap", "Core.Context must expose Context.Create(opts)")
    end

    local ctx = ctxModule.Create({
        Version = manifest.Version,
        LoaderMeta = {
            BaseUrl = baseUrl,
            Branch = branch,
            Diagnostics = Loader.Diagnostics,
        },
    })
    ctx.Loader = Loader
    Loader.Context = ctx

    for _, entry in ipairs(remaining) do
        local ok, modOrErr = loadEntry(entry)
        if not ok then
            if entry.required ~= false then
                reportFatal("ModuleLoad:" .. entry.id, modOrErr)
            else
                warn(string.format("[AdoptMeHub Loader WARN] Optional module %s skipped: %s", entry.id, tostring(modOrErr)))
            end
        elseif type(modOrErr) == "table" and type(modOrErr.Init) == "function" then
            local okInit, initErr = pcall(modOrErr.Init, ctx)
            if not okInit then
                if entry.required ~= false then
                    reportFatal("ModuleInit:" .. entry.id, initErr)
                else
                    warn(string.format("[AdoptMeHub Loader WARN] Init failed for %s: %s", entry.id, tostring(initErr)))
                end
            end
        end
    end

    for _, entry in ipairs(manifest.Modules) do
        local mod = Loader.Cache.Modules[entry.id]
        if type(mod) == "table" and type(mod.Start) == "function" then
            local okStart, startErr = pcall(mod.Start, ctx)
            if not okStart then
                warn(string.format("[AdoptMeHub Loader WARN] Start failed for %s: %s", entry.id, tostring(startErr)))
            end
        end
    end

    if ctx.Services and ctx.Services.ConfigManager then
        pcall(function()
            ctx.Services.ConfigManager:Load()
        end)
    end

    -- Background farm loop
    if ctx.Lifecycle and ctx.Lifecycle.SpawnLoop then
        ctx.Lifecycle.SpawnLoop("AdoptMeMainLoop", 0.75, function()
            if ctx.DualFarm and ctx.DualFarm.StepOnce then
                ctx.DualFarm.StepOnce()
            end
            if ctx.EventsAndWorld and ctx.EventsAndWorld.StepOnce then
                ctx.EventsAndWorld.StepOnce()
            end
            if ctx.PetManager and ctx.PetManager.StepOnce then
                ctx.PetManager.StepOnce()
            end
            if ctx.HouseAndEconomy and ctx.HouseAndEconomy.StepOnce then
                ctx.HouseAndEconomy.StepOnce()
            end
            if ctx.TradeSystem and ctx.TradeSystem.StepOnce then
                ctx.TradeSystem.StepOnce()
            end
        end)
    end

    if ctx.Services and ctx.Services.ConfigManager then
        ctx.Lifecycle.SpawnLoop("AdoptMeConfigAutosave", 5, function()
            ctx.Services.ConfigManager:SaveIfDirty()
        end)
    end

    Loader.Diagnostics.FinishedAt = os.clock()
    Loader.Diagnostics.TotalDurationMs = math.floor((Loader.Diagnostics.FinishedAt - Loader.Diagnostics.StartedAt) * 10000) / 10
    if Loader.UseMemoryCache then
        genv._RLW_AdoptMeLoaderCache = Loader.Cache
    end

    print(string.format(
        "[AdoptMeHub] Booted %s (%s) — %d modules (%d fetched, %d cached, %.1f KB) in %.1f ms",
        tostring(manifest.Name),
        tostring(manifest.Version),
        #manifest.Modules,
        Loader.Diagnostics.FetchedCount,
        Loader.Diagnostics.CacheHitCount,
        Loader.Diagnostics.TotalBytes / 1024,
        Loader.Diagnostics.TotalDurationMs
    ))

    return ctx
end

return Loader.Boot()
