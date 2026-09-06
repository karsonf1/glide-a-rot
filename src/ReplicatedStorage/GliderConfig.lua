-- ============================================================
-- GliderConfig.lua  (ReplicatedStorage — ModuleScript)
-- Flight tuning and tier registry for the thruster prototype.
-- Legacy module/tier names are retained for existing server and hotbar payloads.
--
-- To add a new glider tier:
--   1. Copy any Gliders entry below and give it a new key.
--   2. Give it ThrustAcceleration, AirDrag and MaxSpeed values.
--   3. Wire its existing gear selection flow; creature species are independent.
-- ModelName/old wing tuning remain as legacy content data during the prototype.
-- ============================================================

return {
	-- Thruster prototype. Legacy Gliders keys remain stable for the server/hotbar.
	-- MouseSensitivity is degrees per rendered pixel, not degrees/second.
	Flight = {
		MouseSensitivity = 0.12,
		InvertMouseY = false,
		ForwardYaw = math.pi,
		MaxYawDeviation = 80,
		PitchMin = -45,
		PitchMax = 40,
		AimResponse = 7,
		MaxTurnRate = 135,
		ThrottleResponse = 7,
		BankResponse = 6,
		MaxBank = 28,
		SideslipDamping = 0.8,
		CoastSteering = 0.35,
		SinkAcceleration = 6,
		AirbrakeDrag = 1.5,
		MaxFrameDt = 0.15,
		IntegrationStep = 1 / 120,
		DeployMinHeight = 8,
		DoubleJumpPower = 52,
		OrientationResponse = 14,
		MaxAngularVelocity = 8,
		BodyLean = -18,
		ThrustLean = -14,
		BodyPitchWeight = 0.5,
		Camera = {
			Height = 5,
			Distance = 18,
			LookAhead = 32,
			LookHeight = 2,
			PitchWeight = 1,
			AimResponse = 15,
			PositionResponse = 9,
			FOV = 72,
			SpeedFOV = 10,
			FOVResponse = 4,
			CollisionPadding = 0.8,
		},
		Pose = {
			ShoulderPitch = 12,
			ShoulderSpread = 14,
			ElbowBend = 30,
			HipPitch = -12,
			KneeBend = 24,
			TurnCounterpose = 12,
			SwayDegrees = 2,
			SwayRate = 2.5,
		},
		Pack = {
			PodSpacing = 0.72,
			BackOffset = 0.85,
			Width = 0.7,
			Height = 1.65,
			Depth = 0.65,
			ExhaustLength = 2.2,
			Color = { 52, 61, 73 },
			GlowColor = { 113, 215, 255 },
		},
	},
	-- ── Glider registry ──────────────────────────────────────────────────────
	-- Key  = InternalName used in CreatureDictionary / HotbarSlotActivated.
	-- All angular values are in DEGREES for easy Studio-side tuning.
	Gliders = {

		-- ─────────────────────────────────────────────────────────────────────
		Beginner = {
			ThrustAcceleration = 29,
			AirDrag = 0.0045,
			DisplayName = "Beginner Thrusters",
			ModelName   = "GliderBeginner",  -- must exist in ReplicatedStorage/GliderModels

			-- ── Airspeed ─────────────────────────────────────────────────────
			MaxSpeed    = 80,     -- studs/sec; total forward airspeed at cruise

			-- ── Glide ────────────────────────────────────────────────────────
			-- GlideAngle: passive nose-down pitch when no W/S is held.
			-- More negative = steeper, faster descent; less negative = flatter, longer glide.
			GlideAngle  = -10,   -- degrees (negative = nose down)

			-- ── Turning ──────────────────────────────────────────────────────
			-- TurnSpeed:        max yaw rate (deg/sec) at full stick / mouse input.
			-- TurnAcceleration: how fast the yaw rate climbs to TurnSpeed (lerp coeff).
			--                   Higher = snappier entry into turns.
			-- TurnDecay:        how fast yaw rate bleeds to 0 on input release (lerp coeff).
			--                   Lower = longer carving momentum; requires more anticipation.
			TurnSpeed        = 90,   -- deg/sec
			TurnAcceleration = 3.5,  -- lerp coeff (applied while input is held)
			TurnDecay        = 2.5,  -- lerp coeff (applied when input is released)

			-- ── Visual bank ──────────────────────────────────────────────────
			-- RollMultiplier: peak bank angle (degrees) when yaw rate equals TurnSpeed.
			-- RollLerpFactor: how fast the bank angle catches up to the target.
			RollMultiplier  = 28,   -- degrees at full turn rate
			RollLerpFactor  = 7.0,

			-- ── Pitch control ────────────────────────────────────────────────
			-- W pulls nose up toward PitchRange[2]; S pushes down toward PitchRange[1].
			-- PitchLerpFactor: interpolation speed toward the target pitch.
			PitchRange      = { -20, 5 },  -- [min dive, max pull-up] degrees
			PitchLerpFactor = 5.0,
		},

		-- ─────────────────────────────────────────────────────────────────────
		Advanced = {
			ThrustAcceleration = 36,
			AirDrag = 0.0043,
			DisplayName = "Advanced Thrusters",
			ModelName   = "GliderAdvanced",

			MaxSpeed    = 90,
			GlideAngle  = -6,    -- shallower glide = better lift ratio; feels more capable

			TurnSpeed        = 140,
			TurnAcceleration = 5.0,
			TurnDecay        = 1.8,  -- longer carve tail; harder to control mid-turn
			RollMultiplier   = 40,
			RollLerpFactor   = 10.0,

			PitchRange      = { -25, 10 },
			PitchLerpFactor = 7.0,
		},

		-- ─────────────────────────────────────────────────────────────────────
		-- Template for future tiers (uncomment and fill in):
		-- Elite = {
		--     DisplayName      = "Elite Glider",
		--     ModelName        = "GliderElite",
		--     MaxSpeed         = 130,
		--     GlideAngle       = -4,
		--     TurnSpeed        = 200,
		--     TurnAcceleration = 7.0,
		--     TurnDecay        = 1.2,
		--     RollMultiplier   = 55,
		--     RollLerpFactor   = 14.0,
		--     PitchRange       = { -30, 15 },
		--     PitchLerpFactor  = 10.0,
		-- },
	},
}
