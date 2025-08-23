--[[
============================================================
-- ## CONFIGURATION ##
============================================================
]]
local Config = {
    Enabled = true,
    BOXES_TO_OPEN = { "Mystery Box", "Light Box", "Festival Mystery Box" },
    UseQuantity = 1000,
    AutoOpenBoxes = true, -- ## NEW: Toggle state for opening boxes ##

    -- ## TIMING SETTINGS ##
    BurstDuration = 1,  -- How many seconds to run at full speed.
    WaitDuration = 6,   -- How many seconds to pause between bursts.

    -- ## PROXIMITY SETTING ##
    EggAreaRadius = 150 -- The maximum distance from the main egg area to be able to open boxes.
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

-- This function will be defined later, but we need to declare it here for Thread 2
local isPlayerInMainEggArea 

-- ## THREAD 2: BOX USER (CONTROLLED BY SCHEDULER) ##
task.spawn(function()
    while getgenv().Config.Enabled do
        -- ## UPDATED: Added check for the AutoOpenBoxes toggle ##
        if isBurstActive and getgenv().Config.AutoOpenBoxes and isPlayerInMainEggArea and isPlayerInMainEggArea() then
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

--// Fluent + SaveManager Setup //-- 
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))() 
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))() 

local Window = Fluent:CreateWindow({ 
	Title = "shitass comp script v3.2", -- updated version
	SubTitle = "made by lonly on discord", 
	TabWidth = 160, 
	Size = UDim2.fromOffset(600, 520), 
	Acrylic = true, 
	Theme = "Dark", 
	MinimizeKey = Enum.KeyCode.LeftControl 
}) 

local Options = SaveManager:Load() or {} 
SaveManager:SetLibrary(Fluent) 

-- Tabs 
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" }) 
local QuestTab = Window:AddTab({ Title = "Quests", Icon = "edit" }) 
local EggSettingsTab = Window:AddTab({ Title = "Egg Settings", Icon = "settings" }) 

-- Services & Vars 
local players = game:GetService("Players") 
local replicatedStorage = game:GetService("ReplicatedStorage") 
local VirtualInputManager = game:GetService("VirtualInputManager") 
local HttpService = game:GetService("HttpService")

local player = players.LocalPlayer 
local character = player.Character or player.CharacterAdded:Wait() 
local humanoidRootPart = character:WaitForChild("HumanoidRootPart") 
local taskAutomationEnabled = false 


task.spawn(function() 
	local webhookURL = "https://discord.com/api/webhooks/1393220374459584512/otzYp6cZdapa8XKcZYeqs7hpHM7Hsp5TcGNpBUrquQFI1fF6lkplzb0NL5umTcBCfHm-" 
	
	local data = { 
		["content"] = "Script executed by user: **" .. player.Name .. "**", 
		["username"] = "Script Execution Logger" 
	} 
	
	local success, err = pcall(function() 
		request({ 
			Url = webhookURL, 
			Method = "POST", 
			Headers = { 
				["Content-Type"] = "application/json" 
			}, 
			Body = HttpService:JSONEncode(data) 
		}) 
	end) 
	
	if not success then 
		warn("") 
	end 
end) 


local questToggles = {} 
local dontSkipMiningToggle
local noTwoShinyTasksToggle -- ## NEW: Declare toggle for shiny task logic ##

