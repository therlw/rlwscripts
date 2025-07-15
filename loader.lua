-- SCRIPT YÜKLEYİCİ
local function loadScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/therlw/rlwscripts/refs/heads/main/rlw.lua",true))()
    end)
    
    if not success then
        warn("❌ Script yüklenemedi: "..tostring(err))
        return false
    end
    return true
end

-- ANA YÜKLEYİCİ
if loadScript() then
    print("✅ Script başarıyla yüklendi!")
    
    -- KONTROL MESAJI
    print("\n⚙️ Aktif Ayarlar:")
    print("- Hedef Pet:", _G.targetPetName)
    print("- Max Fiyat:", _G.maxCost)
    print("- Tarama Hızı:", _G.scanDelay.."s")
    print("- Webhook:", _G.webhookEnabled and "Açık" or "Kapalı")
else
    warn("❌ Script başlatılamadı!")
end
