-- ============================================================
-- Stand/Script.server.lua  (Workspace/CreatureSlotPrefab/Stand — Script)
-- A rot display stand: place a held rot to bind it here (ASSIGN, not consume),
-- reclaim it back to your inventory, and have the placement survive rejoin.
--
-- Persistence lives in the OWNER's profile: PlayerData.PlacedRots[standId] =
-- { Rot, OwnerUserId }. This stand identifies itself by a StandId attribute so
-- multiple stands (a hub full of them) each persist independently. If unset, it
-- falls back to the prefab's name — fine for a single stand; SET A UNIQUE StandId
-- ATTRIBUTE per stand once the hub has more than one.
--
-- Income: while occupied, CollectionPlatform.GenerationFactor = rot.Income drives
-- the passive coin loop (see the CollectionPlatform script).
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData          = require(game.ServerScriptService.PlayerData)
local HoldableToolFactory = require(ReplicatedStorage:WaitForChild("HoldableToolFactory"))

local stand              = script.Parent
local prompt             = stand:FindFirstChild("ProximityPrompt")
local prefabFolder       = stand.Parent
local collectionPlatform = prefabFolder:WaitForChild("CollectionPlatform")
local placementNode      = prefabFolder:WaitForChild("PlacementNode")

local STAND_ID = stand:GetAttribute("StandId") or prefabFolder.Name

local currentDisplay = nil   -- the Model currently shown on this stand (or nil)

-- ── Prompt states ────────────────────────────────────────────────────────────
local function setPromptEmpty()
	if not prompt then return end
	prompt.Enabled    = true
	prompt.ActionText = "Place Rot"
end

local function setPromptOccupied(species)
	if not prompt then return end
	prompt.Enabled    = true            -- stays enabled so the owner can reclaim
	prompt.ActionText = "Reclaim " .. tostring(species)
end

-- ── Render / clear the physical model ────────────────────────────────────────
-- Build an anchored display Model from the shared prefab so placement AND restore
-- look identical (no dependence on the player still holding the tool).
local function renderPlaced(species, rarity, income)
	local prefab = HoldableToolFactory.Ensure(species, rarity)
	if not prefab then return end

	local toolClone = prefab:Clone()
	local display = Instance.new("Model")
	display.Name = "PlacedRot"
	for _, child in ipairs(toolClone:GetChildren()) do
		child.Parent = display          -- welds ride along with their parts
	end
	toolClone:Destroy()

	local handle = display:FindFirstChild("Handle")
	if handle then
		display.PrimaryPart = handle
		for _, d in ipairs(display:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide = false end
		end
		handle.Anchored = true          -- welds hold the rest rigidly to it
		display:PivotTo(placementNode.CFrame)
	end

	display.Parent = prefabFolder
	currentDisplay = display

	collectionPlatform:SetAttribute("GenerationFactor", income or 0)
	setPromptOccupied(species)
end

local function clearDisplay()
	if currentDisplay then
		currentDisplay:Destroy()
		currentDisplay = nil
	end
	collectionPlatform:SetAttribute("GenerationFactor", 0)
	setPromptEmpty()
end

-- ── Place (from a held tool) ─────────────────────────────────────────────────
local function tryPlace(player, heldTool)
	local uid = heldTool:GetAttribute("Uid")
	if not uid then return end          -- not one of our creature tools

	-- Server moves the exact instance out of inventory into this stand (persisted).
	local rot = PlayerData.PlaceRot(player, STAND_ID, uid)
	if not rot then return end          -- didn't own it / race — leave the tool be

	renderPlaced(rot.Species, rot.Rarity, rot.Income)
	heldTool:Destroy()
end

-- ── Reclaim (owner pulls their rot back) ─────────────────────────────────────
local function tryReclaim(player)
	-- Only the owner has this stand in their PlacedRots; ReclaimRot returns nil
	-- for anyone else (or if their inventory is full), which safely no-ops.
	local rot = PlayerData.ReclaimRot(player, STAND_ID)
	if not rot then return end
	clearDisplay()
end

-- ── Prompt handler ───────────────────────────────────────────────────────────
if prompt then
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if not character then return end

		if currentDisplay then
			tryReclaim(player)
		else
			local heldTool = character:FindFirstChildOfClass("Tool")
			if heldTool then
				tryPlace(player, heldTool)
			end
		end
	end)
end

-- ── Restore on join ──────────────────────────────────────────────────────────
-- When the owning player's data is loaded, re-render whatever they had on this
-- stand last session. Waits for the profile since load order vs. this script is
-- not guaranteed.
local function restoreForPlayer(player)
	local deadline = os.clock() + 15
	repeat
		if PlayerData.GetProfile(player) then break end
		task.wait(0.2)
	until os.clock() > deadline

	local placed = PlayerData.GetPlacedRots(player)[STAND_ID]
	if placed and placed.Rot and not currentDisplay then
		local rot = placed.Rot
		renderPlaced(rot.Species, rot.Rarity, rot.Income)
	end
end

Players.PlayerAdded:Connect(restoreForPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(restoreForPlayer, player)
end