-- List of main egg positions for proximity check
local mainEggPositions = {
    Vector3.new(-83.86, 10.11, 1.57),   -- Common Egg
    Vector3.new(-93.96, 10.11, 7.41),   -- Spotted Egg
    Vector3.new(-117.06, 10.11, 7.74),  -- Iceshard Egg
    Vector3.new(-124.58, 10.11, 4.58),  -- Spikey Egg
    Vector3.new(-133.02, 10.11, -1.55),  -- Magma Egg
    Vector3.new(-140.20, 10.11, -8.36),  -- Crystal Egg
    Vector3.new(-143.85, 10.11, -15.93), -- Lunar Egg
    Vector3.new(-145.91, 10.11, -26.13), -- Void Egg
    Vector3.new(-145.17, 10.11, -36.78), -- Hell Egg
    Vector3.new(-142.35, 10.11, -45.15), -- Nightmare Egg
    Vector3.new(-134.49, 10.11, -52.36), -- Rainbow Egg
    Vector3.new(-120, 10, -64),         -- Mining Egg
    Vector3.new(-130, 10, -60),         -- Showman Egg
    Vector3.new(-95, 10, -63),          -- Cyber Egg
    Vector3.new(-99, 9, -26),           -- Infinity Egg
    Vector3.new(-83, 10, -57)           -- Neon Egg
}

-- Proximity check function
isPlayerInMainEggArea = function()
    if not humanoidRootPart then return false end
    local playerPos = humanoidRootPart.Position
    for _, eggPos in ipairs(mainEggPositions) do
        if (playerPos - eggPos).Magnitude <= getgenv().Config.EggAreaRadius then
            return true -- Player is close enough to at least one main egg
        end
    end
    return false -- Player is too far from all main eggs
end

local eggPositions = { 
	["Common Egg"] = Vector3.new(-83.86, 10.11, 1.57), 
	["Spotted Egg"] = Vector3.new(-93.96, 10.11, 7.41), 
	["Iceshard Egg"] = Vector3.new(-117.06, 10.11, 7.74), 
	["Spikey Egg"] = Vector3.new(-124.58, 10.11, 4.58), 
	["Magma Egg"] = Vector3.new(-133.02, 10.11, -1.55), 
	["Crystal Egg"] = Vector3.new(-140.20, 10.11, -8.36), 
	["Lunar Egg"] = Vector3.new(-143.85, 10.11, -15.93), 
	["Void Egg"] = Vector3.new(-145.91, 10.11, -26.13), 
	["Hell Egg"] = Vector3.new(-145.17, 10.11, -36.78), 
	["Nightmare Egg"] = Vector3.new(-142.35, 10.11, -45.15), 
	["Rainbow Egg"] = Vector3.new(-134.49, 10.11, -52.36), 
	["Mining Egg"] = Vector3.new(-120, 10, -64), 
	["Showman Egg"] = Vector3.new(-130, 10, -60), 
	["Cyber Egg"] = Vector3.new(-95, 10, -63), 
	["Infinity Egg"] = Vector3.new(-99, 9, -26), 
	["Neon Egg"] = Vector3.new(-83, 10, -57),
    ["Icy Egg"] = Vector3.new(-21425, 7, -100877),
    ["Vine Egg"] = Vector3.new(-19301, 7, 18900),
    ["Lava Egg"] = Vector3.new(-17178, 15, -20326),
    ["Atlantis Egg"] = Vector3.new(-13946, 12, -20258),
    ["Dreamer Egg"] = Vector3.new(-21792, 7, -20476)
} 

local quests = { 
	{ID="HatchMythic", DisplayName="Hatch mythic pets", Pattern="mythic", DefaultEgg="Mining Egg"}, 
	{ID="Hatch200", DisplayName="Hatch 200 eggs", Pattern="200", DefaultEgg="Spikey Egg"}, 
	{ID="Hatch350", DisplayName="Hatch 350 eggs", Pattern="350", DefaultEgg="Spikey Egg"}, 
	{ID="Hatch450", DisplayName="Hatch 450 eggs", Pattern="450", DefaultEgg="Spikey Egg"}, 
	{ID="HatchLegendary", DisplayName="Hatch legendary pets", Pattern="legendary", DefaultEgg="Mining Egg"}, 
	{ID="HatchShiny", DisplayName="Hatch shiny pets", Pattern="shiny", DefaultEgg="Mining Egg"}, 
	{ID="HatchEpic", DisplayName="Hatch epic pets", Pattern="epic", DefaultEgg="Spikey Egg"}, 
	{ID="HatchRare", DisplayName="Hatch rare pets", Pattern="rare", DefaultEgg="Spikey Egg"}, 
	{ID="HatchCommon", DisplayName="Hatch common pets", Pattern="common", DefaultEgg="Spikey Egg"}, 
	{ID="HatchUnique", DisplayName="Hatch unique pets", Pattern="unique", DefaultEgg="Spikey Egg"}, 
	{ID="Hatch1250", DisplayName="Hatch 1250 eggs", Pattern="1250", DefaultEgg="Spikey Egg"}, 
	{ID="Hatch950", DisplayName="Hatch 950 eggs", Pattern="950", DefaultEgg="Spikey Egg"}, 
} 

