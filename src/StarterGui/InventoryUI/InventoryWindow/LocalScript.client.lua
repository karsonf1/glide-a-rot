-- ============================================================
-- InventoryWindow/LocalScript.client.lua
-- Quantity-tracked bag inventory, TweenService snap drag-and-drop,
-- live slot highlight preview, and 1–9 hotkey activation.
--
-- Studio hierarchy required:
--   InventoryUI (ScreenGui)
--     BagButton        (ImageButton)
--     DragProxy        (Frame, AnchorPoint 0.5/0.5, ZIndex 100+, Visible false)
--       ViewportFrame  (Size {1,0},{1,0}, BackgroundTransparency 1)
--     MainPanel        (Frame)
--       CardContainer  (ScrollingFrame + UIGridLayout)
--       CloseButton    (ImageButton)
--     HotbarContainer  (Frame)
--       Slot1..Slot9   (Frame, LayoutOrder 1–9)
--         ViewportFrame
--         TextLabel
--         SlotHighlight  (Frame — toggled during hover; set Visible=false by default)
--   ReplicatedStorage
--     CreatureDictionary   (ModuleScript)
--     TemplateSlot         (TextButton)
--       ViewportFrame
--       NameLabel          (TextLabel)
--       CountLabel         (TextLabel, Visible false by default)
--     UpdateInventoryClient   (RemoteEvent)
--     EquipCreatureClient     (RemoteEvent)
--     HotbarSlotActivated     (BindableEvent)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
player.CharacterAdded:Connect(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	HotbarCapacity     = 9,
	ModelLoadScale     = 1.0,
	IconFillMultiplier = 0.82,
	CameraFOV          = 40,
	ModelFrontRotation = 0,       -- set to math.pi if models face away from camera
	CameraPitchAngle   = 20,      -- degrees above horizontal (0 = eye-level, 90 = top-down)
	CameraYawAngle     = 30,      -- degrees of horizontal rotation around the model

	SnapRadius         = 80,      -- px — cursor must be within this of a slot centre to snap
	SnapTweenTime      = 0.12,    -- seconds for proxy to snap into slot
	SnapEasingStyle    = Enum.EasingStyle.Back,
	SnapEasingDir      = Enum.EasingDirection.Out,
	ReturnTweenTime    = 0.08,    -- seconds for proxy to return to origin on cancel
}

-- ============================================================
-- Dependencies
-- ============================================================
print("[Inventory] Loading dependencies...")
local CreatureDictionary   = require(ReplicatedStorage:WaitForChild("CreatureDictionary"))
print("[Inventory] CreatureDictionary OK")
local updateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventoryClient")
print("[Inventory] UpdateInventoryClient OK")
local equipCreatureEvent   = ReplicatedStorage:WaitForChild("EquipCreatureClient")
print("[Inventory] EquipCreatureClient OK")
local hotbarActivateEvent  = ReplicatedStorage:WaitForChild("HotbarSlotActivated", 5)
if hotbarActivateEvent then
	print("[Inventory] HotbarSlotActivated OK")
else
	warn("[Inventory] HotbarSlotActivated BindableEvent not found — hotkey placement disabled")
end
local templateSlot = ReplicatedStorage:WaitForChild("TemplateSlot")
print("[Inventory] TemplateSlot OK")

-- ============================================================
-- UI References
-- ============================================================
local inventoryUI     = playerGui:WaitForChild("InventoryUI")
local mainPanel       = inventoryUI:WaitForChild("MainPanel")
local cardContainer   = mainPanel:WaitForChild("CardContainer")
local hotbarContainer = inventoryUI:WaitForChild("HotbarContainer")
local bagButton   = inventoryUI:WaitForChild("BagButton",  5) :: ImageButton
local closeButton = mainPanel:WaitForChild("CloseButton",  5) :: ImageButton
local dragProxy   = inventoryUI:WaitForChild("DragProxy",  5)

if not bagButton   then warn("[Inventory] BagButton not found")  end
if not closeButton then warn("[Inventory] CloseButton not found") end
if not dragProxy   then warn("[Inventory] DragProxy not found — drag disabled") end

local dragProxyViewport = dragProxy and dragProxy:FindFirstChildWhichIsA("ViewportFrame")
if dragProxy and not dragProxyViewport then
	warn("[Inventory] DragProxy has no ViewportFrame — 3D drag preview disabled")
end

