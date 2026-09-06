-- Thruster flight prototype: input, simulation and camera run on separate phases.
-- Fuel, distance measurement and creature rewards remain server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local GliderConfig = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local Dynamics = require(ReplicatedStorage:WaitForChild("FlightDynamics"))
local Presentation = require(script.Parent:WaitForChild("FlightPresentation"))
local config = GliderConfig.Flight
local player = Players.LocalPlayer
local equipEvent = ReplicatedStorage:WaitForChild("GliderEquipClient")
local fuelEvent = ReplicatedStorage:WaitForChild("FuelUpdate")
local hotbarEvent = ReplicatedStorage:WaitForChild("HotbarSlotActivated", 10)

local character, humanoid, hrp
local flight
local characterConnections = {}
local canDoubleJump = false
local windowFocused = true
local lastFuel
local promptClock = 0

local gui = Instance.new("ScreenGui")
gui.Name = "ThrusterFlightHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name, y, size)
	local result = Instance.new("TextLabel")
	result.Name = name
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, y)
	result.Size = UDim2.new(0.9, 0, 0, 36)
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.GothamMedium
	result.TextSize = size
	result.TextColor3 = Color3.fromRGB(230, 244, 255)
	result.TextStrokeTransparency = 0.4
	result.Visible = false
	result.Parent = gui
	return result
end

local prompt = label("DeployPrompt", 0.7, 18)
prompt.Text = "F  •  ENGAGE THRUSTERS"
local status = label("FlightStatus", 0.9, 16)
local controls = label("Controls", 0.95, 13)
controls.Text = "MOUSE  AIM     W  THRUST     S  AIRBRAKE     E  END RUN"

-- A fixed aim reference, not a moving cursor. Menus restore the normal pointer.
local reticle = Instance.new("Frame")
reticle.Name = "AimReference"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(4, 4)
reticle.BackgroundColor3 = Color3.fromRGB(220, 242, 255)
reticle.BackgroundTransparency = 0.3
reticle.BorderSizePixel = 0
reticle.Visible = false
reticle.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = reticle

local function inputAvailable()
	return windowFocused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { character } or {}
	params.RespectCanCollide = true
	return params
end

local function canDeploy()
	if flight or not hrp or not humanoid or humanoid.Health <= 0 then return false end
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -config.DeployMinHeight, 0), rayParams())
	return hit == nil
end

local function stopFlight(notifyServer)
	local current = flight
	if not current then return end
	flight = nil
	RunService:UnbindFromRenderStep("GARFlightInput")
	RunService:UnbindFromRenderStep("GARFlightCamera")
	if current.simulation then current.simulation:Disconnect() end
	current.presentation:Destroy()
	current.velocity:Destroy()
	current.orientation:Destroy()
	current.attachment:Destroy()
	if current.humanoid.Parent then
		current.humanoid.PlatformStand = current.saved.platformStand
		current.humanoid.AutoRotate = current.saved.autoRotate
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = current.saved.cameraType
		camera.FieldOfView = current.saved.fov
		if current.saved.subject and current.saved.subject.Parent then
			camera.CameraSubject = current.saved.subject
		elseif humanoid and humanoid.Parent then
			camera.CameraSubject = humanoid
		end
	end
	UserInputService.MouseBehavior = current.saved.mouseBehavior
	UserInputService.MouseIconEnabled = current.saved.mouseIcon
	reticle.Visible, status.Visible, controls.Visible = false, false, false
	canDoubleJump = false
	if notifyServer then equipEvent:FireServer(false, nil) end
	print("[Flight] Thrusters disengaged")
end

