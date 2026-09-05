<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Glider Types

**Status:** 🟡 in progress · `src/ReplicatedStorage/GliderConfig.lua`

## Goal

Glider choice should be a real progression and identity decision, not a skin. It also gives [GAR Social Mechanic](social-mechanic.md) something visible to react to — other players can see what you're flying at a glance.

## How it works

`GliderConfig.lua` is the single stat registry. Every value is in degrees for easy Studio-side tuning, and both `GliderController` (client) and `GliderHandler` (server) read from it. Nothing about flight is hardcoded anywhere else.

Adding a tier is three steps: copy an entry and rekey it, add the key to `CreatureDictionary` so it appears in inventory, and place the model in `ReplicatedStorage/GliderModels` named to match `ModelName`.

| | Beginner | Advanced | Elite (templated) |
|---|---|---|---|
| MaxSpeed | 80 | 90 | 130 |
| GlideAngle | −10° | −6° | −4° |
| TurnSpeed | 90°/s | 140°/s | 200°/s |
| TurnAcceleration | 3.5 | 5.0 | 7.0 |
| TurnDecay | 2.5 | 1.8 | 1.2 |
| RollMultiplier | 28° | 40° | 55° |
| PitchRange | −20/+5 | −25/+10 | −30/+15 |

`GlideAngle` is the sneaky-important stat: a shallower passive descent means a better lift ratio and a longer glide per unit of fuel, which translates directly into distance and therefore rarity. Advanced isn't just faster than Beginner, it's *more efficient* — that's a better progression feel than a raw speed bump.

`TurnDecay` going *down* with tier is a deliberate difficulty gradient: higher tiers carve longer and require more anticipation. Progression that demands more skill, not less.

## Decisions and why

**3–4 distinct types, not one upgradeable glider.** See [Glider Architecture Decision](../decisions/2026-06-29-glider-architecture.md). Short version: each unlock feels categorically different rather than a stat bump, it opens more monetization surfaces (sell a glider or a skin-per-type rather than one linear upgrade path), and it gives the social mechanic a visible identity signal. Accepted trade-off against build simplicity.

## Open

- **Rot slots per glider — fixed or tier-variable?** [GAR Open Questions](../open-questions.md) #2. Decides whether `GliderConfig` needs a `slotCount` field, and blocks finishing [GAR Inventory and Equipment](inventory-and-equipment.md). Leaning tier-variable, since slots are a more legible reward than raw stats.
- **The models aren't placed.** `ReplicatedStorage/GliderModels` needs `GliderBeginner` and `GliderAdvanced`. The Blender hangglider import also has unresolved issues: UV stretching on the left wing and an Alpha=0 wing material. See [Blender to Roblox Pipeline](../references/blender-to-roblox-pipeline.md).
- Speed and Tank types were mentioned early as the 3rd/4th tiers; only Elite exists as a template. Worth reconciling the naming.

## Depends on / blocks

**Depends on:** nothing — the config is stable for the two live tiers.
**Blocks:** the hotbar (equip logic needs slot count), the social mechanic (visible identity), and the first real playtest (no models = no glider).

## Related

[GAR Flight Mechanics](flight-mechanics.md) · [GAR Monetization](monetization.md) · [GAR Codebase Map](../codebase-map.md)
