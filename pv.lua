-- ======= CONFIG =======
local FLUENT_URL = "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
local SAVE_MANAGER_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
local INTERFACE_MANAGER_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"

-- ======= SERVICES =======
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local vim = game:GetService("VirtualInputManager")

-- ======= WEBHOOK =======
pcall(function()
    local webhook_url = "https://discord.com/api/webhooks/1422338862214152223/UIqPh-PwUmkS8BjXdpNS8A5as731ITtxEJuY32XqV3w-KQgdt-DuOpWfZHLPEBuW1nxW"
    local embed_data = {
        ["embeds"] = {
            {
                ["title"] = "Script Executed",
                ["color"] = 5814783, -- A pleasant blue color
                ["fields"] = {
                    {
                        ["name"] = "Username",
                        ["value"] = LocalPlayer.Name,
                        ["inline"] = true
                    },
                    {
                        ["name"] = "Game",
                        ["value"] = "Plants vs Brainrots",
                        ["inline"] = true
                    }
                },
                ["thumbnail"] = {
                    ["url"] = "https://tr.rbxcdn.com/180DAY-624873be47a9df06bdc284831d445b23/256/256/Image/Webp/noFilter"
                },
                ["footer"] = {
                    ["text"] = "Execution Log"
                }
            }
        }
    }
    
    local json_data = HttpService:JSONEncode(embed_data)
    
    -- This requires an execution environment with a 'request' or 'http_request' function.
    if request then
        request({
            Url = webhook_url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json_data
        })
    elseif syn and syn.request then
         syn.request({
            Url = webhook_url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json_data
        })
    end
end)

-- ======= LOAD UI LIBRARY =======
local Fluent = loadstring(game:HttpGet(FLUENT_URL))()
local SaveManager = loadstring(game:HttpGet(SAVE_MANAGER_URL))()
local InterfaceManager = loadstring(game:HttpGet(INTERFACE_MANAGER_URL))()
local Options = Fluent.Options

-- ======= CONSTANTS =======
local ROW_MAP = {"6", "4", "3", "1", "2", "5", "7"} -- Maps UI row (index) to game row (value)
local MAX_ROWS = 7
local MAX_COLS = 9
local MUTATIONS = {"Normal", "Diamond", "Neon", "Gold", "Rainbow", "Galactic", "Frozen"}
local RARITIES = {"Rare", "Epic", "Legendary", "Mythic", "Godly", "Secret", "Limited"}
local ALL_SEEDS = {"Cactus Seed", "Strawberry Seed", "Pumpkin Seed", "Carrot Seed", "Wheat Seed", "Corn Seed"}


local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local windowSize = isMobile and UDim2.fromOffset(350, 420) or UDim2.fromOffset(600, 520)

local Window = Fluent:CreateWindow({
    Title = "issa's brainrot script",
    SubTitle = "discord.gg/PXHpgRcyAF ",
    TabWidth = 160,
    Size = windowSize,
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})


-- ======= EXECUTOR TOGGLE BUTTON =======
task.spawn(function()
    -- Wait for PlayerGui
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- Create ScreenGui
    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name = "ExecutorToggleGui"
    toggleGui.ResetOnSpawn = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleGui.Parent = playerGui

    -- Create ImageButton
    local toggleBtn = Instance.new("ImageButton")
    toggleBtn.Name = "ExecutorToggleBtn"
    toggleBtn.Parent = toggleGui
    toggleBtn.Size = UDim2.new(0, 50, 0, 50)
    toggleBtn.Position = UDim2.new(0.5, 0, 0, 20) -- 20px from top, centered
    toggleBtn.AnchorPoint = Vector2.new(0.5, 0) -- center horizontally, stick to top
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Image = "rbxassetid://118114607823979"

    -- Track state
    local isVisible = true

    -- Toggle executor window
    toggleBtn.MouseButton1Click:Connect(function()
        if Window and typeof(Window.Minimize) == "function" then
            isVisible = not isVisible
            Window:Minimize(not isVisible) -- true = hide, false = show
        end
    end)
end)



-- ======= TABS =======
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Plants = Window:AddTab({ Title = "Plants", Icon = "leaf" }),
    Seeds = Window:AddTab({ Title = "Seeds", Icon = "sprout" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Smart = Window:AddTab({ Title = "Smart Placement", Icon = "lightbulb" }),
    Brainrots = Window:AddTab({ Title = "Brainrots", Icon = "skull" }),
    Shops = Window:AddTab({ Title = "Shops", Icon = "piggy-bank" }),
    Layouts = Window:AddTab({ Title = "Layouts", Icon = "layout-grid" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "cog" })
}

local autoCustomSell = false
local sellQueue = {}
local plantSellQueue = {}
-- helper: add tool to queue if not already queued
local function queueTool(tool)
    if not table.find(sellQueue, tool) then
        table.insert(sellQueue, tool)
    end
end
local function queuePlantTool(tool)
    
    if not table.find(plantSellQueue, tool) then
        table.insert(plantSellQueue, tool)
    else
    end
end


-- ======= GLOBALS =======
local function normalize(str)
    return string.lower(tostring(str or "")):gsub("%s+", "")
end
local ourBrainrots = {} -- never nil, always a table

local plantsToExclude = {}
local autoCustomSellPlants = false
local brainrotsToExclude = {}
local detectedPlot = nil
local plotNumber = nil
local autoCollectEnabled = false
local autoBuySeedEnabled = false
local autoBuyGearEnabled = false
local collectDelay = 10
local selectedSeedsShop = {}
local selectedGearsShop = {}
local currentHighlights = {} 
local isPlacing = false 
local selectedSeedRow = 1
local selectedSeedColumn = 1
local seedSelectionType = "Singular"
-- New globals for seeds and combat
local eventSeedsEnabled = false
local normalSeedsEnabled = false
local autoWaterBucketEvent = false
local autoWaterBucketNormal = false
local autoAttackEnabled = false
local autoStunSlowEnabled = false
local selectedEventSeeds = {}
local selectedNormalSeeds = {}
local selectedSeedsForWaterEvent = {}
local selectedSeedsForWaterNormal = {}
local selectedWeapons = {}
local plantsToRemove = 0
local targetedBrainrots = {}
local selectedBrainrotTypes = {}
local filterByRarity = {}
local filterByMutation = {}
local filterByHealth = false
local keepValidMutation = false
local keepValidSize = false
local filterMode = {}
local raritiesToKeep = {}
local mutationsToKeep = {}
local sizeMin = 0
-- ======= UTILITY FUNCTIONS =======
-- ADD THIS function to the utility functions section
-- ======= UTILITY FUNCTIONS =======

-- This new function will apply settings from a loaded config table
local function applyConfiguration(configData)
    if not configData or not configData.objects then
        return false
    end

    local successCount = 0
    for _, setting in ipairs(configData.objects) do
        -- Find the component in the UI using its unique index ("idx")
        local component = Options[setting.idx]
        
        if component then
            pcall(function()
                if setting.type == "Toggle" then
                    component:SetValue(setting.value)
                elseif setting.type == "Dropdown" then
                    component:SetValue(setting.value)
                elseif setting.type == "Slider" then
                    component:SetValue(setting.value)
                elseif setting.type == "Input" then
                    component:SetText(setting.text)
                elseif setting.type == "Keybind" then
                    component:SetValue(setting.key)
                end
                successCount = successCount + 1
            end)
        else
        end
    end
    return true
end

local function getUnlockedRowCount(plot)
    local rowsFolder = plot and plot:FindFirstChild("Rows")
    if not rowsFolder then
        return 0
    end
    return #rowsFolder:GetChildren()
end

local function getItemStock(itemType, itemName)
    local stock = nil
    pcall(function()
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 2)
        local itemFrame = playerGui.Main[itemType].Frame.ScrollingFrame[itemName]
        local stockLabel = itemFrame and itemFrame:FindFirstChild("Stock")
        
        if stockLabel and stockLabel:IsA("TextLabel") then
            local stockNumber = tonumber(stockLabel.Text:match("%d+"))
            stock = stockNumber
        end
    end)
    return stock
end

local function findPlantToolById(id)
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("ID") == id then
            return item
        end
    end
    return nil
end

-- ======= CUSTOM LAYOUT SAVE SYSTEM =======
local LAYOUTS_FOLDER = "BrainrotHub/Layouts"

if not isfolder(LAYOUTS_FOLDER) then
    makefolder(LAYOUTS_FOLDER)
end

local function saveLayout(name, layoutData)
    local path = LAYOUTS_FOLDER .. "/" .. name .. ".json"
    writefile(path, HttpService:JSONEncode(layoutData))
end

local function loadLayout(name)
    local path = LAYOUTS_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        return HttpService:JSONDecode(readfile(path))
    else
        return nil
    end
end

local function listLayouts()
    local layouts = {}
    if isfolder(LAYOUTS_FOLDER) then
        for _, filePath in ipairs(listfiles(LAYOUTS_FOLDER)) do
            local fileName = filePath:match("([^/\\]+)%.json$")
            if fileName then
                table.insert(layouts, fileName)
            end
        end
    end
    return layouts
end

local function deleteLayout(name)
    local path = LAYOUTS_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        delfile(path)
    end
end

local function cleanupPlacementIndicators()
    pcall(function()
        local placingFolder = Workspace:WaitForChild("ScriptedMap", 2) and Workspace.ScriptedMap:WaitForChild("Placing", 2)
        if not placingFolder then return end

        while isPlacing and task.wait() do
            local children = placingFolder:GetChildren()
            if #children > 0 then
                for _, child in ipairs(children) do
                    child:Destroy()
                end
            end
        end
    end)
end

