local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

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

	-- Migrate any V3 string entries to the V4 rot format, and back-fill a stable
	-- Uid on every rot. The Uid is how the hold-tool and the stands reference one
	-- exact instance across inventory -> hand -> stand (two same-species rots are
	-- otherwise byte-identical). Existing saves get Uids assigned on first load.
	for i, entry in ipairs(profile.Data.Inventory) do
		if type(entry) == "string" then
			profile.Data.Inventory[i] = { Species = entry, Rarity = "Common", Income = 1 }
		end
		local rot = profile.Data.Inventory[i]
		if type(rot) == "table" and not rot.Uid then
			rot.Uid = HttpService:GenerateGUID(false)
		end
	end

	-- Reconcile: ensure any missing keys get default values
	for key, value in pairs(DEFAULT_DATA) do
		if profile.Data[key] == nil then
			profile.Data[key] = value
		end
	end

	-- PlacedRots maps a stand's StandId -> { Rot = <rot>, OwnerUserId = n }.
	-- Kept OUT of DEFAULT_DATA so every profile gets its own fresh table rather
	-- than a shared reference (same reason Inventory is handled explicitly above).
	if type(profile.Data.PlacedRots) ~= "table" then
		profile.Data.PlacedRots = {}
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

-- ============================================================
-- Rot lookup + hold/place API (UID-based)
-- ============================================================
local function fireInventoryUpdate(player, profile)
	local ev = ReplicatedStorage:FindFirstChild("UpdateInventoryClient")
	if ev then ev:FireClient(player, profile.Data.Inventory) end
end

-- Find any owned rot of a species, preferring the highest-Income (best rarity)
-- instance. Used to decide which instance a "hold this species" request grabs.
-- Returns rot, index (or nil).
function PlayerData.FindRotBySpecies(player, species)
	local profile = Profiles[player]
	if not profile then return nil end
	local best, bestIdx
	for i, rot in ipairs(profile.Data.Inventory) do
		if type(rot) == "table" and rot.Species == species then
			if not best or (rot.Income or 0) > (best.Income or 0) then
				best, bestIdx = rot, i
			end
		end
	end
	return best, bestIdx
end

-- Find one exact rot instance by Uid. Returns rot, index (or nil).
function PlayerData.FindRotByUid(player, uid)
	local profile = Profiles[player]
	if not profile then return nil end
	for i, rot in ipairs(profile.Data.Inventory) do
		if type(rot) == "table" and rot.Uid == uid then
			return rot, i
		end
	end
	return nil
end

-- Move a rot out of Inventory onto a stand (persisted under standId).
-- Returns the moved rot, or nil if it wasn't owned.
function PlayerData.PlaceRot(player, standId, uid)
	local profile = Profiles[player]
	if not profile then return nil end
	local rot, index = PlayerData.FindRotByUid(player, uid)
	if not rot then return nil end

	table.remove(profile.Data.Inventory, index)
	profile.Data.PlacedRots[standId] = { Rot = rot, OwnerUserId = player.UserId }
	fireInventoryUpdate(player, profile)
	return rot
end

-- Return a placed rot from a stand back into Inventory (respects the 81 cap).
-- Returns the reclaimed rot, or nil (not placed / inventory full).
function PlayerData.ReclaimRot(player, standId)
	local profile = Profiles[player]
	if not profile then return nil end
	local placed = profile.Data.PlacedRots[standId]
	if not placed then return nil end
	if #profile.Data.Inventory >= 81 then
		warn(("[PlayerData] %s inventory full — cannot reclaim from %s"):format(player.Name, standId))
		return nil
	end

	profile.Data.PlacedRots[standId] = nil
	table.insert(profile.Data.Inventory, placed.Rot)
	fireInventoryUpdate(player, profile)
	return placed.Rot
end

-- Read-only view of a player's placed rots (used by the stand restore on join).
function PlayerData.GetPlacedRots(player)
	local profile = Profiles[player]
	if not profile then return {} end
	return profile.Data.PlacedRots or {}
end

return PlayerData