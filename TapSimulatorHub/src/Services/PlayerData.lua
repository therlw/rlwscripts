-- src/Services/PlayerData.lua
-- Player Replica Access, Currencies, Rebirths, Pet Storage, Hatch Speed & Equip Best Helpers

local PlayerData = {}

function PlayerData.Init(ctx)
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local Svc = ctx.Services
    local ReplicatedStorage = ctx.Roblox.ReplicatedStorage
    local safeFire = ctx.Utils.safeFire

    local requireSafe = ctx.Utils and ctx.Utils.requireSafe

    local function getBoostFormula()
        if Mod.BoostFormula then return Mod.BoostFormula end
        if requireSafe then
            Mod.BoostFormula = requireSafe(function() return ReplicatedStorage.Shared.Items.BoostFormula end)
        else
            local ok, m = pcall(function() return require(ReplicatedStorage.Shared.Items.BoostFormula) end)
            if ok then Mod.BoostFormula = m end
        end
        return Mod.BoostFormula
    end

    local function getGlobalEventState()
        if Mod.GlobalEventState then return Mod.GlobalEventState end
        if requireSafe then
            Mod.GlobalEventState = requireSafe(function() return ReplicatedStorage.Shared.Admin.GlobalEventState end)
        else
            local ok, m = pcall(function() return require(ReplicatedStorage.Shared.Admin.GlobalEventState) end)
            if ok then Mod.GlobalEventState = m end
        end
        return Mod.GlobalEventState
    end

    local function getPlayerData()
        if Mod.DataController and Mod.DataController.GetReplica then
            local ok, replica = pcall(function() return Mod.DataController:GetReplica() end)
            if ok and replica and replica.Data then
                return replica.Data
            end
        end
        return nil
    end

    local function getCoinsForWorld(targetWorld)
        local data = getPlayerData()
        if not data then return 0 end
        local world = targetWorld or (data.Progression and data.Progression.World)
        if world == "TimeRift" and data.Currencies and data.Currencies.RiftCoins then
            return data.Currencies.RiftCoins
        end
        if world == "TimeRift" then
            return 0
        end
        if data.Currencies then
            return data.Currencies.Coins or 0
        end
        return 0
    end

    local function getCoins()
        return getCoinsForWorld(nil)
    end

    local function getCoinsForEgg(eggName)
        local eggInfo = eggName and Mod.LaunchEggConfig and Mod.LaunchEggConfig[eggName]
        local targetWorld = (eggInfo and eggInfo.World) or nil
        return getCoinsForWorld(targetWorld)
    end

    local function getGems()
        local data = getPlayerData()
        if not data then return 0 end
        local curWorld = data.Progression and data.Progression.World
        if curWorld == "TimeRift" and data.Currencies and data.Currencies.RiftGems then
            return data.Currencies.RiftGems
        end
        if data.Currencies then
            return data.Currencies.Gems or 0
        end
        return 0
    end

    local function getRebirthCount()
        local data = getPlayerData()
        if not data then return 0 end
        local curWorld = data.Progression and data.Progression.World
        if curWorld == "TimeRift" and data.Statistics and data.Statistics.RiftRebirths then
            return data.Statistics.RiftRebirths
        end
        if data.Statistics then
            return data.Statistics.Rebirths or 0
        end
        return 0
    end

    local function getPetStorageInfo()
        local data = getPlayerData()
        if not (data and data.Pets) then
            return 0, 150, 150
        end
        local owned = data.Pets.Owned or {}
        local ownedCount = 0
        if type(owned) == "table" then
            for _ in pairs(owned) do
                ownedCount = ownedCount + 1
            end
        end
        local maxStorage = data.Pets.StorageLimit or 150
        local freeSlots = math.max(0, maxStorage - ownedCount)
        return ownedCount, maxStorage, freeSlots
    end

    local function hasX8Gamepass()
        local data = getPlayerData()
        if data and data.Monetization and data.Monetization.Gamepasses then
            if data.Monetization.Gamepasses.x8Egg == true then
                return true
            end
        end
        local ok, perks = pcall(function() return require(ReplicatedStorage.Shared.Monetization.GamepassPerks) end)
        if ok and perks then
            if perks.Has then
                local okHas, has = pcall(function() return perks.Has(data, "x8Egg") end)
                if okHas and has then return true end
            end
            if perks.Owns then
                local okOwns, owns = pcall(function() return perks.Owns(data, "x8Egg") end)
                if okOwns and owns then return true end
            end
        end
        return false
    end

    local function canUseX8Hatch()
        if hasX8Gamepass() then return true end
        local data = getPlayerData()
        local bf = getBoostFormula()
        if bf and bf.HasType and data then
            local ok, hasBoost = pcall(bf.HasType, data, "OctoHatch")
            if ok and hasBoost == true then return true end
        end
        local ge = getGlobalEventState()
        if ge and ge.IsActive then
            local ok, active = pcall(ge.IsActive, "OctoHatch")
            if ok and active == true then return true end
        end
        return false
    end

    local function getLiveHatchSpeed()
        local data = getPlayerData()
        if Mod.ProfileStats and data then
            local ok, sp = pcall(function()
                return Mod.ProfileStats.HatchSpeed(data)
            end)
            if ok and type(sp) == "number" and sp > 0 then
                return sp
            end
        end

        if data then
            local mult = 1.0
            if data.SkillTree and type(data.SkillTree.Unlocked) == "table" then
                for i = 1, 10 do
                    if data.SkillTree.Unlocked["Hatch Speed " .. i] then
                        mult = mult + 0.1
                    end
                end
            end
            if data.Upgrades and type(data.Upgrades.HatchSpeed) == "number" then
                mult = mult + (data.Upgrades.HatchSpeed * 0.1)
            end
            return mult
        end
        return 1.0
    end

    local function getAutoHatchDelay()
        local speed = getLiveHatchSpeed()
        local delay = (CONFIG.HatchCooldown / speed) + CONFIG.HatchJitterCushion
        return math.max(0.15, math.floor(delay * 100) / 100), speed
    end

    local function equipBestPets()
        return safeFire(Svc.PetRemoteService, "RE", "PetActionRequested", { Action = "EquipBest", Mode = "Clicks" })
    end

    local A = ctx.API
    A.getPlayerData = getPlayerData
    A.getCoins = getCoins
    A.getCoinsForWorld = getCoinsForWorld
    A.getCoinsForEgg = getCoinsForEgg
    A.getGems = getGems
    A.getRebirthCount = getRebirthCount
    A.getPetStorageInfo = getPetStorageInfo
    A.hasX8Gamepass = hasX8Gamepass
    A.canUseX8Hatch = canUseX8Hatch
    A.getLiveHatchSpeed = getLiveHatchSpeed
    A.getAutoHatchDelay = getAutoHatchDelay
    A.equipBestPets = equipBestPets

    PlayerData.GetData = getPlayerData
    PlayerData.GetCoins = getCoins
    PlayerData.GetCoinsForWorld = getCoinsForWorld
    PlayerData.GetCoinsForEgg = getCoinsForEgg
    PlayerData.GetGems = getGems
    PlayerData.GetRebirthCount = getRebirthCount
    PlayerData.GetPetStorageInfo = getPetStorageInfo
    PlayerData.HasX8Gamepass = hasX8Gamepass
    PlayerData.CanUseX8Hatch = canUseX8Hatch
    PlayerData.GetLiveHatchSpeed = getLiveHatchSpeed
    PlayerData.GetAutoHatchDelay = getAutoHatchDelay
    PlayerData.EquipBestPets = equipBestPets

    return PlayerData
end

return PlayerData
