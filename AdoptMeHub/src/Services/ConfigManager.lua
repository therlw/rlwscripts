-- src/Services/ConfigManager.lua
-- Config serialization, persistence, and UI synchronization for AdoptMeHub

local ConfigManager = {}

function ConfigManager.Init(ctx)
    local HttpService = ctx.Roblox.HttpService
    local CONFIG = ctx.Config
    local States = ctx.States

    local CM = {
        _dirty = false,
        _uiSyncCallbacks = {},
        _bindings = {},
    }

    local function ensureFolder()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("AdoptMeHub") then
                pcall(makefolder, "AdoptMeHub")
            end
            if CONFIG.Persistence.HouseFolder and not isfolder(CONFIG.Persistence.HouseFolder) then
                pcall(makefolder, CONFIG.Persistence.HouseFolder)
            end
        end
    end

    local function deepCopyInto(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return end
        for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" then
                deepCopyInto(dst[k], v)
            elseif dst[k] ~= nil then
                dst[k] = v
            end
        end
    end

    function CM:MarkDirty()
        self._dirty = true
    end

    function CM:Bind(flag, element, getter, setter)
        if not flag then return end
        self._bindings[flag] = {
            element = element,
            getter = getter,
            setter = setter,
        }
    end

    function CM:RegisterSync(fn)
        if type(fn) == "function" then
            table.insert(self._uiSyncCallbacks, fn)
        end
    end

    function CM:SyncAllUI()
        for _, binding in pairs(self._bindings) do
            pcall(function()
                if binding.element and binding.element.Set and binding.getter then
                    binding.element:Set(binding.getter(), true)
                end
            end)
        end
        for _, fn in ipairs(self._uiSyncCallbacks) do
            pcall(fn)
        end
    end

    function CM:SyncUI()
        self:SyncAllUI()
    end

    function CM:Save()
        if type(writefile) ~= "function" then return false end
        ensureFolder()
        local payload = {
            Version = 1,
            SavedAt = os.time(),
            Farm = States.Farm,
            Events = States.Events,
            Pets = States.Pets,
            House = States.House,
            Trade = States.Trade,
            Visuals = States.Visuals,
            CONFIG = CONFIG,
        }
        local okEnc, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
        if not okEnc then return false end
        local okW = pcall(writefile, CONFIG.Persistence.FileName, encoded)
        if okW then
            self._dirty = false
        end
        return okW == true
    end

    function CM:SaveIfDirty()
        if self._dirty and CONFIG.Persistence.AutoSave then
            self:Save()
        end
    end

    function CM:Load()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then return false end
        if not isfile(CONFIG.Persistence.FileName) then return false end
        local okR, raw = pcall(readfile, CONFIG.Persistence.FileName)
        if not okR or type(raw) ~= "string" then return false end
        local okDec, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if not okDec or type(data) ~= "table" then return false end

        for _, sec in ipairs({ "Farm", "Events", "Pets", "House", "Trade", "Visuals" }) do
            if type(data[sec]) == "table" then
                deepCopyInto(States[sec], data[sec])
            end
        end
        if type(data.CONFIG) == "table" then
            deepCopyInto(CONFIG, data.CONFIG)
        end
        self._dirty = false
        self:SyncAllUI()
        return true
    end

    function CM:ResetToDefaults()
        -- Keep UI responsive; user can re-save
        self:MarkDirty()
        self:SyncAllUI()
    end

    ctx.Services.ConfigManager = CM
    return CM
end

return ConfigManager
