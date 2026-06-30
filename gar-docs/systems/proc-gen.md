# Procedural Segment Generation

_Added: 2026-06-29_

## Goal

Make runs feel infinite and varied without storing infinite geometry. Players glide through a
recycling window of hand-authored segments that get shuffled, optionally mirrored, and
altitude-varied to feel different every run. The system also provides the foundation for biome
switching as the player flies deeper.

---

## Core Constraint: Terrain Can't Move

Roblox Terrain is a fixed voxel grid — you cannot CFrame it, move it, or recycle it. Therefore:

- **All interactive geometry (rings, obstacles, platforms) must be Parts/Models**, not Terrain.
- Terrain can still exist as a static background/landscape for visual depth — cliffs, hills in the
  distance — but it doesn't participate in the treadmill loop.
- This is a fundamental architectural choice: build segments from Parts, not Terrain voxels.

---

## The Treadmill Loop

Rather than spawning geometry infinitely far from origin (which causes floating-point precision
errors and wastes memory), we keep a **fixed play window** of N active segments:

```
[ Seg A ] [ Seg B ] [ Seg C ]   ← 3 segments live at once
              ^ player here
```

When the player clears Seg A's end boundary:
1. **Teleport player back** by exactly one `SEGMENT_LENGTH` along the run axis (Z)
2. **Shift all active segment instances** back by the same offset — world stays consistent
3. **Spawn new Seg D** at the front (clone from ServerStorage template pool)
4. **Destroy old Seg A** (or pool it for reuse later)

From the player's perspective: nothing changed. They continue flying. This also keeps the player
near world origin, avoiding floating-point drift in physics.

### Why teleport works here

Flight uses `LinearVelocity` (a constraint, not a position delta). Teleporting the
`HumanoidRootPart` preserves the constraint's target velocity — the player doesn't stutter.
We must also offset `runStart` in GliderHandler so distance tracking stays accurate.

---

## Segment Template Structure

Each segment lives in `ServerStorage/SegmentTemplates/<BiomeName>/` as a **Model** with:

```
SegmentModel/
├── Geometry/         ← all visual Parts (platforms, arches, rocks, deco)
├── Rings/            ← Parts tagged PoofRing (CollectionService auto-wires them)
├── Config (StringValue or ModuleScript)
│     length = 500         ← stud depth along Z axis
│     difficulty = 1       ← 1=easy, 2=medium, 3=hard (future: weight selection by distance)
│     biome = "Forest"
└── (optional) EntryMarker / ExitMarker  ← invisible Parts marking segment boundaries
```

**Key integration point:** `RingSystem.server.lua` already listens to
`CollectionService:GetInstanceAddedSignal("PoofRing")` — any ring cloned into Workspace at
runtime is automatically wired for fuel + Poofs rewards. No changes to RingSystem needed.

### Authoring segments in Studio

1. Build geometry in a Model inside `ServerStorage/SegmentTemplates/<Biome>/`
2. Place ring Parts inside `Rings/` and tag each with `PoofRing` via the Tag Editor
3. Align segment along **+Z axis**: entry face at Z=0, exit face at Z=SEGMENT_LENGTH
4. Origin of the Model (PrimaryPart or pivot) at the entry face center
5. Register the segment name in `SegmentRegistry` (see below)

Segments should be **modular rectangles** — no geometry sticking out past the X/Y bounds so
adjacent segments don't clip each other.

---

## SegmentRegistry (ModuleScript)

`src/ReplicatedStorage/SegmentRegistry.lua`

```lua
return {
  Forest = {
    segments = { "Forest_A", "Forest_B", "Forest_C", "Forest_Straight" },
    -- future: weights per segment for difficulty-based selection
  },
  Desert = {
    segments = { "Desert_A", "Desert_B" },
  },
}

-- Biome schedule: which biome becomes active at each distance threshold
-- ProcGenManager reads this to know when to switch pools
BIOME_SCHEDULE = {
  { distance = 0,    biome = "Forest" },
  { distance = 2000, biome = "Desert" },
}
```

---

## ProcGenManager (Server Script)

`src/ServerScriptService/ProcGenManager.server.lua`

### Responsibilities

| Responsibility | How |
|---|---|
| Maintain segment window | Keep N=3 segments cloned and positioned in Workspace |
| Detect boundary crossing | Poll player Z position every heartbeat tick |
| Recycle segments | On boundary cross: teleport player, shift all segments, spawn new front, destroy tail |
| Pick next segment | Weighted random from current biome pool (v1: uniform random) |
| Apply variance | Mirror flag (50% chance), altitude offset (±ALTITUDE_VARIANCE studs) |
| Biome switching | Check BIOME_SCHEDULE against cumulative player distance; swap pool on threshold |
| Notify client | Fire `BiomeChanged` RemoteEvent for cosmetic transitions (fog, music, lighting) |
| Distance offset | Expose `GetRunOffset(player)` so GliderHandler can correct distance math after teleports |

