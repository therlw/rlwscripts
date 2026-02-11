-- AYARLAR
_G.AutoSpin = true 
local Spin_Interval = 1.0 -- Animasyonsuz hız (0.1 saniye)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Modules.Network)

-- 1. ADIM: Mevcut animasyon debouncesini (engelini) bypass et
-- Kodunda v_u_15 degiskeni "zaten donuyor" hatasi verdirir.
-- Biz bunu manipule etmek yerine dogrudan Remote'u cagiracagiz.

print("Animasyonsuz hizli cark aktif edildi.")

-- 2. ADIM: Senkronize ve Hizli Dongu
task.spawn(function()
    while _G.AutoSpin do
        -- InvokeServer sunucudan ödül bilgisini alana kadar bekler
        -- Ekranda hicbir sey donmez, ödüller direkt envantere gelir.
        local success, result = pcall(function()
            return Network:InvokeServer("SpinWheel", "ElectricSpinWheel")
        end)

        if success and result then
            -- result[1] kazandığın ödülü, result[2] kalan spin sayısını tutar
            print("Odul Kazandiniz! Kalan Spin: " .. tostring(result[2] or "0"))
            task.wait(Spin_Interval) 
        else
            -- Spin bittiyse veya sunucu hata verdiyse biraz duraksar.
            warn("Islem basarisiz (Spin bitmis olabilir). 2 saniye bekleniyor...")
            task.wait(2)
        end
    end
    print("Otomatik cark durduruldu.")
end)
