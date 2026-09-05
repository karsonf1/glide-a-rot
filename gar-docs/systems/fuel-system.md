<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Fuel System

**Status:** ✅ built · `src/ServerScriptService/FuelSystem.lua` + `FuelSystemInit.server.lua`

## Goal

Give gliding a resource-management layer. Without fuel, flight is infinite — no tension, no reason to chase rings. Fuel makes air time feel earned and gives [GAR Ring System](ring-system.md) a mechanical purpose beyond decoration.

**Fuel is the run timer.** Anything that should extend a run — rings, upgrades, monetization — routes through fuel rather than adding a second clock.

## How it works

**Drain.** Every run starts at `FUEL_MAX = 100`. While the glider is deployed, fuel drains at `FUEL_DRAIN_PER_SECOND = 4` — about 25 seconds of unassisted flight on a full tank.

**Depletion.** At 0, `FuelSystem` fires `GameEvents.FuelDepleted`. `GliderHandler` listens and runs the same end-run cleanup as a manual stow: clears `runStarts[player]` and `activeGliders[player]`, computes horizontal distance, fires `GameEvents.RunEnded` → triggers the crate roll. A guard prevents a double-fire if a manual stow beats depletion to the cleanup.

**Refuel.** `FuelSystem.Refuel(player, amount)` adds fuel clamped to `FUEL_MAX`. Currently only called by `RingSystem` at +25 per ring. Future refuel sources (power-ups, landing pads) plug in the same way.

**Client visibility.** `FuelUpdate` fires every tick and on refuel. **Nothing consumes it yet** — the HUD fuel gauge is unbuilt, which means the player currently flies a timed run with no visible timer. That's a real playability gap, not a polish item.

## Constants

| Constant | Value | Effect |
|---|---|---|
| `FUEL_MAX` | 100 | Max and starting fuel |
| `FUEL_DRAIN_PER_SECOND` | 4 | ~25s unassisted flight |
| `RING_FUEL_REFILL` (in RingSystem) | 25 | +6.25s of flight per ring |

At these values, 4 rings = a full tank, and **ring-to-ring gaps of ≤25s are the design constraint** for map layout.

## Decisions and why

**Per-player fuel in a server module table, not on the glider object.** Cleaner to track, and avoids sync issues while the glider model still isn't placed.

**Drain runs on a `task.spawn` thread, not a Heartbeat connection.** 1-second granularity is imperceptible for fuel. A 60fps Heartbeat for a per-second drain is wasted budget.

**`FuelDepleted` goes through `GameEvents` (BindableEvent), not a direct require.** Keeps `FuelSystem` decoupled from `GliderHandler`, same pattern as `RunEnded`. *Note:* this connection was silently broken for a while because it used `FuelDepleted:Connect` instead of `FuelDepleted.Event:Connect` — the fuel→crate chain never fired. Fixed 2026-07-03.

## Open

- HUD fuel gauge — a client LocalScript listening to `FuelUpdate`. High priority.
- Should fuel persist between runs, or always reset to 100? Currently always resets.
- 4/sec drain and +25 per ring are first guesses that have never been playtested.

## Related

[GAR Ring System](ring-system.md) · [GAR Flight Mechanics](flight-mechanics.md) · [GAR Game Map](game-map.md) · [GAR Crate System](crate-system.md)
