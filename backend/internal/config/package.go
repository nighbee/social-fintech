package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server     ServerConfig     `yaml:"server"`
	Database   DatabaseConfig   `yaml:"database"`
	Redis      RedisConfig      `yaml:"redis"`
	Cache      CacheConfig      `yaml:"cache"`
	Feed       FeedConfig       `yaml:"feed"`
	Logging    LoggingConfig    `yaml:"logging"`
	JWT        JWTConfig        `yaml:"jwt"`
	CORS       CORSConfig       `yaml:"cors"`
	OAuth      OAuthConfig      `yaml:"oauth"`
	Firebase   FirebaseConfig   `yaml:"firebase"`
	Storage    StorageConfig    `yaml:"storage"`
	Economy    EconomyConfig    `yaml:"economy"`
	Admin      AdminConfig      `yaml:"admin"`
	Moderation ModerationConfig `yaml:"moderation"`
	Activation ActivationConfig `yaml:"activation"`
}

type AdminConfig struct {
	Emails []string `yaml:"emails"`
}

type ModerationConfig struct {
	Enabled            bool    `yaml:"enabled"`
	ShadowMode         bool    `yaml:"shadow_mode"`
	MinActivationViews int     `yaml:"min_activation_views"`
	DailyReportLimit   int     `yaml:"daily_report_limit"`
	Level1Threshold    float64 `yaml:"level1_threshold"`
	Level2Threshold    float64 `yaml:"level2_threshold"`
	Level3Threshold    float64 `yaml:"level3_threshold"`
	Level4Threshold    float64 `yaml:"level4_threshold"`
	Level1Ratio        float64 `yaml:"level1_ratio"`
	Level2Ratio        float64 `yaml:"level2_ratio"`
	Level3Ratio        float64 `yaml:"level3_ratio"`
	Level4Ratio        float64 `yaml:"level4_ratio"`
}

type ActivationConfig struct {
	Enabled                      bool `yaml:"enabled"`
	MinRestrictedHours           int  `yaml:"min_restricted_hours"`
	ExtendedRestrictedHours      int  `yaml:"extended_restricted_hours"`
	RequiredDistinctLoginDays    int  `yaml:"required_distinct_login_days"`
	RequiredMeaningfulActions    int  `yaml:"required_meaningful_actions"`
	MaxRegistrationsPerDeviceDay int  `yaml:"max_registrations_per_device_day"`
}

type EconomyConfig struct {
	MaxDailyTransfers       int     `yaml:"max_daily_transfers"`
	MaxFreeSilverBalance    int64   `yaml:"max_free_silver_balance"`
	DailyAccrualSeals       float64 `yaml:"daily_accrual_seals"`
	DailyAccrualCents       int64   `yaml:"daily_accrual_cents"`
	TransferCooldownSeconds int     `yaml:"transfer_cooldown_seconds"`
	ReferralBonusSeals      float64 `yaml:"referral_bonus_seals"`
	ReferralBonusCents      int64   `yaml:"referral_bonus_cents"`
	SealCooldownLevel1Days  int     `yaml:"seal_cooldown_level1_days"`
	SealCooldownLevel2Days  int     `yaml:"seal_cooldown_level2_days"`
	SealCooldownLevel3Days  int     `yaml:"seal_cooldown_level3_days"`
	SealCooldownLevel4Days  int     `yaml:"seal_cooldown_level4_days"`
	SealCooldownLevel5Days  int     `yaml:"seal_cooldown_level5_days"`
	SealDecayThreshold1Days int     `yaml:"seal_decay_threshold1_days"`
	SealDecayThreshold2Days int     `yaml:"seal_decay_threshold2_days"`
}

