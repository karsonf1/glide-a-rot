-- Run with the official Luau CLI: luau checks/flight-dynamics.luau
-- Only checks the numeric model; it cannot validate Roblox movers, camera or rigs.
local Dynamics = require("../src/ReplicatedStorage/FlightDynamics")
local Registry = require("../src/ReplicatedStorage/GliderConfig")
local config = Registry.Flight
local stats = Registry.Gliders.Beginner

for _, fps in { 30, 60, 144 } do
	local aim = { yaw = config.ForwardYaw, pitch = 0 }
	for _ = 1, fps do
		Dynamics.ApplyMouseDelta(aim, config, 300 / fps, -100 / fps)
	end
	assert(math.abs(aim.yaw - (config.ForwardYaw - math.rad(36))) < 1e-8,
		"mouse yaw sensitivity changed with frame rate")
	assert(math.abs(aim.pitch - math.rad(12)) < 1e-8, "mouse-up should aim up")
end

local function run(state, seconds, fps, input, tier)
	for _ = 1, math.floor(seconds * fps + 0.5) do
		Dynamics.Step(state, input, tier or stats, config, 1 / fps)
		local speed = math.sqrt(state.vx ^ 2 + state.vy ^ 2 + state.vz ^ 2)
		assert(speed == speed and speed <= (tier or stats).MaxSpeed + 1e-6, "invalid speed")
		assert(state.vz >= 0, "backwards corridor velocity")
	end
	return state
end

local straight = { yaw = config.ForwardYaw, pitch = 0.1, thrust = true, brake = false }
local baseline = run(Dynamics.New(config, 0, 0, 0), 8, 60, straight)
assert(baseline.vz > 60, "thrust should accelerate from rest")
for _, fps in { 30, 144 } do
	local other = run(Dynamics.New(config, 0, 0, 0), 8, fps, straight)
	local difference = math.sqrt((other.vx - baseline.vx)^2
		+ (other.vy - baseline.vy)^2 + (other.vz - baseline.vz)^2)
	assert(difference < 0.15, "frame-rate-dependent thrust: " .. tostring(difference))
	print(string.format("%d vs 60 fps: velocity difference %.5f studs/s", fps, difference))
end

local coastInput = { yaw = config.ForwardYaw, pitch = 0, thrust = false, brake = false }
local brakeInput = { yaw = config.ForwardYaw, pitch = 0, thrust = true, brake = true }
local coasting = run(Dynamics.New(config, 0, 0, 70), 2, 60, coastInput)
local braking = run(Dynamics.New(config, 0, 0, 70), 2, 60, brakeInput)
assert(coasting.vz < 70 and coasting.vz > 20, "coasting must lose speed but retain momentum")
assert(braking.vz < coasting.vz * 0.3, "airbrake should slow faster than coast")
assert(braking.throttle == 0, "brake must override W")

local turning = Dynamics.New(config, 0, 0, 70)
local turnInput = { yaw = config.ForwardYaw - math.rad(45), pitch = 0, thrust = true, brake = false }
run(turning, 0.1, 60, turnInput)
assert(turning.yaw < config.ForwardYaw, "body must follow right aim")
assert(turning.vx < 0 and turning.vz > math.abs(turning.vx) * 3,
	"turn should initially retain its previous forward momentum")
assert(turning.bank < 0, "right turn must bank right")

local extreme = { yaw = config.ForwardYaw + math.rad(120), pitch = 9, thrust = true, brake = false }
local limited = run(Dynamics.New(config, 0, 0, 0), 12, 30, extreme)
assert(math.abs(Dynamics.AngleDelta(limited.yaw, config.ForwardYaw)) <= math.rad(config.MaxYawDeviation) + 1e-6)
assert(limited.pitch <= math.rad(config.PitchMax) + 1e-6)
for _, tier in Registry.Gliders do
	run(Dynamics.New(config, 0, 0, 0), 15, 60, straight, tier)
end
local unchanged = Dynamics.New(config, 1, 2, 3)
Dynamics.Step(unchanged, straight, stats, config, 0)
assert(unchanged.vx == 1 and unchanged.vy == 2 and unchanged.vz == 3, "zero dt must be a no-op")
print(string.format("Coast %.2f vs brake %.2f studs/s after 2s", coasting.vz, braking.vz))
print("Flight dynamics checks passed; Studio playtest still required.")
