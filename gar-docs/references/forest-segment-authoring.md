# Forest Segment Authoring Guide — ProcGen v1

_For: Glide-A-Rot · Created: 2026-06-29_

This guide covers how to build the three Forest segment variations (`Forest_A`, `Forest_B`, `Forest_C`) that power the ProcGen v1 treadmill system. Each segment is a hand-authored Model in Studio that the server will clone, recycle, and vary at runtime.

---

## The Non-Negotiables (Read First)

Before touching any asset source, understand the hard constraints the script enforces:

| Constraint | Why it matters |
|---|---|
| **500 studs deep along +Z** | `SEGMENT_LENGTH = 500` in ProcGenManager — violating this breaks the recycle boundary detection |
| **Pivot at entry face center (Z = 0)** | The script calls `:PivotTo(CFrame)` to place segments; a wrong pivot means misaligned seams |
| **Parts only — no Terrain** | Terrain cannot be moved or recycled. All geometry must be Parts/Models |
| **No geometry past X/Y bounds** | System mirrors segments on the X axis (50% chance); overhangs will clip adjacent segments |
| **Rings go in a `Rings/` subfolder, tagged `PoofRing`** | CollectionService auto-wires them — no manual scripting needed, but tag is required |
| **Mirror-safe design** | The system flips X, so avoid asymmetric decorations that would look wrong mirrored (or intentionally embrace the asymmetry) |

---

## Studio Folder Structure

Set this up first, before authoring any geometry:

```
ServerStorage/
└── SegmentTemplates/
    └── Forest/
        ├── Forest_A  (Model)
        ├── Forest_B  (Model)
        └── Forest_C  (Model)
```

Each Model has this internal structure:

```
Forest_A/
├── Geometry/     ← all visual parts (trees, rocks, platforms, deco)
├── Rings/        ← Parts tagged PoofRing (fuel rings)
└── Config        ← StringValue or a ModuleScript (optional but recommended)
      length    = "500"
      difficulty = "1"
      biome     = "Forest"
```

**How to create the folder structure:**
1. In the Explorer panel, right-click `ServerStorage` → Insert Object → `Folder`, name it `SegmentTemplates`
2. Inside that, Insert Object → `Folder`, name it `Forest`
3. Inside `Forest`, Insert Object → `Model`, name it `Forest_A`
4. Repeat for `Forest_B` and `Forest_C`
5. Inside each Model, add a `Folder` named `Geometry` and another named `Rings`

---

## Setting the Pivot (Critical Step)

Every segment Model needs its **pivot at the entry face center** — this is where the script will snap the segment into place.

1. Select the `Forest_A` Model in Explorer
2. In the top toolbar, click the **Move** tool, then click **Edit Pivot** (or press `Ctrl+Shift+P`)
3. In the pivot editor, set the pivot position to the **front-center of the segment** — where a player would fly in from. Call this `(0, Y, 0)` where Y is the floor height of your segment
4. The exit face should be at Z = +500 from the pivot
5. Press **Apply** to lock the pivot

**Quick sanity check:** With the Model selected, the orange pivot gizmo should sit at the entry face, not the geometric center.

---

## Three Approaches for Building Geometry

### Approach 1 — Creator Store Assets

Best for: quickly populating Geometry/ with polished forest props (trees, rocks, bushes) without modeling anything yourself.

**Steps:**
1. In Studio, open the **Toolbox** (View → Toolbox)
2. Switch to **Creator Store** tab, search: `"forest tree"`, `"low poly tree"`, `"pine tree"`, `"cartoon tree"`
3. Filter by **Free** and **Verified Creator** for safety
4. Click an asset to insert it into Workspace (it will drop in as a Model)
5. Move it into your segment's `Geometry/` folder in Explorer
6. Resize/reposition as needed — make sure it stays within the segment's X/Y bounds
7. Anchor all Parts (`Anchored = true`) — unanchored parts will fall or shift at runtime

**Good search terms for forest variety:**
- `"forest floor"` — mossy ground patches, roots
- `"forest rocks"` — stone clusters, boulders
- `"pine tree low poly"` — Roblox-stylized evergreens
- `"wooden arch"` / `"tree arch"` — natural tunnel-like features for flight paths
- `"glowing mushroom"` — accent deco for visual interest

**Tip:** Combine 3–5 asset types per segment — some large anchor pieces (big trees, rock formations) and small filler (ground mushrooms, grass tufts). Keep the flight corridor (roughly center X, 10–80 studs above ground) clear of solid parts.

