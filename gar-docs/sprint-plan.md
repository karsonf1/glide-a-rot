<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Sprint Plan

The 5-week MVP shape for [Glide-A-Rot](_index.md), plus what comes after. Use it to decide what's next; defer to [GAR Project State](project-state.md) for where things actually stand today.

---

## The Honest Position

The original 5-week plan assumed map and flight would be settled in week 1 and the rest would follow. What actually happened: scripting ran far ahead of art and world-building, and the ProcGen corridor absorbed most of weeks 1–2 (including a full architecture rewrite). **The real bottleneck for this project is authored content in Studio, not code.** Plan accordingly — the fastest path to a playable MVP is authoring Forest_B/C and finishing the hotbar, not starting a new system.

---

## Week-by-week

| Week | Focus | Deliverables |
|---|---|---|
| 1 | Map & flight | Glider model finalized, flight physics validated, corridor generation working |
| 2 | Creature / rarity integration | Rot equip flow, crate → rot on run end, rot-to-slot assignment |
| 3 | Economy & monetization hooks | Poofs spend mechanic, Robux products, cooldown/fuel reductions, cosmetics scaffold |
| 4 | UI polish | Hotbar, crate UI, currency + fuel display, equipped-rot display, ring VFX |
| 5 | Soft-launch prep | Balancing pass, DataStore hardening (SE-1), server stress test |

---

## Recommended Next Five Tasks

Ordered so each unblocks the next, and each fits one session.

1. **Clear the `.git/index.lock`, save the place in Studio, commit.** Everything else is at risk until the map work is in version control. Two repos are currently in this state.
2. **Author Forest_B ("The Weave") and Forest_C ("The Descent")** to the convention in [Forest Segment Authoring Guide](references/forest-segment-authoring.md). The streamer is picking from a pool where two of three entries are empty floors, so "variety" is currently a lie.
3. **Decide player↔corridor coupling** (see [GAR Open Questions](open-questions.md) #1) and implement it. This is the last thing between here and a clean playtest.
4. **First full streaming playtest.** Fly the corridor end to end. Confirm: no seams, no stutter, rings fire, fuel drains, `RunEnded` reaches `CrateSystem`, a rot lands in inventory.
5. **Ring collection VFX.** `RingCollected` already fires and nothing listens. Small, visible, high juice-per-hour — and the fuel gauge is the natural pair-up.

After that: settle rot slots per glider, then finish the hotbar.

---

## Longer-term Phases

**Foundation & Testing** → **Progression Systems** → **Content & Features** → **Monetization & Balance** → **Polish & Launch**.

Concretely, the post-MVP queue looks like: register the remaining ~44 Creator Store creatures in `CreatureDictionary` · build [GAR Passive Income](systems/passive-income.md) · resolve and build [GAR Social Mechanic](systems/social-mechanic.md) · biome v2 (Desert pool + `BiomeChanged` cosmetic transitions, both already scaffolded) · migrate to ProfileService before any real player count touches the DataStore.

---

## Balancing Dials

Worth knowing which knob does what before launch tuning:

- **Fuel drain (4/sec) and ring refill (+25)** set run length. Run length sets rarity reach. These two numbers are the pacing of the entire game.
- **Ring density** is the difficulty curve. Max safe gap at 80 studs/sec is ~500 studs; design to 300–400.
- **`MAX_DISTANCE = 5000`** must be tuned against the actual reachable corridor length once the map is real, or the top rarity tiers become unreachable or trivial.
- **Rarity multipliers** (2× → 1000× across six tiers) are steep. That's fine while income is the only thing rarity drives; it becomes dangerous the moment rarity also touches speed.
- Free players should reach roughly **one crate per 2–3 hours** of idle income, and the gap between a new and an experienced player should be bridgeable in **2–3 weeks** of regular play.

---

## Related

[Glide-A-Rot](_index.md) · [GAR Project State](project-state.md) · [GAR Open Questions](open-questions.md) · Active Priorities
