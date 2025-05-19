package ws

import (
	"encoding/json"
)

// ClientMessage представляє повідомлення від клієнта
type ClientMessage struct {
	Type string          `json:"type"`
	Room string          `json:"room,omitempty"`
	Data json.RawMessage `json:"data,omitempty"`
}

// ServerResponse представляет унифицированный формат ответов сервера
type ServerResponse struct {
	Type  string      `json:"type"`
	Data  interface{} `json:"data,omitempty"`
	Error *ErrorInfo  `json:"error,omitempty"`
}

// ErrorInfo представляет структуру информации об ошибке
type ErrorInfo struct {
	Code    *int   `json:"code"`
	Message string `json:"message"`
}

// NewSuccessResponse создает успешный ответ сервера
func NewSuccessResponse(responseType string, data interface{}) ServerResponse {
	return ServerResponse{
		Type:  responseType,
		Data:  data,
		Error: nil,
	}
}

// NewErrorResponse создает ответ сервера с ошибкой
func NewErrorResponse(responseType string, message string, code ...int) ServerResponse {
	errorInfo := ErrorInfo{
		Message: message,
	}

	// Устанавливаем код ошибки, если он предоставлен
	if len(code) > 0 && code[0] != 0 {
		errorCode := code[0]
		errorInfo.Code = &errorCode
	}

	return ServerResponse{
		Type:  responseType,
		Data:  map[string]interface{}{},
		Error: &errorInfo,
	}
}

// Відповідь інформації про систему
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

type MetricsMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}
