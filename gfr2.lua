--[[ 
    Fluent Utility GUI v1.4 (Merged)
    Features:
      - Teleportation (targeted, safer positioning)
      - Gamemode skip
      - Hitbox visuals (robust detection)egasddsegdfsghsdhfdshfdhsfdsfhdsfh
      - Kill loop (Kill all / selected players)
      - Auto Upgrade Equipped Weapon (reads LocalPlayer.Stats.Weapon)
      - Unarmed hugging: stay ~2 studs from target
      - SaveManager & InterfaceManager integration
    Author: Gemini (merged & patched)
--]]

-- Load Fluent and addons
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Wait for key folders/objects
local CharactersFolder = Workspace:WaitForChild("Characters")

-- Remotes/Values
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local skipRemote = remotesFolder:FindFirstChild("SkipVoteRequest")
local purchaseWeaponUpgrade = remotesFolder:FindFirstChild("PurchaseWeaponUpgrade")
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")

-- Window
local Window = Fluent:CreateWindow({
    Title = "Utility GUI",
    SubTitle = "v1.4 (Mesdhsdhdhsrged)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Automation = Window:AddTab({ Title = "Automation", Icon = "bot" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- ========================================================================
-- Script state
-- ========================================================================
local targetPlayer = nil
local heartbeatConnection = nil
local killConnection = nil
local hitboxConnection = nil
local autoUpgradeConnection = nil

local isAlive = false
local hasTeleportedThisLife = false

-- Boundary clamp (X/Z), tweak to your map
local SAFE_MIN = Vector3.new(-25, -math.huge, -26)
local SAFE_MAX = Vector3.new(27, math.huge, 28)
local BOUNDARY_PADDING = 2

local function debugAction(tag, msg)
    print(string.format("[%s] %s", tag, tostring(msg)))
end

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

local function isJuggernaut()
    if not LocalPlayer:FindFirstChild("Stats") then return false end
    local hunterValue = LocalPlayer.Stats:FindFirstChild("Hunter")
    if not hunterValue then return false end
    return hunterValue.Value == "Juggernaut" or hunterValue.Value == "MultiJuggernaut"
end

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
    local offset = (root.Position - targetRoot.Position).Unit * 3
    root.CFrame = CFrame.new(targetRoot.Position + offset, targetRoot.Position)
    local potentialPosition = targetPosition + offset + Vector3.new(0, 4, 0)
    if isInSafeArea(potentialPosition) then
        return potentialPosition
    else
        local directionToCenter = (Vector3.new(-2, 23, 3) - targetPosition).Unit
        return targetPosition + (directionToCenter * 3) + Vector3.new(0, 4, 0)
    end
end

-- ========================================================================
-- Teleport logic
-- ========================================================================
local function teleportToTarget()
    if not isAlive or not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    if onSameTeam(LocalPlayer, targetPlayer) or isJuggernaut() then
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

local function findTargetPlayer(username)
    targetPlayer = Players:FindFirstChild(username)
    if targetPlayer then
        resetTeleportState()
        debugAction("target", "Target found: " .. targetPlayer.Name)
        targetPlayer.CharacterAdded:Connect(function() resetTeleportState() debugAction("target","Target respawned") end)
    else
        warn("Target not found: " .. tostring(username))
    end
    return targetPlayer ~= nil
end

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
        heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
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
        pcall(function() if skipRemote then skipRemote:FireServer() end end)
    else
        debugAction("gamemode", "Desirable gamemode found: '" .. tostring(gameModeValue.Value) .. "'.")
    end
end

-- ========================================================================
-- Hitbox visuals & helpers
-- ========================================================================
local originalHitboxProperties = {}

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

local function findHitboxPart(model)
    if not model then return nil end
    local namesToTry = {"Hitbox", "WeaponHitBox", "WeaponHitbox", "HitboxPart", "Part", "Handle", "Main"}
    for _, name in ipairs(namesToTry) do
        local found = model:FindFirstChild(name)
        if found and found:IsA("BasePart") then return found end
    end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then return child end
    end
    return nil
end

local function updateAllHitboxVisuals()
    if not Options.ShowHitboxes.Value then return end
    local processedParts = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Weapon") then
            local weaponName = player.Stats.Weapon.Value
            local playerCharacter = CharactersFolder:FindFirstChild(player.Name)
            if playerCharacter then
                local hitboxPart
                if weaponName == "Unarmed" then
                    hitboxPart = playerCharacter:FindFirstChild("HumanoidRootPart") or playerCharacter:FindFirstChild("Torso")
                else
                    local weaponModel = playerCharacter:FindFirstChild(weaponName)
                    hitboxPart = findHitboxPart(weaponModel)
                end
                if hitboxPart then
                    table.insert(processedParts, hitboxPart)
                    if not originalHitboxProperties[hitboxPart] then
                        originalHitboxProperties[hitboxPart] = { Color = hitboxPart.Color, Transparency = hitboxPart.Transparency }
                        pcall(function()
                            hitboxPart.Color = Color3.fromRGB(255,0,0)
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

-- ========================================================================
-- Attack logic
-- ========================================================================
local function isAttackable(target)
    if not target or target == LocalPlayer then return false end
    if not target:FindFirstChild("Stats") or not LocalPlayer:FindFirstChild("Stats") then return false end

    if Options.SkipShieldUsers and Options.SkipShieldUsers.Value then
        local weaponVal = target.Stats:FindFirstChild("Weapon")
        if weaponVal and weaponVal.Value == "Shield" then
            return false
        end
    end

    local targetTeamVal = target.Stats:FindFirstChild("Team")
    local localTeamVal = LocalPlayer.Stats:FindFirstChild("Team")
    if not targetTeamVal or not localTeamVal then return false end

    local targetTeam = targetTeamVal.Value
    local localTeam = localTeamVal.Value

    if targetTeam == "FFA" or localTeam == "FFA" or targetTeam == "Survivor" or localTeam == "Survivor" then
        return true
    end

    return targetTeam ~= localTeam
end

local function getEquippedWeaponName()
    if not LocalPlayer or not LocalPlayer:FindFirstChild("Stats") then return nil end
    local weaponVal = LocalPlayer.Stats:FindFirstChild("Weapon")
    if weaponVal then return weaponVal.Value end
    return nil
end

-- ========================================================================
-- Kill loop
-- ========================================================================
local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end

    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

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

    local validTargets = {}
    for _, p in ipairs(potentialTargets) do
        local aliveVal = p:FindFirstChild("Alive")
        if aliveVal and aliveVal.Value == true and isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validTargets, p)
        end
    end

    if #validTargets == 0 then return end
    table.sort(validTargets, function(a, b) return a.Name < b.Name end)

    local finalTarget = validTargets[1]
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local localWeaponName = getEquippedWeaponName()
    local weaponPart
    local localCharModel = CharactersFolder:FindFirstChild(LocalPlayer.Name)
    if localWeaponName and localCharModel then
        if localWeaponName == "Unarmed" then
            weaponPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        else
            local weaponModel = localCharModel:FindFirstChild(localWeaponName)
            weaponPart = findHitboxPart(weaponModel)
        end
    end

    if weaponPart and targetRoot then
        local weaponRange = 1.5
        if weaponPart.Size and weaponPart.Size.Z then
            weaponRange = math.max(weaponPart.Size.Z, 1.5)
        end
        local targetPosition = targetRoot.Position

        if localWeaponName == "Unarmed" then
            -- Hugging behavior: keep ~2 studs away from target
            local direction = (targetPosition - localRoot.Position)
            if direction.Magnitude > 0 then direction = direction.Unit else direction = (targetRoot.CFrame.LookVector * -1) end
            local desiredPos = targetPosition - (direction * 2) -- 2 studs away
            desiredPos = clampInsideBounds(desiredPos)
            local finalPos = Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z)
            localRoot.CFrame = CFrame.new(finalPos, targetPosition)
        else
            -- Position behind target based on their LookVector and weapon range
            local desiredPos = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)
            desiredPos = clampInsideBounds(desiredPos)
            local finalPos = Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z)
            localRoot.CFrame = CFrame.new(finalPos, targetPosition)
        end
    end
