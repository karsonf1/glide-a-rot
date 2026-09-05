<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Ring System

**Status:** ✅ built (server) · 🔴 no client VFX · `src/ServerScriptService/RingSystem.server.lua`

## Goal

PoofRings are the primary mid-flight interaction. Two jobs: **refuel** (+25, keeping the player airborne) and **reward** (+5 Poofs). Good placement turns a straight glide into a series of decisions — chase the ring cluster, or push for raw distance and a better rarity roll?

## How it works

**Placement is tag-driven.** Any Part in Workspace tagged `PoofRing` via CollectionService is wired automatically. `RingSystem` also listens on `CollectionService:GetInstanceAddedSignal("PoofRing")`, so rings cloned in at runtime by [GAR ProcGen Corridor](proc-gen.md) register with zero extra work. This is the integration point that makes streamed segments free.

**On touch:**
1. Per-ring debounce check — skip if on cooldown
2. `Players:GetPlayerFromCharacter(hit.Parent)` — skip non-player touches
3. `PlayerData.AwardPoofs(player, 5)` → saves, fires `PoofUpdate`
4. `FuelSystem.Refuel(player, 25)` → fires `FuelUpdate`
5. `ringCollected:FireClient(player, ring)` → **no client consumer yet**
6. Ring goes invisible + non-collidable for 8s, then respawns

## Constants

| Constant | Value |
|---|---|
| `RING_FUEL_REFILL` | 25 |
| `RING_POOF_REWARD` | 5 |
| `RING_RESPAWN_DELAY` | 8s |

## Decisions and why

**CollectionService tags over folder hierarchy.** Rings work from anywhere in Workspace; no folder discipline required, easy to retag in the Studio Tag Editor, and runtime-cloned rings self-register.

**Per-ring debounce, not per-player.** Two players can collect the same ring inside the same 8s window. Deliberate: it avoids the "race to the ring" frustration and keeps the cooperative tone consistent with the direction [GAR Social Mechanic](social-mechanic.md) is heading.

**8-second respawn.** Fast enough to feel alive, slow enough that a player can't hover-loop one ring for infinite fuel.

## Open

- **Client VFX + sound.** `RingCollected` fires into nothing. This is the single highest juice-per-hour task on the board — see [GAR Sprint Plan](../sprint-plan.md).
- Should rings also give a brief speed boost, not just fuel? Revisit after the first playtest.
- Poofs have no sink. 35 rings × 5 = ~175 Poofs per full run, accumulating with nothing to spend on.

## Related

[GAR Fuel System](fuel-system.md) · [GAR Game Map](game-map.md) · [GAR ProcGen Corridor](proc-gen.md) · [Forest Segment Authoring Guide](../references/forest-segment-authoring.md)
