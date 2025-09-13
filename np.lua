

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Just above the target
local SAFE_TELEPORT_DISTANCE = 40 -- How far away to teleport if same team

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

-- NEW: Track if we are in the "go below" phase for non-team targets
local isGoingBelow = false
local belowTimer = 0
local BELOW_DELAY = 3 -- Wait 3 seconds before going below
local BELOW_OFFSET = Vector3.new(0, -10, 0) -- 10 studs below

-- Check if on same team
local function onSameTeam()
    -- NEW: Check for FFA mode first. If anyone is FFA, treat as non-team.
    if not targetPlayer or not targetPlayer:FindFirstChild("Stats") then return false end
    if not localPlayer:FindFirstChild("Stats") then return false end

    local targetTeam = targetPlayer.Stats:FindFirstChild("Team")
    local localTeam = localPlayer.Stats:FindFirstChild("Team")

    if not targetTeam or not localTeam then return false end
    
    -- If either player is in FFA, they are not on a team together.
    if targetTeam.Value == "FFA" or localTeam.Value == "FFA" then
        return false
    end
    -- Otherwise, check if their team values match.
    return targetTeam.Value == localTeam.Value
end

-- Teleport logic
local function teleportToTarget()
    -- NEW: CRITICAL - Check if the local player is alive and has a character
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
        isGoingBelow = false
        belowTimer = 0
        -- Teleport far away from teammate
        local direction = (localRoot.Position - targetRoot.Position).Unit
        localRoot.CFrame = CFrame.new(targetRoot.Position + direction * SAFE_TELEPORT_DISTANCE + Vector3.new(0, 5, 0))
    else
        -- Logic for non-teammates (or FFA)
        belowTimer = belowTimer + RunService.Heartbeat:Wait()

        if belowTimer < BELOW_DELAY then
            -- Phase 1: Stay above the target
            localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET
        else
            -- Phase 2: After the delay, go below to trigger insta-kill
            localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
        end
    end
end

-- Find target
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

-- Start
local function startTeleporting()
    if connection then connection:Disconnect() end
    if not findTargetPlayer() then return end

    -- NEW: Reset the below state when starting to teleport to a new target
    isGoingBelow = false
    belowTimer = 0

    connection = RunService.Heartbeat:Connect(function()
        pcall(teleportToTarget) -- Use pcall to prevent errors from breaking the loop
    end)
end

-- Stop
local function stopTeleporting()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    targetPlayer = nil
    -- NEW: Reset the below state when stopping
    isGoingBelow = false
    belowTimer = 0
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

-- NEW: Check for death on character respawns
local function onCharacterAdded(character)
    -- This event fires when a new character is created (e.g., after death)
    -- The alive check in teleportToTarget will handle it from here.
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
-- If we already have a character when the script starts, set up the event for it.
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

print("Main teleport script running (no randomness). Press F2 to stop.")