end

-- ========================================================================
-- GUI elements
-- ========================================================================
-- Automation Tab
Tabs.Automation:AddParagraph({ Title = "Teleportation", Content = "Enable/disable teleport and select a target." })
local teleportToggle = Tabs.Automation:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })

Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
local ALL_GAMEMODES = {"Teams","Infection","FFA","ColorWar","TeamVampire","CornerDomination","MultiJuggernauts","LastStand","TugOfWar","Squads","Duos","DuosLastStand"}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", { Title = "Wanted Gamemodes", Values = ALL_GAMEMODES, Multi = true, Default = {"FFA","Teams","Infection"} })

-- Combat Tab
Tabs.Combat:AddParagraph({ Title = "Combat Utilities", Content = "Options for combat targeting & visualization." })
local showHitboxesToggle = Tabs.Combat:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
local skipShieldToggle = Tabs.Combat:AddToggle("SkipShieldUsers", { Title = "Skip Shield Users", Default = false })
local killAllToggle = Tabs.Combat:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
local killPlayersToggle = Tabs.Combat:AddToggle("KillPlayers", { Title = "Kill Specific Player(s)", Default = false })
local killPlayersDropdown = Tabs.Combat:AddDropdown("KillTargets", { Title = "Select Targets", Values = {"None"}, Multi = true, Default = {} })

