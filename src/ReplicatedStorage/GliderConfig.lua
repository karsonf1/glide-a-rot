-- ============================================================
-- GliderConfig.lua  (ReplicatedStorage — ModuleScript)
-- Central stat registry for all hangglider tiers.
-- Required by both GliderController (client) and GliderHandler (server).
--
-- To add a new glider tier:
--   1. Copy any Gliders entry below and give it a new key.
--   2. Add that key to CreatureDictionary so it shows up in inventory.
--   3. Place the model inside ReplicatedStorage/GliderModels named ModelName.
-- ============================================================

return {
	-- ── Glider registry ──────────────────────────────────────────────────────
	-- Key  = InternalName used in CreatureDictionary / HotbarSlotActivated.
	-- All angular values are in DEGREES for easy Studio-side tuning.
	Gliders = {

		-- ─────────────────────────────────────────────────────────────────────
		Beginner = {
			DisplayName = "Beginner Glider",
			ModelName   = "GliderBeginner",  -- must exist in ReplicatedStorage/GliderModels

			-- ── Airspeed ─────────────────────────────────────────────────────
			MaxSpeed    = 55,     -- studs/sec; total forward airspeed at cruise

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
			DisplayName = "Advanced Glider",
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
