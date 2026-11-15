-- src/Systems/Secrets/SecretDetector.lua
-- Multi-Source Verified Secret Pet Detection + Smart Deduplication

local SecretDetector = {}

function SecretDetector.Init(ctx)
    local CONFIG = ctx.Config
    local Mod = ctx.Modules
    local LocalPlayer = ctx.Roblox.LocalPlayer
    local SecretPetCatalog = ctx.Catalogs.SecretPetCatalog
    local debugLog = ctx.Utils.debugLog
    local getPlayerData = ctx.API.getPlayerData

    local detector = {
        SeenPetIds = {},
        RecentIdSignatures = {},
        RecentSourcelessSignatures = {},
        BaselineInitialized = false,
        History = {},
        TotalDetected = 0,
    }

    function detector:CaptureBaseline()
        local data = getPlayerData()
        if data and data.Pets and type(data.Pets.Owned) == "table" then
            for id, _ in pairs(data.Pets.Owned) do
                self.SeenPetIds[tostring(id)] = true
            end
        end
        self.BaselineInitialized = true
    end

    function detector:IsSecretRarity(rarity)
        if type(rarity) ~= "string" then return false end
        if string.match(rarity, "^Secret") ~= nil then
            return true
        end
        if CONFIG.Webhook and CONFIG.Webhook.NotifyGodlies and rarity == "Godly" then
            return true
        end
        return false
    end

    function detector:ResolveMetadata(petTable, eggHint)
        local petName = tostring(petTable.Name or petTable.PetName or "Unknown")
        local lowerName = string.lower(petName)
        local catMeta = SecretPetCatalog[lowerName]
        local eggName = eggHint or petTable.Egg or (catMeta and catMeta.Egg) or "Unknown Egg"
        local eggCfg = Mod.LaunchEggConfig and Mod.LaunchEggConfig[eggName]
        local worldName = (eggCfg and eggCfg.World) or (catMeta and catMeta.World) or (function()
            local d = getPlayerData()
            return (d and d.Progression and d.Progression.World) or "Main"
        end)()
        local islandName = (eggCfg and eggCfg.Island) or (catMeta and catMeta.Island) or (function()
            local d = getPlayerData()
            return (d and d.Progression and d.Progression.Island) or "Spawn"
        end)()
        local oneIn = (eggCfg and eggCfg.Secrets and eggCfg.Secrets[petName]) or (catMeta and catMeta.OneIn) or 0
        local tier = petTable.Tier or (petTable.Golden and "Golden") or (petTable.Diamond and "Diamond") or "Normal"
        return {
            Id = petTable.Id and tostring(petTable.Id) or nil,
            Name = petName,
            Rarity = tostring(petTable.Rarity or "Secret"),
            Tier = tostring(tier),
            Shiny = petTable.Shiny == true,
            Egg = tostring(eggName),
            World = (worldName == "TimeRift") and "World 2 (Time Rift)" or "World 1 (Main)",
            Island = tostring(islandName),
            OneIn = tonumber(oneIn) or 0,
            AutoDeleted = petTable.AutoDeleted == true,
        }
    end

    function detector:ProcessCandidate(petTable, sourceName, eggHint, isTest)
        if type(petTable) ~= "table" then return false, "InvalidPetTable" end
        if not self:IsSecretRarity(petTable.Rarity) then
            return false, "NotSecretRarity"
        end

        local meta = self:ResolveMetadata(petTable, eggHint)
        meta.Source = sourceName or "Unknown"
        meta.DetectedAt = os.time()
        meta.IsTest = isTest == true

        local dedupeWindow = (CONFIG.Webhook and tonumber(CONFIG.Webhook.DedupeWindowSeconds)) or 20
        local nowClock = os.clock()
        local sig = string.format("%s|%s|%s|%s|%s",
            string.lower(meta.Name), string.lower(meta.Rarity), string.lower(meta.Tier), tostring(meta.Shiny), string.lower(meta.Egg))

        if not isTest then
            if meta.Id and meta.Id ~= "" then
                if self.SeenPetIds[meta.Id] then
                    debugLog("SecretDetector deduped existing PetId:", meta.Id, meta.Name, sourceName)
                    return false, "DuplicatePetId"
                end
                self.SeenPetIds[meta.Id] = true
                self.RecentIdSignatures[sig] = nowClock
            else
                local lastIdAt = self.RecentIdSignatures[sig]
                local lastNoIdAt = self.RecentSourcelessSignatures[sig]
                if (lastIdAt and (nowClock - lastIdAt) <= dedupeWindow) or (lastNoIdAt and (nowClock - lastNoIdAt) <= dedupeWindow) then
                    debugLog("SecretDetector deduped sourceless signature:", sig, sourceName)
                    return false, "DuplicateSignature"
                end
                self.RecentSourcelessSignatures[sig] = nowClock
            end
        end

        self.TotalDetected = self.TotalDetected + 1
        table.insert(self.History, 1, meta)
        if #self.History > 30 then
            table.remove(self.History)
        end

        if CONFIG.Notifications and CONFIG.Notifications.SecretAlerts then
            pcall(function()
                if ctx.Window and ctx.Window.Notify then
                    ctx.Window:Notify({
                        title = (isTest and "[TEST] " or "") .. "SECRET PET!",
                        content = string.format("%s%s (%s) from %s! [%s]",
                            meta.Shiny and "Shiny " or "", meta.Name, meta.Rarity, meta.Egg, meta.Source),
                        duration = 6,
                    })
                end
            end)
        end

        local shouldWebhook = isTest or (CONFIG.Webhook and CONFIG.Webhook.Enabled and CONFIG.Webhook.NotifySecrets)
        if shouldWebhook and ctx.WebhookSender then
            ctx.WebhookSender:SendSecretAlert(meta, isTest)
        end

        return true, meta
    end

    function detector:HandleHatchPayload(payload, sourceName)
        if type(payload) ~= "table" or payload.Success ~= true then return 0 end
        local detected = 0
        local eggName = payload.Egg
        if type(payload.Pets) == "table" then
            for _, p in ipairs(payload.Pets) do
                if type(p) == "table" and self:IsSecretRarity(p.Rarity) then
                    local ok = self:ProcessCandidate(p, sourceName or "EggHatchResult", eggName, false)
                    if ok then detected = detected + 1 end
                end
            end
        elseif type(payload.Pet) == "table" and self:IsSecretRarity(payload.Pet.Rarity) then
            local ok = self:ProcessCandidate(payload.Pet, sourceName or "EggHatchResult", eggName, false)
            if ok then detected = detected + 1 end
        end
        return detected
    end

    function detector:HandleSystemMessage(msg)
        if not (CONFIG.Webhook and CONFIG.Webhook.SendSystemFallback) then return false end
        local text = nil
        if type(msg) == "string" then
            text = msg
        elseif type(msg) == "table" then
            text = msg.Text or msg.Message or msg.Content or msg.Body
        end
        if type(text) ~= "string" or text == "" then return false end

        local lower = string.lower(text)
        if not string.find(lower, "secret", 1, true) then
            return false
        end

        local pName = LocalPlayer and string.lower(LocalPlayer.Name or "") or ""
        local dName = LocalPlayer and string.lower(LocalPlayer.DisplayName or "") or ""
        local mentionsLocal = (pName ~= "" and string.find(lower, pName, 1, true) ~= nil)
            or (dName ~= "" and string.find(lower, dName, 1, true) ~= nil)
        if not mentionsLocal then
            return false, "OtherPlayerOrNonMatch"
        end

        local matchedMeta = nil
        for lowerPet, meta in pairs(SecretPetCatalog) do
            if string.find(lower, lowerPet, 1, true) then
                matchedMeta = meta
                break
            end
        end
        if not matchedMeta then
            return false, "NoCatalogSecretInMessage"
        end

        return self:ProcessCandidate({
            Name = matchedMeta.Name,
            Rarity = "Secret",
            Tier = string.find(lower, "diamond", 1, true) and "Diamond" or (string.find(lower, "golden", 1, true) and "Golden" or "Normal"),
            Shiny = string.find(lower, "shiny", 1, true) ~= nil,
        }, "MessageServiceFallback", matchedMeta.Egg, false)
    end

    function detector:Simulate(petName, eggName)
        local chosenPet = petName or "Crimson Rose Knight"
        local chosenEgg = eggName or "Royal"
        return self:ProcessCandidate({
            Id = "SIM_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
            Name = chosenPet,
            Rarity = "Secret",
            Tier = "Normal",
            Shiny = false,
        }, "SimulatedTest", chosenEgg, true)
    end

    detector:CaptureBaseline()
    ctx.SecretDetector = detector
    for k, v in pairs(detector) do
        SecretDetector[k] = v
    end
    return detector
