-- src/UI/Tabs/FarmTab.lua
-- Tab 1: Auto Farm (Tapping, Rebirthing & Pet Management)

local FarmTab = {}

function FarmTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local Svc = ctx.Services
    local ConfigManager = ctx.ConfigManager
    local AutoFarmState = ctx.States.AutoFarm
    local safeFire = ctx.Utils.safeFire
    local safeNotify = UI.safeNotify
    local createBoundToggle = UI.createBoundToggle

    UI.FarmTab = Window:CreateTab({ name = "Auto Farm", icon = 93364949241311 })
    UI.FarmTab:CreateSection({ name = "Clicking & Taps" })

    UI.AutoTapToggle = createBoundToggle(UI.FarmTab, {
        name = "Auto Tap (Fast)",
        flag = "AutoTap",
        description = "Automatically taps at the maximum safe server rate (~13.3 taps/s)",
        value = false,
    }, function() return AutoFarmState.AutoTap end, function(v) AutoFarmState.AutoTap = v end)

    createBoundToggle(UI.FarmTab, {
        name = "In-Game Auto Clicker",
        flag = "AutoClicker",
        description = "Toggles the official built-in game autoclicker",
        value = false,
    }, function() return AutoFarmState.AutoClicker end, function(v) AutoFarmState.AutoClicker = v end, function(val)
        safeFire(Svc.AutoClickService, "RE", "AutoClickRequested", val)
    end)

    UI.FarmTab:CreateSection({ name = "Rebirth" })

    local rebirthOptions = {
        "Best Affordable",
        "Index 1 (+1)",
        "Index 2 (+5)",
        "Index 3 (+25)",
        "Index 4 (+125)",
        "Index 5 (+600)",
        "Index 6 (+3k)",
        "Index 7 (+15k)",
        "Index 8 (+75k)",
        "Index 9 (+400k)",
        "Index 10 (+2M)"
    }

    UI.RebirthDropdown = UI.FarmTab:CreateDropdown({
        name = "Rebirth Target",
        flag = "RebirthMode",
        description = "Select rebirth tier or choose Best Affordable",
        options = rebirthOptions,
        value = "Best Affordable",
        callback = function(selected)
            if type(selected) == "table" and selected[1] then
                AutoFarmState.RebirthMode = selected[1]
            elseif type(selected) == "string" then
                AutoFarmState.RebirthMode = selected
            end
            ConfigManager:MarkDirty()
        end
    })
    ConfigManager:Bind("RebirthMode", UI.RebirthDropdown, function() return AutoFarmState.RebirthMode end, function(v) AutoFarmState.RebirthMode = v end)

    UI.AutoRebirthToggle = createBoundToggle(UI.FarmTab, {
        name = "Auto Rebirth",
        flag = "AutoRebirth",
        description = "Instantly rebirths whenever you meet coin requirements",
        value = false,
    }, function() return AutoFarmState.AutoRebirth end, function(v) AutoFarmState.AutoRebirth = v end)

    UI.FarmTab:CreateSection({ name = "Pet Management" })

    createBoundToggle(UI.FarmTab, {
        name = "Auto Equip Best Pets",
        flag = "AutoEquipBest",
        description = "Continuously keeps your strongest pets equipped",
        value = false,
    }, function() return AutoFarmState.AutoEquipBest end, function(v) AutoFarmState.AutoEquipBest = v end)

    createBoundToggle(UI.FarmTab, {
        name = "Auto Clean Trash Pets (Auto Sell)",
        flag = "AutoCleanTrash",
        description = "Safely deletes excess normal trash duplicates on interval (never touches Equipped, Locked, Secrets, Mythics, Enchanted, or Expedition pets)",
        value = false,
    }, function() return AutoFarmState.AutoCleanTrash end, function(v) AutoFarmState.AutoCleanTrash = v end)

    UI.FarmTab:CreateButton({
        name = "Equip Best Now",
        callback = function()
            if ctx.API.equipBestPets and ctx.API.equipBestPets() then
                safeNotify({ title = "Pets", content = "Equipped best pets!" })
            end
        end
    })

    UI.FarmTab:CreateButton({
        name = "Clean Trash Pets Now (Safe Filter)",
        callback = function()
            local cleaned = ctx.API.cleanTrashPets and ctx.API.cleanTrashPets() or 0
            safeNotify({
                title = "Pet Cleaner",
                content = (cleaned > 0) and ("Cleaned " .. tostring(cleaned) .. " excess trash pet(s)!") or "No safe excess trash pets to clean right now."
            })
        end
    })

    UI.FarmTab:CreateButton({
        name = "Unequip All Pets",
        callback = function()
            if safeFire(Svc.PetRemoteService, "RE", "PetActionRequested", { Action = "UnequipAll" }) then
                safeNotify({ title = "Pets", content = "Unequipped all pets." })
            end
        end
    })

    return FarmTab
end

return FarmTab
