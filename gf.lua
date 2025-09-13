--[[
    Title: Teleport & Utility GUI (Merged v1.6 - Full)
    Description: Teleport, Combat, Utility GUI with Juggernaut/Infected logic, 
                 Auto Upgrade, Unarmed hug kill, and flexible hitbox support.
    Author: Gemini (merged + patched)
    Notes: v1.6 - Full script
]]

-- =========================
-- LIBRARIES / SERVICES
-- =========================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Waits (critical folders)
local CharactersFolder = Workspace:WaitForChild("Characters")

-- =========================
-- WINDOW / TABS / UI
-- =========================
local Window = Fluent:CreateWindow({
    Title = "Utility GUI",
    SubTitle = "v1.6 (Full)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Automation = Window:AddTab({ Title = "Automation", Icon = "bot" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- =========================
-- GLOBALS / REMOTES / STATE
-- =========================
local localPlayer = Players.LocalPlayer
local targetPlayer = nil

local heartbeatConnection = nil -- teleport loop connection
local killConnection = nil -- kill loop connection
local hitboxConnection = nil -- hitbox visuals connection

-- Remotes & values
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local skipRemote = Remotes:WaitForChild("SkipVoteRequest")
local purchaseWeaponUpgrade = Remotes:WaitForChild("PurchaseWeaponUpgrade") -- RemoteFunction
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")

-- State
local isAlive = false
local hasTeleportedThisLife = false

-- Boundaries / safety
local SAFE_MIN = Vector3.new(-25, -math.huge, -26)
local SAFE_MAX = Vector3.new(27, math.huge, 28)
local BOUNDARY_PADDING = 2

-- Misc
local originalHitboxProperties = {} -- for visuals revert

-- =========================
-- UTIL HELPERS
-- =========================
local function debugAction(tag, msg)
    print(string.format("[%s] %s", tag or "debug", tostring(msg)))
end

local function resetTeleportState()
    hasTeleportedThisLife = false
end

local function clampInsideBounds(pos)
    local x = math.clamp(pos.X, SAFE_MIN.X + BOUNDARY_PADDING, SAFE_MAX.X - BOUNDARY_PADDING)
    local z = math.clamp(pos.Z, SAFE_MIN.Z + BOUNDARY_PADDING, SAFE_MAX.Z - BOUNDARY_PADDING)
    return Vector3.new(x, pos.Y, z)
end

local function isInSafeArea(position)
    -- same center as previous scripts
    return (position - Vector3.new(-2, 23, 3)).Magnitude <= 50
end

local function getSafeTeleportPosition(targetPosition)
    local randomAngle = math.random() * 2 * math.pi
    local randomDistance = 2 + math.random() * (3 - 2)
    local offset = Vector3.new(math.cos(randomAngle) * randomDistance, 0, math.sin(randomAngle) * randomDistance)
    local potentialPosition = targetPosition + offset + Vector3.new(0, 4, 0)
    if isInSafeArea(potentialPosition) then
        return potentialPosition
    else
        local directionToCenter = (Vector3.new(-2, 23, 3) - targetPosition).Unit
        return targetPosition + (directionToCenter * 3) + Vector3.new(0, 4, 0)
    end
end

local function onSameTeam(p1, p2)
    if not p1 or not p2 then return false end
    if not p1:FindFirstChild("Stats") or not p2:FindFirstChild("Stats") then return false end
    local t1 = p1.Stats:FindFirstChild("Team")
    local t2 = p2.Stats:FindFirstChild("Team")
    if not t1 or not t2 then return false end
    if t1.Value == "FFA" or t2.Value == "FFA" then return false end
    return t1.Value == t2.Value
end

local function getRole()
    -- return "Infected", "Juggernaut", "MultiJuggernaut" or nil
    if not localPlayer:FindFirstChild("Stats") then return nil end
    local teamVal = localPlayer.Stats:FindFirstChild("Team")
    local hunterVal = localPlayer.Stats:FindFirstChild("Hunter")
    if teamVal and teamVal.Value == "Infected" then
        return "Infected"
    elseif hunterVal and (hunterVal.Value == "Juggernaut" or hunterVal.Value == "MultiJuggernaut") then
        return hunterVal.Value
    end
    return nil
end

-- =========================
-- TELEPORT LOGIC
-- =========================
local function teleportToTarget()
    if not isAlive or not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end

    local role = getRole()
    if onSameTeam(localPlayer, targetPlayer) or role == "Infected" or role == "Juggernaut" or role == "MultiJuggernaut" then
        -- one-time per life teleport to the void (40-50 studs down)
        if not hasTeleportedThisLife then
            localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, -50, 0)
            debugAction("teleport", "Void-kill teleport executed (same-team or special role).")
            hasTeleportedThisLife = true
        end
        return
    end

    -- normal safe teleport near target
    local teleportPosition = clampInsideBounds(getSafeTeleportPosition(targetRoot.Position))
    localRoot.CFrame = CFrame.new(teleportPosition)
end

-- =========================
-- KILL / ATTACK LOGIC
-- =========================
-- Accept both Hitbox and WeaponHitBox and fall back to Part
local function findWeaponHitboxForModel(model)
    if not model then return nil end
    -- direct children check
    local candidates = { "Hitbox", "WeaponHitBox", "Part" }
    for _, name in ipairs(candidates) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    -- deeper search (descendants)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Name == "Hitbox" or desc.Name == "WeaponHitBox" or desc.Name == "Part") then
            return desc
        end
    end
    return nil