type FeedConfig struct {
	AdaptiveGeoEnabled bool    `yaml:"adaptive_geo_enabled"`
	MaxKRing           int     `yaml:"max_k_ring"`
	Ring1RadiusKm      float64 `yaml:"ring1_radius_km"`
	Ring2RadiusKm      float64 `yaml:"ring2_radius_km"`
	Ring3RadiusKm      float64 `yaml:"ring3_radius_km"`
	MinLocalPosts24h   int     `yaml:"min_local_posts_24h"`
	MinLocalAuthors24h int     `yaml:"min_local_authors_24h"`
	MedLocalPosts24h   int     `yaml:"med_local_posts_24h"`
	MedLocalAuthors24h int     `yaml:"med_local_authors_24h"`
	LocalShareLow      float64 `yaml:"local_share_low"`
	LocalShareMedium   float64 `yaml:"local_share_medium"`
	LocalShareHigh     float64 `yaml:"local_share_high"`
}

type OAuthConfig struct {
	Apple  OAuthProviderConfig `yaml:"apple"`
	Google OAuthProviderConfig `yaml:"google"`
}

type OAuthProviderConfig struct {
	ClientID string `yaml:"client_id"`
	Issuer   string `yaml:"issuer"`
}

type FirebaseConfig struct {
	Enabled         bool   `yaml:"enabled"`
	CredentialsPath string `yaml:"credentials_path"`
	ProjectID       string `yaml:"project_id"`
}

type StorageConfig struct {
	Endpoint  string `yaml:"endpoint"`
	AccessKey string `yaml:"access_key"`
	SecretKey string `yaml:"secret_key"`
	Bucket    string `yaml:"bucket"`
	UseSSL    bool   `yaml:"use_ssl"`
	PublicURL string `yaml:"public_url"`
}

type ServerConfig struct {
	Port         int           `yaml:"port"`
	Environment  string        `yaml:"environment"`
	ReadTimeout  time.Duration `yaml:"read_timeout"`
	WriteTimeout time.Duration `yaml:"write_timeout"`
	IdleTimeout  time.Duration `yaml:"idle_timeout"`
}

type DatabaseConfig struct {
	Host            string        `yaml:"host"`
	Port            int           `yaml:"port"`
	User            string        `yaml:"user"`
	Password        string        `yaml:"password"`
	Name            string        `yaml:"name"`
	SSLMode         string        `yaml:"sslmode"`
	MaxOpenConns    int           `yaml:"max_open_conns"`
	MaxIdleConns    int           `yaml:"max_idle_conns"`
	ConnMaxLifetime time.Duration `yaml:"conn_max_lifetime"`
}

type RedisConfig struct {
	Address      string `yaml:"address"`
	Password     string `yaml:"password"`
	DB           int    `yaml:"db"`
	PoolSize     int    `yaml:"pool_size"`
	MinIdleConns int    `yaml:"min_idle_conns"`
}

type CacheConfig struct {
	ProfileStatsTTL time.Duration `yaml:"profile_stats_ttl"`
	Enabled         bool          `yaml:"enabled"`
}

type LoggingConfig struct {
	Level            string   `yaml:"level"`
	Encoding         string   `yaml:"encoding"`
	OutputPaths      []string `yaml:"output_paths"`
	ErrorOutputPaths []string `yaml:"error_output_paths"`
}

type JWTConfig struct {
	Secret            string        `yaml:"secret"`
	Expiration        time.Duration `yaml:"expiration"`
	RefreshExpiration time.Duration `yaml:"refresh_expiration"`
}

type CORSConfig struct {
	AllowedOrigins   []string      `yaml:"allowed_origins"`
	AllowedMethods   []string      `yaml:"allowed_methods"`
	AllowedHeaders   []string      `yaml:"allowed_headers"`
	ExposeHeaders    []string      `yaml:"expose_headers"`
	AllowCredentials bool          `yaml:"allow_credentials"`
	MaxAge           time.Duration `yaml:"max_age"`
}

func Load(path string) (*Config, error) {
	file, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(file, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	// Override with environment variables
	overrideFromEnv(&cfg)

	// Validate
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}

	return &cfg, nil
}

