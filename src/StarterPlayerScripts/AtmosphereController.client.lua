-- ============================================================
-- AtmosphereController.client.lua  (StarterPlayerScripts — LocalScript)
-- Owns the cosmetic sky/horizon haze.
--
-- WHY THIS EXISTS: the ProcGen corridor streams sections in ~2000 studs ahead of
-- the player. With no horizon haze, you literally watch each section clone into
-- existence in clear air ("models appear in front of me"). Player airspeed caps
-- at ~90 studs/sec (GliderConfig), so the lookahead is huge in time terms — the
-- ONLY thing missing was something to fade the far geometry into a horizon.
--
-- The key property is Atmosphere.Haze. It builds a horizon band that dissolves
-- distant geometry into the sky. Density thins the whole air column. Together
-- they set how far you see before the corridor fades out — which is what hides
-- the section spawn boundary.
--
-- Structured for v2 biome transitions (see systems/proc-gen.md): a per-biome
-- PROFILES table + tweenable applyProfile(), and a guarded BiomeChanged hook that
-- only wires up once that RemoteEvent exists. No behavior change until then.
-- ============================================================

local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Fog profiles (per biome) ─────────────────────────────────────────────────
-- Haze  ~0 = none, ~3 = strong horizon fade. 2.6 fully buries the spawn line
--       well inside the ~2000-stud lookahead at 90 studs/sec.
-- Tune Haze/Density up if any pop-in still shows; down if it feels claustrophobic.
local PROFILES = {
	Forest = {
		Color   = Color3.fromRGB(198, 205, 200),  -- soft grey-green air column
		Decay   = Color3.fromRGB(106, 112, 125),  -- cooler tint toward the horizon
		Density = 0.40,
		Haze    = 2.6,
		Offset  = 0.25,
		Glare   = 0,
	},
	-- Desert = { ... },  -- v2: add when the biome schedule goes live
}
local DEFAULT_BIOME = "Forest"

-- ── Ensure a single Atmosphere instance ─────────────────────────────────────
-- The place file already ships one (Haze 0); reuse it so we never stack two.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end

local function applyProfile(p, tweenTime)
	local goal = {
		Color   = p.Color,
		Decay   = p.Decay,
		Density = p.Density,
		Haze    = p.Haze,
		Offset  = p.Offset,
		Glare   = p.Glare,
	}
	if tweenTime and tweenTime > 0 then
		TweenService:Create(atmosphere, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), goal):Play()
	else
		for prop, value in goal do
			atmosphere[prop] = value
		end
	end
end

-- Apply the starting biome immediately (no tween on spawn).
applyProfile(PROFILES[DEFAULT_BIOME], 0)

-- ── v2 hook: lerp fog on biome change (wires only if the event exists) ───────
local biomeChanged = ReplicatedStorage:FindFirstChild("BiomeChanged")
if biomeChanged and biomeChanged:IsA("RemoteEvent") then
	biomeChanged.OnClientEvent:Connect(function(biomeName)
		local p = PROFILES[biomeName]
		if p then
			applyProfile(p, 2.0)  -- 2s cross-fade between biome fog looks
		end
	end)
end
