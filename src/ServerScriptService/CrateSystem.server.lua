local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local CreatureDictionary = require(ReplicatedStorage:FindFirstChild("CreatureDictionary"))

local openCrateEvent    = ReplicatedStorage:FindFirstChild("OpenCrateClient")
local crateResultEvent  = ReplicatedStorage:FindFirstChild("CrateResultClient")
local crateRollDataEvent = ReplicatedStorage:FindFirstChild("CrateRollDataClient")

-- ============================================================
-- CONFIG
-- ============================================================
local CRATE_COST            = 100   -- Coins required to open one crate
local SEQUENCE_LENGTH       = 30    -- Number of items in the spin sequence sent to the client
local COIN_REWARD_MULTIPLIER = 1    -- Scale applied to a creature's IncomeRate for the coin payout
                                    -- e.g. set to 2 to double all creature rewards

-- ============================================================
-- Weighted pool helpers
-- ============================================================
local function getWeightedPool()
	local pool = {}
	for internalName, data in pairs(CreatureDictionary) do
		if type(data) == "table" and data.Weight then
			table.insert(pool, {
				InternalName = internalName,
				DisplayName  = data.DisplayName or internalName,
				Rarity       = data.Rarity or "Common",
				Weight       = data.Weight or 1,
				ModelName    = data.ModelName or internalName,
				IncomeRate   = data.IncomeRate or 1,
			})
		end
	end
	return pool
end

local function selectRandomCreature(pool)
	local totalWeight = 0
	for _, creature in ipairs(pool) do
		totalWeight += creature.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, creature in ipairs(pool) do
		cumulative += creature.Weight
		if roll <= cumulative then
			return creature
		end
	end
	return pool[#pool]
end

-- Generates the spin sequence and places the winner at a fixed near-end index.
-- Returns the sequence table and the 1-based winner index within it.
local function generateRollSequence(pool, winner, length)
	length = length or SEQUENCE_LENGTH
	local sequence = {}

	for _ = 1, length do
		local creature = selectRandomCreature(pool)
		table.insert(sequence, {
			InternalName = creature.InternalName,
			DisplayName  = creature.DisplayName,
			Rarity       = creature.Rarity,
			ModelName    = creature.ModelName,
		})
	end

	-- Place the winner near the end so the carousel has room to build suspense
	local winnerIndex = length - 3
	sequence[winnerIndex] = {
		InternalName = winner.InternalName,
		DisplayName  = winner.DisplayName,
		Rarity       = winner.Rarity,
		ModelName    = winner.ModelName,
	}

	return sequence, winnerIndex
end

-- ============================================================
-- Per-creature coin reward
-- ============================================================

-- Returns the coin payout for a specific winner based strictly on its IncomeRate.
-- All scalar tuning is done via COIN_REWARD_MULTIPLIER above.
local function computeCoinReward(winnerInternalName)
	local data = CreatureDictionary[winnerInternalName]
	local incomeRate = (data and data.IncomeRate) or 1
	return math.max(1, math.floor(incomeRate * COIN_REWARD_MULTIPLIER))
end

-- ============================================================
-- Crate opening handler
-- ============================================================
if openCrateEvent then
	openCrateEvent.OnServerEvent:Connect(function(player)
		local profile = PlayerData.GetProfile(player)
		if not profile then return end

		if profile.Data.Coins < CRATE_COST then
			if crateResultEvent then
				crateResultEvent:FireClient(player, "Failed",
					"Not enough coins! Need " .. CRATE_COST .. " coins.")
			end
			return
		end

		local success = PlayerData.SpendCoins(player, CRATE_COST)
		if not success then
			if crateResultEvent then
				crateResultEvent:FireClient(player, "Failed", "Could not spend coins.")
			end
			return
		end

		local pool    = getWeightedPool()
		local winner  = selectRandomCreature(pool)
		local sequence, winnerIndex = generateRollSequence(pool, winner)

		-- Coin reward is computed per-creature from its IncomeRate, not a flat value.
		local coinReward = computeCoinReward(winner.InternalName)
		PlayerData.AddCoins(player, coinReward)

		-- Send roll data (including the reward) so the client can animate and display
		if crateRollDataEvent then
			crateRollDataEvent:FireClient(
				player,
				sequence,
				winnerIndex,
				winner.InternalName,
				winner.Rarity,
				coinReward
			)
		end

		-- Add the creature to the player's inventory
		PlayerData.AddCreatureToInventory(player, winner.InternalName)

		-- Create a holdable tool prefab for this creature if one doesn't exist yet
		local holdableFolder = ReplicatedStorage:FindFirstChild("HoldableCreatures")
		if holdableFolder and not holdableFolder:FindFirstChild(winner.InternalName) then
			local creatureModel = ReplicatedStorage.CreatureModels:FindFirstChild(winner.ModelName)
			if creatureModel then
				local newTool = Instance.new("Tool")
				newTool.Name = winner.InternalName

				local modelClone = creatureModel:Clone()
				local handle = nil

				for _, child in ipairs(modelClone:GetChildren()) do
					if child.Name == "RootPart" then
						child.Name = "Handle"
						child.Anchored = false
						child.CanCollide = false
						child.Massless = true
						handle = child
					end
					child.Parent = newTool
				end

				if handle then
					for _, child in ipairs(newTool:GetChildren()) do
						if child:IsA("BasePart") and child ~= handle then
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = handle
							weld.Part1 = child
							weld.Parent = child
						end
					end
				end

				local strips = {"AnimationController", "VfxInstance", "FakeRootPart"}
				for _, name in ipairs(strips) do
					local c = newTool:FindFirstChild(name)
					if c then c:Destroy() end
				end

				for _, child in ipairs(newTool:GetChildren()) do
					if child:IsA("BasePart") then
						child.Massless = true
						child.CanCollide = false
					end
				end

				local creatureData = CreatureDictionary[winner.InternalName]
				if creatureData then
					newTool:SetAttribute("IncomeRate", creatureData.IncomeRate)
				end

				newTool.Parent = holdableFolder
			end
		end

		-- Confirm success after the client animation finishes (~5 s)
		task.delay(5, function()
			if crateResultEvent then
				crateResultEvent:FireClient(
					player,
					"Success",
					winner.DisplayName,
					winner.Rarity,
					coinReward
				)
			end
		end)
	end)
end
