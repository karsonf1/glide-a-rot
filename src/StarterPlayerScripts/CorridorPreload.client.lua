-- Preload the authored corridor mesh/texture assets once on join.
-- This reduces first-use download delays; it does not control render distance,
-- guarantee permanent cache residency, or wait for server-created sections.
-- Templates remain in ReplicatedStorage to match the saved authored place.

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
			warn(("[Preload] %s not found in ReplicatedStorage — preload skipped for this root"):format(rootName))
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
