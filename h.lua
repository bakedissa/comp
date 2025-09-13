-- Ghost Hitbox Visualizer (Executor Version)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Colors for visualization
local COLOR_PRIMARY = Color3.fromRGB(0, 180, 255) -- blue
local COLOR_SECONDARY = Color3.fromRGB(255, 230, 0) -- yellow

-- Function to spawn ghost parts
local function renderGhost(cframe, size, isPrimary)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = size
    part.CFrame = cframe
    part.Transparency = 0.25
    part.Material = Enum.Material.Neon
    part.Color = isPrimary and COLOR_PRIMARY or COLOR_SECONDARY
    part.Parent = workspace

    -- Fade out over time
    task.spawn(function()
        for i = 1, 10 do
            part.Transparency = part.Transparency + 0.075
            task.wait(0.05)
        end
        part:Destroy()
    end)

    Debris:AddItem(part, 1.5) -- hard cleanup safety
end

-- Listen for hitbox pose events
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HitboxPose")

remote.OnClientEvent:Connect(function(hitboxData)
    -- Expected structure: hitboxData.PrimaryPose, hitboxData.SecondaryPoses
    -- Primary
    if hitboxData.PrimaryPose then
        renderGhost(hitboxData.PrimaryPose.CFrame, hitboxData.PrimaryPose.Size, true)
    end

    -- Secondary poses (array of CFrames + Sizes)
    if hitboxData.SecondaryPoses then
        for _, pose in ipairs(hitboxData.SecondaryPoses) do
            renderGhost(pose.CFrame, pose.Size, false)
        end
    end
end)

print("[Visualizer] Ghost hitbox visualizer enabled.")
