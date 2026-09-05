<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Forward Streamer over Treadmill

**Decided:** 2026-07-03 · commit `743fa55`

## Question

The original [GAR ProcGen Corridor](../systems/proc-gen.md) design was a **teleport treadmill**: keep three segments alive, and every time the player crossed a boundary, teleport them back one segment length and shift all the geometry with them. The player stays near world origin forever, avoiding float-precision drift.

In practice it stuttered badly — rubber-banding and a camera swoop at every boundary.

## Root cause

The recycle set `hrp.CFrame` **on the server**, but the HumanoidRootPart is **network-owned by the client** during flight (`GliderHandler` calls `SetNetworkOwner(player)` on equip — see [GAR Flight Mechanics](../systems/flight-mechanics.md)). Server and client were fighting over position. Every boundary crossing was a tug-of-war.

The deeper problem: the teleport existed *only* to avoid float drift, and float drift was never actually a threat. Runs are fuel-bounded to roughly 5,000 studs. Coordinates never get large enough for precision to matter. The system was paying a severe cost to solve a problem it didn't have.

## Decision

**Replace the treadmill with a forward streamer.** Sections load ahead (4) and cull behind (1) as the player flies +Z. No teleport, no world-shift, no `RunOffsetApplied`.

## What changed

- `ProcGenManager` rewritten as a forward streamer.
- Sections align by the **`floor` Part** (250 × 500), not the model pivot — authored pivots are inconsistent (A at entry, B/C at exit) and would misalign. See [Segment Authoring Convention](2026-07-03-segment-authoring-convention.md).
- Sections are **coplanar** so floors and walls line up. Cost: the old ±15-stud altitude variance is gone as a variety trick.
- Canyon walls integrated — `SegmentRegistry.Forest.walls` names a universal Left+Right set, one cloned per section, tiled along Z with organic overlap hiding the seams.
- `RunOffsetApplied` removed from `GameEvents` and `GliderHandler` — dead once nothing shifts.
- **Incidental fix:** `GliderHandler` was using `FuelDepleted:Connect`, which is invalid on a BindableEvent. It errored on every load and silently broke the entire fuel-depletion → `RunEnded` → crate/teardown chain. Now `FuelDepleted.Event:Connect`. This bug had been live and undetected.

## The general lesson

**Never write position server-side to a client-owned part.** Recorded as SE-6 in [GAR Roblox Playbook](../roblox-playbook.md).

And a second one worth keeping: the treadmill was a well-known, clever technique applied to a problem this game didn't have. Fuel-bounding the run had already solved float drift for free. Check whether the constraint you're engineering around still exists.

## Affects

[GAR ProcGen Corridor](../systems/proc-gen.md) · [GAR Atmosphere](../systems/atmosphere.md) · [GAR Fuel System](../systems/fuel-system.md) · [GAR Flight Mechanics](../systems/flight-mechanics.md) · [GAR Roblox Playbook](../roblox-playbook.md)
