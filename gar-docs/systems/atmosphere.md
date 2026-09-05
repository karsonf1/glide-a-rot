<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Atmosphere

**Status:** ✅ built · `src/StarterPlayerScripts/AtmosphereController.client.lua`

## Goal

Hide the streaming boundary. This system exists for one concrete reason: [GAR ProcGen Corridor](proc-gen.md) loads sections roughly 2,000 studs ahead of the player, and with no horizon haze you literally watch geometry clone into existence in clear air. Airspeed caps around 90 studs/sec, so that lookahead is enormous in time terms — the only missing piece was something to fade distant geometry into the sky.

A nice case of a cosmetic system being load-bearing: without it, the whole procgen approach reads as broken.

## How it works

The key property is `Atmosphere.Haze`, which builds a horizon band that dissolves distant geometry into the sky. `Density` thins the whole air column. Together they set draw-distance-in-feel, which is what conceals the section spawn boundary.

Structured for v2 biome transitions: a per-biome `PROFILES` table plus a tweenable `applyProfile()`, and a guarded `BiomeChanged` hook that only wires itself up once that RemoteEvent exists. **No behaviour change until then** — this is scaffolding done correctly, dormant rather than half-live.

## Coupling to worry about

`SECTIONS_AHEAD` in `ProcGenManager` and the Forest haze profile here are coupled: the spawn boundary must stay *beyond* the fog horizon. Currently 4 sections = 2,000 studs of lookahead against a Forest haze that fully obscures well under that. If either value is tuned, check the other — and re-check at any new airspeed cap, since a faster glider eats the margin.

## Related

[GAR ProcGen Corridor](proc-gen.md) · [GAR Glider Types](glider-types.md) · [GAR Codebase Map](../codebase-map.md)
