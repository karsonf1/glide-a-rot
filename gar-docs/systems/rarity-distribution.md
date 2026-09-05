<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Rarity Distribution

**Status:** ✅ built · `src/ReplicatedStorage/RarityDistribution.lua`

## Goal

Turn *distance flown* into *reward quality*. This module is the mathematical spine of [Glide-A-Rot](../_index.md) — it's what makes flying farther matter, and it's why [GAR Fuel System](fuel-system.md) and [GAR Ring System](ring-system.md) tuning changes the whole game's economy.

## How it works

Six tiers, each with a **center** (as a fraction of `MAX_DISTANCE = 5000` studs), a **spread** controlling how wide its bell is, and an income **multiplier**.

| Tier | Center | Spread | Multiplier |
|---|---|---|---|
| Common | 0.00 | 0.28 | 2× |
| Uncommon | 0.18 | 0.22 | 5× |
| Rare | 0.38 | 0.20 | 25× |
| Epic | 0.58 | 0.18 | 100× |
| Legendary | 0.78 | 0.16 | 500× |
| Mythical | 1.00 | 0.18 | 1000× |

`GetWeights(distance)` computes `exp(-(t - center)² / (2·spread²))` per tier at `t = clamp(distance / MAX_DISTANCE, 0, 1)`, then normalizes. `Roll(distance)` picks from that distribution.

Because the curves are Gaussian and overlapping, **no tier is ever impossible** — a short run can still hit Mythical, just at vanishing odds. That's the right feel for a collector: the lottery ticket is always live.

Note the spreads narrow as tiers get rarer (0.28 → 0.16) before widening slightly at Mythical. Rarer tiers are more sharply gated to their distance band.

## Why this matters more than it looks

Three things all key off `MAX_DISTANCE = 5000`:

1. **Map length.** If the reachable corridor is shorter than 5000 studs, the top tiers are unreachable. If much longer, everything past 5000 rolls identically and distance stops mattering.
2. **Fuel economy.** 25s unassisted at 80 studs/sec ≈ 2000 studs. Reaching 5000 requires roughly 5–6 rings — see [GAR Game Map](game-map.md).
3. **Income scaling.** The 2× → 1000× spread is a 500× range. That's steep but survivable while rarity only drives income. It becomes a balance problem the moment rarity also touches flight speed ([GAR Open Questions](../open-questions.md) #5) — the two curves would have to be retuned together.

## Tuning notes

`MAX_DISTANCE` must be tuned against the *actual* reachable corridor length once the map is real. Right now it's an assumption, not a measurement. This is a soft-launch blocker.

## Related

[GAR Rot System](rot-system.md) · [GAR Crate System](crate-system.md) · [GAR Fuel System](fuel-system.md) · [GAR Sprint Plan](../sprint-plan.md)
