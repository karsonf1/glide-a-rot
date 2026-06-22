-- ============================================================
-- EquipmentHandler.server.lua
-- Validates hotbar equip requests from the client and persists
-- the equipped state via PlayerData.
--
-- Listens to: ReplicatedStorage.EquipCreatureClient (RemoteEvent)
-- Payload:    (player, internalName: string, slotIndex: number 1–9)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

local equipCreatureEvent = ReplicatedStorage:WaitForChild("EquipCreatureClient")

local MAX_SLOT = 9

equipCreatureEvent.OnServerEvent:Connect(function(player, internalName, slotIndex)
	-- Type and range guards — reject anything malformed before touching data
	if typeof(internalName) ~= "string" or #internalName == 0 then return end
	if typeof(slotIndex)    ~= "number"
	or slotIndex < 1
	or slotIndex > MAX_SLOT
	or slotIndex ~= math.floor(slotIndex) then return end

	local profile = PlayerData.GetProfile(player)
	if not profile then return end

	-- Verify the creature is actually in the player's server-authoritative inventory
	local inventory = profile.Data.Inventory or {}
	local owned = false
	for _, name in ipairs(inventory) do
		if name == internalName then
			owned = true
			break
		end
	end

	if not owned then
		warn(("[EquipmentHandler] %s tried to equip unowned creature '%s' — rejected")
			:format(player.Name, internalName))
		return
	end

	-- Persist equipped hotbar as a string-keyed dict (DataStore safe)
	if not profile.Data.EquippedHotbar then
		profile.Data.EquippedHotbar = {}
	end
	profile.Data.EquippedHotbar[tostring(slotIndex)] = internalName

	print(("[EquipmentHandler] %s equipped '%s' → slot %d")
		:format(player.Name, internalName, slotIndex))
end)
