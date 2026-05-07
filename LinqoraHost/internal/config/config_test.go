package config

import (
	"encoding/json"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()
	if cfg.Port != 8070 {
		t.Errorf("Expected default port 8070, got %d", cfg.Port)
	}
	if cfg.AuthorizedDevs == nil {
		t.Error("AuthorizedDevs should not be nil")
	}
}

func TestConfigJSON(t *testing.T) {
	cfg := &ServerConfig{
		Port:         9000,
		EnableTLS:    true,
		EnableE2EE:   true,
		SharedSecret: "test-secret",
	}

	data, err := json.Marshal(cfg)
	if err != nil {
		t.Fatalf("Failed to marshal config: %v", err)
	}

	var loadedCfg ServerConfig
	err = json.Unmarshal(data, &loadedCfg)
	if err != nil {
		t.Fatalf("Failed to unmarshal config: %v", err)
	}

	if loadedCfg.Port != 9000 {
		t.Errorf("Expected port 9000, got %d", loadedCfg.Port)
	}
	if !loadedCfg.EnableE2EE {
		t.Error("Expected EnableE2EE to be true")
	}
	if loadedCfg.SharedSecret != "test-secret" {
		t.Errorf("Expected shared secret 'test-secret', got %s", loadedCfg.SharedSecret)
	}
}
