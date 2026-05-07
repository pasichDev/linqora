package ws

import (
	"encoding/json"
)

// ClientMessage represents a message received from a client.
type ClientMessage struct {
	Type string          `json:"type"`
	Room string          `json:"room,omitempty"`
	Data json.RawMessage `json:"data,omitempty"`
}

// ServerResponse represents the unified format for all server responses.
type ServerResponse struct {
	Type  string      `json:"type"`
	Data  interface{} `json:"data,omitempty"`
	Error *ErrorInfo  `json:"error,omitempty"`
}

// ErrorInfo contains structured information about an error.
type ErrorInfo struct {
	Code    *int   `json:"code"`
	Message string `json:"message"`
}

// NewSuccessResponse creates a successful server response.
func NewSuccessResponse(responseType string, data interface{}) ServerResponse {
	return ServerResponse{
		Type:  responseType,
		Data:  data,
		Error: nil,
	}
}

// NewErrorResponse creates a server response containing an error.
func NewErrorResponse(responseType string, message string, code ...int) ServerResponse {
	errorInfo := ErrorInfo{
		Message: message,
	}

	// Set error code if provided and non-zero
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
