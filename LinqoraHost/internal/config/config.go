package config

import "time"

// ServerConfig містить конфігурацію сервера
type ServerConfig struct {
	Port            int             // Порт для WebSocket сервера
	MDNSName        string          // Ім'я mDNS сервісу
	MDNSType        string          // Тип mDNS сервісу
	MDNSDomain      string          // Домен mDNS сервісу
	ValidDeviceIDs  map[string]bool // Перелік дозволених deviceCode
	MetricsInterval time.Duration   // Інтервал надсилання метрик
}

// DefaultConfig повертає конфігурацію за замовчуванням
func DefaultConfig() *ServerConfig {
	return &ServerConfig{
		Port:       8070,
		MDNSName:   "linqora_host",
		MDNSType:   "_222222._tcp",
		MDNSDomain: "local.",
		ValidDeviceIDs: map[string]bool{
			"222222": true,
		},
		MetricsInterval: 2 * time.Second,
	}
}
