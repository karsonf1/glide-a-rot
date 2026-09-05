local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	CameraHeight      = 24,
	CameraDistance    = 16,
	CameraLerpFactor  = 5.5,
	CameraLookAhead   = 18,
	CameraLookHeight  = -2,
	MouseSensitivity  = 0.25,
	InvertMouse       = false,
	DeployMinHeight   = 8,
	PromptDuration    = 2.4,
	DoubleJumpPower   = 52,
	GliderOffsetY     = 0,
	GliderOffsetX     = 0,
	GliderOffsetZ     = 3,
	GliderOffsetPitch = 90,
	GliderOffsetYaw   = 0,
	GliderOffsetRoll  = 0,
	MaxDt             = 0.1,
	CameraFOV         = 66,
	-- Extra FOV at max airspeed. Speed is variable now, so the camera can
	-- actually communicate it -- this is most of the felt "realism".
	FOVSpeedBoost     = 22,
	FOVLerpFactor     = 3.0,
	VisualPitchOffset = -90,
	-- How quickly the velocity vector swings to a new heading. Lower values
	-- leave the glider drifting through the turn instead of snapping to it.
	VelocityResponse  = 6.0,
	ArmShoulderPitch  = -68,
	ArmShoulderSpread = 14,
	ArmElbowBend      = 58,
}

local GliderConfig        = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local hotbarActivateEvent = ReplicatedStorage:WaitForChild("HotbarSlotActivated", 10)
local gliderEquipEvent    = ReplicatedStorage:WaitForChild("GliderEquipClient",   10)
local ringCollectedEvent  = ReplicatedStorage:WaitForChild("RingCollected",       10)

local PHYS = GliderConfig.Physics

local character, humanoid, hrp

local flightState = {
	active=false, statsRef=nil, gliderName=nil, deployY=nil,
	yawAngle=0, pitch=0, roll=0,
	speed=0,          -- studs/sec along the flight path -- the core state variable
	boostTimer=0,     -- seconds of forced climb pitch remaining
	stalling=false,
	att=nil, lv=nil, ao=nil, heartbeat=nil, gliderModel=nil,
	camPos=Vector3.zero,
	currentVelX=0, currentVelZ=0,
}

local jumpCount     = 0
local canDoubleJump = false
local promptVisible = false
local promptTimer   = 0

local poseJoints = {}

-- ── Arm pose (Weld-based, works with AnimationConstraint rig) ─────────────────
local function poseJoint(parentPart, childPart, animConstraintName, ballSocketName, rotCF)
	if not parentPart or not childPart then return end
	local animC = childPart:FindFirstChild(animConstraintName)
	local ballC = childPart:FindFirstChild(ballSocketName)
	if not animC then return end

	local att0 = animC.Attachment0
	local att1 = animC.Attachment1
	if not att0 or not att1 then return end

	local jointWorldCF   = parentPart.CFrame * att0.CFrame
	local desiredChildCF = jointWorldCF * rotCF * att1.CFrame:Inverse()

	local weld = Instance.new("Weld")
	weld.Part0 = parentPart
	weld.Part1 = childPart
	weld.C0 = parentPart.CFrame:Inverse() * desiredChildCF
	weld.C1 = CFrame.new()
	weld.Parent = childPart

	animC.Enabled = false
	if ballC then ballC.Enabled = false end

	table.insert(poseJoints, { weld = weld, animC = animC, ballC = ballC })
end

