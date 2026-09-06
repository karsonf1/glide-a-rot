-- Local prototype pack and procedural pose. No joint replacement or rig welds.
-- Motor6D and upgraded AnimationConstraint rigs both support Transform.
local Presentation = {}
Presentation.__index = Presentation

local jointRoles = {
	LeftShoulder = "LeftShoulder", ["Left Shoulder"] = "LeftShoulder",
	RightShoulder = "RightShoulder", ["Right Shoulder"] = "RightShoulder",
	LeftElbow = "LeftElbow", RightElbow = "RightElbow",
	LeftHip = "LeftHip", ["Left Hip"] = "LeftHip",
	RightHip = "RightHip", ["Right Hip"] = "RightHip",
	LeftKnee = "LeftKnee", RightKnee = "RightKnee", Neck = "Neck",
}

function Presentation.new(character, config)
	local self = setmetatable({ joints = {}, exhausts = {}, config = config }, Presentation)
	for _, joint in character:GetDescendants() do
		local role = jointRoles[joint.Name]
		if role and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			table.insert(self.joints, { joint = joint, role = role, original = joint.Transform })
		end
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return self end
	local packConfig = config.Pack
	local pack = Instance.new("Model")
	pack.Name = "FlightThrusterPack"
	self.pack = pack
	for _, side in { -1, 1 } do
		local pod = Instance.new("Part")
		pod.Name = side < 0 and "LeftThruster" or "RightThruster"
		pod.Size = Vector3.new(packConfig.Width, packConfig.Height, packConfig.Depth)
		pod.Color = Color3.fromRGB(table.unpack(packConfig.Color))
		pod.Material = Enum.Material.Metal
		pod.CanCollide = false
		pod.CanTouch = false
		pod.CanQuery = false
		pod.CastShadow = false
		pod.Massless = true
		pod.CFrame = torso.CFrame * CFrame.new(side * packConfig.PodSpacing, 0, packConfig.BackOffset)
		pod.Parent = pack
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, pod
		weld.Parent = pod
		local nozzle = Instance.new("Attachment")
		nozzle.Position = Vector3.new(0, -packConfig.Height / 2, 0)
		nozzle.Parent = pod
		local tip = Instance.new("Attachment")
		tip.Position = nozzle.Position - Vector3.new(0, packConfig.ExhaustLength, 0)
		tip.Parent = pod
		local beam = Instance.new("Beam")
		beam.Name = "ThrustExhaust"
		beam.Attachment0, beam.Attachment1 = nozzle, tip
		beam.FaceCamera = true
		beam.Width0, beam.Width1 = packConfig.Width * 0.8, 0
		beam.Color = ColorSequence.new(Color3.fromRGB(table.unpack(packConfig.GlowColor)))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = 1
		beam.Enabled = false
		beam.Parent = pod
		table.insert(self.exhausts, { beam = beam, tip = tip, nozzle = nozzle })
	end
	pack.Parent = character
	return self
end

-- Called after the Animator, during PreSimulation, with absolute transforms.
-- This avoids cumulative offsets when an animation track stops evaluating.
function Presentation:Update(state, elapsed)
	local pose = self.config.Pose
	local bank = state.bank / math.rad(self.config.MaxBank)
	local sway = math.sin(elapsed * pose.SwayRate) * pose.SwayDegrees
	for _, entry in self.joints do
		if not entry.joint.Parent then continue end
		local role = entry.role
		local side = string.sub(role, 1, 4) == "Left" and -1 or 1
		local pitch, roll = 0, 0
		if string.find(role, "Shoulder") then
			pitch = pose.ShoulderPitch + state.throttle * pose.ShoulderPitch + sway * side
			roll = side * pose.ShoulderSpread - bank * pose.TurnCounterpose
		elseif string.find(role, "Elbow") then
			pitch = pose.ElbowBend + sway
		elseif string.find(role, "Hip") then
			pitch = pose.HipPitch * (1 + state.throttle) + sway * side
			roll = -bank * pose.TurnCounterpose * 0.5
		elseif string.find(role, "Knee") then
			pitch = pose.KneeBend * (0.5 + state.throttle * 0.5) + sway * side
		elseif role == "Neck" then
			pitch = -self.config.BodyLean * 0.5
			roll = -math.deg(state.bank) * 0.3
		end
		entry.joint.Transform = CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
	end
	for _, exhaust in self.exhausts do
		exhaust.beam.Enabled = state.throttle > 0.05
		exhaust.tip.Position = exhaust.nozzle.Position
			- Vector3.new(0, self.config.Pack.ExhaustLength * state.throttle, 0)
	end
end

function Presentation:Destroy()
	for _, entry in self.joints do
		if entry.joint.Parent then entry.joint.Transform = entry.original end
	end
	if self.pack then self.pack:Destroy() end
	table.clear(self.joints)
end

return Presentation
