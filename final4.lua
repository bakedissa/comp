--[[
Title: Teleport & Utility GUI (Merged)
Description: Unified Teleport, Combat, and Utility GUI using Fluent.
Author: Gemini (merged & patched)
Notes: Combines the reliable auto-kill system from the original script with the improved boundary-safety, SkipShieldUsers option, UI layout, and other improvements from the patched script. Added Auto Upgrade Equipped Weapon + Unarmed hug logic + AFK prioritization + Precise Targeting + Chaotic Kill mode with a cooldown slider.
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
    Title = "Rotation Wars by issa",
    SubTitle = "https://discord.gg/gZMQFPnPFz",
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
local chaoticKillConnection = nil
local hitboxConnection = nil
local afkConnection = nil
local lastChaoticTeleportTime = 0 -- Cooldown timer for chaotic mode

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
local BOUNDARY_PADDING = 2

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
    if isInSafeArea(potentialPosition) then return potentialPosition
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
        targetPlayer.CharacterAdded:Connect(function()
            resetTeleportState()
        end)
    end
    return targetPlayer ~= nil
end

-- Start / stop teleport loop
local function stopTeleporting()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    targetPlayer = nil
    resetTeleportState()
end

local function startTeleporting()
    stopTeleporting()
    if not Options.TeleportEnabled or not Options.TargetPlayer or Options.TargetPlayer.Value == "None" then return end
    if findTargetPlayer(Options.TargetPlayer.Value) then
        heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
    end
end

-- ========================================================================
-- Gamemode skip logic
-- ========================================================================
local function isGamemodeWanted()
    local wanted = Options.WantedGamemodes.Value
    for mode, selected in pairs(wanted) do
        if selected and gameModeValue.Value == mode then return true end
    end
    return false
end

local function handleGamemodeSkip()
    if Options.AutoSkipEnabled and Options.AutoSkipEnabled.Value then
        if not isGamemodeWanted() then
            pcall(function()
                skipRemote:FireServer()
            end)
        end
    end
end

-- ========================================================================
-- Combat Utilities Logic (hitboxes, attack checks, killLoop)
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
        if part and part.Parent then revertHitboxVisuals(part) end
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
                local hitboxPart = weaponModel and (
                    weaponModel:FindFirstChild("Hitbox") or
                    weaponModel:FindFirstChild("WeaponHitbox") or
                    weaponModel:FindFirstChild("WeaponHitBox") or
                    weaponModel:FindFirstChild("Part")
                )
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
        if not table.find(processedParts, part) then revertHitboxVisuals(part) end
    end
end

-- Attack conditions
local function isAttackable(target)
    if not target or target == localPlayer then return false end
    if not target:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end
    -- Skip shield users
    if Options.SkipShieldUsers and Options.SkipShieldUsers.Value then
        local weaponVal = target.Stats:FindFirstChild("Weapon")
        if weaponVal and weaponVal.Value == "Shield" then return false end
    end
    local targetTeamVal = target.Stats:FindFirstChild("Team")
    local localTeamVal = localPlayer.Stats:FindFirstChild("Team")
    if not targetTeamVal or not localTeamVal then return false end
    local targetTeam = targetTeamVal.Value
    local localTeam = localTeamVal.Value
    if targetTeam == "FFA" or localTeam == "FFA" or targetTeam == "Survivor" or localTeam == "Survivor" then return true end
    return targetTeam ~= localTeam
end

-- ========================================================================
-- AFK detection
-- ========================================================================
local AFKPlayers = {} -- player -> bool
local lastPositions = {} -- player -> {pos = Vector3, t = seconds}

-- Defaults
local DEFAULT_AFK_TIME = 2 -- seconds
local DEFAULT_AFK_THRESHOLD = 0.2 -- studs tolerance

local function startAFKScanner()
    if afkConnection then return end
    afkConnection = RunService.Heartbeat:Connect(function(dt)
        local afkTime = tonumber(Options.AFKTime and Options.AFKTime.Value) or DEFAULT_AFK_TIME
        local afkThreshold = tonumber(Options.AFKThreshold and Options.AFKThreshold.Value) or DEFAULT_AFK_THRESHOLD
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= localPlayer then
                local aliveVal = plr:FindFirstChild("Alive")
                local char = CharactersFolder:FindFirstChild(plr.Name)
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if aliveVal and aliveVal.Value == true and root then
                    local last = lastPositions[plr] or { pos = root.Position, t = 0 }
                    if (root.Position - last.pos).Magnitude < afkThreshold then
                        last.t = last.t + dt
                    else
                        last.t = 0
                    end
                    last.pos = root.Position
                    lastPositions[plr] = last
                    AFKPlayers[plr] = (last.t >= afkTime)
                else
                    lastPositions[plr] = nil
                    AFKPlayers[plr] = false
                end
            end
        end
    end)
end

local function stopAFKScanner()
    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end
    lastPositions = {}
    AFKPlayers = {}
end

-- ========================================================================
-- Core kill loops
-- ========================================================================
local currentTarget = nil

local function pickNewTarget()
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

    if #validTargets == 0 then return nil end

    if Options.PrioritizeAFK and Options.PrioritizeAFK.Value then
        for _, p in ipairs(validTargets) do
            if AFKPlayers[p] then return p end
        end
    end

    table.sort(validTargets, function(a,b) return a.Name < b.Name end)
    return validTargets[1]
end

local function getActiveTarget()
    if not currentTarget or not currentTarget:FindFirstChild("Alive") or currentTarget.Alive.Value == false or not isAttackable(currentTarget) then
        currentTarget = pickNewTarget()
    end
    return currentTarget
end

-- Standard, sequential kill loop
local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local target = getActiveTarget()
    if not target then return end

    if Options.PrioritizeAFK and Options.PrioritizeAFK.Value and not AFKPlayers[target] then
        currentTarget = pickNewTarget()
        target = currentTarget
        if not target then return end
    end

    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local localWeaponName = localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon")
    local weaponRange = 0
    if localWeaponName then
        if localWeaponName.Value == "Unarmed" then
            weaponRange = tonumber(Options.UnarmedDistance and Options.UnarmedDistance.Value) or 2
        else
            local localCharModel = CharactersFolder:FindFirstChild(localPlayer.Name)
            if localCharModel then
                local weaponModel = localCharModel:FindFirstChild(localWeaponName.Value)
                if weaponModel then
                    local weaponPart = weaponModel:FindFirstChild("Hitbox") or weaponModel:FindFirstChild("WeaponHitbox") or weaponModel:FindFirstChild("WeaponHitBox") or weaponModel:FindFirstChild("Part")
                    if weaponPart then
                        weaponRange = weaponPart.Size.Z or 0
                    end
                end
            end
        end
    end

    if weaponRange > 0 then
        local targetPos = targetRoot.Position
        local desiredPos = targetPos - (targetRoot.CFrame.LookVector * weaponRange)
        desiredPos = clampInsideBounds(desiredPos)

        local finalPos
        if Options.PreciseTargeting and Options.PreciseTargeting.Value then
            local offsetY = tonumber(Options.PreciseTargetOffset and Options.PreciseTargetOffset.Value) or 4
            finalPos = Vector3.new(desiredPos.X, targetPos.Y + offsetY, desiredPos.Z)
        else
            finalPos = Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z)
        end

        localRoot.CFrame = CFrame.new(finalPos, targetPos)
    end
end

-- Chaotic Kill loop with cooldown
local function chaoticKillLoop()
    local cooldown = Options.ChaoticCooldown and Options.ChaoticCooldown.Value or 0.1
    if tick() - lastChaoticTeleportTime < cooldown then
        return
    end

    if not isAlive then return end
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local eligibleTargets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(eligibleTargets, p)
        end
    end

    if #eligibleTargets == 0 then return end
    local target = eligibleTargets[math.random(1, #eligibleTargets)]
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local localWeaponName = localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon")
    local weaponRange = 0
    if localWeaponName then
        if localWeaponName.Value == "Unarmed" then
            weaponRange = tonumber(Options.UnarmedDistance and Options.UnarmedDistance.Value) or 2
        else
            local localCharModel = CharactersFolder:FindFirstChild(localPlayer.Name)
            if localCharModel then
                local weaponModel = localCharModel:FindFirstChild(localWeaponName.Value)
                if weaponModel then
                    local weaponPart = weaponModel:FindFirstChild("Hitbox") or weaponModel:FindFirstChild("WeaponHitbox") or weaponModel:FindFirstChild("WeaponHitBox") or weaponModel:FindFirstChild("Part")
                    if weaponPart then weaponRange = weaponPart.Size.Z or 0 end
                end
            end
        end
    end

    if weaponRange > 0 then
        local targetPos = targetRoot.Position
        local desiredPos = targetPos - (targetRoot.CFrame.LookVector * weaponRange)
        desiredPos = clampInsideBounds(desiredPos)
        local offsetY = tonumber(Options.ChaoticKillOffset and Options.ChaoticKillOffset.Value) or 4
        local finalPos = Vector3.new(desiredPos.X, targetPos.Y + offsetY, desiredPos.Z)
        localRoot.CFrame = CFrame.new(finalPos, targetPos)
        lastChaoticTeleportTime = tick() -- Update timestamp after teleporting
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
Tabs.Combat:AddParagraph({ Title = "General Utilities", Content = "Options for visualization and target filtering." })
local showHitboxesToggle = Tabs.Combat:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
local skipShieldToggle = Tabs.Combat:AddToggle("SkipShieldUsers", { Title = "Skip Shield Users", Default = false })

Tabs.Combat:AddParagraph({ Title = "Kill Modes", Content = "Select one method for auto-killing players." })
local killAllToggle = Tabs.Combat:AddToggle("KillAllPlayers", { Title = "Kill All (Sequential)", Default = false })
local killPlayersToggle = Tabs.Combat:AddToggle("KillPlayers", { Title = "Kill Specific (Sequential)", Default = false })
local killPlayersDropdown = Tabs.Combat:AddDropdown("KillTargets", { Title = "Select Targets", Values = {"None"}, Multi = true, Default = {} })
local chaoticKillToggle = Tabs.Combat:AddToggle("ChaoticKill", { Title = "Chaotic Kill (Random)", Default = false })
local chaoticOffsetInput = Tabs.Combat:AddInput("ChaoticKillOffset", { Title = "Chaotic Hover Offset (studs)", Default = "4", Numeric = true, Finished = true })
local chaoticCooldownSlider = Tabs.Combat:AddSlider("ChaoticCooldown", { Title = "Chaotic Teleport Cooldown", Default = 0.1, Min = 0, Max = 2, Suffix = " s", Rounding = 2 })

Tabs.Combat:AddParagraph({ Title = "AFK Prioritization", Content = "If enabled, the script will prefer AFK / stationary players at round start." })
local prioritizeAFKToggle = Tabs.Combat:AddToggle("PrioritizeAFK", { Title = "Prioritize AFK Players", Default = true })
local afkTimeInput = Tabs.Combat:AddInput("AFKTime", { Title = "AFK Time (s)", Default = tostring(DEFAULT_AFK_TIME), Numeric = true, Finished = true })
local afkThresholdInput = Tabs.Combat:AddInput("AFKThreshold", { Title = "AFK Threshold (studs)", Default = tostring(DEFAULT_AFK_THRESHOLD), Numeric = true, Finished = true })

Tabs.Combat:AddParagraph({ Title = "Unarmed", Content = "Hug distance when Unarmed." })
local unarmedDistanceInput = Tabs.Combat:AddInput("UnarmedDistance", { Title = "Unarmed Distance (studs)", Default = "2", Numeric = true, Finished = true })

-- Precise Targeting
Tabs.Combat:AddParagraph({ Title = "Precise Targeting", Content = "Toggle a hovering kill position above your target and set vertical offset." })
local preciseTargetingToggle = Tabs.Combat:AddToggle("PreciseTargeting", { Title = "Enable Precise Targeting", Default = false })
local preciseOffsetInput = Tabs.Combat:AddInput("PreciseTargetOffset", { Title = "Hover Offset (studs)", Default = "4", Numeric = true, Finished = true })

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
    else
        pcall(function() setfpscap(999) end)
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
    if player == targetPlayer then stopTeleporting() end
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
            startAFKScanner()
        else
            stopTeleporting()
            stopAFKScanner()
        end
    end)
end

-- Auto upgrade
RunService.Heartbeat:Connect(function()
    if Options.AutoUpgrade and Options.AutoUpgrade.Value then
        if localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon") then
            local currentWeapon = localPlayer.Stats.Weapon.Value
            if currentWeapon and currentWeapon ~= "" then
                pcall(function() purchaseWeaponUpgrade:InvokeServer(currentWeapon) end)
            end
        end
    end
end)

-- Skip gamemode
gameModeValue:GetPropertyChangedSignal("Value"):Connect(handleGamemodeSkip)

-- Teleport events
teleportToggle:OnChanged(function(enabled) if enabled then startTeleporting() else stopTeleporting() end end)
playerDropdown:OnChanged(function() if Options.TeleportEnabled and Options.TeleportEnabled.Value then startTeleporting() end end)

-- Hitbox visuals
showHitboxesToggle:OnChanged(function(show)
    if show then
        updateAllHitboxVisuals()
        if not hitboxConnection then hitboxConnection = RunService.Heartbeat:Connect(updateAllHitboxVisuals) end
    else
        if hitboxConnection then hitboxConnection:Disconnect() end
        hitboxConnection = nil
        revertAllHitboxVisuals()
    end
end)

-- Prioritize AFK toggle wiring
prioritizeAFKToggle:OnChanged(function()
    if Options.PrioritizeAFK.Value and isAlive then startAFKScanner() end
end)

-- Kill loop master control
local function updateKillLoopState()
    local killAllEnabled = Options.KillAllPlayers and Options.KillAllPlayers.Value
    local killSpecificEnabled = Options.KillPlayers and Options.KillPlayers.Value
    local chaoticKillEnabled = Options.ChaoticKill and Options.ChaoticKill.Value

    local standardLoopShouldRun = killAllEnabled or killSpecificEnabled

    -- Manage standard kill loop
    if standardLoopShouldRun and not killConnection then
        killConnection = RunService.Heartbeat:Connect(function() pcall(killLoop) end)
    elseif not standardLoopShouldRun and killConnection then
        killConnection:Disconnect()
        killConnection = nil
    end

    -- Manage chaotic kill loop
    if chaoticKillEnabled and not chaoticKillConnection then
        chaoticKillConnection = RunService.Heartbeat:Connect(function() pcall(chaoticKillLoop) end)
    elseif not chaoticKillEnabled and chaoticKillConnection then
        chaoticKillConnection:Disconnect()
        chaoticKillConnection = nil
    end
end

-- Kill Mode Toggles (with mutual exclusivity)
killAllToggle:OnChanged(function(value)
    if value then
        killPlayersToggle:SetValue(false, true)
        chaoticKillToggle:SetValue(false, true)
    end
    updateKillLoopState()
end)

killPlayersToggle:OnChanged(function(value)
    if value then
        killAllToggle:SetValue(false, true)
        chaoticKillToggle:SetValue(false, true)
    end
    updateKillLoopState()
end)

chaoticKillToggle:OnChanged(function(value)
    if value then
        killAllToggle:SetValue(false, true)
        killPlayersToggle:SetValue(false, true)
    end
    updateKillLoopState()
end)

killPlayersDropdown:OnChanged(updateKillLoopState)

-- Initial setup calls
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
Fluent:Notify({
    Title = "Rotation Wars GUI",
    Content = "Sucessfully Loaded, Join the server; https://discord.gg/PQvfmPyVtS",
    Duration = 999
})
SaveManager:LoadAutoloadConfig()
