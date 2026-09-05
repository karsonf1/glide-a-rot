<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Segment Authoring Convention

**Decided:** 2026-07-03

## Decision

Every biome segment Model — Forest_A/B/C and any future biome — is authored to this convention so [GAR ProcGen Corridor](../systems/proc-gen.md) can clone and tile it with no per-segment fixups:

1. **Orientation:** identity `(0, 0, 0)`. The floor's long 500-stud axis runs along world **+Z**.
2. **Pivot:** at the **entry (−Z) face center** of the floor, at floor-top height. ProcGen treats `pivot.Z + 500` as the exit boundary, so the pivot must be the entry edge — not the geometric center.
3. **Anchoring:** every descendant BasePart anchored. The recycle `PivotTo` and the X-mirror routine both assume it.
4. **Storage:** the authored Model lives at `ServerStorage/SegmentTemplates/<Biome>/<Name>`, and the name must exactly match its entry in `ReplicatedStorage/SegmentRegistry.lua` (case-sensitive).

## Why

ProcGen clones from ServerStorage and lays copies end-to-end along +Z. Identity orientation plus an entry-face pivot makes floors tile edge-to-edge with correct boundary polling. Anything else needs a per-segment correction, which is exactly the kind of hidden state that makes procgen unmaintainable.

## Corollary — Parts, never voxel Terrain

Side scenery that must recycle with a section has to be **Parts or MeshParts inside `Geometry`**. Roblox voxel Terrain is a singleton on a fixed grid: it cannot be cloned, CFramed, or shifted per-section. Static terrain can still exist as distant background, but it can never participate in streaming. This is architectural.

## Status and the honest caveat

Forest_A was converted to this convention on 2026-07-03. **Forest_B and Forest_C were not** — their pivots sit at the exit face.

Because of that inconsistency, the [Forward Streamer over Treadmill](2026-07-03-forward-streamer-over-treadmill.md) rewrite later the same day made `ProcGenManager` align sections by the **`floor` Part** rather than the model pivot. So the convention's pivot rule is currently *aspirational rather than load-bearing* — the code routes around it.

That's fine, but it should be a deliberate choice: either fix B/C's pivots and keep the convention meaningful, or formally drop rule 2 and document floor-alignment as the real contract. Right now the doc and the code disagree, which is how conventions rot.

## Affects

[GAR ProcGen Corridor](../systems/proc-gen.md) · [Forest Segment Authoring Guide](../references/forest-segment-authoring.md) · [GAR Game Map](../systems/game-map.md) · [GAR Conventions](../conventions.md)
