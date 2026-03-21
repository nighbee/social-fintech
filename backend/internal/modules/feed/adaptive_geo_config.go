package feed

const (
	feedGeoMaxKRing = 3

	// Default distances mapped approximately to H3 grid expansions
	// kRing=1 ≈ 5.0 km (Local neighborhood)
	// kRing=2 ≈ 10.0 km (City district)
	// kRing=3 ≈ 18.0 km (Full city boundaries)
	feedGeoRing1RadiusKm = 5.0
	feedGeoRing2RadiusKm = 10.0
	feedGeoRing3RadiusKm = 18.0

	feedGeoMinLocalPosts24h   = 30
	feedGeoMinLocalAuthors24h = 15
	feedGeoMedLocalPosts24h   = 15
	feedGeoMedLocalAuthors24h = 8

	feedLocalShareLow    = 0.30
	feedLocalShareMedium = 0.50
	feedLocalShareHigh   = 0.70
)

type AdaptiveGeoConfig struct {
	Enabled            bool
	MaxKRing           int
	Ring1RadiusKm      float64
	Ring2RadiusKm      float64
	Ring3RadiusKm      float64
	MinLocalPosts24h   int
	MinLocalAuthors24h int
	MedLocalPosts24h   int
	MedLocalAuthors24h int
	LocalShareLow      float64
	LocalShareMedium   float64
	LocalShareHigh     float64
}

func DefaultAdaptiveGeoConfig() AdaptiveGeoConfig {
	return AdaptiveGeoConfig{
		Enabled:            true,
		MaxKRing:           feedGeoMaxKRing,
		Ring1RadiusKm:      feedGeoRing1RadiusKm,
		Ring2RadiusKm:      feedGeoRing2RadiusKm,
		Ring3RadiusKm:      feedGeoRing3RadiusKm,
		MinLocalPosts24h:   feedGeoMinLocalPosts24h,
		MinLocalAuthors24h: feedGeoMinLocalAuthors24h,
		MedLocalPosts24h:   feedGeoMedLocalPosts24h,
		MedLocalAuthors24h: feedGeoMedLocalAuthors24h,
		LocalShareLow:      feedLocalShareLow,
		LocalShareMedium:   feedLocalShareMedium,
		LocalShareHigh:     feedLocalShareHigh,
	}
}

func (c AdaptiveGeoConfig) normalize() AdaptiveGeoConfig {
	defaults := DefaultAdaptiveGeoConfig()

	if c.MaxKRing <= 0 {
		c.MaxKRing = defaults.MaxKRing
	}
	if c.Ring1RadiusKm <= 0 {
		c.Ring1RadiusKm = defaults.Ring1RadiusKm
	}
	if c.Ring2RadiusKm <= 0 {
		c.Ring2RadiusKm = defaults.Ring2RadiusKm
	}
	if c.Ring3RadiusKm <= 0 {
		c.Ring3RadiusKm = defaults.Ring3RadiusKm
	}
	if c.MinLocalPosts24h <= 0 {
		c.MinLocalPosts24h = defaults.MinLocalPosts24h
	}
	if c.MinLocalAuthors24h <= 0 {
		c.MinLocalAuthors24h = defaults.MinLocalAuthors24h
	}
	if c.MedLocalPosts24h <= 0 {
		c.MedLocalPosts24h = defaults.MedLocalPosts24h
	}
	if c.MedLocalAuthors24h <= 0 {
		c.MedLocalAuthors24h = defaults.MedLocalAuthors24h
	}
	if c.LocalShareLow <= 0 {
		c.LocalShareLow = defaults.LocalShareLow
	}
	if c.LocalShareMedium <= 0 {
		c.LocalShareMedium = defaults.LocalShareMedium
	}
	if c.LocalShareHigh <= 0 {
		c.LocalShareHigh = defaults.LocalShareHigh
	}

	if c.LocalShareLow > 1 {
		c.LocalShareLow = 1
	}
	if c.LocalShareMedium > 1 {
		c.LocalShareMedium = 1
	}
	if c.LocalShareHigh > 1 {
		c.LocalShareHigh = 1
	}

	return c
}
