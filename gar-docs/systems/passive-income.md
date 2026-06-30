# Passive Idle Income

## Goal
Let players earn currency while away from the game (AFK or fully offline), so the game retains
value for players who can't play long sessions, and gives a reason to log back in.

## How it works (high level)
Not yet built. Conceptually: income should accrue based on time elapsed and scale with the
player's progression (likely their best equipped rot's rarity multiplier, consistent with how
that multiplier already governs flight power).

## Decisions made and why
None finalized yet — this system has not been designed in detail. The only settled context is that
it's explicitly in scope for the MVP and depends on the rot rarity multiplier already existing.

## Open questions
- Exact accrual formula (e.g. base rate x highest equipped rot multiplier) — not yet decided, only
  implied by consistency with the flight system's existing multiplier logic.
- Whether this stacks with the social rarity mechanic or is fully independent — not yet discussed.
- Accrual cap (to prevent unbounded offline gains) — not yet decided.

## Depends on / blocks
- Depends on: rot system (for the multiplier), DataStore (needs a last-seen timestamp per player)
- Blocks: nothing else currently, but is one of the five MVP-critical systems not yet started
