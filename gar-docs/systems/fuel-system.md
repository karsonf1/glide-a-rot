# Fuel System

_Added: 2026-06-29_

## Goal

Give gliding a resource-management layer. Without fuel, flying is infinite — no tension, no
reason to chase rings. Fuel makes every second of air time feel earned and gives rings a
mechanical purpose beyond aesthetics.

## How it works

### Drain
- Each player starts a run with **100 fuel** (FUEL_MAX in FuelSystem.lua)
- While the glider is deployed, fuel drains at **4 units/sec** (FUEL_DRAIN_PER_SECOND)
- That gives ~25 seconds of unassisted flight at full tank

### Depletion
- When fuel hits 0, `FuelSystem` fires `GameEvents.FuelDepleted`
- `GliderHandler` listens and runs the same end-run cleanup as a manual stow:
  - Clears `runStarts[player]` and `activeGliders[player]`
  - Computes horizontal distance
  - Fires `GameEvents.RunEnded` → triggers crate roll
- Guard in GliderHandler prevents double-fire if manual stow beats depletion to the cleanup

### Refuel
- `FuelSystem.Refuel(player, amount)` adds fuel, clamped to FUEL_MAX
- Called by RingSystem (+25 per ring) — see ring-system.md
- Future: could be called by other refuel sources (power-ups, landing pads, etc.)

### Client visibility
- `FuelUpdate` RemoteEvent fires every tick and on refuel
- Client reads it to display a fuel bar / gauge in the HUD

## Key file paths
```
src/ServerScriptService/FuelSystem.lua          ← core drain/refuel module
src/ServerScriptService/FuelSystemInit.server.lua ← creates FuelUpdate RemoteEvent, calls Init
src/ServerScriptService/GameEvents.lua          ← FuelDepleted BindableEvent defined here
src/ServerScriptService/GliderHandler.server.lua ← listens to FuelDepleted, ends run
```

## Constants (tune here)
| Constant | Value | Notes |
|---|---|---|
| FUEL_MAX | 100 | Max fuel; also starting fuel per run |
| FUEL_DRAIN_PER_SECOND | 4 | Units drained per second while deployed |
| (in RingSystem) RING_FUEL_REFILL | 25 | Fuel added per ring touch |

At current values: 4 rings = full tank, unassisted flight ≈ 25s, ring-to-ring gap ≤ 25s is
the design constraint for ring placement.

## Decisions made and why

**Per-player fuel, not per-run fuel on the glider object** — cleaner to track in a server
module table than on the glider part; avoids sync issues when glider model isn't yet placed.

**Drain loop is a task.spawn thread, not a heartbeat** — 1-second granularity is fine for
fuel (players won't notice 1s jitter). A Heartbeat connection at 60fps for a 1/sec drain
is wasteful.

**FuelDepleted fires through GameEvents (BindableEvent), not direct require** — keeps
FuelSystem decoupled from GliderHandler. Same pattern as RunEnded.

## Open questions / follow-up
- [ ] HUD fuel bar — client LocalScript needs a fuel gauge listening to FuelUpdate
- [ ] Should fuel persist between runs (partial tank on respawn) or always reset to 100?
  Current: always resets to FUEL_MAX on equip.
- [ ] Balance: 4/sec drain + 25 refill per ring is a first guess — needs in-game tuning
