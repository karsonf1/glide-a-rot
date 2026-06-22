local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player      = Players.LocalPlayer
local crateOverlay = script.Parent
local crateUI      = crateOverlay.Parent
local openCrateBtn = crateUI:FindFirstChild("OpenCrateButton")
local titleLabel   = crateOverlay:FindFirstChild("TitleLabel")
local spinContainer = crateOverlay:FindFirstChild("SpinContainer")
local errorLabel   = crateOverlay:FindFirstChild("ErrorLabel")

-- Result card elements; all populated by buildResultCard() during init
local resultCard       = nil
local resultCardDimmer = nil
local resultCardVP     = nil
local resultCardName   = nil
local resultCardRarity = nil
local resultCardIncome = nil
local resultCardHeader = nil

local CreatureDictionary = require(ReplicatedStorage:WaitForChild("CreatureDictionary"))
local openCrateEvent     = ReplicatedStorage:WaitForChild("OpenCrateClient")
local crateResultEvent   = ReplicatedStorage:WaitForChild("CrateResultClient")
local crateRollDataEvent = ReplicatedStorage:WaitForChild("CrateRollDataClient")

-- ============================================================
-- CONFIG — all structural math parameters, tune here
-- ============================================================
local CONFIG = {
	EllipseRadiusX       = 320,         -- Horizontal spread of the carousel (pixels)
	EllipseRadiusY       = 60,          -- Vertical compression for flat isometric look (pixels)
	CenterX              = 0.5,         -- Carousel pivot as fraction of spinContainer width
	SpinnerCenterYOffset = 0.65,        -- Carousel pivot as fraction of spinContainer height (lower = higher on screen)
	DepthScaleMin        = 0.55,        -- Frame scale at the back of the ellipse (farthest)
	DepthScaleMax        = 1.00,        -- Frame scale at the front of the ellipse (closest)
	FrameCount           = 8,           -- Fixed pool size; must evenly divide TAU for clean spacing
	FrameBaseSize        = 110,         -- Pixel width/height of a frame at DepthScaleMax
	SpinDuration         = 4.2,         -- Total animation duration in seconds
	MinFullRotations     = 4,           -- Minimum full sequence loops before landing on winner
	BaseDeceleration     = 3.5,         -- Exponent for ease-out curve (higher = snappier stop)
	FrontAngle           = math.pi / 2, -- Ellipse angle (rad) that represents the "front" position
	ModelLoadThreshold   = 0.65,        -- Fraction of SpinDuration after which 3D models load into frames
	CreatureModelScale   = 0.5,         -- ScaleTo factor applied to creature models inside carousel frames (0.4–0.6)
	SpinnerFillMultiplier  = 0.82,      -- Fraction of the square card the creature fills (0.7–0.95; higher = more zoomed)
	WinnerHeroDistance     = 1.8,       -- Result-screen camera pull-back; lower values zoom in more
	GlobalRotationSpeed    = 0.6,       -- Radians per second; result-screen creature rotates at this rate
}

-- ============================================================
-- Constants derived from CONFIG
-- ============================================================
local TAU        = math.pi * 2
local SLOT_ANGLE = TAU / CONFIG.FrameCount

local rarityColors = CreatureDictionary.RarityColors or {
	Common    = Color3.fromRGB(180, 180, 180),
	Rare      = Color3.fromRGB(85, 170, 255),
	Epic      = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
}

-- ============================================================
-- State
-- ============================================================
local isSpinning   = false
local wheelPos     = 0.0    -- Continuous float. floor(wheelPos) = sequence index at front slot.
local sequenceData = {}
local framePool    = {}     -- Array of { frame, vp, nameLabel, lastDataIdx }
local renderConn   = nil    -- RenderStepped handle; always disconnected when spin ends
local heroRotConn     = nil  -- RenderStepped handle for result-screen rotation; disconnected on overlay close
local skipDismissConn = nil  -- InputBegan handle for skip-to-dismiss; cleared when overlay closes

