-- ============================================================
-- ProcGenManager.server.lua  (ServerScriptService — Script)
-- Forward-streaming corridor generator.
--
-- The player flies continuously along world +Z. Sections load in AHEAD of the
-- player and unload BEHIND them — no teleporting, no world-shifting. Because a
-- run is fuel-bounded (~5000 studs), coordinates stay small enough that float
-- precision is a non-issue, so the old teleport-treadmill (which fought the
-- client's network ownership of the HumanoidRootPart and caused the stutter) is
-- gone entirely.
--
-- Each "section" = one floor segment (Forest_A/B/C from ServerStorage) tiled at
-- 500-stud intervals, plus one universal canyon-wall set cloned alongside it.
--
-- Alignment is done by each template's `floor` Part (250 x 500), NOT the model
-- pivot — the authored pivots are inconsistent (A at entry, B/C at exit), so
-- floor-edge alignment is the only reliable way to tile them seamlessly.
--
-- v1 scope: single biome (Forest), single active runner, clone+destroy (pooling
-- is a future optimization if heavy-mesh clones ever hitch despite the lookahead).
-- ============================================================

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")

local SegmentRegistry  = require(ReplicatedStorage:WaitForChild("SegmentRegistry"))
local GameEvents       = require(game:GetService("ServerScriptService"):WaitForChild("GameEvents"))
local gliderEquipEvent = ReplicatedStorage:WaitForChild("GliderEquipClient")

local SEGMENT_LENGTH   = 500                    -- studs; floor Z-depth of each template
-- SECTIONS_AHEAD must keep the spawn boundary BEYOND the fog horizon so sections
-- always materialize inside the haze, never in clear air. AtmosphereController's
-- Forest haze fully obscures well under 2000 studs; 4 sections = 2000-stud
-- lookahead gives comfortable margin at the ~90 studs/sec airspeed cap.
local SECTIONS_AHEAD   = 4                       -- sections kept loaded beyond the player
local SECTIONS_BEHIND  = 1                       -- sections kept behind (look-back buffer)
local BIOME            = "Forest"                -- v1 hardcoded
local FALLBACK_ORIGIN  = Vector3.new(0, 100, 0)  -- used if no RunCorridorOrigin marker
local CHECK_INTERVAL   = 0.2                      -- seconds between stream ticks
local CONTAINER_NAME   = "StreamedCorridor"       -- Workspace folder holding live sections

-- Template authoring frame (see gar-docs): floors authored centered on X=0 with
-- their top surface at Y≈99.5; the wall set is authored to line section-0 (floor
-- entry at Z=0). Only the walls need these constants; floors self-align via `floor`.
local AUTHORED_X          = 0
local AUTHORED_FLOOR_TOP  = 99.5
local AUTHORED_WALL_ENTRY = 0

-- ── State ────────────────────────────────────────────────────────────────────
local sections      = {}    -- ordered by entryZ ascending; { floor, walls, entryZ, exitZ }
local nextEntryZ    = nil    -- entry Z of the next section to spawn
local lastFloorName = nil    -- avoid back-to-back repeats
local activeRunner  = nil    -- single player driving the stream (v1)
local originPos     = nil    -- corridor entry position (from marker)
local container     = nil    -- Workspace folder for live sections

-- ── Origin ───────────────────────────────────────────────────────────────────
local function resolveOrigin()
	local marker = workspace:FindFirstChild("RunCorridorOrigin")
	if marker and marker:IsA("BasePart") then
		originPos = marker.Position
	else
		originPos = FALLBACK_ORIGIN
		warn(("[ProcGen] No RunCorridorOrigin marker — using fallback %s"):format(tostring(FALLBACK_ORIGIN)))
	end
end

-- ── Template lookup (defensive) ──────────────────────────────────────────────
local function getFloorTemplate(name)
	local root  = ServerStorage:FindFirstChild("SegmentTemplates")
	local biome = root and root:FindFirstChild(BIOME)
	local t      = biome and biome:FindFirstChild(name)
	if not t then warn(("[ProcGen] Missing floor template %s/%s"):format(BIOME, name)) end
	return t
end

local function getWallTemplate()
	local wallName = SegmentRegistry[BIOME] and SegmentRegistry[BIOME].walls
	if not wallName then return nil end
	local root  = ServerStorage:FindFirstChild("WallTemplates")
	local biome = root and root:FindFirstChild(BIOME)
	local t      = biome and biome:FindFirstChild(wallName)
	if not t then warn(("[ProcGen] Missing wall template %s/%s"):format(BIOME, tostring(wallName))) end
	return t
end

-- ── Floor selection (no back-to-back repeat when pool has > 1) ───────────────
local function pickFloorName()
	local pool = SegmentRegistry[BIOME].segments
	local candidates = {}
	for _, name in pool do
		if name ~= lastFloorName then table.insert(candidates, name) end
	end
	if #candidates == 0 then candidates = pool end
	local name = candidates[math.random(1, #candidates)]
	lastFloorName = name
	return name
end

-- ── Placement ────────────────────────────────────────────────────────────────
-- Align a floor clone so its floor Part's entry edge (min Z) sits at world Z=entryZ,
-- centered on the corridor X, with the floor top at the corridor Y. PivotTo(pivot +
-- delta) translates the whole model rigidly, so we don't care where the pivot is.
local function alignFloorTo(clone, entryZ)
	local geo   = clone:FindFirstChild("Geometry")
	local floor = geo and geo:FindFirstChild("floor")
	if not floor then
		clone:PivotTo(CFrame.new(originPos.X, originPos.Y, entryZ))
		return
	end
	local floorEntryZ = floor.Position.Z - floor.Size.Z / 2
	local floorTopY   = floor.Position.Y + floor.Size.Y / 2
	local delta = Vector3.new(
		originPos.X - floor.Position.X,
		(originPos.Y - 0.5) - floorTopY,   -- floor top just under the corridor origin
		entryZ - floorEntryZ
	)
	clone:PivotTo(clone:GetPivot() + delta)
end

-- Wall set is one template authored for section-0; shift by the corridor origin
-- (X/Y) plus the section's Z. Keeps the canyon lining every streamed section.
local function placeWalls(wallClone, entryZ)
	local delta = Vector3.new(
		originPos.X - AUTHORED_X,
		(originPos.Y - 0.5) - AUTHORED_FLOOR_TOP,
		entryZ - AUTHORED_WALL_ENTRY
	)
	wallClone:PivotTo(wallClone:GetPivot() + delta)
end

-- ── Spawn / cull ─────────────────────────────────────────────────────────────
local wallTemplate  -- resolved once per run in buildInitial

local function spawnSection(entryZ)
	local floorTemplate = getFloorTemplate(pickFloorName())
	if not floorTemplate then return end

	local floorClone = floorTemplate:Clone()
	alignFloorTo(floorClone, entryZ)
	floorClone.Parent = container

	local wallClone
	if wallTemplate then
		wallClone = wallTemplate:Clone()
		placeWalls(wallClone, entryZ)
		wallClone.Parent = container
	end

	table.insert(sections, { floor = floorClone, walls = wallClone, entryZ = entryZ, exitZ = entryZ + SEGMENT_LENGTH })
	print(("[ProcGen] Section spawned at Z=%.0f (%s)"):format(entryZ, floorClone.Name))
end

local function destroySection(section)
	if section.floor then section.floor:Destroy() end
	if section.walls then section.walls:Destroy() end
end

-- Spawn at most one section per tick (isolates the heavy-mesh clone cost).
local function ensureAhead(playerZ)
	if nextEntryZ <= playerZ + SECTIONS_AHEAD * SEGMENT_LENGTH then
		spawnSection(nextEntryZ)
		nextEntryZ += SEGMENT_LENGTH
	end
end

local function cullBehind(playerZ)
	while sections[1] and sections[1].exitZ < playerZ - SECTIONS_BEHIND * SEGMENT_LENGTH do
		destroySection(table.remove(sections, 1))
	end
end

-- ── Run lifecycle ────────────────────────────────────────────────────────────
local function teardown(player)
	if activeRunner ~= player then return end
	for _, section in sections do destroySection(section) end
	table.clear(sections)
	if container then container:Destroy(); container = nil end
	nextEntryZ, lastFloorName, wallTemplate = nil, nil, nil
	activeRunner = nil
	print(("[ProcGen] Corridor torn down for %s"):format(player.Name))
end

local function buildInitial()
	-- Runtime-only cleanup: the streamer owns the corridor, so remove the
	-- hand-placed start copies (edit-mode scene keeps them for authoring).
	for _, name in { "Forest_A", "Forest_Walls" } do
		local static = workspace:FindFirstChild(name)
		if static then static:Destroy() end
	end

	container = Instance.new("Folder")
	container.Name = CONTAINER_NAME
	container.Parent = workspace

	wallTemplate  = getWallTemplate()
	nextEntryZ    = originPos.Z
	lastFloorName = nil

	-- Fill the initial window synchronously (player is stationary at deploy, so a
	-- brief build cost here is unnoticeable vs. mid-flight).
	for _ = 1, SECTIONS_AHEAD do
		spawnSection(nextEntryZ)
		nextEntryZ += SEGMENT_LENGTH
	end
	print(("[ProcGen] Corridor built — %d sections from Z=%.0f"):format(#sections, originPos.Z))
end

-- ── Stream tick ──────────────────────────────────────────────────────────────
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if not activeRunner then return end
	accumulator += dt
	if accumulator < CHECK_INTERVAL then return end
	accumulator = 0

	local char = activeRunner.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local playerZ = hrp.Position.Z
	ensureAhead(playerZ)
	cullBehind(playerZ)
end)

-- Run start (glider equipped). Independent connection from GliderHandler.
gliderEquipEvent.OnServerEvent:Connect(function(player, isEquipped)
	if not isEquipped then return end
	if activeRunner then
		if activeRunner ~= player then
			print(("[ProcGen] %s deployed while %s owns the corridor — ignored (v1 single-runner)")
				:format(player.Name, activeRunner.Name))
		end
		return
	end
	activeRunner = player
	resolveOrigin()
	buildInitial()
	print(("[ProcGen] Corridor stream started for %s"):format(player.Name))
end)

-- Run end — GliderHandler fires RunEnded for BOTH manual stow and fuel depletion,
-- so this single trigger covers every way a run can end.
GameEvents.RunEnded.Event:Connect(teardown)

Players.PlayerRemoving:Connect(teardown)

print("[ProcGen] ProcGenManager ready (forward-streaming)")
