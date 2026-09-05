-- ============================================================
-- CorridorPreload.client.lua  (StarterPlayerScripts — LocalScript)
--
-- The corridor streamer clones segment templates 2000 studs ahead of the player,
-- but "the instance exists" and "the client can draw it" are two different things.
-- A freshly-replicated MeshPart renders as an untextured grey blob (or nothing)
-- until its mesh and texture assets finish downloading — which is the sporadic
-- pop-in you see even with Workspace.StreamingEnabled = false.
--
-- This script forces every asset the corridor can possibly use into the client's
-- content cache ONCE at join. After that, cloning a section is pure instance
-- creation with zero asset fetch, so sections are fully drawn the moment they
-- appear inside the fog.
--
-- Requires SegmentTemplates + WallTemplates to live in ReplicatedStorage.
-- ============================================================

local ContentProvider   = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOTS = { "SegmentTemplates", "WallTemplates" }

-- Only these classes carry fetchable content. Passing the whole descendant list
-- to PreloadAsync works but wastes time on instances with nothing to download.
local function isPreloadable(inst)
	return inst:IsA("MeshPart")
		or inst:IsA("SpecialMesh")
		or inst:IsA("Decal")
		or inst:IsA("Texture")
		or inst:IsA("SurfaceAppearance")
end

local function collect()
	local assets = {}
	for _, rootName in ROOTS do
		local root = ReplicatedStorage:WaitForChild(rootName, 20)
		if not root then
			warn(("[Preload] %s not found in ReplicatedStorage — corridor assets will pop in"):format(rootName))
		else
			for _, inst in root:GetDescendants() do
				if isPreloadable(inst) then
					table.insert(assets, inst)
				end
			end
		end
	end
	return assets
end

task.spawn(function()
	local assets = collect()
	if #assets == 0 then
		warn("[Preload] No corridor assets found — nothing to preload")
		return
	end

	local started = os.clock()
	local done, failed = 0, 0

	-- PreloadAsync yields until every asset resolves. The per-asset callback lets
	-- us surface broken MeshIds, which otherwise fail silently and show as an
	-- invisible tree in the middle of the corridor.
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(assets, function(contentId, status)
			done += 1
			if status ~= Enum.AssetFetchStatus.Success then
				failed += 1
				warn(("[Preload] FAILED %s (%s)"):format(tostring(contentId), tostring(status)))
			end
		end)
	end)

	if not ok then
		warn(("[Preload] PreloadAsync errored: %s"):format(tostring(err)))
		return
	end

	print(("[Preload] %d/%d corridor assets cached in %.2fs (%d failed)")
		:format(done - failed, done, os.clock() - started, failed))
end)
