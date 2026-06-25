-- EggHatcher.lua
-- Auto Hatch Nearest Egg Logic and Egg Room Farming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Utils = getgenv().BackroomsUtils

local EggHatcher = {}

local function disableAnimation()
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local scripts = playerScripts and playerScripts:FindFirstChild("Scripts")
    local gameFolder = scripts and scripts:FindFirstChild("Game")
    local frontend = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
    if frontend and getsenv then
        pcall(function()
            local fe = getsenv(frontend)
            if fe and fe.PlayEggAnimation then
                fe.PlayEggAnimation = function() end
            end
        end)
    end
end

function EggHatcher.hatchRoom(bestRoom, roomUID, lowerID, bestRoomType)
    local ClientNetwork = require(ReplicatedStorage.Library.Client.Network)
    local CustomEggsCmds = require(ReplicatedStorage.Library.Client.CustomEggsCmds)
    
    local maxHatch = 1
    maxHatch = require(ReplicatedStorage.Library.Client.EggCmds).GetMaxHatch() or 1
    
    local BackroomsEggMap = {
        ["nightmare"] = "Backrooms Nightmare Egg",
        ["smile"] = "Backrooms Smile Egg",
        ["flower"] = "Backrooms Flower Egg",
        ["gooey"] = "Backrooms Gooey Egg",
        ["scribble"] = "Backrooms Scribble Egg",
        ["tentacle"] = "Backrooms Tentacles Egg",
        ["keepout"] = "Backrooms Keep Out Egg",
        ["nightterror"] = "Backrooms Night Terror Egg",
        ["fear"] = "Backrooms Fear Egg",
        ["swirl"] = "Backrooms Swirl Egg",
        ["overgrown"] = "Backrooms Overgrown Egg",
        ["ender"] = "Backrooms Ender Egg",
        ["corrupt"] = "Backrooms Corrupt Egg",
        ["heart"] = "Backrooms Heart Egg",
        ["balloon"] = "Backrooms Balloon Egg",
        ["rain"] = "Backrooms Rain Egg",
        ["eyes"] = "Backrooms Eyes Egg",
        ["danger"] = "Backrooms Danger Egg",
        ["titanic"] = "Titanic Backrooms Egg",
        ["huge"] = "Huge Backrooms Egg"
    }

    disableAnimation()

    -- Look up eggUID from the room's attributes
    local eggUID = bestRoom:GetAttribute("EggUID")
    local eggObj = nil
    
    -- Wait up to 3 seconds for the custom egg model to load/stream in
    local eggModel = nil
    local customEggs = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("CustomEggs")
    if eggUID then
        local t = 0
        while t < 3 do
            eggModel = customEggs and customEggs:FindFirstChild(eggUID)
            if eggModel then break end
            task.wait(0.25)
            t = t + 0.25
        end
    end

    if eggUID and CustomEggsCmds then
        eggObj = CustomEggsCmds.Get(eggUID)
    end

    -- Fallback to scanning CustomEggsCmds.All() for any egg in this room
    if not eggObj and CustomEggsCmds then
        local roomPos = bestRoom:GetPivot().Position
        for uid, obj in pairs(CustomEggsCmds.All()) do
            if obj._position and (obj._position - roomPos).Magnitude < 120 then
                eggObj = obj
                eggUID = uid
                eggModel = obj._model or eggModel
                break
            end
        end
    end

    local customUid = eggObj and eggObj._uid or eggUID
    eggModel = eggObj and eggObj._model or eggModel

    -- Resolve eggIdToBuy using loaded egg object ID if available
    local eggIdToBuy = eggObj and eggObj._id
    if not eggIdToBuy then
        local multiplier = bestRoom:GetAttribute("EggMultiplier")
        for key, eggName in pairs(BackroomsEggMap) do
            if lowerID:find(key) then
                if key == "titanic" or key == "huge" then
                    eggIdToBuy = eggName
                else
                    if multiplier then
                        eggIdToBuy = eggName .. " " .. tostring(multiplier) .. "x"
                    else
                        local matchMult = lowerID:match("(%d+)x")
                        if matchMult then
                            eggIdToBuy = eggName .. " " .. matchMult .. "x"
                        else
                            eggIdToBuy = eggName .. " 1x"
                        end
                    end
                end
                break
            end
        end
    end
    
    -- Second fallback using EggType or EggName attributes
    if not eggIdToBuy then
        local eggAttr = bestRoom:GetAttribute("EggType") or bestRoom:GetAttribute("EggName") or bestRoom:GetAttribute("Egg")
        if eggAttr then
            local eggName = tostring(eggAttr)
            local multiplier = bestRoom:GetAttribute("EggMultiplier")
            if multiplier then
                eggIdToBuy = eggName .. " " .. tostring(multiplier) .. "x"
            else
                eggIdToBuy = eggName .. " 1x"
            end
        end
    end

    if not eggIdToBuy then
        eggIdToBuy = "Backrooms Nightmare Egg 1x"
    end

    local hasTeleportedToEgg = false
    while getgenv().Config.AutoFarmEggs do
        -- Check if the egg is still alive. If not, exit the loop!
        if not Utils.isEggAlive(bestRoom) then
            if getgenv().RLW_Window then
                getgenv().RLW_Window:Notify({Title = "💀 Egg Finished", Content = "Egg room completed. Finding next room...", Duration = 3})
            end
            break
        end

        local timeNow = workspace:GetServerTimeNow()
        
        if bestRoomType == 4 and getgenv().Config.AutoBossHunt then
            local bossTimer = getgenv().SmartFarmState.BossRespawningUntil or 0
            local remaining = bossTimer - timeNow
            
            local mult = tonumber(bestRoom:GetAttribute("EggMultiplier")) or 0
            local isPriorityEgg = mult >= getgenv().Config.TargetEggMultiplier
            
            if bossTimer > 0 and remaining > 0 and remaining <= 8 and not isPriorityEgg then
                if getgenv().RLW_Window then
                    getgenv().RLW_Window:Notify({Title = "⏰ Boss Time!", Content = "Returning to Boss Arena...", Duration = 3})
                end
                break
            end
        end

        if customUid and ClientNetwork then
            if not hasTeleportedToEgg and eggModel then
                Utils.getRootPart().CFrame = eggModel:GetPivot() + Vector3.new(0, 5, 0)
                hasTeleportedToEgg = true
                task.wait(0.25)
            end

            task.spawn(function()
                ClientNetwork.Invoke("CustomEggs_Hatch", customUid, maxHatch)
            end)
        elseif eggIdToBuy and ClientNetwork then
            task.spawn(function()
                ClientNetwork.Invoke("Eggs_RequestPurchase", eggIdToBuy, maxHatch)
            end)
        else
            -- Egg not loaded yet, wait and try to resolve again
            task.wait(0.5)
            if eggUID and CustomEggsCmds then
                eggObj = CustomEggsCmds.Get(eggUID)
                if eggObj then
                    customUid = eggObj._uid
                    eggModel = eggObj._model
                    eggIdToBuy = eggObj._id or eggIdToBuy
                end
            end
            continue
        end
        task.wait(1.5)
    end
end

task.spawn(function()
    local ClientNetwork = require(ReplicatedStorage.Library.Client.Network)
    local CustomEggsCmds = require(ReplicatedStorage.Library.Client.CustomEggsCmds)

    while task.wait(1) do
        if getgenv().Config.AutoHatchNearest and ClientNetwork and CustomEggsCmds then
            local root = Utils.getRootPart()
            if not root then continue end
            
            local customUid = nil
            local closestDist = 99999
            
            for uid, eggObj in pairs(CustomEggsCmds.All()) do
                if eggObj._position then
                    local dist = (root.Position - eggObj._position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        customUid = uid
                    end
                end
            end
            
            if customUid then
                -- Disable egg opening animation safely
                disableAnimation()

                local maxHatch = 1
                maxHatch = require(ReplicatedStorage.Library.Client.EggCmds).GetMaxHatch() or 1
                
                task.spawn(function()
                    ClientNetwork.Invoke("CustomEggs_Hatch", customUid, maxHatch)
                end)
            end
        end
    end
end)

getgenv().BackroomsEggHatcher = EggHatcher
return EggHatcher