---

### Approach 2 — Homemade Parts in Studio

Best for: custom flight obstacles, platforms, and geometry you control completely.

**Core technique — wedge + block constructions:**

Roblox's Part types (Block, Wedge, Cylinder, Sphere, CornerWedge) can be combined into almost any shape using **Unions** (Model → Union) or just grouping without unioning.

**Useful part recipes for Forest:**

_Arching tree tunnel:_
- Two tall cylinders (trunk) on either side of the flight path, ~30 studs apart
- A thick Wedge or cylinder bridging them overhead (~5 studs diameter, rotated horizontally)
- Group all three into a Model inside `Geometry/`

_Rocky cliff wall (left or right edge):_
- 4–6 Block parts of varying sizes, slightly overlapping, stacked at an angle
- Material: `Rock` or `SmoothRock`
- Use the **Rotate** tool to tilt some blocks for a natural look

_Mossy platform (optional landing reference):_
- Flat Block, ~20×20 studs, Material: `Grass` or `Leafy Grass`
- Position low enough that players don't accidentally land on it and stop

_Ground plane:_
- One large Block, 300×300 studs, Height = 4 studs, at Y = 0 (your floor level)
- Material: `Ground` or `Grass`
- This is your visible floor — players fly above it, but it gives visual depth

**Coloring tips:**
- Use `BrickColor` or `Color3` on parts (Roblox has a `Forest Green` and `Bright Green` that work well)
- Material matters more than color for forest feel — `Grass`, `Leafy Grass`, `Rock`, `Wood Planks`
- Neon material = 0 use for environment parts (save it only for the rings)

---

### Approach 3 — Blender Models (Imported as Meshes)

Best for: unique hero props (a gnarled old tree, a mossy archway, a large boulder cluster) where Studio parts can't match the silhouette.

**Blender → Roblox workflow:**

**In Blender:**
1. Model the object. Keep poly count low — aim for **under 5,000 triangles** per prop for Roblox performance
2. Apply all transforms: `Ctrl+A` → Apply All Transforms (scale/rotation/location)
3. Make sure the origin (orange dot) is at the base/bottom of the model — this makes positioning in Studio predictable
4. Export: `File → Export → FBX (.fbx)`
   - Scale: `1.00` (Roblox reads FBX in cm, so you may need to scale up in Studio after import)
   - Apply Transform: ✅ checked
   - Include: Mesh only (no armatures needed for static props)

**In Roblox Studio:**
1. Go to `Home → Import 3D` (or use the Asset Manager: View → Asset Manager → right-click → Import 3D)
2. Select your `.fbx` file
3. Studio imports it as a `MeshPart` — it will appear in Workspace
4. Drag it into your segment's `Geometry/` folder
5. Set `Anchored = true`
6. Resize to fit: FBX imports often come in at wrong scale — use the Scale tool. A large tree should be roughly 20–40 studs tall
7. Check: the MeshPart should have a green tint in Studio if the mesh imported cleanly; red = problem with the mesh

**Scale calibration tip:** Place a standard Roblox character (about 5 studs tall) next to your import to check proportions visually before locking in the scale.

**What to model in Blender vs. build in Studio:**
- ✅ Blender: organic shapes (gnarled trees, mossy arches, irregular boulders, twisted roots)
- ✅ Studio parts: flat platforms, walls, floor planes, ring holders, anything boxy
- ❌ Blender: entire segments — too slow to iterate; keep Blender for hero props only

---

## Designing the Three Segments for Visual Contrast

The system picks segments randomly and avoids back-to-back repeats — so the three segments need to feel clearly different from each other when you fly through them sequentially.

### Forest_A — "The Arch" (Open, Tutorial-friendly)
**Design intent:** A wide, easy-to-navigate segment. Good as the first segment a player ever sees.

- **Floor:** Flat ground plane, Material: Grass
- **Feature:** One large arch made of two tall trees with branches meeting overhead at the center of the flight path. Rings go through the arch opening
- **Sides:** 4–5 scattered trees (from Creator Store or Blender) at varying distances from center. Leave 30+ studs clearance from center X
- **Rings (3–4):** Spaced roughly 100–120 studs apart along Z, centered on the arch opening. One ring at Z=100, one at Z=250, one at Z=400
- **Difficulty:** Easy — wide corridor, rings in a straight line