local function updateInput()
	local current = flight
	if not current then return end
	local available = inputAvailable()
	current.input.thrust = available and UserInputService:IsKeyDown(Enum.KeyCode.W)
	current.input.brake = available and UserInputService:IsKeyDown(Enum.KeyCode.S)
	reticle.Visible = available
	if not available then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	-- Delta is pixels SINCE THE LAST RENDER. Multiplying it by dt again makes
	-- mouse sensitivity depend on frame rate. Only angular motion uses dt.
	local delta = UserInputService:GetMouseDelta()
	Dynamics.ApplyMouseDelta(current.input, config, delta.X, delta.Y)
end

local function updateCamera(dt)
	local current = flight
	local camera = workspace.CurrentCamera
	if not current or not camera or not hrp then return end
	dt = math.min(dt, config.MaxFrameDt)
	local c = config.Camera
	local aimAlpha = Dynamics.Alpha(c.AimResponse, dt)
	current.cameraYaw += Dynamics.AngleDelta(current.input.yaw, current.cameraYaw) * aimAlpha
	current.cameraPitch += (current.input.pitch * c.PitchWeight - current.cameraPitch) * aimAlpha
	local aim = CFrame.fromEulerAnglesYXZ(current.cameraPitch, current.cameraYaw, 0)
	local wanted = hrp.Position + aim:VectorToWorldSpace(Vector3.new(0, c.Height, c.Distance))
	local candidate = current.cameraPosition:Lerp(wanted, Dynamics.Alpha(c.PositionResponse, dt))
	local anchor = hrp.Position + Vector3.new(0, c.LookHeight, 0)
	-- Resolve collision AFTER smoothing, so a lagging camera cannot stay in a wall.
	local obstruction = workspace:Raycast(anchor, candidate - anchor, current.rayParams)
	current.cameraPosition = obstruction
		and (obstruction.Position + obstruction.Normal * c.CollisionPadding) or candidate
	local lookAt = anchor + aim.LookVector * c.LookAhead
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(current.cameraPosition, lookAt, Vector3.yAxis)
	camera.Focus = CFrame.new(lookAt)
	local speed = hrp.AssemblyLinearVelocity.Magnitude
	local ratio = math.clamp(speed / current.stats.MaxSpeed, 0, 1)
	local targetFOV = c.FOV + c.SpeedFOV * ratio * ratio
	camera.FieldOfView += (targetFOV - camera.FieldOfView) * Dynamics.Alpha(c.FOVResponse, dt)
	local mode = current.input.brake and "AIRBRAKE" or current.input.thrust and "THRUST" or "COAST"
	local fuelText = lastFuel and string.format("    FUEL %d", math.floor(lastFuel)) or ""
	status.Text = string.format("%s    %d STUDS/S%s", mode, math.floor(speed), fuelText)
end

