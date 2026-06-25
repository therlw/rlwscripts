-- Solvers.lua
-- Puzzle Room Solvers

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = getgenv().BackroomsShared

local Solvers = {}

function Solvers.solve(bestRoom, roomUID)
    local Network = ReplicatedStorage:FindFirstChild("Network")
    local invokeCustom = Network and Network:FindFirstChild("Instancing_InvokeCustomFromClient")
    local fireCustom = Network and Network:FindFirstChild("Instancing_FireCustomFromClient")
    
    if not (invokeCustom and fireCustom) then return end
    local roomName = string.lower(bestRoom:GetAttribute("RoomID") or "")
    
    if roomName:find("chalkboardkeypad") then
        local problem = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetProblem")
        if problem and type(problem) == "string" then
            local num1, op, num2 = string.match(problem, "(%d+)%s*([%+%-%*%/])%s*(%d+)")
            if num1 and op and num2 then
                num1 = tonumber(num1)
                num2 = tonumber(num2)
                local ans = 0
                if op == "+" then ans = num1 + num2
                elseif op == "-" then ans = num1 - num2
                elseif op == "*" then ans = num1 * num2
                elseif op == "/" then ans = num1 / num2 end
                invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "SubmitAnswer", tostring(ans))
            end
        end
    elseif roomName:find("code") then
        local code = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetCode")
        if code then
            fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "Code", code)
        end
    elseif roomName:find("simonfloor") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetSequence")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "StepTile", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("deeplaserpattern") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetSolutionOrder")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("buttons") or roomName:find("colorbutton") then
        local seq = invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "GetCurrentOrder")
        if seq and type(seq) == "table" then
            for _, step in ipairs(seq) do
                fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "ButtonPressed", step)
                task.wait(0.1)
            end
        end
    elseif roomName:find("keyforge") then
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ForgeKey")
    elseif roomName:find("chestchoose") then
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "RedeemChooseChest", 1)
    elseif roomName:find("vending") then
        fireCustom:FireServer("Backrooms", "AbstractRoom_FireServer", roomUID, "UseVending")
    end
    
    task.wait(0.5)
    local rewards = {}
    for _, v in ipairs(bestRoom:GetDescendants()) do
        if v.Name == "RandomReward" and v:IsA("Model") then
            table.insert(rewards, v)
        end
    end
    for _, rw in ipairs(rewards) do
        invokeCustom:InvokeServer("Backrooms", "AbstractRoom_InvokeServer", roomUID, "ClaimRandomReward", rw)
    end
    
    Shared.VisitedRooms[roomUID] = true
    task.wait(1)
end

getgenv().BackroomsSolvers = Solvers
return Solvers
