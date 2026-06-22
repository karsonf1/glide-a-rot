local stand = script.Parent
local prompt = stand:FindFirstChild("ProximityPrompt")
local prefabFolder = stand.Parent
local collectionPlatform = prefabFolder:WaitForChild("CollectionPlatform")
local placementNode = prefabFolder:WaitForChild("PlacementNode")

local PlayerData = require(game.ServerScriptService.PlayerData)

prompt.Triggered:Connect(function(player)
	local character = player.Character
	if not character then return end

	-- 1. Check if the player is actively holding a Tool in their hands
	local heldItem = character:FindFirstChildOfClass("Tool")

	-- 2. Verify the held item is actually a creature by checking for our attribute
	if heldItem and heldItem:GetAttribute("IncomeRate") then
		local incomeRate = heldItem:GetAttribute("IncomeRate")
		local creatureName = heldItem.Name

		-- 3. Clone the creature's physical model (the Handle) to place it on the stand
		local placedCreature = heldItem.Handle:Clone()
		placedCreature.Name = creatureName
		placedCreature.Anchored = true
		placedCreature.CanCollide = false

		-- Move the cloned model to the exact CFrame of our invisible PlacementNode
		placedCreature.CFrame = placementNode.CFrame
		placedCreature.Parent = prefabFolder -- Store it visually inside the prefab

		-- 4. Pass the creature's generation value to the platform to start the passive income loop
		collectionPlatform:SetAttribute("GenerationFactor", incomeRate)

		-- 5. Remove the creature from the player's inventory data and destroy the tool
		PlayerData.RemoveCreatureFromInventory(player, creatureName)
		heldItem:Destroy()

		-- 6. Disable the prompt so nobody else can place a creature here
		prompt.Enabled = false
		prompt.ActionText = "Slot Occupied"
	end
end)