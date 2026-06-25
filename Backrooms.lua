getgenv().BackroomsBaseUrl = "https://raw.githubusercontent.com/therlw/rlwscripts/refs/heads/main/BackroomsModules/"

local success, err = pcall(function()
    loadstring(game:HttpGet(getgenv().BackroomsBaseUrl .. "Main.lua"))()
end)

if not success then
    warn("Failed to load Backrooms modules: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "[BOT-ERROR] Script failed to load! Please check your network or executor.",
            Color = Color3.fromRGB(255, 80, 80)
        })
    end)
end
