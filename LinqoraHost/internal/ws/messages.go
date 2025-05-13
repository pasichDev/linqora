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

// AuthData містить дані для авторизації
type AuthData struct {
	DeviceName string `json:"deviceName"`
	IP         string `json:"ip"`
}

// CursorCommand команда для керування курсором
type CursorCommand struct {
	X      int `json:"x"`
	Y      int `json:"y"`
	Action int `json:"action"` // 0 - move, 1 - click, 2 - right click, etc.
}

/*
// SystemInfo містить інформацію про систему
type SystemInfo struct {
	OS          string `json:"os"`
	Hostname    string `json:"hostname"`
	CPUCores    int    `json:"cpuCores"`
	MemoryTotal uint64 `json:"memoryTotal"`
	MemoryFree  uint64 `json:"memoryFree"`
	DiskTotal   uint64 `json:"diskSpaceTotal"`
	DiskFree    uint64 `json:"diskSpaceFree"`
}
*/

// AuthResponse відповідь на авторизацію
type AuthResponse struct {
	Type            string          `json:"type"`
	Success         bool            `json:"success"`
	Message         string          `json:"message,omitempty"`
	AuthInformation AuthInformation `json:"authInfomation,omitempty"`
}

// MetricsMessage повідомлення з метриками
type MetricsMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

// AuthInfomation містить інформацію про систему яка не буде змінюватись
type AuthInformation struct {
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
