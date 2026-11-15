# TapSimulatorHub — Modular Architecture & GitHub Deployment

Modülerleştirilmiş **Tap Simulator Hub** projesi (`CastleUpdate-Audited`).  
Tekil monolit dosya olan `TapSimulatorHub.lua` dosyasının tüm algoritmaları, UI bileşenleri, AI Kaitun motoru, Secret Pet dedektörü, Discord Webhook göndericisi, CPU Saver ve Persistence (`TapSimHub/config.json`) sistemi sıfır kayıp ilkesiyle ayrıştırılmıştır.

---

## Tek Satır Kullanım (GitHub RAW Loader)

Depoyu GitHub'a yükledikten sonra `Loader.lua` içindeki varsayılan repo bilgilerini güncelleyin veya çalışma zamanında `_RLW_LoaderConfig` ile geçersiz kılın:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<KULLANICI>/<REPO>/main/Loader.lua"))()
```

### İsteğe Bağlı Çalışma Zamanı Yapılandırması

```lua
getgenv()._RLW_LoaderConfig = {
    Owner = "KULLANICI_ADINIZ",
    Repo = "TapSimulatorHub",
    Branch = "main",
    CacheBust = false,       -- Geliştirme sırasında önbelleği aşmak için true yapılabilir
    UseMemoryCache = false,  -- Tekrar çalıştırmalarda indirilmiş kaynakları bellekten oku
    Retries = 3,             -- HTTP başarısızlıklarında yeniden deneme sayısı
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/KULLANICI_ADINIZ/TapSimulatorHub/main/Loader.lua"))()
```

---

## Klasör Yapısı & Modül Haritası

```text
TapSimulatorHub/
├── Loader.lua                          # Tekil giriş noktası (HTTP -> Compile -> Cache -> DI Init -> Start)
├── Manifest.lua                        # Bağımlılık sıralı modül listesi & sürüm bilgisi
├── README.md                           # Kurulum & mimari dokümantasyonu
└── src/
    ├── Core/
    │   ├── Context.lua                 # Merkezi DI Container (ctx), CONFIG, States, W2 Bounds
    │   ├── Lifecycle.lua               # Generation Token (_RLW_ScriptGen), Cleanup, Connection tracking & Anti-AFK
    │   ├── Services.lua                # 47 RemoteService & 41 Client/Shared Controller keşfi
    │   └── Utils.lua                   # Defensive pcall/debug log, safeFire/safeInvoke, formatCompact
    ├── Data/
    │   └── Catalogs.lua                # Dinamik Egg, Secret, Ada listesi & MachinePad keşfi
    ├── Integrations/
    │   └── ClientHooks.lua             # Hatch/Secret cutscene skip, Portal/Machine UI bastırma (+ cleanup restore)
    ├── Services/
    │   ├── ConfigManager.lua           # JSON Persistence (TapSimHub/config.json), Bind, SyncUI, Reset
    │   └── PlayerData.lua              # Coins, Gems, Rebirths, Storage, x8 Pass, Live Hatch Speed, EquipBest
    ├── Systems/
    │   ├── Automation/
    │   │   ├── FarmWorkers.lua         # Auto Tap (~13.3/s upvalue patch) & Auto Rebirth worker'ları
    │   │   ├── LuckyDucky.lua          # Safe 1.45s Lucky Ducky otomatik yakalama
    │   │   ├── PlayerMovement.lua      # WalkSpeed/JumpPower kilidi, InfJump, Noclip, Anti-Void
    │   │   └── RewardsManager.lua      # Chests, Shiny Stars, Smart Potions, Quests, Daily Rewards
    │   ├── Optimization/
    │   │   └── CpuSaver.lua            # Whitelist korumalı bölgesel Map culling, Lighting & FPS restore
    │   ├── Pets/
    │   │   ├── CastleMachines.lua      # Potion Machine, HoneyPot, Glitched Egg/Evo, Lucky Egg, Expeditions, Events
    │   │   ├── EggController.lua       # Egg stand CFrame raycast, goToEgg, Auto Hatch worker & live speed UI
    │   │   ├── MachineEvolution.lua    # Golden (6x) & Diamond (5x) evrim otomasyonu & pad doğrulama
    │   │   └── PetInventory.lua        # Koruma filtresi, frontier species & Auto Trash / Auto Equip Best
    │   ├── Progression/
    │   │   ├── KaitunEngine.lua        # AI Kaitun otonom karar döngüsü
    │   │   └── KaitunTelemetry.lua     # VelocityTracker, Stage detection, Combinatorial Egg EV, ProgressionScore
    │   ├── Secrets/
    │   │   ├── SecretDetector.lua      # 4 kanallı Secret algılama + ID/Signature deduplication
    │   │   └── WebhookSender.lua       # Discord Webhook embed oluşturucu + HTTP retry/rate-limit yönetimi
    │   └── Worlds/
    │       ├── IslandManager.lua       # Drawbridge, World 1 / World 2 / Medieval Castle seyahat & kilit açma
    │       └── UpgradeManager.lua      # Gem Skill Tree, Physical Upgrades & Winter Retained Upgrades
    └── UI/
        ├── WindowManager.lua           # Rayfield Gen2 PlayerGui izolasyonu & ortak widget builder'lar
        ├── HubExports.lua              # Startup Config Load, Events refresh & _RLW_Hub global API
        └── Tabs/
            ├── KaitunTab.lua           # AI Kaitun kontrol & telemetri sekmesi
            ├── OptimizationTab.lua     # CPU Saver & Emergency Restore sekmesi
            ├── FarmTab.lua             # Auto Tap, Rebirth & Pet yönetimi sekmesi
            ├── EggTab.lua              # Yumurtalar, Adaptive Speed & Animasyon skip sekmesi
            ├── UpgradeTab.lua          # Gem & Fiziksel yükseltmeler sekmesi
            ├── IslandTab.lua           # Drawbridge, World 2 & Ada ışınlanma sekmesi
            ├── RewardTab.lua           # Ödüller, Yıldızlar & Promo kodlar sekmesi
            ├── PlayerTab.lua           # Hız/Zıplama/Noclip sekmesi
            ├── EventsTab.lua           # Castle update makineleri & Global Eventler sekmesi
            ├── WebhookTab.lua          # Secret filtreleri & Discord Webhook test sekmesi
            └── ConfigTab.lua           # Kalıcı config, Hotkey'ler & Live Diagnostics sekmesi
```

---

## GitHub'a Yükleme (Windows)

```powershell
cd C:\Users\RLW\.gemini\antigravity\scratch\TapSimulatorHub
git init
git add .
git commit -m "Modular refactor of TapSimulatorHub"
git branch -M main
git remote add origin https://github.com/<KULLANICI>/TapSimulatorHub.git
git push -u origin main
```

Yükledikten sonra `Loader.lua` başındaki `DEFAULT_GITHUB_OWNER` değerini kendi kullanıcı adınızla değiştirin ve pushlayın.
