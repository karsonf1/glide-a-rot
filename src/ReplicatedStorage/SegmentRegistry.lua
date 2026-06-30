-- ============================================================
-- SegmentRegistry.lua  (ReplicatedStorage — ModuleScript)
-- Segment pool configuration for ProcGenManager's treadmill.
--
-- Segment names must match Model names under
--   ServerStorage/SegmentTemplates/<biome>/
--
-- v1: Forest only. Biome switching reads biomeSchedule in v2.
-- ============================================================

return {
	Forest = {
		segments = { "Forest_A", "Forest_B", "Forest_C" },
		-- future: per-segment weights for difficulty-based selection
	},

	-- Distance thresholds that switch the active pool. v1 uses Forest only.
	biomeSchedule = {
		{ distance = 0, biome = "Forest" },
		-- { distance = 2000, biome = "Desert" },  -- v2
	},
}
