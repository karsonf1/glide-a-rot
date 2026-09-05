<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Passive Income

**Status:** 🔴 not started — but mostly pre-built

## Goal

Let players earn while away, so [Glide-A-Rot](../_index.md) retains value for people who can't play long sessions, and gives a reason to log back in.

## Why this is cheaper than it looks

The hard part is already done. `rot.Income` is baked at roll time (`species.IncomeRate × rarity.multiplier`) and stored on every rot object in DataStore — see [GAR Rot System](rot-system.md). There's no stat lookup, no recomputation, no schema migration. What's missing is:

1. A `LastLogin` timestamp in `PlayerData`
2. An accrual formula
3. A payout on join, plus optional in-session ticking

That's a small system sitting on top of a finished data layer, which makes it unusually good value per hour compared to everything else unbuilt.

## Design decisions still open

**Cadence.** Per-second while in-game, or a time-diff against `LastLogin` on join? Offline accrual is the version that actually delivers the goal (retention for short-session players); in-session ticking is mostly a satisfying number going up.

**Scope.** Does income sum over *equipped* rots, the *best* equipped rot, or the *entire* inventory? Summing equipped rots is the recommendation — it makes the hotbar decision matter and ties this system to [GAR Inventory and Equipment](inventory-and-equipment.md) rather than being a passive inventory tax. Whole-inventory accrual makes the 81 cap the only progression lever, which is a worse game.

**Cap.** Offline payout must be capped or it's an exploit surface — leave the game for a month, return to an unbounded pile. 8 hours is a sane default and reads as generous.

**Interaction with the social mechanic.** Does a server-wide rarity buff also boost income accrual, or are they independent? Not yet discussed. Independent is simpler.

## Implementation sketch

```
on join:
  elapsed = min(os.time() - profile.LastLogin, CAP_SECONDS)
  payout  = elapsed * sum(rot.Income for rot in equipped) * RATE
  AwardPoofs(player, payout)
  profile.LastLogin = os.time()

on leave:
  profile.LastLogin = os.time()   -- and save
```

Guard the whole thing in `pcall`, and write `LastLogin` on leave *and* on autosave so a server crash doesn't hand out free time.

## Balance target

A dedicated free player should earn roughly **one crate's worth every 2–3 hours** of idle time. That keeps idle income meaningful without making flying pointless — flying must always be the faster path, or the core loop is dead.

## Depends on / blocks

**Depends on:** [GAR Rot System](rot-system.md) ✅ (income already baked), a `LastLogin` field in `PlayerData`, and ideally [GAR Inventory and Equipment](inventory-and-equipment.md) being finished so "equipped" means something.
**Blocks:** nothing, but it's one of the five MVP-critical systems still at zero.

## Related

[GAR Monetization](monetization.md) · [GAR Open Questions](../open-questions.md) · [GAR Sprint Plan](../sprint-plan.md)
