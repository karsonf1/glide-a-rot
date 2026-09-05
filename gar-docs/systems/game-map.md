<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Game Map

**Status:** 🟡 in progress · lives in `HangglideARot.rbxlx`, not in Rojo

## Where this stands

The map design went through a shift worth understanding. The original plan was a **static hand-built world** — "The Plateau", a mesa launch zone with concentric distance bands mapped to rarity. Then [GAR ProcGen Corridor](proc-gen.md) arrived and the shape changed to a **streamed corridor** of authored 500-stud sections with canyon walls.

The plateau concept isn't dead — it's the right model for a launch/hub area and for the *feel* the corridor should evoke. But the corridor is what actually generates the run. Read the plateau material below as design intent and ring-placement theory, not as a build spec.

**Built:** Forest_A authored and aligned to the corridor origin, canyon walls streaming, `RunCorridorOrigin` at `(0, 100, 0)`, `SpawnLocation` at `(0, 103, −12)` facing +Z.
**Not built:** Forest_B, Forest_C, any hub/launch area, any static background terrain.

---

## Distance zones and why they exist

`MAX_DISTANCE = 5000` studs. These bands are how a player learns the depth-vs-rarity trade without reading any code, and they should shape how sections are themed as they stream.

```
Launch Zone   0–400      Tutorial rings; wide and forgiving
Near Zone     400–1200   Dense ring clusters; teaches the mechanic
Mid Zone      1200–2800  Moderate density; first real gate
Far Zone      2800–4200  Sparse rings; the rarity payoff begins
Deep Zone     4200–5000  Rare/Mythical territory
```

These align intentionally with the tier centers in [GAR Rarity Distribution](rarity-distribution.md): Common peaks around 500 studs, Uncommon and Rare mid-range, Epic through Mythical deep.

At `MaxSpeed = 80` a 5,000-stud run takes ~62 seconds. With 25s unassisted per tank and +6.25s per ring, that's **5–6 rings minimum for a full-distance run**.

---

## Ring placement principles

These carry over cleanly from the static design to per-section authoring:

1. **Teach near spawn.** 3 rings within 200 studs of launch, visible from the spawn point. Nobody should miss these.
2. **Reward commitment.** Cluster rings just past a drop, ridge, or narrowing — risk/reward reads naturally without any tutorial text.
3. **Trail, don't line up.** Loose curves encourage banking. A straight line of rings is a straight line of no decisions.
4. **Gate with density.** A cluster right at a hard point rewards making it; punishing stalling before it.
5. **Sparse midfield.** A deliberate stretch with few rings is the "push your luck" moment — do you have the fuel to reach the next cluster?
6. **Deep payoff cluster.** The rings that matter for Rare+ runs.

### The hard constraint

At 4/sec drain and 80 studs/sec, each ring buys 6.25s ≈ 500 studs.

```
Absolute max gap:  500 studs
Safe design gap:   300–400 studs
```

Never exceed 400 studs between consecutive rings unless the gap *is* the design — see the midfield stretch above.

### Budget

A ~35-ring run at +5 Poofs each caps out at **175 Poofs per full run**. Worth remembering when designing the Poofs sink, which doesn't exist yet ([GAR Open Questions](../open-questions.md) #6).

---

## Studio implementation notes

**Tagging rings:** select the Part → View → Tag Editor → add `PoofRing`. [GAR Ring System](ring-system.md) picks it up automatically, including at runtime.

**Ring shape:** Cylinder with `Shape = Cylinder` rotated 90° on X — a flat disc facing the player. ~10 studs diameter, 1 stud thick. `Anchored = true`, `CanCollide = false`. Neon material in bright cyan or gold makes them readable at distance with zero scripting.

**Verify wiring:** watch Output for `[RingSystem] Player collected ring 'RingName'`. If it's silent, the tag didn't apply or the ring isn't a descendant of the cloned section.

**Terrain rule:** side scenery inside a streamed section must be Parts/MeshParts. Voxel Terrain cannot be cloned or shifted, so it can only ever be static distant background.

---

## Open

- Author Forest_B and Forest_C — see [Forest Segment Authoring Guide](../references/forest-segment-authoring.md)
- Is there a hub/lobby area at all, or does the player spawn straight into the corridor?
- Tune `MAX_DISTANCE` against the real reachable corridor length once B/C exist
- Delete or repurpose the Workspace authoring copy of Forest_A before publishing — it overlaps section 0 during Play

## Related

[GAR ProcGen Corridor](proc-gen.md) · [GAR Fuel System](fuel-system.md) · [GAR Atmosphere](atmosphere.md) · [GAR Sprint Plan](../sprint-plan.md)
