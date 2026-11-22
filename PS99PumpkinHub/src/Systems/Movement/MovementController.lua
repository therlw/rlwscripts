-- src/Systems/Movement/MovementController.lua
-- Dual Movement Engine ("Teleport" & "Legit Walk") + Turkey Island Cannon Crossing

local MovementController = {}

function MovementController.Init(ctx)
    local PathfindingService = ctx.Roblox.PathfindingService
    local Utils = ctx.Utils
    local Net = ctx.Net
    local States = ctx.States

    local Move = {
        _walking = false,
        _walkId = 0,
    }

    function Move.GetMode()
        return States.Movement.Mode or "Teleport"
    end

    function Move.IsOnTurkeyIsland()
        local _, hrp = Utils.getCharacterParts()
        if not hrp then return false end
        local shared = Net.GetTurkeyIslandFolder()
        if not shared then return false end
        local pos = Utils.getInstancePos(shared)
        return pos ~= nil and Utils.flatDist(hrp.Position, pos) < 420
    end

    function Move.TeleportTo(targetPos, yOffset)
        local char, hrp = Utils.getCharacterParts()
        if not char or not hrp or not targetPos then
            return false
        end
        local offset = yOffset or 3.2
        local dest = CFrame.new(targetPos + Vector3.new(0, offset, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        char:PivotTo(dest)
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    function Move.WalkTo(targetPos, arrivalRadius, abortCheckFn)
        local char, hrp, hum = Utils.getCharacterParts()
        if not char or not hrp or not hum or not targetPos then
            return false
        end

        local reqDist = arrivalRadius or 5
        if Utils.flatDist(hrp.Position, targetPos) <= reqDist then
            return true
        end

        Move._walkId = Move._walkId + 1
        local myWalkId = Move._walkId
        Move._walking = true

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { char }
        rayParams.IgnoreWater = true
        rayParams.RespectCanCollide = true

        local lastJumpAt = 0

        local function shouldStop()
            if not ctx.Lifecycle.IsCurrentGeneration() then return true end
            if Move._walkId ~= myWalkId then return true end
            if Move.GetMode() ~= "Legit Walk" then return true end
            if abortCheckFn and abortCheckFn() then return true end
            local _, curHrp, curHum = Utils.getCharacterParts()
            if not curHrp or not curHum or curHum.Health <= 0 then return true end
            return false
        end

        local function tryJump(curHum)
            if not curHum then return end
            local now = os.clock()
            if now - lastJumpAt >= 0.28 and curHum:GetState() ~= Enum.HumanoidStateType.Freefall then
                curHum.Jump = true
                lastJumpAt = now
            end
        end

        -- Checks forward solid vertical obstacles (`RespectCanCollide = true`):
        -- ignores walkable ramps/slopes (Normal.Y >= 0.58) so the character only jumps ledges/steps/walls.
        local function probeAhead(curHrp, curHum, moveDest)
            local flatVec = Vector3.new(moveDest.X - curHrp.Position.X, 0, moveDest.Z - curHrp.Position.Z)
            if flatVec.Magnitude < 0.5 then
                return false, false, nil
            end
            local unit = flatVec.Unit
            local reach = 4.4
            local rootToFloor = (curHum.HipHeight or 2) + (curHrp.Size.Y * 0.5)
            local groundY = curHrp.Position.Y - rootToFloor
            local shinOrigin = Vector3.new(curHrp.Position.X, groundY + 0.9, curHrp.Position.Z)
            local waistOrigin = Vector3.new(curHrp.Position.X, groundY + 2.7, curHrp.Position.Z)
            local headOrigin = Vector3.new(curHrp.Position.X, groundY + 6.0, curHrp.Position.Z)

            local function isSteepObstacle(hit)
                return hit ~= nil and math.abs(hit.Normal.Y) < 0.58
            end

            local shinHit = workspace:Raycast(shinOrigin, unit * reach, rayParams)
            local waistHit = workspace:Raycast(waistOrigin, unit * reach, rayParams)
            if not isSteepObstacle(shinHit) and not isSteepObstacle(waistHit) then
                return false, false, unit
            end

            local headHit = workspace:Raycast(headOrigin, unit * reach, rayParams)
            if not headHit then
                return true, false, unit
            end
            return false, true, unit
        end

        local function driveSegment(segDest, arrivalThresh, maxSegSec, jumpAtStart)
            local _, curHrp, curHum = Utils.getCharacterParts()
            if not curHrp or not curHum then return false, false end

            if jumpAtStart then
                tryJump(curHum)
            end
            curHum:MoveTo(segDest)

            local started = os.clock()
            local lastSampleAt = started
            local lastSamplePos = curHrp.Position
            local sidestepSide = 1
            local consecutiveStucks = 0

            while os.clock() - started < maxSegSec do
                if shouldStop() then return false, true end

                _, curHrp, curHum = Utils.getCharacterParts()
                if not curHrp or not curHum then return false, true end

                if Utils.flatDist(curHrp.Position, targetPos) <= reqDist then
                    return true, false
                end
                if arrivalThresh and Utils.flatDist(curHrp.Position, segDest) <= arrivalThresh then
                    return false, false
                end

                local jumpAhead, tallBlocked, unit = probeAhead(curHrp, curHum, segDest)
                if jumpAhead then
                    tryJump(curHum)
                end

                local now = os.clock()
                if now - lastSampleAt >= 0.24 then
                    local movedFlat = Utils.flatDist(curHrp.Position, lastSamplePos)
                    if movedFlat < 0.75 then
                        consecutiveStucks = consecutiveStucks + 1
                        tryJump(curHum)
                        if tallBlocked or consecutiveStucks >= 2 then
                            if unit then
                                local right = Vector3.new(-unit.Z, 0, unit.X) * sidestepSide
                                sidestepSide = -sidestepSide
                                local nudgePos = curHrp.Position + (right * 5.5) + (unit * 3.0)
                                curHum:MoveTo(nudgePos)
                                task.wait(0.18)
                                if shouldStop() then return false, true end
                            end
                        end
                        curHum:MoveTo(segDest)
                    else
                        consecutiveStucks = 0
                    end
                    lastSamplePos = curHrp.Position
                    lastSampleAt = now
                end

                task.wait(0.05)
            end
            return false, false
        end

        local path = PathfindingService:CreatePath({
            AgentRadius = 2.0,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 4,
        })

        local okPath = pcall(function()
            path:ComputeAsync(hrp.Position, targetPos)
        end)

        local arrived = false
        local timeoutAt = os.clock() + (States.Movement.WalkTimeout or 18)

        if okPath and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for idx = 2, #waypoints do
                if shouldStop() or os.clock() > timeoutAt then break end
                local wp = waypoints[idx]
                local hitFinal, aborted = driveSegment(
                    wp.Position,
                    3.4,
                    math.min(2.6, math.max(0.4, timeoutAt - os.clock())),
                    wp.Action == Enum.PathWaypointAction.Jump
                )
                if hitFinal then
                    arrived = true
                    break
                end
                if aborted then break end
            end
        end

        if not arrived and not shouldStop() and os.clock() <= timeoutAt then
            local remTime = math.max(1.5, timeoutAt - os.clock())
            driveSegment(targetPos, math.max(3.2, math.min(reqDist, 4.5)), math.min(6.5, remTime), false)
        end

        Move._walking = false
        local _, curHrp = Utils.getCharacterParts()
        return curHrp ~= nil and Utils.flatDist(curHrp.Position, targetPos) <= reqDist
    end

    function Move.MoveTo(targetPos, arrivalRadius, yOffset, abortCheckFn)
        if not targetPos then return false end
        local _, hrp = Utils.getCharacterParts()
        if not hrp then return false end
        if Utils.flatDist(hrp.Position, targetPos) <= (arrivalRadius or 5) then
            return true
        end

        ctx.Runtime.Status.Movement = string.format("%s -> (%.0f, %.0f, %.0f)", Move.GetMode(), targetPos.X, targetPos.Y, targetPos.Z)
        if Move.GetMode() == "Legit Walk" then
            return Move.WalkTo(targetPos, arrivalRadius or 5, abortCheckFn)
        end
        return Move.TeleportTo(targetPos, yOffset or 3.2)
    end

    function Move.FindMachinePad(machineName)
        local model = Net.GetPlotModel()
        if model and Net.Mod.Util_Buttons and Net.Mod.Util_Buttons.MachinePad then
            local ok, pad = pcall(Net.Mod.Util_Buttons.MachinePad, model, machineName)
            if ok and pad then
                return Utils.getInstancePos(pad)
            end
        end
        local decor = Net.GetPlotDecor()
        local front = decor and decor:FindFirstChild("Front")
        if front then
            local look = front:FindFirstChild(machineName .. "_Look")
            if look then
                return Utils.getInstancePos(look)
            end
        end
        return nil
    end

    function Move.CrossToTurkeyIsland()
        if Move.IsOnTurkeyIsland() then
            return true
        end

        local NET = Net.Mod.PT_Types and Net.Mod.PT_Types.NET
        local shared = Net.GetTurkeyIslandFolder()
        local arena = shared and shared:FindFirstChild("TurkeyArena")
        local turkeySpawn = arena and arena:FindFirstChild("TurkeySpawn", true)
        local targetArenaPos = Utils.getInstancePos(turkeySpawn or arena or shared)
        if not targetArenaPos then return false end

        local ownsCannon = Net.Mod.Turkey and Net.Mod.Turkey.OwnsCannon and Net.Mod.Turkey.OwnsCannon()
        if Move.GetMode() == "Legit Walk" then
            local plotModel = Net.GetPlotModel()
            local interact = plotModel and plotModel:FindFirstChild("Interactable")
            local cannonPad = interact and interact:FindFirstChild("CannonPad")
            if ownsCannon and cannonPad and NET then
                local padPos = Utils.getInstancePos(cannonPad)
                if padPos then
                    Move.WalkTo(padPos, 10)
                    Net.PlotInvoke(NET.Cannon, "centre")
                    task.wait(1.8)
                    return Move.IsOnTurkeyIsland()
                end
            end
            return false
        end

        if ownsCannon and NET then
            Net.PlotInvoke(NET.Cannon, "centre")
            task.wait(0.6)
            if Move.IsOnTurkeyIsland() then
                return true
            end
        end
        return Move.TeleportTo(targetArenaPos, 4)
    end

    function Move.ReturnToOwnIsland()
        if not Move.IsOnTurkeyIsland() then
            return true
        end

        local NET = Net.Mod.PT_Types and Net.Mod.PT_Types.NET
        local plotModel = Net.GetPlotModel()
        local interact = plotModel and plotModel:FindFirstChild("Interactable")
        local landing = (interact and interact:FindFirstChild("CannonLanding")) or (plotModel and plotModel:FindFirstChild("SpawnPosition"))
        local homePos = Utils.getInstancePos(landing or plotModel)

        if Move.GetMode() == "Legit Walk" then
            local shared = Net.GetTurkeyIslandFolder()
            local homePad = nil
            if shared then
                for _, d in ipairs(shared:GetDescendants()) do
                    if d.Name == "CannonPad" and d:IsA("BasePart") and d:GetAttribute("Target") == "home" then
                        homePad = d
                        break
                    end
                end
            end
            if homePad and NET then
                local padPos = Utils.getInstancePos(homePad)
                if padPos then
                    Move.WalkTo(padPos, 10)
                    Net.PlotInvoke(NET.Cannon, "home")
                    task.wait(1.8)
                    return not Move.IsOnTurkeyIsland()
                end
            end
            return false
        end

        if NET then
            Net.PlotInvoke(NET.Cannon, "home")
            task.wait(0.6)
            if not Move.IsOnTurkeyIsland() then
                return true
            end
        end
        if homePos then
            return Move.TeleportTo(homePos, 4)
        end
        return false
    end

    ctx.Movement = Move
    ctx.API.moveTo = Move.MoveTo
    return Move
end

return MovementController