end

function SecretDetector.Start(ctx)
    local Svc = ctx.Services
    local Mod = ctx.Modules
    local detector = ctx.SecretDetector
    local trackConnection = ctx.Lifecycle.TrackConnection
    local isCurrentGeneration = ctx.Lifecycle.IsCurrentGeneration

    -- Source 1: EggService HatchResult & ForcedHatchResult listeners
    if Svc.EggService and Svc.EggService:FindFirstChild("RE") then
        local hatchResultRemote = Svc.EggService.RE:FindFirstChild("EggHatchResult")
        if hatchResultRemote then
            pcall(function()
                trackConnection(hatchResultRemote.OnClientEvent:Connect(function(res)
                    if not isCurrentGeneration() then return end
                    if detector and type(res) == "table" and res.Success == true then
                        pcall(function()
                            detector:HandleHatchPayload(res, "EggHatchResult")
                        end)
                    end
                end))
            end)
        end

        local forcedResultRemote = Svc.EggService.RE:FindFirstChild("ForcedHatchResult")
        if forcedResultRemote then
            pcall(function()
                trackConnection(forcedResultRemote.OnClientEvent:Connect(function(res)
                    if not isCurrentGeneration() then return end
                    if detector and type(res) == "table" and res.Success == true then
                        pcall(function()
                            detector:HandleHatchPayload(res, "ForcedHatchResult")
                        end)
                    end
                end))
            end)
        end
    end

    -- Source 2: Replica Inventory Listener (catches Secrets added to Pets.Owned cleanly)
    if Mod.DataController and Mod.DataController.GetReplica then
        pcall(function()
            local rep = Mod.DataController:GetReplica()
            if rep and rep.ListenToNewKey then
                trackConnection(rep:ListenToNewKey({ "Pets", "Owned" }, function(a, b)
                    if not isCurrentGeneration() then return end
                    if not detector then return end
                    local petTbl, petId
                    if type(a) == "table" then
                        petTbl, petId = a, b
                    elseif type(b) == "table" then
                        petTbl, petId = b, a
                    end
                    if type(petTbl) == "table" then
                        local candidate = {
                            Id = petTbl.Id or petId,
                            Name = petTbl.Name,
                            Rarity = petTbl.Rarity,
                            Tier = petTbl.Tier,
                            Shiny = petTbl.Shiny,
                            Egg = petTbl.Egg,
                        }
                        if detector:IsSecretRarity(candidate.Rarity) then
                            pcall(function()
                                detector:ProcessCandidate(candidate, "ReplicaInventory", candidate.Egg, false)
                            end)
                        end
                    end
                end))
            end
        end)
    end

    -- Source 4: System MessageService Fallback Listener (Local Player only)
    if Svc.MessageService and Svc.MessageService:FindFirstChild("RE") and Svc.MessageService.RE:FindFirstChild("MessageReceived") then
        pcall(function()
            trackConnection(Svc.MessageService.RE.MessageReceived.OnClientEvent:Connect(function(msg)
                if not isCurrentGeneration() then return end
                if detector then
                    pcall(function()
                        detector:HandleSystemMessage(msg)
                    end)
                end
            end))
        end)
    end
end

return SecretDetector
