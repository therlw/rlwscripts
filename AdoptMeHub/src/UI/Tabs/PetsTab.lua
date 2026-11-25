-- src/UI/Tabs/PetsTab.lua
-- Auto-Neon, Mega Neon, Best Pet Equip, Storage Transfer & Client-Side Visual Pet Spawner

local PetsTab = {}

function PetsTab.Init(ctx)
    local Window = ctx.Window
    local UI = ctx.UI
    local States = ctx.States
    local Pets = ctx.API.Pets
    local Lifecycle = ctx.Lifecycle

    local Tab = Window:CreateTab({
        name = "Pet & Envanter",
        icon = 93364949241311,
    })
    UI.PetsTab = Tab

    Tab:CreateSection({ name = "Otomatik Birleştirme (Neon & Mega Neon)" })

    local petStatus = Tab:CreateText({
        name = "Pet Durumu",
        text = "Durum: Hazır",
    })

    Lifecycle.SpawnLoop("PetsTabStatus", 1.5, function()
        if petStatus and petStatus.Set then
            pcall(function()
                petStatus:Set(string.format("%s | Neon Yapılan: %d", tostring(ctx.Runtime.Status.Pets), ctx.Runtime.Telemetry.NeonsFused))
            end)
        end
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Neon Birleştir (Auto-Neon)",
        flag = "AutoNeon",
        value = States.Pets.AutoNeon,
        description = "4 adet Full Grown aynı pet birikince otomatik birleştirir & animasyonu atlar",
    }, function() return States.Pets.AutoNeon end, function(v)
        States.Pets.AutoNeon = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Otomatik Mega Neon Birleştir",
        flag = "AutoMegaNeon",
        value = States.Pets.AutoMegaNeon,
    }, function() return States.Pets.AutoMegaNeon end, function(v)
        States.Pets.AutoMegaNeon = (v == true)
    end)

    Tab:CreateButton({
        name = "Şimdi Neon / Mega Kontrolü Yap",
        callback = function()
            local cnt = Pets.RunNeonFusion(true)
            UI.safeNotify({
                title = "Neon Birleştirme",
                content = cnt > 0 and (tostring(cnt) .. " birleştirme yapıldı!") or "Birleştirmeye hazır 4 adet Full Grown pet yok.",
                duration = 3,
            })
        end,
    })

    Tab:CreateSection({ name = "Kuşanma & Depolama (Pet Storage)" })

    UI.createBoundToggle(Tab, {
        name = "Boşta Kaldığında En İyi Peti Kuşan",
        flag = "AutoEquipBest",
        value = States.Pets.AutoEquipBest,
    }, function() return States.Pets.AutoEquipBest end, function(v)
        States.Pets.AutoEquipBest = (v == true)
    end)

    Tab:CreateButton({
        name = "En İyi Peti Şimdi Kuşan (Equip Best)",
        callback = function()
            local ok, best = Pets.EquipBestPet()
            UI.safeNotify({
                title = "Pet Kuşanma",
                content = ok and ("Kuşanıldı: " .. tostring(best and best.kind)) or "Envanterde kuşanılacak pet yok.",
                duration = 2.5,
            })
        end,
    })

    UI.createBoundSlider(Tab, {
        name = "Tür Başına Envanterde Tutulacak Sayı",
        flag = "KeepEquippedCount",
        range = { 1, 20 },
        increment = 1,
        value = States.Pets.KeepEquippedCount,
        suffix = " Pet",
    }, function() return States.Pets.KeepEquippedCount end, function(v)
        States.Pets.KeepEquippedCount = v
    end)

    Tab:CreateButton({
        name = "Fazlalık Petleri Depolamaya (Storage) Aktar",
        callback = function()
            local moved, msg = Pets.TransferExcessToStorage(States.Pets.KeepEquippedCount)
            UI.safeNotify({
                title = "Pet Storage",
                content = tostring(moved) .. " pet: " .. tostring(msg),
                duration = 3,
            })
        end,
    })

    Tab:CreateSection({ name = "Görsel Pet Oluşturucu (Sadece Client / Video Amaçlı)" })

    UI.createBoundDropdown(Tab, {
        name = "Hazır Pet Seçimi",
        flag = "VisualPetKind",
        options = Pets.GetSamplePetKinds(),
        value = States.Pets.VisualPetKind,
    }, function() return States.Pets.VisualPetKind end, function(v)
        States.Pets.VisualPetKind = v
    end)

    UI.createBoundInput(Tab, {
        name = "Veya Özel Pet Kind Yaz",
        flag = "VisualPetKindCustom",
        placeholder = "Örn: shadow_dragon, frost_dragon, giraffe",
        value = States.Pets.VisualPetKind,
    }, function() return States.Pets.VisualPetKind end, function(v)
        if v and v ~= "" then
            States.Pets.VisualPetKind = v
        end
    end)

    UI.createBoundDropdown(Tab, {
        name = "Görünüm Modu (Normal / Neon / Mega)",
        flag = "VisualPetNeon",
        options = { "Normal", "Neon", "Mega Neon" },
        value = States.Pets.VisualPetNeon,
    }, function() return States.Pets.VisualPetNeon end, function(v)
        States.Pets.VisualPetNeon = v
    end)

    UI.createBoundToggle(Tab, {
        name = "Fly (F) Etiketi",
        flag = "VisualPetFly",
        value = States.Pets.VisualPetFly,
    }, function() return States.Pets.VisualPetFly end, function(v)
        States.Pets.VisualPetFly = (v == true)
    end)

    UI.createBoundToggle(Tab, {
        name = "Ride (R) Etiketi",
        flag = "VisualPetRide",
        value = States.Pets.VisualPetRide,
    }, function() return States.Pets.VisualPetRide end, function(v)
        States.Pets.VisualPetRide = (v == true)
    end)

    Tab:CreateButton({
        name = "Görsel Pet Oluştur (Client-Side)",
        callback = function()
            local ok, name = Pets.SpawnVisualPet(
                States.Pets.VisualPetKind,
                States.Pets.VisualPetNeon,
                States.Pets.VisualPetRide,
                States.Pets.VisualPetFly
            )
            UI.safeNotify({
                title = "Görsel Pet Spawner",
                content = ok and (tostring(name) .. " yanında görsel olarak oluşturuldu (takas edilemez).") or tostring(name),
                duration = 3,
            })
        end,
    })

    Tab:CreateButton({
        name = "Tüm Görsel Petleri Temizle",
        callback = function()
            Pets.ClearVisualPets()
        end,
    })

    return PetsTab
end

return PetsTab
