local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local TARGET_USERNAME = "hiraethent" -- Replace with the target player's username
local WEAPON_RADIUS = 6 -- Studs
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Offset to avoid spawning in ground
local SAFE_AREA_CENTER = Vector3.new(-2, 23, 3) -- Middle area center
local SAFE_AREA_RADIUS = 50 -- Adjust based on your map size

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

-- Function to check if a position is within the safe area
local function isInSafeArea(position)
    return (position - SAFE_AREA_CENTER).Magnitude <= SAFE_AREA_RADIUS
end

-- Function to get a random position around the target within weapon range
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

-- Function to get a safe position near the target
local function getSafeTeleportPosition(targetPosition)
    local attempts = 0
    local maxAttempts = 10
    
    while attempts < maxAttempts do
        local potentialPosition = getRandomPositionAroundTarget(targetPosition)
        
        -- Check if the position is within the safe area
        if isInSafeArea(potentialPosition) then
            return potentialPosition
        end
        
        attempts += 1
    end
    
    -- If no safe position found after attempts, return a position closer to safe area center
    local directionToCenter = (SAFE_AREA_CENTER - targetPosition).Unit
    return targetPosition + (directionToCenter * WEAPON_RADIUS) + TELEPORT_OFFSET
end

-- Main teleport function
local function teleportToTarget()
    if not targetPlayer or not targetPlayer.Character then
        return
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not targetRoot or not localRoot then
        return
    end
    
    local targetPosition = targetRoot.Position
    local teleportPosition = getSafeTeleportPosition(targetPosition)
    
    -- Teleport the player
    localRoot.CFrame = CFrame.new(teleportPosition)
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
            pcall(teleportToTarget) -- Use pcall to prevent errors from breaking the loop
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
end

-- Auto-reconnect if target player joins later
Players.PlayerAdded:Connect(function(player)
    if (player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME) and not targetPlayer then
        startTeleporting()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == targetPlayer then
        stopTeleporting()
        -- Try to find the target again if they rejoin
        task.delay(2, function()
            if findTargetPlayer() then
                startTeleporting()
            end
        end)
    end
end)

-- Initial start
startTeleporting()

-- Optional: Add a way to stop the script
local stopKey = Enum.KeyCode.F2 -- Change to whatever key you prefer

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == stopKey then
        stopTeleporting()
        print("Teleportation stopped")
    end
end)

print("Teleport script started. Press F2 to stop.")