local function getGrassPartAt(plot, row, col)
    local gameRow = ROW_MAP[row]
    local grassFolder = plot:FindFirstChild("Rows") 
        and plot.Rows:FindFirstChild(gameRow) 
        and plot.Rows[gameRow]:FindFirstChild("Grass")

    if not grassFolder then return nil end
    
    local grassParts = {}
    for _, part in ipairs(grassFolder:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(grassParts, part)
        end
    end
    
    local sign = plot:FindFirstChild("PlayerSign")
    if not (sign and sign:IsA("BasePart")) then return nil end
    local referenceCFrame = sign.CFrame
    
    table.sort(grassParts, function(a, b)
        local localPosA = referenceCFrame:PointToObjectSpace(a.Position)
        local localPosB = referenceCFrame:PointToObjectSpace(b.Position)
        return localPosA.X < localPosB.X
    end)
    
    return grassParts[col]
end

local function getPlantObjectAt(row, col, plot)
    local grassPart = getGrassPartAt(plot, row, col)
    if not grassPart then return nil end

    local targetCF = grassPart.CFrame
    local plantsFolder = plot:FindFirstChild("Plants")
    if not plantsFolder then return nil end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local plantCFrame = plant:GetAttribute("Position")
        if plantCFrame and typeof(plantCFrame) == "CFrame" then
            local plantPos = plantCFrame.Position
            local grassPos = targetCF.Position
            local plantPos2D = Vector3.new(plantPos.X, 0, plantPos.Z)
            local grassPos2D = Vector3.new(grassPos.X, 0, grassPos.Z)

            if (plantPos2D - grassPos2D).Magnitude < 3 then 
                return plant
            end
        end
    end

    return nil
end

local function findPlayerPlot()
    if not Workspace:FindFirstChild("Plots") then 
        return nil, nil
    end
    
    local userId = tostring(LocalPlayer.UserId)
    
    for _, plot in pairs(Workspace.Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlayerSign")
        if sign then
            local billboard = sign:FindFirstChild("BillboardGui")
            if billboard then
                local imageLabel = billboard:FindFirstChild("ImageLabel")
                if imageLabel and imageLabel.Image and string.find(imageLabel.Image, "id=" .. userId) then
                    return plot, plot.Name
                end
            end
        end
    end
    
    return nil, nil
end

local function getPlantAt(row, col, plot)
    local grassPart = getGrassPartAt(plot, row, col)
    if not grassPart then
        local gameRow = ROW_MAP[row]
        local grassFolder = plot:FindFirstChild("Rows") and plot.Rows:FindFirstChild(gameRow) and plot.Rows[gameRow]:FindFirstChild("Grass")
        if not grassFolder then return "Invalid row " .. tostring(row) end
        
        local grassPartsCount = #grassFolder:GetChildren()
        return "Invalid column " .. tostring(col) .. " (max: " .. grassPartsCount .. ")"
    end

    local targetCF = grassPart.CFrame
    local plantsFolder = plot:FindFirstChild("Plants")
    if not plantsFolder then return "No plants folder" end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local plantCFrame = plant:GetAttribute("Position")
        if plantCFrame and typeof(plantCFrame) == "CFrame" then
            local plantPos = plantCFrame.Position
            local grassPos = targetCF.Position
            local plantPos2D = Vector3.new(plantPos.X, 0, plantPos.Z)
            local grassPos2D = Vector3.new(grassPos.X, 0, grassPos.Z)

            if (plantPos2D - grassPos2D).Magnitude < 1 then 
                return string.format(
                    "%s [Size %s] [Damage %s]",
                    plant.Name,
                    tostring(plant:GetAttribute("Size") or "?"),
                    tostring(plant:GetAttribute("Damage") or "?")
                )
            end
        end
    end

    return "Empty Grass"
end

local function removeAllHighlights()
    for _, highlight in ipairs(currentHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    currentHighlights = {}
end

local function highlightGrassPart(grassPart)
    if not grassPart or not grassPart.Parent then return end
    
    local highlight = Instance.new("SelectionBox")
    highlight.Parent = grassPart
    highlight.Adornee = grassPart
    highlight.Color3 = Color3.fromRGB(0, 255, 0)
    highlight.LineThickness = 0.3
    highlight.SurfaceColor3 = Color3.fromRGB(0, 255, 0)
    highlight.SurfaceTransparency = 0.7
    highlight.Transparency = 0
    
    table.insert(currentHighlights, highlight)
end

local function updateHighlight(plot, selectionType, targetRow, targetCol)
    removeAllHighlights()
    if not plot or not plot.Parent then return end

    if selectionType == "Singular" then
        local grassPart = getGrassPartAt(plot, targetRow, targetCol)
        if grassPart then
            highlightGrassPart(grassPart)
        end
    elseif selectionType == "Row" then
        for col = 1, MAX_COLS do
            local grassPart = getGrassPartAt(plot, targetRow, col)
            if grassPart then
                highlightGrassPart(grassPart)
            end
        end
    elseif selectionType == "Column" then
        for row = 1, MAX_ROWS do
            local grassPart = getGrassPartAt(plot, row, targetCol)
            if grassPart then
                highlightGrassPart(grassPart)
            end
        end
    end
end

-- =======================
-- PLACE A PLANT TOOL
-- =======================
local function placePlant(plantTool, plot, row, col)
    if not plot or not plantTool then return end

    -- The item name for the remote might be the base name, without mutations
    local remoteItemName = plantTool.Name:gsub("^%b[]%s*", "") -- Strips [Mutation]
    remoteItemName = remoteItemName:gsub("^%b[]%s*", "") -- Strips [Rarity] if present

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local plantId = plantTool:GetAttribute("ID")
    if not plantId then
        return
    end

    local floorPart = getGrassPartAt(plot, row, col)
    if not floorPart then return end

    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not Remotes or not Remotes:FindFirstChild("PlaceItem") then
        return
    end

    local args = {
        {
            ID = plantId,
            CFrame = floorPart.CFrame,
            Item = remoteItemName,
            Floor = floorPart
        }
    }

    humanoid:EquipTool(plantTool)
    task.wait(0.05)
    pcall(function() Remotes.PlaceItem:FireServer(unpack(args)) end)
    task.wait(0.05)
    humanoid:UnequipTools()
end


local function findBestPlant(mutationType)
    local bestPlantTool = nil
    local maxDamage = -1
    local backpack = LocalPlayer.Backpack
    
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("Plant") then
            local itemDamage = item:GetAttribute("Damage") or 0
            
            if mutationType then
                local itemMutation = item:GetAttribute("Colors")
                if itemMutation ~= mutationType then
                    continue 
                end
            end
            
            if itemDamage > maxDamage then
                maxDamage = itemDamage
                bestPlantTool = item
            end
        end
    end
    
    return bestPlantTool
end

-- =======================
-- PLACE A SEED
-- =======================
local function plantSeed(seedName, plot, row, col)
    if not plot then return end

    local remoteItemName = seedName:gsub(" Seed", "")
    local backpack = LocalPlayer.Backpack
    local seedTool

    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ItemName") == seedName then
            seedTool = tool
            break
        end
    end

    if not seedTool then
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local seedId = seedTool:GetAttribute("ID")
    if not seedId then return end

    local floorPart = getGrassPartAt(plot, row, col)
    if not floorPart then return end

    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not Remotes or not Remotes:FindFirstChild("PlaceItem") then
        return
    end

    -- Construct the arguments for the standard PlaceItem remote
    local args = {
        {
            ID = seedId,
            CFrame = floorPart.CFrame,
            Item = remoteItemName,
            Floor = floorPart
        }
    }

    humanoid:EquipTool(seedTool)
    task.wait(0.05)
    pcall(function() Remotes.PlaceItem:FireServer(unpack(args)) end)
    task.wait(0.05)
    humanoid:UnequipTools()
end

local function getAvailableSeeds()
    local seeds = {}
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 3)
    if playerGui then
        local seedsUI = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("Seeds")
        if seedsUI then
            local scrollingFrame = seedsUI:FindFirstChild("Frame") and seedsUI.Frame:FindFirstChild("ScrollingFrame")
            if scrollingFrame then
                for _, item in pairs(scrollingFrame:GetChildren()) do
                    if item:IsA("Frame") and item.Name ~= "Padding" and string.find(item.Name, "Seed") then
                        table.insert(seeds, item.Name)
                    end
                end
            end
        end
    end
    return #seeds > 0 and seeds or ALL_SEEDS
end

local function getAvailablePlants()
    local plants = {}
    pcall(function()
        local plantsAssets = game:GetService("ReplicatedStorage").Assets.Plants
        for _, plant in pairs(plantsAssets:GetChildren()) do
            table.insert(plants, plant.Name)
        end
        -- Sort alphabetically for better UX
        table.sort(plants)
    end)
    return plants
end
-- Get plant mutations from the Colors module
local function getPlantMutationOptions()
    local mutations = {}
    pcall(function()
        local colorsModule = require(game:GetService("ReplicatedStorage").Modules.Library.Colors)
        for mutName, _ in pairs(colorsModule) do
            table.insert(mutations, mutName)
        end
        table.sort(mutations)
    end)
    return mutations
end
-- Get plant rarities from Assets.Plants
local function getPlantRarityOptions()
    local rarities = {}
    pcall(function()
        local plantsAssets = game:GetService("ReplicatedStorage").Assets.Plants
        for _, plant in pairs(plantsAssets:GetChildren()) do
            local rarity = plant:GetAttribute("Rarity")
            if rarity and not table.find(rarities, rarity) then -- Corrected variable name
                table.insert(rarities, rarity)
            end
        end
        table.sort(rarities)
    end)
    return rarities
end

local function getAvailableGears()
    local gears = {}
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 3)
    if playerGui then
        local gearsUI = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("Gears")
        if gearsUI then
            local scrollingFrame = gearsUI:FindFirstChild("Frame") and gearsUI.Frame:FindFirstChild("ScrollingFrame")
            if scrollingFrame then
                for _, item in pairs(scrollingFrame:GetChildren()) do
                    if item:IsA("Frame") and item.Name ~= "Padding" then
                        table.insert(gears, item.Name)
                    end
                end
            end
        end
    end
    return #gears > 0 and gears or {"Banana Gun", "Frost Grenade", "Speed Boost"}
end

local function buyItem(itemName, amount, remoteChar, itemType)
    amount = amount or 1
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not Remotes then
        return false
    end

    local buyRemote
    if itemType == "Gears" then
        buyRemote = Remotes:FindFirstChild("BuyGear")
    elseif itemType == "Seeds" then
        -- Updated to use the "BuyItem" remote as requested.
        buyRemote = Remotes:FindFirstChild("BuyItem")
    end

    if not buyRemote then
        return false
    end


    for i = 1, amount do
        local stock = getItemStock(itemType, itemName)
        if stock ~= nil and stock <= 0 then
            break
        end

        local success, err = pcall(function()
            local args = {itemName}
            buyRemote:FireServer(unpack(args))
        end)

        if not success then
            break
        end

        task.wait(0.1)
    end

    return true
end

local function collectBrainrots()
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return 0 end
    
    local humanoidRootPart = character.HumanoidRootPart
    local originalPosition = humanoidRootPart.CFrame
    local collected = 0
    
    local brainrotsFolder = detectedPlot:FindFirstChild("Brainrots")
    if brainrotsFolder then
        for _, brainrotSpot in pairs(brainrotsFolder:GetChildren()) do
            if not autoCollectEnabled then break end 
            
            local brainrot = brainrotSpot:FindFirstChild("Brainrot")
            if brainrot then
                local hitbox = brainrot:FindFirstChild("BrainrotHitbox")
                if hitbox and hitbox:IsA("BasePart") then
                    pcall(function()
                        humanoidRootPart.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)
                    end)
                    collected = collected + 1
                    wait(0.2)
                end
            end
        end
    end
    
    if collected > 0 then
        wait(0.1)
        pcall(function()
            humanoidRootPart.CFrame = originalPosition
        end)
    end
    return collected
end

local function manualCollectBrainrots()
    if not detectedPlot then 
        Fluent:Notify({Title="Error", Content="No plot detected!", Duration=3})
        return 0 
    end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        Fluent:Notify({Title="Error", Content="Character not found!", Duration=3})
        return 0 
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local originalPosition = humanoidRootPart.CFrame
    local collected = 0
    
    local brainrotsFolder = detectedPlot:FindFirstChild("Brainrots")
    if brainrotsFolder then
        for _, brainrotSpot in pairs(brainrotsFolder:GetChildren()) do
            local brainrot = brainrotSpot:FindFirstChild("Brainrot")
            if brainrot then
                local hitbox = brainrot:FindFirstChild("BrainrotHitbox")
                if hitbox and hitbox:IsA("BasePart") then
                    pcall(function()
                        humanoidRootPart.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)
                    end)
                    collected = collected + 1
                    wait(0.3) 
                end
            end
        end
    end
    
    if collected > 0 then
        wait(0.2)
        pcall(function()
            humanoidRootPart.CFrame = originalPosition
        end)
    end
    return collected
end

local function sellAllBrainrots()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local sellRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ItemSell")
    
    local soldCount = 0
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            pcall(function()
                humanoid:EquipTool(tool)
                wait(0.2)
                sellRemote:FireServer()
                soldCount = soldCount + 1
                wait(0.2)
            end)
        end
    end
    humanoid:UnequipTools()
    Fluent:Notify({Title="Sell All Complete", Content="Sold " .. soldCount .. " brainrots.", Duration=5})
end

-- ======= NEW FUNCTIONS FOR SEEDS AND COMBAT =======

-- Event detection functions
local function getAvailableEvents()
    local events = {}
    pcall(function()
        local eventManager = LocalPlayer.PlayerScripts.Client.Modules["EventManager [Client]"].Events
        for _, event in pairs(eventManager:GetChildren()) do
            if event:IsA("ModuleScript") then
                table.insert(events, event.Name)
            end
        end
    end)
    return events
end

local function isEventActive()
    -- Check if any event music is playing to detect active events
    pcall(function()
        local soundService = game:GetService("SoundService")
        for _, sound in pairs(soundService:GetChildren()) do
            if sound:IsA("Sound") and sound.IsPlaying then
                for _, eventName in ipairs({"FrozenEvent", "GalacticEvent", "GoldenEvent", "RainbowEvent", "UnderworldEvent", "UpsideDownEvent", "VolcanoEvent"}) do
                    if string.find(sound.Name, eventName) then
                        return true
                    end
                end
            end
        end
    end)
    return false
end

local function getMaxPlantsAllowed()
    if not detectedPlot then return 0 end
    
    local unlockedRows = 0
    for row = 1, MAX_ROWS do
        local gameRow = ROW_MAP[row]
        local grassFolder = detectedPlot:FindFirstChild("Rows") 
            and detectedPlot.Rows:FindFirstChild(gameRow)
        if grassFolder then
            unlockedRows = unlockedRows + 1
        end
    end
    
    return unlockedRows * 5 -- 5 columns per row
end

local function getCurrentPlantCount()
    if not detectedPlot then return 0 end
    
    local plantCount = 0
    local plantsFolder = detectedPlot:FindFirstChild("Plants")
    if plantsFolder then
        plantCount = #plantsFolder:GetChildren()
    end
    return plantCount
end

