# AGENTS.md — Glide-A-Rot

Context for any coding agent working in this repo (Codex, Claude Code, Cursor, Copilot).
Read this first, then `gar-docs/project-state.md`.

## Codex handoff verification — 2026-09-05

PR #3 merged at `f5c2a64`, preserving inherited source, docs, and the user-saved
`HangglideARot.rbxl`. Codex work begins after this boundary on
`codex/corridor-sync-and-rendering`. See `gar-docs/sessions/2026-09-05-codex-handoff.md`.

This inspection supersedes conflicting historical notes below:
- The saved place is `.rbxl`, replacing the stale June `.rbxlx`.
- Segment/wall templates are in **ReplicatedStorage**, outside source-managed geometry.
  A/B/C all contain scenery, but all three `Rings` folders are empty.
- Rojo must map client scripts under **StarterPlayer/StarterPlayerScripts**.
- The stale Git lock was cleared after verifying no Git process was active.
- Studio editor buffers can differ from `Script.Source`; inspect both when syncing.
- The Studio flight physics draft is archived under `gar-docs/handoff/2026-09-05-studio`;
  its required GliderConfig fields are absent. The compatible repository controller
  is the active source until that draft is deliberately completed.
- StreamingEnabled is false in the saved scene. Rendering and end-to-end gameplay
  still require a client playtest; a successful Rojo build only validates packaging.

---

## What this is

**Glide-A-Rot** (working title "Hangglide a Brainrot") — a solo-developed Roblox
creature-collector. You hangglide a fuel-limited run through a streaming corridor, fly
through rings to refuel and earn currency, and cash the run out for a randomly rolled
creature ("rot") whose rarity scales with how far you flew.

Solo project, ~7,700 lines of Luau across ~30 script files. Owner: Karson (`karsonf1`).
Target is a 5-week MVP; the project is in the **map + procgen** stretch.

---

## Stack and layout

