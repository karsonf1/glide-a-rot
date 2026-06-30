# Rot System

## Goal
Creatures ("rots") are the collectible progression layer. Their rarity determines how much they
boost the player's flight power, giving collecting a direct gameplay payoff rather than being
purely cosmetic.

## How it works (high level)
- Rots are stored per-player via DataStore V4 (`PlayerData_V4`). Each rot is stored as
  `{ Species: string, Rarity: string, Income: number }`.
- Each rot belongs to one of six rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythical.
- Rarity tier determines an **income multiplier**, applied at roll time:
  `rot.Income = species.IncomeRate × rarityMultiplier`. This baked value is what the passive
  income ticker will read — no live stat lookup needed at tick time.
- Rots are obtained by completing hanggliding runs (run-end triggers CrateSystem.server.lua).
  The farther the run, the higher the rarity probability (distance-based Gaussian curve in
  RarityDistribution.lua; MAX_DISTANCE = 5000 studs).
- Inventory is capped at 81 rots. Rots can be equipped to hotbar slots via EquipmentHandler.

## Rarity tier income multipliers (from RarityDistribution.lua)
| Tier | Income multiplier | Roll center (fraction of max distance) |
|---|---|---|
| Common    | 2×    | 0% (very start of map) |
| Uncommon  | 5×    | 18% |
| Rare      | 25×   | 38% |
| Epic      | 100×  | 58% |
| Legendary | 500×  | 78% |
| Mythical  | 1000× | 100% (far end of map) |

## Decisions made and why
- **~50 creature models sourced from Roblox Creator Store** instead of custom-modeled: eliminated
  what would have been the single biggest bottleneck for a solo dev (mass-producing creature art).
  This was a meaningful unblocking discovery mid-project — custom modeling effort is now reserved
  for the hangglider only.
- **Rarity-tier multiplier system already built and locked in** — this is the foundation the social
  mechanic, crate odds, and progression curve all build on top of.

## Open questions
- None blocking. The "per-instance vs per-tier stats" question is effectively resolved by the
  code: income is baked per-instance at roll time (`{ Species, Rarity, Income }` on the rot
  object), computed from tier — but there is no random per-instance variance beyond that. All
  rots of the same species + rarity will have the same Income. Update open-questions.md to close
  this question.

## Depends on / blocks
- Depends on: crate system (source of rots), rarity tier system (already done)
- Blocks: social rarity mechanic (needs rot rarity to be meaningful and comparable across players),
  passive income (rate scales with best equipped rot's multiplier)
