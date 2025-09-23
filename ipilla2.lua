-- Standalone Intelligent Auto-Dice Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoBoardGame = true,
    TILES_TO_TARGET = {
        ["infinity"] = true,
    },
    DICE_TYPE = "Giant Dice", -- Can be "Dice", "Golden Dice", or "Giant Dice"
    GOLDEN_DICE_DISTANCE = 6,
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- Services and Core References
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local BoardUtil = require(ReplicatedStorage.Shared.Utils.BoardUtil)

-- Direct references to the Remote instances
local RemoteFunction = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

-- Helper function to perform one full, verified turn
local function takeTurn(diceType)
    print("Rolling with: " .. diceType)
    
    local success, rollResponse = pcall(function()
        local args = {
            "RollDice",
            diceType
        }
        return RemoteFunction:InvokeServer(unpack(args))
    end)

    if success and rollResponse then
        print("  > Success! Rolled a:", rollResponse.Roll, ". Expected destination: Tile", rollResponse.Tile.Index)
        
        local expectedTile = rollResponse.Tile.Index
        local moveCompleted = false
        local timeout = 5
        local startTime = tick()

        while tick() - startTime < timeout do
            task.wait(0.1)
            local currentTile = LocalPlayer:GetAttribute("BoardIndex")
            if currentTile == expectedTile then
                print("  > Landing confirmed at Tile " .. currentTile)
                moveCompleted = true
                break
            end
        end

        if moveCompleted then
            print("  > Claiming tile reward...")
            local claimArgs = {
                "ClaimTile"
            }
            RemoteEvent:FireServer(unpack(claimArgs))
            task.wait(1.5)
            return rollResponse -- Return the full response on success
        else
            print("  > Landing FAILED. Timed out waiting for BoardIndex to update.")
            return nil -- Return nil on failure
        end
    else
        print("  > Roll failed or was rejected. Retrying...")
        task.wait(2.0)
        return nil
    end
end

print("Intelligent Auto-Dice script started. To stop, run: getgenv().Config.AutoBoardGame = false")

while getgenv().Config.AutoBoardGame do
    local currentTileNumber = LocalPlayer:GetAttribute("BoardIndex")
    if not currentTileNumber then
        print("Waiting for player to be on the board...")
        task.wait(2)
        continue
    end

    local totalTiles = #BoardUtil.Nodes
    local actionTaken = false
    local turnResponse = nil -- Variable to hold the result of a turn

    print("---")
    print("Current Tile: " .. currentTileNumber)
    
    -- 1. Golden Dice Snipe Logic
    print("Scanning for Golden Dice targets (Range: " .. Config.GOLDEN_DICE_DISTANCE .. " tiles)...")
    for i = 1, Config.GOLDEN_DICE_DISTANCE do
        local nextTileIndex = currentTileNumber + i
        if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end
        
        local tileInfo = BoardUtil.Nodes[nextTileIndex]
        if tileInfo and Config.TILES_TO_TARGET[tileInfo.Type] then
            print("Target '" .. tileInfo.Type .. "' found " .. i .. " tiles away! Using Golden Dice...")
            for j = 1, i do
                turnResponse = takeTurn("Golden Dice") 
            end
            actionTaken = true
            break
        end
    end

    -- 2. Primary Dice Chance Logic
    if not actionTaken then
        local maxRoll = (Config.DICE_TYPE == "Dice" and 6 or 10) -- Assumes Giant Dice is 10
        print("Scanning for targets for a chance roll (Range: " .. maxRoll .. " tiles)...")
        for i = 1, maxRoll do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end

            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo and Config.TILES_TO_TARGET[tileInfo.Type] then
                print("Target '" .. tileInfo.Type .. "' found in range! Using " .. Config.DICE_TYPE .. " for a chance...")
                turnResponse = takeTurn(Config.DICE_TYPE)
                actionTaken = true
                break
            end
        end
    end
    
    -- 3. Default Action (No targets in range)
    if not actionTaken then
        print("No targets found in range. Performing default roll with " .. Config.DICE_TYPE .. "...")
        turnResponse = takeTurn(Config.DICE_TYPE)
    end
    
    -- There is no longer a delay here after the turn is completed.
end

print("Intelligent Auto-Dice script has stopped.")
