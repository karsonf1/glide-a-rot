# Task Handoff — ProcGenManager v1

_Generated: 2026-06-29_

---

## PASTE THIS INTO THE CODE AGENT

---

You are helping develop **Glide-A-Rot** (a.k.a. "Hangglide a Brainrot"), a Roblox hanggliding
creature-collector game. The codebase is synced via Rojo. All scripts are `.lua` files under
`src/`.

## What to build

Implement **ProcGenManager v1** — a server script that manages a recycling window of 3 hand-authored
"segment" Models, creating an infinite treadmill effect for the player's flight run.

This is a greenfield script. No existing proc-gen system exists. You will also need to patch
`GliderHandler.server.lua` to handle a new `RunOffsetApplied` BindableEvent.

---

## Repo structure (relevant files)

```
src/
├── ReplicatedStorage/
│   ├── GliderConfig.lua              ← glider stats (read-only reference)
│   ├── RarityDistribution.lua        ← distance-based rarity (read-only reference)
│   └── SegmentRegistry.lua           ← YOU CREATE THIS
├── ServerScriptService/
│   ├── GliderHandler.server.lua      ← PATCH THIS (add RunOffsetApplied listener)
│   ├── GameEvents.lua                ← BindableEvents hub (add RunOffsetApplied here)
│   ├── RingSystem.server.lua         ← DO NOT TOUCH (already handles runtime rings)
│   ├── FuelSystem.lua                ← DO NOT TOUCH
│   ├── PlayerData.lua                ← DO NOT TOUCH
│   └── ProcGenManager.server.lua     ← YOU CREATE THIS
```

In Roblox, segment templates live in `ServerStorage/SegmentTemplates/Forest/` as Model instances.
You don't need to create them — just write the code that consumes them. Reference them by name
via `ServerStorage:FindFirstChild("SegmentTemplates"):FindFirstChild(biome):FindFirstChild(name)`.

---

## Existing systems to know about

### GliderHandler.server.lua (current behavior)
- Fires `GameEvents.RunEnded:Fire(player, distance)` when a run ends (stow or fuel depleted)
- Tracks `runStarts[player] = hrp.Position` at equip time
- Distance = horizontal magnitude from `runStarts[player]` to current HRP position
- **You will patch this** to listen to `GameEvents.RunOffsetApplied` and adjust `runStarts[player]`
  so distance tracking stays accurate after teleports

### GameEvents.lua (current)
- Returns a table of BindableEvents: `RunEnded`, `FuelDepleted`
- **Add** `RunOffsetApplied` here (same pattern as the others)

### RingSystem.server.lua
- Uses `CollectionService:GetInstanceAddedSignal("PoofRing")` — **any Part tagged `PoofRing`
  cloned into Workspace at runtime is automatically wired**. No changes needed.

---

## What to create

### 1. `src/ReplicatedStorage/SegmentRegistry.lua`

A ModuleScript that returns the segment pool configuration:

```lua
return {
  -- Segment template names (must match Model names in ServerStorage/SegmentTemplates/<biome>/)
  Forest = {
    segments = { "Forest_A", "Forest_B", "Forest_C" },
  },

  -- Biome schedule: distance thresholds that switch the active pool
  -- v1 only uses Forest; Desert etc. come later
  biomeSchedule = {
    { distance = 0, biome = "Forest" },
    -- { distance = 2000, biome = "Desert" },  -- uncomment in v2
  },
}
```

### 2. Patch `src/ServerScriptService/GameEvents.lua`

Add `RunOffsetApplied = Instance.new("BindableEvent")` alongside the existing events.
Follow the exact same pattern already in the file.

### 3. Patch `src/ServerScriptService/GliderHandler.server.lua`

Add a listener at the bottom:

```lua
GameEvents.RunOffsetApplied.Event:Connect(function(player, offset)
    if runStarts[player] then
        runStarts[player] = runStarts[player] + offset
    end
end)
```

This keeps the distance calculation correct after every teleport.

### 4. `src/ServerScriptService/ProcGenManager.server.lua`

#### Constants
```lua
local SEGMENT_LENGTH    = 500   -- studs; Z depth of each segment template
local WINDOW_SIZE       = 3     -- segments alive at once
local ALTITUDE_VARIANCE = 15    -- ± studs of random vertical shift per new segment
local BIOME             = "Forest"  -- v1 hardcoded; v2 reads biomeSchedule dynamically
```

#### Startup sequence
1. Wait for a player to equip their glider (listen to `GliderEquipClient` RemoteEvent,
   same as GliderHandler does — or use a simpler approach: just always keep the window
   populated once any player is in the server)
2. Clone the first 3 segments from the Forest pool, place them back-to-back along +Z from
   a fixed world origin (e.g. `Vector3.new(0, 100, 0)` — match wherever your map's run
   corridor starts)
3. Store the active segment instances in an ordered list: `activeSegments = {segA, segB, segC}`

