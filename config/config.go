package config

import "os"

type Config struct {
	ServerPort string
	DBHost     string
	DBPort     string
	DBUser     string
	DBPass     string
	DBName     string
	DBSSL      string
	JWTSecret  string
}

func Load() Config {
	return Config{
		ServerPort: get("SERVER_PORT", "8080"),
		DBHost:     get("DB_HOST", "localhost"),
		DBPort:     get("DB_PORT", "5432"),
		DBUser:     get("DB_USER", "admin"),
		DBPass:     get("DB_PASSWORD", "1234"),
		DBName:     get("DB_NAME", "mydb"),
		DBSSL:      get("DB_SSLMODE", "disable"),
		JWTSecret:  get("JWT_SECRET", "change-me"),
	}
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
