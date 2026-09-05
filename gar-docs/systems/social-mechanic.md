<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Social Mechanic

**Status:** 🔴 not started — design unresolved

## Goal

The signature hook. Other players' presence in your server should meaningfully change your own play: specifically, their equipped gliders and rots influence the rarity of rots rolling for everyone in the server. It's what separates [Glide-A-Rot](../_index.md) from a purely single-player collector loop, and it's the reason a populated server should feel better than an empty one.

Scale context: ~5 active players per server.

## Why it isn't built

Two orthogonal design forks, both of which change the implementation substantially. It was deliberately deferred rather than guessed at, because getting it wrong means reworking crate odds and possibly the DataStore schema after the fact.

**Fork 1 — cooperative or competitive?**
- *Cooperative:* every player's equipped rots pool to raise a shared rarity floor for the server. More players and rarer collections make everyone's rolls better.
- *Competitive:* only the single rarest rot in the server grants a buff, and players contest it. Richer dynamics, but creates a have/have-not split inside a five-person server.

**Fork 2 — per-session or persistent?**
- *Per-session:* resets on server restart. No DataStore involvement at all.
- *Persistent:* accumulates via DataStore. Deeper, but adds a schema and a whole class of sync bugs.

## Recommendation

**Cooperative + per-session.** Reasons, in order of weight:

1. **Lowest grief surface.** Competitive rarity buffs in a 5-player Roblox server means one player's presence actively degrades others' experience. That's a bad first impression at exactly the moment a new player is deciding whether to stay.
2. **No schema change.** Per-session means a server-side `ServerRarityModifier` function that reads currently-equipped rots and returns a multiplier — called at run end, before the crate roll. Zero DataStore work, and it's removable if it doesn't land.
3. **Easiest to balance.** One number, tunable live, with a legible relationship to server population.
4. **It matches the tone already set elsewhere.** [GAR Ring System](ring-system.md)'s per-ring debounce was chosen specifically so two players don't race for the same ring. Building a competitive rarity system on top of a cooperative ring system would be tonally incoherent.

Competitive and persistent variants are richer and worth revisiting post-MVP — as a layer on top, not a replacement.

## Implementation sketch (cooperative + per-session)

```
ServerRarityModifier():
  for each player in server:
    read equipped rots
  return f(count, rarity tiers present)   -- a small multiplier, 1.0x baseline

CrateSystem, at roll time:
  weights = RarityDistribution.GetWeights(distance)
  apply ServerRarityModifier() as a shift toward rarer tiers
```

Keep the modifier bounded and legible — a 1.0×–1.5× band, surfaced in the UI so players can *see* that other people are helping them. An invisible social buff is not a social mechanic.

## Depends on / blocks

**Depends on:** [GAR Rot System](rot-system.md) ✅, [GAR Glider Types](glider-types.md) (for visible in-server identity), [GAR Inventory and Equipment](inventory-and-equipment.md) (needs "equipped" to actually work).
**Blocks:** nothing structurally, but it's the hardest system to retrofit. Resolving the forks matters more than starting to code.

## Related

[GAR Open Questions](../open-questions.md) · [GAR Rarity Distribution](rarity-distribution.md) · [GAR Crate System](crate-system.md)
