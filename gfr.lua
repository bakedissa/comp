--[[
Title: Teleport & Utility GUI (Merged with Auto Upgrade + Unarmed Hugging Fix)
Description: Unified Teleport, Combat and Utility GUI using Fluent.
Author: Gemini (merged & patched)
Notes: Adds Auto Upgrade Equipped Weapon, robust hitboxdrthfyhfdjgdfhrdfhdfhdfhfdghhfdhfd discovery, and unarmed hugging logic.
]]


-- Load Fluent library and addons
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()


-- Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")


-- Wait for crucial folders
local CharactersFolder = Workspace:WaitForChild("Characters")


-- Create the main GUI Window
local Window = Fluent:CreateWindow({
Title = "Utility GUI",
SubTitle = "v1.4 (Merged)",
TabWidth = 160,
Size = UDim2.fromOffset(580, 520),
Acrylic = true,
Theme = "Dark",
MinimizeKey = Enum.KeyCode.RightControl
})


-- Add Tabs to the Window
local Tabs = {
Automation = Window:AddTab({ Title = "Automation", Icon = "bot" }),
Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}


-- Centralized options table from Fluent
local Options = Fluent.Options


-- ========================================================================
-- Script-wide variables
-- ========================================================================
local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local heartbeatConnection = nil
local killConnection = nil
local autoUpgradeConnection = nil


-- Remotes and Values
local skipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipVoteRequest")
local purchaseWeaponUpgrade = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PurchaseWeaponUpgrade")
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")


-- State
local isAlive = false
local hasTeleportedThisLife = false


-- Boundary clamp (X/Z only matter, Y ignored)
local SAFE_MIN = Vector3.new(-25, -math.huge, -26)
local SAFE_MAX = Vector3.new(27, math.huge, 28)
local BOUNDARY_PADDING = 2 -- inward padding to avoid clipping


-- Debug print helper
local function debugAction(tag, msg)
print(string.format("[%s] %s", tag, tostring(msg)))
end


-- Reset teleport state
local function resetTeleportState()
hasTeleportedThisLife = false
end


-- Team check
local function onSameTeam(player1, player2)
if not player1 or not player2 or not player1:FindFirstChild("Stats") or not player2:FindFirstChild("Stats") then return false end
local team1Val = player1.Stats:FindFirstChild("Team")
local team2Val = player2.Stats:FindFirstChild("Team")
if not team1Val or not team2Val then return false end
if team1Val.Value == "FFA" or team2Val.Value == "FFA" then return false end
return team1Val.Value == team2Val.Value
end


-- Juggernaut check
local function isJuggernaut()
if not localPlayer:FindFirstChild("Stats") then return false end
local hunterValue = localPlayer.Stats:FindFirstChild("Hunter")
if not hunterValue then return false end
end)

-- Automation Tab: Teleport + Gamemode skip
Tabs.Automation:AddParagraph({ Title = "Teleportation", Content = "Enable/disable teleport and select a target." })
local teleportToggle = Tabs.Automation:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })

Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
local ALL_GAMEMODES = {"Teams","Infection","FFA","ColorWar","TeamVampire","CornerDomination","MultiJuggernauts","LastStand","TugOfWar","Squads","Duos","DuosLastStand"}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", { Title = "Wanted Gamemodes", Values = ALL_GAMEMODES, Multi = true, Default = {"FFA","Teams","Infection"} })

-- Combat Tab: Hitboxes, Skip shield, Kill controls
Tabs.Combat:AddParagraph({ Title = "Combat Utilities", Content = "Options for combat targeting & visualization." })
local showHitboxesToggle = Tabs.Combat:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
local skipShieldToggle = Tabs.Combat:AddToggle("SkipShieldUsers", { Title = "Skip Shield Users", Default = false })
local killAllToggle = Tabs.Combat:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
local killPlayersToggle = Tabs.Combat:AddToggle("KillPlayers", { Title = "Kill Specific Player(s)", Default = false })
local killPlayersDropdown = Tabs.Combat:AddDropdown("KillTargets", { Title = "Select Targets", Values = {"None"}, Multi = true, Default = {} })