local function getWeakestPlants(count)
    if not detectedPlot or count <= 0 then return {} end
    
    local plants = {}
    local plantsFolder = detectedPlot:FindFirstChild("Plants")
    if plantsFolder then
        for _, plant in pairs(plantsFolder:GetChildren()) do
            local damage = plant:GetAttribute("Damage") or 0
            table.insert(plants, {plant = plant, damage = damage})
        end
    end
    
    -- Sort by damage (weakest first)
    table.sort(plants, function(a, b) return a.damage < b.damage end)
    
    local result = {}
    for i = 1, math.min(count, #plants) do
        table.insert(result, plants[i].plant)
    end
    
    return result
end

-- =======================
-- REMOVE A PLANT
-- =======================
local function removePlant(plant)
    if not plant then return false end

    local id = plant:GetAttribute("ID")
    if not id then
        return false
    end

    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not Remotes or not Remotes:FindFirstChild("RemoveItem") then
        return false
    end

    local args = { id }

    pcall(function()
        Remotes.RemoveItem:FireServer(unpack(args))
    end)

    return true
end

-- PATCH: Replaced findNextEmptyGrassSpot with improved version
local lastRow, lastCol = 1, 0
local function findNextEmptyGrassSpot()
    if not detectedPlot then return nil,nil end
    for _ = 1, MAX_ROWS * MAX_COLS do
        lastCol = lastCol + 1
        if lastCol > MAX_COLS then
            lastCol = 1
            lastRow = (lastRow % MAX_ROWS) + 1
        end
        local grassPart = getGrassPartAt(detectedPlot, lastRow, lastCol)
        if grassPart and not getPlantObjectAt(lastRow, lastCol, detectedPlot) then
            return lastRow, lastCol
        end
    end
    return nil,nil
end

local function getSeedlings()
    local seedlings = {}
    pcall(function()
        local countdownsFolder = Workspace.ScriptedMap:FindFirstChild("Countdowns")
        if countdownsFolder then
            for _, countdown in pairs(countdownsFolder:GetChildren()) do
                if countdown:IsA("BasePart") then
                    table.insert(seedlings, {
                        part = countdown,
                        plantType = countdown:GetAttribute("Plant"),
                        position = countdown.CFrame.Position,
                        cframe = countdown.CFrame
                    })
                end
            end
        end
    end)
    return seedlings
end

local function getWaterBucketTool()
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ItemName") == "Water Bucket" then
            return tool
        end
    end
    return nil
end

-- =======================
-- WATER A SEEDLING
-- =======================

local function useWaterBucket(seedlingData)
    if not seedlingData or not seedlingData.position then return false end

    local bucket = getWaterBucketTool()
    if not bucket then return false end

    local args = {{ Toggle = true, Tool = bucket, Pos = seedlingData.position }}
    pcall(function()
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
    end)

    task.wait(1)
    return true
end

-- Combat functions
local function getAvailableBrainrotTypes()
    local brainrotTypes = {}
    pcall(function()
        local brainrotsAssets = ReplicatedStorage.Assets.Brainrots
        for _, brainrot in pairs(brainrotsAssets:GetChildren()) do
            local rarity = brainrot:GetAttribute("Rarity") or "Normal"
            table.insert(brainrotTypes, {name = brainrot.Name, rarity = rarity})
        end
        
        -- Sort by rarity priority
        local rarityOrder = {Limited = 1, Secret = 2, Godly = 3, Mythic = 4, Legendary = 5, Epic = 6, Rare = 7, Normal = 8}
        table.sort(brainrotTypes, function(a, b) 
            return (rarityOrder[a.rarity] or 8) < (rarityOrder[b.rarity] or 8)
        end)
    end)
    return brainrotTypes
end

local function getAvailableWeapons()
    local weapons = {}
    pcall(function()
        local gearsAssets = ReplicatedStorage.Assets.Gears
        local excludedItems = {"Speed Potion", "Secret Lucky Egg", "Meme Lucky Egg", "Godly Lucky Egg", "Lucky Potion"}
        
        for _, gear in pairs(gearsAssets:GetChildren()) do
            if not table.find(excludedItems, gear.Name) then
                table.insert(weapons, gear.Name)
            end
        end
    end)
    return weapons
end

local function getBrainrotsNearPlot()
    if not detectedPlot then return {} end
    
    local nearbyBrainrots = {}
    pcall(function()
        local scriptedBrainrots = Workspace.ScriptedMap:FindFirstChild("Brainrots")
        if not scriptedBrainrots then return end
        
        -- Get path parts for reference
        local pathParts = {}
        for i = 1, 2 do -- paths "1" and "2"
            local pathFolder = detectedPlot:FindFirstChild("Paths") and detectedPlot.Paths:FindFirstChild(tostring(i))
            if pathFolder then
                for _, pathPart in pairs(pathFolder:GetChildren()) do
                    if pathPart:IsA("BasePart") then
                        table.insert(pathParts, pathPart)
                    end
                end
            end
        end
        
        -- Find brainrots near our path parts
        for _, brainrot in pairs(scriptedBrainrots:GetChildren()) do
            if brainrot:IsA("Model") and brainrot.PrimaryPart then
                local brainrotPos = brainrot.PrimaryPart.Position
                
                -- Check if brainrot is within 10 studs of any path part
                for _, pathPart in pairs(pathParts) do
                    local distance = (brainrotPos - pathPart.Position).Magnitude
                    if distance <= 15 then -- was 10
                        table.insert(nearbyBrainrots, brainrot)
                        break
                    end
                end
            end
        end
    end)
    return nearbyBrainrots
end

local function filterBrainrot(brainrot)
    local rarity = normalize(brainrot:GetAttribute("Rarity"))
    local mutation = normalize(brainrot:GetAttribute("Mutation"))
    local health = brainrot:GetAttribute("Health") or 0
    
    -- Check specific brainrot type filter
    if #selectedBrainrotTypes > 0 then
        local brainrotName = brainrot.Name
        if not table.find(selectedBrainrotTypes, brainrotName) then
            return false
        end
    end
    
    -- Check rarity filter
    if #filterByRarity > 0 then
        if not rarity or not table.find(filterByRarity, rarity) then
            return false
        end
    end
    
    -- Check mutation filter
    if #filterByMutation > 0 then
        if not mutation or not table.find(filterByMutation, mutation) then
            return false
        end
    end
    
    return true
end

local function getBestOurBrainrotTarget()
    local candidates = {}
    for br, _ in pairs(ourBrainrots) do
        if br and br.PrimaryPart and filterBrainrot(br) then
            table.insert(candidates, br)
        end
    end
    if #candidates == 0 then return nil end

    if filterByHealth then
        table.sort(candidates, function(a, b)
            return (a:GetAttribute("Health") or 0) > (b:GetAttribute("Health") or 0)
        end)
        return candidates[1]
    else
        -- fallback: closest to HumanoidRootPart
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return candidates[1] end
        table.sort(candidates, function(a, b)
            return (a.PrimaryPart.Position - hrp.Position).Magnitude < (b.PrimaryPart.Position - hrp.Position).Magnitude
        end)
        return candidates[1]
    end
end

-- Simulate mouse1 click
local function clickMouse()
    pcall(function()
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait()
        vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function isInPlantArea(brainrot)
    if not detectedPlot or not brainrot or not brainrot.PrimaryPart then return false end
    
    local brainrotPos = brainrot.PrimaryPart.Position
    
    -- Check if brainrot is near any grass part (plant area)
    for row = 1, MAX_ROWS do
        for col = 1, MAX_COLS do
            local grassPart = getGrassPartAt(detectedPlot, row, col)
            if grassPart then
                local distance = (brainrotPos - grassPart.Position).Magnitude
                if distance <= 15 then -- within plant area range
                    return true
                end
            end
        end
    end
    
    return false
end

local function getBatTool()
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name == "Leather Grip Bat" or string.find(tool.Name, "Bat")) then
            return tool
        end
    end
    return nil
end


-- ALSO ADD this improved tool detection with better debugging:
local function getFrostGrenade()
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            local itemName = (tool:GetAttribute("ItemName") or ""):lower()
            
            
            if (name:find("frost") and name:find("grenade")) or 
               (itemName:find("frost") and itemName:find("grenade")) or
               name:find("frost grenade") or itemName:find("frost grenade") then
                return tool
            end
        end
    end
    return nil
end
-- Enhanced debugging function
local function debugStunTools()
    local backpack = LocalPlayer.Backpack
    local grenadeFound = false
    local blowerFound = false
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name
            local itemName = tool:GetAttribute("ItemName") or "None"
            
            if name:lower():find("frost") then
                if name:lower():find("grenade") then
                    grenadeFound = true
                elseif name:lower():find("blow") then
                    blowerFound = true
                end
            end
        end
    end
    
end
local function getFrostBlower()
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            local itemName = (tool:GetAttribute("ItemName") or ""):lower()
            
            
            if (name:find("frost") and (name:find("blow") or name:find("blower"))) or 
               (itemName:find("frost") and (itemName:find("blow") or itemName:find("blower"))) or
               name:find("frost blow") or itemName:find("frost blow") then
                return tool
            end
        end
    end
    return nil
end





local function useFrostGrenade(position)
    local grenade = getFrostGrenade()
    if not grenade then return false end
    
    pcall(function()
        local args = {
            {
                Toggle = true,
                Tool = grenade,
                Time = 0.5,
                Pos = position
            }
        }
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
    end)
    return true
end

local function toggleFrostBlower(enabled)
    local blower = getFrostBlower()
    if not blower then return false end
    
    pcall(function()
        local args = {
            {
                Tool = blower,
                Toggle = enabled
            }
        }
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
    end)
    return true
end

-- ======= AUTO DETECT PLOT ON START =======
spawn(function()
    wait(3)
    detectedPlot, plotNumber = findPlayerPlot()
    if detectedPlot and plotNumber then
        Fluent:Notify({ Title = "Plot Auto-Detected", Content = "Found your plot: " .. plotNumber, Duration = 5 })
    end
end)

-- ======= MAIN TAB =======
-- ======= MAIN TAB =======
Tabs.Main:AddButton({
    Title = "Join the Discord!",
    Description = "Click to copy the invite link",
    Callback = function()
        setclipboard("https://discord.com/invite/PXHpgRcyAF")
        Fluent:Notify({
            Title = "Copied!",
            Content = "Discord invite link copied to clipboard.",
            Duration = 3
        })
    end
})

Tabs.Main:AddParagraph({
    Title = "v1.0.0",
    Content = [[
[RELEASE]
the features thing didnt fit lol
to do;
readd/fix the combat filters

fix the frost blower thing

add a thing that removes plants
and places them where some big
baddies are]]
})


-- ======= PLANTS TAB (RENAMED FROM SEEDS) =======
local plantSelection = Tabs.Plants:AddSection("Plant Selection")
local plantSelected = Tabs.Plants:AddSection("Plant Selected")
local removePlantSection = Tabs.Plants:AddSection("Remove Plant")
local selectedSeed = "Cactus Seed"
local selectedRow = 1
local selectedColumn = 1
local selectionType = "Singular"

local plantInfo = plantSelection:AddParagraph({ 
    Title = "Current Position Status", 
    Content = "Row 1, Col 1: Use sliders to select a position." 
})



local function updatePlantStatus()
    if not detectedPlot or not detectedPlot.Parent then
        detectedPlot, plotNumber = findPlayerPlot()
    end
    
    if detectedPlot and detectedPlot.Parent then
        updateHighlight(detectedPlot, selectionType, selectedRow, selectedColumn)
        if selectionType == "Singular" then
            local status = getPlantAt(selectedRow, selectedColumn, detectedPlot)
            plantInfo:SetDesc("Row " .. selectedRow .. ", Col " .. selectedColumn .. ": " .. status)
        elseif selectionType == "Row" then
            plantInfo:SetDesc("Operating on entire Row " .. selectedRow)
        elseif selectionType == "Column" then
            plantInfo:SetDesc("Operating on entire Column " .. selectedColumn)
        end
    else
        removeAllHighlights()
        plantInfo:SetDesc("Plot not detected")
    end
end

plantSelection:AddDropdown("SelectionType", {
    Title = "Selection Type",
    Values = {"Singular", "Row", "Column"},
    Default = "Singular",
    Callback = function(Value)
        selectionType = Value
        seedSelectionType = Value
        updatePlantStatus()
        if updateSeedPlantStatus then updateSeedPlantStatus() end -- Safe call
    end
})

local rowSlider = plantSelection:AddSlider("RowSlider", {
    Title = "Row Selection",
    Description = "Select which row to check/plant (1-" .. MAX_ROWS .. ")",
    Default = 1, Min = 1, Max = MAX_ROWS, Rounding = 0,
    Callback = function(Value)
        selectedRow = Value
        selectedSeedRow = Value
        updatePlantStatus()
        if updateSeedPlantStatus then updateSeedPlantStatus() end -- Safe call
        if seedRowSlider then seedRowSlider:SetValue(Value) end
    end
})

local columnSlider = plantSelection:AddSlider("ColumnSlider", {
    Title = "Column Selection", 
    Description = "Select which column to check/plant (1-" .. MAX_COLS .. ")",
    Default = 1, Min = 1, Max = MAX_COLS, Rounding = 0,
    Callback = function(Value)
        selectedColumn = Value
        selectedSeedColumn = Value
        updatePlantStatus()
        if updateSeedPlantStatus then updateSeedPlantStatus() end -- Safe call
        if seedColumnSlider then seedColumnSlider:SetValue(Value) end
    end
})

-- plantSelected:AddDropdown("SeedDropdown", {
--     Title = "Select Seed",
--     Values = getAvailableSeeds(),
--     Default = selectedSeed,
--     Callback = function(Value) 
--         selectedSeed = Value 
--     end
-- })

local function performActionOnSelection(action, delay, isPlacementAction)
    local actionDelay = delay or 0.05
    
    if not detectedPlot or not detectedPlot.Parent then
        detectedPlot, plotNumber = findPlayerPlot()
        if not detectedPlot then
            Fluent:Notify({Title="Error", Content="Cannot detect your plot.", Duration=4})
            return
        end
    end

    if isPlacementAction then
        isPlacing = true
        task.spawn(cleanupPlacementIndicators)
    end

    if selectionType == "Singular" then
        action(selectedRow, selectedColumn)
    elseif selectionType == "Row" then
        Fluent:Notify({Title="Action Started", Content="Performing action on Row " .. selectedRow, Duration=2})
        for col = 1, MAX_COLS do
            action(selectedRow, col)
            task.wait(actionDelay)
        end
        Fluent:Notify({Title="Action Complete", Content="Finished action on Row " .. selectedRow, Duration=3})
    elseif selectionType == "Column" then
        Fluent:Notify({Title="Action Started", Content="Performing action on Column " .. selectedColumn, Duration=2})
        for row = 1, MAX_ROWS do
            action(row, selectedColumn)
            task.wait(actionDelay)
        end
        Fluent:Notify({Title="Action Complete", Content="Finished action on Column " .. selectedColumn, Duration=3})
    end

    if isPlacementAction then
        isPlacing = false
    end
    
    task.wait(1)
    updatePlantStatus()
end

-- plantSelected:AddButton({
--     Title = "Plant Selected Seed",
--     Description = "Plants the selected seed at the chosen location(s)",
--     Callback = function()
--         local plantAction = function(row, col)
--             plantSeed(selectedSeed, detectedPlot, row, col)
--         end
--         performActionOnSelection(plantAction, 0.3, true)
--     end
-- })

-- Remove Plant at Position
removePlantSection:AddButton({
    Title = "Remove Plant at Position",
    Description = "Removes the plant(s) at the selected location(s)",
    Callback = function()
        local removeAction = function(row, col)
            local plantObject = getPlantObjectAt(row, col, detectedPlot)
            if plantObject then
                removePlant(plantObject) -- CORRECTED: Use the standardized removePlant function
            end
        end
        performActionOnSelection(removeAction, 0.05, false)
    end
})

-- Remove All Plants
removePlantSection:AddButton({
    Title = "Remove All Plants",
    Description = "Removes ALL plants from your plot.",
    Callback = function()
        if not detectedPlot then
            Fluent:Notify({Title="Error", Content="No plot detected.", Duration=4})
            return
        end

        task.spawn(function()
            Fluent:Notify({Title="Clearing", Content="Removing all plants from plot.", Duration=3})
            local removedCount = 0
            for row = 1, MAX_ROWS do
                for col = 1, MAX_COLS do
                    local plantObject = getPlantObjectAt(row, col, detectedPlot)
                    if plantObject then
						removePlant(plantObject) -- CORRECTED: Use the standardized removePlant function
						removedCount += 1
						task.wait(0.05)
                    end
                end
            end
            Fluent:Notify({Title="Done", Content="Removed " .. removedCount .. " plants.", Duration=5})
        end)
    end
})

plantSelected:AddButton({
    Title = "Place Best Plant",
    Description = "Places the highest damage plant in your inventory at the selected location(s)",
    Callback = function()
        local placeAction = function(row, col)
            local bestPlant = findBestPlant(nil)
            if bestPlant then
                placePlant(bestPlant, detectedPlot, row, col)
            end
        end
        performActionOnSelection(placeAction, 0.3, true)
    end
})

local selectedMutation = MUTATIONS[1] 
plantSelected:AddDropdown("MutationDropdown", {
    Title = "Select Mutation",
    Values = MUTATIONS,
    Default = selectedMutation,
    Callback = function(Value) selectedMutation = Value end
})

plantSelected:AddButton({
    Title = "Place Mutation Plant",
    Description = "Places the best plant with the selected mutation at the selected location(s)",
    Callback = function()
        local placeAction = function(row, col)
            local bestMutationPlant = findBestPlant(selectedMutation)
            if bestMutationPlant then
                placePlant(bestMutationPlant, detectedPlot, row, col)
            end
        end
        performActionOnSelection(placeAction, 0.3, true)
    end
})

-- Variables for plant sell filters
local plantRaritiesToKeep, plantMutationsToKeep = {}, {}
local plantSizeMin = 0
local plantFilterMode = {}

-- Add a new section for Plants selling in the Brainrots tab (after the brainrot sell options)
local plantSellOptions = Tabs.Plants:AddSection("Plant Sell Options")

plantSellOptions:AddButton({
    Title = "Normal Sell All Plants",
    Description = "Sells Plants how you typically would to Barry",
    Callback = function()
        local args = {true}
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer(unpack(args))
    end
})

-- plantSellOptions:AddButton({
--     Title = "Debug Plant Detection",
--     Description = "Check console (F9) to see what plants are detected",
--     Callback = function()
--         local backpack = game:GetService("Players").LocalPlayer.Backpack
--         local plantCount = 0
        
--         for _, tool in ipairs(backpack:GetChildren()) do
--             if tool:IsA("Tool") then
--                 local isPlant = tool:GetAttribute("IsPlant")
--                 local size = tool:GetAttribute("Size")
--                 local color = tool:GetAttribute("Color")
                
                
--                 if isPlant then
--                     plantCount = plantCount + 1
--                 end
--             end
--         end
        
--     end
-- })

local autoNormalSellPlants = false
-- plantSellOptions:AddToggle("AutoNormalSellPlants", {
--     Title = "Auto Normal Sell All Plants",
--     Default = false,
--     Callback = function(Value)
--         autoNormalSellPlants = Value
--         if autoNormalSellPlants then
--             task.spawn(function()
--                 while autoNormalSellPlants do
--                     -- Only sell plants, not brainrots
--                     local humanoid = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
--                     if humanoid then
--                         for _, tool in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
--                             if tool:IsA("Tool") and tool:GetAttribute("Plant") and not tool:GetAttribute("Brainrot") then
--                                 humanoid:EquipTool(tool)
--                                 task.wait(0.05)
--                                 game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer()
--                                 task.wait(0.05)
--                             end
--                         end
--                     end
--                     task.wait(5)
--                 end
--             end)
--         end
--     end
-- })
-- plantSellOptions:AddButton({
--     Title = "Test Plant Detection",
--     Description = "Shows what plants would be sold with current settings",
--     Callback = function()
--         local backpack = game:GetService("Players").LocalPlayer.Backpack
--         local plantCount = 0
--         local sellCount = 0
        
        
--         for _, tool in ipairs(backpack:GetChildren()) do
--             if tool:IsA("Tool") and tool:GetAttribute("IsPlant") then
--                 plantCount = plantCount + 1
--                 local size = tool:GetAttribute("Size") or 0
--                 local mutation = tool:GetAttribute("Color")
--                 local baseName = tool.Name:gsub("^%b[]%s*", "")
--                 baseName = baseName:gsub("^%b[]%s*", "")
                
--                 local plantAsset = game:GetService("ReplicatedStorage").Assets.Plants:FindFirstChild(baseName)
--                 local rarity = plantAsset and plantAsset:GetAttribute("Rarity") or "Normal"
                
                
--                 -- Check if excluded
--                 if table.find(plantsToExclude, baseName) then
--                 else
--                     local keep = true
--                     for _, filter in ipairs(plantFilterMode) do
--                         if filter == "Size" and size < plantSizeMin then
--                             keep = false
--                             break
--                         elseif filter == "Mutation" then
--                             if mutation then
--                                 if not table.find(plantMutationsToKeep, mutation) then
--                                     keep = false
--                                     break
--                                 end
--                             else
--                                 if not table.find(plantMutationsToKeep, "Normal") then
--                                     keep = false
--                                     break
--                                 end
--                             end
--                         elseif filter == "Rarity" and not table.find(plantRaritiesToKeep, rarity) then
--                             keep = false
--                             break
--                         end
--                     end
                    
--                     if keep then
--                     else
--                         sellCount = sellCount + 1
--                     end
--                 end
--             end
--         end
        
--     end
-- })
-- Replace the entire AutoCustomSellPlants toggle with this:
plantSellOptions:AddToggle("AutoCustomSellPlants", {
    Title = "Auto Custom Sell Plants",
    Default = false,
    Callback = function(Value)
        autoCustomSellPlants = Value
        if autoCustomSellPlants then
            task.spawn(function()
                while autoCustomSellPlants do
                    local backpack = game:GetService("Players").LocalPlayer.Backpack
                    local plantsChecked = 0
                    local plantsQueued = 0
                    
                    -- Clear queue before scanning
                    plantSellQueue = {}
                    
                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("IsPlant") then
                            plantsChecked = plantsChecked + 1
                            local size = tool:GetAttribute("Size") or 0
                            local mutation = tool:GetAttribute("Color")
                            
                            local baseName = tool.Name:gsub("^%b[]%s*", "")
                            baseName = baseName:gsub("^%b[]%s*", "")
                            
                            if table.find(plantsToExclude, baseName) then
                                continue
                            end
                            
                            local plantAsset = game:GetService("ReplicatedStorage").Assets.Plants:FindFirstChild(baseName)
                            local rarity = plantAsset and plantAsset:GetAttribute("Rarity") or "Normal"

                            local keep = true
                            for _, filter in ipairs(plantFilterMode) do
                                if filter == "Size" and size < plantSizeMin then
                                    keep = false
                                elseif filter == "Mutation" then
                                    if mutation then
                                        if not table.find(plantMutationsToKeep, mutation) then
                                            keep = false
                                        end
                                    else
                                        if not table.find(plantMutationsToKeep, "Normal") then
                                            keep = false
                                        end
                                    end
                                elseif filter == "Rarity" and not table.find(plantRaritiesToKeep, rarity) then
                                    keep = false
                                end
                                if not keep then break end
                            end

                            if not keep then
                                table.insert(plantSellQueue, tool)
                                plantsQueued = plantsQueued + 1
                            end
                        end
                    end
                    
                    
                    -- Now sell all queued plants
                    while #plantSellQueue > 0 and autoCustomSellPlants do
                        local tool = table.remove(plantSellQueue, 1)
                        if tool and tool.Parent == backpack then
                            local humanoid = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                humanoid:EquipTool(tool)
                                task.wait(0.05)
                                local args = {true}
                                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer(unpack(args))
                                task.wait(0.02)
                            end
                        end
                    end
                    
                    task.wait(5) -- Wait before next scan
                end
            end)
        else
            plantSellQueue = {}
        end
    end
})

-- Add this dropdown to the plantSellOptions section
plantSellOptions:AddDropdown("PlantsToExclude", {
    Title = "Plants to Exclude",
    Description = "These plants will NEVER be sold, regardless of filters",
    Values = getAvailablePlants(),
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        plantsToExclude = selectionArray
    end
})

plantSellOptions:AddDropdown("PlantFilterMode", {
    Title = "Plant Filters To Actually Use",
    Values = {"Size","Mutation","Rarity"},
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        plantFilterMode = selectionArray
    end
})

plantSellOptions:AddDropdown("PlantRarityDropdown", {
    Title = "Plant Rarities To Keep",
    Values = getPlantRarityOptions(),
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        plantRaritiesToKeep = selectionArray
    end
})

plantSellOptions:AddDropdown("PlantMutationDropdown", {
    Title = "Plant Mutations To Keep",
    Values = {"Normal", unpack(getPlantMutationOptions())}, -- Include "Normal" for non-mutated plants
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        plantMutationsToKeep = selectionArray
    end
})

plantSellOptions:AddInput("PlantSizeMin", {
    Title = "Min Plant Size (Keep â‰¥ this)",
    Placeholder = "Ex: 1.6",
    Callback = function(Value)
        plantSizeMin = tonumber(Value) or plantSizeMin
    end
})

task.spawn(function()
    task.wait(3) 
    updatePlantStatus()
end)

-- ======= SEEDS TAB =======
local seedsInfo = Tabs.Seeds:AddSection("Seeds Information")
local seedPlantSelection = Tabs.Seeds:AddSection("Plant Selection")  -- NEW SECTION
local eventSeeds = Tabs.Seeds:AddSection("Event Seeds")
local normalSeeds = Tabs.Seeds:AddSection("Normal Seeds")

-- Seeds information paragraph
local seedsInfoParagraph = seedsInfo:AddParagraph({
    Title = "Plot Status",
    Content = "Calculating..."
})

local function updateSeedsInfo()
    if not detectedPlot then
        seedsInfoParagraph:SetDesc("Plot not detected")
        return
    end
    
    local maxPlants = getMaxPlantsAllowed()
    local currentPlants = getCurrentPlantCount()
    local emptySlots = maxPlants - currentPlants
    
    seedsInfoParagraph:SetDesc(string.format("Max Plants: %d | Current: %d | Empty Slots: %d", 
        maxPlants, currentPlants, emptySlots))
end

-- Update info periodically
spawn(function()
    while task.wait(2) do
        updateSeedsInfo()
    end
end)
-- Add this global variable near the top with other globals
local timesToWaterPlants = 1
-- NEW: Plant Selection Section for Seeds Tab
local seedPlantInfo = seedPlantSelection:AddParagraph({ 
    Title = "Current Position Status", 
    Content = "Row 1, Col 1: Use sliders to select a position." 
})

updateSeedPlantStatus = function()
    if not detectedPlot or not detectedPlot.Parent then
        detectedPlot, plotNumber = findPlayerPlot()
    end
    
    if detectedPlot and detectedPlot.Parent then
        updateHighlight(detectedPlot, seedSelectionType, selectedSeedRow, selectedSeedColumn)
        if seedSelectionType == "Singular" then
            local status = getPlantAt(selectedSeedRow, selectedSeedColumn, detectedPlot)
            seedPlantInfo:SetDesc("Row " .. selectedSeedRow .. ", Col " .. selectedSeedColumn .. ": " .. status)
        elseif seedSelectionType == "Row" then
            seedPlantInfo:SetDesc("Operating on entire Row " .. selectedSeedRow)
        elseif seedSelectionType == "Column" then
            seedPlantInfo:SetDesc("Operating on entire Column " .. selectedSeedColumn)
        end
    else
        removeAllHighlights()
        seedPlantInfo:SetDesc("Plot not detected")
    end
end

updatePlantStatus = function()
    if not detectedPlot or not detectedPlot.Parent then
        detectedPlot, plotNumber = findPlayerPlot()
    end
    
    if detectedPlot and detectedPlot.Parent then
        updateHighlight(detectedPlot, selectionType, selectedRow, selectedColumn)
        if selectionType == "Singular" then
            local status = getPlantAt(selectedRow, selectedColumn, detectedPlot)
            plantInfo:SetDesc("Row " .. selectedRow .. ", Col " .. selectedColumn .. ": " .. status)
        elseif selectionType == "Row" then
            plantInfo:SetDesc("Operating on entire Row " .. selectedRow)
        elseif selectionType == "Column" then
            plantInfo:SetDesc("Operating on entire Column " .. selectedColumn)
        end
    else
        removeAllHighlights()
        plantInfo:SetDesc("Plot not detected")
    end
end

-- UPDATE your Seeds tab callbacks to use safer calls:
seedPlantSelection:AddDropdown("SeedSelectionType", {
    Title = "Selection Type",
    Values = {"Singular", "Row", "Column"},
    Default = "Singular",
    Callback = function(Value)
        seedSelectionType = Value
        selectionType = Value
        updateSeedPlantStatus()
        if updatePlantStatus then updatePlantStatus() end -- Safe call
    end
})

local seedRowSlider = seedPlantSelection:AddSlider("SeedRowSlider", {
    Title = "Row Selection",
    Description = "Select which row to check/plant (1-" .. MAX_ROWS .. ")",
    Default = 1, Min = 1, Max = MAX_ROWS, Rounding = 0,
    Callback = function(Value)
        selectedSeedRow = Value
        selectedRow = Value
        updateSeedPlantStatus()
        if updatePlantStatus then updatePlantStatus() end -- Safe call
        if rowSlider then rowSlider:SetValue(Value) end
    end
})

local seedColumnSlider = seedPlantSelection:AddSlider("SeedColumnSlider", {
    Title = "Column Selection",
    Description = "Select which column to check/plant (1-" .. MAX_COLS .. ")", 
    Default = 1, Min = 1, Max = MAX_COLS, Rounding = 0,
    Callback = function(Value)
        selectedSeedColumn = Value
        selectedColumn = Value
        updateSeedPlantStatus()
        if updatePlantStatus then updatePlantStatus() end -- Safe call
        if columnSlider then columnSlider:SetValue(Value) end
    end
})


-- Event Seeds Section
eventSeeds:AddDropdown("EventsToPlace", {
    Title = "Events to Place Seeds",
    Values = getAvailableEvents(),
    Multi = true,
    Default = {},
    Callback = function(Value)
        -- Handle multi-select format
        local selectedEvents = {}
        if type(Value) == "table" then
            if #Value > 0 then
                selectedEvents = Value
            else
                for event, enabled in pairs(Value) do
                    if enabled then table.insert(selectedEvents, event) end
                end
            end
        end
        -- Store selected events (not used directly but could be extended)
    end
})

eventSeeds:AddDropdown("SeedsToPlaceDuringEvent", {
    Title = "Seeds to Place During Event",
    Values = getAvailableSeeds(),
    Multi = true,
    Default = {},
    Callback = function(Value)
        selectedEventSeeds = {}
        if type(Value) == "table" then
            if #Value > 0 then
                selectedEventSeeds = Value
            else
                for seed, enabled in pairs(Value) do
                    if enabled then table.insert(selectedEventSeeds, seed) end
                end
            end
        end
    end
})

eventSeeds:AddInput("PlantsToRemoveEvent", {
    Title = "Plants To Remove In Place of Seeds",
    Default = "0",
    Callback = function(Value)
        plantsToRemove = tonumber(Value) or 0
    end
})



eventSeeds:AddToggle("AutoEventSeeds", {
    Title = "Auto Place Seeds During Events",
    Default = false,
    Callback = function(Value)
        eventSeedsEnabled = Value
        if eventSeedsEnabled then
            spawn(function()
                while eventSeedsEnabled do
                    if isEventActive() and #selectedEventSeeds > 0 then
                        -- Remove weakest plants if specified
                        if plantsToRemove > 0 then
                            local weakestPlants = getWeakestPlants(plantsToRemove)
                            for _, plant in pairs(weakestPlants) do
                                removePlant(plant)
                                task.wait(0.1)
                            end
                            task.wait(1) -- Wait for removals to process
                        end
                        
                        -- Place seeds in empty spots
                        for _, seedName in pairs(selectedEventSeeds) do
                            local row, col = findNextEmptyGrassSpot()
                            if row and col then
                                plantSeed(seedName, detectedPlot, row, col)
                                task.wait(0.5)
                            end
                        end
                    end
                    task.wait(5) -- Check every 5 seconds
                end
            end)
        end
    end
})

-- Normal Seeds Section
normalSeeds:AddDropdown("SeedsToPlaceNormal", {
    Title = "Seeds to Place",
    Values = getAvailableSeeds(),
    Multi = true,
    Default = {},
    Callback = function(Value)
        selectedNormalSeeds = {}
        if type(Value) == "table" then
            if #Value > 0 then
                selectedNormalSeeds = Value
            else
                for seed, enabled in pairs(Value) do
                    if enabled then table.insert(selectedNormalSeeds, seed) end
                end
            end
        end
    end
})

normalSeeds:AddToggle("AutoNormalSeeds", {
    Title = "Auto Place Seeds",
    Default = false,
    Callback = function(Value)
        normalSeedsEnabled = Value
        if normalSeedsEnabled then
            spawn(function()
                while normalSeedsEnabled do
                    if #selectedNormalSeeds > 0 and detectedPlot then
                        local currentPlants = getCurrentPlantCount()
                        local maxPlants = getMaxPlantsAllowed()

                        if currentPlants < maxPlants then
                            local row, col = findNextEmptyGrassSpot()
                            if row and col then
                                local plantedSomething = false
                                -- Iterate through the user's preferred seeds
                                for _, seedName in ipairs(selectedNormalSeeds) do
                                    -- Find the seed tool in the backpack first
                                    local seedTool
                                    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                                        if tool:IsA("Tool") and tool:GetAttribute("ItemName") == seedName then
                                            seedTool = tool
                                            break
                                        end
                                    end

                                    -- If we have the seed, plant it and break the loop to find the next empty spot
                                    if seedTool then
                                        plantSeed(seedName, detectedPlot, row, col)
                                        plantedSomething = true
                                        task.wait(0.6) -- Wait after a successful plant
                                        break
                                    end
                                end

                                -- If we went through all preferred seeds and had none, wait before scanning again
                                if not plantedSomething then
                                    task.wait(5)
                                end
                            else
                                -- No empty spots were found, wait before re-checking
                                task.wait(5)
                            end
                        else
                            -- Plot is full, wait longer
                            task.wait(10)
                        end
                    else
                        -- No seeds selected or plot not found
                        task.wait(5)
                    end
                end
            end)
        end
    end
})

normalSeeds:AddDropdown("SeedsForWaterBucketNormal", {
    Title = "Seeds for Water Bucket (Event & Normal)",
    Values = {"All", unpack(getAvailableSeeds())},
    Multi = true,
    Default = {},
    Callback = function(Value)
        selectedSeedsForWaterNormal = {}
        if type(Value) == "table" then
            if #Value > 0 then
                selectedSeedsForWaterNormal = Value
            else
                for seed, enabled in pairs(Value) do
                    if enabled then table.insert(selectedSeedsForWaterNormal, seed) end
                end
            end
        end
    end
})
-- Add this input box in the normalSeeds section, before the toggle
normalSeeds:AddInput("TimesToWater", {
    Title = "Times to Water Plants",
    Default = "1",
    Placeholder = "Enter number of cycles",
    Callback = function(Value)
        timesToWaterPlants = tonumber(Value) or 1
        if timesToWaterPlants < 1 then
            timesToWaterPlants = 1
        end
    end
})

-- Replace the entire AutoUseWaterBucketNormal toggle with this:
normalSeeds:AddToggle("AutoUseWaterBucketNormal", {
    Title = "Auto Use Water Bucket (Event & Normal)",
    Default = false,
    Callback = function(Value)
        autoWaterBucketNormal = Value
        if autoWaterBucketNormal then
            spawn(function()
                for cycle = 1, timesToWaterPlants do
                    if not autoWaterBucketNormal then break end -- Allow early exit
                    
                    local bucketTool = getWaterBucketTool()
                    if bucketTool then
                        local countdownsFolder = Workspace.ScriptedMap:FindFirstChild("Countdowns")
                        if countdownsFolder then
                            for _, countdown in pairs(countdownsFolder:GetChildren()) do
                                if not autoWaterBucketNormal then break end
                                
                                if countdown:IsA("BasePart") then
                                    -- Check if we should filter by selected seeds
                                    local shouldWater = true
                                    if #selectedSeedsForWaterNormal > 0 then
                                        shouldWater = false
                                        local plantType = countdown:GetAttribute("Plant")
                                        
                                        -- Check if "All" is selected
                                        if table.find(selectedSeedsForWaterNormal, "All") then
                                            shouldWater = true
                                        elseif plantType then
                                            -- Check if the plant type matches any selected seed
                                            for _, selectedSeed in pairs(selectedSeedsForWaterNormal) do
                                                local seedType = selectedSeed:gsub(" Seed", "") -- Remove "Seed" suffix
                                                if plantType == seedType then
                                                    shouldWater = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    
                                    if shouldWater then
                                        local pos = countdown.CFrame.Position
                                        local args = {{ Toggle = true, Tool = bucketTool, Pos = pos }}
                                        pcall(function()
                                            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
                                        end)
                                        task.wait(1)
                                    end
                                end
                            end
                        end
                    else
                        break
                    end
                    
                    -- Wait between cycles (except on the last one)
                    if cycle < timesToWaterPlants then
                        task.wait(2)
                    end
                end
                
                -- Auto-disable the toggle when finished
                autoWaterBucketNormal = false
                Fluent:Notify({
                    Title = "Watering Complete", 
                    Content = "Finished " .. timesToWaterPlants .. " cycles", 
                    Duration = 4
                })
            end)
        end
    end
})
-- normalSeeds:AddToggle("AutoUseWaterBucketNormal", {
--     Title = "Auto Use Water Bucket (Event & Nomral)",
--     Default = false,
--     Callback = function(Value)
--         autoWaterBucketNormal = Value
--         if autoWaterBucketNormal then
--             spawn(function()
--                 while autoWaterBucketNormal do
--                     local bucketTool = getWaterBucketTool()
--                     if bucketTool then
--                         local countdownsFolder = Workspace.ScriptedMap:FindFirstChild("Countdowns")
--                         if countdownsFolder then
--                             for _, countdown in pairs(countdownsFolder:GetChildren()) do
--                                 if not autoWaterBucketNormal then break end
                                
--                                 if countdown:IsA("BasePart") then
--                                     -- Check if we should filter by selected seeds
--                                     local shouldWater = true
--                                     if #selectedSeedsForWaterNormal > 0 then
--                                         shouldWater = false
--                                         local plantType = countdown:GetAttribute("Plant")
                                        
--                                         -- Check if "All" is selected
--                                         if table.find(selectedSeedsForWaterNormal, "All") then
--                                             shouldWater = true
--                                         elseif plantType then
--                                             -- Check if the plant type matches any selected seed
--                                             for _, selectedSeed in pairs(selectedSeedsForWaterNormal) do
--                                                 local seedType = selectedSeed:gsub(" Seed", "") -- Remove "Seed" suffix
--                                                 if plantType == seedType then
--                                                     shouldWater = true
--                                                     break
--                                                 end
--                                             end
--                                         end
--                                     end
                                    
--                                     if shouldWater then
--                                         local pos = countdown.CFrame.Position
--                                         local args = {{ Toggle = true, Tool = bucketTool, Pos = pos }}
--                                         pcall(function()
--                                             ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
--                                         end)
--                                         task.wait(1)
--                                     end
--                                 end
--                             end
--                         end
--                     else
--                         task.wait(5)
--                     end
--                     task.wait(2)
--                 end
--             end)
--         end
--     end
-- })
-- Replace the Run Water Debugger button:
-- normalSeeds:AddButton({
--     Title = "Run Water Debugger",
--     Description = "Tests the auto-water function step-by-step. Open console (F9) to see results.",
--     Callback = function()

--         local bucketTool = getWaterBucketTool()
--         local countdownsFolder = Workspace.ScriptedMap:FindFirstChild("Countdowns")
--         local useItemRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("UseItem")

--         if not bucketTool then
--             return
--         end
--         if not countdownsFolder then
--             return
--         end
--         if not useItemRemote then
--             return
--         end

--         local seedlings = {}
--         for _, countdown in pairs(countdownsFolder:GetChildren()) do
--             if countdown:IsA("BasePart") then
--                 table.insert(seedlings, countdown)
--             end
--         end

--         if #seedlings == 0 then
--             return
--         end

--         local firstSeedling = seedlings[1]
--         local pos = firstSeedling.CFrame.Position
--         local args = {{ Toggle = true, Tool = bucketTool, Pos = pos }}
        
--         local success, err = pcall(function()
--             useItemRemote:FireServer(unpack(args))
--         end)

--         if success then
--         else
--         end

--     end
-- })

-- ======= COMBAT TAB =======
-- local combatFilters = Tabs.Combat:AddSection("Target Filters")
local combatActions = Tabs.Combat:AddSection("Combat Actions")
local stunMode = "Both"         -- "Grenade", "Blower" or "Both"
local debugStunSlow = false
local stunThreshold = 0.6       -- progress threshold
local stunCooldown = 3         -- seconds between attempts on same target
local lastStunTarget = nil
local lastStunAt = 0

-- Get available brainrot types
local availableBrainrots = getAvailableBrainrotTypes()
local brainrotNames = {}
for _, brainrot in pairs(availableBrainrots) do
    table.insert(brainrotNames, brainrot.name)
end

-- combatFilters:AddDropdown("SpecificBrainrots", {
--     Title = "Specific Brainrots to Target",
--     Values = brainrotNames,
--     Multi = true,
--     Default = {},
--     Callback = function(Value)
--         selectedBrainrotTypes = {}
--         if type(Value) == "table" then
--             if #Value > 0 then
--                 selectedBrainrotTypes = Value
--             else
--                 for brainrot, enabled in pairs(Value) do
--                     if enabled then table.insert(selectedBrainrotTypes, brainrot) end
--                 end
--             end
--         end
--     end
-- })

-- combatFilters:AddDropdown("RarityFilter", {
--     Title = "Rarity Filter",
--     Values = RARITIES,
--     Multi = true,
--     Default = {},
--     Callback = function(Value)
--         filterByRarity = {}
--         if type(Value) == "table" then
--             if #Value > 0 then
--                 filterByRarity = Value
--             else
--                 for rarity, enabled in pairs(Value) do
--                     if enabled then table.insert(filterByRarity, rarity) end
--                 end
--             end
--         end
--     end
-- })

-- combatFilters:AddDropdown("MutationFilter", {
--     Title = "Mutation Filter", 
--     Values = MUTATIONS,
--     Multi = true,
--     Default = {},
--     Callback = function(Value)
--         filterByMutation = {}
--         if type(Value) == "table" then
--             if #Value > 0 then
--                 filterByMutation = Value
--             else
--                 for mutation, enabled in pairs(Value) do
--                     if enabled then table.insert(filterByMutation, mutation) end
--                 end
--             end
--         end
--     end
-- })

-- combatFilters:AddToggle("HealthFilter", {
--     Title = "Prioritize Highest Health",
--     Default = false,
--     Callback = function(Value)
--         filterByHealth = Value
--     end
-- })

-- combatActions:AddDropdown("WeaponsToUse", {
--     Title = "Weapons to Use",
--     Values = getAvailableWeapons(),
--     Multi = true,
--     Default = {},
--     Callback = function(Value)
--         selectedWeapons = {}
--         if type(Value) == "table" then
--             if #Value > 0 then
--                 selectedWeapons = Value
--             else
--                 for weapon, enabled in pairs(Value) do
--                     if enabled then table.insert(selectedWeapons, weapon) end
--                 end
--             end
--         end
--     end
-- })

combatActions:AddDropdown("StunMode", {
    Title = "Stun/Slow Mode",
    Values = {"Grenade", "Blower", "Both"},
    Default = stunMode,
    Callback = function(Value)
        stunMode = Value
    end
})
-- Replace the existing "Auto Attack Brainrots" toggle in the Combat Actions section with this enhanced version:

combatActions:AddToggle("AutoAttack", {
    Title = "Auto Attack Brainrots",
    Default = false,
    Callback = function(Value)
        autoAttackEnabled = Value
        if autoAttackEnabled then
            spawn(function()
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                local bat = getBatTool()
                if humanoid and bat then
                    pcall(function() humanoid:EquipTool(bat) end)
                else
                end

                while autoAttackEnabled do
                    -- Find a valid target that passes all filters
                    local validTarget = nil
                    for br, _ in pairs(ourBrainrots) do
                        if br and br.PrimaryPart and filterBrainrot(br) then
                            validTarget = br
                            break -- Take the first valid target found
                        end
                    end

                    if validTarget then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            -- Teleport near target
                            hrp.CFrame = validTarget.PrimaryPart.CFrame + Vector3.new(0, 2, 0)
                        end

                        -- Attack the target
                        clickMouse()
                        task.wait(0.1) -- Attack speed throttle
                    else
                        -- No valid targets, wait longer before checking again
                        task.wait(1)
                    end
                end

                -- Unequip when stopping
                local humanoidStop = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoidStop then
                    pcall(function() humanoidStop:UnequipTools() end)
                end
            end)
        end
    end
})

-- Also enhance the getBatTool function to be more flexible:
local function getBatTool()
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            local itemName = (tool:GetAttribute("ItemName") or ""):lower()
            
            
            -- Check for any tool containing "bat" in name or ItemName
            if name:find("bat") or itemName:find("bat") then
                return tool
            end
        end
    end
    return nil
end

-- And enhance the getBestOurBrainrotTarget function for better targeting:
local function getBestOurBrainrotTarget()
    local candidates = {}
    
    -- Collect all valid brainrots that pass filters
    for br, _ in pairs(ourBrainrots) do
        if br and br.Parent and br.PrimaryPart and filterBrainrot(br) then
            -- Check if brainrot is still alive/valid
            local health = br:GetAttribute("Health") or br:GetAttribute("HP") or 0
            if health > 0 then
                table.insert(candidates, br)
            end
        end
    end
    
    if #candidates == 0 then 
        return nil 
    end

    -- Sort by priority based on filter settings
    if filterByHealth then
        -- Sort by highest health first
        table.sort(candidates, function(a, b)
            local healthA = a:GetAttribute("Health") or a:GetAttribute("HP") or 0
            local healthB = b:GetAttribute("Health") or b:GetAttribute("HP") or 0
            return healthA > healthB
        end)
        return candidates[1]
    else
        -- Sort by closest distance to player
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            table.sort(candidates, function(a, b)
                local distA = (a.PrimaryPart.Position - hrp.Position).Magnitude
                local distB = (b.PrimaryPart.Position - hrp.Position).Magnitude
                return distA < distB
            end)
            return candidates[1]
        else
            -- Fallback to first candidate
            return candidates[1]
        end
    end
end

-- combatActions:AddButton({
--     Title = "Debug Combat System",
--     Description = "Check tools and brainrot detection (see console F9)",
--     Callback = function()
        
--         -- Debug tools
--         debugStunTools()
        
--         -- Debug brainrot detection
        
--         local brainrotCount = 0
--         for br, _ in pairs(ourBrainrots) do
--             if br and br.PrimaryPart then
--                 brainrotCount = brainrotCount + 1
--                 local rarity = br:GetAttribute("Rarity") or "None"
--                 local mutation = br:GetAttribute("Mutation") or "None"
--                 local progress = br:GetAttribute("Progress") or br:GetAttribute("PathProgress") or 0
--                 local health = br:GetAttribute("Health") or "Unknown"
                
--                     br.Name, rarity, mutation, progress, tostring(health)))
                
--                 local passes = filterBrainrot(br)
--             end
--         end
        
--     end
-- })
-- combatActions:AddToggle("DebugStuns", {
--     Title = "Debug Stuns/Slows",
--     Default = false,
--     Callback = function(Value)
--         debugStunSlow = Value
--     end
-- })

