--[[
    Title: Teleport & Utility GUI
    Description: An interactive GUI with teleport, combat, and utility features using the Fluent library.
    Author: Gemini (Modified)
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
    SubTitle = "v1.4 (Stable)",
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
local skipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipVoteRequest")
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")

-- State
local isAlive = false
local hasTeleportedThisLife = false

-- Boundary clamp (X/Z only matter, Y ignored)
local SAFE_MIN = Vector3.new(-25, -math.huge, -26)
local SAFE_MAX = Vector3.new(27, math.huge, 28)

-- Debug print helper
local function debugAction(tag, msg)
    print(string.format("[%s] %s", tag, msg))
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

-- Clamp to safe boundaries
local function clampInsideBounds(pos)
    local x = math.clamp(pos.X, SAFE_MIN.X + 2, SAFE_MAX.X - 2)
    local z = math.clamp(pos.Z, SAFE_MIN.Z + 2, SAFE_MAX.Z - 2)
    return Vector3.new(x, pos.Y, z)
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
        local desired = targetRoot.Position + Vector3.new(0, 4, 0)
        desired = clampInsideBounds(desired)
        localRoot.CFrame = CFrame.new(desired, targetRoot.Position)
    end
end

-- ========================================================================
-- Combat Utilities Logic
-- ========================================================================

-- Hitbox visuals
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
                local hitboxPart = weaponModel and weaponModel:FindFirstChild("Part")
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

    local finalTarget = validTargets[1]
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")

    local localWeaponName = localPlayer.Stats:FindFirstChild("Weapon")
    local weaponPart
    if localWeaponName then
        local weaponModel = CharactersFolder[localPlayer.Name]:FindFirstChild(localWeaponName.Value)
        weaponPart = weaponModel and weaponModel:FindFirstChild("Part")
    end

    if weaponPart and targetRoot then
        local weaponRange = weaponPart.Size.Z
        local targetPosition = targetRoot.Position
        local newPosition = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)
        newPosition = clampInsideBounds(newPosition)
        localRoot.CFrame = CFrame.new(newPosition, targetPosition)
    end
end

-- ========================================================================
-- GUI Elements
-- ========================================================================

-- Automation Tab
Tabs.Automation:AddParagraph({ Title = "Teleportation", Content = "Enable or disable teleport + select a target." })
local teleportToggle = Tabs.Automation:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })

-- Gamemode skipper
Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically skip unwanted game modes." })
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

-- (kept Settings tab same as before for FPS, SaveManager etc)

-- ========================================================================
-- Connections
-- ========================================================================

teleportToggle:OnChanged(function()
    if Options.TeleportEnabled.Value then
        if Options.TargetPlayer.Value ~= "None" then
            heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
        end
    else
        if heartbeatConnection then heartbeatConnection:Disconnect() heartbeatConnection = nil end
    end
end)
playerDropdown:OnChanged(function()
    if Options.TeleportEnabled.Value and Options.TargetPlayer.Value ~= "None" then
        if heartbeatConnection then heartbeatConnection:Disconnect() end
        heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
    end
end)

autoSkipToggle:OnChanged(function() pcall(function() if Options.AutoSkipEnabled.Value then skipRemote:FireServer() end end) end)
wantedGamesDropdown:OnChanged(function() pcall(function() if Options.AutoSkipEnabled.Value then skipRemote:FireServer() end end) end)

showHitboxesToggle:OnChanged(function()
    if Options.ShowHitboxes.Value then
        if not hitboxConnection then hitboxConnection = RunService.Heartbeat:Connect(updateAllHitboxVisuals) end
    else
        if hitboxConnection then hitboxConnection:Disconnect() hitboxConnection = nil revertAllHitboxVisuals() end
    end
end)

local function updateKillLoopState()
    if (Options.KillAllPlayers.Value or Options.KillPlayers.Value) and not killConnection then
        killConnection = RunService.Heartbeat:Connect(function() pcall(killLoop) end)
    elseif not Options.KillAllPlayers.Value and not Options.KillPlayers.Value and killConnection then
        killConnection:Disconnect() killConnection = nil
    end
end
killAllToggle:OnChanged(updateKillLoopState)
killPlayersToggle:OnChanged(updateKillLoopState)
killPlayersDropdown:OnChanged(updateKillLoopState)

-- (rest: FPS, SaveManager, Alive tracking remain same as your baseline)

