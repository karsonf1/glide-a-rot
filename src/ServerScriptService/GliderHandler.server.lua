-- ============================================================
-- GliderHandler.server.lua  (ServerScriptService)
-- Server-side authoritative handler for glider equip events.
--
-- Responsibilities:
--   1. Validate that the requested glider exists in GliderConfig.
--   2. Set Humanoid.PlatformStand so the server agrees with the client state.
--   3. Transfer / revoke HumanoidRootPart network ownership so the client
--      can drive physics constraints without fighting server authority.
--
-- Listens to: ReplicatedStorage.GliderEquipClient (RemoteEvent)
-- Payload:    (player, isEquipped: boolean, gliderName: string | nil)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GliderConfig       = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local gliderEquipEvent   = ReplicatedStorage:WaitForChild("GliderEquipClient")

-- Track active sessions for cleanup on PlayerRemoving
local activeGliders = {}   -- [player] = gliderName or nil

gliderEquipEvent.OnServerEvent:Connect(function(player, isEquipped, gliderName)
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildWhichIsA("Humanoid")
	local hrp      = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	if isEquipped and typeof(gliderName) == "string" then
		-- Reject unknown glider names to prevent spoofed requests
		if not GliderConfig.Gliders[gliderName] then
			warn(("[GliderHandler] %s requested unknown glider '%s' — rejected")
				:format(player.Name, gliderName))
			return
		end

		humanoid.PlatformStand = true
		-- Give the client full ownership of HRP so LinearVelocity / AlignOrientation
		-- applied from the LocalScript don't lag or conflict with server simulation.
		hrp:SetNetworkOwner(player)

		activeGliders[player] = gliderName
		print(("[GliderHandler] %s → airborne on '%s'"):format(player.Name, gliderName))

	else
		-- Stow: restore normal physics authority
		humanoid.PlatformStand = false
		hrp:SetNetworkOwnershipAuto()

		activeGliders[player] = nil
		print(("[GliderHandler] %s → landed"):format(player.Name))
	end
end)

-- Clean up if the player leaves mid-flight
Players.PlayerRemoving:Connect(function(player)
	activeGliders[player] = nil
end)