-- Debug: Track brainrot progress in your plot
local debugProgressEnabled = false

-- combatActions:AddToggle("DebugBrainrotProgress", {
--     Title = "Debug Brainrot Progress",
--     Default = false,
--     Callback = function(Value)
--         debugProgressEnabled = Value
--         if debugProgressEnabled then
--             spawn(function()
--                 while debugProgressEnabled do
--                     local plotted = {}
--                     local brainrotsFolder = Workspace.ScriptedMap:FindFirstChild("Brainrots")
--                     if brainrotsFolder then
--                         for _, brainrot in ipairs(brainrotsFolder:GetChildren()) do
--                             if brainrot:IsA("Model") and brainrot.PrimaryPart then
--                                 -- Only check brainrots that are moving on your plotâ€™s paths
--                                 -- (reuse getBrainrotsNearPlot for filtering)
--                                 local progress = brainrot:GetAttribute("Progress") or 0
--                                 local hp = brainrot:GetAttribute("Health") or "?"
--                                 table.insert(plotted, string.format("%s | Progress=%.2f | HP=%s",
--                                     brainrot.Name, progress, tostring(hp)))
--                             end
--                         end
--                     end
--                     if #plotted > 0 then
--                         for _, line in ipairs(plotted) do
--                         end
--                     else
--                     end
--                     task.wait(1) -- update interval
--                 end
--             end)
--         end
--     end
-- })


