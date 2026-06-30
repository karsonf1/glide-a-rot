# Ring System

_Added: 2026-06-29_

## Goal

Rings (PoofRings) are the primary mid-flight interaction object. They serve two purposes:
1. **Refuel** — keep the player airborne by replenishing fuel (+25 per ring)
2. **Reward** — award Poofs currency (+5 per ring), building toward a future spend mechanic

Good ring placement turns a straight glide into a flight path with decisions: do I chase
that ring cluster or push for distance for a better rarity roll?

## How it works

### Placement
- Any Part in the Workspace tagged `PoofRing` via CollectionService is automatically wired
- RingSystem also listens to `CollectionService:GetInstanceAddedSignal("PoofRing")` so rings
  spawned at runtime (e.g., procedural placement later) are picked up without a restart

### On touch
1. Per-ring debounce check — skip if ring is on cooldown
2. `Players:GetPlayerFromCharacter(hit.Parent)` — skip non-player touches
3. `PlayerData.AwardPoofs(player, 5)` — adds to Poofs balance, saves, fires PoofUpdate
4. `FuelSystem.Refuel(player, 25)` — refills fuel, fires FuelUpdate to client
5. `ringCollected:FireClient(player, ring)` — client can play VFX / sound
6. Ring goes invisible + non-collidable for 8 seconds, then respawns

### Debounce model
- **Per-ring**, not per-player — two players can collect the same ring in the same window
  if they touch it before either one's 8s respawn. This is intentional: cooperative feel,
  less frustration on shared rings. If we want to change this, see notes.

## Key file paths
```
src/ServerScriptService/RingSystem.server.lua   ← all ring wiring + touch logic
src/ServerScriptService/FuelSystem.lua          ← Refuel() called by ring
src/ServerScriptService/PlayerData.lua          ← AwardPoofs() called by ring
```

## Constants (tune here)
| Constant | Value | Notes |
|---|---|---|
| RING_FUEL_REFILL | 25 | Fuel awarded per ring touch |
| RING_POOF_REWARD | 5 | Poofs awarded per ring touch |
| RING_RESPAWN_DELAY | 8 | Seconds before ring reappears |

## Ring placement strategy (starter map)
See game-map.md for detailed layout. Key principles:

- **Density near spawn** — 3–4 rings within 200 studs of launch so new players immediately
  learn the mechanic
- **Sparse midfield** — force players to choose between fuel-safe routes and high-risk
  long glides for better rarity rolls
- **Cluster near terrain obstacles** — rings just past a cliff edge or ridge reward
  committed fliers; risk/reward reads naturally
- **Ring-to-ring gap ≤ 25s of flight** — at current drain (4/sec, 25 fuel/ring = 100 fuel)
  the max safe gap is ~6 seconds unassisted; clusters should never require more than that
  without a refill opportunity nearby

## Decisions made and why

**CollectionService tags over folder hierarchy** — rings placed anywhere in Workspace
are automatically wired; designer doesn't need to put them in a specific folder. Easy to
retag in Studio with the Tag Editor plugin.

**Per-ring debounce** — avoids the "race to the ring" frustration where two players approach
simultaneously and only one gets the reward. Keeps the cooperative feel consistent with
the rest of the game's tone.

**8-second respawn** — fast enough to feel snappy, slow enough that players can't hover-loop
the same ring. At 4/sec drain, one ring extends a run by 6.25 seconds of extra flight.

## Open questions / follow-up
- [ ] Client VFX for ring collection (sparkle, pop, sound) — `RingCollected` RemoteEvent is
  already fired, needs a client LocalScript to consume it
- [ ] Procedural / scripted ring placement vs. manual Studio placement — manual for now
- [ ] Should rings also briefly boost speed (not just fuel)? TBD after first playtest
- [ ] Poofs spend mechanic — what do Poofs unlock? (currency design is separate)
