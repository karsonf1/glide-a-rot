<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Flight Mechanics

**Status:** ✅ built · `src/StarterPlayerScripts/Client.client.lua` + `src/ServerScriptService/GliderHandler.server.lua`

## Goal

A satisfying, skill-expressive hanggliding feel. This is the loop players repeat to earn currency and roll for rots — everything else in [Glide-A-Rot](../_index.md) exists to support it.

## How it works

**Physics run client-side.** `LinearVelocity` + `AlignOrientation` constraints on the HumanoidRootPart, with network ownership handed to the client via `hrp:SetNetworkOwner(player)` on equip. Standard Roblox practice for character movement; gives smooth low-latency response.

**The server validates and measures, it doesn't drive.** `GliderHandler.server.lua` checks the requested glider exists in `GliderConfig`, records the launch position, fires `GameEvents.RunEnded` with horizontal distance on land, and restores auto-ownership on stow.

**The client owns the feel:** yaw/pitch/roll physics, lerp-based air drag, the deploy prompt (double-jump → `F`), `E` to stow, arm posing via Weld overrides on Motor6D/AnimationConstraint, glider model attachment, and camera follow. All tuning values come from `GliderConfig` — never hardcoded in the controller.

**Forward lock.** Yaw deviation is capped at ±90° off +Z, so the glider can steer to full lateral but `Vz` is floored at 0 — you can never travel backward down the corridor away from the rings. Tightened from 75° to 90° on 2026-07-03.

**Rarity does not affect flight.** Speed is purely glider-tier driven. Whether equipped-rot rarity should multiply speed is [GAR Open Questions](../open-questions.md) #5.

## Current tuning

| | Beginner | Advanced |
|---|---|---|
| MaxSpeed | 80 studs/sec | 90 |
| GlideAngle | −10° | −6° |
| TurnSpeed | 90°/sec | 140 |
| TurnAcceleration | 3.5 | 5.0 |
| TurnDecay | 2.5 | 1.8 |
| RollMultiplier | 28° | 40° |
| PitchRange | −20° to +5° | −25° to +10° |

`TurnDecay` is the interesting one: lower means yaw bleeds off slower, giving a longer carve tail. That's what makes Advanced feel more capable *and* harder to control, rather than just faster.

## Decisions and why

**Client-side physics with server distance tracking.** The server validates glider identity and measures distance (which feeds the rarity roll), but doesn't control moment-to-moment movement. Anti-exploit pressure is handled by the server-authoritative reward system — you can't fake a longer run to get better rarity — rather than by server-side physics, which would add latency to the thing that has to feel best.

**Modern movers only.** `LinearVelocity` / `AlignOrientation`, never `BodyVelocity` / `BodyGyro`.

**Never write position server-side.** Because the HRP is client-owned during flight, any server-side CFrame write causes rubber-banding. This is not theoretical — it cost a full ProcGen rewrite. See [Forward Streamer over Treadmill](../decisions/2026-07-03-forward-streamer-over-treadmill.md).

## Depends on / blocks

**Depends on:** the hangglider model being imported and placed in `ReplicatedStorage/GliderModels` (still open — see the Blender UV/alpha issues in [GAR Open Questions](../open-questions.md)).
**Blocks:** nothing directly, but it's the loop every other system is built to serve.

## Related

[GAR Glider Types](glider-types.md) · [GAR Fuel System](fuel-system.md) · [GAR ProcGen Corridor](proc-gen.md) · [GAR Codebase Map](../codebase-map.md)
