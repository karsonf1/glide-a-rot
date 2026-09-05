<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Art Sourcing Strategy

**Decided:** 2026-06-29 (logged retroactively; the call was made earlier)

## Question

Custom-modeling dozens of brainrot creatures would be a major time sink for a solo developer. How should creature art for [GAR Rot System](../systems/rot-system.md) be sourced?

## Decision

Source ~50 brainrot creature models from the **Roblox Creator Store**. Reserve custom Blender work for the hangglider only.

## Why

This removed what would otherwise have been the single largest content-production bottleneck for a solo dev building a creature collector. A collector game needs *volume* of creatures to feel like a collection — modeling fifty of anything by hand is a multi-month project on its own, and it would have gated the entire rot/rarity/crate loop behind art that had nothing to do with the game's actual identity.

The hangglider is different: it's the thing players look at for the entire run, it has no off-the-shelf equivalent that fits, and it *is* the game's visual identity. That's where custom modeling time earns its cost.

This was described as a meaningful unblocking discovery mid-project — the kind of decision that changes the timeline rather than the design.

## Consequences

- The MVP timeline lost a major risk item.
- Content expansion is now table-editing: registering a species in `CreatureDictionary` costs minutes, not days. Only 6 of the ~50 sourced models are registered so far, which makes species expansion the cheapest content lever available.
- Creator Store licensing terms apply to the creature art. Worth confirming before any commercial push.

## Affects

[GAR Rot System](../systems/rot-system.md) · [GAR Sprint Plan](../sprint-plan.md) · [Blender to Roblox Pipeline](../references/blender-to-roblox-pipeline.md)
