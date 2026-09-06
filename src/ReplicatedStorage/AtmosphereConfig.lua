-- Biome atmosphere tuning. Visibility still depends on camera/graphics settings.
return {
	DefaultBiome = "Forest",
	TransitionSeconds = 2,
	Profiles = {
		Forest = {
			Color = Color3.fromRGB(198, 205, 200),
			Decay = Color3.fromRGB(106, 112, 125),
			Density = 0.18,
			Haze = 0.75,
			Offset = 0.1,
			Glare = 0,
		},
	},
}
