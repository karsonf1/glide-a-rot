# Game Map

_Updated: 2026-06-29 — starter map design added_

## Goal

A playable overworld that makes hanggliding feel worth doing repeatedly — varied terrain, clear
visual landmarks, and ring placement that creates interesting flight decisions. The map needs to
be buildable by Karson in Studio without requiring advanced terrain skills.

---

## Starter Map Concept: "The Plateau"

A single mesa/plateau as the launch zone, with terrain that steps down in elevation as you glide
outward. Players launch off the edge and glide into a valley-and-ridge landscape below.

**Why this shape works:**
- Elevation drop at launch gives immediate speed and "oh wow" moment
- Ridgelines naturally segment the map into distinct visual zones (no need for complex biomes)
- Concentric distance bands from launch match the rarity system perfectly (near = Common, far = Rare+)
- Simple to build: flat top → steep cliff → rolling hills → flat valley → distant ridge

---

## Map Dimensions

| | Value | Notes |
|---|---|---|
| MAX_DISTANCE | 5000 studs | Max tracked flight distance (already in GliderHandler) |
| Launch plateau height | ~200 studs above valley floor | Enough drop for dramatic launch |
| Playable radius | ~2500 studs from center | Diameter = 5000; players go out, not back |
| Suggested terrain resolution | 4 studs/cell | Smooth enough, performable |

At MaxSpeed = 80 studs/sec, a 5000-stud run takes ~62 seconds unassisted. With fuel (25s
unassisted per tank, +6.25s per ring), players need 5–6 rings for a full-distance run.

---

## Zone Breakdown

```
Launch Zone      0–400 studs     Flat plateau top; spawn point; tutorial rings
Near Zone        400–1200 studs  Steep cliff descent; dense ring clusters; valley entrance
Mid Zone         1200–2800 studs Rolling hills + first ridge; moderate ring density
Far Zone         2800–4200 studs Open valley floor + second ridge; sparse rings; rarity payoff
Deep Zone        4200–5000 studs Distant landmark visible from launch; rare/mythical rolls
```

### Zone rationale against rarity system

From `RarityDistribution.lua`, rarity peaks shift with distance:
- Common peaks early (~500 studs)
- Uncommon/Rare peak mid-range (~1500–2500)
- Epic/Legendary/Mythical peak deep (~3500–5000)

Zone boundaries intentionally align so players understand the depth-vs-rarity tradeoff
without reading the code.

---

## Terrain Building Guide (Studio)

Build in this order — each step is independently testable:

1. **Plateau** — Large flat Part or terrain block (~400×400 studs, 200 studs high). Add a
   SpawnLocation on top. This is where players load in.

2. **Cliff edge** — Terrain sculpt tool: steep drop from plateau edge down to valley floor.
   One clear "launch edge" facing the main flight direction (pick North as canonical).

3. **Valley floor** — Flat terrain at the base of the cliff. ~600 studs wide. This is Near Zone.

4. **First ridge** — A long ridge (runs East–West) cutting across the valley at ~1800 studs.
   Height: ~80 studs above valley. Players must go over or around it. Creates a natural "gate".

5. **Second ridge + landmark** — Shorter ridge at ~3500 studs, plus one tall spike/spire
   (~150 studs) visible from the launch plateau. This is the Far Zone waypoint players fly toward.

6. **Subtle side features** — Scattered rock clusters, small hills: add after basic shape works.
   Don't block early; use smooth terrain fill tool for rough shapes.

**Roblox terrain tips:**
- Use the terrain editor's "Fill" tool for big base shapes, "Sculpt" for cliff edges
- Material: Grass for valley, Rock for cliffs, SmoothRock for the plateau top
- Don't stress geometry detail early — get the silhouette right, then fill in

---

## Ring Distribution

### Placement principles

1. **Teach the mechanic near spawn** — Place 3 rings within 200 studs of the plateau edge,
   visible from the spawn point. These are gimme rings; no one should miss them.

2. **Cliff descent cluster** — 5–6 rings down the cliff face at varying heights. Reward players
   for committing to the launch. Spacing: ~40–60 studs apart vertically.

3. **Valley floor trail** — 8–10 rings forming a loose path across the Near Zone. Not a
   perfectly straight line — slight curves encourage banking turns.

4. **Ridge gateway rings** — 3–4 rings right at the crest of the first ridge. Reward making it
   over; punish stalling before it.

5. **Midfield sparse stretch** — Only 4–5 rings across the Mid Zone open valley. This is the
   "push your luck" segment: do you have enough fuel to reach the second ridge's cluster?

6. **Far zone cluster** — 6–8 rings near the second ridge and landmark. High-value payoff for
   players who made it deep. These are the rings that matter for Rare+ runs.

### Ring spacing constraint

At 4/sec drain, each ring (+25 fuel) = 6.25 seconds of extra flight. At MaxSpeed 80 studs/sec:

```
Max horizontal gap between rings:  80 × 6.25 = 500 studs
Safe gap (with buffer):            ~300–400 studs
```

Never place consecutive rings more than 400 studs apart unless the gap is intentional
"danger zone" design (the midfield sparse stretch above is ~600 studs wide, which is borderline —
fuel-conscious players make it, careless ones don't).

### Total ring count estimate

| Zone | Rings | Notes |
|---|---|---|
| Launch Zone | 3 | Tutorial / gimme |
| Near Zone cliff | 6 | High density, teaches mechanic |
| Near Zone valley | 9 | Trail |
| Mid Zone ridge | 4 | Gateway rings |
| Mid Zone open | 5 | Sparse, risk zone |
| Far Zone | 8 | Deep reward cluster |
| **Total** | **~35** | Good for MVP; add more after playtesting |

35 rings × 5 Poofs = 175 Poofs maximum per full run. Keep this in mind when designing the
Poofs spend mechanic.

---

## Studio Implementation Steps

1. **Tag rings:** In Studio, select a Part and add `PoofRing` tag via the Tag Editor plugin
   (Built-in: View → Tag Editor). RingSystem.server.lua picks it up automatically.

2. **Ring part shape:** Use a Cylinder or Torus (special mesh) rotated 90° — flat disc shape,
   ~8–12 studs diameter. A thin cylinder (Height=1, Diameter=10) works well until you have a
   custom Blender mesh.

3. **Ring material:** Neon material with a bright color (cyan or gold) makes rings visible from
   a distance without any scripting. Transparency=0 when live, the server sets it to 1 on collect.

4. **Test spawn:** Start a test run, fly through rings, check output for RingSystem prints:
   `[RingSystem] Player collected ring 'RingName'` — confirms wiring worked.

---

## Decisions made and why

**Single plateau launch, outward-only flight** — simpler than a circular course; distance from
origin maps cleanly to rarity. Players glide away from spawn, not in loops.

**Manual ring placement vs. procedural** — manual for MVP. Scripted placement is faster to
iterate but produces boring uniform spacing. Manual lets us tune for visual interest and
terrain-following rings.

**Ridgelines as natural gates** — creates visible goals during flight ("I can see that ridge,
I want to make it there") without scripted waypoints. Emergent pacing.

## Depends on / blocks
- Depends on: flight mechanics testable (done), fuel system (done), ring system (done)
- Blocks: true playtest with real feel; Poofs economy balance; social mechanic (needs other players in a real map)