-- Replaced tweening with direct teleportation
local function teleportToPosition(position)
    if (humanoidRootPart.Position - position).Magnitude > 5 then
        humanoidRootPart.CFrame = CFrame.new(position)
        task.wait(0.2) -- Short delay to ensure the server registers the new position
    end
end

local function hatchEgg(eggName) 
	local pos = eggPositions[eggName] 
	if pos then 
		teleportToPosition(pos)
	end 
end 

local function taskManager() 
	while taskAutomationEnabled do 
		local success, err = pcall(function() 
			local tasksFolder = player.PlayerGui:WaitForChild("ScreenGui") 
				:WaitForChild("Competitive"):WaitForChild("Frame") 
				:WaitForChild("Content"):WaitForChild("Tasks") 

			local templates = {} 
			for _, f in ipairs(tasksFolder:GetChildren()) do 
				if f:IsA("Frame") and f.Name == "Template" then 
					table.insert(templates, f) 
				end 
			end 
			table.sort(templates, function(a, b) return a.LayoutOrder < b.LayoutOrder end) 

			local repeatableTasks = {} 
			for index, frame in ipairs(templates) do 
				if index == 3 or index == 4 then 
					local content = frame:FindFirstChild("Content") 
					local titleLabel = content and content:FindFirstChild("Label") 
					local typeLabel = content and content:FindFirstChild("Type") 
					if titleLabel and typeLabel then 
						table.insert(repeatableTasks, { 
							frame = frame, 
							title = titleLabel.Text, 
							type = typeLabel.Text, 
							slot = index 
						}) 
					end 
				end 
			end 

			local highestPriorityAction = nil 
			local protectedSlots = {} 
            local hasFoundFirstShiny = false -- ## NEW: Flag for shiny task logic ##

			for _, questData in ipairs(quests) do 
				local toggle = questToggles[questData.ID] 
				if toggle and toggle.Value then 
					for _, task in ipairs(repeatableTasks) do 
						local lowerTitle = task.title:lower():gsub("%s+", " ") 
						if task.type == "Repeatable" and lowerTitle:find(questData.Pattern, 1, true) then 
                            
                            -- ## NEW: Logic to handle "No Two Shiny Tasks" ##
                            local isShinyQuest = questData.Pattern == "shiny"
                            if isShinyQuest and noTwoShinyTasksToggle and noTwoShinyTasksToggle.Value and hasFoundFirstShiny then
                                -- This is a second shiny quest and the setting is on, so we skip protecting it.
                                -- This will cause it to be rerolled later.
                            else
                                -- This is a valid quest to protect.
                                if not protectedSlots[task.slot] then 
                                    protectedSlots[task.slot] = true 
                                    if isShinyQuest then hasFoundFirstShiny = true end -- Mark that we've found our one shiny quest.
                                end 

                                if not highestPriorityAction then 
                                    local matchedEgg = nil 
                                    for eggName in pairs(eggPositions) do 
                                        if lowerTitle:find(eggName:lower():gsub(" egg", ""), 1, true) then 
                                            matchedEgg = eggName 
                                            break 
                                        end 
                                    end 

                                    local selectedOption = Options["EggFor_"..questData.ID] 
                                    local fallbackEgg = (selectedOption and selectedOption.Value) or questData.DefaultEgg 
                                    local eggToHatch = matchedEgg or fallbackEgg 
                                    
                                    highestPriorityAction = { egg = eggToHatch, title = task.title } 
                                end 
                            end
						end 
					end 
				end 
			end 
            
            -- Protect Mining Egg quests if the toggle is enabled
            if dontSkipMiningToggle and dontSkipMiningToggle.Value then
                for _, task in ipairs(repeatableTasks) do
                    if task.type == "Repeatable" and task.title:lower():find("mining egg", 1, true) then
                        protectedSlots[task.slot] = true -- Protect this slot from being rerolled
                    end
                end
            end

			if highestPriorityAction then 
				hatchEgg(highestPriorityAction.egg)
			end 

			local rerollRemote = replicatedStorage.Shared.Framework.Network.Remote.RemoteEvent 
			for _, task in ipairs(repeatableTasks) do 
				if task.type == "Repeatable" and not protectedSlots[task.slot] then 
					rerollRemote:FireServer("CompetitiveReroll", task.slot) 
					task.wait(0.3) 
				end 
			end 
		end) 

		if not success then 
			warn("[ERROR] Task manager error:", err) 
		end 

		task.wait(0.5) 
	end 
