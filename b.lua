local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration - INCREASED DISTANCES
local TARGET_USERNAME = "TargetUsername" -- The player with the bow
local FORMATION_RADIUS = 15 -- Increased from 8 to 15 studs (bow range)
local MIN_DISTANCE = 10 -- Increased from 6 to 10 studs between players
local GROUND_HEIGHT = 2 -- Slightly higher for better visibility
local SAFE_AREA_CENTER = Vector3.new(-2, 23, 3)
local SAFE_AREA_RADIUS = 50

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil
local teleportedPlayers = {}

-- Function to check if a position is within the safe area
local function isInSafeArea(position)
    return (position - SAFE_AREA_CENTER).Magnitude <= SAFE_AREA_RADIUS
end

-- Function to check if position is too close to other teleported players
local function isTooCloseToOthers(position, excludingPlayer)
    for player, playerPosition in pairs(teleportedPlayers) do
        if player ~= excludingPlayer and (position - playerPosition).Magnitude < MIN_DISTANCE then
            return true
        end
    end
    return false
end

-- Function to check if position is too close to target player
local function isTooCloseToTarget(position, targetPosition)
    return (position - targetPosition).Magnitude < (FORMATION_RADIUS - 3)
end

-- Function to get a safe formation position around the target
local function getFormationPosition(targetPosition, player)
    local attempts = 0
    local maxAttempts = 25
    
    while attempts < maxAttempts do
        -- Use consistent angles based on player for formation
        local otherPlayers = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= targetPlayer then
                table.insert(otherPlayers, p)
            end
        end
        
        local playerCount = math.max(1, #otherPlayers)
        local angleIncrement = (2 * math.pi) / playerCount
        local playerIndex = 0
        
        -- Find this player's index
        for i, p in ipairs(otherPlayers) do
            if p == player then
                playerIndex = i
                break
            end
        end
        
        local angle = playerIndex * angleIncrement
        local variedRadius = FORMATION_RADIUS + math.random(-2, 2) -- Slight variation
        
        local position = targetPosition + Vector3.new(
            math.cos(angle) * variedRadius,
            GROUND_HEIGHT,
            math.sin(angle) * variedRadius
        )
        
        -- Check all safety conditions
        if isInSafeArea(position) and 
           not isTooCloseToOthers(position, player) and
           not isTooCloseToTarget(position, targetPosition) then
            return position
        end
        
        attempts += 1
        
        -- Try random position if formation fails
        if attempts > 10 then
            local randomAngle = math.random() * 2 * math.pi
            local randomRadius = math.random(FORMATION_RADIUS, FORMATION_RADIUS + 5) -- Even more distance
            
            position = targetPosition + Vector3.new(
                math.cos(randomAngle) * randomRadius,
                GROUND_HEIGHT + math.random(-1, 1),
                math.sin(randomAngle) * randomRadius
            )
        end
    end
    
    -- Fallback position with maximum distance
    local fallbackAngle = math.random() * 2 * math.pi
    return targetPosition + Vector3.new(
        math.cos(fallbackAngle) * (FORMATION_RADIUS + 5),
        GROUND_HEIGHT,
        math.sin(fallbackAngle) * (FORMATION_RADIUS + 5)
    )
end

-- Update teleported players positions
local function updatePlayerPosition(player, position)
    teleportedPlayers[player] = position
end

-- Remove players from tracking when they leave
local function cleanupPlayer(player)
    teleportedPlayers[player] = nil
end

-- Main teleport function
local function teleportToFormation()
    if not targetPlayer or not targetPlayer.Character then
        return
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not targetRoot or not localRoot or localPlayer == targetPlayer then
        return
    end
    
    local targetPosition = targetRoot.Position
    local teleportPosition = getFormationPosition(targetPosition, localPlayer)
    
    -- Teleport the player
    localRoot.CFrame = CFrame.new(teleportPosition)
    updatePlayerPosition(localPlayer, teleportPosition)
end

-- Find the target player
local function findTargetPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
            targetPlayer = player
            break
        end
    end
    
    if not targetPlayer then
        warn("Target player not found: " .. TARGET_USERNAME)
        return false
    end
    
    return true
end

-- Start the teleportation
local function startTeleporting()
    if connection then
        connection:Disconnect()
    end
    
    if not findTargetPlayer() then
        return
    end
    
    connection = RunService.Heartbeat:Connect(function()
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(teleportToFormation)
        end
    end)
end

-- Stop the teleportation
local function stopTeleporting()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    targetPlayer = nil
    teleportedPlayers = {}
end

-- Track other players leaving
Players.PlayerRemoving:Connect(function(player)
    cleanupPlayer(player)
    if player == targetPlayer then
        stopTeleporting()
    end
end)

-- Auto-reconnect if target player joins later
Players.PlayerAdded:Connect(function(player)
    if (player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME) and not targetPlayer then
        startTeleporting()
    end
end)

-- Initial start
startTeleporting()

-- Optional: Add a way to stop the script
local stopKey = Enum.KeyCode.F2

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == stopKey then
        stopTeleporting()
        print("Teleportation stopped")
    end
end)

print("Bow formation teleport script started. Press F2 to stop.")
