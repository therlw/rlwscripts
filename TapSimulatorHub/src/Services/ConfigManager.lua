-- src/Services/ConfigManager.lua
-- JSON Persistence, UI Element Binding, State Sync & Safe Defaults Reset (Mirrors [02b])

local ConfigManagerModule = {}

function ConfigManagerModule.Init(ctx)
    local HttpService = ctx.Roblox.HttpService
    local CONFIG = ctx.Config
    local States = ctx.States
    local debugWarn = ctx.Utils.debugWarn
    local deepCopyTable = ctx.Utils.deepCopyTable

    local ConfigManager = {
        Bindings = {},
        StateBindings = {},
        Loaded = false,
        LastSavedAt = nil,
        LastError = nil,
        _applying = false,
        _saveScheduled = false,
    }

    local DEFAULT_PERSISTENT_SNAPSHOT = {
        CONFIG = {
            TapLoopDelay = CONFIG.TapLoopDelay,
            HatchCooldown = CONFIG.HatchCooldown,
            HatchJitterCushion = CONFIG.HatchJitterCushion,
            HatchLoopDelay = CONFIG.HatchLoopDelay,
            TrashCleanInterval = CONFIG.TrashCleanInterval,
            QuestClaimInterval = CONFIG.QuestClaimInterval,
            MachineCheckInterval = CONFIG.MachineCheckInterval,
            EventCheckInterval = CONFIG.EventCheckInterval,
            Retries = deepCopyTable(CONFIG.Retries),
            Notifications = deepCopyTable(CONFIG.Notifications),
            Debug = deepCopyTable(CONFIG.Debug),
            Webhook = deepCopyTable(CONFIG.Webhook),
            Hotkeys = deepCopyTable(CONFIG.Hotkeys),
            Persistence = deepCopyTable(CONFIG.Persistence),
        },
        AutoFarmState = deepCopyTable(States.AutoFarm),
        HatchState = deepCopyTable(States.Hatch),
        UpgradeState = deepCopyTable(States.Upgrade),
        IslandState = deepCopyTable(States.Island),
        RewardState = deepCopyTable(States.Reward),
        PlayerState = deepCopyTable(States.Player),
        OptimizationState = deepCopyTable(States.Optimization),
        MachineState = deepCopyTable(States.Machine),
        EventState = {
            MonitorGlobalEvents = States.Event.MonitorGlobalEvents,
            AutoBalloonInflate = States.Event.AutoBalloonInflate,
            AutoCloudRain = States.Event.AutoCloudRain,
        },
        KaitunState = {
            Enabled = States.Kaitun.Enabled,
            AllowHatch = States.Kaitun.AllowHatch,
            AllowTripleHatch = States.Kaitun.AllowTripleHatch,
            AllowRebirth = States.Kaitun.AllowRebirth,
            AllowSkillTree = States.Kaitun.AllowSkillTree,
            AllowIslandUnlock = States.Kaitun.AllowIslandUnlock,
            AllowAutoCraft = States.Kaitun.AllowAutoCraft,
            SuppressMachineUI = States.Kaitun.SuppressMachineUI,
            AllowChestsAndStars = States.Kaitun.AllowChestsAndStars,
            AllowTrashCleaning = States.Kaitun.AllowTrashCleaning,
            AllowSmartBoosts = States.Kaitun.AllowSmartBoosts,
            CollectShinyStars = States.Kaitun.CollectShinyStars,
            AutoLuckyDucky = States.Kaitun.AutoLuckyDucky,
        },
    }

    local function fsEnsureFolder(folderPath)
        if type(isfolder) == "function" and type(makefolder) == "function" then
            local ok, exists = pcall(isfolder, folderPath)
            if ok and not exists then
                pcall(makefolder, folderPath)
            end
        end
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
        local okExists, exists = pcall(isfile, filePath)
        if not okExists or not exists then
            return false, "File not found"
        end
        local okRead, content = pcall(readfile, filePath)
        if not okRead or type(content) ~= "string" then
            return false, tostring(content or "Read failed")
        end
        return true, content
    end

    local function applyMergedTable(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return end
        for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" then
                applyMergedTable(dst[k], v)
            elseif dst[k] ~= nil then
                dst[k] = v
            end
        end
    end

    function ConfigManager:ExportSnapshot()
        return {
            Version = 2,
            SavedAt = os.time(),
            CONFIG = {
                TapLoopDelay = CONFIG.TapLoopDelay,
                HatchCooldown = CONFIG.HatchCooldown,
                HatchJitterCushion = CONFIG.HatchJitterCushion,
                HatchLoopDelay = CONFIG.HatchLoopDelay,
                TrashCleanInterval = CONFIG.TrashCleanInterval,
                QuestClaimInterval = CONFIG.QuestClaimInterval,
                MachineCheckInterval = CONFIG.MachineCheckInterval,
                EventCheckInterval = CONFIG.EventCheckInterval,
                Retries = deepCopyTable(CONFIG.Retries),
                Notifications = deepCopyTable(CONFIG.Notifications),
                Debug = deepCopyTable(CONFIG.Debug),
                Webhook = deepCopyTable(CONFIG.Webhook),
                Hotkeys = deepCopyTable(CONFIG.Hotkeys),
                Persistence = deepCopyTable(CONFIG.Persistence),
            },
            AutoFarmState = deepCopyTable(States.AutoFarm),
            HatchState = deepCopyTable(States.Hatch),
            UpgradeState = deepCopyTable(States.Upgrade),
            IslandState = deepCopyTable(States.Island),
            RewardState = deepCopyTable(States.Reward),
            PlayerState = {
                WalkSpeed = States.Player.WalkSpeed,
                JumpPower = States.Player.JumpPower,
                CustomWalkSpeed = States.Player.CustomWalkSpeed,
                CustomJumpPower = States.Player.CustomJumpPower,
                InfiniteJump = States.Player.InfiniteJump,
                Noclip = States.Player.Noclip,
            },
            OptimizationState = deepCopyTable(States.Optimization),
            MachineState = deepCopyTable(States.Machine),
            EventState = {
                MonitorGlobalEvents = States.Event.MonitorGlobalEvents,
                AutoBalloonInflate = States.Event.AutoBalloonInflate,
                AutoCloudRain = States.Event.AutoCloudRain,
            },
            KaitunState = {
                Enabled = States.Kaitun.Enabled,
                AllowHatch = States.Kaitun.AllowHatch,
                AllowTripleHatch = States.Kaitun.AllowTripleHatch,
                AllowRebirth = States.Kaitun.AllowRebirth,
                AllowSkillTree = States.Kaitun.AllowSkillTree,
                AllowIslandUnlock = States.Kaitun.AllowIslandUnlock,
                AllowAutoCraft = States.Kaitun.AllowAutoCraft,
                SuppressMachineUI = States.Kaitun.SuppressMachineUI,
                AllowChestsAndStars = States.Kaitun.AllowChestsAndStars,
                AllowTrashCleaning = States.Kaitun.AllowTrashCleaning,
                AllowSmartBoosts = States.Kaitun.AllowSmartBoosts,
                CollectShinyStars = States.Kaitun.CollectShinyStars,
                AutoLuckyDucky = States.Kaitun.AutoLuckyDucky,
            },
            Elements = (function()
                local els = {}
                for flag, b in pairs(self.Bindings) do
                    local ok, val = pcall(b.getter)
                    if ok and val ~= nil then
                        els[flag] = val
                    end
                end
                return els
            end)(),
        }
    end

    function ConfigManager:Bind(flag, element, getter, setter)
        if not flag or not element then return element end
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
                        b.element:Set(val)
                    end
                end
            end)
        end
        self._applying = false
    end

    function ConfigManager:ApplySnapshot(snap)
        if type(snap) ~= "table" then return false, "Invalid snapshot" end
        self._applying = true
        pcall(function()
            if snap.CONFIG then applyMergedTable(CONFIG, snap.CONFIG) end
            if snap.AutoFarmState then applyMergedTable(States.AutoFarm, snap.AutoFarmState) end
            if snap.HatchState then applyMergedTable(States.Hatch, snap.HatchState) end
            if snap.UpgradeState then applyMergedTable(States.Upgrade, snap.UpgradeState) end
            if snap.IslandState then applyMergedTable(States.Island, snap.IslandState) end
            if snap.RewardState then applyMergedTable(States.Reward, snap.RewardState) end
            if snap.PlayerState then applyMergedTable(States.Player, snap.PlayerState) end
            if snap.OptimizationState then applyMergedTable(States.Optimization, snap.OptimizationState) end
            if snap.MachineState then applyMergedTable(States.Machine, snap.MachineState) end
            if snap.EventState then applyMergedTable(States.Event, snap.EventState) end
            if snap.KaitunState then applyMergedTable(States.Kaitun, snap.KaitunState) end
            if type(snap.Elements) == "table" then
                for flag, val in pairs(snap.Elements) do
                    local b = self.Bindings[flag]
                    if b and b.setter then
                        pcall(b.setter, val)
                    end
                end
            end
        end)
        self:SyncUI()
        self._applying = false
        if ctx.API.setCpuSaverState then
            pcall(ctx.API.setCpuSaverState, States.Optimization.CpuSaver == true)
        end
        if ctx.API.applyPlayerHumanoidStats then
            pcall(ctx.API.applyPlayerHumanoidStats)
        end
        return true
    end

    function ConfigManager:Save(customPath)
        local path = customPath or (CONFIG.Persistence and CONFIG.Persistence.FileName) or "TapSimHub/config.json"
        local okEnc, jsonStr = pcall(function()
            return HttpService:JSONEncode(self:ExportSnapshot())
        end)
        if not okEnc or type(jsonStr) ~= "string" then
            self.LastError = tostring(jsonStr)
            return false, self.LastError
        end
        local okWrite, writeErr = fsWrite(path, jsonStr)
        if not okWrite then
            self.LastError = tostring(writeErr)
            return false, self.LastError
        end
        self.LastSavedAt = os.time()
        self.LastError = nil
        return true, path
    end

    function ConfigManager:Load(customPath)
        local path = customPath or (CONFIG.Persistence and CONFIG.Persistence.FileName) or "TapSimHub/config.json"
        local okRead, content = fsRead(path)
        if not okRead then
            self.LastError = tostring(content)
            return false, self.LastError
        end
        local okDec, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if not okDec or type(decoded) ~= "table" then
            self.LastError = "Corrupt JSON config: " .. tostring(decoded)
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
        local ok, err = self:ApplySnapshot(deepCopyTable(DEFAULT_PERSISTENT_SNAPSHOT))
        if ctx.API.setCpuSaverState then
            pcall(ctx.API.setCpuSaverState, false)
        end
        return ok, err
    end

    function ConfigManager:MarkDirty()
        if self._applying then return end
        if not (CONFIG.Persistence and CONFIG.Persistence.AutoSave) then return end
        if self._saveScheduled then return end
        self._saveScheduled = true
        task.delay(0.75, function()
            self._saveScheduled = false
            if CONFIG.Persistence and CONFIG.Persistence.AutoSave then
                pcall(function() self:Save() end)
            end
        end)
    end

    ctx.ConfigManager = ConfigManager
    ConfigManagerModule.Instance = ConfigManager
    return ConfigManagerModule
end

return ConfigManagerModule