-- ============================================================
-- Frame pool construction (called once on init)
-- ============================================================
local function buildFramePool()
	for _, entry in ipairs(framePool) do
		entry.frame:Destroy()
	end
	framePool = {}

	for i = 1, CONFIG.FrameCount do
		local frame = Instance.new("Frame")
		frame.Name = "CarouselFrame" .. i
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.new(0, CONFIG.FrameBaseSize, 0, CONFIG.FrameBaseSize)
		frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		frame.BorderSizePixel = 0
		frame.Visible = false

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local vp = Instance.new("ViewportFrame")
		vp.Name = "MiniModel"
		vp.Size = UDim2.new(1, -8, 0.62, 0)
		vp.Position = UDim2.new(0, 4, 0, 4)
		vp.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		vp.BackgroundTransparency = 0.4
		vp.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -4, 0.34, 0)
		nameLabel.Position = UDim2.new(0, 2, 0.63, 4)
		nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.BackgroundTransparency = 0.45
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 10
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = ""
		nameLabel.Parent = frame

		local nlCorner = Instance.new("UICorner")
		nlCorner.CornerRadius = UDim.new(0, 6)
		nlCorner.Parent = nameLabel

		frame.Parent = spinContainer

		framePool[i] = {
			frame       = frame,
			vp          = vp,
			nameLabel   = nameLabel,
			lastDataIdx = -1,
		}
	end
end

