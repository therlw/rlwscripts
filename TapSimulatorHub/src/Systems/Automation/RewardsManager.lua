-- src/Systems/Automation/RewardsManager.lua
-- Tap Chests, Shiny Stars Collector, Smart Potions/Boosts & Quests/Daily Rewards Worker

local RewardsManager = {}

function RewardsManager.Init(ctx)
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService
    local KaitunState = ctx.States.Kaitun
    local getPlayerData = ctx.API.getPlayerData
    local getInstancePosition = ctx.Utils.getInstancePosition
    local safeInvoke = ctx.Utils.safeInvoke

    local function collectIslandShinyStars()
        local data = getPlayerData()
        if not (data and Mod.ShinyStarConfig and Svc.ShinyStarService and Svc.ShinyStarService:FindFirstChild("RF") and Svc.ShinyStarService.RF:FindFirstChild("Collect")) then
            return false
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local curWorld = (data.Progression and data.Progression.World) or "Main"
        local curIsland = (data.Progression and data.Progression.Island) or "Spawn"
        local totalStars = #(Mod.ShinyStarConfig.Stars or {})
        if totalStars <= 0 then totalStars = 24 end

        local function matchesCurrentStarIsland(starInfo)
            if starInfo.Island == curIsland then return true end
            if curWorld == "TimeRift" and curIsland == "Spawn" and (starInfo.Island == "World 2 Spawn" or starInfo.Island == "TimeRiftSpawn") then
                return true
            end
            return false
        end

        for _, starInfo in ipairs(Mod.ShinyStarConfig.Stars or {}) do
            if matchesCurrentStarIsland(starInfo) then
                local isFound = false
                if Mod.ShinyStarConfig.IsFound then
                    isFound = Mod.ShinyStarConfig.IsFound(data, starInfo.Id)
                elseif data.ShinyStars and data.ShinyStars.Found then
                    isFound = table.find(data.ShinyStars.Found, starInfo.Id) ~= nil
                end

                if not isFound then
                    local shinyStarsFolder = workspace:FindFirstChild("ShinyStars")
                    local w2StarsFolder = workspace:FindFirstChild("World2") and workspace.World2:FindFirstChild("ShinyStars")
                    local starObj = (shinyStarsFolder and shinyStarsFolder:FindFirstChild(starInfo.Id))
                        or (w2StarsFolder and w2StarsFolder:FindFirstChild(starInfo.Id))
                    if not starObj then
                        for _, tagged in ipairs(CollectionService:GetTagged(Mod.ShinyStarConfig.Tag or "ShinyStar")) do
                            if (tagged:GetAttribute(Mod.ShinyStarConfig.IdAttribute or "ShinyStarId") or tagged.Name) == starInfo.Id then
                                starObj = tagged
                                break
                            end
                        end
                    end

                    if starObj then
                        local starPos = getInstancePosition(starObj)
                        if starPos then
                            local oldCF = hrp.CFrame
                            hrp.CFrame = CFrame.new(starPos + Vector3.new(0, 1.5, 3.5), starPos)
                            task.wait(0.3)
                            local res = safeInvoke(Svc.ShinyStarService, "RF", "Collect", starInfo.Id)
                            task.wait(0.2)
                            hrp.CFrame = oldCF
                            if type(res) == "table" and res.Success == true then
                                if ctx.UI.safeNotify then
                                    ctx.UI.safeNotify({
                                        title = "Shiny Star Collected!",
                                        content = string.format("Found %s! (%d/%d Total)", starInfo.Id, res.Found or 1, totalStars)
                                    })
                                end
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local function manageSmartBoosts(isActivelyHatching, isSavingForIsland)
        local data = getPlayerData()
        if not (data and data.Boosts and Mod.BoostConfig and Mod.BoostFormula and Svc.BoostService and Svc.BoostService:FindFirstChild("RF") and Svc.BoostService.RF:FindFirstChild("Use")) then
            return
        end

        local boosts = data.Boosts
        local safeNotify = function(opts)
            if ctx.UI.safeNotify then ctx.UI.safeNotify(opts) end
        end

        -- 1. Coins Potion: Use during sprint for next island or heavy zone farming
        local hasCoinsBoost = Mod.BoostFormula.HasType(data, "Coins")
        if not hasCoinsBoost and (isSavingForIsland or string.find(tostring(KaitunState.CurrentAction), "Tapping")) then
            local coinPotionToUse = nil
            if (boosts["Coins Potion II"] or 0) > 0 then
                coinPotionToUse = "Coins Potion II"
            elseif (boosts["Coins Potion I"] or 0) > 0 then
                coinPotionToUse = "Coins Potion I"
            elseif (boosts["Small Coins Potion"] or 0) > 0 then
                coinPotionToUse = "Small Coins Potion"
            end

            if coinPotionToUse then
                pcall(function()
                    Svc.BoostService.RF.Use:InvokeServer(coinPotionToUse)
                    safeNotify({
                        title = "Potion Activated!",
                        content = string.format("Used %s for bonus coin income!", coinPotionToUse)
                    })
                end)
                return
            end
        end

        -- 2. Luck / Golden Potion: Use ONLY when actively hatching eggs
        local hasLuckBoost = Mod.BoostFormula.HasType(data, "Luck")
        if not hasLuckBoost and isActivelyHatching then
            local luckPotionToUse = nil
            if (boosts["Luck Potion II"] or 0) > 0 then
                luckPotionToUse = "Luck Potion II"
            elseif (boosts["Luck Potion I"] or 0) > 0 then
                luckPotionToUse = "Luck Potion I"
            elseif (boosts["Small Luck Potion"] or 0) > 0 then
                luckPotionToUse = "Small Luck Potion"
            elseif (boosts["Golden Potion"] or 0) > 0 and not Mod.BoostFormula.HasType(data, "GoldenHatch") then
                luckPotionToUse = "Golden Potion"
            end

            if luckPotionToUse then
                pcall(function()
                    Svc.BoostService.RF.Use:InvokeServer(luckPotionToUse)
                    safeNotify({
                        title = "Potion Activated!",
                        content = string.format("Used %s for bonus egg luck!", luckPotionToUse)
                    })
                end)
                return
            end
        end

        -- 3. Gems Potion: Use when recently rebirthing
        local hasGemsBoost = Mod.BoostFormula.HasType(data, "Gems")
        if not hasGemsBoost and (os.clock() - KaitunState.LastRebirthTime < 15.0) then
            local gemsPotionToUse = nil
            if (boosts["Gems Potion II"] or 0) > 0 then
                gemsPotionToUse = "Gems Potion II"
            elseif (boosts["Gems Potion I"] or 0) > 0 then
                gemsPotionToUse = "Gems Potion I"
            elseif (boosts["Small Gems Potion"] or 0) > 0 then
                gemsPotionToUse = "Small Gems Potion"
            end

            if gemsPotionToUse then
                pcall(function()
                    Svc.BoostService.RF.Use:InvokeServer(gemsPotionToUse)
                    safeNotify({
                        title = "Potion Activated!",
                        content = string.format("Used %s for +75%% Gems boost!", gemsPotionToUse)
                    })
                end)
                return
            end
        end
    end

    ctx.API.collectIslandShinyStars = collectIslandShinyStars
    ctx.API.manageSmartBoosts = manageSmartBoosts

    RewardsManager.collectIslandShinyStars = collectIslandShinyStars
    RewardsManager.manageSmartBoosts = manageSmartBoosts
    return RewardsManager