-- Auto-upgrade toggle
local autoUpgradeToggle = Tabs.Combat:AddToggle("AutoUpgradeEquippedWeapon", { Title = "Auto Upgrade Equipped Weapon", Default = false })

-- Settings Tab
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "60", Numeric = true, Finished = true })

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

-- ========================================================================
-- Auto-upgrade logic
-- ========================================================================
local function autoUpgradeTick()
    if not purchaseWeaponUpgrade then return end
    if not LocalPlayer or not LocalPlayer.Character or not LocalPlayer:FindFirstChild("Stats") then return end
    local weaponName = getEquippedWeaponName()
    if not weaponName or weaponName == "" then return end
    if weaponName == "Unarmed" then return end
    pcall(function()
        purchaseWeaponUpgrade:InvokeServer(weaponName, 1)
        debugAction("upgrade", "Invoked upgrade for " .. weaponName)
    end)
end

local function startAutoUpgrade()
    if autoUpgradeConnection then return end
    autoUpgradeConnection = RunService.Heartbeat:Connect(function()
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
-- Event wiring & initialization
-- ========================================================================
local function updatePlayerLists()
    local singleSelectNames = {"None"}
    local multiSelectNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
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
    local aliveValue = LocalPlayer:WaitForChild("Alive")
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

LocalPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    hookAlive()
    debugAction("system", "LocalPlayer respawned, reset state")
end)

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
    if Options.TeleportEnabled.Value and Options.TargetPlayer.Value ~= "None" then
        startTeleporting()
    else
        stopTeleporting()
    end
end)

autoSkipToggle:OnChanged(function()
    if Options.AutoSkipEnabled.Value then handleGamemodeSkip() end
end)
wantedGamesDropdown:OnChanged(handleGamemodeSkip)
gameModeValue.Changed:Connect(handleGamemodeSkip)

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

-- initial calls
hookAlive()
updatePlayerLists()
task.wait(1)
handleGamemodeSkip()
updateFpsCap()

-- load auto-upgrade if saved enabled
if Options.AutoUpgradeEquippedWeapon and Options.AutoUpgradeEquippedWeapon.Value then
    startAutoUpgrade()
end

-- SaveManager & Interface wiring
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
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
