local Players = game:GetService("Players") 
 local RunService = game:GetService("RunService") 
 local UserInputService = game:GetService("UserInputService") 

 -- Config 
 local TARGET_USERNAME = "hiraethent" 
 local BELOW_OFFSET = Vector3.new(0, -50, 0)       -- Kill offset for teammates
 local ENEMY_TELEPORT_RADIUS = 13                  -- NEW: Radius for enemy teleport
 
 local localPlayer = Players.LocalPlayer 
 local targetPlayer = nil 
 local connection = nil 

 -- State 
 local isAlive = false 
 local hasTeleportedThisLife = false -- Simplified state for one-time teleport

 -- Debug print only when actions occur 
 local function debugAction(tag, msg) 
     print(string.format("[%s] %s", tag, msg)) 
 end 

 -- Reset teleport state
 local function resetTeleportState() 
     hasTeleportedThisLife = false 
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

 -- Core teleport logic (REWRITTEN)
 local function teleportToTarget() 
     -- Exit if dead or if we've already teleported this life
     if not isAlive or hasTeleportedThisLife then return end

     if not targetPlayer or not targetPlayer.Character then return end 
     local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart") 
     local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") 
     if not targetRoot or not localRoot then return end 

     if onSameTeam() then
         -- SAME TEAM: Teleport below them to kill them
         localRoot.CFrame = targetRoot.CFrame + BELOW_OFFSET
         debugAction("teleport", "Same team. Teleporting below target.")
         hasTeleportedThisLife = true -- Mark teleport as done for this life
     else
         -- ENEMY TEAM / FFA: Teleport to a random spot in a radius and stay
         local randomAngle = math.random() * 2 * math.pi
         local offsetX = math.cos(randomAngle) * ENEMY_TELEPORT_RADIUS
         local offsetZ = math.sin(randomAngle) * ENEMY_TELEPORT_RADIUS
         
         local randomPosition = targetRoot.Position + Vector3.new(offsetX, 0, offsetZ)
         
         localRoot.CFrame = CFrame.new(randomPosition)
         debugAction("teleport", "Enemy team. Teleporting to radius.")
         hasTeleportedThisLife = true -- Mark teleport as done for this life
     end
 end 

 -- Find target 
 local function findTargetPlayer() 
     for _, player in ipairs(Players:GetPlayers()) do 
         if player.Name == TARGET_USERNAME or player.DisplayName == TARGET_USERNAME then 
             targetPlayer = player 
             resetTeleportState() 

             player.CharacterAdded:Connect(function() 
                 resetTeleportState()
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

     connection = RunService.Heartbeat:Connect(function() 
         pcall(teleportToTarget) 
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
     resetTeleportState() 
 end 

 -- Alive tracking 
 local function hookAlive()
     local aliveValue = localPlayer:WaitForChild("Alive")
 
     local function updateAliveStatus(newStatus)
         if newStatus == isAlive then
             return
         end
 
         isAlive = newStatus
 
         if isAlive then
             resetTeleportState()
             debugAction("life", "LocalPlayer is now ALIVE")
         else
             resetTeleportState()
             debugAction("life", "LocalPlayer is now DEAD")
         end
     end
 
     aliveValue.Changed:Connect(updateAliveStatus)
     updateAliveStatus(aliveValue.Value)
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
     resetTeleportState() 
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
