-- ============================================================
-- ProcGenManager.server.lua  (ServerScriptService — Script)
-- Treadmill segment manager: keeps a recycling window of N hand-authored
-- segment Models alive so a run feels infinite without storing infinite geometry.
--
-- Corridor convention (v1): runs along world +Z. A segment's entry face is at its
-- pivot; its exit face is at pivot + (0,0,SEGMENT_LENGTH). The client forward-locks
-- the player's heading to +Z (see Client.client.lua), so the player always makes
-- forward progress and the boundary poll always eventually fires.
--
-- v1 scope: single biome (Forest), single active runner, destroy+clone (no pooling).
-- ============================================================

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameEvents      = require(ServerScriptService:WaitForChild("GameEvents"))
local SegmentRegistry = require(ReplicatedStorage:WaitForChild("SegmentRegistry"))
local gliderEquipEvent = ReplicatedStorage:WaitForChild("GliderEquipClient")

local SEGMENT_LENGTH    = 500                    -- studs; Z depth of each segment template
local WINDOW_SIZE       = 3                       -- segments alive at once
local ALTITUDE_VARIANCE = 15                      -- ± studs of vertical shift per new segment
local MAX_ALT_DRIFT     = 30                      -- clamp cumulative drift around baseY (anti random-walk)
local BIOME             = "Forest"                -- v1 hardcoded; v2 reads biomeSchedule
local FALLBACK_ORIGIN   = Vector3.new(0, 100, 0)  -- used if no RunCorridorOrigin marker is present

-- ── State ────────────────────────────────────────────────────────────────────
local activeSegments    = {}    -- ordered list; index 1 = tail (oldest), #list = front (newest)
local lastPickedSegment = nil   -- avoid back-to-back repeats
local activeRunner      = nil   -- single player whose run drives the treadmill (v1)
local originPos         = nil   -- resolved corridor entry position
local baseY             = nil   -- corridor baseline altitude (originPos.Y)

-- ── Origin resolution ──────────────────────────────────────────────────────
local function resolveOrigin()
	local marker = workspace:FindFirstChild("RunCorridorOrigin")
	if marker and marker:IsA("BasePart") then
		originPos = marker.Position
	else
		originPos = FALLBACK_ORIGIN
		warn(("[ProcGen] No RunCorridorOrigin marker found — using fallback %s")
			:format(tostring(FALLBACK_ORIGIN)))
	end
	baseY = originPos.Y
end

-- ── Template lookup (defensive) ──────────────────────────────────────────────
local function getTemplate(name)
	local root        = ServerStorage:FindFirstChild("SegmentTemplates")
	local biomeFolder = root and root:FindFirstChild(BIOME)
	local template    = biomeFolder and biomeFolder:FindFirstChild(name)
	if not template then
		warn(("[ProcGen] Missing segment template %s/%s"):format(BIOME, name))
	end
	return template
end