-- NEW: Auto-upgrade equipped weapon
local autoUpgradeToggle = Tabs.Combat:AddToggle("AutoUpgradeEquippedWeapon", { Title = "Auto Upgrade Equipped Weapon", Default = false })

-- Settings Tab: FPS and Save/Interface manager wiring (restored)
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "60", Numeric = true, Finished = true })

local function updateFpsCap()
    if Options.FpsCapEnabled.Value then
        local cap = tonumber(Options.FpsCapValue.Value) or 60
        -- setfpscap may not exist on all exploit environments; pcall for safety
        pcall(function() setfpscap(cap) end)
        debugAction("fps", "FPS cap set to " .. tostring(cap))
    else
        pcall(function() setfpscap(999) end)
        debugAction("fps", "FPS cap disabled")
    end
end
fpsToggle:OnChanged(updateFpsCap)
fpsInput:OnChanged(updateFpsCap)

-- ========================================================================
-- Auto-upgrade logic
-- ========================================================================
local function autoUpgradeTick()
    if not purchaseWeaponUpgrade then return end
    if not localPlayer or not localPlayer.Character or not localPlayer:FindFirstChild("Stats") then return end
    local weaponName = getEquippedWeaponName()
    if not weaponName or weaponName == "" then return end

    -- do not try to upgrade unarmed
    if weaponName == "Unarmed" then return end

    -- upgradeLevel doesn't seem to matter, using 1 for calls
    pcall(function()
        purchaseWeaponUpgrade:InvokeServer(weaponName, 1)
        debugAction("upgrade", "Invoked upgrade for " .. weaponName)
    end)
end

local function startAutoUpgrade()
    if autoUpgradeConnection then return end
    autoUpgradeConnection = RunService.Heartbeat:Connect(function()
        -- run every ~15 heartbeats to avoid spam; simple counter approach
        if not autoUpgradeConnection._counter then autoUpgradeConnection._counter = 0 end
        autoUpgradeConnection._counter = autoUpgradeConnection._counter + 1
        if autoUpgradeConnection._counter >= 15 then
            autoUpgradeConnection._counter = 0
            pcall(autoUpgradeTick)
        end
    end)
    debugAction("system", "Auto-upgrade started")
end

local function stopAutoUpgrade()
    if autoUpgradeConnection then
        autoUpgradeConnection:Disconnect()
        autoUpgradeConnection = nil
        debugAction("system", "Auto-upgrade stopped")
    end
end

-- Wiring for auto-upgrade toggle
autoUpgradeToggle:OnChanged(function()
    if Options.AutoUpgradeEquippedWeapon.Value then
        startAutoUpgrade()
        Fluent:Notify({ Title = "Auto Upgrade", Content = "Auto upgrade enabled.", Duration = 2 })
    else
        stopAutoUpgrade()
        Fluent:Notify({ Title = "Auto Upgrade", Content = "Auto upgrade disabled.", Duration = 2 })
    end
end)

-- ========================================================================
-- Event Handling & Initialization
-- ========================================================================

-- Update player dropdown lists
local function updatePlayerLists()
    local singleSelectNames = {"None"}
    local multiSelectNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(singleSelectNames, player.Name)
            table.insert(multiSelectNames, player.Name)
        end
    end
    playerDropdown:SetValues(singleSelectNames)
    killPlayersDropdown:SetValues(multiSelectNames)

    if Options.TargetPlayer and not table.find(singleSelectNames, Options.TargetPlayer.Value) then
        playerDropdown:SetValue("None")
    end
end

Players.PlayerAdded:Connect(updatePlayerLists)
Players.PlayerRemoving:Connect(function(player)
    updatePlayerLists()
    if player == targetPlayer then stopTeleporting() end
end)

