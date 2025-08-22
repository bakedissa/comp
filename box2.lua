--[[
============================================================
-- ## CONFIGURATION ##
============================================================
]]
local Config = {
    Enabled = true,
    BOXES_TO_OPEN = { "Mystery Box", "Light Box", "Festival Mystery Box" },
    UseQuantity = 1000
}
getgenv().Config = Config

-- A list of UI popup names to find and destroy.
-- These names are taken directly from the logs you provided.
local POPUP_NAMES_TO_BLOCK = {
    "ScreenGui",    -- Blocks the main reward popups 
    "BillboardGui"  -- Blocks the other floating UI 
}

--[[
============================================================
-- ## CORE SCRIPT (MAX SPEED + UI BLOCKER) ##
============================================================
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

print("--- Starting MAX SPEED script with CUSTOM UI Blocker. ---")

-- ## THREAD 1: UI BLOCKER ##
task.spawn(function()
    PlayerGui.ChildAdded:Connect(function(child)
        if table.find(POPUP_NAMES_TO_BLOCK, child.Name) then
            child:Destroy()
        end
    end)
end)

-- ## THREAD 2: CONSTANTLY USE BOXES ##
task.spawn(function()
    while getgenv().Config.Enabled do
        for _, boxName in ipairs(getgenv().Config.BOXES_TO_OPEN) do
            RemoteEvent:FireServer(unpack({"UseGift", boxName, getgenv().Config.UseQuantity}))
        end
        task.wait()
    end
end)

-- ## THREAD 3: CONSTANTLY CLAIM & DESTROY GIFTS ##
task.spawn(function()
    local giftsFolder = workspace.Rendered:WaitForChild("Gifts")
    while getgenv().Config.Enabled do
        for _, gift in ipairs(giftsFolder:GetChildren()) do
            if gift and gift.Parent then
                RemoteEvent:FireServer(unpack({"ClaimGift", gift.Name}))
                gift:Destroy()
            end
        end
        task.wait()
    end
end)
