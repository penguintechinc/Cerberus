// Package config provides configuration management for the Go backend.
package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the Go backend.
type Config struct {
	// Server settings
	Host        string
	Port        int
	GRPCPort    int
	Environment string
	Version     string

	// XDP settings
	XDPEnabled   bool
	XDPMode      string // "native", "skb", or "offload"
	XDPInterface string

	// NUMA settings
	NUMAEnabled      bool
	NUMANodeID       int
	HugepagesEnabled bool

	// Memory pool settings
	MemoryPoolSlots    int
	MemoryPoolSlotSize int
	MemoryPreallocate  bool

	// Metrics
	MetricsEnabled bool
	MetricsPort    int

	// Timeouts
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
}

// Load loads configuration from environment variables.
func Load() *Config {
	return &Config{
		// Server
		Host:        getEnv("HOST", "0.0.0.0"),
		Port:        getEnvInt("PORT", 8080),
		GRPCPort:    getEnvInt("GRPC_PORT", 50051),
		Environment: getEnv("GO_ENV", "development"),
		Version:     getEnv("VERSION", "1.0.0"),

		// XDP
		XDPEnabled:   getEnvBool("XDP_ENABLED", false),
		XDPMode:      getEnv("XDP_MODE", "skb"), // skb is safest default
		XDPInterface: getEnv("XDP_INTERFACE", "eth0"),

		// NUMA
		NUMAEnabled:      getEnvBool("NUMA_ENABLED", false),
		NUMANodeID:       getEnvInt("NUMA_NODE_ID", 0),
		HugepagesEnabled: getEnvBool("HUGEPAGES_ENABLED", false),

		// Memory pool
		MemoryPoolSlots:    getEnvInt("MEMORY_POOL_SLOTS", 1024),
		MemoryPoolSlotSize: getEnvInt("MEMORY_POOL_SLOT_SIZE", 2048),
		MemoryPreallocate:  getEnvBool("MEMORY_PREALLOCATE", true),

		// Metrics
		MetricsEnabled: getEnvBool("METRICS_ENABLED", true),
		MetricsPort:    getEnvInt("METRICS_PORT", 9090),

		// Timeouts
		ReadTimeout:  getEnvDuration("READ_TIMEOUT", 30*time.Second),
		WriteTimeout: getEnvDuration("WRITE_TIMEOUT", 30*time.Second),
		IdleTimeout:  getEnvDuration("IDLE_TIMEOUT", 120*time.Second),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if b, err := strconv.ParseBool(value); err == nil {
			return b
		}
	}
	return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if d, err := time.ParseDuration(value); err == nil {
			return d
		}
	}
	return defaultValue
}
