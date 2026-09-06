<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Project State

The live status board for [Glide-A-Rot](_index.md). This is the note to read first in any GAR session. Terse and current — the "why" behind anything here lives in the relevant GAR Systems note or GAR Decisions entry.

**Last verified:** 2026-09-06 for source/Git; 2026-09-05 for the authored Studio scene
**Repo:** `C:\Users\karso\Desktop\Glide-A-Rot!` · `github.com/karsonf1/glide-a-rot` (main)
**Claude/Codex boundary on main:** `f5c2a64` — PR #3. Synchronization PR #4 is now merged at `78d9377`. The new movement prototype is on `codex/thruster-flight-prototype`; see [session record](sessions/2026-09-06-thruster-flight.md).
**Scale of codebase:** ~7,700 lines of Luau across 30 script files.

---

## Sprint Position

5-week MVP target. Currently in the **map + procgen** stretch — scripting is well ahead of art and world-building, which is the persistent shape of this project.

**Current focus:** test mouse-aimed thruster flight (hold W, release to coast), lower camera/animated pose and reduced fog. Creature rewards remain at run end. Obstacle and roguelike design follows the movement prototype; see [decision](decisions/2026-09-06-thruster-flight-prototype.md).

---

## System Status

| System | Status | Where it lives | Notes |
|---|---|---|---|
| Flight mechanics | 🟡 thruster prototype | `Client.client.lua`, `FlightDynamics.lua`, `FlightPresentation.lua` | Mouse aim, W thrust/coast, S brake, independent momentum, upright lean and lower follow camera. Source/numerical checks pass; Studio feel untested |
| Fuel system | ✅ done | `FuelSystem.lua` | 100 max, 4/sec drain, `FuelDepleted` ends the run |
| Ring system | ✅ done | `RingSystem.server.lua` | `PoofRing` CollectionService tag; +25 fuel / +5 Poofs; 8s respawn |
| Poofs currency | ✅ done | `PlayerData.lua` | Award/Get + `PoofUpdate`; **no spend mechanic yet** |
| Crate / rot award | ✅ done | `CrateSystem.server.lua` | Fires on `RunEnded`; awards `{Species, Rarity, Income}` |
| Rot data storage | ✅ done | `PlayerData.lua` | DataStore `PlayerData_V4`; 81-slot cap; V3 migration |
| Rarity tier system | ✅ done | `RarityDistribution.lua` | 6 tiers, distance-Gaussian, `MAX_DISTANCE = 5000` |
| Atmosphere / haze | 🟡 needs visual verification | `AtmosphereController.client.lua`, `AtmosphereConfig.lua` | Prototype density 0.18 / haze 0.75; clearer than old 0.40 / 2.6. Needs Studio sync/test |
| ProcGen corridor | 🟡 in progress | `ProcGenManager.server.lua` | Forward streamer; all A/B/C templates have scenery. Lookup corrected to actual ReplicatedStorage roots; no rings authored in their Rings folders |
| Glider type system | 🟡 in progress | `GliderConfig.lua` | Beginner + Advanced tuned; Elite commented template; models need placing in `ReplicatedStorage/GliderModels` |
| Inventory hotbar | 🟡 in progress | `EquipmentHandler.server.lua` + `InventoryUI` | Equip validation works; rot-to-slot assignment not functional |
| Game map | 🟡 in progress | `HangglideARot.rbxl` (authored content not Rojo) | Saved scene verified. Templates in ReplicatedStorage; StreamingEnabled=false. Runtime flight remains untested |
| Ring collection VFX | 🔴 not started | — | `RingCollected` RemoteEvent already fires; no client consumer |
| Social rot-rarity mechanic | 🔴 not started | — | Design fork unresolved — see [GAR Open Questions](open-questions.md) |
| Passive idle income | 🔴 not started | — | `rot.Income` already baked; needs ticker + last-seen timestamp |
| Monetization hooks | 🔴 not started | — | Philosophy locked, no code |
| Quest / progression | 🔴 not started | — | |

Status key: 🔴 not started · 🟡 in progress · ✅ done

---

## Current Blockers

1. **Baseline playtest pending.** The stale Git lock was cleared and PR #3 merged. The saved place and source had drifted; Codex corrected template lookup and the Rojo client path. Building validates packaging only.
   PR #4 now captures the saved synchronized place on main. New thruster source still needs Studio synchronization and a Play test; the Studio connection was unavailable during implementation.
2. **Place saving remains manual.** Geometry and templates live in `HangglideARot.rbxl`; source changes alone do not update that file. Save the local Studio tab after syncing.
3. **Player ↔ corridor coupling.** Launch placement and multiplayer ownership remain unresolved. The inspected spawn is `(0, 338, -12)` and the origin is `(0, 100, 0)`, not the old documented spawn height.
4. **No authored rings.** All three template Rings folders are empty. The separate ring asset exists, but RingSystem's cooldown currently makes its invisible hitbox visible/collidable; fix this before ring playtesting.
5. **Rendering cause unproven.** Instance streaming is off. Measure actual client generation, mesh downloads and graphics behavior before choosing LOD distances; see the proposal.

---

## Content Inventory

**Creature species defined (6 of ~50 available models):** StrawberryElephant, TungTungSahur, TralaleroTralala, BombardiroCrocodilo, BallerinaCappuccina, CappuccinoAssassino. Only TungTungSahur has an actual model wired under `ReplicatedStorage/CreatureModels`. The remaining ~44 Creator Store brainrot models are sourced but not registered — see [GAR Rot System](systems/rot-system.md).

**Gliders defined:** Beginner (80 studs/sec, −10° glide, 90°/s turn), Advanced (90 studs/sec, −6° glide, 140°/s turn). Elite exists as a commented template.

**Segments present:** Forest_A (412 parts), Forest_B (324), Forest_C (412), each with a 250 x 1 x 500 floor. Wall set: `Forest_Walls` (6 mesh parts). These are under ReplicatedStorage, outside source-managed geometry. Counts confirm scenery exists, not that layouts are sufficiently varied.

---

## Known Discrepancies Worth Fixing

- `ProfileService.lua` sits in `ServerScriptService` and two scripts *mention* it in comments (`TotalMoneyLabel`, `CollectionPlatform`), but the live data path is raw DataStore via `PlayerData.lua`. Either finish the migration or delete the dead module — right now it reads like the hardening is done when it isn't. See SE-1 in [GAR Roblox Playbook](roblox-playbook.md).
- `systems/proc-gen.md` in the old gar-docs still describes the **teleport treadmill**, which was ripped out on 2026-07-03. [GAR ProcGen Corridor](systems/proc-gen.md) here reflects the actual code.
- `GliderController.client.lua` and `HoldHandler.server.lua` and `HoldableToolFactory.lua` are undocumented in gar-docs. Captured in [GAR Codebase Map](codebase-map.md).

---

## Related

[Glide-A-Rot](_index.md) · [GAR Open Questions](open-questions.md) · [GAR Sprint Plan](sprint-plan.md) · [GAR Conventions](conventions.md) · Active Priorities
