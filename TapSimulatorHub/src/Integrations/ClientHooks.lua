-- src/Integrations/ClientHooks.lua
-- HatchRenderer, Secret Cutscene Skipper, Portal Prompt Suppressor & Evolution Machine UI Hooks

local ClientHooks = {}

function ClientHooks.Init(ctx)
    local Mod = ctx.Modules
    local PlayerGui = ctx.Roblox.PlayerGui
    local HatchState = ctx.States.Hatch
    local IslandState = ctx.States.Island
    local KaitunState = ctx.States.Kaitun
    local getCoins = ctx.API.getCoins
    local trackConnection = ctx.Lifecycle.TrackConnection
    local registerCleanup = ctx.Lifecycle.RegisterCleanup
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration

    -- Hook HatchRenderer & Secret Animators for Instant Clean Skip + Secret Detection
    if Mod.HatchRenderer and type(Mod.HatchRenderer.Play) == "function" then
        local oldHatchPlay = Mod.HatchRenderer._RLW_OrigPlay or Mod.HatchRenderer.Play
        Mod.HatchRenderer._RLW_OrigPlay = oldHatchPlay
        Mod.HatchRenderer.Play = function(self, egg, result, onDone, receipt)
            if ctx.SecretDetector and type(result) == "table" then
                pcall(function()
                    ctx.SecretDetector:HandleHatchPayload({ Success = true, Egg = egg, Pets = result }, "HatchRenderer")
                end)
            end
            if HatchState.SkipAnimation then
                if onDone then
                    task.defer(onDone)
                end
                task.defer(function()
                    pcall(function() Mod.HatchRenderer:FlushHudRestore() end)
                end)
                return
            end
            return oldHatchPlay(self, egg, result, onDone, receipt)
        end
        registerCleanup(function()
            if Mod.HatchRenderer and Mod.HatchRenderer._RLW_OrigPlay then
                Mod.HatchRenderer.Play = Mod.HatchRenderer._RLW_OrigPlay
            end
        end)
    end

    if Mod.SecretHatchRenderer and type(Mod.SecretHatchRenderer.Play) == "function" then
        local oldSecretPlay = Mod.SecretHatchRenderer._RLW_OrigPlay or Mod.SecretHatchRenderer.Play
        Mod.SecretHatchRenderer._RLW_OrigPlay = oldSecretPlay
        Mod.SecretHatchRenderer.Play = function(self, pet, onDone, receipt, options)
            if ctx.SecretDetector and type(pet) == "table" then
                pcall(function()
                    local eggHint = (type(receipt) == "table" and receipt.Egg) or (type(options) == "table" and options.Egg) or nil
                    ctx.SecretDetector:ProcessCandidate(pet, "SecretHatchRenderer", eggHint, false)
                end)
            end
            if HatchState.SkipSecretAnimation then
                if onDone then
                    task.delay(0.3, onDone)
                end
                return
            end
            return oldSecretPlay(self, pet, onDone, receipt, options)
        end

        local oldSecretReveal = Mod.SecretHatchRenderer._RLW_OrigReveal or Mod.SecretHatchRenderer.PlayReveal
        if type(oldSecretReveal) == "function" then
            Mod.SecretHatchRenderer._RLW_OrigReveal = oldSecretReveal
            Mod.SecretHatchRenderer.PlayReveal = function(self, pet, onDone, receipt)
                if ctx.SecretDetector and type(pet) == "table" then
                    pcall(function()
                        local eggHint = (type(receipt) == "table" and receipt.Egg) or nil
                        ctx.SecretDetector:ProcessCandidate(pet, "SecretHatchReveal", eggHint, false)
                    end)
                end
                if HatchState.SkipSecretAnimation then
                    if onDone then
                        task.delay(0.3, onDone)
                    end
                    return
                end
                return oldSecretReveal(self, pet, onDone, receipt)
            end
        end

        registerCleanup(function()
            if Mod.SecretHatchRenderer then
                if Mod.SecretHatchRenderer._RLW_OrigPlay then
                    Mod.SecretHatchRenderer.Play = Mod.SecretHatchRenderer._RLW_OrigPlay
                end
                if Mod.SecretHatchRenderer._RLW_OrigReveal then
                    Mod.SecretHatchRenderer.PlayReveal = Mod.SecretHatchRenderer._RLW_OrigReveal
                end
            end
        end)
    end

    if Mod.SecretHatchCutscenes and type(Mod.SecretHatchCutscenes.Play) == "function" then
        local oldCutscenePlay = Mod.SecretHatchCutscenes._RLW_OrigPlay or Mod.SecretHatchCutscenes.Play
        Mod.SecretHatchCutscenes._RLW_OrigPlay = oldCutscenePlay
        Mod.SecretHatchCutscenes.Play = function(self, pet, onDone, options)
            if ctx.SecretDetector and type(pet) == "table" then
                pcall(function()
                    local eggHint = (type(options) == "table" and options.Egg) or nil
                    ctx.SecretDetector:ProcessCandidate(pet, "SecretHatchCutscenes", eggHint, false)
                end)
            end
            if HatchState.SkipSecretAnimation then
                if onDone then
                    task.delay(0.3, function() onDone("Success") end)
                end
                return true, nil
            end
            return oldCutscenePlay(self, pet, onDone, options)
        end
        registerCleanup(function()
            if Mod.SecretHatchCutscenes and Mod.SecretHatchCutscenes._RLW_OrigPlay then
                Mod.SecretHatchCutscenes.Play = Mod.SecretHatchCutscenes._RLW_OrigPlay
            end
        end)
    end

    -- Hook MessageController to Suppress / Auto-Confirm Portal Purchase Dialogs
    if Mod.MessageController and type(Mod.MessageController.ShowConfirm) == "function" then
        local oldShowConfirm = Mod.MessageController._RLW_OrigShowConfirm or Mod.MessageController.ShowConfirm
        Mod.MessageController._RLW_OrigShowConfirm = oldShowConfirm
        Mod.MessageController.ShowConfirm = function(self, options)
            if options and type(options.Title) == "string" and options.Title == "Purchase" then
                local desc = type(options.Description) == "string" and options.Description or ""
                if string.find(desc, "island") or string.find(desc, "portal") then
                    if IslandState.SuppressPrompt or IslandState.AutoUnlockNext then
                        local coins = getCoins()
                        local targetName = string.match(desc, '"(.-)"')
                        local islandInfo = targetName and Mod.IslandConfig and Mod.IslandConfig.Islands and Mod.IslandConfig.Islands[targetName]
                        local price = islandInfo and islandInfo.Price or 0

                        if IslandState.AutoConfirmOnTouch and coins >= price and price > 0 and options.OnConfirm then
                            task.defer(options.OnConfirm)
                            task.defer(function()
                                pcall(function()
                                    if ctx.UI.safeNotify then
                                        ctx.UI.safeNotify({
                                            title = "Island Unlocked!",
                                            content = string.format("Unlocked %s without popup!", tostring(targetName or "Island"))
                                        })
                                    end
                                end)
                            end)
                        end

                        return false
                    end
                end
            end
            return oldShowConfirm(self, options)
        end
        registerCleanup(function()
            if Mod.MessageController and Mod.MessageController._RLW_OrigShowConfirm then
                Mod.MessageController.ShowConfirm = Mod.MessageController._RLW_OrigShowConfirm
            end
        end)
    end

    -- Hook MenuController to Suppress Machine UI & CraftingRoll Popups
    if Mod.MenuController and type(Mod.MenuController.Open) == "function" then
        local oldMenuOpen = Mod.MenuController._RLW_OrigOpen or Mod.MenuController.Open
        Mod.MenuController._RLW_OrigOpen = oldMenuOpen
        Mod.MenuController.Open = function(self, menuName, ...)
            if KaitunState and KaitunState.SuppressMachineUI and (menuName == "CraftingRoll" or menuName == "Golden" or menuName == "Diamond") then
                if menuName == "CraftingRoll" and Mod.MachineController and type(Mod.MachineController.ContinueRoll) == "function" then
                    task.defer(function()
                        pcall(function() Mod.MachineController:ContinueRoll() end)
                    end)
                end
                return nil
            end
            return oldMenuOpen(self, menuName, ...)
        end
        registerCleanup(function()
            if Mod.MenuController and Mod.MenuController._RLW_OrigOpen then
                Mod.MenuController.Open = Mod.MenuController._RLW_OrigOpen
            end
        end)
    end

    -- Non-blocking fallback UI watchers (portal prompt & Golden/Diamond/CraftingRoll popups)
    task.spawn(function()
        pcall(function()
            local tabs = PlayerGui:WaitForChild("Tabs", 5)
            local msgGui = tabs and tabs:WaitForChild("Message", 5)
            if msgGui and isCurrentGeneration() then
                trackConnection(msgGui:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not isCurrentGeneration() then return end
                    if msgGui.Enabled and (IslandState.SuppressPrompt or IslandState.AutoUnlockNext) then
                        local menu = msgGui:FindFirstChild("Menu")
                        local desc = menu and menu:FindFirstChild("Description")
                        local text = desc and desc.Text or ""
                        if string.find(text, "island") or string.find(text, "portal") then
                            if Mod.MenuController and type(Mod.MenuController.Close) == "function" then
                                Mod.MenuController:Close("Message")
                            else
                                msgGui.Enabled = false
                            end
                        end
                    end
                end))
            end
        end)

        pcall(function()
            local tabs = PlayerGui:WaitForChild("Tabs", 10)
            if tabs and isCurrentGeneration() then
                local function bindMachineSuppression(gui, name)
                    if gui and gui:IsA("ScreenGui") then
                        trackConnection(gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                            if not isCurrentGeneration() then return end
                            if gui.Enabled and KaitunState and KaitunState.SuppressMachineUI then
                                gui.Enabled = false
                                if name == "CraftingRoll" then
                                    pcall(function()
                                        if Mod.MachineController and type(Mod.MachineController.ContinueRoll) == "function" then
                                            Mod.MachineController:ContinueRoll()
                                        end
                                    end)
                                    pcall(function()
                                        if Mod.MenuController and type(Mod.MenuController.Close) == "function" then
                                            Mod.MenuController:Close("CraftingRoll")
                                        end
                                    end)
                                    local cont = gui:FindFirstChild("Menu") and gui.Menu:FindFirstChild("Continue")
                                    local btn = cont and cont:FindFirstChildWhichIsA("TextButton", true)
                                    if btn then
                                        for _, c in ipairs(getconnections(btn.Activated or btn.MouseButton1Click)) do
                                            c:Fire()
                                        end
                                    end
                                elseif name == "Golden" or name == "Diamond" then
                                    pcall(function()
                                        if Mod.MenuController and type(Mod.MenuController.Close) == "function" then
                                            Mod.MenuController:Close(name)
                                        end
                                    end)
                                end
                            end
                        end))
                        if gui.Enabled and KaitunState and KaitunState.SuppressMachineUI then
                            gui.Enabled = false
                        end
                    end
                end

                for _, name in ipairs({ "CraftingRoll", "Golden", "Diamond" }) do
                    local g = tabs:FindFirstChild(name)
                    if g then
                        bindMachineSuppression(g, name)
                    end
                end

                trackConnection(tabs.ChildAdded:Connect(function(child)
                    if not isCurrentGeneration() then return end
                    if child.Name == "CraftingRoll" or child.Name == "Golden" or child.Name == "Diamond" then
                        bindMachineSuppression(child, child.Name)
                    end
                end))
            end
        end)
    end)

    return ClientHooks
end

return ClientHooks