-- Build hotbarSlots[1..9] by parsing the trailing number from each frame's name
-- (e.g. "Slot1" → index 1, "HotbarSlot9" → index 9).
-- This makes KeyCode.One always bind to the frame named *1 regardless of LayoutOrder,
-- which was the root cause of the reversed key mapping.
local hotbarSlots = (function()
	local frames     = {}
	local nameCount  = 0
	for _, child in ipairs(hotbarContainer:GetChildren()) do
		if child:IsA("Frame") then
			local idx = tonumber(child.Name:match("%d+$"))
			if idx and idx >= 1 and idx <= CONFIG.HotbarCapacity then
				frames[idx] = child
				nameCount   += 1
			end
		end
	end
	if nameCount == CONFIG.HotbarCapacity then
		return frames   -- name-parse succeeded; index ≡ visual slot number
	end
	-- Fallback: sort by LayoutOrder (requires LayoutOrder 1 = leftmost slot in Studio)
	warn("[Inventory] Name-parse found only", nameCount,
		"of", CONFIG.HotbarCapacity, "slots — falling back to LayoutOrder sort.",
		"Rename hotbar frames so they end in 1–9 to fix any remaining key inversion.")
	local ordered = {}
	for _, child in ipairs(hotbarContainer:GetChildren()) do
		if child:IsA("Frame") then table.insert(ordered, child) end
	end
	table.sort(ordered, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	return ordered
end)()

print("[Inventory] Found", #hotbarSlots, "hotbar slot frames")

local SNAP_INFO   = TweenInfo.new(CONFIG.SnapTweenTime,   CONFIG.SnapEasingStyle, CONFIG.SnapEasingDir)
local RETURN_INFO = TweenInfo.new(CONFIG.ReturnTweenTime, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)

-- ============================================================
-- State
-- ============================================================
-- bagInventory  : creatures sitting in the bag (not equipped)
-- bagOrder      : stable display order for bag cards
-- hotbar        : hotbar[1..9] = internalName or nil (fully decoupled from bag)
-- slotConns     : InputBegan handles on cloned bag cards (disconnected on each rebuild)
local bagInventory = {}
local bagOrder     = {}
local hotbar       = {}
local slotConns    = {}

local dragState = {
	active       = false,
	internalName = nil,
	originPos    = nil,   -- UDim2 starting position; used for cancel-return tween
	snapTarget   = nil,   -- currently highlighted slot index during hover
	moveConn     = nil,
	endConn      = nil,
}
local activeTween = nil   -- one global handle so we can cancel mid-snap on new drag

-- Forward declarations — assigned below after their own dependencies are defined.
-- This is required because refreshBagUI references startDrag inside a closure,
-- and startDrag/endDrag reference each other indirectly through commitEquip.
local startDrag
local refreshBagUI

-- ============================================================
-- Viewport model loading (shared by bag cards, hotbar, and DragProxy)
-- ============================================================
local function loadModelIntoViewport(vp, internalName)
	for _, child in ipairs(vp:GetChildren()) do child:Destroy() end

	local data = CreatureDictionary[internalName]
	if not data then return end

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	if not modelsFolder then return end

	local model = modelsFolder:FindFirstChild(data.ModelName or internalName)
	if not model then return end

	local clone = model:Clone()
	for _, stripName in ipairs({"AnimationController", "VfxInstance", "FakeRootPart"}) do
		local c = clone:FindFirstChild(stripName)
		if c then c:Destroy() end
	end

	clone:ScaleTo(CONFIG.ModelLoadScale)

	local bbCFrame, bbSize = clone:GetBoundingBox()
	local pivotToBB = bbCFrame.Position - clone:GetPivot().Position
	local yCenter   = bbSize.Y * 0.5
	local maxDim    = math.max(bbSize.X, bbSize.Y, bbSize.Z)

	if CONFIG.ModelFrontRotation == 0 then
		clone:PivotTo(CFrame.new(-pivotToBB.X, yCenter - pivotToBB.Y, -pivotToBB.Z))
	else
		local cosR = math.cos(CONFIG.ModelFrontRotation)
		local sinR = math.sin(CONFIG.ModelFrontRotation)
		clone:PivotTo(CFrame.new(
			-(pivotToBB.X * cosR + pivotToBB.Z * sinR),
			  yCenter - pivotToBB.Y,
			  pivotToBB.X * sinR - pivotToBB.Z * cosR
		) * CFrame.Angles(0, CONFIG.ModelFrontRotation, 0))
	end

	local camera       = Instance.new("Camera")
	camera.FieldOfView = CONFIG.CameraFOV
	vp.CurrentCamera   = camera
	camera.Parent      = vp

	local halfFov  = math.rad(CONFIG.CameraFOV / 2)
	local dist     = (maxDim * 0.5) / (math.tan(halfFov) * CONFIG.IconFillMultiplier)
	local pitchRad = math.rad(CONFIG.CameraPitchAngle)
	local yawRad   = math.rad(CONFIG.CameraYawAngle)
	camera.CFrame  = CFrame.new(
		Vector3.new(
			 dist * math.sin(yawRad) * math.cos(pitchRad),
			 yCenter + dist * math.sin(pitchRad),
			-dist * math.cos(yawRad) * math.cos(pitchRad)
		),
		Vector3.new(0, yCenter, 0)
	)

	clone.Parent = vp
end

-- ============================================================
-- Bag mutation helpers — single point of truth for +/- operations
-- ============================================================
local function addToBag(internalName)
	if bagInventory[internalName] then
		bagInventory[internalName].Quantity += 1
	else
		bagInventory[internalName] = { InternalName = internalName, Quantity = 1 }
		table.insert(bagOrder, internalName)
	end
end

local function takeFromBag(internalName)
	local entry = bagInventory[internalName]
	if not entry then return end
	entry.Quantity -= 1
	if entry.Quantity <= 0 then
		bagInventory[internalName] = nil
		for i = #bagOrder, 1, -1 do
			if bagOrder[i] == internalName then
				table.remove(bagOrder, i)
				break
			end
		end
	end
end

-- ============================================================
-- Hotbar geometry helpers
-- ============================================================
local function getSlotCentre(frame)
	return Vector2.new(
		frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.5,
		frame.AbsolutePosition.Y + frame.AbsoluteSize.Y * 0.5
	)
end

-- Returns the index of the nearest hotbar slot within CONFIG.SnapRadius, or nil.
local function getNearestSlot(screenPos)
	local bestIndex, bestDist = nil, math.huge
	local sv = Vector2.new(screenPos.X, screenPos.Y)
	for i, frame in ipairs(hotbarSlots) do
		local dist = (sv - getSlotCentre(frame)).Magnitude
		if dist < bestDist then
			bestDist  = dist
			bestIndex = i
		end
	end
	return (bestDist <= CONFIG.SnapRadius) and bestIndex or nil
end

-- Toggles the pre-built SlotHighlight child Frame inside each hotbar slot.
-- Pass nil to clear all highlights.
local function setSlotHighlight(activeIndex)
	for i, frame in ipairs(hotbarSlots) do
		local hl = frame:FindFirstChild("SlotHighlight")
		if hl then hl.Visible = (i == activeIndex) end
	end
end

-- ============================================================
-- Hotbar UI helpers
-- ============================================================
local function clearHotbarSlot(frame)
	local vp    = frame:FindFirstChildWhichIsA("ViewportFrame")
	local label = frame:FindFirstChildWhichIsA("TextLabel")
	if vp then
		for _, c in ipairs(vp:GetChildren()) do c:Destroy() end
		vp.CurrentCamera = nil
	end
	if label then label.Text = "" end
end

local function populateHotbarSlot(frame, internalName)
	clearHotbarSlot(frame)
	if not internalName then return end
	local data  = CreatureDictionary[internalName]
	local label = frame:FindFirstChildWhichIsA("TextLabel")
	local vp    = frame:FindFirstChildWhichIsA("ViewportFrame")
	if label then label.Text = (data and data.DisplayName) or internalName end
	if vp    then loadModelIntoViewport(vp, internalName) end
end

local function refreshHotbarUI()
	for i, frame in ipairs(hotbarSlots) do
		populateHotbarSlot(frame, hotbar[i])
	end
end

-- ============================================================
-- DragProxy
-- ============================================================
local function clearDragProxy()
	if not dragProxy then return end
	dragProxy.Visible = false
	if dragProxyViewport then
		for _, c in ipairs(dragProxyViewport:GetChildren()) do c:Destroy() end
		dragProxyViewport.CurrentCamera = nil
	end
end

-- ============================================================
-- Equip commit — called AFTER the snap tween fully completes
-- ============================================================
local function commitEquip(incomingName, targetIndex)
	local displacedName = hotbar[targetIndex]
	if displacedName == incomingName then return end

	if displacedName then addToBag(displacedName) end   -- return displaced to bag
	takeFromBag(incomingName)                           -- consume one bag copy

	hotbar[targetIndex] = incomingName
	equipCreatureEvent:FireServer(incomingName, targetIndex)

	print("[Inventory] Equipped", incomingName, "→ slot", targetIndex,
		displacedName and ("(displaced " .. displacedName .. ")") or "")

	refreshBagUI()     -- upvalue; assigned below
	refreshHotbarUI()
end

-- ============================================================
-- Drag system
-- ============================================================
local function endDrag(screenPos)
	if not dragState.active then return end

	if dragState.moveConn then dragState.moveConn:Disconnect(); dragState.moveConn = nil end
	if dragState.endConn  then dragState.endConn:Disconnect();  dragState.endConn  = nil end

	setSlotHighlight(nil)

	local snapIndex    = getNearestSlot(screenPos)
	local incomingName = dragState.internalName
	local originPos    = dragState.originPos

	-- Clear transient state before any async work
	dragState.active       = false
	dragState.internalName = nil
	dragState.originPos    = nil
	dragState.snapTarget   = nil

	if not dragProxy then return end

	if activeTween then activeTween:Cancel(); activeTween = nil end

	if snapIndex and incomingName then
		-- ── SNAP: tween proxy to slot centre, then commit equip ──────────
		local centre = getSlotCentre(hotbarSlots[snapIndex])
		local tween  = TweenService:Create(dragProxy, SNAP_INFO, {
			Position = UDim2.fromOffset(centre.X, centre.Y),
		})
		activeTween = tween
		tween.Completed:Connect(function(state)
			activeTween = nil
			if state == Enum.PlaybackState.Completed then
				commitEquip(incomingName, snapIndex)
			end
			clearDragProxy()
		end)
		tween:Play()

	elseif originPos then
		-- ── CANCEL: tween proxy back to drag origin ───────────────────────
		local tween = TweenService:Create(dragProxy, RETURN_INFO, {
			Position = originPos,
		})
		activeTween = tween
		tween.Completed:Connect(function()
			activeTween = nil
			clearDragProxy()
		end)
		tween:Play()

	else
		clearDragProxy()
	end
end

-- Assigned to the forward-declared upvalue so closures inside refreshBagUI see it.
startDrag = function(internalName, startPos)
	if dragState.active then return end

	-- Kill any leftover snap/return tween before showing the proxy for new drag
	if activeTween then activeTween:Cancel(); activeTween = nil end
	clearDragProxy()

	dragState.active       = true
	dragState.internalName = internalName
	dragState.originPos    = UDim2.fromOffset(startPos.X, startPos.Y)

	if dragProxy then
		dragProxy.Position = dragState.originPos
		dragProxy.Visible  = true
		if dragProxyViewport then
			loadModelIntoViewport(dragProxyViewport, internalName)
		end
	end

	dragState.moveConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end

		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if dragProxy then
			dragProxy.Position = UDim2.fromOffset(pos.X, pos.Y)
		end

		-- Live snap preview: highlight nearest in-range slot every frame
		local nearest = getNearestSlot(pos)
		if nearest ~= dragState.snapTarget then
			dragState.snapTarget = nearest
			setSlotHighlight(nearest)
		end
	end)

	dragState.endConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
		endDrag(Vector2.new(input.Position.X, input.Position.Y))
	end)
