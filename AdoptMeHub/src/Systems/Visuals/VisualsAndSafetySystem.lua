-- src/Systems/Visuals/VisualsAndSafetySystem.lua
-- Event/Object/Player ESP, Ultra FPS Boost, 3D Render Disable + AFK Overlay, Anti-AFK & Auto-Reconnect

local VisualsAndSafetySystem = {}

function VisualsAndSafetySystem.Init(ctx)
    local States = ctx.States
    local Lifecycle = ctx.Lifecycle
    local Utils = ctx.Utils
    local Bridge = ctx.Bridge
    local Players = ctx.Roblox.Players
    local RunService = ctx.Roblox.RunService
    local VirtualUser = ctx.Roblox.VirtualUser
    local GuiService = ctx.Roblox.GuiService
    local TeleportService = ctx.Roblox.TeleportService

    local V = {
        _espFolder = nil,
        _overlayGui = nil,
        _overlayLabels = {},
        _fpsApplied = false,
    }

    local function getEspFolder()
        if V._espFolder and V._espFolder.Parent then
            return V._espFolder
        end
        local lp = Players.LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local old = pg:FindFirstChild("RLW_AdoptMe_ESP")
        if old then old:Destroy() end
        local f = Instance.new("Folder")
        f.Name = "RLW_AdoptMe_ESP"
        f.Parent = pg
        V._espFolder = f
        return f
    end

    function V.ClearESP()
        if V._espFolder then
            V._espFolder:ClearAllChildren()
        end
    end

    local function createMarker(adornee, tagText, color)
        local folder = getEspFolder()
        if not folder or not adornee then return end

        local hl = Instance.new("Highlight")
        hl.Adornee = adornee
        hl.FillColor = color
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.65
        hl.Parent = folder

        local bb = Instance.new("BillboardGui")
        bb.Adornee = adornee
        bb.Size = UDim2.new(0, 140, 0, 32)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        bb.Parent = folder

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0.2
        lbl.Text = tagText
        lbl.Parent = bb
    end

    function V.RefreshESP()
        V.ClearESP()
        if not States.Visuals.EventObjectESP and not States.Visuals.PlayerPetESP then
            return
        end

        if States.Visuals.PlayerPetESP then
            local lp = Players.LocalPlayer
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and plr.Character then
                    createMarker(plr.Character, plr.DisplayName or plr.Name, Color3.fromRGB(110, 220, 255))
                end
            end
        end

        if States.Visuals.EventObjectESP then
            local interiors = workspace:FindFirstChild("Interiors")
            if interiors then
                for _, d in ipairs(interiors:GetDescendants()) do
                    if d:IsA("Model") or d:IsA("BasePart") then
                        local ln = string.lower(d.Name)
                        if string.find(ln, "bottle", 1, true) or string.find(ln, "lure", 1, true) or string.find(ln, "egg", 1, true) or string.find(ln, "lightning", 1, true) then
                            createMarker(d, d.Name, Color3.fromRGB(255, 220, 80))
                        end
                    end
                end
            end
        end
    end

    -- Ultra FPS Booster
    function V.ApplyUltraFPSBoost(enabled)
        if not enabled then return end
        V._fpsApplied = true
        pcall(function()
            local Lighting = game:GetService("Lighting")
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("PostEffect") or eff:IsA("BlurEffect") or eff:IsA("SunRaysEffect") or eff:IsA("BloomEffect") then
                    eff.Enabled = false
                end
            end
        end)
        pcall(function()
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Smoke") or desc:IsA("Fire") or desc:IsA("Sparkles") then
                    desc.Enabled = false
                elseif desc:IsA("BasePart") then
                    desc.CastShadow = false
                end
            end
        end)
    end

    -- 3D Rendering Toggle + Dark AFK Telemetry Overlay
    function V.Set3DRenderDisabled(disabled)
        pcall(function()
            RunService:Set3dRenderingEnabled(not disabled)
        end)
    end

    function V.UpdateAFKOverlay(show)
        local lp = Players.LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        if not pg then return end

        if not show then
            if V._overlayGui then
                V._overlayGui.Enabled = false
            end
            return
        end

        if not V._overlayGui or not V._overlayGui.Parent then
            local sg = Instance.new("ScreenGui")
            sg.Name = "RLW_AdoptMe_AFKOverlay"
            sg.DisplayOrder = 50
            sg.IgnoreGuiInset = true
            sg.ResetOnSpawn = false
            sg.Parent = pg

            local bg = Instance.new("Frame")
            bg.Size = UDim2.fromScale(1, 1)
            bg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
            bg.BackgroundTransparency = 0.08
            bg.Parent = sg

            local card = Instance.new("Frame")
            card.Size = UDim2.fromOffset(460, 260)
            card.Position = UDim2.fromScale(0.5, 0.5)
            card.AnchorPoint = Vector2.new(0.5, 0.5)
            card.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
            card.Parent = bg

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = card

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -24, 0, 38)
            title.Position = UDim2.fromOffset(12, 12)
            title.BackgroundTransparency = 1
            title.Font = Enum.Font.GothamBold
            title.TextSize = 20
            title.TextColor3 = Color3.fromRGB(110, 220, 255)
            title.Text = "AdoptMeHub · Ultra AFK Tasarruf Modu"
            title.Parent = card

            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -24, 1, -64)
            info.Position = UDim2.fromOffset(12, 54)
            info.BackgroundTransparency = 1
            info.Font = Enum.Font.Code
            info.TextSize = 15
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.TextYAlignment = Enum.TextYAlignment.Top
            info.TextColor3 = Color3.fromRGB(235, 240, 248)
            info.Text = "Veriler yükleniyor..."
            info.Parent = card

            V._overlayGui = sg
            V._overlayLabels.Info = info
        end

        V._overlayGui.Enabled = true
        if V._overlayLabels.Info then
            local elapsed = math.floor(os.clock() - ctx.Runtime.StartedAt)
            local bucks = Bridge.GetMoney()
            V._overlayLabels.Info.Text = string.format(
                "Bucks: %s (+%s bu oturum)\nTamamlanan Görev: %d | Çatlayan Yumurta: %d\nLure: %d | Neon: %d\nFarm Durumu: %s\nEtkinlik Durumu: %s\nSüre: %ds | Kapatmak için arayüzden kapatın",
                Utils.formatNumber(bucks),
                Utils.formatNumber(ctx.Runtime.Telemetry.BucksEarned),
                ctx.Runtime.Telemetry.TasksCompleted,
                ctx.Runtime.Telemetry.EggsHatched,
                ctx.Runtime.Telemetry.LuresClaimed,
                ctx.Runtime.Telemetry.NeonsFused,
                tostring(ctx.Runtime.Status.Farm),
                tostring(ctx.Runtime.Status.Events),
                elapsed
            )
        end
    end

    -- Anti-AFK (Idled Hook)
    local lp = Players.LocalPlayer
    if lp then
        Lifecycle.TrackConnection(lp.Idled:Connect(function()
            if States.Visuals.AntiAFK then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end))
    end

    -- Auto-Reconnect (GuiService ErrorMessageChanged)
    pcall(function()
        Lifecycle.TrackConnection(GuiService.ErrorMessageChanged:Connect(function(msg)
            if States.Visuals.AutoReconnect and msg and msg ~= "" then
                task.delay(3, function()
                    pcall(function()
                        if #Players:GetPlayers() <= 1 then
                            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
                        else
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
                        end
                    end)
                end)
            end
        end))
    end)

    Lifecycle.AddCleanup(function()
        V.Set3DRenderDisabled(false)
        if V._overlayGui then pcall(function() V._overlayGui:Destroy() end) end
        if V._espFolder then pcall(function() V._espFolder:Destroy() end) end
    end)

    Lifecycle.SpawnLoop("VisualsAndSafety", 1.5, function()
        if States.Visuals.EventObjectESP or States.Visuals.PlayerPetESP then
            V.RefreshESP()
        elseif V._espFolder and #V._espFolder:GetChildren() > 0 then
            V.ClearESP()
        end

        if States.Visuals.UltraFPSBoost and not V._fpsApplied then
            V.ApplyUltraFPSBoost(true)
        end
        V.Set3DRenderDisabled(States.Visuals.Disable3DRender == true)
        V.UpdateAFKOverlay(States.Visuals.ShowAFKOverlay == true)
    end)

    ctx.API.Visuals = V
    return V
end

return VisualsAndSafetySystem
