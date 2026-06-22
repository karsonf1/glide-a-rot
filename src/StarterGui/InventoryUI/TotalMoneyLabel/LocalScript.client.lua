local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local moneyLabel = script.Parent

-- Wait for the server to load the ProfileService data and create the leaderstats folder
local leaderstats = localPlayer:WaitForChild("leaderstats")
local coinsValue = leaderstats:WaitForChild("Coins")

-- 1. Set the text immediately when the UI loads
moneyLabel.Text = "Total Coins: $" .. coinsValue.Value

-- 2. Listen for any changes to the money value
coinsValue.Changed:Connect(function(newValue)
	-- This fires instantly whenever PlayerData.AddCoins or SpendCoins runs on the server
	moneyLabel.Text = "Total Coins: $" .. newValue
end)