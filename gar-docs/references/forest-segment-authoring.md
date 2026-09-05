<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Forest Segment Authoring Guide

How to build a corridor segment for [GAR ProcGen Corridor](../systems/proc-gen.md) in Roblox Studio. **Forest_A is done; B and C are floor-only stubs** — this is the operative doc for finishing them, and the top content task on [GAR Sprint Plan](../sprint-plan.md).

---

## Non-negotiables — read first

| Constraint | Why |
|---|---|
| **500 studs deep along +Z** | `SEGMENT_LENGTH = 500`; violating it breaks boundary detection |
| **Floor Part is 250 × 500 and named `floor`** | The streamer aligns sections by this Part, not the model pivot |
| **Parts only — no voxel Terrain** | Terrain is a singleton and cannot be cloned or shifted |
| **All BaseParts anchored** | Unanchored parts fall or drift when a section clones |
| **No geometry past X/Y bounds** | Sections tile edge-to-edge; overhangs clip neighbours |
| **Rings in a `Rings/` subfolder, tagged `PoofRing`** | CollectionService auto-wires them; the tag is required |
| **Name must match `SegmentRegistry`** | Case-sensitive lookup |

Sections are **coplanar** — no altitude offset — so floors and walls line up. Design within that.

---

## Studio folder structure

```
ServerStorage/
└── SegmentTemplates/
    └── Forest/
        ├── Forest_A  (Model)  ← done
        ├── Forest_B  (Model)  ← stub
        └── Forest_C  (Model)  ← stub
```

Each Model contains:

```
Forest_X/
├── floor        ← 250 × 500 Part; the alignment reference
├── Geometry/    ← all visual parts (trees, rocks, arches, deco)
├── Rings/       ← Parts tagged PoofRing
└── Config       ← optional StringValue: length=500, difficulty=1, biome=Forest
```

Canyon walls are **not** per-segment — `Forest_Walls` under `ServerStorage/WallTemplates/Forest/` is a universal set that streams alongside every section.

---

## Building the geometry — three approaches

### Creator Store assets

Fastest way to populate `Geometry/`. Toolbox → Creator Store tab → filter **Free** and **Verified Creator**.

Good search terms: `low poly tree`, `pine tree`, `forest rocks`, `forest floor`, `wooden arch`, `glowing mushroom`.

Combine 3–5 asset types per segment — a few large anchor pieces (big trees, rock formations) plus small filler (mushrooms, grass tufts). **Keep the flight corridor clear**: roughly center X, 10–80 studs above ground, nothing solid in it. Anchor everything after placing.

### Studio parts

Best for obstacles and structure you want full control over.

- **Arching tree tunnel** — two tall cylinders ~30 studs apart flanking the flight path, bridged overhead by a thick horizontal cylinder or wedge. Group into a Model inside `Geometry/`.
- **Rocky cliff wall** — 4–6 overlapping Blocks of varying size, stacked at an angle, rotated for irregularity. Material `Rock` or `SmoothRock`.
- **Ground plane** — one large Block at your floor level, material `Ground` or `Grass`.

Material matters more than colour for forest feel. **Never use Neon on environment parts** — reserve it for rings so they read instantly.

### Blender hero props

For organic shapes Studio parts can't match — gnarled trees, mossy arches, irregular boulders. See [Blender to Roblox Pipeline](blender-to-roblox-pipeline.md) for the full export/import path. Rule of thumb: **Blender for organic, Studio parts for boxy, never Blender for a whole segment** (too slow to iterate).

---

## Design briefs for B and C

The streamer picks randomly and avoids back-to-back repeats, so the three segments need to read as clearly different when flown in sequence.

### Forest_A — "The Arch" *(built)*
Wide, forgiving, tutorial-friendly. Flat grass floor, one large arch of two tall trees meeting overhead at center, rings through the opening. 4–5 scattered trees at 30+ studs from center X. Rings at Z≈100, 250, 400 in a straight line.

### Forest_B — "The Weave" *(to build)*
Forces banking; adds skill expression.

- Floor: two or three raised wedge blocks for gentle slope changes
- Rock cluster on the **left** at Z≈150, another on the **right** at Z≈350
- Denser tree line both sides, 15–20 studs from center X, narrowing the visual corridor
- Rings offset from center: `(X=−15, Z=100)`, `(X=+15, Z=250)`, `(X=−10, Z=400)`

### Forest_C — "The Descent" *(to build)*
Reads as flying into a ravine.

- Floor drops 10–15 studs below entry height starting at Z≈200
- Tall cliff-wall part stacks (40+ studs) both sides, framing a narrow canyon mouth at Z≈300
- Optional treetop canopy Parts above the corridor for a tunnel feel
- Rings start at entry altitude and step progressively lower with the descending line

*Caveat:* Forest_C's design predates the coplanar constraint from the streamer rewrite. An in-segment floor drop is fine — sections just can't be offset relative to each other. Confirm the exit face still meets the next section's entry cleanly.

---

## Rings

For every ring:

1. Insert a **Part** inside the segment's `Rings/` folder
2. `Shape = Cylinder`, rotated 90° on X — a flat disc facing the player. ~10 studs diameter, 1 stud thick
3. Material `Neon`, bright cyan or gold
4. `Anchored = true`, `CanCollide = false`
5. **Tag it:** View → Tag Editor, select the Part, type `PoofRing`, Enter. A green badge appears in Explorer

Verify in Tag Editor's Tag View that `PoofRing` shows the right count.

**Spacing:** never more than ~400 studs between consecutive rings unless the gap is intentional design. See [GAR Game Map](../systems/game-map.md) for the full ring math.

---

## Pre-test checklist

- [ ] Model is at `ServerStorage/SegmentTemplates/Forest/` with the exact registry name
- [ ] `floor` Part exists, 250 × 500, correctly positioned
- [ ] Geometry ends at or before Z = 500
- [ ] Every BasePart anchored
- [ ] Rings in `Rings/`, all tagged `PoofRing`, all `CanCollide = false`
- [ ] Nothing extends past the X/Y bounding box
- [ ] Segment looks reasonable mirrored on X
- [ ] Name registered in `src/ReplicatedStorage/SegmentRegistry.lua`

---

## Test flow

1. Play solo in Studio
2. Deploy the glider (`F` or double-jump)
3. Fly +Z — sections should materialize inside the haze, never in clear air
4. Watch Output for ProcGen spawn logs and any `warn()` about missing templates
5. Fly a ring — Output should show `[RingSystem] Player collected ring 'RingName'`

If rings don't fire, the tag didn't apply or the ring isn't a descendant of the cloned Model.

## Related

[Segment Authoring Convention](../decisions/2026-07-03-segment-authoring-convention.md) · [GAR ProcGen Corridor](../systems/proc-gen.md) · [GAR Ring System](../systems/ring-system.md) · [GAR Atmosphere](../systems/atmosphere.md)
