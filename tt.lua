--[[ 
Title: Teleport & Utility GUI (Merged) 
Description: Unified Teleport, Combat and Utility GUI using Fluent.
Author: Gemini (merged & patched)
Notes: Combines the reliable auto-kill system from the original script with the improved boundary-safety, SkipShieldUsers option, UI layout, 
and other improvements from the patched script. Added Auto Upgrade Equipped Weapon + Unarmed hug logic.
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
    SubTitle = "v1.5 (Merged)",
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

-- Remotes and Values
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skipRemote = remotes:WaitForChild("SkipVoteRequest")
local purchaseWeaponUpgrade = remotes:WaitForChild("PurchaseWeaponUpgrade")
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
    return hunterValue.Value == "Juggernaut" or hunterValue.Value == "MultiJuggernaut"
end

-- Safety helpers
local function clampInsideBounds(pos)
    local x = math.clamp(pos.X, SAFE_MIN.X + BOUNDARY_PADDING, SAFE_MAX.X - BOUNDARY_PADDING)
    local z = math.clamp(pos.Z, SAFE_MIN.Z + BOUNDARY_PADDING, SAFE_MAX.Z - BOUNDARY_PADDING)
    return Vector3.new(x, pos.Y, z)
end

local function isInSafeArea(position)
    return (position - Vector3.new(-2, 23, 3)).Magnitude <= 50
end

local function getSafeTeleportPosition(targetPosition)
    local randomAngle = math.random() * 2 * math.pi
    local randomDistance = 2 + math.random() * (3 - 2)
    local offset = Vector3.new(
        math.cos(randomAngle) * randomDistance,
        0,
        math.sin(randomAngle) * randomDistance
    )
    local potentialPosition = targetPosition + offset + Vector3.new(0, 4, 0)
    if isInSafeArea(potentialPosition) then
        return potentialPosition
    else
        local directionToCenter = (Vector3.new(-2, 23, 3) - targetPosition).Unit
        return targetPosition + (directionToCenter * 3) + Vector3.new(0, 4, 0)
    end
end

-- ========================================================================
-- Core teleport logic (Automation tab)
-- ========================================================================
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
        teleportPosition = clampInsideBounds(teleportPosition)
        localRoot.CFrame = CFrame.new(teleportPosition)
    end
end

-- Find target player helper
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
        warn("Target not found: " .. tostring(username))
    end
    return targetPlayer ~= nil
end

-- Start / stop teleport loop
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
    stopTeleporting()
    if not Options.TeleportEnabled or not Options.TargetPlayer or Options.TargetPlayer.Value == "None" then return end
    if findTargetPlayer(Options.TargetPlayer.Value) then
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            pcall(teleportToTarget)
        end)
        debugAction("system", "Teleport loop started for " .. Options.TargetPlayer.Value)
    end
end

-- ========================================================================
-- Gamemode skip logic
-- ========================================================================
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
        debugAction("gamemode", "Undesirable gamemode: '" .. tostring(gameModeValue.Value) .. "'. Firing skip request.")
        pcall(function() skipRemote:FireServer() end)
    else
        debugAction("gamemode", "Desirable gamemode found: '" .. tostring(gameModeValue.Value) .. "'.")
    end
end

-- ========================================================================
-- Combat Utilities Logic (hitboxes, attack checks, killLoop)
-- ========================================================================
local originalHitboxProperties = {}
local hitboxConnection = nil

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
                local hitboxPart = weaponModel and (weaponModel:FindFirstChild("Hitbox") or weaponModel:FindFirstChild("WeaponHitBox") or weaponModel:FindFirstChild("Part"))
                if hitboxPart then
                    table.insert(processedParts, hitboxPart)
                    if not originalHitboxProperties[hitboxPart] then
                        originalHitboxProperties[hitboxPart] = {
                            Color = hitboxPart.Color,
                            Transparency = hitboxPart.Transparency
                        }
                        pcall(function()
                            hitboxPart.Color = Color3.fromRGB(255, 0, 0)
                            hitboxPart.Transparency = 0.5
                        end)
                        hitboxPart.Destroying:Connect(function()
                            originalHitboxProperties[hitboxPart] = nil
                        end)
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

-- Attack conditions
local function isAttackable(target)
    if not target or target == localPlayer then return false end
    if not target:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end

    -- Skip shield users
    if Options.SkipShieldUsers and Options.SkipShieldUsers.Value then
        local weaponVal = target.Stats:FindFirstChild("Weapon")
        if weaponVal and weaponVal.Value == "Shield" then
            return false
        end
    end

    local targetTeamVal = target.Stats:FindFirstChild("Team")
    local localTeamVal = localPlayer.Stats:FindFirstChild("Team")
    if not targetTeamVal or not localTeamVal then return false end

    local targetTeam = targetTeamVal.Value
    local localTeam = localTeamVal.Value

    if targetTeam == "FFA" or localTeam == "FFA" or targetTeam == "Survivor" or localTeam == "Survivor" then
        return true
    end
    return targetTeam ~= localTeam
end

-- Core kill loop
local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    -- Determine target list
    local potentialTargets = {}
    if Options.KillAllPlayers.Value then
        potentialTargets = Players:GetPlayers()
    elseif Options.KillPlayers.Value then
        for name, selected in pairs(Options.KillTargets.Value) do
            if selected then
                local p = Players:FindFirstChild(name)
                if p then table.insert(potentialTargets, p) end
            end
        end
    end

    -- Filter and sort
    local validTargets = {}
    for _, p in ipairs(potentialTargets) do
        local aliveVal = p:FindFirstChild("Alive")
        if aliveVal and aliveVal.Value == true and isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validTargets, p)
        end
    end
    if #validTargets == 0 then return end
    table.sort(validTargets, function(a, b) return a.Name < b.Name end)

    -- Final target
    local finalTarget = validTargets[1]
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Weapon logic
    local localWeaponName = localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon")
    local weaponPart
    local weaponRange = 0

    if localWeaponName then
        if localWeaponName.Value == "Unarmed" then
            weaponRange = 2 -- hugging distance
        else
            local localCharModel = CharactersFolder:FindFirstChild(localPlayer.Name)
            if localCharModel then
                local weaponModel = localCharModel:FindFirstChild(localWeaponName.Value)
                weaponPart = weaponModel and (weaponModel:FindFirstChild("Hitbox") or weaponModel:FindFirstChild("WeaponHitBox") or weaponModel:FindFirstChild("Part"))
                if weaponPart then
                    weaponRange = weaponPart.Size.Z or 0
                end
            end
        end
    end

    if targetRoot and weaponRange > 0 then
        local targetPosition = targetRoot.Position
        local desiredPos = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)
        desiredPos = clampInsideBounds(desiredPos)
        local finalPos = Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z)
        localRoot.CFrame = CFrame.new(finalPos, targetPosition)
    end
