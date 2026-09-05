-- ============================================================
-- HoldHandler.server.lua  (ServerScriptService — Script)
-- Owns the "hold a rot in my hand" action — split out from the old
-- EquipCreatureClient path, which was doing double duty (hotbar slot AND hold)
-- and silently no-oping against the object inventory.
--
-- Flow:
--   Client fires HoldCreatureClient:FireServer(species)
--   -> pick the player's best instance of that species (server resolves Uid)
--   -> ensure the Species_Rarity tool prefab exists (even for rots rolled in a
--      past session, via HoldableToolFactory)
--   -> clone it, tag the clone with the exact Uid + Income, put it in the hand
--
-- The rot stays in Inventory while held; only PLACING (the stand) moves it out.
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData          = require(script.Parent.PlayerData)
local HoldableToolFactory = require(ReplicatedStorage:WaitForChild("HoldableToolFactory"))

-- Provision the RemoteEvent up front so the client's WaitForChild resolves.
local holdEvent = ReplicatedStorage:FindFirstChild("HoldCreatureClient")
if not holdEvent then
	holdEvent = Instance.new("RemoteEvent")
	holdEvent.Name = "HoldCreatureClient"
	holdEvent.Parent = ReplicatedStorage
end

-- Remove any creature tool the player is currently holding/carrying, so holding
-- is single-item and switching is clean. Creature tools are tagged with a Uid.
local function clearHeldCreatures(player)
	local function sweep(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("Uid") then
				item:Destroy()
			end
		end
	end
	sweep(player.Character)
	sweep(player:FindFirstChild("Backpack"))
end

holdEvent.OnServerEvent:Connect(function(player, species)
	if typeof(species) ~= "string" or #species == 0 then return end

	local rot = PlayerData.FindRotBySpecies(player, species)
	if not rot then
		-- Player asked to hold something they don't own — reject quietly.
		return
	end

	local prefab = HoldableToolFactory.Ensure(rot.Species, rot.Rarity)
	if not prefab then return end

	clearHeldCreatures(player)

	local tool = prefab:Clone()
	-- Stamp the exact instance so the stand can move THIS rot out of inventory.
	tool:SetAttribute("Uid", rot.Uid)
	tool:SetAttribute("Income", rot.Income)
	tool:SetAttribute("Species", rot.Species)
	tool:SetAttribute("Rarity", rot.Rarity)

	local character = player.Character
	if character and character:FindFirstChildOfClass("Humanoid") then
		tool.Parent = character            -- parenting to the character equips it (renders in hand)
	else
		tool.Parent = player:FindFirstChild("Backpack")
	end
end)

print("[HoldHandler] Ready (HoldCreatureClient provisioned)")
