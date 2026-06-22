local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GliderConfig     = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local GameEvents       = require(script.Parent:WaitForChild("GameEvents"))
local gliderEquipEvent = ReplicatedStorage:WaitForChild("GliderEquipClient")

local activeGliders = {}   -- [player] = gliderName
local runStarts     = {}   -- [player] = Vector3 launch position

gliderEquipEvent.OnServerEvent:Connect(function(player, isEquipped, gliderName)
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildWhichIsA("Humanoid")
	local hrp      = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	if isEquipped and typeof(gliderName) == "string" then
		if not GliderConfig.Gliders[gliderName] then
			warn(("[GliderHandler] %s requested unknown glider '%s' — rejected")
				:format(player.Name, gliderName))
			return
		end

		humanoid.PlatformStand = true
		hrp:SetNetworkOwner(player)

		activeGliders[player] = gliderName
		runStarts[player]     = hrp.Position

		print(("[GliderHandler] %s → airborne on '%s' from %s")
			:format(player.Name, gliderName, tostring(hrp.Position)))

	else
		humanoid.PlatformStand = false
		hrp:SetNetworkOwnershipAuto()

		local startPos = runStarts[player]
		if startPos then
			local endPos = hrp.Position
			-- Horizontal distance only — vertical travel doesn't represent zone progression.
			local distance = Vector3.new(endPos.X - startPos.X, 0, endPos.Z - startPos.Z).Magnitude
			runStarts[player]     = nil
			activeGliders[player] = nil

			print(("[GliderHandler] %s → landed | distance: %.1f studs"):format(player.Name, distance))
			GameEvents.RunEnded:Fire(player, distance)
		else
			activeGliders[player] = nil
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	activeGliders[player] = nil
	runStarts[player]     = nil
end)