#### Segment positioning
Each segment Model should be placed using `:PivotTo(CFrame)`. The entry face of each segment
is at its pivot; the exit face is at pivot + Vector3.new(0, 0, SEGMENT_LENGTH).

```lua
-- Place segment at world position
local function placeSegment(segModel, position)
    segModel.Parent = workspace
    segModel:PivotTo(CFrame.new(position))
end
```

When spawning the next segment in the sequence, its position is:
`lastSegment:GetPivot().Position + Vector3.new(0, altitudeOffset, SEGMENT_LENGTH)`

#### Boundary detection (server heartbeat poll)
Every `RunService.Heartbeat`, for each player in an active run:
- Get their `HumanoidRootPart.Position.Z`
- Compare against `activeSegments[1]:GetPivot().Position.Z + SEGMENT_LENGTH`
  (the Z position of the end of the first/oldest segment)
- If player Z > that threshold → trigger recycle

#### Recycle step
```lua
local function recycleSegment(player)
    local offset = Vector3.new(0, 0, -SEGMENT_LENGTH)

    -- 1. Teleport player (preserve velocity — LinearVelocity handles this automatically)
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    hrp.CFrame = hrp.CFrame + offset

    -- 2. Shift all active segments
    for _, seg in activeSegments do
        seg:PivotTo(seg:GetPivot() + offset)
    end

    -- 3. Notify GliderHandler to adjust runStart
    GameEvents.RunOffsetApplied:Fire(player, offset)

    -- 4. Destroy tail segment
    local tail = table.remove(activeSegments, 1)
    tail:Destroy()

    -- 5. Pick and spawn new front segment
    local newSeg = spawnNextSegment()
    table.insert(activeSegments, newSeg)
end
```

#### Segment selection + variance
```lua
local function pickSegmentName(pool, lastPicked)
    -- Avoid back-to-back repeat if pool has > 1 segment
    local candidates = {}
    for _, name in pool do
        if name ~= lastPicked then table.insert(candidates, name) end
    end
    if #candidates == 0 then candidates = pool end
    return candidates[math.random(1, #candidates)]
end

local function spawnNextSegment()
    local registry = require(ReplicatedStorage.SegmentRegistry)
    local pool = registry[BIOME].segments
    local name = pickSegmentName(pool, lastPickedSegment)
    lastPickedSegment = name

    local template = ServerStorage.SegmentTemplates[BIOME][name]
    local clone = template:Clone()

    -- Altitude variance
    local altOffset = math.random(-ALTITUDE_VARIANCE, ALTITUDE_VARIANCE)

    -- Mirror (50% chance): flip X axis
    local pivot = activeSegments[#activeSegments]:GetPivot()
    local spawnPos = pivot.Position + Vector3.new(0, altOffset, SEGMENT_LENGTH)
    local spawnCFrame = CFrame.new(spawnPos)
    if math.random() < 0.5 then
        spawnCFrame = spawnCFrame * CFrame.fromMatrix(Vector3.zero,
            Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1))
    end

    clone.Parent = workspace
    clone:PivotTo(spawnCFrame)
    return clone
end
```

#### Cleanup on run end
When `GameEvents.RunEnded` fires, destroy all active segments and reset state so the next
run starts fresh. (Or keep them — but for v1, reset is simpler.)

---

## Code style rules (match existing scripts)

- Server authority on all state; no client-side geometry
- Guards first: check Character exists, HRP exists before acting
- `warn()` for unexpected states, `print()` for lifecycle logs
- Module requires at top, constants after requires, logic in named functions
- No `wait()` — use `task.wait()` or event-driven patterns
- Luau syntax (type annotations optional but welcome)

---

## What NOT to do

- Do not touch `RingSystem.server.lua` — it already handles runtime rings via CollectionService
- Do not use Terrain for segments — only Parts/Models
- Do not add biome switching yet — v1 is Forest-only
- Do not add a client LocalScript — cosmetic events come in v2
- Do not assume segment templates exist in Studio — write defensive code
  (`if not template then warn(...) return end`)

---

## Definition of done

- [ ] `SegmentRegistry.lua` created in ReplicatedStorage
- [ ] `GameEvents.lua` has `RunOffsetApplied` BindableEvent
- [ ] `GliderHandler.server.lua` patched to adjust `runStarts` on offset
- [ ] `ProcGenManager.server.lua` created with: window init, heartbeat boundary detection,
      recycle loop (teleport + shift + destroy tail + spawn front), segment variance (mirror + altitude)
- [ ] Rings inside cloned segments are auto-wired by existing RingSystem (verify via print logs)
- [ ] Run ends cleanly (segments destroyed, state reset, CrateSystem fires correctly)
- [ ] No errors in output during a test flight through 2+ segment boundaries

---

## Reference: full system design doc

`gar-docs/systems/proc-gen.md` in the repo has the full rationale, integration map, and
open questions. Read it if anything above is ambiguous.
