-- src/Systems/Automation/PlayerMovement.lua
-- SprintController-Safe WalkSpeed/JumpPower, Infinite Jump, Noclip & Anti-Void Safeguard

local PlayerMovement = {}

function PlayerMovement.Init(ctx)
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local PlayerState = ctx.States.Player
    local DEFAULT_WALKSPEED = ctx.DefaultWalkSpeed
    local DEFAULT_JUMPPOWER = ctx.DefaultJumpPower

    local function applyPlayerHumanoidStats()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if PlayerState.CustomWalkSpeed then
                hum.WalkSpeed = PlayerState.WalkSpeed
            else
                hum.WalkSpeed = DEFAULT_WALKSPEED
            end
            if PlayerState.CustomJumpPower then
                hum.UseJumpPower = true
                hum.JumpPower = PlayerState.JumpPower
            else
                hum.UseJumpPower = true
                hum.JumpPower = DEFAULT_JUMPPOWER
            end
        end
    end

    ctx.API.applyPlayerHumanoidStats = applyPlayerHumanoidStats
    PlayerMovement.applyPlayerHumanoidStats = applyPlayerHumanoidStats
    return PlayerMovement
end

function PlayerMovement.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local trackConnection = ctx.Lifecycle.TrackConnection
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local RunService = ctx.Roblox.RunService
    local UserInputService = ctx.Roblox.UserInputService
    local Mod = ctx.Modules
    local PlayerState = ctx.States.Player
    local OptimizationState = ctx.States.Optimization
    local debugWarn = ctx.Utils.debugWarn
    local getPlayerData = ctx.API.getPlayerData
    local restoreCulledArea = ctx.API.restoreCulledArea

    local function enforcePhysicsAndStats(doNoclip)
        if not isCurrentGeneration() then return end
        local wantSpeed = PlayerState.CustomWalkSpeed
        local wantJump = PlayerState.CustomJumpPower
        if not PlayerState.Noclip and not wantSpeed and not wantJump then
            return
        end

        local char = LocalPlayer.Character
        if not char then return end

        if doNoclip and PlayerState.Noclip then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if wantSpeed and hum.WalkSpeed ~= PlayerState.WalkSpeed then
                hum.WalkSpeed = PlayerState.WalkSpeed
            end
            if wantJump and hum.JumpPower ~= PlayerState.JumpPower then
                hum.UseJumpPower = true
                hum.JumpPower = PlayerState.JumpPower
            end
        end
    end

    -- 8. Movement & Physics Workers
    trackConnection(UserInputService.JumpRequest:Connect(function()
        if not isCurrentGeneration() then return end
        if PlayerState.InfiniteJump then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    trackConnection(LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not isCurrentGeneration() then return end
        task.defer(function()
            local hum = newChar:WaitForChild("Humanoid", 5)
            if hum then
                PlayerMovement.applyPlayerHumanoidStats()
            end
        end)
    end))

    -- 8b. Emergency Anti-Void Fall Catcher & World Safeguard
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            task.wait(0.2)
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local pos = hrp.Position
                    local data = getPlayerData()
                    local curWorld = data and data.Progression and data.Progression.World or "Main"

                    if curWorld == "TimeRift" or pos.Z > 3000 then
                        if OptimizationState and OptimizationState.CpuSaver and restoreCulledArea then
                            local w2 = workspace:FindFirstChild("World2")
                            if not w2 or not w2:FindFirstChild("World 2 Spawn") then
                                restoreCulledArea("World2")
                                restoreCulledArea("World 2 Spawn")
                                restoreCulledArea("Medieval Island")
                            end
                        end

                        if pos.Y < 430 then
                            if restoreCulledArea then
                                restoreCulledArea("World2")
                                restoreCulledArea("World 2 Spawn")
                                restoreCulledArea("Prehistoric Island")
                                restoreCulledArea("Ice Age")
                                restoreCulledArea("Medieval Island")
                            end

                            hrp.AssemblyLinearVelocity = Vector3.zero
                            if pos.X > 2000 then
                                hrp.CFrame = CFrame.new(2544.0, 1942.0, 7050.0)
                            else
                                hrp.CFrame = CFrame.new(-3.0, 498.0, 7009.0)
                            end
                            debugWarn("AntiVoid", "Caught void fall in World 2! Restored World 2 and placed character safely.")
                        end
                    elseif curWorld == "Main" then
                        if pos.Y < -550 then
                            if restoreCulledArea then
                                restoreCulledArea("Map1")
                                restoreCulledArea("Spawn")
                                restoreCulledArea("Ts2Islands")
                            end

                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.CFrame = CFrame.new(-54.0, -373.0, -1536.0)
                            debugWarn("AntiVoid", "Caught void fall in World 1! Restored World 1 and safely placed character on Spawn floor.")
                        end
                    end
                end
            end)
        end
    end)

    -- Proactive World Switch Listener via Replica
    if Mod.DataController and Mod.DataController.GetReplica then
        pcall(function()
            local rep = Mod.DataController:GetReplica()
            if rep and rep.ListenToChange and restoreCulledArea then
                trackConnection(rep:ListenToChange({ "Progression", "World" }, function(newWorld)
                    if not isCurrentGeneration() then return end
                    if newWorld == "TimeRift" then
                        restoreCulledArea("World2")
                        restoreCulledArea("World 2 Spawn")
                        restoreCulledArea("Medieval Island")
                    else
                        restoreCulledArea("Map1")
                        restoreCulledArea("Spawn")
                        restoreCulledArea("Ts2Islands")
                    end
                end))
            end
        end)
    end

    trackConnection(RunService.Stepped:Connect(function()
        enforcePhysicsAndStats(true)
    end))
    trackConnection(RunService.RenderStepped:Connect(function()
        enforcePhysicsAndStats(false)
    end))

    pcall(PlayerMovement.applyPlayerHumanoidStats)
end

return PlayerMovement
