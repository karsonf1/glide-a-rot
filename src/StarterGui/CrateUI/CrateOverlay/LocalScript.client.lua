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

local resultCard        = nil
local resultCardDimmer  = nil
local resultCardVP      = nil
local resultCardVPStroke = nil
local resultCardName    = nil
local resultCardRarity  = nil
local resultCardIncome  = nil
local resultCardHeader  = nil

local CreatureDictionary = require(ReplicatedStorage:WaitForChild("CreatureDictionary"))
local openCrateEvent     = ReplicatedStorage:WaitForChild("OpenCrateClient")
local crateResultEvent   = ReplicatedStorage:WaitForChild("CrateResultClient")
local crateRollDataEvent = ReplicatedStorage:WaitForChild("CrateRollDataClient")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	EllipseRadiusX       = 320,
	EllipseRadiusY       = 60,
	CenterX              = 0.5,
	SpinnerCenterYOffset = 0.65,
	DepthScaleMin        = 0.55,
	DepthScaleMax        = 1.00,
	FrameCount           = 8,
	FrameBaseSize        = 130,          -- slightly larger cards
	SpinDuration         = 4.2,
	MinFullRotations     = 4,
	BaseDeceleration     = 3.5,
	FrontAngle           = math.pi / 2,
	ModelLoadThreshold   = 0.08,         -- load models early so they spin from the start
	CreatureModelScale   = 0.48,
	SpinnerFillMultiplier  = 0.72,
	WinnerHeroDistance     = 1.8,
	GlobalRotationSpeed    = 0.6,        -- result card creature rotation speed
	ModelRotationSpeed     = 1.4,        -- rad/sec for carousel model spin
	SpinnerCamLookFrac     = 0.32,       -- camera looks at this fraction of model height (lower = more pop-out)
	PopOutFraction         = 0.78,       -- VP extends this fraction of card height above the card
}

local TAU        = math.pi * 2
local SLOT_ANGLE = TAU / CONFIG.FrameCount

