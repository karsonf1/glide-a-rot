local CreatureDictionary = {
	["StrawberryElephant"] = {
		IncomeRate = 5,
		Rarity = "Common",
		DisplayName = "Strawberry Elephant",
		ModelName = "Strawberrelli Flamingelli",
		Weight = 40,
	},
	["TungTungSahur"] = {
		IncomeRate = 15,
		Rarity = "Rare",
		DisplayName = "Tung Tung Sahur",
		ModelName = "TungTungSahur",
		Weight = 25,
	},
	["TralaleroTralala"] = {
		IncomeRate = 10,
		Rarity = "Common",
		DisplayName = "Tralalero Tralala",
		ModelName = "Tralalero Tralala",
		Weight = 35,
	},
	["BombardiroCrocodilo"] = {
		IncomeRate = 25,
		Rarity = "Rare",
		DisplayName = "Bombardiro Crocodilo",
		ModelName = "Bombardiro Crocodilo",
		Weight = 20,
	},
	["BallerinaCappuccina"] = {
		IncomeRate = 40,
		Rarity = "Epic",
		DisplayName = "Ballerina Cappuccina",
		ModelName = "Ballerina Cappuccina",
		Weight = 10,
	},
	["CappuccinoAssassino"] = {
		IncomeRate = 60,
		Rarity = "Legendary",
		DisplayName = "Cappuccino Assassino",
		ModelName = "Cappuccino Assassino",
		Weight = 3,
	},
	-- You can easily copy, paste, and define new creatures here!
}

-- Rarity color definitions for UI
CreatureDictionary.RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(85, 170, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
}

return CreatureDictionary