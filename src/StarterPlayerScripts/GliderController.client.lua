-- ============================================================
-- GliderController.client.lua  (StarterPlayerScripts)
-- Hangglider flight controller.
--
-- Deploy:  Activate a hotbar slot whose InternalName exists in GliderConfig.Gliders.
--          (HotbarSlotActivated BindableEvent fired by InventoryWindow/LocalScript)
-- Stow:    Press E, or re-activate the same slot.
--
-- Physics: LinearVelocity drives world-space velocity;
--          AlignOrientation drives rotation (yaw + pitch + visual roll).
--          All inertia / smoothing is computed in Lua — constraint responsiveness
--          is set high so parts follow our math precisely.
--
-- Studio requirements:
--   ReplicatedStorage
--     GliderConfig       (ModuleScript — this file's data companion)
--     HotbarSlotActivated (BindableEvent — fired by inventory system)
--     GliderEquipClient  (RemoteEvent   — tells server to set PlatformStand / ownership)
--     GliderModels       (Folder, optional — glider visual models stored here)
--       GliderBeginner   (Model with a BasePart named "GliderRoot" as root)
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- Tune these values without touching flight logic below.
-- ============================================================
local CONFIG = {
	-- Follow camera
	CameraHeight      = 10,    -- studs above HumanoidRootPart
	CameraDistance    = 22,    -- studs behind HumanoidRootPart (positive = behind)
	CameraLerpFactor  = 5.0,   -- higher = camera tracks glider more tightly
	CameraLookHeight  = 2,     -- vertical offset of the camera's look-at point above HRP

	-- Mouse steering
	MouseSensitivity  = 0.25,  -- mouse delta X scale added to yaw input
	InvertMouse       = false, -- set true if mouse feels backwards

	-- Safety
	MaxDt             = 0.1,   -- dt cap (studs) to prevent physics explosions on lag spikes
}

-- ============================================================
-- Dependencies
-- ============================================================
local GliderConfig        = require(ReplicatedStorage:WaitForChild("GliderConfig"))
local hotbarActivateEvent = ReplicatedStorage:WaitForChild("HotbarSlotActivated", 10)
local gliderEquipEvent    = ReplicatedStorage:WaitForChild("GliderEquipClient",   10)

if not hotbarActivateEvent then
	warn("[Glider] HotbarSlotActivated not found — glider cannot deploy from hotbar")
end
if not gliderEquipEvent then
	warn("[Glider] GliderEquipClient RemoteEvent not found — server-side PlatformStand disabled")
end

-- ============================================================
-- Module-level character references
-- (repopulated by setupCharacter on every respawn)
-- ============================================================
local character, humanoid, hrp

-- ============================================================
-- Flight state
-- Reset each time startFlight/stopFlight is called.
-- ============================================================
local flightState = {
	active      = false,
	statsRef    = nil,   -- pointer to GliderConfig.Gliders[name]
	gliderName  = nil,   -- string; used to detect same-slot toggle

	-- Kinematics (degrees unless noted)
	yawAngle    = 0,     -- radians; accumulated world yaw
	yawRate     = 0,     -- degrees/sec; decays with inertia
	pitch       = 0,     -- degrees; interpolated toward pitchTarget each frame
	roll        = 0,     -- degrees; mirrors yawRate for visual banking

	-- Roblox instances created on deploy, destroyed on stow
	att         = nil,   -- Attachment (parent of both constraints)
	lv          = nil,   -- LinearVelocity
	ao          = nil,   -- AlignOrientation
	heartbeat   = nil,   -- RBXScriptConnection
	gliderModel = nil,   -- cloned visual model welded to character

	-- Camera
	camPos      = Vector3.zero,
}

-- ============================================================
-- Constraint creation / teardown
-- ============================================================
local function createConstraints()
	local att = Instance.new("Attachment")
	att.Name   = "GliderAtt"
	att.Parent = hrp

	-- LinearVelocity: overrides gravity entirely; descent is encoded in pitch angle.
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0    = att
	lv.MaxForce       = math.huge
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.RelativeTo     = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent         = hrp

	-- AlignOrientation: snaps HRP to our computed CFrame each Heartbeat.
	-- Responsiveness is high — all smoothing is in our yaw/pitch/roll lerps.
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0        = att
	ao.Mode               = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque          = math.huge
	ao.MaxAngularVelocity = 500
	ao.Responsiveness     = 50
	ao.Parent             = hrp

	return att, lv, ao
end

local function destroyConstraints()
	pcall(function()
		if flightState.att then flightState.att:Destroy() end
		if flightState.lv  then flightState.lv:Destroy()  end
		if flightState.ao  then flightState.ao:Destroy()  end
	end)
	flightState.att = nil
	flightState.lv  = nil
	flightState.ao  = nil
end

-- ============================================================
-- Stop flight (safe to call even if not active)
-- ============================================================
local function stopFlight()
	if not flightState.active then return end

	flightState.active    = false
	flightState.statsRef  = nil
	flightState.gliderName= nil

	if flightState.heartbeat then
		flightState.heartbeat:Disconnect()
		flightState.heartbeat = nil
	end

	destroyConstraints()

	if flightState.gliderModel then
		flightState.gliderModel:Destroy()
		flightState.gliderModel = nil
	end

	if humanoid then
		humanoid.PlatformStand = false
	end

	camera.CameraType              = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	if gliderEquipEvent then gliderEquipEvent:FireServer(false, nil) end
	print("[Glider] Stowed")
end

-- ============================================================
-- Start flight
-- ============================================================
local function startFlight(gliderName)
	if not character or not humanoid or not hrp then
		warn("[Glider] Character not ready; cannot deploy")
		return
	end

	-- Same-slot re-press = toggle off
	if flightState.active and flightState.gliderName == gliderName then
		stopFlight()
		return
	end

	if flightState.active then stopFlight() end

	local stats = GliderConfig.Gliders[gliderName]
	if not stats then
		warn("[Glider] No GliderConfig entry for:", gliderName)
		return
	end

	-- ── Initialise kinematics from current character heading ─────────────────
	local lookXZ = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if lookXZ.Magnitude > 0.001 then lookXZ = lookXZ.Unit end

	flightState.active     = true
	flightState.statsRef   = stats
	flightState.gliderName = gliderName
	flightState.yawAngle   = math.atan2(-lookXZ.X, -lookXZ.Z)  -- radians
	flightState.yawRate    = 0
	flightState.pitch      = stats.GlideAngle
	flightState.roll       = 0
	flightState.camPos     = camera.CFrame.Position

	-- ── Physics setup ─────────────────────────────────────────────────────────
	humanoid.PlatformStand = true
	local att, lv, ao = createConstraints()
	flightState.att = att
	flightState.lv  = lv
	flightState.ao  = ao

	-- ── Optional glider visual model ─────────────────────────────────────────
	local modelsFolder = ReplicatedStorage:FindFirstChild("GliderModels")
	if modelsFolder then
		local template   = modelsFolder:FindFirstChild(stats.ModelName or gliderName)
		if template then
			local clone      = template:Clone()
			local gliderRoot = clone:FindFirstChild("GliderRoot") or clone.PrimaryPart
			if gliderRoot then
				local weld  = Instance.new("WeldConstraint")
				weld.Part0  = hrp
				weld.Part1  = gliderRoot
				weld.Parent = gliderRoot
				clone.Parent = character
				flightState.gliderModel = clone
			else
				clone:Destroy()
				warn("[Glider] Model", stats.ModelName or gliderName,
					"needs a BasePart named 'GliderRoot' to attach")
			end
		end
	end

	-- ── Camera ───────────────────────────────────────────────────────────────
	camera.CameraType              = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	if gliderEquipEvent then gliderEquipEvent:FireServer(true, gliderName) end

	print("[Glider] Deployed:", gliderName,
		"| MaxSpeed:", stats.MaxSpeed,
		"| GlideAngle:", stats.GlideAngle)

	-- ══════════════════════════════════════════════════════════════════════════
	-- Heartbeat flight loop
	-- ══════════════════════════════════════════════════════════════════════════
	flightState.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not flightState.active then return end
		dt = math.min(dt, CONFIG.MaxDt)

		local s = flightState.statsRef

		-- ── Input ─────────────────────────────────────────────────────────────
		local mouseX = UserInputService:GetMouseDelta().X
		                * (CONFIG.InvertMouse and -1 or 1)

		-- A = +yaw (left), D = -yaw (right)
		local adInput = (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
		-- W = nose up, S = nose down
		local wsInput = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		              - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)

		-- ── Yaw with turn inertia ─────────────────────────────────────────────
		-- rawYaw combines keyboard steer and mouse steer
		local rawYaw     = adInput - mouseX * CONFIG.MouseSensitivity
		local targetRate = rawYaw * s.TurnSpeed   -- deg/sec

		-- Separate acceleration (key held) and decay (key released) coefficients.
		-- This is the core of the carving feel: quick ramp-up, slow bleed-off.
		local accel = (math.abs(rawYaw) > 0.01) and s.TurnAcceleration or s.TurnDecay
		flightState.yawRate  += (targetRate - flightState.yawRate) * accel * dt
		flightState.yawAngle += math.rad(flightState.yawRate) * dt

		-- ── Pitch ─────────────────────────────────────────────────────────────
		local pitchTarget
		if wsInput > 0 then
			pitchTarget = s.PitchRange[2]   -- W: pull toward max pull-up
		elseif wsInput < 0 then
			pitchTarget = s.PitchRange[1]   -- S: push toward max dive
		else
			pitchTarget = s.GlideAngle      -- no input: settle at passive glide angle
		end
		flightState.pitch += (pitchTarget - flightState.pitch) * s.PitchLerpFactor * dt

		-- ── Roll (visual bank proportional to yaw rate) ───────────────────────
		-- Flip the sign of targetRoll below if the glider banks in the wrong direction.
		local targetRoll = (flightState.yawRate / s.TurnSpeed) * s.RollMultiplier
		flightState.roll += (targetRoll - flightState.roll) * s.RollLerpFactor * dt

		-- ── Orientation ───────────────────────────────────────────────────────
		local pitchRad = math.rad(flightState.pitch)
		local rollRad  = math.rad(flightState.roll)
		local targetCF = CFrame.fromEulerAnglesYXZ(pitchRad, flightState.yawAngle, rollRad)
		flightState.ao.CFrame = targetCF

		-- ── Velocity ──────────────────────────────────────────────────────────
		-- Derived analytically from yaw + pitch so velocity always matches facing direction.
		-- No roll component in velocity (roll is purely visual banking).
		--   vx = -sin(yaw)  * cos(pitch) * speed   (world X)
		--   vy =  sin(pitch)             * speed   (world Y; negative = descending)
		--   vz = -cos(yaw)  * cos(pitch) * speed   (world Z)
		local cosPitch = math.cos(pitchRad)
		local speed    = s.MaxSpeed
		flightState.lv.VectorVelocity = Vector3.new(
			-math.sin(flightState.yawAngle) * cosPitch * speed,
			 math.sin(pitchRad)             * speed,
			-math.cos(flightState.yawAngle) * cosPitch * speed
		)

		-- ── Follow camera ─────────────────────────────────────────────────────
		-- Camera does NOT roll with the glider — omitting roll prevents nausea.
		-- Slight pitch influence (× 0.3) keeps the horizon in view on steep dives.
		local flatCF       = CFrame.fromEulerAnglesYXZ(pitchRad * 0.3, flightState.yawAngle, 0)
		local offsetWorld  = flatCF * Vector3.new(0, CONFIG.CameraHeight, CONFIG.CameraDistance)
		local targetCamPos = hrp.Position + offsetWorld
		flightState.camPos += (targetCamPos - flightState.camPos) * CONFIG.CameraLerpFactor * dt

		camera.CFrame = CFrame.new(
			flightState.camPos,
			hrp.Position + Vector3.new(0, CONFIG.CameraLookHeight, 0)
		)
	end)
