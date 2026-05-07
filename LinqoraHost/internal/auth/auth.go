package auth

import (
	"log"
	"sync"
	"time"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/interfaces"
)

// AuthManager coordinates device authorization requests and maintains the trusted device registry.
type AuthManager struct {
	config        *config.ServerConfig
	pendingAuth   map[string]*interfaces.PendingAuthRequest
	pendingChan   chan<- interfaces.PendingAuthRequest
	pendingResult map[string]bool
	challenges    *ChallengeStore
	mu            sync.Mutex
}

// NewAuthManager initialises a new AuthManager with the provided server configuration and output channel.
func NewAuthManager(cfg *config.ServerConfig, authChan chan<- interfaces.PendingAuthRequest) *AuthManager {
	return &AuthManager{
		config:        cfg,
		pendingAuth:   make(map[string]*interfaces.PendingAuthRequest),
		pendingChan:   authChan,
		pendingResult: make(map[string]bool),
		challenges:    NewChallengeStore(),
	}
}

// RequestAuthorization initiates a new authorization flow for a device.
// It returns true if the request was successfully queued or if the device is already trusted.
func (am *AuthManager) RequestAuthorization(deviceName, deviceID, ip string) bool {
	am.mu.Lock()
	defer am.mu.Unlock()

	// Check if device is already authorized
	if _, exists := am.config.AuthorizedDevs[deviceID]; exists {
		log.Printf("Device %s already authorized", deviceName)
		return true
	}

	// Check if there is already a pending request
	if _, exists := am.pendingAuth[deviceID]; exists {
		log.Printf("Authorization request for device %s already pending", deviceName)
		return true
	}

	// Create new authorization request
	request := &interfaces.PendingAuthRequest{
		DeviceName:  deviceName,
		DeviceID:    deviceID,
		IP:          ip,
		RequestTime: time.Now(),
	}

	am.pendingAuth[deviceID] = request

	if am.pendingChan == nil {
		log.Printf("ERROR: pendingChan is nil, cannot send auth request for %s", deviceName)
		return false
	}

	// Send request to channel asynchronously
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

// RespondToAuthRequest records the user's decision (approve/reject) for a pending request.
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
		// Persist authorized device in configuration
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

// IsAuthorized checks if the given device ID is in the trusted devices list.
func (am *AuthManager) IsAuthorized(deviceID string) bool {
	am.mu.Lock()
	defer am.mu.Unlock()

	_, exists := am.config.AuthorizedDevs[deviceID]
	return exists
}

// CheckPendingResult retrieves and clears the result of a recently completed authorization request.
func (am *AuthManager) CheckPendingResult(deviceID string) (bool, bool) {
	am.mu.Lock()
	defer am.mu.Unlock()

	result, exists := am.pendingResult[deviceID]
	if exists {
		delete(am.pendingResult, deviceID)
	}
	return result, exists
}

// RevokeAuth removes a device from the trusted devices list.
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

// ListDevices returns a list of all currently authorized devices.
func (am *AuthManager) ListDevices() []config.DeviceAuth {
	am.mu.Lock()
	defer am.mu.Unlock()

	devices := make([]config.DeviceAuth, 0, len(am.config.AuthorizedDevs))
	for _, auth := range am.config.AuthorizedDevs {
		devices = append(devices, auth)
	}
	return devices
}
