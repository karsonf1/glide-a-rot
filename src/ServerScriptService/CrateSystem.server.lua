local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData          = require(script.Parent.PlayerData)
local CreatureDictionary  = require(ReplicatedStorage:WaitForChild("CreatureDictionary"))
local RarityDistribution  = require(ReplicatedStorage:WaitForChild("RarityDistribution"))
local GameEvents          = require(script.Parent:WaitForChild("GameEvents"))

local crateResultEvent   = ReplicatedStorage:FindFirstChild("CrateResultClient")
local crateRollDataEvent = ReplicatedStorage:FindFirstChild("CrateRollDataClient")

local SEQUENCE_LENGTH = 30

-- Rarities used to fill the fake spin entries before the winner slot.
-- Weighted toward lower tiers so the real winner feels earned.
local FAKE_RARITY_POOL = {
	"Common", "Common", "Common",
	"Uncommon", "Uncommon",
	"Rare",
}

-- ============================================================
-- Species pool
-- ============================================================
local function buildSpeciesPool()
	local pool = {}
	for internalName, data in pairs(CreatureDictionary) do
		if type(data) == "table" and data.Weight then
			table.insert(pool, {
				InternalName = internalName,
				DisplayName  = data.DisplayName or internalName,
				ModelName    = data.ModelName or internalName,
				Weight       = data.Weight,
				IncomeRate   = data.IncomeRate or 1,
			})
		end
	end
	return pool
end

local function rollSpecies(pool)
	local total = 0
	for _, s in ipairs(pool) do total += s.Weight end
	local roll = math.random() * total
	local cumulative = 0
	for _, s in ipairs(pool) do
		cumulative += s.Weight
		if roll <= cumulative then return s end
	end
	return pool[#pool]
end

-- ============================================================
-- Spin sequence
-- ============================================================
local function buildSequence(pool, winner, winnerRarity)
	local sequence = {}
	for _ = 1, SEQUENCE_LENGTH do
		local species = rollSpecies(pool)
		local fakeRarity = FAKE_RARITY_POOL[math.random(1, #FAKE_RARITY_POOL)]
		table.insert(sequence, {
			InternalName = species.InternalName,
			DisplayName  = species.DisplayName,
			Rarity       = fakeRarity,
			ModelName    = species.ModelName,
		})
	end

	-- Place winner near the end so the carousel has room to build suspense.
	local winnerIndex = SEQUENCE_LENGTH - 3
	sequence[winnerIndex] = {
		InternalName = winner.InternalName,
		DisplayName  = winner.DisplayName,
		Rarity       = winnerRarity,
		ModelName    = winner.ModelName,
	}

	return sequence, winnerIndex
end

-- ============================================================
-- Holdable tool creation (visual equip in hotbar/world)
-- ============================================================
local function ensureHoldableTool(species, rarityName)
	local holdableFolder = ReplicatedStorage:FindFirstChild("HoldableCreatures")
	if not holdableFolder then return end

	local toolName = species.InternalName .. "_" .. rarityName
	if holdableFolder:FindFirstChild(toolName) then return end

	local creatureModel = ReplicatedStorage.CreatureModels:FindFirstChild(species.ModelName)
	if not creatureModel then return end

	local newTool = Instance.new("Tool")
	newTool.Name = toolName
	newTool:SetAttribute("Species", species.InternalName)
	newTool:SetAttribute("Rarity",  rarityName)

	local modelClone = creatureModel:Clone()
	local handle

	for _, child in ipairs(modelClone:GetChildren()) do
		if child.Name == "RootPart" then
			child.Name      = "Handle"
			child.Anchored  = false
			child.CanCollide = false
			child.Massless  = true
			handle = child
		end
		child.Parent = newTool
	end

	if handle then
		for _, child in ipairs(newTool:GetChildren()) do
			if child:IsA("BasePart") and child ~= handle then
				local weld  = Instance.new("WeldConstraint")
				weld.Part0  = handle
				weld.Part1  = child
				weld.Parent = child
			end
		end
	end

	local strips = { "AnimationController", "VfxInstance", "FakeRootPart" }
	for _, name in ipairs(strips) do
		local c = newTool:FindFirstChild(name)
		if c then c:Destroy() end
	end

	for _, child in ipairs(newTool:GetChildren()) do
		if child:IsA("BasePart") then
			child.Massless   = true
			child.CanCollide = false
		end
	end

	newTool.Parent = holdableFolder
end

-- ============================================================
-- Run-end handler — one rot awarded per completed flight
-- ============================================================
GameEvents.RunEnded.Event:Connect(function(player, distance)
	local profile = PlayerData.GetProfile(player)
	if not profile then return end

	local pool       = buildSpeciesPool()
	local species    = rollSpecies(pool)
	local rarityRoll = RarityDistribution.Roll(distance)

	-- Income stored on the rot at roll time so the slot system can read it directly.
	local income = math.max(1, math.floor(species.IncomeRate * rarityRoll.multiplier))

	local sequence, winnerIndex = buildSequence(pool, species, rarityRoll.name)

	if crateRollDataEvent then
		crateRollDataEvent:FireClient(
			player,
			sequence,
			winnerIndex,
			species.InternalName,
			rarityRoll.name,
			income
		)
	end

	PlayerData.AddRotToInventory(player, {
		Species = species.InternalName,
		Rarity  = rarityRoll.name,
		Income  = income,
	})

	ensureHoldableTool(species, rarityRoll.name)

	task.delay(5, function()
		if crateResultEvent then
			crateResultEvent:FireClient(
				player,
				"Success",
				species.DisplayName,
				rarityRoll.name,
				income
			)
		end
	end)

	print(("[CrateSystem] %s rolled %s %s | income: %d/s | distance: %.1f")
		:format(player.Name, rarityRoll.name, species.DisplayName, income, distance))
end)