-- ============================================================
-- Viewport loading
-- ============================================================
local function loadModelIntoViewport(vp, creatureData)
	for _, child in ipairs(vp:GetChildren()) do
		child:Destroy()
	end

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	if not modelsFolder then return end

	local model = modelsFolder:FindFirstChild(creatureData.ModelName or creatureData.InternalName)
	if not model then return end

	local clone = model:Clone()
	for _, stripName in ipairs({"AnimationController", "VfxInstance", "FakeRootPart"}) do
		local c = clone:FindFirstChild(stripName)
		if c then c:Destroy() end
	end

	-- Scale the creature down to a miniature figurine size before measuring
	clone:ScaleTo(CONFIG.CreatureModelScale)

	-- GetBoundingBox returns the BB *center* in world space, which is not the same
	-- as the model pivot. We compute the pivot→BB offset so we can back-solve for the
	-- exact PivotTo position that places the BB center at (0, yCenter, 0).
	local bbCFrame, bbSize = clone:GetBoundingBox()
	local pivotToBB = bbCFrame.Position - clone:GetPivot().Position

	local yCenter = bbSize.Y * 0.5
	local maxDim  = math.max(bbSize.X, bbSize.Y, bbSize.Z)

	-- Place the bounding box base at Y=0, center at (0, yCenter, 0)
	clone:PivotTo(CFrame.new(
		-pivotToBB.X,
		yCenter - pivotToBB.Y,
		-pivotToBB.Z
	))

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	vp.CurrentCamera = camera
	camera.Parent = vp

	-- FOV-based distance so the creature fills SpinnerFillMultiplier of the square frame
	local halfFov = math.rad(camera.FieldOfView / 2)
	local dist = (maxDim * 0.5) / (math.tan(halfFov) * CONFIG.SpinnerFillMultiplier)
	-- Front-facing: camera sits on the -Z axis looking toward +Z (model's face)
	camera.CFrame = CFrame.new(
		Vector3.new(0, yCenter, -dist),
		Vector3.new(0, yCenter, 0)
	)
	clone.Parent = vp
end

local function clearViewport(vp)
	for _, child in ipairs(vp:GetChildren()) do
		child:Destroy()
	end
end

-- ============================================================
-- Frame data update (skips unchanged frames via lastDataIdx)
-- ============================================================
local function updateFrameData(entry, dataIdx, spinProgress)
	if entry.lastDataIdx == dataIdx then return end
	entry.lastDataIdx = dataIdx

	local seqLen = #sequenceData
	if seqLen == 0 then return end

	-- Safe modulo for negative dataIdx values that may occur at spin start
	local safeIdx = ((dataIdx % seqLen) + seqLen) % seqLen
	local creature = sequenceData[safeIdx + 1]
	if not creature then return end

	entry.frame.BackgroundColor3 = rarityColors[creature.Rarity] or rarityColors.Common
	entry.nameLabel.Text = creature.DisplayName or creature.InternalName

	-- Defer 3D model loads until the spin is slowing down to avoid frame-rate hitching
	if spinProgress >= CONFIG.ModelLoadThreshold then
		loadModelIntoViewport(entry.vp, creature)
	else
		clearViewport(entry.vp)
	end
end

-- ============================================================
-- Per-frame carousel layout update
-- Uses math.sin / math.cos on an ellipse to position each frame.
-- depth = (sin(angle)+1)/2 maps [back=-1 … front=+1] to [0…1].
-- Scale and ZIndex are derived from depth for genuine 3D perspective.
-- ============================================================
local function updateCarousel(wp, spinProgress)
	local containerSize = spinContainer.AbsoluteSize
	local centerLocalX  = containerSize.X * CONFIG.CenterX
	local centerLocalY  = containerSize.Y * CONFIG.SpinnerCenterYOffset

	-- fracPart shifts all frames smoothly between integer slot boundaries
	local fracPart   = wp - math.floor(wp)
	local baseSlotIdx = math.floor(wp)

	for i = 1, CONFIG.FrameCount do
		local entry = framePool[i]
		local slotOffset = i - 1

		-- Angle of this frame on the ellipse.
		-- Frame 0 (slotOffset=0) targets FrontAngle when fracPart=0.
		-- As wheelPos increases by 1, every frame shifts back by SLOT_ANGLE.
		local angle = CONFIG.FrontAngle + (slotOffset - fracPart) * SLOT_ANGLE

		-- Ellipse screen position (local within spinContainer)
		local localX = centerLocalX + CONFIG.EllipseRadiusX * math.cos(angle)
		local localY = centerLocalY + CONFIG.EllipseRadiusY * math.sin(angle)

		-- Depth: sin ranges −1 (back) → +1 (front/bottom of ellipse)
		local depth = (math.sin(angle) + 1) / 2   -- 0 = furthest back, 1 = front
		local scale = CONFIG.DepthScaleMin + depth * (CONFIG.DepthScaleMax - CONFIG.DepthScaleMin)
		local pixelSize = CONFIG.FrameBaseSize * scale

		-- Hide frames that are at extreme back-arc to keep the view clean
		local visible = depth > 0.05
		entry.frame.Visible = visible

		if visible then
			entry.frame.Position = UDim2.new(0, localX, 0, localY)
			entry.frame.Size     = UDim2.new(0, pixelSize, 0, pixelSize)
			-- ZIndex 1–10, front frames render over back frames
			local zIndex = math.max(1, math.floor(1 + depth * 9))
			entry.frame.ZIndex      = zIndex
			entry.nameLabel.ZIndex  = zIndex + 1
			entry.vp.ZIndex         = zIndex

			updateFrameData(entry, baseSlotIdx + slotOffset, spinProgress)
		end
	end
end

-- ============================================================
-- Spin sequence and animation
-- ============================================================

-- Computes the final wheelPos needed to display the winner at the front slot.
-- Adds enough full sequence loops to guarantee MinFullRotations worth of travel.
local function computeTargetWheelPos(winnerIndex, seqLen)
	-- winner is at 0-based index: winnerIndex - 1
	-- frame 0 (slotOffset=0) is the front slot; it shows sequence[floor(wp) % seqLen + 1]
	-- so we need floor(targetWp) % seqLen == winnerIndex - 1
	local base = winnerIndex - 1
	local minSlots = CONFIG.MinFullRotations * seqLen
	local extraLoops = math.ceil(minSlots / seqLen)
	return base + extraLoops * seqLen
end

local function startSpin(sequence, winnerIndex)
	sequenceData = sequence
	wheelPos = 0.0

	-- Reset all frames so they don't carry stale data from a prior spin
	for _, entry in ipairs(framePool) do
		entry.lastDataIdx = -1
		entry.frame.Visible = false
		clearViewport(entry.vp)
	end

	local targetWheelPos = computeTargetWheelPos(winnerIndex, #sequence)
	local startTime      = tick()
	local duration       = CONFIG.SpinDuration

	-- Disconnect any leftover connection from an interrupted spin
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end

	renderConn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local t = math.min(elapsed / duration, 1)

		-- Ease-out: fast acceleration at start, smooth deceleration to exact stop
		local eased = 1 - (1 - t) ^ CONFIG.BaseDeceleration

		wheelPos = eased * targetWheelPos
		updateCarousel(wheelPos, t)

		if t >= 1 then
			renderConn:Disconnect()
			renderConn = nil
		end
	end)
end

-- ============================================================
-- Result display
-- ============================================================
local function setupModelPreview(internalName, modelName)
	if not resultCardVP then return end

	for _, child in ipairs(resultCardVP:GetChildren()) do
		child:Destroy()
	end
	-- Kill any previous rotation loop before starting a new showcase
	if heroRotConn then
		heroRotConn:Disconnect()
		heroRotConn = nil
	end

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	if not modelsFolder then return end
	local model = modelsFolder:FindFirstChild(modelName or internalName)
	if not model then return end

	local clone = model:Clone()
	for _, stripName in ipairs({"AnimationController", "VfxInstance", "FakeRootPart"}) do
		local c = clone:FindFirstChild(stripName)
		if c then c:Destroy() end
	end

	-- Same pivot-offset correction as the spinner loader: back-solve so the BB center
	-- lands exactly at (0, yCenter, 0) regardless of where the model's pivot sits.
	local bbCFrame, bbSize = clone:GetBoundingBox()
	local pivotToBB = bbCFrame.Position - clone:GetPivot().Position

	local yCenter = bbSize.Y * 0.5
	local maxDim  = math.max(bbSize.X, bbSize.Y, bbSize.Z)

	clone:PivotTo(CFrame.new(
		-pivotToBB.X,
		yCenter - pivotToBB.Y,
		-pivotToBB.Z
	))

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	resultCardVP.CurrentCamera = camera
	camera.Parent = resultCardVP

	local halfFov = math.rad(camera.FieldOfView / 2)
	local dist = (maxDim * 0.5) / (math.tan(halfFov) * CONFIG.WinnerHeroDistance)
	-- Camera sits 40% up the model so the creature fills the frame without clipping
	local camY  = yCenter * 0.4
	camera.CFrame = CFrame.new(
		Vector3.new(0, camY, -dist),
		Vector3.new(0, yCenter, 0)
	)

	clone.Parent = resultCardVP

	-- Rotate around the BB center (0, yCenter, 0), NOT the pivot.
	-- The pivot is typically at the model's feet, so naively placing it at yCenter each frame
	-- causes the geometry to float up by pivotToBB.Y, putting feet in view instead of the body.
	-- Fix: back-solve the pivot position for each angle so BB center stays pinned at (0, yCenter, 0).
	local rotY = 0
	heroRotConn = RunService.RenderStepped:Connect(function(dt)
		rotY = rotY + CONFIG.GlobalRotationSpeed * dt
		local cosR = math.cos(rotY)
		local sinR = math.sin(rotY)
		local px = -(pivotToBB.X * cosR + pivotToBB.Z * sinR)
		local py =   yCenter - pivotToBB.Y
		local pz =   pivotToBB.X * sinR - pivotToBB.Z * cosR
		clone:PivotTo(CFrame.new(px, py, pz) * CFrame.Angles(0, rotY, 0))
	end)
end

local function showResult(displayName, rarity, incomeRate)
	local rarityColor = rarityColors[rarity] or Color3.fromRGB(180, 180, 180)

	if resultCardHeader then resultCardHeader.BackgroundColor3 = rarityColor end
	if resultCardRarity then
		resultCardRarity.Text       = rarity:upper()
		resultCardRarity.TextColor3 = Color3.new(1, 1, 1)
	end
	if resultCardName   then resultCardName.Text = displayName end
	if resultCardIncome then
		resultCardIncome.Text = "Base Income: " .. (incomeRate or 0) .. " / sec"
	end

	if resultCard       then resultCard.Visible = true end
	if resultCardDimmer then resultCardDimmer.Visible = true end
end

-- ============================================================
-- Result card construction (called once during init)
-- ============================================================
local function buildResultCard()
	-- Darkens the spinner behind the card
	local dimmer = Instance.new("Frame")
	dimmer.Name = "ResultDimmer"
	dimmer.Size = UDim2.new(1, 0, 1, 0)
	dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimmer.BackgroundTransparency = 0.45
	dimmer.BorderSizePixel = 0
	dimmer.ZIndex = 20
	dimmer.Visible = false
	dimmer.Parent = crateOverlay

	-- Main card panel
	local card = Instance.new("Frame")
	card.Name = "ResultCard"
	card.Size = UDim2.new(0, 400, 0, 480)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.ClipsDescendants = true   -- lets UICorner round-clip all children
	card.ZIndex = 21
	card.Visible = false
	card.Parent = crateOverlay

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card

	-- Rarity-colored header strip (card ClipsDescendants rounds its top corners)
	local header = Instance.new("Frame")
	header.Name = "RarityHeader"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	header.BorderSizePixel = 0
	header.ZIndex = 22
	header.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 1, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = "COMMON"
	rarityLabel.TextColor3 = Color3.new(1, 1, 1)
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.TextSize = 22
	rarityLabel.ZIndex = 23
	rarityLabel.Parent = header

	-- Hero ViewportFrame — wide rectangle for the rotating creature showcase
	local vp = Instance.new("ViewportFrame")
	vp.Name = "HeroViewport"
	vp.Size = UDim2.new(1, -32, 0, 282)
	vp.Position = UDim2.new(0, 16, 0, 68)
	vp.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.ZIndex = 22
	vp.Parent = card

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 10)
	vpCorner.Parent = vp

	-- Creature display name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CreatureName"
	nameLabel.Size = UDim2.new(1, -32, 0, 46)
	nameLabel.Position = UDim2.new(0, 16, 0, 360)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 28
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.ZIndex = 22
	nameLabel.Parent = card

	-- Base income per second
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, -32, 0, 30)
	incomeLabel.Position = UDim2.new(0, 16, 0, 410)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "Base Income: 0 / sec"
	incomeLabel.TextColor3 = Color3.fromRGB(255, 210, 70)
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextSize = 18
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.ZIndex = 22
	incomeLabel.Parent = card

	-- Dismiss hint — card auto-closes after 2 s or on any key press
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "DismissHint"
	hintLabel.Size = UDim2.new(1, -32, 0, 22)
	hintLabel.Position = UDim2.new(0, 16, 0, 448)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "Press any key to skip"
	hintLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 14
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.ZIndex = 22
	hintLabel.Parent = card

	resultCard       = card
	resultCardDimmer = dimmer
	resultCardVP     = vp
	resultCardName   = nameLabel
	resultCardRarity = rarityLabel
	resultCardIncome = incomeLabel
	resultCardHeader = header
