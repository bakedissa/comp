local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Just above the target
local SAFE_TELEPORT_DISTANCE = 40 -- How far away to teleport if same team
local BELOW_OFFSET = Vector3.new(0, -50, 0)
local BELOW_DELAY = 3 -- Wait 3 seconds before going below

local DEBUG = true -- set to false to silence debug

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil
local targetCharConn = nil

-- State trackers
local isGoingBelow = false
local belowTimer = 0
local hasTriggeredBelowForThisLife = false

-- For action-only debug
local lastActionMessage = nil
local lastLocalAlive = nil
local lastTargetAlive = nil

local function debugAction(action, details)
    if not DEBUG then return end
    details = details or ""
    local message = action .. (details ~= "" and (" - " .. tostring(details)) or "")
    if message ~= lastActionMessage then
        print("[DEBUG ACTION] " .. message)
        lastActionMessage = message
    end
end

-- Robust alive check:
-- 1) prefer Stats.Alive BoolValue (if it exists)
-- 2) then check Character.Alive BoolValue (sometimes present)
-- 3) fallback to Humanoid.Health
local function isPlayerAlive(player)
    if not player then return false end

    local stats = player:FindFirstChild("Stats")
    if stats then
        local aliveVal = stats:FindFirstChild("Alive")
        if aliveVal and aliveVal:IsA("BoolValue") then
            return aliveVal.Value
        end
    end

    if player.Character then
        local aliveInChar = player.Character:FindFirstChild("Alive")
        if aliveInChar and aliveInChar:IsA("BoolValue") then
            return aliveInChar.Value
        end

        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid.Health > 0
        end
    end

    return false
end

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
    -- only log as an action; debugAction will avoid spamming identical messages
    debugAction("reset_below_state", "timer and flags cleared")
end

-- Teleport logic (dt passed from Heartbeat)
local function teleportToTarget(dt)
    -- Confirm hunter/alive via BoolValue fallback
    local localAlive = isPlayerAlive(localPlayer)
    if not localAlive then
        if lastLocalAlive ~= false then
            -- only reset and log on transition to not-alive
            resetBelowState()
            debugAction("paused_hunter_dead", "hunter not alive; teleport paused")
        end
        lastLocalAlive = false
        return
    end
    if lastLocalAlive ~= true then
        debugAction("hunter_alive", "hunter became alive")
    end
    lastLocalAlive = true

    -- confirm target exists
    if not targetPlayer then
        debugAction("no_target", "waiting for target to appear")
        return
    end

    -- confirm target alive
    local targetAlive = isPlayerAlive(targetPlayer)
    if not targetAlive then
        if lastTargetAlive ~= false then
            resetBelowState()
            debugAction("paused_target_dead", "target is not alive; waiting")
        end
        lastTargetAlive = false
        return
    end
    if lastTargetAlive ~= true then
        debugAction("target_alive", "target became alive")
    end
    lastTargetAlive = true

    -- ensure characters/roots exist
    if not localPlayer.Character or not targetPlayer.Character then
        debugAction("missing_character", "character missing for hunter/target")
        return
    end
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot or not targetRoot then
        debugAction("missing_root", "HumanoidRootPart missing")
        return
    end

    if onSameTeam() then
        -- if same team, cancel below-phase behavior and teleport away safely
        if not hasTriggeredBelowForThisLife then
            -- ensure any running below timer isn't carried over
            resetBelowState()
        end

        -- compute safe direction without dividing by zero
        local dirVec = localRoot.Position - targetRoot.Position
        if dirVec.Magnitude == 0 then
            dirVec = Vector3.new(0, 0, 1)
        else
            dirVec = dirVec.Unit
        end

        localRoot.CFrame = CFrame.new(targetRoot.Position + dirVec * SAFE_TELEPORT_DISTANCE + Vector3.new(0, 5, 0))
        debugAction("teleport_safe_distance", "moved away from teammate")
        return
    end

    -- Not same team -> accumulate belowTimer (only if not already triggered for this life)
    if not hasTriggeredBelowForThisLife then
        belowTimer = belowTimer + (dt or 0)
    end

    if belowTimer < BELOW_DELAY then
        -- Phase 1: stay above
        localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET
        local timeLeft = math.max(0, BELOW_DELAY - belowTimer)
        debugAction("teleport_above", string.format("above target (%.2fs left)", timeLeft))
    else
        -- Phase 2: go below once
        localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
        hasTriggeredBelowForThisLife = true
        debugAction("teleport_below", "below target (insta-kill phase)")
    end
end

-- Find target
local function findTargetPlayer()
    -- disconnect any old target CharacterAdded connection
    if targetCharConn then
        targetCharConn:Disconnect()
        targetCharConn = nil
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
            targetPlayer = player
            resetBelowState()
            debugAction("found_target", player.Name)

            -- reset below state on target respawn
            targetCharConn = targetPlayer.CharacterAdded:Connect(function()
                resetBelowState()
                debugAction("target_respawned", "resetting below-phase for new life")
            end)

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

    debugAction("started_teleport_loop", "heartbeat connected")
    connection = RunService.Heartbeat:Connect(function(dt)
        -- pass dt into teleport function; pcall to avoid runtime halting
        pcall(teleportToTarget, dt)
    end)
end

-- Stop
local function stopTeleporting()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    if targetCharConn then
        targetCharConn:Disconnect()
        targetCharConn = nil
    end
    targetPlayer = nil
    resetBelowState()
    debugAction("stopped_teleport_loop", "disconnected")
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
        -- small delay then try to find another match
        task.delay(2, function()
            if findTargetPlayer() then startTeleporting() end
        end)
    end
end)

-- Local respawn: reset below state when our character respawns
local function onCharacterAdded(character)
    resetBelowState()
    debugAction("hunter_respawned", "character added -> reset state")
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