end

-- ============================================================
-- Character lifecycle
-- Reconnects character references on every respawn.
-- ============================================================
local function setupCharacter(char)
	-- If flight was mid-session, the old character and its instances are gone;
	-- just nil the references without calling Destroy (already cleaned up by Roblox).
	if flightState.active then
		flightState.active    = false
		flightState.gliderName= nil
		flightState.statsRef  = nil
		if flightState.heartbeat then
			flightState.heartbeat:Disconnect()
			flightState.heartbeat = nil
		end
		flightState.att = nil; flightState.lv = nil; flightState.ao = nil
		flightState.gliderModel = nil
		camera.CameraType              = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	character = char
	humanoid  = char:WaitForChild("Humanoid")
	hrp       = char:WaitForChild("HumanoidRootPart")
	print("[Glider] Character ready")
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	task.defer(setupCharacter, player.Character)
end

-- ============================================================
-- Hotbar activation → glider deploy
-- ============================================================
if hotbarActivateEvent then
	hotbarActivateEvent.Event:Connect(function(data)
		if not data or not data.InternalName then return end
		if GliderConfig.Gliders[data.InternalName] then
			startFlight(data.InternalName)
		end
	end)
end

-- ============================================================
-- E key — emergency stow
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E and flightState.active then
		stopFlight()
	end
end)
