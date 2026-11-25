-- src/Core/Utils.lua
-- Shared helpers for AdoptMeHub

local Utils = {}

function Utils.Init(ctx)
    local Players = ctx.Roblox.Players
    local U = {}

    function U.formatNumber(n)
        local num = tonumber(n) or 0
        if num >= 1e9 then
            return string.format("%.2fB", num / 1e9)
        elseif num >= 1e6 then
            return string.format("%.2fM", num / 1e6)
        elseif num >= 1e3 then
            return string.format("%.1fK", num / 1e3)
        end
        return tostring(math.floor(num))
    end

    function U.getCharacterParts()
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        if not char then return nil, nil, nil end
        return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
    end

    function U.getPos(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then return inst:GetPivot().Position end
        return nil
    end

    function U.moveToPosition(pos, timeoutSec)
        local char, hrp, hum = U.getCharacterParts()
        if not char or not hrp or not pos then return false end
        if hum and hum.Sit then
            hum.Sit = false
            hum.Jump = true
            task.wait(0.15)
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(timeoutSec or 0.2)
        return true
    end

    function U.debugWarn(tag, msg)
        if ctx.Config and ctx.Config.Debug and ctx.Config.Debug.DebugMode then
            warn(string.format("[AdoptMeHub:%s] %s", tostring(tag), tostring(msg)))
        end
    end

    ctx.Utils = U
    return U
end

return Utils
