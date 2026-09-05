-- ============================================================
-- HoldableToolFactory.lua  (ReplicatedStorage — ModuleScript)
-- Single source of truth for the per-species holdable Tool prefabs kept in
-- ReplicatedStorage/HoldableCreatures.
--
-- Two callers need identical prefabs:
--   * CrateSystem  — builds one the moment a rot is rolled.
--   * HoldHandler  — builds one on demand for rots loaded from a PAST session
--                    (their prefab was never built this server's lifetime).
-- Centralizing avoids the two drifting apart (which is exactly how the old
-- inline builder ended up missing the income attribute the stand relied on).
-- ============================================================

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local CreatureDictionary = require(ReplicatedStorage:WaitForChild("CreatureDictionary"))

local Factory = {}

-- Roblox rig extras that shouldn't ride along in a held tool.
local STRIP = { "AnimationController", "VfxInstance", "FakeRootPart" }

local function ensureFolder()
	local f = ReplicatedStorage:FindFirstChild("HoldableCreatures")
	if not f then
		f = Instance.new("Folder")
		f.Name = "HoldableCreatures"
		f.Parent = ReplicatedStorage
	end
	return f
end

-- Choose the part that becomes Tool.Handle. Prefer an authored top-level
-- "RootPart"; otherwise fall back to the largest top-level BasePart so models
-- WITHOUT a RootPart still render in-hand instead of silently failing.
-- (Handle must be a DIRECT child of the Tool, so we only consider top-level.)
local function pickHandle(topLevelChildren)
	for _, c in ipairs(topLevelChildren) do
		if c.Name == "RootPart" and c:IsA("BasePart") then return c end
	end
	local best, bestVol
	for _, c in ipairs(topLevelChildren) do
		if c:IsA("BasePart") then
			local vol = c.Size.X * c.Size.Y * c.Size.Z
			if not best or vol > bestVol then best, bestVol = c, vol end
		end
	end
	return best
end

-- Returns the prefab Tool for (internalName, rarity), building it once if needed.
-- Nil only if the species / model can't be resolved.
function Factory.Ensure(internalName, rarity)
	local folder   = ensureFolder()
	local toolName = internalName .. "_" .. rarity
	local existing = folder:FindFirstChild(toolName)
	if existing then return existing end

	local data = CreatureDictionary[internalName]
	if not data then
		warn(("[HoldableToolFactory] Unknown species '%s'"):format(tostring(internalName)))
		return nil
	end

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local model = modelsFolder and modelsFolder:FindFirstChild(data.ModelName or internalName)
	if not model then
		warn(("[HoldableToolFactory] Missing CreatureModel '%s'"):format(tostring(data.ModelName or internalName)))
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.CanBeDropped = false
	tool:SetAttribute("Species", internalName)
	tool:SetAttribute("Rarity", rarity)

	local clone = model:Clone()
	local handle = pickHandle(clone:GetChildren())

	-- Flatten the model's top-level children into the Tool.
	for _, child in ipairs(clone:GetChildren()) do
		child.Parent = tool
	end
	clone:Destroy()

	if handle then
		handle.Name       = "Handle"
		handle.Anchored   = false
		handle.CanCollide = false
		handle.Massless   = true
		-- Weld everything else rigidly to the Handle so the model holds its shape.
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("BasePart") and d ~= handle then
				d.Massless   = true
				d.CanCollide = false
				local w = Instance.new("WeldConstraint")
				w.Part0  = handle
				w.Part1  = d
				w.Parent = d
			end
		end
	else
		-- No usable part — tolerate rather than crash; it just won't show in-hand.
		tool.RequiresHandle = false
		warn(("[HoldableToolFactory] '%s' has no top-level BasePart for a Handle"):format(toolName))
	end

	for _, name in ipairs(STRIP) do
		local c = tool:FindFirstChild(name)
		if c then c:Destroy() end
	end

	tool.Parent = folder
	return tool
end

return Factory
