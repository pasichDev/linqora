package auth

import (
	"encoding/json"
	"log"
	"time"

	"LinqoraHost/internal/interfaces"

	"github.com/Masterminds/semver"
)

const (
	// MinVersionClient specifies the minimum supported version of the mobile application.
	MinVersionClient = "0.1.0"
)

// AuthResponse represents the structure sent back to clients after an auth attempt.
type AuthResponse struct {
	Success bool   `json:"success"`
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// AuthRequestData identifies the device attempting to connect.
type AuthRequestData struct {
	DeviceID      string `json:"deviceId"`
	DeviceName    string `json:"deviceName"`
	IP            string `json:"ip"`
	VersionClient string `json:"versionClient"`
}

// IsVersionClientSupported checks if the client version meets the minimum requirements.
func (am *AuthManager) IsVersionClientSupported(version string) bool {
	clientVersion, err := semver.NewVersion(version)
	if err != nil {
		return false
	}
	minVersion, _ := semver.NewVersion(MinVersionClient)

	return clientVersion.GreaterThan(minVersion) || clientVersion.Equal(minVersion)
}

// HandleAuthRequest processes an incoming authorization request from a client.
func (am *AuthManager) HandleAuthRequest(client interfaces.WSClient, msg interfaces.WSMessage) {
	log.Printf("Processing auth request from %s", client.GetIP())

	var authData AuthRequestData
	if err := json.Unmarshal(msg.GetData(), &authData); err != nil {
		log.Printf("Error unmarshaling auth data: %v", err)
		sendResponse(client, AuthStatusInvalidFormat, false, MessageTypeAuthResponse)
		return
	}

	deviceID := authData.DeviceID
	if deviceID == "" {
		log.Printf("Empty device ID in auth request")
		sendResponse(client, AuthStatusMissingDeviceID, false, MessageTypeAuthResponse)
		return
	}

	// Verify client compatibility.
	if !am.IsVersionClientSupported(authData.VersionClient) {
		log.Printf("Unsupported client version: %s", authData.VersionClient)
		sendResponse(client, AuthStatusUnsupportedVersion, false, MessageTypeAuthResponse)
		return
	}

	log.Printf("Auth request from device %s (%s) at IP %s",
		authData.DeviceName, deviceID, client.GetIP())

	client.SetDeviceID(deviceID)
	client.SetDeviceName(authData.DeviceName)

	// If a shared secret is configured, issue a challenge instead of going
	// straight to pending approval or auto-authorise.
	if am.config.SharedSecret != "" {
		token, err := am.challenges.Generate(deviceID)
		if err != nil {
			log.Printf("Failed to generate challenge for %s: %v", authData.DeviceName, err)
			sendResponse(client, AuthStatusRequestFailed, false, MessageTypeAuthResponse)
			return
		}
		client.SendSuccess(MessageTypeAuthChallenge, map[string]interface{}{"token": token})
		log.Printf("Challenge issued to device %s (%s)", authData.DeviceName, deviceID)
		return
	}

	// Check if the device is already authorized (no shared secret path).
	if am.IsAuthorized(deviceID) {
		log.Printf("Device %s already authorized", authData.DeviceName)
		sendResponse(client, AuthStatusAuthorized, true, MessageTypeAuthResponse)
		return
	}

	// Request manual authorization if not already authorized.
	pending := am.RequestAuthorization(authData.DeviceName, deviceID, client.GetIP())
	if pending {
		client.SetDeviceID(deviceID)
		client.SetDeviceName(authData.DeviceName)

		sendResponse(client, AuthStatusPending, false, MessageTypeAuthPending)

		// Start background monitoring for the user's decision.
		go am.checkAuthResultPeriodically(client)
		log.Printf("Auth request for %s is pending", authData.DeviceName)
	} else {
		sendResponse(client, AuthStatusRequestFailed, false, MessageTypeAuthResponse)
		log.Printf("Failed to request auth for %s", authData.DeviceName)
	}
}

// checkAuthResultPeriodically polls for authorization results until approval, rejection, or timeout.
func (am *AuthManager) checkAuthResultPeriodically(client interfaces.WSClient) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	timeout := time.After(30 * time.Second)

	for {
		select {
		case <-ticker.C:
			deviceID := client.GetDeviceID()
			if deviceID == "" {
				return
			}

			result, exists := am.CheckPendingResult(deviceID)
			if exists {
				if result {
					sendResponse(client, AuthStatusApproved, true, MessageTypeAuthResponse)
				} else {
					sendResponse(client, AuthStatusRejected, false, MessageTypeAuthResponse)
				}
				return
			}

		case <-timeout:
			sendResponse(client, AuthStatusTimeout, false, MessageTypeAuthResponse)
			return
		}
	}
}

// HandleAuthCheck verifies the current authorization status of a connected client.
func (am *AuthManager) HandleAuthCheck(client interfaces.WSClient) {
	deviceID := client.GetDeviceID()

	if deviceID == "" {
		sendResponse(client, AuthStatusNotAuthorized, false, MessageTypeAuthResponse)
		return
	}

	if am.IsAuthorized(deviceID) {
		sendResponse(client, AuthStatusAuthorized, true, MessageTypeAuthResponse)
		return
	}

	result, exists := am.CheckPendingResult(deviceID)
	if exists {
		if result {
			sendResponse(client, AuthStatusApproved, true, MessageTypeAuthResponse)
		} else {
			sendResponse(client, AuthStatusRejected, false, MessageTypeAuthResponse)
		}
		return
	}

	sendResponse(client, AuthStatusPending, false, MessageTypeAuthPending)
}

// HandleChallengeResponse verifies the HMAC sent by the client in response to
// the challenge issued by HandleAuthRequest.
func (am *AuthManager) HandleChallengeResponse(client interfaces.WSClient, msg interfaces.WSMessage) {
	var data struct {
		Token string `json:"token"`
		HMAC  string `json:"hmac"`
	}
	if err := json.Unmarshal(msg.GetData(), &data); err != nil {
		log.Printf("Error parsing challenge response: %v", err)
		sendResponse(client, AuthStatusInvalidFormat, false, MessageTypeAuthResponse)
		return
	}

	deviceID := client.GetDeviceID()
	if deviceID == "" {
		sendResponse(client, AuthStatusMissingDeviceID, false, MessageTypeAuthResponse)
		return
	}

	if !am.challenges.Verify(deviceID, data.Token, data.HMAC, am.config.SharedSecret) {
		log.Printf("Challenge HMAC mismatch for device %s", client.GetDeviceName())
		sendResponse(client, AuthStatusChallengeInvalid, false, MessageTypeAuthResponse)
		return
	}

	log.Printf("Challenge verified for device %s (%s)", client.GetDeviceName(), deviceID)

	if am.IsAuthorized(deviceID) {
		sendResponse(client, AuthStatusAuthorized, true, MessageTypeAuthResponse)
		return
	}

	pending := am.RequestAuthorization(client.GetDeviceName(), deviceID, client.GetIP())
	if pending {
		sendResponse(client, AuthStatusPending, false, MessageTypeAuthPending)
		go am.checkAuthResultPeriodically(client)
	} else {
		sendResponse(client, AuthStatusRequestFailed, false, MessageTypeAuthResponse)
	}
}

// sendResponse helper function to transmit authorization status to the client.
func sendResponse(client interfaces.WSClient, code int, success bool, typeResponse string) {
	response := AuthResponse{
		Success: success,
		Code:    code,
		Message: GetAuthMessage(code),
	}

	client.SendSuccess(typeResponse, response)
}
