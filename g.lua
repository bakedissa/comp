--[[
    Title: Teleport & Utility GUI
    Description: An interactive GUI for the teleport script using the Fluent library.
    Author: Gemini
]]

-- Load Fluent library and addons
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create the main GUI Window
local Window = Fluent:CreateWindow({
    Title = "Utility GUI",
    SubTitle = "v1.0",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Add Tabs to the Window
local Tabs = {
    Main = Window:AddTab({ Title = "Teleport", Icon = "move-3d" }),
    Automation = Window:AddTab({ Title = "Automation", Icon = "bot" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Centralized options table from Fluent
local Options = Fluent.Options

-- ========================================================================
-- Original Script Logic (Adapted for GUI Control)
-- ========================================================================

-- Script-wide variables
local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local heartbeatConnection = nil

-- Remotes and Values
local skipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipVoteRequest")
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")

-- State
local isAlive = false
local hasTeleportedThisLife = false

-- Debug print only when actions occur
local function debugAction(tag, msg)
    print(string.format("[%s] %s", tag, msg))
end

-- Reset state on respawn
local function resetTeleportState()
    hasTeleportedThisLife = false
end

-- Team check
local function onSameTeam()
    if not targetPlayer or not targetPlayer:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end
    local targetTeam = targetPlayer.Stats:FindFirstChild("Team")
    local localTeam = localPlayer.Stats:FindFirstChild("Team")
    if not targetTeam or not localTeam then return false end
    if targetTeam.Value == "FFA" or localTeam.Value == "FFA" then return false end
    return targetTeam.Value == localTeam.Value
end

-- Juggernaut check
local function isJuggernaut()
    if not localPlayer:FindFirstChild("Stats") then return false end
    local hunterValue = localPlayer.Stats:FindFirstChild("Hunter")
    if not hunterValue then return false end
    return hunterValue.Value == "Juggernaut" or hunterValue.Value == "MultiJuggernaut"
end

-- Safety and position calculation for enemy teleport
local function isInSafeArea(position)
    return (position - Vector3.new(-2, 23, 3)).Magnitude <= 50
end

local function getSafeTeleportPosition(targetPosition)
    local randomAngle = math.random() * 2 * math.pi
    local randomDistance = 2 + math.random() * (3 - 2) -- 2 to 3 studs
    
    local offset = Vector3.new(
        math.cos(randomAngle) * randomDistance,
        0,
        math.sin(randomAngle) * randomDistance
    )
    
    local potentialPosition = targetPosition + offset + Vector3.new(0, 4, 0)
    
    if isInSafeArea(potentialPosition) then
        return potentialPosition
    else
        -- Fallback if outside safe area
        local directionToCenter = (Vector3.new(-2, 23, 3) - targetPosition).Unit
        return targetPosition + (directionToCenter * 3) + Vector3.new(0, 4, 0)
    end
end

-- Core teleport logic
local function teleportToTarget()
    if not isAlive or not targetPlayer or not targetPlayer.Character then return end

    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    if onSameTeam() or isJuggernaut() then
        if not hasTeleportedThisLife then
            localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, -50, 0)
            debugAction("teleport", "Same team or Juggernaut. Teleporting below target.")
            hasTeleportedThisLife = true
        end
    else
        local teleportPosition = getSafeTeleportPosition(targetRoot.Position)
        localRoot.CFrame = CFrame.new(teleportPosition)
    end
end

-- Find the target player based on GUI dropdown
local function findTargetPlayer(username)
    targetPlayer = Players:FindFirstChild(username)
    if targetPlayer then
        resetTeleportState()
        debugAction("target", "Target found: " .. targetPlayer.Name)
        
        targetPlayer.CharacterAdded:Connect(function()
            resetTeleportState()
            debugAction("target", "Target respawned, reset state")
        end)
    else
        warn("Target not found: " .. username)
    end
    return targetPlayer ~= nil
end

-- Control the main teleport loop
local function stopTeleporting()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
        debugAction("system", "Teleport loop stopped")
    end
    targetPlayer = nil
    resetTeleportState()
end

local function startTeleporting()
    stopTeleporting() -- Stop any existing loop first
    if not Options.TeleportEnabled.Value or Options.TargetPlayer.Value == "None" then
        return
    end

    if findTargetPlayer(Options.TargetPlayer.Value) then
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            pcall(teleportToTarget)
        end)
        debugAction("system", "Teleport loop started for " .. Options.TargetPlayer.Value)
    end
end

-- Gamemode skip logic
local function isGamemodeWanted()
    local wanted = Options.WantedGamemodes.Value
    for mode, selected in pairs(wanted) do
        if selected and gameModeValue.Value == mode then
            return true
        end
    end
    return false
end

local function handleGamemodeSkip()
    if not Options.AutoSkipEnabled.Value then return end

    if not isGamemodeWanted() then
        debugAction("gamemode", "Undesirable gamemode: '" .. gameModeValue.Value .. "'. Firing skip request.")
        pcall(function() skipRemote:FireServer() end)
    else
        debugAction("gamemode", "Desirable gamemode found: '" .. gameModeValue.Value .. "'.")
    end
end

-- ========================================================================
-- GUI Elements and Callbacks
-- ========================================================================

-- Main Tab: Teleport controls
Tabs.Main:AddParagraph({ Title = "Master Control", Content = "Enable or disable the main teleport functionality." })
local teleportToggle = Tabs.Main:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
teleportToggle:OnChanged(function()
    if Options.TeleportEnabled.Value then
        startTeleporting()
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation has been enabled.", Duration = 3 })
    else
        stopTeleporting()
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation has been disabled.", Duration = 3 })
    end
end)

Tabs.Main:AddParagraph({ Title = "Target Selection", Content = "Choose a player to target. The list updates automatically." })
local playerDropdown = Tabs.Main:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })
playerDropdown:OnChanged(function()
    startTeleporting()
end)

-- Automation Tab: Gamemode skipper
Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
autoSkipToggle:OnChanged(function()
    handleGamemodeSkip() -- Run a check immediately on toggle
end)

local ALL_GAMEMODES = {"Teams", "Infection", "FFA", "ColorWar", "TeamVampire", "CornerDomination", "MultiJuggernauts", "LastStand", "TugOfWar", "Squads", "Duos", "DuosLastStand"}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", {
    Title = "Wanted Gamemodes",
    Description = "Select which gamemodes you want to play.",
    Values = ALL_GAMEMODES,
    Multi = true,
    Default = {"FFA", "Teams", "Infection"},
})
wantedGamesDropdown:OnChanged(handleGamemodeSkip)

