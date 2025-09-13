local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TARGET_USERNAME = "hiraethent"
local BELOW_OFFSET = Vector3.new(0, -5, 0) -- Below the target

local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local connection = nil

local function teleportBelowTarget()
	if not targetPlayer or not targetPlayer.Character then return end
	local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not localRoot then return end

	localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
end

local function findTargetPlayer()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then
			targetPlayer = player
			break
		end
	end
	return targetPlayer ~= nil
end

local function startTeleporting()
	if connection then connection:Disconnect() end
	if not findTargetPlayer() then return end

	connection = RunService.Heartbeat:Connect(function()
		if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
			pcall(teleportBelowTarget)
		end
	end)
end

local function stopTeleporting()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	targetPlayer = nil
end

Players.PlayerAdded:Connect(function(player)
	if (player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME) and not targetPlayer then
		startTeleporting()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player == targetPlayer then
		stopTeleporting()
	end
end)

-- Start once
startTeleporting()
print("Testing script started: teleporting below target.")
