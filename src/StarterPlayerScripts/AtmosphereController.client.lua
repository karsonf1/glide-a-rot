-- ============================================================
-- AtmosphereController.client.lua  (StarterPlayerScripts — LocalScript)
-- Owns the cosmetic sky/horizon haze.
--
-- ProcGen creates sections about 2000 studs ahead. Haze can soften their visible
-- boundary, but does not guarantee a distance cutoff or load missing mesh assets.
-- Verify the result at the actual camera angle and low/high graphics settings.
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
local Config = require(ReplicatedStorage:WaitForChild("AtmosphereConfig"))

-- ── Fog profiles (per biome) ─────────────────────────────────────────────────
-- The clearer prototype uses Density 0.18 / Haze 0.75 in AtmosphereConfig.
-- These are art settings, not a guaranteed streaming/render distance cutoff.
local PROFILES = Config.Profiles
local DEFAULT_BIOME = Config.DefaultBiome

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
			applyProfile(p, Config.TransitionSeconds)
		end
	end)
end
