local CollectionService   = game:GetService("CollectionService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local FuelSystem = require(ServerScriptService:WaitForChild("FuelSystem"))

local RING_FUEL_REFILL  = 25
local RING_POOF_REWARD  = 5
local RING_RESPAWN_DELAY = 8

-- Create RemoteEvents so clients can WaitForChild them
local function ensureRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
		print(("[RingSystem] Created %s RemoteEvent"):format(name))
	end
	return event
end

local poofUpdate    = ensureRemoteEvent("PoofUpdate")
local ringCollected = ensureRemoteEvent("RingCollected")

local ringDebounce = {}  -- [ring] = true while on cooldown (per-ring, not per-player)

local function wireRing(ring)
	ring.Touched:Connect(function(hit)
		if ringDebounce[ring] then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		ringDebounce[ring] = true

		PlayerData.AwardPoofs(player, RING_POOF_REWARD)
		FuelSystem.Refuel(player, RING_FUEL_REFILL)

		ringCollected:FireClient(player, ring)
		print(("[RingSystem] %s collected ring '%s'"):format(player.Name, ring.Name))

		ring.Transparency = 1
		ring.CanCollide   = false

		task.delay(RING_RESPAWN_DELAY, function()
			if ring and ring.Parent then
				ring.Transparency = 0
				ring.CanCollide   = true
				print(("[RingSystem] Ring '%s' respawned"):format(ring.Name))
			end
			ringDebounce[ring] = nil
		end)
	end)
end

for _, ring in CollectionService:GetTagged("PoofRing") do
	wireRing(ring)
end

CollectionService:GetInstanceAddedSignal("PoofRing"):Connect(wireRing)
