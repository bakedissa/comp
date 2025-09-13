local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Just above the target
local SAFE_TELEPORT_DISTANCE = 40 -- How far away to teleport if same team
local BELOW_OFFSET = Vector3.new(0, -50, 0) -- Increased from -10 to -50 studs below

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

-- Track if we are in the "go below" phase for non-team targets
local isGoingBelow = false
local belowTimer = 0
local BELOW_DELAY = 3 -- Wait 3 seconds before going below

-- Track if we've already set up the below phase for the current target's life
local hasTriggeredBelowForThisLife = false

-- Check if on same team
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

-- Reset the below state
local function resetBelowState()
    isGoingBelow = false
    belowTimer = 0
    hasTriggeredBelowForThisLife = false
end

-- Teleport logic
local function teleportToTarget()
    -- Check if the local player is alive and has a character
    if not localPlayer.Character then return end
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return -- Stop teleporting if the executor is dead
    end

    if not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    if onSameTeam() then
        -- Reset the below state if we were doing it to someone else and now are on the same team
        resetBelowState()
        -- Teleport far away from teammate
        local direction = (localRoot.Position - targetRoot.Position).Unit
        localRoot.CFrame = CFrame.new(targetRoot.Position + direction * SAFE_TELEPORT_DISTANCE + Vector3.new(0, 5, 0))
    else
        -- Only start the timer if we haven't already triggered the below phase for this life
        if not hasTriggeredBelowForThisLife then
            belowTimer = belowTimer + RunService.Heartbeat:Wait()
        end

        if belowTimer < BELOW_DELAY then
            -- Phase 1: Stay above the target
            localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET
        else
            -- Phase 2: After the delay, go below to trigger insta-kill
            localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
            hasTriggeredBelowForThisLife = true
        end
    end
end

-- Find target
local function findTargetPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
            targetPlayer = player
            -- Reset below state when we find a new target
            resetBelowState()
            
            -- Set up event to reset below state when target respawns
            if targetPlayer.Character then
                targetPlayer.CharacterAdded:Connect(function()
                    resetBelowState()
                end)
            end
            
            break
        end
    end
    if not targetPlayer then
        warn("Target player not found: " .. TARGET_USERNAME)
        return false
    end
    return true
end

-- Start
local function startTeleporting()
    if connection then connection:Disconnect() end
    if not findTargetPlayer() then return end

    connection = RunService.Heartbeat:Connect(function()
        pcall(teleportToTarget)
    end)
end

-- Stop
local function stopTeleporting()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    targetPlayer = nil
    resetBelowState()
end

-- Player events
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

-- Check for death on character respawns
local function onCharacterAdded(character)
    -- Reset below state when our character respawns
    resetBelowState()
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end

-- Initial
startTeleporting()

-- Stop key
local stopKey = Enum.KeyCode.F2
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == stopKey then
        stopTeleporting()
        print("Teleportation stopped")
    end
end)

print("Main teleport script running. Press F2 to stop.")
