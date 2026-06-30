# Social Rot-Rarity Mechanic

## Goal
Make other players' presence in your server meaningfully affect your own play — specifically,
tying other players' equipped hanggliders to the rarity of rots rolling for everyone in the
server. This is meant to be GAR's signature social hook, distinguishing it from a purely
single-player collector loop.

## How it works (high level — not yet built)
The core idea: the rarity of rots a player can roll from crates is influenced by what other
players in the same server have equipped (likely their glider type and/or rot rarity). The exact
mechanism is undecided — see open questions below, which represent the two biggest unresolved
design forks for this system.

## Decisions made and why
None yet — this is the least-defined system in the game and the one with the most open design
forks. It was intentionally deferred rather than guessed at, since getting it wrong would likely
require reworking crate odds and possibly DataStore schema after the fact.

## Open questions
- **Cooperative vs competitive**: do all players' equipped rots pool together to raise a shared
  rarity floor (cooperative), or does only the single rarest rot in the server grant a special
  buff that others can compete for (competitive)? See [[open-questions]] for full framing.
- **Per-session vs persistent**: does this bonus reset each time the server resets / player
  rejoins, or does it persist and accumulate via DataStore? See [[open-questions]].

## Depends on / blocks
- Depends on: rot system's rarity tiers (already done), glider types (for visible player identity
  in-server)
- Blocks: nothing structurally, but is one of the harder systems to retrofit later — resolving the
  open questions before building anything here is a priority over just starting to code it