-- ── Segment selection (no back-to-back repeat when pool has > 1) ─────────────
local function pickSegmentName(pool, lastPicked)
	local candidates = {}
	for _, name in pool do
		if name ~= lastPicked then
			table.insert(candidates, name)
		end
	end
	if #candidates == 0 then candidates = pool end
	return candidates[math.random(1, #candidates)]
end

-- ── Real X-axis mirror ───────────────────────────────────────────────────────
-- Reflect each part across the segment pivot's local YZ-plane. Stores an improper
-- (det = -1) rotation matrix via the 12-arg CFrame.new — valid for rendering static
-- Part geometry. NOTE: MeshParts/Unions reposition but don't truly mirror their mesh;
-- acceptable for v1 (segments are Part-built per proc-gen.md). Assumes anchored parts.
local function mirrorModelAcrossPivot(model)
	local P    = model:GetPivot()
	local Pinv = P:Inverse()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local rel = Pinv * part.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
			local mirrored = CFrame.new(-x, y, z,
				 r00, -r01, -r02,
				-r10,  r11,  r12,
				-r20,  r21,  r22)
			part.CFrame = P * mirrored
		end
	end
end

-- ── Spawn one segment at a given entry position ──────────────────────────────
local function spawnSegmentAt(entryPos)
	local pool = SegmentRegistry[BIOME].segments
	local name = pickSegmentName(pool, lastPickedSegment)
	lastPickedSegment = name

	local template = getTemplate(name)
	if not template then return nil end

	local clone = template:Clone()
	clone.Parent = workspace
	clone:PivotTo(CFrame.new(entryPos))   -- identity orientation, +Z corridor

	local mirrored = math.random() < 0.5
	if mirrored then mirrorModelAcrossPivot(clone) end

	print(("[ProcGen] Spawned %s%s at Z=%.0f Y=%.0f")
		:format(name, mirrored and " (mirrored)" or "", entryPos.Z, entryPos.Y))
	return clone, name
end

-- Bounded altitude variance around the corridor baseline (prevents random-walk drift).
local function nextAltitude(prevY)
	return math.clamp(prevY + math.random(-ALTITUDE_VARIANCE, ALTITUDE_VARIANCE),
		baseY - MAX_ALT_DRIFT, baseY + MAX_ALT_DRIFT)
end

-- ── Window lifecycle ─────────────────────────────────────────────────────────
local function destroyWindow()
	for _, seg in activeSegments do
		if seg then seg:Destroy() end
	end
	table.clear(activeSegments)
	lastPickedSegment = nil
end

local function buildWindow()
	destroyWindow()  -- guard against a stale window
	local z     = originPos.Z
	local prevY = baseY
	for i = 1, WINDOW_SIZE do
		local y = (i == 1) and baseY or nextAltitude(prevY)
		prevY = y
		local seg = spawnSegmentAt(Vector3.new(originPos.X, y, z))
		if seg then table.insert(activeSegments, seg) end
		z += SEGMENT_LENGTH
	end
	print(("[ProcGen] Window built — %d segments from Z=%.0f"):format(#activeSegments, originPos.Z))
end

-- ── Recycle (player cleared the oldest segment's exit boundary) ──────────────
local function recycle()
	if not activeRunner then return end
	local char = activeRunner.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if #activeSegments == 0 then return end

	local offset = Vector3.new(0, 0, -SEGMENT_LENGTH)

	-- 1. Teleport player back (LinearVelocity is a constraint, so velocity is preserved)
	hrp.CFrame = hrp.CFrame + offset

	-- 2. Shift all active segments by the same offset — world stays consistent
	for _, seg in activeSegments do
		seg:PivotTo(seg:GetPivot() + offset)
	end

	-- 3. Keep GliderHandler's distance tracking accurate after the teleport
	GameEvents.RunOffsetApplied:Fire(activeRunner, offset)

	-- 4. Destroy the tail (oldest) segment
	local tail = table.remove(activeSegments, 1)
	if tail then tail:Destroy() end

	-- 5. Spawn a fresh segment ahead of the current front
	local front      = activeSegments[#activeSegments]
	if not front then return end
	local frontPivot = front:GetPivot().Position
	local y          = nextAltitude(frontPivot.Y)
	local newSeg     = spawnSegmentAt(Vector3.new(originPos.X, y, frontPivot.Z + SEGMENT_LENGTH))
	if newSeg then table.insert(activeSegments, newSeg) end
end

-- ── Boundary poll ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	if not activeRunner then return end
	local char = activeRunner.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if #activeSegments == 0 then return end

	-- Threshold = exit face Z of the oldest segment. Cross it → recycle.
	local threshold = activeSegments[1]:GetPivot().Position.Z + SEGMENT_LENGTH
	if hrp.Position.Z > threshold then
		recycle()
	end
end)

-- ── Run start (glider equipped) ──────────────────────────────────────────────
-- Independent connection from GliderHandler; both may listen to the same RemoteEvent.
gliderEquipEvent.OnServerEvent:Connect(function(player, isEquipped)
	if not isEquipped then return end
	if activeRunner then
		if activeRunner ~= player then
			print(("[ProcGen] %s deployed while %s owns the treadmill — ignored (v1 single-runner)")
				:format(player.Name, activeRunner.Name))
		end
		return
	end

	activeRunner = player
	resolveOrigin()
	buildWindow()
	print(("[ProcGen] Treadmill started for %s"):format(player.Name))
end)

-- ── Run end (stow or fuel depletion both fire RunEnded) ──────────────────────
local function teardown(player)
	if activeRunner ~= player then return end
	destroyWindow()
	activeRunner = nil
	print(("[ProcGen] Treadmill torn down for %s"):format(player.Name))
end

GameEvents.RunEnded.Event:Connect(function(player)
	teardown(player)
end)

Players.PlayerRemoving:Connect(function(player)
	teardown(player)
end)

print("[ProcGen] ProcGenManager ready")
