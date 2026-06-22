local platform = script.Parent
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Require the PlayerData module we made previously
local PlayerData = require(game.ServerScriptService.PlayerData)

local accumulatedMoney = 0
local debounce = false

-- 1. Passive Money Generation Loop
-- We use RunService.Heartbeat to get the precise elapsed time (deltaTime) every frame [2].
RunService.Heartbeat:Connect(function(deltaTime)
	-- Read the generation factor attribute that was passed to the platform
	local generationFactor = platform:GetAttribute("GenerationFactor") or 0

	-- If a creature is placed in this slot, it will have a factor > 0
	if generationFactor > 0 then
		-- Add money proportionally based on how much time has passed
		accumulatedMoney += (generationFactor * deltaTime)

		-- Optional: Update a TextLabel on the platform to show uncollected money
		local surfaceGui = platform:FindFirstChild("SurfaceGui")
		if surfaceGui and surfaceGui:FindFirstChild("TextLabel") then
			surfaceGui.TextLabel.Text = "$" .. math.floor(accumulatedMoney)
		end
	end
end)

-- 2. Collecting the Money (Jumping on the platform)
platform.Touched:Connect(function(hit)
	if debounce then return end

	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)

	-- Only allow collection if it's a player and there is at least 1 full coin to collect
	if player and accumulatedMoney >= 1 then
		debounce = true

		-- Round down the money to give them whole coins
		local coinsToGive = math.floor(accumulatedMoney)

		-- Reset the platform's internal storage, but DO NOT destroy the platform
		accumulatedMoney -= coinsToGive 

		-- Add coins using ProfileService safely [3]
		PlayerData.AddCoins(player, coinsToGive)

		-- Wait a short moment before they can trigger the collection again
		task.wait(0.5)
		debounce = false
	end
end)