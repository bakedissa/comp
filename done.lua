--[[ 
Title: Teleport & Utility GUI (Merged, Fixed, Infected Logic) 
Description: Unified Teleport, Combat and Utility GUI using Fluent. 
Includes fixes:sgdfgsdadfghasasegra gsddafgs gadsagsd agsd gdsafgsad 
 - Teleport no longer breaks when a target leaves.
 - Auto combat now reselects new players automatically in Infected mode.
 - Infected-specific logic: Survivors always target Infected, Infected always target Survivors.
Author: Gemini (patched)
]] 

-- Load Fluent library and addons
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Wait for crucial folders
local CharactersFolder = Workspace:WaitForChild("Characters")

-- Create the main GUI Window
local Window = Fluent:CreateWindow({
    Title = "Rotation Wars by issa",
    SubTitle = "https://discord.gg/gZMQFPnPFz",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Add Tabs
local Tabs = {
    Automation = Window:AddTab({ Title = "Automation", Icon = "bot" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Centralized options
local Options = Fluent.Options

-- ========================================================================
-- Script-wide variables
-- ========================================================================
local localPlayer = Players.LocalPlayer
local targetPlayer = nil
local heartbeatConnection, killConnection, hitboxConnection, afkConnection = nil, nil, nil, nil

-- Remotes and Values
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skipRemote = remotes:WaitForChild("SkipVoteRequest")
local purchaseWeaponUpgrade = remotes:WaitForChild("PurchaseWeaponUpgrade")
local gameModeValue = ReplicatedStorage:WaitForChild("GameStatus"):WaitForChild("Gamemode")

-- State
local isAlive = false
local hasTeleportedThisLife = false

-- ========================================================================
-- Debug helper
local function debugAction(tag, msg)
    print(string.format("[%s] %s", tag, tostring(msg)))
end

local function resetTeleportState() hasTeleportedThisLife = false end

-- Team check
local function getTeam(p)
    if not p or not p:FindFirstChild("Stats") then return nil end
    local t = p.Stats:FindFirstChild("Team")
    return t and t.Value or nil
end

local function onSameTeam(p1, p2)
    local t1, t2 = getTeam(p1), getTeam(p2)
    if not t1 or not t2 then return false end
    if t1 == "FFA" or t2 == "FFA" then return false end
    return t1 == t2
end

-- Juggernaut check
local function isJuggernaut()
    if not localPlayer:FindFirstChild("Stats") then return false end
    local h = localPlayer.Stats:FindFirstChild("Hunter")
    return h and (h.Value == "Juggernaut" or h.Value == "MultiJuggernaut")
end

-- Clamp safe pos
local SAFE_MIN = Vector3.new(-25, -math.huge, -26)
local SAFE_MAX = Vector3.new(27, math.huge, 28)
local BOUNDARY_PADDING = 2
local function clampInsideBounds(pos)
    local x = math.clamp(pos.X, SAFE_MIN.X + BOUNDARY_PADDING, SAFE_MAX.X - BOUNDARY_PADDING)
    local z = math.clamp(pos.Z, SAFE_MIN.Z + BOUNDARY_PADDING, SAFE_MAX.Z - BOUNDARY_PADDING)
    return Vector3.new(x, pos.Y, z)
end

-- Teleport core
local function teleportToTarget()
    if not isAlive or not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not localRoot then return end
    if onSameTeam(localPlayer, targetPlayer) or isJuggernaut() then
        if not hasTeleportedThisLife then
            localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, -50, 0)
            hasTeleportedThisLife = true
        end
    else
        local tp = clampInsideBounds(targetRoot.Position + Vector3.new(0, 4, 0))
        localRoot.CFrame = CFrame.new(tp)
    end
end

local function findTargetPlayer(username)
    targetPlayer = Players:FindFirstChild(username)
    if targetPlayer then
        resetTeleportState()
        targetPlayer.CharacterAdded:Connect(resetTeleportState)
    end
    return targetPlayer ~= nil
end

local function stopTeleporting()
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    heartbeatConnection, targetPlayer = nil, nil
    resetTeleportState()
end

local function startTeleporting()
    stopTeleporting()
    if not Options.TeleportEnabled or not Options.TargetPlayer or Options.TargetPlayer.Value == "None" then return end
    if findTargetPlayer(Options.TargetPlayer.Value) then
        heartbeatConnection = RunService.Heartbeat:Connect(function() pcall(teleportToTarget) end)
    end
end

-- ========================================================================
-- Combat targeting logic
-- ========================================================================
local AFKPlayers, lastPositions, currentTarget = {}, {}, nil

-- Attackable check
local function isAttackable(p)
    if not p or p == localPlayer then return false end
    if not p:FindFirstChild("Stats") or not localPlayer:FindFirstChild("Stats") then return false end
    if Options.SkipShieldUsers and Options.SkipShieldUsers.Value then
        local w = p.Stats:FindFirstChild("Weapon")
        if w and w.Value == "Shield" then return false end
    end
    local myTeam, theirTeam = getTeam(localPlayer), getTeam(p)
    if not myTeam or not theirTeam then return false end

    -- Infected gamemode logic
    if gameModeValue.Value == "Infection" then
        if myTeam == "Infected" then
            return theirTeam == "Survivor"
        elseif myTeam == "Survivor" then
            return theirTeam == "Infected"
        end
    end

    -- FFA or other gamemodes
    if myTeam == "FFA" or theirTeam == "FFA" then return true end
    return myTeam ~= theirTeam
end

-- Pick new target
local function pickNewTarget()
    local candidates = {}
    if Options.KillAllPlayers.Value then
        candidates = Players:GetPlayers()
    elseif Options.KillPlayers.Value then
        for n, sel in pairs(Options.KillTargets.Value) do
            if sel then
                local p = Players:FindFirstChild(n)
                if p then table.insert(candidates, p) end
            end
        end
    end
    local valid = {}
    for _, p in ipairs(candidates) do
        if p:FindFirstChild("Alive") and p.Alive.Value and isAttackable(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(valid, p)
        end
    end
    if #valid == 0 then return nil end
    -- AFK priority
    if Options.PrioritizeAFK and Options.PrioritizeAFK.Value then
        for _, p in ipairs(valid) do if AFKPlayers[p] then return p end end
    end
    table.sort(valid, function(a,b) return a.Name < b.Name end)
    return valid[1]
end

local function getActiveTarget()
    if not currentTarget or not currentTarget.Parent or not currentTarget:FindFirstChild("Alive") or not currentTarget.Alive.Value or not isAttackable(currentTarget) then
        currentTarget = pickNewTarget()
    end
    return currentTarget
end

local function killLoop()
    if not isAlive then return end
    if not Options.KillAllPlayers.Value and not Options.KillPlayers.Value then return end
    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local tgt = getActiveTarget()
    if not tgt then return end
    local tgtRoot = tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart")
    if not tgtRoot then return end
    local localW = localPlayer:FindFirstChild("Stats") and localPlayer.Stats:FindFirstChild("Weapon")
    local range = 2
    if localW and localW.Value ~= "Unarmed" then
        local charModel = CharactersFolder:FindFirstChild(localPlayer.Name)
        if charModel then
            local wM = charModel:FindFirstChild(localW.Value)
            local wP = wM and (wM:FindFirstChild("Hitbox") or wM:FindFirstChild("WeaponHitbox") or wM:FindFirstChild("WeaponHitBox") or wM:FindFirstChild("Part"))
            if wP then range = wP.Size.Z or 2 end
        end
    end
    local tgtPos = tgtRoot.Position
    local desiredPos = clampInsideBounds(tgtPos - (tgtRoot.CFrame.LookVector * range))
    localRoot.CFrame = CFrame.new(Vector3.new(desiredPos.X, localRoot.Position.Y, desiredPos.Z), tgtPos)
end

-- ========================================================================
-- GUI Elements (same as before)
-- ========================================================================
Tabs.Automation:AddToggle("TeleportEnabled",{Title="Enable Teleport",Default=false})
local playerDropdown = Tabs.Automation:AddDropdown("TargetPlayer",{Title="Select Target",Values={"None"},Default="None"})
Tabs.Automation:AddToggle("AutoSkipEnabled",{Title="Enable Auto Skip",Default=false})
local ALL_GAMEMODES={"Teams","Infection","FFA","ColorWar","TeamVampire","CornerDomination","MultiJuggernauts","LastStand","TugOfWar","Squads","Duos","DuosLastStand"}
Tabs.Automation:AddDropdown("WantedGamemodes",{Title="Wanted Gamemodes",Values=ALL_GAMEMODES,Multi=true,Default={"FFA","Teams","Infection"}})
Tabs.Automation:AddToggle("AutoUpgrade",{Title="Auto Upgrade Equipped Weapon",Default=false})

Tabs.Combat:AddToggle("ShowHitboxes",{Title="Show Player Hitboxes",Default=false})
Tabs.Combat:AddToggle("SkipShieldUsers",{Title="Skip Shield Users",Default=false})
local killAllToggle=Tabs.Combat:AddToggle("KillAllPlayers",{Title="Kill All Players",Default=false})
local killPlayersToggle=Tabs.Combat:AddToggle("KillPlayers",{Title="Kill Specific Player(s)",Default=false})
local killPlayersDropdown=Tabs.Combat:AddDropdown("KillTargets",{Title="Select Targets",Values={"None"},Multi=true,Default={}})
Tabs.Combat:AddToggle("PrioritizeAFK",{Title="Prioritize AFK Players",Default=true})
Tabs.Combat:AddInput("AFKTime",{Title="AFK Time (s)",Default="2",Numeric=true,Finished=true})
Tabs.Combat:AddInput("AFKThreshold",{Title="AFK Threshold (studs)",Default="0.2",Numeric=true,Finished=true})
Tabs.Combat:AddInput("UnarmedDistance",{Title="Unarmed Distance (studs)",Default="2",Numeric=true,Finished=true})

Tabs.Settings:AddToggle("FpsCapEnabled",{Title="Enable FPS Cap",Default=true})
Tabs.Settings:AddInput("FpsCapValue",{Title="FPS Limit",Default="60",Numeric=true,Finished=true})

-- ========================================================================
-- Event Handling
-- ========================================================================
local function updatePlayerLists()
    local singles, multis={"None"}, {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer then
            table.insert(singles,p.Name)
            table.insert(multis,p.Name)
        end
    end
    playerDropdown:SetValues(singles)
    killPlayersDropdown:SetValues(multis)
    if Options.TargetPlayer and not table.find(singles,Options.TargetPlayer.Value) then
        playerDropdown:SetValue("None")
    end
end
Players.PlayerAdded:Connect(updatePlayerLists)
Players.PlayerRemoving:Connect(function(p)
    updatePlayerLists()
    -- Teleport fix
    if p==targetPlayer then
        stopTeleporting()
        if Options.TeleportEnabled and Options.TeleportEnabled.Value and Options.TargetPlayer and Options.TargetPlayer.Value~="None" then
            startTeleporting()
        end
    end
    -- Combat fix: if kill target left, re-pick
    if p==currentTarget then
        currentTarget=pickNewTarget()
    end
end)

-- Alive hook
local function hookAlive()
    local aliveValue=localPlayer:WaitForChild("Alive")
    isAlive=aliveValue.Value
    aliveValue:GetPropertyChangedSignal("Value"):Connect(function()
        isAlive=aliveValue.Value
        if isAlive then
            resetTeleportState()
            startTeleporting()
        else
            stopTeleporting()
            currentTarget=nil -- Reset target when dead (important in Infected)
        end
    end)
end

-- Kill loop start/stop
local function updateKillLoopState()
    local shouldRun=(Options.KillAllPlayers and Options.KillAllPlayers.Value) or (Options.KillPlayers and Options.KillPlayers.Value)
    if shouldRun and not killConnection then
        killConnection=RunService.Heartbeat:Connect(function() pcall(killLoop) end)
    elseif not shouldRun and killConnection then
        killConnection:Disconnect()
        killConnection=nil
    end
end
killAllToggle:OnChanged(updateKillLoopState)
killPlayersToggle:OnChanged(updateKillLoopState)
killPlayersDropdown:OnChanged(updateKillLoopState)

-- Init
updatePlayerLists()
hookAlive()

-- Save system
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
Fluent:Notify({Title="Utility GUI",Content="Loaded with Infected logic fix.",Duration=6})
SaveManager:LoadAutoloadConfig()