end

-- ========================================================================
-- GUI Elements
-- ========================================================================
-- Automation Tab
Tabs.Automation:AddParagraph({ Title = "Teleportation", Content = "Enable/disable teleport and select a target." })
local teleportToggle = Tabs.Automation:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })

Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
local ALL_GAMEMODES = {"Teams","Infection","FFA","ColorWar","TeamVampire","CornerDomination","MultiJuggernauts","LastStand","TugOfWar","Squads","Duos","DuosLastStand"}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", { Title = "Wanted Gamemodes", Values = ALL_GAMEMODES, Multi = true, Default = {"FFA","Teams","Infection"} })

Tabs.Automation:AddParagraph({ Title = "Weapon Upgrades", Content = "Automatically upgrade your equipped weapon." })
local autoUpgradeToggle = Tabs.Automation:AddToggle("AutoUpgrade", { Title = "Auto Upgrade Equipped Weapon", Default = false })

-- Combat Tab
Tabs.Combat:AddParagraph({ Title = "Combat Utilities", Content = "Options for combat targeting & visualization." })
local showHitboxesToggle = Tabs.Combat:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
local skipShieldToggle = Tabs.Combat:AddToggle("SkipShieldUsers", { Title = "Skip Shield Users", Default = false })
local killAllToggle = Tabs.Combat:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
local killPlayersToggle = Tabs.Combat:AddToggle("KillPlayers", { Title = "Kill Specific Player(s)", Default = false })
local killPlayersDropdown = Tabs.Combat:AddDropdown("KillTargets", { Title = "Select Targets", Values = {"None"}, Multi = true, Default = {} })

-- Settings Tab
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "60", Numeric = true, Finished = true })

-- ========================================================================
-- Event Handling & Initialization
-- ========================================================================
-- FPS
local function updateFpsCap()
    if Options.FpsCapEnabled.Value then
        local cap = tonumber(Options.FpsCapValue.Value) or 60
        pcall(function() setfpscap(cap) end)
        debugAction("fps", "FPS cap set to " .. tostring(cap))
    else
        pcall(function() setfpscap(999) end)
        debugAction("fps", "FPS cap disabled")
    end
end
fpsToggle:OnChanged(updateFpsCap)
fpsInput:OnChanged(updateFpsCap)

-- Player lists
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
    if player == targetPlayer then
        stopTeleporting()
    end
end)

-- Alive tracking
local function hookAlive()
    local aliveValue = localPlayer:WaitForChild("Alive")
    isAlive = aliveValue.Value
    aliveValue:GetPropertyChangedSignal("Value"):Connect(function()
        isAlive = aliveValue.Value
        if isAlive then
            resetTeleportState()
            startTeleporting()
        else
            stopTeleporting()
        end
    end)
end

-- Auto upgrade
RunService.Heartbeat:Connect(function()
    if Options.AutoUpgrade and Options.AutoUpgrade.Value then
        if localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon") then
            local currentWeapon = localPlayer.Stats.Weapon.Value
            if currentWeapon and currentWeapon ~= "" then
                pcall(function()
                    purchaseWeaponUpgrade:InvokeServer(currentWeapon)
                end)
            end
        end
    end
end)

-- Skip gamemode
gameModeValue:GetPropertyChangedSignal("Value"):Connect(handleGamemodeSkip)

-- Teleport events
teleportToggle:OnChanged(function(enabled)
    if enabled then
        startTeleporting()
    else
        stopTeleporting()
    end
end)
playerDropdown:OnChanged(function()
    if Options.TeleportEnabled and Options.TeleportEnabled.Value then
        startTeleporting()
    end
end)

-- Hitbox visuals
showHitboxesToggle:OnChanged(function(show)
    if show then
        updateAllHitboxVisuals()
        hitboxConnection = RunService.Heartbeat:Connect(updateAllHitboxVisuals)
    else
        if hitboxConnection then hitboxConnection:Disconnect() end
        hitboxConnection = nil
        revertAllHitboxVisuals()
    end
end)

-- Kill loop
killConnection = RunService.Heartbeat:Connect(killLoop)

-- Init
updatePlayerLists()
hookAlive()
updateFpsCap()
handleGamemodeSkip()

-- Save & Interface
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"TargetPlayer","WantedGamemodes","KillTargets"})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
Fluent:Notify({ Title = "Utility GUI", Content = "Loaded successfully.", Duration = 6 })
SaveManager:LoadAutoloadConfig()
