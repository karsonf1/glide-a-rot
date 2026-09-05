# Studio source at the Claude/Codex handoff

These files preserve the inherited Studio editor sources that were absent from or differed from `src/` on 2026-09-05. They are archival and are not mapped by Rojo.

- `Client.client.lua`: Studio flight controller; differs from the local source version.
- `CorridorPreload.client.lua`: Studio-only preload script expecting templates in ReplicatedStorage.

The authored scene is saved as `HangglideARot.rbxl`, replacing the stale June XML place. It includes Forest_A, Forest_Walls, the corridor origin, ring template, and segment/wall templates in ReplicatedStorage. The source streamer currently expects ServerStorage; reconciling that mismatch is follow-up Codex work.

Code checkpoint: `6ac13bf`. Documentation checkpoint: `ce4d7b6`. No new gameplay implementation is included in this archive.
