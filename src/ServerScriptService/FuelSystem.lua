local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(script.Parent:WaitForChild("GameEvents"))

local FUEL_MAX             = 100
local FUEL_DRAIN_PER_SECOND = 4

local fuelLevels = {}  -- [player] = number (0–100), nil when no run active
local fuelThreads = {} -- [player] = task thread handle

local FuelUpdate  -- set by Init

local FuelSystem = {}

local function stopFuelLoop(player)
	if fuelThreads[player] then
		task.cancel(fuelThreads[player])
		fuelThreads[player] = nil
	end
	fuelLevels[player] = nil
end

function FuelSystem.Init(fuelUpdateEvent)
	FuelUpdate = fuelUpdateEvent

	local gliderEquipEvent = ReplicatedStorage:WaitForChild("GliderEquipClient")

	gliderEquipEvent.OnServerEvent:Connect(function(player, isEquipped)
		if isEquipped then
			-- Cancel any leftover loop from a previous equip that didn't stow cleanly
			stopFuelLoop(player)

			fuelLevels[player] = FUEL_MAX
			print(("[FuelSystem] %s → fuel initialized to %d"):format(player.Name, FUEL_MAX))
			FuelUpdate:FireClient(player, FUEL_MAX)

			fuelThreads[player] = task.spawn(function()
				while true do
					task.wait(1)

					-- fuelLevels[player] is nil if stopFuelLoop was called while we slept
					local current = fuelLevels[player]
					if current == nil then break end

					local next = math.max(0, current - FUEL_DRAIN_PER_SECOND)
					fuelLevels[player] = next

					FuelUpdate:FireClient(player, next)
					print(("[FuelSystem] %s → fuel: %d"):format(player.Name, next))

					if next <= 0 then
						fuelThreads[player] = nil
						fuelLevels[player]  = nil
						print(("[FuelSystem] %s → fuel depleted, signalling GliderHandler"):format(player.Name))
						GameEvents.FuelDepleted:Fire(player)
						break
					end
				end
			end)

		else
			-- Manual stow: kill the drain loop immediately
			stopFuelLoop(player)
			print(("[FuelSystem] %s → fuel loop stopped (glider stowed)"):format(player.Name))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		stopFuelLoop(player)
	end)
end

function FuelSystem.Refuel(player, amount)
	local current = fuelLevels[player]
	if current == nil then
		warn(("[FuelSystem] Refuel called for %s but no active run"):format(player.Name))
		return
	end
	local next = math.min(FUEL_MAX, current + amount)
	fuelLevels[player] = next
	FuelUpdate:FireClient(player, next)
	print(("[FuelSystem] %s → refuelled +%d → %d"):format(player.Name, amount, next))
end

return FuelSystem
