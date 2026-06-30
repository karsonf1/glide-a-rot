# Flight Mechanics

## Goal
Give the player a satisfying, skill-expressive hanggliding feel that's the core gameplay loop
players repeat to earn currency and roll for rots.

## How it works (as built — Client.client.lua)
- Physics run **client-side**: `LinearVelocity` + `AlignOrientation` constraints on the
  `HumanoidRootPart`, with network ownership transferred to the client via
  `hrp:SetNetworkOwner(player)` on equip. This is standard Roblox practice for character movement
  and gives smooth, low-latency feel.
- Server (`GliderHandler.server.lua`) validates equip requests (checks glider name is in
  GliderConfig), records launch position, fires `GameEvents.RunEnded` with horizontal distance on
  land, and restores network auto-ownership on stow.
- Flight stats (speed, turn rate, pitch range, etc.) come entirely from `GliderConfig.lua`. Rot
  rarity does **not** affect flight speed in the current implementation — rarity only affects
  **income** (see [[rot-system]]). Speed-scaling with rots is a future design decision, not yet
  coded.
- Client handles: yaw/pitch/roll physics, air drag (lerp-based velocity), deploy prompt (double-
  jump → F to deploy), arm posing (Weld overrides on Motor6D/AnimationConstraint), glider model
  attachment, and camera follow.

## Decisions made and why
- **Client-side physics with server distance tracking**: the server validates glider identity and
  measures horizontal distance flown (used for rarity roll), but doesn't control moment-to-moment
  movement. Anti-exploit pressure is handled by the server-authoritative reward system (you can't
  fake a longer run to get better rarity) rather than server-side physics, which would add latency
  and complexity to the core gameplay feel.
- **Rarity does not currently affect flight speed**: speed is purely stat-driven by glider tier.
  Whether to tie rot rarity into speed is an open design question — it would reinforce the
  rot-collection loop but adds complexity and makes it harder to balance.

## Open questions
None directly, but blocked on the hangglider model import (see project-state.md current blocker)
before it can be tested end-to-end in Studio.

## Depends on / blocks
- Depends on: hangglider model being correctly imported and placed in ReplicatedStorage
- Blocks: nothing else directly, but is the core loop everything else (rots, crates, social,
  passive income) is built to support
