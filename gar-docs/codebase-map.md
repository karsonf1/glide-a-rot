<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Codebase Map

**2026-09-06 movement prototype:** `ReplicatedStorage/FlightDynamics.lua` is the pure numeric thruster integrator; `GliderConfig.Flight` holds controls/camera/pose tuning and per-tier thrust/drag is under Gliders. `StarterPlayerScripts/FlightPresentation.lua` renders local thruster pods and procedural joint transforms. `Client.client.lua` now separates rendered input, PreSimulation motion and render-step camera; it listens to server FuelUpdate for cleanup. `ReplicatedStorage/AtmosphereConfig.lua` owns the reduced-fog profiles. See the thruster decision note for the current behavior; the legacy controller descriptions below are historical.

**2026-09-05 correction:** Rojo now maps client scripts under StarterPlayer/StarterPlayerScripts. `CorridorPreload.client.lua` warms assets from the saved place's ReplicatedStorage template folders. The compatible repository flight controller remains active; a divergent Studio physics draft is archived under `handoff/2026-09-05-studio` because its required GliderConfig fields are missing. Authored geometry is in `HangglideARot.rbxl`; ServerStorage is not the current template location.

Every script in [Glide-A-Rot](_index.md), what it owns, and what it talks to. ~7,700 lines of Luau across 30 files. Read this before asking "where does X live" — and update it when a file is added or gutted.

**Root:** `C:\Users\karso\Desktop\Glide-A-Rot!\src`

---

## ReplicatedStorage — shared modules and config registries

| File | Owns |
|---|---|
| `GliderConfig.lua` | Stat registry for every glider tier. `MaxSpeed`, `GlideAngle`, `TurnSpeed`, `TurnAcceleration`, `TurnDecay`, `RollMultiplier`, `RollLerpFactor`, `PitchRange`, `PitchLerpFactor`. Read by both `GliderController` (client) and `GliderHandler` (server). Beginner + Advanced live; Elite is a commented template. |
| `RarityDistribution.lua` | The 6-tier Gaussian rarity curve. `GetWeights(distance)` → normalized weights, `Roll(distance)` → `{name, multiplier}`. `MAX_DISTANCE = 5000`. |
| `CreatureDictionary.lua` | Species registry — `IncomeRate`, `DisplayName`, `ModelName`, `Weight`. Six species defined. Rarity is deliberately *not* here; it's assigned per instance at roll time. |
| `CreatureModels/` | Actual creature Models. Only `TungTungSahur` is wired (with `Chase.server.lua` + `Script.server.lua`). |
| `SegmentRegistry.lua` | ProcGen pool config. `Forest.segments = {Forest_A, Forest_B, Forest_C}`, `Forest.walls = "Forest_Walls"`, plus a `biomeSchedule` stub for v2. |
| `HoldableToolFactory.lua` | Builds the holdable rot tools. Naming: `{InternalName}_{RarityName}`. *Undocumented in the old gar-docs.* |

---

## ServerScriptService — authority layer

| File | Owns |
|---|---|
| `PlayerData.lua` | **The data layer.** DataStore `PlayerData_V4`. Rot objects `{Species, Rarity, Income}`, 81-slot inventory cap (hardcoded twice — lines ~124 and ~271), V3 string-entry migration on load, `AwardPoofs`/`GetPoofs`, `PoofUpdate` RemoteEvent. |
| `GameEvents.lua` | BindableEvent hub. Owns `RunEnded` and `FuelDepleted`. The decoupling seam for the whole game. `RunOffsetApplied` was removed in the streamer rewrite. |
| `GliderHandler.server.lua` | Validates equip requests against `GliderConfig`, records launch position, transfers HRP network ownership to the client, computes horizontal distance on land, fires `RunEnded`, restores auto-ownership on stow. Listens to `FuelDepleted.Event`. |
| `FuelSystem.lua` | Drain/refuel module. `FUEL_MAX = 100`, `FUEL_DRAIN_PER_SECOND = 4`, `Refuel(player, amount)` clamped to max. Drain runs on a `task.spawn` thread at 1s granularity, deliberately not a Heartbeat. |
| `FuelSystemInit.server.lua` | Creates the `FuelUpdate` RemoteEvent and calls `FuelSystem.Init`. |
| `RingSystem.server.lua` | `PoofRing` CollectionService tag wiring, including `GetInstanceAddedSignal` so runtime-cloned rings auto-register. +25 fuel / +5 Poofs, 8s respawn, **per-ring** debounce. Fires `RingCollected` to the client (no consumer yet). |
| `CrateSystem.server.lua` | Listens on `RunEnded`, rolls rarity by distance, rolls species by weight, bakes `Income`, writes the rot. |
| `EquipmentHandler.server.lua` | Hotbar equip validation. Rot-to-slot assignment is the unfinished half. |
| `GameManager.server.lua` | Player join/leave lifecycle, holdable tool setup. |
| `HoldHandler.server.lua` | Holdable tool behaviour. *Undocumented in the old gar-docs.* |
| `ProcGenManager.server.lua` | Forward-streaming corridor generator — see [GAR ProcGen Corridor](systems/proc-gen.md). |
| `ProfileService.lua` | **Present but not wired.** The live data path is raw DataStore via `PlayerData`. Two scripts mention ProfileService in comments, which makes it look adopted when it isn't. Either finish the migration or delete the file. |

