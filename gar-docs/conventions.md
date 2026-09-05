<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Conventions

The house rules for [Glide-A-Rot](_index.md). These are already enforced in the codebase — new code matches them, it doesn't relitigate them.

---

## Naming

| Thing | Convention | Example |
|---|---|---|
| ModuleScript | `PascalCase.lua` | `RarityDistribution.lua` |
| Server Script | `descriptive.server.lua` | `RingSystem.server.lua` |
| LocalScript | `descriptive.client.lua` | `Client.client.lua` |
| Rot internal name | Must match `CreatureDictionary` key exactly | `TungTungSahur` |
| Holdable tool | `{InternalName}_{RarityName}` | `TungTungSahur_Legendary` |
| Segment model | `{Biome}_{Letter}` | `Forest_A` |
| Commit scope | one of the fixed set below | `feat(procgen): ...` |

**Commit scopes:** `flight`, `rot`, `crate`, `inventory`, `social`, `economy`, `ui`, `data`, `glider`, `map`, `monetization`, `procgen`, `docs`.

The internal-name rule matters more than it looks: the same string is the DataStore key, the RemoteEvent payload, the tool name, and the model lookup. A rename in one place silently orphans rots in players' inventories.

---

## File Structure

```
src/
├── ReplicatedStorage/    ← shared ModuleScripts, config registries
├── ServerScriptService/  ← server Scripts + server-only modules
├── StarterPlayerScripts/ ← client controllers (flight, atmosphere)
├── StarterGui/           ← ScreenGui LocalScripts
└── Workspace/            ← in-world prefabs and their scripts
```

**Authored content outside source sync:** segment/wall templates in `ReplicatedStorage` and authored Workspace geometry live inside `HangglideARot.rbxl`. The binary place is tracked by Git; inspect its content in Studio. **Saving the local place in Studio is required before committing map work.** Rojo maps source scripts but does not reconstruct those authored assets.

---

## Architecture Rules

**Server authority on every economy change.** The client fires a RemoteEvent; the server validates and writes. The client is display-only for Poofs, fuel, rot inventory, and rarity. Never regress this.

**Guards first in every handler.** In order: type check → range check → ownership check → cooldown check → *then* act. `warn()` on a rejected or suspicious request, `print()` for normal lifecycle.

**Income is baked at roll time.** `rot.Income = species.IncomeRate × rarity.multiplier`, stored on the rot object. No live stat lookup at tick time. This is what makes [GAR Passive Income](systems/passive-income.md) cheap to build later.

**Distinct glider types, not one upgradeable glider.** See [Glider Architecture Decision](decisions/2026-06-29-glider-architecture.md).

**Decoupling via BindableEvents.** `GameEvents.lua` owns `RunEnded` and `FuelDepleted`. Systems fire and listen through it rather than requiring each other directly. *Gotcha, already hit once:* a BindableEvent is `event.Event:Connect(...)`, not `event:Connect(...)` — the latter silently errors and broke the whole fuel→crate chain until it was caught on 2026-07-03.

**Config lives in registries, never inline.** Flight stats in `GliderConfig`, species in `CreatureDictionary`, tiers in `RarityDistribution`, segment pools in `SegmentRegistry`. Adding content should mean editing one table, never touching logic.

**Modern movers only.** `LinearVelocity` + `AlignOrientation`. Do not reintroduce `BodyVelocity` / `BodyGyro`.

**Never set position server-side on a client-owned part.** The HumanoidRootPart's network ownership is handed to the client on glider equip. Server-side CFrame writes fight the client and produce rubber-banding. This is the lesson of [Forward Streamer over Treadmill](decisions/2026-07-03-forward-streamer-over-treadmill.md).

---

## Segment Authoring

Covered in full in [Forest Segment Authoring Guide](references/forest-segment-authoring.md). The non-negotiables:

- 500 studs deep along **+Z**, floor part 250 × 500.
- All descendant BaseParts **anchored**.
- Rings in a `Rings/` subfolder, each tagged `PoofRing`.
- No geometry past the X/Y bounds — sections mirror on X.
- **Side scenery must be Parts/MeshParts, never voxel Terrain.** Terrain is a singleton and cannot be cloned or shifted per section.
- Templates live at `ReplicatedStorage/SegmentTemplates/<Biome>/<Name>` in the verified saved place; the name must match `SegmentRegistry`. The server remains authoritative for all spawned gameplay/rewards.

Note the current streamer aligns sections by the `floor` Part, **not** the model pivot, because authored pivots are inconsistent (Forest_A at entry, B/C at exit).

---

## Tooling Pipeline

**Rojo** syncs `src/*.lua` ↔ Studio. **Rokit/Aftman** manage the toolchain (`rokit.toml`, `aftman.toml`). **Claude Code in VS Code** writes the Luau. **Blender** handles the hangglider and hero props — see [Blender to Roblox Pipeline](references/blender-to-roblox-pipeline.md). Roblox Creator Store supplies the ~50 brainrot creature models.

Same repo on desktop and laptop via `git pull`. Both machines point at `C:\Users\karso\Desktop\Glide-A-Rot!`.

**MCP awareness:** this project has the official Roblox Studio MCP and the Blender MCP available. Check what's actually connected before assuming — with Studio MCP live you can run Luau and read the console directly; without it, produce copy-paste-ready scripts instead.

---

## Division of Labour

Karson owns Studio world-building, map design, and Blender. Scripting is delegated to a Claude Code agent. UI and visual work are **in scope** for Claude.

**The one guardrail:** never let a "best practice" hurt fun or replayability. Neutral engineering advice — performance, safety, clarity — always applies. Taste-level design rules are subordinate to the game feeling good.

---

## Related

[Glide-A-Rot](_index.md) · [GAR Codebase Map](codebase-map.md) · [GAR Roblox Playbook](roblox-playbook.md) · [GAR Project State](project-state.md)
