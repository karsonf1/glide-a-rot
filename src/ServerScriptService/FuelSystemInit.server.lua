local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ServerScriptService  = game:GetService("ServerScriptService")

-- Create FuelUpdate RemoteEvent so the client can WaitForChild it
local fuelUpdate = ReplicatedStorage:FindFirstChild("FuelUpdate")
if not fuelUpdate then
	fuelUpdate = Instance.new("RemoteEvent")
	fuelUpdate.Name = "FuelUpdate"
	fuelUpdate.Parent = ReplicatedStorage
	print("[FuelSystem] Created FuelUpdate RemoteEvent")
end

local FuelSystem = require(ServerScriptService:WaitForChild("FuelSystem"))
FuelSystem.Init(fuelUpdate)