---

## StarterPlayerScripts — client controllers

| File | Owns |
|---|---|
| `Client.client.lua` | **The flight controller.** `LinearVelocity` + `AlignOrientation` on the HRP, `RunService.Heartbeat` physics loop, `UserInputService` bindings (double-jump or `F` to deploy, `E` to stow), yaw/pitch/roll, lerp-based air drag, arm posing via Motor6D/AnimationConstraint weld overrides, glider model attachment, camera follow. Forward lock: `MaxYawDeviation = 90`, `currentVelZ` floored at 0. |
| `GliderController.client.lua` | Client-side glider state alongside the main controller. *Undocumented in the old gar-docs.* |
| `AtmosphereController.client.lua` | Sky/horizon haze. Exists specifically to hide the ProcGen section spawn boundary — without it you watch geometry pop into clear air 2,000 studs out. Per-biome `PROFILES` table + tweenable `applyProfile()`, with a guarded `BiomeChanged` hook that stays dormant until that RemoteEvent exists. |

---

## StarterGui — UI

| Path | Owns |
|---|---|
| `InventoryUI/InventoryWindow/LocalScript.client.lua` | Rot inventory display. |
| `InventoryUI/TotalMoneyLabel/LocalScript.client.lua` | Poofs counter, driven off leaderstats. |
| `CrateUI/CrateOverlay/LocalScript.client.lua` | Crate roll carousel on run end. |
| `GliderTestUI/GliderToggleScript.client.lua` | Dev-only glider toggle. |

**Missing UI:** fuel gauge (the `FuelUpdate` event fires into nothing), ring-collect VFX (`RingCollected` likewise), equipped-rot display.

---

## Workspace — in-world prefabs

`CreatureSlotPrefab/` (with `CollectionPlatform` and `Stand` scripts) and a `TungTungSahur` instance. These are the physical rot display stands.

---

## Not in Rojo — lives only in `HangglideARot.rbxlx`

- `ServerStorage/SegmentTemplates/Forest/Forest_A|B|C`
- `ServerStorage/WallTemplates/Forest/Forest_Walls`
- `RunCorridorOrigin` marker at `(0, 100, 0)`
- `SpawnLocation` at `(0, 103, −12)` facing +Z
- The authoring copy of Forest_A parked at the corridor origin — **delete or disable this before publishing**, it overlaps the first streamed section during Play.

---

## Event Wiring at a Glance

```
deploy (F / double-jump)
  → GliderHandler validates + SetNetworkOwner(client)
  → ProcGenManager starts streaming at RunCorridorOrigin
  → FuelSystem starts draining (4/sec)

ring touch
  → RingSystem → PlayerData.AwardPoofs(+5) → PoofUpdate
              → FuelSystem.Refuel(+25)     → FuelUpdate
              → RingCollected :FireClient   → (no consumer)

fuel hits 0
  → GameEvents.FuelDepleted.Event
  → GliderHandler computes distance → GameEvents.RunEnded
  → CrateSystem rolls rarity(distance) + species(weight)
  → PlayerData writes {Species, Rarity, Income}
  → CrateUI carousel
```

---

## Related

[GAR Conventions](conventions.md) · [GAR Project State](project-state.md) · GAR Systems · [GAR Roblox Playbook](roblox-playbook.md)