### Forest_B — "The Weave" (S-curve path)
**Design intent:** Forces the player to bank left-right, adds skill expression.

- **Floor:** Slight terrain variation — two or three raised ground blocks (Wedges) creating gentle slope changes
- **Feature:** Rock formation cluster on the left at Z=150, rock cluster on the right at Z=350 — rings weave between them
- **Trees:** Denser tree line on both sides, closer to center (15–20 studs from center X) to narrow the visual corridor
- **Rings (3–4):** Offset from center — ring 1 at (X=-15, Z=100), ring 2 at (X=+15, Z=250), ring 3 at (X=-10, Z=400). Players bank to follow the chain
- **Difficulty:** Medium — side-to-side movement required

### Forest_C — "The Descent" (Altitude drop)
**Design intent:** Takes advantage of the ±15 stud altitude variance — design this segment to feel like flying into a ravine or dipping into a clearing.

- **Floor:** Floor drops 10–15 studs below the entry Y midway through the segment (lower ground plane starting at Z=200)
- **Feature:** Tall cliff walls on both sides (rock part stacks, 40+ studs tall) framing a narrow canyon mouth at Z=300
- **Canopy:** Optional — a row of treetop Parts above the corridor that obscure the sky, giving a "tunnel" feel
- **Rings (3–4):** Start high (entry altitude), drop with the descending line — ring 1 at (Y=entry, Z=100), rings 2–3 progressively lower
- **Difficulty:** Medium — requires reading the altitude change and adjusting flight path

---

## Adding and Tagging Rings

For every ring in every segment:

1. Insert a **Part** inside the segment's `Rings/` folder
2. Shape: Cylinder (`Shape = Cylinder`), rotated 90° on X so it's a flat disc facing the player
   - Suggested size: Diameter = 10 studs, Height = 1 stud
3. Material: `Neon`, Color: bright cyan or gold — visible from distance
4. `Anchored = true`, `CanCollide = false`
5. **Tag it:**
   - View → Tag Editor (built-in plugin)
   - With the ring Part selected, type `PoofRing` in the tag field and press Enter
   - A green tag badge should appear in Explorer

**Verify:** In the Tag Editor, switch to "Tag View" and confirm `PoofRing` shows the correct count of rings.

RingSystem.server.lua auto-detects `PoofRing` tags in real-time via CollectionService — no further scripting needed. When the segment is cloned into Workspace at runtime, the rings are wired automatically.

---

## Pre-Test Checklist (Before First Playtest)

Run through this for each of the three segments before connecting them to ProcGen:

- [ ] Model is in `ServerStorage/SegmentTemplates/Forest/` with the correct name (`Forest_A`, etc.)
- [ ] Pivot is at the entry face center (Z = 0 relative to segment)
- [ ] Exit face geometry ends at or before Z = 500
- [ ] `Geometry/` folder contains all visual parts; all parts are Anchored
- [ ] `Rings/` folder contains ring parts; all rings tagged `PoofRing`, `CanCollide = false`
- [ ] No geometry extends past the X/Y bounding box of the segment
- [ ] Segment looks reasonable when mirrored — mentally flip the X axis and check nothing looks broken
- [ ] Segment name is registered in `src/ReplicatedStorage/SegmentRegistry.lua`

---

## Registering in SegmentRegistry.lua

Once all three are built, open `src/ReplicatedStorage/SegmentRegistry.lua` and confirm this:

```lua
return {
  Forest = {
    segments = { "Forest_A", "Forest_B", "Forest_C" },
  },
  biomeSchedule = {
    { distance = 0, biome = "Forest" },
  },
}
```

The names here must exactly match the Model names in `ServerStorage/SegmentTemplates/Forest/` — case-sensitive.

---

## Quick Test Flow

1. Place ProcGenManager.server.lua in SSS (if not already done by the Code agent)
2. In Studio, hit **Play** (solo test mode)
3. Equip the glider (press F to deploy)
4. Fly forward — you should see segment geometry appear ahead of you and the system should print:
   `[ProcGenManager] Spawning Forest_A` (or B/C)
5. When you cross the 500-stud boundary, you should feel a seamless teleport and a new segment spawn ahead
6. Check Output for any `warn()` messages from ProcGenManager about missing templates

If rings aren't firing, check the Output for RingSystem's `Player collected ring` message — if absent, verify the `PoofRing` tag is applied and the ring Part is a descendant of the cloned Model in Workspace.