| | |
|---|---|
| Language | Luau (Roblox) |
| Sync | [Rojo](https://rojo.space) — `default.project.json` maps `src/` into the place |
| Toolchain | `rokit.toml` / `aftman.toml` |
| Place file | `HangglideARot.rbxl` — tracked in git, **diffs as binary** |

```
src/
├── ReplicatedStorage/    shared ModuleScripts, config registries
├── ServerScriptService/  server Scripts + server-only modules (the authority layer)
├── StarterPlayerScripts/ client controllers (flight, atmosphere)
├── StarterGui/           ScreenGui LocalScripts
└── Workspace/            in-world prefabs and their scripts
```

### Commands

```bash
rojo build -o "Hangglide.rbxlx"   # build a place from scratch
rojo serve                        # live-sync into an open Studio session
```

**There is no test suite, no linter, and no CI.** Nothing in this repo can be run
headlessly. Correctness is verified by Karson pressing Play in Roblox Studio. Do not
claim a change works — say what you expect to happen and what to watch for in Studio.

---

## Read these, in this order

`gar-docs/` is the in-repo source of truth for engineering docs. It was re-synced from
Karson's Obsidian vault on 2026-09-05; earlier copies were stale.

1. **`gar-docs/project-state.md`** — status board. Every system and its state. Start here.
2. **`gar-docs/codebase-map.md`** — every script, what it owns, what it talks to. Read
   this instead of grepping for "where does X live".
3. **`gar-docs/conventions.md`** — naming, architecture rules, commit scopes. These are
   already enforced in the codebase; match them, don't relitigate them.
4. **`gar-docs/open-questions.md`** — unresolved design forks, ordered by how much they
   block. Several carry a recorded leaning. **Do not silently resolve one by writing
   code** — surface it and let Karson decide.
5. **`gar-docs/systems/*.md`** — per-system design docs and the reasoning behind them.
6. **`gar-docs/decisions/*.md`** — dated decision records. These are settled; if code
   contradicts one, the code is the bug (or the decision needs an explicit revision).
7. **`gar-docs/roblox-playbook.md`** — security/hardening/performance checklist for this
   codebase specifically.

---

## Architecture rules that will bite you

These are the ones an agent unfamiliar with the project gets wrong. Full list in
`gar-docs/conventions.md`.

- **Server authority on every economy change.** Client fires a RemoteEvent, server
  validates and writes. The client is display-only for Poofs, fuel, rot inventory, and
  rarity. Never regress this.
- **Guards first in every handler**, in order: type check → range check → ownership check
  → cooldown check → *then* act. `warn()` on rejected/suspicious input, `print()` for
  normal lifecycle.
- **BindableEvents connect via `.Event`.** `GameEvents.RunEnded.Event:Connect(...)`, not
  `GameEvents.RunEnded:Connect(...)`. The second form fails silently and once broke the
  entire fuel → crate chain.
- **Modern movers only.** `LinearVelocity` + `AlignOrientation`. Do not reintroduce
  `BodyVelocity` / `BodyGyro`.
- **Never set position server-side on a client-owned part.** The client owns the
  HumanoidRootPart during a run. Fighting that ownership is what killed the old
  "teleport treadmill" procgen — see
  `gar-docs/decisions/2026-07-03-forward-streamer-over-treadmill.md`.
- **Income is baked at roll time.** `rot.Income = species.IncomeRate × rarity.multiplier`,
  stored on the rot object. No live stat lookup at tick time.
- **A rot's internal name is load-bearing.** The same string is the DataStore key, the
  RemoteEvent payload, the tool name, and the model lookup. Renaming it in one place
  silently orphans rots in live players' inventories.
- **Config lives in registries, never inline.** `GliderConfig`, `CreatureDictionary`,
  `RarityDistribution`, `SegmentRegistry`. Adding content should mean editing one table.
- **Authored assets are not reconstructed by Rojo.** Segment/wall templates are in
  ReplicatedStorage in `HangglideARot.rbxl`, alongside authored Workspace geometry. Editing `src/`
  cannot touch them. Map work requires Ctrl+S in Studio before it can be committed.

---

## Historical pre-handoff state — superseded by the verification above

- Branch **`perf/procgen-seamless-streaming`**, HEAD `743fa55` (2026-07-03), one commit
  ahead of `main` and **not pushed**. `origin/main` is at `a21fe46`.
- **Uncommitted work in the tree** from 2026-07-09: real changes in `PlayerData.lua`,
  `CrateSystem.server.lua`, `GameManager.server.lua`, and
  `Workspace/CreatureSlotPrefab/Stand/Script.server.lua`, plus three untracked new files
  never committed: `HoldableToolFactory.lua`, `HoldHandler.server.lua`,
  `AtmosphereController.client.lua`.
- ✅ Done: flight, fuel, rings, Poofs currency, crate/rot award, rot storage, rarity
  tiers, atmosphere.
  🟡 In progress: procgen corridor, glider types, inventory hotbar, game map.
  🔴 Not started: ring VFX, HUD fuel gauge, social mechanic, passive income,
  monetization, quests.

### Known traps in the working tree

1. **Line endings.** Most tracked files are CRLF and diffs are full of whole-file churn —
   `git diff` reports ~1,200 changed lines where only ~250 are real. Use
   `git diff --ignore-all-space` to see actual changes. A `.gitattributes` with
   `* text=auto eol=lf` would fix this permanently; not yet added.
2. **`HangglideARot.rbxlx` has not been modified since 2026-06-14 and has only ever been
   committed once (at `init`).** The docs describe Forest_A geometry, a
   `RunCorridorOrigin` marker, spawn placement, and `ServerStorage/SegmentTemplates` as
   existing — **none of that is in the place file on disk.** Treat every claim about
   in-Studio content as unverified until Karson confirms it in Studio.
3. **`ProfileService.lua` is dead code.** It sits in `ServerScriptService` and two scripts
   mention it in comments, but the live data path is raw DataStore via `PlayerData.lua`.
   Either finish the migration or delete the module — do not assume hardening is done.
4. **`Forest_B` and `Forest_C` are floor-only stubs.** `SegmentRegistry` picks randomly
   from a three-name pool where two entries are empty floors. Variety is currently fake.

---

## Working agreement

Karson is the lead and is learning as he builds. He wants to understand what goes into
his game, not receive finished blocks of code.

- **Ask before you build.** What's the design goal? What constraints? Has it been
  sketched? Then design together, then write code.
- **Show tradeoffs.** When there are several ways to do something, name them and say what
  each costs. Let him pick.
- **Explain the code you write** — why it's structured that way, what might break.
- **Be honest about gaps.** Roblox/Luau has quirks and Studio-version behavior you can't
  verify from here. Say when you're unsure. He has the game running; he tests.
- **Don't resolve open questions by fiat.** If a task depends on one in
  `gar-docs/open-questions.md`, surface it first.

### Commits

Conventional commits with a scope from this fixed set: `flight`, `rot`, `crate`,
`inventory`, `social`, `economy`, `ui`, `data`, `glider`, `map`, `monetization`,
`procgen`, `docs`.

```
feat(procgen): stream canyon walls alongside floor segments
fix(data): clamp inventory writes to the 81-slot cap
```

### Naming

| Thing | Convention | Example |
|---|---|---|
| ModuleScript | `PascalCase.lua` | `RarityDistribution.lua` |
| Server Script | `descriptive.server.lua` | `RingSystem.server.lua` |
| LocalScript | `descriptive.client.lua` | `Client.client.lua` |
| Rot internal name | must match `CreatureDictionary` key exactly | `TungTungSahur` |
| Holdable tool | `{InternalName}_{RarityName}` | `TungTungSahur_Legendary` |
| Segment model | `{Biome}_{Letter}` | `Forest_A` |

---

## After a work session

Update `gar-docs/project-state.md` if system status changed, add a dated file to
`gar-docs/decisions/` when a fork in `open-questions.md` gets settled (and delete the item
from that file), and add a session note under `gar-docs/sessions/`. Docs that drift from
the code are worse than no docs — this project has been bitten by that twice.

`CLAUDE.md` in this repo is a behavioral guide for Claude Code and overlaps with the
"Working agreement" section above; this file is the repo context both agents share.