end

-- ============================================================
-- Bag UI — assigned to the forward-declared upvalue
-- ============================================================
refreshBagUI = function()
	for _, conn in ipairs(slotConns) do conn:Disconnect() end
	slotConns = {}

	for _, child in ipairs(cardContainer:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end

	for i, internalName in ipairs(bagOrder) do
		local entry = bagInventory[internalName]
		local data  = CreatureDictionary[internalName]
		if not entry or not data then continue end

		local card       = templateSlot:Clone()
		card.Name        = "Card_" .. internalName
		card.LayoutOrder = i
		card.Parent      = cardContainer

		local nameLabel = card:FindFirstChild("NameLabel")
		if nameLabel then nameLabel.Text = data.DisplayName or internalName end

		local countLabel = card:FindFirstChild("CountLabel")
		if countLabel then
			countLabel.Visible = entry.Quantity > 1
			countLabel.Text    = "x" .. entry.Quantity
		end

		local rarityColor = CreatureDictionary.RarityColors
			and CreatureDictionary.RarityColors[data.Rarity]
		if rarityColor then card.BackgroundColor3 = rarityColor end

		local vp = card:FindFirstChildWhichIsA("ViewportFrame")
		if vp then loadModelIntoViewport(vp, internalName) end

		-- Wire drag: startDrag is already assigned by this point
		local conn = card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
			startDrag(internalName, Vector2.new(input.Position.X, input.Position.Y))
		end)
		table.insert(slotConns, conn)
	end

	print("[Inventory] Bag rebuilt —", #bagOrder, "unique creatures")
end

-- ============================================================
-- Hotbar click — unequip: return creature to bag
-- ============================================================
for i, frame in ipairs(hotbarSlots) do
	frame.Active = true
	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if dragState.active then return end   -- ignore clicks mid-drag
		local name = hotbar[i]
		if not name then return end
		addToBag(name)
		hotbar[i] = nil
		print("[Inventory] Unequipped", name, "from slot", i, "— returned to bag")
		refreshBagUI()
		refreshHotbarUI()
	end)