end

local function closeCrateOverlay()
	-- Always disconnect all render loops on close to prevent memory leaks
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if heroRotConn then
		heroRotConn:Disconnect()
		heroRotConn = nil
	end
	if skipDismissConn then
		skipDismissConn:Disconnect()
		skipDismissConn = nil
	end

	crateOverlay.Visible = false
	if resultCard       then resultCard.Visible = false end
	if resultCardDimmer then resultCardDimmer.Visible = false end
	if errorLabel  then errorLabel.Visible = false end

	isSpinning   = false
	sequenceData = {}
	wheelPos     = 0.0

	for _, entry in ipairs(framePool) do
		entry.frame.Visible = false
		entry.lastDataIdx   = -1
		clearViewport(entry.vp)
	end
end

-- ============================================================
-- Button wiring
-- ============================================================
if openCrateBtn then
	openCrateBtn.MouseButton1Click:Connect(function()
		if isSpinning then return end
		isSpinning = true

		crateOverlay.Visible = true
		if resultCard       then resultCard.Visible = false end
		if resultCardDimmer then resultCardDimmer.Visible = false end
		if errorLabel  then errorLabel.Visible = false end
		if titleLabel  then titleLabel.Text = "Opening Crate..." end

		openCrateEvent:FireServer()
	end)
