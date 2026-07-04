# Decision — Segment authoring convention (ProcGen treadmill)

_Date: 2026-07-03_

## Decision
Every biome segment Model (Forest_A/B/C, future biomes) is authored to this convention so
`ProcGenManager` can clone and tile it without per-segment fixups:

1. **Orientation:** identity (0,0,0). The floor's long (500-stud) axis runs along world **+Z**.
2. **Pivot:** model pivot sits at the **entry (−Z) face center** of the floor, at floor-top height.
   ProcGen does `clone:PivotTo(CFrame.new(entryPos))` and treats `pivot.Z + SEGMENT_LENGTH` (500)
   as the exit boundary, so the pivot must be the entry edge, not the center.
3. **Anchoring:** all descendant BaseParts anchored (the recycle `PivotTo` and the X-mirror routine
   assume anchored parts).
4. **Storage:** the authored Model lives in `ServerStorage/SegmentTemplates/<Biome>/<Name>` and its
   name must match the entry in `ReplicatedStorage/SegmentRegistry.lua`.

## Why
- ProcGen clones from ServerStorage and lays copies end-to-end along +Z; identity + entry-face pivot
  makes floors tile edge-to-edge with correct boundary polling.
- ServerStorage is **not** in the Rojo tree, so templates persist in the `.rbxlx` place file — save
  the place to commit template changes.

## Corollary
- **Side terrain = Parts/MeshParts, never voxel Terrain.** Voxel Terrain is a singleton and can't be
  cloned/shifted per segment; scenery that must recycle has to be part-based inside `Geometry`.

## Applied
- Forest_A converted to this convention on 2026-07-03. Forest_B/C still stubs — apply the same recipe.
