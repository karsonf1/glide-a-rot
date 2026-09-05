<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Inventory and Equipment

**Status:** 🟡 in progress · `src/ServerScriptService/EquipmentHandler.server.lua`, `HoldHandler.server.lua`, `src/ReplicatedStorage/HoldableToolFactory.lua`, `src/StarterGui/InventoryUI/`

## Goal

Let players see what they've collected, choose what to equip, and carry rots visibly. This is the largest unfinished 🟡 item in [Glide-A-Rot](../_index.md) and the main thing standing between "the loop runs" and "the loop feels like a game".

## What exists

- **`PlayerData.lua`** — the 81-slot inventory of `{Species, Rarity, Income}` objects, with V3 migration and DataStore V4 persistence.
- **`EquipmentHandler.server.lua`** — validates equip requests server-side, guards-first.
- **`HoldableToolFactory.lua`** — builds the holdable rot tools, named `{InternalName}_{RarityName}` (e.g. `TungTungSahur_Legendary`).
- **`HoldHandler.server.lua`** — holdable tool behaviour.
- **`InventoryUI/InventoryWindow`** — the inventory display.
- **`InventoryUI/TotalMoneyLabel`** — Poofs counter, driven off leaderstats.
- **`Workspace/CreatureSlotPrefab`** — in-world display stands (`CollectionPlatform` + `Stand`) for placing rots.

## What's missing

**Rot-to-slot assignment doesn't work.** A player can hold a rot and the server will validate an equip, but actually assigning a specific rot to a specific hotbar slot — and having that persist and mean something — isn't wired.

This is blocked on a design decision, not on code: **how many slots does a glider have?** See [GAR Open Questions](../open-questions.md) #2. Fixed across all tiers is simpler; variable by tier (Beginner 3 / Advanced 6) makes slots a progression reward and gives [GAR Glider Types](glider-types.md) a second axis beyond speed. That answer determines the `GliderConfig` schema and the hotbar's whole shape, so it should be settled before more code lands here.

**Also missing:** an equipped-rot display on the HUD, and any UI feedback for the 81-slot cap being hit.

## Notes

The 81-slot cap is hardcoded in two places in `PlayerData.lua` (lines ~124 and ~271). Whatever the right number turns out to be, extracting it to a named constant is a five-minute fix that should happen before the number is ever tuned.

Equip requests are validated but **not rate-limited** — see SE-5 in [GAR Roblox Playbook](../roblox-playbook.md). Worth adding a per-player cooldown when this system is finished rather than after.

## Related

[GAR Rot System](rot-system.md) · [GAR Glider Types](glider-types.md) · [GAR Passive Income](passive-income.md) · [GAR Codebase Map](../codebase-map.md)
