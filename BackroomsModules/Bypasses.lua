-- Bypasses.lua
-- Client-side Bypasses, Hacks, and Suppressions

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Utils = getgenv().BackroomsUtils

-- ==========================
-- 🚀 PET SPEED HACK (INSTANT)
-- ==========================
do
    local PlayerPet = require(ReplicatedStorage.Library.Client.PlayerPet)
    if PlayerPet and type(PlayerPet) == "table" then
        PlayerPet.CalculateSpeedMultiplier = function()
            return 9999
        end
    end
end

-- ==========================
-- 🔄 ANTI-PET DISAPPEAR (RESPAWN FIX)
-- ==========================
LocalPlayer.CharacterAdded:Connect(function()
    task.spawn(function()
        task.wait(3.5) -- Wait for character to load fully
        local SaveModule = ReplicatedStorage.Library.Client.Save
        local Network = ReplicatedStorage:WaitForChild("Network", 10)
        if not Network then return end
        
        local saveFile = require(SaveModule).Get()
        if not saveFile or not saveFile.Inventory or not saveFile.Inventory.Pet then return end
        
        local equippedUIDs = {}
        for uid, data in pairs(saveFile.Inventory.Pet) do
            if data._e then
                table.insert(equippedUIDs, uid)
            end
        end
        
        if #equippedUIDs > 0 then
            local unequipAll = Network:FindFirstChild("Pets_UnequipAll")
            if unequipAll then 
                if unequipAll:IsA("RemoteEvent") then unequipAll:FireServer() else unequipAll:InvokeServer() end 
            end
            
            task.wait(1)
            
            local equip = Network:FindFirstChild("Pets_Equip")
            if equip then
                for _, uid in ipairs(equippedUIDs) do
                    if equip:IsA("RemoteEvent") then equip:FireServer(uid, true) else equip:InvokeServer(uid, true) end
                    task.wait(0.01)
                end
            end
            
            if getgenv().RLW_Window then
                getgenv().RLW_Window:Notify({Title = "🐾 Pets Restored!", Content = "Respawn detected. All pets have been re-equipped!", Duration = 3})
            end
        else
            local equipBest = Network:FindFirstChild("Pets_EquipBest")
            if equipBest then
                if equipBest:IsA("RemoteEvent") then equipBest:FireServer() else equipBest:InvokeServer() end
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "🐾 Pets Restored!", Content = "Respawn detected. Best pets equipped!", Duration = 3})
                end
            end
        end
    end)
end)

-- ==========================
-- 🛡️ GELİŞMİŞ ANTİ-AFK SİSTEMİ
-- ==========================
do
    local VirtualUser = game:GetService("VirtualUser")

    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local scriptsFolder = playerScripts and playerScripts:WaitForChild("Scripts", 5)
    local coreScripts = scriptsFolder and scriptsFolder:WaitForChild("Core", 5)
    if coreScripts and coreScripts:FindFirstChild("Idle Tracking") then
        coreScripts["Idle Tracking"].Enabled = false
    end

    task.spawn(function()
        while task.wait(30) do
            local Network = ReplicatedStorage:FindFirstChild("Network")
            if Network then
                local remote = Network:FindFirstChild("Idle Tracking: Stop Timer")
                if remote then
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer()
                    else
                        remote:FireServer()
                    end
                end
            end
        end
    end)

    LocalPlayer.Idled:Connect(function() 
        VirtualUser:CaptureController() 
        VirtualUser:ClickButton2(Vector2.new()) 
    end)
end

-- ==========================
-- 🚫 EKRAN BİLDİRİMLERİNİ GİZLEME
-- ==========================
do
    local Message = require(ReplicatedStorage.Library.Client.Message)
    Message.Error = function() end
    local oldNew = Message.New
    Message.New = function(msg, ...)
        if msg and type(msg) == "string" then
            local lowerMsg = msg:lower()
            if lowerMsg:find("mini%-boss") or lowerMsg:find("boss defeated") or lowerMsg:find("gamemaster") then
                return
            end
        end
        return oldNew(msg, ...)
    end
end

-- ==========================
-- 👻 NOCLIP SİSTEMİ
-- ==========================
task.spawn(function()
    RunService.Stepped:Connect(function()
        if getgenv().Config and getgenv().Config.MetaFarmActive then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end)

return true
