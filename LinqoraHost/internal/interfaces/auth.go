package interfaces

import (
	"time"
)

// PendingAuthRequest представляет ожидающий запрос авторизации
type PendingAuthRequest struct {
	DeviceName  string
	DeviceID    string
	IP          string
	RequestTime time.Time
}

// WSClient определяет интерфейс для работы с WebSocket клиентом
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

// WSMessage определяет интерфейс для сообщений WebSocket
type WSMessage interface {
	GetType() string
	GetData() []byte
}

// AuthManagerInterface определяет интерфейс для менеджера авторизации
type AuthManagerInterface interface {
	RequestAuthorization(deviceName, deviceID, ip string) bool
	RespondToAuthRequest(deviceID string, approved bool)
	IsAuthorized(deviceID string) bool
	CheckPendingResult(deviceID string) (bool, bool)
	RevokeAuth(deviceID string)

	// Методы теперь используют интерфейсы вместо конкретных типов
	HandleAuthRequest(client WSClient, msg WSMessage)
	HandleAuthCheck(client WSClient)
}