local function startFlight(name)
	if flight then stopFlight(true); return end
	if not canDeploy() then return end
	local stats = GliderConfig.Gliders[name]
	local camera = workspace.CurrentCamera
	if not stats or not camera then return end
	local actual = hrp.AssemblyLinearVelocity
	local motion = Dynamics.New(config, actual.X, actual.Y, actual.Z)
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = hrp
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "FlightVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = actual
	velocity.Parent = hrp
	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "FlightOrientation"
	orientation.Attachment0 = attachment
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.MaxTorque = math.huge
	orientation.MaxAngularVelocity = config.MaxAngularVelocity
	orientation.Responsiveness = config.OrientationResponse
	orientation.CFrame = CFrame.fromEulerAnglesYXZ(math.rad(config.BodyLean), motion.yaw, 0)
	orientation.Parent = hrp

	local current = {
		stats = stats, motion = motion, humanoid = humanoid, elapsed = 0,
		input = { yaw = config.ForwardYaw, pitch = 0, thrust = false, brake = false },
		attachment = attachment, velocity = velocity, orientation = orientation,
		cameraYaw = config.ForwardYaw, cameraPitch = 0, cameraPosition = camera.CFrame.Position,
		rayParams = rayParams(),
		saved = {
			cameraType = camera.CameraType, fov = camera.FieldOfView, subject = camera.CameraSubject,
			mouseBehavior = UserInputService.MouseBehavior, mouseIcon = UserInputService.MouseIconEnabled,
			autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand,
		},
	}
	current.presentation = Presentation.new(character, config)
	flight = current
	lastFuel = nil
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	camera.CameraType = Enum.CameraType.Scriptable
	prompt.Visible = false
	status.Visible, controls.Visible = true, true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	RunService:BindToRenderStep("GARFlightInput", Enum.RenderPriority.Input.Value + 1, updateInput)
	RunService:BindToRenderStep("GARFlightCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	-- Pose writes occur after Animator evaluation; velocity is ready for physics.
	current.simulation = RunService.PreSimulation:Connect(function(dt)
		if flight ~= current or not hrp or not hrp.Parent then return end
		current.elapsed += dt
		-- Read actual velocity so collisions affect momentum instead of carrying an
		-- ever-growing desired velocity through a wall. No position writes.
		local measured = hrp.AssemblyLinearVelocity
		motion.vx, motion.vy, motion.vz = measured.X, measured.Y, measured.Z
		Dynamics.Step(motion, current.input, stats, config, dt)
		velocity.VectorVelocity = Vector3.new(motion.vx, motion.vy, motion.vz)
		local lean = config.BodyLean + config.ThrustLean * motion.throttle
		orientation.CFrame = CFrame.fromEulerAnglesYXZ(
			math.rad(lean) + motion.pitch * config.BodyPitchWeight, motion.yaw, motion.bank)
		current.presentation:Update(motion, current.elapsed)
	end)
	equipEvent:FireServer(true, name)
	print("[Flight] Engaged:", name, "| hold W to thrust, release to coast")
end

local function setupCharacter(newCharacter)
	stopFlight(true)
	for _, connection in characterConnections do connection:Disconnect() end
	table.clear(characterConnections)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	canDoubleJump = false
	table.insert(characterConnections, humanoid.Died:Connect(function() stopFlight(true) end))
	table.insert(characterConnections, humanoid.StateChanged:Connect(function(_, state)
		if flight then return end
		if state == Enum.HumanoidStateType.Freefall then
			canDoubleJump = true
		elseif state == Enum.HumanoidStateType.Landed then
			canDoubleJump = false
		end
	end))
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
	stopFlight(true)
	character, humanoid, hrp = nil, nil, nil
end)
if player.Character then task.defer(setupCharacter, player.Character) end

UserInputService.WindowFocusReleased:Connect(function() windowFocused = false end)
UserInputService.WindowFocused:Connect(function() windowFocused = true end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inputAvailable() then return end
	if input.KeyCode == Enum.KeyCode.F then
		startFlight("Beginner")
	elseif input.KeyCode == Enum.KeyCode.E then
		stopFlight(true)
	elseif input.KeyCode == Enum.KeyCode.Space and canDoubleJump and not flight and hrp then
		canDoubleJump = false
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, config.DoubleJumpPower, v.Z)
	end
end)

fuelEvent.OnClientEvent:Connect(function(fuel)
	if typeof(fuel) ~= "number" then return end
	lastFuel = fuel
	-- Server emits RunEnded/awards. Only remove local movers/camera here.
	if flight and fuel <= 0 then stopFlight(false) end
end)
if hotbarEvent and hotbarEvent:IsA("BindableEvent") then
	hotbarEvent.Event:Connect(function(data)
		if type(data) == "table" and GliderConfig.Gliders[data.InternalName] then
			startFlight(data.InternalName)
		end
	end)
end
RunService.Heartbeat:Connect(function(dt)
	promptClock += dt
	if promptClock < 0.1 then return end
	promptClock = 0
	prompt.Visible = not flight and inputAvailable() and canDeploy()
end)
script.Destroying:Connect(function()
	stopFlight(true)
	gui:Destroy()
end)
print("[Flight] Ready: jump, F to engage | mouse aims | W thrust | S brake | E end run")
