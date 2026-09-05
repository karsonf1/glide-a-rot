local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

-- Handle a player joining
local function onPlayerAdded(player)
	PlayerData.LoadProfile(player)
end

-- Handle a player leaving
local function onPlayerRemoving(player)
	PlayerData.SaveProfile(player)
end

-- NOTE: The old EquipCreatureClient listener that lived here (cloning a hold-tool
-- into the Backpack) has been removed. It collided with EquipmentHandler on the
-- same event AND compared inventory OBJECTS to name strings, so it never actually
-- fired. Holding is now owned by HoldHandler.server.lua (HoldCreatureClient);
-- hotbar-slot assignment stays with EquipmentHandler (EquipCreatureClient).

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in the game
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end