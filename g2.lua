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
    SubTitle = "v1.3 (Stable)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
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
-- Combat Utilities Logic
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

-- Core kill loop logic (patched to use localPlayer's weapon + Alive check)
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

    -- 2. Filter and sort targets (Alive check added)
    local validTargets = {}
    for _, p in ipairs(potentialTargets) do
        local aliveVal = p:FindFirstChild("Alive")
        if aliveVal and aliveVal.Value == true then
            if isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(validTargets, p)
            end
        end
    end
    if #validTargets == 0 then return end
    table.sort(validTargets, function(a, b) return a.Name < b.Name end)

    -- 3. Select final target
    local finalTarget = validTargets[1]
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- 4. Use local player's weapon for range
    local localStats = localPlayer:FindFirstChild("Stats")
    local localWeaponNameVal = localStats and localStats:FindFirstChild("Weapon")
    if not localWeaponNameVal or localWeaponNameVal.Value == "" then return end

    local localCharacter = CharactersFolder:FindFirstChild(localPlayer.Name)
    if not localCharacter then return end

    local weaponModel = localCharacter:FindFirstChild(localWeaponNameVal.Value)
    local weaponPart = weaponModel and weaponModel:FindFirstChild("Part")
    if not weaponPart then return end

    -- 5. Calculate position and teleport
    local weaponRange = weaponPart.Size.Z
    local targetPosition = targetRoot.Position
    local newPosition = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)

    localRoot.CFrame = CFrame.new(newPosition, targetPosition)
end

-- ========================================================================
-- GUI Elements and Callbacks
-- ========================================================================

-- Teleport Tab
Tabs.Main:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false }):OnChanged(startTeleporting)
Tabs.Main:AddDropdown("TargetPlayer", {
    Title = "Target Player",
    Values = { "None" },
    Multi = false,
    Default = "None"
}):OnChanged(startTeleporting)

-- Automation Tab
Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Auto Skip Gamemodes", Default = false })
Tabs.Automation:AddMultiDropdown("WantedGamemodes", {
    Title = "Wanted Gamemodes",
    Values = { "FFA", "Juggernaut", "TeamBattle", "Survivor" },
    Default = {}
})
Tabs.Automation:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
Tabs.Automation:AddToggle("KillPlayers", { Title = "Kill Selected Players", Default = false })
Tabs.Automation:AddMultiDropdown("KillTargets", {
    Title = "Select Kill Targets",
    Values = {},
    Default = {}
})
Tabs.Automation:AddToggle("ShowHitboxes", { Title = "Show Hitboxes", Default = false })

-- Settings Tab
Tabs.Settings:AddButton({ Title = "Unload Script", Callback = function() Window:Unload() end })
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "TargetPlayer", "KillTargets" })
InterfaceManager:SetFolder("UtilityGUI")
SaveManager:SetFolder("UtilityGUI/saves")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ========================================================================
-- Connections
-- ========================================================================

-- Update dropdowns when players join/leave
Players.PlayerAdded:Connect(function(player)
    Options.TargetPlayer:AddValue(player.Name)
    Options.KillTargets:AddValue(player.Name)
end)
Players.PlayerRemoving:Connect(function(player)
    Options.TargetPlayer:RemoveValue(player.Name)
    Options.KillTargets:RemoveValue(player.Name)
end)

-- Keep Alive status synced
localPlayer:GetPropertyChangedSignal("Parent"):Connect(function()
    local aliveVal = localPlayer:FindFirstChild("Alive")
    isAlive = aliveVal and aliveVal.Value or false
end)
localPlayer.ChildAdded:Connect(function(child)
    if child.Name == "Alive" and child:IsA("BoolValue") then
        child:GetPropertyChangedSignal("Value"):Connect(function()
            isAlive = child.Value
        end)
        isAlive = child.Value
    end
end)

-- Hook Heartbeat for visuals and combat
RunService.Heartbeat:Connect(function()
    pcall(updateAllHitboxVisuals)
    pcall(killLoop)
end)

-- Hook gamemode skip
gameModeValue:GetPropertyChangedSignal("Value"):Connect(handleGamemodeSkip)