-- Settings Tab: FPS Cap
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "2", Numeric = true, Finished = true })

local function updateFpsCap()
    if Options.FpsCapEnabled.Value then
        local cap = tonumber(Options.FpsCapValue.Value) or 60
        setfpscap(cap)
        debugAction("fps", "FPS cap set to " .. cap)
    else
        setfpscap(999) -- A high value to effectively uncap
        debugAction("fps", "FPS cap disabled")
    end
end

fpsToggle:OnChanged(updateFpsCap)
fpsInput:OnChanged(updateFpsCap)

-- ========================================================================
-- Event Handling & Initialization
-- ========================================================================

-- Update player dropdown list
local function updatePlayerList()
    local playerNames = {"None"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    playerDropdown:SetValues(playerNames)

    -- If current target left, reset dropdown
    if not table.find(playerNames, Options.TargetPlayer.Value) then
        playerDropdown:SetValue("None")
    end
end

-- Player join/leave events
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(player)
    updatePlayerList()
    if player == targetPlayer then
        stopTeleporting()
    end
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
            resetTeleportState()
            debugAction("life", "LocalPlayer is now DEAD")
        end
    end
    aliveValue.Changed:Connect(updateAliveStatus)
    updateAliveStatus(aliveValue.Value)
end

localPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    debugAction("system", "LocalPlayer respawned, reset state")
end)

-- Gamemode change event
gameModeValue.Changed:Connect(handleGamemodeSkip)

-- Initial setup calls
hookAlive()
updatePlayerList()
task.wait(1)
handleGamemodeSkip()
updateFpsCap()

-- ========================================================================
-- Save Manager & Interface Manager Setup
-- ========================================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("FluentUtility")
SaveManager:SetFolder("FluentUtility/Config")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent GUI",
    Content = "The script has been loaded successfully.",
    SubContent = "Press Right Ctrl to minimize.",
    Duration = 8
})

SaveManager:LoadAutoloadConfig()