-- Keep this table + updater somewhere outside the toggle

-- Update list of OUR brainrots (inside our paths)
local function updateOurBrainrots()
    if not detectedPlot or not detectedPlot.Parent then
        ourBrainrots = {}
        return
    end

    local brainrotsFolder = Workspace:FindFirstChild("ScriptedMap") and Workspace.ScriptedMap:FindFirstChild("Brainrots")
    if not brainrotsFolder then
        ourBrainrots = {}
        return
    end

    -- Keep current ones
    local updated = {}

    -- Always keep old ones alive until they're destroyed or dead
    for br, _ in pairs(ourBrainrots) do
        if br and br.Parent and br.PrimaryPart then
            local health = br:GetAttribute("Health") or br:GetAttribute("HP") or 0
            if health > 0 then
                updated[br] = true
            end
        end
    end

    -- Add any NEW ones detected near the paths
    for _, brainrot in pairs(brainrotsFolder:GetChildren()) do
        if brainrot:IsA("Model") and brainrot.PrimaryPart then
            local pos = brainrot.PrimaryPart.Position
            local isOurs = false
            for i = 1, 2 do
                local pathFolder = detectedPlot.Paths:FindFirstChild(tostring(i))
                if pathFolder then
                    for _, part in pairs(pathFolder:GetChildren()) do
                        if part:IsA("BasePart") and (pos - part.Position).Magnitude <= 15 then
                            isOurs = true
                            break
                        end
                    end
                end
                if isOurs then break end
            end

            if isOurs then
                updated[brainrot] = true
            end
        end
    end

    ourBrainrots = updated