end

-- ============================================================
-- Server event handlers
-- ============================================================

-- Roll data arrives immediately after the server confirms the spend.
-- Sequence, winner position, and per-creature coin reward are all passed together.
if crateRollDataEvent then
	crateRollDataEvent.OnClientEvent:Connect(function(
		sequence, winnerIndex, winnerInternalName, winnerRarity, coinReward
	)
		startSpin(sequence, winnerIndex)

		-- Show the result panel once the spin animation completes
		task.delay(CONFIG.SpinDuration + 0.3, function()
			local creatureData = CreatureDictionary[winnerInternalName]
			local displayName  = creatureData and creatureData.DisplayName or winnerInternalName
			local modelName    = creatureData and (creatureData.ModelName or winnerInternalName)
			                     or winnerInternalName

			showResult(displayName, winnerRarity, creatureData and creatureData.IncomeRate or 0)
			setupModelPreview(winnerInternalName, modelName)
			isSpinning = false

			-- Dismiss on any key press, or automatically after 2 seconds
			skipDismissConn = UserInputService.InputBegan:Connect(function(_, gameProcessed)
				if gameProcessed then return end
				closeCrateOverlay()
			end)
			task.delay(2, function()
				if skipDismissConn then
					closeCrateOverlay()
				end
			end)
		end)
	end)