end

-- ============================================================
-- Server sync
-- ============================================================
local function reconcileInventory(serverArray)
	-- Tally hotbar allocation; bag shows only unequipped copies
	local hotbarCount = {}
	for _, name in pairs(hotbar) do
		if name then hotbarCount[name] = (hotbarCount[name] or 0) + 1 end
	end

	-- serverArray entries may be plain strings (legacy) or rot objects {Species, Rarity, Income}.
	local serverCounts = {}
	for _, entry in ipairs(serverArray) do
		local name = type(entry) == "table" and entry.Species or entry
		if type(name) == "string" then
			serverCounts[name] = (serverCounts[name] or 0) + 1
		end
	end

	-- Prune hotbar entries whose creature was removed server-side
	for slot = 1, CONFIG.HotbarCapacity do
		if hotbar[slot] and not serverCounts[hotbar[slot]] then
			hotbar[slot] = nil
		end
	end

	-- Remove bag entries no longer on the server
	for i = #bagOrder, 1, -1 do
		local name = bagOrder[i]
		if not serverCounts[name] then
			bagInventory[name] = nil
			table.remove(bagOrder, i)
		end
	end

	-- Bag quantity = server total minus hotbar allocation
	for name, count in pairs(serverCounts) do
		local bagQty = math.max(0, count - (hotbarCount[name] or 0))
		if bagQty > 0 then
			if bagInventory[name] then
				bagInventory[name].Quantity = bagQty
			else
				bagInventory[name] = { InternalName = name, Quantity = bagQty }
				table.insert(bagOrder, name)
			end
		else
			-- All copies are currently equipped; remove card from bag view
			bagInventory[name] = nil
			for i = #bagOrder, 1, -1 do
				if bagOrder[i] == name then
					table.remove(bagOrder, i)
					break
				end
			end
		end
	end
