setfpscap(5)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local TARGET_USERNAME = "hiraethent" -- The player with the bow
local FORMATION_RADIUS = 8 -- Distance from target player
local MIN_DISTANCE = 6 -- Minimum distance between teleported players
local GROUND_HEIGHT = 2.5 -- Closer to ground for arrow hitboxes
local SAFE_AREA_CENTER = Vector3.new(-2, 23, 3)
local SAFE_AREA_RADIUS = 50

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil
local teleportedPlayers = {} -- Track all teleported players to avoid collisions

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

-- Function to get a safe formation position around the target
local function getFormationPosition(targetPosition, player)
    local attempts = 0
    local maxAttempts = 20
    
    while attempts < maxAttempts do
        -- Use consistent angles based on player for formation
        local playerCount = math.max(1, #Players:GetPlayers() - 1) -- Exclude target
        local angleIncrement = (2 * math.pi) / playerCount
        local playerIndex = 0
        
        -- Find this player's index
        for i, p in ipairs(Players:GetPlayers()) do
            if p == player and p ~= targetPlayer then
                playerIndex = i
                break
            end
        end
        
        local angle = playerIndex * angleIncrement + (math.sin(time() * 0.5) * 0.2) -- Slight movement
        
        local position = targetPosition + Vector3.new(
            math.cos(angle) * FORMATION_RADIUS,
            GROUND_HEIGHT, -- Close to ground for arrow hitboxes
            math.sin(angle) * FORMATION_RADIUS
        )
        
        -- Check if position is safe and not too close to others
        if isInSafeArea(position) and not isTooCloseToOthers(position, player) then
            return position
        end
        
        attempts += 1
        
        -- Try random position if formation fails
        if attempts > 10 then
            local randomAngle = math.random() * 2 * math.pi
            local randomRadius = math.random(FORMATION_RADIUS - 2, FORMATION_RADIUS + 2)
            
            position = targetPosition + Vector3.new(
                math.cos(randomAngle) * randomRadius,
                GROUND_HEIGHT,
                math.sin(randomAngle) * randomRadius
            )
        end
    end
    
    -- Fallback position
    return targetPosition + Vector3.new(
        math.random(-FORMATION_RADIUS, FORMATION_RADIUS),
        GROUND_HEIGHT,
        math.random(-FORMATION_RADIUS, FORMATION_RADIUS)
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
