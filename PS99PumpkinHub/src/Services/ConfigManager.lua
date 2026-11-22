-- src/Services/ConfigManager.lua
-- JSON Persistence, Rayfield Gen2 Element Binding & State Synchronization

local ConfigManagerModule = {}

function ConfigManagerModule.Init(ctx)
    local HttpService = ctx.Roblox.HttpService
    local CONFIG = ctx.Config
    local States = ctx.States
    local debugWarn = ctx.Utils.debugWarn
    local deepCopyTable = ctx.Utils.deepCopyTable
    local applyMergedTable = ctx.Utils.applyMergedTable
    local fsEnsureFolder = ctx.Utils.fsEnsureFolder

    local ConfigManager = {
        Bindings = {},
        Loaded = false,
        LastSavedAt = nil,
        LastError = nil,
        _applying = false,
        _saveScheduled = false,
        _dirty = false,
    }

    local STATE_SECTIONS = {
        "Movement",
        "Main",
        "PumpkinTycoon",
        "Farm",
        "Egg",
        "Automatic",
        "FishingWorld",
        "FarmingWorld",
        "Mailbox",
        "Optimization",
        "Webhook",
    }

    local DEFAULT_SNAPSHOT = {
        CONFIG = {
            Notifications = deepCopyTable(CONFIG.Notifications),
            Debug = deepCopyTable(CONFIG.Debug),
            Persistence = deepCopyTable(CONFIG.Persistence),
            Hotkeys = deepCopyTable(CONFIG.Hotkeys),
        },
    }
    for _, sec in ipairs(STATE_SECTIONS) do
        DEFAULT_SNAPSHOT[sec] = deepCopyTable(States[sec])
    end

    local function fsWrite(filePath, content)
        if type(writefile) ~= "function" then
            return false, "writefile not available"
        end
        local dir = string.match(filePath, "^(.*)/[^/]+$")
        if dir and dir ~= "" then
            fsEnsureFolder(dir)
        end
        local ok, err = pcall(writefile, filePath, content)
        return ok, err
    end

    local function fsRead(filePath)
        if type(isfile) ~= "function" or type(readfile) ~= "function" then
            return false, "readfile not available"
        end
        local okEx, exists = pcall(isfile, filePath)
        if not okEx or not exists then
            return false, "Config file not found yet"
        end
        local okRead, content = pcall(readfile, filePath)
        if not okRead or type(content) ~= "string" then
            return false, tostring(content or "Read failed")
        end
        return true, content
    end

    function ConfigManager:Bind(flag, element, getter, setter)
        if not flag or not element then
            return element
        end
        self.Bindings[flag] = {
            element = element,
            getter = getter,
            setter = setter,
        }
        return element
    end

    function ConfigManager:SyncUI()
        self._applying = true
        for _, b in pairs(self.Bindings) do
            pcall(function()
                if b.getter and b.element and b.element.Set then
                    local val = b.getter()
                    if val ~= nil then
                        b.element:Set(val, true)
                    end
                end
            end)
        end
        self._applying = false
    end

    function ConfigManager:ExportSnapshot()
        local snap = {
            Version = 2,
            SavedAt = os.time(),
            CONFIG = {
                Notifications = deepCopyTable(CONFIG.Notifications),
                Debug = deepCopyTable(CONFIG.Debug),
                Persistence = deepCopyTable(CONFIG.Persistence),
                Hotkeys = deepCopyTable(CONFIG.Hotkeys),
            },
        }
        for _, sec in ipairs(STATE_SECTIONS) do
            snap[sec] = deepCopyTable(States[sec])
        end
        return snap
    end

    function ConfigManager:ApplySnapshot(snap)
        if type(snap) ~= "table" then
            return false, "Invalid snapshot"
        end
        self._applying = true
        pcall(function()
            if snap.CONFIG then applyMergedTable(CONFIG, snap.CONFIG) end
            for _, sec in ipairs(STATE_SECTIONS) do
                if snap[sec] and States[sec] then
                    applyMergedTable(States[sec], snap[sec])
                end
            end
        end)
        self:SyncUI()
        self._applying = false
        self._dirty = false

        if ctx.Optimizer then
            if ctx.Optimizer.SetEnabled then
                pcall(ctx.Optimizer.SetEnabled, States.PumpkinTycoon.OptimizePumpkinTycoon == true)
            end
            if ctx.Optimizer.ApplyAll then
                pcall(ctx.Optimizer.ApplyAll)
            end
        end
        return true
    end

    function ConfigManager:Save(customPath)
        local path = customPath or (CONFIG.Persistence and CONFIG.Persistence.FileName) or "PS99PumpkinHub/config.json"
        local okEnc, jsonStr = pcall(function()
            return HttpService:JSONEncode(self:ExportSnapshot())
        end)
        if not okEnc or type(jsonStr) ~= "string" then
            self.LastError = tostring(jsonStr)
            return false, self.LastError
        end
        local okWrite, errWrite = fsWrite(path, jsonStr)
        if not okWrite then
            self.LastError = tostring(errWrite)
            return false, self.LastError
        end
        self.LastSavedAt = os.time()
        self.LastError = nil
        self._dirty = false
        return true, path
    end

    function ConfigManager:Load(customPath)
        local path = customPath or (CONFIG.Persistence and CONFIG.Persistence.FileName) or "PS99PumpkinHub/config.json"
        local okRead, content = fsRead(path)
        if not okRead then
            self.LastError = tostring(content)
            return false, self.LastError
        end
        local okDec, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if not okDec or type(decoded) ~= "table" then
            self.LastError = "Corrupt JSON: " .. tostring(decoded)
            debugWarn("ConfigManager:Load", self.LastError)
            return false, self.LastError
        end
        local okApply, errApply = self:ApplySnapshot(decoded)
        if not okApply then
            self.LastError = tostring(errApply)
            return false, self.LastError
        end
        self.Loaded = true
        self.LastError = nil
        return true, "Loaded"
    end

    function ConfigManager:Reset()
        local ok, err = self:ApplySnapshot(deepCopyTable(DEFAULT_SNAPSHOT))
        return ok, err
    end

    function ConfigManager:MarkDirty()
        if self._applying then return end
        if not (CONFIG.Persistence and CONFIG.Persistence.AutoSave) then return end
        self._dirty = true
        if self._saveScheduled then return end
        self._saveScheduled = true
        task.delay(0.15, function()
            self._saveScheduled = false
            if ctx.Lifecycle and not ctx.Lifecycle.IsCurrentGeneration() then return end
            if CONFIG.Persistence and CONFIG.Persistence.AutoSave and self._dirty then
                pcall(function() self:Save() end)
            end
        end)
    end

    if ctx.Lifecycle and ctx.Lifecycle.RegisterCleanup then
        ctx.Lifecycle.RegisterCleanup(function()
            if ConfigManager._dirty and CONFIG.Persistence and CONFIG.Persistence.AutoSave then
                pcall(function() ConfigManager:Save() end)
            end
        end)
    end

    ctx.ConfigManager = ConfigManager
    return ConfigManager
end

return ConfigManagerModule
