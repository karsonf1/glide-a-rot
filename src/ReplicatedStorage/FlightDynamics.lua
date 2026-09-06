-- Pure numeric motion model: no Roblox services, character writes or rewards.
-- State stores velocity independently from facing, so turns retain momentum.
local Dynamics = {}

function Dynamics.Alpha(response, dt)
	return 1 - math.exp(-response * dt)
end

function Dynamics.AngleDelta(target, current)
	return (target - current + math.pi) % (2 * math.pi) - math.pi
end

function Dynamics.Direction(yaw, pitch)
	local horizontal = math.cos(pitch)
	return -math.sin(yaw) * horizontal, math.sin(pitch), -math.cos(yaw) * horizontal
end

-- Pixels already represent motion across a rendered frame; deliberately no dt.
function Dynamics.ApplyMouseDelta(input, config, dx, dy)
	local sensitivity = math.rad(config.MouseSensitivity)
	local limit = math.rad(config.MaxYawDeviation)
	input.yaw = math.clamp(input.yaw - dx * sensitivity,
		config.ForwardYaw - limit, config.ForwardYaw + limit)
	local invert = config.InvertMouseY and -1 or 1
	input.pitch = math.clamp(input.pitch - dy * sensitivity * invert,
		math.rad(config.PitchMin), math.rad(config.PitchMax))
end

function Dynamics.New(config, vx, vy, vz)
	return {
		yaw = config.ForwardYaw, pitch = 0, bank = 0, throttle = 0,
		vx = vx, vy = vy, vz = math.max(vz, 0),
	}
end

function Dynamics.Step(state, input, stats, config, dt)
	dt = math.clamp(dt, 0, config.MaxFrameDt)
	if dt == 0 then return end
	local steps = math.max(1, math.ceil(dt / config.IntegrationStep))
	local h = dt / steps
	local yawLimit = math.rad(config.MaxYawDeviation)
	local targetYaw = config.ForwardYaw + math.clamp(
		Dynamics.AngleDelta(input.yaw, config.ForwardYaw), -yawLimit, yawLimit)
	local targetPitch = math.clamp(input.pitch, math.rad(config.PitchMin), math.rad(config.PitchMax))
	local turnLimit = math.rad(config.MaxTurnRate)

	for _ = 1, steps do
		local turn = math.clamp(Dynamics.AngleDelta(targetYaw, state.yaw)
			* Dynamics.Alpha(config.AimResponse, h), -turnLimit * h, turnLimit * h)
		state.yaw += turn
		state.pitch += (targetPitch - state.pitch) * Dynamics.Alpha(config.AimResponse, h)
		local bankTarget = (turn / h) / turnLimit * math.rad(config.MaxBank)
		state.bank += (bankTarget - state.bank) * Dynamics.Alpha(config.BankResponse, h)
		-- Braking wins if W and S are pressed together.
		local throttleTarget = input.thrust and not input.brake and 1 or 0
		state.throttle += (throttleTarget - state.throttle) * Dynamics.Alpha(config.ThrottleResponse, h)
		local fx, fy, fz = Dynamics.Direction(state.yaw, state.pitch)
		local vx, vy, vz = state.vx, state.vy, state.vz
		local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
		local forwardSpeed = vx * fx + vy * fy + vz * fz
		local damping = config.SideslipDamping
			* (config.CoastSteering + (1 - config.CoastSteering) * state.throttle)
		local drag = stats.AirDrag * speed + (input.brake and config.AirbrakeDrag or 0)
		local thrust = stats.ThrustAcceleration * state.throttle
		-- Quadratic air drag opposes velocity; sideslip damping models steering grip.
		-- Residual sink is deliberately gentler than Roblox gravity: arcade flight.
		state.vx += (fx * thrust - vx * drag - (vx - fx * forwardSpeed) * damping) * h
		state.vy += (fy * thrust - vy * drag - (vy - fy * forwardSpeed) * damping
			- config.SinkAcceleration) * h
		state.vz = math.max(0, vz + (fz * thrust - vz * drag
			- (vz - fz * forwardSpeed) * damping) * h)
		local nextSpeed = math.sqrt(state.vx ^ 2 + state.vy ^ 2 + state.vz ^ 2)
		if nextSpeed > stats.MaxSpeed then
			local scale = stats.MaxSpeed / nextSpeed
			state.vx *= scale
			state.vy *= scale
			state.vz *= scale
		end
	end
end

return Dynamics
