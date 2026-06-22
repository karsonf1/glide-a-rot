local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)

local equipCreatureEvent = ReplicatedStorage:FindFirstChild("EquipCreatureClient")
local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")

-- Handle a player joining
local function onPlayerAdded(player)
	PlayerData.LoadProfile(player)
end

-- Handle a player leaving
local function onPlayerRemoving(player)
	PlayerData.SaveProfile(player)
end

-- Handle client requesting to equip a creature from their inventory
if equipCreatureEvent then
	equipCreatureEvent.OnServerEvent:Connect(function(player, creatureName)
		if typeof(creatureName) ~= "string" then return end

		local profile = PlayerData.GetProfile(player)
		if not profile then return end

		-- Verify the player actually owns this creature
		local ownsCreature = false
		for _, name in ipairs(profile.Data.Inventory) do
			if name == creatureName then
				ownsCreature = true
				break
			end
		end
		if not ownsCreature then return end

		-- Check if they already have this tool equipped
		local character = player.Character
		if character and character:FindFirstChild(creatureName) then return end
		local backpack = player:FindFirstChild("Backpack")
		if backpack and backpack:FindFirstChild(creatureName) then return end

		-- Find the tool prefab and clone it to their Backpack
		local toolPrefab = ReplicatedStorage.HoldableCreatures:FindFirstChild(creatureName)
		if toolPrefab then
			local newTool = toolPrefab:Clone()
			newTool.Parent = player:FindFirstChild("Backpack")
		end
	end)
end

-- Handle a player unequipping/placing a creature (tool removed from character)
-- When the Stand script destroys the tool, we don't need to do anything extra
-- since the inventory data is managed separately from the physical tool

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in the game
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end