end

function RewardsManager.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local CollectionService = ctx.Roblox.CollectionService
    local RewardState = ctx.States.Reward
    local Runtime = ctx.Runtime

    -- 7. Rewards & Collectibles Worker
    task.spawn(function()
        while true do
            if not isCurrentGeneration() then break end
            task.wait(2.5)

            if RewardState.AutoChests and Mod.TapChestConfig and Svc.TapChestService and Svc.TapChestService:FindFirstChild("RF") and Svc.TapChestService.RF:FindFirstChild("Claim") then
                pcall(function()
                    for _, chest in ipairs(CollectionService:GetTagged(Mod.TapChestConfig.Tag or "TapChest")) do
                        local chestId = chest:GetAttribute("TapChestId") or chest:GetAttribute("Id") or chest.Name
                        if chestId then
                            Svc.TapChestService.RF.Claim:InvokeServer(chestId)
                            task.wait(0.1)
                        end
                    end
                end)
            end

            if RewardState.AutoStars and Mod.ShinyStarConfig and Svc.ShinyStarService and Svc.ShinyStarService:FindFirstChild("RF") and Svc.ShinyStarService.RF:FindFirstChild("Collect") then
                pcall(function()
                    for _, star in ipairs(CollectionService:GetTagged(Mod.ShinyStarConfig.Tag or "ShinyStar")) do
                        local starId = star:GetAttribute(Mod.ShinyStarConfig.IdAttribute or "ShinyStarId") or star.Name
                        if starId then
                            Svc.ShinyStarService.RF.Collect:InvokeServer(starId)
                            task.wait(0.1)
                        end
                    end
                end)
            end

            if RewardState.AutoQuests and Svc.QuestService and ctx.API.claimAllReadyQuests then
                pcall(ctx.API.claimAllReadyQuests)
            end

            if RewardState.AutoDailyRewards then
                pcall(function()
                    if Svc.OfflineRewardsService and Svc.OfflineRewardsService:FindFirstChild("RF") and Svc.OfflineRewardsService.RF:FindFirstChild("Claim") then
                        Svc.OfflineRewardsService.RF.Claim:InvokeServer()
                    end
                    local ld = LocalPlayer.PlayerGui:FindFirstChild("LuckyDucky")
                    if ld and ld.Enabled and (os.clock() - (Runtime.lastLuckyDuckySpawn or 0) >= CONFIG.LuckyDuckySafeTime) then
                        pcall(function()
                            if Mod.LuckyDuckyController and type(Mod.LuckyDuckyController.CatchShown) == "function" then
                                Mod.LuckyDuckyController:CatchShown()
                            end
                            for _, btn in ipairs(ld:GetDescendants()) do
                                if btn:IsA("GuiButton") and btn.Visible then
                                    for _, c in ipairs(getconnections(btn.Activated or btn.MouseButton1Click)) do
                                        c:Fire()
                                    end
                                end
                            end
                        end)
                    end
                    if Svc.PetIndexService and Svc.PetIndexService:FindFirstChild("RE") and Svc.PetIndexService.RE:FindFirstChild("ClaimAllRequested") then
                        Svc.PetIndexService.RE.ClaimAllRequested:FireServer()
                    end
                    if Svc.EventWheelService and Svc.EventWheelService:FindFirstChild("RF") and Svc.EventWheelService.RF:FindFirstChild("Spin") then
                        Svc.EventWheelService.RF.Spin:InvokeServer()
                    end
                end)
            end
        end
    end)
end

return RewardsManager
