--[[
    Title: Teleport & Utility GUI
    Description: An interactive GUI with teleport, combat, and utility features using the Fluent library.
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
local Workspace = game:GetService("Workspace")

-- Wait for crucial folders
local CharactersFolder = Workspace:WaitForChild("Characters")

-- Create the main GUI Window
local Window = Fluent:CreateWindow({
    Title = "Utility GUI",
    SubTitle = "v1.1",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520), -- Increased height for new options
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

    if onSameTeam(localPlayer, targetPlayer) or isJuggernaut() then
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
-- NEW: Combat Utilities Logic
-- ========================================================================

-- Hitbox visualizer variables and functions
local originalHitboxProperties = {}
local hitboxConnection = nil
local killConnection = nil

local function revertHitboxVisuals(part)
    if originalHitboxProperties[part] then
        pcall(function()
            part.Color = originalHitboxProperties[part].Color
            part.Transparency = originalHitboxProperties[part].Transparency
        end)
        originalHitboxProperties[part] = nil
    end
end

local function revertAllHitboxVisuals()
    for part, _ in pairs(originalHitboxProperties) do
        if part and part.Parent then
            revertHitboxVisuals(part)
        end
    end
    originalHitboxProperties = {}
end

local function updateAllHitboxVisuals()
    if not Options.ShowHitboxes.Value then return end
    local processedParts = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Weapon") then
            local weaponName = player.Stats.Weapon.Value
            local playerCharacter = CharactersFolder:FindFirstChild(player.Name)
            if playerCharacter then
                local weaponModel = playerCharacter:FindFirstChild(weaponName)
                local hitboxPart = weaponModel and weaponModel:FindFirstChild("Part")

                if hitboxPart then
                    table.insert(processedParts, hitboxPart)
                    if not originalHitboxProperties[hitboxPart] then
                        originalHitboxProperties[hitboxPart] = { Color = hitboxPart.Color, Transparency = hitboxPart.Transparency }
                        pcall(function()
                            hitboxPart.Color = Color3.fromRGB(255, 0, 0)
                            hitboxPart.Transparency = 0.5
                        end)
                        hitboxPart.Destroying:Connect(function() originalHitboxProperties[hitboxPart] = nil end)
                    end
                end
            end
        end
    end

    for part, _ in pairs(originalHitboxProperties) do
        if not table.find(processedParts, part) then
            revertHitboxVisuals(part)
        end
    end
end

-- Team check for combat
local function isAttackable(target)
    if not target or target == localPlayer then return false end
    if not target:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end

    local targetTeamVal = target.Stats:FindFirstChild("Team")
    local localTeamVal = localPlayer.Stats:FindFirstChild("Team")
    if not targetTeamVal or not localTeamVal then return false end

    local targetTeam = targetTeamVal.Value
    local localTeam = localTeamVal.Value

    -- Exceptions where attacking is always allowed
    if targetTeam == "FFA" or localTeam == "FFA" or targetTeam == "Survivor" or localTeam == "Survivor" then
        return true
    end

    -- If not an exception, check if teams are different
    return targetTeam ~= localTeam
end

-- Core kill loop logic
local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end

    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    -- 1. Determine target list
    local potentialTargets = {}
    if Options.KillAllPlayers.Value then
        potentialTargets = Players:GetPlayers()
    elseif Options.KillPlayers.Value then
        local selectedNames = Options.KillTargets.Value
        for name, selected in pairs(selectedNames) do
            if selected then
                local p = Players:FindFirstChild(name)
                if p then table.insert(potentialTargets, p) end
            end
        end
    end

    -- 2. Filter and sort targets
    local validTargets = {}
    for _, p in ipairs(potentialTargets) do
        if isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validTargets, p)
        end
    end
    if #validTargets == 0 then return end
    table.sort(validTargets, function(a, b) return a.Name < b.Name end)

    -- 3. Select final target and get info
    local finalTarget = validTargets[1]
    local targetCharacter = CharactersFolder:FindFirstChild(finalTarget.Name)
    local targetStats = finalTarget:FindFirstChild("Stats")
    local targetWeaponNameVal = targetStats and targetStats:FindFirstChild("Weapon")
    
    if not targetCharacter or not targetWeaponNameVal then return end

    local weaponModel = targetCharacter:FindFirstChild(targetWeaponNameVal.Value)
    local weaponPart = weaponModel and weaponModel:FindFirstChild("Part")
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")

    -- 4. Calculate position and teleport
    if weaponPart and targetRoot then
        local weaponRange = weaponPart.Size.Z
        local targetPosition = targetRoot.Position
        local newPosition = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)
        
        localRoot.CFrame = CFrame.new(newPosition, targetPosition)
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
playerDropdown:OnChanged(startTeleporting)

-- Automation Tab: Gamemode skipper & Combat
Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
autoSkipToggle:OnChanged(function() handleGamemodeSkip() end)

local ALL_GAMEMODES = {"Teams", "Infection", "FFA", "ColorWar", "TeamVampire", "CornerDomination", "MultiJuggernauts", "LastStand", "TugOfWar", "Squads", "Duos", "DuosLastStand"}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", {
    Title = "Wanted Gamemodes",
    Values = ALL_GAMEMODES,
    Multi = true,
    Default = {"FFA", "Teams", "Infection"},
})
wantedGamesDropdown:OnChanged(handleGamemodeSkip)

Tabs.Automation:AddDivider()
Tabs.Automation:AddParagraph({ Title = "Combat Utilities", Content = "Tools to assist with combat and awareness." })

-- NEW: Hitbox Toggle
local showHitboxesToggle = Tabs.Automation:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
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

-- NEW: Master control for the kill loop
local function updateKillLoopState()
    local shouldBeRunning = Options.KillAllPlayers.Value or Options.KillPlayers.Value
    if shouldBeRunning and not killConnection then
        killConnection = RunService.Heartbeat:Connect(function() pcall(killLoop) end)
        debugAction("system", "Kill loop started")
    elseif not shouldBeRunning and killConnection then
        killConnection:Disconnect()
        killConnection = nil
        debugAction("system", "Kill loop stopped")
    end
end

-- NEW: Kill Toggles and Dropdown
local killAllToggle = Tabs.Automation:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
killAllToggle:OnChanged(updateKillLoopState)

local killPlayersToggle = Tabs.Automation:AddToggle("KillPlayers", { Title = "Kill Specific Player(s)", Default = false })
killPlayersToggle:OnChanged(updateKillLoopState)

local killPlayersDropdown = Tabs.Automation:AddDropdown("KillTargets", {
    Title = "Select Targets",
    Values = {"None"},
    Multi = true,
    Default = {},
})
killPlayersDropdown:OnChanged(updateKillLoopState)


-- Settings Tab: FPS Cap
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "60", Numeric = true, Finished = true })

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

    if not table.find(singleSelectNames, Options.TargetPlayer.Value) then
        playerDropdown:SetValue("None")
    end
end

-- Player join/leave events
Players.PlayerAdded:Connect(updatePlayerLists)
Players.PlayerRemoving:Connect(function(player)
    updatePlayerLists()
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
            debugAction("life", "LocalPlayer is now DEAD")
        end
    end
    aliveValue.Changed:Connect(updateAliveStatus)
    updateAliveStatus(aliveValue.Value)
end

localPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    hookAlive() -- Re-hook in case character is fully replaced
    debugAction("system", "LocalPlayer respawned, reset state")
end)

-- Gamemode change event
gameModeValue.Changed:Connect(handleGamemodeSkip)

-- Initial setup calls
hookAlive()
updatePlayerLists()
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