end

updateInventoryEvent.OnClientEvent:Connect(function(inventoryArray)
	print("[Inventory] Server sync —", #(inventoryArray or {}), "entries")
	reconcileInventory(inventoryArray or {})
	refreshBagUI()
	refreshHotbarUI()
end)

-- ============================================================
-- Panel visibility
-- ============================================================
mainPanel.Visible = false
print("[Inventory] Ready — awaiting BagButton click")

if bagButton then
	bagButton.MouseButton1Click:Connect(function()
		print("[Inventory] Opening inventory")
		mainPanel.Visible = true
	end)
end

if closeButton then
	closeButton.MouseButton1Click:Connect(function()
		print("[Inventory] Closing inventory")
		mainPanel.Visible = false
	end)
end

-- ============================================================
-- Keyboard hotkeys 1–9
-- ============================================================
local KEYCODE_TO_SLOT = {
	[Enum.KeyCode.One]   = 1, [Enum.KeyCode.Two]   = 2,
	[Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four]  = 4,
	[Enum.KeyCode.Five]  = 5, [Enum.KeyCode.Six]   = 6,
	[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine]  = 9,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local slotIndex = KEYCODE_TO_SLOT[input.KeyCode]
	if not slotIndex then return end
	local name = hotbar[slotIndex]
	if not name then
		print("[Inventory] Hotkey", slotIndex, "— slot empty")
		return
	end
	print("[Inventory] Hotkey", slotIndex, "— activating", name)
	equipCreatureEvent:FireServer(name, slotIndex)
	if hotbarActivateEvent then
		hotbarActivateEvent:Fire({ InternalName = name, SlotIndex = slotIndex })
	end
end)