-- Alive tracking
local function hookAlive()
    local aliveValue = localPlayer:WaitForChild("Alive")
    local function updateAliveStatus(newStatus)
        isAlive = newStatus
        if isAlive then
            resetTeleportState()
            debugAction("life", "LocalPlayer is now ALIVE")
        else
            debugAction("life", "LocalPlayer is now DEAD")
        end
    end
    -- connect changes safely
    aliveValue.Changed:Connect(updateAliveStatus)
    updateAliveStatus(aliveValue.Value)
end

localPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    hookAlive()
    debugAction("system", "LocalPlayer respawned, reset state")
end)

-- Teleportation controls wiring (use start/stop functions)
teleportToggle:OnChanged(function()
    if Options.TeleportEnabled.Value then
        startTeleporting()
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation enabled.", Duration = 2 })
    else
        stopTeleporting()
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation disabled.", Duration = 2 })
    end
end)

playerDropdown:OnChanged(function()
    -- restart teleport loop if enabled
    if Options.TeleportEnabled.Value and Options.TargetPlayer.Value ~= "None" then
        startTeleporting()
    else
        stopTeleporting()
    end
end)

-- Gamemode skip wiring
autoSkipToggle:OnChanged(function()
    if Options.AutoSkipEnabled.Value then
        handleGamemodeSkip()
    end
end)
wantedGamesDropdown:OnChanged(handleGamemodeSkip)
gameModeValue.Changed:Connect(handleGamemodeSkip)

-- Hitbox toggle wiring
showHitboxesToggle:OnChanged(function()
    if Options.ShowHitboxes.Value then
        if not hitboxConnection then
            hitboxConnection = RunService.Heartbeat:Connect(updateAllHitboxVisuals)
            debugAction("hitbox", "Hitbox visuals enabled")
        end
    else
        if hitboxConnection then
            hitboxConnection:Disconnect()
            hitboxConnection = nil
            revertAllHitboxVisuals()
            debugAction("hitbox", "Hitbox visuals disabled")
        end
    end
end)

-- Skip shield toggle: no extra wiring required (isAttackable reads Options.SkipShieldUsers.Value)

-- Kill loop master control
local function updateKillLoopState()
    local killAllEnabled = Options.KillAllPlayers and Options.KillAllPlayers.Value
    local killSpecificEnabled = Options.KillPlayers and Options.KillPlayers.Value
    local shouldBeRunning = killAllEnabled or killSpecificEnabled
    if shouldBeRunning and not killConnection then
        killConnection = RunService.Heartbeat:Connect(function() pcall(killLoop) end)
        debugAction("system", "Kill loop started")
    elseif not shouldBeRunning and killConnection then
        killConnection:Disconnect()
        killConnection = nil
        debugAction("system", "Kill loop stopped")
    end
end
killAllToggle:OnChanged(updateKillLoopState)
killPlayersToggle:OnChanged(updateKillLoopState)
killPlayersDropdown:OnChanged(updateKillLoopState)

-- Initial setup calls
hookAlive()
updatePlayerLists()
task.wait(1)
handleGamemodeSkip()
updateFpsCap()

-- Ensure auto-upgrade follow saved option on startup
if Options.AutoUpgradeEquippedWeapon and Options.AutoUpgradeEquippedWeapon.Value then
    startAutoUpgrade()
end

-- ========================================================================
-- Save Manager & Interface Manager Setup
-- ========================================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
-- ignore these so dropdown selections don't save to index order messily
SaveManager:SetIgnoreIndexes({ "TargetPlayer", "KillTargets" })

InterfaceManager:SetFolder("FluentUtility")
SaveManager:SetFolder("FluentUtility/Config")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent GUI",
    Content = "The script has been loaded successfully.",
    SubContent = "Press Right Ctrl to minimize.",
    Duration = 6
})

SaveManager:LoadAutoloadConfig()
