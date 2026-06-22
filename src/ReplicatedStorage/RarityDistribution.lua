local RarityDistribution = {}

-- Tune this to the furthest reachable point on your map in studs.
local MAX_DISTANCE = 5000

-- Each tier has a center (0–1 fraction of MAX_DISTANCE), a spread that controls
-- how wide the bell is, and the multiplier applied to a species' base income rate.
local TIERS = {
	{ name = "Common",    center = 0.00, spread = 0.28, multiplier = 2    },
	{ name = "Uncommon",  center = 0.18, spread = 0.22, multiplier = 5    },
	{ name = "Rare",      center = 0.38, spread = 0.20, multiplier = 25   },
	{ name = "Epic",      center = 0.58, spread = 0.18, multiplier = 100  },
	{ name = "Legendary", center = 0.78, spread = 0.16, multiplier = 500  },
	{ name = "Mythical",  center = 1.00, spread = 0.18, multiplier = 1000 },
}

local function gaussian(t, center, spread)
	local diff = t - center
	return math.exp(-(diff * diff) / (2 * spread * spread))
end

-- Returns normalized weights for each tier at a given distance.
-- Each entry: { name: string, weight: number (0–1), multiplier: number }
function RarityDistribution.GetWeights(distance)
	local t = math.clamp(distance / MAX_DISTANCE, 0, 1)

	local weights = {}
	local total = 0

	for _, tier in ipairs(TIERS) do
		local w = gaussian(t, tier.center, tier.spread)
		table.insert(weights, { name = tier.name, weight = w, multiplier = tier.multiplier })
		total += w
	end

	for _, entry in ipairs(weights) do
		entry.weight = entry.weight / total
	end

	return weights
end

-- Rolls one rarity at a given distance. Returns { name: string, multiplier: number }
function RarityDistribution.Roll(distance)
	local weights = RarityDistribution.GetWeights(distance)
	local roll = math.random()
	local cumulative = 0

	for _, entry in ipairs(weights) do
		cumulative += entry.weight
		if roll <= cumulative then
			return { name = entry.name, multiplier = entry.multiplier }
		end
	end

	local last = weights[#weights]
	return { name = last.name, multiplier = last.multiplier }
end

-- Looks up the income multiplier for a rarity name. Useful for existing rot instances.
function RarityDistribution.GetMultiplier(rarityName)
	for _, tier in ipairs(TIERS) do
		if tier.name == rarityName then
			return tier.multiplier
		end
	end
	return 1
end

return RarityDistribution