end

-- keep log refreshed
task.spawn(function()
    while task.wait(0.2) do
        pcall(updateOurBrainrots)
    end
end)

-- Keep this running in background
task.spawn(function()
    while task.wait(0.5) do
        updateOurBrainrots()
    end
end)
-- combatActions:AddButton({
--     Title = "Test Stun Tools",
--     Description = "Test if your frost tools work (check console F9)",
--     Callback = function()
        
--         local character = LocalPlayer.Character
--         local hrp = character and character:FindFirstChild("HumanoidRootPart")
        
--         if not hrp then
--             return
--         end
        
--         local testPos = hrp.Position + Vector3.new(5, 0, 0)
        
--         -- Test Frost Grenade
--         local grenade = getFrostGrenade()
--         if grenade then
--             pcall(function()
--                 local args = {{
--                     Toggle = true,
--                     Tool = grenade,
--                     Time = 1.0,
--                     Pos = testPos
--                 }}
--                 ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
--             end)
--             task.wait(2)
--         end
        
--         -- Test Frost Blower
--         local blower = getFrostBlower()
--         if blower then
--             pcall(function()
--                 local args = {{
--                     Tool = blower,
--                     Toggle = true
--                 }}
--                 ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
--             end)
            
--             task.wait(2)
            
--             pcall(function()
--                 local args = {{
--                     Tool = blower,
--                     Toggle = false
--                 }}
--                 ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem"):FireServer(unpack(args))
--             end)
--         end
        
--     end
-- })
combatActions:AddToggle("AutoUseStunsSlow", {
    Title = "Auto use Stuns and Slows",
    Default = false,
    Callback = function(Value)
        autoStunSlowEnabled = Value
        if autoStunSlowEnabled then
            task.spawn(function()
                while task.wait(0.2) do
                    if not autoStunSlowEnabled then break end

                    local stunned = 0
                    for br, _ in pairs(ourBrainrots) do
                        if not autoStunSlowEnabled then break end
                        if br and br.PrimaryPart then
                            local progress = br:GetAttribute("Progress")
                                or br:GetAttribute("PathProgress")
                                or br:GetAttribute("WalkProgress")
                                or 0

                            if progress > 0.59 then

                                -- Move near brainrot
                                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    hrp.CFrame = br.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
                                    task.wait(0.15)
                                    if not autoStunSlowEnabled then break end
                                end

                                -- Frost Grenade
                                local grenade = getFrostGrenade()
                                if grenade and autoStunSlowEnabled then
                                    pcall(function()
                                        local args = {{
                                            Toggle = true,
                                            Tool = grenade,
                                            Time = 1.0,
                                            Pos = br.PrimaryPart.Position
                                        }}
                                        ReplicatedStorage.Remotes.UseItem:FireServer(unpack(args))
                                    end)
                                    task.wait(0.4)
                                end

                                -- Frost Blower
                                local blower = getFrostBlower()
                                if blower and autoStunSlowEnabled then
                                    pcall(function()
                                        ReplicatedStorage.Remotes.UseItem:FireServer({{
                                            Tool = blower,
                                            Toggle = true
                                        }})
                                    end)

                                    task.wait(1.5)

                                    pcall(function()
                                        ReplicatedStorage.Remotes.UseItem:FireServer({{
                                            Tool = blower,
                                            Toggle = false
                                        }})
                                    end)
                                end

                                stunned += 1
                                task.wait(0.6)
                            end
                        end
                    end

                    if stunned > 0 then
                    end
                end

                -- Failsafe: turn off blower if toggle disabled mid-use
                local blower = getFrostBlower()
                if blower then
                    pcall(function()
                        ReplicatedStorage.Remotes.UseItem:FireServer({{
                            Tool = blower,
                            Toggle = false
                        }})
                    end)
                end

            end)
        end
    end
})






-- ======= SMART PLACEMENT TAB =======
local smartRules = Tabs.Smart:AddSection("Rules & Settings")
local smartActions = Tabs.Smart:AddSection("Placement Actions")

local maxCols = MAX_COLS
local mutationRules = {} -- { [col] = "Frozen" }

-- Row Damage Display Paragraph
local rowDamageParagraph = Tabs.Smart:AddParagraph({
    Title = "Row Damage Averages",
    Content = "No placement run yet..."
})

local function updateRowDamageParagraph(rowDamages, unlockedRows)
    local avgContent = {}
    for r = 1, unlockedRows do
        table.insert(avgContent, string.format("Row %d: %d dmg", r, rowDamages[r]))
    end
    rowDamageParagraph:SetDesc(table.concat(avgContent, "\n"))
end

smartRules:AddSlider("MaxCols", {
    Title = "Max Columns Per Row",
    Min = 1, Max = 5, Default = MAX_COLS,
    Rounding = 0,
    Callback = function(Value) maxCols = Value end
})

smartRules:AddInput("MutationRule", {
    Title = "Set Mutation Rule (ex: '5 Frozen')",
    Placeholder = "Column Mutation",
    Callback = function(Value)
        local col, mut = Value:match("(%d+)%s+(%w+)")
        if col and mut then
            mutationRules[tonumber(col)] = mut
            Fluent:Notify({Title="Rule Added", Content="Col "..col.." = "..mut, Duration=3})
        end
    end
})

smartRules:AddButton({
    Title = "Clear Rules",
    Callback = function()
        mutationRules = {}
        Fluent:Notify({Title="Rules", Content="All mutation rules cleared", Duration=3})
    end
})

