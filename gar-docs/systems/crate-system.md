# Crate System

## Goal
The primary mechanism for players to obtain new rots — the gacha-style reward loop that drives
session-to-session engagement and is a natural future monetization surface (cooldown reduction).

## How it works (high level)
- Crates dispense rots according to the rarity tier system's odds/weights.
- Crate logic and the DataStore-based rot storage are already built and considered stable.

## Decisions made and why
- **Built early, before flight mechanics were tested**: crate logic and rot storage have no
  dependency on the flight system, so they were sequenced first to de-risk the data layer early.
- **Acceleration-not-gatekeeping monetization philosophy applies here directly**: crate timers are
  the planned lever for monetization (faster cooldowns = paid), while free players always retain
  full access to crates, just at a slower cadence. See [[monetization]].

## Open questions
None currently blocking. Once rarity-tier-vs-instance-stats is resolved (see [[open-questions]]),
crate reward rolling logic may need a small extension to roll instance-level stat variance, but
this isn't expected to require rework of the core crate logic.

## Depends on / blocks
- Depends on: rarity tier system (done)
- Blocks: rot system's supply of new creatures; eventually, monetization hooks (crate timer
  acceleration)
