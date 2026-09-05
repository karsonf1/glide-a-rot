<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Roblox Playbook

Roblox and Luau engineering practice as it applies to [Glide-A-Rot](_index.md) — the sharp edges, the security posture, and the quick reference. General enough to reuse; specific enough to say what GAR already does and where it's exposed.

---

## The Golden Rule

> **Never trust the client.** Every RemoteEvent payload is attacker-controlled. Validate type, range, ownership, and cooldown on the server for every request.

GAR already follows this — guards-first handlers, server-authoritative economy. The job is not regressing it.

---

## Sharp Edges

| ID | Severity | Issue | GAR status |
|---|---|---|---|
| **SE-1** | 🔴 Critical | DataStore loss from missing session locking | **Live exposure.** `PlayerData.lua` uses raw DataStore V4. Wrap every call in `pcall`, use `UpdateAsync` (not `SetAsync`) for read-modify-write, and migrate to ProfileService/ProfileStore before soft launch. `ProfileService.lua` is already sitting in the repo unwired — finishing that migration is the highest-value hardening left. |
| **SE-2** | 🔴 Critical | Client-side currency manipulation | **Handled.** All Poofs and income math is server-side; the client only renders `PoofUpdate` / `FuelUpdate`. Keep it that way. |
| **SE-3** | 🔴 Critical | `ProcessReceipt` mishandling — duplicate grants or lost purchases | **Not yet applicable.** When monetization lands: grant the item *then* return `PurchaseGranted`. If the grant fails, return `NotProcessedYet` so Roblox retries. Grants must be idempotent. |
| **SE-4** | 🟠 High | Memory leaks from undisconnected events | **Watch closely.** The Heartbeat flight loop, per-ring `Touched` connections, the ProcGen stream tick, and per-player join/leave handlers all accumulate. Store every `:Connect()` return and `:Disconnect()` on cleanup — a Maid/Trove pattern would pay for itself here. |
| **SE-5** | 🟠 High | RemoteEvent flooding | **Partially exposed.** Equip requests are validated but not rate-limited. Any future "open crate" or "spend Poofs" remote needs a per-player last-fire timestamp on the server. |
| **SE-6** | 🟠 High | Server writing position to a client-owned part | **Bitten once, fixed.** Cost this project a full ProcGen rewrite — see [Forward Streamer over Treadmill](decisions/2026-07-03-forward-streamer-over-treadmill.md). |
| **SE-7** | 🟡 Medium | BindableEvent connected wrong | **Bitten once, fixed.** `event.Event:Connect(...)`, never `event:Connect(...)`. The wrong form errored silently on every load and broke the fuel→crate chain undetected. |

---

## Service Hierarchy — what goes where

- **ServerScriptService** — server-only logic: game state, data, anti-cheat. Never replicated to clients.
- **ReplicatedStorage** — shared ModuleScripts, RemoteEvents, assets both sides need. Assume players can read everything here.
- **ServerStorage** — server-only assets: map templates, tools cloned on demand. Not in the Rojo tree for GAR.
- **StarterPlayerScripts** — client controllers: input, camera, UI logic.
- **StarterGui** — ScreenGuis, cloned into PlayerGui on spawn.
- **Workspace** — the live 3D world. Keep it lean; everything here is simulated and replicated.

## Script types

| Type | Runs on | Use for |
|---|---|---|
| `Script` (`.server.lua`) | Server | Game logic, data, physics authority |
| `LocalScript` (`.client.lua`) | Client | Input, camera, UI, local effects |
| `ModuleScript` (`.lua`) | Either | Shared code, config tables, utilities |

## RemoteEvent shape

```luau
-- Server: listen
RemoteEvent.OnServerEvent:Connect(function(player, ...) end)
-- Client: fire
RemoteEvent:FireServer(...)
-- Server → one client
RemoteEvent:FireClient(player, ...)
```

## DataStore shape

```luau
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData_V4")
-- Always pcall. Always UpdateAsync for read-modify-write. See SE-1.
```

---

## Feature Planning Framework

When scoping anything new for GAR:

1. **Clarify scope.** Ask the one or two questions that actually unblock implementation. Don't ask for what you can infer.
2. **Check what exists.** Map the feature onto `PlayerData`, `RarityDistribution`, `GliderConfig`, `GameEvents`. Don't rebuild done work — see [GAR Codebase Map](codebase-map.md).
3. **Split into three layers.** *Data* (what's stored/loaded) → *server logic* (authoritative rules, guards-first) → *client experience* (UI, animation, VFX).
4. **Flag dependencies.** Is it blocked by an item in [GAR Open Questions](open-questions.md) or an unbuilt system? Say so out loud rather than guessing past it.
5. **Write an ordered task list.** Each task self-contained and completable in one session.

## Delegating to Claude Code

One self-contained task at a time. Always name the real file to create or edit, the inputs and outputs, and which existing modules it reads from. Anything touching DataStore or RemoteEvents requires `pcall`, error handling, and logging (`warn` on reject, `print` on lifecycle).

**Shape of a good handoff:**

> In `src/ServerScriptService/EquipmentHandler.server.lua`, add `EquipRot(player, rotId)` that reads the rot from the player's DataStore inventory, validates ownership guards-first, stores the equipped rot in the server-side player table, and fires a RemoteEvent to the client with the rot's data. Rate-limit to one equip per 0.5s per player. The player table and RemoteEvent already exist.

---

## Related

[GAR Conventions](conventions.md) · [GAR Codebase Map](codebase-map.md) · [GAR Project State](project-state.md) · [Glide-A-Rot](_index.md)
