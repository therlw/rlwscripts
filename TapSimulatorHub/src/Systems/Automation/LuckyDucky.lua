-- src/Systems/Automation/LuckyDucky.lua
-- Lucky Ducky Unified Smart Auto-Catch (Server-Safe 1.45s Flight Timing)

local LuckyDucky = {}

function LuckyDucky.Init(ctx)
    local CONFIG = ctx.Config
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local KaitunState = ctx.States.Kaitun
    local RewardState = ctx.States.Reward
    local Runtime = ctx.Runtime

    local function handleLuckyDuckySpawn(spawnData)
        Runtime.lastLuckyDuckySpawn = os.clock()
        local isKaitunActive = KaitunState and KaitunState.AutoLuckyDucky
        local isNormalActive = RewardState and (RewardState.AutoLuckyDucky or RewardState.AutoDailyRewards)
        if not (isKaitunActive or isNormalActive) then return end

        task.delay(CONFIG.LuckyDuckySafeTime, function()
            local caught = false
            pcall(function()
                if Mod.LuckyDuckyController and type(Mod.LuckyDuckyController.CatchShown) == "function" then
                    caught = Mod.LuckyDuckyController:CatchShown()
                end
            end)

            if not caught then
                pcall(function()
                    local ld = LocalPlayer.PlayerGui:FindFirstChild("LuckyDucky")
                    if ld then
                        for _, btn in ipairs(ld:GetDescendants()) do
                            if btn:IsA("GuiButton") and btn.Visible then
                                for _, c in ipairs(getconnections(btn.Activated or btn.MouseButton1Click)) do
                                    c:Fire()
                                    caught = true
                                end
                            end
                        end
                    end
                end)
            end

            if not caught and spawnData then
                pcall(function()
                    local duckId = type(spawnData) == "table" and spawnData.Id or spawnData
                    if duckId and Svc.LuckyDuckyService and Svc.LuckyDuckyService:FindFirstChild("RF") and Svc.LuckyDuckyService.RF:FindFirstChild("Claim") then
                        Svc.LuckyDuckyService.RF.Claim:InvokeServer(duckId)
                    end
                end)
            end
        end)
    end

    ctx.API.handleLuckyDuckySpawn = handleLuckyDuckySpawn
    LuckyDucky.handleLuckyDuckySpawn = handleLuckyDuckySpawn
    return LuckyDucky
end

function LuckyDucky.Start(ctx)
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration
    local trackConnection = ctx.Lifecycle.TrackConnection
    local Svc = ctx.Services

    if Svc.LuckyDuckyService and Svc.LuckyDuckyService:FindFirstChild("RE") and Svc.LuckyDuckyService.RE:FindFirstChild("Spawn") then
        trackConnection(Svc.LuckyDuckyService.RE.Spawn.OnClientEvent:Connect(function(...)
            if not isCurrentGeneration() then return end
            local args = { ... }
            LuckyDucky.handleLuckyDuckySpawn(args[1])
        end))
    end
end

return LuckyDucky
