# Glider Types

## Goal
Hangglider choice should be a meaningful progression and identity decision for the player, not
just a cosmetic skin — and should give the social rarity mechanic something visible to react to
(other players can see what you're flying).

## How it works (high level)
- 3-4 distinct hangglider types exist (not a single upgradeable glider). Beginner and Advanced
  tiers are currently defined in `GliderConfig.lua`; Speed and Tank types are planned.
- Each type has its own base stats (speed, handling) defined in GliderConfig — never hardcoded
  elsewhere in scripts.
- Each glider has a slot capacity for equipped rots — see open question on whether this is fixed
  or variable by tier.

## Decisions made and why
- **3-4 distinct types chosen over one upgradeable glider**: gives better progression depth (each
  unlock feels distinct, not just a stat increase), opens more monetization angles (selling
  specific gliders or skins per type rather than a single linear upgrade path), and creates more
  meaningful interaction with the social rarity mechanic — other players can recognize which
  glider type you're flying at a glance, which a single reskinned glider wouldn't support as well.
- This was a deliberate trade-off against simplicity: a single upgradeable glider would have been
  faster to build, but was judged not worth it for the progression and monetization depth lost.

## Open questions
- Rot slots per glider: fixed across all types, or variable by tier? See [[open-questions]].
  This directly affects whether GliderConfig needs a `slotCount` field per glider entry.

## Depends on / blocks
- Depends on: nothing (GliderConfig already exists and is stable for the two defined tiers)
- Blocks: rot slot resolution, inventory hotbar finishing (equip logic needs to know slot count
  per equipped glider), and the social mechanic (glider type may factor into visible "flex" or
  recognition between players)
