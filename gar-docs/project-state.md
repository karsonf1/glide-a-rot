# GAR — Live Project State
_Last updated: 2026-06-29_

## Sprint Position
**Current week:** MVP sprint (5-week target)
**This week's focus:** Ring system + fuel economy shipped; map design + ring placement next

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
| Game map | 🟡 in progress | Design planned (see systems/game-map.md); no Studio terrain built yet; ring placement strategy defined |
| Social rot-rarity mechanic | 🔴 not started | Design decision still open (see open-questions.md) |
| Passive idle income | 🔴 not started | Rots have Income field; ticker not yet built |
| Monetization hooks | 🔴 not started | |
| Quest / progression | 🔴 not started | |

Status key: 🔴 not started · 🟡 in progress · ✅ done

## Current Blocker
Map needs to be built in Studio — ring placement, terrain, landmarks. Scripting is ahead of
art/map. Ring VFX client script (consumes RingCollected RemoteEvent) also not yet built.

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
src/StarterGui/InventoryUI/                      ← inventory display UI
src/StarterGui/CrateUI/                          ← crate roll carousel UI
```