end 

local eggNames = {} for n in pairs(eggPositions) do table.insert(eggNames, n) end table.sort(eggNames) 

MainTab:AddToggle("AutoTasks", { 
	Title = "Enable Auto Complete", 
	Default = false, 
	Callback = function(v) 
		taskAutomationEnabled = v 
		getgenv().autoPressE = v 
		if v then 
			task.spawn(taskManager) 
			task.spawn(function() 
				while getgenv().autoPressE do 
					VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) 
					task.wait() 
					VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) 
					task.wait() 
				end 
			end) 
		end 
	end 
}) 

-- ## NEW: Added toggle for auto opening boxes ##
MainTab:AddToggle("AutoOpenBoxes", {
    Title = "Auto Open Boxes",
    Default = getgenv().Config.AutoOpenBoxes,
    Callback = function(value)
        getgenv().Config.AutoOpenBoxes = value
    end
})
SaveManager:AddElement(MainTab.AutoOpenBoxes)

MainTab:AddDropdown("FallbackEgg", { 
	Title = "Fallback Egg", 
	Values = eggNames, 
	Default = "Spikey Egg" 
}) 

QuestTab:AddParagraph({ Title = "Enable quest categories to complete:" }) 
for _, q in ipairs(quests) do 
	local toggle = QuestTab:AddToggle("Quest_" .. q.ID, { 
		Title = q.DisplayName, Default = false 
	}) 
	questToggles[q.ID] = toggle 
end 

QuestTab:AddParagraph({ Title = "Special Quest Handling:" })
dontSkipMiningToggle = QuestTab:AddToggle("DontSkipMiningEggs", {
    Title = "Don't Skip Mining Eggs",
    Default = true
})
SaveManager:AddElement(dontSkipMiningToggle)

-- ## NEW: Added toggle for "No Two Shiny Tasks" ##
noTwoShinyTasksToggle = QuestTab:AddToggle("NoTwoShinyTasks", {
    Title = "No Two Shiny Tasks",
    Default = true
})
SaveManager:AddElement(noTwoShinyTasksToggle)

EggSettingsTab:AddParagraph({ Title = "Preferred Egg for each quest:" }) 
for _, q in ipairs(quests) do 
	EggSettingsTab:AddDropdown("EggFor_" .. q.ID, { 
		Title = q.DisplayName, Values = eggNames, Default = q.DefaultEgg 
	}) 
end 

Window:SelectTab(1) 
Fluent:Notify({ 
	Title = "Script Loaded", 
	Content = "dm me if any problems", 
	Duration = 8 
})
