-- Species entries define base income rate and display info only.
-- Rarity is NOT stored here — it is assigned per rot instance at roll time.
-- IncomeRate is the base value multiplied by the rarity multiplier at runtime.
-- Weight controls how likely this species is to appear (species pool, not rarity pool).
local CreatureDictionary = {
	["StrawberryElephant"] = {
		IncomeRate = 5,
		DisplayName = "Strawberry Elephant",
		ModelName = "Strawberrelli Flamingelli",
		Weight = 40,
	},
	["TungTungSahur"] = {
		IncomeRate = 15,
		DisplayName = "Tung Tung Sahur",
		ModelName = "TungTungSahur",
		Weight = 25,
	},
	["TralaleroTralala"] = {
		IncomeRate = 10,
		DisplayName = "Tralalero Tralala",
		ModelName = "Tralalero Tralala",
		Weight = 35,
	},
	["BombardiroCrocodilo"] = {
		IncomeRate = 25,
		DisplayName = "Bombardiro Crocodilo",
		ModelName = "Bombardiro Crocodilo",
		Weight = 20,
	},
	["BallerinaCappuccina"] = {
		IncomeRate = 40,
		DisplayName = "Ballerina Cappuccina",
		ModelName = "Ballerina Cappuccina",
		Weight = 10,
	},
	["CappuccinoAssassino"] = {
		IncomeRate = 60,
		DisplayName = "Cappuccino Assassino",
		ModelName = "Cappuccino Assassino",
		Weight = 3,
	},
	-- Add new species here. No Rarity field needed.
}

CreatureDictionary.RarityColors = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(100, 200, 120),
	Rare      = Color3.fromRGB(85,  170, 255),
	Epic      = Color3.fromRGB(170, 85,  255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythical  = Color3.fromRGB(255, 80,  140),
}

return CreatureDictionary