local rarityColors = CreatureDictionary.RarityColors or {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(100, 200, 120),
	Rare      = Color3.fromRGB(85,  170, 255),
	Epic      = Color3.fromRGB(170, 85,  255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythical  = Color3.fromRGB(255, 80,  140),
}

-- ============================================================
-- State
-- ============================================================
local isSpinning   = false
local wheelPos     = 0.0
local sequenceData = {}
local framePool    = {}
local renderConn   = nil
local heroRotConn     = nil
local skipDismissConn = nil

-- ============================================================
-- Frame pool construction
-- ============================================================
local function buildFramePool()
	for _, entry in ipairs(framePool) do
		entry.frame:Destroy()
	end
	framePool = {}

	for i = 1, CONFIG.FrameCount do
		-- Card background — dark navy, rounded, no clipping so VP can overflow
		local frame = Instance.new("Frame")
		frame.Name = "CarouselFrame" .. i
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.new(0, CONFIG.FrameBaseSize, 0, CONFIG.FrameBaseSize)
		frame.BackgroundColor3 = Color3.fromRGB(14, 16, 26)
		frame.BackgroundTransparency = 0.05
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = false
		frame.Visible = false

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.16, 0)
		corner.Parent = frame

		-- Rarity-coloured border — updated per-slot as sequence scrolls
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 100, 120)
		stroke.Thickness = 2.5
		stroke.Transparency = 0.25
		stroke.Parent = frame

		-- Subtle inner rarity glow (very low alpha tint)
		local glowFrame = Instance.new("Frame")
		glowFrame.Name = "RarityGlow"
		glowFrame.Size = UDim2.new(1, 0, 1, 0)
		glowFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
		glowFrame.BackgroundTransparency = 0.88
		glowFrame.BorderSizePixel = 0
		glowFrame.ZIndex = 1
		glowFrame.Parent = frame

		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0.16, 0)
		glowCorner.Parent = glowFrame

		-- ViewportFrame: transparent background, oversized so model pops above card.
		-- Top edge sits PopOutFraction × cardHeight above the card's top edge.
		-- Bottom edge aligns with card bottom. Total VP height = (1 + PopOutFraction) × cardHeight.
		local vp = Instance.new("ViewportFrame")
		vp.Name = "MiniModel"
		vp.Size = UDim2.new(1.0, 0, 1.0 + CONFIG.PopOutFraction, 0)
		vp.Position = UDim2.new(0, 0, -CONFIG.PopOutFraction, 0)
		vp.BackgroundTransparency = 1
		vp.ZIndex = 8
		vp.Parent = frame

		-- Minimal name badge floats below the card
		local badge = Instance.new("Frame")
		badge.Name = "NameBadge"
		badge.Size = UDim2.new(1.15, 0, 0, 18)
		badge.Position = UDim2.new(-0.075, 0, 1.0, 5)
		badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		badge.BackgroundTransparency = 0.45
		badge.BorderSizePixel = 0
		badge.ZIndex = 5
		badge.Parent = frame

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0.5, 0)
		badgeCorner.Parent = badge

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 1, 0)
		nameLabel.Position = UDim2.new(0, 4, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 9
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Text = ""
		nameLabel.ZIndex = 6
		nameLabel.Parent = badge

		frame.Parent = spinContainer

		framePool[i] = {
			frame       = frame,
			vp          = vp,
			nameLabel   = nameLabel,
			stroke      = stroke,
			glowFrame   = glowFrame,
			lastDataIdx = -1,
			modelRef    = nil,
			pivotToBB   = Vector3.zero,
			yCenter     = 0,
			rotYaw      = 0,
		}
	end
end

-- ============================================================
-- Viewport loading — carousel variant (stores refs for rotation)
-- ============================================================
local function loadModelIntoEntry(entry, creatureData)
	for _, child in ipairs(entry.vp:GetChildren()) do child:Destroy() end
	entry.modelRef = nil

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	if not modelsFolder then return end

	local model = modelsFolder:FindFirstChild(creatureData.ModelName or creatureData.InternalName)
	if not model then return end

	local clone = model:Clone()
	for _, stripName in ipairs({"AnimationController", "VfxInstance", "FakeRootPart"}) do
		local c = clone:FindFirstChild(stripName)
		if c then c:Destroy() end
	end

	clone:ScaleTo(CONFIG.CreatureModelScale)

	local bbCFrame, bbSize = clone:GetBoundingBox()
	local pivotToBB = bbCFrame.Position - clone:GetPivot().Position
	local yCenter   = bbSize.Y * 0.5
	local maxDim    = math.max(bbSize.X, bbSize.Y, bbSize.Z)

	-- Initial placement: feet at y=0
	clone:PivotTo(CFrame.new(-pivotToBB.X, yCenter - pivotToBB.Y, -pivotToBB.Z))

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	entry.vp.CurrentCamera = camera
	camera.Parent = entry.vp

	-- Camera looks at the lower portion of the model.
	-- SpinnerCamLookFrac < 0.5 means camera targets below model-center,
	-- which pushes the model's upper body (head) into the pop-out zone above the card.
	local halfFov = math.rad(camera.FieldOfView / 2)
	local dist    = (maxDim * 0.5) / (math.tan(halfFov) * CONFIG.SpinnerFillMultiplier)
	local lookY   = bbSize.Y * CONFIG.SpinnerCamLookFrac
	camera.CFrame = CFrame.new(
		Vector3.new(0, lookY, -dist),
		Vector3.new(0, lookY, 0)
	)

	clone.Parent = entry.vp

	entry.modelRef  = clone
	entry.pivotToBB = pivotToBB
	entry.yCenter   = yCenter
	entry.rotYaw    = 0
end

local function clearViewport(vp)
	for _, child in ipairs(vp:GetChildren()) do child:Destroy() end
end

-- ============================================================
-- Frame data update
-- ============================================================
local function updateFrameData(entry, dataIdx, spinProgress)
	if entry.lastDataIdx == dataIdx then return end
	entry.lastDataIdx = dataIdx

	local seqLen = #sequenceData
	if seqLen == 0 then return end

	local safeIdx = ((dataIdx % seqLen) + seqLen) % seqLen
	local creature = sequenceData[safeIdx + 1]
	if not creature then return end

	-- Apply rarity accent: border stroke + inner glow
	local rarityColor = rarityColors[creature.Rarity] or rarityColors.Common
	if entry.stroke    then entry.stroke.Color = rarityColor end
	if entry.glowFrame then entry.glowFrame.BackgroundColor3 = rarityColor end

	entry.nameLabel.Text = creature.DisplayName or creature.InternalName

	if spinProgress >= CONFIG.ModelLoadThreshold then
		loadModelIntoEntry(entry, creature)
	else
		clearViewport(entry.vp)
		entry.modelRef = nil
	end
end

-- ============================================================
-- Carousel layout
-- ============================================================
local function updateCarousel(wp, spinProgress)
	local containerSize = spinContainer.AbsoluteSize
	local centerLocalX  = containerSize.X * CONFIG.CenterX
	local centerLocalY  = containerSize.Y * CONFIG.SpinnerCenterYOffset

	local fracPart    = wp - math.floor(wp)
	local baseSlotIdx = math.floor(wp)

	for i = 1, CONFIG.FrameCount do
		local entry      = framePool[i]
		local slotOffset = i - 1
		local angle      = CONFIG.FrontAngle + (slotOffset - fracPart) * SLOT_ANGLE

		local localX = centerLocalX + CONFIG.EllipseRadiusX * math.cos(angle)
		local localY = centerLocalY + CONFIG.EllipseRadiusY * math.sin(angle)

		local depth     = (math.sin(angle) + 1) / 2
		local scale     = CONFIG.DepthScaleMin + depth * (CONFIG.DepthScaleMax - CONFIG.DepthScaleMin)
		local pixelSize = CONFIG.FrameBaseSize * scale

		local visible = depth > 0.05
		entry.frame.Visible = visible

		if visible then
			entry.frame.Position = UDim2.new(0, localX, 0, localY)
			entry.frame.Size     = UDim2.new(0, pixelSize, 0, pixelSize)

			local zIndex = math.max(1, math.floor(1 + depth * 9))
			entry.frame.ZIndex      = zIndex
			entry.glowFrame.ZIndex  = zIndex
			entry.vp.ZIndex         = zIndex + 2

			updateFrameData(entry, baseSlotIdx + slotOffset, spinProgress)
		end
	end
end

-- ============================================================
-- Spin animation
-- ============================================================
local function computeTargetWheelPos(winnerIndex, seqLen)
	local base      = winnerIndex - 1
	local minSlots  = CONFIG.MinFullRotations * seqLen
	local extraLoops = math.ceil(minSlots / seqLen)
	return base + extraLoops * seqLen
end

local function startSpin(sequence, winnerIndex)
	sequenceData = sequence
	wheelPos = 0.0

	for _, entry in ipairs(framePool) do
		entry.lastDataIdx = -1
		entry.frame.Visible = false
		entry.modelRef = nil
		clearViewport(entry.vp)
	end

	local targetWheelPos = computeTargetWheelPos(winnerIndex, #sequence)
	local startTime      = tick()
	local duration       = CONFIG.SpinDuration

	if renderConn then renderConn:Disconnect(); renderConn = nil end

	renderConn = RunService.RenderStepped:Connect(function(dt)
		local elapsed = tick() - startTime
		local t = math.min(elapsed / duration, 1)
		local eased = 1 - (1 - t) ^ CONFIG.BaseDeceleration

		wheelPos = eased * targetWheelPos
		updateCarousel(wheelPos, t)

		-- Rotate all visible carousel models
		for _, entry in ipairs(framePool) do
			local mr = entry.modelRef
			if entry.frame.Visible and mr and mr.Parent then
				entry.rotYaw += CONFIG.ModelRotationSpeed * dt
				local r  = entry.rotYaw
				local pb = entry.pivotToBB
				local cosR, sinR = math.cos(r), math.sin(r)
				mr:PivotTo(CFrame.new(
					-(pb.X * cosR + pb.Z * sinR),
					  entry.yCenter - pb.Y,
					  pb.X * sinR - pb.Z * cosR
				) * CFrame.Angles(0, r, 0))
			end
		end

		if t >= 1 then
			renderConn:Disconnect()
			renderConn = nil
		end
	end)
end

-- ============================================================
-- Result card model preview
-- ============================================================
local function setupModelPreview(internalName, modelName)
	if not resultCardVP then return end

	clearViewport(resultCardVP)
	if heroRotConn then heroRotConn:Disconnect(); heroRotConn = nil end

	local modelsFolder = ReplicatedStorage:FindFirstChild("CreatureModels")
	if not modelsFolder then return end
	local model = modelsFolder:FindFirstChild(modelName or internalName)
	if not model then return end

	local clone = model:Clone()
	for _, stripName in ipairs({"AnimationController", "VfxInstance", "FakeRootPart"}) do
		local c = clone:FindFirstChild(stripName)
		if c then c:Destroy() end
	end

	local bbCFrame, bbSize = clone:GetBoundingBox()
	local pivotToBB = bbCFrame.Position - clone:GetPivot().Position
	local yCenter   = bbSize.Y * 0.5
	local maxDim    = math.max(bbSize.X, bbSize.Y, bbSize.Z)

	clone:PivotTo(CFrame.new(-pivotToBB.X, yCenter - pivotToBB.Y, -pivotToBB.Z))

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	resultCardVP.CurrentCamera = camera
	camera.Parent = resultCardVP

	local halfFov = math.rad(camera.FieldOfView / 2)
	local dist = (maxDim * 0.5) / (math.tan(halfFov) * CONFIG.WinnerHeroDistance)
	local camY  = yCenter * 0.4
	camera.CFrame = CFrame.new(
		Vector3.new(0, camY, -dist),
		Vector3.new(0, yCenter, 0)
	)

	clone.Parent = resultCardVP

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

-- ============================================================
-- Result display
-- ============================================================
local function showResult(displayName, rarity, incomeRate)
	local rarityColor = rarityColors[rarity] or Color3.fromRGB(180, 180, 180)

	if resultCardHeader  then resultCardHeader.BackgroundColor3 = rarityColor end
	if resultCardRarity  then
		resultCardRarity.Text       = rarity:upper()
		resultCardRarity.TextColor3 = Color3.new(1, 1, 1)
	end
	if resultCardName    then resultCardName.Text = displayName end
	if resultCardIncome  then
		resultCardIncome.Text = "Base Income: " .. (incomeRate or 0) .. " / sec"
	end
	-- Tint the hero viewport border to the rarity colour
	if resultCardVPStroke then
		resultCardVPStroke.Color = rarityColor
		resultCardVPStroke.Transparency = 0.1
	end

	if resultCard       then resultCard.Visible = true end
	if resultCardDimmer then resultCardDimmer.Visible = true end
end

-- ============================================================
-- Result card construction (called once on init)
-- ============================================================
local function buildResultCard()
	-- Backdrop dimmer
	local dimmer = Instance.new("Frame")
	dimmer.Name = "ResultDimmer"
	dimmer.Size = UDim2.new(1, 0, 1, 0)
	dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimmer.BackgroundTransparency = 0.45
	dimmer.BorderSizePixel = 0
	dimmer.ZIndex = 20
	dimmer.Visible = false
	dimmer.Parent = crateOverlay

	-- Main card
	local card = Instance.new("Frame")
	card.Name = "ResultCard"
	card.Size = UDim2.new(0, 400, 0, 490)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.ZIndex = 21
	card.Visible = false
	card.Parent = crateOverlay

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 20)
	cardCorner.Parent = card

	-- Rarity-coloured header strip
	local header = Instance.new("Frame")
	header.Name = "RarityHeader"
	header.Size = UDim2.new(1, 0, 0, 62)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	header.BorderSizePixel = 0
	header.ZIndex = 22
	header.Parent = card

	-- Subtle gradient on header for polish
	local headerGrad = Instance.new("UIGradient")
	headerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
	})
	headerGrad.Rotation = 90
	headerGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	headerGrad.Parent = header

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

	-- Hero ViewportFrame — wider + rarity UIStroke
	local vp = Instance.new("ViewportFrame")
	vp.Name = "HeroViewport"
	vp.Size = UDim2.new(1, -28, 0, 290)
	vp.Position = UDim2.new(0, 14, 0, 70)
	vp.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.ZIndex = 22
	vp.Parent = card

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 14)
	vpCorner.Parent = vp

	-- Rarity-tinted border on hero VP — updated in showResult()
	local vpStroke = Instance.new("UIStroke")
	vpStroke.Color = Color3.fromRGB(180, 180, 180)
	vpStroke.Thickness = 3
	vpStroke.Transparency = 0.6
	vpStroke.Parent = vp

	-- Creature name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CreatureName"
	nameLabel.Size = UDim2.new(1, -28, 0, 48)
	nameLabel.Position = UDim2.new(0, 14, 0, 370)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 28
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.ZIndex = 22
	nameLabel.Parent = card

	-- Income per second
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, -28, 0, 28)
	incomeLabel.Position = UDim2.new(0, 14, 0, 422)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "Base Income: 0 / sec"
	incomeLabel.TextColor3 = Color3.fromRGB(255, 210, 70)
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextSize = 18
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.ZIndex = 22
	incomeLabel.Parent = card

	-- Dismiss hint
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "DismissHint"
	hintLabel.Size = UDim2.new(1, -28, 0, 22)
	hintLabel.Position = UDim2.new(0, 14, 0, 458)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "Press any key to dismiss"
	hintLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 13
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.ZIndex = 22
	hintLabel.Parent = card

	resultCard         = card
	resultCardDimmer   = dimmer
	resultCardVP       = vp
	resultCardVPStroke = vpStroke
	resultCardName     = nameLabel
	resultCardRarity   = rarityLabel
	resultCardIncome   = incomeLabel
	resultCardHeader   = header
