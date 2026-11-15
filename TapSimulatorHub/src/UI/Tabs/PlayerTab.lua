-- src/UI/Tabs/PlayerTab.lua
-- Tab 6: Player & Utilities (WalkSpeed Lock, JumpPower Lock, Infinite Jump, Noclip & Rejoin)

local PlayerTab = {}

function PlayerTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local ConfigManager = ctx.ConfigManager
    local PlayerState = ctx.States.Player
    local DEFAULT_WALKSPEED = ctx.DefaultWalkSpeed
    local DEFAULT_JUMPPOWER = ctx.DefaultJumpPower
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local applyPlayerHumanoidStats = ctx.API.applyPlayerHumanoidStats

    UI.MiscTab = Window:CreateTab({ name = "Player", icon = 93364949241311 })
    UI.MiscTab:CreateSection({ name = "Movement Modifiers (SprintController-Safe Override)" })

    UI.WalkSpeedSlider = nil
    UI.JumpPowerSlider = nil
    UI.CustomWalkSpeedToggle = nil
    UI.CustomJumpPowerToggle = nil

    UI.CustomWalkSpeedToggle = createBoundToggle(UI.MiscTab, {
        name = "Lock Custom WalkSpeed",
        flag = "CustomWalkSpeed",
        description = "Continuously enforces slider WalkSpeed over the game's SprintController reset",
        value = false,
    }, function() return PlayerState.CustomWalkSpeed end, function(v) PlayerState.CustomWalkSpeed = v end, function()
        if applyPlayerHumanoidStats then applyPlayerHumanoidStats() end
    end)

    pcall(function()
        UI.WalkSpeedSlider = UI.MiscTab:CreateSlider({
            name = "WalkSpeed",
            flag = "PlayerWalkSpeed",
            range = { 16, 250 },
            increment = 1,
            value = PlayerState.WalkSpeed,
            callback = function(val)
                PlayerState.WalkSpeed = val
                if val ~= DEFAULT_WALKSPEED and not PlayerState.CustomWalkSpeed then
                    PlayerState.CustomWalkSpeed = true
                    if UI.CustomWalkSpeedToggle and UI.CustomWalkSpeedToggle.Set then
                        pcall(function() UI.CustomWalkSpeedToggle:Set(true, true) end)
                    end
                end
                if applyPlayerHumanoidStats then applyPlayerHumanoidStats() end
                ConfigManager:MarkDirty()
            end
        })
        ConfigManager:Bind("PlayerWalkSpeed", UI.WalkSpeedSlider, function() return PlayerState.WalkSpeed end, function(v)
            PlayerState.WalkSpeed = tonumber(v) or DEFAULT_WALKSPEED
        end)
    end)

    UI.CustomJumpPowerToggle = createBoundToggle(UI.MiscTab, {
        name = "Lock Custom JumpPower",
        flag = "CustomJumpPower",
        description = "Continuously enforces slider JumpPower on Humanoid",
        value = false,
    }, function() return PlayerState.CustomJumpPower end, function(v) PlayerState.CustomJumpPower = v end, function()
        if applyPlayerHumanoidStats then applyPlayerHumanoidStats() end
    end)

    pcall(function()
        UI.JumpPowerSlider = UI.MiscTab:CreateSlider({
            name = "JumpPower",
            flag = "PlayerJumpPower",
            range = { 50, 300 },
            increment = 1,
            value = PlayerState.JumpPower,
            callback = function(val)
                PlayerState.JumpPower = val
                if val ~= DEFAULT_JUMPPOWER and not PlayerState.CustomJumpPower then
                    PlayerState.CustomJumpPower = true
                    if UI.CustomJumpPowerToggle and UI.CustomJumpPowerToggle.Set then
                        pcall(function() UI.CustomJumpPowerToggle:Set(true, true) end)
                    end
                end
                if applyPlayerHumanoidStats then applyPlayerHumanoidStats() end
                ConfigManager:MarkDirty()
            end
        })
        ConfigManager:Bind("PlayerJumpPower", UI.JumpPowerSlider, function() return PlayerState.JumpPower end, function(v)
            PlayerState.JumpPower = tonumber(v) or DEFAULT_JUMPPOWER
        end)
    end)

    UI.MiscTab:CreateButton({
        name = "Reset WalkSpeed & JumpPower to Default",
        callback = function()
            PlayerState.CustomWalkSpeed = false
            PlayerState.CustomJumpPower = false
            PlayerState.WalkSpeed = DEFAULT_WALKSPEED
            PlayerState.JumpPower = DEFAULT_JUMPPOWER
            pcall(function()
                if UI.CustomWalkSpeedToggle and UI.CustomWalkSpeedToggle.Set then UI.CustomWalkSpeedToggle:Set(false, true) end
                if UI.CustomJumpPowerToggle and UI.CustomJumpPowerToggle.Set then UI.CustomJumpPowerToggle:Set(false, true) end
                if UI.WalkSpeedSlider and UI.WalkSpeedSlider.Set then UI.WalkSpeedSlider:Set(DEFAULT_WALKSPEED, true) end
                if UI.JumpPowerSlider and UI.JumpPowerSlider.Set then UI.JumpPowerSlider:Set(DEFAULT_JUMPPOWER, true) end
            end)
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = DEFAULT_WALKSPEED
                hum.JumpPower = DEFAULT_JUMPPOWER
            end
            ConfigManager:MarkDirty()
            safeNotify({ title = "Movement Reset", content = string.format("Restored WalkSpeed=%d, JumpPower=%d", DEFAULT_WALKSPEED, DEFAULT_JUMPPOWER) })
        end
    })

    createBoundToggle(UI.MiscTab, {
        name = "Infinite Jump",
        flag = "InfiniteJump",
        description = "Allows jumping repeatedly in mid-air",
        value = false,
    }, function() return PlayerState.InfiniteJump end, function(v) PlayerState.InfiniteJump = v end)

    createBoundToggle(UI.MiscTab, {
        name = "Noclip",
        flag = "Noclip",
        description = "Walk through walls and obstacles effortlessly",
        value = false,
    }, function() return PlayerState.Noclip end, function(v) PlayerState.Noclip = v end)

    UI.MiscTab:CreateSection({ name = "Server & Game" })

    UI.MiscTab:CreateButton({
        name = "Rejoin Server",
        callback = function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    })

    return PlayerTab
end

return PlayerTab
