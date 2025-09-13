local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_USERNAME = "hiraethent"
local TELEPORT_OFFSET = Vector3.new(0, 3, 0) -- Just above the target
local BELOW_OFFSET = Vector3.new(0, -11, 0)  -- Below offset
local BELOW_DELAY = 5 -- seconds before going below

local DEBUG = true -- toggle debug action messages

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil
local targetCharConn = nil

-- State trackers
local belowTimer = 0
local hasTriggeredBelowForThisLife = false

-- Action-only debug helper
local lastActionMessage = nil
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
-- prefers Stats.Alive BoolValue, then Character.Alive, then Humanoid.Health
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

-- Reset below state each life
local function resetBelowState()
	belowTimer = 0
	hasTriggeredBelowForThisLife = false
	debugAction("reset_below_state", "timer and flags cleared")
end

-- Unified teleport logic
local function teleportToTarget(dt)
	-- Hunter alive check
	if not isPlayerAlive(localPlayer) then return end
	if not targetPlayer or not isPlayerAlive(targetPlayer) then return end

	local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not localRoot then return end

	-- Decide if we should force enemy behavior
	local forceEnemyLogic = false
	local localTeam = localPlayer.Stats and localPlayer.Stats:FindFirstChild("Team")
	local targetTeam = targetPlayer.Stats and targetPlayer.Stats:FindFirstChild("Team")

	-- Force enemy if hunter is Infected
	if localTeam and localTeam.Value == "Infected" then
		forceEnemyLogic = true
	end

	-- Force enemy if target is Infected
	if targetTeam and targetTeam.Value == "Infected" then
		forceEnemyLogic = true
	end

	-- Handle the special Infected rule
	if forceEnemyLogic then
		if not hasTriggeredBelowForThisLife then
			localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
			hasTriggeredBelowForThisLife = true
			debugAction("force_below_infected", "forced below because Infected detected")
		end
		return
	end

	-- Normal phased above → below cycle
	if not hasTriggeredBelowForThisLife then
		belowTimer = belowTimer + (dt or 0)
	end

	if belowTimer < BELOW_DELAY then
		-- Phase 1: above
		localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET
		debugAction("teleport_above", string.format("above target (%.2fs left)", BELOW_DELAY - belowTimer))
	else
		-- Phase 2: below
		localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
		hasTriggeredBelowForThisLife = true
		debugAction("teleport_below", "below target (insta-kill phase)")
	end
end

-- Find target
local function findTargetPlayer()
	if targetCharConn then
		targetCharConn:Disconnect()
		targetCharConn = nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
			targetPlayer = player
			resetBelowState()
			debugAction("found_target", player.Name)

			-- Reset below state on target respawn
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