end

-- ============================================================
-- Close / cleanup
-- ============================================================
local function closeCrateOverlay()
	if renderConn      then renderConn:Disconnect();      renderConn      = nil end
	if heroRotConn     then heroRotConn:Disconnect();     heroRotConn     = nil end
	if skipDismissConn then skipDismissConn:Disconnect(); skipDismissConn = nil end

	crateOverlay.Visible = false
	if resultCard       then resultCard.Visible = false end
	if resultCardDimmer then resultCardDimmer.Visible = false end
	if errorLabel       then errorLabel.Visible = false end

	isSpinning   = false
	sequenceData = {}
	wheelPos     = 0.0

	for _, entry in ipairs(framePool) do
		entry.frame.Visible = false
		entry.lastDataIdx   = -1
		entry.modelRef      = nil
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
		if errorLabel       then errorLabel.Visible = false end
		if titleLabel       then titleLabel.Text = "Opening Crate..." end

		openCrateEvent:FireServer()
	end)
end

-- ============================================================
-- Server event handlers
-- ============================================================
if crateRollDataEvent then
	crateRollDataEvent.OnClientEvent:Connect(function(
		sequence, winnerIndex, winnerInternalName, winnerRarity, coinReward
	)
		startSpin(sequence, winnerIndex)

		task.delay(CONFIG.SpinDuration + 0.3, function()
			local creatureData = CreatureDictionary[winnerInternalName]
			local displayName  = creatureData and creatureData.DisplayName or winnerInternalName
			local modelName    = creatureData and (creatureData.ModelName or winnerInternalName)
			                     or winnerInternalName

			showResult(displayName, winnerRarity, creatureData and creatureData.IncomeRate or 0)
			setupModelPreview(winnerInternalName, modelName)
			isSpinning = false

			skipDismissConn = UserInputService.InputBegan:Connect(function(_, gameProcessed)
				if gameProcessed then return end
				closeCrateOverlay()
			end)
			task.delay(2, function()
				if skipDismissConn then closeCrateOverlay() end
			end)
		end)
	end)
end

if crateResultEvent then
	crateResultEvent.OnClientEvent:Connect(function(status, message, rarity, coinReward)
		if status == "Failed" then
			if renderConn then renderConn:Disconnect(); renderConn = nil end

			if errorLabel then
				errorLabel.Text = message or "Failed to open crate"
				errorLabel.Visible = true
			end
			if titleLabel then titleLabel.Text = "Crate Failed" end
			isSpinning = false

			task.delay(3, function()
				if errorLabel and errorLabel.Visible then errorLabel.Visible = false end
			end)
		end
		-- "Success" is handled by showResult via crateRollDataEvent; nothing more needed here
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
if initialLeaderstats then wireCoinsChanged(initialLeaderstats) end

player.CharacterAdded:Connect(function()
	task.wait(1)
	local ls = player:FindFirstChild("leaderstats")
	if ls then wireCoinsChanged(ls) end
end)

-- ============================================================
-- Initialize
-- ============================================================
if spinContainer then spinContainer.ClipsDescendants = false end
crateOverlay.ClipsDescendants = false

buildResultCard()
buildFramePool()
task.wait(2)
updateButtonText()