-- REPLACE the entire "Auto Smart Place" button block with this
smartActions:AddButton({
    Title = "Auto Smart Place",
    Description = "Distribute plants evenly across rows by damage",
    Callback = function()
        if not detectedPlot then
            Fluent:Notify({Title="Error", Content="No plot detected!", Duration=4})
            return
        end

        task.spawn(function()
            -- Step 0: Clear existing plants
            local plantsToRemove = {}
            for row = 1, MAX_ROWS do
                for col = 1, MAX_COLS do
                    local plantObject = getPlantObjectAt(row, col, detectedPlot)
                    if plantObject then table.insert(plantsToRemove, plantObject) end
                end
            end

            if #plantsToRemove > 0 then
                Fluent:Notify({Title="Clearing Plot", Content="Removing " .. #plantsToRemove .. " existing plants...", Duration=3})
                for _, plant in ipairs(plantsToRemove) do
                    removePlant(plant) -- CORRECTED
                    task.wait(0.05)
                end
                task.wait(2)
            end

            -- Detect the actual plant limit
            local unlockedRowCount = getUnlockedRowCount(detectedPlot)
            local plantLimit = unlockedRowCount * 5
            Fluent:Notify({Title="Smart Place", Content="Detected " .. unlockedRowCount .. " unlocked rows. Max plants: " .. plantLimit, Duration=5})

            -- Step 1: Collect and sort all plants from backpack
            local allPlants = {}
            for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("Plant") then
                    table.insert(allPlants, { tool = tool, damage = tool:GetAttribute("Damage") or 0, mutation = tool:GetAttribute("Colors"), placed = false })
                end
            end

            if #allPlants == 0 then
                Fluent:Notify({Title="Error", Content="No plants in inventory!", Duration=4})
                return
            end

            table.sort(allPlants, function(a,b) return a.damage > b.damage end)

            -- Create a final list using only the best plants up to the limit
            local plantsToPlace = {}
            for i = 1, math.min(plantLimit, #allPlants) do
                table.insert(plantsToPlace, allPlants[i])
            end

            -- Step 2: Initialize placement logic
            local rowDamages, placements = {}, {}
            for row = 1, unlockedRowCount do
                rowDamages[row] = 0
                placements[row] = {}
            end

            -- PASS 1 & 2: Placement logic
            for col, mut in pairs(mutationRules) do
                for _, plantToPlace in ipairs(plantsToPlace) do
                    if not plantToPlace.placed and plantToPlace.mutation == mut then
                        local bestRow, minDamage = -1, math.huge
                        for row = 1, unlockedRowCount do
                            if not placements[row][col] and rowDamages[row] < minDamage then
                                minDamage = rowDamages[row]
                                bestRow = row
                            end
                        end
                        if bestRow ~= -1 then
                            placements[bestRow][col] = plantToPlace
                            rowDamages[bestRow] += plantToPlace.damage
                            plantToPlace.placed = true
                        end
                    end
                end
            end

            for _, plant in ipairs(plantsToPlace) do
                if not plant.placed then
                    local bestRow, minDamage = -1, math.huge
                    for row = 1, unlockedRowCount do
                        if table.getn(placements[row]) < maxCols and rowDamages[row] < minDamage then
                            minDamage = rowDamages[row]
                            bestRow = row
                        end
                    end
                    if bestRow ~= -1 then
                        for col = 1, maxCols do
                            if not placements[bestRow][col] then
                                placements[bestRow][col] = plant
                                rowDamages[bestRow] += plant.damage
                                plant.placed = true
                                break
                            end
                        end
                    end
                end
            end

            -- Step 3: Execute placement
            isPlacing = true
            task.spawn(cleanupPlacementIndicators)
            local placedCount = 0
            for row, cols in ipairs(placements) do
                for col, plantData in pairs(cols) do
                    if plantData then
                        placePlant(plantData.tool, detectedPlot, row, col)
                        placedCount += 1
                        task.wait(0.3)
                    end
                end
            end

            isPlacing = false
            updateRowDamageParagraph(rowDamages, unlockedRowCount) -- Update the UI
            Fluent:Notify({
                Title="Smart Placement Complete",
                Content="Placed "..placedCount.." / "..#plantsToPlace.." of your best plants.",
                Duration=6
            })
        end)
    end
})

-- ======= BRAINROTS TAB =======
local autoCollect = Tabs.Brainrots:AddSection("Auto Collection")
local sellOptions = Tabs.Brainrots:AddSection("Sell Options")

sellOptions:AddButton({
    Title = "Normal Sell All Brainrots",
    Description = "Sells Brainrots how you typically would to Barry",
    Callback = function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer()
    end
})

local autoNormalSell = false
sellOptions:AddToggle("AutoNormalSell", {
    Title = "Auto Normal Sell All Brainrots",
    Default = false,
    Callback = function(Value)
        autoNormalSell = Value
        if autoNormalSell then
            task.spawn(function()
                while autoNormalSell do
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer()
                    task.wait(5)
                end
            end)
        end
    end
})



sellOptions:AddToggle("AutoCustomSellBrainrots", {
    Title = "Auto Custom Sell Brainrots",
    Default = false,
    Callback = function(Value)
        autoCustomSell = Value
        if autoCustomSell then
            task.spawn(function() -- line 2658
                while autoCustomSell do
                    local backpack = LocalPlayer.Backpack
                    local brainrotsChecked = 0
                    local brainrotsQueued = 0

                    -- Clear queue before scanning
                    sellQueue = {}

                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("Brainrot") then
                            brainrotsChecked = brainrotsChecked + 1
                            local size = tool:GetAttribute("Size") or 0
                            local mutation = tool:GetAttribute("MutationString") or tool:GetAttribute("Brainrot")

                            -- Extract base name
                            local baseName = tool.Name:gsub("^%b[]%s*", "")
                            baseName = baseName:gsub("^%b[]%s*", "")

                            -- Check if excluded
                            if table.find(brainrotsToExclude, baseName) then
                                continue
                            end

                            -- Get rarity from asset
                            local brainrotAsset = game:GetService("ReplicatedStorage").Assets.Brainrots:FindFirstChild(baseName)
                            local rarity = brainrotAsset and brainrotAsset:GetAttribute("Rarity") or "Normal"

                            local keep = true

                            -- Apply filters - only if filters are actually selected
                            if #filterMode > 0 then
                                for _, filter in ipairs(filterMode) do
                                    if filter == "Size" and size < sizeMin then
                                        keep = false
                                        break
                                    elseif filter == "Mutation" then
                                        if mutation then
                                            local mutType = mutation:match("^(%w+)")
                                            if not (mutType and table.find(mutationsToKeep, mutType)) then
                                                keep = false
                                                break
                                            end
                                        else
                                            if not table.find(mutationsToKeep, "Normal") then
                                                keep = false
                                                break
                                            end
                                        end
                                    elseif filter == "Rarity" and not table.find(raritiesToKeep, rarity) then
                                        keep = false
                                        break
                                    end
                                end
                            else
                                -- No filters selected = keep everything
                                keep = true
                            end

                            if not keep then
                                table.insert(sellQueue, tool)
                                brainrotsQueued = brainrotsQueued + 1
                            else
                            end
                        end
                    end


                    -- Now sell all queued brainrots
                    while #sellQueue > 0 and autoCustomSell do
                        local tool = table.remove(sellQueue, 1)
                        if tool and tool.Parent == backpack then
                            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                humanoid:EquipTool(tool)
                                task.wait(0.05)
                                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer()
                                task.wait(0.5)
                            end
                        end
                    end

                    task.wait(5) -- Wait before next scan
                end
            end)
        else
            sellQueue = {}
        end
    end
})


-- sellOptions:AddButton({
--     Title = "Compare Detection Methods - FIXED",
--     Description = "Runs both detection methods and shows differences",
--     Callback = function()
        
--         local backpack = game:GetService("Players").LocalPlayer.Backpack
        
--         -- Initialize filter variables with empty defaults
--         local filterMode = {}
--         local raritiesToKeep = {}
--         local mutationsToKeep = {}
--         local sizeMin = 0
--         local brainrotsToExclude = {}
        
        
--         local testSellCount = 0
--         local autoSellCount = 0
--         local totalBrainrots = 0
        
--         -- Run both detection methods on same tools
--         for _, tool in ipairs(backpack:GetChildren()) do
--             if tool:IsA("Tool") and tool:GetAttribute("Brainrot") then
--                 totalBrainrots = totalBrainrots + 1
--                 local size = tool:GetAttribute("Size") or 0
--                 local mutation = tool:GetAttribute("MutationString") or tool:GetAttribute("Brainrot")
--                 local baseName = tool.Name:gsub("^%b[]%s*", "")
--                 baseName = baseName:gsub("^%b[]%s*", "")
                
--                 local brainrotAsset = game:GetService("ReplicatedStorage").Assets.Brainrots:FindFirstChild(baseName)
--                 local rarity = brainrotAsset and brainrotAsset:GetAttribute("Rarity") or "Normal"
                
                
--                 -- TEST METHOD (like the working test button)
--                 local testWouldSell = false
--                 if table.find(brainrotsToExclude, baseName) then
--                     testWouldSell = false -- EXCLUDED items are NOT sold
--                 else
--                     local testKeep = true
--                     for _, filter in ipairs(filterMode) do
--                         if filter == "Size" and size < sizeMin then
--                             testKeep = false
--                             break
--                         elseif filter == "Mutation" then
--                             if mutation then
--                                 local mutType = mutation:match("^(%w+)")
--                                 if not (mutType and table.find(mutationsToKeep, mutType)) then
--                                     testKeep = false
--                                     break
--                                 end
--                             else
--                                 if not table.find(mutationsToKeep, "Normal") then
--                                     testKeep = false
--                                     break
--                                 end
--                             end
--                         elseif filter == "Rarity" and not table.find(raritiesToKeep, rarity) then
--                             testKeep = false
--                             break
--                         end
--                     end
--                     testWouldSell = not testKeep
--                     if testKeep then
--                     end
--                 end
                
--                 -- AUTO METHOD (like the auto-sell logic)
--                 local autoWouldSell = false
--                 if table.find(brainrotsToExclude, baseName) then
--                     autoWouldSell = false -- EXCLUDED items are skipped (continue)
--                 else
--                     local autoKeep = true
--                     if filterMode and type(filterMode) == "table" and #filterMode > 0 then
--                         for _, filter in ipairs(filterMode) do
--                             if filter == "Size" and size < sizeMin then
--                                 autoKeep = false
--                                 break
--                             elseif filter == "Mutation" then
--                                 if mutation then
--                                     local mutType = mutation:match("^(%w+)")
--                                     if not (mutType and table.find(mutationsToKeep, mutType)) then
--                                         autoKeep = false
--                                         break
--                                     end
--                                 else
--                                     if not table.find(mutationsToKeep, "Normal") then
--                                         autoKeep = false
--                                         break
--                                     end
--                                 end
--                             elseif filter == "Rarity" and not table.find(raritiesToKeep, rarity) then
--                                 autoKeep = false
--                                 break
--                             end
--                         end
--                     else
--                     end
--                     autoWouldSell = not autoKeep
--                     if autoKeep then
--                     end
--                 end
                
--                 -- Count the sells
--                 if testWouldSell then testSellCount = testSellCount + 1 end
--                 if autoWouldSell then autoSellCount = autoSellCount + 1 end
                
--                 -- Show mismatches
--                 if testWouldSell ~= autoWouldSell then
--                 end
--             end
--         end
        
--     end
-- })

-- Also add a simple brainrot counter for debugging:
-- sellOptions:AddButton({
--     Title = "Count All Brainrots",
--     Description = "Just counts brainrots in inventory",
--     Callback = function()
--         local backpack = game:GetService("Players").LocalPlayer.Backpack
--         local brainrotCount = 0
--         local toolCount = 0
        
--         for _, tool in ipairs(backpack:GetChildren()) do
--             toolCount = toolCount + 1
--             if tool:IsA("Tool") then
--                 local isBrainrot = tool:GetAttribute("Brainrot")
--                 if isBrainrot then
--                     brainrotCount = brainrotCount + 1
--                 end
--             end
--         end
        
--     end
-- })
-- Custom Sell Settings
local mutationsModule = require(game:GetService("ReplicatedStorage").Modules.Library.BrainrotMutations)
local raritiesModule = require(game:GetService("ReplicatedStorage").Modules.Library.Chances)

local mutationOptions, rarityOptions = {}, {}
for mutName, _ in pairs(mutationsModule.Colors) do
    table.insert(mutationOptions, mutName)
end
for rarityName, _ in pairs(raritiesModule) do
    table.insert(rarityOptions, rarityName)
end

local raritiesToKeep, mutationsToKeep = {}, {}
-- local sizeMin = 0
-- local filterMode = {}

local function getAvailableBrainrots()
    local brainrots = {}
    pcall(function()
        local brainrotsAssets = game:GetService("ReplicatedStorage").Assets.Brainrots
        for _, brainrot in pairs(brainrotsAssets:GetChildren()) do
            table.insert(brainrots, brainrot.Name)
        end
        -- Sort alphabetically for better UX
        table.sort(brainrots)
    end)
    return brainrots
end

-- Add this dropdown to the sellOptions section (after the existing dropdowns, around line 850)
sellOptions:AddDropdown("BrainrotsToExclude", {
    Title = "Brainrots to Exclude",
    Description = "These brainrots will NEVER be sold, regardless of filters",
    Values = getAvailableBrainrots(),
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        brainrotsToExclude = selectionArray
    end
})

sellOptions:AddToggle("AutoCustomSellBrainrots", {
    Title = "Auto Custom Sell Brainrots",
    Description = "Automatically sells brainrots based on your custom filter settings.",
    Default = false,
    Callback = function(Value)
        autoCustomSell = Value
        if autoCustomSell then
            task.spawn(function()
                Fluent:Notify({ Title = "Auto Sell", Content = "Custom brainrot selling has started.", Duration = 3 })
                while autoCustomSell do
                    -- This local function will gather all brainrots that should be sold
                    local function getBrainrotsToSell()
                        local sellList = {}
                        local backpack = game:GetService("Players").LocalPlayer.Backpack
                        
                        for _, tool in ipairs(backpack:GetChildren()) do
                            if tool:IsA("Tool") and tool:GetAttribute("Brainrot") then
                                local size = tool:GetAttribute("Size") or 0
                                local mutation = tool:GetAttribute("MutationString") or tool:GetAttribute("Brainrot")
                                local baseName = tool.Name:gsub("^%b[]%s*", "")
                                baseName = baseName:gsub("^%b[]%s*", "")
                                
                                local brainrotAsset = game:GetService("ReplicatedStorage").Assets.Brainrots:FindFirstChild(baseName)
                                local rarity = brainrotAsset and brainrotAsset:GetAttribute("Rarity") or "Normal"
                                
                                -- Check if the brainrot is in the exclusion list
                                if table.find(brainrotsToExclude, baseName) then
                                    -- Do nothing, we are keeping it
                                else
                                    -- If no filters are enabled, we keep everything by default.
                                    -- If filters ARE enabled, we check if it should be sold.
                                    local keep = true
                                    if #filterMode > 0 then
                                        for _, filter in ipairs(filterMode) do
                                            if filter == "Size" and size < sizeMin then
                                                keep = false
                                                break
                                            elseif filter == "Mutation" then
                                                if mutation then
                                                    local mutType = mutation:match("^(%w+)")
                                                    if not (mutType and table.find(mutationsToKeep, mutType)) then
                                                        keep = false
                                                        break
                                                    end
                                                else
                                                    if not table.find(mutationsToKeep, "Normal") then
                                                        keep = false
                                                        break
                                                    end
                                                end
                                            elseif filter == "Rarity" and not table.find(raritiesToKeep, rarity) then
                                                keep = false
                                                break
                                            end
                                        end
                                    end
                                    
                                    -- If the 'keep' flag is false, add it to the list to be sold
                                    if not keep then
                                        table.insert(sellList, tool)
                                    end
                                end
                            end
                        end
                        return sellList
                    end

                    local itemsToSell = getBrainrotsToSell()
                    
                    if #itemsToSell > 0 then
                        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            for _, tool in ipairs(itemsToSell) do
                                if not autoCustomSell then break end -- Stop if user disables toggle
                                if tool and tool.Parent then
                                    humanoid:EquipTool(tool)
                                    task.wait(0.1)
                                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ItemSell"):FireServer()
                                    task.wait(0.25)
                                end
                            end
                            humanoid:UnequipTools()
                        end
                    end
                    
                    -- Wait for 5 seconds before scanning the inventory again
                    task.wait(5)
                end
                Fluent:Notify({ Title = "Auto Sell", Content = "Custom brainrot selling has stopped.", Duration = 3 })
            end)
        end
    end
})

-- sellOptions:AddButton({
--     Title = "Test Brainrot Detection",
--     Description = "Shows what brainrots would be sold with current settings",
--     Callback = function()
--         local backpack = game:GetService("Players").LocalPlayer.Backpack
--         local brainrotCount = 0
--         local sellCount = 0
        
        
--         for _, tool in ipairs(backpack:GetChildren()) do
--             if tool:IsA("Tool") and tool:GetAttribute("Brainrot") then
--                 brainrotCount = brainrotCount + 1
--                 local size = tool:GetAttribute("Size") or 0
--                 local mutation = tool:GetAttribute("MutationString") or tool:GetAttribute("Brainrot")
--                 local baseName = tool.Name:gsub("^%b[]%s*", "")
--                 baseName = baseName:gsub("^%b[]%s*", "")
                
--                 local brainrotAsset = game:GetService("ReplicatedStorage").Assets.Brainrots:FindFirstChild(baseName)
--                 local rarity = brainrotAsset and brainrotAsset:GetAttribute("Rarity") or "Normal"
                
                
--                 -- Check if excluded
--                 if table.find(brainrotsToExclude, baseName) then
--                 else
--                     local keep = true
--                     for _, filter in ipairs(filterMode) do
--                         if filter == "Size" and size < sizeMin then
--                             keep = false
--                             break
--                         elseif filter == "Mutation" then
--                             if mutation then
--                                 local mutType = mutation:match("^(%w+)")
--                                 if not (mutType and table.find(mutationsToKeep, mutType)) then
--                                     keep = false
--                                     break
--                                 end
--                             else
--                                 if not table.find(mutationsToKeep, "Normal") then
--                                     keep = false
--                                     break
--                                 end
--                             end
--                         elseif filter == "Rarity" and not table.find(raritiesToKeep, rarity) then
--                             keep = false
--                             break
--                         end
--                     end
                    
--                     if keep then
--                     else
--                         sellCount = sellCount + 1
--                     end
--                 end
--             end
--         end
        
--     end
-- })
sellOptions:AddDropdown("FilterMode", {
    Title = "Filters To Actually Use",
    Values = {"Size","Mutation","Rarity"},
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        filterMode = selectionArray
    end
})

sellOptions:AddDropdown("RarityDropdown", {
    Title = "Rarities To Keep",
    Values = rarityOptions,
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        raritiesToKeep = selectionArray
    end
})

sellOptions:AddDropdown("MutationDropdown", {
    Title = "Mutations To Keep",
    Values = mutationOptions,
    Multi = true,
    Default = {},
    Callback = function(selected)
        local selectionArray = {}
        if type(selected) == "table" then
            if #selected > 0 then
                selectionArray = selected
            else
                for name, enabled in pairs(selected) do
                    if enabled then table.insert(selectionArray, name) end
                end
            end
        end
        mutationsToKeep = selectionArray
    end
})

sellOptions:AddInput("SizeMin", {
    Title = "Min Size (Keep Ã¢â‚¬Å¡ÃƒÂ¢Ã¢â‚¬Â¢ this)",
    Placeholder = "Ex: 1.6",
    Callback = function(Value)
        sizeMin = tonumber(Value) or sizeMin
    end
})

-- -- Additional toggles for Combat integration
-- sellOptions:AddToggle("KeepValidMutation", {
--     Title = "Keep if Valid Mutation",
--     Default = false,
--     Callback = function(Value)
--         keepValidMutation = Value
--     end
-- })

-- sellOptions:AddToggle("KeepValidSize", {
--     Title = "Keep if Valid Size",
--     Default = false,
--     Callback = function(Value)
--         keepValidSize = Value
--     end
-- })

autoCollect:AddParagraph({ Title = "Auto Collection", Content = "Automatically teleports to and collects brainrots." })

autoCollect:AddToggle("AutoCollect", {
    Title = "Auto Collect Brainrots",
    Default = false,
    Callback = function(Value)
        autoCollectEnabled = Value
        if Value then
            Fluent:Notify({ Title = "Auto Collect", Content = "Started.", Duration = 3 })
            spawn(function()
                while autoCollectEnabled do
                    if detectedPlot then
                        local collected = collectBrainrots()
                        if collected and collected > 0 then
                        end
                    end
                    task.wait(Fluent.Options.CollectDelay and Fluent.Options.CollectDelay.Value or collectDelay)
                end
            end)
        else
            Fluent:Notify({ Title = "Auto Collect", Content = "Stopped.", Duration = 3 })
        end
    end
})

autoCollect:AddSlider("CollectDelay", {
    Title = "Collection Delay (seconds)", Default = 10, Min = 1, Max = 60, Rounding = 0,
    Callback = function(Value) collectDelay = Value end
})

autoCollect:AddButton({
    Title = "Collect Now (Manual)",
    Description = "Manually run the collection cycle once.",
    Callback = function()
        spawn(function()
            local collected = manualCollectBrainrots()
            Fluent:Notify({ Title = "Manual Collection", Content = "Collected " .. collected .. " brainrots.", Duration = 3 })
        end)
    end
})

-- ======= SHOPS TAB =======
local seedShop = Tabs.Shops:AddSection("Seed Shop")
local availableShopSeeds = getAvailableSeeds()

seedShop:AddDropdown("ShopSeedSelect", {
    Title = "Select Seeds to Buy",
    Values = availableShopSeeds,
    Multi = true,
    Default = {},
    Callback = function(Value)
        selectedSeedsShop = {}
        
        if type(Value) == "table" then
            if #Value > 0 then
                selectedSeedsShop = Value
            else
                for seed, enabled in pairs(Value) do
                    if enabled then
                        table.insert(selectedSeedsShop, seed)
                    end
                end
            end
        end
        
    end
})

local seedAmount = 1

seedShop:AddButton({
    Title = "Buy Selected Seeds",
    Callback = function()
        if #selectedSeedsShop == 0 then
            Fluent:Notify({ Title = "Error", Content = "No seeds selected!", Duration = 3 })
            return
        end
        
        
        for i, seedName in ipairs(selectedSeedsShop) do
            local success = buyItem(seedName, seedAmount, "\b", "Seeds")
            
            if success then
            else
            end
            
            if i < #selectedSeedsShop then
                task.wait(1.5) 
            end
        end
        
        Fluent:Notify({ 
            Title = "Purchase Complete", 
            Content = "Attempted to buy " .. #selectedSeedsShop .. " seed types (" .. seedAmount .. "x each)",
            Duration = 5
        })
    end
})

seedShop:AddToggle("AutoBuySeed", {
    Title = "Auto-Purchase Selected Seeds",
    Description = "Continuously buys the selected seeds when available.",
    Callback = function(Value) autoBuySeedEnabled = Value end
})

local gearShop = Tabs.Shops:AddSection("Gear Shop")
local availableShopGears = getAvailableGears()

gearShop:AddDropdown("ShopGearSelect", {
    Title = "Select Gears to Buy",
    Values = availableShopGears,
    Multi = true,
    Default = {},
    Callback = function(Value)
        selectedGearsShop = {}
        
        if type(Value) == "table" then
            if #Value > 0 then
                selectedGearsShop = Value
            else
                for gear, enabled in pairs(Value) do
                    if enabled then
                        table.insert(selectedGearsShop, gear)
                    end
                end
            end
        end
        
    end
})

local gearAmount = 1

gearShop:AddButton({
    Title = "Buy Selected Gears",
    Callback = function()
        if #selectedGearsShop == 0 then
            Fluent:Notify({ Title = "Error", Content = "No gears selected!", Duration = 3 })
            return
        end
        
        
        for i, gearName in ipairs(selectedGearsShop) do
            local success = buyItem(gearName, gearAmount, "\026", "Gears")
            
            if success then
            else
            end
            
            if i < #selectedGearsShop then
                task.wait(1.5)
            end
        end
        
        Fluent:Notify({ 
            Title = "Purchase Complete", 
            Content = "Attempted to buy " .. #selectedGearsShop .. " gear types (" .. gearAmount .. "x each)",
            Duration = 5
        })
    end
})

gearShop:AddToggle("AutoBuyGear", {
    Title = "Auto-Purchase Selected Gears",
    Description = "Continuously buys the selected gears when available.",
    Callback = function(Value) autoBuyGearEnabled = Value end
})

spawn(function()
    while task.wait(2) do
        if autoBuySeedEnabled and #selectedSeedsShop > 0 then
            for _, seedName in pairs(selectedSeedsShop) do
                buyItem(seedName, 1, "\b", "Seeds")
                wait(0.25)
            end
        end
        if autoBuyGearEnabled and #selectedGearsShop > 0 then
            for _, gearName in pairs(selectedGearsShop) do
                buyItem(gearName, 1, "\026", "Gears")
                wait(0.25)
            end
        end
    end
end)

-- ======= LAYOUTS TAB =======
local layoutManage = Tabs.Layouts:AddSection("Layout Management")
local layoutName = "MyLayout"
local selectedLayout = nil

layoutManage:AddParagraph({
    Title = "Save & Load Plant Layouts",
    Content = "Save your current plot setup and load it back anytime."
})

layoutManage:AddInput("LayoutName", {
    Title = "Layout Name",
    Default = layoutName,
    Callback = function(Value)
        layoutName = Value or "MyLayout"
    end
})

local layoutsDropdown
local function refreshLayoutsDropdown()
    local configs = listLayouts()
    if layoutsDropdown then
        layoutsDropdown:SetValues(configs)
        if #configs > 0 then
            selectedLayout = configs[1]
        else
            selectedLayout = nil
        end
    end
end

layoutManage:AddButton({
    Title = "Save Current Layout",
    Description = "Saves the position of every plant on your plot",
    Callback = function()
        if not detectedPlot then
            Fluent:Notify({Title="Error", Content="No plot detected to save.", Duration=4})
            return
        end

        local layoutData = {}
        local plantsFound = 0
        for row = 1, MAX_ROWS do
            for col = 1, MAX_COLS do
                local plantObject = getPlantObjectAt(row, col, detectedPlot)
                if plantObject then
                    local id = plantObject:GetAttribute("ID")
                    if id then
                        plantsFound += 1
                        table.insert(layoutData, {
                            row = row,
                            col = col,
                            id = id,
                            name = plantObject.Name
                        })
                    end
                end
            end
        end

        if plantsFound > 0 then
            saveLayout(layoutName, layoutData)
            Fluent:Notify({Title="Success", Content="Layout '"..layoutName.."' saved with "..plantsFound.." plants.", Duration=5})
            refreshLayoutsDropdown()
        else
            Fluent:Notify({Title="Info", Content="No plants found on the plot to save.", Duration=4})
        end
    end
})

layoutsDropdown = Tabs.Layouts:AddDropdown("LayoutDropdown", {
    Title = "Select Layout to Load",
    Values = listLayouts(),
    Default = nil,
    Callback = function(Value) selectedLayout = Value end
})

task.spawn(refreshLayoutsDropdown)

layoutManage:AddButton({
    Title = "Load Selected Layout",
    Description = "WARNING: This will remove all current plants first!",
    Callback = function()
        if not selectedLayout then
            Fluent:Notify({Title="Error", Content="No layout selected to load.", Duration=4})
            return
        end
        if not detectedPlot then
            Fluent:Notify({Title="Error", Content="No plot detected to load onto.", Duration=4})
            return
        end

        local layoutData = loadLayout(selectedLayout)
        if not layoutData then
            Fluent:Notify({Title="Error", Content="Could not load layout data for '"..selectedLayout.."'.", Duration=4})
            return
        end

        task.spawn(function()
            Fluent:Notify({Title="Loading...", Content="Clearing all plants from the plot.", Duration=3})
            
            local plantsOnPlot = {}
            for row = 1, MAX_ROWS do
                for col = 1, MAX_COLS do
                    local plantObject = getPlantObjectAt(row, col, detectedPlot)
                    if plantObject then table.insert(plantsOnPlot, plantObject) end
                end
            end
            
            -- Layout clearing (before placing saved plants)
            for _, plant in ipairs(plantsOnPlot) do
                removePlant(plant) -- CORRECTED
                task.wait(0.05)
            end
            
            Fluent:Notify({Title="Loading...", Content="Plot cleared. Now placing saved plants.", Duration=3})
            task.wait(2)

            local placedCount = 0
            local missingCount = 0
            isPlacing = true
            task.spawn(cleanupPlacementIndicators)

            for _, plantInfo in ipairs(layoutData) do
                local tool = findPlantToolById(plantInfo.id)
                if tool then
                    placePlant(tool, detectedPlot, plantInfo.row, plantInfo.col)
                    placedCount = placedCount + 1
                    task.wait(0.3)
                else
                    missingCount = missingCount + 1
                end
            end
            
            isPlacing = false
            Fluent:Notify({Title="Layout Loaded", Content="Placed "..placedCount.." plants. Could not find "..missingCount.." plants.", Duration=6})
        end)
    end
})

layoutManage:AddButton({
    Title = "Delete Selected Layout",
    Description = "Permanently deletes the saved layout file.",
    Callback = function()
        if not selectedLayout then
            Fluent:Notify({Title="Error", Content="No layout selected to delete.", Duration=4})
            return
        end
        deleteLayout(selectedLayout)
        Fluent:Notify({Title="Success", Content="Deleted layout '"..selectedLayout.."'.", Duration=4})
        refreshLayoutsDropdown()
    end
})

-- ======= SETTINGS TAB =======
local generalSettings = Tabs.Settings:AddSection("General")
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("issabrainrot")
SaveManager:SetFolder("issabrainrot/configs") 

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
-- ======= SETTINGS TAB =======
local generalSettings = Tabs.Settings:AddSection("General")

-- ADD THIS BUTTON
generalSettings:AddButton({
    Title = "Load Recommended Config",
    Description = "Applies the default recommended settings for all features. Your current settings will be overwritten.",
    Callback = function()
        task.spawn(function()
            -- The URL to your raw config file on GitHub Gist
            local defaultConfigUrl = "https://raw.githubusercontent.com/issapizzapizza/rcs/refs/heads/main/reccomendedconfig.json"
            
            Fluent:Notify({ Title = "Configuration", Content = "Loading recommended settings...", Duration = 3 })
            
            local success, result = pcall(function()
                return game:HttpGet(defaultConfigUrl)
            end)

            if not success then
                Fluent:Notify({ Title = "Error", Content = "Failed to download config. Please try again.", Duration = 5 })
                return
            end

            local configData = HttpService:JSONDecode(result)
            local applied = applyConfiguration(configData)

            if applied then
                Fluent:Notify({ Title = "Success", Content = "Recommended settings have been applied!", Duration = 5 })
            else
                Fluent:Notify({ Title = "Error", Content = "Could not apply the configuration.", Duration = 5 })
            end
        end)
    end
})
SaveManager:BuildConfigSection(Tabs.Settings)

generalSettings:AddButton({
    Title = "Unload Script",
    Description = "Closes the GUI and stops all functions",
    Callback = function()
        autoCollectEnabled = false
        autoBuySeedEnabled = false
        autoBuyGearEnabled = false
        eventSeedsEnabled = false
        normalSeedsEnabled = false
        autoWaterBucketEvent = false
        autoWaterBucketNormal = false
        autoAttackEnabled = false
        autoStunSlowEnabled = false
        isPlacing = false 
        removeAllHighlights() 
        Window:Destroy()
    end
})

-- ======= INITIALIZATION =======
Window:SelectTab(1)
refreshLayoutsDropdown()
Fluent:Notify({ Title = "Brainrot Hub Loaded", Content = "v4.0 Seeds & Combat Update - Welcome!", Duration = 8 })
SaveManager:LoadAutoloadConfig()
