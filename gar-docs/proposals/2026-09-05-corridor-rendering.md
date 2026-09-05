# Corridor appearance and distant rendering proposal

Status: recommendation for discussion, not an implemented LOD system. Inspected in Studio on 2026-09-05 after the Claude handoff PR #3.

## What actually exists

- The saved place is `HangglideARot.rbxl`. The old XML place was stale.
- `ReplicatedStorage/SegmentTemplates/Forest` contains A (412 parts), B (324 parts), and C (412 parts). B/C are not floor-only stubs. Scenery counts alone do not establish meaningful layout variety.
- Each template has an identity-oriented 250 x 1 x 500 floor. Their authored Z positions differ; the existing floor-edge alignment handles that.
- `ReplicatedStorage/WallTemplates/Forest/Forest_Walls` has six mesh parts.
- All three segment `Rings` folders are empty. `ReplicatedStorage/PoofRingTemplate` exists separately: 24 visible rim parts and an invisible tagged Hitbox. Ring placement still needs authoring.
- Workspace instance streaming is disabled. Its radius settings therefore cannot explain current instance-streaming pop-in. Native graphics culling, mesh/texture downloads, generation timing, and missing client atmosphere are separate candidates; no client flight reproduction has isolated them yet.
- The inspected Workspace Forest_A has 270 MeshParts using 49 distinct MeshIds, 412 shadow-casting parts, and 252 collidable parts. This suggests opportunities to reuse assets and simplify distant decoration; it does not prove a frame-time bottleneck.
- Source previously looked for templates in ServerStorage, and Rojo placed StarterPlayerScripts at the DataModel root. Codex fixed both integration issues before changing the rendering architecture.

## Recommended structure

Keep the existing 500-stud, +Z, floor-aligned corridor. Treat a section's playable layout and visual theme as separate data.

| Layer | Owns | Example |
| --- | --- | --- |
| Layout | Floor contract, clear flight space, ring/obstacle sockets | Straight, left weave, right weave |
| Theme | Prop set, wall look, palette, atmosphere, distant silhouette assets | Forest, desert, snow |
| Server | Section selection/identity, placement, collision, ring hits and rewards | A ring remains the same server-owned hitbox in every theme |
| Client | Decorative distance tiers, asset preloading, atmosphere transition | Nearby trees replaced by a simple canopy cluster farther away |

This gives levels a consistent flight structure without requiring a complete new map for each appearance. Theme transitions should align with section boundaries, with a short transition section if a hard visual seam looks bad. Do not silently choose level lengths, launch placement, or multiplayer corridor ownership; these remain design choices.

## LOD options and their costs

| Approach | Benefit | Cost / limitation |
| --- | --- | --- |
| More full-detail lookahead + haze | Smallest initial change; existing streamer already generates about 2000 studs ahead | More replicated instances and clone work; haze is not a precise visibility cutoff and does not guarantee assets are loaded |
| Roblox SLIM on static scenery clusters | Automatically combines models into lightweight representations and multiple LODs | Requires streaming, a cloud-saved place and Team Create; runtime geometry/material changes are excluded. Test generated assets through this exact clone/PivotTo lifecycle before relying on them |
| Authored low-detail clusters + local distance switching | Predictable art direction for runtime-generated sections; no hand-authored LOD per individual tree | Requires a small proxy library, section identity shared with clients, bounded cleanup and sensible swap distances; native graphics/device limits still apply |
| Preassemble finite themed levels before publishing + SLIM | Particularly simple if levels are fixed-length and layout changes are modest | Gives up runtime geometry variety; ring patterns can still vary. Current code does not enforce a 5000-stud end, so a finite level length would be a new design decision |

**Recommendation for the existing runtime streamer:** prototype reusable low-detail scenery clusters for one forest section. Keep the playable floor, collision and rings on the server. Give the distant tree line/cliff shape a longer lifetime than the detailed section decoration. Use mesh Automatic fidelity for individual props, then consider SLIM as an additional optimization for compatible static clusters.

Do not mark the whole infinite forest Persistent or replicate all detailed future sections to solve a horizon problem. A handful of simple skyline meshes is a much smaller budget than several extra copies of hundreds of tree parts.

For a strictly finite, authored level, preassembly plus SLIM may be simpler than maintaining custom distance switching. The experiment should establish whether runtime layout variety is valuable enough to justify it.

## Smallest useful experiment

1. Play the synchronized baseline with one fixed section sequence. Verify actual floor/wall creation, asset preload results and client atmosphere before tuning distances.
2. Place a simple repeatable ring route using the existing template. Keep reward/flight tuning constant while investigating visuals.
3. Build one low-detail canopy/cliff silhouette from a small number of reused meshes. Render it farther ahead than the full trees. Keep it outside the flight lane, without collision/touch/shadows where appropriate.
4. Compare baseline vs proxy on low and high client graphics settings, at the fastest supported speed and across at least ten section boundaries. Observe mesh fetch failures, client frame time, memory, clone spikes and visible swaps. Test a cold join as well as a repeat run; preloading is not a guarantee of permanent cache residency.
5. Tune the near/proxy/haze distances from that result. Only then add a second theme using the same layout and the same few proxy shapes.

The acceptance target is no empty playable section, no visible hard scene spawn at the tested settings, stable memory over repeated boundaries, and enough ring visibility to choose a route. Rojo building successfully does not validate any of these visual behaviors.

## Improvements found for separate follow-up

- RingSystem resets a collected tagged Hitbox to Transparency=0 and CanCollide=true after eight seconds. For the actual invisible, noncolliding ring hitbox this creates an invisible-to-visible blocker; preserve its original properties and control the visible rim separately.
- No authored ring instances are present inside any of the three templates.
- ProcGen starts from a separate raw equip remote listener, rather than an accepted server run-start event. Validation, death teardown and multiplayer ownership need a coherent run lifecycle.
- The archived Studio flight draft uses Physics/CruiseSpeed/StallSpeed and other fields absent from current GliderConfig. It is preserved for review, not activated during synchronization.
- Placed-rot restore/ownership and raw DataStore session safety remain separate economy concerns. Do not fold those into a visual prototype.

## Sources

- [Roblox SLIM](https://create.roblox.com/docs/workspace/streaming/slim): automatic composite LOD, prerequisites, static-model restrictions.
- [Instance streaming](https://create.roblox.com/docs/workspace/streaming): streaming radius, client-created instances, Atomic and Persistent behavior.
- [RenderFidelity](https://create.roblox.com/docs/reference/engine/enums/RenderFidelity): per-mesh Automatic/Precise/Performance behavior.
- [Performance guidance](https://create.roblox.com/docs/performance-optimization/improve): mesh reuse, shadows, collision and rendering costs.
