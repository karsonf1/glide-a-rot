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
	GliderOffsetY     = 3,
	MaxDt             = 0.1,
	CameraFOV         = 66,
	VisualPitchOffset = -65,   -- steeper nose-down lean; clamped to -82° to avoid gimbal lock
	SinkRate          = 5,
	AirDrag           = 3.0,   -- horizontal velocity lerp rate; lower = more air resistance
	-- Arm pose (degrees, relative to each joint's default C0).
	-- Negative shoulder pitch swings arm backward in character space → points
	-- toward the control bar when character is pitched ~65° nose-down.
	ArmShoulderPitch  = -68,
	ArmShoulderSpread = 14,
	ArmElbowBend      = 58,
}

local GliderConfig        = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local hotbarActivateEvent = ReplicatedStorage:WaitForChild("HotbarSlotActivated", 10)
local gliderEquipEvent    = ReplicatedStorage:WaitForChild("GliderEquipClient",   10)

local character, humanoid, hrp

local flightState = {
	active=false, statsRef=nil, gliderName=nil, deployY=nil,
	yawAngle=0, yawRate=0, pitch=0, roll=0,
	att=nil, lv=nil, ao=nil, heartbeat=nil, gliderModel=nil,
	camPos=Vector3.zero,
	currentVelX=0, currentVelZ=0,
}

local jumpCount     = 0
local canDoubleJump = false
local promptVisible = false
local promptTimer   = 0

-- Saved Motor6D state for restore on stow
local poseJoints = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Arm / body pose
-- With PlatformStand=true the Animator freezes, so we can safely overwrite
-- Motor6D.C0 to pose the arms.  We multiply the original C0 by a rotation so
-- it's additive on top of whatever the avatar's default offset is.
-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: weld childPart to parentPart at the given joint rotation,
-- then disable the AnimationConstraint + BallSocket so they don't fight the weld.
-- Works with both the new AnimationConstraint rig and old Motor6D rigs.
local function poseJoint(parentPart, childPart, animConstraintName, ballSocketName, rotCF)
	if not parentPart or not childPart then return end
	local animC = childPart:FindFirstChild(animConstraintName)
	local ballC = childPart:FindFirstChild(ballSocketName)
	if not animC then return end  -- joint doesn't exist on this rig

	local att0 = animC.Attachment0  -- attachment on parent
	local att1 = animC.Attachment1  -- attachment on child
	if not att0 or not att1 then return end

	-- World CFrame at the joint pivot (parent side)
	local jointWorldCF   = parentPart.CFrame * att0.CFrame
	-- Desired world CFrame for the child: place att1 at the rotated joint pivot
	local desiredChildCF = jointWorldCF * rotCF * att1.CFrame:Inverse()

	-- Weld locks the child to parent at the desired pose
	local weld = Instance.new("Weld")
	weld.Part0 = parentPart
	weld.Part1 = childPart
	weld.C0 = parentPart.CFrame:Inverse() * desiredChildCF
	weld.C1 = CFrame.new()
	weld.Parent = childPart

	-- Disable physics constraints so they don't fight the weld
	if animC then animC.Enabled = false end
	if ballC  then ballC.Enabled  = false end

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
	if not upperTorso then return end  -- R6 not supported

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

