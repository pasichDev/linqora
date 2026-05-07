package interfaces

import (
	"time"
)

// PendingAuthRequest represents an authorization request waiting for manual approval.
type PendingAuthRequest struct {
	DeviceName  string
	DeviceID    string
	IP          string
	RequestTime time.Time
}

// WSClient defines the required behavior for a WebSocket client in the auth subsystem.
type WSClient interface {
	SendError(requestType string, message string, errorCode ...int) error
	SendSuccess(responseType string, data interface{}) error
	GetIP() string
	GetDeviceID() string
	GetDeviceName() string
	SetDeviceID(id string)
	SetDeviceName(name string)
	IsClosed() bool
}

// WSMessage defines a generic interface for raw WebSocket messages.
type WSMessage interface {
	GetType() string
	GetData() []byte
}

// AuthManagerInterface defines the contract for authorization management services.
type AuthManagerInterface interface {
	RequestAuthorization(deviceName, deviceID, ip string) bool
	RespondToAuthRequest(deviceID string, approved bool)
	IsAuthorized(deviceID string) bool
	CheckPendingResult(deviceID string) (bool, bool)
	RevokeAuth(deviceID string)

	HandleAuthRequest(client WSClient, msg WSMessage)
	HandleAuthCheck(client WSClient)
	HandleChallengeResponse(client WSClient, msg WSMessage)
}
