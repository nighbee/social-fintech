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
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	Redis    RedisConfig    `yaml:"redis"`
	Logging  LoggingConfig  `yaml:"logging"`
	JWT      JWTConfig      `yaml:"jwt"`
	CORS     CORSConfig     `yaml:"cors"`
	OAuth    OAuthConfig    `yaml:"oauth"`
	Firebase FirebaseConfig `yaml:"firebase"`
	Storage  StorageConfig  `yaml:"storage"`
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

	// Storage (MinIO / S3)
	if v := os.Getenv("MINIO_ENDPOINT"); v != "" {
		cfg.Storage.Endpoint = v
	}
	if v := os.Getenv("MINIO_ACCESS_KEY"); v != "" {
		cfg.Storage.AccessKey = v
	}
	if v := os.Getenv("MINIO_SECRET_KEY"); v != "" {
		cfg.Storage.SecretKey = v
	}
	if v := os.Getenv("MINIO_BUCKET"); v != "" {
		cfg.Storage.Bucket = v
	}
	if v := os.Getenv("MINIO_USE_SSL"); v != "" {
		cfg.Storage.UseSSL = v == "true"
	}
	if v := os.Getenv("MINIO_PUBLIC_URL"); v != "" {
		cfg.Storage.PublicURL = v
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
