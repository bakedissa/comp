local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local BELOW_OFFSET = Vector3.new(0, -50, 0) -- Kill offset for teammates

-- Config from original script (for enemy teleport)
local WEAPON_RADIUS = 6 -- Studs
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Offset to avoid spawning in ground
local SAFE_AREA_CENTER = Vector3.new(-2, 23, 3) -- Middle area center
local SAFE_AREA_RADIUS = 50 -- Adjust based on your map size

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

-- State
local isAlive = false
local hasTeleportedThisLife = false -- For one-time actions (like teammate kill)

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
    if not targetPlayer or not targetPlayer:FindFirstChild("Stats") then return false end
    if not localPlayer:FindFirstChild("Stats") then return false end

    local targetTeam = targetPlayer.Stats:FindFirstChild("Team")
    local localTeam = localPlayer.Stats:FindFirstChild("Team")
    if not targetTeam or not localTeam then return false end

    if targetTeam.Value == "FFA" or localTeam.Value == "FFA" then
        return false
    end
    return targetTeam.Value == localTeam.Value
end

-- Helper functions for enemy teleport logic (from original script)
local function isInSafeArea(position)
    return (position - SAFE_AREA_CENTER).Magnitude <= SAFE_AREA_RADIUS
end

local function getRandomPositionAroundTarget(targetPosition)
    local randomAngle = math.random() * 2 * math.pi
    local randomDistance = math.random() * WEAPON_RADIUS
    
    local offset = Vector3.new(
        math.cos(randomAngle) * randomDistance,
        0,
        math.sin(randomAngle) * randomDistance
    )
    
    return targetPosition + offset + TELEPORT_OFFSET
end

local function getSafeTeleportPosition(targetPosition)
    local attempts = 0
    local maxAttempts = 10
    
    while attempts < maxAttempts do
        local potentialPosition = getRandomPositionAroundTarget(targetPosition)
        
        if isInSafeArea(potentialPosition) then
            return potentialPosition
        end
        
        attempts = attempts + 1
    end
    
    -- Fallback if no safe position found
    local directionToCenter = (SAFE_AREA_CENTER - targetPosition).Unit
    return targetPosition + (directionToCenter * WEAPON_RADIUS) + TELEPORT_OFFSET
end

-- Core teleport logic
local function teleportToTarget()
    if not isAlive then return end
    if not targetPlayer or not targetPlayer.Character then return end

    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    if onSameTeam() then
        -- SAME TEAM: Teleport below them to kill them (only once per life)
        if not hasTeleportedThisLife then
            localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
            debugAction("teleport", "Same team. Teleporting below target.")
            hasTeleportedThisLife = true
        end
    else
        -- ENEMY TEAM / FFA: Use the original method to find a random position
        -- This calculates a new position on every frame.
        local targetPosition = targetRoot.Position
        local teleportPosition = getSafeTeleportPosition(targetPosition)
        localRoot.CFrame = CFrame.new(teleportPosition)
    end
end

-- Find target
local function findTargetPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
            targetPlayer = player
            resetTeleportState()

            player.CharacterAdded:Connect(function()
                resetTeleportState()
                debugAction("target", "Target respawned, reset state")
            end)

            debugAction("target", "Target found: " .. player.Name)
            return true
        end
    end
    warn("Target not found: " .. TARGET_USERNAME)
    return false
end

-- Start teleport loop
local function startTeleporting()
    if connection then connection:Disconnect() end
    if not findTargetPlayer() then return end

    connection = RunService.Heartbeat:Connect(function()
        pcall(teleportToTarget)
    end)
    debugAction("system", "Teleport loop started")
end

-- Stop teleport loop
local function stopTeleporting()
    if connection then
        connection:Disconnect()
        connection = nil
        debugAction("system", "Teleport loop stopped")
    end
    targetPlayer = nil
    resetTeleportState()
end

-- Alive tracking
local function hookAlive()
    local aliveValue = localPlayer:WaitForChild("Alive")

    local function updateAliveStatus(newStatus)
        if newStatus == isAlive then
            return
        end

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

-- Events
Players.PlayerAdded:Connect(function(player)
    if (player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME) and not targetPlayer then
        startTeleporting()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == targetPlayer then
        stopTeleporting()
        task.delay(2, function()
            if findTargetPlayer() then startTeleporting() end
        end)
    end
end)

localPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    debugAction("system", "LocalPlayer respawned, reset state")
end)

-- Init
hookAlive()
startTeleporting()

-- Stop key
local stopKey = Enum.KeyCode.F2
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == stopKey then
        stopTeleporting()
        print("Teleportation stopped (manual)")
    end
end)

print("Teleport script running. Press F2 to stop.")
