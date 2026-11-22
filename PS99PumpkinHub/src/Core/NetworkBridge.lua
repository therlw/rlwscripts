-- src/Core/NetworkBridge.lua
-- Audited Wrapper over PS99 Client Modules, Hashed Network, ClientPlot & Live FFlags
-- Strictly routes calls through official ReplicatedStorage.Library.Client modules.

local NetworkBridge = {}

function NetworkBridge.Init(ctx)
    local RS = ctx.Roblox.ReplicatedStorage
    local Library = RS:WaitForChild("Library", 15)
    local Client = Library:WaitForChild("Client", 15)
    local Types = Library:WaitForChild("Types", 15)
    local Util = Library:WaitForChild("Util", 15)
    local Items = Library:WaitForChild("Items", 15)
    local Balancing = Library:WaitForChild("Balancing", 15)

    local function safeReq(parent, childName)
        local ok, mod = pcall(function()
            local c = parent and parent:FindFirstChild(childName)
            return c and require(c) or nil
        end)
        return ok and mod or nil
    end

    local M = {
        Network = safeReq(Client, "Network"),
        FFlags = safeReq(Client, "FFlags"),
        Save = safeReq(Client, "Save"),
        InstancingCmds = safeReq(Client, "InstancingCmds"),
        MapCmds = safeReq(Client, "MapCmds"),
        CurrencyCmds = safeReq(Client, "CurrencyCmds"),
        CustomEggsCmds = safeReq(Client, "CustomEggsCmds"),
        EggCmds = safeReq(Client, "EggCmds"),
        HatchingCmds = safeReq(Client, "HatchingCmds"),
        BreakableCmds = safeReq(Client, "BreakableCmds"),
        BreakableFrontend = safeReq(Client, "BreakableFrontend"),
        ConsumableCmds = safeReq(Client, "ConsumableCmds"),
        BoostCmds = safeReq(Client, "BoostCmds"),
        EnchantCmds = safeReq(Client, "EnchantCmds"),
        FlyingCmds = safeReq(Client, "FlyingCmds"),
        Gamepasses = safeReq(Client, "Gamepasses"),
        PlayerPet = safeReq(Client, "PlayerPet"),
        InventoryCmds = safeReq(Client, "InventoryCmds"),
        ZoneCmds = safeReq(Client, "ZoneCmds"),
        RebirthCmds = safeReq(Client, "RebirthCmds"),
        RankCmds = safeReq(Client, "RankCmds"),
        QuestCmds = safeReq(Client, "QuestCmds"),
        AutoFarmCmds = safeReq(Client, "AutoFarmCmds"),
        OrbCmds = safeReq(Client, "OrbCmds"),
        UltimateCmds = safeReq(Client, "UltimateCmds"),
        PotionCmds = safeReq(Client, "PotionCmds"),
        FruitCmds = safeReq(Client, "FruitCmds"),
        SprinklerCmds = safeReq(Client, "SprinklerCmds"),
        LootboxCmds = safeReq(Client, "LootboxCmds"),
        SpinnyWheelCmds = safeReq(Client, "SpinnyWheelCmds"),
        UpgradeCmds = safeReq(Client, "UpgradeCmds"),
        EventUpgradeCmds = safeReq(Client, "EventUpgradeCmds"),
        BoostExchangeCmds = safeReq(Client, "BoostExchangeCmds"),
        ForeverPackCmds = safeReq(Client, "ForeverPackCmds"),
        TeleportMapCmds = safeReq(Client, "TeleportMapCmds"),
        EventFishingCmds = safeReq(Client, "EventFishingCmds"),
        FarmHoldCmds = safeReq(Client, "FarmHoldCmds"),
        PlotCmds = safeReq(Client, "PlotCmds"),
        PetCmds = safeReq(Client, "PetCmds"),
        PetEquipCmds = safeReq(Client, "PetEquipCmds"),
        CharmCmds = safeReq(Client, "CharmCmds"),
        SettingsCmds = safeReq(Client, "SettingsCmds"),
        GUIFX = safeReq(Client, "GUIFX"),
        GUI = safeReq(Client, "GUI"),
        TabController = safeReq(Client, "TabController"),
        MachineCmds = safeReq(Client, "MachineCmds"),
        Signal = safeReq(Library, "Signal"),
        Directory = safeReq(Library, "Directory"),
        Types = Types,
        CalcEggPricePlayer = safeReq(Balancing, "CalcEggPricePlayer"),
        Balancing = Balancing,
        BoostTierFamilies = safeReq(Util, "BoostTierFamilies"),
        TapTargetPolicy = safeReq(Util, "TapTargetPolicy"),
        AutoFarmReach = safeReq(Util, "AutoFarmReach"),
        ZonesUtil = safeReq(Util, "ZonesUtil"),
        WorldsUtil = safeReq(Util, "WorldsUtil"),
        EventFishingUtil = safeReq(Util, "EventFishingUtil"),
        MiscItem = safeReq(Items, "MiscItem"),
        ConsumableItem = safeReq(Items, "ConsumableItem"),
        LootboxItem = safeReq(Items, "LootboxItem"),
        PetItem = safeReq(Items, "PetItem"),
        FruitItem = safeReq(Items, "FruitItem"),
        PotionItem = safeReq(Items, "PotionItem"),
        EnchantItem = safeReq(Items, "EnchantItem"),
        CharmItem = safeReq(Items, "CharmItem"),
        CatchItem = safeReq(Items, "CatchItem"),
        WorkerItem = safeReq(Items, "WorkerItem"),
        EggFarmItem = safeReq(Items, "EggFarmItem"),
        CurrencyItem = safeReq(Items, "CurrencyItem"),
        PetUtil = safeReq(Util, "PetUtil"),
        FarmingTypes = safeReq(Types, "Farming"),

        -- Pumpkin Tycoon specific modules
        PT = safeReq(Client, "PumpkinTycoonCmds"),
        PT_Types = safeReq(Types, "PumpkinTycoon"),
    }

    local PTFolder = Client:FindFirstChild("PumpkinTycoonCmds")
    if PTFolder then
        M.Island = safeReq(PTFolder, "Island")
        M.Buttons = safeReq(PTFolder, "Buttons")
        M.Merchant = safeReq(PTFolder, "Merchant")
        M.Stock = safeReq(PTFolder, "Stock")
        M.AutoBreak = safeReq(PTFolder, "AutoBreak")
        M.Lock = safeReq(PTFolder, "Lock")
        M.Upgrades = safeReq(PTFolder, "Upgrades")
        M.Cocoa = safeReq(PTFolder, "Cocoa")
        M.Wild = safeReq(PTFolder, "Wild")
        M.Hunt = safeReq(PTFolder, "Hunt")
        M.Nets = safeReq(PTFolder, "Nets")
        M.Store = safeReq(PTFolder, "Store")
        M.Turkey = safeReq(PTFolder, "Turkey")
        M.Rebirth = safeReq(PTFolder, "Rebirth")
        M.Gift = safeReq(PTFolder, "Gift")
        M.PumpkinFx = safeReq(PTFolder, "PumpkinFx")
    end

    local PTTypesFolder = Types:FindFirstChild("PumpkinTycoon")
    if PTTypesFolder then
        M.PT_Buttons = safeReq(PTTypesFolder, "Buttons")
        M.PT_Upgrades = safeReq(PTTypesFolder, "Upgrades")
        M.PT_Merchant = safeReq(PTTypesFolder, "Merchant")
        M.PT_Wild = safeReq(PTTypesFolder, "Wild")
        M.PT_Ladder = safeReq(PTTypesFolder, "Ladder")
        M.PT_Chase = safeReq(PTTypesFolder, "Chase")
    end

    M.Util_Buttons = safeReq(Util, "PumpkinTycoonButtons")
    M.Util_Upgrades = safeReq(Util, "PumpkinTycoonUpgrades")
    M.Util_Cocoa = safeReq(Util, "PumpkinTycoonCocoa")
    M.Util_Boosts = safeReq(Util, "PumpkinTycoonBoosts")
    M.Util_Wild = safeReq(Util, "PumpkinTycoonWild")
    M.Util_Gift = safeReq(Util, "PumpkinTycoonGift")
    M.Util_Turkey = safeReq(Util, "PumpkinTycoonTurkey")

    local Net = {
        Mod = M,
    }

    function Net.GetFFlag(keyName, fallback)
        if M.FFlags and M.FFlags.Keys and M.FFlags.Keys[keyName] then
            local ok, val = pcall(M.FFlags.Get, M.FFlags.Keys[keyName])
            if ok and val ~= nil then
                return val
            end
        end
        return fallback
    end

    function Net.GetNumberFFlag(keyName, fallback)
        local v = Net.GetFFlag(keyName, fallback)
        if type(v) == "number" and v == v and v < math.huge and v > -math.huge then
            return v
        end
        return fallback
    end

    function Net.IsInPumpkinTycoon()
        local inst = M.InstancingCmds and M.InstancingCmds.Get()
        local id = (M.PT_Types and M.PT_Types.INSTANCE_ID) or "PumpkinTycoon"
        return inst ~= nil and inst.instanceID == id
    end

    function Net.GetPlot()
        if not M.Island or not M.Island.Plot then return nil end
        local ok, plot = pcall(M.Island.Plot)
        if ok and plot and not (plot.IsDestroyed and plot:IsDestroyed()) then
            return plot
        end
        return nil
    end

    function Net.GetPlotModel()
        local plot = Net.GetPlot()
        if not plot or not plot.GetModel then return nil end
        local ok, model = pcall(plot.GetModel, plot)
        return ok and model or nil
    end

    function Net.GetPlotDecor()
        local plot = Net.GetPlot()
        if not plot or not M.Island or not M.Island.Decor then return nil end
        local ok, decor = pcall(M.Island.Decor, plot)
        return ok and decor or nil
    end

    function Net.IsPart2Enabled()
        if M.PT and M.PT.Part2 then
            local ok, res = pcall(M.PT.Part2)
            if ok then return res == true end
        end
        return Net.GetFFlag("PumpkinTycoon_Part2", false) == true
    end

    function Net.OwnPlotPart2()
        if M.PT and M.PT.OwnPlotPart2 then
            local ok, res = pcall(M.PT.OwnPlotPart2)
            if ok then return res == true end
        end
        local model = Net.GetPlotModel()
        return model ~= nil and model:GetAttribute("Part2Built") == true
    end

    function Net.PlotSave(varName)
        local plot = Net.GetPlot()
        if not plot or not plot.Save then return nil end
        local ok, val = pcall(plot.Save, plot, varName)
        return ok and val or nil
    end

    -- All Pumpkin Tycoon plot verbs MUST go via ClientPlot:Invoke -> Plots_Invoke
    function Net.PlotInvoke(verb, ...)
        local plot = Net.GetPlot()
        if not plot then
            return false, "no_plot"
        end
        if type(verb) ~= "string" then
            return false, "invalid_verb"
        end
        local args = { ... }
        local ok, res1, res2, res3 = pcall(function()
            return plot:Invoke(verb, table.unpack(args))
        end)
        if not ok then
            ctx.Utils.debugWarn("PlotInvoke:" .. verb, res1)
            return false, tostring(res1)
        end
        return res1, res2, res3
    end

    function Net.NetworkInvoke(remoteName, ...)
        if not M.Network or not M.Network.Invoke then
            return false, "no_network"
        end
        local args = { ... }
        local ok, res1, res2, res3 = pcall(function()
            return M.Network.Invoke(remoteName, table.unpack(args))
        end)
        if not ok then
            ctx.Utils.debugWarn("NetworkInvoke:" .. tostring(remoteName), res1)
            return false, tostring(res1)
        end
        return res1, res2, res3
    end

    function Net.NetworkFire(remoteName, ...)
        if not M.Network or not M.Network.Fire then return false end
        local args = { ... }
        local ok, err = pcall(function()
            M.Network.Fire(remoteName, table.unpack(args))
        end)
        if not ok then
            ctx.Utils.debugWarn("NetworkFire:" .. tostring(remoteName), err)
        end
        return ok
    end

    function Net.NetworkUnreliableFire(remoteName, ...)
        if not M.Network or not M.Network.UnreliableFire then return false end
        local args = { ... }
        local ok, err = pcall(function()
            M.Network.UnreliableFire(remoteName, table.unpack(args))
        end)
        if not ok then
            ctx.Utils.debugWarn("UnreliableFire:" .. tostring(remoteName), err)
        end
        return ok
    end

    function Net.SignalFire(name, ...)
        if not M.Signal or not M.Signal.Fire then return false end
        local args = { ... }
        local ok, err = pcall(function()
            M.Signal.Fire(name, table.unpack(args))
        end)
        if not ok then
            ctx.Utils.debugWarn("SignalFire:" .. tostring(name), err)
        end
        return ok
    end

    function Net.GetPumpkinCoins()
        if M.CurrencyCmds and M.CurrencyCmds.Get then
            local ok, v = pcall(M.CurrencyCmds.Get, (M.PT_Types and M.PT_Types.COIN) or "PumpkinTycoonCoins")
            if ok and type(v) == "number" then return v end
        end
        return 0
    end

    function Net.GetPumpkinTokens()
        if M.CurrencyCmds and M.CurrencyCmds.Get then
            local ok, v = pcall(M.CurrencyCmds.Get, (M.PT_Types and M.PT_Types.TOKENS) or "PumpkinTokens")
            if ok and type(v) == "number" then return v end
        end
        return 0
    end

    function Net.GetPumpkinRebirths()
        local varKey = (M.PT_Types and M.PT_Types.VAR and M.PT_Types.VAR.Rebirths) or "Rebirths"
        local val = Net.PlotSave(varKey)
        return math.max(0, math.floor(tonumber(val) or 0))
    end

    function Net.GetMiscCount(itemId)
        if not M.MiscItem then return 0 end
        local ok, c = pcall(function()
            return M.MiscItem(itemId):CountExact()
        end)
        return (ok and type(c) == "number") and c or 0
    end

    function Net.GetBestNetName()
        if Net.GetMiscCount("Ultra Pet Net") > 0 then
            return "Ultra Pet Net"
        end
        if Net.GetMiscCount("Pet Net") > 0 then
            return "Pet Net"
        end
        return nil
    end

    --- Picks the pet net matching conservation policy & pet rarity tier.
    function Net.SelectNetForTier(tierName, mode)
        local ultraCount = Net.GetMiscCount("Ultra Pet Net")
        local normalCount = Net.GetMiscCount("Pet Net")
        local tier = tostring(tierName or "")
        local isTitanicPlus = (tier == "Titanic" or tier == "Gargantuan")
        local isHugePlus = isTitanicPlus or (tier == "Huge")
        local pref = tostring(mode or "Ultra Titanic/Garg")

        if pref == "Pet Net Only" then
            return (normalCount > 0) and "Pet Net" or nil
        elseif pref == "Ultra Titanic/Garg" then
            if isTitanicPlus then
                if ultraCount > 0 then return "Ultra Pet Net" end
                if normalCount > 0 then return "Pet Net" end
                return nil
            end
            -- Huge or normal wild pets: strictly save Ultra Pet Nets for Titanic & Gargantuan
            return (normalCount > 0) and "Pet Net" or nil
        elseif pref == "Ultra For Huge+" or pref == "Ultra All Rares" then
            if isHugePlus then
                if ultraCount > 0 then return "Ultra Pet Net" end
                if normalCount > 0 then return "Pet Net" end
                return nil
            end
            return (normalCount > 0) and "Pet Net" or nil
        end

        -- "Best Available"
        return Net.GetBestNetName()
    end

    function Net.GetTurkeyIslandFolder()
        local things = workspace:FindFirstChild("__THINGS")
        local instances = things and things:FindFirstChild("Instances")
        local pt = instances and instances:FindFirstChild((M.PT_Types and M.PT_Types.INSTANCE_ID) or "PumpkinTycoon")
        return pt and pt:FindFirstChild("PumpkinTycoonShared") or nil
    end

    function Net.GetSave()
        if not M.Save or not M.Save.Get then return nil end
        local ok, s = pcall(M.Save.Get)
        return ok and type(s) == "table" and s or nil
    end

    function Net.GetClientPlot(dirId)
        local ClientPlot = nil
        local ptFolder = RS.Library.Client:FindFirstChild("PlotCmds")
        local okReq, mod = pcall(function()
            return ptFolder and ptFolder:FindFirstChild("ClientPlot") and require(ptFolder.ClientPlot)
        end)
        if okReq and type(mod) == "table" then
            ClientPlot = mod
        elseif M.PlotCmds then
            ClientPlot = M.PlotCmds
        end
        if not ClientPlot or not ClientPlot.GetAll then return nil end
        local okAll, list = pcall(ClientPlot.GetAll)
        if not okAll or type(list) ~= "table" then return nil end
        local lp = ctx.Roblox.LocalPlayer
        for _, p in pairs(list) do
            if (not p.IsDestroyed or not p:IsDestroyed()) and p.GetOwner and p:GetOwner() == lp then
                if not dirId or (p.GetDirectory and p:GetDirectory() and p:GetDirectory()._id == dirId) then
                    return p
                end
            end
        end
        return nil
    end

    function Net.GetPumpkinBreakZoneParts()
        local plotModel = Net.GetPlotModel()
        local parts = {}
        local sections = plotModel and plotModel:FindFirstChild("Sections")
        if sections then
            for _, sec in ipairs(sections:GetChildren()) do
                local bz = sec:FindFirstChild("BREAK_ZONES")
                if bz then
                    for _, part in ipairs(bz:GetChildren()) do
                        if part:IsA("BasePart") then
                            table.insert(parts, part)
                        end
                    end
                end
            end
        end
        return parts
    end

    ctx.Net = Net
    return Net
end

return NetworkBridge
