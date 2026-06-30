# Monetization

## Goal
Generate revenue from a public launch without making free-to-play progression feel blocked or
unfair — this is a stated design philosophy for the whole project, not just this one system.

## How it works (high level — not yet built)
No specific monetization hooks are implemented yet. The governing philosophy is established and
should shape every future monetization decision: acceleration, not gatekeeping.

## Decisions made and why
- **Acceleration-not-gatekeeping philosophy**: free players should always be able to progress
  through every system in the game — crates, rots, gliders, passive income — given enough time.
  Paid options only speed things up. Examples already identified as fitting this model: cooldown
  reduction (crates), crate timers, and cosmetic skins (which monetize identity/expression rather
  than power directly).
- This philosophy was chosen deliberately over a pay-to-win or gatekeeping model, likely because
  it preserves long-term player trust and retention, which matters more for a solo-dev game
  relying on organic growth than short-term revenue maximization.

## Open questions
None on the philosophy itself, but no concrete monetization hooks have been scoped yet — this is
planned for Week 3 of the MVP sprint (see project-state.md), after rot/rarity integration in Week 2.

## Depends on / blocks
- Depends on: crate system (timer acceleration), glider types (potential skins/cosmetics surface)
- Blocks: nothing else in the dependency graph, but is explicitly sequenced after core systems
  are stable, consistent with monetizing a game that already works rather than building
  monetization into an unproven loop