end

-- Success/failure confirmations from the server (fires ~5 s after roll data)
if crateResultEvent then
	crateResultEvent.OnClientEvent:Connect(function(status, message, rarity, coinReward)
		if status == "Failed" then
			-- Abort any in-progress spin
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end

			if errorLabel then
				errorLabel.Text = message or "Failed to open crate"
				errorLabel.Visible = true
			end
			if titleLabel then titleLabel.Text = "Crate Failed" end
			isSpinning = false

			task.delay(3, function()
				if errorLabel and errorLabel.Visible then
					errorLabel.Visible = false
				end
			end)

		elseif status == "Success" then
			-- Result card is already populated by showResult; nothing further needed
		end
	end)
end

-- ============================================================
-- Coin button text
-- ============================================================
local function updateButtonText()
	if not openCrateBtn then return end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then return end

	openCrateBtn.Text = "Open Crate - 100 Coins (" .. coins.Value .. ")"
	openCrateBtn.BackgroundColor3 = coins.Value < 100
		and Color3.fromRGB(120, 80, 80)
		or  Color3.fromRGB(255, 170, 0)
end

local function wireCoinsChanged(leaderstats)
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Changed:Connect(updateButtonText)
		updateButtonText()
	end
end

local initialLeaderstats = player:FindFirstChild("leaderstats")
if initialLeaderstats then
	wireCoinsChanged(initialLeaderstats)
end

player.CharacterAdded:Connect(function()
	task.wait(1)
	local ls = player:FindFirstChild("leaderstats")
	if ls then wireCoinsChanged(ls) end
end)

-- ============================================================
-- Initialize
-- ============================================================

-- Disable clipping on the spinner container and its overlay parent so frames
-- that scale up at the front of the carousel are never cut off at frame edges.
if spinContainer then
	spinContainer.ClipsDescendants = false
end
crateOverlay.ClipsDescendants = false

buildResultCard()
buildFramePool()
task.wait(2)
updateButtonText()
