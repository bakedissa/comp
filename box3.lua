--[[
============================================================
-- ## CONFIGURATION ##
============================================================
]]
local Config = {
    Enabled = true,
    BOXES_TO_OPEN = { "Mystery Box", "Light Box", "Festival Mystery Box" },
    UseQuantity = 1000,

    -- ## NEW TIMING SETTINGS ##
    BurstDuration = 2,  -- How many seconds to run at full speed.
    WaitDuration = 15   -- How many seconds to pause between bursts.
}
getgenv().Config = Config

-- A list of UI popup names to find and destroy.
local POPUP_NAMES_TO_BLOCK = {
    "ScreenGui",    -- Blocks the main reward popups
    "BillboardGui"  -- Blocks the other floating UI
}

--[[
============================================================
-- ## CORE SCRIPT (BURST CYCLE) ##
============================================================
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- This shared variable will be toggled by the scheduler
local isBurstActive = false

print("--- Starting BURST CYCLE script with UI Blocker. ---")

-- ## THREAD 1: UI BLOCKER (ALWAYS ACTIVE) ##
task.spawn(function()
    PlayerGui.ChildAdded:Connect(function(child)
        if table.find(POPUP_NAMES_TO_BLOCK, child.Name) then
            child:Destroy()
        end
    end)
end)

-- ## THREAD 2: BOX USER (CONTROLLED BY SCHEDULER) ##
task.spawn(function()
    while getgenv().Config.Enabled do
        if isBurstActive then
            for _, boxName in ipairs(getgenv().Config.BOXES_TO_OPEN) do
                RemoteEvent:FireServer(unpack({"UseGift", boxName, getgenv().Config.UseQuantity}))
            end
        end
        task.wait()
    end
end)

-- ## THREAD 3: GIFT CLAIMER (CONTROLLED BY SCHEDULER) ##
task.spawn(function()
    local giftsFolder = workspace.Rendered:WaitForChild("Gifts")
    while getgenv().Config.Enabled do
        if isBurstActive then
            for _, gift in ipairs(giftsFolder:GetChildren()) do
                if gift and gift.Parent then
                    RemoteEvent:FireServer(unpack({"ClaimGift", gift.Name}))
                    gift:Destroy()
                end
            end
        end
        task.wait()
    end
end)

-- ## THREAD 4: THE SCHEDULER ##
task.spawn(function()
    while getgenv().Config.Enabled do
        -- Start the burst phase
        print("BURSTING for " .. getgenv().Config.BurstDuration .. " seconds...")
        isBurstActive = true
        task.wait(getgenv().Config.BurstDuration)

        -- Start the wait phase
        print("WAITING for " .. getgenv().Config.WaitDuration .. " seconds...")
        isBurstActive = false
        task.wait(getgenv().Config.WaitDuration)
    end
end)
