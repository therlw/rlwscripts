-- BreakableFarmer.lua
-- Smart Farm: Fast Breakables & Pet Assignment

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Utils = getgenv().BackroomsUtils

task.spawn(function()
    local Network = ReplicatedStorage:WaitForChild("Network", 10)
    if not Network then return end
    local lastPetAssign = 0
    
    local function GetPlayerPets()
        local pets = {}
        do
            local PlayerPet = require(ReplicatedStorage.Library.Client.PlayerPet)
            for _, petData in pairs(PlayerPet.GetAll()) do
                if petData.owner == LocalPlayer then table.insert(pets, petData) end
            end
        end
        return pets
    end

    while task.wait(getgenv().SmartFarmState.AutoTapInterval or 0.08) do
        if not getgenv().SmartFarmState.Running then continue end
        if not (getgenv().Config.AutoFarmCoins or getgenv().Config.MetaFarmActive or getgenv().Config.AutoBossHunt or getgenv().Config.AutoFarmChests or getgenv().Config.AutoFarmEvents or getgenv().Config.AutoFarmEggs) then continue end
        
        local root = Utils.getRootPart()
        if not root then continue end
        local charPos = root.Position
        
        local things = workspace:FindFirstChild("__THINGS")
        local breakables = things and things:FindFirstChild("Breakables")
        if not breakables then continue end
        
        local targets = {}
        for _, b in ipairs(breakables:GetChildren()) do
            local part = b:FindFirstChild("Hitbox") or (b:IsA("Model") and b.PrimaryPart) or b:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (part.Position - charPos).Magnitude
                if dist <= (getgenv().SmartFarmState.FarmRange or 150) then
                    table.insert(targets, {uid = b.Name, dist = dist, obj = b})
                end
            end
        end
        
        table.sort(targets, function(a, b) return a.dist < b.dist end)
        
        local maxT = getgenv().SmartFarmState.MaxTargetsPerTick or 8
        local now = tick()
        local shouldAssignPet = (now - lastPetAssign) >= (getgenv().SmartFarmState.PetAssignInterval or 0.5)
        if shouldAssignPet then lastPetAssign = now end
        
        local validTargets = {}

        for i = 1, math.min(maxT, #targets) do
            local uid = targets[i].uid
            
            if targets[i].dist <= (getgenv().SmartFarmState.ClickAuraRange or 150) then
                do
                    local ClientNetwork = require(ReplicatedStorage.Library.Client.Network)
                    ClientNetwork.UnreliableFire("Breakables_PlayerDealDamage", uid)
                end
            end
            
            if shouldAssignPet then
                table.insert(validTargets, uid)
            end
        end

        if shouldAssignPet and #validTargets > 0 then
            local pets = GetPlayerPets()
            if #pets > 0 then
                local mapping = {}
                local petsPerBreakable = math.floor(#pets / #validTargets)
                local remainder = #pets % #validTargets
                local petIndex = 1
                
                for i, uid in ipairs(validTargets) do
                    local count = petsPerBreakable + (i <= remainder and 1 or 0)
                    for j = 1, count do
                        if petIndex > #pets then break end
                        mapping[pets[petIndex].euid] = uid
                        petIndex = petIndex + 1
                    end
                end
                
                if next(mapping) then
                    do
                        local bulkJoin = Network:FindFirstChild("Breakables_JoinPetBulk")
                        if bulkJoin then bulkJoin:FireServer(mapping) end
                    end
                end
            end
        end
    end
end)

return true
