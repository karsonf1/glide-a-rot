<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR ProcGen Corridor

**Status:** 🟡 in progress · `src/ServerScriptService/ProcGenManager.server.lua` + `src/ReplicatedStorage/SegmentRegistry.lua`

**2026-09-05 verification:** The saved place is now `HangglideARot.rbxl`. Templates actually live under **ReplicatedStorage**, and the Codex follow-up corrects source lookup to match. A/B/C all contain scenery; all three Rings folders are empty. StreamingEnabled is false. The old assumptions below about floor-only B/C and a guaranteed fog horizon are superseded by the [measured rendering proposal](../proposals/2026-09-05-corridor-rendering.md). No LOD architecture has been implemented.

> **This system was rewritten on 2026-07-03.** Any doc describing a "teleport treadmill" is stale — that architecture is gone. See [Forward Streamer over Treadmill](../decisions/2026-07-03-forward-streamer-over-treadmill.md) for why.

## Goal

Make runs feel infinite and varied without storing infinite geometry. The player flies continuously along world **+Z** through hand-authored sections that stream in ahead and cull behind.

## How it works now — forward streamer

Sections load **ahead** of the player and unload **behind** them. No teleporting, no world-shifting, no `RunOffsetApplied`. Because a run is fuel-bounded to roughly 5,000 studs, coordinates stay small enough that float precision was never actually a problem — which is what made the teleport trick unnecessary in the first place.

Each "section" = one floor segment (Forest_A/B/C, cloned from `ReplicatedStorage`) tiled at 500-stud intervals, **plus** one universal canyon-wall set cloned alongside it.

### Constants

| Constant | Value | Notes |
|---|---|---|
| `SEGMENT_LENGTH` | 500 | Floor Z-depth per template |
| `SECTIONS_AHEAD` | 4 | 2,000-stud lookahead — must stay beyond the fog horizon |
| `SECTIONS_BEHIND` | 1 | Look-back buffer |
| `CHECK_INTERVAL` | 0.2s | Stream tick |
| `BIOME` | `"Forest"` | v1 hardcoded |
| `FALLBACK_ORIGIN` | `(0, 100, 0)` | Used if no `RunCorridorOrigin` marker |
| `CONTAINER_NAME` | `StreamedCorridor` | Workspace folder holding live sections |

Authoring frame constants: `AUTHORED_X = 0`, `AUTHORED_FLOOR_TOP = 99.5`, `AUTHORED_WALL_ENTRY = 0`.

### Alignment — the non-obvious part

Sections align by each template's **`floor` Part (250 × 500)**, *not* the model pivot. The authored pivots are inconsistent — Forest_A's sits at the entry face, B and C's at the exit — so pivot-based placement would misalign them. Floor-edge alignment is the only reliable tiling method given the current templates.

Sections are **coplanar** — no altitude variance — so floors and walls line up. That's a cost of the wall integration: the old design's ±15-stud altitude variance is gone, and with it one of the cheap variety tricks.

### Walls

`SegmentRegistry.Forest.walls = "Forest_Walls"` names a universal Left+Right set under `ReplicatedStorage/WallTemplates/<Biome>/`. One set clones per section and tiles along Z; organic overlap in the geometry hides the seams.

### Ring integration — free

`RingSystem` listens on `CollectionService:GetInstanceAddedSignal("PoofRing")`, so rings inside a cloned segment wire themselves up automatically. No ProcGen changes needed to reward them. This is the cleanest seam in the codebase.

## Why terrain can't participate

Roblox voxel Terrain is a singleton on a fixed grid — it cannot be CFramed, cloned, or shifted. Therefore **all recycling geometry must be Parts/MeshParts**. Static terrain can still exist as distant background scenery, but it can never be part of a streamed section. This is architectural and non-negotiable.

## v1 scope

**In:** single biome (Forest), single active runner, clone-and-destroy, wall streaming, floor-based alignment.
**Out:** multiple biomes and the `biomeSchedule`, difficulty-weighted selection, `BiomeChanged` client cosmetics (scaffolded in [GAR Atmosphere](atmosphere.md) but dormant), segment pooling, obstacle segments, per-player corridors for multiplayer.

## Open

- **Author ring routes and assess layout variety.** A/B/C have scenery, but their Rings folders are empty. The RingSystem hitbox cooldown must preserve authored collision/transparency before using the existing ring asset.
- **Player↔corridor coupling** — the corridor builds at `RunCorridorOrigin` but nothing binds the player to it. See [GAR Open Questions](../open-questions.md) #1.
- Multiplayer: one shared corridor, or one window per player? v1 assumes a single runner.
- Mirroring on X was in the original design; confirm whether it survived the rewrite given the coplanar wall constraint.
- Pooling instead of clone-and-destroy, if heavy-mesh clones ever hitch despite the lookahead.

## Related

[Segment Authoring Convention](../decisions/2026-07-03-segment-authoring-convention.md) · [GAR Atmosphere](atmosphere.md) · [GAR Game Map](game-map.md) · [GAR Ring System](ring-system.md) · [GAR Flight Mechanics](flight-mechanics.md)
