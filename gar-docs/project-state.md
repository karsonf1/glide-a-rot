# GAR — Live Project State
_Last updated: 2026-06-29 (session 2)_

## Sprint Position
**Current week:** MVP sprint (5-week target)
**This week's focus:** ProcGen v1 — build Forest segments in Studio, run Code agent handoff, first playtest of infinite treadmill

## System Status

| System | Status | Notes |
|---|---|---|
| Flight mechanics | ✅ done | Client.client.lua — physics (LinearVelocity + AlignOrientation), camera, arm pose, double-jump → deploy, F to deploy, E to stow |
| Crate / rot award | ✅ done | CrateSystem.server.lua — runs on RunEnded; awards rot with species + rarity + baked income |
| Rot data storage | ✅ done | PlayerData.lua — DataStore V4, rot objects {Species, Rarity, Income}, 81-slot cap, V3 migration |
| Rarity tier system | ✅ done | RarityDistribution.lua — 6 tiers (Common→Mythical), distance-based Gaussian bell curve |
| Fuel system | ✅ done | FuelSystem.lua — 100 max, 4/sec drain, FuelDepleted event ends run; FuelUpdate RemoteEvent to client |
| Ring system | ✅ done | RingSystem.server.lua — CollectionService PoofRing tag; +25 fuel +5 Poofs per touch; 8s respawn; per-ring debounce |
| Poofs currency | ✅ done | PlayerData AwardPoofs/GetPoofs; PoofUpdate RemoteEvent; no spend mechanic yet |
| Glider type system | 🟡 in progress | GliderConfig.lua has Beginner + Advanced stats; server handler tracks runs; models need placing in Studio (GliderModels folder in RS) |
| Inventory hotbar | 🟡 in progress | EquipmentHandler.server.lua validates equip; InventoryUI exists; rot-to-slot assignment not yet functional |
| ProcGen v1 | 🟡 in progress | Code agent handoff written (sessions/2026-06-29-procgen-handoff.md); Forest_A/B/C segments not yet built in Studio; see references/forest-segment-authoring.md |
| Game map | 🟡 in progress | Design planned (see systems/game-map.md); no Studio terrain built yet; ring placement strategy defined |
| Social rot-rarity mechanic | 🔴 not started | Design decision still open (see open-questions.md) |
| Passive idle income | 🔴 not started | Rots have Income field; ticker not yet built |
| Monetization hooks | 🔴 not started | |
| Quest / progression | 🔴 not started | |

Status key: 🔴 not started · 🟡 in progress · ✅ done

## Current Blocker
ProcGen v1 needs Forest_A/B/C segment Models built in Studio before the Code agent script can be tested. Build segments first (see references/forest-segment-authoring.md), then run the Code agent with sessions/2026-06-29-procgen-handoff.md. Map terrain and ring VFX also still pending.

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
src/ReplicatedStorage/SegmentRegistry.lua        ← procgen segment pool config (CREATE THIS)
src/ServerScriptService/ProcGenManager.server.lua ← treadmill manager (CREATE THIS)
src/StarterGui/InventoryUI/                      ← inventory display UI
src/StarterGui/CrateUI/                          ← crate roll carousel UI
```
