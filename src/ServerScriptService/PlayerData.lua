local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()
local PlayerDataStore = nil
local dataStoreOk, dataStoreErr = pcall(function()
	PlayerDataStore = DataStoreService:GetDataStore("PlayerData_V3")
end)
local canUseDataStore = isStudio and dataStoreOk or not isStudio

local Profiles = {}

local DEFAULT_DATA = {
	Coins = 500,
	Inventory = {},
}

local PlayerData = {}

function PlayerData.LoadProfile(player)
	local data = nil
	if canUseDataStore and PlayerDataStore then
		local success, result = pcall(function()
			return PlayerDataStore:GetAsync("Player_" .. player.UserId)
		end)
		if success then
			data = result
		else
			warn("Failed to load data for " .. player.Name .. ": " .. tostring(result))
			-- In Studio, fall back to default data instead of kicking
			if not isStudio then
				player:Kick("Failed to load your data. Please rejoin.")
				return nil
			end
		end
	end

	-- Merge with defaults so new fields are always present
	local profile = {
		Data = data or table.clone(DEFAULT_DATA),
	}

	-- Deep-copy the inventory table so defaults aren't shared
	if data == nil then
		profile.Data.Inventory = {}
	end

	-- Reconcile: ensure any missing keys get default values
	for key, value in pairs(DEFAULT_DATA) do
		if profile.Data[key] == nil then
			profile.Data[key] = value
		end
	end

	Profiles[player] = profile

	-- Create leaderstats folder for the client UI
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = profile.Data.Coins
	coinsValue.Parent = leaderstats

	-- Fire the RemoteEvent to tell the client to populate the inventory UI
	local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
	if updateInventoryEvent then
		updateInventoryEvent:FireClient(player, profile.Data.Inventory)
	end

	return profile
end

function PlayerData.SaveProfile(player)
	local profile = Profiles[player]
	if profile then
		if canUseDataStore and PlayerDataStore then
			local success, err = pcall(function()
				PlayerDataStore:SetAsync("Player_" .. player.UserId, profile.Data)
			end)
			if not success then
				warn("Failed to save data for " .. player.Name .. ": " .. err)
			end
		end
		Profiles[player] = nil
	end
end

function PlayerData.GetProfile(player)
	return Profiles[player]
end

function PlayerData.AddCreatureToInventory(player, creatureInternalName)
	local profile = Profiles[player]
	if profile then
		if #profile.Data.Inventory < 81 then
			table.insert(profile.Data.Inventory, creatureInternalName)

			local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
			if updateInventoryEvent then
				updateInventoryEvent:FireClient(player, profile.Data.Inventory)
			end
			return true
		else
			warn(player.Name .. "'s inventory is full!")
			return false
		end
	end
	return false
end

function PlayerData.RemoveCreatureFromInventory(player, creatureInternalName)
	local profile = Profiles[player]
	if profile then
		for i, name in ipairs(profile.Data.Inventory) do
			if name == creatureInternalName then
				table.remove(profile.Data.Inventory, i)

				local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
				if updateInventoryEvent then
					updateInventoryEvent:FireClient(player, profile.Data.Inventory)
				end
				return true
			end
		end
	end
	return false
end

function PlayerData.AddCoins(player, amount)
	local profile = Profiles[player]
	if profile then
		profile.Data.Coins += amount
		local coinsValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
		if coinsValue then
			coinsValue.Value = profile.Data.Coins
		end
	end
end

function PlayerData.SpendCoins(player, amount)
	local profile = Profiles[player]
	if profile and profile.Data.Coins >= amount then
		profile.Data.Coins -= amount
		local coinsValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
		if coinsValue then
			coinsValue.Value = profile.Data.Coins
		end
		return true
	end
	return false
end

return PlayerData