end

local function isAttackable(target)
    if not target or target == localPlayer then return false end
    if not target:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end

    -- skip shield users if option enabled
    if Options.SkipShieldUsers and Options.SkipShieldUsers.Value then
        local weaponVal = target.Stats:FindFirstChild("Weapon")
        if weaponVal and weaponVal.Value == "Shield" then
            return false
        end
    end

    local tTeam = target.Stats:FindFirstChild("Team")
    local lTeam = localPlayer.Stats:FindFirstChild("Team")
    if not tTeam or not lTeam then return false end
    local tVal = tTeam.Value
    local lVal = lTeam.Value

    if tVal == "FFA" or lVal == "FFA" or tVal == "Survivor" or lVal == "Survivor" then
        return true
    end

    return tVal ~= lVal
end

local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end

    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    -- Build potential target list
    local potentialTargets = {}
    if Options.KillAllPlayers.Value then
        potentialTargets = Players:GetPlayers()
    elseif Options.KillPlayers.Value then
        for name, selected in pairs(Options.KillTargets.Value) do
            if selected then
                local p = Players:FindFirstChild(name)
                if p then table.insert(potentialTargets, p) end
            end
        end
    end

    -- Filter valid targets
    local validTargets = {}
    for _, p in ipairs(potentialTargets) do
        local aliveVal = p:FindFirstChild("Alive")
        if aliveVal and aliveVal.Value == true and isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validTargets, p)
        end
    end

    if #validTargets == 0 then return end
    table.sort(validTargets, function(a,b) return a.Name < b.Name end)

    local finalTarget = validTargets[1]
    if not finalTarget or not finalTarget.Character then return end
    local targetRoot = finalTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- If player role is special => void-kill
    local role = getRole()
    if role == "Infected" or role == "Juggernaut" or role == "MultiJuggernaut" then
        localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, -50, 0)
        debugAction("kill", "Void kill performed due to special role.")
        return
    end

    -- determine equipped tool
    local tool = nil
    if localPlayer.Character then
        tool = localPlayer.Character:FindFirstChildOfClass("Tool")
    end

    -- UNARMED handling: stick close behind the target to maintain contact
    if tool and tool.Name == "Unarmed" or (not tool and Options.ForceUnarmedAsHug and Options.ForceUnarmedAsHug.Value) then
        -- hug distance (1 stud behind target). Adjust if necessary.
        local hugOffset = CFrame.new(0, 0, -1)
        -- keep local player's current Y so we don't clip weirdly
        local desired = targetRoot.CFrame * hugOffset
        local finalPos = Vector3.new(desired.X, localRoot.Position.Y, desired.Z)
        localRoot.CFrame = CFrame.new(finalPos, targetRoot.Position)
        return
    end

    -- Normal weapon behavior: attempt to position weapon hitbox parts behind target (use player's character model under CharactersFolder)
    local localCharModel = CharactersFolder:FindFirstChild(localPlayer.Name)
    local localWeaponName = localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon") and localPlayer.Stats.Weapon.Value or nil
    local weaponPart = nil
    if localCharModel and localWeaponName then
        local weaponModel = localCharModel:FindFirstChild(localWeaponName)
        weaponPart = findWeaponHitboxForModel(weaponModel)
    end

    if weaponPart and targetRoot then
        local weaponRange = 0
        pcall(function() weaponRange = weaponPart.Size.Z end)
        local targetPosition = targetRoot.Position
        local desiredPos = targetPosition - (targetRoot.CFrame.LookVector * weaponRange)
        desiredPos = clampInsideBounds(desiredPos)

        local finalPos = Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z)
        localRoot.CFrame = CFrame.new(finalPos, targetPosition)
        return
    end

    -- Fallback: try to move any local character "Hitbox" or "WeaponHitBox" parts into position (descendants of character)
    for _, part in ipairs(localPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Hitbox" or part.Name == "WeaponHitBox" or part.Name == "Part") then
            local offsetCF = targetRoot.CFrame * CFrame.new(0, 0, -3)
            pcall(function() part.CFrame = offsetCF end)
        end
    end
end

-- =========================
-- HITBOX VISUALS (ShowHitboxes)
-- =========================
local function revertHitboxVisuals(part)
    if originalHitboxProperties[part] then
        pcall(function()
            part.Color = originalHitboxProperties[part].Color
            part.Transparency = originalHitboxProperties[part].Transparency
        end)
        originalHitboxProperties[part] = nil
    end
end

local function revertAllHitboxVisuals()
    for part, _ in pairs(originalHitboxProperties) do
        if part and part.Parent then
            revertHitboxVisuals(part)
        end
    end
    originalHitboxProperties = {}
end

local function updateAllHitboxVisuals()
    if not Options.ShowHitboxes.Value then return end
    local processedParts = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Weapon") then
            local weaponName = player.Stats.Weapon.Value
            local playerCharacter = CharactersFolder:FindFirstChild(player.Name)
            if playerCharacter then
                local weaponModel = playerCharacter:FindFirstChild(weaponName)
                local hitboxPart = findWeaponHitboxForModel(weaponModel)
                if hitboxPart then
                    table.insert(processedParts, hitboxPart)
                    if not originalHitboxProperties[hitboxPart] then
                        originalHitboxProperties[hitboxPart] = { Color = hitboxPart.Color, Transparency = hitboxPart.Transparency }
                        pcall(function()
                            hitboxPart.Color = Color3.fromRGB(255, 0, 0)
                            hitboxPart.Transparency = 0.5
                        end)
                        hitboxPart.Destroying:Connect(function() originalHitboxProperties[hitboxPart] = nil end)
                    end
                end
            end
        end
    end

    for part, _ in pairs(originalHitboxProperties) do
        if not table.find(processedParts, part) then
            revertHitboxVisuals(part)
        end
    end
end

-- =========================
-- GIMMICK: AUTO UPGRADE
-- =========================
-- We'll call purchaseWeaponUpgrade:InvokeServer(toolName, 1) every heartbeat while enabled and tool exists
-- using pcall to avoid runtime errors if arguments are unexpected
local function autoUpgradeHeartbeat()
    if not Options.AutoUpgradeEnabled.Value then return end
    if not localPlayer.Character then return end
    local tool = localPlayer.Character:FindFirstChildOfClass("Tool")
    if tool and tool.Name ~= "Unarmed" then
        pcall(function()
            purchaseWeaponUpgrade:InvokeServer(tool.Name, 1) -- server may ignore the second arg
        end)
    end
end

-- =========================
-- GUI ELEMENTS
-- =========================
-- Automation Tab
Tabs.Automation:AddParagraph({
    Title = "Automation",
    Content = "How it works:\n- If you are on the same team as the target or you are Infected/Juggernaut/MultiJuggernaut → automation will perform a void-kill teleport (40-50 studs down).\n- Otherwise automation uses a safe offset teleport near the target.\n- Unarmed: when equipped, automation will keep you ~1 stud behind the target to maintain contact (hug kill).\n- Auto Upgrade will attempt to upgrade your equipped weapon using the PurchaseWeaponUpgrade RemoteFunction."
})

local teleportToggle = Tabs.Automation:AddToggle("TeleportEnabled", { Title = "Enable Teleport", Default = false })
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer", { Title = "Select Target", Values = {"None"}, Default = "None" })

Tabs.Automation:AddParagraph({ Title = "Gamemode Skipper", Content = "Automatically vote to skip undesirable game modes." })
local autoSkipToggle = Tabs.Automation:AddToggle("AutoSkipEnabled", { Title = "Enable Auto Skip", Default = false })
local ALL_GAMEMODES = {
    "Teams","Infection","FFA","ColorWar","TeamVampire","CornerDomination",
    "MultiJuggernauts","Juggernaut","LastStand","TugOfWar","Squads","Duos","DuosLastStand"
}
local wantedGamesDropdown = Tabs.Automation:AddDropdown("WantedGamemodes", { Title = "Wanted Gamemodes", Values = ALL_GAMEMODES, Multi = true, Default = {"FFA","Teams","Infection"} })

-- Auto Upgrade toggle
local autoUpgradeToggle = Tabs.Automation:AddToggle("AutoUpgradeEnabled", { Title = "Auto Upgrade Equipped Weapon", Default = false })

-- Combat Tab
Tabs.Combat:AddParagraph({ Title = "Combat Utilities", Content = "Options for combat targeting & visualization." })
local showHitboxesToggle = Tabs.Combat:AddToggle("ShowHitboxes", { Title = "Show Player Hitboxes", Default = false })
local skipShieldToggle = Tabs.Combat:AddToggle("SkipShieldUsers", { Title = "Skip Shield Users", Default = false })
local killAllToggle = Tabs.Combat:AddToggle("KillAllPlayers", { Title = "Kill All Players", Default = false })
local killPlayersToggle = Tabs.Combat:AddToggle("KillPlayers", { Title = "Kill Specific Player(s)", Default = false })
local killPlayersDropdown = Tabs.Combat:AddDropdown("KillTargets", { Title = "Select Targets", Values = {"None"}, Multi = true, Default = {} })

-- Settings Tab
Tabs.Settings:AddParagraph({ Title = "Performance", Content = "Control the game's FPS cap for performance." })
local fpsToggle = Tabs.Settings:AddToggle("FpsCapEnabled", { Title = "Enable FPS Cap", Default = true })
local fpsInput = Tabs.Settings:AddInput("FpsCapValue", { Title = "FPS Limit", Default = "60", Numeric = true, Finished = true })

local function updateFpsCap()
    if Options.FpsCapEnabled.Value then
        local cap = tonumber(Options.FpsCapValue.Value) or 60
        pcall(function() setfpscap(cap) end)
        debugAction("fps", "FPS cap set to " .. tostring(cap))
    else
        pcall(function() setfpscap(999) end)
        debugAction("fps", "FPS cap disabled")
    end
end
fpsToggle:OnChanged(updateFpsCap)
fpsInput:OnChanged(updateFpsCap)

-- =========================
-- EVENT HANDLING / UI WIRING
-- =========================
-- Player lists update
local function updatePlayerLists()
    local singleSelectNames = {"None"}
    local multiSelectNames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(singleSelectNames, p.Name)
            table.insert(multiSelectNames, p.Name)
        end
    end
    playerDropdown:SetValues(singleSelectNames)
    killPlayersDropdown:SetValues(multiSelectNames)

    if Options.TargetPlayer and not table.find(singleSelectNames, Options.TargetPlayer.Value) then
        playerDropdown:SetValue("None")
    end
end

Players.PlayerAdded:Connect(updatePlayerLists)
Players.PlayerRemoving:Connect(function(player)
    updatePlayerLists()
    if player == targetPlayer then
        -- if our target left, stop teleporting
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        targetPlayer = nil
    end
end)

-- Alive tracking
local function hookAlive()
    local aliveValue = localPlayer:WaitForChild("Alive")
    local function updateAliveStatus(newStatus)
        isAlive = newStatus
        if isAlive then
            resetTeleportState()
            debugAction("life", "LocalPlayer is now ALIVE")
        else
            debugAction("life", "LocalPlayer is now DEAD")
        end
    end
    aliveValue.Changed:Connect(updateAliveStatus)
    updateAliveStatus(aliveValue.Value)
end

localPlayer.CharacterAdded:Connect(function()
    resetTeleportState()
    hookAlive()
    debugAction("system", "LocalPlayer respawned, reset state")
end)

-- Teleport toggle wiring
teleportToggle:OnChanged(function()
    if Options.TeleportEnabled.Value then
        -- start teleport loop
        if heartbeatConnection then heartbeatConnection:Disconnect() heartbeatConnection = nil end
        if Options.TargetPlayer and Options.TargetPlayer.Value and Options.TargetPlayer.Value ~= "None" then
            targetPlayer = Players:FindFirstChild(Options.TargetPlayer.Value)
            if targetPlayer then
                heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
                debugAction("system", "Teleport loop started for " .. targetPlayer.Name)
            end
        end
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation enabled.", Duration = 2 })
    else
        if heartbeatConnection then heartbeatConnection:Disconnect() heartbeatConnection = nil end
        targetPlayer = nil
        Fluent:Notify({ Title = "Teleport", Content = "Teleportation disabled.", Duration = 2 })
        debugAction("system", "Teleportation disabled")
    end
end)

playerDropdown:OnChanged(function()
    -- update target and restart teleport if enabled
    if Options.TeleportEnabled.Value and Options.TargetPlayer.Value and Options.TargetPlayer.Value ~= "None" then
        if heartbeatConnection then heartbeatConnection:Disconnect() heartbeatConnection = nil end
        if findTargetPlayer then
            -- ensure the function exists (it does)
        end
        targetPlayer = Players:FindFirstChild(Options.TargetPlayer.Value)
        if targetPlayer then
            heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
            debugAction("system", "Teleport loop updated for " .. targetPlayer.Name)
        end
    else
        if heartbeatConnection then heartbeatConnection:Disconnect() heartbeatConnection = nil end
        targetPlayer = nil
    end
end)

-- Gamemode skip wiring
autoSkipToggle:OnChanged(function()
    if Options.AutoSkipEnabled.Value then
        handleGamemodeSkip()
    end
end)
wantedGamesDropdown:OnChanged(handleGamemodeSkip)
gameModeValue.Changed:Connect(handleGamemodeSkip)

-- Hitbox visuals wiring
showHitboxesToggle:OnChanged(function()
    if Options.ShowHitboxes.Value then
        if not hitboxConnection then
            hitboxConnection = RunService.Heartbeat:Connect(updateAllHitboxVisuals)
            debugAction("hitbox", "Hitbox visuals enabled")
        end
    else
        if hitboxConnection then
            hitboxConnection:Disconnect()
            hitboxConnection = nil
        end
        revertAllHitboxVisuals()
        debugAction("hitbox", "Hitbox visuals disabled")
    end
end)

-- Kill loop master control
local function updateKillLoopState()
    local killAllEnabled = Options.KillAllPlayers and Options.KillAllPlayers.Value
    local killSpecificEnabled = Options.KillPlayers and Options.KillPlayers.Value
    local shouldBeRunning = killAllEnabled or killSpecificEnabled
    if shouldBeRunning and not killConnection then
        killConnection = RunService.Heartbeat:Connect(function() pcall(killLoop) end)
        debugAction("system", "Kill loop started")
    elseif not shouldBeRunning and killConnection then
        killConnection:Disconnect()
        killConnection = nil
        debugAction("system", "Kill loop stopped")
    end
end
killAllToggle:OnChanged(updateKillLoopState)
killPlayersToggle:OnChanged(updateKillLoopState)
killPlayersDropdown:OnChanged(updateKillLoopState)

-- Auto-upgrade heartbeat wiring: efficient single connection that checks option and acts
local autoUpgradeConnection = RunService.Heartbeat:Connect(function()
    pcall(autoUpgradeHeartbeat)
end)

-- =========================
-- HELPER: findTargetPlayer (used in a few places)
-- =========================
function findTargetPlayer(username)
    targetPlayer = Players:FindFirstChild(username)
    if targetPlayer then
        resetTeleportState()
        debugAction("target", "Target found: " .. targetPlayer.Name)
        -- reconnect on respawn to reset state
        targetPlayer.CharacterAdded:Connect(function() resetTeleportState() debugAction("target","Target respawned") end)
    else
        warn("Target not found: " .. tostring(username))
    end
    return targetPlayer ~= nil
end

-- =========================
-- INITIALIZE / SAVE MANAGER
-- =========================
-- Populate UI lists and hook everything
local function initialSetup()
    hookAlive()
    updatePlayerLists()
    task.wait(1)
    handleGamemodeSkip()
    updateFpsCap()
end

-- SaveManager / InterfaceManager wiring
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "TargetPlayer", "KillTargets" })
InterfaceManager:SetFolder("FluentUtility")
SaveManager:SetFolder("FluentUtility/Config")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Fluent GUI",
    Content = "The script has been loaded successfully.",
    SubContent = "Press Right Ctrl to minimize.",
    Duration = 6
})

SaveManager:LoadAutoloadConfig()
initialSetup()

-- =========================
-- END OF SCRIPT
-- =========================
