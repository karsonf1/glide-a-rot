# GAR — Live Project State
_Last updated: 2026-07-03 (session 3)_

## Sprint Position
**Current week:** MVP sprint (5-week target)
**This week's focus:** ProcGen v1 — Forest_A authored & wired to the treadmill; next: author Forest_B/C to the same convention, resolve player↔corridor coupling, first infinite-treadmill playtest

## System Status

| System | Status | Notes |
|---|---|---|
| Flight mechanics | ✅ done | Client.client.lua — physics, camera, arm pose, double-jump → deploy, F/E. Forward-lock: heading launches down +Z, steer ±90° (full lateral), Vz floored at 0 (no reverse). NOTE: running Studio session may hold an older copy — Rojo re-sync needed |
| Crate / rot award | ✅ done | CrateSystem.server.lua — runs on RunEnded; awards rot with species + rarity + baked income |
| Rot data storage | ✅ done | PlayerData.lua — DataStore V4, rot objects {Species, Rarity, Income}, 81-slot cap, V3 migration |
| Rarity tier system | ✅ done | RarityDistribution.lua — 6 tiers (Common→Mythical), distance-based Gaussian bell curve |
| Fuel system | ✅ done | FuelSystem.lua — 100 max, 4/sec drain, FuelDepleted event ends run; FuelUpdate RemoteEvent to client |
| Ring system | ✅ done | RingSystem.server.lua — CollectionService PoofRing tag; +25 fuel +5 Poofs per touch; 8s respawn; per-ring debounce |
| Poofs currency | ✅ done | PlayerData AwardPoofs/GetPoofs; PoofUpdate RemoteEvent; no spend mechanic yet |
| Glider type system | 🟡 in progress | GliderConfig.lua has Beginner + Advanced stats; server handler tracks runs; models need placing in Studio (GliderModels folder in RS) |
| Inventory hotbar | 🟡 in progress | EquipmentHandler.server.lua validates equip; InventoryUI exists; rot-to-slot assignment not yet functional |
| ProcGen v1 | 🟡 in progress | ProcGenManager live. Forest_A authored, oriented to +Z identity, pivot at entry face, anchored, and synced into ServerStorage template. RunCorridorOrigin marker added (0,100,0). Forest_B/C still floor-only stubs. Convention: decisions/2026-07-03-segment-authoring-convention.md |
| Game map | 🟡 in progress | Forest_A segment built & aligned to spawn/corridor origin. Side terrain must be Parts, not voxel Terrain (recycles with treadmill). Ring placement strategy defined (systems/game-map.md) |
| Social rot-rarity mechanic | 🔴 not started | Design decision still open (see open-questions.md) |
| Passive idle income | 🔴 not started | Rots have Income field; ticker not yet built |
| Monetization hooks | 🔴 not started | |
| Quest / progression | 🔴 not started | |

Status key: 🔴 not started · 🟡 in progress · ✅ done

## Current Blocker
1) **Save + commit pending** — map/geometry changes (Forest_A, template, RunCorridorOrigin, spawn) live only in `HangglideARot.rbxlx`; press Ctrl+S in Studio, then commit. A stale `.git/index.lock` is currently blocking git — clear it first.
2) **Player↔corridor coupling** unresolved (see open-questions.md) — needed for a clean first playtest.
3) **Forest_B/C** still need authoring to the segment convention. Ring VFX still pending.

## Key File Paths
```
src/StarterPlayerScripts/Client.client.lua       ← flight controller (main client)
src/ServerScriptService/PlayerData.lua           ← DataStore V4, rot inventory
src/ServerScriptService/CrateSystem.server.lua   ← rot award on run-end
src/ServerScriptService/GliderHandler.server.lua ← server-side equip + distance tracking
src/ServerScriptService/EquipmentHandler.server.lua ← hotbar equip validation
src/ServerScriptService/GameManager.server.lua   ← player join/leave + holdable tools
src/ServerScriptService/GameEvents.lua           ← BindableEvent RunEnded
src/ReplicatedStorage/GliderConfig.lua           ← glider stats registry
src/ReplicatedStorage/RarityDistribution.lua     ← distance-based rarity roll
src/ReplicatedStorage/CreatureDictionary.lua     ← creature data (species, weight, income)
src/ReplicatedStorage/SegmentRegistry.lua        ← procgen segment pool config (Forest_A/B/C)
src/ServerScriptService/ProcGenManager.server.lua ← treadmill manager (+Z corridor, recycles window)
ServerStorage/SegmentTemplates/Forest/           ← authored segment Models (NOT in Rojo — lives in .rbxlx)
src/StarterGui/InventoryUI/                      ← inventory display UI
src/StarterGui/CrateUI/                          ← crate roll carousel UI
```
