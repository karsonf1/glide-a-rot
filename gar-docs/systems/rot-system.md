<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Rot System

**Status:** ✅ storage built · 🟡 content thin · `src/ServerScriptService/PlayerData.lua` + `src/ReplicatedStorage/CreatureDictionary.lua`

## Goal

Rots (brainrot creatures) are the collectible progression layer of [Glide-A-Rot](../_index.md). Their rarity determines income, giving collection a mechanical payoff rather than a purely cosmetic one.

## Data shape

Each rot is stored per-player as:

```lua
{ Species = "TungTungSahur", Rarity = "Legendary", Income = 7500 }
```

Stored in DataStore `PlayerData_V4`. Inventory caps at **81 slots** (hardcoded in two places in `PlayerData.lua`). V3 string entries auto-migrate on load.

**Income is baked at roll time:** `rot.Income = species.IncomeRate × rarity.multiplier`. No live stat lookup, ever. This is what will make [GAR Passive Income](passive-income.md) a cheap system to build — the ticker just sums stored numbers.

## Species registry

`CreatureDictionary.lua` holds `IncomeRate`, `DisplayName`, `ModelName`, and `Weight` (species pool likelihood, distinct from rarity). Rarity is deliberately *not* stored here.

| Species | IncomeRate | Weight |
|---|---|---|
| StrawberryElephant | 5 | 40 |
| TralaleroTralala | 10 | 35 |
| TungTungSahur | 15 | 25 |
| BombardiroCrocodilo | 25 | 20 |
| BallerinaCappuccina | 40 | 10 |
| CappuccinoAssassino | 60 | 3 |

Weight and IncomeRate are inversely correlated, which is the right shape — the rare species is also the valuable one.

**Content gap:** only **6 of ~50** sourced Creator Store models are registered, and only `TungTungSahur` has an actual model wired under `ReplicatedStorage/CreatureModels`. Registering more species is pure table-editing with no logic changes — the cheapest possible content expansion, and probably underrated as a task.

## How rots are obtained

Runs end (fuel depletion or manual stow) → `RunEnded` → [GAR Crate System](crate-system.md) rolls rarity from distance via [GAR Rarity Distribution](rarity-distribution.md), rolls species by weight, bakes income, writes the rot.

Rots can be equipped to hotbar slots via `EquipmentHandler` — see [GAR Inventory and Equipment](inventory-and-equipment.md) — and displayed in-world on `CreatureSlotPrefab` stands.

## Decisions and why

**~50 creature models sourced from the Roblox Creator Store rather than custom-modeled.** This removed what would have been the single largest content bottleneck for a solo dev building a creature collector. Karson's Blender time is reserved for the hangglider, which has no off-the-shelf equivalent and is core to the game's identity. See [Art Sourcing Strategy](../decisions/2026-06-29-art-sourcing-strategy.md).

**Deterministic per-instance stats.** All rots of the same species + rarity share an identical `Income`. No random variance on top of the tier. Simpler DataStore, and no confusion from two "Legendary TungTungSahur" comparing differently. Effectively decided by the code already — just needs writing up as a decision.

**Holdable tool naming is `{InternalName}_{RarityName}`.** The internal name must match the `CreatureDictionary` key exactly, because that string is simultaneously the DataStore value, the event payload, the tool name, and the model lookup key.

## Depends on / blocks

**Depends on:** [GAR Crate System](crate-system.md) (supply), [GAR Rarity Distribution](rarity-distribution.md) (tiering).
**Blocks:** [GAR Passive Income](passive-income.md) (needs the income values it already bakes), [GAR Social Mechanic](social-mechanic.md) (needs rarity to be comparable across players).

## Related

[GAR Codebase Map](../codebase-map.md) · [GAR Open Questions](../open-questions.md)
