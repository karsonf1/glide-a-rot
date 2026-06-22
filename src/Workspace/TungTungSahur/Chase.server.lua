local NPC = script.Parent
local HumanoidRootPart = NPC:WaitForChild("HumanoidRootPart")
local Humanoid = NPC:WaitForChild("Humanoid")
local MaxDistance = math.huge
local debounce = false

-- Handle touch damage with debounce
Humanoid.Touched:Connect(function(hit)
	local hitHumanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if hitHumanoid and not debounce then
		debounce = true
		hitHumanoid:TakeDamage(20)
		task.wait(1)  -- More precise wait
		debounce = false
	end
end)

-- Track closest player
game:GetService("RunService").Heartbeat:Connect(function()
	local Players = game.Players:GetPlayers()
	local closestPlayer, closestDistance = nil, MaxDistance

	for _, plr in ipairs(Players) do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and humanoid.Health > 0 and rootPart then
			local distance = (HumanoidRootPart.Position - rootPart.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = rootPart
			end
		end
	end

	if closestPlayer and closestDistance <= MaxDistance then
		Humanoid:MoveTo(closestPlayer.Position)
	end
end)