### Key constants

```lua
local SEGMENT_LENGTH    = 500    -- studs; must match segment template Z depth
local WINDOW_SIZE       = 3      -- segments alive at once
local ALTITUDE_VARIANCE = 15     -- ± studs to shift incoming segment vertically
local RUN_AXIS          = "Z"    -- direction of travel (canonically +Z)
```

### Teleport implementation detail

```lua
-- When player crosses boundary:
local offset = Vector3.new(0, 0, -SEGMENT_LENGTH)
hrp.CFrame = hrp.CFrame + offset          -- teleport player
for _, seg in activeSegments do
    seg:PivotTo(seg:GetPivot() + offset)  -- shift all geometry
end
-- Also shift runStart so GliderHandler distance tracking stays correct:
GameEvents.RunOffsetApplied:Fire(player, offset)
```

GliderHandler listens to `RunOffsetApplied` and adjusts `runStarts[player]` by the same offset.

---

## Variance Tricks (Making Segments Feel Different)

| Trick | Cost | Effect |
|---|---|---|
| Random pick from pool | None | Different geometry each time |
| Horizontal mirror (flip X) | Negligible | Doubles effective segment variety |
| Altitude offset ±15 studs | Negligible | Changes flight line, feels like new terrain |
| Pool shuffle (no repeat) | Trivial | Prevents same segment back-to-back |
| Difficulty weighting by distance | Small | Harder segments appear deeper in run |

For v1: random pick + mirror flag + altitude offset. Difficulty weighting comes in v2.

---

## Biome Transitions

Biomes are segment pool swaps. The transition is:
1. ProcGenManager detects cumulative distance crosses a `BIOME_SCHEDULE` threshold
2. Switches `currentBiome` → next pool; next segment draw comes from the new pool
3. Fires `BiomeChanged` RemoteEvent to client (client handles fog/music lerp)
4. Optional: use a designated "transition segment" type that blends both biome aesthetics

For v1: single biome (Forest). Biome schedule wired in v2.

---

## Integration Map

| System | Interaction | Notes |
|---|---|---|
| RingSystem | Rings tagged in segment templates auto-wire on clone | No changes needed |
| FuelSystem | No direct tie | Ring fuel rewards handled by RingSystem as normal |
| GliderHandler | Listens to `RunOffsetApplied`; adjusts `runStarts[player]` | Needed for correct distance/rarity |
| RarityDistribution | Uses distance from GliderHandler; unchanged | Rarity curve still works correctly |
| Client.client.lua | Receives `BiomeChanged` for cosmetics | v2; no changes in v1 |
| CrateSystem | Fires on `RunEnded`; unaffected | Distance passed from GliderHandler; still correct |

---

## v1 Scope (ProcGenManager v1)

**In scope:**
- Single biome (Forest), 3–4 hand-made segment templates in Studio
- 3-segment window, recycling loop, teleport trick
- SegmentRegistry ModuleScript
- Mirror flag + altitude variance
- `RunOffsetApplied` BindableEvent + GliderHandler patch

**Out of scope for v1:**
- Multiple biomes / biome schedule
- Difficulty-weighted segment selection
- Client cosmetic transitions (BiomeChanged)
- Segment pooling/reuse (destroy+clone is fine for v1)
- Obstacle segments (rings-only segments first)

---

## Decisions made and why

**Teleport trick over infinite spawning** — Keeps player near origin; no float precision issues;
segment positions stay in reasonable coordinate ranges for physics. Clean boundary.

**Parts over Terrain for segments** — Terrain cannot be moved. This is non-negotiable.
Static terrain can still exist as background scenery.

**Server-only segment management** — Rings have collision + economy logic; all segment geometry
must exist on server. Client receives cosmetic events only.

**SegmentRegistry as ModuleScript in ReplicatedStorage** — Client may eventually need biome
info for cosmetics. Putting it in RS avoids duplication. Server imports it directly.

**3-segment window** — One behind player (cleanup buffer), one current, one ahead (pre-loaded).
Minimizes pop-in without holding too many instances in memory.

---

## Open questions / follow-up

- [ ] How many starter Forest segments do we want before first playtest? (3–4 recommended)
- [ ] Should transition segments between biomes be their own type, or just visual skin swaps?
- [ ] Difficulty weighting: tie to distance thresholds or to rarity tier unlocks?
- [ ] What happens to in-flight rings when a segment shifts (teleport)? Test: rings should move
      with the segment since they're children of the segment Model
- [ ] Multi-player: does each player get their own segment window, or is the world shared?
      (v1 assumption: single-player run; revisit for multiplayer)