local function beginGliderPose()
	poseJoints = {}
	if not character then return end
	local upperTorso    = character:FindFirstChild("UpperTorso")
	local leftUpperArm  = character:FindFirstChild("LeftUpperArm")
	local rightUpperArm = character:FindFirstChild("RightUpperArm")
	local leftLowerArm  = character:FindFirstChild("LeftLowerArm")
	local rightLowerArm = character:FindFirstChild("RightLowerArm")
	if not upperTorso then return end

	local sp  = CFrame.Angles(math.rad(CONFIG.ArmShoulderPitch), 0, math.rad(-CONFIG.ArmShoulderSpread))
	local spR = CFrame.Angles(math.rad(CONFIG.ArmShoulderPitch), 0, math.rad( CONFIG.ArmShoulderSpread))
	local eb  = CFrame.Angles(math.rad(CONFIG.ArmElbowBend), 0, 0)

	poseJoint(upperTorso,    leftUpperArm,  "LeftShoulder",  "LeftShoulderBallSocket",  sp)
	poseJoint(upperTorso,    rightUpperArm, "RightShoulder", "RightShoulderBallSocket", spR)
	if leftLowerArm  then poseJoint(leftUpperArm,  leftLowerArm,  "LeftElbow",  "LeftElbowBallSocket",  eb) end
	if rightLowerArm then poseJoint(rightUpperArm, rightLowerArm, "RightElbow", "RightElbowBallSocket", eb) end

	print("[Glider] Arm pose applied —", #poseJoints, "joints")
end

local function endGliderPose()
	for _, j in ipairs(poseJoints) do
		pcall(function()
			if j.weld  and j.weld.Parent  then j.weld:Destroy() end
			if j.animC and j.animC.Parent then j.animC.Enabled = true end
			if j.ballC and j.ballC.Parent then j.ballC.Enabled = true end
		end)
	end
	poseJoints = {}
end

-- ── Deploy prompt ─────────────────────────────────────────────────────────────
local deployGui = Instance.new("ScreenGui")
deployGui.Name = "GliderDeployPrompt"
deployGui.ResetOnSpawn = false
deployGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
deployGui.Parent = player.PlayerGui

local deployLabel = Instance.new("TextLabel")
deployLabel.Size = UDim2.new(0.7, 0, 0.1, 0)
deployLabel.Position = UDim2.new(0.15, 0, 0.38, 0)
deployLabel.BackgroundTransparency = 1
deployLabel.Text = "PRESS  F  TO DEPLOY HANGGLIDER"
deployLabel.TextColor3 = Color3.fromRGB(176, 224, 255)
deployLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
deployLabel.TextStrokeTransparency = 0
deployLabel.Font = Enum.Font.GothamBold
deployLabel.TextScaled = true
deployLabel.TextXAlignment = Enum.TextXAlignment.Center
deployLabel.Visible = false
deployLabel.Parent = deployGui

-- Stall is a real failure state now. Without a readable cue it just feels like
-- the game broke, so it gets its own indicator.
local stallLabel = Instance.new("TextLabel")
stallLabel.Name = "StallWarning"
stallLabel.Size = UDim2.new(0.5, 0, 0.07, 0)
stallLabel.Position = UDim2.new(0.25, 0, 0.16, 0)
stallLabel.BackgroundTransparency = 1
stallLabel.Text = "STALL — NOSE DOWN"
stallLabel.TextColor3 = Color3.fromRGB(255, 96, 72)
stallLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
stallLabel.TextStrokeTransparency = 0
stallLabel.Font = Enum.Font.GothamBlack
stallLabel.TextScaled = true
stallLabel.Visible = false
stallLabel.Parent = deployGui

local function hidePrompt()
	deployLabel.Visible = false
	promptVisible = false
	promptTimer = 0
end

local function tryShowPrompt()
	if flightState.active or not hrp then return end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -120, 0), params)
	local height = result and (hrp.Position.Y - result.Position.Y) or 999
	if height < CONFIG.DeployMinHeight then return end
	deployLabel.Visible = true
	promptVisible = true
	promptTimer = CONFIG.PromptDuration
end

RunService.Heartbeat:Connect(function(dt)
	if not promptVisible then return end
	promptTimer -= dt
	if promptTimer <= 0 then hidePrompt() end
end)

-- ── Physics constraints ───────────────────────────────────────────────────────
local function createConstraints()
	local att = Instance.new("Attachment"); att.Name = "GliderAtt"; att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att; lv.MaxForce = math.huge
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero; lv.Parent = hrp
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att; ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = math.huge; ao.MaxAngularVelocity = 80; ao.Responsiveness = 20
	ao.Parent = hrp
	return att, lv, ao
end

local function destroyConstraints()
	pcall(function()
		if flightState.att then flightState.att:Destroy() end
		if flightState.lv  then flightState.lv:Destroy()  end
		if flightState.ao  then flightState.ao:Destroy()  end
	end)
	flightState.att = nil; flightState.lv = nil; flightState.ao = nil
end

