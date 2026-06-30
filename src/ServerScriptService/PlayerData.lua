local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()
local PlayerDataStore = nil
local dataStoreOk, dataStoreErr = pcall(function()
	PlayerDataStore = DataStoreService:GetDataStore("PlayerData_V4")
end)
local canUseDataStore = isStudio and dataStoreOk or not isStudio

local Profiles = {}

local DEFAULT_DATA = {
	Coins = 500,
	Inventory = {},
	Poofs = 0,
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

	-- Migrate any V3 string entries to the V4 rot format.
	for i, entry in ipairs(profile.Data.Inventory) do
		if type(entry) == "string" then
			profile.Data.Inventory[i] = { Species = entry, Rarity = "Common", Income = 1 }
		end
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

-- rot: { Species: string, Rarity: string, Income: number }
function PlayerData.AddRotToInventory(player, rot)
	local profile = Profiles[player]
	if not profile then return false end

	if #profile.Data.Inventory >= 81 then
		warn(player.Name .. "'s inventory is full!")
		return false
	end

	table.insert(profile.Data.Inventory, rot)

	local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
	if updateInventoryEvent then
		updateInventoryEvent:FireClient(player, profile.Data.Inventory)
	end
	return true
end

-- Removes a rot at a specific inventory index (1-based).
function PlayerData.RemoveRotFromInventory(player, index)
	local profile = Profiles[player]
	if not profile then return false end

	if not profile.Data.Inventory[index] then return false end

	table.remove(profile.Data.Inventory, index)

	local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
	if updateInventoryEvent then
		updateInventoryEvent:FireClient(player, profile.Data.Inventory)
	end
	return true
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

function PlayerData.GetPoofs(player)
	local profile = Profiles[player]
	if not profile then return 0 end
	return profile.Data.Poofs or 0
end

function PlayerData.AwardPoofs(player, amount)
	local profile = Profiles[player]
	if not profile then return end

	profile.Data.Poofs = (profile.Data.Poofs or 0) + amount
	local total = profile.Data.Poofs

	print(("[PlayerData] AwardPoofs → %s +%d Poofs (total: %d)"):format(player.Name, amount, total))

	if canUseDataStore and PlayerDataStore then
		local success, err = pcall(function()
			PlayerDataStore:SetAsync("Player_" .. player.UserId, profile.Data)
		end)
		if success then
			print(("[PlayerData] Saved profile for %s after Poofs award"):format(player.Name))
		else
			warn(("[PlayerData] Failed to save Poofs for %s: %s"):format(player.Name, tostring(err)))
		end
	end

	local poofUpdateEvent = ReplicatedStorage:FindFirstChild("PoofUpdate")
	if poofUpdateEvent then
		poofUpdateEvent:FireClient(player, total)
		print(("[PlayerData] PoofUpdate fired to %s with total %d"):format(player.Name, total))
	else
		warn("[PlayerData] PoofUpdate RemoteEvent not found in ReplicatedStorage")
	end
end

return PlayerData