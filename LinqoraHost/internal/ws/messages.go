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
