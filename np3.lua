local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Just above the target
local SAFE_TELEPORT_DISTANCE = 40 -- How far away to teleport if same team
local BELOW_OFFSET = Vector3.new(0, -50, 0)
local BELOW_DELAY = 3 -- Wait 3 seconds before going below

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

-- State trackers
local isGoingBelow = false
local belowTimer = 0
local hasTriggeredBelowForThisLife = false

-- Debug toggle
local DEBUG = true

local function debugPrint(...)
    if DEBUG then
        print("[DEBUG]:", ...)
    end
end

-- Check if on same team
local function onSameTeam()
    if not targetPlayer or not targetPlayer:FindFirstChild("Stats") then return false end
    if not localPlayer:FindFirstChild("Stats") then return false end

    local targetTeam = targetPlayer.Stats:FindFirstChild("Team")
    local localTeam = localPlayer.Stats:FindFirstChild("Team")

    if not targetTeam or not localTeam then return false end

    if targetTeam.Value == "FFA" or localTeam.Value == "FFA" then
        debugPrint("Team check → One is FFA → treated as enemies")
        return false
    end

    debugPrint("Team check → local:", localTeam.Value, "target:", targetTeam.Value)
    return targetTeam.Value == localTeam.Value
end

-- Reset the below state
local function resetBelowState()
    isGoingBelow = false
    belowTimer = 0
    hasTriggeredBelowForThisLife = false
    debugPrint("Reset below state")
end

-- Teleport logic
local function teleportToTarget()
    if not localPlayer.Character then return end
    local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        debugPrint("Hunter is NOT alive → teleport paused")
        return
    end

    debugPrint("Hunter is alive")

    if not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    if onSameTeam() then
        resetBelowState()
        local direction = (localRoot.Position - targetRoot.Position).Unit
        localRoot.CFrame = CFrame.new(targetRoot.Position + direction * SAFE_TELEPORT_DISTANCE + Vector3.new(0, 5, 0))
        debugPrint("Same team → teleporting SAFE distance away")
    else
        if not hasTriggeredBelowForThisLife then
            belowTimer = belowTimer + RunService.Heartbeat:Wait()
        end

        if belowTimer < BELOW_DELAY then
            localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET
            debugPrint("Phase 1 → Above target (", math.floor(BELOW_DELAY - belowTimer), "s left )")
        else
            localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
            hasTriggeredBelowForThisLife = true
            debugPrint("Phase 2 → BELOW target (insta-kill phase)")
        end
    end
end

-- Find target
local function findTargetPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
            targetPlayer = player
            resetBelowState()
            debugPrint("Found target:", player.Name)

            if targetPlayer.Character then
                targetPlayer.CharacterAdded:Connect(function()
                    resetBelowState()
                    debugPrint("Target respawned → reset state")
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

    debugPrint("Started teleport loop")
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
    debugPrint("Stopped teleport loop")
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

-- Local respawn
local function onCharacterAdded(character)
    resetBelowState()
    debugPrint("Hunter respawned → reset state")
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