-- ── Flight ────────────────────────────────────────────────────────────────────
local function stopFlight()
	if not flightState.active then return end
	flightState.active = false; flightState.statsRef = nil
	flightState.gliderName = nil; flightState.deployY = nil
	flightState.boostTimer = 0; flightState.stalling = false
	stallLabel.Visible = false
	if flightState.heartbeat then flightState.heartbeat:Disconnect(); flightState.heartbeat = nil end
	endGliderPose()
	destroyConstraints()
	if flightState.gliderModel then flightState.gliderModel:Destroy(); flightState.gliderModel = nil end
	if humanoid then humanoid.PlatformStand = false end
	jumpCount = 0; canDoubleJump = false; hidePrompt()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if gliderEquipEvent then gliderEquipEvent:FireServer(false, nil) end
	print("[Glider] Stowed")
end

local function startFlight(gliderName)
	if not character or not humanoid or not hrp then warn("[Glider] Character not ready"); return end
	if flightState.active and flightState.gliderName == gliderName then stopFlight(); return end
	if flightState.active then stopFlight() end
	local stats = GliderConfig.Gliders[gliderName]
	if not stats then warn("[Glider] No config for:", gliderName); return end

	local lookXZ = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if lookXZ.Magnitude > 0.001 then lookXZ = lookXZ.Unit end

	flightState.active = true; flightState.statsRef = stats
	flightState.gliderName = gliderName
	flightState.yawAngle = math.atan2(-lookXZ.X, -lookXZ.Z)
	flightState.pitch = stats.GlideAngle
	flightState.roll = 0; flightState.deployY = hrp.Position.Y
	flightState.boostTimer = 0
	flightState.stalling = false

	-- Deploy at cruise so the wing is already flying rather than stalled.
	flightState.speed = stats.CruiseSpeed
	local initHoriz = math.cos(math.rad(stats.GlideAngle)) * flightState.speed
	flightState.currentVelX = -math.sin(flightState.yawAngle) * initHoriz
	flightState.currentVelZ = -math.cos(flightState.yawAngle) * initHoriz

	humanoid.PlatformStand = true
	local att, lv, ao = createConstraints()
	flightState.att = att; flightState.lv = lv; flightState.ao = ao

	task.defer(beginGliderPose)

	local modelsFolder = ReplicatedStorage:FindFirstChild("GliderModels")
	if modelsFolder then
		local template = modelsFolder:FindFirstChild(stats.ModelName or gliderName)
		if template then
			local clone = template:Clone()
			local gliderRoot = clone:FindFirstChild("GliderRoot") or clone.PrimaryPart
			if gliderRoot then
				gliderRoot.CFrame = hrp.CFrame
					* CFrame.new(CONFIG.GliderOffsetX, CONFIG.GliderOffsetY, CONFIG.GliderOffsetZ)
					* CFrame.Angles(math.rad(CONFIG.GliderOffsetPitch), math.rad(CONFIG.GliderOffsetYaw), math.rad(CONFIG.GliderOffsetRoll))
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false; part.Massless = true
						part.CastShadow = false; part.CanQuery = false
					end
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp; weld.Part1 = gliderRoot; weld.Parent = gliderRoot
				clone.Parent = character; flightState.gliderModel = clone
			else
				clone:Destroy()
				warn("[Glider] No GliderRoot in model:", stats.ModelName)
			end
		end
	end

	local initOffset = Vector3.new(0, CONFIG.CameraHeight, 0) + lookXZ * (-CONFIG.CameraDistance)
	flightState.camPos = hrp.Position + initOffset
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CONFIG.CameraFOV
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	if gliderEquipEvent then gliderEquipEvent:FireServer(true, gliderName) end
	print("[Glider] Deployed:", gliderName, "| deployY:", math.floor(flightState.deployY))

	flightState.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not flightState.active then return end
		dt = math.min(dt, CONFIG.MaxDt)
		local s = flightState.statsRef

		local mouseX = UserInputService:GetMouseDelta().X * (CONFIG.InvertMouse and -1 or 1)
		local adInput = (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
		local wsInput = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)

		-- BANK: A/D and mouse X command a bank ANGLE, not a yaw rate. The wing
		-- rolls and hangs there; yaw is derived from it below. This is the swing.
		local bankInput = math.clamp(adInput - mouseX * CONFIG.MouseSensitivity, -1, 1)
		local rollTarget = bankInput * s.MaxBank
		flightState.roll += (rollTarget - flightState.roll) * s.RollResponse * dt
		flightState.roll = math.clamp(flightState.roll, -s.MaxBank, s.MaxBank)
		local rollRad = math.rad(flightState.roll)

		-- PITCH: a live ring boost overrides pilot input and forces the nose up.
		local pitchTarget
		if flightState.boostTimer > 0 then
			flightState.boostTimer -= dt
			pitchTarget = PHYS.BoostPitch
		elseif wsInput > 0 then pitchTarget = s.PitchRange[2]
		elseif wsInput < 0 then pitchTarget = s.PitchRange[1]
		else pitchTarget = s.GlideAngle end
		flightState.pitch += (pitchTarget - flightState.pitch) * s.PitchLerpFactor * dt
		local pitchRad = math.rad(flightState.pitch)

		-- AIRSPEED -- the core of the model. Nose down converts altitude into
		-- speed; quadratic drag caps it. Nose up spends speed. Everything below
		-- reads from this number.
		local accel = -math.sin(pitchRad) * PHYS.DiveAccel
		            - PHYS.Drag * flightState.speed * flightState.speed
		flightState.speed = math.clamp(flightState.speed + accel * dt, s.MinSpeed, s.MaxSpeed)
		local speed = flightState.speed

		-- YAW FROM BANK. Coordinated-turn style: yaw rate rises with bank AND with
		-- airspeed, so a slow glider turns sluggishly no matter how hard you roll.
		local speedRatio = math.clamp(speed / s.CruiseSpeed, 0.25, 1.6)
		local yawRate = math.tan(rollRad) * s.BankTurnGain * speedRatio
		flightState.yawAngle += math.rad(yawRate) * dt

		local visualPitchRad = math.max(
			pitchRad + math.rad(CONFIG.VisualPitchOffset),
			math.rad(-82)
		)
		flightState.ao.CFrame = CFrame.fromEulerAnglesYXZ(visualPitchRad, flightState.yawAngle, rollRad)

		-- HORIZONTAL VELOCITY, lerped rather than assigned so the glider carries
		-- momentum through a turn instead of snapping to the new heading.
		local horizSpeed = math.cos(pitchRad) * speed
		local targetVx = -math.sin(flightState.yawAngle) * horizSpeed
		local targetVz = -math.cos(flightState.yawAngle) * horizSpeed
		flightState.currentVelX += (targetVx - flightState.currentVelX) * CONFIG.VelocityResponse * dt
		flightState.currentVelZ += (targetVz - flightState.currentVelZ) * CONFIG.VelocityResponse * dt

		-- VERTICAL VELOCITY. Three terms: geometric descent from pitch, parasitic
		-- sink (which multiplies as the wing stalls), and the cost of banking.
		local stallFactor = 1
		if speed < s.StallSpeed then
			stallFactor = 1 + (1 - speed / s.StallSpeed) * s.StallSinkMultiplier
		end
		local bankSink = (1 - math.cos(rollRad)) * s.BankSinkPenalty
		local vy = math.sin(pitchRad) * speed - s.SinkRate * stallFactor - bankSink

		-- Ceiling relative to DEPLOY altitude so a ring chain can't reach orbit.
		-- (v1 clamped vy <= -0.5 above deployY, which made altitude gain of any
		-- kind impossible -- rings could never have lifted you.)
		if flightState.deployY and hrp.Position.Y > flightState.deployY + PHYS.MaxAltitudeGain then
			vy = math.min(vy, 0)
		end

		flightState.lv.VectorVelocity = Vector3.new(flightState.currentVelX, vy, flightState.currentVelZ)

		local nowStalling = speed < s.StallSpeed
		if nowStalling ~= flightState.stalling then
			flightState.stalling = nowStalling
			stallLabel.Visible = nowStalling
		end

		local fovRatio = math.clamp((speed - s.CruiseSpeed) / (s.MaxSpeed - s.CruiseSpeed), 0, 1)
		local targetFOV = CONFIG.CameraFOV + fovRatio * CONFIG.FOVSpeedBoost
		camera.FieldOfView += (targetFOV - camera.FieldOfView) * CONFIG.FOVLerpFactor * dt

		local flatCF = CFrame.fromEulerAnglesYXZ(pitchRad * 0.25, flightState.yawAngle, 0)
		local camOffset = flatCF * Vector3.new(0, CONFIG.CameraHeight, CONFIG.CameraDistance)
		local targetCamPos = hrp.Position + camOffset
		flightState.camPos += (targetCamPos - flightState.camPos) * CONFIG.CameraLerpFactor * dt
		local fwdDir = Vector3.new(-math.sin(flightState.yawAngle), 0, -math.cos(flightState.yawAngle))
		local lookTarget = hrp.Position + fwdDir * CONFIG.CameraLookAhead + Vector3.new(0, CONFIG.CameraLookHeight, 0)
		camera.CFrame = CFrame.new(flightState.camPos, lookTarget)
	end)