func overrideFromEnv(cfg *Config) {
	// Server
	if v := os.Getenv("SERVER_PORT"); v != "" {
		if port, err := strconv.Atoi(v); err == nil {
			cfg.Server.Port = port
		}
	}
	if v := os.Getenv("SERVER_ENV"); v != "" {
		cfg.Server.Environment = v
	}

	// Database
	if v := os.Getenv("DB_HOST"); v != "" {
		cfg.Database.Host = v
	}
	if v := os.Getenv("DB_PORT"); v != "" {
		if port, err := strconv.Atoi(v); err == nil {
			cfg.Database.Port = port
		}
	}
	if v := os.Getenv("DB_USER"); v != "" {
		cfg.Database.User = v
	}
	if v := os.Getenv("DB_PASSWORD"); v != "" {
		cfg.Database.Password = v
	}
	if v := os.Getenv("DB_NAME"); v != "" {
		cfg.Database.Name = v
	}
	if v := os.Getenv("DB_SSLMODE"); v != "" {
		cfg.Database.SSLMode = v
	}

	// Redis
	if v := os.Getenv("REDIS_HOST"); v != "" {
		port := "6379"
		if p := os.Getenv("REDIS_PORT"); p != "" {
			port = p
		}
		cfg.Redis.Address = v + ":" + port
	}
	if v := os.Getenv("REDIS_PASSWORD"); v != "" {
		cfg.Redis.Password = v
	}
	if v := os.Getenv("REDIS_DB"); v != "" {
		if db, err := strconv.Atoi(v); err == nil {
			cfg.Redis.DB = db
		}
	}

	// JWT
	if v := os.Getenv("JWT_SECRET"); v != "" {
		cfg.JWT.Secret = v
	}

	// oauth
	if v := os.Getenv("OAUTH_APPLE_CLIENT_ID"); v != "" {
		cfg.OAuth.Apple.ClientID = v
	}
	if v := os.Getenv("OAUTH_APPLE_ISSUER"); v != "" {
		cfg.OAuth.Apple.Issuer = v
	}
	if v := os.Getenv("OAUTH_GOOGLE_CLIENT"); v != "" {
		cfg.OAuth.Google.ClientID = v
	}
	if v := os.Getenv("OAUTH_GOOGLE_ISSUER"); v != "" {
		cfg.OAuth.Google.Issuer = v
	}

	// Firebase
	if v := os.Getenv("FIREBASE_ENABLED"); v != "" {
		cfg.Firebase.Enabled = v == "true"
	}
	if v := os.Getenv("FIREBASE_CREDENTIALS_PATH"); v != "" {
		cfg.Firebase.CredentialsPath = v
	}
	if v := os.Getenv("FIREBASE_PROJECT_ID"); v != "" {
		cfg.Firebase.ProjectID = v
	}

	// Server Defaults
	if cfg.Server.IdleTimeout == 0 {
		cfg.Server.IdleTimeout = 120 * time.Second
	}

	// Database Defaults
	if cfg.Database.MaxOpenConns == 0 {
		cfg.Database.MaxOpenConns = 25
	}
	if cfg.Database.MaxIdleConns == 0 {
		cfg.Database.MaxIdleConns = 25
	}
	if cfg.Database.ConnMaxLifetime == 0 {
		cfg.Database.ConnMaxLifetime = 5 * time.Minute
	}

	// Economy Defaults and Overrides
	// Set defaults if not present in yaml
	if cfg.Economy.MaxDailyTransfers == 0 {
		cfg.Economy.MaxDailyTransfers = 50
	}
	if cfg.Economy.MaxFreeSilverBalance == 0 {
		cfg.Economy.MaxFreeSilverBalance = 500 // 5.00 seals
	}
	if cfg.Economy.DailyAccrualSeals == 0 {
		cfg.Economy.DailyAccrualSeals = 1.0
	}
	if cfg.Economy.DailyAccrualCents == 0 {
		cfg.Economy.DailyAccrualCents = 100
	}
	if cfg.Economy.TransferCooldownSeconds == 0 {
		cfg.Economy.TransferCooldownSeconds = 60
	}
	if cfg.Economy.ReferralBonusSeals == 0 {
		cfg.Economy.ReferralBonusSeals = 1.0
	}
	if cfg.Economy.ReferralBonusCents == 0 {
		cfg.Economy.ReferralBonusCents = 100
	}
	if cfg.Economy.SealCooldownLevel1Days == 0 {
		cfg.Economy.SealCooldownLevel1Days = 30
	}
	if cfg.Economy.SealCooldownLevel2Days == 0 {
		cfg.Economy.SealCooldownLevel2Days = 45
	}
	if cfg.Economy.SealCooldownLevel3Days == 0 {
		cfg.Economy.SealCooldownLevel3Days = 60
	}
	if cfg.Economy.SealCooldownLevel4Days == 0 {
		cfg.Economy.SealCooldownLevel4Days = 90
	}
	if cfg.Economy.SealCooldownLevel5Days == 0 {
		cfg.Economy.SealCooldownLevel5Days = 120
	}
	if cfg.Economy.SealDecayThreshold1Days == 0 {
		cfg.Economy.SealDecayThreshold1Days = 120
	}
	if cfg.Economy.SealDecayThreshold2Days == 0 {
		cfg.Economy.SealDecayThreshold2Days = 240
	}

	// Overrides
	if v := os.Getenv("ECONOMY_MAX_DAILY_TRANSFERS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.MaxDailyTransfers = val
		}
	}
	if v := os.Getenv("ECONOMY_MAX_FREE_SILVER_BALANCE"); v != "" {
		if val, err := strconv.ParseInt(v, 10, 64); err == nil {
			cfg.Economy.MaxFreeSilverBalance = val
		}
	}
	if v := os.Getenv("ECONOMY_TRANSFER_COOLDOWN_SECONDS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.TransferCooldownSeconds = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_COOLDOWN_LEVEL1_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealCooldownLevel1Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_COOLDOWN_LEVEL2_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealCooldownLevel2Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_COOLDOWN_LEVEL3_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealCooldownLevel3Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_COOLDOWN_LEVEL4_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealCooldownLevel4Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_COOLDOWN_LEVEL5_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealCooldownLevel5Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_DECAY_THRESHOLD1_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealDecayThreshold1Days = val
		}
	}
	if v := os.Getenv("ECONOMY_SEAL_DECAY_THRESHOLD2_DAYS"); v != "" {
		if val, err := strconv.Atoi(v); err == nil {
			cfg.Economy.SealDecayThreshold2Days = val
		}
	}

	// Admin
	if v := os.Getenv("ADMIN_EMAILS"); v != "" {
		cfg.Admin.Emails = strings.Split(v, ",")
		for i := range cfg.Admin.Emails {
			cfg.Admin.Emails[i] = strings.TrimSpace(cfg.Admin.Emails[i])
		}
	}

	// Cache defaults
	if cfg.Cache.ProfileStatsTTL == 0 {
		cfg.Cache.ProfileStatsTTL = 5 * time.Minute
	}

	if !cfg.Feed.AdaptiveGeoEnabled {
		cfg.Feed.AdaptiveGeoEnabled = true
	}
	if cfg.Feed.MaxKRing == 0 {
		cfg.Feed.MaxKRing = 3
	}
	if cfg.Feed.Ring1RadiusKm == 0 {
		cfg.Feed.Ring1RadiusKm = 5.0
	}
	if cfg.Feed.Ring2RadiusKm == 0 {
		cfg.Feed.Ring2RadiusKm = 10.0
	}
	if cfg.Feed.Ring3RadiusKm == 0 {
		cfg.Feed.Ring3RadiusKm = 18.0
	}
	if cfg.Feed.MinLocalPosts24h == 0 {
		cfg.Feed.MinLocalPosts24h = 30
	}
	if cfg.Feed.MinLocalAuthors24h == 0 {
		cfg.Feed.MinLocalAuthors24h = 15
	}
	if cfg.Feed.MedLocalPosts24h == 0 {
		cfg.Feed.MedLocalPosts24h = 15
	}
	if cfg.Feed.MedLocalAuthors24h == 0 {
		cfg.Feed.MedLocalAuthors24h = 8
	}
	if cfg.Feed.LocalShareLow == 0 {
		cfg.Feed.LocalShareLow = 0.30
	}
	if cfg.Feed.LocalShareMedium == 0 {
		cfg.Feed.LocalShareMedium = 0.50
	}
	if cfg.Feed.LocalShareHigh == 0 {
		cfg.Feed.LocalShareHigh = 0.70
	}

	if cfg.Moderation.MinActivationViews == 0 {
		cfg.Moderation.MinActivationViews = 50
	}
	if cfg.Moderation.DailyReportLimit == 0 {
		cfg.Moderation.DailyReportLimit = 10
	}
	if cfg.Moderation.Level1Threshold == 0 {
		cfg.Moderation.Level1Threshold = 3
	}
	if cfg.Moderation.Level2Threshold == 0 {
		cfg.Moderation.Level2Threshold = 5
	}
	if cfg.Moderation.Level3Threshold == 0 {
		cfg.Moderation.Level3Threshold = 10
	}
	if cfg.Moderation.Level4Threshold == 0 {
		cfg.Moderation.Level4Threshold = 20
	}
	if cfg.Moderation.Level1Ratio == 0 {
		cfg.Moderation.Level1Ratio = 0.02
	}
	if cfg.Moderation.Level2Ratio == 0 {
		cfg.Moderation.Level2Ratio = 0.05
	}
	if cfg.Moderation.Level3Ratio == 0 {
		cfg.Moderation.Level3Ratio = 0.08
	}
	if cfg.Moderation.Level4Ratio == 0 {
		cfg.Moderation.Level4Ratio = 0.12
	}

	if cfg.Activation.MinRestrictedHours == 0 {
		cfg.Activation.MinRestrictedHours = 72
	}
	if cfg.Activation.ExtendedRestrictedHours == 0 {
		cfg.Activation.ExtendedRestrictedHours = 120
	}
	if cfg.Activation.RequiredDistinctLoginDays == 0 {
		cfg.Activation.RequiredDistinctLoginDays = 3
	}
	if cfg.Activation.RequiredMeaningfulActions == 0 {
		cfg.Activation.RequiredMeaningfulActions = 5
	}
	if cfg.Activation.MaxRegistrationsPerDeviceDay == 0 {
		cfg.Activation.MaxRegistrationsPerDeviceDay = 3
	}

	// Cache enabled by default (true by default if not specified)
	if v := os.Getenv("CACHE_ENABLED"); v != "" {
		cfg.Cache.Enabled = v == "true"
	}
	if v := os.Getenv("CACHE_PROFILE_STATS_TTL"); v != "" {
		if ttl, err := parseDurationEnv(v); err == nil {
			cfg.Cache.ProfileStatsTTL = ttl
		}
	}
}

func (c *Config) Validate() error {
	if c.Database.Host == "" {
		return fmt.Errorf("database host is required")
	}
	if c.Database.Port == 0 {
		return fmt.Errorf("database port is required")
	}
	if c.JWT.Secret == "" || c.JWT.Secret == "your-secret-key-change-in-production" {
		return fmt.Errorf("jwt secret must be set via environment variable")
	}
	if c.Server.Port == 0 {
		return fmt.Errorf("server port is required")
	}

	if c.OAuth.Apple.ClientID == "" {
		return fmt.Errorf("oauth apple client id is required")
	}

	if c.OAuth.Google.ClientID == "" {
		return fmt.Errorf("oauth google clinet id if required")
	}

	return nil
}

func parseDurationEnv(raw string) (time.Duration, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, fmt.Errorf("empty duration")
	}

	//если есть буквы парсить как по индексу
	if strings.IndexFunc(raw, func(r rune) bool { return r < '0' || r > '9' }) != -1 {
		return time.ParseDuration(raw)
	}

	//если нет то парсить быстрее через атой
	secs, err := strconv.Atoi(raw)
	if err != nil {
		return 0, err
	}
	return time.Duration(secs) * time.Second, nil
}
