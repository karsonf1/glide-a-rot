<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Open Questions

Unresolved design forks for [Glide-A-Rot](_index.md). When one is settled, write a dated note in the GAR Decisions folder and delete the item here. Questions are ordered by how much they block.

---

## Blocking — resolve before the next build step

### 1. Player ↔ corridor coupling
`ProcGenManager` builds the corridor at the `RunCorridorOrigin` marker on glider deploy, but nothing ties the player's position or heading to it.

- **Option A** — teleport the player to `RunCorridorOrigin` on deploy. Clean and deterministic, but a teleport at deploy time fights the client's network ownership of the HumanoidRootPart, which is *exactly* the bug that killed the old treadmill (see [Forward Streamer over Treadmill](decisions/2026-07-03-forward-streamer-over-treadmill.md)).
- **Option B** — build the corridor window at the player's actual deploy position instead of a fixed marker. Avoids the ownership fight entirely; costs you a fixed, authored "section 0" and makes the world non-reproducible between runs.
- **Current stopgap** — SpawnLocation parked at `(0, 103, −12)` facing +Z so players fall into the corridor naturally. Works for solo testing, breaks the moment a second player deploys from anywhere else.

**Leaning:** Option B. The whole reason the streamer rewrite worked was refusing to set position server-side on a client-owned part. Option A reintroduces that class of bug for a cosmetic gain.

### 2. Rot slots per glider — fixed or tier-variable?
Does every glider carry the same number of equipped rots, or does slot count scale with tier (Beginner 3 / Advanced 6 / Elite 9)?

Decides whether `GliderConfig` entries need a `slotCount` field, and shapes the hotbar logic in `EquipmentHandler`. Blocks finishing the inventory hotbar, which is the largest 🟡 item on the board.

**Leaning:** tier-variable. Slots are a legible, non-numeric progression reward — "my new glider holds more rots" reads better to a player than "+10 speed", and it gives [GAR Glider Types](systems/glider-types.md) a second axis so gliders aren't just a speed ladder.

---

## Design — needed soon, not blocking today

### 3. Social mechanic — cooperative or competitive? Per-session or persistent?
GAR's signature hook: other players' equipped gliders/rots influence rarity rolls server-wide. Two orthogonal forks:

- **Cooperative** (everyone's rots pool to raise a shared rarity floor) vs. **competitive** (only the server's rarest rot grants a buff, and players contest it).
- **Per-session** (resets on server restart) vs. **persistent** (accumulates in DataStore).

**Recommendation: cooperative + per-session.** Lowest grief surface, no DataStore schema change, easiest to balance, and it makes a populated server feel good instead of hostile — which matters more at ~5 players per server than any competitive depth would add. Revisit competitive variants post-MVP.

### 4. Passive income ticker — cadence and offline behavior
`rot.Income` is already baked per rot, so only the accrual rule is missing.

- Per-second while in-game, or time-diffed against a stored `LastLogin` on join?
- Does it scale off the single best equipped rot, the sum of equipped rots, or the whole inventory?
- Offline payout cap — 8h is a reasonable default to block accumulation exploits.

**Leaning:** offline time-diff on join, summed over *equipped* rots only, capped at 8h. Ties passive income to the equip decision, which makes the hotbar matter.

### 5. Rot rarity → flight speed?
Rarity currently drives **income only**. Should equipped-rot rarity also multiply glider speed?

It would tighten the collection loop (rarer rots → longer runs → rarer rots), but that's also a compounding feedback spiral that could run away. If this ships, the rarity income curve and the speed curve must be rebalanced together so a Mythical doesn't double-count.

### 6. Poofs spend mechanic — what do Poofs actually buy?
Poofs accrue at +5/ring with a theoretical ceiling around 175 per full run, and there is currently nowhere to spend them. Currency with no sink is the most visible unfinished thing a new player will notice. Candidates: glider unlocks, crate rerolls, cosmetic skins, extra inventory slots.

---

## Tuning / low stakes

### 7. Inventory cap
81 slots, hardcoded in two places in `PlayerData.lua` (lines ~124 and ~271). Whatever the right number is, it should be a named constant in one place first.

### 8. Fuel persistence between runs
Fuel always resets to `FUEL_MAX` on equip. Should a partial tank carry over? Current behavior is simpler and probably correct — noted only so it's a decision rather than an accident.

### 9. Per-instance stat variance — effectively resolved
All rots of the same species + rarity share an identical `Income`, baked deterministically at roll time. **Recommendation: keep it deterministic.** Two "Legendary TungTungSahur" with different stats would confuse trading and inventory comparison for no gameplay gain. This is close to closable — it just needs to be written as a decision.

### 10. Segment count before first playtest
3–4 authored Forest segments is the usual recommendation. Currently at 1.

---

## Related

[GAR Project State](project-state.md) · GAR Decisions · GAR Systems · [GAR Sprint Plan](sprint-plan.md)
