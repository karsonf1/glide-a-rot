<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Project State

The live status board for [Glide-A-Rot](_index.md). This is the note to read first in any GAR session. Terse and current — the "why" behind anything here lives in the relevant GAR Systems note or GAR Decisions entry.

**Last verified against the repo:** 2026-07-26 (read from source + git log, not from a stale doc)
**Repo:** `C:\Users\karso\Desktop\Glide-A-Rot!` · `github.com/karsonf1/glide-a-rot` (main)
**HEAD:** `743fa55` — *Rewrite ProcGen as forward streamer + integrate canyon walls* (2026-07-03)
**Scale of codebase:** ~7,700 lines of Luau across 30 script files.

---

## Sprint Position

5-week MVP target. Currently in the **map + procgen** stretch — scripting is well ahead of art and world-building, which is the persistent shape of this project.

**This week's focus:** author Forest_B and Forest_C to the segment convention, resolve player↔corridor coupling, and get the first end-to-end streaming playtest on the board.

---

## System Status

| System | Status | Where it lives | Notes |
|---|---|---|---|
| Flight mechanics | ✅ done | `Client.client.lua` | `LinearVelocity` + `AlignOrientation`; yaw capped ±90° off +Z, `currentVelZ` floored at 0 (never reverse) |
| Fuel system | ✅ done | `FuelSystem.lua` | 100 max, 4/sec drain, `FuelDepleted` ends the run |
| Ring system | ✅ done | `RingSystem.server.lua` | `PoofRing` CollectionService tag; +25 fuel / +5 Poofs; 8s respawn |
| Poofs currency | ✅ done | `PlayerData.lua` | Award/Get + `PoofUpdate`; **no spend mechanic yet** |
| Crate / rot award | ✅ done | `CrateSystem.server.lua` | Fires on `RunEnded`; awards `{Species, Rarity, Income}` |
| Rot data storage | ✅ done | `PlayerData.lua` | DataStore `PlayerData_V4`; 81-slot cap; V3 migration |
| Rarity tier system | ✅ done | `RarityDistribution.lua` | 6 tiers, distance-Gaussian, `MAX_DISTANCE = 5000` |
| Atmosphere / haze | ✅ done | `AtmosphereController.client.lua` | Built to hide the streaming spawn boundary; v2 biome hook pre-wired but dormant |
| ProcGen corridor | 🟡 in progress | `ProcGenManager.server.lua` | **Rewritten as a forward streamer** (see [Forward Streamer over Treadmill](decisions/2026-07-03-forward-streamer-over-treadmill.md)). Forest_A authored; B/C still floor-only stubs |
| Glider type system | 🟡 in progress | `GliderConfig.lua` | Beginner + Advanced tuned; Elite commented template; models need placing in `ReplicatedStorage/GliderModels` |
| Inventory hotbar | 🟡 in progress | `EquipmentHandler.server.lua` + `InventoryUI` | Equip validation works; rot-to-slot assignment not functional |
| Game map | 🟡 in progress | `.rbxlx` (not Rojo) | Forest_A aligned to corridor origin; canyon walls streaming |
| Ring collection VFX | 🔴 not started | — | `RingCollected` RemoteEvent already fires; no client consumer |
| Social rot-rarity mechanic | 🔴 not started | — | Design fork unresolved — see [GAR Open Questions](open-questions.md) |
| Passive idle income | 🔴 not started | — | `rot.Income` already baked; needs ticker + last-seen timestamp |
| Monetization hooks | 🔴 not started | — | Philosophy locked, no code |
| Quest / progression | 🔴 not started | — | |

Status key: 🔴 not started · 🟡 in progress · ✅ done

---

## Current Blockers

1. **Stale `.git/index.lock`.** A git process on the machine holds it and the sandbox can't remove it. Nothing commits until this is cleared. *Note: the trivia-game repo has the identical problem — this is a machine-level habit, not a one-off.*
2. **Uncommitted place-file work.** Forest_A geometry, the `RunCorridorOrigin` marker, spawn placement, and the ServerStorage segment templates live only inside `HangglideARot.rbxlx`. ServerStorage is **not** in the Rojo tree, so those changes only persist via Ctrl+S in Studio → commit the `.rbxlx`.
3. **Player ↔ corridor coupling.** ProcGen builds the corridor at `RunCorridorOrigin` on deploy, but nothing binds the player's position or heading to it. Current stopgap: the SpawnLocation sits at `(0, 103, −12)` facing +Z so players naturally launch onto section 0.
4. **Forest_B / Forest_C are floor-only stubs.** The streamer picks randomly from a three-name pool where two entries are empty floors — variety is currently fake.

---

## Content Inventory

**Creature species defined (6 of ~50 available models):** StrawberryElephant, TungTungSahur, TralaleroTralala, BombardiroCrocodilo, BallerinaCappuccina, CappuccinoAssassino. Only TungTungSahur has an actual model wired under `ReplicatedStorage/CreatureModels`. The remaining ~44 Creator Store brainrot models are sourced but not registered — see [GAR Rot System](systems/rot-system.md).

**Gliders defined:** Beginner (80 studs/sec, −10° glide, 90°/s turn), Advanced (90 studs/sec, −6° glide, 140°/s turn). Elite exists as a commented template.

**Segments authored:** 1 of 3 (Forest_A). Wall set: `Forest_Walls` (universal, streams per section).

---

## Known Discrepancies Worth Fixing

- `ProfileService.lua` sits in `ServerScriptService` and two scripts *mention* it in comments (`TotalMoneyLabel`, `CollectionPlatform`), but the live data path is raw DataStore via `PlayerData.lua`. Either finish the migration or delete the dead module — right now it reads like the hardening is done when it isn't. See SE-1 in [GAR Roblox Playbook](roblox-playbook.md).
- `systems/proc-gen.md` in the old gar-docs still describes the **teleport treadmill**, which was ripped out on 2026-07-03. [GAR ProcGen Corridor](systems/proc-gen.md) here reflects the actual code.
- `GliderController.client.lua` and `HoldHandler.server.lua` and `HoldableToolFactory.lua` are undocumented in gar-docs. Captured in [GAR Codebase Map](codebase-map.md).

---

## Related

[Glide-A-Rot](_index.md) · [GAR Open Questions](open-questions.md) · [GAR Sprint Plan](sprint-plan.md) · [GAR Conventions](conventions.md) · Active Priorities
