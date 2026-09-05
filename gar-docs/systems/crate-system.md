<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Crate System

**Status:** ✅ built · `src/ServerScriptService/CrateSystem.server.lua` + `src/StarterGui/CrateUI/`

## Goal

The gacha payoff at the end of every run — the mechanism that turns a flight into a collectible and drives session-to-session engagement. It's also the natural future monetization surface (cooldown reduction).

## How it works

Listens on `GameEvents.RunEnded`, which fires from `GliderHandler` on fuel depletion or manual stow with the run's horizontal distance. Then:

1. Roll rarity by distance via [GAR Rarity Distribution](rarity-distribution.md)
2. Roll species by `Weight` from `CreatureDictionary`
3. Bake `Income = species.IncomeRate × rarity.multiplier`
4. Write `{Species, Rarity, Income}` through `PlayerData` (respecting the 81-slot cap)
5. `CrateUI/CrateOverlay` plays the roll carousel client-side

## Decisions and why

**Built early, before flight was testable.** Crate logic and rot storage have no dependency on flight, so sequencing them first de-risked the data layer while the harder physics and map work was still unsettled. This turned out to be the right call — the data layer has been stable ever since while ProcGen was rewritten from scratch.

**Rarity rolls on distance, not at crate-open.** The roll is already determined when the crate appears; the carousel is theatre. This is deliberate — it means the reward is earned by flying, not by a second independent slot machine, and it makes the outcome server-authoritative before any client UI runs.

**Extension points are the registries, not the award logic.** Adding a rarity tier or a species means editing `RarityDistribution` or `CreatureDictionary` only. `CrateSystem` should never need to change for content.

## Monetization hook

Crate cooldown reduction is the primary planned lever, and it fits the acceleration-not-gatekeeping philosophy exactly: free players get every crate, just at a slower cadence. See [GAR Monetization](monetization.md).

## Depends on / blocks

**Depends on:** [GAR Rarity Distribution](rarity-distribution.md) ✅, [GAR Fuel System](fuel-system.md) ✅ (for `RunEnded`).
**Blocks:** [GAR Rot System](rot-system.md)'s supply of creatures; eventually the crate-timer monetization hook.

## Related

[GAR Codebase Map](../codebase-map.md) · [GAR Project State](../project-state.md)
