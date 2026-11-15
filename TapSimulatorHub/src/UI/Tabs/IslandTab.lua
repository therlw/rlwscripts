-- src/UI/Tabs/IslandTab.lua
-- Tab 4: Islands & Worlds (Drawbridge, Unlocks, World 2 & Medieval Castle Travel)

local IslandTab = {}

function IslandTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local ConfigManager = ctx.ConfigManager
    local IslandState = ctx.States.Island
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle
    local formatCompact = ctx.Utils.formatCompact

    local getPlayerData = ctx.API.getPlayerData
    local getCoins = ctx.API.getCoins
    local buildDynamicIslandList = ctx.API.buildDynamicIslandList
    local getBridgeStatus = ctx.API.getBridgeStatus
    local pushBridge = ctx.API.pushBridge
    local isWorld2Unlocked = ctx.API.isWorld2Unlocked
    local unlockWorld2 = ctx.API.unlockWorld2
    local getNextLockedIsland = ctx.API.getNextLockedIsland
    local unlockIsland = ctx.API.unlockIsland
    local getBestUnlockedIsland = ctx.API.getBestUnlockedIsland
    local travelToIsland = ctx.API.travelToIsland

    UI.IslandTab = Window:CreateTab({ name = "Islands", icon = 93364949241311 })
    local allIslands = buildDynamicIslandList()

    UI.IslandTab:CreateSection({ name = "Drawbridge Progression" })

    UI.BridgeStatusText = UI.IslandTab:CreateText({ name = "Drawbridge Status", text = "Checking status..." })

    createBoundToggle(UI.IslandTab, {
        name = "Auto Push Drawbridge",
        flag = "AutoPushBridge",
        description = "Automatically pushes and lowers the drawbridge as soon as power is ready",
        value = true,
    }, function() return IslandState.AutoPushBridge end, function(v) IslandState.AutoPushBridge = v end)

    UI.IslandTab:CreateButton({
        name = "Push Drawbridge Now",
        callback = function()
            local status = getBridgeStatus()
            if status.lowered then
                safeNotify({ title = "Drawbridge", content = "Drawbridge is already unlocked and lowered!" })
                return
            end
            if not status.ready then
                safeNotify({
                    title = "Drawbridge",
                    content = string.format("Tap Power not ready yet! (%s / %s needed)", formatCompact(status.power), formatCompact(status.req))
                })
                return
            end
            safeNotify({ title = "Drawbridge", content = "Pushing drawbridge down..." })
            task.spawn(function()
                local ok = pushBridge(7)
                if ok then
                    safeNotify({ title = "Drawbridge", content = "Drawbridge successfully lowered!" })
                else
                    safeNotify({ title = "Drawbridge", content = "Failed to lower bridge. Try again or check power." })
                end
            end)
        end
    })

    UI.IslandTab:CreateSection({ name = "Island Progression" })

    UI.NextIslandStatusText = UI.IslandTab:CreateText({ name = "Next Island", text = "Checking requirements..." })

    createBoundToggle(UI.IslandTab, {
        name = "Auto Unlock Next Island",
        flag = "AutoUnlockNextIsland",
        description = "Automatically purchases and unlocks the next island once affordable (handles bridge & proximity)",
        value = false,
    }, function() return IslandState.AutoUnlockNext end, function(v) IslandState.AutoUnlockNext = v end)

    createBoundToggle(UI.IslandTab, {
        name = "Auto Best World Teleport",
        flag = "AutoBestTeleport",
        description = "Automatically teleports you to your highest unlocked island/world for maximum farming",
        value = false,
    }, function() return IslandState.AutoBestTeleport end, function(v) IslandState.AutoBestTeleport = v end, function(val)
        if val then
            task.spawn(function()
                local best = getBestUnlockedIsland()
                local curData = getPlayerData()
                local curW = curData and curData.Progression and curData.Progression.World or "Main"
                local curI = curData and curData.Progression and curData.Progression.Island or "Spawn"
                local isAlreadyAtBest = (curI == best) or (curW == "TimeRift" and curI == "Spawn" and best == "World 2 Spawn")
                if best and not isAlreadyAtBest and best ~= "Spawn" then
                    local ok = travelToIsland(best)
                    if ok then
                        safeNotify({
                            title = "Best World Teleport",
                            content = "Teleported to your best unlocked island: " .. best
                        })
                    end
                end
            end)
        end
    end)

    createBoundToggle(UI.IslandTab, {
        name = "Suppress Purchase Popups",
        flag = "SuppressPurchasePopups",
        description = "Completely blocks the 'Are you sure you want to unlock' dialog from popping up on screen",
        value = true,
    }, function() return IslandState.SuppressPrompt end, function(v) IslandState.SuppressPrompt = v end)

    createBoundToggle(UI.IslandTab, {
        name = "Auto Confirm on Touch",
        flag = "AutoConfirmOnTouch",
        description = "Instantly unlocks the island in background when stepping on pad (if affordable)",
        value = true,
    }, function() return IslandState.AutoConfirmOnTouch end, function(v) IslandState.AutoConfirmOnTouch = v end)

    UI.IslandTab:CreateButton({
        name = "Unlock Next Island Now",
        callback = function()
            local nextIsl = getNextLockedIsland()
            if not nextIsl then
                safeNotify({ title = "Island Unlock", content = "All islands are already unlocked!" })
                return
            end
            local coins = getCoins()
            if coins < nextIsl.price then
                safeNotify({
                    title = "Island Unlock",
                    content = string.format("Need %s Coins for %s! (You have %s)", formatCompact(nextIsl.price), nextIsl.name, formatCompact(coins))
                })
                return
            end
            safeNotify({ title = "Island Unlock", content = "Teleporting to portal to unlock " .. nextIsl.name .. "..." })
            task.spawn(function()
                local ok, err = unlockIsland(nextIsl)
                if ok then
                    safeNotify({ title = "Island Unlocked!", content = "Successfully unlocked " .. nextIsl.name .. "!" })
                    if IslandState.AutoBestTeleport then
                        task.wait(0.5)
                        travelToIsland(nextIsl.name)
                    end
                else
                    safeNotify({ title = "Island Unlock Failed", content = tostring(err or "Failed to purchase") })
                end
            end)
        end
    })

    UI.IslandTab:CreateSection({ name = "World 2 (Time Rift) & Castle Island" })

    UI.World2StatusText = UI.IslandTab:CreateText({ name = "World 2 Status", text = "Checking status..." })

    UI.IslandTab:CreateButton({
        name = "Unlock World 2 (Time Rift) [20 QN Coins]",
        callback = function()
            if isWorld2Unlocked() then
                safeNotify({ title = "World 2", content = "World 2 is already unlocked!" })
                return
            end
            local coins = getCoins()
            if coins < 2e19 then
                safeNotify({
                    title = "World 2",
                    content = string.format("Need 20.00QN Coins! (You have %s)", formatCompact(coins))
                })
                return
            end
            safeNotify({ title = "World 2", content = "Teleporting to W2Platform and unlocking..." })
            task.spawn(function()
                local ok, err = unlockWorld2()
                if ok then
                    safeNotify({ title = "World 2 Unlocked!", content = "Time Rift unlocked! Teleporting to World 2..." })
                    task.wait(0.5)
                    travelToIsland("World 2 Spawn")
                else
                    safeNotify({ title = "World 2 Unlock Failed", content = tostring(err) })
                end
            end)
        end
    })

    UI.IslandTab:CreateButton({
        name = "Travel to World 2 (Time Rift)",
        callback = function()
            if not isWorld2Unlocked() then
                safeNotify({ title = "World 2 Locked", content = "You must unlock World 2 first!" })
                return
            end
            safeNotify({ title = "World 2 Travel", content = "Traveling to World 2..." })
            task.spawn(function()
                travelToIsland("World 2 Spawn")
            end)
        end
    })

    UI.IslandTab:CreateButton({
        name = "Travel to Castle (Medieval Island)",
        callback = function()
            task.spawn(function()
                local ok = travelToIsland("Medieval Island")
                safeNotify({
                    title = "Castle Island Travel",
                    content = ok and "Arrived at Medieval Island!" or "Could not travel (check World 2 / Medieval Island unlock)."
                })
            end)
        end
    })

    UI.IslandTab:CreateSection({ name = "Island Travel" })

    UI.IslandDropdown = UI.IslandTab:CreateDropdown({
        name = "Select Destination",
        flag = "SelectedIsland",
        options = allIslands,
        value = IslandState.SelectedIsland,
        callback = function(selected)
            local isl = type(selected) == "table" and selected[1] or selected
            if isl then
                IslandState.SelectedIsland = isl
            end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("SelectedIsland", UI.IslandDropdown, function() return IslandState.SelectedIsland end, function(v) IslandState.SelectedIsland = v end)

    UI.IslandTab:CreateButton({
        name = "Travel to Selected Island",
        callback = function()
            local target = IslandState.SelectedIsland
            if target then
                task.spawn(function()
                    local ok = travelToIsland(target)
                    if ok then
                        safeNotify({ title = "Travel", content = "Traveled to " .. target })
                    else
                        safeNotify({ title = "Travel Failed", content = "Could not travel to " .. target })
                    end
                end)
            end
        end
    })

    return IslandTab
end

return IslandTab
