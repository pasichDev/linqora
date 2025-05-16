package auth

import (
	"log"
	"sync"
	"time"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/interfaces"
)

// AuthManager управляет авторизацией клиентов
type AuthManager struct {
	config        *config.ServerConfig
	pendingAuth   map[string]*interfaces.PendingAuthRequest // Используем тип из интерфейсов
	pendingChan   chan<- interfaces.PendingAuthRequest
	pendingResult map[string]bool
	mu            sync.Mutex
}

func NewAuthManager(cfg *config.ServerConfig, authChan chan<- interfaces.PendingAuthRequest) *AuthManager {
	return &AuthManager{
		config:        cfg,
		pendingAuth:   make(map[string]*interfaces.PendingAuthRequest),
		pendingChan:   authChan,
		pendingResult: make(map[string]bool),
	}
}

// RequestAuthorization запрашивает авторизацию устройства
func (am *AuthManager) RequestAuthorization(deviceName, deviceID, ip string) bool {
	am.mu.Lock()
	defer am.mu.Unlock()

	// Проверяем, есть ли устройство в списке авторизованных
	if _, exists := am.config.AuthorizedDevs[deviceID]; exists {
		log.Printf("Device %s already authorized", deviceName)
		return true
	}

	// Проверяем, нет ли уже ожидающего запроса
	if _, exists := am.pendingAuth[deviceID]; exists {
		log.Printf("Authorization request for device %s already pending", deviceName)
		return true
	}

	// Создаем новый запрос авторизации
	request := &interfaces.PendingAuthRequest{
		DeviceName:  deviceName,
		DeviceID:    deviceID,
		IP:          ip,
		RequestTime: time.Now(),
	}

	am.pendingAuth[deviceID] = request

	// ВАЖНО: проверка канала
	if am.pendingChan == nil {
		log.Printf("ERROR: pendingChan is nil, cannot send auth request for %s", deviceName)
		return false
	}

	// Отправляем запрос в канал (неблокирующим способом)
	go func() {
		select {
		case am.pendingChan <- *request:
			log.Printf("Auth request sent to console for device %s", deviceName)
		case <-time.After(1 * time.Second):
			log.Printf("Failed to send auth request to console (timeout) for device %s", deviceName)
		}
	}()

	return true
}

// RespondToAuthRequest обрабатывает ответ на запрос авторизации
func (am *AuthManager) RespondToAuthRequest(deviceID string, approved bool) {
	am.mu.Lock()
	defer am.mu.Unlock()

	request, exists := am.pendingAuth[deviceID]
	if !exists {
		log.Printf("No pending auth request for device ID: %s", deviceID)
		return
	}

	delete(am.pendingAuth, deviceID)
	am.pendingResult[deviceID] = approved

	if approved {
		// Добавляем устройство в список авторизованных
		am.config.AuthorizedDevs[deviceID] = config.DeviceAuth{
			DeviceName: request.DeviceName,
			DeviceID:   deviceID,
			LastAuth:   time.Now().Format("2006-01-02 15:04:05"),
		}

		if err := am.config.SaveConfig(); err != nil {
			log.Printf("Error saving config: %v", err)
		}
	}
}

// IsAuthorized проверяет, авторизовано ли устройство
func (am *AuthManager) IsAuthorized(deviceID string) bool {
	am.mu.Lock()
	defer am.mu.Unlock()

	_, exists := am.config.AuthorizedDevs[deviceID]
	return exists
}

// CheckPendingResult проверяет результат ожидающего запроса авторизации
func (am *AuthManager) CheckPendingResult(deviceID string) (bool, bool) {
	am.mu.Lock()
	defer am.mu.Unlock()

	result, exists := am.pendingResult[deviceID]
	if exists {
		delete(am.pendingResult, deviceID)
	}
	return result, exists
}

// RevokeAuth отзывает авторизацию устройства
func (am *AuthManager) RevokeAuth(deviceID string) {
	am.mu.Lock()
	defer am.mu.Unlock()

	if _, exists := am.config.AuthorizedDevs[deviceID]; exists {
		delete(am.config.AuthorizedDevs, deviceID)
		log.Printf("Authorization revoked for device ID: %s", deviceID)

		if err := am.config.SaveConfig(); err != nil {
			log.Printf("Error saving config: %v", err)
		}
	}
}

// ListDevices возвращает список авторизованных устройств
func (am *AuthManager) ListDevices() []config.DeviceAuth {
	am.mu.Lock()
	defer am.mu.Unlock()

	devices := make([]config.DeviceAuth, 0, len(am.config.AuthorizedDevs))
	for _, auth := range am.config.AuthorizedDevs {
		devices = append(devices, auth)
	}
	return devices
}