end

-- ── Ring boost ────────────────────────────────────────────────────────────────
-- The server owns the fuel and Poof award; this handles only the felt part: a
-- shot of airspeed plus a forced climb. Purely local, so it lands on the same
-- frame the player sees the ring pass.
if ringCollectedEvent then
	ringCollectedEvent.OnClientEvent:Connect(function()
		if not flightState.active then return end
		local s = flightState.statsRef
		if not s then return end
		flightState.speed = math.max(flightState.speed, s.CruiseSpeed * PHYS.BoostSpeedFloor)
		flightState.boostTimer = PHYS.BoostDuration
	end)
else
	warn("[Glider] RingCollected RemoteEvent missing -- ring boosts will not fire")
end

-- ── Character setup ───────────────────────────────────────────────────────────
local function setupCharacter(char)
	if flightState.active then
		flightState.active = false; flightState.gliderName = nil
		flightState.statsRef = nil; flightState.deployY = nil
		flightState.boostTimer = 0; flightState.stalling = false
		stallLabel.Visible = false
		if flightState.heartbeat then flightState.heartbeat:Disconnect(); flightState.heartbeat = nil end
		endGliderPose()
		flightState.att = nil; flightState.lv = nil; flightState.ao = nil
		flightState.gliderModel = nil
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	jumpCount = 0; canDoubleJump = false; hidePrompt()
	character = char
	humanoid  = char:WaitForChild("Humanoid")
	hrp       = char:WaitForChild("HumanoidRootPart")

	humanoid.StateChanged:Connect(function(_, newState)
		if flightState.active then return end
		if newState == Enum.HumanoidStateType.Jumping then
			jumpCount = math.min(jumpCount + 1, 2)
		elseif newState == Enum.HumanoidStateType.Freefall then
			if jumpCount == 1 then canDoubleJump = true end
		elseif newState == Enum.HumanoidStateType.Landed
		    or newState == Enum.HumanoidStateType.Running
		    or newState == Enum.HumanoidStateType.RunningNoPhysics then
			jumpCount = 0; canDoubleJump = false; hidePrompt()
		end
	end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then task.defer(setupCharacter, player.Character) end

-- ── Input ─────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space and canDoubleJump and not flightState.active and hrp then
		canDoubleJump = false
		local vel = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(vel.X, CONFIG.DoubleJumpPower, vel.Z)
		task.spawn(function()
			task.wait(0.08)
			local apexWatcher
			apexWatcher = RunService.Heartbeat:Connect(function()
				if not hrp or flightState.active then apexWatcher:Disconnect(); return end
				if hrp.AssemblyLinearVelocity.Y <= 0.5 then
					apexWatcher:Disconnect()
					tryShowPrompt()
				end
			end)
			task.delay(4, function() pcall(function() apexWatcher:Disconnect() end) end)
		end)
	end

	if input.KeyCode == Enum.KeyCode.F and promptVisible and not flightState.active then
		hidePrompt(); startFlight("Beginner")
	end
	if input.KeyCode == Enum.KeyCode.E and flightState.active then
		stopFlight()
	end
end)

if hotbarActivateEvent then
	hotbarActivateEvent.Event:Connect(function(data)
		if not data or not data.InternalName then return end
		if GliderConfig.Gliders[data.InternalName] then startFlight(data.InternalName) end
	end)
end

print("[GliderController] READY — jump, double-jump, press F to deploy | A/D bank, W/S pitch")
