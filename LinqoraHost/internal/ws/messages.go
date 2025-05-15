package ws

import (
	"encoding/json"
)

// ClientMessage представляє повідомлення від клієнта
type ClientMessage struct {
	Type       string          `json:"type"`
	DeviceCode string          `json:"deviceCode"`
	Room       string          `json:"room,omitempty"`
	Data       json.RawMessage `json:"data,omitempty"`
}

// AuthResponse відповідь на авторизацію
type HostInfoResponse struct {
	Type     string   `json:"type"`
	Success  bool     `json:"success"`
	Message  string   `json:"message,omitempty"`
	HostInfo HostInfo `json:"host_info,omitempty"`
}

// HostInfo містить інформацію про систему яка не буде змінюватись
type HostInfo struct {
	OS                 string  `json:"os"`
	Hostname           string  `json:"hostname"`
	CpuModel           string  `json:"cpuModel"`
	CpuFrequency       float64 `json:"cpuFrequency"`
	CpuPhysicalCores   int     `json:"physicalCores"`
	CpuLogicalCores    int     `json:"logicalCores"`
	VirtualMemoryTotal float64 `json:"virtualMemoryTotal"`
}

type MediaMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

// MetricsMessage повідомлення з метриками
type MetricsMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}
