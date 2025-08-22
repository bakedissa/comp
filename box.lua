--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to false in your executor to stop the script
    Enabled = true,

    -- List of box/gift types to constantly use
    BOXES_TO_OPEN = {
        "Mystery Box",
        "Light Box",
        "Festival Mystery Box"
    },

    -- How many of each box to attempt to use per event fire.
    UseQuantity = 1000
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (MAXIMUM SPEED)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

print("--- Starting MAXIMUM SPEED Auto Box script. ---")

-- ## THREAD 1: CONSTANTLY USE BOXES ##
task.spawn(function()
    while getgenv().Config.Enabled do
        for _, boxName in ipairs(getgenv().Config.BOXES_TO_OPEN) do
            local args = {"UseGift", boxName, getgenv().Config.UseQuantity}
            RemoteEvent:FireServer(unpack(args))
        end
        task.wait() -- Runs this loop once every frame (as fast as possible)
    end
end)

-- ## THREAD 2: CONSTANTLY CLAIM & DESTROY GIFTS ##
task.spawn(function()
    local giftsFolder = workspace.Rendered:WaitForChild("Gifts")
    while getgenv().Config.Enabled do
        -- Use a copy of the children array to avoid issues while iterating
        local spawnedGifts = giftsFolder:GetChildren()
        
        if #spawnedGifts > 0 then
            for _, gift in ipairs(spawnedGifts) do
                -- Check if the gift still exists before processing
                if gift and gift.Parent then
                    local giftId = gift.Name
                    local args = {"ClaimGift", giftId}
                    RemoteEvent:FireServer(unpack(args))
                    gift:Destroy() -- Instantly destroy for max speed
                end
            end
        end
        task.wait() -- Runs this loop once every frame (as fast as possible)
    end
end)
