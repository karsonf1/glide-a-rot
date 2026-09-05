<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Glide-A-Rot

A creature-collector hanggliding game on Roblox, working title *Hangglide a Brainrot*. Solo-developed by Karson in Luau with Roblox Studio, Rojo, and Blender.

**This folder is the source of truth for GAR.** It supersedes the `gar-docs` vault inside the repo — everything there has been mirrored here and reconciled against the actual code as of 2026-07-26.

**Repo:** `C:\Users\karso\Desktop\Glide-A-Rot!` · `github.com/karsonf1/glide-a-rot` (main)

---

## The core loop

1. Equip a hangglider and launch a run
2. Flight burns **fuel** — 100 max, 4/sec drain; running out ends the run
3. Flying through **rings** refills fuel (+25) and awards **Poofs** (+5)
4. Distance flown drives a **Gaussian rarity roll** — farther runs reach rarer tiers
5. On run end, a **crate** dispenses a rot: species + rarity + baked income
6. Collected rots will feed **passive idle income** while away *(planned)*
7. Other players' equipped rots will influence rarity rolls server-wide *(planned)*

**Design philosophy:** monetization accelerates, it never gatekeeps. Free players reach everything eventually.

**Scale:** ~5 active players per server.

---

## Start here

- [GAR Project State](project-state.md) — live status board, blockers, what's actually built. **Read this first every session.**
- [GAR Open Questions](open-questions.md) — unresolved design forks, ordered by how much they block
- [GAR Sprint Plan](sprint-plan.md) — the MVP shape and the recommended next five tasks

## Reference

- [GAR Codebase Map](codebase-map.md) — every script, what it owns, how events wire together
- [GAR Conventions](conventions.md) — naming, architecture rules, tooling, division of labour
- [GAR Roblox Playbook](roblox-playbook.md) — sharp edges, security posture, Luau quick reference

## Folders

- GAR Systems — one note per game system, built and planned
- GAR Decisions — settled questions with their reasoning
- GAR References — how-to guides for authoring and asset pipelines
- GAR Sessions — dated records of what shipped

---

## Status at a glance

| | |
|---|---|
| ✅ Built | Flight, fuel, rings, Poofs, crates, rot storage, rarity curve, atmosphere |
| 🟡 In progress | ProcGen corridor, glider types, inventory hotbar, game map |
| 🔴 Not started | Ring VFX, passive income, social mechanic, monetization, quests |

**Current blockers:** stale `.git/index.lock` · uncommitted place-file work · player↔corridor coupling · Forest_B/C are empty stubs.

---

## Related

Active Priorities · [Blender to Roblox Pipeline](references/blender-to-roblox-pipeline.md) · Trivia Game