-- ─────────────────────────────────────────────────────────────────────────────
-- Deploy prompt
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Physics constraints
-- MaxAngularVelocity 500→80: prevents the AlignOrientation from spinning wildly
--   to reach its target, which was the root cause of the corkscrew.
-- Responsiveness 50→20: smoother, weighted-pendulum feel.
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Flight
-- ─────────────────────────────────────────────────────────────────────────────
local function stopFlight()
	if not flightState.active then return end
	flightState.active = false; flightState.statsRef = nil
	flightState.gliderName = nil; flightState.deployY = nil
	if flightState.heartbeat then flightState.heartbeat:Disconnect(); flightState.heartbeat = nil end
	endGliderPose()
	destroyConstraints()
	if flightState.gliderModel then flightState.gliderModel:Destroy(); flightState.gliderModel = nil end
	if humanoid then humanoid.PlatformStand = false end
	jumpCount = 0; canDoubleJump = false; hidePrompt()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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
	flightState.yawRate = 0; flightState.pitch = stats.GlideAngle
	flightState.roll = 0; flightState.deployY = hrp.Position.Y

	-- Seed air-drag velocity so there's no jerk on deploy
	local initCosPitch = math.cos(math.rad(stats.GlideAngle))
	flightState.currentVelX = -math.sin(flightState.yawAngle) * initCosPitch * stats.MaxSpeed
	flightState.currentVelZ = -math.cos(flightState.yawAngle) * initCosPitch * stats.MaxSpeed

	humanoid.PlatformStand = true
	local att, lv, ao = createConstraints()
	flightState.att = att; flightState.lv = lv; flightState.ao = ao

	-- Apply prone arm pose (defer one frame so PlatformStand state settles)
	task.defer(beginGliderPose)

	local modelsFolder = ReplicatedStorage:FindFirstChild("GliderModels")
	if modelsFolder then
		local template = modelsFolder:FindFirstChild(stats.ModelName or gliderName)
		if template then
			local clone = template:Clone()
			local gliderRoot = clone:FindFirstChild("GliderRoot") or clone.PrimaryPart
			if gliderRoot then
				gliderRoot.CFrame = hrp.CFrame * CFrame.new(0, CONFIG.GliderOffsetY, 0)
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
	if gliderEquipEvent then gliderEquipEvent:FireServer(true, gliderName) end
	print("[Glider] Deployed:", gliderName, "| deployY:", math.floor(flightState.deployY))

	flightState.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not flightState.active then return end
		dt = math.min(dt, CONFIG.MaxDt)
		local s = flightState.statsRef

		-- Inputs
		local mouseX = UserInputService:GetMouseDelta().X * (CONFIG.InvertMouse and -1 or 1)
		local adInput = (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
		local wsInput = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)

		-- Yaw (turn) — TurnDecay gives the pendulum "swing back to neutral" feel
		local rawYaw = adInput - mouseX * CONFIG.MouseSensitivity
		local targetRate = rawYaw * s.TurnSpeed
		local accel = (math.abs(rawYaw) > 0.01) and s.TurnAcceleration or s.TurnDecay
		flightState.yawRate  += (targetRate - flightState.yawRate) * accel * dt
		flightState.yawAngle += math.rad(flightState.yawRate) * dt

		-- Pitch
		local pitchTarget
		if wsInput > 0 then pitchTarget = s.PitchRange[2]
		elseif wsInput < 0 then pitchTarget = s.PitchRange[1]
		else pitchTarget = s.GlideAngle end
		flightState.pitch += (pitchTarget - flightState.pitch) * s.PitchLerpFactor * dt

		-- Roll (bank) — hard capped at ±40° so character can never roll inverted
		local targetRoll = (flightState.yawRate / s.TurnSpeed) * s.RollMultiplier
		flightState.roll += (targetRoll - flightState.roll) * s.RollLerpFactor * dt
		flightState.roll = math.clamp(flightState.roll, -40, 40)

		-- Orientation
		-- VisualPitchOffset makes the character appear prone (parallel to glider wing).
		-- Clamped at -82° so we stay clear of the ±90° gimbal-lock singularity
		-- that caused the AlignOrientation to spin into a corkscrew.
		local pitchRad = math.rad(flightState.pitch)
		local rollRad  = math.rad(flightState.roll)
		local visualPitchRad = math.max(
			pitchRad + math.rad(CONFIG.VisualPitchOffset),
			math.rad(-82)
		)
		flightState.ao.CFrame = CFrame.fromEulerAnglesYXZ(visualPitchRad, flightState.yawAngle, rollRad)

		-- Velocity with air drag
		-- Lerping toward the target instead of instantly setting it gives a
		-- noticeable "pushing through air" sensation on direction changes.
		local cosPitch = math.cos(pitchRad)
		local speed    = s.MaxSpeed
		local targetVx = -math.sin(flightState.yawAngle) * cosPitch * speed
		local targetVz = -math.cos(flightState.yawAngle) * cosPitch * speed
		flightState.currentVelX += (targetVx - flightState.currentVelX) * CONFIG.AirDrag * dt
		flightState.currentVelZ += (targetVz - flightState.currentVelZ) * CONFIG.AirDrag * dt

		local vy = math.sin(pitchRad) * speed - CONFIG.SinkRate
		if flightState.deployY and hrp.Position.Y >= flightState.deployY - 0.5 then
			vy = math.min(vy, -0.5)
		end
		flightState.lv.VectorVelocity = Vector3.new(flightState.currentVelX, vy, flightState.currentVelZ)

		-- Camera
		local flatCF = CFrame.fromEulerAnglesYXZ(pitchRad * 0.25, flightState.yawAngle, 0)
		local camOffset = flatCF * Vector3.new(0, CONFIG.CameraHeight, CONFIG.CameraDistance)
		local targetCamPos = hrp.Position + camOffset
		flightState.camPos += (targetCamPos - flightState.camPos) * CONFIG.CameraLerpFactor * dt
		local fwdDir = Vector3.new(-math.sin(flightState.yawAngle), 0, -math.cos(flightState.yawAngle))
		local lookTarget = hrp.Position + fwdDir * CONFIG.CameraLookAhead + Vector3.new(0, CONFIG.CameraLookHeight, 0)
		camera.CFrame = CFrame.new(flightState.camPos, lookTarget)
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Character setup
-- ─────────────────────────────────────────────────────────────────────────────
local function setupCharacter(char)
	if flightState.active then
		flightState.active = false; flightState.gliderName = nil
		flightState.statsRef = nil; flightState.deployY = nil
		if flightState.heartbeat then flightState.heartbeat:Disconnect(); flightState.heartbeat = nil end
		endGliderPose()
		flightState.att = nil; flightState.lv = nil; flightState.ao = nil
		flightState.gliderModel = nil
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────────────────────────────────────────
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

print("[GliderController] READY — jump, double-jump, press F to deploy")
