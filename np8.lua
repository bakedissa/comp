local Players = game:GetService("Players") 
 local RunService = game:GetService("RunService") 
 local UserInputService = game:GetService("UserInputService") 

 -- Config 
 local TARGET_USERNAME = "hiraethent" 
 local TELEPORT_OFFSET = Vector3.new(0, 3, 0)      -- Above target 
 local SAFE_TELEPORT_DISTANCE = 40                 -- Distance for teammate avoidance 
 local BELOW_OFFSET = Vector3.new(0, -50, 0)       -- Kill offset 
 local BELOW_DELAY = 3                             -- Seconds before going below 

 local localPlayer = Players.LocalPlayer 
 local targetPlayer = nil 
 local connection = nil 

 -- State 
 local isAlive = false 
 local belowTimer = 0 
 local hasTriggeredBelowForThisLife = false 

 -- Debug print only when actions occur 
 local function debugAction(tag, msg) 
     print(string.format("[%s] %s", tag, msg)) 
 end 

 -- Reset kill logic state 
 local function resetBelowState() 
     belowTimer = 0 
     hasTriggeredBelowForThisLife = false 
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

 -- Core teleport logic 
 local function teleportToTarget(dt) 
     if not isAlive then return end -- only run when alive 

     if not targetPlayer or not targetPlayer.Character then return end 
     local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart") 
     local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") 
     if not targetRoot or not localRoot then return end 

     local myTeam = localPlayer.Stats and localPlayer.Stats:FindFirstChild("Team") 

     if onSameTeam() and (myTeam and myTeam.Value ~= "Infected") then 
         -- Treat same team as "safe offset" case 
         if not hasTriggeredBelowForThisLife then 
             belowTimer = belowTimer + dt 
         end 

         if belowTimer < BELOW_DELAY then 
             localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET 
         else 
             -- Instead of buggy "safe distance", reuse below-offset style 
             local direction = (localRoot.Position - targetRoot.Position).Unit 
             localRoot.CFrame = CFrame.new( 
                 targetRoot.Position + direction * SAFE_TELEPORT_DISTANCE + Vector3.new(0, 5, 0) 
             ) 
             hasTriggeredBelowForThisLife = true 
         end 
     else 
         -- If on enemy team OR local player is "Infected" → kill offset logic 
         if not hasTriggeredBelowForThisLife then 
             belowTimer = belowTimer + dt 
         end 

         if belowTimer < BELOW_DELAY then 
             localRoot.CFrame = targetRoot.CFrame + TELEPORT_OFFSET 
         else 
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
             resetBelowState() 

             player.CharacterAdded:Connect(function() 
                 resetBelowState() 
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

     connection = RunService.Heartbeat:Connect(function(dt) 
         pcall(function() 
             teleportToTarget(dt) 
         end) 
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
     resetBelowState() 
 end 

 -- Alive tracking (CORRECTED FUNCTION)
 local function hookAlive()
     local aliveValue = localPlayer:WaitForChild("Alive")
 
     local function updateAliveStatus(newStatus)
         -- First, check if the status has actually changed. If not, do nothing.
         if newStatus == isAlive then
             return
         end
 
         -- The status has changed, so update our internal state immediately.
         isAlive = newStatus
 
         -- Now, perform actions based on the new state.
         if isAlive then
             resetBelowState()
             debugAction("life", "LocalPlayer is now ALIVE")
         else
             resetBelowState()
             debugAction("life", "LocalPlayer is now DEAD")
         end
     end
 
     aliveValue.Changed:Connect(updateAliveStatus)
     updateAliveStatus(aliveValue.Value) -- Set the initial state correctly
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
     resetBelowState() 
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
