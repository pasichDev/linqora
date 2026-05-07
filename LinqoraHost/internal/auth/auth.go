package auth

import (
	"log/slog"
	"sync"
	"time"

	"LinqoraHost/internal/config"
	"LinqoraHost/internal/interfaces"
)

const (
	// maxAuthAttemptsPerMinute is the maximum number of auth attempts allowed per IP per minute.
	maxAuthAttemptsPerMinute = 5
)

// authAttemptRecord tracks the number of auth attempts from a single IP.
type authAttemptRecord struct {
	Count        int
	FirstAttempt time.Time
}

// AuthManager coordinates device authorization requests and maintains the trusted device registry.
type AuthManager struct {
	config        *config.ServerConfig
	pendingAuth   map[string]*interfaces.PendingAuthRequest
	pendingChan   chan<- interfaces.PendingAuthRequest
	pendingResult map[string]bool
	challenges    *ChallengeStore
	authAttempts  map[string]*authAttemptRecord
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
		authAttempts:  make(map[string]*authAttemptRecord),
	}
}

// cleanupAttempts removes attempt records older than 2 minutes.
// Must be called with am.mu held.
func (am *AuthManager) cleanupAttempts() {
	cutoff := time.Now().Add(-2 * time.Minute)
	for ip, record := range am.authAttempts {
		if record.FirstAttempt.Before(cutoff) {
			delete(am.authAttempts, ip)
		}
	}
}

// RequestAuthorization initiates a new authorization flow for a device.
// It returns true if the request was successfully queued or if the device is already trusted.
func (am *AuthManager) RequestAuthorization(deviceName, deviceID, ip string) bool {
	am.mu.Lock()
	defer am.mu.Unlock()

	// Clean up stale entries first
	am.cleanupAttempts()

	// Check per-IP rate limit
	record, exists := am.authAttempts[ip]
	if exists && time.Since(record.FirstAttempt) < time.Minute {
		if record.Count >= maxAuthAttemptsPerMinute {
			slog.Warn("Auth rate limit exceeded", "ip", ip, "device", deviceName, "attempts", record.Count)
			return false
		}
	}

	// Check if device is already authorized
	if _, exists := am.config.AuthorizedDevs[deviceID]; exists {
		slog.Info("Device already authorized", "device", deviceName)
		return true
	}

	// Check if there is already a pending request
	if _, exists := am.pendingAuth[deviceID]; exists {
		slog.Info("Authorization request already pending", "device", deviceName)
		return true
	}

	// Increment attempt counter
	if record == nil || time.Since(record.FirstAttempt) >= time.Minute {
		am.authAttempts[ip] = &authAttemptRecord{Count: 1, FirstAttempt: time.Now()}
	} else {
		record.Count++
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
		slog.Error("pendingChan is nil, cannot send auth request", "device", deviceName)
		return false
	}

	// Send request to channel asynchronously
	go func() {
		select {
		case am.pendingChan <- *request:
			slog.Info("Auth request sent to console", "device", deviceName)
		case <-time.After(1 * time.Second):
			slog.Warn("Failed to send auth request to console (timeout)", "device", deviceName)
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
		slog.Warn("No pending auth request", "device_id", deviceID)
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
			slog.Error("Error saving config", "err", err)
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
		slog.Info("Authorization revoked", "device_id", deviceID)

		if err := am.config.SaveConfig(); err != nil {
			slog.Error("Error saving config", "err", err)
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
